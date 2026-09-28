// lib/po/screens/po_bulk_close_screen.dart — ปิดใบสั่งซื้อทีละหลายใบ (bulk close) — เลือกจากรายการที่กรองได้
// แล้วปิดพร้อมกันหลายใบ การปิดจริงเรียก PoTransactionService.closeTransaction ทีละใบ (endpoint เดิม ไม่มี
// endpoint เขียนใหม่) ดังนั้น 1 ใบล้มเหลว (เช่นถูกใบอื่นปิดไปแล้วระหว่างนั้น) จะไม่บล็อกใบที่เหลือในชุดเดียวกัน
import 'dart:math' show max;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../ap/models/ap_vendor.dart';
import '../../ap/services/ap_vendor_service.dart';
import '../widgets/po_search_multi_picker.dart';
import '../models/po_closable_row.dart';
import '../models/po_transaction.dart';
import '../services/po_closable_service.dart';
import '../services/po_transaction_service.dart';

// ─── Column widths (all fixed — no Expanded in horizontal scroll) ─────────────
const double _wCB = 40.0;
const double _wDocNo = 110.0;
const double _wDate = 92.0;
const double _wVendor = 220.0;
const double _wWarehouse = 160.0;
const double _wStatus = 130.0;
const double _wQty = 90.0;
const double _wPct = 70.0;
const double _wValue = 120.0;

const double _totalTableWidth = _wCB +
    _wDocNo +
    _wDate * 2 +
    _wVendor +
    _wWarehouse +
    _wStatus +
    _wQty * 2 +
    _wPct +
    _wValue;

class _CloseResult {
  final String docNo;
  final bool success;
  final String? error;
  _CloseResult({required this.docNo, required this.success, this.error});
}

class PoBulkCloseScreen extends StatefulWidget {
  const PoBulkCloseScreen({super.key});

  @override
  State<PoBulkCloseScreen> createState() => _PoBulkCloseScreenState();
}

class _PoBulkCloseScreenState extends State<PoBulkCloseScreen> {
  final _closableService = PoClosableService();
  final _transactionService = PoTransactionService();
  final _vendorService = ApVendorService();
  final _fmt = NumberFormat('#,##0.00', 'en_US');
  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _hScroll = ScrollController();
  final _vScroll = ScrollController();

  bool _isEnglish = false;
  bool _isLoading = false;
  bool _isClosing = false;
  bool _hasLoaded = false;
  int _closingProgress = 0;

  bool _isFilterExpanded = true;
  double _filterPanelWidth = 320.0;
  bool _isDraggingDivider = false;

  DateTime? _poDateFrom;
  DateTime? _poDateTo;
  DateTime? _dueDateFrom;
  DateTime? _dueDateTo;
  List<ApVendor> _vendors = [];
  List<int> _selectedVendorIds = [];
  final Set<String> _selectedStatuses = {'Approved', 'PartiallyReceived', 'FullyReceived'};

