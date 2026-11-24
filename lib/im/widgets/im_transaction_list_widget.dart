import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/im_transaction.dart';
import '../models/im_warehouse.dart';
import '../services/im_transaction_service.dart';
import '../services/im_warehouse_service.dart';
import '../../cd/services/cd_currency_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/widgets/sa_doc_list_kit.dart';
import '../../utils/date_utils.dart';

// หน้ารายการธุรกรรม IM (user design 2026-11-22 — ต้นแบบของ sa_doc_list_kit.dart):
// การ์ดเงื่อนไข ① เอกสาร ② คลัง/คู่ค้า ③ สถานะ ④ ค้นหาเพิ่มเติม + การ์ดรายการแบบการ์ดรายการสินค้า
class ImTransactionListWidget extends StatefulWidget {
  final Function(int) onEditPressed;
  final Function(int) onViewPressed;
  final bool shouldRefresh;
  final VoidCallback onRefreshComplete;
  final bool enableEditButton;

  const ImTransactionListWidget({
    super.key,
    required this.onEditPressed,
    required this.onViewPressed,
    required this.shouldRefresh,
    required this.onRefreshComplete,
    this.enableEditButton = true,
  });

  @override
  State<ImTransactionListWidget> createState() => _ImTransactionListWidgetState();
}

