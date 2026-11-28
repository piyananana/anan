import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../models/im_uom.dart';
import '../services/im_uom_service.dart';
import 'im_master_kit.dart';
import 'im_uom_std_conversion_section.dart';

// หน้ารายละเอียดหน่วยนับ (แบบ B, user 2026-11-25): ตัวเลขการใช้งาน, 2 กลุ่ม (ข้อมูลหลัก / การวัด),
// การ์ดอัตราแปลงมาตรฐาน, การ์ดสินค้าที่ใช้หน่วยนี้ (อ่านอย่างเดียว)
class ImUomDetailWidget extends StatefulWidget {
  final Mode mode;
  final ImUom? selected;
  final Future<void> Function(ImUom) onSubmit;
  final VoidCallback onCancel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isPlaceholder;
  // เพิ่มขึ้นทุกครั้งที่ผู้ใช้กดปุ่มเพิ่ม/แก้ไข/ดู/ยกเลิกจากหน้าจอหลัก — ใช้บังคับให้ didUpdateWidget เคลียร์ฟอร์ม
  // เสมอ แม้ mode/selected จะ "เหมือนเดิม" กับครั้งก่อน (เช่น กดเพิ่มหน่วยนับซ้ำหลังพิมพ์ข้อมูลค้างไว้)
  final int requestSeq;

  const ImUomDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.onEdit,
    this.onDelete,
    this.isPlaceholder = false,
    this.requestSeq = 0,
  });

  @override
  State<ImUomDetailWidget> createState() => ImUomDetailWidgetState();
}

class ImUomDetailWidgetState extends State<ImUomDetailWidget> with ImMasterKit {
  final _svc = ImUomService();
  final _codeCtrl = TextEditingController();
  final _nameThCtrl = TextEditingController();
  final _nameEnCtrl = TextEditingController();
  bool _isActive = true;
  String _dimension = 'COUNT';
  int _decimals = 0;
  bool _isSaving = false;
  bool _isEnglish = false;

  ImUomSummary? _summary;
  bool _loadingSummary = false;
  int _summarySeq = 0;
  String _snapshot = '';

