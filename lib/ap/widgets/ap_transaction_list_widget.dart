import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/ap_transaction.dart';
import '../services/ap_transaction_service.dart';
import '../../gl/models/gl_dimension.dart';
import '../../gl/services/gl_dimension_service.dart';
import '../../gl/widgets/gl_dimension_picker_field.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/models/sa_user_branch.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/widgets/sa_doc_list_kit.dart';
import '../../cd/models/cd_branch.dart';
import '../../cd/services/cd_branch_service.dart';
import '../../cd/services/cd_currency_service.dart';

// หน้ารายการธุรกรรม AP — แบบเดียวกับหน้ารายการ IM (sa_doc_list_kit.dart):
// ① เอกสาร ② ผู้ขาย/สาขา ③ สถานะ ④ ค้นหาเพิ่มเติม (+ มิติ) / ตาราง: เอกสาร | ผู้ขาย/อ้างอิง | ยอด
class ApTransactionListWidget extends StatefulWidget {
  final Function(int) onEditPressed;
  final Function(int) onViewPressed;
  final bool shouldRefresh;
  final VoidCallback onRefreshComplete;
  final bool enableEditButton;

  const ApTransactionListWidget({
    super.key,
    required this.onEditPressed,
    required this.onViewPressed,
    required this.shouldRefresh,
    required this.onRefreshComplete,
    this.enableEditButton = true,
  });

  @override
  State<ApTransactionListWidget> createState() => _ApTransactionListWidgetState();
}

