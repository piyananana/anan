import 'dart:async';
import 'package:flutter/services.dart';

class InactivityService {
  static final InactivityService _instance = InactivityService._();
  factory InactivityService() => _instance;
  InactivityService._();

  // warning แสดงก่อน timeout 60 วินาที แต่ไม่เกิน 50% ของ timeout
  int get _warningBeforeSeconds => (_timeoutSeconds * 0.5).floor().clamp(30, 60);

  int _timeoutSeconds = 300; // default 5 minutes
  DateTime _lastActivity = DateTime.now();
  Timer? _ticker;
  bool _warningShown = false;
  bool _running = false;

  VoidCallback? onShowWarning;
  VoidCallback? onTimeout;

  void configure(int timeoutMinutes) {
    _timeoutSeconds = timeoutMinutes * 60;
  }

  void start() {
    if (_running) return;
    _running = true;
    _lastActivity = DateTime.now();
    _warningShown = false;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), _tick);
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  void stop() {
    if (!_running) return;
    _running = false;
    _ticker?.cancel();
    _ticker = null;
    _warningShown = false;
    try {
      HardwareKeyboard.instance.removeHandler(_onKey);
    } catch (_) {}
  }

  void resetActivity() {
    _lastActivity = DateTime.now();
    _warningShown = false;
  }

  int get remainingSeconds {
    if (!_running) return _timeoutSeconds;
    final elapsed = DateTime.now().difference(_lastActivity).inSeconds;
    return (_timeoutSeconds - elapsed).clamp(0, _timeoutSeconds);
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      resetActivity();
    }
    return false; // ไม่ consume event
  }

  void _tick(Timer timer) {
    final elapsed = DateTime.now().difference(_lastActivity).inSeconds;
    if (elapsed >= _timeoutSeconds) {
      stop();
      onTimeout?.call();
    } else if (!_warningShown &&
        elapsed >= _timeoutSeconds - _warningBeforeSeconds) {
      _warningShown = true;
      onShowWarning?.call();
    }
  }
}
