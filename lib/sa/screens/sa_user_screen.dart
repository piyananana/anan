// screens/user_management_screen.dart

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../services/sa_language_provider.dart';
import '../utils/sa_app_l10n.dart';
import '../utils/sa_menu_scope.dart';
import '../models/sa_user.dart';
import '../services/sa_auth_service.dart';
import '../services/sa_user_service.dart';
import '../widgets/sa_user_list_widget.dart';
import '../widgets/sa_user_detail_widget.dart';

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

  bool _isLeftPanelExpanded = true;
  double _leftPanelWidth = 360.0;
  bool _isDraggingDivider = false;

  String get _currentUserType => AuthService().currentUser?.userType ?? 'guest';

  // กรองรายชื่อตาม hierarchy — ผู้ login เห็นเฉพาะ type ที่ ≤ ตัวเอง
  List<User> get _visibleUsers {
    final allowed = User.allowedTypesFor(_currentUserType).toSet();
    return _users.where((u) => allowed.contains(u.userType)).toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
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
    _onEditUser(user); // user_screen ใช้ edit mode เสมอ
  }

  Future<void> _onDeleteUser(User user) async {
    final l = AppL10n(Provider.of<LanguageProvider>(context, listen: false).isEnglish);
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.confirmDelete),
        content: Text(l.isEnglish
            ? 'Are you sure you want to delete user "${user.firstName} ${user.lastName}"?'
            : 'คุณแน่ใจหรือไม่ที่จะลบผู้ใช้ "${user.firstName} ${user.lastName}" ?'),
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
        final userService = Provider.of<UserService>(context, listen: false);
        await userService.deleteUser(user.id);
        await _fetchUsers();
        _onFormCancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.isEnglish ? 'User deleted successfully' : 'ลบผู้ใช้สำเร็จ')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.isEnglish ? 'Error deleting user: ${e.toString()}' : 'เกิดข้อผิดพลาดในการลบผู้ใช้: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _onFormSubmit(User user) async {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    try {
      final userService = Provider.of<UserService>(context, listen: false);
      if (_selectedUserForEdit == null) {
        await userService.addUser(user);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEnglish ? 'User added successfully' : 'เพิ่มผู้ใช้สำเร็จ')),
          );
        }
      } else {
        await userService.updateUser(user);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEnglish ? 'User saved successfully' : 'บันทึกผู้ใช้สำเร็จ')),
          );
        }
      }
      await _fetchUsers();
      _onFormCancel();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEnglish ? 'Error saving user: ${e.toString()}' : 'เกิดข้อผิดพลาดในการบันทึกผู้ใช้: ${e.toString()}')),
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
            tooltip: l.isEnglish ? 'Refresh list' : 'รีเฟรชรายการ',
            onPressed: _fetchUsers,
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
                              child: ColoredBox(
                                color: Colors.blueGrey.shade100,
                                child: UserListPanel(
                                  users: _visibleUsers,
                                  enableAddButton: true,
                                  enableSortButton: true,
                                  onAdd: _onAddUser,
                                  onEdit: _onEditUser,
                                  onView: _onViewUser,
                                  onDelete: _onDeleteUser,
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
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    switch (_formState) {
      case UserFormState.none:
        return Center(
          child: Text(isEnglish
              ? 'Select a user to edit or delete, or press + to add a new user'
              : 'เลือกผู้ใช้เพื่อแก้ไข หรือ ลบ หรือ กดปุ่ม + เพื่อเพิ่มผู้ใช้ใหม่'),
        );
      case UserFormState.adding:
        return UserDetailForm(
          adminMode: true,
          currentUserType: _currentUserType,
          onSubmit: _onFormSubmit,
          onCancel: _onFormCancel,
        );
      case UserFormState.editing:
        return UserDetailForm(
          adminMode: true,
          currentUserType: _currentUserType,
          editUser: _selectedUserForEdit,
          onSubmit: _onFormSubmit,
          onCancel: _onFormCancel,
        );
      case UserFormState.viewing:
        return UserDetailForm(
          adminMode: true,
          currentUserType: _currentUserType,
          editUser: _selectedUserForView,
          onSubmit: _onFormSubmit,
          onCancel: _onFormCancel,
        );
      default:
        return const SizedBox.shrink();
    }
  }
  
}