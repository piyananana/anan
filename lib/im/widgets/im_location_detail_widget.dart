import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../models/im_location.dart';
import '../models/im_item_category.dart';
import '../services/im_location_service.dart';
import '../widgets/im_item_category_list_tree_widget.dart';
import 'im_master_kit.dart';
import '../../sa/utils/sa_menu_theme.dart';

// หน้ารายละเอียดตำแหน่งจัดเก็บ (user 2026-11-25): ตัวเลขสรุป (สินค้าที่มียอด, มูลค่า, เป็นตำแหน่งเริ่มต้นของ, ลำดับเดิน/ช่องเก็บ),
// 2 กลุ่ม (ข้อมูลหลัก / การจัดเก็บ), การ์ดตำแหน่งย่อย (เมื่อเป็นกลุ่ม), การ์ดสินค้าในตำแหน่ง (ยอดแยกล็อต + ตำแหน่งเริ่มต้น)
// GROUP = จัดผังเท่านั้น (โซน/แถว), BIN = ช่องเก็บจริง กำหนดหมวดหมู่/เป็นตำแหน่งหลักของคลังได้
// mode addChild: selected = กลุ่มแม่ (ฟอร์มว่าง)
class ImLocationDetailWidget extends StatefulWidget {
  final Mode mode;
  final ImLocation? selected;
  final int warehouseId;
  final Future<void> Function(ImLocation) onSubmit;
  final VoidCallback onCancel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddChild;
  final ValueChanged<int>? onOpenChild;
  /// เส้นทาง เช่น "W01 › A โซนสินค้าทั่วไป › A-01 แถว 1"
  final String parentPath;
  final bool isPlaceholder;
  final int requestSeq;

  const ImLocationDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.warehouseId,
    required this.onSubmit,
    required this.onCancel,
    this.onEdit,
    this.onDelete,
    this.onAddChild,
    this.onOpenChild,
    this.parentPath = '',
    this.isPlaceholder = false,
    this.requestSeq = 0,
  });

  @override
  State<ImLocationDetailWidget> createState() => ImLocationDetailWidgetState();
}

class ImLocationDetailWidgetState extends State<ImLocationDetailWidget> with ImMasterKit {
  final _svc = ImLocationService();
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _nameEnCtrl = TextEditingController();
  final _sortOrderCtrl = TextEditingController();
  bool _isActive = true;
  bool _isDefault = false;
  bool _isSaving = false;
  bool _isEnglish = false;
  String _locationType = 'BIN';
  int? _categoryId; String? _categoryCode; String? _categoryNameTh; String? _categoryNameEn;

  ImLocationSummary? _summary;
  bool _loadingSummary = false;
  int _summarySeq = 0;
  String _snapshot = '';

  static final _qtyFmt = NumberFormat('#,##0.##');
  static final _amtFmt = NumberFormat('#,##0.00');

