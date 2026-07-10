// screens/menu_management_screen.dart

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../utils/menu_scope.dart';

import '../models/group.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/group_service.dart';
import '../services/group_user_service.dart';
import '../services/user_menu_service.dart';

// Enum สำหรับโหมดการแสดงผลของ Panel ขวา
enum NodeMode {
  view, // ดูรายชื่อผู้ใช้ที่สังกัดอยู่
  edit, // แก้ไข (เลือก/ไม่เลือก) รายชื่อผู้ใช้ทั้งหมด
  empty, // ไม่มีกลุ่มถูกเลือก
}

// Enum สำหรับตัวเลือกการจัดเรียง
enum SortOption {
  userName,
  firstName,
  lastName,
}

class GroupUserManagementScreen extends StatefulWidget {
  // final List<Group> initialMenus; // รับเมนูเริ่มต้นมา
  // final VoidCallback onChanged; // Callback เมื่อมีการเปลี่ยนแปลงเมนู
  final VoidCallback? onExit; // <-- เพิ่ม Callback นี้

  const GroupUserManagementScreen({
    super.key,
    this.onExit, // <-- รับเข้ามา
  });

  @override
  State<GroupUserManagementScreen> createState() =>
      _GroupUserManagementScreenState();
}

class _GroupUserManagementScreenState extends State<GroupUserManagementScreen> with AutomaticKeepAliveClientMixin {
  final GroupUserService _groupUserService = GroupUserService();
  final UserMenuService _userMenuService = UserMenuService();
  // late List<Group> _currentList;
  List<Group> _currentList = []; // กำหนดค่าเริ่มต้นเป็น List ว่างเปล่า
  List<User> _allUsers = []; // <-- เก็บผู้ใช้ทั้งหมดในระบบ

  bool _isLoading = true; // เพิ่มสถานะการโหลดกลุ่ม

  bool _isLeftPanelExpanded = true;
  double _leftPanelWidth = 360.0;
  bool _isDraggingDivider = false;
  String _errorLoading = ''; // เพิ่มข้อความ error
  final Map<String?, bool> _expandedState = {};
  Group? _selectedNode; // กลุ่มที่ถูกเลือกใน TreeView
  NodeMode _nodeMode = NodeMode.empty; // โหมดของ Form
  List<User?> _detailInPanel =
      []; // ผู้ใช้ที่แสดงใน Panel ขวา (อาจเป็นสมาชิกหรือทั้งหมด)
  bool _isLoadingDetail = false; // สถานะโหลดข้อมูลใน Panel ขวา
  SortOption _currentSortOption =
      SortOption.userName; // ตัวเลือกการจัดเรียงปัจจุบัน

  String get _currentUserType => AuthService().currentUser?.userType ?? 'guest';
  Set<String> get _allowedTypes => User.allowedTypesFor(_currentUserType).toSet();

