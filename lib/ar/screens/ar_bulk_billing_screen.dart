import 'dart:math' show max;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import 'package:provider/provider.dart';
import '../models/ar_customer.dart';
import '../models/ar_customer_group.dart';
import '../models/ar_collector.dart';
import '../services/ar_billing_plan_report_service.dart';
import '../services/ar_bulk_billing_service.dart';
import '../services/ar_customer_service.dart';
import '../services/ar_customer_group_service.dart';
import '../services/ar_collector_service.dart';
import '../widgets/ar_customer_group_multi_picker.dart';

// ─── Column widths (all fixed — no Expanded in horizontal scroll) ─────────────
const double _wCB    = 40.0;   // checkbox
const double _wDate  = 92.0;   // all date columns
const double _wType  = 110.0;  // doc type
const double _wDocNo = 120.0;  // doc no
const double _wCust  = 215.0;  // customer code+name
const double _wAmt   = 110.0;  // amount columns (total / balance)
const double _wEdit  = 130.0;  // editable billing amount
const double _wRef   =  80.0;  // reference

// Total min width of all columns combined
const double _totalTableWidth =
    _wCB + _wDate * 4 + _wType + _wDocNo + _wCust + _wAmt * 2 + _wEdit + _wRef;

// ─── Data model ───────────────────────────────────────────────────────────────
class _InvoiceRow {
  final int    txnId;
  final int    customerId;
  final String billingDate;
  final String docNameThai;
  final String docNo;
  final String docDate;
  final String dueDate;
  final String expectedPaymentDate;
  final String customerCode;
  final String customerNameTh;
  final double totalAmount;
  final double balance;
  final String refNo;
  bool selected;
  final TextEditingController amountCtrl;

  _InvoiceRow({
    required this.txnId,
    required this.customerId,
    required this.billingDate,
    required this.docNameThai,
    required this.docNo,
    required this.docDate,
    required this.dueDate,
    required this.expectedPaymentDate,
    required this.customerCode,
    required this.customerNameTh,
    required this.totalAmount,
    required this.balance,
    required this.refNo,
    this.selected = true,
    required this.amountCtrl,
  });

  double get billingAmount =>
      double.tryParse(amountCtrl.text.replaceAll(',', '')) ?? 0;

  void dispose() => amountCtrl.dispose();
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class ArBulkBillingScreen extends StatefulWidget {
  const ArBulkBillingScreen({super.key});

  @override
  State<ArBulkBillingScreen> createState() => _ArBulkBillingScreenState();
}

class _ArBulkBillingScreenState extends State<ArBulkBillingScreen> {
  final _planService     = ArBillingPlanReportService();
  final _bulkService     = ArBulkBillingService();
  final _groupService    = ArCustomerGroupService();
  final _collectorService = ArCollectorService();

  bool _isLoading   = false;
  bool _isCreating  = false;
  bool _isFilterExpanded = true;
  bool _isEnglish = false;
  double _filterPanelWidth = 310.0;
  bool _isDraggingDivider = false;

  // Master data
  List<ArCustomerGroup>     _customerGroups = [];
  List<ArCollector>         _collectors     = [];
  List<Map<String, dynamic>> _bcDocTypes    = [];

  // Filters
  DateTime _dateFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _dateTo   = DateTime.now();
  List<int> _selectedGroupIds = [];
  int?    _selectedCollectorId;
  String? _customerCodeFrom;
  String? _customerCodeTo;
  String  _fromLabel = '';
  String  _toLabel   = '';

  // BC document
  int?     _selectedBcDocId;
  DateTime _bcDocDate = DateTime.now();

  // Table rows
  List<_InvoiceRow> _rows = [];

  final _fmt     = NumberFormat('#,##0.00', 'en_US');
  final _hScroll = ScrollController();
  final _vScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMasterData();
  }

  @override
  void dispose() {
    for (final r in _rows) { r.dispose(); }
    _hScroll.dispose();
    _vScroll.dispose();
    super.dispose();
  }

