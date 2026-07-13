// screens/sa_group_menu_management_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sa_language_provider.dart';
import '../utils/sa_app_l10n.dart';
import '../utils/sa_menu_scope.dart';

import '../models/sa_group.dart';
import '../models/sa_menu.dart';
import '../models/sa_menu_permission.dart';
import '../services/sa_group_service.dart';
import '../services/sa_menu_service.dart';
import '../services/sa_group_menu_service.dart';
import '../widgets/sa_user_menu_detail_tree_widget.dart';

// Enum เพื่อบอกสถานะของ Form
enum NodeMode {
  view,
  edit,
  none,
}

class GroupMenuManagementScreen extends StatefulWidget {
  final VoidCallback? onExit; // <-- เพิ่ม Callback นี้

  const GroupMenuManagementScreen({
    super.key,
    this.onExit, // <-- รับเข้ามา
  });

  @override
  State<GroupMenuManagementScreen> createState() => _GroupMenuManagementScreenState();
}

class _GroupMenuManagementScreenState extends State<GroupMenuManagementScreen> with AutomaticKeepAliveClientMixin {
  // late List<Group> _currentList;
  List<Group> _currentList = []; // กำหนดค่าเริ่มต้นเป็น List ว่างเปล่า
  List<Menu> _allMenus = []; // <-- เก็บเมนูทั้งหมดในระบบ

  // สิทธิ์เมนูที่กลุ่มที่เลือกมี (สำหรับการแสดงผล/แก้ไข)
  Map<int, MenuPermission> _currentGrantedPerms = {};

  // สิทธิ์เมนูที่ถูกเลือกในโหมด Edit (ยังไม่บันทึก)
  Map<int, MenuPermission> _stagedGrantedPerms = {};

  bool _isLoading = true; // เพิ่มสถานะการโหลดเมนู
  String _errorLoading = ''; // เพิ่มข้อความ error
  final Map<String?, bool> _expandedState = {};

  bool _isLeftPanelExpanded = true;
  double _leftPanelWidth = 360.0;
  bool _isDraggingDivider = false;
  Group? _selectedNode; // เมนูที่ถูกเลือกใน TreeView
  NodeMode _nodeMode = NodeMode.none; // โหมดของ Form

