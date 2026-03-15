// widgets/user_detail_form.dart
import 'package:flutter/material.dart';
import '../models/user.dart';

class UserDetailForm extends StatefulWidget {
  final User? editUser;
  final User? viewUser;
  final Function(User) onSubmit;
  final VoidCallback onCancel;

  const UserDetailForm({
    super.key,
    this.editUser,
    this.viewUser,
    required this.onSubmit,
    required this.onCancel,
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
  late String _userType; // <-- เพิ่ม _userType
  bool _isEditing = false;
  bool _isViewing = false;
  bool _showPassword = false;

  final List<String> _userTypes = [
    'guest',
    'user',
    'administrator',
    'superadmin'
  ]; // <-- รายการ User Type

  @override
  void initState() {
    super.initState();
    _isEditing = widget.editUser != null;
    _isViewing = widget.viewUser != null;
    user = widget.editUser ?? widget.viewUser;
    _usernameController =
        TextEditingController(text: user?.userName ?? '');
    _firstNameController =
        TextEditingController(text: user?.firstName ?? '');
    _lastNameController =
        TextEditingController(text: user?.lastName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _passwordController = TextEditingController(text: '');
    _status = user?.status ?? 'active';
    _userType = user?.userType ??
        'user'; // <-- กำหนดค่าเริ่มต้น/โหลดค่าที่มีอยู่
  }

  @override
  void didUpdateWidget(covariant UserDetailForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // if (widget.user != oldWidget.user) {
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
      _userType = user?.userType ?? 'user'; // <-- อัปเดต userType
      _showPassword = false;
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

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final newUser = User(
        // id: widget.user?.id ?? 0,
        id: widget.editUser?.id ?? 0,
        userName: _usernameController.text,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        email: _emailController.text,
        password: _passwordController.text.isNotEmpty
            ? _passwordController.text
            : null,
        status: _status,
        userType: _userType, // <-- เพิ่ม userType ที่นี่
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
              readOnly: _isEditing || _isViewing,
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'ผู้ใช้',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณาป้อนผู้ใช้';
                }
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
                if (value == null || value.isEmpty) {
                  return 'กรุณาป้อนชื่อจริง';
                }
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
                if (value == null || value.isEmpty) {
                  return 'กรุณาป้อนนามสกุล';
                }
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
              // validator: (value) {
              //   if (value == null || value.isEmpty) {
              //     return 'กรุณาป้อนอีเมล';
              //   }
              //   if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
              //     return 'รูปแบบอีเมลไม่ถูกต้อง';
              //   }
              //   return null;
              // },
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
                    _showPassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _showPassword = !_showPassword;
                    });
                  },
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
              onChanged: _isViewing ? null : (value) {
                if (value != null) {
                  setState(() {
                    _status = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            // --- เพิ่ม Dropdown สำหรับ User Type ---
            DropdownButtonFormField<String>(
              value: _userType,
              decoration: const InputDecoration(
                labelText: 'ประเภทผู้ใช้',
                border: OutlineInputBorder(),
              ),
              items: _userTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: _isViewing ? null : (value) {
                if (value != null) {
                  setState(() {
                    _userType = value;
                  });
                }
              },
            ),
            // --- สิ้นสุดการเพิ่ม User Type ---
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _isViewing
                    ? Container() // ไม่แสดงปุ่มใดๆ หากเป็นโหมดดูอย่างเดียว
                    : ElevatedButton(
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
