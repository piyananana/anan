import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../../cd/models/cd_currency.dart';
import '../../cd/widgets/cd_currency_list_widget.dart';
import '../../utils/file_download.dart';
import '../models/im_price_list.dart';
import '../models/im_item.dart';
import '../services/im_item_service.dart';
import '../services/im_price_list_service.dart';
import '../widgets/im_item_list_widget.dart';
import '../widgets/im_price_group_list_widget.dart';
import 'im_master_kit.dart';
import '../../sa/utils/sa_menu_theme.dart';

// หน้ารายละเอียดตารางราคา (แบบ B, user 2026-11-25):
//  - ตัวเลขสรุป: รายการราคา, มีผลวันนี้, หมดอายุแล้ว (กดกรอง), สินค้าขาย/ซื้อที่ยังไม่มีราคา (กดเพิ่มหลายสินค้า)
//  - 4 กลุ่ม: ข้อมูลหลัก (รหัส/ชื่อไทย/ชื่ออังกฤษ) / การใช้งาน / ราคา-ภาษี / เพิ่มเติม
//  - รายการราคา: ค้นหา + กรองสถานะ, แก้ในแถวตาราง (คลิกแถว) แทน dialog, เพิ่มหลายสินค้า, นำเข้าจาก Excel
//    (นำเข้า = อ่านไฟล์แล้วรวมเข้ากับรายการที่กำลังแก้ ผู้ใช้ตรวจแล้วกดบันทึกเอง)
class ImPriceListDetailWidget extends StatefulWidget {
  final Mode mode;
  final ImPriceListHeader? selected;
  final Future<void> Function(ImPriceListHeader) onSubmit;
  final VoidCallback onCancel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isPlaceholder;
  // เพิ่มขึ้นทุกครั้งที่ผู้ใช้กดปุ่มเพิ่ม/แก้ไข/ดู/ยกเลิกจากหน้าจอหลัก — บังคับให้ฟอร์มเคลียร์เสมอแม้ mode/selected ซ้ำ
  final int requestSeq;

  const ImPriceListDetailWidget({
    super.key,
    required this.mode,
    required this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.onEdit,
    this.onDelete,
    this.isPlaceholder = false,
    this.requestSeq = 0,
  });

  @override
  State<ImPriceListDetailWidget> createState() => ImPriceListDetailWidgetState();
}

class ImPriceListDetailWidgetState extends State<ImPriceListDetailWidget> with ImMasterKit {
  final _svc = ImPriceListService();
  bool _isSaving = false;
  bool _isEnglish = false;

  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _nameEnCtrl = TextEditingController();

  bool _isActive = true;
  // ตั้งเป็นลิสต์ default ของ _listType นี้หรือไม่ — ใบเดียวต่อ list_type เท่านั้น (unique index ฝั่ง backend บังคับ)
  bool _isDefault = false;
  bool _priceIncludesVat = false; // ราคาทั้งตารางรวม VAT แล้ว
  String _listType = 'SALES';
  int? _currencyId; String? _currencyCode; String? _currencyName;
  // กลุ่มราคา (im_price_group) — แค่ป้ายกำกับ/หมวดหมู่ ไม่ใช่ targeting ไม่เกี่ยวกับ _listType
  int? _priceGroupId; String? _priceGroupCode; String? _priceGroupName;

  List<ImPriceListDetail> _details = [];

  // แก้ในแถว: แถวที่กำลังแก้ (index ใน _details) + ช่องพิมพ์ของแถวนั้น
  int? _editIdx;
  final _minCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  // หน่วยที่เลือกได้ต่อสินค้า (ตามงานของตาราง ขาย/ซื้อ)
  final Map<int, List<ImItemUomOption>> _uomCache = {};

  // ค้นหา/กรองรายการ + แบ่งหน้า
  final _lineSearchCtrl = TextEditingController();
  String _lineQuery = '';
  String? _lineFilter; // active | promo | expired | future
  int _shown = 50;

  List<ImPriceMissingItem>? _missing;
  int _missingSeq = 0;
  String _snapshot = '';

  static final _qtyFmt = NumberFormat('#,##0.##');
  static final _priceFmt = NumberFormat('#,##0.00##');
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  bool get _isReadOnly => widget.mode == Mode.view || widget.mode == Mode.none;
  @override
  bool get kitEnglish => _isEnglish;
  @override
  bool get kitReadOnly => _isReadOnly;

  /// มีการแก้ไขที่ยังไม่บันทึก
  bool get isDirty => !_isReadOnly && !widget.isPlaceholder && _fingerprint() != _snapshot;

  @override
  void initState() {
    super.initState();
    _apply();
  }