  @override
  void initState() {
    super.initState();
    _fetchData(); // <-- เรียกเมธอด fetch เพื่อโหลดเมนูเมื่อ Widget ถูกสร้าง
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive => true;

  // *** NEW: Method สำหรับ Fetch เมนูทั้งหมด ***
  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorLoading = '';
    });
    try {
      final groupService = Provider.of<GroupService>(context, listen: false);
      final fetchedData = await groupService.fetchData();
      final menuService = Provider.of<MenuService>(context,
          listen: false); // <-- ใช้ MenuService
      _allMenus = await menuService.fetchMenus(); // ดึงเมนูทั้งหมดจาก MenuService
      setState(() {
        _currentList = fetchedData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorLoading = 'ไม่สามารถโหลดข้อมูลได้: ${e.toString()}';
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorLoading)),
      );
    }
  }

  // --- Utility Methods ---
  List<Group> _buildTree(List<Group> dataList, String? parentId) {
    return dataList
        .where((data) => data.parentId == parentId)
        .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
  }

  void _clearForm() {
    setState(() {
      _selectedNode = null;
      _nodeMode = NodeMode.none;
    });
  }

  // --- Form Logic ---

  Future<void> _onView(Group rowData) async {
    _clearForm();
    setState(() {
      _nodeMode = NodeMode.none;
      _selectedNode = rowData;
      _currentGrantedPerms = {};
      _stagedGrantedPerms = {};
    });
    try {
      final menuService = Provider.of<MenuService>(context, listen: false);
      final grantedMenus = await menuService.fetchMenuByGroupId(rowData.id);
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
        _nodeMode = NodeMode.view;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ไม่สามารถโหลดสิทธิ์ของกลุ่ม: ${e.toString()}')),
        );
      }
      setState(() {
        _nodeMode = NodeMode.none;
        _selectedNode = null;
      });
    }
  }

  Future<void> _onEdit(Group rowData) async {
    setState(() {
      _nodeMode = NodeMode.none;
      _selectedNode = rowData;
      _currentGrantedPerms = {};
      _stagedGrantedPerms = {};
    });
    try {
      final menuService = Provider.of<MenuService>(context, listen: false);
      final grantedMenus = await menuService.fetchMenuByGroupId(rowData.id);
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
        _nodeMode = NodeMode.edit;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ไม่สามารถโหลดสิทธิ์ของกลุ่ม: ${e.toString()}')),
        );
      }
      setState(() {
        _nodeMode = NodeMode.none;
        _selectedNode = null;
      });
    }
  }

  Future<void> _onSave() async {
    final l = AppL10n(Provider.of<LanguageProvider>(context, listen: false).isEnglish);
    if (_selectedNode == null || _nodeMode != NodeMode.edit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.isEnglish
            ? 'No group selected or not in edit mode'
            : 'ไม่มีกลุ่มที่เลือกหรือไม่ได้อยู่ในโหมดแก้ไข')),
      );
      return;
    }

    if (_stagedGrantedPerms.isEmpty) {
      final bool? confirmDelete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.isEnglish ? 'Confirm Delete All Permissions' : 'ยืนยันการลบสิทธิ์ทั้งหมด'),
          content: Text(l.isEnglish
              ? 'Remove all menu permissions for ${_selectedNode!.name}?'
              : 'คุณต้องการลบสิทธิ์เข้าถึงเมนูทั้งหมดของ ${_selectedNode!.name} ใช่หรือไม่?'),
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
      final masterService =
          Provider.of<GroupMenuService>(context, listen: false);
      if (_stagedGrantedPerms.isEmpty) {
        // ถ้า Map ว่างเปล่า ให้เรียก API ลบทั้งหมด
        await masterService.deleteGroupMenu(_selectedNode!.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.isEnglish
              ? 'All permissions for ${_selectedNode?.name} deleted'
              : 'ลบสิทธิ์ทั้งหมดของกลุ่ม ${_selectedNode?.name} สำเร็จ')),
        );
      } else {
        await masterService.updateGroupMenu(_selectedNode?.id, _stagedGrantedPerms);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.isEnglish
              ? 'Permissions saved for ${_selectedNode?.name}'
              : 'บันทึกสิทธิ์สำหรับกลุ่ม ${_selectedNode?.name} สำเร็จ')),
        );
      }

      // รีเฟรชข้อมูลหลังจากบันทึก
      _onView(_selectedNode!); // Refresh to view mode with new permissions

    } catch (e) {
      print('Error saving group menu: $e'); // Log เพื่อดูรายละเอียดใน Debug Console
      // _showSnackBar('เกิดข้อผิดพลาดในการบันทึกสิทธิ์: ${e.toString()}', Colors.red);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('เกิดข้อผิดพลาดในการบันทึกสิทธิ์: ${e.toString()}')),
      );
      // ^^^^ แสดงข้อความ error ที่ชัดเจนขึ้น ^^^^
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);

    // ต้องตรวจสอบสถานะการโหลดก่อนสร้าง UI
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorLoading.isNotEmpty) {
      return Center(child: Text(_errorLoading));
    }

    final List<Group> topLevelData = _buildTree(_currentList, null);

    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        // leading: IconButton(
        //   icon: const Icon(Icons.arrow_back),
        //   onPressed: () {
        //     // // เรียก callback เมื่อต้องการ "ออกจาก" หน้าจัดการเมนู
        //     // // แทนการใช้ Navigator.pop()
        //     if (widget.onExit != null) {
        //       widget.onExit!();
        //     }
        //   },
        // ),
        backgroundColor: Colors.deepOrange.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l.refresh,
            onPressed: _fetchData,
          ),
          _selectedNode != null && _nodeMode == NodeMode.edit
            ? IconButton(
                icon: const Icon(Icons.save_outlined, color: Colors.white),
                onPressed: _nodeMode == NodeMode.edit ? _onSave : null,
                tooltip: l.isEnglish ? 'Save Permissions' : 'บันทึกสิทธิ์',
              )
            : const SizedBox.shrink(),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
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
                    _isLeftPanelExpanded ? Icons.filter_list_off : Icons.filter_list,
                    color: Colors.white,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () =>
                      setState(() => _isLeftPanelExpanded = !_isLeftPanelExpanded),
                  tooltip: _isLeftPanelExpanded
                      ? (l.isEnglish ? 'Collapse List' : 'ย่อรายการ')
                      : (l.isEnglish ? 'Expand List' : 'ขยายรายการ'),
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
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              l.isEnglish ? 'Group Structure' : 'โครงสร้างกลุ่ม',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: topLevelData.length,
                              itemBuilder: (context, index) {
                                return _buildNode(topLevelData[index], 0);
                              },
                            ),
                          ),
                        ],
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
                        _leftPanelWidth = (_leftPanelWidth + details.delta.dx)
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

  // --- Build Methods ---
  Widget _buildNode(Group rowData, int level) {
    final l = AppL10n(Provider.of<LanguageProvider>(context, listen: false).isEnglish);
    final bool isFolder = rowData.haveSubGroup;
    final List<Group> children = _buildTree(_currentList, rowData.id);
    final bool hasChildren = children.isNotEmpty;
    final bool isExpanded = _expandedState[rowData.id] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            if (isFolder && hasChildren) {
              setState(() {
                _expandedState[rowData.id] = !isExpanded;
              });
            } else {
              // _setEditMode(rowData); // คลิกเมนูเพื่อแก้ไขรายละเอียด
              // _onEdit(rowData); // คลิกเมนูเพื่อแก้ไขรายละเอียด
              _onView(rowData); 
            }
          },
          child: Padding(
            padding: EdgeInsets.only(left: level * 16.0),
            child: Row(
              children: [
                if (isFolder && hasChildren)
                  Icon(isExpanded ? Icons.arrow_drop_down : Icons.arrow_right),
                if (!isFolder || !hasChildren)
                  const SizedBox(width: 24),
                Icon(isFolder ? Icons.group_work
                  : Icons.groups_3),
                const SizedBox(width: 8),
                // Icon(Icons.groups_3),
                Expanded(
                  child: Text(
                    rowData.name,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Icon ปุ่ม Edit
                IconButton(
                  icon: const Icon(Icons.visibility, color: Colors.green, size: 20),
                  tooltip: l.isEnglish ? 'View Permissions' : 'ดูสิทธิ์',
                  onPressed: () => _onView(rowData),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                  tooltip: l.edit,
                  onPressed: () => _onEdit(rowData),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded && hasChildren)
          Column(
            children: children
                .map((child) => _buildNode(child, level + 1))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildRightPanelContent() {
    final l = AppL10n(Provider.of<LanguageProvider>(context, listen: false).isEnglish);
    if (_selectedNode == null || _nodeMode == NodeMode.none) {
      return Center(child: Text(l.isEnglish ? 'Select a group to manage permissions' : 'เลือกกลุ่มเพื่อจัดการสิทธิ์'));
    }

    if (_allMenus.isEmpty) {
      return Center(child: Text(l.isEnglish ? 'No menu items found in the system' : 'ไม่พบรายการเมนูในระบบ'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            l.isEnglish
                ? 'Menu Permissions for: ${_selectedNode!.name}'
                : 'สิทธิ์เมนูสำหรับ: ${_selectedNode!.name}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const Divider(),
        Expanded(
          child: UserMenuDetailTreeWidget(
            lists: _allMenus,
            initialPermissions: _nodeMode == NodeMode.view
                ? _currentGrantedPerms
                : _stagedGrantedPerms,
            isEditing: _nodeMode == NodeMode.edit,
            onPermissionsChanged: (updated) {
              setState(() => _stagedGrantedPerms = updated);
            },
          ),
        ),
      ],
    );
  }
  
}