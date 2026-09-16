// lib/po/widgets/po_transaction_list_widget.dart — มิเรอร์ im_transaction_list_widget.dart แบบเรียบง่ายลง (ไม่มี
// doc-type filter เพราะ PO มีประเภทเอกสารเดียว)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/po_transaction.dart';
import '../services/po_transaction_service.dart';
import '../../ap/models/ap_vendor.dart';
import '../../ap/widgets/ap_vendor_list_widget.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../utils/date_utils.dart';

class PoTransactionListWidget extends StatefulWidget {
  final VoidCallback onAddPressed;
  final Function(int) onEditPressed;
  final Function(int) onViewPressed;
  final bool shouldRefresh;
  final VoidCallback onRefreshComplete;
  final bool enableAddButton;
  final bool enableEditButton;

  const PoTransactionListWidget({
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
  State<PoTransactionListWidget> createState() => _PoTransactionListWidgetState();
}

class _PoTransactionListWidgetState extends State<PoTransactionListWidget> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _service = PoTransactionService();
  final _fmtQty = NumberFormat('#,##0.####');
  final _fmtValue = NumberFormat('#,##0.00');
  final _dateFmt = DateFormat('dd/MM/yyyy');
  bool _isEnglish = false;

  List<PoTransactionHeader> _rows = [];
  List<PoTransactionHeader> _filteredRows = [];
  bool _isLoading = false;

  final _searchCtrl = TextEditingController();
  String? _selectedStatus;
  ApVendor? _selectedVendor;

  final DateTime _defaultDateFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  final DateTime _defaultDateTo = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
  late DateTime _dateFrom;
  late DateTime _dateTo;

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
  void didUpdateWidget(covariant PoTransactionListWidget old) {
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
        vendorId: _selectedVendor?.id,
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
    Iterable<PoTransactionHeader> base = _rows;
    if (_selectedStatus != null) base = base.where((r) => r.status == _selectedStatus);
    if (query.isEmpty) {
      _filteredRows = base.toList();
      return;
    }
    final keywords = query.split(RegExp(r'\s+'));
    _filteredRows = base.where((r) {
      final fields = [r.docNo, r.vendorCode ?? '', r.vendorNameTh ?? '', r.status].map((f) => f.toLowerCase()).toList();
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
      case 'Approved': return Colors.blue;
      case 'PartiallyReceived': return Colors.teal;
      case 'FullyReceived': return Colors.green;
      case 'Closed': return Colors.grey;
      case 'Void': return Colors.red;
      default: return Colors.grey;
    }
  }

  bool get _hasActiveFilters =>
      _selectedStatus != null || _selectedVendor != null || _dateFrom != _defaultDateFrom || _dateTo != _defaultDateTo || _searchCtrl.text.isNotEmpty;

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
              onTap: () => ApVendorListWidget.search(context, onSelected: (v) {
                setState(() => _selectedVendor = v);
                _fetchRows();
              }),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Vendor' : 'ผู้ขาย', isDense: true, border: const OutlineInputBorder(),
                  suffixIcon: _selectedVendor == null
                      ? const Icon(Icons.search, size: 16)
                      : IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () { setState(() => _selectedVendor = null); _fetchRows(); }),
                ),
                child: Text(_selectedVendor == null ? (isEnglish ? 'All Vendors' : 'ทุกผู้ขาย') : '${_selectedVendor!.vendorCode} ${_selectedVendor!.vendorNameTh}',
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
                ...['Draft', 'Approved', 'PartiallyReceived', 'FullyReceived', 'Closed', 'Void']
                    .map((s) => DropdownMenuItem(value: s, child: Text(poTransactionStatusLabel(s, isEnglish)))),
              ],
              onChanged: (v) => setState(() { _selectedStatus = v; _applyFilter(); }),
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
                labelText: isEnglish ? 'Search (PO No. / Vendor)' : 'ค้นหา (เลขที่ / ผู้ขาย)',
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
              label: Text(isEnglish ? 'New PO' : 'สร้างใบสั่งซื้อ'),
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
                  _selectedVendor = null;
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
              DataColumn(label: Text(isEnglish ? 'PO No.' : 'เลขที่ใบสั่งซื้อ', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(isEnglish ? 'Date' : 'วันที่', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(isEnglish ? 'Vendor' : 'ผู้ขาย', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(isEnglish ? 'Due Date' : 'วันครบกำหนด', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(isEnglish ? 'Total Qty' : 'จำนวนรวม', style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text(isEnglish ? 'Total Value' : 'มูลค่ารวม', style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text(isEnglish ? 'Status' : 'สถานะ', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(isEnglish ? 'Actions' : 'จัดการ', style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _filteredRows.map((row) {
              final isDraft = row.status == 'Draft';
              return DataRow(cells: [
                DataCell(Text(row.docNo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    onTap: () => isDraft ? widget.onEditPressed(row.id) : widget.onViewPressed(row.id)),
                DataCell(Text(_dateFmt.format(row.docDate), style: const TextStyle(fontSize: 12))),
                DataCell(Text('${row.vendorCode ?? ''} ${row.vendorNameTh ?? ''}'.trim(), style: const TextStyle(fontSize: 12))),
                DataCell(Text(row.dueDate != null ? _dateFmt.format(row.dueDate!) : '-', style: const TextStyle(fontSize: 12))),
                DataCell(Text(_fmtQty.format(row.totalQty), style: const TextStyle(fontSize: 12))),
                DataCell(Text(_fmtValue.format(row.totalValueLc), style: const TextStyle(fontSize: 12))),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: _statusColor(row.status).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                  child: Text(poTransactionStatusLabel(row.status, isEnglish),
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
