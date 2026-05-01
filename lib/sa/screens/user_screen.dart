// screens/user_management_screen.dart

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../models/user.dart';
import '../services/user_service.dart';
import '../widgets/user_list_widget.dart';
import '../widgets/user_detail_widget.dart';

enum UserFormState {
  none,
  adding,
  editing,
  viewing,
}

class UserScreen extends StatefulWidget {
  final VoidCallback? onExit;

  const UserScreen({
    super.key,
    this.onExit,
  });

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> with AutomaticKeepAliveClientMixin{
  List<User> _users = [];
  bool _isLoading = true;
  String _error = '';

  UserFormState _formState = UserFormState.none;
  User? _selectedUserForEdit;
  User? _selectedUserForView;

  UserSortBy _sortBy = UserSortBy.userName;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool _isLeftPanelExpanded = true;
  double _leftPanelWidth = 360.0;
  bool _isDraggingDivider = false;

  @override
  void initState() {
    super.initState();
    _fetchUsers();

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
  // bool get wantKeepAlive => throw UnimplementedError();
  bool get wantKeepAlive => true;

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final userService = Provider.of<UserService>(context, listen: false);
      final fetchedUsers = await userService.fetchUsers();
      setState(() {
        _users = fetchedUsers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'ไม่สามารถโหลดข้อมูลผู้ใช้ได้: ${e.toString()}';
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_error)),
        );
      }
    }
  }

  void _onAddUser() {
    setState(() {
      _formState = UserFormState.adding;
      _selectedUserForEdit = null;
      _selectedUserForView = null;
    });
  }

  void _onEditUser(User user) {
    setState(() {
      _formState = UserFormState.editing;
      _selectedUserForEdit = user;
      _selectedUserForView = null;
    });
  }

  void _onViewUser(User user) {
    setState(() {
      _formState = UserFormState.viewing;
      _selectedUserForEdit = null;
      _selectedUserForView = user;
    });
  }

  Future<void> _onDeleteUser(User user) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('คุณแน่ใจหรือไม่ที่จะลบผู้ใช้ "${user.firstName} ${user.lastName}" ?'),
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
        final userService = Provider.of<UserService>(context, listen: false);
        await userService.deleteUser(user.id);
        await _fetchUsers();
        _onFormCancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ลบผู้ใช้สำเร็จ')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('เกิดข้อผิดพลาดในการลบผู้ใช้: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _onFormSubmit(User user) async {
    try {
      final userService = Provider.of<UserService>(context, listen: false);
      if (_selectedUserForEdit == null) {
        await userService.addUser(user);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('เพิ่มผู้ใช้สำเร็จ')),
          );
        }
      } else {
        await userService.updateUser(user);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('บันทึกผู้ใช้สำเร็จ')),
          );
        }
      }
      await _fetchUsers();
      _onFormCancel();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึกผู้ใช้: ${e.toString()}')),
        );
      }
    }
  }

  void _onFormCancel() {
    setState(() {
      _formState = UserFormState.none;
      _selectedUserForEdit = null;
      _selectedUserForView = null;
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
        title: const Row(children: [Icon(Icons.manage_accounts, color: Colors.white, size: 20), SizedBox(width: 8), Text('จัดการผู้ใช้')]),
        backgroundColor: Colors.deepOrange[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรชรายการ',
            onPressed: _fetchUsers,
          ),
          // IconButton(
          //   icon: const Icon(Icons.add, color: Colors.white),
          //   onPressed: _onAddUser,
          //   tooltip: 'เพิ่มผู้ใช้ใหม่',
          // ),
          PopupMenuButton<UserSortBy>(
            icon: const Icon(Icons.sort, color: Colors.white),
            tooltip: 'จัดเรียงข้อมูล',
            onSelected: _onSortSelected,
            itemBuilder: (BuildContext context) => <PopupMenuEntry<UserSortBy>>[
              const PopupMenuItem<UserSortBy>(
                value: UserSortBy.userName,
                child: Text('เรียงตาม Username'),
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
              const PopupMenuItem<UserSortBy>( // <-- เพิ่มการจัดเรียงตาม User Type
                value: UserSortBy.userType,
                child: Text('เรียงตามประเภทผู้ใช้'),
              ),
            ],
          ),
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
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: _onAddUser,
                                          icon: const Icon(Icons.add),
                                          label: const Text('เพิ่มผู้ใช้ใหม่'),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: UserListPanel(
                                        users: _users,
                                        onEdit: _onEditUser,
                                        onView: _onViewUser,
                                        onDelete: _onDeleteUser,
                                        searchController: _searchController,
                                        sortBy: _sortBy,
                                        searchQuery: _searchQuery,
                                        onViewPermissions: (user) {},
                                        onEditPermissions: (user) {},
                                        onDeletePermissions: (user) {},
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
                        Expanded(child: _buildDetailForm()),
                      ],
                    );
                  },
                ),
    );
  }

  Widget _buildDetailForm() {
    switch (_formState) {
      case UserFormState.none:
        return const Center(
          child: Text('เลือกผู้ใช้เพื่อแก้ไข หรือ ลบ หรือ กดปุ่ม + เพื่อเพิ่มผู้ใช้ใหม่'),
        );
      case UserFormState.adding:
        return UserDetailForm(
          onSubmit: _onFormSubmit,
          onCancel: _onFormCancel,
        );
      case UserFormState.editing:
        return UserDetailForm(
          editUser: _selectedUserForEdit,
          viewUser: _selectedUserForView,
          onSubmit: _onFormSubmit,
          onCancel: _onFormCancel,
        );
      case UserFormState.viewing:
        return UserDetailForm(
          editUser: _selectedUserForEdit,
          viewUser: _selectedUserForView,
          onSubmit: (user){},
          onCancel: _onFormCancel,
        );
      default:
        return const SizedBox.shrink();
    }
  }
  
}