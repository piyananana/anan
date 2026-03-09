// widgets/change_password_dialog.dart
import 'package:flutter/material.dart';

import '../models/password_policy.dart';
import '../screens/home_screen.dart';
import '../services/auth_service.dart';
import '../services/password_policy_service.dart';
import 'password_strength_meter.dart';

class ChangePasswordDialog extends StatefulWidget {
  final int userId; // User ID for the password change
  final bool forceChange; // Flag สำหรับบังคับเปลี่ยนรหัสผ่าน

  // final Function(String currentPassword, String newPassword) onChangePassword;

  const ChangePasswordDialog({
    super.key,
    required this.userId,
    this.forceChange = false,
    // required this.onChangePassword,
  });

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>(); // Key สำหรับ Form validation
  // final bool _isLoading = false;
  // String? _errorMessage;

  PasswordPolicy? _passwordPolicy;
  bool _isLoadingPolicy = true;
  String? _policyError;

  // Future<void> _submitChangePassword() async {
  //   if (_formKey.currentState!.validate()) {
  //     setState(() {
  //       _isLoading = true;
  //       _errorMessage = null;
  //     });
  //     try {
  //       await widget.onChangePassword(
  //         _currentPasswordController.text,
  //         _newPasswordController.text,
  //       );
  //       Navigator.of(context).pop(true); // ปิด dialog และส่งค่า true กลับไป
  //     } catch (e) {
  //       setState(() {
  //         _errorMessage = e.toString().replaceFirst('Exception: ', '');
  //       });
  //     } finally {
  //       setState(() {
  //         _isLoading = false;
  //       });
  //     }
  //   }
  // }

  @override
  void initState() {
    super.initState();
    _fetchPasswordPolicy();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _fetchPasswordPolicy() async {
    setState(() {
      _isLoadingPolicy = true;
      _policyError = null;
    });
    try {
      _passwordPolicy = await PasswordPolicyService().getPasswordPolicy();
    } catch (e) {
      _policyError = e.toString();
      print('Error fetching password policy: $e');
    } finally {
      setState(() {
        _isLoadingPolicy = false;
      });
    }
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'กรุณากรอกรหัสผ่านใหม่';
    }
    if (_passwordPolicy == null) {
      return 'กำลังโหลดนโยบายรหัสผ่าน...';
    }

    if (value.length < _passwordPolicy!.minLength) {
      return 'รหัสผ่านต้องมีความยาวอย่างน้อย ${_passwordPolicy!.minLength} ตัวอักษร';
    }
    if (_passwordPolicy!.requireUppercase && !value.contains(RegExp(r'[A-Z]'))) {
      return 'ต้องมีตัวอักษรพิมพ์ใหญ่อย่างน้อย 1 ตัว';
    }
    if (_passwordPolicy!.requireLowercase && !value.contains(RegExp(r'[a-z]'))) {
      return 'ต้องมีตัวอักษรพิมพ์เล็กอย่างน้อย 1 ตัว';
    }
    if (_passwordPolicy!.requireDigits && !value.contains(RegExp(r'[0-9]'))) {
      return 'ต้องมีตัวเลขอย่างน้อย 1 ตัว';
    }
    if (_passwordPolicy!.requireSpecialChars && !value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      // สามารถกำหนด regex สำหรับอักขระพิเศษที่อนุญาตได้
      return 'ต้องมีตัวอักษรพิเศษอย่างน้อย 1 ตัว';
    }
    return null; // Valid
  }