  // ─── master data ────────────────────────────────────────────────────────────

  Future<void> _loadMasterData() async {
    final results = await Future.wait([
      _groupService.fetchActiveRows(),
      _collectorService.fetchRows(),
      _bulkService.getBcDocTypes(),
    ]);
    if (mounted) {
      setState(() {
        _customerGroups = results[0] as List<ArCustomerGroup>;
        _collectors     = (results[1] as List<ArCollector>)
            .where((c) => c.isActive).toList();
        _bcDocTypes     = results[2] as List<Map<String, dynamic>>;
        if (_bcDocTypes.isNotEmpty) {
          _selectedBcDocId = _bcDocTypes.first['id'] as int?;
        }
      });
    }
  }

  // ─── load invoice data ───────────────────────────────────────────────────────

  Future<void> _loadData() async {
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    setState(() { _isLoading = true; });
    for (final r in _rows) { r.dispose(); }

    try {
      final raw = await _planService.getBillingPlanReport(
        dateFrom:           DateFormat('yyyy-MM-dd').format(_dateFrom),
        dateTo:             DateFormat('yyyy-MM-dd').format(_dateTo),
        customerGroupIds:   _selectedGroupIds,
        billingCollectorId: _selectedCollectorId,
        customerCodeFrom:   _customerCodeFrom,
        customerCodeTo:     _customerCodeTo,
      );

      final rows = <_InvoiceRow>[];
      for (final collector in raw) {
        for (final inv in (collector['invoices'] as List? ?? [])) {
          final bal   = (inv['balance_amount_lc'] as num?)?.toDouble() ?? 0;
          final total = (inv['total_amount_lc']   as num?)?.toDouble() ?? 0;
          rows.add(_InvoiceRow(
            txnId:               inv['txn_id']      as int?    ?? 0,
            customerId:          inv['customer_id'] as int?    ?? 0,
            billingDate:         inv['billing_date']           as String? ?? '',
            docNameThai:         inv['doc_name_thai']          as String? ?? '',
            docNo:               inv['doc_no']                 as String? ?? '',
            docDate:             inv['doc_date']               as String? ?? '',
            dueDate:             inv['due_date']               as String? ?? '',
            expectedPaymentDate: inv['expected_payment_date']  as String? ?? '',
            customerCode:        inv['customer_code']          as String? ?? '',
            customerNameTh:      inv['customer_name_th']       as String? ?? '',
            totalAmount:         total,
            balance:             bal,
            refNo:               inv['ref_no']                 as String? ?? '',
            amountCtrl: TextEditingController(text: _fmt.format(bal)),
          ));
        }
      }

      if (rows.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l.isEnglish
                ? 'No invoices due for billing in the selected period'
                : 'ไม่พบใบแจ้งหนี้ที่มีกำหนดวางบิลในช่วงที่เลือก')));
      }
      setState(() => _rows = rows);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── helpers ────────────────────────────────────────────────────────────────

  // ใช้ toLocal() เหมือน parseLocalDate ใน date_utils.dart — ป้องกัน off-by-one
  String _fmtD(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final local = DateTime.parse(raw).toLocal();
      return DateFormat('dd/MM/yyyy')
          .format(DateTime(local.year, local.month, local.day));
    } catch (_) { return raw; }
  }

  List<_InvoiceRow> get _selectedRows =>
      _rows.where((r) => r.selected && r.billingAmount > 0).toList();

  Map<int, List<_InvoiceRow>> get _selectedByCustomer {
    final map = <int, List<_InvoiceRow>>{};
    for (final r in _selectedRows) {
      map.putIfAbsent(r.customerId, () => []).add(r);
    }
    return map;
  }

  bool get _allSelected  => _rows.isNotEmpty && _rows.every((r) => r.selected);
  bool get _someSelected => _rows.any((r) => r.selected);
  double get _selectedTotal =>
      _selectedRows.fold(0, (s, r) => s + r.billingAmount);

  void _toggleAll(bool? v) {
    setState(() {
      for (final r in _rows) { r.selected = v ?? false; }
    });
  }

  // ─── create bulk BC ──────────────────────────────────────────────────────────

  Future<void> _createBulkBilling() async {
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    if (_selectedBcDocId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.isEnglish
              ? 'Please select a billing document type'
              : 'กรุณาเลือกประเภทเอกสารวางบิล')));
      return;
    }
    final byCustomer = _selectedByCustomer;
    if (byCustomer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.isEnglish
              ? 'Please select items to bill first'
              : 'กรุณาเลือกรายการที่ต้องการวางบิลก่อน')));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.isEnglish
            ? 'Confirm Billing Document Creation'
            : 'ยืนยันการสร้างใบวางบิล'),
        content: Text(l.isEnglish
            ? 'Will create ${byCustomer.length} billing document(s)\n'
                'Total ${_selectedRows.length} invoice(s)\n'
                'Total amount ${_fmt.format(_selectedTotal)} THB\n'
                'Document date: ${DateFormat('dd/MM/yyyy').format(_bcDocDate)}\n\n'
                'Do you want to proceed?'
            : 'จะสร้างใบวางบิล ${byCustomer.length} ใบ\n'
                'รวม ${_selectedRows.length} ใบแจ้งหนี้\n'
                'ยอดรวม ${_fmt.format(_selectedTotal)} บาท\n'
                'วันที่เอกสาร: ${DateFormat('dd/MM/yyyy').format(_bcDocDate)}\n\n'
                'ต้องการดำเนินการหรือไม่?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.cancel)),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[800],
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.confirm)),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isCreating = true);
    try {
      final customerGroups = byCustomer.entries.map((e) {
        final rows = e.value;
        return {
          'customer_id':      e.key,
          'customer_code':    rows.first.customerCode,
          'customer_name_th': rows.first.customerNameTh,
          'invoices': rows.map((r) => {
            'txn_id': r.txnId,
            'amount': r.billingAmount,
          }).toList(),
        };
      }).toList();

      final result = await _bulkService.createBulkBilling(
        billingDate:    DateFormat('yyyy-MM-dd').format(_bcDocDate),
        bcDocId:        _selectedBcDocId!,
        customerGroups: customerGroups,
      );

      final createdList =
          (result['created'] as List? ?? []).cast<Map<String, dynamic>>();

      if (mounted) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Row(children: [
              Icon(Icons.check_circle, color: Colors.teal[700]),
              const SizedBox(width: 8),
              Text(l.isEnglish
                  ? 'Billing Documents Created Successfully'
                  : 'สร้างใบวางบิลสำเร็จ'),
            ]),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      l.isEnglish
                          ? 'Created ${createdList.length} document(s) in total:'
                          : 'สร้างเอกสารทั้งหมด ${createdList.length} ใบ:',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 340),
                    child: SingleChildScrollView(
                      child: Table(
                        columnWidths: const {
                          0: IntrinsicColumnWidth(),
                          1: FlexColumnWidth(),
                          2: IntrinsicColumnWidth(),
                        },
                        border: TableBorder.all(
                            color: Colors.grey, width: 0.4),
                        children: [
                          TableRow(
                            decoration:
                                BoxDecoration(color: Colors.teal[50]),
                            children: [
                              Padding(padding: const EdgeInsets.all(6),
                                  child: Text(l.docNo,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12))),
                              Padding(padding: const EdgeInsets.all(6),
                                  child: Text(l.isEnglish
                                          ? 'Customer Name'
                                          : 'ชื่อลูกหนี้',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12))),
                              Padding(padding: const EdgeInsets.all(6),
                                  child: Text(l.isEnglish
                                          ? 'Total Amount'
                                          : 'ยอดรวม',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12))),
                            ],
                          ),
                          ...createdList.map((c) => TableRow(children: [
                            Padding(padding: const EdgeInsets.all(6),
                                child: Text(c['doc_no'] as String? ?? '',
                                    style: const TextStyle(fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(6),
                                child: Text(
                                    '${c['customer_code'] ?? ''}  ${c['customer_name_th'] ?? ''}',
                                    style: const TextStyle(fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(6),
                                child: Text(
                                    _fmt.format(
                                        (c['total_amount'] as num?)
                                                ?.toDouble() ??
                                            0),
                                    style: const TextStyle(fontSize: 12),
                                    textAlign: TextAlign.right)),
                          ])),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[800],
                      foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  child: Text(l.close)),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
      // โหลดข้อมูลใหม่ตามเงื่อนไขเดิมเสมอ หลัง dialog ปิด
      if (mounted) await _loadData();
    }
  }

  // ─── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
    _isEnglish = l.isEnglish;
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final maxFilterWidth =
            (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // toggle
            Container(
              width: 36,
              color: Colors.teal[800],
              child: IconButton(
                icon: Icon(
                    _isFilterExpanded
                        ? Icons.filter_list_off
                        : Icons.filter_list,
                    color: Colors.white, size: 20),
                padding: EdgeInsets.zero,
                tooltip: _isFilterExpanded
                    ? (l.isEnglish ? 'Collapse filters' : 'ย่อเงื่อนไข')
                    : (l.isEnglish ? 'Expand filters' : 'ขยายเงื่อนไข'),
                onPressed: () =>
                    setState(() => _isFilterExpanded = !_isFilterExpanded),
              ),
            ),
            // filter panel
            AnimatedContainer(
              duration: _isDraggingDivider
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              width: _isFilterExpanded ? _filterPanelWidth : 0.0,
              child: ClipRect(
                child: OverflowBox(
                  maxWidth: _filterPanelWidth,
                  minWidth: _filterPanelWidth,
                  alignment: Alignment.topLeft,
                  child: Card(
                    margin: const EdgeInsets.all(8),
                    child: Column(children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding:
                              const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  l.isEnglish
                                      ? 'Data Loading Conditions'
                                      : 'เงื่อนไขการโหลดข้อมูล',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              const SizedBox(height: 16),

                              // วันที่วางบิล ตั้งแต่ - ถึง
                              _buildDateField(
                                  label: l.isEnglish
                                      ? 'Billing Date From'
                                      : 'วันที่วางบิล ตั้งแต่',
                                  date: _dateFrom,
                                  onPick: (d) =>
                                      setState(() => _dateFrom = d)),
                              const SizedBox(height: 12),
                              _buildDateField(
                                  label: l.isEnglish
                                      ? 'Billing Date To'
                                      : 'วันที่วางบิล ถึง',
                                  date: _dateTo,
                                  onPick: (d) =>
                                      setState(() => _dateTo = d)),

                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 12),

                              // กลุ่มลูกค้า
                              ArCustomerGroupMultiPicker(
                                groups: _customerGroups,
                                selectedIds: _selectedGroupIds,
                                onChanged: (v) =>
                                    setState(() => _selectedGroupIds = v),
                              ),
                              const SizedBox(height: 12),

                              // ผู้วางบิล
                              DropdownButtonFormField<int?>(
                                isExpanded: true,
                                value: _selectedCollectorId,
                                decoration: InputDecoration(
                                    labelText:
                                        l.isEnglish ? 'Biller' : 'ผู้วางบิล',
                                    border: const OutlineInputBorder(),
                                    isDense: true),
                                items: [
                                  DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text(l.isEnglish
                                          ? '— All —'
                                          : '— ทั้งหมด —')),
                                  ..._collectors.map((c) =>
                                      DropdownMenuItem<int?>(
                                        value: c.id,
                                        child: Text(
                                            '${c.collectorCode}  ${l.isEnglish && (c.collectorNameEng?.isNotEmpty ?? false) ? c.collectorNameEng! : c.collectorNameThai}',
                                            overflow:
                                                TextOverflow.ellipsis),
                                      )),
                                ],
                                onChanged: (v) =>
                                    setState(() => _selectedCollectorId = v),
                              ),
                              const SizedBox(height: 12),

                              // รหัสลูกค้า ตั้งแต่ / ถึง
                              _buildCustomerCodeField(
                                  label: l.isEnglish
                                      ? 'Customer Code From'
                                      : 'รหัสลูกค้า ตั้งแต่',
                                  displayText: _fromLabel,
                                  onPick: () => _pickCustomer(isFrom: true),
                                  onClear: () => setState(() {
                                    _customerCodeFrom = null;
                                    _fromLabel = '';
                                  })),
                              const SizedBox(height: 8),
                              _buildCustomerCodeField(
                                  label: l.isEnglish
                                      ? 'Customer Code To'
                                      : 'รหัสลูกค้า ถึง',
                                  displayText: _toLabel,
                                  onPick: () => _pickCustomer(isFrom: false),
                                  onClear: () => setState(() {
                                    _customerCodeTo = null;
                                    _toLabel = '';
                                  })),

                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 12),

                              Text(
                                  l.isEnglish
                                      ? 'Billing Document'
                                      : 'เอกสารวางบิล',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              const SizedBox(height: 10),

                              // ประเภทเอกสารวางบิล
                              DropdownButtonFormField<int?>(
                                isExpanded: true,
                                value: _selectedBcDocId,
                                decoration: InputDecoration(
                                    labelText: l.isEnglish
                                        ? 'Billing Document Type'
                                        : 'ประเภทเอกสารวางบิล',
                                    border: const OutlineInputBorder(),
                                    isDense: true),
                                items: _bcDocTypes.map((d) {
                                  final nameEng = d['doc_name_eng'] as String?;
                                  final name = l.isEnglish && (nameEng?.isNotEmpty ?? false)
                                      ? nameEng!
                                      : (d['doc_name_thai'] ?? '');
                                  return DropdownMenuItem<int?>(
                                      value: d['id'] as int?,
                                      child: Text(
                                          '${d['doc_code'] ?? ''}  $name',
                                          overflow:
                                              TextOverflow.ellipsis),
                                    );
                                }).toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedBcDocId = v),
                              ),
                              const SizedBox(height: 12),

                              // วันที่เอกสาร BC
                              _buildDateField(
                                  label: l.isEnglish
                                      ? 'Billing Document Date'
                                      : 'วันที่เอกสารวางบิล',
                                  date: _bcDocDate,
                                  onPick: (d) =>
                                      setState(() => _bcDocDate = d)),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: Text(
                                l.isEnglish ? 'Load Data' : 'โหลดข้อมูล'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal[800],
                                foregroundColor: Colors.white),
                            onPressed: _isLoading ? null : _loadData,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
            // draggable divider
            if (_isFilterExpanded)
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  onHorizontalDragStart: (_) =>
                      setState(() => _isDraggingDivider = true),
                  onHorizontalDragUpdate: (d) => setState(() {
                    _filterPanelWidth =
                        (_filterPanelWidth + d.delta.dx)
                            .clamp(200.0, maxFilterWidth);
                  }),
                  onHorizontalDragEnd: (_) =>
                      setState(() => _isDraggingDivider = false),
                  child:
                      Container(width: 5, color: Colors.grey[400]),
                ),
              ),
            // right panel
            Expanded(child: _buildRightPanel()),
          ],
        );
      }),
    );
  }

  // ─── right panel ─────────────────────────────────────────────────────────────

  Widget _buildRightPanel() {
    final byCustomer = _selectedByCustomer;
    final selTotal   = _selectedTotal;
    final selCount   = _selectedRows.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // toolbar: select-all + summary
        Container(
          color: Colors.grey[100],
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(children: [
            Checkbox(
              value: _rows.isEmpty
                  ? false
                  : (_allSelected
                      ? true
                      : (_someSelected ? null : false)),
              tristate: true,
              onChanged: _rows.isEmpty ? null : _toggleAll,
            ),
            Text(_isEnglish ? 'Select All' : 'เลือกทั้งหมด',
                style: const TextStyle(fontSize: 13)),
            const Spacer(),
            if (_rows.isNotEmpty)
              Text(
                _isEnglish
                    ? 'Selected $selCount item(s) | ${byCustomer.length} customer(s) | '
                        'Total ${_fmt.format(selTotal)}'
                    : 'เลือก $selCount รายการ | ${byCustomer.length} ลูกค้า | '
                        'รวม ${_fmt.format(selTotal)} บาท',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.teal[800],
                    fontWeight: FontWeight.w600),
              ),
          ]),
        ),
        const Divider(height: 1),
        // table — LayoutBuilder ให้ขนาดจริง
        // horizontal scroll (outer) + ListView vertical scroll (inner)
        // เพื่อให้ scroll ได้ทั้งซ้าย-ขวาและบน-ล่างอิสระจากกัน
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _rows.isEmpty
                  ? Center(
                      child: Text(
                        _isEnglish
                            ? 'Please set the conditions and press "Load Data"'
                            : 'กรุณากำหนดเงื่อนไขและกด "โหลดข้อมูล"',
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 14),
                      ),
                    )
                  : LayoutBuilder(builder: (ctx, constraints) {
                      final tableW =
                          max(constraints.maxWidth, _totalTableWidth);
                      return Scrollbar(
                        controller: _hScroll,
                        scrollbarOrientation:
                            ScrollbarOrientation.bottom,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _hScroll,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: tableW,
                            height: constraints.maxHeight,
                            child: Column(children: [
                              _buildHeader(),
                              const Divider(height: 1),
                              Expanded(
                                child: Scrollbar(
                                  controller: _vScroll,
                                  thumbVisibility: true,
                                  child: ListView.builder(
                                    controller: _vScroll,
                                    itemCount: _rows.length,
                                    itemBuilder: (_, i) =>
                                        _buildRow(i, _rows[i]),
                                  ),
                                ),
                              ),
                            ]),
                          ),
                        ),
                      );
                    }),
        ),
        // footer
        if (_rows.isNotEmpty)
          _buildFooter(byCustomer, selTotal, byCustomer.length),
      ],
    );
  }

  // ─── table header ─────────────────────────────────────────────────────────────

  static const _headerStyle = TextStyle(
      fontWeight: FontWeight.bold, fontSize: 12.5);

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFFDCEFE9),
      child: Row(children: [
        const SizedBox(width: _wCB),
        _hCell(_isEnglish ? 'Billing Date' : 'วันที่วางบิล',        _wDate),
        _hCell(_isEnglish ? 'Doc Type' : 'ประเภทเอกสาร',        _wType),
        _hCell(_isEnglish ? 'Doc No.' : 'เลขที่เอกสาร',        _wDocNo),
        _hCell(_isEnglish ? 'Invoice Date' : 'วันแจ้งหนี้',          _wDate),
        _hCell(_isEnglish ? 'Due Date' : 'วันครบกำหนด',         _wDate),
        _hCell(_isEnglish ? 'Expected Payment' : 'วันชำระ(คาดว่า)',      _wDate),
        _hCell(_isEnglish ? 'Code – Customer Name' : 'รหัส – ชื่อลูกหนี้',   _wCust),
        _hCell(_isEnglish ? 'Total' : 'ยอดรวม',              _wAmt,  right: true),
        _hCell(_isEnglish ? 'Balance' : 'ยอดคงค้าง',           _wAmt,  right: true),
        _hCell(_isEnglish ? 'Billing Amount' : 'ยอดที่จะวางบิล',      _wEdit, right: true),
        _hCell(_isEnglish ? 'Reference' : 'อ้างอิง',             _wRef),
      ]),
    );
  }

  Widget _hCell(String t, double w, {bool right = false}) => SizedBox(
    width: w,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: Text(t, style: _headerStyle,
          textAlign: right ? TextAlign.right : TextAlign.left),
    ),
  );

  // ─── table row ────────────────────────────────────────────────────────────────

  Widget _buildRow(int index, _InvoiceRow row) {
    final isOverAmount = row.billingAmount > row.balance + 0.001;
    return Container(
      color: index.isEven ? Colors.white : const Color(0xFFF7FAFA),
      child: Row(children: [
        // checkbox
        SizedBox(
          width: _wCB,
          child: Checkbox(
            value: row.selected,
            onChanged: (v) => setState(() => row.selected = v ?? false),
          ),
        ),
        _dCell(_fmtD(row.billingDate),         _wDate),
        _dCell(row.docNameThai,                 _wType),
        _dCell(row.docNo,                       _wDocNo),
        _dCell(_fmtD(row.docDate),              _wDate),
        _dCell(_fmtD(row.dueDate),              _wDate),
        _dCell(_fmtD(row.expectedPaymentDate),  _wDate),
        _dCell('${row.customerCode}  ${row.customerNameTh}', _wCust),
        _numCell(row.totalAmount,               _wAmt),
        _numCell(row.balance,                   _wAmt),
        // editable amount
        SizedBox(
          width: _wEdit,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: TextField(
              controller: row.amountCtrl,
              textAlign: TextAlign.right,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                  fontSize: 13,
                  color: isOverAmount ? Colors.red[700] : Colors.black87),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                errorText: isOverAmount
                    ? (_isEnglish ? 'Exceeds balance' : 'เกินยอดคงค้าง')
                    : null,
                errorStyle: const TextStyle(fontSize: 9, height: 1),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
        _dCell(row.refNo, _wRef, center: true),
      ]),
    );
  }

  Widget _dCell(String t, double w, {bool center = false}) => SizedBox(
    width: w,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Text(t,
          style: const TextStyle(fontSize: 13),
          textAlign: center ? TextAlign.center : TextAlign.left,
          overflow: TextOverflow.ellipsis),
    ),
  );

  Widget _numCell(double v, double w) => SizedBox(
    width: w,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Text(_fmt.format(v),
          style: const TextStyle(fontSize: 13),
          textAlign: TextAlign.right),
    ),
  );

  // ─── footer ───────────────────────────────────────────────────────────────────

  Widget _buildFooter(Map<int, List<_InvoiceRow>> byCustomer, double selTotal,
      int custCount) {
    final hasError =
        _selectedRows.any((r) => r.billingAmount > r.balance + 0.001);
    final noDocType = _selectedBcDocId == null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
          color: Colors.grey[50],
          border: Border(top: BorderSide(color: Colors.grey[300]!))),
      child: Row(children: [
        Expanded(
          child: Wrap(spacing: 20, runSpacing: 4, children: [
            _chip(Icons.people,
                _isEnglish ? '$custCount customer(s)' : '$custCount ลูกค้า',
                Colors.blue[700]!),
            _chip(Icons.description,
                _isEnglish
                    ? '${_selectedRows.length} doc(s)'
                    : '${_selectedRows.length} ใบ',
                Colors.orange[700]!),
            _chip(Icons.payments,     _fmt.format(selTotal),          Colors.teal[700]!),
            if (noDocType)
              _chip(
                  Icons.warning_amber,
                  _isEnglish
                      ? 'Document type not selected'
                      : 'ยังไม่ได้เลือกประเภทเอกสาร',
                  Colors.red[600]!),
          ]),
        ),
        SizedBox(
          height: 44,
          child: ElevatedButton.icon(
            icon: _isCreating
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.add_circle),
            label: Text(
                _isEnglish ? 'Create Billing Document' : 'สร้างใบวางบิล'),
            style: ElevatedButton.styleFrom(
                backgroundColor:
                    (hasError || noDocType || custCount == 0)
                        ? Colors.grey[400]
                        : Colors.teal[800],
                foregroundColor: Colors.white),
            onPressed:
                (_isCreating || hasError || noDocType || custCount == 0)
                    ? null
                    : _createBulkBilling,
          ),
        ),
      ]),
    );
  }

  Widget _chip(IconData icon, String label, Color color) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w600, fontSize: 13)),
      ]);

  // ─── filter helpers ──────────────────────────────────────────────────────────

  Widget _buildDateField({
    required String label,
    required DateTime date,
    required void Function(DateTime) onPick,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: const Icon(Icons.calendar_today, size: 16),
        ),
        child: Text(DateFormat('dd/MM/yyyy').format(date)),
      ),
    );
  }

  Future<void> _pickCustomer({required bool isFrom}) async {
    final result = await showDialog<ArCustomer>(
      context: context,
      builder: (_) => const _CustomerSearchDialog(),
    );
    if (result != null && mounted) {
      setState(() {
        final custName = _isEnglish &&
                (result.customerNameEn?.isNotEmpty ?? false)
            ? result.customerNameEn!
            : result.customerNameTh;
        final label = '${result.customerCode}  $custName';
        if (isFrom) {
          _customerCodeFrom = result.customerCode;
          _fromLabel        = label;
        } else {
          _customerCodeTo = result.customerCode;
          _toLabel        = label;
        }
      });
    }
  }

  Widget _buildCustomerCodeField({
    required String label,
    required String displayText,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    final hasValue = displayText.isNotEmpty;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
          if (hasValue)
            InkWell(
                onTap: onClear,
                child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.clear, size: 16, color: Colors.grey))),
          InkWell(
              onTap: onPick,
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.search,
                      size: 18, color: Colors.teal[800]))),
        ]),
      ),
      child: InkWell(
        onTap: onPick,
        child: Text(
          hasValue
              ? displayText
              : (_isEnglish ? '— All —' : '— ทั้งหมด —'),
          style: TextStyle(
              fontSize: 13,
              color: hasValue ? Colors.black87 : Colors.black38),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ─── Customer search dialog ────────────────────────────────────────────────────

class _CustomerSearchDialog extends StatefulWidget {
  const _CustomerSearchDialog();

  @override
  State<_CustomerSearchDialog> createState() =>
      _CustomerSearchDialogState();
}

class _CustomerSearchDialogState extends State<_CustomerSearchDialog> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();
  final _svc    = ArCustomerService();
  List<ArCustomer> _list = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final list = await _svc.fetchRows(
          search: q.trim().isEmpty ? null : q.trim());
      if (mounted) setState(() => _list = list);
    } catch (_) {
      if (mounted) setState(() => _list = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
    return Dialog(
      child: SizedBox(
        width: 520, height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              color: Colors.teal[800],
              child: Text(l.isEnglish ? 'Search Customer' : 'ค้นหาลูกค้า',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                decoration: InputDecoration(
                    hintText: l.isEnglish
                        ? 'Search by customer code or name'
                        : 'ค้นหาจากรหัสหรือชื่อลูกค้า',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: const OutlineInputBorder(),
                    isDense: true),
                onChanged: _search,
              ),
            ),
            Container(
              color: Colors.grey[200],
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 6),
              child: Row(children: [
                SizedBox(
                    width: 100,
                    child: Text(l.code,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(
                    child: Text(
                        l.isEnglish ? 'Customer Name' : 'ชื่อลูกค้า',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _list.isEmpty
                      ? Center(
                          child: Text(
                              l.isEnglish ? 'No data found' : 'ไม่พบข้อมูล',
                              style: const TextStyle(color: Colors.grey)))
                      : ListView.separated(
                          controller: _scroll,
                          itemCount: _list.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 12),
                          itemBuilder: (ctx, i) {
                            final c = _list[i];
                            return InkWell(
                              onTap: () => Navigator.pop(ctx, c),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Row(children: [
                                  SizedBox(
                                      width: 100,
                                      child: Text(c.customerCode,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight:
                                                  FontWeight.w500))),
                                  Expanded(
                                      child: Text(
                                          l.isEnglish &&
                                                  (c.customerNameEn
                                                          ?.isNotEmpty ??
                                                      false)
                                              ? c.customerNameEn!
                                              : c.customerNameTh,
                                          style: const TextStyle(
                                              fontSize: 13),
                                          overflow:
                                              TextOverflow.ellipsis)),
                                ]),
                              ),
                            );
                          }),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l.cancel)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
