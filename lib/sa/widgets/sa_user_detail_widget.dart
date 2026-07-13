import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sa_user.dart';
import '../models/sa_user_branch.dart';
import '../services/sa_language_provider.dart';
import '../services/sa_user_branch_service.dart';
import '../../cd/models/branch.dart';
import '../../cd/services/branch_service.dart';

class UserDetailForm extends StatefulWidget {
  final User? editUser;
  final User? viewUser;
  final Function(User) onSubmit;
  final VoidCallback onCancel;
  /// true = หน้าจอจัดการผู้ใช้ (แก้ไขได้ทุกฟีลด์รวม username, โหลดทุกสาขา)
  final bool adminMode;
  /// ประเภทผู้ใช้ที่ login อยู่ — ใช้กำหนด dropdown ประเภทผู้ใช้ที่มองเห็นได้
  final String currentUserType;

  const UserDetailForm({
    super.key,
    this.editUser,
    this.viewUser,
    required this.onSubmit,
    required this.onCancel,
    this.adminMode = false,
    this.currentUserType = 'user',
  });

  @override
  State<UserDetailForm> createState() => _UserDetailFormState();
}

class _UserDetailFormState extends State<UserDetailForm> {
  User? user;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late String _status;
  late String _userType;
  bool _isEditing = false;
  bool _isViewing = false;
  bool _showPassword = false;
  // Branch section
  List<UserBranch> _assignedBranches = [];
  bool _branchesLoading = false;
  bool _branchesSaving = false;
  int? _defaultBranchId;
  final UserBranchService _userBranchService = UserBranchService();

  // ประเภทที่ current user สามารถมองเห็น/กำหนดได้ (ตัวเองและต่ำกว่า)
  List<String> get _allowedUserTypes => User.allowedTypesFor(widget.currentUserType);

  // Clamps to available list (ถ้า value ไม่อยู่ใน list → เลือกตัวแรก)
  String get _resolvedUserType {
    final available = _allowedUserTypes;
    return available.contains(_userType) ? _userType : (available.isNotEmpty ? available.first : 'user');
  }

