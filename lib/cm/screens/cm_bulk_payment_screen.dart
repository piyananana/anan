// lib/cm/screens/cm_bulk_payment_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../config/app_config.dart';
import '../../sa/services/auth_service.dart';
import '../../sa/utils/menu_scope.dart';
import '../services/cm_period_service.dart';

const _kTheme  = Color(0xFF1565C0);
final _fmt     = NumberFormat('#,##0.00', 'en_US');
final _dateFmt = DateFormat('dd/MM/yyyy');

class CmBulkPaymentScreen extends StatefulWidget {
  const CmBulkPaymentScreen({super.key});
  @override
  State<CmBulkPaymentScreen> createState() => _CmBulkPaymentScreenState();
}

class _CmBulkPaymentScreenState extends State<CmBulkPaymentScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _panelOpen = true;

  // setup panel
  int?     _fBankAccId;
  DateTime _fPaymentDate = DateTime.now();
  String   _fPayMethod   = 'TRANSFER';
  int?     _fGlDocId;

  // filter
  String   _fVendorSearch = '';
  DateTime? _fDueDateTo;

  List<Map<String, dynamic>> _invoices    = [];
  List<Map<String, dynamic>> _bankAccounts = [];
  List<Map<String, dynamic>> _glDocTypes   = [];
  final Set<int> _selected = {};

  bool _loading  = false;
  bool _running  = false;

  final _vendorCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBankAccounts();
    _loadGlDocTypes();
    _loadInvoices();
  }

  @override
  void dispose() {
    _vendorCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _headers() async =>
      {...await AuthService().getAuthHeader(), 'Content-Type': 'application/json'};

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

  Future<void> _loadGlDocTypes() async {
    try {
      final h = await _headers();
      final r = await http.get(Uri.parse('${AppConfig.apiSa}/sa_module_document?is_active=true'), headers: h);
      if (r.statusCode == 200) {
        final d = json.decode(r.body) as List;
        setState(() => _glDocTypes = d.cast<Map<String, dynamic>>());
      }
    } catch (_) {}
  }

  Future<void> _loadInvoices() async {
    setState(() { _loading = true; _selected.clear(); });
    try {
      final h = await _headers();
      final params = <String, String>{};
      if (_fVendorSearch.isNotEmpty) params['vendor_search'] = _fVendorSearch;
      if (_fDueDateTo != null) params['due_date_to'] = DateFormat('yyyy-MM-dd').format(_fDueDateTo!);
      final uri = Uri.parse('${AppConfig.apiCm}/cm_bulk_payment/eligible')
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
    if (_fBankAccId == null) { _showErr('กรุณาเลือกบัญชีธนาคาร'); return; }
    if (_selected.isEmpty) { _showErr('กรุณาเลือกใบแจ้งหนี้อย่างน้อย 1 รายการ'); return; }
    if (!await CmPeriodService.canPost(context, _fPaymentDate)) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยัน Bulk Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('จำนวนรายการ: ${_selected.length} ใบ'),
            Text('ยอดรวม: ${_fmt.format(_totalSelected)} บาท'),
            Text('วันที่ชำระ: ${_dateFmt.format(_fPaymentDate)}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน'),
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
        'bank_account_id':   _fBankAccId,
        'payment_date':      DateFormat('yyyy-MM-dd').format(_fPaymentDate),
        'payment_method':    _fPayMethod,
        'gl_doc_type_id':    _fGlDocId,
        'items':             items,
      });
      final r = await http.post(
          Uri.parse('${AppConfig.apiCm}/cm_bulk_payment/run'), headers: h, body: body);
      if (r.statusCode == 200 || r.statusCode == 201) {
        final result = json.decode(r.body) as Map<String, dynamic>;
        final count = result['created_count'] ?? items.length;
        _showOk('สร้างรายการชำระ $count รายการสำเร็จ');
        await _loadInvoices();
      } else {
        _showErr('เกิดข้อผิดพลาด: ${r.body}');
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kTheme,
        foregroundColor: Colors.white,
        toolbarHeight: 40,
        title: const MenuTitle(),
        actions: [
          if (_selected.isNotEmpty)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: _running ? null : _runBulkPayment,
              icon: _running
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.payments, size: 16),
              label: Text('ชำระ ${_selected.length} รายการ | ${_fmt.format(_totalSelected)} บาท',
                  style: const TextStyle(fontSize: 13)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toggle strip
          Container(
            width: 36,
            color: _kTheme,
            child: Column(children: [
              IconButton(
                padding: EdgeInsets.zero,
                iconSize: 20,
                color: Colors.white,
                icon: Icon(_panelOpen ? Icons.chevron_left : Icons.chevron_right),
                onPressed: () => setState(() => _panelOpen = !_panelOpen),
              ),
            ]),
          ),
          // Left panel – setup
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _panelOpen ? 280 : 0,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                maxWidth: 280,
                child: SizedBox(
                  width: 280,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        color: Colors.blueGrey.shade200,
                        padding: const EdgeInsets.all(8),
                        child: Text('ตั้งค่าการชำระเงิน',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                                color: Colors.blueGrey.shade800)),
                      ),
                      Expanded(
                        child: Container(
                          color: Colors.blueGrey.shade100,
                          padding: const EdgeInsets.all(10),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _field('บัญชีธนาคาร *', DropdownButtonFormField<int?>(
                                  value: _fBankAccId,
                                  isDense: true,
                                  decoration: const InputDecoration(border: OutlineInputBorder(),
                                      filled: true, fillColor: Colors.white,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                                  hint: const Text('เลือกบัญชี', style: TextStyle(fontSize: 11)),
                                  items: _bankAccounts.map((b) => DropdownMenuItem<int?>(
                                      value: b['id'] as int?,
                                      child: Text('${b['account_code'] ?? ''} ${b['account_name'] ?? ''}',
                                          style: const TextStyle(fontSize: 11),
                                          overflow: TextOverflow.ellipsis))).toList(),
                                  onChanged: (v) => setState(() => _fBankAccId = v),
                                )),
                                const SizedBox(height: 8),
                                _field('วันที่ชำระ *', _datePicker(_fPaymentDate, (d) => setState(() => _fPaymentDate = d))),
                                const SizedBox(height: 8),
                                _field('วิธีชำระ', DropdownButtonFormField<String>(
                                  value: _fPayMethod,
                                  isDense: true,
                                  decoration: const InputDecoration(border: OutlineInputBorder(),
                                      filled: true, fillColor: Colors.white,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                                  items: const [
                                    DropdownMenuItem(value: 'TRANSFER', child: Text('โอนเงิน', style: TextStyle(fontSize: 11))),
                                    DropdownMenuItem(value: 'CHECK',    child: Text('เช็ค', style: TextStyle(fontSize: 11))),
                                    DropdownMenuItem(value: 'CASH',     child: Text('เงินสด', style: TextStyle(fontSize: 11))),
                                  ],
                                  onChanged: (v) => setState(() => _fPayMethod = v ?? 'TRANSFER'),
                                )),
                                const SizedBox(height: 8),
                                _field('GL Doc Type', DropdownButtonFormField<int?>(
                                  value: _fGlDocId,
                                  isDense: true,
                                  decoration: const InputDecoration(border: OutlineInputBorder(),
                                      filled: true, fillColor: Colors.white,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                                  hint: const Text('เลือก Doc Type', style: TextStyle(fontSize: 11)),
                                  items: _glDocTypes.map((d) => DropdownMenuItem<int?>(
                                      value: d['id'] as int?,
                                      child: Text('${d['doc_code'] ?? ''} ${d['doc_name'] ?? ''}',
                                          style: const TextStyle(fontSize: 11)))).toList(),
                                  onChanged: (v) => setState(() => _fGlDocId = v),
                                )),
                                const Divider(height: 20),
                                Text('กรองใบแจ้งหนี้',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade700)),
                                const SizedBox(height: 6),
                                _field('ค้นหาผู้ขาย', TextField(
                                  controller: _vendorCtrl,
                                  decoration: const InputDecoration(
                                      isDense: true, border: OutlineInputBorder(),
                                      filled: true, fillColor: Colors.white,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      hintText: 'รหัส / ชื่อ'),
                                  style: const TextStyle(fontSize: 11),
                                  onChanged: (v) => setState(() => _fVendorSearch = v),
                                  onSubmitted: (_) => _loadInvoices(),
                                )),
                                const SizedBox(height: 8),
                                _field('ครบกำหนดถึง', _datePicker(_fDueDateTo, (d) { setState(() => _fDueDateTo = d); _loadInvoices(); })),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(double.infinity, 32),
                                      padding: const EdgeInsets.symmetric(vertical: 6)),
                                  onPressed: _loadInvoices,
                                  icon: const Icon(Icons.search, size: 14),
                                  label: const Text('ค้นหา', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Right panel – invoice list
          Expanded(
            child: Column(children: [
              // Column headers
              Container(
                color: Colors.blueGrey.shade200,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                  const Expanded(flex: 2, child: Text('เลขที่ใบแจ้งหนี้', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  const Expanded(flex: 2, child: Text('ผู้ขาย', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 90, child: Text('วันที่ครบกำหนด', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 100, child: Text('ยอดค้างชำระ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                  const SizedBox(width: 80, child: Text('สถานะ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                ]),
              ),
              // Summary bar
              Container(
                color: _kTheme.withOpacity(0.08),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(children: [
                  Text('เลือกแล้ว ${_selected.length} รายการ  |  ยอดรวม: ${_fmt.format(_totalSelected)} บาท',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _kTheme)),
                ]),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _invoices.isEmpty
                        ? Center(child: Text('ไม่พบใบแจ้งหนี้ที่รอชำระ', style: TextStyle(color: Colors.blueGrey.shade400)))
                        : ListView.builder(
                            itemCount: _invoices.length,
                            itemBuilder: (_, i) {
                              final inv = _invoices[i];
                              final id  = inv['id'] as int;
                              final sel = _selected.contains(id);
                              DateTime? dueDate;
                              try { dueDate = DateTime.parse(inv['due_date'].toString()); } catch (_) {}
                              final status = inv['status'] as String? ?? '';
                              return Container(
                                color: sel ? _kTheme.withOpacity(0.07) : (i.isEven ? Colors.grey.shade50 : Colors.white),
                                child: Row(children: [
                                  Checkbox(
                                    value: sel,
                                    onChanged: (v) => setState(() {
                                      if (v == true) _selected.add(id); else _selected.remove(id);
                                    }),
                                  ),
                                  Expanded(flex: 2, child: Text(inv['doc_no'] ?? '', style: const TextStyle(fontSize: 12))),
                                  Expanded(flex: 2, child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(inv['vendor_code'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      Text(inv['vendor_name_th'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
                                    ],
                                  )),
                                  SizedBox(width: 90, child: Text(dueDate != null ? _dateFmt.format(dueDate) : '',
                                      style: const TextStyle(fontSize: 11))),
                                  SizedBox(width: 100,
                                      child: Text(_fmt.format((inv['remaining_amount'] as num?)?.toDouble() ?? 0),
                                          style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
                                  SizedBox(
                                    width: 80,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (status == 'Approved' ? Colors.green : Colors.orange).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: status == 'Approved' ? Colors.green : Colors.orange),
                                        ),
                                        child: Text(status, style: TextStyle(
                                            fontSize: 9,
                                            color: status == 'Approved' ? Colors.green.shade700 : Colors.orange.shade700)),
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
        ],
      ),
    );
  }

  Widget _field(String label, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
      const SizedBox(height: 2),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(value != null ? _dateFmt.format(value) : 'เลือกวันที่',
                style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 6),
            Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
          ]),
        ),
      );
}
