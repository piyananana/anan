// lib/mo/widgets/mo_header_list_widget.dart — มิเรอร์ po_transaction_list_widget.dart (กรองตามคลังแทนผู้ขาย)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/mo_header.dart';
import '../services/mo_header_service.dart';
import '../../im/models/im_warehouse.dart';
import '../../im/widgets/im_warehouse_list_widget.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../utils/date_utils.dart';

class MoHeaderListWidget extends StatefulWidget {
  final VoidCallback onAddPressed;
  final Function(int) onEditPressed;
  final Function(int) onViewPressed;
  final bool shouldRefresh;
  final VoidCallback onRefreshComplete;
  final bool enableAddButton;
  final bool enableEditButton;

  const MoHeaderListWidget({
    super.key,
    required this.onAddPressed,
    required this.onEditPressed,
    required this.onViewPressed,
    required this.shouldRefresh,
    required this.onRefreshComplete,
    this.enableAddButton = true,
    this.enableEditButton = true,
  });

  @override
  State<MoHeaderListWidget> createState() => _MoHeaderListWidgetState();
}

class _MoHeaderListWidgetState extends State<MoHeaderListWidget> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _service = MoHeaderService();
  final _fmtQty = NumberFormat('#,##0.####');
  final _dateFmt = DateFormat('dd/MM/yyyy');
  bool _isEnglish = false;

  List<MoHeader> _rows = [];
  List<MoHeader> _filteredRows = [];
  bool _isLoading = false;

  final _searchCtrl = TextEditingController();
  String? _selectedStatus;
  ImWarehouse? _selectedWarehouse;

  final DateTime _defaultDateFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  final DateTime _defaultDateTo = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
  late DateTime _dateFrom;
  late DateTime _dateTo;

  static const _statuses = ['Draft', 'Submitted', 'Rejected', 'Released', 'InProgress', 'Completed', 'Closed', 'Cancelled', 'Deleted'];

  @override
  void initState() {
    super.initState();
    _dateFrom = _defaultDateFrom;
    _dateTo = _defaultDateTo;
    _fetchRows();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MoHeaderListWidget old) {
    super.didUpdateWidget(old);
    if (widget.shouldRefresh && !old.shouldRefresh) {
      _fetchRows();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onRefreshComplete();
      });
    }
  }

  Future<void> _fetchRows() async {
    final isEnglish = _isEnglish;
    setState(() => _isLoading = true);
    try {
      final rows = await _service.fetchRows(
        status: _selectedStatus == 'Deleted' ? 'Deleted' : null, // ใบที่ลบแล้วไม่ส่งมาเว้นแต่ขอ
        warehouseId: _selectedWarehouse?.id,
        dateFrom: formatLocalDate(_dateFrom),
        dateTo: formatLocalDate(_dateTo),
      );
      setState(() {
        _rows = rows;
        _applyFilter();
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final query = _searchCtrl.text.trim().toLowerCase();
    Iterable<MoHeader> base = _rows;
    if (_selectedStatus != null) base = base.where((r) => r.status == _selectedStatus);
    if (query.isEmpty) {
      _filteredRows = base.toList();
      return;
    }
    final keywords = query.split(RegExp(r'\s+'));
    _filteredRows = base.where((r) {
      final fields = [r.docNo, r.warehouseCode ?? '', r.warehouseNameTh ?? '', r.status].map((f) => f.toLowerCase()).toList();
      return keywords.every((kw) => fields.any((f) => f.contains(kw)));
    }).toList();
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(context: context, initialDate: isFrom ? _dateFrom : _dateTo, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked != null) {
      setState(() {
        if (isFrom) _dateFrom = picked; else _dateTo = picked;
      });
      _fetchRows();
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Draft': return Colors.orange;
      case 'Submitted': return Colors.amber;
      case 'Rejected': return Colors.deepOrange;
      case 'Released': return Colors.blue;
      case 'InProgress': return Colors.teal;
      case 'Completed': return Colors.green;
      case 'Closed': return Colors.grey;
      case 'Cancelled': return Colors.red;
      case 'Deleted': return Colors.brown;
      default: return Colors.grey;
    }
  }

  bool get _hasActiveFilters =>
      _selectedStatus != null || _selectedWarehouse != null || _dateFrom != _defaultDateFrom || _dateTo != _defaultDateTo || _searchCtrl.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    return Column(children: [
      _buildFilterRow(isEnglish),
      const Divider(height: 1),
      if (!_isLoading)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _hasActiveFilters
                  ? (isEnglish ? 'Found ${_filteredRows.length} of ${_rows.length} rows' : 'พบ ${_filteredRows.length} รายการ จาก ${_rows.length} รายการ')
                  : (isEnglish ? '${_filteredRows.length} rows' : '${_filteredRows.length} รายการ'),
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ),
      Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildTable(isEnglish)),
    ]);
  }

  Widget _buildFilterRow(bool isEnglish) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: InkWell(
              onTap: () => ImWarehouseListWidget.search(context, onSelected: (w) {
                setState(() => _selectedWarehouse = w);
                _fetchRows();
              }),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Warehouse' : 'คลังสินค้า', isDense: true, border: const OutlineInputBorder(),
                  suffixIcon: _selectedWarehouse == null
                      ? const Icon(Icons.search, size: 16)
                      : IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () { setState(() => _selectedWarehouse = null); _fetchRows(); }),
                ),
                child: Text(_selectedWarehouse == null ? (isEnglish ? 'All Warehouses' : 'ทุกคลัง') : '${_selectedWarehouse!.warehouseCode} ${_selectedWarehouse!.warehouseNameTh}',
                    style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String?>(
              value: _selectedStatus,
              isExpanded: true,
              decoration: InputDecoration(labelText: isEnglish ? 'Status' : 'สถานะ', isDense: true, border: const OutlineInputBorder()),
              items: [
                DropdownMenuItem(value: null, child: Text(isEnglish ? 'All' : 'ทั้งหมด')),
                ..._statuses.map((s) => DropdownMenuItem(value: s, child: Text(moHeaderStatusLabel(s, isEnglish)))),
              ],
              onChanged: (v) {
                final refetch = (v == 'Deleted') != (_selectedStatus == 'Deleted');
                setState(() { _selectedStatus = v; _applyFilter(); });
                if (refetch) _fetchRows();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () => _pickDate(true),
              child: InputDecorator(
                decoration: InputDecoration(labelText: isEnglish ? 'From Date' : 'จากวันที่', isDense: true, border: const OutlineInputBorder()),
                child: Text(_dateFmt.format(_dateFrom), style: const TextStyle(fontSize: 13)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () => _pickDate(false),
              child: InputDecorator(
                decoration: InputDecoration(labelText: isEnglish ? 'To Date' : 'ถึงวันที่', isDense: true, border: const OutlineInputBorder()),
                child: Text(_dateFmt.format(_dateTo), style: const TextStyle(fontSize: 13)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                labelText: isEnglish ? 'Search (MO No. / Warehouse)' : 'ค้นหา (เลขที่ / คลัง)',
                isDense: true, border: const OutlineInputBorder(), suffixIcon: const Icon(Icons.search, size: 16),
              ),
              onChanged: (_) => setState(() => _applyFilter()),
            ),
          ),
          const SizedBox(width: 8),
          if (widget.enableAddButton)
            ElevatedButton.icon(
              onPressed: widget.onAddPressed,
              icon: const Icon(Icons.add, size: 16),
              label: Text(isEnglish ? 'New MO' : 'สร้างใบสั่งผลิต'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
            ),
          if (_hasActiveFilters) ...[
            const SizedBox(width: 4),
            TextButton(
              onPressed: () {
                setState(() {
                  _dateFrom = _defaultDateFrom;
                  _dateTo = _defaultDateTo;
                  _selectedStatus = null;
                  _selectedWarehouse = null;
                  _searchCtrl.clear();
                });
                _fetchRows();
              },
              child: Text(isEnglish ? 'Clear' : 'ล้าง'),
            ),
          ],
        ]),
      ]),
    );
  }

  Widget _buildTable(bool isEnglish) {
    if (_filteredRows.isEmpty) {
      return Center(child: Text(_rows.isEmpty ? (isEnglish ? 'No records found' : 'ไม่พบรายการ') : (isEnglish ? 'No records match your search' : 'ไม่พบรายการที่ตรงกับคำค้น')));
    }
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
            columnSpacing: 12,
            dataRowMinHeight: 32,
            dataRowMaxHeight: 42,
            columns: [
              DataColumn(label: Text(isEnglish ? 'MO No.' : 'เลขที่ใบสั่งผลิต', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(isEnglish ? 'Date' : 'วันที่', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(isEnglish ? 'Warehouse' : 'คลังสินค้า', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(isEnglish ? 'Due Date' : 'วันครบกำหนด', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(isEnglish ? 'Order Qty' : 'จำนวนสั่งผลิต', style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text(isEnglish ? 'Status' : 'สถานะ', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(isEnglish ? 'Actions' : 'จัดการ', style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _filteredRows.map((row) {
              final isDraft = row.status == 'Draft' || row.status == 'Rejected'; // Rejected แก้ไขแล้วส่งใหม่ได้
              return DataRow(cells: [
                DataCell(Text(row.docNo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    onTap: () => isDraft ? widget.onEditPressed(row.id) : widget.onViewPressed(row.id)),
                DataCell(Text(_dateFmt.format(row.docDate), style: const TextStyle(fontSize: 12))),
                DataCell(Text('${row.warehouseCode ?? ''} ${row.warehouseNameTh ?? ''}'.trim(), style: const TextStyle(fontSize: 12))),
                DataCell(Text(row.dueDate != null ? _dateFmt.format(row.dueDate!) : '-', style: const TextStyle(fontSize: 12))),
                DataCell(Text(_fmtQty.format(row.orderQty), style: const TextStyle(fontSize: 12))),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: _statusColor(row.status).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                  child: Text(moHeaderStatusLabel(row.status, isEnglish),
                      style: TextStyle(color: _statusColor(row.status), fontSize: 11, fontWeight: FontWeight.w600)),
                )),
                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                  if (isDraft && widget.enableEditButton)
                    IconButton(icon: const Icon(Icons.edit, size: 16), tooltip: isEnglish ? 'Edit' : 'แก้ไข', onPressed: () => widget.onEditPressed(row.id)),
                  IconButton(icon: const Icon(Icons.visibility, size: 16), tooltip: isEnglish ? 'View' : 'ดู', onPressed: () => widget.onViewPressed(row.id)),
                ])),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}
