// screens/user_document_screen.dart

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../services/language_provider.dart';
import '../utils/app_l10n.dart';
import '../utils/menu_scope.dart';
import 'dart:collection'; // สำหรับ HashSet

import '../models/anan_module.dart';
import '../models/module_document.dart';
import '../models/user.dart';
import '../services/user_service.dart';
import '../services/module_document_service.dart'; 
import '../services/user_document_service.dart'; 
import '../widgets/user_list_widget.dart'; // ใช้ UserListPanel เดิมแต่เปลี่ยน callback
import '../widgets/user_document_detail_tree_widget.dart';

class UserDocumentScreen extends StatefulWidget {
  final VoidCallback? onExit;

  const UserDocumentScreen({
    super.key,
    this.onExit,
  });

  @override
  State<UserDocumentScreen> createState() => _UserDocumentScreenState();
}

class _UserDocumentScreenState extends State<UserDocumentScreen> with AutomaticKeepAliveClientMixin {
  List<User> _headers = [];
  bool _isLoading = true;
  String _error = '';

  List<ModuleDocument> _lists = []; // <-- เก็บเมนูทั้งหมดในระบบ

  Mode _mode = Mode.none;
  User? _selected; // ผู้ใช้ที่เลือกใน Panel ซ้าย

  // ชุดของ ModuleDocument ID ที่ผู้ใช้ที่เลือกมีสิทธิ์ (สำหรับการแสดงผล/แก้ไข)
  Set<int> _currentGrantedIds = HashSet();

  // ชุดของ ModuleDocument ID ที่ถูกเลือกในโหมด Edit (ยังไม่บันทึก)
  Set<int> _stagedGrantedIds = HashSet();

  bool _isLeftPanelExpanded = true;
  double _leftPanelWidth = 360.0;
  bool _isDraggingDivider = false;

