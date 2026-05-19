// screens/user_menu_management_screen.dart

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../models/anan_module.dart';
import '../models/user.dart';
import '../models/menu.dart';
import '../models/menu_permission.dart';
import '../services/user_service.dart';
import '../services/menu_service.dart';
import '../services/user_menu_service.dart';
import '../widgets/user_list_widget.dart';
import '../widgets/user_menu_detail_tree_widget.dart';

// Enum สำหรับโหมดการแสดงผลของ Panel ขวา
// enum Mode {
//   none, // Panel ขวาว่างเปล่า
//   view, // แสดงเมนูที่มีสิทธิ์เท่านั้น (อ่านอย่างเดียว)
//   edit, // แสดงเมนูทั้งหมดพร้อม Checkbox
// }

class UserMenuScreen extends StatefulWidget {
  final VoidCallback? onExit;

  const UserMenuScreen({
    super.key,
    this.onExit,
  });

  @override
  State<UserMenuScreen> createState() => _UserMenuScreenState();
}

class _UserMenuScreenState extends State<UserMenuScreen> with AutomaticKeepAliveClientMixin {
  List<User> _users = [];
  bool _isLoading = true;
  String _error = '';

  List<Menu> _allMenus = []; // <-- เก็บเมนูทั้งหมดในระบบ

  Mode _mode = Mode.none;
  User? _selectedNode; // ผู้ใช้ที่เลือกใน Panel ซ้าย

  // สิทธิ์เมนูที่ผู้ใช้ที่เลือกมี (สำหรับการแสดงผล/แก้ไข)
  Map<int, MenuPermission> _currentGrantedPerms = {};

  // สิทธิ์เมนูที่ถูกเลือกในโหมด Edit (ยังไม่บันทึก)
  Map<int, MenuPermission> _stagedGrantedPerms = {};

  bool _isLeftPanelExpanded = true;
  double _leftPanelWidth = 360.0;
  bool _isDraggingDivider = false;

