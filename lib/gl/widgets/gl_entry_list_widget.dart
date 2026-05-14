import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../sa/models/module_document.dart';
import '../../sa/models/user_branch.dart';
import '../../sa/services/auth_service.dart';
import '../models/gl_dimension.dart';
import '../models/gl_entry.dart';
import '../models/period.dart';
import '../services/gl_dimension_service.dart';
import '../services/gl_entry_service.dart';
import '../services/period_service.dart';
import '../widgets/gl_dimension_picker_field.dart';

class GlEntryListWidget extends StatefulWidget {
  final VoidCallback onAddPressed;
  final Function(int) onEditPressed;
  final Function(int) onViewPressed;
  final bool shouldRefresh;
  final VoidCallback onRefreshComplete;

  const GlEntryListWidget({
    super.key,
    required this.onAddPressed,
    required this.onEditPressed,
    required this.onViewPressed,
    required this.shouldRefresh,
    required this.onRefreshComplete,
  });

  @override
  State<GlEntryListWidget> createState() => _GlEntryListWidgetState();
}

class _GlEntryListWidgetState extends State<GlEntryListWidget> {
  final GlEntryService _entryService = GlEntryService();
  final PeriodService _periodService = PeriodService();
  final GlDimensionService _dimService = GlDimensionService();
  final _fmt = NumberFormat('#,##0.00');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  List<GlEntryHeader> _entries = [];
  List<GlEntryHeader> _filteredEntries = [];
  bool _isLoading = false;

  Set<String> _allowedDocCodes = {};

  List<FiscalYear> _fiscalYears = [];
  List<PostingPeriod> _periods = [];

