import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/models/sa_user_branch.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/widgets/sa_doc_list_kit.dart';
import '../../cd/services/cd_currency_service.dart';
import '../models/gl_dimension.dart';
import '../models/gl_entry.dart';
import '../models/gl_period.dart';
import '../services/gl_dimension_service.dart';
import '../services/gl_entry_service.dart';
import '../services/gl_period_service.dart';
import '../widgets/gl_dimension_picker_field.dart';
import '../../sa/widgets/sa_document_reverse_widgets.dart';

// หน้ารายการบันทึกบัญชี (GL) — แบบเดียวกับหน้ารายการ IM (sa_doc_list_kit.dart):
// ① เอกสาร/งวด ② สาขา/อ้างอิง ③ สถานะ ④ ค้นหาเพิ่มเติม (+ มิติ) / ตาราง: เอกสาร | อ้างอิง/คำอธิบาย | เดบิต/เครดิต
// GL เลือกตามปีบัญชี/งวด (ไม่ใช่ช่วงวันที่) และ backend ส่งรายการที่ลบแล้วมาด้วย — กรองสถานะในหน้าจอทั้งหมด
class GlEntryListWidget extends StatefulWidget {
  final Function(int) onEditPressed;
  final Function(int) onViewPressed;
  final bool shouldRefresh;
  final VoidCallback onRefreshComplete;
  final bool enableEditButton;
  final bool enableDeleteButton;

  const GlEntryListWidget({
    super.key,
    required this.onEditPressed,
    required this.onViewPressed,
    required this.shouldRefresh,
    required this.onRefreshComplete,
    this.enableEditButton = true,
    this.enableDeleteButton = true,
  });

  @override
  State<GlEntryListWidget> createState() => _GlEntryListWidgetState();
}

class _GlEntryListWidgetState extends State<GlEntryListWidget> {
  bool _isEnglish = false;
  final GlEntryService _entryService = GlEntryService();
  final PeriodService _periodService = PeriodService();
  final GlDimensionService _dimService = GlDimensionService();
  final _fmt = NumberFormat('#,##0.00');
  final _dateFmt = DocListKit.dateFmt;

  List<GlEntryHeader> _entries = [];
  List<GlEntryHeader> _filteredEntries = [];
  bool _isLoading = false;

  List<ModuleDocument> _allowedDocs = [];
  Set<String> _allowedDocCodes = {};

  List<FiscalYear> _fiscalYears = [];
  List<PostingPeriod> _periods = [];

  FiscalYear? _selectedFiscalYear;
  PostingPeriod? _selectedPeriod;
  PostingPeriod? _defaultPeriod;
  String? _selectedDocCode;
  final Set<String> _statuses = {};
  List<UserBranch> _allowedBranches = [];
  int? _selectedBranchId;
  List<GlDimensionType> _dimTypes = [];
  final Map<String, List<GlDimensionValue>> _dimValues = {};
  final Map<int, int?> _dimSelections = {}; // slotNo → dimValueId
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _refCtrl = TextEditingController();

  String _sortKey = 'date';
  bool _sortAsc = false;
  bool _collapsed = false;
  static const _collapsedPrefKey = 'gl_list_filter_collapsed';
  static const _statusOrder = ['Draft', 'Posted', 'Void', 'Deleted'];

