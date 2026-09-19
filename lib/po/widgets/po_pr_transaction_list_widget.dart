// lib/po/widgets/po_pr_transaction_list_widget.dart — มิเรอร์ po_transaction_list_widget.dart (ไม่มี vendor filter
// เป็นหลัก เพราะ PR ไม่บังคับผู้ขาย — ใช้ค้นหาด้วยเลขที่/คำอธิบายแทน) ย้ายมารวมกับโฟลเดอร์ po (เดิมอยู่ lib/pr/)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/po_pr_transaction.dart';
import '../services/po_pr_transaction_service.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../utils/date_utils.dart';

class PrTransactionListWidget extends StatefulWidget {
  final VoidCallback onAddPressed;
  final Function(int) onEditPressed;
  final Function(int) onViewPressed;
  final bool shouldRefresh;
  final VoidCallback onRefreshComplete;
  final bool enableAddButton;
  final bool enableEditButton;

  const PrTransactionListWidget({
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
  State<PrTransactionListWidget> createState() => _PrTransactionListWidgetState();
}

class _PrTransactionListWidgetState extends State<PrTransactionListWidget> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _service = PrTransactionService();
  final _fmtQty = NumberFormat('#,##0.####');
  final _fmtValue = NumberFormat('#,##0.00');
  final _dateFmt = DateFormat('dd/MM/yyyy');
  bool _isEnglish = false;

  List<PrTransactionHeader> _rows = [];
  List<PrTransactionHeader> _filteredRows = [];
  bool _isLoading = false;

  final _searchCtrl = TextEditingController();
  String? _selectedStatus;

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
  void didUpdateWidget(covariant PrTransactionListWidget old) {
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
    Iterable<PrTransactionHeader> base = _rows;
    if (_selectedStatus != null) base = base.where((r) => r.status == _selectedStatus);
    if (query.isEmpty) {
      _filteredRows = base.toList();
      return;
    }
    final keywords = query.split(RegExp(r'\s+'));
    _filteredRows = base.where((r) {
      final fields = [r.docNo, r.vendorCode ?? '', r.vendorNameTh ?? '', r.requestedByName ?? '', r.description ?? '', r.status]
          .map((f) => f.toLowerCase())
          .toList();
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
      case 'Approved': return Colors.blue;
      case 'Rejected': return Colors.deepOrange;
      case 'PartiallyConverted': return Colors.teal;
      case 'FullyConverted': return Colors.green;
      case 'Closed': return Colors.grey;
      case 'Void': return Colors.red;
      default: return Colors.grey;
    }
  }

  bool get _hasActiveFilters =>
      _selectedStatus != null || _dateFrom != _defaultDateFrom || _dateTo != _defaultDateTo || _searchCtrl.text.isNotEmpty;

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
            child: DropdownButtonFormField<String?>(
              value: _selectedStatus,
              isExpanded: true,
              decoration: InputDecoration(labelText: isEnglish ? 'Status' : 'สถานะ', isDense: true, border: const OutlineInputBorder()),
              items: [
                DropdownMenuItem(value: null, child: Text(isEnglish ? 'All' : 'ทั้งหมด')),
                ...['Draft', 'Submitted', 'Approved', 'Rejected', 'PartiallyConverted', 'FullyConverted', 'Closed', 'Void']
                    .map((s) => DropdownMenuItem(value: s, child: Text(prTransactionStatusLabel(s, isEnglish)))),
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
                labelText: isEnglish ? 'Search (PR No. / Requester / Vendor)' : 'ค้นหา (เลขที่ / ผู้ขอ / ผู้ขาย)',
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
              label: Text(isEnglish ? 'New PR' : 'สร้างใบขอซื้อ'),
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
              DataColumn(label: Text(isEnglish ? 'PR No.' : 'เลขที่ใบขอซื้อ', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(isEnglish ? 'Date' : 'วันที่', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(isEnglish ? 'Requester' : 'ผู้ขอ', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(isEnglish ? 'Vendor' : 'ผู้ขาย', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(isEnglish ? 'Total Qty' : 'จำนวนรวม', style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text(isEnglish ? 'Est. Value' : 'มูลค่าประมาณ', style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text(isEnglish ? 'Status' : 'สถานะ', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(isEnglish ? 'Actions' : 'จัดการ', style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _filteredRows.map((row) {
              final isEditable = row.status == 'Draft' || row.status == 'Rejected';
              return DataRow(cells: [
                DataCell(Text(row.docNo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    onTap: () => isEditable ? widget.onEditPressed(row.id) : widget.onViewPressed(row.id)),
                DataCell(Text(_dateFmt.format(row.docDate), style: const TextStyle(fontSize: 12))),
                DataCell(Text(row.requestedByName ?? '-', style: const TextStyle(fontSize: 12))),
                DataCell(Text('${row.vendorCode ?? ''} ${row.vendorNameTh ?? ''}'.trim().isEmpty ? '-' : '${row.vendorCode ?? ''} ${row.vendorNameTh ?? ''}'.trim(), style: const TextStyle(fontSize: 12))),
                DataCell(Text(_fmtQty.format(row.totalQty), style: const TextStyle(fontSize: 12))),
                DataCell(Text(_fmtValue.format(row.totalValueLc), style: const TextStyle(fontSize: 12))),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: _statusColor(row.status).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                  child: Text(prTransactionStatusLabel(row.status, isEnglish),
                      style: TextStyle(color: _statusColor(row.status), fontSize: 11, fontWeight: FontWeight.w600)),
                )),
                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                  if (isEditable && widget.enableEditButton)
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
