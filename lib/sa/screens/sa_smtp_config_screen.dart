// lib/sa/screens/sa_smtp_config_screen.dart
import 'package:flutter/material.dart';
import '../models/sa_smtp_config.dart';
import '../services/sa_smtp_config_service.dart';

class SaSmtpConfigScreen extends StatefulWidget {
  const SaSmtpConfigScreen({super.key});

  @override
  State<SaSmtpConfigScreen> createState() => _SaSmtpConfigScreenState();
}

class _SaSmtpConfigScreenState extends State<SaSmtpConfigScreen>
    with AutomaticKeepAliveClientMixin {
  final _svc = SaSmtpConfigService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _hostCtrl;
  late TextEditingController _portCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _passwordCtrl;
  late TextEditingController _fromEmailCtrl;
  late TextEditingController _fromNameCtrl;
  bool _useTls = true;
  bool _isActive = true;
  bool _obscurePassword = true;
  bool _loading = true;
  bool _isSaving = false;
  SaSmtpConfig? _config;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _hostCtrl      = TextEditingController();
    _portCtrl      = TextEditingController(text: '587');
    _usernameCtrl  = TextEditingController();
    _passwordCtrl  = TextEditingController();
    _fromEmailCtrl = TextEditingController();
    _fromNameCtrl  = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _fromEmailCtrl.dispose();
    _fromNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final cfg = await _svc.getConfig();
      if (mounted) {
        setState(() {
          _config = cfg;
          if (cfg != null) {
            _hostCtrl.text      = cfg.host;
            _portCtrl.text      = cfg.port.toString();
            _usernameCtrl.text  = cfg.username ?? '';
            _fromEmailCtrl.text = cfg.fromEmail ?? '';
            _fromNameCtrl.text  = cfg.fromName ?? '';
            _useTls   = cfg.useTls;
            _isActive = cfg.isActive;
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('โหลดข้อมูลล้มเหลว: $e'),
                backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final cfg = SaSmtpConfig(
        id: _config?.id,
        host: _hostCtrl.text.trim(),
        port: int.tryParse(_portCtrl.text) ?? 587,
        username: _usernameCtrl.text.trim().isEmpty ? null : _usernameCtrl.text.trim(),
        fromEmail: _fromEmailCtrl.text.trim().isEmpty ? null : _fromEmailCtrl.text.trim(),
        fromName: _fromNameCtrl.text.trim().isEmpty ? null : _fromNameCtrl.text.trim(),
        useTls: _useTls,
        isActive: _isActive,
      );
      final newPassword = _passwordCtrl.text.isNotEmpty ? _passwordCtrl.text : null;
      final saved = await _svc.upsertConfig(cfg, newPassword: newPassword);
      if (mounted) {
        setState(() {
          _config = saved;
          _passwordCtrl.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('บันทึกสำเร็จ'),
                backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('เกิดข้อผิดพลาด: $e'),
                backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.email_outlined, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text('ตั้งค่า SMTP (อีเมล)'),
        ]),
        backgroundColor: Colors.blueGrey[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'รีเฟรช',
              onPressed: _loading ? null : _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Server settings ──────────────────────────────────
                      _sectionHeader('การตั้งค่าเซิร์ฟเวอร์', Icons.dns_outlined),
                      const SizedBox(height: 12),
                      Row(children: [
                        Flexible(
                          flex: 3,
                          child: TextFormField(
                            controller: _hostCtrl,
                            decoration: const InputDecoration(
                              labelText: 'SMTP Host *',
                              hintText: 'smtp.gmail.com',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'กรุณาป้อน SMTP Host'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          flex: 1,
                          child: TextFormField(
                            controller: _portCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Port *',
                              hintText: '587',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'ระบุ Port';
                              if (int.tryParse(v) == null) return 'ต้องเป็นตัวเลข';
                              return null;
                            },
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),

                      // ── Auth settings ────────────────────────────────────
                      _sectionHeader('การตรวจสอบสิทธิ์', Icons.lock_outlined),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            controller: _usernameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Username (Email)',
                              hintText: 'sender@example.com',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _passwordCtrl,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: _config != null
                                  ? 'Password (เว้นว่างเพื่อคงรหัสเดิม)'
                                  : 'Password',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),

                      // ── Sender info ──────────────────────────────────────
                      _sectionHeader('ข้อมูลผู้ส่ง', Icons.person_outlined),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            controller: _fromEmailCtrl,
                            decoration: const InputDecoration(
                              labelText: 'From Email',
                              hintText: 'noreply@company.com',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _fromNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'From Name',
                              hintText: 'บริษัท ตัวอย่าง จำกัด',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),

                      // ── Options ──────────────────────────────────────────
                      _sectionHeader('ตัวเลือก', Icons.settings_outlined),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: SwitchListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                              side: BorderSide(color: Colors.grey.shade400),
                            ),
                            title: const Text('ใช้ TLS/STARTTLS'),
                            subtitle: const Text('แนะนำให้เปิดใช้งาน'),
                            value: _useTls,
                            onChanged: (v) => setState(() => _useTls = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SwitchListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                              side: BorderSide(color: Colors.grey.shade400),
                            ),
                            title: const Text('สถานะ'),
                            subtitle: Text(_isActive ? 'ใช้งาน' : 'หยุดใช้'),
                            value: _isActive,
                            onChanged: (v) => setState(() => _isActive = v),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 24),

                      // ── Save button ──────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save),
                          label: Text(_isSaving ? 'กำลังบันทึก...' : 'บันทึกการตั้งค่า'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 18, color: Colors.blueGrey[700]),
      const SizedBox(width: 6),
      Text(title,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey[800],
              fontSize: 14)),
      const SizedBox(width: 8),
      Expanded(child: Divider(color: Colors.blueGrey.shade200)),
    ]);
  }
}
