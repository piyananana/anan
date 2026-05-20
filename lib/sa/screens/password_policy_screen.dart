// lib/screens/sa_password_policy_screen.dart

import 'package:flutter/material.dart';
import '../services/password_policy_service.dart';
import '../services/inactivity_service.dart';
import '../models/password_policy.dart';

class PasswordPolicyScreen extends StatefulWidget {
  const PasswordPolicyScreen({super.key});

  @override
  State<PasswordPolicyScreen> createState() => _PasswordPolicyScreenState();
}

class _PasswordPolicyScreenState extends State<PasswordPolicyScreen> with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  
  // Text controllers for number fields
  final _minLengthController = TextEditingController();
  final _historyCountController = TextEditingController();
  final _expiryDaysController = TextEditingController();
  final _notificationDaysController = TextEditingController();
  final _sessionTimeoutController = TextEditingController();

  // Checkbox states
  bool _requireUppercase = false;
  bool _requireLowercase = false;
  bool _requireDigits = false;
  bool _requireSpecialChars = false;
  bool _forceChangeOnExpiry = false;

  String _singleSessionMode = 'dialog'; // 'dialog' | 'force'

  bool _isLoading = true;
  String? _errorMessage;

  @override
  bool get wantKeepAlive => true; // ต้อง return true เพื่อให้เก็บสถานะ

  @override
  void initState() {
    super.initState();
    _fetchPasswordPolicy();
  }

  @override
  void dispose() {
    _minLengthController.dispose();
    _historyCountController.dispose();
    _expiryDaysController.dispose();
    _notificationDaysController.dispose();
    _sessionTimeoutController.dispose();
    super.dispose();
  }

  Future<void> _fetchPasswordPolicy() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final policy = await PasswordPolicyService().getPasswordPolicy();
      setState(() {
        _minLengthController.text = policy.minLength.toString();
        _historyCountController.text = policy.passwordHistoryCount.toString();
        _expiryDaysController.text = policy.passwordExpiryDays.toString();
        _notificationDaysController.text = policy.passwordNotificationDays.toString();
        _sessionTimeoutController.text = policy.sessionTimeoutMinutes.toString();
        _singleSessionMode = policy.singleSessionMode;
        _requireUppercase = policy.requireUppercase;
        _requireLowercase = policy.requireLowercase;
        _requireDigits = policy.requireDigits;
        _requireSpecialChars = policy.requireSpecialChars;
        _forceChangeOnExpiry = policy.forcePasswordChangeOnExpiry;
      });
    } catch (e) {
      print('Error during fetching password policy: $e');
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _savePolicy() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        final newPolicy = PasswordPolicy(
          minLength: int.parse(_minLengthController.text),
          requireUppercase: _requireUppercase,
          requireLowercase: _requireLowercase,
          requireDigits: _requireDigits,
          requireSpecialChars: _requireSpecialChars,
          passwordHistoryCount: int.parse(_historyCountController.text),
          passwordExpiryDays: int.parse(_expiryDaysController.text),
          passwordNotificationDays: int.parse(_notificationDaysController.text),
          forcePasswordChangeOnExpiry: _forceChangeOnExpiry,
          sessionTimeoutMinutes: int.parse(_sessionTimeoutController.text),
          singleSessionMode: _singleSessionMode,
        );

        await PasswordPolicyService().updatePasswordPolicy(newPolicy);
        // Reload InactivityService ทันทีโดยไม่ต้อง login ใหม่
        InactivityService().configure(newPolicy.sessionTimeoutMinutes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('บันทึกการตั้งค่ารหัสผ่านสำเร็จ')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึก: ${e.toString()}')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ต้องเรียก super.build(context)

    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      appBar: AppBar(
        title: const Row(children: [Icon(Icons.lock, color: Colors.white, size: 20), SizedBox(width: 8), Text('ตั้งค่าความปลอดภัยรหัสผ่าน')]),
        backgroundColor: Colors.deepOrange[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรชรายการ',
            onPressed: _fetchPasswordPolicy,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _savePolicy,
            tooltip: 'บันทึกการตั้งค่า',
          ),
        ],
      ),
      body: _isLoading && _errorMessage == null
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  // child: ConstrainedBox(
                  //   constraints: const BoxConstraints(maxWidth: 600),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ความยาวรหัสผ่าน',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          _buildNumberField(
                            controller: _minLengthController,
                            label: 'ความยาวรหัสผ่านขั้นต่ำ (ตัวอักษร)',
                            tooltip: 'กำหนดจำนวนตัวอักษรขั้นต่ำของรหัสผ่าน (1-128)',
                            min: 1, max: 128,
                          ),
                          const SizedBox(height: 24),
                          const Divider(),
                          const Text(
                            'ความซับซ้อนของรหัสผ่าน',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          _buildCheckbox(
                            label: 'ต้องมีตัวอักษรพิมพ์ใหญ่',
                            value: _requireUppercase,
                            onChanged: (value) => setState(() => _requireUppercase = value!),
                          ),
                          _buildCheckbox(
                            label: 'ต้องมีตัวอักษรพิมพ์เล็ก',
                            value: _requireLowercase,
                            onChanged: (value) => setState(() => _requireLowercase = value!),
                          ),
                          _buildCheckbox(
                            label: 'ต้องมีตัวเลข',
                            value: _requireDigits,
                            onChanged: (value) => setState(() => _requireDigits = value!),
                          ),
                          _buildCheckbox(
                            label: 'ต้องมีตัวอักษรพิเศษ',
                            value: _requireSpecialChars,
                            onChanged: (value) => setState(() => _requireSpecialChars = value!),
                          ),
                          const SizedBox(height: 24),
                          const Divider(),
                          const Text(
                            'การเปลี่ยนรหัสผ่าน',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          _buildNumberField(
                            controller: _historyCountController,
                            label: 'รหัสผ่านต้องไม่ซ้ำกับจำนวนครั้งที่ผ่านมา',
                            tooltip: 'กำหนดจำนวนครั้งของรหัสผ่านเก่าที่ไม่สามารถนำกลับมาใช้ได้ (0-24)',
                            min: 0, max: 24,
                          ),
                          const SizedBox(height: 16),
                          _buildNumberField(
                            controller: _expiryDaysController,
                            label: 'อายุของรหัสผ่าน (วัน)',
                            tooltip: 'กำหนดจำนวนวันก่อนที่รหัสผ่านจะหมดอายุ (1-3650)',
                            min: 1, max: 3650,
                          ),
                          const SizedBox(height: 16),
                          _buildNumberField(
                            controller: _notificationDaysController,
                            label: 'ระยะเวลาการแจ้งเตือน (วัน)',
                            tooltip: 'กำหนดจำนวนวันที่ต้องแจ้งเตือนก่อนรหัสผ่านหมดอายุ (ต้องน้อยกว่าอายุรหัสผ่าน)',
                            min: 0,
                            extraValidator: (v) {
                              final n = int.tryParse(v ?? '');
                              final expiry = int.tryParse(_expiryDaysController.text);
                              if (n != null && expiry != null && n >= expiry) {
                                return 'ต้องน้อยกว่าอายุรหัสผ่าน ($expiry วัน)';
                              }
                              return null;
                            },
                          ),
                          // const SizedBox(height: 8),
                          _buildCheckbox(
                            label: 'บังคับเปลี่ยนรหัสผ่านเมื่อหมดอายุ',
                            value: _forceChangeOnExpiry,
                            onChanged: (value) => setState(() => _forceChangeOnExpiry = value!),
                          ),
                          const SizedBox(height: 24),
                          const Divider(),
                          const Text(
                            'ความปลอดภัยของ Session',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          _buildNumberField(
                            controller: _sessionTimeoutController,
                            label: 'หมดเวลาอัตโนมัติเมื่อไม่มีการใช้งาน (นาที)',
                            tooltip: 'ระบบจะออกจากระบบอัตโนมัติเมื่อไม่มีการใช้งานตามเวลาที่กำหนด (1-600 นาที)',
                            min: 1,
                            max: 600,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'นโยบาย Login พร้อมกัน (Single Session)',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ผู้ใช้สามารถ Login ได้เพียง 1 เครื่องในเวลาเดียวกัน',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          RadioListTile<String>(
                            value: 'dialog',
                            groupValue: _singleSessionMode,
                            title: const Text('แสดง Dialog ให้เลือก'),
                            subtitle: const Text(
                              'เครื่องใหม่จะถามว่าต้องการ Logout เครื่องเก่าหรือไม่ (แนะนำ)',
                              style: TextStyle(fontSize: 12),
                            ),
                            onChanged: (v) => setState(() => _singleSessionMode = v!),
                            dense: true,
                          ),
                          RadioListTile<String>(
                            value: 'force',
                            groupValue: _singleSessionMode,
                            title: const Text('Logout เครื่องเก่าทันที'),
                            subtitle: const Text(
                              'เมื่อ Login จากเครื่องใหม่ เครื่องเก่าจะถูก Logout อัตโนมัติโดยไม่ถาม',
                              style: TextStyle(fontSize: 12),
                            ),
                            onChanged: (v) => setState(() => _singleSessionMode = v!),
                            dense: true,
                          ),
                          const SizedBox(height: 24),
                          const Divider(),
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _savePolicy,
                            icon: const Icon(Icons.save),
                            label: const Text('บันทึกการตั้งค่า'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(150, 50),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // ),
                ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String tooltip,
    int? min,
    int? max,
    String? Function(String?)? extraValidator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: Tooltip(
          message: tooltip,
          child: const Icon(Icons.info_outline),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'กรุณากรอกข้อมูล';
        final n = int.tryParse(value);
        if (n == null) return 'กรุณากรอกเป็นตัวเลขเท่านั้น';
        if (min != null && n < min) return 'ต้องไม่น้อยกว่า $min';
        if (max != null && n > max) return 'ต้องไม่มากกว่า $max';
        return extraValidator?.call(value);
      },
    );
  }

  Widget _buildCheckbox({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return CheckboxListTile(
      title: Text(label),
      value: value,
      onChanged: onChanged,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
    );
  }
}