  String? _validateConfirmNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'กรุณายืนยันรหัสผ่านใหม่';
    }
    if (value != _newPasswordController.text) {
      return 'รหัสผ่านใหม่และการยืนยันไม่ตรงกัน';
    }
    return null;
  }

  Future<void> _changePassword() async {
    if (_formKey.currentState!.validate()) {
      try {
        await AuthService().changePassword(
          userId: widget.userId,
          oldPassword: _currentPasswordController.text,
          newPassword: _newPasswordController.text,
          confirmNewPassword: _confirmPasswordController.text,
        );
        // AlertDialog(
        //   title: const Text('เปลี่ยนรหัสผ่านสำเร็จ'),
        //   content: const Text('คุณได้เปลี่ยนรหัสผ่านเรียบร้อยแล้ว'),
        //   actions: [
        //     TextButton(
        //       onPressed: () => Navigator.of(context).pop(), // ปิด dialog
        //       child: const Text('ตกลง'),
        //     ),
        //   ],
        // );
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('เปลี่ยนรหัสผ่านสำเร็จ')),
        // );
        if (widget.forceChange) {
          // ถ้าถูกบังคับเปลี่ยน ให้กลับไปหน้า Login หรือ Home (ถ้า Login ได้แล้ว)
          // Navigator.of(context).pop(); // ปิดหน้า Change Password
          // อาจจะต้องการ navigate ไปที่ home โดยตรง ถ้า login token ยังใช้ได้
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const HomeScreen()));
        } else {
          Navigator.of(context).pop(); // กลับไปหน้าเดิม
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('เปลี่ยนรหัสผ่าน'),
      content: 
        _isLoadingPolicy
          ? const Center(child: CircularProgressIndicator())
          : _policyError != null
            ? Center(child: Text('ไม่สามารถโหลดนโยบายรหัสผ่านได้: $_policyError'))
            : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.forceChange)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 20),
                                child: Text(
                                  'รหัสผ่านของคุณหมดอายุแล้ว กรุณาเปลี่ยนรหัสผ่านเพื่อดำเนินการต่อ',
                                  style: TextStyle(color: Colors.red, fontSize: 16),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            TextFormField(
                              controller: _currentPasswordController,
                              decoration: const InputDecoration(
                                labelText: 'รหัสผ่านปัจจุบัน',
                                border: OutlineInputBorder(),
                              ),
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'กรุณากรอกรหัสผ่านปัจจุบัน';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _newPasswordController,
                              decoration: const InputDecoration(
                                labelText: 'รหัสผ่านใหม่',
                                border: OutlineInputBorder(),
                                hintText: 'ตัวอย่าง: P@ssw0rd123 (8+ ตัว, พิมพ์ใหญ่, เล็ก, ตัวเลข, พิเศษ)',
                              ),
                              obscureText: true,
                              onChanged: (value) {
                                setState(() {
                                  // Rebuild เพื่ออัปเดต PasswordStrengthMeter
                                });
                              },
                              validator: _validateNewPassword,
                            ),
                            const SizedBox(height: 8),
                            PasswordStrengthMeter(
                              password: _newPasswordController.text,
                              policy: _passwordPolicy,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmPasswordController,
                              decoration: const InputDecoration(
                                labelText: 'ยืนยันรหัสผ่านใหม่',
                                border: OutlineInputBorder(),
                              ),
                              obscureText: true,
                              validator: _validateConfirmNewPassword,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _changePassword,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 15),
                              ),
                              child: const Text('บันทึกรหัสผ่าน'),
                            ),
                            !widget.forceChange 
                              ? const SizedBox(height: 8) 
                              : const SizedBox.shrink(),
                            !widget.forceChange 
                              ? ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(false), // ปิด dialog โดยไม่ทำอะไร
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                ),
                                child: const Text('ยกเลิก'),
                              )
                              : const SizedBox.shrink(),
                          ],
                        ),
                      ),
                    ),
                  ),
                // child: SingleChildScrollView(
                //   child: Form(
                //     key: _formKey,
                //     child: Column(
                //       mainAxisSize: MainAxisSize.min,
                //       children: [
                //         TextFormField(
                //           controller: _currentPasswordController,
                //           obscureText: true,
                //           decoration: const InputDecoration(labelText: 'รหัสผ่านปัจจุบัน'),
                //           validator: (value) {
                //             if (value == null || value.isEmpty) {
                //               return 'กรุณาป้อนรหัสผ่านปัจจุบัน';
                //             }
                //             return null;
                //           },
                //         ),
                //         TextFormField(
                //           controller: _newPasswordController,
                //           obscureText: true,
                //           decoration: const InputDecoration(labelText: 'รหัสผ่านใหม่'),
                //           validator: (value) {
                //             if (value == null || value.isEmpty) {
                //               return 'กรุณาป้อนรหัสผ่านใหม่';
                //             }
                //             if (value.length < 6) {
                //               return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                //             }
                //             return null;
                //           },
                //         ),
                //         TextFormField(
                //           controller: _confirmPasswordController,
                //           obscureText: true,
                //           decoration: const InputDecoration(labelText: 'ยืนยันรหัสผ่านใหม่'),
                //           validator: (value) {
                //             if (value == null || value.isEmpty) {
                //               return 'กรุณายืนยันรหัสผ่านใหม่';
                //             }
                //             if (value != _newPasswordController.text) {
                //               return 'รหัสผ่านไม่ตรงกัน';
                //             }
                //             return null;
                //           },
                //         ),
                //         if (_errorMessage != null)
                //           Padding(
                //             padding: const EdgeInsets.only(top: 10),
                //             child: Text(
                //               _errorMessage!,
                //               style: const TextStyle(color: Colors.red),
                //             ),
                //           ),
                //       ],
                //     ),
                //   ),
                // ),
              ),
      // actions: [
      //   TextButton(
      //     onPressed: () => Navigator.of(context).pop(false), // ปิด dialog โดยไม่ทำอะไร
      //     child: const Text('ยกเลิก'),
      //   ),
      //   _isLoading
      //       ? const CircularProgressIndicator()
      //       : ElevatedButton(
      //           onPressed: _submitChangePassword,
      //           child: const Text('บันทึก'),
      //         ),
      // ],
    );
  }

}