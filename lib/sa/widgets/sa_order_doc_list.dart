import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../cd/services/cd_currency_service.dart';
import '../services/sa_language_provider.dart';
import 'sa_doc_list_kit.dart';

// หน้ารายการเอกสารสั่งซื้อ/ขาย (ใบสั่งขาย, ใบเสนอราคา, ใบสั่งซื้อ, ใบขอซื้อ) — แบบเดียวกับหน้ารายการ IM (sa_doc_list_kit.dart)
// (ใช้กับใบสั่งผลิตด้วย: คู่ค้า = สินค้าที่ผลิต, ไม่มีคอลัมน์มูลค่า)
// ① เอกสาร (ช่วงวันที่) ② ลูกค้า/ผู้ขาย + คลัง ③ สถานะ ④ ค้นหาเพิ่มเติม / ตาราง: เอกสาร | คู่ค้า/อ้างอิง | ยอด
// แต่ละโมดูลแปลง header ของตัวเองเป็น OrderDocRow แล้วส่งให้วิดเจ็ตนี้

/// แถวของรายการ — ค่าที่หน้ารายการใช้ (แปลงจาก header ของแต่ละโมดูล)
class OrderDocRow {
  final int id;
  final String docNo;
  final DateTime docDate;
  final String status;
  final String? partyCode;
  final String? partyNameTh;
  final String? partyNameEn;
  final String? warehouseCode;
  final String? warehouseNameTh;
  final String? warehouseNameEn;
  final DateTime? dueDate;
  final String? ref; // เลขที่อ้างอิง (เช่น ใบสั่งซื้อลูกค้า)
  final String? person; // ผู้จัดทำ / ผู้ขอ
  final double totalQty;
  final String? qtyUnit; // หน่วยต่อท้ายจำนวน (ใบสั่งผลิต)
  final double valueLc; // ก่อน VAT
  final double? totalLc; // รวม VAT (null = ไม่มีคอลัมน์นี้)
  final String? description;

  const OrderDocRow({
    required this.id,
    required this.docNo,
    required this.docDate,
    required this.status,
    this.partyCode,
    this.partyNameTh,
    this.partyNameEn,
    this.warehouseCode,
    this.warehouseNameTh,
    this.warehouseNameEn,
    this.dueDate,
    this.ref,
    this.person,
    required this.totalQty,
    this.qtyUnit,
    this.valueLc = 0,
    this.totalLc,
    this.description,
  });
}

class OrderDocListConfig {
  final String prefKey; // จำสถานะย่อ/ขยายของการ์ดเงื่อนไข
  final List<String> statuses;
  final String Function(String status, bool isEnglish) statusLabel;
  final Set<String> editableStatuses;
  final String Function(bool en) partyLabel; // ลูกค้า / ผู้ขาย
  final String Function(bool en) docNoLabel;
  final String Function(bool en)? dueLabel; // null = ไม่มีคอลัมน์วันที่ครบกำหนด/ยืนราคา
  final String Function(bool en)? refLabel; // null = ไม่มีคอลัมน์อ้างอิง
  final String Function(bool en)? personLabel; // null = ไม่มีคอลัมน์ผู้จัดทำ/ผู้ขอ
  final String Function(bool en)? valueLabel; // null = ไม่มีคอลัมน์มูลค่า (ใบสั่งผลิต)
  final String Function(bool en)? qtyLabel; // null = จำนวนรวม
  final String Function(bool en) searchTooltip;

  const OrderDocListConfig({
    required this.prefKey,
    required this.statuses,
    required this.statusLabel,
    required this.partyLabel,
    required this.docNoLabel,
    this.valueLabel,
    this.qtyLabel,
    required this.searchTooltip,
    this.editableStatuses = const {'Draft', 'Rejected'},
    this.dueLabel,
    this.refLabel,
    this.personLabel,
  });
}

typedef OrderDocFetch = Future<List<OrderDocRow>> Function({required String dateFrom, required String dateTo, required bool includeDeleted});

class OrderDocListWidget extends StatefulWidget {
  final OrderDocListConfig config;
  final OrderDocFetch fetch;
  final Function(int) onEditPressed;
  final Function(int) onViewPressed;
  final bool shouldRefresh;
  final VoidCallback onRefreshComplete;
  final bool enableEditButton;

