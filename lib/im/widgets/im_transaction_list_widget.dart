import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/im_transaction.dart';
import '../models/im_warehouse.dart';
import '../services/im_transaction_service.dart';
import '../services/im_warehouse_service.dart';
import '../../cd/services/cd_currency_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../utils/date_utils.dart';

// หน้ารายการธุรกรรม IM (user design 2026-11-22) — สไตล์เดียวกับหน้ารายละเอียด:
// การ์ดเงื่อนไข fix ด้านบน (4 กลุ่มสี ① เอกสาร ② คลัง/คู่ค้า ③ สถานะ ④ ค้นหาเพิ่มเติม, ย่อเป็นแถบสรุปได้)
// + การ์ดรายการ (ตารางแบบการ์ดรายการสินค้า: แถบสีกลุ่มเหนือหัวคอลัมน์, แถว 2 บรรทัด, เรียงตามคอลัมน์, แถวรวม)
// ขนาด: ช่อง 40 px / ตัวอักษร 13, ป้ายลอย 12, หัวการ์ด 16 ตัวหนา, หัวคอลัมน์ 12 ตัวหนา
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

// คอลัมน์ของตาราง: width 0 = ยืดตามพื้นที่ที่เหลือ; group 1-3 = แถบสีเหนือหัวคอลัมน์ (0 = ไม่มี)
class _Col {
  final String key;
  final String label;
  final double width;
  final int group;
  final bool right;
  final String? sortKey;
  const _Col(this.key, this.label, this.width, this.group, {this.right = false, this.sortKey});
}