  static final _fmt = NumberFormat('#,##0.######');
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
  void didUpdateWidget(covariant ImUomDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected || widget.mode != oldWidget.mode || widget.requestSeq != oldWidget.requestSeq) _apply();
  }

  void _apply() {
    final s = widget.mode == Mode.add ? null : widget.selected;
    _codeCtrl.text = s?.uomCode ?? '';
    _nameThCtrl.text = s?.uomNameTh ?? '';
    _nameEnCtrl.text = s?.uomNameEn ?? '';
    _isActive = s?.isActive ?? true;
    _dimension = s?.uomDimension ?? 'COUNT';
    _decimals = s?.decimalPlaces ?? 0;
    _summary = null;
    _summarySeq++;
    if (s != null && s.id != 0) _loadSummary(s.id);
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

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameThCtrl.dispose();
    _nameEnCtrl.dispose();
    super.dispose();
  }

  ImUom _build() => ImUom(
        id: widget.mode == Mode.edit ? widget.selected!.id : 0,
        uomCode: _codeCtrl.text.trim().toUpperCase(),
        uomNameTh: _nameThCtrl.text.trim(),
        uomNameEn: _nameEnCtrl.text.trim().isEmpty ? null : _nameEnCtrl.text.trim(),
        isActive: _isActive,
        uomDimension: _dimension,
        decimalPlaces: _decimals,
      );

  String _fingerprint() => docFingerprint(_build().toJson());

  Future<void> _save() async {
    final e = _isEnglish;
    String? err;
    if (_codeCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter the UOM code' : 'กรุณาป้อนรหัสหน่วยนับ';
    } else if (_nameThCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter the UOM name (Thai)' : 'กรุณาป้อนชื่อหน่วยนับ (ไทย)';
    }
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await widget.onSubmit(_build());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _mainCard() {
    final e = _isEnglish;
    final ed = !_isReadOnly;
    return kCard(
      title: e ? 'Unit Information' : 'ข้อมูลหน่วยนับ',
      trailing: _isReadOnly ? null : kLegend(),
      child: kGroups([
        kGroup(1, e ? 'Main Information' : 'ข้อมูลหลัก', ImKit.gDoc, [
          kRow([
            kTxt(widget.mode == Mode.add ? (e ? 'UOM Code *' : 'รหัสหน่วยนับ *') : (e ? 'UOM Code' : 'รหัสหน่วยนับ'), _codeCtrl,
                editable: widget.mode == Mode.add, cap: TextCapitalization.characters),
            const SizedBox.shrink(),
          ]),
          kRow([
            kTxt(e ? 'UOM Name (Thai) *' : 'ชื่อหน่วยนับ (ไทย) *', _nameThCtrl),
            kTxt(e ? 'UOM Name (English)' : 'ชื่อหน่วยนับ (อังกฤษ)', _nameEnCtrl),
          ]),
        ]),
        kGroup(2, e ? 'Measurement' : 'การวัด', ImKit.gParty, [
          kRow([
            kDd<String>(e ? 'UOM Type' : 'ประเภทหน่วย', _dimension,
                kUomDimensions.map((d) => DropdownMenuItem(value: d, child: Text(uomDimensionLabel(d, e)))).toList(),
                ed ? (v) => setState(() => _dimension = v ?? 'COUNT') : null),
            kDd<int>(e ? 'Decimal Places' : 'ทศนิยม (ตำแหน่ง)', _decimals,
                [0, 1, 2, 3, 4, 5, 6].map((d) => DropdownMenuItem(value: d, child: Text('$d'))).toList(),
                ed ? (v) => setState(() => _decimals = v ?? 0) : null, auto: false),
          ]),
          // กฎ (2026-11-21): หน่วยนับจำนวนต้องลงตัว, หน่วยอื่นปัดตามทศนิยม
          kNote(_dimension == 'COUNT'
              ? (e
                  ? 'Count unit: quantities must fit $_decimals decimal place(s) exactly — a conversion that does not fit is rejected. Use 0 for whole pieces.'
                  : 'หน่วยนับจำนวน: จำนวนต้องลงตัวไม่เกิน $_decimals ตำแหน่ง ถ้าแปลงหน่วยแล้วไม่ลงตัวจะไม่ให้บันทึก หน่วยที่นับเป็นชิ้นให้ตั้ง 0')
              : (e
                  ? 'Quantities in this unit (including converted ones) are rounded to $_decimals decimal place(s).'
                  : 'จำนวนในหน่วยนี้ (รวมจำนวนที่แปลงมาจากหน่วยอื่น) จะปัดเป็น $_decimals ตำแหน่ง')),
          kChecks([kCk(e ? 'Active' : 'ใช้งาน', _isActive, ed ? (v) => setState(() => _isActive = v) : null)]),
        ]),
      ]),
    );
  }

  Widget _itemsCard() {
    final e = _isEnglish;
    final s = _summary;
    final total = (s?.baseCount ?? 0) + (s?.altCount ?? 0);
    final items = s?.items ?? const <ImUomItemUse>[];
    return kCard(
      title: e ? 'Items Using This Unit' : 'สินค้าที่ใช้หน่วยนี้',
      count: s == null
          ? null
          : e
              ? 'Read-only · $total item(s)${items.length < total ? ' (first ${items.length})' : ''}'
              : 'อ่านอย่างเดียว · $total สินค้า${items.length < total ? ' (แสดง ${items.length} แรก)' : ''}',
      padding: EdgeInsets.zero,
      child: s == null
          ? Padding(
              padding: const EdgeInsets.all(14),
              child: Center(child: _loadingSummary ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const SizedBox.shrink()),
            )
          : kTable([
              KCol(e ? 'Item' : 'สินค้า', 6),
              KCol(e ? 'Used as' : 'ใช้เป็น', 2),
              KCol(e ? 'Conversion' : 'อัตรา', 3, num: true),
            ], [
              for (final it in items)
                [
                  kCell('${it.itemCode}  ${it.displayName(e)}'),
                  it.role == 'BASE'
                      ? ImKit.chip(e ? 'Base unit' : 'หน่วยหลัก', ImKit.ro, ImKit.gMore)
                      : ImKit.chip(e ? 'Alt unit' : 'หน่วยรอง', ImKit.blueSoft, ImKit.blue),
                  kCell(it.role == 'BASE' ? '1' : '= ${_fmt.format(it.factor)} ${it.baseUomCode ?? ''}', mono: true),
                ],
            ], minWidth: 560, empty: e ? 'No item uses this unit yet' : 'ยังไม่มีสินค้าใช้หน่วยนี้'),
    );
  }

  List<ImKpi> _kpis() {
    final e = _isEnglish;
    final s = _summary;
    if (s == null) return const [];
    return [
      ImKpi(e ? 'Base unit of' : 'เป็นหน่วยหลักของ', '${s.baseCount}', e ? 'item(s)' : 'สินค้า'),
      ImKpi(e ? 'Alternate unit of' : 'เป็นหน่วยรองของ', '${s.altCount}', e ? 'item(s) (pack/carton)' : 'สินค้า (แพ็ค/ลัง)'),
      ImKpi(e ? 'Standard conversions' : 'อัตราแปลงมาตรฐาน', '${s.stdConversions.length}',
          s.stdConversions.isEmpty ? (e ? 'None' : 'ยังไม่มี') : s.stdConversions.join(', ')),
      ImKpi(e ? 'Last used on a document' : 'ใช้ในเอกสารล่าสุด', s.lastDocDate == null ? '—' : _dateFmt.format(s.lastDocDate!),
          s.lastDocNo == null ? (e ? 'Not used yet' : 'ยังไม่เคยใช้') : '${s.lastDocCode ?? ''} ${s.lastDocNo}'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    _isEnglish = context.watch<LanguageProvider>().isEnglish;
    final e = _isEnglish;
    if (widget.isPlaceholder) {
      return kPlaceholder(Icons.straighten, e ? 'Select a unit on the left to view its data' : 'เลือกหน่วยนับทางซ้ายเพื่อดูข้อมูล');
    }
    final saved = widget.mode != Mode.add && widget.selected != null;
    final header = kHeaderBar(
      code: saved ? widget.selected!.uomCode : null,
      title: saved
          ? (e && (widget.selected!.uomNameEn ?? '').isNotEmpty ? widget.selected!.uomNameEn! : widget.selected!.uomNameTh)
          : (e ? 'Add UOM' : 'เพิ่มหน่วยนับ'),
      badges: [
        if (widget.mode == Mode.edit) kEditingBadge(),
        if (saved) ImKit.activeChip(_isActive, e),
      ],
      acts: kStdActs(saving: _isSaving, onEdit: widget.onEdit, onDelete: widget.onDelete, onClose: widget.onCancel,
          onCancel: widget.onCancel, onSave: _save),
      busy: _isSaving,
    );
    return kPage(
      header: header,
      top: saved ? kKpis(_kpis(), loading: _loadingSummary) : null,
      sections: [
        (0, e ? 'Main' : 'ข้อมูลหลัก', _mainCard()),
        if (saved) (1, e ? 'Standard conversions' : 'อัตราแปลงมาตรฐาน', ImUomStdConversionSection(uom: widget.selected!, readOnly: _isReadOnly)),
        if (saved) (2, e ? 'Items using this unit' : 'สินค้าที่ใช้หน่วยนี้', _itemsCard()),
      ],
    );
  }
}
