import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/cm_transaction.dart';
import '../services/cm_transaction_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../utils/date_utils.dart';

class CmTransactionListWidget extends StatefulWidget {
  final VoidCallback onAddPressed;
  final void Function(int id, int? sysDocType) onEditPressed;
  final void Function(int id, int? sysDocType) onViewPressed;
  final bool shouldRefresh;
  final VoidCallback onRefreshComplete;
  final bool enableAddButton;
  final bool enableEditButton;

  const CmTransactionListWidget({
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
  State<CmTransactionListWidget> createState() => _CmTransactionListWidgetState();
}

class _CmTransactionListWidgetState extends State<CmTransactionListWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final CmTransactionService _service = CmTransactionService();
  final _fmt = NumberFormat('#,##0.00');
  final _dateFmt = DateFormat('dd/MM/yyyy');
  bool _isEnglish = false;

  List<CmTransactionHeader> _rows = [];
  List<CmTransactionHeader> _filteredRows = [];
  List<ModuleDocument> _docTypes = [];
  bool _isLoading = false;

  final _searchCtrl = TextEditingController();
  String? _selectedStatus;
  String? _selectedDocType;

  final DateTime _defaultDateFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  final DateTime _defaultDateTo   = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

  late DateTime _dateFrom;
  late DateTime _dateTo;

  @override
  void initState() {
    super.initState();
    _dateFrom = _defaultDateFrom;
    _dateTo   = _defaultDateTo;
    _initialLoad();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CmTransactionListWidget old) {
    super.didUpdateWidget(old);
    if (widget.shouldRefresh && !old.shouldRefresh) {
      _fetchRows();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onRefreshComplete();
      });
    }
  }

  Future<void> _initialLoad() async {
    final isEnglish = _isEnglish;
    setState(() => _isLoading = true);
    try {
      final docTypes = await _service.fetchDocTypesByUser();
      setState(() => _docTypes = docTypes.where((d) => d.isDocType).toList());
      await _fetchRows();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchRows() async {
    final isEnglish = _isEnglish;
    setState(() => _isLoading = true);
    try {
      final rows = await _service.fetchRows(
        docType: _selectedDocType,
        dateFrom: formatLocalDate(_dateFrom),
        dateTo: formatLocalDate(_dateTo),
      );
      setState(() {
        _rows = rows;
        _applyFilter();
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final query = _searchCtrl.text.trim().toLowerCase();
    Iterable<CmTransactionHeader> base = _rows;

    if (_selectedStatus != null) {
      base = base.where((r) => r.status == _selectedStatus);
    }

    if (query.isEmpty) {
      _filteredRows = base.toList();
      return;
    }

    final keywords = query.split(RegExp(r'\s+'));
    _filteredRows = base.where((r) {
      final fields = [
        r.docNo,
        r.docCode ?? '',
        r.docNameThai ?? '',
        r.docNameEng ?? '',
        _dateFmt.format(r.docDate),
        r.counterpartyName ?? '',
        r.refNo ?? '',
        r.status,
      ].map((f) => f.toLowerCase()).toList();
      return keywords.every((kw) => fields.any((f) => f.contains(kw)));
    }).toList();
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _dateFrom : _dateTo,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) _dateFrom = picked;
        else _dateTo = picked;
      });
      _fetchRows();
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Draft':    return Colors.orange;
      case 'Posted':   return Colors.green;
      case 'Void':     return Colors.red;
      case 'Cleared':  return Colors.green;
      case 'Bounced':  return Colors.red;
      case 'Pending':  return Colors.orange;
      default:         return Colors.grey;
    }
  }

  String _docTypeName(CmTransactionHeader row) {
    final code = row.docCode ?? '';
    final name = _isEnglish && (row.docNameEng ?? '').isNotEmpty
        ? row.docNameEng!
        : (row.docNameThai ?? '');
    return code.isNotEmpty ? '$code $name' : name;
  }

  bool get _hasActiveFilters =>
      _selectedStatus != null ||
      _selectedDocType != null ||
      _dateFrom != _defaultDateFrom ||
      _dateTo != _defaultDateTo ||
      _searchCtrl.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    return Column(
      children: [
        _buildFilterRow(isEnglish),
        const Divider(height: 1),
        if (!_isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _hasActiveFilters
                    ? (isEnglish
                        ? 'Found ${_filteredRows.length} of ${_rows.length} rows'
                        : 'พบ ${_filteredRows.length} รายการ จาก ${_rows.length} รายการ')
                    : (isEnglish
                        ? '${_filteredRows.length} rows'
                        : '${_filteredRows.length} รายการ'),
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
          ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildTable(isEnglish),
        ),
      ],
    );
  }

  Widget _buildFilterRow(bool isEnglish) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _selectedDocType,
                  isExpanded: true,
                  decoration: InputDecoration(
                      labelText: isEnglish ? 'Document Type' : 'ประเภทเอกสาร', isDense: true, border: const OutlineInputBorder()),
                  items: [
                    DropdownMenuItem(value: null, child: Text(isEnglish ? 'All' : 'ทั้งหมด')),
                    ..._docTypes.map((d) => DropdownMenuItem(
                        value: d.sysDocType,
                        child: Text('${d.docCode} ${isEnglish && d.docNameEng.isNotEmpty ? d.docNameEng : d.docNameThai}',
                            overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedDocType = v);
                    _fetchRows();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _selectedStatus,
                  isExpanded: true,
                  decoration: InputDecoration(
                      labelText: isEnglish ? 'Status' : 'สถานะ', isDense: true, border: const OutlineInputBorder()),
                  items: [
                    DropdownMenuItem(value: null, child: Text(isEnglish ? 'All' : 'ทั้งหมด')),
                    const DropdownMenuItem(value: 'Draft', child: Text('Draft')),
                    const DropdownMenuItem(value: 'Posted', child: Text('Posted')),
                    const DropdownMenuItem(value: 'Void', child: Text('Void')),
                    const DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                    const DropdownMenuItem(value: 'Cleared', child: Text('Cleared')),
                  ],
                  onChanged: (v) => setState(() {
                    _selectedStatus = v;
                    _applyFilter();
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(true),
                  child: InputDecorator(
                    decoration: InputDecoration(
                        labelText: isEnglish ? 'From Date' : 'จากวันที่', isDense: true, border: const OutlineInputBorder()),
                    child: Text(_dateFmt.format(_dateFrom), style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(false),
                  child: InputDecorator(
                    decoration: InputDecoration(
                        labelText: isEnglish ? 'To Date' : 'ถึงวันที่', isDense: true, border: const OutlineInputBorder()),
                    child: Text(_dateFmt.format(_dateTo), style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    labelText: isEnglish
                        ? 'Search (Doc No. / Counterparty / Ref No.)'
                        : 'ค้นหา (เลขที่เอกสาร / คู่ค้า / เลขที่อ้างอิง)',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixIcon: const Icon(Icons.search, size: 16),
                  ),
                  onChanged: (_) => setState(() => _applyFilter()),
                ),
              ),
              const SizedBox(width: 8),
              if (widget.enableAddButton)
                ElevatedButton.icon(
                  onPressed: widget.onAddPressed,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(isEnglish ? 'Add Document' : 'เพิ่มเอกสาร'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
                ),
              if (_hasActiveFilters) ...[
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _dateFrom = _defaultDateFrom;
                      _dateTo   = _defaultDateTo;
                      _selectedStatus = null;
                      _selectedDocType = null;
                      _searchCtrl.clear();
                    });
                    _fetchRows();
                  },
                  child: Text(isEnglish ? 'Clear' : 'ล้าง'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTable(bool isEnglish) {
    if (_filteredRows.isEmpty) {
      return Center(
        child: Text(_rows.isEmpty
            ? (isEnglish ? 'No records found' : 'ไม่พบรายการ')
            : (isEnglish ? 'No records match your search' : 'ไม่พบรายการที่ตรงกับคำค้น')),
      );
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
              DataColumn(label: Text(isEnglish ? 'Doc No.' : 'เลขที่เอกสาร', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(isEnglish ? 'Type' : 'ประเภท', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(isEnglish ? 'Date' : 'วันที่', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(isEnglish ? 'Counterparty' : 'คู่ค้า', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(isEnglish ? 'Total' : 'ยอดรวม', style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text(isEnglish ? 'Balance' : 'คงเหลือ', style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text(isEnglish ? 'Status' : 'สถานะ', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(isEnglish ? 'Actions' : 'จัดการ', style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _filteredRows.map((row) {
              final isReadOnlyType = row.sysDocType != null && cmReadOnlyDocTypes.contains(row.sysDocType);
              final isDraft = !isReadOnlyType && row.status == 'Draft';
              return DataRow(
                cells: [
                  DataCell(
                    Text(row.docNo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    onTap: () => isDraft
                        ? widget.onEditPressed(row.id, row.sysDocType)
                        : widget.onViewPressed(row.id, row.sysDocType),
                  ),
                  DataCell(Text(_docTypeName(row), style: const TextStyle(fontSize: 12))),
                  DataCell(Text(_dateFmt.format(row.docDate), style: const TextStyle(fontSize: 12))),
                  DataCell(Text(row.counterpartyName ?? '', style: const TextStyle(fontSize: 12))),
                  DataCell(Text(_fmt.format(row.totalAmountLc), style: const TextStyle(fontSize: 12))),
                  DataCell(Text(
                      row.sysDocType == cmDocTypePettyCashVoucher ? _fmt.format(row.balanceAmountLc) : '',
                      style: const TextStyle(fontSize: 12, color: Colors.blue))),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusColor(row.status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(row.status,
                        style: TextStyle(color: _statusColor(row.status), fontSize: 11, fontWeight: FontWeight.w600)),
                  )),
                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                    if (isDraft && widget.enableEditButton)
                      IconButton(
                        icon: const Icon(Icons.edit, size: 16),
                        tooltip: isEnglish ? 'Edit' : 'แก้ไข',
                        onPressed: () => widget.onEditPressed(row.id, row.sysDocType),
                        visualDensity: VisualDensity.compact,
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.visibility, size: 16),
                        tooltip: isEnglish ? 'View' : 'ดู',
                        onPressed: () => widget.onViewPressed(row.id, row.sysDocType),
                        visualDensity: VisualDensity.compact,
                      ),
                  ])),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
