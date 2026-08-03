import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/services/sa_language_provider.dart';
import '../models/ap_payment_run_running.dart';
import '../services/ap_payment_run_running_service.dart';

class ApPaymentRunRunningScreen extends StatefulWidget {
  const ApPaymentRunRunningScreen({super.key});

  @override
  State<ApPaymentRunRunningScreen> createState() => _ApPaymentRunRunningScreenState();
}

class _ApPaymentRunRunningScreenState extends State<ApPaymentRunRunningScreen> {
  final _service = ApPaymentRunRunningService();

  bool _isEnglish = false;

  ApPaymentRunRunning? _config;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMsg;
  String? _successMsg;

  final _prefixCtrl = TextEditingController();
  final _separatorCtrl = TextEditingController();
  final _nextNumberCtrl = TextEditingController();

  bool _isAutoNumbering = true;
  String _formatSuffixDate = 'YYYYMM';
  int _runningLength = 4;

  List<MapEntry<String, String>> _suffixOptions(bool isEnglish) => [
    MapEntry('', isEnglish ? 'No date' : 'ไม่ใช้วันที่'),
    MapEntry('YY', isEnglish ? 'YY — 2-digit year (e.g. 68)' : 'YY — ปี 2 หลัก (เช่น 68)'),
    MapEntry('YYYY', isEnglish ? 'YYYY — 4-digit year (e.g. 2568)' : 'YYYY — ปี 4 หลัก (เช่น 2568)'),
    MapEntry('YYMM', isEnglish ? 'YYMM — 2-digit year-month (e.g. 6803)' : 'YYMM — ปี-เดือน 2 หลัก (เช่น 6803)'),
    MapEntry('YYYYMM', isEnglish ? 'YYYYMM — 4-digit year-month (e.g. 256803)' : 'YYYYMM — ปี-เดือน 4 หลัก (เช่น 256803)'),
    MapEntry('YYMMDD', isEnglish ? 'YYMMDD — year-month-day (e.g. 680317)' : 'YYMMDD — ปี-เดือน-วัน (เช่น 680317)'),
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

  void _applyConfig(ApPaymentRunRunning config) {
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
    final isEnglish = _isEnglish;
    setState(() {
      _isSaving = true;
      _errorMsg = null;
      _successMsg = null;
    });
    try {
      final nextNum = int.tryParse(_nextNumberCtrl.text);
      if (_isAutoNumbering && nextNum == null) {
        setState(() => _errorMsg = isEnglish ? 'Please enter a valid next running number' : 'กรุณาระบุเลขรันถัดไปให้ถูกต้อง');
        return;
      }
      final toSave = ApPaymentRunRunning(
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
        _successMsg = isEnglish ? 'Settings saved successfully' : 'บันทึกการตั้งค่าเรียบร้อยแล้ว';
      });
    } catch (e) {
      setState(() => _errorMsg = e.toString());
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: isEnglish ? 'Refresh' : 'รีเฟรชรายการ',
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.info_outline, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                isEnglish ? 'Payment Approval Note Auto-Numbering Settings' : 'การตั้งค่าเลขที่ใบอนุมัติจ่ายอัตโนมัติ',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.blue),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            Text(
                              isEnglish
                                  ? 'When enabled, the system will automatically assign a payment approval note number based on the format below.'
                                  : 'เมื่อเปิดใช้งาน ระบบจะออกเลขที่ใบอนุมัติจ่ายให้อัตโนมัติตามรูปแบบที่กำหนด',
                              style: const TextStyle(color: Colors.blue),
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
                              Text(isEnglish ? 'Settings' : 'การตั้งค่า',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold)),
                              const Divider(height: 24),

                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(isEnglish ? 'Use auto payment approval note numbering' : 'ใช้เลขที่ใบอนุมัติจ่ายอัตโนมัติ',
                                    style:
                                        const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(_isAutoNumbering
                                    ? (isEnglish ? 'Enabled — the system will assign a number when a new payment approval note is created' : 'เปิดใช้งาน — ระบบจะออกเลขที่ให้เมื่อสร้างใบอนุมัติจ่ายใหม่')
                                    : (isEnglish ? 'Disabled — falls back to the default PR-YYYYMMDD-NNN format' : 'ปิดใช้งาน — จะใช้รูปแบบเดิม PR-YYYYMMDD-NNN แทน')),
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
                                      label: isEnglish ? 'Prefix' : 'คำนำหน้า (Prefix)',
                                      child: TextFormField(
                                        controller: _prefixCtrl,
                                        decoration: InputDecoration(
                                          hintText: isEnglish ? 'e.g. PR' : 'เช่น PR',
                                          border: const OutlineInputBorder(),
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
                                      label: isEnglish ? 'Separator' : 'ตัวคั่น (Separator)',
                                      child: TextFormField(
                                        controller: _separatorCtrl,
                                        decoration: InputDecoration(
                                          hintText: isEnglish ? 'e.g. - / or blank' : 'เช่น - / หรือว่าง',
                                          border: const OutlineInputBorder(),
                                          counterText: '',
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 16),

                                _LabeledField(
                                  label: isEnglish ? 'Date Suffix' : 'ส่วนท้ายวันที่ (Date Suffix)',
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    value: _formatSuffixDate,
                                    decoration: const InputDecoration(
                                        border: OutlineInputBorder()),
                                    items: _suffixOptions(isEnglish)
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
                                      label: isEnglish ? 'Running Number Length' : 'ความยาวเลขรัน',
                                      child: DropdownButtonFormField<int>(
                                        isExpanded: true,
                                        value: _runningLength,
                                        decoration: const InputDecoration(
                                            border: OutlineInputBorder()),
                                        items: [3, 4, 5, 6]
                                            .map((n) => DropdownMenuItem(
                                                value: n,
                                                child: Text(isEnglish ? '$n digits' : '$n หลัก')))
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
                                      label: isEnglish ? 'Next Running Number' : 'เลขรันถัดไป',
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

                      // ── Card: ตัวอย่างเลขที่ ──────────────────────────────
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
                                Text(isEnglish ? 'Sample generated number' : 'ตัวอย่างเลขที่ที่จะออก',
                                    style: const TextStyle(
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
                                  isEnglish
                                      ? 'Format: ${_prefixCtrl.text}${_formatSuffixDate.isNotEmpty ? '<$_formatSuffixDate>' : ''}${_separatorCtrl.text}<running number, $_runningLength digits>'
                                      : 'รูปแบบ: ${_prefixCtrl.text}${_formatSuffixDate.isNotEmpty ? '<$_formatSuffixDate>' : ''}${_separatorCtrl.text}<เลขรัน $_runningLength หลัก>',
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
                          onPressed: (_isSaving || !(MenuScope.of(context)?.canEdit ?? true))
                              ? null
                              : _save,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save),
                          label: Text(
                              _isSaving ? (isEnglish ? 'Saving...' : 'กำลังบันทึก...') : (isEnglish ? 'Save Settings' : 'บันทึกการตั้งค่า')),
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
