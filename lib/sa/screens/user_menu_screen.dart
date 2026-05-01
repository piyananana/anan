// screens/user_menu_management_screen.dart

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'dart:collection'; // สำหรับ HashSet

import '../models/anan_module.dart';
import '../models/user.dart';
import '../models/menu.dart'; 
import '../services/user_service.dart';
import '../services/menu_service.dart'; 
import '../services/user_menu_service.dart'; 
import '../widgets/user_list_widget.dart'; // ใช้ UserListPanel เดิมแต่เปลี่ยน callback
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

  // ชุดของ Menu ID ที่ผู้ใช้ที่เลือกมีสิทธิ์ (สำหรับการแสดงผล/แก้ไข)
  Set<int> _currentGrantedMenuIds = HashSet();

  // ชุดของ Menu ID ที่ถูกเลือกในโหมด Edit (ยังไม่บันทึก)
  Set<int> _stagedGrantedMenuIds = HashSet();

  bool _isLeftPanelExpanded = true;
  double _leftPanelWidth = 360.0;
  bool _isDraggingDivider = false;

  UserSortBy _sortBy = UserSortBy.userName;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchUsersAndMenus();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  // TODO: implement wantKeepAlive
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
      _mode = Mode.none; // เคลียร์ก่อนโหลดใหม่
      _selectedNode = user;
      _currentGrantedMenuIds.clear();
      _stagedGrantedMenuIds.clear(); // Clear staged as well
    });
    try {
      // final masterService =
      //     Provider.of<UserMenuService>(context, listen: false);
      // final grantedIds = await masterService.fetchUserMenu(user.id);
      final menuService =
          Provider.of<MenuService>(context, listen: false);
      final grantedIds = await menuService.fetchMenuByUserId(user.id);
      setState(() {
        _currentGrantedMenuIds = grantedIds.map((menu) => menu.id).toSet();
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
      _mode = Mode.none; // เคลียร์ก่อนโหลดใหม่
      _selectedNode = user;
      _currentGrantedMenuIds.clear();
      _stagedGrantedMenuIds.clear(); // Clear staged before loading
    });
    try {
      final menuService =
          Provider.of<MenuService>(context, listen: false);
      final grantedIds = await menuService.fetchMenuByUserId(user.id);
      setState(() {
        _currentGrantedMenuIds = grantedIds.map((menu) => menu.id).toSet();
        _stagedGrantedMenuIds = HashSet.from(
            grantedIds.map((menu) => menu.id)); // คัดลอกไปที่ staged เพื่อแก้ไข
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

    if (_stagedGrantedMenuIds.isEmpty) {
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
      if (_stagedGrantedMenuIds.isEmpty) {
        // ถ้า Set ว่างเปล่า ให้เรียก API ลบทั้งหมด
        await masterService.deleteUserMenu(_selectedNode!.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('ลบสิทธิ์ทั้งหมดของผู้ใช้ ${_selectedNode!.userName} สำเร็จ')),
        );
      } else {
        await masterService.updateUserMenu(_selectedNode!.id, _stagedGrantedMenuIds);
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
      _currentGrantedMenuIds.clear();
      _stagedGrantedMenuIds.clear();
    });
  }

  void _onSortSelected(UserSortBy sortBy) {
    setState(() {
      _sortBy = sortBy;
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
        // leading: IconButton(
        //   icon: const Icon(Icons.arrow_back, color: Colors.white),
        //   onPressed: () {
        //     widget.onExit?.call(); // เรียก Callback ย้อนกลับไป HomeScreen
        //   },
        // ),
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
          PopupMenuButton<UserSortBy>(
            icon: const Icon(Icons.sort_outlined, color: Colors.white),
            tooltip: 'จัดเรียงข้อมูล',
            onSelected: _onSortSelected,
            itemBuilder: (BuildContext context) => <PopupMenuEntry<UserSortBy>>[
              const PopupMenuItem<UserSortBy>(
                value: UserSortBy.userName,
                child: Text('เรียงตามผู้ใช้'),
              ),
              const PopupMenuItem<UserSortBy>(
                value: UserSortBy.firstName,
                child: Text('เรียงตามชื่อจริง'),
              ),
              const PopupMenuItem<UserSortBy>(
                value: UserSortBy.lastName,
                child: Text('เรียงตามนามสกุล'),
              ),
              const PopupMenuItem<UserSortBy>(
                value: UserSortBy.status,
                child: Text('เรียงตามสถานะ'),
              ),
              const PopupMenuItem<UserSortBy>(
                value: UserSortBy.userType,
                child: Text('เรียงตามประเภทผู้ใช้'),
              ),
            ],
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
                              child: Container(
                                color: Colors.blueGrey[100],
                                child: UserListPanel(
                                  users: _users,
                                  onViewPermissions: _onView,
                                  onEditPermissions: _onEdit,
                                  onDeletePermissions: _onDelete,
                                  onEdit: _onEdit,
                                  onView: _onView,
                                  onDelete: _onDelete,
                                  searchController: _searchController,
                                  sortBy: _sortBy,
                                  searchQuery: _searchQuery,
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
            initialGrantedIds: _mode == Mode.view
                ? _currentGrantedMenuIds
                : _stagedGrantedMenuIds,
            isEditing: _mode == Mode.edit,
            onPermissionsChanged: (updatedGrantedIds) {
              // อัปเดต stagedGrantedMenuIds เมื่อมีการเปลี่ยนแปลงใน PermissionMenuTreeview
              setState(() {
                _stagedGrantedMenuIds = updatedGrantedIds;
              });
            },
          ),
        ),
      ],
    );
  }
  
}