class _ApTransactionListWidgetState extends State<ApTransactionListWidget> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final ApTransactionService _service = ApTransactionService();
  final GlDimensionService _dimService = GlDimensionService();
  final BranchService _branchService = BranchService();
  final _fmt = NumberFormat('#,##0.00');
  final _dateFmt = DocListKit.dateFmt;
  bool _isEnglish = false;

  // _rows = จาก server (ประเภท + ช่วงวันที่ + สาขา + มิติ) / _filteredRows = หลังกรองในหน้าจอ (สถานะ + ผู้ขาย + คำค้น)
  List<ApTransactionHeader> _rows = [];
  List<ApTransactionHeader> _filteredRows = [];
  List<ModuleDocument> _docTypes = [];
  bool _isLoading = false;

  final _searchCtrl = TextEditingController();
  final _partyCtrl = TextEditingController();
  final Set<String> _statuses = {};
  String? _selectedDocType;
  List<UserBranch> _allowedBranches = [];
  int? _selectedBranchId;
  List<Branch> _allBranches = [];
  List<GlDimensionType> _dimTypes = [];
  final Map<String, List<GlDimensionValue>> _dimValues = {};
  final Map<int, int?> _dimSelections = {}; // slotNo → dimValueId

  late DateTime _dateFrom;
  late DateTime _dateTo;
  String? _preset = 'month';

  String _sortKey = 'date';
  bool _sortAsc = false;
  bool _collapsed = false;
  static const _collapsedPrefKey = 'ap_list_filter_collapsed';
  static const _statusOrder = ['Draft', 'Submitted', 'Approved', 'Posted', 'Void', 'Deleted'];

  @override
  void initState() {
    super.initState();
    _applyPreset('month');
    DocListPrefs.loadCollapsed(_collapsedPrefKey).then((v) {
      if (mounted && v != _collapsed) setState(() => _collapsed = v);
    });
    _initialLoad();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _partyCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ApTransactionListWidget old) {
    super.didUpdateWidget(old);
    if (widget.shouldRefresh && !old.shouldRefresh) {
      _fetchRows();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onRefreshComplete();
      });
    }
  }

  int? get _defaultBranchId => _allowedBranches.length == 1 ? _allowedBranches.first.branchId : null;

  Future<void> _initialLoad() async {
    final isEnglish = _isEnglish;
    setState(() => _isLoading = true);
    _allowedBranches = AuthService().allowedBranches;
    _selectedBranchId = _defaultBranchId;
    try {
      final results = await Future.wait([
        _service.fetchDocTypesByUser(),
        _dimService.fetchActiveTypes(),
        _branchService.fetchRows(),
      ]);
      final types = results[1] as List<GlDimensionType>;
      final valResults = await Future.wait(types.map((t) => _dimService.fetchValuesByType(t.typeCode)));
      setState(() {
        _docTypes = (results[0] as List<ModuleDocument>).where((d) => d.isDocType).toList();
        _dimTypes = types;
        for (int i = 0; i < types.length; i++) {
          _dimValues[types[i].typeCode] = valResults[i];
        }
        _allBranches = results[2] as List<Branch>;
      });
      await _fetchRows();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
      }
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
        dateFrom: DateFormat('yyyy-MM-dd').format(_dateFrom),
        dateTo: DateFormat('yyyy-MM-dd').format(_dateTo),
        branchId: _selectedBranchId,
        dim1Id: _dimSelections[1],
        dim2Id: _dimSelections[2],
        dim3Id: _dimSelections[3],
        dim4Id: _dimSelections[4],
        dim5Id: _dimSelections[5],
        includeDeleted: _statuses.contains('Deleted'),
      );
      setState(() {
        _rows = rows;
        _applyFilter();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _vendorName(ApTransactionHeader r) =>
      _isEnglish && (r.vendorNameEn ?? '').isNotEmpty ? r.vendorNameEn! : (r.vendorNameTh ?? '');

  bool _baseMatch(ApTransactionHeader r) {
    final party = _partyCtrl.text.trim().toLowerCase();
    if (party.isNotEmpty && ![r.vendorCode, r.vendorNameTh, r.vendorNameEn].any((s) => (s ?? '').toLowerCase().contains(party))) {
      return false;
    }
    return docKeywordMatch(_searchCtrl.text, [
      r.docNo, r.docCode, r.docNameThai, r.docNameEng, _dateFmt.format(r.docDate),
      r.dueDate != null ? _dateFmt.format(r.dueDate!) : null,
      r.vendorCode, r.vendorNameTh, r.vendorNameEn, r.refNo, r.refDocNo, r.description, r.status,
    ]);
  }

  bool _statusMatch(ApTransactionHeader r) => _statuses.isEmpty ? r.status != 'Deleted' : _statuses.contains(r.status);

  void _applyFilter() {
    final list = _rows.where((r) => _baseMatch(r) && _statusMatch(r)).toList();
    list.sort((a, b) {
      final c = switch (_sortKey) {
        'docNo' => a.docNo.compareTo(b.docNo),
        'due' => (a.dueDate ?? DateTime(1900)).compareTo(b.dueDate ?? DateTime(1900)),
        'total' => a.totalAmountLc.compareTo(b.totalAmountLc),
        'balance' => a.balanceAmountLc.compareTo(b.balanceAmountLc),
        _ => a.docDate.compareTo(b.docDate),
      };
      return c != 0 ? (_sortAsc ? c : -c) : b.docNo.compareTo(a.docNo);
    });
    _filteredRows = list;
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

  void _applyPreset(String p) {
    final (a, b) = DocDatePresets.range(p);
    _dateFrom = a;
    _dateTo = b;
    _preset = p;
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
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
        _preset = null;
      });
      _fetchRows();
    }
  }

  bool get _hasActiveFilters {
    final (a, b) = DocDatePresets.range('month');
    return _statuses.isNotEmpty ||
        _selectedDocType != null ||
        _selectedBranchId != _defaultBranchId ||
        _dimSelections.values.any((v) => v != null) ||
        _dateFrom != a ||
        _dateTo != b ||
        _searchCtrl.text.isNotEmpty ||
        _partyCtrl.text.isNotEmpty;
  }

  void _clearFilters() {
    setState(() {
      _applyPreset('month');
      _statuses.clear();
      _selectedDocType = null;
      _selectedBranchId = _defaultBranchId;
      _dimSelections.clear();
      _searchCtrl.clear();
      _partyCtrl.clear();
      _applyFilter();
    });
    _fetchRows();
  }

  void _toggleStatus(String s) {
    final before = _statuses.contains('Deleted');
    setState(() {
      _statuses.contains(s) ? _statuses.remove(s) : _statuses.add(s);
      _applyFilter();
    });
    if (_statuses.contains('Deleted') != before) _fetchRows();
  }

  // UserBranch ไม่มีชื่ออังกฤษ — หาจากรายการสาขาเต็มตามรหัส
  String _branchLabel(UserBranch b) {
    var name = b.branchNameThai;
    if (_isEnglish) {
      for (final x in _allBranches) {
        if (x.id == b.branchId && x.branchNameEng.isNotEmpty) name = x.branchNameEng;
      }
    }
    return '${b.branchCode} $name';
  }

  String _docTypeLabel(ModuleDocument d) => '${d.docCode} ${_isEnglish && d.docNameEng.isNotEmpty ? d.docNameEng : d.docNameThai}';

  String _rowDocTypeName(ApTransactionHeader row) {
    final name = _isEnglish && (row.docNameEng ?? '').isNotEmpty ? row.docNameEng! : (row.docNameThai ?? '');
    final code = row.docCode ?? '';
    return code.isNotEmpty ? '$code $name' : name;
  }

  String _dimTypeName(GlDimensionType t) => _isEnglish && (t.nameEng ?? '').isNotEmpty ? t.nameEng! : t.nameThai;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    return docListLayout(context, filterCard: _buildFilterCard(isEnglish), listCard: _buildListCard(isEnglish));
  }

  Widget _buildFilterCard(bool isEnglish) {
    final visibleAll = _rows.where((r) => r.status != 'Deleted').length;
    final countText = _isLoading
        ? (isEnglish ? 'Loading…' : 'กำลังโหลด…')
        : _hasActiveFilters
            ? (isEnglish ? 'Found ${_filteredRows.length} of $visibleAll' : 'พบ ${_filteredRows.length} จาก $visibleAll รายการ')
            : (isEnglish ? '${_filteredRows.length} rows' : '${_filteredRows.length} รายการ');
    final base = _rows.where(_baseMatch).toList();

    String? docType;
    for (final d in _docTypes) {
      if (d.sysDocType == _selectedDocType) docType = _docTypeLabel(d);
    }
    String? branch;
    for (final b in _allowedBranches) {
      if (b.branchId == _selectedBranchId) branch = _branchLabel(b);
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
      flexes: const [12, 10, 10, 11],
      groups: [
        docFilterGroup(1, isEnglish ? 'Document' : 'เอกสาร', [
          docDropdown<String>(
            label: isEnglish ? 'Document Type' : 'ประเภทเอกสาร',
            value: _selectedDocType,
            allLabel: isEnglish ? 'All' : 'ทั้งหมด',
            items: [for (final d in _docTypes) (d.sysDocType, _docTypeLabel(d))],
            onChanged: (v) {
              setState(() => _selectedDocType = v);
              _fetchRows();
            },
          ),
          Row(children: [
            Expanded(child: docDateField(isEnglish ? 'From Date' : 'จากวันที่', _dateFrom, () => _pickDate(true))),
            const SizedBox(width: 8),
            Expanded(child: docDateField(isEnglish ? 'To Date' : 'ถึงวันที่', _dateTo, () => _pickDate(false))),
          ]),
          docPresetRow(
            selected: _preset,
            isEnglish: isEnglish,
            onPick: (p) {
              setState(() => _applyPreset(p));
              _fetchRows();
            },
          ),
        ]),
        docFilterGroup(2, isEnglish ? 'Vendor / Branch' : 'ผู้ขาย / สาขา', [
          docSearchField(_partyCtrl, isEnglish ? 'Vendor (code / name)' : 'ผู้ขาย (รหัส / ชื่อ)', () => setState(_applyFilter)),
          if (_allowedBranches.length > 1)
            docDropdown<int>(
              label: isEnglish ? 'Branch' : 'สาขา',
              value: _selectedBranchId,
              allLabel: isEnglish ? 'All Branches' : 'ทุกสาขา',
              items: [for (final b in _allowedBranches) (b.branchId, _branchLabel(b))],
              onChanged: (v) {
                setState(() => _selectedBranchId = v);
                _fetchRows();
              },
            ),
        ]),
        docFilterGroup(3, isEnglish ? 'Status' : 'สถานะ', [
          docStatusToggles(
            statuses: _statusOrder,
            selected: _statuses,
            isEnglish: isEnglish,
            count: (s) => s == 'Deleted' && !_statuses.contains(s) ? null : base.where((r) => r.status == s).length,
            onToggle: _toggleStatus,
          ),
        ]),
        docFilterGroup(4, isEnglish ? 'More' : 'ค้นหาเพิ่มเติม', [
          docSearchField(
            _searchCtrl,
            isEnglish ? 'Search (doc no. / ref)' : 'ค้นหา (เลขที่ / อ้างอิง)',
            () => setState(_applyFilter),
            tooltip: isEnglish ? 'Doc no. / reference / description' : 'เลขที่เอกสาร / เลขที่อ้างอิง / คำอธิบาย',
          ),
          for (final t in _dimTypes) _dimPicker(t),
        ]),
      ],
      summary: [
        DocSummaryItem(DocListKit.gDoc, isEnglish ? 'Type' : 'ประเภท', docType ?? (isEnglish ? 'All' : 'ทั้งหมด')),
        DocSummaryItem(DocListKit.gDoc, isEnglish ? 'Date' : 'วันที่', '${_dateFmt.format(_dateFrom)} – ${_dateFmt.format(_dateTo)}'),
        if (_partyCtrl.text.trim().isNotEmpty) DocSummaryItem(DocListKit.gParty, isEnglish ? 'Vendor' : 'ผู้ขาย', _partyCtrl.text.trim()),
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
        _fetchRows();
      },
    );
  }

  Widget _buildListCard(bool isEnglish) {
    final counted = _filteredRows.where((r) => r.status != 'Void' && r.status != 'Deleted').toList();
    double sum(double Function(ApTransactionHeader) f) => counted.fold<double>(0, (s, r) => s + f(r));
    final total = sum((r) => r.totalAmountLc), paid = sum((r) => r.paidAmountLc), balance = sum((r) => r.balanceAmountLc);
    final drafts = _filteredRows.where((r) => r.status == 'Draft').length;
    final base = CurrencyService.baseCode;

    return DocListCard(
      title: isEnglish ? 'Documents' : 'รายการเอกสาร',
      chips: [if (drafts > 0) docChip(isEnglish ? 'Draft $drafts' : 'ร่าง $drafts', const Color(0xFFE65100), const Color(0xFFFFF0D9))],
      trailing: counted.isEmpty ? null : docTotalLabel(isEnglish ? 'Balance' : 'คงเหลือรวม', balance, base),
      columns: [
        DocListColumn('doc', isEnglish ? 'Doc No. / Type' : 'เลขที่ / ประเภท', 200, 1, sortKey: 'docNo'),
        DocListColumn('date', isEnglish ? 'Date' : 'วันที่', 92, 1, sortKey: 'date'),
        DocListColumn('due', isEnglish ? 'Due Date' : 'ครบกำหนด', 92, 1, sortKey: 'due'),
        DocListColumn('party', isEnglish ? 'Vendor' : 'ผู้ขาย', 0, 2),
        DocListColumn('ref', isEnglish ? 'Reference' : 'อ้างอิง', 130, 2),
        DocListColumn('total', '${isEnglish ? 'Total' : 'ยอดรวม'} ($base)', 124, 3, right: true, sortKey: 'total'),
        DocListColumn('paid', isEnglish ? 'Paid' : 'ชำระแล้ว', 112, 3, right: true),
        DocListColumn('balance', isEnglish ? 'Balance' : 'คงเหลือ', 120, 3, right: true, sortKey: 'balance'),
        DocListColumn('status', isEnglish ? 'Status' : 'สถานะ', 84, 0),
        const DocListColumn('act', '', 40, 0),
      ],
      groupTitle: (g) => switch (g) {
        1 => isEnglish ? 'Document' : 'เอกสาร',
        2 => isEnglish ? 'Vendor / Reference' : 'ผู้ขาย / อ้างอิง',
        _ => isEnglish ? 'Amounts' : 'ยอด',
      },
      rowCount: _filteredRows.length,
      loading: _isLoading,
      emptyText: _rows.isEmpty
          ? (isEnglish ? 'No documents in this date range' : 'ไม่พบเอกสารในช่วงวันที่นี้')
          : (isEnglish ? 'No documents match the criteria — try a wider date range or clear filters'
              : 'ไม่พบเอกสารที่ตรงกับเงื่อนไข — ลองขยายช่วงวันที่หรือล้างเงื่อนไข'),
      sortKey: _sortKey,
      sortAsc: _sortAsc,
      onSort: _setSort,
      onTap: (n) {
        final r = _filteredRows[n];
        r.status == 'Draft' && widget.enableEditButton ? widget.onEditPressed(r.id) : widget.onViewPressed(r.id);
      },
      cell: (n, key) => _cell(_filteredRows[n], key, isEnglish),
      footer: {
        'doc': docFooterCount(counted.length, isEnglish, exclude: isEnglish ? '(excl. Void / deleted)' : '(ไม่นับ Void / ลบแล้ว)'),
        'total': docNum(total, _fmt, bold: true),
        'paid': docNum(paid, _fmt, bold: true),
        'balance': docNum(balance, _fmt, bold: true),
      },
    );
  }

  Widget _cell(ApTransactionHeader r, String key, bool isEnglish) {
    switch (key) {
      case 'doc':
        return docTwoLine(r.docNo, _rowDocTypeName(r), aColor: DocListKit.docNoColor);
      case 'date':
        return Text(_dateFmt.format(r.docDate), style: DocListKit.numStyle);
      case 'due':
        return r.sysDocType == apDocTypePurchaseInvoice && r.dueDate != null ? Text(_dateFmt.format(r.dueDate!), style: DocListKit.numStyle) : docDash;
      case 'party':
        return (r.vendorCode ?? '').isEmpty ? docDash : docTwoLine(r.vendorCode!, _vendorName(r));
      case 'ref':
        final ref = (r.refNo ?? '').trim();
        return ref.isEmpty ? docDash : Text(ref, maxLines: 1, overflow: TextOverflow.ellipsis);
      case 'total':
        return docNum(r.totalAmountLc, _fmt);
      case 'paid':
        return docNum(r.paidAmountLc, _fmt, dashZero: true);
      case 'balance':
        return docNum(r.balanceAmountLc, _fmt, bold: r.balanceAmountLc != 0, color: r.balanceAmountLc > 0 ? const Color(0xFF1E4F8F) : null);
      case 'status':
        return docStatusBadge(r.status);
      case 'act':
        final editable = r.status == 'Draft' && widget.enableEditButton;
        return Tooltip(
          message: editable ? (isEnglish ? 'Edit' : 'แก้ไข') : (isEnglish ? 'View' : 'ดู'),
          child: Icon(editable ? Icons.edit_outlined : Icons.visibility_outlined, size: 18, color: DocListKit.accent),
        );
    }
    return const SizedBox.shrink();
  }
}
