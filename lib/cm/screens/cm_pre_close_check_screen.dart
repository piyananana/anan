// lib/cm/screens/cm_pre_close_check_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../services/cm_pre_close_check_service.dart';

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

  DateTime? _periodDate;
  bool _loading = false;
  List<Map<String, dynamic>> _issues  = [];
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
      final result = await _svc.runChecks(DateFormat('yyyy-MM-dd').format(_periodDate!));
      if (!mounted) return;
      setState(() {
        _issues    = List<Map<String, dynamic>>.from(result['issues'] as List);
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kTheme,
        foregroundColor: Colors.white,
        title: const MenuTitle(),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        toolbarHeight: 40,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('เลือกวันที่ปิดงวด เพื่อตรวจสอบรายการที่ค้างอยู่ก่อนปิด',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            // Date picker + Run button
            Row(children: [
              _datePicker(),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white,
                    minimumSize: const Size(0, 36)),
                onPressed: _loading ? null : _runChecks,
                icon: _loading
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.fact_check_outlined, size: 16),
                label: const Text('ตรวจสอบ', style: TextStyle(fontSize: 13)),
              ),
            ]),
            const SizedBox(height: 24),

            // Results
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (!_hasRun)
              Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.search, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('กด "ตรวจสอบ" เพื่อดูผลลัพธ์',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                ]),
              )
            else if (_issues.isEmpty)
              _buildAllClear()
            else
              Expanded(child: _buildIssueList()),
          ],
        ),
      ),
    );
  }

  Widget _buildAllClear() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(Icons.check_circle, color: Colors.green.shade600, size: 40),
        const SizedBox(width: 16),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ผ่านการตรวจสอบทุกรายการ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
            const SizedBox(height: 4),
            Text('ไม่พบรายการค้างในงวดถึง ${_dateFmt.format(_periodDate!)} — สามารถปิดงวดได้',
                style: TextStyle(fontSize: 13, color: Colors.green.shade600)),
          ],
        )),
      ]),
    );
  }

  Widget _buildIssueList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _hasErrors ? Colors.red.shade50 : Colors.orange.shade50,
            border: Border.all(color: _hasErrors ? Colors.red.shade200 : Colors.orange.shade200),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(children: [
            Icon(_hasErrors ? Icons.error_outline : Icons.warning_amber_rounded,
                color: _hasErrors ? Colors.red.shade700 : Colors.orange.shade700, size: 22),
            const SizedBox(width: 8),
            Text(
              'พบ ${_issues.length} รายการที่ต้องแก้ไข ก่อนปิดงวดวันที่ ${_dateFmt.format(_periodDate!)}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: _hasErrors ? Colors.red.shade700 : Colors.orange.shade700),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: _issues.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _buildIssueCard(_issues[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildIssueCard(Map<String, dynamic> issue) {
    final severity = issue['severity'] as String? ?? 'INFO';
    Color borderColor, bgColor, iconColor;
    IconData icon;
    switch (severity) {
      case 'ERROR':
        borderColor = Colors.red.shade300;
        bgColor     = Colors.red.shade50;
        iconColor   = Colors.red.shade700;
        icon        = Icons.error_outline;
      case 'WARNING':
        borderColor = Colors.orange.shade300;
        bgColor     = Colors.orange.shade50;
        iconColor   = Colors.orange.shade700;
        icon        = Icons.warning_amber_rounded;
      default:
        borderColor = Colors.blue.shade200;
        bgColor     = Colors.blue.shade50;
        iconColor   = Colors.blue.shade700;
        icon        = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(issue['title'] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: iconColor)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: iconColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                child: Text('${issue['count']} รายการ',
                    style: TextStyle(fontSize: 11, color: iconColor, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(issue['message'] ?? '', style: TextStyle(fontSize: 13, color: iconColor.withOpacity(0.85))),
          ],
        )),
      ]),
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
          const Text('วันที่ปิดงวด: ', style: TextStyle(fontSize: 13, color: Colors.grey)),
          Text(_periodDate != null ? _dateFmt.format(_periodDate!) : '—',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Icon(Icons.calendar_today, size: 15, color: Colors.grey.shade500),
        ]),
      ),
    );
  }
}