  @override
  void initState() {
    super.initState();
    _fetchData();
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
      final service = Provider.of<GroupService>(context, listen: false);
      final fetchedData = await service.fetchData();
      final userService = Provider.of<UserService>(context,
          listen: false); // <-- ใช้ UserMenuService
      final fetched = await userService.fetchUsers();
      _allUsers = fetched.where((u) => _allowedTypes.contains(u.userType)).toList();
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
    return dataList.where((data) => data.parentId == parentId).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
        ),
      );
    }
  }

  // --- Form Logic ---

  // ดึงข้อมูลผู้ใช้สำหรับ Panel ขวา ตามโหมดที่เลือก
  Future<void> _fetchDataForDetail() async {
    if (_selectedNode == null) {
      setState(() {
        _nodeMode = NodeMode.empty;
        _detailInPanel = [];
      });
      return;
    }

    setState(() {
      _isLoadingDetail = true;
      _detailInPanel = []; // Clear current list while loading
    });

    try {
      List<User> fetchedUser;
      if (_nodeMode == NodeMode.edit) {
        fetchedUser = await _groupUserService.getGroupUser(_selectedNode!.id!);
      } else {
        fetchedUser = await _groupUserService.getGroupOnlyUsers(_selectedNode!.id!);
      }
      // กรองเฉพาะ type ที่ผู้ login มีสิทธิ์มองเห็น
      _detailInPanel = fetchedUser.where((u) => _allowedTypes.contains(u.userType)).toList();
      _sortUser(); // จัดเรียงทันทีหลังจากโหลด
    } catch (e) {
      _showSnackBar('Failed to load users: $e', Colors.red);
      _detailInPanel = [];
    } finally {
      setState(() {
        _isLoadingDetail = false;
      });
    }
  }

  // เมื่อกด "ดู" ที่ TreeView
  void _onView(Group rowData) {
    setState(() {
      _selectedNode = rowData;
      _nodeMode = NodeMode.view;
    });
    _fetchDataForDetail();
  }

  // เมื่อกด "แก้ไข" ที่ TreeView
  void _onEdit(Group rowData) {
    setState(() {
      _selectedNode = rowData;
      _nodeMode = NodeMode.edit;
    });
    _fetchDataForDetail();
  }

  // เมื่อเปลี่ยนสถานะ CheckBox ของผู้ใช้
  Future<void> _toggleUserMembership(User user, bool? newValue) async {
    if (_selectedNode == null || newValue == null) return;

    setState(() {
      user.isMember = newValue;
    });
    // // รวบรวม user IDs ที่ถูกเลือกทั้งหมด
    // List<int> selectedUserIds = _detailInPanel
    //     .where((u) => u!.isMember)
    //     .map((u) => u!.id)
    //     .toList();
    try {
      if (user.isMember) {
        await _groupUserService.createGroupUserByUserId(
            _selectedNode!.id!, user.id);
        _showSnackBar(
            'เพิ่ม "${user.userName}" เข้ากลุ่มแล้ว (เมนูกลุ่มถูกเพิ่มเข้าสิทธิ์ที่มีอยู่)', Colors.green);
      } else {
        await _groupUserService.deleteGroupUserByUserId(
            _selectedNode!.id!, user.id);
        _showSnackBar('ลบผู้ใช้ "${user.userName}" ออกจากกลุ่มแล้ว (สิทธิ์เมนูยังคงอยู่)', Colors.green);
      }
      // // ถ้าผู้ใช้ถูกยกเลิกการเลือก ให้ลบสิทธิ์เมนูด้วย
      // if (!newValue) {
      //   await _groupUserService.copyGroupMenuToUser(_selectedNode!.id!, user.id); // คัดลอกสิทธิ์ (ซึ่งในกรณีนี้คือการลบสิทธิ์เฉพาะผู้ใช้นั้นออก)
      //    _showSnackBar('สิทธิ์ผู้ใช้ ${user.userName} ถูกอัปเดต (ลบสิทธิ์ถ้าไม่เป็นสมาชิกแล้ว)', Colors.blue);
      // } else {
      //   // หากเลือกผู้ใช้เป็นสมาชิกใหม่ หรือเลือกผู้ใช้เดิมอีกครั้ง
      //   // ให้คัดลอกสิทธิ์จาก organization_menu ไปทับสิทธิ์ผู้ใช้
      //   await _groupUserService.copyGroupMenuToUser(_selectedNode!.id!, user.id);
      //   _showSnackBar('สิทธิ์ผู้ใช้ ${user.userName} ถูกคัดลอกจากกลุ่มแล้ว', Colors.blue);
      // }
    } catch (e) {
      // Rollback UI change if API fails
      setState(() {
        user.isMember = !newValue;
      });
      _showSnackBar('Failed to update membership: $e', Colors.red);
    }
  }

  // ลบผู้ใช้ทั้งหมดจากกลุ่ม
  Future<void> _onDelete(Group rowData) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ยืนยันการลบผู้ใช้ทั้งหมด'),
          content: Text(
              'คุณแน่ใจหรือไม่ที่ต้องการลบผู้ใช้ทั้งหมดออกจากกลุ่ม "${rowData.name}"?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('ลบทั้งหมด'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await _groupUserService.deleteGroupUsers(rowData.id!);
        _showSnackBar('ลบผู้ใช้ทั้งหมดจากกลุ่ม ${rowData.name} เรียบร้อยแล้ว',
            Colors.green);
        if (_selectedNode?.id == rowData.id) {
          // ถ้าเป็นกลุ่มที่กำลังแสดงอยู่ ให้รีเฟรช panel
          _fetchDataForDetail();
        }
      } catch (e) {
        _showSnackBar('Failed to delete all users from group: $e', Colors.red);
      }
    }
  }

  // คัดลอกสิทธิ์เมนูจากกลุ่มไปยังผู้ใช้ (ปุ่ม "คัดลอกสิทธิ์")
  Future<void> _onCopyGroupMenuToUser(User user) async {
    if (_selectedNode == null) {
      _showSnackBar('กรุณาเลือกกลุ่มก่อน', Colors.orange);
      return;
    }
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('คัดลอกสิทธิ์เมนู'),
          content: Text(
              'คุณต้องการคัดลอกสิทธิ์เมนูของกลุ่ม "${_selectedNode!.name}" ไปทับสิทธิ์ปัจจุบันของ "${user.userName}" หรือไม่?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('คัดลอก'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await _groupUserService.copyGroupMenuToUser(
            _selectedNode!.id!, user.id);
        _showSnackBar(
            'สิทธิ์เมนูถูกคัดลอกไปยังผู้ใช้ ${user.userName} เรียบร้อยแล้ว',
            Colors.green);
      } catch (e) {
        _showSnackBar('Failed to copy group menu to user: $e', Colors.red);
      }
    }
  }

  // จัดเรียงผู้ใช้
  void _sortUser() {
    _detailInPanel.sort((a, b) {
      switch (_currentSortOption) {
        case SortOption.userName:
          return a!.userName.compareTo(b!.userName);
        case SortOption.firstName:
          return a!.firstName!.compareTo(b!.firstName!);
        case SortOption.lastName:
          return a!.lastName!.compareTo(b!.lastName!);
      }
    });
    setState(() {}); // บังคับให้ UI อัปเดต
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
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
        backgroundColor: Colors.deepOrange.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรชรายการ',
            onPressed: _fetchData,
          ),
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
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'โครงสร้างกลุ่ม',
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
                if (!isFolder || !hasChildren) const SizedBox(width: 24),
                Icon(isFolder ? Icons.group_work : Icons.groups_3),
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
                  tooltip: 'ดูสมาชิกกลุ่ม',
                  onPressed: () => _onView(rowData),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                  tooltip: 'แก้ไข',
                  // onPressed: () => _setEditMode(rowData),
                  onPressed: () => _onEdit(rowData),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.red, size: 20),
                  tooltip: 'ลบผู้ใช้ทั้งหมดจากกลุ่ม',
                  // onPressed: () => _setEditMode(rowData),
                  onPressed: () => _onDelete(rowData),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded && hasChildren)
          Column(
            children:
                children.map((child) => _buildNode(child, level + 1)).toList(),
          ),
      ],
    );
  }

  // Helper method สำหรับสร้างเนื้อหาใน Panel ด้านขวา
  Widget _buildRightPanelContent() {
    if (_selectedNode == null || _nodeMode == NodeMode.empty) {
      return const Center(child: Text('เลือกกลุ่มเพื่อจัดการสิทธิ์'));
    }

    if (_allUsers.isEmpty) {
      return const Center(child: Text('ไม่พบรายการเมนูในระบบ'));
    }

    return Column(
      children: [
        // ส่วนหัว Panel ขวา
        AppBar(
          automaticallyImplyLeading: false, // ไม่ต้องมีปุ่ม Back
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          title: Text(
            _selectedNode == null
                ? 'เลือกกลุ่มเพื่อจัดการผู้ใช้'
                : 'ผู้ใช้: ${_selectedNode!.name}',
            style: const TextStyle(fontSize: 18),
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (_selectedNode != null && _nodeMode == NodeMode.edit)
              PopupMenuButton<SortOption>(
                icon: const Icon(Icons.sort),
                onSelected: (SortOption result) {
                  setState(() {
                    _currentSortOption = result;
                  });
                  _sortUser();
                },
                itemBuilder: (BuildContext context) =>
                    <PopupMenuEntry<SortOption>>[
                  const PopupMenuItem<SortOption>(
                    value: SortOption.userName,
                    child: Text('เรียงตามผู้ใช้'),
                  ),
                  const PopupMenuItem<SortOption>(
                    value: SortOption.firstName,
                    child: Text('เรียงตามชื่อจริง'),
                  ),
                  const PopupMenuItem<SortOption>(
                    value: SortOption.lastName,
                    child: Text('เรียงตามนามสกุล'),
                  ),
                ],
              ),
          ],
        ),
        // Body Panel ขวา
        Expanded(
          child: _isLoadingDetail
              ? const Center(child: CircularProgressIndicator())
              : _selectedNode == null
                  ? const Center(child: Text('กรุณาเลือกกลุ่มจาก Panel ซ้าย'))
                  : _detailInPanel.isEmpty
                      ? const Center(child: Text('ไม่พบผู้ใช้ในกลุ่มนี้'))
                      : ListView.builder(
                          itemCount: _detailInPanel.length,
                          itemBuilder: (context, index) {
                            final user = _detailInPanel[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 8.0, vertical: 4.0),
                              elevation: 1,
                              child: ListTile(
                                leading: _nodeMode == NodeMode.edit
                                    ? Checkbox(
                                        value: user!.isMember,
                                        onChanged: (newValue) =>
                                            _toggleUserMembership(
                                                user, newValue),
                                      )
                                    : null,
                                title: Text(
                                    '${user!.firstName} ${user.lastName} (${user.userName})'),
                                subtitle: Text('${user.email}'),
                                // trailing:
                                //     _nodeMode == NodeMode.edit && user.isMember
                                //         ? IconButton(
                                //             icon: const Icon(Icons.copy_all,
                                //                 color: Colors.indigo),
                                //             tooltip: 'คัดลอกสิทธิ์จากกลุ่ม',
                                //             onPressed: () =>
                                //                 _onCopyGroupMenuToUser(user),
                                //           )
                                //         : null,
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
  
}