class _ImTransactionListWidgetState extends State<ImTransactionListWidget> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ImTransactionService _service = ImTransactionService();
  final ImWarehouseService _warehouseService = ImWarehouseService();
  final _fmtQty = NumberFormat('#,##0.####');
  final _fmtValue = NumberFormat('#,##0.00');
  final _dateFmt = DateFormat('dd/MM/yyyy');
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

  // ── สี/ขนาด (ตรงกับหน้ารายละเอียด) ──
  static const _gDoc = Color(0xFF1E5AA8);
  static const _gParty = Color(0xFF1F7A4D);
  static const _gFin = Color(0xFFB45309);
  static const _gMore = Color(0xFF5B6B7C);
  static const _hAuto = Color(0xFFE3EEFA);
  static const _ink2 = Color(0xFF4A5562);
  static const _ink3 = Color(0xFF6B7682);
  static const _docNoColor = Color(0xFF0F5C5C);
  static const _rowLine = Color(0xFFEEF1F4);
  static const _groupLine = Color(0xFFDDE3EA);
  static const double _fieldH = 40;
  static const double _fontSize = 13;
  static const double _cardTitleSize = 16;
  static const double _rowH = 44;
  static const double _gap = 8;
  static const _numStyle = TextStyle(fontSize: 13, fontFeatures: [FontFeature.tabularFigures()]);

  static const _statusOrder = ['Draft', 'Posted', 'Received', 'Delivered', 'Void', 'Deleted'];

  @override
  void initState() {
    super.initState();
    _applyPreset('month');
    _loadCollapsed();
    _initialLoad();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _partyCtrl.dispose();
    _hScroll.dispose();
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

  Future<void> _loadCollapsed() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getBool(_collapsedPrefKey) ?? false;
      if (mounted && v != _collapsed) setState(() => _collapsed = v);
    } catch (_) {}
  }

  Future<void> _toggleCollapsed() async {
    setState(() => _collapsed = !_collapsed);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_collapsedPrefKey, _collapsed);
    } catch (_) {}
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
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    final hay = [
      r.docNo,
      r.docCode ?? '',
      r.docNameThai ?? '',
      r.docNameEng ?? '',
      _dateFmt.format(r.docDate),
      r.warehouseCode ?? '',
      r.warehouseNameTh ?? '',
      r.warehouseNameEn ?? '',
      r.toWarehouseCode ?? '',
      r.refNo ?? '',
      r.refPoDocNo ?? '',
      r.refSoDocNo ?? '',
      r.refMoDocNo ?? '',
      r.refImTransactionDocNo ?? '',
      r.customerPoNo ?? '',
      _partyCode(r),
      r.vendorNameTh ?? '',
      r.vendorNameEn ?? '',
      r.customerNameTh ?? '',
      r.customerNameEn ?? '',
      r.description ?? '',
      r.status,
    ].join(' ').toLowerCase();
    return query.split(RegExp(r'\s+')).every(hay.contains);
  }

  bool _statusMatch(ImTransactionHeader r) => _statuses.isEmpty ? r.status != 'Deleted' : _statuses.contains(r.status);

  void _applyFilter() {
    final list = _rows.where((r) => _baseMatch(r) && _statusMatch(r)).toList();
    int cmp(ImTransactionHeader a, ImTransactionHeader b) {
      final c = switch (_sortKey) {
        'docNo' => a.docNo.compareTo(b.docNo),
        'value' => a.totalValueLc.compareTo(b.totalValueLc),
        _ => a.docDate.compareTo(b.docDate),
      };
      return c != 0 ? (_sortAsc ? c : -c) : b.docNo.compareTo(a.docNo);
    }

    list.sort(cmp);
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
  (DateTime, DateTime) _presetRange(String p) {
    final now = DateTime.now();
    final y = now.year, m = now.month;
    switch (p) {
      case 'prev':
        return (DateTime(y, m - 1, 1), DateTime(y, m, 0));
      case 'quarter':
        final q = ((m - 1) ~/ 3) * 3 + 1;
        return (DateTime(y, q, 1), DateTime(y, q + 3, 0));
      case 'year':
        return (DateTime(y, 1, 1), DateTime(y, 12, 31));
      default:
        return (DateTime(y, m, 1), DateTime(y, m + 1, 0));
    }
  }

  void _applyPreset(String p) {
    final (a, b) = _presetRange(p);
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
    final (a, b) = _presetRange('month');
    return _statuses.isNotEmpty ||
        _selectedDocCode != null ||
        _selectedWarehouseId != null ||
        _dateFrom != a ||
        _dateTo != b ||
        _searchCtrl.text.isNotEmpty ||
        _partyCtrl.text.isNotEmpty;
  }

  void _clearFilters() {
    final hadDeleted = _statuses.contains('Deleted');
    final serverChanged = _selectedDocCode != null || _selectedWarehouseId != null || _preset != 'month' || hadDeleted;
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

  // ── ป้าย / สี ──
  (Color, Color) _statusColors(String status) {
    switch (status) {
      case 'Draft':
        return (const Color(0xFFE65100), const Color(0xFFFFF0D9));
      case 'Posted':
        return (const Color(0xFF1E6B3A), const Color(0xFFE6F4EA));
      case 'Received':
      case 'Delivered':
        return (const Color(0xFF1E4F8F), const Color(0xFFE3EEFA));
      case 'Void':
        return (const Color(0xFFB71C1C), const Color(0xFFFDECEA));
      default:
        return (const Color(0xFF5B6B7C), const Color(0xFFEEF0F2));
    }
  }

  String _docTypeLabel(ModuleDocument d) => '${d.docCode} ${_isEnglish && d.docNameEng.isNotEmpty ? d.docNameEng : d.docNameThai}';

  String _rowDocTypeName(ImTransactionHeader row) {
    final name = _isEnglish && (row.docNameEng ?? '').isNotEmpty ? row.docNameEng! : (row.docNameThai ?? '');
    final code = row.docCode ?? '';
    return code.isNotEmpty ? '$code $name' : name;
  }

  String _whName(String? th, String? en) => _isEnglish && (en ?? '').isNotEmpty ? en! : (th ?? '');

  String _warehouseLabel(ImWarehouse w) => '${w.warehouseCode} ${_whName(w.warehouseNameTh, w.warehouseNameEn)}';

  // ── ธีมขนาดตัวอักษร (เหมือน _sizedTheme ของหน้ารายละเอียด) ──
  Widget _sizedTheme(BuildContext context, Widget child) {
    final theme = Theme.of(context);
    TextStyle? sz(TextStyle? s) => (s ?? const TextStyle()).copyWith(fontSize: _fontSize);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.copyWith(
          bodyLarge: sz(theme.textTheme.bodyLarge),
          bodyMedium: sz(theme.textTheme.bodyMedium),
          titleMedium: sz(theme.textTheme.titleMedium),
          titleSmall: sz(theme.textTheme.titleSmall),
        ),
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          labelStyle: const TextStyle(fontSize: _fontSize),
          floatingLabelStyle: const TextStyle(fontSize: 16),
        ),
      ),
      child: child,
    );
  }

  // ช่องสูง 40 พอดีทุกชนิด: ไม่ dense (กรอบขั้นต่ำ 48) + จำกัดความสูง 40 → กรอบถูกบีบลงเหลือ 40; ระยะบนล่าง 4 ไม่บีบข้อความไทยที่ Aa 125%
  InputDecoration _dec(String label, {bool auto = false, Widget? suffixIcon}) => InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: false,
        constraints: const BoxConstraints.tightFor(height: _fieldH),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        suffixIcon: suffixIcon,
        suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 24, maxHeight: 24),
        filled: auto,
        fillColor: _hAuto,
      );

  Widget _groupLabel(int no, String title, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9)),
          child: Text('$no', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 6),
        Flexible(child: Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
      ]);

  Widget _group(int no, String title, Color color, List<Widget> rows) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFBFCFD),
            border: Border.all(color: _groupLine),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(height: 3, color: color),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                _groupLabel(no, title, color),
                for (final r in rows) ...[const SizedBox(height: 10), r],
              ]),
            ),
          ]),
        ),
      );

  Widget _chip(String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg), overflow: TextOverflow.ellipsis),
      );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    // การ์ดเงื่อนไข fix ด้านบน (ไม่เลื่อนตามรายการ) — จอเตี้ย: สูงไม่เกิน 60% แล้วเลื่อนภายในการ์ด
    return _sizedTheme(
      context,
      LayoutBuilder(
        builder: (context, box) => Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: box.maxHeight.isFinite ? box.maxHeight * 0.6 : double.infinity),
              child: SingleChildScrollView(child: _buildFilterCard(isEnglish)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _buildListCard(isEnglish),
            ),
          ),
        ]),
      ),
    );
  }

  // ── ① การ์ดเงื่อนไขการค้นหา ─────────────────────────────────────────────────────────────────
  Widget _buildFilterCard(bool isEnglish) {
    final visibleAll = _rows.where((r) => r.status != 'Deleted').length;
    final countText = _isLoading
        ? (isEnglish ? 'Loading…' : 'กำลังโหลด…')
        : _hasActiveFilters
            ? (isEnglish ? 'Found ${_filteredRows.length} of $visibleAll' : 'พบ ${_filteredRows.length} จาก $visibleAll รายการ')
            : (isEnglish ? '${_filteredRows.length} rows' : '${_filteredRows.length} รายการ');

    // ซ้าย: ชื่อ + ชิปจำนวน (Expanded กินพื้นที่ว่างทั้งหมด) / ขวาสุด: ล้างเงื่อนไข + ย่อ/ขยาย
    // (เดิม Flexible+Spacer แบ่งพื้นที่ว่างคนละครึ่ง ส่วนที่ชิปไม่ใช้เหลือค้างหลังปุ่ม → ปุ่มไม่ชิดขวา)
    final titleRow = Row(children: [
      Expanded(
        child: Row(children: [
          Text(isEnglish ? 'Search Criteria' : 'เงื่อนไขการค้นหา', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: _cardTitleSize)),
          const SizedBox(width: 10),
          Flexible(child: _chip(countText, const Color(0xFF1E4F8F), const Color(0xFFE3EEFA))),
        ]),
      ),
      if (_hasActiveFilters)
        TextButton(
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact, foregroundColor: const Color(0xFF0F6E6E)),
          onPressed: _clearFilters,
          child: Text(isEnglish ? 'Clear filters' : 'ล้างเงื่อนไข', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      const SizedBox(width: 6),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 10), foregroundColor: Colors.blueGrey.shade800),
        icon: Icon(_collapsed ? Icons.expand_more : Icons.expand_less, size: 18),
        label: Text(_collapsed ? (isEnglish ? 'Expand' : 'ขยาย') : (isEnglish ? 'Collapse' : 'ย่อ'), style: const TextStyle(fontSize: 12)),
        onPressed: _toggleCollapsed,
      ),
    ]);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          titleRow,
          const SizedBox(height: 10),
          if (_collapsed) _filterSummary(isEnglish) else _filterGroups(isEnglish),
        ]),
      ),
    );
  }

  Widget _filterGroups(bool isEnglish) {
    final g1 = _group(1, isEnglish ? 'Document' : 'เอกสาร', _gDoc, [
      DropdownButtonFormField<String?>(
        value: _selectedDocCode,
        isExpanded: true,
        isDense: true,
        decoration: _dec(isEnglish ? 'Document Type' : 'ประเภทเอกสาร'),
        items: [
          DropdownMenuItem(value: null, child: Text(isEnglish ? 'All' : 'ทั้งหมด')),
          ..._docTypes.map((d) => DropdownMenuItem(value: d.docCode, child: Text(_docTypeLabel(d), overflow: TextOverflow.ellipsis))),
        ],
        onChanged: (v) {
          setState(() => _selectedDocCode = v);
          _fetchRows();
        },
      ),
      Row(children: [
        Expanded(child: _dateField(isEnglish ? 'From Date' : 'จากวันที่', _dateFrom, () => _pickDate(true))),
        const SizedBox(width: 8),
        Expanded(child: _dateField(isEnglish ? 'To Date' : 'ถึงวันที่', _dateTo, () => _pickDate(false))),
      ]),
      // ช่วงวันที่สำเร็จรูป: บรรทัดเดียวเสมอ — ที่ไม่พอแสดง "…" ชี้เมาส์เห็นชื่อเต็ม
      Row(children: [
        for (final (i, p) in const ['month', 'prev', 'quarter', 'year'].indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          Flexible(
            child: _presetChip(
                p,
                switch (p) {
                  'month' => isEnglish ? 'This month' : 'เดือนนี้',
                  'prev' => isEnglish ? 'Last month' : 'เดือนก่อน',
                  'quarter' => isEnglish ? 'This quarter' : 'ไตรมาสนี้',
                  _ => isEnglish ? 'This year' : 'ปีนี้',
                }),
          ),
        ],
      ]),
    ]);

    final g2 = _group(2, isEnglish ? 'Warehouse / Party' : 'คลัง / คู่ค้า', _gParty, [
      DropdownButtonFormField<int?>(
        value: _selectedWarehouseId,
        isExpanded: true,
        isDense: true,
        decoration: _dec(isEnglish ? 'Warehouse' : 'คลังสินค้า'),
        items: [
          DropdownMenuItem(value: null, child: Text(isEnglish ? 'All Warehouses' : 'ทุกคลัง')),
          ..._warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(_warehouseLabel(w), overflow: TextOverflow.ellipsis))),
        ],
        onChanged: (v) {
          setState(() => _selectedWarehouseId = v);
          _fetchRows();
        },
      ),
      TextField(
        controller: _partyCtrl,
        decoration: _dec(isEnglish ? 'Customer / Vendor' : 'ลูกค้า / ผู้ขาย',
            suffixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF0F6E6E))),
        onChanged: (_) => setState(_applyFilter),
      ),
    ]);

    final base = _rows.where(_baseMatch).toList();
    final g3 = _group(3, isEnglish ? 'Status' : 'สถานะ', _gFin, [
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final s in _statusOrder) _statusToggle(s, base.where((r) => r.status == s).length),
      ]),
      Text(isEnglish ? 'None selected = all except deleted · multiple allowed' : 'ไม่เลือก = ทุกสถานะ ยกเว้นลบแล้ว · เลือกได้หลายสถานะ',
          style: const TextStyle(fontSize: 12, color: _ink3)),
    ]);

    final g4 = _group(4, isEnglish ? 'More' : 'ค้นหาเพิ่มเติม', _gMore, [
      Tooltip(
        message: isEnglish ? 'Doc no. / reference / PO / SO / MO / description' : 'เลขที่เอกสาร / เลขที่อ้างอิง / PO / SO / MO / คำอธิบาย',
        child: TextField(
          controller: _searchCtrl,
          decoration: _dec(isEnglish ? 'Search (doc no. / ref / PO / SO)' : 'ค้นหา (เลขที่ / อ้างอิง / PO / SO)',
              suffixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF0F6E6E))),
          onChanged: (_) => setState(_applyFilter),
        ),
      ),
    ]);

    // จอกว้าง: 4 กลุ่มแถวเดียว / จอกลาง: 2×2 / จอแคบ: เรียงลง
    return LayoutBuilder(builder: (context, c) {
      Widget row(List<(Widget, int)> items) => IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(flex: items[i].$2, child: items[i].$1),
              ],
            ]),
          );
      if (c.maxWidth >= 1150) return row([(g1, 12), (g2, 10), (g3, 11), (g4, 10)]);
      if (c.maxWidth >= 640) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          row([(g1, 1), (g2, 1)]),
          const SizedBox(height: 10),
          row([(g3, 1), (g4, 1)]),
        ]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        g1, const SizedBox(height: 10), g2, const SizedBox(height: 10), g3, const SizedBox(height: 10), g4,
      ]);
    });
  }

  Widget _dateField(String label, DateTime value, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: _dec(label, auto: true, suffixIcon: const Icon(Icons.calendar_today, size: 16, color: Color(0xFF0F6E6E))),
          child: Text(_dateFmt.format(value), maxLines: 1),
        ),
      );

  Widget _presetChip(String p, String label) {
    final on = _preset == p;
    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () {
          setState(() => _applyPreset(p));
          _fetchRows();
        },
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: on ? const Color(0xFFEAF1FB) : Colors.white,
            border: Border.all(color: on ? _gDoc : _groupLine),
            borderRadius: BorderRadius.circular(13),
          ),
          // widthFactor 1 = กว้างตามข้อความ (ไม่ยืดเต็มช่อง) แต่ย่อแล้วตัดเป็น "…" เมื่อที่ไม่พอ
          child: Align(
            widthFactor: 1,
            child: Text(label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: on ? _gDoc : _ink2, fontWeight: on ? FontWeight.w600 : FontWeight.normal)),
          ),
        ),
      ),
    );
  }

  Widget _statusToggle(String s, int count) {
    final on = _statuses.contains(s);
    final (fg, bg) = _statusColors(s);
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () => _toggleStatus(s),
      child: Container(
        height: 30,
        padding: const EdgeInsets.only(left: 8, right: 10),
        decoration: BoxDecoration(
          color: on ? bg : Colors.white,
          border: Border.all(color: on ? fg : _groupLine),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 6),
          Text(s, style: TextStyle(fontSize: 12, color: on ? fg : _ink2, fontWeight: on ? FontWeight.w600 : FontWeight.normal)),
          const SizedBox(width: 6),
          Text(s == 'Deleted' && !on ? '' : '$count', style: _numStyle.copyWith(fontSize: 12, color: on ? fg : _ink3)),
        ]),
      ),
    );
  }

  // แถบสรุปตอนย่อการ์ด — จุดสีบอกกลุ่มที่มา
  Widget _filterSummary(bool isEnglish) {
    Widget item(Color c, String label, String value) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 6),
          Text('$label ', style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700)),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(value, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
          ),
        ]);
    String? docType;
    for (final d in _docTypes) {
      if (d.docCode == _selectedDocCode) docType = _docTypeLabel(d);
    }
    String? wh;
    for (final w in _warehouses) {
      if (w.id == _selectedWarehouseId) wh = _warehouseLabel(w);
    }
    final party = _partyCtrl.text.trim();
    final q = _searchCtrl.text.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFF6F8FA), borderRadius: BorderRadius.circular(4)),
      child: Wrap(spacing: 22, runSpacing: 6, children: [
        item(_gDoc, isEnglish ? 'Type' : 'ประเภท', docType ?? (isEnglish ? 'All' : 'ทั้งหมด')),
        item(_gDoc, isEnglish ? 'Date' : 'วันที่', '${_dateFmt.format(_dateFrom)} – ${_dateFmt.format(_dateTo)}'),
        item(_gParty, isEnglish ? 'Warehouse' : 'คลัง', wh ?? (isEnglish ? 'All' : 'ทุกคลัง')),
        if (party.isNotEmpty) item(_gParty, isEnglish ? 'Party' : 'คู่ค้า', party),
        item(_gFin, isEnglish ? 'Status' : 'สถานะ',
            _statuses.isEmpty ? (isEnglish ? 'All' : 'ทุกสถานะ') : _statusOrder.where(_statuses.contains).join(', ')),
        if (q.isNotEmpty) item(_gMore, isEnglish ? 'Search' : 'ค้นหา', q),
      ]),
    );
  }

  // ── ② การ์ดรายการเอกสาร ─────────────────────────────────────────────────────────────────────
  List<_Col> _cols(bool isEnglish) => [
        _Col('doc', isEnglish ? 'Doc No. / Type' : 'เลขที่ / ประเภท', 200, 1, sortKey: 'docNo'),
        _Col('date', isEnglish ? 'Date' : 'วันที่', 92, 1, sortKey: 'date'),
        _Col('wh', isEnglish ? 'Warehouse' : 'คลังสินค้า', 170, 2),
        _Col('party', isEnglish ? 'Customer / Vendor' : 'ลูกค้า / ผู้ขาย', 0, 2),
        _Col('ref', isEnglish ? 'Reference' : 'อ้างอิง', 140, 2),
        _Col('qty', isEnglish ? 'Total Qty' : 'จำนวนรวม', 96, 3, right: true),
        _Col('value', '${isEnglish ? 'Total Value' : 'มูลค่ารวม'} (${CurrencyService.baseCode})', 136, 3, right: true, sortKey: 'value'),
        _Col('status', isEnglish ? 'Status' : 'สถานะ', 96, 0),
        const _Col('act', '', 40, 0),
      ];

  String _groupTitle(int g, bool isEnglish) => switch (g) {
        1 => isEnglish ? 'Document' : 'เอกสาร',
        2 => isEnglish ? 'Warehouse / Party / Reference' : 'คลัง / คู่ค้า / อ้างอิง',
        _ => isEnglish ? 'Amounts' : 'ยอด',
      };

  Color _groupColor(int g) => g == 1 ? _gDoc : g == 2 ? _gParty : _gFin;

  Widget _buildListCard(bool isEnglish) {
    final counted = _filteredRows.where((r) => r.status != 'Void' && r.status != 'Deleted').toList();
    final sumValue = counted.fold<double>(0, (s, r) => s + r.totalValueLc);
    final drafts = _filteredRows.where((r) => r.status == 'Draft').length;

    final titleRow = Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 6,
      children: [
        Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(isEnglish ? 'Documents' : 'รายการเอกสาร', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: _cardTitleSize)),
          if (drafts > 0) _chip(isEnglish ? 'Draft $drafts' : 'ร่าง $drafts', const Color(0xFFE65100), const Color(0xFFFFF0D9)),
        ]),
        if (counted.isNotEmpty)
          Text.rich(TextSpan(children: [
            TextSpan(text: '${isEnglish ? 'Total value' : 'มูลค่ารวม'} ', style: const TextStyle(fontSize: 12, color: _ink3)),
            TextSpan(text: _fmtValue.format(sumValue), style: _numStyle.copyWith(fontWeight: FontWeight.bold)),
            TextSpan(text: ' ${CurrencyService.baseCode}', style: const TextStyle(fontSize: 12, color: _ink3)),
          ])),
      ],
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          titleRow,
          const SizedBox(height: 10),
          Expanded(child: _buildTable(isEnglish, counted.length, sumValue)),
        ]),
      ),
    );
  }

  final _hScroll = ScrollController();

  Widget _buildTable(bool isEnglish, int countedRows, double sumValue) {
    final cols = _cols(isEnglish);
    final fixed = cols.fold<double>(0, (t, c) => t + c.width) + _gap * (cols.length - 1);
    return LayoutBuilder(builder: (context, cons) {
      final flexW = cons.maxWidth - fixed > 180 ? cons.maxWidth - fixed : 180.0;
      final tableW = fixed + flexW;
      double w(_Col c) => c.width == 0 ? flexW : c.width;
      Widget cells(List<Widget> ws) => Row(children: [
            for (var i = 0; i < cols.length; i++) ...[
              if (i > 0) const SizedBox(width: _gap),
              SizedBox(width: w(cols[i]), child: ws[i]),
            ],
          ]);

      // แถบสีกลุ่มเหนือหัวคอลัมน์ — แบบการ์ดรายการสินค้า
      final groupRow = <Widget>[];
      var i = 0;
      while (i < cols.length) {
        var j = i;
        var span = w(cols[i]);
        while (j + 1 < cols.length && cols[j + 1].group == cols[i].group) {
          j++;
          span += _gap + w(cols[j]);
        }
        if (i > 0) groupRow.add(const SizedBox(width: _gap));
        final g = cols[i].group;
        groupRow.add(SizedBox(
          width: span,
          child: g == 0
              ? null
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(height: 3, decoration: BoxDecoration(color: _groupColor(g), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 3),
                  _groupLabel(g, _groupTitle(g, isEnglish), _groupColor(g)),
                ]),
        ));
        i = j + 1;
      }

      const hdStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _ink2);
      Widget header(_Col c) {
        final text = Text(c.label, style: hdStyle, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: c.right ? TextAlign.right : TextAlign.left);
        if (c.sortKey == null) return text;
        final on = _sortKey == c.sortKey;
        return InkWell(
          onTap: () => _setSort(c.sortKey!),
          child: Row(mainAxisAlignment: c.right ? MainAxisAlignment.end : MainAxisAlignment.start, children: [
            Flexible(child: text),
            const SizedBox(width: 2),
            Icon(on ? (_sortAsc ? Icons.arrow_upward : Icons.arrow_downward) : Icons.unfold_more,
                size: 14, color: on ? const Color(0xFF0F6E6E) : Colors.grey.shade400),
          ]),
        );
      }

      final Widget body;
      if (_isLoading) {
        body = const Center(child: CircularProgressIndicator());
      } else if (_filteredRows.isEmpty) {
        body = Center(
          child: Text(
            _rows.isEmpty
                ? (isEnglish ? 'No documents in this date range' : 'ไม่พบเอกสารในช่วงวันที่นี้')
                : (isEnglish ? 'No documents match the criteria — try a wider date range or clear filters'
                    : 'ไม่พบเอกสารที่ตรงกับเงื่อนไข — ลองขยายช่วงวันที่หรือล้างเงื่อนไข'),
            style: const TextStyle(color: _ink3),
          ),
        );
      } else {
        body = ListView.builder(
          itemCount: _filteredRows.length,
          itemExtent: _rowH + 1,
          itemBuilder: (context, n) => _row(_filteredRows[n], cols, cells, isEnglish),
        );
      }

      final table = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: groupRow),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _groupLine))),
          child: cells([for (final c in cols) header(c)]),
        ),
        Expanded(child: body),
        if (!_isLoading && countedRows > 0)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF6F8FA),
              border: Border(top: BorderSide(color: _groupLine)),
            ),
            child: cells([
              for (final c in cols)
                switch (c.key) {
                  'doc' => Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(isEnglish ? 'Total $countedRows docs' : 'รวม $countedRows เอกสาร',
                          style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  'date' => Text(isEnglish ? '(excl. Void / deleted)' : '(ไม่นับ Void / ลบแล้ว)',
                      style: const TextStyle(fontSize: 12, color: _ink3), maxLines: 1, overflow: TextOverflow.visible, softWrap: false),
                  'value' => Text(_fmtValue.format(sumValue), textAlign: TextAlign.right, style: _numStyle.copyWith(fontWeight: FontWeight.bold)),
                  _ => const SizedBox.shrink(),
                },
            ]),
          ),
      ]);

      if (tableW <= cons.maxWidth + 0.5) return table;
      return Scrollbar(
        controller: _hScroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _hScroll,
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: tableW, height: cons.maxHeight, child: table),
        ),
      );
    });
  }

  Widget _two(String a, String b, {Color? aColor}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(a, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: aColor)),
          if (b.isNotEmpty)
            Text(b, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: _ink3)),
        ],
      );

  static const _dash = Text('—', style: TextStyle(color: Color(0xFF9AA3AD)));

  Widget _row(ImTransactionHeader r, List<_Col> cols, Widget Function(List<Widget>) cells, bool isEnglish) {
    final editable = r.status == 'Draft' && widget.enableEditButton;
    Widget cell(String key) {
      switch (key) {
        case 'doc':
          return _two(r.docNo, _rowDocTypeName(r), aColor: _docNoColor);
        case 'date':
          return Text(_dateFmt.format(r.docDate), style: _numStyle);
        case 'wh':
          final code = r.warehouseCode ?? '';
          if ((r.toWarehouseCode ?? '').isNotEmpty) {
            return _two('$code → ${r.toWarehouseCode}',
                '${isEnglish ? 'to' : 'ไป'} ${_whName(r.toWarehouseNameTh, r.toWarehouseNameEn)}');
          }
          return _two(code, _whName(r.warehouseNameTh, r.warehouseNameEn));
        case 'party':
          final code = _partyCode(r);
          return code.isEmpty ? _dash : _two(code, _partyName(r));
        case 'ref':
          final doc = _refDocNo(r);
          final ref = (r.refNo ?? '').trim();
          if (doc == null && ref.isEmpty) return _dash;
          if (doc != null && ref.isNotEmpty && ref != doc) return _two(doc, ref);
          return Text(doc ?? ref, maxLines: 1, overflow: TextOverflow.ellipsis);
        case 'qty':
          return Text(_fmtQty.format(r.totalQty),
              textAlign: TextAlign.right, style: _numStyle.copyWith(color: r.totalQty < 0 ? const Color(0xFFC62828) : null));
        case 'value':
          if (r.totalValueLc == 0) return const Align(alignment: Alignment.centerRight, child: _dash);
          return Text(_fmtValue.format(r.totalValueLc),
              textAlign: TextAlign.right, style: _numStyle.copyWith(color: r.totalValueLc < 0 ? const Color(0xFFC62828) : null));
        case 'status':
          final (fg, bg) = _statusColors(r.status);
          return Align(alignment: Alignment.centerLeft, child: _chip(r.status, fg, bg));
        case 'act':
          return Tooltip(
            message: editable ? (isEnglish ? 'Edit' : 'แก้ไข') : (isEnglish ? 'View' : 'ดู'),
            child: Icon(editable ? Icons.edit_outlined : Icons.visibility_outlined, size: 18, color: const Color(0xFF0F6E6E)),
          );
      }
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () => editable ? widget.onEditPressed(r.id) : widget.onViewPressed(r.id),
      hoverColor: const Color(0xFFEEF6F5),
      child: Container(
        height: _rowH + 1,
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _rowLine))),
        child: cells([for (final c in cols) Align(alignment: c.right ? Alignment.centerRight : Alignment.centerLeft, child: cell(c.key))]),
      ),
    );
  }
}
