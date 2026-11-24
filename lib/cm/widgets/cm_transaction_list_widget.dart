import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/cm_transaction.dart';
import '../services/cm_transaction_service.dart';
import '../../cd/services/cd_currency_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/widgets/sa_doc_list_kit.dart';
import '../../utils/date_utils.dart';

// หน้ารายการธุรกรรม CM — แบบเดียวกับหน้ารายการ IM (sa_doc_list_kit.dart):
// ① เอกสาร ② คู่ค้า/ธนาคาร ③ สถานะ ④ ค้นหาเพิ่มเติม / ตาราง: เอกสาร | บัญชีธนาคาร/คู่ค้า/อ้างอิง | ยอด
class CmTransactionListWidget extends StatefulWidget {
  final void Function(int id, int? sysDocType) onEditPressed;
  final void Function(int id, int? sysDocType) onViewPressed;
  final bool shouldRefresh;
  final VoidCallback onRefreshComplete;
  final bool enableEditButton;

  const CmTransactionListWidget({
    super.key,
    required this.onEditPressed,
    required this.onViewPressed,
    required this.shouldRefresh,
    required this.onRefreshComplete,
    this.enableEditButton = true,
  });

  @override
  State<CmTransactionListWidget> createState() => _CmTransactionListWidgetState();
}