  @override
  void initState() {
    super.initState();
    DocListPrefs.loadCollapsed(_collapsedPrefKey).then((v) {
      if (mounted && v != _collapsed) setState(() => _collapsed = v);
    });
    _initialLoad();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _refCtrl.dispose();
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
      final allowedDocs = (results[1] as List<ModuleDocument>).where((d) => d.isDocType).toList();
      final types = results[2] as List<GlDimensionType>;
      final valResults = await Future.wait(types.map((t) => _dimService.fetchValuesByType(t.typeCode)));
      setState(() {
        _allowedDocs = allowedDocs;
        _allowedDocCodes = allowedDocs.map((d) => d.docCode).toSet();
        _fiscalYears = fys;
        _dimTypes = types;
        for (int i = 0; i < types.length; i++) {
          _dimValues[types[i].typeCode] = valResults[i];
        }
      });

      if (fys.isNotEmpty) {
        final now = DateTime.now();
        _selectedFiscalYear = fys.firstWhere(
            (fy) =>
                now.isAfter(fy.yearStartDate.subtract(const Duration(days: 1))) &&
                now.isBefore(fy.yearEndDate.add(const Duration(days: 1))),
            orElse: () => fys.first);
        await _fetchPeriods(_selectedFiscalYear!.id);
        _defaultPeriod = _selectedPeriod;
      }
      await _fetchEntries();
    } catch (e) {
      if (mounted) {
        final isEnglish = _isEnglish;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish ? 'Error loading master data: $e' : 'เกิดข้อผิดพลาดในการโหลดข้อมูลหลัก: $e')));
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
        final current = periods.where((p) =>
            now.isAfter(p.periodStartDate.subtract(const Duration(days: 1))) &&
            now.isBefore(p.periodEndDate.add(const Duration(days: 1))));
        _selectedPeriod = current.isNotEmpty ? current.first : (periods.isNotEmpty ? periods.first : null);
      });
    } catch (e) {
      if (mounted) {
        final isEnglish = _isEnglish;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEnglish ? 'Error fetching periods: $e' : 'เกิดข้อผิดพลาดในการโหลดงวดบัญชี: $e')));
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
        final isEnglish = _isEnglish;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEnglish ? 'Error fetching entries: $e' : 'เกิดข้อผิดพลาดในการโหลดรายการ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ประเภทเอกสารที่ผู้ใช้มีสิทธิ์ + สาขา + เลขที่อ้างอิง + คำค้น (ไม่รวมสถานะ — ใช้นับจำนวนบนชิปสถานะ)
  bool _baseMatch(GlEntryHeader item) {
    if (_allowedDocCodes.isNotEmpty && !_allowedDocCodes.contains(item.docCode)) return false;
    if (_selectedDocCode != null && item.docCode != _selectedDocCode) return false;
    if (_selectedBranchId != null && item.branchId != _selectedBranchId) return false;
    final ref = _refCtrl.text.trim().toLowerCase();
    if (ref.isNotEmpty && ![item.refNo, item.refDocCode, item.refDocName, item.refDocNo].any((s) => (s ?? '').toLowerCase().contains(ref))) {
      return false;
    }
    return docKeywordMatch(_searchCtrl.text, [
      item.docCode, item.docName, item.docNo, _dateFmt.format(item.docDate),
      item.refNo, item.refDocCode, item.refDocName, item.refDocNo,
      item.refDocDate != null ? _dateFmt.format(item.refDocDate!) : null, item.description, item.status,
    ]);
  }

  bool _statusMatch(GlEntryHeader r) => _statuses.isEmpty ? r.status != 'Deleted' : _statuses.contains(r.status);

  void _applyFilter() {
    final list = _entries.where((r) => _baseMatch(r) && _statusMatch(r)).toList();
    list.sort((a, b) {
      final c = switch (_sortKey) {
        'docNo' => a.docNo.compareTo(b.docNo),
        'amount' => a.totalDebitLc.compareTo(b.totalDebitLc),
        _ => a.docDate.compareTo(b.docDate),
      };
      return c != 0 ? (_sortAsc ? c : -c) : b.docNo.compareTo(a.docNo);
    });
    _filteredEntries = list;
  }

  void _setSort(String key) {
    setState(() {
      if (_sortKey == key) {
        _sortAsc = !_sortAsc;
      } else {
        _sortKey = key;
        _sortAsc = key == 'docNo';
      }
      _applyFilter();
    });
  }

  Future<void> _deleteEntry(GlEntryHeader item) async {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    final l = AppL10n(isEnglish);
    final reason = await showDocReasonDialog(
      context,
      isEnglish: isEnglish,
      title: l.confirmDelete,
      message: isEnglish
          ? 'Delete entry ${item.docNo}?\nThe entry is kept for audit but cannot be used again.'
          : 'ต้องการลบรายการ ${item.docNo} ใช่หรือไม่?\nระบบจะเก็บรายการไว้เพื่อตรวจสอบ แต่นำกลับมาใช้ต่อไม่ได้',
      confirmLabel: l.delete,
    );
    if (reason == null) return;
    try {
      await _entryService.deleteEntry(item.id, reason);
      _fetchEntries();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Deleted successfully' : 'ลบรายการสำเร็จ')));
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Delete failed: $msg' : 'ลบไม่สำเร็จ: $msg')));
      }
    }
  }

  String _formatPeriodLabel(PostingPeriod p) =>
      '${p.periodName} (${_dateFmt.format(p.periodStartDate)} - ${_dateFmt.format(p.periodEndDate)})';

  bool get _hasActiveFilters =>
      _statuses.isNotEmpty ||
      _selectedDocCode != null ||
      _selectedBranchId != null ||
      _selectedPeriod?.id != _defaultPeriod?.id ||
      _dimSelections.values.any((v) => v != null) ||
      _searchCtrl.text.isNotEmpty ||
      _refCtrl.text.isNotEmpty;

  Future<void> _clearFilters() async {
    final serverChanged = _selectedPeriod?.id != _defaultPeriod?.id || _dimSelections.values.any((v) => v != null);
    setState(() {
      _statuses.clear();
      _selectedDocCode = null;
      _selectedBranchId = null;
      _dimSelections.clear();
      _searchCtrl.clear();
      _refCtrl.clear();
      _applyFilter();
    });
    if (!serverChanged) return;
    final fy = _fiscalYears.where((f) => _defaultPeriod != null && f.id == _defaultPeriod!.fiscalYearId);
    if (fy.isNotEmpty && fy.first.id != _selectedFiscalYear?.id) {
      setState(() => _selectedFiscalYear = fy.first);
      await _fetchPeriods(fy.first.id);
    }
    setState(() => _selectedPeriod = _periods.where((p) => p.id == _defaultPeriod?.id).firstOrNull ?? _selectedPeriod);
    _fetchEntries();
  }

  String _docLabel(ModuleDocument d) => '${d.docCode} ${_isEnglish && d.docNameEng.isNotEmpty ? d.docNameEng : d.docNameThai}';

  // ชื่อประเภทเอกสารของรายการ: ชื่ออังกฤษจากรายการประเภทที่มีสิทธิ์ (รายการบัญชีมีแค่ชื่อเดียว)
  String _rowDocName(GlEntryHeader item) {
    if (_isEnglish) {
      for (final d in _allowedDocs) {
        if (d.docCode == item.docCode && d.docNameEng.isNotEmpty) return '${item.docCode} ${d.docNameEng}';
      }
    }
    return '${item.docCode} ${item.docName}';
  }

  String _dimTypeName(GlDimensionType t) => _isEnglish && (t.nameEng ?? '').isNotEmpty ? t.nameEng! : t.nameThai;

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    return docListLayout(context, filterCard: _buildFilterCard(isEnglish), listCard: _buildListCard(isEnglish));
  }

  Widget _buildFilterCard(bool isEnglish) {
    final visibleAll = _entries.where((r) => r.status != 'Deleted' && (_allowedDocCodes.isEmpty || _allowedDocCodes.contains(r.docCode))).length;
    final countText = _isLoading
        ? (isEnglish ? 'Loading…' : 'กำลังโหลด…')
        : _hasActiveFilters
            ? (isEnglish ? 'Found ${_filteredEntries.length} of $visibleAll' : 'พบ ${_filteredEntries.length} จาก $visibleAll รายการ')
            : (isEnglish ? '${_filteredEntries.length} entries' : '${_filteredEntries.length} รายการ');
    final base = _entries.where(_baseMatch).toList();

    String? branch;
    for (final b in _allowedBranches) {
      if (b.branchId == _selectedBranchId) branch = '${b.branchCode} ${b.branchNameThai}';
    }
    final dimSummary = <String>[];
    for (final t in _dimTypes) {
      final id = _dimSelections[t.slotNo];
      for (final v in _dimValues[t.typeCode] ?? const <GlDimensionValue>[]) {
        if (v.id == id) dimSummary.add('${_dimTypeName(t)}: ${v.valueCode}');
      }
    }

    return DocFilterCard(
      isEnglish: isEnglish,
      countText: countText,
      hasActive: _hasActiveFilters,
      onClear: _clearFilters,
      collapsed: _collapsed,
      onToggleCollapse: () {
        setState(() => _collapsed = !_collapsed);
        DocListPrefs.saveCollapsed(_collapsedPrefKey, _collapsed);
      },
      flexes: const [13, 10, 10, 11],
      groups: [
        docFilterGroup(1, isEnglish ? 'Document / Period' : 'เอกสาร / งวด', [
          docDropdown<String>(
            label: isEnglish ? 'Document Type' : 'ประเภทเอกสาร',
            value: _selectedDocCode,
            allLabel: isEnglish ? 'All' : 'ทั้งหมด',
            items: [for (final d in _allowedDocs) (d.docCode, _docLabel(d))],
            onChanged: (v) => setState(() {
              _selectedDocCode = v;
              _applyFilter();
            }),
          ),
          Row(children: [
            SizedBox(
              width: 110,
              child: DropdownButtonFormField<FiscalYear>(
                value: _selectedFiscalYear,
                isExpanded: true,
                isDense: true,
                decoration: docFieldDec(isEnglish ? 'Fiscal Year' : 'ปีบัญชี'),
                items: [for (final fy in _fiscalYears) DropdownMenuItem(value: fy, child: Text(fy.fyCode, overflow: TextOverflow.ellipsis))],
                onChanged: (val) {
                  if (val == null) return;
                  setState(() {
                    _selectedFiscalYear = val;
                    _selectedPeriod = null;
                    _periods = [];
                  });
                  _fetchPeriods(val.id).then((_) => _fetchEntries());
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: docDropdown<int>(
                label: isEnglish ? 'Period' : 'งวด',
                value: _selectedPeriod?.id,
                allLabel: isEnglish ? 'Whole year' : 'ทั้งปี',
                items: [for (final p in _periods) (p.id, _formatPeriodLabel(p))],
                onChanged: (id) {
                  setState(() => _selectedPeriod = _periods.where((p) => p.id == id).firstOrNull);
                  _fetchEntries();
                },
              ),
            ),
          ]),
        ]),
        docFilterGroup(2, isEnglish ? 'Branch / Reference' : 'สาขา / อ้างอิง', [
          docSearchField(_refCtrl, isEnglish ? 'Reference doc / ref no.' : 'เอกสารอ้างอิง / เลขที่อ้างอิง', () => setState(_applyFilter)),
          if (_allowedBranches.length > 1)
            docDropdown<int>(
              label: isEnglish ? 'Branch' : 'สาขา',
              value: _selectedBranchId,
              allLabel: isEnglish ? 'All Branches' : 'ทุกสาขา',
              items: [for (final b in _allowedBranches) (b.branchId, '${b.branchCode} ${b.branchNameThai}')],
              onChanged: (v) => setState(() {
                _selectedBranchId = v;
                _applyFilter();
              }),
            ),
        ]),
        docFilterGroup(3, isEnglish ? 'Status' : 'สถานะ', [
          docStatusToggles(
            statuses: _statusOrder,
            selected: _statuses,
            isEnglish: isEnglish,
            count: (s) => base.where((r) => r.status == s).length,
            onToggle: (s) => setState(() {
              _statuses.contains(s) ? _statuses.remove(s) : _statuses.add(s);
              _applyFilter();
            }),
          ),
        ]),
        docFilterGroup(4, isEnglish ? 'More' : 'ค้นหาเพิ่มเติม', [
          docSearchField(
            _searchCtrl,
            isEnglish ? 'Search (doc no. / description)' : 'ค้นหา (เลขที่ / คำอธิบาย)',
            () => setState(_applyFilter),
            tooltip: isEnglish ? 'Doc no. / reference / description' : 'เลขที่เอกสาร / เอกสารอ้างอิง / คำอธิบาย',
          ),
          for (final t in _dimTypes) _dimPicker(t),
        ]),
      ],
      summary: [
        DocSummaryItem(DocListKit.gDoc, isEnglish ? 'Type' : 'ประเภท',
            _selectedDocCode == null ? (isEnglish ? 'All' : 'ทั้งหมด') : _allowedDocs.where((d) => d.docCode == _selectedDocCode).map(_docLabel).join()),
        DocSummaryItem(DocListKit.gDoc, isEnglish ? 'Period' : 'งวด',
            '${_selectedFiscalYear?.fyCode ?? ''} ${_selectedPeriod?.periodName ?? (isEnglish ? 'whole year' : 'ทั้งปี')}'),
        if (_refCtrl.text.trim().isNotEmpty) DocSummaryItem(DocListKit.gParty, isEnglish ? 'Reference' : 'อ้างอิง', _refCtrl.text.trim()),
        if (_allowedBranches.length > 1)
          DocSummaryItem(DocListKit.gParty, isEnglish ? 'Branch' : 'สาขา', branch ?? (isEnglish ? 'All' : 'ทุกสาขา')),
        DocSummaryItem(DocListKit.gFin, isEnglish ? 'Status' : 'สถานะ',
            _statuses.isEmpty ? (isEnglish ? 'All' : 'ทุกสถานะ') : _statusOrder.where(_statuses.contains).join(', ')),
        if (_searchCtrl.text.trim().isNotEmpty) DocSummaryItem(DocListKit.gMore, isEnglish ? 'Search' : 'ค้นหา', _searchCtrl.text.trim()),
        if (dimSummary.isNotEmpty) DocSummaryItem(DocListKit.gMore, isEnglish ? 'Dimensions' : 'มิติ', dimSummary.join(', ')),
      ],
    );
  }

  Widget _dimPicker(GlDimensionType t) {
    final vals = _dimValues[t.typeCode] ?? const <GlDimensionValue>[];
    GlDimensionValue? sel;
    for (final v in vals) {
      if (v.id == _dimSelections[t.slotNo]) sel = v;
    }
    return GlDimensionPickerField(
      dimType: t,
      values: vals,
      selected: sel,
      fontSize: DocListKit.fontSize,
      decoration: docFieldDec(_dimTypeName(t)),
      onSelected: (v) {
        setState(() => _dimSelections[t.slotNo] = v?.id);
        _fetchEntries();
      },
    );
  }

  Widget _buildListCard(bool isEnglish) {
    final counted = _filteredEntries.where((r) => r.status != 'Void' && r.status != 'Deleted').toList();
    final debit = counted.fold<double>(0, (s, r) => s + r.totalDebitLc);
    final credit = counted.fold<double>(0, (s, r) => s + r.totalCreditLc);
    final drafts = _filteredEntries.where((r) => r.status == 'Draft').length;
    final base = CurrencyService.baseCode;

    return DocListCard(
      title: isEnglish ? 'Journal Entries' : 'รายการบันทึกบัญชี',
      chips: [if (drafts > 0) docChip(isEnglish ? 'Draft $drafts' : 'ร่าง $drafts', const Color(0xFFE65100), const Color(0xFFFFF0D9))],
      trailing: counted.isEmpty ? null : docTotalLabel(isEnglish ? 'Total debit' : 'เดบิตรวม', debit, base),
      columns: [
        DocListColumn('doc', isEnglish ? 'Doc No. / Type' : 'เลขที่ / ประเภท', 210, 1, sortKey: 'docNo'),
        DocListColumn('date', isEnglish ? 'Date' : 'วันที่', 92, 1, sortKey: 'date'),
        DocListColumn('ref', isEnglish ? 'Reference' : 'อ้างอิง', 170, 2),
        DocListColumn('desc', isEnglish ? 'Description' : 'คำอธิบาย', 0, 2),
        DocListColumn('debit', '${isEnglish ? 'Debit' : 'เดบิต'} ($base)', 128, 3, right: true, sortKey: 'amount'),
        DocListColumn('credit', isEnglish ? 'Credit' : 'เครดิต', 128, 3, right: true),
        DocListColumn('status', isEnglish ? 'Status' : 'สถานะ', 84, 0),
        const DocListColumn('act', '', 68, 0),
      ],
      groupTitle: (g) => switch (g) {
        1 => isEnglish ? 'Document' : 'เอกสาร',
        2 => isEnglish ? 'Reference / Description' : 'อ้างอิง / คำอธิบาย',
        _ => isEnglish ? 'Amounts' : 'ยอด',
      },
      rowCount: _filteredEntries.length,
      loading: _isLoading,
      emptyText: _entries.isEmpty
          ? (isEnglish ? 'No entries in this period' : 'ไม่พบรายการในงวดนี้')
          : (isEnglish ? 'No entries match the criteria — try another period or clear filters'
              : 'ไม่พบรายการที่ตรงกับเงื่อนไข — ลองเลือกงวดอื่นหรือล้างเงื่อนไข'),
      sortKey: _sortKey,
      sortAsc: _sortAsc,
      onSort: _setSort,
      onTap: (n) {
        final r = _filteredEntries[n];
        r.status == 'Draft' && widget.enableEditButton ? widget.onEditPressed(r.id) : widget.onViewPressed(r.id);
      },
      cell: (n, key) => _cell(_filteredEntries[n], key, isEnglish),
      footer: {
        'doc': docFooterCount(counted.length, isEnglish, exclude: isEnglish ? '(excl. Void / deleted)' : '(ไม่นับ Void / ลบแล้ว)'),
        'debit': docNum(debit, _fmt, bold: true),
        'credit': docNum(credit, _fmt, bold: true),
      },
    );
  }

  Widget _cell(GlEntryHeader item, String key, bool isEnglish) {
    switch (key) {
      case 'doc':
        return docTwoLine(item.docNo, _rowDocName(item), aColor: DocListKit.docNoColor);
      case 'date':
        return Text(_dateFmt.format(item.docDate), style: DocListKit.numStyle);
      case 'ref':
        final doc = (item.refDocNo ?? '').isNotEmpty ? '${item.refDocCode ?? ''} ${item.refDocNo}'.trim() : '';
        final ref = item.refNo.trim();
        if (doc.isEmpty && ref.isEmpty) return docDash;
        if (doc.isNotEmpty && ref.isNotEmpty && ref != item.refDocNo) return docTwoLine(doc, ref);
        return Text(doc.isNotEmpty ? doc : ref, maxLines: 1, overflow: TextOverflow.ellipsis);
      case 'desc':
        return item.description.trim().isEmpty ? docDash : Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.25));
      case 'debit':
        return docNum(item.totalDebitLc, _fmt);
      case 'credit':
        return docNum(item.totalCreditLc, _fmt);
      case 'status':
        return docStatusBadge(item.status);
      case 'act':
        final draft = item.status == 'Draft';
        final editable = draft && widget.enableEditButton;
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Tooltip(
            message: editable ? (isEnglish ? 'Edit' : 'แก้ไข') : (isEnglish ? 'View' : 'ดู'),
            child: Icon(editable ? Icons.edit_outlined : Icons.visibility_outlined, size: 18, color: DocListKit.accent),
          ),
          if (draft && widget.enableDeleteButton)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              tooltip: isEnglish ? 'Delete' : 'ลบ',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              onPressed: () => _deleteEntry(item),
            ),
        ]);
    }
    return const SizedBox.shrink();
  }
}
