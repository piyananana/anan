// screens/user_menu_management_screen.dart

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../utils/menu_scope.dart';

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

  /// แปลง List<Menu> → Map<int, MenuPermission>
  Map<int, MenuPermission> _permsFromMenuList(List<Menu> menus) => {
    for (final m in menus)
      m.id: MenuPermission(
        menuId: m.id,
        canView: m.canView,
        canCreate: m.canCreate,
        canEdit: m.canEdit,
        canDelete: m.canDelete,
        canApprove: m.canApprove,
        canPrint: m.canPrint,
        canExport: m.canExport,
      )
  };

  Future<void> _showCopyDialog() async {
    final menuService     = Provider.of<MenuService>(context, listen: false);
    final userMenuService = Provider.of<UserMenuService>(context, listen: false);

    final targetUserId = await showDialog<int>(
      context: context,
      builder: (_) => _CopyPermissionsDialog(
        users: _users,
        preselectedUser: _selectedNode,
        menuService: menuService,
        userMenuService: userMenuService,
        permsFromMenuList: _permsFromMenuList,
      ),
    );

    // ถ้า dialog คัดลอกไปยัง user ที่กำลัง view/edit อยู่ → refresh
    if (targetUserId != null && mounted && _selectedNode?.id == targetUserId) {
      _onView(_selectedNode!);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
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
          IconButton(
            icon: const Icon(Icons.copy_all, color: Colors.white),
            onPressed: _showCopyDialog,
            tooltip: 'คัดลอกสิทธิ์จากผู้ใช้อื่น',
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

// ── Copy Permissions Dialog ─────────────────────────────────────────────────

class _CopyPermissionsDialog extends StatefulWidget {
  final List<User> users;
  final User? preselectedUser;       // user ที่กำลัง view/edit อยู่ (เป็น "ปลายทาง" default)
  final MenuService menuService;
  final UserMenuService userMenuService;
  final Map<int, MenuPermission> Function(List<Menu>) permsFromMenuList;

  const _CopyPermissionsDialog({
    required this.users,
    required this.preselectedUser,
    required this.menuService,
    required this.userMenuService,
    required this.permsFromMenuList,
  });

  @override
  State<_CopyPermissionsDialog> createState() => _CopyPermissionsDialogState();
}

class _CopyPermissionsDialogState extends State<_CopyPermissionsDialog> {
  User? _fromUser;
  User? _toUser;
  bool _replaceExisting = true;   // true = ลบก่อนแล้วคัดลอก, false = รวมสิทธิ์
  bool _isCopying = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _toUser = widget.preselectedUser;
  }

  List<User> get _fromCandidates =>
      widget.users.where((u) => u.id != _toUser?.id).toList();

  List<User> get _toCandidates =>
      widget.users.where((u) => u.id != _fromUser?.id).toList();

  Future<void> _doCopy() async {
    if (_fromUser == null || _toUser == null) return;
    setState(() { _isCopying = true; _errorMsg = null; });

    try {
      // โหลดสิทธิ์ต้นทาง
      final srcMenus = await widget.menuService.fetchMenuByUserId(_fromUser!.id);
      final srcPerms = widget.permsFromMenuList(srcMenus);

      Map<int, MenuPermission> finalPerms;

      if (_replaceExisting) {
        finalPerms = srcPerms;
      } else {
        // โหลดสิทธิ์ปลายทาง แล้ว OR กัน
        final dstMenus = await widget.menuService.fetchMenuByUserId(_toUser!.id);
        final dstPerms = widget.permsFromMenuList(dstMenus);
        finalPerms = Map.from(dstPerms);
        for (final entry in srcPerms.entries) {
          final dst = finalPerms[entry.key];
          if (dst == null) {
            finalPerms[entry.key] = entry.value;
          } else {
            finalPerms[entry.key] = MenuPermission(
              menuId:    dst.menuId,
              canView:   dst.canView   || entry.value.canView,
              canCreate: dst.canCreate || entry.value.canCreate,
              canEdit:   dst.canEdit   || entry.value.canEdit,
              canDelete: dst.canDelete || entry.value.canDelete,
              canApprove:dst.canApprove|| entry.value.canApprove,
              canPrint:  dst.canPrint  || entry.value.canPrint,
              canExport: dst.canExport || entry.value.canExport,
            );
          }
        }
      }

      await widget.userMenuService.updateUserMenu(_toUser!.id, finalPerms);

      if (mounted) Navigator.pop(context, _toUser!.id);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCopying = false;
          _errorMsg = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCopy = _fromUser != null && _toUser != null && !_isCopying;

    return AlertDialog(
      title: const Row(children: [
        Icon(Icons.copy_all, color: Colors.deepOrange),
        SizedBox(width: 8),
        Text('คัดลอกสิทธิ์เมนู'),
      ]),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FROM
            DropdownButtonFormField<User>(
              isExpanded: true,
              value: _fromUser,
              decoration: const InputDecoration(
                labelText: 'คัดลอกจาก (ต้นทาง)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _fromCandidates
                  .map((u) => DropdownMenuItem(
                        value: u,
                        child: Text('${u.userName}  (${u.firstName} ${u.lastName})',
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: _isCopying ? null : (u) => setState(() => _fromUser = u),
            ),
            const SizedBox(height: 14),

            // TO
            DropdownButtonFormField<User>(
              isExpanded: true,
              value: _toUser,
              decoration: const InputDecoration(
                labelText: 'คัดลอกไปยัง (ปลายทาง)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _toCandidates
                  .map((u) => DropdownMenuItem(
                        value: u,
                        child: Text('${u.userName}  (${u.firstName} ${u.lastName})',
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: _isCopying ? null : (u) => setState(() => _toUser = u),
            ),
            const SizedBox(height: 16),

            // Mode
            const Text('วิธีการคัดลอก', style: TextStyle(fontWeight: FontWeight.w600)),
            RadioListTile<bool>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('แทนที่สิทธิ์เดิม (ได้รับเฉพาะสิทธิ์ที่คัดลอก)'),
              value: true,
              groupValue: _replaceExisting,
              onChanged: _isCopying ? null : (v) => setState(() => _replaceExisting = v!),
            ),
            RadioListTile<bool>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('รวมกับสิทธิ์เดิม (ได้รับสิทธิ์เดิม + สิทธิ์ที่คัดลอก)'),
              value: false,
              groupValue: _replaceExisting,
              onChanged: _isCopying ? null : (v) => setState(() => _replaceExisting = v!),
            ),

            if (_errorMsg != null) ...[
              const SizedBox(height: 8),
              Text(_errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCopying ? null : () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton.icon(
          icon: _isCopying
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.copy_all, size: 18),
          label: Text(_isCopying ? 'กำลังคัดลอก...' : 'คัดลอก'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange[700],
            foregroundColor: Colors.white,
          ),
          onPressed: canCopy ? _doCopy : null,
        ),
      ],
    );
  }
}
