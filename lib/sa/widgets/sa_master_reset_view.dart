import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../services/sa_auth_service.dart';
import '../services/sa_language_provider.dart';
import '../utils/sa_app_l10n.dart';
import '../utils/sa_menu_scope.dart';

/// ตัวเลือกหนึ่งรายการบนหน้าจอล้างข้อมูลหลักรายโมดูล — [bodyKey] คือชื่อ flag ที่ส่งไป backend
class MasterResetOption {
  final String bodyKey;
  final IconData icon;
  final Color color;
  final String titleTh;
  final String titleEn;

  /// บรรทัดย่อยใต้หัวข้อ (มักเป็นจำนวนแถว) — ได้ counts ล่าสุดจาก backend
  final String Function(Map<String, dynamic>? counts, bool isEnglish) subtitle;

  /// คำอธิบายที่แสดงเมื่อเลือก — (ไทย, อังกฤษ)
  final List<(String, String)> details;

  const MasterResetOption({
    required this.bodyKey,
    required this.icon,
    required this.color,
    required this.titleTh,
    required this.titleEn,
    required this.subtitle,
    this.details = const [],
  });
}

/// หน้าจอล้างข้อมูลหลัก/การตั้งค่าของโมดูล (ผู้พัฒนาระบบเท่านั้น)
/// ธุรกรรมล้างที่หน้าจอ "ล้างธุรกรรมทุกโมดูล" (SaSystemResetScreen) — backend ตอบ transactions_total
/// ถ้ายังมีธุรกรรมค้าง หน้าจอนี้จะปิดตัวเลือกทั้งหมด
class MasterResetView extends StatefulWidget {
  final String countsUrl;
  final String resetUrl;
  final String descriptionTh;
  final String descriptionEn;
  final List<MasterResetOption> options;

  const MasterResetView({
    super.key,
    required this.countsUrl,
    required this.resetUrl,
    required this.descriptionTh,
    required this.descriptionEn,
    required this.options,
  });

  @override
  State<MasterResetView> createState() => _MasterResetViewState();
}

class _MasterResetViewState extends State<MasterResetView> {
  static const String _confirmWord = 'ยืนยัน';

  final _confirmCtrl = TextEditingController();
  final Set<String> _selected = {};
  bool _isLoadingCounts = false;
  bool _isExecuting = false;
  Map<String, dynamic>? _counts;
  String? _error;
  bool _isEnglish = false;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  @override
  void dispose() {
    _confirmCtrl.dispose();
    super.dispose();
  }

  String _t(String th, String en) => _isEnglish ? en : th;

  int get _transactionsTotal => (_counts?['transactions_total'] as num?)?.toInt() ?? 0;

  bool get _blocked => _transactionsTotal > 0;

  Future<void> _loadCounts() async {
    setState(() {
      _isLoadingCounts = true;
      _error = null;
    });
    try {
      final headers = await AuthService().getAuthHeader();
      final res = await http.get(Uri.parse(widget.countsUrl), headers: headers);
      if (res.statusCode == 200) {
        setState(() => _counts = json.decode(res.body));
      } else {
        setState(() => _error = json.decode(res.body)['message'] ?? _t('โหลดข้อมูลไม่สำเร็จ', 'Failed to load data'));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingCounts = false);
    }
  }

  bool get _canExecute =>
      (MenuScope.of(context)?.canDelete ?? true) &&
      _counts != null &&
      !_blocked &&
      _selected.isNotEmpty &&
      _confirmCtrl.text.trim() == _confirmWord &&
      !_isExecuting;

