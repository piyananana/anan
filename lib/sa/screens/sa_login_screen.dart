// screens/sa_login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sa_password_status.dart';
import '../services/sa_login_branding_service.dart';
import '../services/sa_auth_service.dart';
import '../services/sa_language_provider.dart';
import '../widgets/sa_change_password_dialog.dart';
import '../widgets/sa_font_size_button.dart';
import '../widgets/sa_session_conflict_dialog.dart';
import 'sa_home_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? logoutMessage;
  const LoginScreen({super.key, this.logoutMessage});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  List<String> _databases = [];
  String? _selectedDatabase;

  // หน้าตาหน้าล็อกอิน (แบบ A/B, โลโก้, ชื่อระบบ) ตั้งค่าที่หน้า "ตั้งค่าหน้าล็อกอิน" — ใช้ค่าที่โหลดไว้ก่อน (ถ้ามี) กันหน้ากระพริบ
  LoginBranding _branding = LoginBrandingService().cached ?? const LoginBranding();
  final FocusNode _passwordFocus = FocusNode();
  bool _obscure = true;
  bool _rememberUser = false;
  bool _capsOn = false;

  @override
  void initState() {
    super.initState();
    _loadBranding();
    _loadRemembered();
    _fetchDatabasesAndLoadDefault();
    if (widget.logoutMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.logoutMessage!),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 5),
        ));
      });
    }
  }

  Future<void> _fetchDatabasesAndLoadDefault() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final databases = await authService.fetchDatabases();
      final defaultDb = await authService.getDefaultDatabase();
      if (!mounted) return;
      setState(() {
        _databases = databases;
        _selectedDatabase =
            defaultDb ?? (databases.isNotEmpty ? databases[0] : null);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _login() async {
    final isEnglish =
        Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final responseData = await authService.login(
        _usernameController.text,
        _passwordController.text,
        _selectedDatabase!,
      );

      if (!mounted) return;

      if (responseData['requiresConfirmation'] == true) {
        setState(() => _isLoading = false);
        final confirmToken = responseData['confirmToken'] as String;
        final sessionStartedAt = responseData['sessionStartedAt'] != null
            ? DateTime.tryParse(responseData['sessionStartedAt'].toString())
                ?.toLocal()
            : null;

        final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => SessionConflictDialog(
            sessionStartedAt: sessionStartedAt,
            onForceLogout: () => Navigator.of(context).pop(true),
            onCancel: () => Navigator.of(context).pop(false),
          ),
        );

        if (confirmed != true || !mounted) return;

        setState(() => _isLoading = true);
        final confirmData =
            await authService.confirmLogin(confirmToken, forceLogout: true);
        if (!mounted) return;
        if (confirmData['success'] != true) return;

        final passwordStatus = PasswordStatus.fromJson(
            confirmData['passwordStatus'] ??
                {'isPasswordExpired': false, 'forceChangePassword': false});
        _navigateAfterLogin(passwordStatus, confirmData);
        return;
      }

      final passwordStatus =
          PasswordStatus.fromJson(responseData['passwordStatus']);
      _navigateAfterLogin(passwordStatus, responseData);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish
              ? 'Login failed: ${e.toString().replaceFirst('Exception: ', '')}'
              : 'เข้าสู่ระบบไม่สำเร็จ: ${e.toString().replaceFirst('Exception: ', '')}'),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _navigateAfterLogin(
      PasswordStatus passwordStatus, Map<String, dynamic> data) {
    _persistUsername();
    if (passwordStatus.forceChangePassword) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChangePasswordDialog(
              userId: data['user']['id'], forceChange: true),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(passwordStatus: passwordStatus),
        ),
      );
    }
  }

  // ── จดจำชื่อผู้ใช้ (เครื่องนี้) ─────────────────────────────────────────────
  static const _rememberKey = 'login_remember_username';

  Future<void> _loadRemembered() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final u = prefs.getString(_rememberKey);
      if (!mounted || u == null || u.isEmpty) return;
      setState(() {
        _rememberUser = true;
        _usernameController.text = u;
      });
      // มีชื่อผู้ใช้แล้ว → ไปที่ช่องรหัสผ่านเลย
      WidgetsBinding.instance.addPostFrameCallback((_) => _passwordFocus.requestFocus());
    } catch (_) {}
  }

  Future<void> _persistUsername() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_rememberUser) {
        await prefs.setString(_rememberKey, _usernameController.text.trim());
      } else {
        await prefs.remove(_rememberKey);
      }
    } catch (_) {}
  }

  Future<void> _loadBranding() async {
    try {
      final b = await LoginBrandingService().fetch();
      if (mounted) setState(() => _branding = b);
    } catch (_) {
      // ใช้ค่าเริ่มต้นของแอป
    }
  }

  void _updateCaps() {
    final on = HardwareKeyboard.instance.lockModesEnabled.contains(KeyboardLockMode.capsLock);
    if (on != _capsOn) setState(() => _capsOn = on);
  }

  // ── ส่วนประกอบ ──────────────────────────────────────────────────────────
  Widget _logo({double radius = 12}) {
    final url = _branding.logoUrl;
    const fallback = Image(image: AssetImage('assets/images/ANAN.png'), fit: BoxFit.contain);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null
          ? fallback
          : Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) => fallback),
    );
  }

  InputDecoration _deco(IconData icon, {Widget? suffix}) => InputDecoration(
        isDense: false,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon, size: 20, color: _LoginColors.ink3),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: _LoginColors.line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: _LoginColors.brand, width: 1.6)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _LoginColors.ink2)),
      );

  Widget _form(bool isEnglish) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      _label(isEnglish ? 'Database' : 'ฐานข้อมูล'),
      DropdownButtonFormField<String>(
        isExpanded: true,
        decoration: _deco(Icons.storage_rounded),
        value: _selectedDatabase,
        items: _databases.map((db) => DropdownMenuItem(value: db, child: Text(db))).toList(),
        onChanged: (value) => setState(() => _selectedDatabase = value),
      ),
      const SizedBox(height: 14),
      _label(isEnglish ? 'Username' : 'ชื่อผู้ใช้งาน'),
      TextField(
        controller: _usernameController,
        autofocus: true,
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => _passwordFocus.requestFocus(),
        decoration: _deco(Icons.person_outline_rounded),
      ),
      const SizedBox(height: 14),
      _label(isEnglish ? 'Password' : 'รหัสผ่าน'),
      Focus(
        onKeyEvent: (_, __) {
          _updateCaps();
          return KeyEventResult.ignored;
        },
        onFocusChange: (_) => _updateCaps(),
        child: TextField(
          controller: _passwordController,
          focusNode: _passwordFocus,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _login(),
          decoration: _deco(
            Icons.lock_outline_rounded,
            suffix: IconButton(
              tooltip: _obscure
                  ? (isEnglish ? 'Show password' : 'แสดงรหัสผ่าน')
                  : (isEnglish ? 'Hide password' : 'ซ่อนรหัสผ่าน'),
              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: _LoginColors.ink3),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
      ),
      if (_capsOn)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFFFF3C4), borderRadius: BorderRadius.circular(6)),
              child: Text(isEnglish ? 'Caps Lock is on' : 'Caps Lock เปิดอยู่',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8A5A00))),
            ),
          ),
        ),
      const SizedBox(height: 10),
      Row(children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _rememberUser,
            activeColor: _LoginColors.brand,
            onChanged: (v) => setState(() => _rememberUser = v ?? false),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => setState(() => _rememberUser = !_rememberUser),
          child: Text(isEnglish ? 'Remember username' : 'จดจำชื่อผู้ใช้',
              style: const TextStyle(fontSize: 13, color: _LoginColors.ink2)),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            isEnglish ? 'Forgot password? Contact your administrator' : 'ลืมรหัสผ่าน? ติดต่อผู้ดูแลระบบ',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, color: _LoginColors.ink3),
          ),
        ),
      ]),
      if (_errorMessage != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFFFDECEA), borderRadius: BorderRadius.circular(8)),
          child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFC62828), fontSize: 13)),
        ),
      ],
      const SizedBox(height: 16),
      SizedBox(
        height: 48,
        child: FilledButton(
          onPressed: _isLoading ? null : _login,
          style: FilledButton.styleFrom(
            backgroundColor: _LoginColors.brand,
            disabledBackgroundColor: _LoginColors.brand.withOpacity(0.6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
          ),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(isEnglish ? 'Log in' : 'เข้าสู่ระบบ'),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ]),
        ),
      ),
    ]);
  }

  // ปุ่มขนาดตัวอักษร + ภาษา มุมขวาบน (dark = วางบนพื้นเข้ม)
  Widget _tools(bool isEnglish, {required bool dark}) {
    final ink = dark ? _LoginColors.brandInk : _LoginColors.ink2;
    final line = dark ? Colors.white30 : _LoginColors.line;
    Widget seg(String t, bool on) => InkWell(
          onTap: on ? null : context.read<LanguageProvider>().toggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: on ? (dark ? _LoginColors.gold : _LoginColors.brand) : Colors.transparent,
            child: Text(t,
                style: TextStyle(fontSize: 12.5, color: on ? (dark ? _LoginColors.brand2 : Colors.white) : ink)),
          ),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      FontSizeButton(isEnglish: isEnglish, color: ink, compact: true),
      const SizedBox(width: 8),
      Tooltip(
        message: isEnglish ? 'สลับเป็นภาษาไทย' : 'Switch to English',
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: line), borderRadius: BorderRadius.circular(8)),
          clipBehavior: Clip.antiAlias,
          child: Row(mainAxisSize: MainAxisSize.min, children: [seg('ไทย', !isEnglish), seg('ENG', isEnglish)]),
        ),
      ),
    ]);
  }

  static const _modules = ['GL', 'AR', 'AP', 'CM', 'IM', 'PO', 'SO', 'MO', 'VAT', 'WHT'];

  // ── แบบ A: แบ่งซ้าย-ขวา ─────────────────────────────────────────────────
  Widget _layoutA(bool isEnglish, Size size) {
    final wide = size.width >= 900;
    final formSide = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 72, 24, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!wide) ...[
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _LoginColors.line)),
                  child: _logo(),
                ),
              ),
              const SizedBox(height: 10),
              Text(_branding.name(isEnglish),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _LoginColors.ink)),
              const SizedBox(height: 20),
            ],
            Text(isEnglish ? 'Log in' : 'เข้าสู่ระบบ',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: _LoginColors.ink)),
            const SizedBox(height: 4),
            Text(
              isEnglish
                  ? 'Choose a database, then enter your username and password'
                  : 'เลือกฐานข้อมูลแล้วกรอกชื่อผู้ใช้และรหัสผ่าน',
              style: const TextStyle(color: _LoginColors.ink2, fontSize: 14),
            ),
            const SizedBox(height: 22),
            _form(isEnglish),
          ]),
        ),
      ),
    );
    return Stack(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (wide)
          Expanded(
            flex: 105,
            child: Container(
              color: _LoginColors.brand2,
              child: CustomPaint(
                painter: _LedgerPainter(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(64, 56, 64, 36),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 168,
                      height: 168,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.96),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 40, offset: Offset(0, 18))],
                      ),
                      child: _logo(radius: 16),
                    ),
                    const SizedBox(height: 34),
                    Text(_branding.name(isEnglish),
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: _LoginColors.brandInk, height: 1.15)),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Text(_branding.tagline(isEnglish),
                          style: const TextStyle(fontSize: 17, color: _LoginColors.brandDim, height: 1.55)),
                    ),
                    const Spacer(),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final m in _modules)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                          child: Text(m, style: const TextStyle(fontSize: 11.5, color: _LoginColors.brandDim, letterSpacing: 0.5)),
                        ),
                    ]),
                    const SizedBox(height: 16),
                    const Text('© ANAN', style: TextStyle(fontSize: 12, color: Color(0xFF7DA793))),
                  ]),
                ),
              ),
            ),
          ),
        Expanded(flex: 100, child: Container(color: Colors.white, child: formSide)),
      ]),
      Positioned(top: 18, right: 20, child: _tools(isEnglish, dark: false)),
    ]);
  }

  // ── แบบ B: การ์ดกลางจอ ─────────────────────────────────────────────────
  Widget _layoutB(bool isEnglish) {
    final bg = _branding.backgroundUrl;
    const gradient = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1D6A4D), _LoginColors.brand2, Color(0xFF5C4A12)],
        stops: [0, 0.6, 1],
      ),
    );
    return Stack(fit: StackFit.expand, children: [
      // พื้นหลัง: รูปที่อัปโหลด หรือไล่สีเขียว-ทอง
      Container(decoration: gradient),
      if (bg != null) Image.network(bg, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x40061E16), Color(0x8C061E16)],
          ),
        ),
      ),
      Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 72, 16, 48),
          child: Container(
            width: 440,
            padding: const EdgeInsets.fromLTRB(36, 32, 36, 28),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.97),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 60, offset: Offset(0, 24))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Center(
                child: Container(
                  width: 92,
                  height: 92,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _LoginColors.line),
                  ),
                  child: _logo(),
                ),
              ),
              const SizedBox(height: 12),
              Text(_branding.name(isEnglish),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _LoginColors.ink)),
              const SizedBox(height: 4),
              Text(_branding.tagline(isEnglish),
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: _LoginColors.ink2)),
              const SizedBox(height: 20),
              _form(isEnglish),
            ]),
          ),
        ),
      ),
      const Positioned(
        left: 0,
        right: 0,
        bottom: 16,
        child: Text('© ANAN', textAlign: TextAlign.center, style: TextStyle(color: Color(0xB3E8F3EC), fontSize: 12)),
      ),
      Positioned(top: 18, right: 20, child: _tools(isEnglish, dark: true)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: _branding.layout == 'B' ? _LoginColors.brand2 : Colors.white,
      body: _branding.layout == 'B' ? _layoutB(isEnglish) : _layoutA(isEnglish, size),
    );
  }
}

class _LoginColors {
  static const brand = Color(0xFF0F4A36);
  static const brand2 = Color(0xFF0B3A2A);
  static const brandInk = Color(0xFFE8F3EC);
  static const brandDim = Color(0xFF9FC0B0);
  static const gold = Color(0xFFE0A526);
  static const line = Color(0xFFE1E6E3);
  static const ink = Color(0xFF1B2420);
  static const ink2 = Color(0xFF55625B);
  static const ink3 = Color(0xFF8B968F);
}

/// ลายเส้นสมุดบัญชีจาง ๆ บนพื้นเขียว (แบบ A)
class _LedgerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0x219FC0B0)
      ..strokeWidth = 1;
    for (double y = 24; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    final col = Paint()
      ..color = const Color(0x2EE0A526)
      ..strokeWidth = 1;
    for (final x in [size.width * 0.62, size.width * 0.8]) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), col);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