  @override
  void didUpdateWidget(covariant ImPriceListDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected || widget.mode != oldWidget.mode || widget.requestSeq != oldWidget.requestSeq) _apply();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _nameEnCtrl.dispose();
    _minCtrl.dispose();
    _priceCtrl.dispose();
    _lineSearchCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final h = widget.mode == Mode.add ? null : widget.selected;
    _codeCtrl.text = h?.priceListCode ?? '';
    _nameCtrl.text = h?.priceListName ?? '';
    _nameEnCtrl.text = h?.priceListNameEn ?? '';
    _isActive = h?.isActive ?? true;
    _isDefault = h?.isDefault ?? false;
    _priceIncludesVat = h?.priceIncludesVat ?? false;
    _listType = h?.listType ?? 'SALES';
    _currencyId = h?.currencyId; _currencyCode = h?.currencyCode;
    _currencyName = _isEnglish && (h?.currencyNameEn ?? '').isNotEmpty ? h?.currencyNameEn : h?.currencyNameTh;
    _priceGroupId = h?.priceGroupId; _priceGroupCode = h?.priceGroupCode;
    _priceGroupName = _isEnglish && (h?.priceGroupNameEn ?? '').isNotEmpty ? h?.priceGroupNameEn : h?.priceGroupNameTh;
    _details = List.from(h?.details ?? const <ImPriceListDetail>[]);
    _editIdx = null;
    _lineQuery = '';
    _lineSearchCtrl.clear();
    _lineFilter = null;
    _shown = 50;
    _uomCache.clear();
    _missing = null;
    _missingSeq++;
    if (widget.mode != Mode.none) _loadMissing();
    kScrollTop();
    _snapshot = _fingerprint();
  }

  Future<void> _loadMissing() async {
    final seq = ++_missingSeq;
    try {
      final r = await _svc.fetchMissingItems(widget.mode == Mode.add ? 0 : (widget.selected?.id ?? 0), _listType);
      if (mounted && seq == _missingSeq) setState(() => _missing = r);
    } catch (_) {}
  }

  ImPriceListHeader _build() => ImPriceListHeader(
        id: widget.mode == Mode.add ? null : widget.selected?.id,
        priceListCode: _codeCtrl.text.trim().toUpperCase(),
        priceListName: _nameCtrl.text.trim(),
        priceListNameEn: _nameEnCtrl.text.trim().isEmpty ? null : _nameEnCtrl.text.trim(),
        listType: _listType,
        currencyId: _currencyId,
        priceGroupId: _priceGroupId,
        isDefault: _isDefault,
        priceIncludesVat: _priceIncludesVat,
        isActive: _isActive,
        details: _details,
      );

  String _fingerprint() => docFingerprint(_build().toJson());

  // ── บรรทัดราคา ──
  ImPriceListDetail _line(ImPriceListDetail d,
          {int? itemId, String? itemCode, String? itemNameTh, String? itemNameEn,
          int? uomId, String? uomCode, String? uomNameTh, String? uomNameEn,
          double? minQty, double? unitPriceFc, String? priceType,
          DateTime? from, DateTime? to, bool clearFrom = false, bool clearTo = false, bool clearUom = false}) =>
      ImPriceListDetail(
        id: d.id,
        priceListId: d.priceListId,
        itemId: itemId ?? d.itemId,
        itemCode: itemCode ?? d.itemCode,
        itemNameTh: itemNameTh ?? d.itemNameTh,
        itemNameEn: itemId != null ? itemNameEn : d.itemNameEn,
        uomId: clearUom ? null : (uomId ?? d.uomId),
        uomCode: clearUom ? null : (uomCode ?? d.uomCode),
        uomNameTh: clearUom ? null : (uomNameTh ?? d.uomNameTh),
        uomNameEn: clearUom ? null : (uomId != null ? uomNameEn : d.uomNameEn),
        minQty: minQty ?? d.minQty,
        unitPriceFc: unitPriceFc ?? d.unitPriceFc,
        priceType: priceType ?? d.priceType,
        effectiveFrom: clearFrom ? null : (from ?? d.effectiveFrom),
        effectiveTo: clearTo ? null : (to ?? d.effectiveTo),
        updatedAt: d.updatedAt,
        updatedBy: d.updatedBy,
      );

  String _purpose() => _listType == 'PURCHASE' ? 'PURCHASE' : 'SALES';

  Future<List<ImItemUomOption>> _uomsFor(int itemId) async {
    final c = _uomCache[itemId];
    if (c != null) return c;
    try {
      final u = await ImItemService().fetchItemUoms(itemId, purpose: _purpose());
      _uomCache[itemId] = u.units;
      return u.units;
    } catch (_) {
      return const [];
    }
  }

  void _startEdit(int idx) {
    if (_isReadOnly) return;
    final d = _details[idx];
    setState(() {
      _editIdx = idx;
      _minCtrl.text = NumberFormat('0.######').format(d.minQty);
      _priceCtrl.text = NumberFormat('0.####').format(d.unitPriceFc);
    });
    _uomsFor(d.itemId).then((_) {
      if (mounted) setState(() {});
    });
  }

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  String _status(ImPriceListDetail d) {
    final t = _today;
    if (d.effectiveTo != null && d.effectiveTo!.isBefore(t)) return 'expired';
    if (d.effectiveFrom != null && d.effectiveFrom!.isAfter(t)) return 'future';
    return 'active';
  }

  Widget _statusChip(String s) {
    final e = _isEnglish;
    switch (s) {
      case 'expired': return ImKit.chip(e ? 'Expired' : 'หมดอายุ', ImKit.redSoft, ImKit.red);
      case 'future': return ImKit.chip(e ? 'Not yet' : 'ยังไม่ถึง', ImKit.goldSoft, ImKit.amber);
      default: return ImKit.chip(e ? 'Effective' : 'มีผล', ImKit.okSoft, ImKit.ok);
    }
  }

  String _itemName(ImPriceListDetail d) => _isEnglish && (d.itemNameEn ?? '').isNotEmpty ? d.itemNameEn! : (d.itemNameTh ?? '');
  String _uomName(ImPriceListDetail d) => _isEnglish && (d.uomNameEn ?? '').isNotEmpty ? d.uomNameEn! : (d.uomNameTh ?? d.uomCode ?? '');

  /// index ใน _details ของบรรทัดที่ผ่านตัวค้นหา/ตัวกรอง (แถวที่กำลังแก้แสดงเสมอ)
  List<int> _visibleIdx() {
    final q = _lineQuery.trim().toUpperCase();
    return [
      for (var i = 0; i < _details.length; i++)
        if (i == _editIdx ||
            ((q.isEmpty ||
                    (_details[i].itemCode ?? '').toUpperCase().contains(q) ||
                    (_details[i].itemNameTh ?? '').toUpperCase().contains(q) ||
                    (_details[i].itemNameEn ?? '').toUpperCase().contains(q)) &&
                switch (_lineFilter) {
                  'promo' => _details[i].priceType == 'PROMOTION',
                  null => true,
                  _ => _status(_details[i]) == _lineFilter,
                }))
          i,
    ];
  }

  // เพิ่มบรรทัดใหม่ไว้บนสุด แล้วเปิดแก้ทันที
  Future<void> _addLine() async {
    await ImItemListWidget.search(context, onSelected: (ImItem it) async {
      if (it.id == null) return;
      final units = await _uomsFor(it.id!);
      ImItemUomOption? def;
      try {
        final u = await ImItemService().fetchItemUoms(it.id!, purpose: _purpose());
        def = u.byId(u.defaultUomId) ?? (u.units.isNotEmpty ? u.units.first : null);
      } catch (_) {
        def = units.isNotEmpty ? units.first : null;
      }
      if (!mounted) return;
      setState(() {
        _details.insert(0, ImPriceListDetail(
          itemId: it.id!, itemCode: it.itemCode, itemNameTh: it.itemNameTh, itemNameEn: it.itemNameEn,
          uomId: def?.uomId, uomCode: def?.uomCode, uomNameTh: def?.uomNameTh, uomNameEn: def?.uomNameEn,
        ));
        _lineFilter = null;
        _lineQuery = '';
        _lineSearchCtrl.clear();
      });
      _startEdit(0);
      kJumpTo(1);
    });
  }

  Future<void> _changeLineItem(int idx) async {
    await ImItemListWidget.search(context, onSelected: (ImItem it) async {
      if (it.id == null) return;
      final units = await _uomsFor(it.id!);
      if (!mounted || idx >= _details.length) return;
      final cur = _details[idx];
      final keep = units.any((u) => u.uomId == cur.uomId);
      final first = units.isNotEmpty ? units.first : null;
      setState(() {
        _details[idx] = keep
            ? _line(cur, itemId: it.id, itemCode: it.itemCode, itemNameTh: it.itemNameTh, itemNameEn: it.itemNameEn)
            : first == null
                ? _line(cur, itemId: it.id, itemCode: it.itemCode, itemNameTh: it.itemNameTh, itemNameEn: it.itemNameEn, clearUom: true)
                : _line(cur, itemId: it.id, itemCode: it.itemCode, itemNameTh: it.itemNameTh, itemNameEn: it.itemNameEn,
                    uomId: first.uomId, uomCode: first.uomCode, uomNameTh: first.uomNameTh, uomNameEn: first.uomNameEn);
      });
    });
  }

  void _removeLine(int idx) => setState(() {
        _details.removeAt(idx);
        if (_editIdx == idx) {
          _editIdx = null;
        } else if (_editIdx != null && _editIdx! > idx) {
          _editIdx = _editIdx! - 1;
        }
      });

  // เปลี่ยนประเภทตาราง (ขาย <-> ซื้อ) — หน่วยของบรรทัดต้องอนุญาตในงานใหม่ (backend ตรวจทุกบรรทัดอีกครั้งตอนบันทึก)
  Future<void> _onListTypeChanged(String v) async {
    setState(() {
      _listType = v;
      _uomCache.clear();
      _missing = null;
    });
    _loadMissing();
    final isEnglish = _isEnglish;
    final purpose = _purpose();
    final messenger = ScaffoldMessenger.of(context);
    final bad = <String>[];
    for (final d in List.of(_details)) {
      final uomId = d.uomId;
      if (uomId == null) continue;
      final allowed = (await _uomsFor(d.itemId)).map((u) => u.uomId).toSet();
      if (!allowed.contains(uomId)) bad.add('${d.itemCode ?? d.itemId} (${d.uomCode ?? uomId})');
    }
    if (!mounted || _listType != v || bad.isEmpty) return;
    messenger.showSnackBar(SnackBar(
      backgroundColor: Colors.orange,
      duration: const Duration(seconds: 8),
      content: Text(isEnglish
          ? 'These lines use a unit not allowed for ${purpose == 'PURCHASE' ? 'purchasing' : 'sales'} — change the unit before saving: ${bad.join(', ')}'
          : 'บรรทัดต่อไปนี้ใช้หน่วยที่ไม่ได้อนุญาตในงาน${purpose == 'PURCHASE' ? 'ซื้อ' : 'ขาย'} — แก้หน่วยก่อนบันทึก: ${bad.join(', ')}'),
    ));
  }

  Future<void> _pickCurrency() async {
    final isEnglish = _isEnglish;
    await CurrencyListWidget.search(context, onSelected: (Currency c) {
      setState(() {
        _currencyId = c.id; _currencyCode = c.currencyCode;
        _currencyName = isEnglish && c.currencyNameEng.isNotEmpty ? c.currencyNameEng : c.currencyNameThai;
      });
    });
  }

  Future<void> _save() async {
    final e = _isEnglish;
    String? err;
    if (_codeCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter the price list code' : 'กรุณาป้อนรหัสตารางราคา';
    } else if (_nameCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter the price list name (Thai)' : 'กรุณาป้อนชื่อตารางราคา (ไทย)';
    } else if (_details.isEmpty) {
      err = e ? 'Please add at least one price line' : 'กรุณาเพิ่มรายการราคาอย่างน้อย 1 รายการ';
    }
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
      return;
    }
    // ราคา 0 มักเกิดจาก "เพิ่มหลายสินค้า" แล้วยังไม่ได้ใส่ราคา — ถามก่อนบันทึก
    final zero = _details.where((d) => d.unitPriceFc == 0).length;
    if (zero > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(e ? 'Lines with price 0' : 'มีรายการราคา 0'),
          content: Text(e ? '$zero line(s) have a unit price of 0. Save anyway?' : 'มี $zero รายการที่ราคาต่อหน่วยเป็น 0 ต้องการบันทึกหรือไม่'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(e ? 'Back to edit' : 'กลับไปแก้')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(e ? 'Save' : 'บันทึก')),
          ],
        ),
      );
      if (ok != true) {
        if (mounted) setState(() => _lineFilter = null);
        return;
      }
    }
    setState(() => _isSaving = true);
    try {
      await widget.onSubmit(_build());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── เพิ่มหลายสินค้า ──
  Future<void> _addMultiple() async {
    final e = _isEnglish;
    if (_missing == null) await _loadMissing();
    if (!mounted) return;
    final inList = _details.map((d) => d.itemId).toSet();
    final pool = (_missing ?? const <ImPriceMissingItem>[]).where((m) => !inList.contains(m.id)).toList();
    if (pool.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e
          ? 'Every ${_listType == 'PURCHASE' ? 'purchase' : 'sales'} item already has a price in this list'
          : 'สินค้า${_listType == 'PURCHASE' ? 'ซื้อ' : 'ขาย'}ทุกรายการมีราคาในตารางนี้แล้ว')));
      return;
    }
    final cats = <String, String>{for (final m in pool) if ((m.categoryCode ?? '').isNotEmpty) m.categoryCode!: '${m.categoryCode}  ${m.categoryName ?? ''}'};
    final catKeys = cats.keys.toList()..sort();
    final picked = <int>{};
    String q = '';
    String? cat;
    final searchCtrl = TextEditingController();
    final result = await showDialog<List<ImPriceMissingItem>>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        final shown = pool.where((m) {
          if (cat != null && m.categoryCode != cat) return false;
          final u = q.trim().toUpperCase();
          return u.isEmpty || m.itemCode.toUpperCase().contains(u) || m.itemNameTh.toUpperCase().contains(u) || (m.itemNameEn ?? '').toUpperCase().contains(u);
        }).toList();
        final allShown = shown.isNotEmpty && shown.every((m) => picked.contains(m.id));
        return AlertDialog(
          title: Text(e ? 'Add Multiple Items' : 'เพิ่มหลายสินค้า'),
          content: SizedBox(
            width: 620,
            height: 480,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(
                e
                    ? '${_listType == 'PURCHASE' ? 'Purchase' : 'Sales'} items without a price in this list (${pool.length}). Lines are added with the base unit and price 0 — enter prices in the table.'
                    : 'สินค้า${_listType == 'PURCHASE' ? 'ซื้อ' : 'ขาย'}ที่ยังไม่มีราคาในตารางนี้ (${pool.length} รายการ) — เพิ่มด้วยหน่วยหลักและราคา 0 แล้วใส่ราคาในตาราง',
                style: const TextStyle(fontSize: 12, color: ImKit.ink2),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: e ? 'Search code / name' : 'ค้นหา รหัส / ชื่อสินค้า',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => setD(() => q = v),
                    ),
                  ),
                ),
                if (catKeys.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String?>(
                      value: cat,
                      isExpanded: true,
                      isDense: true,
                      decoration: InputDecoration(labelText: e ? 'Category' : 'หมวด', border: const OutlineInputBorder(), isDense: true),
                      items: [
                        DropdownMenuItem<String?>(value: null, child: Text(e ? 'All categories' : 'ทุกหมวด')),
                        for (final k in catKeys) DropdownMenuItem<String?>(value: k, child: Text(cats[k]!, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => setD(() => cat = v),
                    ),
                  ),
                ],
              ]),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: allShown,
                title: Text(e ? 'Select all shown (${shown.length})' : 'เลือกทั้งหมดที่แสดง (${shown.length})', style: const TextStyle(fontSize: 13)),
                onChanged: (v) => setD(() {
                  for (final m in shown) {
                    v == true ? picked.add(m.id) : picked.remove(m.id);
                  }
                }),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (_, i) {
                    final m = shown[i];
                    return CheckboxListTile(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: picked.contains(m.id),
                      title: Text('${m.itemCode}  ${m.displayName(e)}', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                      subtitle: Text('${m.categoryCode ?? ''}  ·  ${m.baseUomCode ?? '—'}', style: const TextStyle(fontSize: 11.5)),
                      onChanged: (v) => setD(() => v == true ? picked.add(m.id) : picked.remove(m.id)),
                    );
                  },
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(e ? 'Cancel' : 'ยกเลิก')),
            ElevatedButton(
              onPressed: picked.isEmpty ? null : () => Navigator.pop(ctx, pool.where((m) => picked.contains(m.id)).toList()),
              child: Text(e ? 'Add ${picked.length} item(s)' : 'เพิ่ม ${picked.length} รายการ'),
            ),
          ],
        );
      }),
    );
    searchCtrl.dispose();
    if (result == null || result.isEmpty || !mounted) return;
    setState(() {
      _details.insertAll(0, [
        for (final m in result)
          ImPriceListDetail(
            itemId: m.id, itemCode: m.itemCode, itemNameTh: m.itemNameTh, itemNameEn: m.itemNameEn,
            uomId: m.baseUomId, uomCode: m.baseUomCode, uomNameTh: m.baseUomNameTh, uomNameEn: m.baseUomNameEn,
          ),
      ]);
      _editIdx = null;
      _lineFilter = null;
      _lineQuery = '';
      _lineSearchCtrl.clear();
    });
    kJumpTo(1);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e
        ? 'Added ${result.length} line(s) at the top with price 0 — click a row to enter its price'
        : 'เพิ่ม ${result.length} รายการไว้บนสุด ราคา 0 — คลิกแถวเพื่อใส่ราคา')));
  }

  // ── นำเข้าราคาจาก Excel ──
  Future<void> _importPrices() async {
    final e = _isEnglish;
    ImPriceImportResult? parsed;
    String? fileName;
    String? error;
    bool busy = false;
    final res = await showDialog<ImPriceImportResult>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        Future<void> pick() async {
          final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'xls', 'csv'], withData: true);
          if (r == null || r.files.isEmpty || r.files.first.bytes == null) return;
          final f = r.files.first;
          setD(() { busy = true; error = null; parsed = null; fileName = f.name; });
          try {
            final p = await _svc.parseImport(f.bytes!, f.name, _listType);
            setD(() => parsed = p);
          } catch (ex) {
            setD(() => error = ex.toString().replaceFirst('Exception: ', ''));
          } finally {
            setD(() => busy = false);
          }
        }

        Future<void> template() async {
          try {
            final bytes = await _svc.downloadImportTemplate(english: e);
            await downloadFile(bytes, 'im_price_list_template.xlsx');
          } catch (ex) {
            setD(() => error = ex.toString().replaceFirst('Exception: ', ''));
          }
        }

        final p = parsed;
        return AlertDialog(
          title: Text(e ? 'Import Prices from Excel' : 'นำเข้าราคาจาก Excel'),
          content: SizedBox(
            width: 620,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(
                e
                    ? 'Lines from the file are merged into this price list (not saved yet). A line with the same item, unit, minimum quantity, price type and effective-from date updates the existing price; others are added. Review, then press Save.'
                    : 'รายการจากไฟล์จะรวมเข้ากับตารางราคานี้ (ยังไม่บันทึก) — บรรทัดที่สินค้า หน่วย จำนวนขั้นต่ำ ชนิดราคา และวันที่มีผลตั้งแต่ตรงกัน จะปรับราคาเดิม ที่เหลือเพิ่มใหม่ ตรวจแล้วกดบันทึก',
                style: const TextStyle(fontSize: 12.5, color: ImKit.ink2),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(onPressed: template, icon: const Icon(Icons.download, size: 18), label: Text(e ? 'Download template' : 'ดาวน์โหลดเทมเพลต')),
                ElevatedButton.icon(onPressed: busy ? null : pick, icon: const Icon(Icons.upload_file, size: 18), label: Text(e ? 'Choose file' : 'เลือกไฟล์')),
              ]),
              if (fileName != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(fileName!, style: const TextStyle(fontSize: 12.5))),
              if (busy) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
              if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: ImKit.red))),
              if (p != null) ...[
                const SizedBox(height: 10),
                Text(
                  e
                      ? '${p.totalRows} row(s) read · ${p.lines.length} ready · ${p.errors.length} with errors (skipped)'
                      : 'อ่าน ${p.totalRows} แถว · พร้อมนำเข้า ${p.lines.length} · มีข้อผิดพลาด ${p.errors.length} (ข้าม)',
                  style: TextStyle(fontWeight: FontWeight.w600, color: p.errors.isEmpty ? ImKit.ok : ImKit.amber),
                ),
                if (p.errors.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView(shrinkWrap: true, children: [
                      for (final er in p.errors)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(e ? 'Row ${er.row} · ${er.column}: ${er.message}' : 'แถว ${er.row} · ${er.column}: ${er.message}',
                              style: const TextStyle(fontSize: 12, color: ImKit.red)),
                        ),
                    ]),
                  ),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(e ? 'Cancel' : 'ยกเลิก')),
            ElevatedButton(
              onPressed: p == null || p.lines.isEmpty ? null : () => Navigator.pop(ctx, p),
              child: Text(e ? 'Import ${p?.lines.length ?? 0} line(s)' : 'นำเข้า ${p?.lines.length ?? 0} รายการ'),
            ),
          ],
        );
      }),
    );
    if (res == null || !mounted) return;
    String key(ImPriceListDetail d) =>
        '${d.itemId}|${d.uomId ?? 0}|${d.minQty}|${d.priceType}|${d.effectiveFrom == null ? '' : DateFormat('yyyy-MM-dd').format(d.effectiveFrom!)}';
    var updated = 0, added = 0;
    setState(() {
      final idx = <String, int>{for (var i = 0; i < _details.length; i++) key(_details[i]): i};
      final adds = <ImPriceListDetail>[];
      for (final l in res.lines) {
        final i = idx[key(l)];
        if (i != null) {
          _details[i] = _line(_details[i], unitPriceFc: l.unitPriceFc, to: l.effectiveTo, clearTo: l.effectiveTo == null);
          updated++;
        } else {
          adds.add(l);
          added++;
        }
      }
      _details.insertAll(0, adds);
      _editIdx = null;
      _lineFilter = null;
    });
    kJumpTo(1);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e
        ? 'Imported: $updated price(s) updated, $added line(s) added — review and press Save'
        : 'นำเข้าแล้ว: ปรับราคาเดิม $updated รายการ เพิ่มใหม่ $added รายการ — ตรวจแล้วกดบันทึก')));
  }

  // ── การ์ด ──
  Widget _mainCard() {
    final e = _isEnglish;
    final ed = !_isReadOnly;
    final h = widget.selected;
    return kCard(
      title: e ? 'Price List Information' : 'ข้อมูลตารางราคา',
      trailing: _isReadOnly ? null : kLegend(),
      child: kGroups([
        kGroup(1, e ? 'Main Information' : 'ข้อมูลหลัก', ImKit.gDoc, [
          kRow([
            kTxt(widget.mode == Mode.add ? (e ? 'Price List Code *' : 'รหัสตารางราคา *') : (e ? 'Price List Code' : 'รหัสตารางราคา'), _codeCtrl,
                editable: widget.mode == Mode.add, cap: TextCapitalization.characters),
            const SizedBox.shrink(),
          ]),
          kTxt(e ? 'Price List Name (Thai) *' : 'ชื่อตารางราคา (ไทย) *', _nameCtrl),
          kTxt(e ? 'Price List Name (English)' : 'ชื่อตารางราคา (อังกฤษ)', _nameEnCtrl),
        ]),
        kGroup(2, e ? 'Usage' : 'การใช้งาน', ImKit.gParty, [
          kRow([
            kDd<String>(e ? 'List Type' : 'ประเภทตารางราคา', _listType,
                imPriceListTypes.map((t) => DropdownMenuItem(value: t, child: Text(imPriceListTypeLabel(t, e)))).toList(),
                ed ? (v) => _onListTypeChanged(v ?? 'SALES') : null),
            // กลุ่มราคา — แค่ป้ายกำกับ/หมวดหมู่สำหรับจัดกลุ่มการแสดงผล/รายงาน ไม่เกี่ยวกับการ resolve ราคา
            kFk(
              label: e ? 'Price Group' : 'กลุ่มราคา',
              hasValue: _priceGroupId != null,
              text: '$_priceGroupCode  ${_priceGroupName ?? ''}',
              onSearch: () => ImPriceGroupListWidget.search(context, onSelected: (g) {
                setState(() {
                  _priceGroupId = g.id; _priceGroupCode = g.priceGroupCode;
                  _priceGroupName = e && (g.priceGroupNameEn ?? '').isNotEmpty ? g.priceGroupNameEn : g.priceGroupNameTh;
                });
              }),
              onClear: () => setState(() { _priceGroupId = null; _priceGroupCode = null; _priceGroupName = null; }),
            ),
          ]),
          // ตั้งเป็นลิสต์ default ของ _listType นี้ — ใบเดียวต่อ list_type เท่านั้น (unique index ฝั่ง backend บังคับ)
          kChecks([
            kCk(e ? 'Default list for this type' : 'ค่าเริ่มต้นของประเภทนี้', _isDefault, ed ? (v) => setState(() => _isDefault = v) : null,
                tooltip: e ? 'Used when a customer/vendor has no list of their own' : 'ใช้เมื่อลูกค้า/ผู้ขายไม่มีตารางราคาเฉพาะของตัวเอง'),
          ]),
        ]),
        kGroup(3, e ? 'Price / Tax' : 'ราคา / ภาษี', ImKit.gFin, [
          kRow([
            kFk(
              label: e ? 'Currency' : 'สกุลเงิน',
              hasValue: _currencyId != null,
              text: '$_currencyCode  ${_currencyName ?? ''}',
              onSearch: _pickCurrency,
              onClear: () => setState(() { _currencyId = null; _currencyCode = null; _currencyName = null; }),
              auto: true,
            ),
            const SizedBox.shrink(),
          ]),
          kChecks([
            kCk(e ? 'Prices include VAT' : 'ราคารวม VAT แล้ว', _priceIncludesVat, ed ? (v) => setState(() => _priceIncludesVat = v) : null,
                tooltip: e
                    ? 'Documents set the other way get the price converted by the line VAT rate'
                    : 'เอกสารที่ตั้งราคารวม/ไม่รวม VAT ต่างจากตารางนี้ ระบบแปลงราคาตามอัตรา VAT ของรายการ'),
          ]),
        ]),
        kGroup(4, e ? 'More' : 'เพิ่มเติม', ImKit.gMore, [
          kRow([
            InputDecorator(
              decoration: kDec(e ? 'Last updated by' : 'แก้ไขล่าสุดโดย', editable: false),
              child: Text(
                h?.updatedBy == null ? '' : '${h!.updatedBy}${h.updatedAt == null ? '' : ' · ${_dateFmt.format(h.updatedAt!)}'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: ImKit.font),
              ),
            ),
            const SizedBox.shrink(),
          ]),
          kChecks([kCk(e ? 'Active' : 'ใช้งาน', _isActive, ed ? (v) => setState(() => _isActive = v) : null)]),
        ]),
      ]),
    );
  }

  InputDecoration _cellDec() => const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        filled: true,
        fillColor: Colors.white,
      );

  Widget _dateCell(DateTime? v, ValueChanged<DateTime?> onChanged) => InkWell(
        onTap: () async {
          final d = await showDatePicker(context: context, initialDate: v ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (d != null) onChanged(d);
        },
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade500), borderRadius: BorderRadius.circular(4)),
          child: Row(children: [
            Expanded(child: Text(v == null ? '—' : _dateFmt.format(v), style: const TextStyle(fontSize: 12.5))),
            if (v != null)
              InkWell(onTap: () => onChanged(null), child: const Icon(Icons.clear, size: 14, color: Colors.red)),
          ]),
        ),
      );

  List<Widget> _editRow(int i) {
    final e = _isEnglish;
    final d = _details[i];
    final units = _uomCache[d.itemId] ?? const <ImItemUomOption>[];
    final opts = [
      ...units,
      // หน่วยเดิมของบรรทัดที่ถูกปิดสิทธิ์ภายหลัง ยังเลือกคงเดิมได้ (backend ตรวจเฉพาะบรรทัดใหม่/ที่เปลี่ยนหน่วย)
      if (d.uomId != null && !units.any((u) => u.uomId == d.uomId))
        ImItemUomOption(uomId: d.uomId!, uomCode: d.uomCode ?? '', uomNameTh: d.uomNameTh, uomNameEn: d.uomNameEn),
    ];
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5);
    return [
      InkWell(
        onTap: () => _changeLineItem(i),
        child: Row(children: [
          Flexible(child: kCell('${d.itemCode ?? ''}  ${_itemName(d)}', bold: true)),
          const SizedBox(width: 4),
          Tooltip(message: e ? 'Change item' : 'เปลี่ยนสินค้า', child: const Icon(Icons.search, size: 15, color: Colors.teal)),
        ]),
      ),
      SizedBox(
        height: 30,
        child: DropdownButtonFormField<int>(
          value: opts.any((o) => o.uomId == d.uomId) ? d.uomId : null,
          isExpanded: true,
          isDense: true,
          style: textStyle,
          decoration: _cellDec(),
          items: [for (final o in opts) DropdownMenuItem(value: o.uomId, child: Text(o.uomCode, overflow: TextOverflow.ellipsis))],
          onChanged: (v) {
            final o = opts.firstWhere((x) => x.uomId == v);
            setState(() => _details[i] = _line(d, uomId: o.uomId, uomCode: o.uomCode, uomNameTh: o.uomNameTh, uomNameEn: o.uomNameEn));
          },
        ),
      ),
      SizedBox(
        height: 30,
        child: TextField(
          controller: _minCtrl,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 12.5),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
          decoration: _cellDec(),
          onChanged: (v) => setState(() => _details[i] = _line(_details[i], minQty: double.tryParse(v) ?? 0)),
        ),
      ),
      SizedBox(
        height: 30,
        child: TextField(
          controller: _priceCtrl,
          autofocus: true,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 12.5),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
          decoration: _cellDec(),
          onChanged: (v) => setState(() => _details[i] = _line(_details[i], unitPriceFc: double.tryParse(v) ?? 0)),
        ),
      ),
      SizedBox(
        height: 30,
        child: DropdownButtonFormField<String>(
          value: d.priceType,
          isExpanded: true,
          isDense: true,
          style: textStyle,
          decoration: _cellDec(),
          items: imPriceTypes.map((t) => DropdownMenuItem(value: t, child: Text(imPriceTypeLabel(t, e), overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) => setState(() => _details[i] = _line(_details[i], priceType: v ?? 'STANDARD')),
        ),
      ),
      Row(children: [
        Expanded(child: _dateCell(d.effectiveFrom, (v) => setState(() => _details[i] = _line(_details[i], from: v, clearFrom: v == null)))),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 3), child: Text('–')),
        Expanded(child: _dateCell(d.effectiveTo, (v) => setState(() => _details[i] = _line(_details[i], to: v, clearTo: v == null)))),
      ]),
      _statusChip(_status(d)),
      Row(mainAxisSize: MainAxisSize.min, children: [
        kIconBtn(Icons.check, e ? 'Done' : 'เสร็จ', () => setState(() => _editIdx = null), color: ImKit.ok),
        kIconBtn(Icons.delete, e ? 'Delete' : 'ลบ', () => _removeLine(i), color: Colors.red),
      ]),
    ];
  }

  List<Widget> _viewRow(int i) {
    final e = _isEnglish;
    final d = _details[i];
    final range = (d.effectiveFrom == null && d.effectiveTo == null)
        ? ''
        : '${d.effectiveFrom == null ? '' : _dateFmt.format(d.effectiveFrom!)} – ${d.effectiveTo == null ? '' : _dateFmt.format(d.effectiveTo!)}';
    return [
      kCell('${d.itemCode ?? ''}  ${_itemName(d)}'),
      kCell(_uomName(d)),
      kCell(d.minQty > 0 ? _qtyFmt.format(d.minQty) : '0', mono: true),
      kCell(_priceFmt.format(d.unitPriceFc), mono: true, bold: true, color: d.unitPriceFc == 0 ? ImKit.red : null),
      d.priceType == 'PROMOTION' ? ImKit.chip(imPriceTypeLabel('PROMOTION', e), ImKit.goldSoft, ImKit.amber) : kCell(imPriceTypeLabel('STANDARD', e)),
      kCell(range),
      _statusChip(_status(d)),
      if (!_isReadOnly) kIconBtn(Icons.delete, e ? 'Delete' : 'ลบ', () => _removeLine(i), color: Colors.red),
    ];
  }

  Widget _linesCard() {
    final e = _isEnglish;
    final ed = !_isReadOnly;
    final vis = _visibleIdx();
    final shown = vis.take(_shown).toList();
    int cnt(String s) => _details.where((d) => _status(d) == s).length;
    final promo = _details.where((d) => d.priceType == 'PROMOTION').length;
    void toggle(String f) => setState(() {
          _lineFilter = _lineFilter == f ? null : f;
          _shown = 50;
        });
    final cols = [
      KCol(e ? 'Item' : 'สินค้า', 6),
      KCol(e ? 'Unit' : 'หน่วย', 2),
      KCol(e ? 'Min qty' : 'ขั้นต่ำ', 2, num: true),
      KCol(e ? 'Price / unit' : 'ราคา/หน่วย', 2, num: true),
      KCol(e ? 'Price type' : 'ชนิดราคา', 2),
      KCol(e ? 'Effective from – to' : 'มีผลตั้งแต่ – ถึง', 5),
      KCol(e ? 'Status' : 'สถานะ', 2),
      if (ed) const KCol('', 2, num: true),
    ];
    return kCard(
      title: e ? 'Price Lines' : 'รายการราคา',
      count: e ? '${_details.length} line(s)${imPriceInclVatSuffix(_priceIncludesVat, true)}' : '${_details.length} รายการ${imPriceInclVatSuffix(_priceIncludesVat, false)}',
      trailing: ed
          ? Wrap(spacing: 6, runSpacing: 6, children: [
              kGhost(e ? 'Import' : 'นำเข้าราคา', Icons.upload_file, _importPrices),
              kGhost(e ? 'Add multiple items' : 'เพิ่มหลายสินค้า', Icons.playlist_add, _addMultiple),
              kGhost(e ? 'Add line' : 'เพิ่มรายการ', Icons.add, _addLine),
            ])
          : null,
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ImKit.line))),
          child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(
              width: 280,
              height: 34,
              child: TextField(
                controller: _lineSearchCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: e ? 'Search item code / name' : 'ค้นหาในรายการ รหัส / ชื่อสินค้า',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() {
                  _lineQuery = v;
                  _shown = 50;
                }),
              ),
            ),
            _lineChip(e ? 'All' : 'ทั้งหมด', _lineFilter == null, () => setState(() => _lineFilter = null)),
            _lineChip(e ? 'Effective ${cnt('active')}' : 'มีผล ${cnt('active')}', _lineFilter == 'active', () => toggle('active')),
            _lineChip(e ? 'Promotion $promo' : 'โปรโมชั่น $promo', _lineFilter == 'promo', () => toggle('promo')),
            _lineChip(e ? 'Expired ${cnt('expired')}' : 'หมดอายุ ${cnt('expired')}', _lineFilter == 'expired', () => toggle('expired'),
                fg: cnt('expired') > 0 ? ImKit.red : null),
            _lineChip(e ? 'Not yet ${cnt('future')}' : 'ยังไม่ถึง ${cnt('future')}', _lineFilter == 'future', () => toggle('future')),
          ]),
        ),
        kTable(
          cols,
          [for (final i in shown) i == _editIdx ? _editRow(i) : _viewRow(i)],
          onTap: [for (final i in shown) ed && i != _editIdx ? () => _startEdit(i) : null],
          rowColors: [for (final i in shown) i == _editIdx ? const Color(0xFFFFFCF2) : null],
          rowMinHeight: 38,
          minWidth: 980,
          empty: _details.isEmpty
              ? (e ? 'No price lines yet' : 'ยังไม่มีรายการราคา')
              : (e ? 'No line matches the search/filter' : 'ไม่พบรายการตามที่ค้นหา/กรอง'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Row(children: [
            Expanded(
              child: kNote(e
                  ? 'Showing ${shown.length} of ${vis.length}${ed ? ' · click a row to edit it in the table' : ''}'
                  : 'แสดง ${shown.length} จาก ${vis.length} รายการ${ed ? ' · คลิกแถวเพื่อแก้ในตาราง' : ''}'),
            ),
            if (vis.length > shown.length)
              kGhost(e ? 'Show 50 more' : 'แสดงเพิ่ม 50', Icons.expand_more, () => setState(() => _shown += 50)),
          ]),
        ),
      ]),
    );
  }

  Widget _lineChip(String label, bool on, VoidCallback onTap, {Color? fg}) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: on ? ScreenTheme.of(context).soft : Colors.white,
            border: Border.all(color: on ? const Color(0xFFB7D6D3) : ImKit.line),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(label, style: TextStyle(fontSize: 12, color: on ? ScreenTheme.of(context).ink : (fg ?? ImKit.ink2), fontWeight: on ? FontWeight.w600 : null)),
        ),
      );

  List<ImKpi> _kpis() {
    final e = _isEnglish;
    final items = _details.map((d) => d.itemId).toSet().length;
    final active = _details.where((d) => _status(d) == 'active').toList();
    final promo = active.where((d) => d.priceType == 'PROMOTION').length;
    final expired = _details.where((d) => _status(d) == 'expired').length;
    final inList = _details.map((d) => d.itemId).toSet();
    final missing = _missing?.where((m) => !inList.contains(m.id)).length;
    final sales = _listType != 'PURCHASE';
    return [
      ImKpi(e ? 'Price lines' : 'รายการราคา', '${_details.length}', e ? '$items item(s)' : '$items สินค้า'),
      ImKpi(e ? 'Effective today' : 'มีผลวันนี้', '${active.length}',
          e ? 'standard ${active.length - promo} · promotion $promo' : 'ปกติ ${active.length - promo} · โปรโมชั่น $promo'),
      ImKpi(e ? 'Expired' : 'หมดอายุแล้ว', '$expired', expired > 0 ? (e ? 'tap to filter lines' : 'กดเพื่อกรองรายการ') : (e ? 'None' : 'ไม่มี'),
          warn: expired > 0,
          onTap: expired > 0
              ? () {
                  setState(() => _lineFilter = 'expired');
                  kJumpTo(1);
                }
              : null),
      ImKpi(
        sales ? (e ? 'Sales items without price' : 'สินค้าขายที่ยังไม่มีราคา') : (e ? 'Purchase items without price' : 'สินค้าซื้อที่ยังไม่มีราคา'),
        missing == null ? '…' : '$missing',
        missing == null || missing == 0
            ? (e ? 'All covered' : 'ครบแล้ว')
            : (_isReadOnly ? (e ? 'press Edit to add them' : 'กดแก้ไขเพื่อเพิ่ม') : (e ? 'tap to add multiple items' : 'กดเพื่อเพิ่มหลายสินค้า')),
        onTap: !_isReadOnly && (missing ?? 0) > 0 ? _addMultiple : null,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    _isEnglish = Provider.of<LanguageProvider>(context).isEnglish;
    final e = _isEnglish;
    if (widget.isPlaceholder) {
      return kPlaceholder(Icons.price_change_outlined, e ? 'Select a price list on the left to view its data' : 'เลือกตารางราคาทางซ้ายเพื่อดูข้อมูล');
    }
    final saved = widget.mode != Mode.add && widget.selected != null;
    final h = widget.selected;
    return kPage(
      header: kHeaderBar(
        code: saved ? h!.priceListCode : null,
        title: saved ? h!.displayName(e) : (e ? 'Add Price List' : 'เพิ่มตารางราคา'),
        badges: [
          if (widget.mode == Mode.edit) kEditingBadge(),
          if (saved && h!.isDefault) ImKit.chip(e ? 'Default' : 'ค่าเริ่มต้น', ImKit.goldSoft, ImKit.amber),
          if (saved)
            h!.listType == 'PURCHASE'
                ? ImKit.chip(e ? 'Purchase' : 'ราคาซื้อ', ImKit.purSoft, ImKit.pur)
                : ImKit.chip(e ? 'Sales' : 'ราคาขาย', ImKit.blueSoft, ImKit.blue),
          if (saved) ImKit.activeChip(_isActive, e),
        ],
        acts: kStdActs(saving: _isSaving, onEdit: widget.onEdit, onDelete: widget.onDelete, onClose: widget.onCancel,
            onCancel: widget.onCancel, onSave: _save),
        busy: _isSaving,
      ),
      top: kKpis(_kpis()),
      sections: [
        (0, e ? 'Main' : 'ข้อมูลหลัก', _mainCard()),
        (1, e ? 'Price lines' : 'รายการราคา', _linesCard()),
      ],
    );
  }
}
