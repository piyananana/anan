import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/inactivity_service.dart';
import '../screens/login_screen.dart';

class InactivityDetector extends StatefulWidget {
  final Widget child;
  const InactivityDetector({super.key, required this.child});

  @override
  State<InactivityDetector> createState() => _InactivityDetectorState();
}

class _InactivityDetectorState extends State<InactivityDetector> {
  final _svc = InactivityService();
  bool _dialogShowing = false;
  Timer? _sessionPollTimer;

  @override
  void initState() {
    super.initState();
    _svc.onShowWarning = _handleShowWarning;
    _svc.onTimeout = _handleTimeout;
    // ตรวจ session ทุก 60 วิ เพื่อรับรู้ว่าถูก kick ออกจากเครื่องอื่น
    _sessionPollTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _checkSession(),
    );
  }

  @override
  void dispose() {
    _sessionPollTimer?.cancel();
    _svc.onShowWarning = null;
    _svc.onTimeout = null;
    super.dispose();
  }

  Future<void> _checkSession() async {
    try {
      final headers = await AuthService().getAuthHeader();
      final res = await http.post(
        Uri.parse('${AuthService.baseUrl}/auth/check_token'),
        headers: headers,
      );
      if (res.statusCode == 401) {
        _sessionPollTimer?.cancel();
        _handleSessionReplaced();
      }
    } catch (_) {}
  }

  Future<void> _handleSessionReplaced() async {
    if (!mounted) return;
    _svc.stop();
    final auth = Provider.of<AuthService>(context, listen: false);
    await auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(
          logoutMessage: 'บัญชีนี้ถูก Login จากเครื่องอื่น คุณถูก Logout อัตโนมัติ',
        ),
      ),
      (_) => false,
    );
  }

  void _handleShowWarning() {
    if (!mounted || _dialogShowing) return;
    _dialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _InactivityWarningDialog(
        service: _svc,
        onContinue: () => _dialogShowing = false,
        onLogout: () {
          _dialogShowing = false;
          _handleTimeout();
        },
      ),
    ).then((_) => _dialogShowing = false);
  }

  Future<void> _handleTimeout() async {
    if (!mounted) return;
    _svc.stop();
    final auth = Provider.of<AuthService>(context, listen: false);
    await auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(
          logoutMessage: 'ออกจากระบบอัตโนมัติ เนื่องจากไม่มีการใช้งานในเวลาที่กำหนด',
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _svc.resetActivity(),
      onPointerMove: (_) => _svc.resetActivity(),
      child: widget.child,
    );
  }
}

class _InactivityWarningDialog extends StatefulWidget {
  final InactivityService service;
  final VoidCallback onContinue;
  final VoidCallback onLogout;

  const _InactivityWarningDialog({
    required this.service,
    required this.onContinue,
    required this.onLogout,
  });

  @override
  State<_InactivityWarningDialog> createState() =>
      _InactivityWarningDialogState();
}

class _InactivityWarningDialogState extends State<_InactivityWarningDialog> {
  late Timer _timer;
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    _remaining = widget.service.remainingSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final r = widget.service.remainingSeconds;
      setState(() => _remaining = r);
      if (r <= 0) {
        _timer.cancel();
        if (mounted) Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _timeStr {
    final m = (_remaining ~/ 60).toString().padLeft(2, '0');
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(children: [
        Icon(Icons.timer_off_outlined, color: Colors.orange),
        SizedBox(width: 8),
        Flexible(child: Text('การเชื่อมต่อกำลังจะหมดอายุ')),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('ไม่มีการใช้งานเป็นเวลานาน'),
          const SizedBox(height: 4),
          Text('ออกจากระบบอัตโนมัติใน',
              style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 12),
          Text(
            _timeStr,
            style: const TextStyle(
              fontSize: 52,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _timer.cancel();
            widget.onLogout();
            Navigator.of(context).pop();
          },
          child: const Text('ออกจากระบบ'),
        ),
        ElevatedButton(
          onPressed: () {
            _timer.cancel();
            widget.service.resetActivity();
            widget.onContinue();
            Navigator.of(context).pop();
          },
          child: const Text('ใช้งานต่อ'),
        ),
      ],
    );
  }
}