  List<PoClosableRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _loadMasterData();
  }

  @override
  void dispose() {
    _hScroll.dispose();
    _vScroll.dispose();
    super.dispose();
  }

  Future<void> _loadMasterData() async {
    final vendors = await _vendorService.fetchActiveRows();
    if (mounted) setState(() => _vendors = vendors);
  }

  Future<void> _loadData() async {
    final isEnglish = _isEnglish;
    setState(() => _isLoading = true);
    try {
      final rows = await _closableService.fetchClosableList(
        poDateFrom: _poDateFrom,
        poDateTo: _poDateTo,
        dueDateFrom: _dueDateFrom,
        dueDateTo: _dueDateTo,
        vendorIds: _selectedVendorIds,
        statuses: _selectedStatuses.toList(),
      );
      if (rows.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish
                ? 'No closable purchase orders found for the selected conditions'
                : 'ไม่พบใบสั่งซื้อที่ปิดได้ตามเงื่อนไขที่เลือก')));
      }
      setState(() {
        _rows = rows;
        _hasLoaded = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── selection helpers ──────────────────────────────────────────────────────

  List<PoClosableRow> get _selectedRows => _rows.where((r) => r.selected).toList();
  bool get _allSelected => _rows.isNotEmpty && _rows.every((r) => r.selected);
  bool get _someSelected => _rows.any((r) => r.selected);
  double get _selectedTotal => _selectedRows.fold(0.0, (s, r) => s + r.totalValueLc);

  void _toggleAll(bool? v) {
    setState(() {
      for (final r in _rows) {
        r.selected = v ?? false;
      }
    });
  }

  // ─── bulk close ─────────────────────────────────────────────────────────────

  Future<void> _closeSelected() async {
    final isEnglish = _isEnglish;
    final selected = _selectedRows;
    if (selected.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEnglish ? 'Confirm Closing Purchase Orders' : 'ยืนยันการปิดใบสั่งซื้อ'),
        content: Text(isEnglish
            ? 'Will close ${selected.length} purchase order(s)\n'
                'Total value ${_fmt.format(_selectedTotal)}\n\n'
                'Do you want to proceed?'
            : 'จะปิดใบสั่งซื้อ ${selected.length} ใบ\n'
                'มูลค่ารวม ${_fmt.format(_selectedTotal)} บาท\n\n'
                'ต้องการดำเนินการหรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[800], foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(isEnglish ? 'Confirm' : 'ยืนยัน'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      _isClosing = true;
      _closingProgress = 0;
    });

    final results = <_CloseResult>[];
    for (final row in selected) {
      try {
        await _transactionService.closeTransaction(row.poId);
        results.add(_CloseResult(docNo: row.poDocNo, success: true));
      } catch (e) {
        results.add(_CloseResult(docNo: row.poDocNo, success: false, error: e.toString().replaceFirst('Exception: ', '')));
      }
      if (mounted) setState(() => _closingProgress++);
    }

    if (mounted) setState(() => _isClosing = false);
    if (mounted) await _showResultDialog(results);
    if (mounted) await _loadData();
  }

  Future<void> _showResultDialog(List<_CloseResult> results) async {
    final isEnglish = _isEnglish;
    final succeeded = results.where((r) => r.success).toList();
    final failed = results.where((r) => !r.success).toList();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: [
          Icon(failed.isEmpty ? Icons.check_circle : Icons.warning_amber, color: failed.isEmpty ? Colors.teal[700] : Colors.orange[700]),
          const SizedBox(width: 8),
          Text(isEnglish ? 'Close Purchase Orders Result' : 'ผลการปิดใบสั่งซื้อ'),
        ]),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEnglish
                      ? 'Succeeded: ${succeeded.length}   Failed: ${failed.length}'
                      : 'สำเร็จ: ${succeeded.length} ใบ   ล้มเหลว: ${failed.length} ใบ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (succeeded.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(isEnglish ? 'Succeeded' : 'ปิดสำเร็จ', style: TextStyle(color: Colors.teal[800], fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  ...succeeded.map((r) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Row(children: [
                          Icon(Icons.check, size: 14, color: Colors.teal[700]),
                          const SizedBox(width: 4),
                          Text(r.docNo, style: const TextStyle(fontSize: 13)),
                        ]),
                      )),
                ],
                if (failed.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(isEnglish ? 'Failed' : 'ปิดไม่สำเร็จ', style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  ...failed.map((r) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(Icons.close, size: 14, color: Colors.red[700]),
                          const SizedBox(width: 4),
                          Expanded(
                              child: Text('${r.docNo}: ${r.error}',
                                  style: TextStyle(fontSize: 13, color: Colors.red[900]))),
                        ]),
                      )),
                ],
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[800], foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context),
            child: Text(isEnglish ? 'Close' : 'ปิด'),
          ),
        ],
      ),
    );
  }

  // ─── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final canApprove = MenuScope.of(context)?.canApprove ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final maxFilterWidth = (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 36,
              color: Colors.teal[800],
              child: IconButton(
                icon: Icon(_isFilterExpanded ? Icons.filter_list_off : Icons.filter_list, color: Colors.white, size: 20),
                padding: EdgeInsets.zero,
                tooltip: _isFilterExpanded ? (isEnglish ? 'Collapse filter' : 'ย่อเงื่อนไข') : (isEnglish ? 'Expand filter' : 'ขยายเงื่อนไข'),
                onPressed: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
              ),
            ),
            AnimatedContainer(
              duration: _isDraggingDivider ? Duration.zero : const Duration(milliseconds: 200),
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
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isEnglish ? 'Report Conditions' : 'เงื่อนไขรายงาน',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 16),
                              Text(isEnglish ? 'Order Date' : 'วันที่สั่งซื้อ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Row(children: [
                                Expanded(child: _dateField(isEnglish ? 'From' : 'ตั้งแต่', _poDateFrom, (d) => setState(() => _poDateFrom = d))),
                                const SizedBox(width: 8),
                                Expanded(child: _dateField(isEnglish ? 'To' : 'ถึง', _poDateTo, (d) => setState(() => _poDateTo = d))),
                              ]),
                              const SizedBox(height: 12),
                              Text(isEnglish ? 'Due Date' : 'วันที่ครบกำหนด', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Row(children: [
                                Expanded(child: _dateField(isEnglish ? 'From' : 'ตั้งแต่', _dueDateFrom, (d) => setState(() => _dueDateFrom = d))),
                                const SizedBox(width: 8),
                                Expanded(child: _dateField(isEnglish ? 'To' : 'ถึง', _dueDateTo, (d) => setState(() => _dueDateTo = d))),
                              ]),
                              const SizedBox(height: 12),
                              SearchMultiPicker<ApVendor>(
                                items: _vendors,
                                selectedIds: _selectedVendorIds,
                                idOf: (v) => v.id!,
                                labelOf: (v, en) => '${v.vendorCode}  ${en && (v.vendorNameEn ?? '').isNotEmpty ? v.vendorNameEn! : v.vendorNameTh}',
                                searchTextOf: (v) => '${v.vendorCode} ${v.vendorNameTh} ${v.vendorNameEn ?? ''}',
                                onChanged: (v) => setState(() => _selectedVendorIds = v),
                                labelTh: 'ผู้ขาย',
                                labelEn: 'Vendor',
                                allLabelTh: '— ทุกผู้ขาย —',
                                allLabelEn: '— All vendors —',
                              ),
                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              Text(isEnglish ? 'Status' : 'สถานะ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              for (final s in const ['Approved', 'PartiallyReceived', 'FullyReceived'])
                                CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  value: _selectedStatuses.contains(s),
                                  title: Text(poTransactionStatusLabel(s, isEnglish), style: const TextStyle(fontSize: 13)),
                                  onChanged: (v) => setState(() {
                                    if (v == true) {
                                      _selectedStatuses.add(s);
                                    } else {
                                      _selectedStatuses.remove(s);
                                    }
                                  }),
                                ),
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
                            label: Text(isEnglish ? 'Load Data' : 'โหลดข้อมูล'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[800], foregroundColor: Colors.white),
                            onPressed: (_isLoading || _selectedStatuses.isEmpty) ? null : _loadData,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
            if (_isFilterExpanded)
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  onHorizontalDragStart: (_) => setState(() => _isDraggingDivider = true),
                  onHorizontalDragUpdate: (d) => setState(() {
                    _filterPanelWidth = (_filterPanelWidth + d.delta.dx).clamp(200.0, maxFilterWidth);
                  }),
                  onHorizontalDragEnd: (_) => setState(() => _isDraggingDivider = false),
                  child: Container(width: 5, color: Colors.grey[400]),
                ),
              ),
            Expanded(child: _buildRightPanel(isEnglish, canApprove)),
          ],
        );
      }),
    );
  }

  // ─── right panel ────────────────────────────────────────────────────────────

  Widget _buildRightPanel(bool isEnglish, bool canApprove) {
    final selCount = _selectedRows.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Colors.grey[100],
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(children: [
            Checkbox(
              value: _rows.isEmpty ? false : (_allSelected ? true : (_someSelected ? null : false)),
              tristate: true,
              onChanged: _rows.isEmpty ? null : _toggleAll,
            ),
            Text(isEnglish ? 'Select All' : 'เลือกทั้งหมด', style: const TextStyle(fontSize: 13)),
            const Spacer(),
            if (_rows.isNotEmpty)
              Text(
                isEnglish
                    ? 'Selected $selCount of ${_rows.length} | Total ${_fmt.format(_selectedTotal)}'
                    : 'เลือก $selCount จาก ${_rows.length} ใบ | รวม ${_fmt.format(_selectedTotal)} บาท',
                style: TextStyle(fontSize: 13, color: Colors.teal[800], fontWeight: FontWeight.w600),
              ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _rows.isEmpty
                  ? Center(
                      child: Text(
                        _hasLoaded
                            ? (isEnglish ? 'No closable purchase orders found' : 'ไม่พบใบสั่งซื้อที่ปิดได้')
                            : (isEnglish ? 'Please set conditions and press "Load Data"' : 'กรุณากำหนดเงื่อนไขและกด "โหลดข้อมูล"'),
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                    )
                  : LayoutBuilder(builder: (ctx, constraints) {
                      final tableW = max(constraints.maxWidth, _totalTableWidth);
                      return Scrollbar(
                        controller: _hScroll,
                        scrollbarOrientation: ScrollbarOrientation.bottom,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _hScroll,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: tableW,
                            height: constraints.maxHeight,
                            child: Column(children: [
                              _buildHeader(isEnglish),
                              const Divider(height: 1),
                              Expanded(
                                child: Scrollbar(
                                  controller: _vScroll,
                                  thumbVisibility: true,
                                  child: ListView.builder(
                                    controller: _vScroll,
                                    itemCount: _rows.length,
                                    itemBuilder: (_, i) => _buildRow(i, _rows[i], isEnglish),
                                  ),
                                ),
                              ),
                            ]),
                          ),
                        ),
                      );
                    }),
        ),
        if (_rows.isNotEmpty) _buildFooter(isEnglish, canApprove),
      ],
    );
  }

  static const _headerStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5);

  Widget _buildHeader(bool isEnglish) {
    return Container(
      color: const Color(0xFFDCEFE9),
      child: Row(children: [
        const SizedBox(width: _wCB),
        _hCell(isEnglish ? 'PO No.' : 'เลขที่ใบสั่งซื้อ', _wDocNo),
        _hCell(isEnglish ? 'PO Date' : 'วันที่สั่งซื้อ', _wDate),
        _hCell(isEnglish ? 'Due Date' : 'วันครบกำหนด', _wDate),
        _hCell(isEnglish ? 'Vendor' : 'ผู้ขาย', _wVendor),
        _hCell(isEnglish ? 'Warehouse' : 'คลังสินค้า', _wWarehouse),
        _hCell(isEnglish ? 'Status' : 'สถานะ', _wStatus),
        _hCell(isEnglish ? 'Ordered' : 'สั่งซื้อ', _wQty, right: true),
        _hCell(isEnglish ? 'Received' : 'รับแล้ว', _wQty, right: true),
        _hCell('%', _wPct, right: true),
        _hCell(isEnglish ? 'Total Value' : 'มูลค่ารวม', _wValue, right: true),
      ]),
    );
  }

  Widget _hCell(String t, double w, {bool right = false}) => SizedBox(
        width: w,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          child: Text(t, style: _headerStyle, textAlign: right ? TextAlign.right : TextAlign.left),
        ),
      );

  Widget _buildRow(int index, PoClosableRow row, bool isEnglish) {
    final vendorName = isEnglish && (row.vendorNameEn ?? '').isNotEmpty ? row.vendorNameEn! : (row.vendorNameTh ?? '');
    final warehouseName = isEnglish && (row.warehouseNameEn ?? '').isNotEmpty ? row.warehouseNameEn! : (row.warehouseNameTh ?? '');
    return Container(
      color: index.isEven ? Colors.white : const Color(0xFFF7FAFA),
      child: Row(children: [
        SizedBox(
          width: _wCB,
          child: Checkbox(value: row.selected, onChanged: (v) => setState(() => row.selected = v ?? false)),
        ),
        _dCell(row.poDocNo, _wDocNo),
        _dCell(row.poDocDate != null ? _dateFmt.format(row.poDocDate!) : '-', _wDate),
        _dCell(row.dueDate != null ? _dateFmt.format(row.dueDate!) : '-', _wDate),
        _dCell('${row.vendorCode ?? ''}  $vendorName', _wVendor),
        _dCell('${row.warehouseCode ?? ''}  $warehouseName', _wWarehouse),
        _dCell(poTransactionStatusLabel(row.status, isEnglish), _wStatus),
        _numCell(row.qtyOrdered, _wQty),
        _numCell(row.qtyReceived, _wQty),
        _dCell('${row.receivedPct.toStringAsFixed(0)}%', _wPct, center: true),
        _numCell(row.totalValueLc, _wValue),
      ]),
    );
  }

  Widget _dCell(String t, double w, {bool center = false}) => SizedBox(
        width: w,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Text(t,
              style: const TextStyle(fontSize: 13), textAlign: center ? TextAlign.center : TextAlign.left, overflow: TextOverflow.ellipsis),
        ),
      );

  Widget _numCell(double v, double w) => SizedBox(
        width: w,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Text(_fmt.format(v), style: const TextStyle(fontSize: 13), textAlign: TextAlign.right),
        ),
      );

  Widget _buildFooter(bool isEnglish, bool canApprove) {
    final selCount = _selectedRows.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: Colors.grey[50], border: Border(top: BorderSide(color: Colors.grey[300]!))),
      child: Row(children: [
        Expanded(
          child: Wrap(spacing: 20, runSpacing: 4, children: [
            _chip(Icons.description, isEnglish ? '$selCount doc(s) selected' : 'เลือก $selCount ใบ', Colors.orange[700]!),
            _chip(Icons.payments, _fmt.format(_selectedTotal), Colors.teal[700]!),
            if (!canApprove)
              _chip(Icons.lock, isEnglish ? 'No permission to close' : 'ไม่มีสิทธิ์ปิดใบสั่งซื้อ', Colors.red[600]!),
            if (_isClosing)
              _chip(Icons.hourglass_top, isEnglish ? 'Closing $_closingProgress/$selCount…' : 'กำลังปิด $_closingProgress/$selCount…',
                  Colors.blue[700]!),
          ]),
        ),
        SizedBox(
          height: 44,
          child: ElevatedButton.icon(
            icon: _isClosing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.lock_outline),
            label: Text(isEnglish ? 'Close Selected' : 'ปิดรายการที่เลือก'),
            style: ElevatedButton.styleFrom(
                backgroundColor: (_isClosing || !canApprove || selCount == 0) ? Colors.grey[400] : Colors.teal[800],
                foregroundColor: Colors.white),
            onPressed: (_isClosing || !canApprove || selCount == 0) ? null : _closeSelected,
          ),
        ),
      ]),
    );
  }

  Widget _chip(IconData icon, String label, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
      ]);

  Widget _dateField(String label, DateTime? value, ValueChanged<DateTime?> onPicked) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
          if (value != null)
            InkWell(
              onTap: () => onPicked(null),
              child: const Padding(padding: EdgeInsets.symmetric(horizontal: 2), child: Icon(Icons.clear, size: 14, color: Colors.grey)),
            ),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(context: context, initialDate: value ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (picked != null) onPicked(picked);
            },
            child: const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.calendar_today, size: 14)),
          ),
        ]),
      ),
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(context: context, initialDate: value ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (picked != null) onPicked(picked);
        },
        child: Text(value != null ? _dateFmt.format(value) : (_isEnglish ? '— Any —' : '— ไม่ระบุ —'),
            style: TextStyle(fontSize: 13, color: value != null ? Colors.black87 : Colors.black38)),
      ),
    );
  }
}