  @override
  void initState() {
    super.initState();
    _fetchUsersAndMenus();
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _fetchUsersAndMenus() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final userService = Provider.of<UserService>(context, listen: false);
      // final masterService = Provider.of<UserMenuService>(context,
      //     listen: false); // <-- ใช้ UserMenuService
      // final fetchedUsers = await userService.fetchUsers();
      // _allMenus = await masterService
      //     .getAllMenus(); // ดึงเมนูทั้งหมดจาก UserMenuService
      final menuService = Provider.of<MenuService>(context,
          listen: false); // <-- ใช้ UserMenuService
      final fetchedUsers = await userService.fetchUsers();
      _allMenus = await menuService
          .fetchMenus(); // ดึงเมนูทั้งหมดจาก UserMenuService
      setState(() {
        _users = fetchedUsers;
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

  Future<void> _onView(User user) async {
    setState(() {
      _mode = Mode.none;
      _selectedNode = user;
      _currentGrantedPerms = {};
      _stagedGrantedPerms = {};
    });
    try {
      final menuService = Provider.of<MenuService>(context, listen: false);
      final grantedMenus = await menuService.fetchMenuByUserId(user.id);
      final perms = <int, MenuPermission>{};
      for (final m in grantedMenus) {
        perms[m.id] = MenuPermission(
          menuId: m.id,
          canView: m.canView,
          canCreate: m.canCreate,
          canEdit: m.canEdit,
          canDelete: m.canDelete,
          canApprove: m.canApprove,
          canPrint: m.canPrint,
          canExport: m.canExport,
        );
      }
      setState(() {
        _currentGrantedPerms = perms;
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
        _selectedNode = null;
      });
    }
  }

  Future<void> _onEdit(User user) async {
    setState(() {
      _mode = Mode.none;
      _selectedNode = user;
      _currentGrantedPerms = {};
      _stagedGrantedPerms = {};
    });
    try {
      final menuService = Provider.of<MenuService>(context, listen: false);
      final grantedMenus = await menuService.fetchMenuByUserId(user.id);
      final perms = <int, MenuPermission>{};
      for (final m in grantedMenus) {
        perms[m.id] = MenuPermission(
          menuId: m.id,
          canView: m.canView,
          canCreate: m.canCreate,
          canEdit: m.canEdit,
          canDelete: m.canDelete,
          canApprove: m.canApprove,
          canPrint: m.canPrint,
          canExport: m.canExport,
        );
      }
      setState(() {
        _currentGrantedPerms = perms;
        _stagedGrantedPerms = Map.from(perms);
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
        _selectedNode = null;
      });
    }
  }

  Future<void> _onDelete(User user) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบสิทธิ์'),
        content:
            Text('คุณแน่ใจหรือไม่ที่จะลบสิทธิ์เมนูทั้งหมดของผู้ใช้ "${user.firstName} ${user.lastName}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final masterService =
            Provider.of<UserMenuService>(context, listen: false);
        await masterService.deleteUserMenu(user.id);
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
    if (_selectedNode == null || _mode != Mode.edit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('ไม่มีผู้ใช้ที่เลือกหรือไม่ได้อยู่ในโหมดแก้ไข')),
      );
      return;
    }

    if (_stagedGrantedPerms.isEmpty) {
      // ถามผู้ใช้ก่อนว่าต้องการลบสิทธิ์ทั้งหมดจริงหรือไม่
      final bool? confirmDelete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ยืนยันการลบสิทธิ์ทั้งหมด'),
          content: Text('คุณต้องการลบสิทธิ์เข้าถึงเมนูทั้งหมดของ ${_selectedNode!.userName} ใช่หรือไม่?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('ลบ', style: TextStyle(color: Colors.white)),
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
      final masterService =
          Provider.of<UserMenuService>(context, listen: false);
      if (_stagedGrantedPerms.isEmpty) {
        // ถ้า Map ว่างเปล่า ให้เรียก API ลบทั้งหมด
        await masterService.deleteUserMenu(_selectedNode!.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('ลบสิทธิ์ทั้งหมดของผู้ใช้ ${_selectedNode!.userName} สำเร็จ')),
        );
      } else {
        await masterService.updateUserMenu(_selectedNode!.id, _stagedGrantedPerms);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('บันทึกสิทธิ์สำหรับผู้ใช้ ${_selectedNode!.userName} สำเร็จ')),
        );
      }

      // รีเฟรชข้อมูลหลังจากบันทึก
      // await _fetchUserPermissions(_selectedNode!.id);
      _onView(
          _selectedNode!); // Refresh to view mode with new permissions

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
      _selectedNode = null;
      _currentGrantedPerms = {};
      _stagedGrantedPerms = {};
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [Icon(Icons.admin_panel_settings, color: Colors.white, size: 20), SizedBox(width: 8), Text('จัดการสิทธิ์เมนูของผู้ใช้')]),
        backgroundColor: Colors.deepOrange[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรชรายการ',
            onPressed: _fetchUsersAndMenus,
          ),
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined, color: Colors.white),
            onPressed: _onClearRightPanel,
            tooltip: 'เคลียร์ Panel ขวา',
          ),
          _selectedNode != null ?
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
                                  users: _users,
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
                        Expanded(child: _buildRightPanelContent()),
                      ],
                    );
                  },
                ),
    );
  }

  // Helper method สำหรับสร้างเนื้อหาใน Panel ด้านขวา
  Widget _buildRightPanelContent() {
    if (_selectedNode == null || _mode == Mode.none) {
      return const Center(child: Text('เลือกผู้ใช้เพื่อจัดการสิทธิ์'));
    }

    if (_allMenus.isEmpty) {
      return const Center(child: Text('ไม่พบรายการเมนูในระบบ'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'สิทธิ์เมนูสำหรับ: ${_selectedNode!.userName}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const Divider(),
        Expanded(
          child: UserMenuDetailTreeWidget(
            lists: _allMenus,
            initialPermissions: _mode == Mode.view
                ? _currentGrantedPerms
                : _stagedGrantedPerms,
            isEditing: _mode == Mode.edit,
            onPermissionsChanged: (updated) {
              setState(() => _stagedGrantedPerms = updated);
            },
          ),
        ),
      ],
    );
  }
  
}
