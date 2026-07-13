import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/language_provider.dart';

class SessionConflictDialog extends StatefulWidget {
  final DateTime? sessionStartedAt;
  final VoidCallback onForceLogout;
  final VoidCallback onCancel;

  const SessionConflictDialog({
    super.key,
    this.sessionStartedAt,
    required this.onForceLogout,
    required this.onCancel,
  });

  @override
  State<SessionConflictDialog> createState() => _SessionConflictDialogState();
}

class _SessionConflictDialogState extends State<SessionConflictDialog> {
  static const int _totalSeconds = 120;
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = _totalSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        _timer?.cancel();
        if (mounted) widget.onCancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timeStr {
    final m = (_remaining ~/ 60).toString().padLeft(2, '0');
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final sessionInfo = widget.sessionStartedAt != null
        ? (isEnglish
            ? 'Started at ${fmt.format(widget.sessionStartedAt!.toLocal())}'
            : 'เริ่มเมื่อ ${fmt.format(widget.sessionStartedAt!.toLocal())}')
        : (isEnglish ? 'Unknown time' : 'ไม่ทราบเวลา');

    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.devices, color: Colors.orange, size: 28),
        const SizedBox(width: 10),
        Flexible(
          child: Text(isEnglish ? 'Already Logged In' : 'มีการ Login อยู่แล้ว'),
        ),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEnglish
                ? 'This account is logged in on another device'
                : 'บัญชีนี้กำลัง Login อยู่ที่อีกเครื่องหนึ่ง',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(sessionInfo,
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 16),
          Text(isEnglish
              ? 'Do you want to logout that device and login here?'
              : 'ต้องการ Logout เครื่องนั้นและ Login ที่เครื่องนี้หรือไม่?'),
          const SizedBox(height: 16),
          Center(
            child: Column(children: [
              Text(
                isEnglish ? 'Auto-cancel in' : 'ยกเลิกอัตโนมัติใน',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                _timeStr,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: _remaining <= 30 ? Colors.red : Colors.orange,
                ),
              ),
            ]),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _timer?.cancel();
            widget.onCancel();
          },
          child: Text(isEnglish ? 'No (Cancel)' : 'ไม่ (ยกเลิก)'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.logout, size: 18),
          label: Text(isEnglish ? 'Yes (Logout That Device)' : 'ใช่ (Logout เครื่องนั้น)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[700],
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            _timer?.cancel();
            widget.onForceLogout();
          },
        ),
      ],
    );
  }
}