  bool get _isNew => widget.mode == Mode.addRoot || widget.mode == Mode.addChild;
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
  void didUpdateWidget(covariant ImLocationDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected || widget.mode != oldWidget.mode || widget.requestSeq != oldWidget.requestSeq) _apply();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _nameEnCtrl.dispose();
    _sortOrderCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final l = _isNew ? null : widget.selected;
    _codeCtrl.text = l?.locationCode ?? '';
    _nameCtrl.text = l?.locationName ?? '';
    _nameEnCtrl.text = l?.locationNameEn ?? '';
    _sortOrderCtrl.text = l?.sortOrder?.toString() ?? '';
    _isActive = l?.isActive ?? true;
    _isDefault = l?.isDefault ?? false;
    _locationType = l?.locationType ?? 'BIN';
    _categoryId = l?.categoryId;
    _categoryCode = l?.categoryCode;
    _categoryNameTh = l?.categoryNameTh;
    _categoryNameEn = l?.categoryNameEn;
    _summary = null;
    _summarySeq++;
    if (l != null && l.id != 0) _loadSummary(l.id);
    kScrollTop();
    _snapshot = _fingerprint();
  }

  Future<void> _loadSummary(int id) async {
    final seq = ++_summarySeq;
    _loadingSummary = true;
    try {
      final r = await _svc.fetchSummary(id);
      if (mounted && seq == _summarySeq) setState(() => _summary = r);
    } catch (_) {
    } finally {
      if (mounted && seq == _summarySeq) setState(() => _loadingSummary = false);
    }
  }

  ImLocation _build() => ImLocation(
        id: widget.mode == Mode.edit ? widget.selected!.id : 0,
        warehouseId: widget.warehouseId,
        parentId: widget.mode == Mode.addRoot
            ? null
            : widget.mode == Mode.addChild
                ? widget.selected?.id
                : widget.selected?.parentId,
        locationCode: _codeCtrl.text.trim().toUpperCase(),
        locationName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        locationNameEn: _nameEnCtrl.text.trim().isEmpty ? null : _nameEnCtrl.text.trim(),
        locationType: _locationType,
        categoryId: _locationType == 'BIN' ? _categoryId : null,
        isActive: _isActive,
        sortOrder: _sortOrderCtrl.text.trim().isEmpty ? null : int.tryParse(_sortOrderCtrl.text.trim()),
        isDefault: _isDefault && _isActive && _locationType == 'BIN',
      );

  String _fingerprint() => docFingerprint(_build().toJson());

  Future<void> _save() async {
    final e = _isEnglish;
    if (_codeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e ? 'Please enter the location code' : 'กรุณาป้อนรหัสตำแหน่ง'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await widget.onSubmit(_build());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickCategory() async {
    final isEnglish = _isEnglish;
    await ImItemCategoryListTreeWidget.search(context, onSelected: (ImItemCategory c) {
      setState(() {
        _categoryId = c.id; _categoryCode = c.categoryCode;
        _categoryNameTh = c.categoryNameTh; _categoryNameEn = c.categoryNameEn;
      });
      if (c.categoryType != 'CATEGORY') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish
              ? 'Note: "${c.categoryCode}" is a header, not a real category — pick a leaf category instead'
              : 'ข้อสังเกต: "${c.categoryCode}" เป็นหัวข้อ ไม่ใช่หมวดหมู่จริง — ควรเลือกหมวดหมู่ปลายทาง'),
          backgroundColor: Colors.orange,
        ));
      }
    });
  }

  String get _categoryName => _isEnglish && (_categoryNameEn ?? '').isNotEmpty ? _categoryNameEn! : (_categoryNameTh ?? '');

  // ── การ์ด ──
  Widget _mainCard() {
    final e = _isEnglish;
    final ed = !_isReadOnly;
    final bin = _locationType == 'BIN';
    final parentText = widget.mode == Mode.addChild
        ? '${widget.parentPath.isEmpty ? '' : '${widget.parentPath} › '}${widget.selected?.locationCode ?? ''} ${widget.selected?.displayName(e) ?? ''}'
        : (widget.parentPath.isEmpty ? (e ? '— Top level —' : '— ระดับบนสุด —') : widget.parentPath);
    return kCard(
      title: e ? 'Location Information' : 'ข้อมูลตำแหน่ง',
      trailing: _isReadOnly ? null : kLegend(),
      child: kGroups([
        kGroup(1, e ? 'Main Information' : 'ข้อมูลหลัก', ImKit.gDoc, [
          kRow([
            kTxt(_isNew ? (e ? 'Location Code *' : 'รหัสตำแหน่ง *') : (e ? 'Location Code' : 'รหัสตำแหน่ง'), _codeCtrl,
                editable: _isNew, cap: TextCapitalization.characters),
            kDd<String>(e ? 'Type' : 'ประเภท', _locationType, [
              DropdownMenuItem(value: 'GROUP', child: Text(e ? 'Group (GROUP)' : 'กลุ่ม (GROUP)')),
              DropdownMenuItem(value: 'BIN', child: Text(e ? 'Bin (BIN)' : 'ช่องเก็บ (BIN)')),
            ], ed ? (v) => setState(() => _locationType = v ?? 'BIN') : null),
          ]),
          kRow([
            kTxt(e ? 'Location Name (Thai)' : 'ชื่อตำแหน่ง (ไทย)', _nameCtrl),
            kTxt(e ? 'Location Name (English)' : 'ชื่อตำแหน่ง (อังกฤษ)', _nameEnCtrl),
          ]),
          InputDecorator(
            decoration: kDec(e ? 'Parent' : 'อยู่ภายใต้', editable: false),
            child: Text(parentText, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: ImKit.font)),
          ),
          kNote(bin
              ? (e ? 'A real storage slot — can be assigned a category and hold stock' : 'ช่องเก็บจริง — กำหนดหมวดหมู่และเก็บสินค้าได้')
              : (e ? 'Organizational only (zone/aisle) — cannot hold stock or a category' : 'ใช้จัดกลุ่มในผังเท่านั้น (โซน/แถว) — เก็บสินค้าหรือกำหนดหมวดหมู่ไม่ได้')),
        ]),
        kGroup(2, e ? 'Storage' : 'การจัดเก็บ', ImKit.gParty, [
          Opacity(
            opacity: bin ? 1 : 0.45,
            child: IgnorePointer(
              ignoring: !bin,
              child: kFk(
                label: e ? 'Assigned Category' : 'หมวดหมู่ที่กำหนดให้เก็บ',
                hasValue: bin && _categoryId != null,
                text: '$_categoryCode  $_categoryName',
                onSearch: _pickCategory,
                onClear: () => setState(() { _categoryId = null; _categoryCode = null; _categoryNameTh = null; _categoryNameEn = null; }),
              ),
            ),
          ),
          kRow([
            kTxt(e ? 'Walk Sequence (for count sheets)' : 'ลำดับการเดินตรวจนับ', _sortOrderCtrl, numeric: true, digitsOnly: true),
            const SizedBox.shrink(),
          ]),
          kChecks([
            // ตำแหน่งหลักของคลัง — 1 ตำแหน่งต่อคลัง เฉพาะ BIN ที่ใช้งาน ใช้เป็นตำแหน่งเริ่มต้นของรายการในเอกสาร IM ใหม่
            kCk(e ? 'Main location of the warehouse' : 'ตำแหน่งหลักของคลัง', _isDefault && _isActive && bin,
                ed && _isActive && bin ? (v) => setState(() => _isDefault = v) : null,
                tooltip: e ? 'Default location on new inventory document lines; one per warehouse' : 'ตำแหน่งเริ่มต้นของรายการในเอกสารสินค้าใหม่ มีได้ 1 ตำแหน่งต่อคลัง'),
            kCk(e ? 'Active' : 'ใช้งาน', _isActive, ed ? (v) => setState(() => _isActive = v) : null),
          ]),
        ]),
      ]),
    );
  }

  Widget _childrenCard() {
    final e = _isEnglish;
    final s = _summary;
    final kids = s?.children ?? const <ImLocationChildRow>[];
    return kCard(
      title: e ? 'Sub-locations' : 'ตำแหน่งย่อย',
      count: s == null ? null : (e ? '${kids.length} location(s)' : '${kids.length} ตำแหน่ง'),
      trailing: widget.onAddChild != null ? kGhost(e ? 'Add sub-location' : 'เพิ่มตำแหน่งย่อย', Icons.add, widget.onAddChild) : null,
      padding: EdgeInsets.zero,
      child: s == null
          ? const SizedBox(height: 40)
          : kTable([
              KCol(e ? 'Code' : 'รหัส', 3),
              KCol(e ? 'Name' : 'ชื่อ', 4),
              KCol(e ? 'Type' : 'ประเภท', 2),
              KCol(e ? 'Category' : 'หมวด', 2),
              KCol(e ? 'Items' : 'สินค้า', 2, num: true),
              KCol(e ? 'Walk seq.' : 'ลำดับเดิน', 2, num: true),
            ], [
              for (final k in kids)
                [
                  kCell(k.code, bold: true, color: k.isActive ? ScreenTheme.of(context).ink : ImKit.ink3),
                  kCell(k.displayName(e)),
                  k.type == 'GROUP' ? ImKit.chip(e ? 'Group' : 'กลุ่ม', ImKit.ro, ImKit.gMore) : ImKit.chip(e ? 'Bin' : 'ช่องเก็บ', ImKit.goldSoft, ImKit.amber),
                  kCell(k.categoryCode ?? ''),
                  kCell(k.type == 'BIN' ? '${k.itemCount}' : '', mono: true),
                  kCell(k.sortOrder?.toString() ?? '', mono: true),
                ],
            ],
              onTap: widget.onOpenChild == null ? null : [for (final k in kids) () => widget.onOpenChild!(k.id)],
              minWidth: 640,
              empty: e ? 'No sub-location yet' : 'ยังไม่มีตำแหน่งย่อย'),
    );
  }

  Widget _itemsCard() {
    final e = _isEnglish;
    final s = _summary;
    final group = widget.selected?.locationType == 'GROUP';
    final items = s?.items ?? const <ImLocationItemRow>[];
    return kCard(
      title: e ? 'Items in Location' : 'สินค้าในตำแหน่ง',
      count: e
          ? 'Read-only · stock by lot + items with this as default location${group ? ' (all bins in this group)' : ''}'
          : 'อ่านอย่างเดียว · ยอดคงเหลือแยกล็อต + สินค้าที่ตั้งเป็นตำแหน่งเริ่มต้น${group ? ' (ทุกช่องใต้กลุ่ม)' : ''}',
      padding: EdgeInsets.zero,
      child: s == null
          ? Padding(
              padding: const EdgeInsets.all(14),
              child: Center(child: _loadingSummary ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const SizedBox.shrink()),
            )
          : kTable([
              KCol(e ? 'Item' : 'สินค้า', 6),
              if (group) KCol(e ? 'Location' : 'ตำแหน่ง', 2),
              KCol(e ? 'Lot' : 'ล็อต', 2),
              KCol(e ? 'On hand' : 'คงเหลือ', 3, num: true),
              KCol(e ? 'Value' : 'มูลค่า', 3, num: true),
              KCol(e ? 'Default location' : 'ตำแหน่งเริ่มต้น', 2),
            ], [
              for (final it in items)
                [
                  kCell('${it.itemCode}  ${it.displayName(e)}'),
                  if (group) kCell(it.locationCode ?? ''),
                  kCell(it.lotNo ?? ''),
                  kCell('${_qtyFmt.format(it.qty)} ${it.uomName(e)}', mono: true),
                  kCell(_amtFmt.format(it.value), mono: true),
                  it.isDefault ? ImKit.chip(e ? 'Yes' : 'ใช่', ImKit.okSoft, ImKit.ok) : kCell(''),
                ],
            ], minWidth: group ? 780 : 680, empty: e ? 'No stock in this location yet' : 'ยังไม่มีสินค้าในตำแหน่งนี้'),
    );
  }

  List<ImKpi> _kpis() {
    final e = _isEnglish;
    final s = _summary;
    if (s == null) return const [];
    final group = widget.selected?.locationType == 'GROUP';
    return [
      ImKpi(e ? 'Items with stock' : 'สินค้าที่มียอด', '${s.itemCount}', group ? (e ? 'in all bins of this group' : 'ในทุกช่องใต้กลุ่ม') : (e ? 'in this bin' : 'ในช่องเก็บนี้')),
      ImKpi(e ? 'Stock value' : 'มูลค่าคงเหลือ', _amtFmt.format(s.stockValue), e ? 'At average cost' : 'ตามต้นทุนเฉลี่ย'),
      ImKpi(e ? 'Default location of' : 'เป็นตำแหน่งเริ่มต้นของ', '${s.defaultCount}', e ? 'item(s) (warehouse settings)' : 'สินค้า (ตั้งค่าต่อคลัง)'),
      group
          ? ImKpi(e ? 'Bins in this group' : 'ช่องเก็บใต้กลุ่ม', '${s.binCount}', e ? 'all levels' : 'ทุกระดับ')
          : ImKpi(e ? 'Walk sequence' : 'ลำดับเดินตรวจนับ', widget.selected?.sortOrder?.toString() ?? '—', e ? 'on count sheets' : 'ในใบตรวจนับ'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    _isEnglish = context.watch<LanguageProvider>().isEnglish;
    final e = _isEnglish;
    if (widget.isPlaceholder) {
      return kPlaceholder(Icons.grid_view, e ? 'Select a location on the left to view its data' : 'เลือกตำแหน่งทางซ้ายเพื่อดูข้อมูล');
    }
    final saved = !_isNew && widget.selected != null;
    final l = widget.selected;
    final title = saved
        ? l!.displayName(e)
        : widget.mode == Mode.addChild
            ? (e ? 'Add sub-location under ${l?.locationCode ?? ''}' : 'เพิ่มตำแหน่งย่อยของ ${l?.locationCode ?? ''} ${l?.displayName(e) ?? ''}')
            : (e ? 'Add Zone' : 'เพิ่มโซน');
    return kPage(
      header: kHeaderBar(
        code: saved ? l!.locationCode : null,
        title: title,
        badges: [
          if (widget.mode == Mode.edit) kEditingBadge(),
          if (saved)
            l!.locationType == 'GROUP'
                ? ImKit.chip(e ? 'Group' : 'กลุ่ม', ImKit.ro, ImKit.gMore)
                : ImKit.chip(e ? 'Bin' : 'ช่องเก็บ', ImKit.goldSoft, ImKit.amber),
          if (saved && l!.isDefault) ImKit.chip(e ? 'Main location' : 'ตำแหน่งหลัก', ImKit.blueSoft, ImKit.blue),
          if (saved) ImKit.activeChip(_isActive, e),
          if (saved && widget.parentPath.isNotEmpty) Text(widget.parentPath, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
        acts: kStdActs(
          saving: _isSaving,
          onEdit: widget.onEdit,
          onDelete: widget.onDelete,
          onClose: widget.onCancel,
          onCancel: widget.onCancel,
          onSave: _save,
          extra: [
            if (widget.onAddChild != null) DocBarAction(e ? '+ Sub-location' : '+ ตำแหน่งย่อย', widget.onAddChild, fg: ScreenTheme.of(context).ink),
          ],
        ),
        busy: _isSaving,
      ),
      top: saved ? kKpis(_kpis(), loading: _loadingSummary) : null,
      sections: [
        (0, e ? 'Main' : 'ข้อมูลหลัก', _mainCard()),
        if (saved && l!.locationType == 'GROUP') (1, e ? 'Sub-locations' : 'ตำแหน่งย่อย', _childrenCard()),
        if (saved) (2, e ? 'Items in location' : 'สินค้าในตำแหน่ง', _itemsCard()),
      ],
    );
  }
}