  FiscalYear? _selectedFiscalYear;
  PostingPeriod? _selectedPeriod;
  String? _selectedStatus;
  List<UserBranch> _allowedBranches = [];
  UserBranch? _selectedBranchFilter;
  List<GlDimensionType> _dimTypes = [];
  Map<String, List<GlDimensionValue>> _dimValues = {};
  Map<int, int?> _dimSelections = {}; // slotNo → selected dimValueId
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant GlEntryListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldRefresh) {
      _fetchEntries();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onRefreshComplete();
      });
    }
  }

  Future<void> _initialLoad() async {
    setState(() => _isLoading = true);
    _allowedBranches = AuthService().allowedBranches;
    try {
      final results = await Future.wait([
        _periodService.fetchActiveFiscalYears(),
        _entryService.fetchRowsByModuleUserId(),
        _dimService.fetchActiveTypes(),
      ]);
      final fys = results[0] as List<FiscalYear>;
      final allowedDocs = results[1] as List<ModuleDocument>;
      final types = results[2] as List<GlDimensionType>;
      _allowedDocCodes = allowedDocs
          .where((d) => d.isDocType)
          .map((d) => d.docCode)
          .toSet();
      // โหลด dimension values
      final valResults = await Future.wait(
        types.map((t) => _dimService.fetchValuesByType(t.typeCode)),
      );
      setState(() {
        _fiscalYears = fys;
        _dimTypes = types;
        for (int i = 0; i < types.length; i++) {
          _dimValues[types[i].typeCode] = valResults[i];
        }
      });

      if (fys.isNotEmpty) {
        final now = DateTime.now();
        try {
          _selectedFiscalYear = fys.firstWhere((fy) =>
              now.isAfter(fy.yearStartDate.subtract(const Duration(days: 1))) &&
              now.isBefore(fy.yearEndDate.add(const Duration(days: 1))));
        } catch (_) {
          _selectedFiscalYear = fys.first;
        }
        if (_selectedFiscalYear != null) {
          await _fetchPeriods(_selectedFiscalYear!.id);
        }
      }
      await _fetchEntries();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading master data: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchPeriods(int fyId) async {
    try {
      final periods = await _periodService.fetchPostingPeriodsByFiscalYearId(fyId);
      setState(() {
        _periods = periods;
        final now = DateTime.now();
        try {
          _selectedPeriod = periods.firstWhere((p) =>
              now.isAfter(p.periodStartDate.subtract(const Duration(days: 1))) &&
              now.isBefore(p.periodEndDate.add(const Duration(days: 1))));
        } catch (_) {
          _selectedPeriod = periods.isNotEmpty ? periods.first : null;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error fetching periods: $e')));
      }
    }
  }

  Future<void> _fetchEntries() async {
    setState(() => _isLoading = true);
    try {
      final data = await _entryService.fetchEntries(
        periodId: _selectedPeriod?.id,
        fiscalYearId: _selectedPeriod == null ? _selectedFiscalYear?.id : null,
        dim1Id: _dimSelections[1],
        dim2Id: _dimSelections[2],
        dim3Id: _dimSelections[3],
        dim4Id: _dimSelections[4],
        dim5Id: _dimSelections[5],
      );
      setState(() {
        _entries = data;
        _applyFilter();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error fetching entries: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final query = _searchCtrl.text.trim();
    Iterable<GlEntryHeader> base = _entries;

    if (_allowedDocCodes.isNotEmpty) {
      base = base.where((item) => _allowedDocCodes.contains(item.docCode));
    }
    if (_selectedStatus != null) {
      base = base.where((item) => item.status == _selectedStatus);
    }
    if (_selectedBranchFilter != null) {
      base = base.where((item) => item.branchId == _selectedBranchFilter!.branchId);
    }

    if (query.isEmpty) {
      _filteredEntries = base.toList();
      return;
    }

    final keywords = query.toLowerCase().split(RegExp(r'\s+'));
    _filteredEntries = base.where((item) {
      final fields = [
        item.docCode,
        item.docName,
        item.docNo,
        _dateFmt.format(item.docDate),
        item.refDocCode ?? '',
        item.refDocName ?? '',
        item.refDocNo ?? '',
        item.refDocDate != null ? _dateFmt.format(item.refDocDate!) : '',
        item.description,
        item.status,
      ].map((f) => f.toLowerCase()).toList();
      return keywords.every((kw) => fields.any((f) => f.contains(kw)));
    }).toList();
  }

  Future<void> _deleteEntry(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: const Text('ต้องการลบรายการนี้ใช่หรือไม่?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ลบ', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _entryService.deleteEntry(id);
        _fetchEntries();
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('ลบรายการสำเร็จ')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('ลบไม่สำเร็จ: $e')));
        }
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Draft':
        return Colors.orange;
      case 'Posted':
        return Colors.green;
      case 'Void':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatPeriodLabel(PostingPeriod p) =>
      '${p.periodName} (${_dateFmt.format(p.periodStartDate)} - ${_dateFmt.format(p.periodEndDate)})';

  bool get _hasActiveFilters =>
      _selectedStatus != null ||
      _selectedBranchFilter != null ||
      _dimSelections.values.any((v) => v != null) ||
      _searchCtrl.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
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
                    ? 'พบ ${_filteredEntries.length} รายการ จาก ${_entries.length} รายการ'
                    : '${_filteredEntries.length} รายการ',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
          // Row 1: ปีบัญชี | งวด | สถานะ
          Row(
            children: [
              SizedBox(
                width: 110,
                child: DropdownButtonFormField<FiscalYear>(
                  value: _selectedFiscalYear,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'ปีบัญชี', isDense: true, border: OutlineInputBorder()),
                  items: _fiscalYears
                      .map((fy) => DropdownMenuItem(
                          value: fy,
                          child: Text(fy.fyCode, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedFiscalYear = val;
                        _selectedPeriod = null;
                        _periods = [];
                      });
                      _fetchPeriods(val.id).then((_) => _fetchEntries());
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<PostingPeriod>(
                  value: _selectedPeriod,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'งวด', isDense: true, border: OutlineInputBorder()),
                  items: _periods
                      .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(_formatPeriodLabel(p), overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (val) {
                    setState(() => _selectedPeriod = val);
                    _fetchEntries();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String?>(
                  value: _selectedStatus,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'สถานะ', isDense: true, border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
                    DropdownMenuItem(value: 'Draft', child: Text('Draft')),
                    DropdownMenuItem(value: 'Posted', child: Text('Posted')),
                    DropdownMenuItem(value: 'Deleted', child: Text('Deleted')),
                  ],
                  onChanged: (v) => setState(() {
                    _selectedStatus = v;
                    _applyFilter();
                  }),
                ),
              ),
              if (_allowedBranches.length > 1) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
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
                    onChanged: (v) => setState(() {
                      _selectedBranchFilter = v;
                      _applyFilter();
                    }),
                  ),
                ),
              ],
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
                        _fetchEntries();
                      },
                    ),
                  ),
                ];
              }).toList(),
            ),
          ],
          const SizedBox(height: 6),
          // Row 2: ค้นหา | เพิ่มรายการ | ล้าง
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ค้นหา (เลขที่เอกสาร / คำอธิบาย / เลขที่อ้างอิง)',
                    isDense: true,
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.search, size: 16),
                  ),
                  onChanged: (_) => setState(() => _applyFilter()),
                  onSubmitted: (_) => setState(() => _applyFilter()),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: widget.onAddPressed,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('เพิ่มรายการ'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700], foregroundColor: Colors.white),
              ),
              if (_hasActiveFilters) ...[
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedStatus = null;
                      _selectedBranchFilter = null;
                      _dimSelections.clear();
                      _searchCtrl.clear();
                    });
                    _fetchEntries();
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
    if (_filteredEntries.isEmpty) {
      return Center(
        child: Text(_entries.isEmpty
            ? 'ไม่พบรายการบัญชีตามเงื่อนไข'
            : 'ไม่พบรายการที่ตรงกับคำค้น'),
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
              DataColumn(label: Text('อ้างอิง', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('คำอธิบาย', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('ยอดเดบิต', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text('สถานะ', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('จัดการ', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _filteredEntries.map((item) {
              final isDraft = item.status == 'Draft';
              return DataRow(
                cells: [
                  DataCell(
                    Text(item.docNo,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    onTap: () => widget.onViewPressed(item.id),
                  ),
                  DataCell(Text('${item.docCode} ${item.docName}', style: const TextStyle(fontSize: 12))),
                  DataCell(Text(_dateFmt.format(item.docDate), style: const TextStyle(fontSize: 12))),
                  DataCell(Text(
                    item.refDocNo != null
                        ? '${item.refDocCode ?? ''} ${item.refDocNo}'.trim()
                        : '-',
                    style: const TextStyle(fontSize: 12),
                  )),
                  DataCell(SizedBox(
                    width: 200,
                    child: Text(item.description,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  )),
                  DataCell(Text(_fmt.format(item.totalDebitLc),
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusColor(item.status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(item.status,
                        style: TextStyle(
                            color: _statusColor(item.status),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  )),
                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                    if (isDraft)
                      IconButton(
                        icon: const Icon(Icons.edit, size: 16),
                        tooltip: 'แก้ไข',
                        onPressed: () => widget.onEditPressed(item.id),
                        visualDensity: VisualDensity.compact,
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.visibility, size: 16),
                        tooltip: 'ดู',
                        onPressed: () => widget.onViewPressed(item.id),
                        visualDensity: VisualDensity.compact,
                      ),
                    if (isDraft)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        tooltip: 'ลบ',
                        onPressed: () => _deleteEntry(item.id),
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
