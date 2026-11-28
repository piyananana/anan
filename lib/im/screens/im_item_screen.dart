import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../models/im_item.dart';
import '../services/im_item_service.dart';
import '../widgets/im_item_list_widget.dart';
import '../widgets/im_item_detail_widget.dart';
import '../../sa/utils/sa_menu_theme.dart';

// หน้าจอข้อมูลสินค้า — แบบ B (user 2026-11-25): ซ้ายการ์ดสินค้าพร้อมคงเหลือ / ขวารายละเอียดเลื่อนหน้าเดียว
// คลิกการ์ด = ดู; ปุ่มแก้ไข/สำเนาเป็นสินค้าใหม่/ลบ อยู่ที่แถบหัวด้านขวา; มีแก้ไขค้าง → ยืนยันก่อนเปลี่ยนสินค้า
class ImItemScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;
  final VoidCallback? onExit;

  const ImItemScreen({
    super.key,
    required this.onFieldsChanged,
    this.onExit,
  });

  @override
  State<ImItemScreen> createState() => _ImItemScreenState();
}

class _ImItemScreenState extends State<ImItemScreen> with AutomaticKeepAliveClientMixin {
  final GlobalKey<ImItemListWidgetState> _listKey = GlobalKey();
  final GlobalKey<ImItemDetailWidgetState> _detailKey = GlobalKey();
  final _svc = ImItemService();

  Mode _mode = Mode.none;
  ImItem? _selectedData;
  ImItem? _copyFrom;
  // โหลดข้อมูลเต็ม (หน่วย/คลัง/ล็อกหน่วยหลัก) เสร็จแล้ว — ก่อนหน้านั้นยังแก้ไข/สำเนาไม่ได้
  bool _fullLoaded = false;
  // เพิ่มขึ้นทุกครั้งที่เปลี่ยน mode ของแผงขวา — ส่งให้ ImItemDetailWidget เพื่อบังคับเคลียร์ฟอร์มเสมอ
  // แม้ mode/selected จะซ้ำกับครั้งก่อน (เช่น กด "เพิ่มสินค้า" ซ้ำหลังพิมพ์ข้อมูลค้างไว้)
  int _requestSeq = 0;

  bool _isLeftPanelExpanded = true;
  double _leftPanelWidth = 320.0;
  bool _isDraggingDivider = false;

  Color get _bar => ScreenTheme.of(context).bar;
  static const _gold = Color(0xFFE0A526);

  @override
  bool get wantKeepAlive => true;

  bool get _isEnglish => Provider.of<LanguageProvider>(context, listen: false).isEnglish;

  Future<bool> _confirmLeave() async {
    final d = _detailKey.currentState;
    if (d != null && d.isDirty) return confirmDiscardChanges(context, _isEnglish);
    return true;
  }

  Future<void> _onAdd() async {
    if (!await _confirmLeave()) return;
    setState(() {
      _mode = Mode.add;
      _selectedData = null;
      _copyFrom = null;
      _requestSeq++;
    });
  }

  void _onCopy() {
    final src = _selectedData;
    if (src == null) return;
    setState(() {
      _mode = Mode.add;
      _selectedData = null;
      _copyFrom = src;
      _requestSeq++;
    });
  }

  void _onEdit() {
    if (_selectedData == null) return;
    setState(() {
      _mode = Mode.edit;
      _copyFrom = null;
      _requestSeq++;
    });
  }

  Future<void> _onView(ImItem row) async {
    if (_mode != Mode.none && _selectedData?.id == row.id && _mode == Mode.view) return;
    if (!await _confirmLeave()) return;
    _show(row);
  }

  void _show(ImItem row) {
    setState(() {
      _mode = Mode.view;
      _selectedData = row;
      _copyFrom = null;
      _fullLoaded = false;
      _requestSeq++;
    });
    _fetchFull(row);
  }

