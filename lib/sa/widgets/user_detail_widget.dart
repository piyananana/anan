import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/user_branch.dart';
import '../services/user_branch_service.dart';
import '../../cd/models/branch.dart';
import '../../cd/services/branch_service.dart';

class UserDetailForm extends StatefulWidget {
  final User? editUser;
  final User? viewUser;
  final Function(User) onSubmit;
  final VoidCallback onCancel;
  /// true = หน้าจอจัดการผู้ใช้ (แก้ไขได้ทุกฟีลด์รวม username, โหลดทุกสาขา)
  final bool adminMode;

  const UserDetailForm({
    super.key,
    this.editUser,
    this.viewUser,
    required this.onSubmit,
    required this.onCancel,
    this.adminMode = false,
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

  final List<String> _userTypes = ['guest', 'user', 'administrator', 'superadmin'];

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('บันทึกสาขาสำเร็จ'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('บันทึกสาขาล้มเหลว: $e'),
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

    if (loadError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลดข้อมูลสาขาล้มเหลว: $loadError'),
            backgroundColor: Colors.red),
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
        const SnackBar(content: Text('ไม่มีสาขาที่เพิ่มได้อีกแล้ว')),
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
            title: const Row(children: [
              Icon(Icons.business, size: 20, color: Colors.teal),
              SizedBox(width: 8),
              Text('เลือกสาขา'),
            ]),
            content: SizedBox(
              width: 420,
              height: 360,
              child: Column(children: [
                TextField(
                  controller: searchCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'ค้นหา รหัส / ชื่อ',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  onChanged: doFilter,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text('ไม่พบข้อมูล',
                              style: TextStyle(color: Colors.grey)))
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
                  child: const Text('ปิด')),
            ],
          );
        },
      ),
    );
    searchCtrl.dispose();
  }

  Widget _buildBranchSection() {
    // superadmin ที่ยังไม่ได้บันทึก → แสดง card พร้อมคำแนะนำ
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
            Text('สาขาที่มีสิทธิ์',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[800])),
            const SizedBox(width: 16),
            Text('— กรุณาบันทึกผู้ใช้ก่อน เพื่อกำหนดสาขา',
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
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
              Text('สาขาที่มีสิทธิ์',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[800])),
              const Spacer(),
              if (!_isViewing)
                TextButton.icon(
                  onPressed: _showAddBranchDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('เพิ่มสาขา'),
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
                  Text('ยังไม่ได้กำหนดสาขา',
                      style: TextStyle(
                          color: Colors.orange[700], fontSize: 13)),
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
                          child: Text('หลัก',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.teal[800],
                                  fontWeight: FontWeight.w500)),
                        ),
                      if (!_isViewing)
                        IconButton(
                          icon: const Icon(Icons.close,
                              size: 16, color: Colors.grey),
                          onPressed: () => _removeBranch(branch),
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          tooltip: 'ลบ',
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
                  label: const Text('บันทึกสาขา'),
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
        userType: _userType,
      );
      widget.onSubmit(newUser);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isViewing
                  ? 'ดูข้อมูลผู้ใช้'
                  : _isEditing
                      ? 'แก้ไขผู้ใช้'
                      : 'เพิ่มผู้ใช้ใหม่',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            TextFormField(
              readOnly: !widget.adminMode && (_isEditing || _isViewing),
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'ผู้ใช้',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'กรุณาป้อนผู้ใช้';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              readOnly: _isViewing,
              controller: _firstNameController,
              decoration: const InputDecoration(
                labelText: 'ชื่อจริง',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'กรุณาป้อนชื่อจริง';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              readOnly: _isViewing,
              controller: _lastNameController,
              decoration: const InputDecoration(
                labelText: 'นามสกุล',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'กรุณาป้อนนามสกุล';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              readOnly: _isViewing,
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'อีเมล',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              readOnly: _isViewing,
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: _isEditing
                    ? 'รหัสผ่าน (เว้นว่างหากไม่เปลี่ยน)'
                    : 'รหัสผ่าน',
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
                  return 'กรุณาป้อนรหัสผ่าน';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(
                labelText: 'สถานะ',
                border: OutlineInputBorder(),
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
              value: _userType,
              decoration: const InputDecoration(
                labelText: 'ประเภทผู้ใช้',
                border: OutlineInputBorder(),
              ),
              items: _userTypes
                  .map((type) =>
                      DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: _isViewing
                  ? null
                  : (value) {
                      if (value != null) setState(() => _userType = value);
                    },
            ),

            // Branch section: แสดงเสมอสำหรับ superadmin, แสดงเมื่อมี id สำหรับ user ประเภทอื่น
            if ((user != null && user!.id > 0) || _userType == 'superadmin') ...[
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
                    child: Text(_isEditing ? 'บันทึก' : 'เพิ่ม'),
                  ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: widget.onCancel,
                  child: const Text('ยกเลิก'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