class _ImTransactionListWidgetState extends State<ImTransactionListWidget> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ImTransactionService _service = ImTransactionService();
  final ImWarehouseService _warehouseService = ImWarehouseService();
  final _fmtQty = NumberFormat('#,##0.####');
  final _fmtValue = NumberFormat('#,##0.00');
  final _dateFmt = DocListKit.dateFmt;
  bool _isEnglish = false;

  List<ImTransactionHeader> _rows = [];
  List<ImTransactionHeader> _filteredRows = [];
  List<ModuleDocument> _docTypes = [];
  List<ImWarehouse> _warehouses = [];
  bool _isLoading = false;

  final _searchCtrl = TextEditingController();
  final _partyCtrl = TextEditingController();
  final Set<String> _statuses = {}; // ว่าง = ทุกสถานะ ยกเว้น Deleted
  String? _selectedDocCode;
  int? _selectedWarehouseId;

  late DateTime _dateFrom;
  late DateTime _dateTo;
  String? _preset = 'month'; // ช่วงวันที่สำเร็จรูปที่เลือกอยู่ (null = กำหนดเอง)

  String _sortKey = 'date';
  bool _sortAsc = false;

  bool _collapsed = false;
  static const _collapsedPrefKey = 'im_list_filter_collapsed';

  static const _statusOrder = ['Draft', 'Posted', 'Received', 'Delivered', 'Void', 'Deleted'];

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
  void didUpdateWidget(covariant ImTransactionListWidget old) {
    super.didUpdateWidget(old);
    if (widget.shouldRefresh && !old.shouldRefresh) {
      _fetchRows();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onRefreshComplete();
      });
    }
  }

  void _toggleCollapsed() {
    setState(() => _collapsed = !_collapsed);
    DocListPrefs.saveCollapsed(_collapsedPrefKey, _collapsed);
  }

  Future<void> _initialLoad() async {
    final isEnglish = _isEnglish;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _service.fetchDocTypesByUser(),
        _warehouseService.fetchActiveRows(),
      ]);
      setState(() {
        _docTypes = (results[0] as List<ModuleDocument>).where((d) => d.isDocType).toList();
        _warehouses = results[1] as List<ImWarehouse>;
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

  // สถานะกรองในหน้าจอ (เลือกได้หลายค่า) — เลือก Deleted: ขอ backend รวมเอกสารที่ลบแล้วมาด้วย (include_deleted) ครั้งเดียว
  Future<void> _fetchRows() async {
    final isEnglish = _isEnglish;
    setState(() => _isLoading = true);
    try {
      final rows = await _service.fetchRows(
        docCode: _selectedDocCode,
        warehouseId: _selectedWarehouseId,
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

  // ── เงื่อนไขฝั่งหน้าจอ (คู่ค้า / คำค้น / สถานะ) + เรียงลำดับ ──
  String _partyCode(ImTransactionHeader r) => r.vendorCode ?? r.customerCode ?? '';
  String _partyName(ImTransactionHeader r) {
    final (th, en) = r.vendorCode != null ? (r.vendorNameTh, r.vendorNameEn) : (r.customerNameTh, r.customerNameEn);
    return _isEnglish && (en ?? '').isNotEmpty ? en! : (th ?? '');
  }

  String? _refDocNo(ImTransactionHeader r) {
    for (final s in [r.refPoDocNo, r.refSoDocNo, r.refMoDocNo, r.refImTransactionDocNo, r.refDocNo]) {
      if ((s ?? '').isNotEmpty) return s;
    }
    return null;
  }

  bool _baseMatch(ImTransactionHeader r) {
    final party = _partyCtrl.text.trim().toLowerCase();
    if (party.isNotEmpty &&
        ![_partyCode(r), r.vendorNameTh, r.vendorNameEn, r.customerNameTh, r.customerNameEn]
            .any((s) => (s ?? '').toLowerCase().contains(party))) {
      return false;
    }
    return docKeywordMatch(_searchCtrl.text, [
      r.docNo, r.docCode, r.docNameThai, r.docNameEng, _dateFmt.format(r.docDate),
      r.warehouseCode, r.warehouseNameTh, r.warehouseNameEn, r.toWarehouseCode,
      r.refNo, r.refPoDocNo, r.refSoDocNo, r.refMoDocNo, r.refImTransactionDocNo, r.customerPoNo,
      _partyCode(r), r.vendorNameTh, r.vendorNameEn, r.customerNameTh, r.customerNameEn, r.description, r.status,
    ]);
  }

  bool _statusMatch(ImTransactionHeader r) => _statuses.isEmpty ? r.status != 'Deleted' : _statuses.contains(r.status);

  void _applyFilter() {
    final list = _rows.where((r) => _baseMatch(r) && _statusMatch(r)).toList();
    list.sort((a, b) {
      final c = switch (_sortKey) {
        'docNo' => a.docNo.compareTo(b.docNo),
        'value' => a.totalValueLc.compareTo(b.totalValueLc),
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

  // ── ช่วงวันที่ ──
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
        _selectedDocCode != null ||
        _selectedWarehouseId != null ||
        _dateFrom != a ||
        _dateTo != b ||
        _searchCtrl.text.isNotEmpty ||
        _partyCtrl.text.isNotEmpty;
  }

  void _clearFilters() {
    final serverChanged = _selectedDocCode != null || _selectedWarehouseId != null || _preset != 'month' || _statuses.contains('Deleted');
    setState(() {
      _applyPreset('month');
      _statuses.clear();
      _selectedDocCode = null;
      _selectedWarehouseId = null;
      _searchCtrl.clear();
      _partyCtrl.clear();
      _applyFilter();
    });
    if (serverChanged) _fetchRows();
  }

  void _toggleStatus(String s) {
    // ดึงใหม่เฉพาะเมื่อเลือก/เอาออก Deleted (ต้องให้ backend รวมเอกสารที่ลบแล้ว) — สถานะอื่นกรองในหน้าจอ
    final before = _statuses.contains('Deleted');
    setState(() {
      _statuses.contains(s) ? _statuses.remove(s) : _statuses.add(s);
      _applyFilter();
    });
    if (_statuses.contains('Deleted') != before) _fetchRows();
  }

  String _docTypeLabel(ModuleDocument d) => '${d.docCode} ${_isEnglish && d.docNameEng.isNotEmpty ? d.docNameEng : d.docNameThai}';

  String _rowDocTypeName(ImTransactionHeader row) {
    final name = _isEnglish && (row.docNameEng ?? '').isNotEmpty ? row.docNameEng! : (row.docNameThai ?? '');
    final code = row.docCode ?? '';
    return code.isNotEmpty ? '$code $name' : name;
  }

  String _whName(String? th, String? en) => _isEnglish && (en ?? '').isNotEmpty ? en! : (th ?? '');
  String _warehouseLabel(ImWarehouse w) => '${w.warehouseCode} ${_whName(w.warehouseNameTh, w.warehouseNameEn)}';

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    return docListLayout(context, filterCard: _buildFilterCard(isEnglish), listCard: _buildListCard(isEnglish));
  }

  // ── ① การ์ดเงื่อนไขการค้นหา ──
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
      if (d.docCode == _selectedDocCode) docType = _docTypeLabel(d);
    }
    String? wh;
    for (final w in _warehouses) {
      if (w.id == _selectedWarehouseId) wh = _warehouseLabel(w);
    }

    return DocFilterCard(
      isEnglish: isEnglish,
      countText: countText,
      hasActive: _hasActiveFilters,
      onClear: _clearFilters,
      collapsed: _collapsed,
      onToggleCollapse: _toggleCollapsed,
      flexes: const [12, 10, 11, 10],
      groups: [
        docFilterGroup(1, isEnglish ? 'Document' : 'เอกสาร', [
          docDropdown<String>(
            label: isEnglish ? 'Document Type' : 'ประเภทเอกสาร',
            value: _selectedDocCode,
            allLabel: isEnglish ? 'All' : 'ทั้งหมด',
            items: [for (final d in _docTypes) (d.docCode, _docTypeLabel(d))],
            onChanged: (v) {
              setState(() => _selectedDocCode = v);
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
        docFilterGroup(2, isEnglish ? 'Warehouse / Party' : 'คลัง / คู่ค้า', [
          docDropdown<int>(
            label: isEnglish ? 'Warehouse' : 'คลังสินค้า',
            value: _selectedWarehouseId,
            allLabel: isEnglish ? 'All Warehouses' : 'ทุกคลัง',
            items: [for (final w in _warehouses) (w.id, _warehouseLabel(w))],
            onChanged: (v) {
              setState(() => _selectedWarehouseId = v);
              _fetchRows();
            },
          ),
          docSearchField(_partyCtrl, isEnglish ? 'Customer / Vendor' : 'ลูกค้า / ผู้ขาย', () => setState(_applyFilter)),
        ]),
        docFilterGroup(3, isEnglish ? 'Status' : 'สถานะ', [
          docStatusToggles(
            statuses: _statusOrder,
            label: (s) => imTransactionStatusChipLabel(s, isEnglish),
            selected: _statuses,
            isEnglish: isEnglish,
            // ลบแล้วนับได้เฉพาะตอนเลือก (backend ส่งมาเฉพาะตอนนั้น)
            count: (s) => s == 'Deleted' && !_statuses.contains(s) ? null : base.where((r) => r.status == s).length,
            onToggle: _toggleStatus,
          ),
        ]),
        docFilterGroup(4, isEnglish ? 'More' : 'ค้นหาเพิ่มเติม', [
          docSearchField(
            _searchCtrl,
            isEnglish ? 'Search (doc no. / ref / PO / SO)' : 'ค้นหา (เลขที่ / อ้างอิง / PO / SO)',
            () => setState(_applyFilter),
            tooltip: isEnglish ? 'Doc no. / reference / PO / SO / MO / description' : 'เลขที่เอกสาร / เลขที่อ้างอิง / PO / SO / MO / คำอธิบาย',
          ),
        ]),
      ],
      summary: [
        DocSummaryItem(DocListKit.gDoc, isEnglish ? 'Type' : 'ประเภท', docType ?? (isEnglish ? 'All' : 'ทั้งหมด')),
        DocSummaryItem(DocListKit.gDoc, isEnglish ? 'Date' : 'วันที่', '${_dateFmt.format(_dateFrom)} – ${_dateFmt.format(_dateTo)}'),
        DocSummaryItem(DocListKit.gParty, isEnglish ? 'Warehouse' : 'คลัง', wh ?? (isEnglish ? 'All' : 'ทุกคลัง')),
        if (_partyCtrl.text.trim().isNotEmpty) DocSummaryItem(DocListKit.gParty, isEnglish ? 'Party' : 'คู่ค้า', _partyCtrl.text.trim()),
        DocSummaryItem(DocListKit.gFin, isEnglish ? 'Status' : 'สถานะ',
            _statuses.isEmpty ? (isEnglish ? 'All' : 'ทุกสถานะ') : _statusOrder.where(_statuses.contains).join(', ')),
        if (_searchCtrl.text.trim().isNotEmpty) DocSummaryItem(DocListKit.gMore, isEnglish ? 'Search' : 'ค้นหา', _searchCtrl.text.trim()),
      ],
    );
  }

  // ── ② การ์ดรายการเอกสาร ──
  Widget _buildListCard(bool isEnglish) {
    final counted = _filteredRows.where((r) => r.status != 'Void' && r.status != 'Deleted').toList();
    final sumValue = counted.fold<double>(0, (s, r) => s + r.totalValueLc);
    final drafts = _filteredRows.where((r) => r.status == 'Draft').length;
    final base = CurrencyService.baseCode;

    return DocListCard(
      title: isEnglish ? 'Documents' : 'รายการเอกสาร',
      chips: [if (drafts > 0) docChip(isEnglish ? 'Draft $drafts' : 'ร่าง $drafts', const Color(0xFFE65100), const Color(0xFFFFF0D9))],
      trailing: counted.isEmpty ? null : docTotalLabel(isEnglish ? 'Total value' : 'มูลค่ารวม', sumValue, base),
      columns: [
        DocListColumn('doc', isEnglish ? 'Doc No. / Type' : 'เลขที่ / ประเภท', 200, 1, sortKey: 'docNo'),
        DocListColumn('date', isEnglish ? 'Date' : 'วันที่', 92, 1, sortKey: 'date'),
        DocListColumn('wh', isEnglish ? 'Warehouse' : 'คลังสินค้า', 170, 2),
        DocListColumn('party', isEnglish ? 'Customer / Vendor' : 'ลูกค้า / ผู้ขาย', 0, 2),
        DocListColumn('ref', isEnglish ? 'Reference' : 'อ้างอิง', 140, 2),
        DocListColumn('qty', isEnglish ? 'Total Qty' : 'จำนวนรวม', 96, 3, right: true),
        DocListColumn('value', '${isEnglish ? 'Total Value' : 'มูลค่ารวม'} ($base)', 136, 3, right: true, sortKey: 'value'),
        DocListColumn('status', isEnglish ? 'Status' : 'สถานะ', 96, 0),
        const DocListColumn('act', '', 40, 0),
      ],
      groupTitle: (g) => switch (g) {
        1 => isEnglish ? 'Document' : 'เอกสาร',
        2 => isEnglish ? 'Warehouse / Party / Reference' : 'คลัง / คู่ค้า / อ้างอิง',
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
        'value': docNum(sumValue, _fmtValue, bold: true),
      },
    );
  }

  Widget _cell(ImTransactionHeader r, String key, bool isEnglish) {
    switch (key) {
      case 'doc':
        return docTwoLine(r.docNo, _rowDocTypeName(r), aColor: DocListKit.docNoColor);
      case 'date':
        return Text(_dateFmt.format(r.docDate), style: DocListKit.numStyle);
      case 'wh':
        final code = r.warehouseCode ?? '';
        if ((r.toWarehouseCode ?? '').isNotEmpty) {
          return docTwoLine('$code → ${r.toWarehouseCode}', '${isEnglish ? 'to' : 'ไป'} ${_whName(r.toWarehouseNameTh, r.toWarehouseNameEn)}');
        }
        return docTwoLine(code, _whName(r.warehouseNameTh, r.warehouseNameEn));
      case 'party':
        final code = _partyCode(r);
        return code.isEmpty ? docDash : docTwoLine(code, _partyName(r));
      case 'ref':
        final doc = _refDocNo(r);
        final ref = (r.refNo ?? '').trim();
        if (doc == null && ref.isEmpty) return docDash;
        if (doc != null && ref.isNotEmpty && ref != doc) return docTwoLine(doc, ref);
        return Text(doc ?? ref, maxLines: 1, overflow: TextOverflow.ellipsis);
      case 'qty':
        return docNum(r.totalQty, _fmtQty);
      case 'value':
        return docNum(r.totalValueLc, _fmtValue, dashZero: true);
      case 'status':
        return docStatusBadge(r.status, label: imTransactionStatusLabel(r.status, isEnglish));
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
