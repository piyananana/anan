// lib/screens/sa_password_policy_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/sa_menu_scope.dart';
import '../services/sa_password_policy_service.dart';
import '../services/sa_inactivity_service.dart';
import '../services/sa_language_provider.dart';
import '../models/sa_password_policy.dart';

class PasswordPolicyScreen extends StatefulWidget {
  const PasswordPolicyScreen({super.key});

  @override
  State<PasswordPolicyScreen> createState() => _PasswordPolicyScreenState();
}

class _PasswordPolicyScreenState extends State<PasswordPolicyScreen>
    with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();

  final _minLengthController        = TextEditingController();
  final _historyCountController     = TextEditingController();
  final _expiryDaysController       = TextEditingController();
  final _notificationDaysController = TextEditingController();
  final _sessionTimeoutController   = TextEditingController();

  bool _requireUppercase     = false;
  bool _requireLowercase     = false;
  bool _requireDigits        = false;
  bool _requireSpecialChars  = false;
  bool _forceChangeOnExpiry  = false;

  String _singleSessionMode = 'dialog';

  bool    _isLoading    = true;
  String? _errorMessage;

  @override
  bool get wantKeepAlive => true;

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
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final policy = await PasswordPolicyService().getPasswordPolicy();
      setState(() {
        _minLengthController.text        = policy.minLength.toString();
        _historyCountController.text     = policy.passwordHistoryCount.toString();
        _expiryDaysController.text       = policy.passwordExpiryDays.toString();
        _notificationDaysController.text = policy.passwordNotificationDays.toString();
        _sessionTimeoutController.text   = policy.sessionTimeoutMinutes.toString();
        _singleSessionMode    = policy.singleSessionMode;
        _requireUppercase     = policy.requireUppercase;
        _requireLowercase     = policy.requireLowercase;
        _requireDigits        = policy.requireDigits;
        _requireSpecialChars  = policy.requireSpecialChars;
        _forceChangeOnExpiry  = policy.forcePasswordChangeOnExpiry;
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePolicy() async {
    if (!_formKey.currentState!.validate()) return;
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    setState(() => _isLoading = true);
    try {
      final newPolicy = PasswordPolicy(
        minLength:                    int.parse(_minLengthController.text),
        requireUppercase:             _requireUppercase,
        requireLowercase:             _requireLowercase,
        requireDigits:                _requireDigits,
        requireSpecialChars:          _requireSpecialChars,
        passwordHistoryCount:         int.parse(_historyCountController.text),
        passwordExpiryDays:           int.parse(_expiryDaysController.text),
        passwordNotificationDays:     int.parse(_notificationDaysController.text),
        forcePasswordChangeOnExpiry:  _forceChangeOnExpiry,
        sessionTimeoutMinutes:        int.parse(_sessionTimeoutController.text),
        singleSessionMode:            _singleSessionMode,
      );
      await PasswordPolicyService().updatePasswordPolicy(newPolicy);
      InactivityService().configure(newPolicy.sessionTimeoutMinutes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish
                ? 'Password policy saved successfully'
                : 'บันทึกการตั้งค่ารหัสผ่านสำเร็จ')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish ? 'Save error: $e' : 'เกิดข้อผิดพลาดในการบันทึก: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;

    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.deepOrange[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: isEnglish ? 'Refresh' : 'รีเฟรชรายการ',
            onPressed: _fetchPasswordPolicy,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _savePolicy,
            tooltip: isEnglish ? 'Save Settings' : 'บันทึกการตั้งค่า',
          ),
        ],
      ),
      body: _isLoading && _errorMessage == null
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Password Length ──────────────────────────────
                        Text(
                          isEnglish ? 'Password Length' : 'ความยาวรหัสผ่าน',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _buildNumberField(
                          controller: _minLengthController,
                          label: isEnglish
                              ? 'Minimum Password Length (characters)'
                              : 'ความยาวรหัสผ่านขั้นต่ำ (ตัวอักษร)',
                          tooltip: isEnglish
                              ? 'Minimum number of characters required (1–128)'
                              : 'กำหนดจำนวนตัวอักษรขั้นต่ำของรหัสผ่าน (1-128)',
                          min: 1, max: 128,
                          isEnglish: isEnglish,
                        ),
                        const SizedBox(height: 24),
                        const Divider(),

                        // ── Password Complexity ──────────────────────────
                        Text(
                          isEnglish ? 'Password Complexity' : 'ความซับซ้อนของรหัสผ่าน',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        _buildCheckbox(
                          label: isEnglish ? 'Require uppercase letters' : 'ต้องมีตัวอักษรพิมพ์ใหญ่',
                          value: _requireUppercase,
                          onChanged: (v) => setState(() => _requireUppercase = v!),
                        ),
                        _buildCheckbox(
                          label: isEnglish ? 'Require lowercase letters' : 'ต้องมีตัวอักษรพิมพ์เล็ก',
                          value: _requireLowercase,
                          onChanged: (v) => setState(() => _requireLowercase = v!),
                        ),
                        _buildCheckbox(
                          label: isEnglish ? 'Require digits' : 'ต้องมีตัวเลข',
                          value: _requireDigits,
                          onChanged: (v) => setState(() => _requireDigits = v!),
                        ),
                        _buildCheckbox(
                          label: isEnglish ? 'Require special characters' : 'ต้องมีตัวอักษรพิเศษ',
                          value: _requireSpecialChars,
                          onChanged: (v) => setState(() => _requireSpecialChars = v!),
                        ),
                        const SizedBox(height: 24),
                        const Divider(),

                        // ── Password Change ──────────────────────────────
                        Text(
                          isEnglish ? 'Password Change' : 'การเปลี่ยนรหัสผ่าน',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _buildNumberField(
                          controller: _historyCountController,
                          label: isEnglish
                              ? 'Password must differ from last N passwords'
                              : 'รหัสผ่านต้องไม่ซ้ำกับจำนวนครั้งที่ผ่านมา',
                          tooltip: isEnglish
                              ? 'Number of previous passwords that cannot be reused (0–24)'
                              : 'กำหนดจำนวนครั้งของรหัสผ่านเก่าที่ไม่สามารถนำกลับมาใช้ได้ (0-24)',
                          min: 0, max: 24,
                          isEnglish: isEnglish,
                        ),
                        const SizedBox(height: 16),
                        _buildNumberField(
                          controller: _expiryDaysController,
                          label: isEnglish
                              ? 'Password Expiry (days)'
                              : 'อายุของรหัสผ่าน (วัน)',
                          tooltip: isEnglish
                              ? 'Number of days before password expires (1–3650)'
                              : 'กำหนดจำนวนวันก่อนที่รหัสผ่านจะหมดอายุ (1-3650)',
                          min: 1, max: 3650,
                          isEnglish: isEnglish,
                        ),
                        const SizedBox(height: 16),
                        _buildNumberField(
                          controller: _notificationDaysController,
                          label: isEnglish
                              ? 'Notification Period (days)'
                              : 'ระยะเวลาการแจ้งเตือน (วัน)',
                          tooltip: isEnglish
                              ? 'Days before expiry to start notifying the user (must be less than expiry)'
                              : 'กำหนดจำนวนวันที่ต้องแจ้งเตือนก่อนรหัสผ่านหมดอายุ (ต้องน้อยกว่าอายุรหัสผ่าน)',
                          min: 0,
                          isEnglish: isEnglish,
                          extraValidator: (v) {
                            final n = int.tryParse(v ?? '');
                            final expiry = int.tryParse(_expiryDaysController.text);
                            if (n != null && expiry != null && n >= expiry) {
                              return isEnglish
                                  ? 'Must be less than expiry ($expiry days)'
                                  : 'ต้องน้อยกว่าอายุรหัสผ่าน ($expiry วัน)';
                            }
                            return null;
                          },
                        ),
                        _buildCheckbox(
                          label: isEnglish
                              ? 'Force password change on expiry'
                              : 'บังคับเปลี่ยนรหัสผ่านเมื่อหมดอายุ',
                          value: _forceChangeOnExpiry,
                          onChanged: (v) => setState(() => _forceChangeOnExpiry = v!),
                        ),
                        const SizedBox(height: 24),
                        const Divider(),

                        // ── Session Security ─────────────────────────────
                        Text(
                          isEnglish ? 'Session Security' : 'ความปลอดภัยของ Session',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _buildNumberField(
                          controller: _sessionTimeoutController,
                          label: isEnglish
                              ? 'Auto-timeout on inactivity (minutes)'
                              : 'หมดเวลาอัตโนมัติเมื่อไม่มีการใช้งาน (นาที)',
                          tooltip: isEnglish
                              ? 'Auto-logout after this many idle minutes (1–600)'
                              : 'ระบบจะออกจากระบบอัตโนมัติเมื่อไม่มีการใช้งานตามเวลาที่กำหนด (1-600 นาที)',
                          min: 1, max: 600,
                          isEnglish: isEnglish,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          isEnglish
                              ? 'Concurrent Login Policy (Single Session)'
                              : 'นโยบาย Login พร้อมกัน (Single Session)',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isEnglish
                              ? 'Each user may be logged in from only one device at a time.'
                              : 'ผู้ใช้สามารถ Login ได้เพียง 1 เครื่องในเวลาเดียวกัน',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        RadioListTile<String>(
                          value: 'dialog',
                          groupValue: _singleSessionMode,
                          title: Text(isEnglish ? 'Show dialog to choose' : 'แสดง Dialog ให้เลือก'),
                          subtitle: Text(
                            isEnglish
                                ? 'New device will ask whether to logout the old one (Recommended)'
                                : 'เครื่องใหม่จะถามว่าต้องการ Logout เครื่องเก่าหรือไม่ (แนะนำ)',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onChanged: (v) => setState(() => _singleSessionMode = v!),
                          dense: true,
                        ),
                        RadioListTile<String>(
                          value: 'force',
                          groupValue: _singleSessionMode,
                          title: Text(isEnglish ? 'Force logout old device immediately' : 'Logout เครื่องเก่าทันที'),
                          subtitle: Text(
                            isEnglish
                                ? 'Old device is logged out automatically when a new device logs in'
                                : 'เมื่อ Login จากเครื่องใหม่ เครื่องเก่าจะถูก Logout อัตโนมัติโดยไม่ถาม',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onChanged: (v) => setState(() => _singleSessionMode = v!),
                          dense: true,
                        ),
                        const SizedBox(height: 24),
                        const Divider(),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _savePolicy,
                          icon: const Icon(Icons.save),
                          label: Text(isEnglish ? 'Save Settings' : 'บันทึกการตั้งค่า'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(150, 50),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String tooltip,
    required bool isEnglish,
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
        if (value == null || value.isEmpty) {
          return isEnglish ? 'Please enter a value' : 'กรุณากรอกข้อมูล';
        }
        final n = int.tryParse(value);
        if (n == null) {
          return isEnglish ? 'Must be a number' : 'กรุณากรอกเป็นตัวเลขเท่านั้น';
        }
        if (min != null && n < min) {
          return isEnglish ? 'Must be at least $min' : 'ต้องไม่น้อยกว่า $min';
        }
        if (max != null && n > max) {
          return isEnglish ? 'Must be at most $max' : 'ต้องไม่มากกว่า $max';
        }
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