  const OrderDocListWidget({
    super.key,
    required this.config,
    required this.fetch,
    required this.onEditPressed,
    required this.onViewPressed,
    required this.shouldRefresh,
    required this.onRefreshComplete,
    this.enableEditButton = true,
  });

  @override
  State<OrderDocListWidget> createState() => _OrderDocListWidgetState();
}

class _OrderDocListWidgetState extends State<OrderDocListWidget> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _fmtQty = NumberFormat('#,##0.####');
  final _fmtValue = NumberFormat('#,##0.00');
  final _dateFmt = DocListKit.dateFmt;
  bool _isEnglish = false;

  List<OrderDocRow> _rows = [];
  List<OrderDocRow> _filteredRows = [];
  bool _isLoading = false;

  final _searchCtrl = TextEditingController();
  final _partyCtrl = TextEditingController();
  final Set<String> _statuses = {};
  String? _warehouseCode;

  late DateTime _dateFrom;
  late DateTime _dateTo;
  String? _preset = 'month';

  String _sortKey = 'date';
  bool _sortAsc = false;
  bool _collapsed = false;

  OrderDocListConfig get _c => widget.config;

  @override
  void initState() {
    super.initState();
    _applyPreset('month');
    DocListPrefs.loadCollapsed(_c.prefKey).then((v) {
      if (mounted && v != _collapsed) setState(() => _collapsed = v);
    });
    _fetchRows();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _partyCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OrderDocListWidget old) {
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
      final rows = await widget.fetch(
        dateFrom: DateFormat('yyyy-MM-dd').format(_dateFrom),
        dateTo: DateFormat('yyyy-MM-dd').format(_dateTo),
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

  String _partyName(OrderDocRow r) => _isEnglish && (r.partyNameEn ?? '').isNotEmpty ? r.partyNameEn! : (r.partyNameTh ?? '');
  String _whName(OrderDocRow r) => _isEnglish && (r.warehouseNameEn ?? '').isNotEmpty ? r.warehouseNameEn! : (r.warehouseNameTh ?? '');

  bool _baseMatch(OrderDocRow r) {
    if (_warehouseCode != null && r.warehouseCode != _warehouseCode) return false;
    final party = _partyCtrl.text.trim().toLowerCase();
    if (party.isNotEmpty && ![r.partyCode, r.partyNameTh, r.partyNameEn].any((s) => (s ?? '').toLowerCase().contains(party))) return false;
    return docKeywordMatch(_searchCtrl.text, [
      r.docNo, _dateFmt.format(r.docDate), r.partyCode, r.partyNameTh, r.partyNameEn, r.warehouseCode, r.warehouseNameTh,
      r.warehouseNameEn, r.ref, r.person, r.description, r.status, _c.statusLabel(r.status, false), _c.statusLabel(r.status, true),
    ]);
  }

  bool _statusMatch(OrderDocRow r) => _statuses.isEmpty ? r.status != 'Deleted' : _statuses.contains(r.status);

  void _applyFilter() {
    final list = _rows.where((r) => _baseMatch(r) && _statusMatch(r)).toList();
    list.sort((a, b) {
      final c = switch (_sortKey) {
        'docNo' => a.docNo.compareTo(b.docNo),
        'due' => (a.dueDate ?? DateTime(1900)).compareTo(b.dueDate ?? DateTime(1900)),
        'value' => a.valueLc.compareTo(b.valueLc),
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
        _warehouseCode != null ||
        _dateFrom != a ||
        _dateTo != b ||
        _searchCtrl.text.isNotEmpty ||
        _partyCtrl.text.isNotEmpty;
  }

  void _clearFilters() {
    final serverChanged = _preset != 'month' || _statuses.contains('Deleted');
    setState(() {
      _applyPreset('month');
      _statuses.clear();
      _warehouseCode = null;
      _searchCtrl.clear();
      _partyCtrl.clear();
      _applyFilter();
    });
    if (serverChanged) _fetchRows();
  }

  void _toggleStatus(String s) {
    final before = _statuses.contains('Deleted');
    setState(() {
      _statuses.contains(s) ? _statuses.remove(s) : _statuses.add(s);
      _applyFilter();
    });
    if (_statuses.contains('Deleted') != before) _fetchRows();
  }

  bool _isEditable(OrderDocRow r) => _c.editableStatuses.contains(r.status) && widget.enableEditButton;

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
    // คลังที่มีในรายการที่โหลดมา (ไม่ต้องโหลดรายการคลังแยก)
    final whs = <String, String>{};
    for (final r in _rows) {
      if ((r.warehouseCode ?? '').isNotEmpty) whs[r.warehouseCode!] = '${r.warehouseCode} ${_whName(r)}';
    }
    final whItems = whs.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return DocFilterCard(
      isEnglish: isEnglish,
      countText: countText,
      hasActive: _hasActiveFilters,
      onClear: _clearFilters,
      collapsed: _collapsed,
      onToggleCollapse: () {
        setState(() => _collapsed = !_collapsed);
        DocListPrefs.saveCollapsed(_c.prefKey, _collapsed);
      },
      flexes: const [11, 10, 13, 10],
      groups: [
        docFilterGroup(1, isEnglish ? 'Document' : 'เอกสาร', [
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
        docFilterGroup(2, '${_c.partyLabel(isEnglish)} / ${isEnglish ? 'Warehouse' : 'คลัง'}', [
          docSearchField(_partyCtrl, '${_c.partyLabel(isEnglish)} (${isEnglish ? 'code / name' : 'รหัส / ชื่อ'})', () => setState(_applyFilter)),
          docDropdown<String>(
            label: isEnglish ? 'Warehouse' : 'คลังสินค้า',
            value: _warehouseCode,
            allLabel: isEnglish ? 'All Warehouses' : 'ทุกคลัง',
            items: [for (final e in whItems) (e.key, e.value)],
            onChanged: (v) => setState(() {
              _warehouseCode = v;
              _applyFilter();
            }),
          ),
        ]),
        docFilterGroup(3, isEnglish ? 'Status' : 'สถานะ', [
          docStatusToggles(
            statuses: _c.statuses,
            selected: _statuses,
            isEnglish: isEnglish,
            label: (s) => _c.statusLabel(s, isEnglish),
            count: (s) => s == 'Deleted' && !_statuses.contains(s) ? null : base.where((r) => r.status == s).length,
            onToggle: _toggleStatus,
          ),
        ]),
        docFilterGroup(4, isEnglish ? 'More' : 'ค้นหาเพิ่มเติม', [
          docSearchField(
            _searchCtrl,
            isEnglish ? 'Search (doc no. / description)' : 'ค้นหา (เลขที่ / คำอธิบาย)',
            () => setState(_applyFilter),
            tooltip: _c.searchTooltip(isEnglish),
          ),
        ]),
      ],
      summary: [
        DocSummaryItem(DocListKit.gDoc, isEnglish ? 'Date' : 'วันที่', '${_dateFmt.format(_dateFrom)} – ${_dateFmt.format(_dateTo)}'),
        if (_partyCtrl.text.trim().isNotEmpty) DocSummaryItem(DocListKit.gParty, _c.partyLabel(isEnglish), _partyCtrl.text.trim()),
        if (_warehouseCode != null) DocSummaryItem(DocListKit.gParty, isEnglish ? 'Warehouse' : 'คลัง', whs[_warehouseCode] ?? _warehouseCode!),
        DocSummaryItem(DocListKit.gFin, isEnglish ? 'Status' : 'สถานะ',
            _statuses.isEmpty ? (isEnglish ? 'All' : 'ทุกสถานะ') : _c.statuses.where(_statuses.contains).map((s) => _c.statusLabel(s, isEnglish)).join(', ')),
        if (_searchCtrl.text.trim().isNotEmpty) DocSummaryItem(DocListKit.gMore, isEnglish ? 'Search' : 'ค้นหา', _searchCtrl.text.trim()),
      ],
    );
  }

  Widget _buildListCard(bool isEnglish) {
    final counted = _filteredRows.where((r) => !const {'Void', 'Cancelled', 'Deleted'}.contains(r.status)).toList();
    final sumValue = counted.fold<double>(0, (s, r) => s + r.valueLc);
    final hasTotal = _rows.any((r) => r.totalLc != null);
    final sumTotal = counted.fold<double>(0, (s, r) => s + (r.totalLc ?? 0));
    final drafts = _filteredRows.where((r) => r.status == 'Draft').length;
    final base = CurrencyService.baseCode;

    return DocListCard(
      title: isEnglish ? 'Documents' : 'รายการเอกสาร',
      chips: [if (drafts > 0) docChip(isEnglish ? 'Draft $drafts' : 'ร่าง $drafts', const Color(0xFFE65100), const Color(0xFFFFF0D9))],
      trailing: counted.isEmpty || _c.valueLabel == null ? null : docTotalLabel(_c.valueLabel!(isEnglish), sumValue, base),
      columns: [
        DocListColumn('doc', _c.docNoLabel(isEnglish), 190, 1, sortKey: 'docNo'),
        DocListColumn('date', isEnglish ? 'Date' : 'วันที่', 92, 1, sortKey: 'date'),
        if (_c.dueLabel != null) DocListColumn('due', _c.dueLabel!(isEnglish), 96, 1, sortKey: 'due'),
        DocListColumn('party', _c.partyLabel(isEnglish), 0, 2),
        if (_c.personLabel != null) DocListColumn('person', _c.personLabel!(isEnglish), 120, 2),
        if (_c.refLabel != null) DocListColumn('ref', _c.refLabel!(isEnglish), 130, 2),
        DocListColumn('qty', _c.qtyLabel?.call(isEnglish) ?? (isEnglish ? 'Total Qty' : 'จำนวนรวม'), _c.valueLabel == null ? 130 : 92, 3, right: true),
        if (_c.valueLabel != null) DocListColumn('value', '${_c.valueLabel!(isEnglish)} ($base)', 132, 3, right: true, sortKey: 'value'),
        if (hasTotal) DocListColumn('total', isEnglish ? 'Incl. VAT' : 'รวม VAT', 124, 3, right: true),
        DocListColumn('status', isEnglish ? 'Status' : 'สถานะ', 128, 0),
        const DocListColumn('act', '', 40, 0),
      ],
      groupTitle: (g) => switch (g) {
        1 => isEnglish ? 'Document' : 'เอกสาร',
        2 => '${_c.partyLabel(isEnglish)} / ${isEnglish ? 'Reference' : 'อ้างอิง'}',
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
        _isEditable(r) ? widget.onEditPressed(r.id) : widget.onViewPressed(r.id);
      },
      cell: (n, key) => _cell(_filteredRows[n], key, isEnglish),
      footer: {
        'doc': docFooterCount(counted.length, isEnglish, exclude: isEnglish ? '(excl. Void / cancelled / deleted)' : '(ไม่นับ Void / ยกเลิก / ลบแล้ว)'),
        if (_c.valueLabel != null) 'value': docNum(sumValue, _fmtValue, bold: true),
        if (hasTotal) 'total': docNum(sumTotal, _fmtValue, bold: true),
      },
    );
  }

  Widget _cell(OrderDocRow r, String key, bool isEnglish) {
    switch (key) {
      case 'doc':
        // บรรทัดสอง = คลังสินค้า
        final wh = (r.warehouseCode ?? '').isEmpty ? '' : '${r.warehouseCode} ${_whName(r)}';
        return docTwoLine(r.docNo, wh, aColor: DocListKit.docNoColor);
      case 'date':
        return Text(_dateFmt.format(r.docDate), style: DocListKit.numStyle);
      case 'due':
        return r.dueDate == null ? docDash : Text(_dateFmt.format(r.dueDate!), style: DocListKit.numStyle);
      case 'party':
        return (r.partyCode ?? '').isEmpty ? docDash : docTwoLine(r.partyCode!, _partyName(r));
      case 'person':
        return (r.person ?? '').isEmpty ? docDash : Text(r.person!, maxLines: 1, overflow: TextOverflow.ellipsis);
      case 'ref':
        return (r.ref ?? '').trim().isEmpty ? docDash : Text(r.ref!, maxLines: 1, overflow: TextOverflow.ellipsis);
      case 'qty':
        if ((r.qtyUnit ?? '').isEmpty) return docNum(r.totalQty, _fmtQty);
        return Text('${_fmtQty.format(r.totalQty)} ${r.qtyUnit}', textAlign: TextAlign.right, maxLines: 1, style: DocListKit.numStyle);
      case 'value':
        return docNum(r.valueLc, _fmtValue);
      case 'total':
        return r.totalLc == null ? docDash : docNum(r.totalLc!, _fmtValue);
      case 'status':
        return docStatusBadge(r.status, label: _c.statusLabel(r.status, isEnglish));
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
