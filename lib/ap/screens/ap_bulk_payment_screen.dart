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

  final _vendorCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBankAccounts();
    _loadInvoices();
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

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEnglish ? 'Confirm Bulk Payment' : 'ยืนยัน Bulk Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEnglish
                ? 'Number of invoices: ${_selected.length}'
                : 'จำนวนรายการ: ${_selected.length} ใบ'),
            Text(isEnglish
                ? 'Total amount: ${_fmt.format(_totalSelected)} THB'
                : 'ยอดรวม: ${_fmt.format(_totalSelected)} บาท'),
            Text(isEnglish
                ? 'Payment date: ${_dateFmt.format(_fPaymentDate)}'
                : 'วันที่ชำระ: ${_dateFmt.format(_fPaymentDate)}'),
          ],
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

    setState(() => _running = true);
    try {
      final h = await _headers();
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
      final r = await http.post(
          Uri.parse('${AppConfig.apiAp}/ap_bulk_payment/run'), headers: h, body: body);
      if (r.statusCode == 200 || r.statusCode == 201) {
        final result = json.decode(r.body) as Map<String, dynamic>;
        final count = result['created_count'] ?? items.length;
        _showOk(isEnglish
            ? 'Created $count payment(s) successfully'
            : 'สร้างรายการชำระ $count รายการสำเร็จ');
        await _loadInvoices();
      } else {
        _showErr(isEnglish ? 'Error: ${r.body}' : 'เกิดข้อผิดพลาด: ${r.body}');
      }
    } catch (e) { _showErr('$e'); }
    finally { if (mounted) setState(() => _running = false); }
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
          IconButton(icon: const Icon(Icons.refresh), tooltip: l.refresh, onPressed: _loadInvoices),
          const SizedBox(width: 4),
          if (_selected.isNotEmpty)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: _running ? null : _runBulkPayment,
              icon: _running
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.payments, size: 16),
              label: Text(
                  isEnglish
                      ? 'Pay ${_selected.length} item(s) | ${_fmt.format(_totalSelected)}'
                      : 'ชำระ ${_selected.length} รายการ | ${_fmt.format(_totalSelected)} บาท',
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
          // Right panel – invoice list
          Expanded(
            child: Column(children: [
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
                          : 'เลือกแล้ว ${_selected.length} รายการ  |  ยอดรวม: ${_fmt.format(_totalSelected)} บาท',
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
          ),
        ]);
      }),
    );
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
