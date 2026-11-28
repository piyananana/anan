import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../models/im_price_group.dart';
import '../models/im_price_list.dart';
import '../services/im_price_list_service.dart';
import 'im_master_kit.dart';

// หน้ารายละเอียดกลุ่มราคา (แบบ B, user 2026-11-25): 2 กลุ่ม (ข้อมูลหลัก / เพิ่มเติม) +
// การ์ดตารางราคาในกลุ่มนี้ (อ่านอย่างเดียว + ปุ่มไปหน้าตารางราคา)
class ImPriceGroupDetailWidget extends StatefulWidget {
  final Mode mode;
  final ImPriceGroup? selected;
  final Future<void> Function(ImPriceGroup) onSubmit;
  final VoidCallback onCancel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isPlaceholder;
  // เพิ่มขึ้นทุกครั้งที่ผู้ใช้กดปุ่มเพิ่ม/แก้ไข/ดู/ยกเลิกจากหน้าจอหลัก — บังคับให้ฟอร์มเคลียร์เสมอแม้ mode/selected ซ้ำ
  final int requestSeq;

  const ImPriceGroupDetailWidget({
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
  State<ImPriceGroupDetailWidget> createState() => ImPriceGroupDetailWidgetState();
}

class ImPriceGroupDetailWidgetState extends State<ImPriceGroupDetailWidget> with ImMasterKit {
  final _codeCtrl = TextEditingController();
  final _nameThCtrl = TextEditingController();
  final _nameEnCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isActive = true;
  bool _isSaving = false;
  bool _isEnglish = false;

  List<ImPriceListHeader>? _lists;
  int _listSeq = 0;
  String _snapshot = '';

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
  void didUpdateWidget(covariant ImPriceGroupDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected || widget.mode != oldWidget.mode || widget.requestSeq != oldWidget.requestSeq) _apply();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameThCtrl.dispose();
    _nameEnCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final g = widget.mode == Mode.add ? null : widget.selected;
    _codeCtrl.text = g?.priceGroupCode ?? '';
    _nameThCtrl.text = g?.priceGroupNameTh ?? '';
    _nameEnCtrl.text = g?.priceGroupNameEn ?? '';
    _descCtrl.text = g?.description ?? '';
    _isActive = g?.isActive ?? true;
    _lists = null;
    _listSeq++;
    if (g != null && g.id != 0) _loadLists(g.id);
    kScrollTop();
    _snapshot = _fingerprint();
  }

  Future<void> _loadLists(int groupId) async {
    final seq = ++_listSeq;
    try {
      final rows = await ImPriceListService().fetchRows(priceGroupIds: [groupId]);
      if (mounted && seq == _listSeq) setState(() => _lists = rows);
    } catch (_) {
      if (mounted && seq == _listSeq) setState(() => _lists = const []);
    }
  }

  ImPriceGroup _build() => ImPriceGroup(
        id: widget.mode == Mode.edit ? widget.selected!.id : 0,
        priceGroupCode: _codeCtrl.text.trim().toUpperCase(),
        priceGroupNameTh: _nameThCtrl.text.trim(),
        priceGroupNameEn: _nameEnCtrl.text.trim().isEmpty ? null : _nameEnCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        isActive: _isActive,
      );

  String _fingerprint() => docFingerprint(_build().toJson());

  Future<void> _save() async {
    final e = _isEnglish;
    String? err;
    if (_codeCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter the price group code' : 'กรุณาป้อนรหัสกลุ่มราคา';
    } else if (_nameThCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter the price group name (Thai)' : 'กรุณาป้อนชื่อกลุ่มราคา (ไทย)';
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
      title: e ? 'Price Group Information' : 'ข้อมูลกลุ่มราคา',
      trailing: _isReadOnly ? null : kLegend(withAuto: false),
      child: kGroups([
        kGroup(1, e ? 'Main Information' : 'ข้อมูลหลัก', ImKit.gDoc, [
          kRow([
            kTxt(widget.mode == Mode.add ? (e ? 'Price Group Code *' : 'รหัสกลุ่มราคา *') : (e ? 'Price Group Code' : 'รหัสกลุ่มราคา'), _codeCtrl,
                editable: widget.mode == Mode.add, cap: TextCapitalization.characters),
            const SizedBox.shrink(),
          ]),
          kRow([
            kTxt(e ? 'Price Group Name (Thai) *' : 'ชื่อกลุ่มราคา (ไทย) *', _nameThCtrl),
            kTxt(e ? 'Price Group Name (English)' : 'ชื่อกลุ่มราคา (อังกฤษ)', _nameEnCtrl),
          ]),
        ]),
        kGroup(2, e ? 'More' : 'เพิ่มเติม', ImKit.gMore, [
          kTxt(e ? 'Description' : 'คำอธิบาย', _descCtrl),
          kChecks([kCk(e ? 'Active' : 'ใช้งาน', _isActive, ed ? (v) => setState(() => _isActive = v) : null)]),
        ]),
      ]),
    );
  }

  Widget _listsCard() {
    final e = _isEnglish;
    final lists = _lists;
    return kCard(
      title: e ? 'Price Lists in This Group' : 'ตารางราคาในกลุ่มนี้',
      count: lists == null ? null : (e ? 'Read-only · ${lists.length} list(s)' : 'อ่านอย่างเดียว · ${lists.length} ตาราง'),
      trailing: kGhost(e ? 'Open Price List' : 'ไปหน้าตารางราคา', Icons.open_in_new,
          () => ImKit.openMenu(context, 'ImPriceListScreen', 'ตารางราคา', 'Price List', e)),
      padding: EdgeInsets.zero,
      child: lists == null
          ? const Padding(padding: EdgeInsets.all(14), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
          : kTable([
              KCol(e ? 'Price list' : 'ตารางราคา', 5),
              KCol(e ? 'Type' : 'ประเภท', 3),
              KCol(e ? 'Currency' : 'สกุลเงิน', 2),
              KCol(e ? 'Incl. VAT' : 'รวม VAT', 2),
              KCol(e ? 'Lines' : 'รายการ', 2, num: true),
              KCol(e ? 'Status' : 'สถานะ', 2),
            ], [
              for (final l in lists)
                [
                  kCell('${l.priceListCode}  ${l.priceListName}'),
                  kCell('${imPriceListTypeLabel(l.listType, e)}${l.isDefault ? (e ? ' · default' : ' · ค่าเริ่มต้น') : ''}'),
                  kCell(l.currencyCode ?? ''),
                  kCell(l.priceIncludesVat ? (e ? 'Incl.' : 'รวม') : (e ? 'Excl.' : 'ไม่รวม')),
                  kCell('${l.lineCount}', mono: true),
                  ImKit.activeChip(l.isActive, e),
                ],
            ], minWidth: 680, empty: e ? 'No price list uses this group yet' : 'ยังไม่มีตารางราคาในกลุ่มนี้'),
    );
  }

  @override
  Widget build(BuildContext context) {
    _isEnglish = context.watch<LanguageProvider>().isEnglish;
    final e = _isEnglish;
    if (widget.isPlaceholder) {
      return kPlaceholder(Icons.sell_outlined, e ? 'Select a price group on the left to view its data' : 'เลือกกลุ่มราคาทางซ้ายเพื่อดูข้อมูล');
    }
    final saved = widget.mode != Mode.add && widget.selected != null;
    return kPage(
      header: kHeaderBar(
        code: saved ? widget.selected!.priceGroupCode : null,
        title: saved ? widget.selected!.displayName(e) : (e ? 'Add Price Group' : 'เพิ่มกลุ่มราคา'),
        badges: [
          if (widget.mode == Mode.edit) kEditingBadge(),
          if (saved) ImKit.activeChip(_isActive, e),
        ],
        acts: kStdActs(saving: _isSaving, onEdit: widget.onEdit, onDelete: widget.onDelete, onClose: widget.onCancel,
            onCancel: widget.onCancel, onSave: _save),
        busy: _isSaving,
      ),
      sections: [
        (0, e ? 'Main' : 'ข้อมูลหลัก', _mainCard()),
        if (saved) (1, e ? 'Price lists in this group' : 'ตารางราคาในกลุ่มนี้', _listsCard()),
      ],
    );
  }
}