  Future<void> _execute() async {
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    final chosen = widget.options.where((o) => _selected.contains(o.bodyKey)).toList();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
          const SizedBox(width: 8),
          Text(_t('ยืนยันการลบข้อมูล', 'Confirm Delete')),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('การดำเนินการนี้ไม่สามารถยกเลิกได้!\nข้อมูลที่ลบจะหายไปถาวร',
                  'This action cannot be undone!\nDeleted data will be permanently lost.'),
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            for (final o in chosen)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Icon(o.icon, size: 16, color: Colors.red[700]),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(_t(o.titleTh, o.titleEn), style: const TextStyle(fontWeight: FontWeight.w500)),
                  ),
                ]),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(_t('ยืนยัน ลบข้อมูล', 'Confirm Delete')),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isExecuting = true);
    try {
      final headers = {
        ...await AuthService().getAuthHeader(),
        'Content-Type': 'application/json',
      };
      final res = await http.delete(
        Uri.parse(widget.resetUrl),
        headers: headers,
        body: json.encode({for (final o in widget.options) o.bodyKey: _selected.contains(o.bodyKey)}),
      );

      if (!mounted) return;
      final data = json.decode(res.body);
      if (res.statusCode == 200) {
        final errors = (data['errors'] as Map?) ?? const {};
        if (errors.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_t('ดำเนินการสำเร็จ', 'Completed successfully')),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 4),
          ));
        } else {
          await _showErrors(errors);
        }
        _confirmCtrl.clear();
        _selected.clear();
        await _loadCounts();
      } else {
        final msg = data['message'] ?? _t('เกิดข้อผิดพลาด', 'An error occurred');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('ล้มเหลว: $msg', 'Failed: $msg')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ));
        if (res.statusCode == 409) await _loadCounts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('เกิดข้อผิดพลาด: $e', 'Error: $e')),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isExecuting = false);
    }
  }

  // ขั้นตอนที่ล้มเหลว (ส่วนใหญ่ติด FK เพราะข้อมูลหลักอื่นยังอ้างอิงอยู่) — ขั้นตอนอื่นที่สำเร็จถูกบันทึกแล้ว
  Future<void> _showErrors(Map errors) {
    final l = AppL10n(_isEnglish);
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.error_outline, color: Colors.orange[800]),
          const SizedBox(width: 8),
          Text(_t('บางรายการล้างไม่สำเร็จ', 'Some items were not cleared')),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_t('รายการอื่นที่เลือกล้างเรียบร้อยแล้ว', 'The other selected items were cleared.')),
              const SizedBox(height: 8),
              for (final e in errors.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• ${e.key}: ${e.value}', style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.close))],
      ),
    );
  }

  Widget _optionCard(MasterResetOption o) {
    final value = _selected.contains(o.bodyKey);
    return Card(
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            secondary: Icon(o.icon, color: _blocked ? Colors.grey : o.color),
            title: Text(_t(o.titleTh, o.titleEn), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(o.subtitle(_counts, _isEnglish), style: const TextStyle(fontSize: 12)),
            value: value,
            activeColor: o.color,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: _blocked
                ? null
                : (v) => setState(() => v == true ? _selected.add(o.bodyKey) : _selected.remove(o.bodyKey)),
          ),
          if (value && o.details.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final d in o.details)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text('• ${_t(d.$1, d.$2)}', style: TextStyle(fontSize: 12, color: o.color)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _isEnglish = context.watch<LanguageProvider>().isEnglish;
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.red[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: _t('รีเฟรช', 'Refresh'),
            onPressed: _loadCounts,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[300]!),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _t('เครื่องมือสำหรับผู้พัฒนาระบบเท่านั้น', 'For System Developers Only'),
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red[800]),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      _t(widget.descriptionTh, widget.descriptionEn),
                      style: TextStyle(color: Colors.red[900], fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _t('ธุรกรรมทุกโมดูลล้างที่หน้าจอ "ล้างธุรกรรมทุกโมดูล" — ต้องล้างธุรกรรมก่อน จึงจะล้างข้อมูลหลักที่หน้าจอนี้ได้',
                          'Transactions are cleared on the "Reset All Transactions" screen — clear them first before clearing master data here.'),
                      style: TextStyle(color: Colors.grey[800], fontSize: 12),
                    ),
                  ]),
                ),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),

                if (_blocked) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange[300]!),
                    ),
                    child: Row(children: [
                      Icon(Icons.block, color: Colors.orange[800]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _t('ยังมีธุรกรรมในระบบ $_transactionsTotal รายการ — ล้างข้อมูลหลักไม่ได้จนกว่าจะล้างธุรกรรมที่หน้าจอ "ล้างธุรกรรมทุกโมดูล"',
                              '$_transactionsTotal transaction rows remain — master data cannot be cleared until transactions are cleared on the "Reset All Transactions" screen'),
                          style: TextStyle(color: Colors.orange[900], fontSize: 13),
                        ),
                      ),
                    ]),
                  ),
                ],

                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: Text(_t('เลือกข้อมูลหลักที่ต้องการลบ/รีเซ็ต', 'Select master data to delete/reset'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  if (_isLoadingCounts)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ]),
                const SizedBox(height: 8),

                for (final o in widget.options) ...[
                  _optionCard(o),
                  const SizedBox(height: 6),
                ],

                const SizedBox(height: 18),

                TextFormField(
                  controller: _confirmCtrl,
                  enabled: !_blocked,
                  decoration: InputDecoration(
                    labelText: _t('พิมพ์ "$_confirmWord" เพื่อเปิดใช้ปุ่มลบ',
                        'Type "$_confirmWord" to enable the delete button'),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey[50],
                    prefixIcon: const Icon(Icons.keyboard),
                  ),
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _canExecute ? _execute : null,
                    icon: _isExecuting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.delete_forever),
                    label: Text(
                      _isExecuting ? _t('กำลังลบข้อมูล...', 'Deleting...') : _t('ลบข้อมูลที่เลือก', 'Delete Selected'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[800],
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Center(
                  child: Text(
                    _t('ปุ่มจะพร้อมใช้งานเมื่อพิมพ์ "$_confirmWord" และเลือกอย่างน้อย 1 รายการ',
                        'The button activates when you type "$_confirmWord" and select at least one item'),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
