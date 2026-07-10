import 'package:flutter/material.dart';
import '../../sa/utils/menu_scope.dart';
import '../models/ap_vendor_running.dart';
import '../services/ap_vendor_running_service.dart';

class ApVendorRunningScreen extends StatefulWidget {
  const ApVendorRunningScreen({super.key});

  @override
  State<ApVendorRunningScreen> createState() => _ApVendorRunningScreenState();
}

class _ApVendorRunningScreenState extends State<ApVendorRunningScreen> {
  final _service = ApVendorRunningService();

  ApVendorRunning? _config;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMsg;
  String? _successMsg;

  final _prefixCtrl = TextEditingController();
  final _separatorCtrl = TextEditingController();
  final _nextNumberCtrl = TextEditingController();

  bool _isAutoNumbering = false;
  String _formatSuffixDate = '';
  int _runningLength = 4;

  static const _suffixOptions = [
    MapEntry('', 'ไม่ใช้วันที่'),
    MapEntry('YY', 'YY — ปี 2 หลัก (เช่น 68)'),
    MapEntry('YYYY', 'YYYY — ปี 4 หลัก (เช่น 2568)'),
    MapEntry('YYMM', 'YYMM — ปี-เดือน 2 หลัก (เช่น 6803)'),
    MapEntry('YYYYMM', 'YYYYMM — ปี-เดือน 4 หลัก (เช่น 256803)'),
    MapEntry('YYMMDD', 'YYMMDD — ปี-เดือน-วัน (เช่น 680317)'),
  ];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _prefixCtrl.dispose();
    _separatorCtrl.dispose();
    _nextNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    try {
      final config = await _service.fetchConfig();
      _applyConfig(config);
      setState(() => _config = config);
    } catch (e) {
      setState(() => _errorMsg = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyConfig(ApVendorRunning config) {
    _isAutoNumbering = config.isAutoNumbering;
    _prefixCtrl.text = config.formatPrefix;
    _separatorCtrl.text = config.formatSeparator;
    _formatSuffixDate = config.formatSuffixDate;
    _runningLength = config.runningLength;
    _nextNumberCtrl.text = config.nextRunningNumber.toString();
  }

  String get _sampleCode {
    String code = _prefixCtrl.text;
    if (_formatSuffixDate.isNotEmpty) {
      final now = DateTime.now();
      final year = now.year.toString();
      final month = now.month.toString().padLeft(2, '0');
      final day = now.day.toString().padLeft(2, '0');
      switch (_formatSuffixDate) {
        case 'YY':
          code += year.substring(2);
          break;
        case 'YYYY':
          code += year;
          break;
        case 'YYMM':
          code += year.substring(2) + month;
          break;
        case 'YYYYMM':
          code += year + month;
          break;
        case 'YYMMDD':
          code += year.substring(2) + month + day;
          break;
      }
    }
    code += _separatorCtrl.text;
    final num = int.tryParse(_nextNumberCtrl.text) ?? 1;
    code += num.toString().padLeft(_runningLength, '0');
    return code;
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorMsg = null;
      _successMsg = null;
    });
    try {
      final nextNum = int.tryParse(_nextNumberCtrl.text);
      if (_isAutoNumbering && nextNum == null) {
        setState(() => _errorMsg = 'กรุณาระบุเลขรันถัดไปให้ถูกต้อง');
        return;
      }
      final toSave = ApVendorRunning(
        id: _config?.id,
        isAutoNumbering: _isAutoNumbering,
        formatPrefix: _prefixCtrl.text.trim().toUpperCase(),
        formatSeparator: _separatorCtrl.text,
        formatSuffixDate: _formatSuffixDate,
        runningLength: _runningLength,
        nextRunningNumber: nextNum ?? 1,
      );
      final saved = await _service.saveConfig(toSave);
      setState(() {
        _config = saved;
        _successMsg = 'บันทึกการตั้งค่าเรียบร้อยแล้ว';
      });
    } catch (e) {
      setState(() => _errorMsg = e.toString());
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรชรายการ',
            onPressed: _loadConfig,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Banner ────────────────────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.info_outline, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'การตั้งค่ารหัสเจ้าหนี้อัตโนมัติ',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.blue),
                              ),
                            ]),
                            SizedBox(height: 8),
                            Text(
                              'เมื่อเปิดใช้งาน ระบบจะออกรหัสเจ้าหนี้ให้อัตโนมัติตามรูปแบบที่กำหนด'
                              ' ผู้ใช้ยังสามารถแก้ไขรหัสเองได้ในหน้าเพิ่มข้อมูลเจ้าหนี้',
                              style: TextStyle(color: Colors.blue),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Alerts ────────────────────────────────────────────
                      if (_errorMsg != null)
                        _Alert(
                          message: _errorMsg!,
                          color: Colors.red,
                          icon: Icons.error,
                          onClose: () => setState(() => _errorMsg = null),
                        ),
                      if (_successMsg != null)
                        _Alert(
                          message: _successMsg!,
                          color: Colors.green,
                          icon: Icons.check_circle,
                          onClose: () => setState(() => _successMsg = null),
                        ),

                      // ── Card: การตั้งค่า ─────────────────────────────────
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('การตั้งค่า',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold)),
                              const Divider(height: 24),

                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('ใช้รหัสเจ้าหนี้อัตโนมัติ',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(_isAutoNumbering
                                    ? 'เปิดใช้งาน — ระบบจะออกรหัสให้เมื่อเพิ่มเจ้าหนี้ใหม่'
                                    : 'ปิดใช้งาน — ต้องระบุรหัสเจ้าหนี้เอง'),
                                value: _isAutoNumbering,
                                activeColor: Colors.blue[700],
                                onChanged: (v) =>
                                    setState(() => _isAutoNumbering = v),
                              ),

                              if (_isAutoNumbering) ...[
                                const SizedBox(height: 20),
                                const Divider(),
                                const SizedBox(height: 16),

                                Row(children: [
                                  Expanded(
                                    flex: 3,
                                    child: _LabeledField(
                                      label: 'คำนำหน้า (Prefix)',
                                      child: TextFormField(
                                        controller: _prefixCtrl,
                                        decoration: const InputDecoration(
                                          hintText: 'เช่น VEND, AP',
                                          border: OutlineInputBorder(),
                                          counterText: '',
                                        ),
                                        textCapitalization:
                                            TextCapitalization.characters,
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 2,
                                    child: _LabeledField(
                                      label: 'ตัวคั่น (Separator)',
                                      child: TextFormField(
                                        controller: _separatorCtrl,
                                        decoration: const InputDecoration(
                                          hintText: 'เช่น - / หรือว่าง',
                                          border: OutlineInputBorder(),
                                          counterText: '',
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 16),

                                _LabeledField(
                                  label: 'ส่วนท้ายวันที่ (Date Suffix)',
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    value: _formatSuffixDate,
                                    decoration: const InputDecoration(
                                        border: OutlineInputBorder()),
                                    items: _suffixOptions
                                        .map((e) => DropdownMenuItem(
                                            value: e.key,
                                            child: Text(e.value)))
                                        .toList(),
                                    onChanged: (v) => setState(
                                        () => _formatSuffixDate = v ?? ''),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                Row(children: [
                                  Expanded(
                                    flex: 2,
                                    child: _LabeledField(
                                      label: 'ความยาวเลขรัน',
                                      child: DropdownButtonFormField<int>(
                                        isExpanded: true,
                                        value: _runningLength,
                                        decoration: const InputDecoration(
                                            border: OutlineInputBorder()),
                                        items: [3, 4, 5, 6]
                                            .map((n) => DropdownMenuItem(
                                                value: n,
                                                child: Text('$n หลัก')))
                                            .toList(),
                                        onChanged: (v) => setState(
                                            () => _runningLength = v ?? 4),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 3,
                                    child: _LabeledField(
                                      label: 'เลขรันถัดไป',
                                      child: TextFormField(
                                        controller: _nextNumberCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          hintText: '1',
                                          border: OutlineInputBorder(),
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ),
                                ]),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // ── Card: ตัวอย่างรหัส ──────────────────────────────
                      if (_isAutoNumbering) ...[
                        const SizedBox(height: 16),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('ตัวอย่างรหัสที่จะออก',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                                const Divider(height: 24),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.blue.shade200),
                                  ),
                                  child: Text(
                                    _sampleCode,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[700],
                                        letterSpacing: 2),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'รูปแบบ: ${_prefixCtrl.text}${_formatSuffixDate.isNotEmpty ? '<$_formatSuffixDate>' : ''}${_separatorCtrl.text}<เลขรัน $_runningLength หลัก>',
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // ── Save Button ───────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save),
                          label: Text(
                              _isSaving ? 'กำลังบันทึก...' : 'บันทึกการตั้งค่า'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
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
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _Alert extends StatelessWidget {
  final String message;
  final Color color;
  final IconData icon;
  final VoidCallback onClose;

  const _Alert(
      {required this.message,
      required this.color,
      required this.icon,
      required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: color))),
          IconButton(
              icon: Icon(Icons.close, size: 16, color: color),
              onPressed: onClose),
        ],
      ),
    );
  }
}
