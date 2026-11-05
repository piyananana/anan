// lib/ap/screens/ap_bulk_payment_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../cm/services/cm_period_service.dart';
import '../../utils/date_utils.dart';
import '../../cd/services/cd_currency_service.dart';
import '../../gl/widgets/gl_journal_preview.dart';
import '../../sa/models/sa_doc_approval.dart';
import '../../sa/widgets/sa_doc_approval_panel.dart';

final _fmt     = NumberFormat('#,##0.00', 'en_US');
final _dateFmt = DateFormat('dd/MM/yyyy');

class ApBulkPaymentScreen extends StatefulWidget {
  const ApBulkPaymentScreen({super.key});
  @override
  State<ApBulkPaymentScreen> createState() => _ApBulkPaymentScreenState();
}

class _ApBulkPaymentScreenState extends State<ApBulkPaymentScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isLeftExpanded = true;
  double _leftWidth = 300;
  bool _isDraggingDivider = false;
  bool _isEnglish = false;

  // setup panel
  int?     _fBankAccId;
  DateTime _fPaymentDate = DateTime.now();
  String   _fPayMethod   = 'TRANSFER';

  // filter
  String   _fVendorSearch = '';
  DateTime? _fDueDateTo;

  List<Map<String, dynamic>> _invoices     = [];
  List<Map<String, dynamic>> _bankAccounts = [];
  final Set<int> _selected = {};

  bool _loading  = false;
  bool _running  = false;

  // ชุดจ่ายแบบกลุ่ม — ต้องผ่านอนุมัติก่อนจ่าย (Draft → Submitted → Approved → Paid)
  List<Map<String, dynamic>> _batches = [];
  bool _loadingBatches = false;

  final _vendorCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBankAccounts();
    _loadInvoices();
    _loadBatches();
  }

  @override
  void dispose() {
    _vendorCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _headers() async =>
      {...await AuthService().getAuthHeader(), 'Content-Type': 'application/json'};

  String _bankAccountLabel(Map<String, dynamic> b) {
    final nameTh = b['account_name_th'] ?? '';
    final nameEn = b['account_name_en'] ?? '';
    final name = _isEnglish && (nameEn as String).isNotEmpty ? nameEn : nameTh;
    return '${b['account_code'] ?? ''} $name';
  }

  String _vendorLabel(Map<String, dynamic> inv) {
    final nameTh = inv['vendor_name_th'] ?? '';
    final nameEn = inv['vendor_name_en'] ?? '';
    return _isEnglish && (nameEn as String).isNotEmpty ? nameEn : nameTh;
  }

  Future<void> _loadBankAccounts() async {
    try {
      final h = await _headers();
      final r = await http.get(Uri.parse('${AppConfig.apiCm}/cm_bank_account'), headers: h);
      if (r.statusCode == 200) {
        final d = json.decode(r.body) as List;
        setState(() => _bankAccounts = d.cast<Map<String, dynamic>>());
      }
    } catch (_) {}
  }

  Future<void> _loadInvoices() async {
    setState(() { _loading = true; _selected.clear(); });
    try {
      final h = await _headers();
      final params = <String, String>{};
      if (_fVendorSearch.isNotEmpty) params['vendor_search'] = _fVendorSearch;
      if (_fDueDateTo != null) params['due_date_to'] = formatLocalDate(_fDueDateTo!);
      final uri = Uri.parse('${AppConfig.apiAp}/ap_bulk_payment/eligible')
          .replace(queryParameters: params.isNotEmpty ? params : null);
      final r = await http.get(uri, headers: h);
      if (r.statusCode == 200) {
        final d = json.decode(r.body) as List;
        setState(() => _invoices = d.cast<Map<String, dynamic>>());
      }
    } catch (e) { _showErr('$e'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  double get _totalSelected => _invoices
      .where((inv) => _selected.contains(inv['id'] as int?))
      .fold(0.0, (s, inv) => s + ((inv['remaining_amount'] as num?)?.toDouble() ?? 0));

  Future<void> _runBulkPayment() async {
    final l = AppL10n(Provider.of<LanguageProvider>(context, listen: false).isEnglish);
    final isEnglish = l.isEnglish;
    if (_fBankAccId == null) {
      _showErr(isEnglish ? 'Please select a bank account' : 'กรุณาเลือกบัญชีธนาคาร');
      return;
    }
    if (_selected.isEmpty) {
      _showErr(isEnglish ? 'Please select at least 1 invoice' : 'กรุณาเลือกใบแจ้งหนี้อย่างน้อย 1 รายการ');
      return;
    }
    if (!await CmPeriodService.canPost(context, _fPaymentDate)) return;
    if (!(MenuScope.of(context)?.canCreate ?? true)) return;

    final items = _invoices
        .where((inv) => _selected.contains(inv['id'] as int?))
        .map((inv) => {
              'ap_document_id': inv['id'],
              'amount': (inv['remaining_amount'] as num?)?.toDouble() ?? 0,
            })
        .toList();
    final body = json.encode({
      'bank_account_id': _fBankAccId,
      'payment_date':    formatLocalDate(_fPaymentDate),
      'payment_method':  _fPayMethod,
      'items':           items,
    });

    // รายการบัญชีที่จะเกิด — คำนวณที่ backend ด้วยฟังก์ชันเดียวกับตอนจ่ายจริง
    List<GlJournalLine> journal;
    setState(() => _running = true);
    try {
      final r = await http.post(Uri.parse('${AppConfig.apiAp}/ap_bulk_payment/preview'),
          headers: await _headers(), body: body);
      if (r.statusCode != 200) {
        String msg = r.body;
        try { msg = (json.decode(r.body) as Map<String, dynamic>)['error']?.toString() ?? msg; } catch (_) {}
        _showErr(isEnglish ? 'Error: $msg' : 'เกิดข้อผิดพลาด: $msg');
        return;
      }
      journal = GlJournalLine.listFromJson((json.decode(r.body) as Map<String, dynamic>)['journal']);
    } catch (e) {
      _showErr('$e');
      return;
    } finally {
      if (mounted) setState(() => _running = false);
    }
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEnglish ? 'Create Payment Batch and Request Approval' : 'สร้างชุดจ่ายและส่งขออนุมัติ'),
        content: SizedBox(
          width: (MediaQuery.of(context).size.width * 0.8).clamp(320.0, 900.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEnglish
                    ? 'Number of invoices: ${_selected.length}'
                    : 'จำนวนรายการ: ${_selected.length} ใบ'),
                Text(isEnglish
                    ? 'Total amount: ${_fmt.format(_totalSelected)} ${CurrencyService.baseCode}'
                    : 'ยอดรวม: ${_fmt.format(_totalSelected)} ${CurrencyService.baseCode}'),
                Text(isEnglish
                    ? 'Payment date: ${_dateFmt.format(_fPaymentDate)}'
                    : 'วันที่ชำระ: ${_dateFmt.format(_fPaymentDate)}'),
                const SizedBox(height: 6),
                Text(
                    isEnglish
                        ? 'The batch is paid only after it is approved (Payment Batches tab).'
                        : 'ระบบจะจ่ายได้หลังชุดได้รับอนุมัติแล้วเท่านั้น (ที่แท็บชุดจ่ายแบบกลุ่ม)',
                    style: TextStyle(fontSize: 12, color: Colors.orange[800])),
                const SizedBox(height: 12),
                GlJournalPreview(
                  lines: journal, isEnglish: isEnglish,
                  note: isEnglish
                      ? '* AP accounts from the vendor (or the AP payment GL setup), bank account from the selected bank; deferred VAT is recognized pro rata to the amount paid'
                      : '* บัญชีเจ้าหนี้จากผู้ขาย (หรือการตั้งค่าบัญชีของเอกสารจ่ายชำระ AP) บัญชีธนาคารจากบัญชีที่เลือก และรับรู้ VAT รอตัดบัญชีตามสัดส่วนที่จ่าย',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.confirm),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    if (!mounted) return;
    final menuId = MenuScope.of(context)?.id;
    setState(() => _running = true);
    try {
      final h = await _headers();
      final r = await http.post(
          Uri.parse('${AppConfig.apiAp}/ap_bulk_payment/batches'), headers: h, body: body);
      if (r.statusCode != 201) {
        _showErr(isEnglish ? 'Error: ${_errMsg(r.body)}' : 'เกิดข้อผิดพลาด: ${_errMsg(r.body)}');
        return;
      }
      final created = json.decode(r.body) as Map<String, dynamic>;
      final batchNo = created['batch_no'] ?? '';
      await _loadInvoices();
      await _loadBatches();
      // ส่งขออนุมัติต่อทันที — ถ้าไม่ผ่าน (เช่น วงเงินไม่พอ) ชุดยังอยู่เป็น Draft ให้แก้แล้วส่งใหม่ที่แท็บชุดจ่าย
      final s = await http.put(Uri.parse('${AppConfig.apiAp}/ap_bulk_payment/batches/${created['id']}/submit'),
          headers: h, body: json.encode({'menu_id': menuId}));
      await _loadBatches();
      if (s.statusCode == 200) {
        _showOk(isEnglish
            ? 'Batch $batchNo created and submitted for approval'
            : 'สร้างชุด $batchNo และส่งขออนุมัติแล้ว');
      } else {
        _showErr(isEnglish
            ? 'Batch $batchNo saved as draft but could not be submitted: ${_errMsg(s.body)}'
            : 'บันทึกชุด $batchNo เป็นร่างแล้ว แต่ส่งขออนุมัติไม่ได้: ${_errMsg(s.body)}');
      }
    } catch (e) { _showErr('$e'); }
    finally { if (mounted) setState(() => _running = false); }
  }

  String _errMsg(String body) {
    try {
      final m = json.decode(body) as Map<String, dynamic>;
      return (m['message'] ?? m['error'] ?? body).toString();
    } catch (_) { return body; }
  }

  Future<void> _loadBatches() async {
    setState(() => _loadingBatches = true);
    try {
      final r = await http.get(Uri.parse('${AppConfig.apiAp}/ap_bulk_payment/batches'), headers: await _headers());
      if (r.statusCode == 200 && mounted) {
        setState(() => _batches = (json.decode(r.body) as List).cast<Map<String, dynamic>>());
      }
    } catch (e) { _showErr('$e'); }
    finally { if (mounted) setState(() => _loadingBatches = false); }
  }

  Future<void> _openBatch(int id) async {
    final menu = MenuScope.of(context);
    await showDialog<void>(
      context: context,
      builder: (_) {
        final dlg = _BulkBatchDialog(batchId: id, onChanged: () { _loadBatches(); _loadInvoices(); });
        return menu == null ? dlg : MenuScope(menu: menu, child: dlg);
      },
    );
    await _loadBatches();
  }

  void _showOk(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.green.shade700));
  }

  void _showErr(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final l = AppL10n(isEnglish);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        title: const MenuTitle(),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: l.refresh,
              onPressed: () { _loadInvoices(); _loadBatches(); }),
          const SizedBox(width: 4),
          if (_selected.isNotEmpty)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: _running ? null : _runBulkPayment,
              icon: _running
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.how_to_reg_outlined, size: 16),
              label: Text(
                  isEnglish
                      ? 'Request approval: ${_selected.length} item(s) | ${_fmt.format(_totalSelected)}'
                      : 'ขออนุมัติจ่าย ${_selected.length} รายการ | ${_fmt.format(_totalSelected)} ${CurrencyService.baseCode}',
                  style: const TextStyle(fontSize: 13)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final double maxLeftWidth =
            (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Toggle strip
          Container(
            width: 36,
            color: Colors.blue[700],
            child: IconButton(
              icon: Icon(
                _isLeftExpanded ? Icons.filter_list_off : Icons.filter_list,
                color: Colors.white,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _isLeftExpanded = !_isLeftExpanded),
              tooltip: _isLeftExpanded
                  ? (isEnglish ? 'Collapse panel' : 'ย่อแผง')
                  : (isEnglish ? 'Expand panel' : 'ขยายแผง'),
            ),
          ),
          // Left panel – setup
          AnimatedContainer(
            duration: _isDraggingDivider ? Duration.zero : const Duration(milliseconds: 200),
            width: _isLeftExpanded ? _leftWidth : 0.0,
            child: ClipRect(
              child: OverflowBox(
                maxWidth: _leftWidth,
                minWidth: _leftWidth,
                alignment: Alignment.topLeft,
                child: ColoredBox(
                  color: Colors.blueGrey.shade100,
                  child: SizedBox(
                    width: _leftWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          color: Colors.blueGrey.shade200,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Text(
                              isEnglish ? 'Payment Settings' : 'ตั้งค่าการชำระเงิน',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey.shade800)),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _field(isEnglish ? 'Bank Account *' : 'บัญชีธนาคาร *', DropdownButtonFormField<int?>(
                                  value: _fBankAccId,
                                  isDense: true,
                                  decoration: const InputDecoration(border: OutlineInputBorder(),
                                      filled: true, fillColor: Colors.white,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                  hint: Text(isEnglish ? 'Select account' : 'เลือกบัญชี', style: const TextStyle(fontSize: 13)),
                                  items: _bankAccounts.map((b) => DropdownMenuItem<int?>(
                                      value: b['id'] as int?,
                                      child: Text(_bankAccountLabel(b),
                                          style: const TextStyle(fontSize: 13),
                                          overflow: TextOverflow.ellipsis))).toList(),
                                  onChanged: (v) => setState(() => _fBankAccId = v),
                                )),
                                const SizedBox(height: 10),
                                _field(isEnglish ? 'Payment Date *' : 'วันที่ชำระ *',
                                    _datePicker(_fPaymentDate, (d) => setState(() => _fPaymentDate = d))),
                                const SizedBox(height: 10),
                                _field(isEnglish ? 'Payment Method' : 'วิธีชำระ', DropdownButtonFormField<String>(
                                  value: _fPayMethod,
                                  isDense: true,
                                  decoration: const InputDecoration(border: OutlineInputBorder(),
                                      filled: true, fillColor: Colors.white,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                  items: [
                                    DropdownMenuItem(value: 'TRANSFER', child: Text(isEnglish ? 'Transfer' : 'โอนเงิน', style: const TextStyle(fontSize: 13))),
                                    DropdownMenuItem(value: 'CHECK',    child: Text(isEnglish ? 'Check' : 'เช็ค', style: const TextStyle(fontSize: 13))),
                                    DropdownMenuItem(value: 'CASH',     child: Text(isEnglish ? 'Cash' : 'เงินสด', style: const TextStyle(fontSize: 13))),
                                  ],
                                  onChanged: (v) => setState(() => _fPayMethod = v ?? 'TRANSFER'),
                                )),
                                const Divider(height: 24),
                                Text(isEnglish ? 'Filter Invoices' : 'กรองใบแจ้งหนี้',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade700)),
                                const SizedBox(height: 8),
                                _field(isEnglish ? 'Search Vendor' : 'ค้นหาผู้ขาย', TextField(
                                  controller: _vendorCtrl,
                                  decoration: InputDecoration(
                                      isDense: true, border: const OutlineInputBorder(),
                                      filled: true, fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      hintText: isEnglish ? 'Code / Name' : 'รหัส / ชื่อ'),
                                  style: const TextStyle(fontSize: 13),
                                  onChanged: (v) => setState(() => _fVendorSearch = v),
                                  onSubmitted: (_) => _loadInvoices(),
                                )),
                                const SizedBox(height: 10),
                                _field(isEnglish ? 'Due Date To' : 'ครบกำหนดถึง',
                                    _datePicker(_fDueDateTo, (d) { setState(() => _fDueDateTo = d); _loadInvoices(); })),
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(double.infinity, 36),
                                      padding: const EdgeInsets.symmetric(vertical: 8)),
                                  onPressed: _loadInvoices,
                                  icon: const Icon(Icons.search, size: 16),
                                  label: Text(l.search, style: const TextStyle(fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Resizable divider
          if (_isLeftExpanded)
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                onHorizontalDragStart: (_) => setState(() => _isDraggingDivider = true),
                onHorizontalDragUpdate: (details) => setState(() {
                  _leftWidth = (_leftWidth + details.delta.dx).clamp(220.0, maxLeftWidth);
                }),
                onHorizontalDragEnd: (_) => setState(() => _isDraggingDivider = false),
                child: Container(width: 5, color: Colors.grey[400]),
              ),
            ),
          // Right panel – invoice list / payment batches
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(children: [
                Material(
                  color: Colors.blueGrey.shade100,
                  child: TabBar(
                    labelColor: Colors.blue[800],
                    unselectedLabelColor: Colors.blueGrey.shade700,
                    indicatorColor: Colors.blue[700],
                    tabs: [
                      Tab(height: 36, text: isEnglish ? 'Select Invoices' : 'เลือกใบแจ้งหนี้'),
                      Tab(height: 36, text: isEnglish ? 'Payment Batches (${_batches.length})' : 'ชุดจ่ายแบบกลุ่ม (${_batches.length})'),
                    ],
                  ),
                ),
                Expanded(child: TabBarView(children: [
            Column(children: [
              // Column headers
              Container(
                color: Colors.blueGrey.shade200,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(children: [
                  Checkbox(
                    value: _invoices.isNotEmpty && _selected.length == _invoices.length,
                    tristate: _selected.isNotEmpty && _selected.length < _invoices.length,
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _selected.addAll(_invoices.map((inv) => inv['id'] as int));
                      } else {
                        _selected.clear();
                      }
                    }),
                  ),
                  Expanded(flex: 2, child: Text(isEnglish ? 'Invoice No.' : 'เลขที่ใบแจ้งหนี้', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text(isEnglish ? 'Vendor' : 'ผู้ขาย', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  SizedBox(width: 90, child: Text(isEnglish ? 'Due Date' : 'วันที่ครบกำหนด', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  SizedBox(width: 110, child: Text(isEnglish ? 'Remaining' : 'ยอดค้างชำระ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                  SizedBox(width: 90, child: Text(l.status, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                ]),
              ),
              // Summary bar
              Container(
                color: Colors.blue.withOpacity(0.08),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(children: [
                  Text(
                      isEnglish
                          ? 'Selected ${_selected.length} item(s)  |  Total: ${_fmt.format(_totalSelected)}'
                          : 'เลือกแล้ว ${_selected.length} รายการ  |  ยอดรวม: ${_fmt.format(_totalSelected)} ${CurrencyService.baseCode}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.blue[800])),
                ]),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _invoices.isEmpty
                        ? Center(child: Text(
                            isEnglish ? 'No outstanding invoices found' : 'ไม่พบใบแจ้งหนี้ที่รอชำระ',
                            style: TextStyle(color: Colors.blueGrey.shade400)))
                        : ListView.builder(
                            itemCount: _invoices.length,
                            itemBuilder: (_, i) {
                              final inv = _invoices[i];
                              final id  = inv['id'] as int;
                              final sel = _selected.contains(id);
                              final dueDate = parseLocalDateNullable(inv['due_date']);
                              return Container(
                                color: sel ? Colors.blue.withOpacity(0.07) : (i.isEven ? Colors.grey.shade50 : Colors.white),
                                child: Row(children: [
                                  Checkbox(
                                    value: sel,
                                    onChanged: (v) => setState(() {
                                      if (v == true) _selected.add(id); else _selected.remove(id);
                                    }),
                                  ),
                                  Expanded(flex: 2, child: Text(inv['doc_no'] ?? '', style: const TextStyle(fontSize: 13))),
                                  Expanded(flex: 2, child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(inv['vendor_code'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      Text(_vendorLabel(inv), style: TextStyle(fontSize: 12, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
                                    ],
                                  )),
                                  SizedBox(width: 90, child: Text(dueDate != null ? _dateFmt.format(dueDate) : '',
                                      style: const TextStyle(fontSize: 12))),
                                  SizedBox(width: 110,
                                      child: Text(_fmt.format((inv['remaining_amount'] as num?)?.toDouble() ?? 0),
                                          style: const TextStyle(fontSize: 13), textAlign: TextAlign.right)),
                                  SizedBox(
                                    width: 90,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.green),
                                        ),
                                        child: Text(l.posted, style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.green.shade700)),
                                      ),
                                    ),
                                  ),
                                ]),
                              );
                            },
                          ),
              ),
            ]),
                  _buildBatchList(isEnglish, l),
                ])),
              ]),
            ),
          ),
        ]);
      }),
    );
  }

  Widget _buildBatchList(bool isEnglish, AppL10n l) {
    const hdr = TextStyle(fontSize: 12, fontWeight: FontWeight.bold);
    return Column(children: [
      Container(
        color: Colors.blueGrey.shade200,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Expanded(flex: 2, child: Text(isEnglish ? 'Batch No.' : 'เลขที่ชุด', style: hdr)),
          SizedBox(width: 90, child: Text(isEnglish ? 'Pay Date' : 'วันที่จ่าย', style: hdr)),
          Expanded(flex: 3, child: Text(isEnglish ? 'Bank Account' : 'บัญชีธนาคาร', style: hdr)),
          SizedBox(width: 60, child: Text(isEnglish ? 'Items' : 'รายการ', style: hdr, textAlign: TextAlign.right)),
          SizedBox(width: 120, child: Text(isEnglish ? 'Total' : 'ยอดรวม', style: hdr, textAlign: TextAlign.right)),
          SizedBox(width: 110, child: Text(l.status, style: hdr, textAlign: TextAlign.center)),
        ]),
      ),
      Expanded(
        child: _loadingBatches
            ? const Center(child: CircularProgressIndicator())
            : _batches.isEmpty
                ? Center(child: Text(isEnglish ? 'No payment batches' : 'ยังไม่มีชุดจ่ายแบบกลุ่ม',
                    style: TextStyle(color: Colors.blueGrey.shade400)))
                : ListView.builder(
                    itemCount: _batches.length,
                    itemBuilder: (_, i) {
                      final b = _batches[i];
                      final date = parseLocalDateNullable(b['payment_date']);
                      final bankName = isEnglish && (b['bank_account_name_en'] ?? '').toString().isNotEmpty
                          ? b['bank_account_name_en'] : (b['bank_account_name_th'] ?? '');
                      return InkWell(
                        onTap: () => _openBatch(b['id'] as int),
                        child: Container(
                          color: i.isEven ? Colors.grey.shade50 : Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(children: [
                            Expanded(flex: 2, child: Text(b['batch_no'] ?? '', style: const TextStyle(fontSize: 13))),
                            SizedBox(width: 90, child: Text(date != null ? _dateFmt.format(date) : '', style: const TextStyle(fontSize: 12))),
                            Expanded(flex: 3, child: Text('${b['bank_account_code'] ?? ''} $bankName',
                                style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                            SizedBox(width: 60, child: Text('${b['item_count'] ?? 0}', style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
                            SizedBox(width: 120, child: Text(_fmt.format((b['total_amount_lc'] as num?)?.toDouble() ?? 0),
                                style: const TextStyle(fontSize: 13), textAlign: TextAlign.right)),
                            SizedBox(width: 110, child: Center(child: _batchStatusChip(b['status'] ?? '', isEnglish))),
                          ]),
                        ),
                      );
                    },
                  ),
      ),
    ]);
  }

  Widget _field(String label, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      const SizedBox(height: 4),
      child,
    ],
  );

  Widget _datePicker(DateTime? value, void Function(DateTime) onPick) =>
      InkWell(
        onTap: () async {
          final d = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (d != null) onPick(d);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Expanded(
              child: Text(value != null ? _dateFmt.format(value) : (_isEnglish ? 'Select date' : 'เลือกวันที่'),
                  style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(width: 6),
            Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
          ]),
        ),
      );
}

Widget _batchStatusChip(String status, bool isEnglish) {
  final (MaterialColor color, String th, String en) = switch (status) {
    'Draft' => (Colors.grey, 'ร่าง', 'Draft'),
    'Submitted' => (Colors.orange, 'รออนุมัติ', 'Submitted'),
    'Approved' => (Colors.blue, 'อนุมัติแล้ว', 'Approved'),
    'Paid' => (Colors.green, 'จ่ายแล้ว', 'Paid'),
    _ => (Colors.blueGrey, status, status),
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color),
    ),
    child: Text(isEnglish ? en : th, style: TextStyle(fontSize: 11, color: color.shade700)),
  );
}

// รายละเอียดชุดจ่ายแบบกลุ่ม + ขั้นตอนอนุมัติ + ปุ่มตามสถานะ
// Draft: ส่งขออนุมัติ / ลบ — Submitted: อนุมัติ/ปฏิเสธ (DocApprovalPanel) / ถอยเป็นร่าง — Approved: จ่าย / ถอยเป็นร่าง
class _BulkBatchDialog extends StatefulWidget {
  final int batchId;
  final VoidCallback onChanged;
  const _BulkBatchDialog({required this.batchId, required this.onChanged});

  @override
  State<_BulkBatchDialog> createState() => _BulkBatchDialogState();
}

class _BulkBatchDialogState extends State<_BulkBatchDialog> {
  Map<String, dynamic>? _b;
  bool _busy = false;

  String get _base => '${AppConfig.apiAp}/ap_bulk_payment/batches/${widget.batchId}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<Map<String, String>> _headers() async =>
      {...await AuthService().getAuthHeader(), 'Content-Type': 'application/json'};

  String _errMsg(String body) {
    try {
      final m = json.decode(body) as Map<String, dynamic>;
      return (m['message'] ?? m['error'] ?? body).toString();
    } catch (_) { return body; }
  }

  Future<void> _load() async {
    final r = await http.get(Uri.parse(_base), headers: await _headers());
    if (!mounted) return;
    if (r.statusCode == 200) setState(() => _b = json.decode(r.body) as Map<String, dynamic>);
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700));
  }

  // เรียก endpoint ของชุดนี้ — โยน Exception(ข้อความ backend) เมื่อไม่สำเร็จ
  Future<void> _send(String method, String path, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse(path.isEmpty ? _base : '$_base/$path');
    final h = await _headers();
    final payload = json.encode(body ?? {});
    final r = switch (method) {
      'DELETE' => await http.delete(uri, headers: h, body: payload),
      _ => await http.put(uri, headers: h, body: payload),
    };
    if (r.statusCode != 200) throw Exception(_errMsg(r.body));
  }

  Future<void> _run(Future<void> Function() action, String okMsg) async {
    setState(() => _busy = true);
    try {
      await action();
      _snack(okMsg);
      widget.onChanged();
      await _load();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String content, AppL10n l) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.confirm)),
          ],
        ),
      ) ==
      true;

  Future<void> _submit(bool isEnglish) async {
    final menuId = MenuScope.of(context)?.id;
    if (!await _confirm(isEnglish ? 'Submit for Approval' : 'ส่งขออนุมัติ',
        isEnglish ? 'Submit ${_b!['batch_no']} for approval?' : 'ส่งขออนุมัติชุด ${_b!['batch_no']}?', AppL10n(isEnglish))) {
      return;
    }
    await _run(() => _send('PUT', 'submit', {'menu_id': menuId}), isEnglish ? 'Submitted for approval' : 'ส่งขออนุมัติแล้ว');
  }

  Future<void> _delete(bool isEnglish) async {
    if (!await _confirm(isEnglish ? 'Delete Batch' : 'ลบชุดจ่าย',
        isEnglish
            ? 'Delete ${_b!['batch_no']}? Its invoices become available again.'
            : 'ลบชุด ${_b!['batch_no']}? ใบแจ้งหนี้ในชุดจะกลับไปเลือกจ่ายได้อีก',
        AppL10n(isEnglish))) {
      return;
    }
    await _run(() => _send('DELETE', ''), isEnglish ? 'Deleted' : 'ลบแล้ว');
  }

  Future<void> _reverse(bool isEnglish) async {
    final l = AppL10n(isEnglish);
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEnglish ? 'Reverse to Draft' : 'ถอยเป็นร่าง'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isEnglish
              ? 'Pending approvals are skipped; the batch must be submitted again.'
              : 'ผู้อนุมัติที่ยังไม่ตัดสินจะถูกข้าม ต้องส่งขออนุมัติใหม่'),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(
                labelText: isEnglish ? 'Reason *' : 'เหตุผล *', border: const OutlineInputBorder(), isDense: true),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.confirm)),
        ],
      ),
    );
    final reason = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true) return;
    await _run(() => _send('PUT', 'reverse', {'reason': reason}), isEnglish ? 'Reversed to draft' : 'ถอยเป็นร่างแล้ว');
  }

  // จ่าย: แสดงรายการบัญชีที่จะเกิดก่อน แล้วยืนยัน
  Future<void> _pay(bool isEnglish) async {
    final payDate = parseLocalDateNullable(_b!['payment_date']);
    if (payDate != null && !await CmPeriodService.canPost(context, payDate)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    List<GlJournalLine> journal;
    try {
      final r = await http.post(Uri.parse('$_base/preview'), headers: await _headers());
      if (r.statusCode != 200) throw Exception(_errMsg(r.body));
      journal = GlJournalLine.listFromJson((json.decode(r.body) as Map<String, dynamic>)['journal']);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    final l = AppL10n(isEnglish);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEnglish ? 'Confirm Payment ${_b!['batch_no']}' : 'ยืนยันการจ่ายชุด ${_b!['batch_no']}'),
        content: SizedBox(
          width: (MediaQuery.of(context).size.width * 0.8).clamp(320.0, 900.0),
          child: SingleChildScrollView(
            child: GlJournalPreview(
              lines: journal, isEnglish: isEnglish,
              note: isEnglish
                  ? '* AP accounts from the vendor (or the AP payment GL setup), bank account from the selected bank; deferred VAT is recognized pro rata to the amount paid'
                  : '* บัญชีเจ้าหนี้จากผู้ขาย (หรือการตั้งค่าบัญชีของเอกสารจ่ายชำระ AP) บัญชีธนาคารจากบัญชีที่เลือก และรับรู้ VAT รอตัดบัญชีตามสัดส่วนที่จ่าย',
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isEnglish ? 'Pay' : 'จ่าย'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => _send('PUT', 'pay'), isEnglish ? 'Paid successfully' : 'จ่ายสำเร็จ');
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final l = AppL10n(isEnglish);
    final b = _b;
    final menu = MenuScope.of(context);
    final status = (b?['status'] ?? '').toString();
    final items = (b?['items'] as List? ?? []).cast<Map<String, dynamic>>();
    final payDate = parseLocalDateNullable(b?['payment_date']);
    const hdr = TextStyle(fontSize: 12, fontWeight: FontWeight.bold);
    String bankName() => isEnglish && (b?['bank_account_name_en'] ?? '').toString().isNotEmpty
        ? b!['bank_account_name_en'] : (b?['bank_account_name_th'] ?? '');

    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      title: Container(
        color: Colors.blue[700],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Expanded(
            child: Text('${isEnglish ? 'Payment Batch' : 'ชุดจ่ายแบบกลุ่ม'} ${b?['batch_no'] ?? ''}',
                style: const TextStyle(color: Colors.white, fontSize: 16)),
          ),
          if (b != null) _batchStatusChip(status, isEnglish),
        ]),
      ),
      content: SizedBox(
        width: (MediaQuery.of(context).size.width * 0.8).clamp(320.0, 900.0),
        child: b == null
            ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 24, runSpacing: 4, children: [
                    Text('${isEnglish ? 'Pay date' : 'วันที่จ่าย'}: ${payDate != null ? _dateFmt.format(payDate) : ''}'),
                    Text('${isEnglish ? 'Bank' : 'บัญชีธนาคาร'}: ${b['bank_account_code'] ?? ''} ${bankName()}'),
                    Text('${isEnglish ? 'Total' : 'ยอดรวม'}: ${_fmt.format((b['total_amount_lc'] as num?)?.toDouble() ?? 0)} ${CurrencyService.baseCode}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if ((b['gl_doc_no'] ?? '').toString().isNotEmpty)
                      Text('${isEnglish ? 'GL doc' : 'เลขที่ GL'}: ${b['gl_doc_no']}'),
                  ]),
                  DocApprovalPanel(
                    docNo: b['batch_no'] ?? '',
                    approvals: DocApprovalStep.listFromJson(b['approvals']),
                    approvalMode: b['approval_mode'],
                    awaiting: status == 'Submitted',
                    onApprove: (r) => _send('PUT', 'approve', {'remarks': r}),
                    onReject: (r) => _send('PUT', 'reject', {'remarks': r}),
                    onDone: () async { widget.onChanged(); await _load(); },
                  ),
                  const SizedBox(height: 8),
                  Container(
                    color: Colors.blueGrey.shade100,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(children: [
                      Expanded(flex: 2, child: Text(isEnglish ? 'Invoice No.' : 'เลขที่ใบแจ้งหนี้', style: hdr)),
                      Expanded(flex: 3, child: Text(isEnglish ? 'Vendor' : 'ผู้ขาย', style: hdr)),
                      SizedBox(width: 90, child: Text(isEnglish ? 'Due Date' : 'ครบกำหนด', style: hdr)),
                      SizedBox(width: 110, child: Text(isEnglish ? 'Amount' : 'ยอดจ่าย', style: hdr, textAlign: TextAlign.right)),
                    ]),
                  ),
                  ...items.map((it) {
                    final due = parseLocalDateNullable(it['due_date']);
                    final vName = isEnglish && (it['vendor_name_en'] ?? '').toString().isNotEmpty
                        ? it['vendor_name_en'] : (it['vendor_name_th'] ?? '');
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(children: [
                        Expanded(flex: 2, child: Text(it['doc_no'] ?? '', style: const TextStyle(fontSize: 13))),
                        Expanded(flex: 3, child: Text('${it['vendor_code'] ?? ''} $vName',
                            style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                        SizedBox(width: 90, child: Text(due != null ? _dateFmt.format(due) : '', style: const TextStyle(fontSize: 12))),
                        SizedBox(width: 110, child: Text(_fmt.format((it['amount_lc'] as num?)?.toDouble() ?? 0),
                            style: const TextStyle(fontSize: 13), textAlign: TextAlign.right)),
                      ]),
                    );
                  }),
                ]),
              ),
      ),
      actions: [
        if (_busy) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        if (!_busy && b != null) ...[
          if (status == 'Draft' && (menu?.canDelete ?? true))
            TextButton.icon(
              onPressed: () => _delete(isEnglish),
              icon: const Icon(Icons.delete_outline, size: 16),
              label: Text(l.delete),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          if ((status == 'Submitted' || status == 'Approved') && (menu?.canDelete ?? true))
            TextButton.icon(
              onPressed: () => _reverse(isEnglish),
              icon: const Icon(Icons.undo, size: 16),
              label: Text(isEnglish ? 'Reverse to Draft' : 'ถอยเป็นร่าง'),
              style: TextButton.styleFrom(foregroundColor: Colors.orange[800]),
            ),
          if (status == 'Draft' && (menu?.canCreate ?? true))
            OutlinedButton.icon(
              onPressed: () => _submit(isEnglish),
              icon: const Icon(Icons.how_to_reg_outlined, size: 16),
              label: Text(isEnglish ? 'Request Approval' : 'ขออนุมัติ'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.orange[800]),
            ),
          if (status == 'Approved' && (menu?.canCreate ?? true))
            ElevatedButton.icon(
              onPressed: () => _pay(isEnglish),
              icon: const Icon(Icons.payments, size: 16),
              label: Text(isEnglish ? 'Pay' : 'จ่าย'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
            ),
        ],
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.close)),
      ],
    );
  }
}
