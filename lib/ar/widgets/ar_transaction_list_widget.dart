import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ar_transaction.dart';
import '../services/ar_transaction_service.dart';
import '../../gl/models/gl_dimension.dart';
import '../../gl/services/gl_dimension_service.dart';
import '../../gl/widgets/gl_dimension_picker_field.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/models/sa_user_branch.dart';
import '../../sa/services/sa_auth_service.dart';

class ArTransactionListWidget extends StatefulWidget {
  final VoidCallback onAddPressed;
  final Function(int) onEditPressed;
  final Function(int) onViewPressed;
  final bool shouldRefresh;
  final VoidCallback onRefreshComplete;

  const ArTransactionListWidget({
    super.key,
    required this.onAddPressed,
    required this.onEditPressed,
    required this.onViewPressed,
    required this.shouldRefresh,
    required this.onRefreshComplete,
  });

  @override
  State<ArTransactionListWidget> createState() => _ArTransactionListWidgetState();
}

class _ArTransactionListWidgetState extends State<ArTransactionListWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final ArTransactionService _service = ArTransactionService();
  final GlDimensionService _dimService = GlDimensionService();
  final _fmt = NumberFormat('#,##0.00');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  // _rows = ข้อมูลทั้งหมดจาก server (กรองตาม docType + ช่วงวันที่ + branch + dims)
  // _filteredRows = ข้อมูลหลัง client-side filter (status + search)
  List<ArTransactionHeader> _rows = [];
  List<ArTransactionHeader> _filteredRows = [];
  List<ModuleDocument> _docTypes = [];
  bool _isLoading = false;

  final _searchCtrl = TextEditingController();
  String? _selectedStatus;
  String? _selectedDocType;
  List<UserBranch> _allowedBranches = [];
  UserBranch? _selectedBranchFilter;
  List<GlDimensionType> _dimTypes = [];
  Map<String, List<GlDimensionValue>> _dimValues = {};
  Map<int, int?> _dimSelections = {}; // slotNo → selected dimValueId

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
  void didUpdateWidget(covariant ArTransactionListWidget old) {
    super.didUpdateWidget(old);
    if (widget.shouldRefresh && !old.shouldRefresh) {
      _fetchRows();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onRefreshComplete();
      });
    }
  }

  Future<void> _initialLoad() async {
    setState(() => _isLoading = true);
    _allowedBranches = AuthService().allowedBranches;
    if (_allowedBranches.length == 1) {
      _selectedBranchFilter = _allowedBranches.first;
    }
    try {
      final results = await Future.wait([
        _service.fetchDocTypesByUser(),
        _dimService.fetchActiveTypes(),
      ]);
      final docTypes = results[0] as List<ModuleDocument>;
      final types = results[1] as List<GlDimensionType>;
      final valResults = await Future.wait(
        types.map((t) => _dimService.fetchValuesByType(t.typeCode)),
      );
      setState(() {
        _docTypes = docTypes.where((d) => d.isDocType).toList();
        _dimTypes = types;
        for (int i = 0; i < types.length; i++) {
          _dimValues[types[i].typeCode] = valResults[i];
        }
      });
      await _fetchRows();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // โหลดจาก server ด้วย primary filter เท่านั้น (docType + ช่วงวันที่)
  // แล้ว _applyFilter() จะกรอง status + search แบบ client-side
  Future<void> _fetchRows() async {
    setState(() => _isLoading = true);
    try {
      final rows = await _service.fetchRows(
        docType: _selectedDocType,
        dateFrom: DateFormat('yyyy-MM-dd').format(_dateFrom),
        dateTo: DateFormat('yyyy-MM-dd').format(_dateTo),
        branchId: _selectedBranchFilter?.branchId,
        dim1Id: _dimSelections[1],
        dim2Id: _dimSelections[2],
        dim3Id: _dimSelections[3],
        dim4Id: _dimSelections[4],
        dim5Id: _dimSelections[5],
      );
      setState(() {
        _rows = rows;
        _applyFilter();
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // กรอง client-side: status + search text จาก _rows → _filteredRows
  void _applyFilter() {
    final query = _searchCtrl.text.trim().toLowerCase();
    Iterable<ArTransactionHeader> base = _rows;

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
        _dateFmt.format(r.docDate),
        r.dueDate != null ? _dateFmt.format(r.dueDate!) : '',
        r.customerCode ?? '',
        r.customerNameTh ?? '',
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
      case 'Draft':  return Colors.orange;
      case 'Posted': return Colors.green;
      case 'Void':   return Colors.red;
      default:       return Colors.grey;
    }
  }

  String _docTypeNameFromHeader(ArTransactionHeader row) {
    final code = row.docCode ?? '';
    final name = row.docNameThai ?? '';
    return code.isNotEmpty ? '$code $name' : name;
  }

  bool get _hasActiveFilters =>
      _selectedStatus != null ||
      _selectedDocType != null ||
      _selectedBranchFilter != null ||
      _dimSelections.values.any((v) => v != null) ||
      _dateFrom != _defaultDateFrom ||
      _dateTo != _defaultDateTo ||
      _searchCtrl.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _buildFilterRow(),
        const Divider(height: 1),
        if (!_isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _hasActiveFilters
                    ? 'พบ ${_filteredRows.length} รายการ จาก ${_rows.length} รายการ'
                    : '${_filteredRows.length} รายการ',
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
          ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildTable(),
        ),
      ],
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: ประเภทเอกสาร | สถานะ | จากวันที่ | ถึงวันที่
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _selectedDocType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'ประเภทเอกสาร', isDense: true, border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
                    ..._docTypes.map((d) => DropdownMenuItem(
                        value: d.sysDocType,
                        child: Text('${d.docCode} ${d.docNameThai}',
                            overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedDocType = v);
                    _fetchRows(); // server fetch เมื่อเปลี่ยนประเภทเอกสาร
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _selectedStatus,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'สถานะ', isDense: true, border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
                    DropdownMenuItem(value: 'Draft', child: Text('Draft')),
                    DropdownMenuItem(value: 'Posted', child: Text('Posted')),
                    DropdownMenuItem(value: 'Void', child: Text('Void')),
                  ],
                  onChanged: (v) => setState(() {
                    _selectedStatus = v;
                    _applyFilter(); // client-side เท่านั้น
                  }),
                ),
              ),
              if (_allowedBranches.length > 1) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<UserBranch?>(
                    value: _selectedBranchFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'สาขา', isDense: true, border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem<UserBranch?>(value: null, child: Text('ทุกสาขา')),
                      ..._allowedBranches.map((b) => DropdownMenuItem(
                            value: b,
                            child: Text('${b.branchCode} ${b.branchNameThai}',
                                overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedBranchFilter = v);
                      _fetchRows(); // server-side filter
                    },
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(true),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                        labelText: 'จากวันที่', isDense: true, border: OutlineInputBorder()),
                    child: Text(
                        _dateFmt.format(_dateFrom),
                        style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(false),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                        labelText: 'ถึงวันที่', isDense: true, border: OutlineInputBorder()),
                    child: Text(
                        _dateFmt.format(_dateTo),
                        style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
          if (_dimTypes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: _dimTypes.expand((t) {
                final vals = _dimValues[t.typeCode] ?? [];
                final selId = _dimSelections[t.slotNo];
                final selVal = vals.cast<GlDimensionValue?>()
                    .firstWhere((v) => v?.id == selId, orElse: () => null);
                return [
                  if (_dimTypes.first != t) const SizedBox(width: 8),
                  Expanded(
                    child: GlDimensionPickerField(
                      dimType: t,
                      values: vals,
                      selected: selVal,
                      isDense: false,
                      onSelected: (val) {
                        setState(() => _dimSelections[t.slotNo] = val?.id);
                        _fetchRows();
                      },
                    ),
                  ),
                ];
              }).toList(),
            ),
          ],
          const SizedBox(height: 6),
          // Row 2: ค้นหา | เพิ่มเอกสาร | ล้าง
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ค้นหา (เลขที่เอกสาร / ลูกค้า / เลขที่อ้างอิง)',
                    isDense: true,
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.search, size: 16),
                  ),
                  onChanged: (_) => setState(() => _applyFilter()),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: widget.onAddPressed,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('เพิ่มเอกสาร'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700], foregroundColor: Colors.white),
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
                      _selectedBranchFilter = null;
                      _dimSelections.clear();
                      _searchCtrl.clear();
                    });
                    _fetchRows();
                  },
                  child: const Text('ล้าง'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    if (_filteredRows.isEmpty) {
      return Center(
        child: Text(_rows.isEmpty ? 'ไม่พบรายการ' : 'ไม่พบรายการที่ตรงกับคำค้น'),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.teal[50]),
            columnSpacing: 12,
            dataRowMinHeight: 32,
            dataRowMaxHeight: 42,
            columns: const [
              DataColumn(label: Text('เลขที่เอกสาร', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('ประเภท', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('วันที่', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('ครบกำหนด', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('ลูกค้า', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('ยอดรวม', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text('ชำระแล้ว', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text('คงเหลือ', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text('สถานะ', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('จัดการ', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _filteredRows.map((row) {
              final isDraft = row.status == 'Draft';
              return DataRow(
                cells: [
                  DataCell(
                    Text(row.docNo,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    onTap: () => isDraft
                        ? widget.onEditPressed(row.id)
                        : widget.onViewPressed(row.id),
                  ),
                  DataCell(Text(_docTypeNameFromHeader(row), style: const TextStyle(fontSize: 12))),
                  DataCell(Text(_dateFmt.format(row.docDate), style: const TextStyle(fontSize: 12))),
                  DataCell(Text(
                      row.sysDocType == arDocTypeInvoice && row.dueDate != null
                          ? _dateFmt.format(row.dueDate!)
                          : '',
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${row.customerCode ?? ''} ${row.customerNameTh ?? ''}'.trim(),
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Text(_fmt.format(row.totalAmountLc),
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Text(_fmt.format(row.paidAmountLc),
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Text(_fmt.format(row.balanceAmountLc),
                      style: const TextStyle(fontSize: 12, color: Colors.blue))),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusColor(row.status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(row.status,
                        style: TextStyle(
                            color: _statusColor(row.status),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  )),
                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                    if (isDraft)
                      IconButton(
                        icon: const Icon(Icons.edit, size: 16),
                        tooltip: 'แก้ไข',
                        onPressed: () => widget.onEditPressed(row.id),
                        visualDensity: VisualDensity.compact,
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.visibility, size: 16),
                        tooltip: 'ดู',
                        onPressed: () => widget.onViewPressed(row.id),
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