  Future<void> _fetchFull(ImItem row) async {
    if (row.id == null) return;
    try {
      final full = await _svc.fetchRow(row.id!);
      // ผู้ใช้เปลี่ยนไปสินค้าอื่น/เริ่มแก้ไขแล้ว — ไม่ทับฟอร์ม
      if (!mounted || _selectedData?.id != row.id || _mode != Mode.view) return;
      setState(() {
        _selectedData = full;
        _fullLoaded = true;
      });
    } catch (_) {}
  }

  Future<void> _onDelete() async {
    final row = _selectedData;
    if (row?.id == null) return;
    final isEnglish = _isEnglish;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEnglish ? 'Confirm Delete' : 'ยืนยันการลบ'),
        content: Text(isEnglish
            ? 'Are you sure you want to delete item "${row!.itemCode} ${row.itemNameTh}" ?'
            : 'คุณแน่ใจหรือไม่ที่จะลบสินค้า "${row!.itemCode} ${row.itemNameTh}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(isEnglish ? 'Delete' : 'ลบ', style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _svc.deleteRow(row!.id!);
      _listKey.currentState?.refresh();
      _close();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Deleted successfully' : 'ลบสำเร็จ')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEnglish ? 'Error deleting: $e' : 'เกิดข้อผิดพลาดในการลบ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // บันทึกแล้วแสดงสินค้านั้นต่อ (ไม่ปิดแผงขวา) — ไล่แก้หลายสินค้าต่อกันได้
  Future<void> _onSubmit(ImItem row) async {
    final isEnglish = _isEnglish;
    try {
      final ImItem saved;
      if (_mode == Mode.add) {
        saved = await _svc.addRow(row);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Added ${saved.itemCode}' : 'เพิ่มสินค้า ${saved.itemCode} สำเร็จ')));
        }
      } else {
        saved = await _svc.updateRow(row);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Saved successfully' : 'บันทึกสำเร็จ')));
        }
      }
      _listKey.currentState?.refresh();
      widget.onFieldsChanged();
      if (mounted) _show(saved);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ยกเลิก: แก้ไข → กลับไปดูสินค้าเดิม, สำเนา → กลับไปดูต้นฉบับ, อื่นๆ → ปิดแผงขวา
  Future<void> _onCancel() async {
    if (!await _confirmLeave()) return;
    if (_mode == Mode.edit && _selectedData != null) {
      _show(_selectedData!);
    } else if (_mode == Mode.add && _copyFrom != null) {
      _show(_copyFrom!);
    } else {
      _close();
    }
  }

  void _close() => setState(() {
        _mode = Mode.none;
        _selectedData = null;
        _copyFrom = null;
        _requestSeq++;
      });

  // ปุ่มย่อ/ขยายรายการซ้าย — อยู่บนแถบหัวแผงขวา หน้ารหัส/ชื่อสินค้า (แบบเดียวกับปุ่มย่อแถบเมนู)
  Widget _listToggle(bool onHeader) {
    final isEnglish = _isEnglish;
    return IconButton(
      icon: Icon(_isLeftPanelExpanded ? Icons.menu_open_rounded : Icons.menu_rounded,
          color: onHeader ? Colors.white : Colors.blueGrey.shade700),
      tooltip: _isLeftPanelExpanded ? (isEnglish ? 'Collapse list' : 'ย่อรายการ') : (isEnglish ? 'Expand list' : 'ขยายรายการ'),
      onPressed: () => setState(() => _isLeftPanelExpanded = !_isLeftPanelExpanded),
    );
  }

  Widget _buildRightPanel(bool canCreate, bool canEdit, bool canDelete) {
    if (_mode == Mode.none) {
      return ImItemDetailWidget(key: _detailKey, mode: Mode.none, selected: null, onSubmit: (_) async {}, onCancel: _close,
          isPlaceholder: true, leading: _listToggle(false), requestSeq: _requestSeq);
    }
    final view = _mode == Mode.view;
    return ImItemDetailWidget(
      key: _detailKey,
      mode: _mode,
      selected: _mode == Mode.add ? null : _selectedData,
      copyFrom: _mode == Mode.add ? _copyFrom : null,
      onSubmit: _onSubmit,
      onCancel: view ? _close : _onCancel,
      onEdit: view && canEdit ? (_fullLoaded ? _onEdit : null) : null,
      onCopy: view && canCreate ? (_fullLoaded ? _onCopy : null) : null,
      onDelete: view && canDelete ? _onDelete : null,
      leading: _listToggle(true),
      requestSeq: _requestSeq,
    );
  }

  Widget _barButton(String label, IconData icon, VoidCallback onPressed, {bool primary = false}) {
    final font = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    final style = TextStyle(fontFamily: font, fontWeight: FontWeight.w600, fontSize: 13);
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: primary
          ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 16),
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: const Color(0xFF0B3A2A),
                textStyle: style,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 34),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 16),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
                textStyle: style,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 34),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
              ),
            ),
    );
  }

  void _openImport() {
    if (!MenuOpener.open('ImItemImportScreen')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEnglish ? 'You do not have access to the Item Import menu' : 'ไม่มีสิทธิ์เข้าถึงเมนูนำเข้าข้อมูลสินค้า'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final perm = MenuScope.of(context);
    final canCreate = perm?.canCreate ?? true;
    final canEdit = perm?.canEdit ?? true;
    final canDelete = perm?.canDelete ?? true;
    final narrow = MediaQuery.sizeOf(context).width < 700;
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: _bar,
        foregroundColor: Colors.white,
        actions: [
          if (canCreate && !narrow) _barButton(isEnglish ? 'Import' : 'นำเข้าข้อมูล', Icons.upload_file, _openImport),
          if (canCreate) _barButton(isEnglish ? 'Add item' : 'เพิ่มสินค้า', Icons.add, _onAdd, primary: true),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: isEnglish ? 'Refresh' : 'รีเฟรชรายการ',
            onPressed: () async {
              if (!await _confirmLeave()) return;
              _listKey.currentState?.refresh();
              if (_selectedData != null && _mode != Mode.add) {
                _show(_selectedData!);
              } else {
                _close();
              }
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double maxLeftWidth = (constraints.maxWidth - 5 - 300).clamp(100.0, double.infinity);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedContainer(
                duration: _isDraggingDivider ? Duration.zero : const Duration(milliseconds: 200),
                width: _isLeftPanelExpanded ? _leftPanelWidth : 0.0,
                child: ClipRect(
                  child: OverflowBox(
                    maxWidth: _leftPanelWidth,
                    minWidth: _leftPanelWidth,
                    alignment: Alignment.topLeft,
                    child: ColoredBox(
                      color: const Color(0xFFCFD8DC),
                      child: ImItemListWidget(
                        key: _listKey,
                        enableAddButton: false,
                        enableEditButton: false,
                        enableViewButton: true,
                        enableDeleteButton: false,
                        selectedId: _mode == Mode.view || _mode == Mode.edit ? _selectedData?.id : null,
                        onAdd: _onAdd,
                        onEdit: _onView,
                        onView: _onView,
                        onDelete: (_) {},
                        onCallback: _onView,
                      ),
                    ),
                  ),
                ),
              ),
              if (_isLeftPanelExpanded)
                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    onHorizontalDragStart: (_) => setState(() => _isDraggingDivider = true),
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _leftPanelWidth = (_leftPanelWidth + details.delta.dx).clamp(220.0, maxLeftWidth);
                      });
                    },
                    onHorizontalDragEnd: (_) => setState(() => _isDraggingDivider = false),
                    child: Container(width: 5, color: Colors.grey[400]),
                  ),
                ),
              Expanded(child: _buildRightPanel(canCreate, canEdit, canDelete)),
            ],
          );
        },
      ),
    );
  }
}