class _CmTransactionListWidgetState extends State<CmTransactionListWidget> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final CmTransactionService _service = CmTransactionService();
  final _fmt = NumberFormat('#,##0.00');
  final _dateFmt = DocListKit.dateFmt;
  bool _isEnglish = false;

  List<CmTransactionHeader> _rows = [];
  List<CmTransactionHeader> _filteredRows = [];
  List<ModuleDocument> _docTypes = [];
  bool _isLoading = false;

  final _searchCtrl = TextEditingController();
  final _partyCtrl = TextEditingController();
  final Set<String> _statuses = {};
  String? _selectedDocType;

  late DateTime _dateFrom;
  late DateTime _dateTo;
  String? _preset = 'month';

  String _sortKey = 'date';
  bool _sortAsc = false;
  bool _collapsed = false;
  static const _collapsedPrefKey = 'cm_list_filter_collapsed';
  // Pending/Cleared/Bounced = เช็ค/รายการรับ-จ่ายจาก AR/AP (มุมมองอ่านอย่างเดียว)
  static const _statusOrder = ['Draft', 'Submitted', 'Approved', 'Posted', 'Pending', 'Cleared', 'Bounced', 'Void', 'Deleted'];

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
        dateFrom: formatLocalDate(_dateFrom),
        dateTo: formatLocalDate(_dateTo),
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

  String _bankName(String? th, String? en) => _isEnglish && (en ?? '').isNotEmpty ? en! : (th ?? '');

  bool _baseMatch(CmTransactionHeader r) {
    final party = _partyCtrl.text.trim().toLowerCase();
    if (party.isNotEmpty &&
        ![r.partyCode, r.counterpartyName, r.bankAccountNumber, r.bankName, r.bankNameEng, r.fromAccountNumber, r.fromBankName,
          r.toAccountNumber, r.toBankName]
            .any((s) => (s ?? '').toLowerCase().contains(party))) {
      return false;
    }
    return docKeywordMatch(_searchCtrl.text, [
      r.docNo, r.docCode, r.docNameThai, r.docNameEng, _dateFmt.format(r.docDate),
      r.partyCode, r.counterpartyName, r.refNo, r.description, r.status,
    ]);
  }

  bool _statusMatch(CmTransactionHeader r) => _statuses.isEmpty ? r.status != 'Deleted' : _statuses.contains(r.status);

  void _applyFilter() {
    final list = _rows.where((r) => _baseMatch(r) && _statusMatch(r)).toList();
    list.sort((a, b) {
      final c = switch (_sortKey) {
        'docNo' => a.docNo.compareTo(b.docNo),
        'total' => a.totalAmountLc.compareTo(b.totalAmountLc),
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

  String _docTypeLabel(ModuleDocument d) => '${d.docCode} ${_isEnglish && d.docNameEng.isNotEmpty ? d.docNameEng : d.docNameThai}';

  String _rowDocTypeName(CmTransactionHeader row) {
    final name = _isEnglish && (row.docNameEng ?? '').isNotEmpty ? row.docNameEng! : (row.docNameThai ?? '');
    final code = row.docCode ?? '';
    return code.isNotEmpty ? '$code $name' : name;
  }

  // รายการรับ/จ่ายจาก AR/AP (อ่านอย่างเดียว) เปิดดูเสมอ; ร่าง/รออนุมัติ/อนุมัติแล้ว เปิดแบบมีปุ่มดำเนินการ
  bool _isReadOnlyType(CmTransactionHeader r) => r.sysDocType != null && cmReadOnlyDocTypes.contains(r.sysDocType);
  bool _isEditable(CmTransactionHeader r) => !_isReadOnlyType(r) && r.status == 'Draft' && widget.enableEditButton;
  bool _openForAction(CmTransactionHeader r) =>
      !_isReadOnlyType(r) && (r.status == 'Draft' || r.status == 'Submitted' || r.status == 'Approved');

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
      flexes: const [12, 10, 13, 10],
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
        docFilterGroup(2, isEnglish ? 'Counterparty / Bank' : 'คู่ค้า / ธนาคาร', [
          docSearchField(_partyCtrl, isEnglish ? 'Counterparty / bank account' : 'คู่ค้า / บัญชีธนาคาร', () => setState(_applyFilter),
              tooltip: isEnglish ? 'Counterparty code or name, bank account no. or bank name' : 'รหัสหรือชื่อคู่ค้า เลขที่บัญชี หรือชื่อธนาคาร'),
        ]),
        docFilterGroup(3, isEnglish ? 'Status' : 'สถานะ', [
          docStatusToggles(
            statuses: _statusOrder,
            label: (s) => cmTransactionStatusLabel(s, isEnglish),
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
        ]),
      ],
      summary: [
        DocSummaryItem(DocListKit.gDoc, isEnglish ? 'Type' : 'ประเภท', docType ?? (isEnglish ? 'All' : 'ทั้งหมด')),
        DocSummaryItem(DocListKit.gDoc, isEnglish ? 'Date' : 'วันที่', '${_dateFmt.format(_dateFrom)} – ${_dateFmt.format(_dateTo)}'),
        if (_partyCtrl.text.trim().isNotEmpty) DocSummaryItem(DocListKit.gParty, isEnglish ? 'Counterparty' : 'คู่ค้า', _partyCtrl.text.trim()),
        DocSummaryItem(DocListKit.gFin, isEnglish ? 'Status' : 'สถานะ',
            _statuses.isEmpty ? (isEnglish ? 'All' : 'ทุกสถานะ') : _statusOrder.where(_statuses.contains).join(', ')),
        if (_searchCtrl.text.trim().isNotEmpty) DocSummaryItem(DocListKit.gMore, isEnglish ? 'Search' : 'ค้นหา', _searchCtrl.text.trim()),
      ],
    );
  }

  Widget _buildListCard(bool isEnglish) {
    final counted = _filteredRows.where((r) => r.status != 'Void' && r.status != 'Deleted').toList();
    final total = counted.fold<double>(0, (s, r) => s + r.totalAmountLc);
    final drafts = _filteredRows.where((r) => r.status == 'Draft').length;
    final base = CurrencyService.baseCode;

    return DocListCard(
      title: isEnglish ? 'Documents' : 'รายการเอกสาร',
      chips: [if (drafts > 0) docChip(isEnglish ? 'Draft $drafts' : 'ร่าง $drafts', const Color(0xFFE65100), const Color(0xFFFFF0D9))],
      trailing: counted.isEmpty ? null : docTotalLabel(isEnglish ? 'Total' : 'ยอดรวม', total, base),
      columns: [
        DocListColumn('doc', isEnglish ? 'Doc No. / Type' : 'เลขที่ / ประเภท', 210, 1, sortKey: 'docNo'),
        DocListColumn('date', isEnglish ? 'Date' : 'วันที่', 92, 1, sortKey: 'date'),
        DocListColumn('bank', isEnglish ? 'Bank Account' : 'บัญชีธนาคาร', 190, 2),
        DocListColumn('party', isEnglish ? 'Counterparty' : 'คู่ค้า', 0, 2),
        DocListColumn('ref', isEnglish ? 'Reference' : 'อ้างอิง', 120, 2),
        DocListColumn('total', '${isEnglish ? 'Total' : 'ยอดรวม'} ($base)', 128, 3, right: true, sortKey: 'total'),
        DocListColumn('balance', isEnglish ? 'Balance' : 'คงเหลือ', 116, 3, right: true),
        DocListColumn('status', isEnglish ? 'Status' : 'สถานะ', 92, 0),
        const DocListColumn('act', '', 40, 0),
      ],
      groupTitle: (g) => switch (g) {
        1 => isEnglish ? 'Document' : 'เอกสาร',
        2 => isEnglish ? 'Bank / Counterparty / Reference' : 'ธนาคาร / คู่ค้า / อ้างอิง',
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
        _openForAction(r) && widget.enableEditButton ? widget.onEditPressed(r.id, r.sysDocType) : widget.onViewPressed(r.id, r.sysDocType);
      },
      cell: (n, key) => _cell(_filteredRows[n], key, isEnglish),
      footer: {
        'doc': docFooterCount(counted.length, isEnglish, exclude: isEnglish ? '(excl. Void / deleted)' : '(ไม่นับ Void / ลบแล้ว)'),
        'total': docNum(total, _fmt, bold: true),
      },
    );
  }

  Widget _cell(CmTransactionHeader r, String key, bool isEnglish) {
    switch (key) {
      case 'doc':
        return docTwoLine(r.docNo, _rowDocTypeName(r), aColor: DocListKit.docNoColor);
      case 'date':
        return Text(_dateFmt.format(r.docDate), style: DocListKit.numStyle);
      case 'bank':
        if ((r.fromAccountNumber ?? '').isNotEmpty || (r.toAccountNumber ?? '').isNotEmpty) {
          return docTwoLine('${r.fromAccountNumber ?? '-'} → ${r.toAccountNumber ?? '-'}',
              '${_bankName(r.fromBankName, r.fromBankNameEng)} → ${_bankName(r.toBankName, r.toBankNameEng)}');
        }
        if ((r.bankAccountNumber ?? '').isEmpty) return docDash;
        return docTwoLine(r.bankAccountNumber!, _bankName(r.bankName, r.bankNameEng));
      case 'party':
        final name = (r.counterpartyName ?? '').trim();
        final code = (r.partyCode ?? '').trim();
        if (name.isEmpty && code.isEmpty) return docDash;
        return code.isEmpty ? Text(name, maxLines: 1, overflow: TextOverflow.ellipsis) : docTwoLine(code, name);
      case 'ref':
        final ref = (r.refNo ?? '').trim();
        return ref.isEmpty ? docDash : Text(ref, maxLines: 1, overflow: TextOverflow.ellipsis);
      case 'total':
        return docNum(r.totalAmountLc, _fmt);
      case 'balance':
        // คงเหลือมีความหมายเฉพาะเบิกเงินสดย่อย (ยอดที่ยังไม่เบิกคืน)
        return r.sysDocType == cmDocTypePettyCashVoucher
            ? docNum(r.balanceAmountLc, _fmt, color: r.balanceAmountLc > 0 ? const Color(0xFF1E4F8F) : null)
            : const Align(alignment: Alignment.centerRight, child: docDash);
      case 'status':
        return docStatusBadge(r.status, label: cmTransactionStatusLabel(r.status, isEnglish));
      case 'act':
        final editable = _isEditable(r);
        return Tooltip(
          message: editable ? (isEnglish ? 'Edit' : 'แก้ไข') : (isEnglish ? 'View' : 'ดู'),
          child: Icon(editable ? Icons.edit_outlined : Icons.visibility_outlined, size: 18, color: DocListKit.accent),
        );
    }
    return const SizedBox.shrink();
  }
}