  @override
  void initState() {
    super.initState();
    _fetchLists();
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _fetchLists() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final headerService = Provider.of<UserService>(context, listen: false);
      // final detailService = Provider.of<UserDocumentService>(context,
      //     listen: false); // <-- ใช้ UserDocumentService
      // final fetchedHeader = await headerService.fetchUsers();
      // _lists = await detailService
      //     .getAllMenus(); // ดึงเมนูทั้งหมดจาก UserDocumentService
      final detailService = Provider.of<ModuleDocumentService>(context,
          listen: false); // <-- ใช้ UserDocumentService
      final fetchedHeader = await headerService.fetchUsers();
      _lists = await detailService
          .fetchRows(); // ดึงเมนูทั้งหมดจาก UserDocumentService
      setState(() {
        _headers = fetchedHeader;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'ไม่สามารถโหลดข้อมูลได้: ${e.toString()}';
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_error)),
        );
      }
    }
  }

  Future<void> _onView(User row) async {
    setState(() {
      _mode = Mode.none; // เคลียร์ก่อนโหลดใหม่
      _selected = row;
      _currentGrantedIds.clear();
      _stagedGrantedIds.clear(); // Clear staged as well
    });
    try {
      // final detailService =
      //     Provider.of<UserDocumentService>(context, listen: false);
      // final grantedIds = await detailService.fetchUserMenu(user.id);
      final detailService =
          Provider.of<ModuleDocumentService>(context, listen: false);
      final grantedIds = await detailService.fetchRowsByUserId(row.id);
      setState(() {
        _currentGrantedIds = grantedIds.map((item) => item.id).toSet();
        _mode = Mode.view;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ไม่สามารถโหลดสิทธิ์ผู้ใช้: ${e.toString()}')),
        );
      }
      setState(() {
        _mode = Mode.none;
        _selected = null;
      });
    }
  }

  Future<void> _onEdit(User row) async {
    setState(() {
      _mode = Mode.none; // เคลียร์ก่อนโหลดใหม่
      _selected = row;
      _currentGrantedIds.clear();
      _stagedGrantedIds.clear(); // Clear staged before loading
    });
    try {
      final detailService =
          Provider.of<ModuleDocumentService>(context, listen: false);
      final grantedIds = await detailService.fetchRowsByUserId(row.id);
      setState(() {
        _currentGrantedIds = grantedIds.map((item) => item.id).toSet();
        _stagedGrantedIds = HashSet.from(
            grantedIds.map((item) => item.id)); // คัดลอกไปที่ staged เพื่อแก้ไข
        _mode = Mode.edit;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ไม่สามารถโหลดสิทธิ์ผู้ใช้: ${e.toString()}')),
        );
      }
      setState(() {
        _mode = Mode.none;
        _selected = null;
      });
    }
  }

  Future<void> _onDelete(User row) async {
    final l = AppL10n(Provider.of<LanguageProvider>(context, listen: false).isEnglish);
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบสิทธิ์'),
        content:
            Text('คุณแน่ใจหรือไม่ที่จะลบสิทธิ์เมนูทั้งหมดของผู้ใช้ "${row.firstName} ${row.lastName}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final detailService =
            Provider.of<UserDocumentService>(context, listen: false);
        await detailService.deleteRowsByUserId(row.id);
        _onClearRightPanel(); // เคลียร์ panel ขวาหลังจากลบ
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ลบสิทธิ์ผู้ใช้สำเร็จ')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่พบเมนูผู้ใช้ที่เลือก')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('เกิดข้อผิดพลาดในการลบสิทธิ์ผู้ใช้: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _onSave() async {
    final l = AppL10n(Provider.of<LanguageProvider>(context, listen: false).isEnglish);
    if (_selected == null || _mode != Mode.edit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('ไม่มีผู้ใช้ที่เลือกหรือไม่ได้อยู่ในโหมดแก้ไข')),
      );
      return;
    }

    if (_stagedGrantedIds.isEmpty) {
      // ถามผู้ใช้ก่อนว่าต้องการลบสิทธิ์ทั้งหมดจริงหรือไม่
      final bool? confirmDelete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ยืนยันการลบสิทธิ์ทั้งหมด'),
          content: Text('คุณต้องการลบสิทธิ์เข้าถึงเมนูทั้งหมดของ ${_selected!.userName} ใช่หรือไม่?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(l.delete, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirmDelete != true) {
        return; // ผู้ใช้ยกเลิกการลบ
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final detailService =
          Provider.of<UserDocumentService>(context, listen: false);
      if (_stagedGrantedIds.isEmpty) {
        // ถ้า Set ว่างเปล่า ให้เรียก API ลบทั้งหมด
        await detailService.deleteRowsByUserId(_selected!.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('ลบสิทธิ์ทั้งหมดของผู้ใช้ ${_selected!.userName} สำเร็จ')),
        );
      } else {
        await detailService.updateRowsByUserId(_selected!.id, _stagedGrantedIds);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('บันทึกสิทธิ์สำหรับผู้ใช้ ${_selected!.userName} สำเร็จ')),
        );
      }

      // รีเฟรชข้อมูลหลังจากบันทึก
      // await _fetchUserPermissions(_selected!.id);
      _onView(
          _selected!); // Refresh to view mode with new permissions

    } catch (e) {
      print('Error saving user menu: $e'); // Log เพื่อดูรายละเอียดใน Debug Console
      // _showSnackBar('เกิดข้อผิดพลาดในการบันทึกสิทธิ์: ${e.toString()}', Colors.red);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('เกิดข้อผิดพลาดในการบันทึกสิทธิ์: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onClearRightPanel() {
    setState(() {
      _mode = Mode.none;
      _selected = null;
      _currentGrantedIds.clear();
      _stagedGrantedIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);

    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.deepOrange[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรชรายการ',
            onPressed: _fetchLists,
          ),
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined, color: Colors.white),
            onPressed: _onClearRightPanel,
            tooltip: 'เคลียร์ Panel ขวา',
          ),
          _selected != null ?
          IconButton(
            icon: const Icon(Icons.save_outlined, color: Colors.white),
            onPressed: _mode == Mode.edit
                ? _onSave
                : null, // บันทึกได้เฉพาะตอนอยู่ในโหมดแก้ไข
            tooltip: 'บันทึกสิทธิ์',
          )
          : const SizedBox.shrink(),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final double maxLeftWidth =
                        (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 36,
                          color: Colors.deepOrange[900],
                          child: IconButton(
                            icon: Icon(
                              _isLeftPanelExpanded
                                  ? Icons.filter_list_off
                                  : Icons.filter_list,
                              color: Colors.white,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            onPressed: () => setState(
                                () => _isLeftPanelExpanded = !_isLeftPanelExpanded),
                            tooltip: _isLeftPanelExpanded ? 'ย่อรายการ' : 'ขยายรายการ',
                          ),
                        ),
                        AnimatedContainer(
                          duration: _isDraggingDivider
                              ? Duration.zero
                              : const Duration(milliseconds: 200),
                          width: _isLeftPanelExpanded ? _leftPanelWidth : 0.0,
                          child: ClipRect(
                            child: OverflowBox(
                              maxWidth: _leftPanelWidth,
                              minWidth: _leftPanelWidth,
                              alignment: Alignment.topLeft,
                              child: ColoredBox(
                                color: Colors.blueGrey.shade100,
                                child: UserListPanel(
                                  users: _headers,
                                  enableAddButton: false,
                                  enableSortButton: true,
                                  onAdd: () {},
                                  onEdit: _onEdit,
                                  onView: _onView,
                                  onDelete: _onDelete,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_isLeftPanelExpanded)
                          MouseRegion(
                            cursor: SystemMouseCursors.resizeColumn,
                            child: GestureDetector(
                              onHorizontalDragStart: (_) =>
                                  setState(() => _isDraggingDivider = true),
                              onHorizontalDragUpdate: (details) {
                                setState(() {
                                  _leftPanelWidth =
                                      (_leftPanelWidth + details.delta.dx)
                                          .clamp(200.0, maxLeftWidth);
                                });
                              },
                              onHorizontalDragEnd: (_) =>
                                  setState(() => _isDraggingDivider = false),
                              child: Container(width: 5, color: Colors.grey[400]),
                            ),
                          ),
                        Expanded(child: _buildDetailRightPanel()),
                      ],
                    );
                  },
                ),
    );
  }

  // Helper method สำหรับสร้างเนื้อหาใน Panel ด้านขวา
  Widget _buildDetailRightPanel() {
    if (_selected == null || _mode == Mode.none) {
      return const Center(child: Text('เลือกผู้ใช้เพื่อจัดการสิทธิ์'));
    }

    if (_lists.isEmpty) {
      return const Center(child: Text('ไม่พบรายการประเภทเอกสารในระบบ'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'สิทธิ์ประเภทเอกสารสำหรับ: ${_selected!.userName}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const Divider(),
        Expanded(
          child: UserDocumentDetailTreeWidget(
            lists: _lists,
            initialGrantedIds: _mode == Mode.view
                ? _currentGrantedIds
                : _stagedGrantedIds,
            isEditing: _mode == Mode.edit,
            onPermissionsChanged: (updatedGrantedIds) {
              // อัปเดต stagedGrantedMenuIds เมื่อมีการเปลี่ยนแปลงใน PermissionMenuTreeview
              setState(() {
                _stagedGrantedIds = updatedGrantedIds;
              });
            },
          ),
        ),
      ],
    );
  }
  
}