  @override
  void initState() {
    super.initState();
    _isEditing = widget.editUser != null;
    _isViewing = widget.viewUser != null;
    user = widget.editUser ?? widget.viewUser;
    _usernameController = TextEditingController(text: user?.userName ?? '');
    _firstNameController = TextEditingController(text: user?.firstName ?? '');
    _lastNameController = TextEditingController(text: user?.lastName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _passwordController = TextEditingController();
    _status = user?.status ?? 'active';
    _userType = user?.userType ?? 'user';
    if (user != null && user!.id > 0) _loadBranches();
  }

  @override
  void didUpdateWidget(covariant UserDetailForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.editUser != null && widget.editUser != oldWidget.editUser) ||
        (oldWidget.viewUser != null && widget.viewUser != oldWidget.viewUser)) {
      _isEditing = widget.editUser != null;
      _isViewing = widget.viewUser != null;
      user = widget.editUser ?? widget.viewUser;
      _usernameController.text = user?.userName ?? '';
      _firstNameController.text = user?.firstName ?? '';
      _lastNameController.text = user?.lastName ?? '';
      _emailController.text = user?.email ?? '';
      _passwordController.text = '';
      _status = user?.status ?? 'active';
      _userType = user?.userType ?? 'user';
      _showPassword = false;
      _assignedBranches = [];
      _defaultBranchId = null;
      if (user != null && user!.id > 0) _loadBranches();
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    if (user == null || user!.id <= 0) return;
    setState(() => _branchesLoading = true);
    try {
      final branches = await _userBranchService.fetchByUserId(user!.id);
      final defs = branches.where((b) => b.isDefault);
      if (mounted) {
        setState(() {
          _assignedBranches = branches;
          _defaultBranchId = defs.isEmpty ? null : defs.first.branchId;
          _branchesLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _branchesLoading = false);
    }
  }

  Future<void> _saveBranches() async {
    if (user == null || user!.id <= 0) return;
    setState(() => _branchesSaving = true);
    try {
      final toSave = _assignedBranches
          .map((b) => b.copyWith(isDefault: b.branchId == _defaultBranchId))
          .toList();
      await _userBranchService.updateByUserId(user!.id, toSave);
      if (mounted) {
        final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isEnglish ? 'Branch saved successfully' : 'บันทึกสาขาสำเร็จ'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isEnglish ? 'Save branch failed: $e' : 'บันทึกสาขาล้มเหลว: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _branchesSaving = false);
    }
  }

  void _removeBranch(UserBranch branch) {
    setState(() {
      _assignedBranches.removeWhere((b) => b.branchId == branch.branchId);
      if (_defaultBranchId == branch.branchId) {
        _defaultBranchId =
            _assignedBranches.isEmpty ? null : _assignedBranches.first.branchId;
      }
    });
  }

  Future<void> _showAddBranchDialog() async {
    List<Branch> allBranches = [];
    String? loadError;
    try {
      allBranches = await BranchService().fetchRows();
    } catch (e) {
      loadError = e.toString();
    }

    if (!mounted) return;

    final isEnglish = mounted
        ? Provider.of<LanguageProvider>(context, listen: false).isEnglish
        : false;

    if (loadError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEnglish
              ? 'Load branch data failed: $loadError'
              : 'โหลดข้อมูลสาขาล้มเหลว: $loadError'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final assignedIds = _assignedBranches.map((b) => b.branchId).toSet();
    final available = allBranches
        .where((b) => b.isActive && !assignedIds.contains(b.id))
        .toList()
      ..sort((a, b) => a.branchCode.compareTo(b.branchCode));

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEnglish
              ? 'No more branches available to add'
              : 'ไม่มีสาขาที่เพิ่มได้อีกแล้ว'),
        ),
      );
      return;
    }

    final searchCtrl = TextEditingController();
    List<Branch> filtered = List.from(available);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          void doFilter(String q) {
            setDlgState(() {
              if (q.isEmpty) {
                filtered = List.from(available);
              } else {
                final lq = q.toLowerCase();
                filtered = available
                    .where((b) =>
                        b.branchCode.toLowerCase().contains(lq) ||
                        b.branchNameThai.toLowerCase().contains(lq))
                    .toList();
              }
            });
          }

          return AlertDialog(
            title: Row(children: [
              const Icon(Icons.business, size: 20, color: Colors.teal),
              const SizedBox(width: 8),
              Text(isEnglish ? 'Select Branch' : 'เลือกสาขา'),
            ]),
            content: SizedBox(
              width: 420,
              height: 360,
              child: Column(children: [
                TextField(
                  controller: searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: isEnglish ? 'Search code / name' : 'ค้นหา รหัส / ชื่อ',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  onChanged: doFilter,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            isEnglish ? 'No data found' : 'ไม่พบข้อมูล',
                            style: const TextStyle(color: Colors.grey),
                          ))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final b = filtered[i];
                            return ListTile(
                              dense: true,
                              title: Text(
                                '${b.branchCode}  ${b.branchNameThai}',
                                style: const TextStyle(fontSize: 14),
                              ),
                              onTap: () {
                                Navigator.of(ctx).pop();
                                final isFirst = _assignedBranches.isEmpty;
                                setState(() {
                                  _assignedBranches.add(UserBranch(
                                    id: 0,
                                    userId: user!.id,
                                    branchId: b.id!,
                                    branchCode: b.branchCode,
                                    branchNameThai: b.branchNameThai,
                                    isDefault: isFirst,
                                  ));
                                  if (isFirst) _defaultBranchId = b.id;
                                });
                              },
                            );
                          },
                        ),
                ),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(isEnglish ? 'Close' : 'ปิด')),
            ],
          );
        },
      ),
    );
    searchCtrl.dispose();
  }

  Widget _buildBranchSection() {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final notSavedYet = user == null || user!.id <= 0;
    if (notSavedYet) {
      return Card(
        elevation: 0,
        color: Colors.teal.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.teal.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(Icons.business, size: 18, color: Colors.teal[700]),
            const SizedBox(width: 8),
            Text(
              isEnglish ? 'Allowed Branches' : 'สาขาที่มีสิทธิ์',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[800]),
            ),
            const SizedBox(width: 16),
            Text(
              isEnglish
                  ? '— Please save the user first before assigning branches'
                  : '— กรุณาบันทึกผู้ใช้ก่อน เพื่อกำหนดสาขา',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ]),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: Colors.teal.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.teal.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.business, size: 18, color: Colors.teal[700]),
              const SizedBox(width: 8),
              Text(
                isEnglish ? 'Allowed Branches' : 'สาขาที่มีสิทธิ์',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[800]),
              ),
              const Spacer(),
              if (!_isViewing)
                TextButton.icon(
                  onPressed: _showAddBranchDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(isEnglish ? 'Add Branch' : 'เพิ่มสาขา'),
                  style:
                      TextButton.styleFrom(foregroundColor: Colors.teal[700]),
                ),
            ]),
            const SizedBox(height: 8),
            if (_branchesLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_assignedBranches.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Text(
                    isEnglish ? 'No branch assigned yet' : 'ยังไม่ได้กำหนดสาขา',
                    style: TextStyle(
                        color: Colors.orange[700], fontSize: 13),
                  ),
                ]),
              )
            else
              Column(
                children: _assignedBranches.map((branch) {
                  final isDefault = branch.branchId == _defaultBranchId;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Radio<int>(
                        value: branch.branchId,
                        groupValue: _defaultBranchId,
                        onChanged: _isViewing
                            ? null
                            : (v) => setState(() => _defaultBranchId = v),
                        activeColor: Colors.teal,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                      Expanded(
                        child: Text(
                          '${branch.branchCode}  ${branch.branchNameThai}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      if (isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isEnglish ? 'Main' : 'หลัก',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.teal[800],
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      if (!_isViewing)
                        IconButton(
                          icon: const Icon(Icons.close,
                              size: 16, color: Colors.grey),
                          onPressed: () => _removeBranch(branch),
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          tooltip: isEnglish ? 'Remove' : 'ลบ',
                        ),
                    ]),
                  );
                }).toList(),
              ),
            if (!_isViewing) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _branchesSaving ? null : _saveBranches,
                  icon: _branchesSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save, size: 16),
                  label: Text(isEnglish ? 'Save Branches' : 'บันทึกสาขา'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final newUser = User(
        id: widget.editUser?.id ?? 0,
        userName: _usernameController.text,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        email: _emailController.text,
        password: _passwordController.text.isNotEmpty
            ? _passwordController.text
            : null,
        status: _status,
        userType: _resolvedUserType,
      );
      widget.onSubmit(newUser);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isViewing
                  ? (isEnglish ? 'View User' : 'ดูข้อมูลผู้ใช้')
                  : _isEditing
                      ? (isEnglish ? 'Edit User' : 'แก้ไขผู้ใช้')
                      : (isEnglish ? 'Add New User' : 'เพิ่มผู้ใช้ใหม่'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            TextFormField(
              readOnly: !widget.adminMode && (_isEditing || _isViewing),
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: isEnglish ? 'Username' : 'ผู้ใช้',
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return isEnglish ? 'Please enter a username' : 'กรุณาป้อนผู้ใช้';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              readOnly: _isViewing,
              controller: _firstNameController,
              decoration: InputDecoration(
                labelText: isEnglish ? 'First Name' : 'ชื่อจริง',
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return isEnglish ? 'Please enter a first name' : 'กรุณาป้อนชื่อจริง';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              readOnly: _isViewing,
              controller: _lastNameController,
              decoration: InputDecoration(
                labelText: isEnglish ? 'Last Name' : 'นามสกุล',
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return isEnglish ? 'Please enter a last name' : 'กรุณาป้อนนามสกุล';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              readOnly: _isViewing,
              controller: _emailController,
              decoration: InputDecoration(
                labelText: isEnglish ? 'Email' : 'อีเมล',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              readOnly: _isViewing,
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: _isEditing
                    ? (isEnglish ? 'Password (leave blank to keep unchanged)' : 'รหัสผ่าน (เว้นว่างหากไม่เปลี่ยน)')
                    : (isEnglish ? 'Password' : 'รหัสผ่าน'),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                      _showPassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
              ),
              obscureText: !_showPassword,
              validator: (value) {
                if (!_isEditing && (value == null || value.isEmpty)) {
                  return isEnglish ? 'Please enter a password' : 'กรุณาป้อนรหัสผ่าน';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _status,
              decoration: InputDecoration(
                labelText: isEnglish ? 'Status' : 'สถานะ',
                border: const OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('active')),
                DropdownMenuItem(value: 'inactive', child: Text('inactive')),
              ],
              onChanged: _isViewing
                  ? null
                  : (value) {
                      if (value != null) setState(() => _status = value);
                    },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _resolvedUserType,
              decoration: InputDecoration(
                labelText: isEnglish ? 'User Type' : 'ประเภทผู้ใช้',
                border: const OutlineInputBorder(),
              ),
              items: _allowedUserTypes
                  .map((type) =>
                      DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: _isViewing
                  ? null
                  : (value) {
                      if (value != null) setState(() => _userType = value);
                    },
            ),

            if (user != null && user!.id > 0) ...[
              const SizedBox(height: 24),
              _buildBranchSection(),
            ],

            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!_isViewing)
                  ElevatedButton(
                    onPressed: _submitForm,
                    child: Text(_isEditing
                        ? (isEnglish ? 'Save' : 'บันทึก')
                        : (isEnglish ? 'Add' : 'เพิ่ม')),
                  ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: widget.onCancel,
                  child: Text(isEnglish ? 'Cancel' : 'ยกเลิก'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
