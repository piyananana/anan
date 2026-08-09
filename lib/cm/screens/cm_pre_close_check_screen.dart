// lib/cm/screens/cm_pre_close_check_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../services/cm_pre_close_check_service.dart';
import '../../utils/date_utils.dart';

const _kTheme = Color(0xFF1565C0);
final _dateFmt = DateFormat('dd/MM/yyyy');

class CmPreCloseCheckScreen extends StatefulWidget {
  const CmPreCloseCheckScreen({super.key});
  @override
  State<CmPreCloseCheckScreen> createState() => _State();
}

class _State extends State<CmPreCloseCheckScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _svc = CmPreCloseCheckService();
  bool _isEnglish = false;

  DateTime? _periodDate;
  bool _loading = false;
  List<Map<String, dynamic>> _checks = [];
  bool _hasErrors = false;
  bool _hasRun    = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periodDate = DateTime(now.year, now.month + 1, 0); // last day of current month
  }

  Future<void> _runChecks() async {
    if (_periodDate == null) return;
    setState(() { _loading = true; _hasRun = false; });
    try {
      final result = await _svc.runChecks(formatLocalDate(_periodDate!));
      if (!mounted) return;
      setState(() {
        _checks    = List<Map<String, dynamic>>.from(result['checks'] as List);
        _hasErrors = result['has_errors'] == true;
        _hasRun    = true;
        _loading   = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red.shade700));
    }
  }

  Widget _checkItem(Map<String, dynamic> check) {
    final isEnglish = _isEnglish;
    final count    = (check['count'] as num?)?.toInt() ?? 0;
    final severity = check['severity'] as String? ?? 'INFO';
    final ok       = count == 0;
    final isWarning = severity == 'WARNING' || severity == 'INFO';
    final docs = List<Map<String, dynamic>>.from(check['docs'] as List? ?? []);

    final icon = ok
        ? const Icon(Icons.check_circle, color: _kTheme, size: 20)
        : isWarning
            ? const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20)
            : const Icon(Icons.cancel, color: Colors.red, size: 20);
    final color = ok ? _kTheme : isWarning ? Colors.orange : Colors.red;
    final label = isEnglish ? (check['title_en'] as String? ?? '') : (check['title'] as String? ?? '');
    final value = isEnglish ? '$count items' : '$count รายการ';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        icon,
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
      ]),
      if (docs.isNotEmpty) ...[
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Wrap(
            spacing: 8, runSpacing: 4,
            children: docs.take(5).map((d) => Chip(
              label: Text(d['doc_no']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: Colors.orange[50],
            )).toList()
              ..addAll(count > 5
                  ? [Chip(label: Text(isEnglish ? '+${count - 5} items' : '+${count - 5} รายการ', style: const TextStyle(fontSize: 11)), padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)]
                  : []),
          ),
        ),
      ],
      const Divider(height: 20),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kTheme,
        foregroundColor: Colors.white,
        title: const MenuTitle(),
        toolbarHeight: 40,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Period selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Text(isEnglish ? 'Period Close Date:' : 'วันที่ปิดงวด:', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                _datePicker(),
                const SizedBox(width: 16),
                FilledButton.icon(
                  icon: _loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.search, size: 16),
                  label: Text(isEnglish ? 'Check' : 'ตรวจสอบ'),
                  style: FilledButton.styleFrom(backgroundColor: _kTheme),
                  onPressed: _loading ? null : _runChecks,
                ),
              ]),
            ),
          ),

          if (_loading) ...[
            const SizedBox(height: 40),
            const Center(child: CircularProgressIndicator()),
          ] else if (!_hasRun) ...[
            const SizedBox(height: 40),
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.search, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Text(isEnglish ? 'Press "Check" to see results' : 'กด "ตรวจสอบ" เพื่อดูผลลัพธ์',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
              ]),
            ),
          ] else ...[
            const SizedBox(height: 20),
            // Result checklist
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                      isEnglish
                          ? 'Check result for period through ${_dateFmt.format(_periodDate!)}'
                          : 'ผลการตรวจสอบงวดถึงวันที่ ${_dateFmt.format(_periodDate!)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const Divider(height: 24),
                  for (final check in _checks) _checkItem(check),
                  if (!_hasErrors)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _kTheme.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Icon(Icons.check_circle, color: _kTheme, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                            isEnglish
                                ? 'Ready to close the period — no blocking issues found'
                                : 'พร้อมดำเนินการปิดงวด — ไม่พบรายการที่ขัดขวางการปิดงวด',
                            style: TextStyle(color: _kTheme, fontWeight: FontWeight.bold))),
                      ]),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        const Icon(Icons.block, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                            isEnglish
                                ? 'Please resolve the items above before closing the period'
                                : 'กรุณาแก้ไขรายการข้างต้นก่อนปิดงวด',
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                      ]),
                    ),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _datePicker() {
    return InkWell(
      onTap: () async {
        final p = await showDatePicker(context: context,
            initialDate: _periodDate ?? DateTime.now(),
            firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (p != null) setState(() => _periodDate = p);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(_periodDate != null ? _dateFmt.format(_periodDate!) : '—',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Icon(Icons.calendar_today, size: 15, color: Colors.grey.shade500),
        ]),
      ),
    );
  }
}
