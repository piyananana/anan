// screens/sa_login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sa_password_status.dart';
import '../services/sa_auth_service.dart';
import '../services/sa_language_provider.dart';
import '../widgets/sa_change_password_dialog.dart';
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

  @override
  void initState() {
    super.initState();
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
        _databases        = databases;
        _selectedDatabase = defaultDb ?? (databases.isNotEmpty ? databases[0] : null);
        _isLoading        = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading    = false;
      });
    }
  }

  Future<void> _login() async {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    setState(() { _isLoading = true; _errorMessage = null; });

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
        final confirmToken     = responseData['confirmToken'] as String;
        final sessionStartedAt = responseData['sessionStartedAt'] != null
            ? DateTime.tryParse(responseData['sessionStartedAt'].toString())
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
        final confirmData = await authService.confirmLogin(confirmToken, forceLogout: true);
        if (!mounted) return;
        if (confirmData['success'] != true) return;

        final passwordStatus = PasswordStatus.fromJson(confirmData['passwordStatus']
            ?? {'isPasswordExpired': false, 'forceChangePassword': false});
        _navigateAfterLogin(passwordStatus, confirmData);
        return;
      }

      final passwordStatus = PasswordStatus.fromJson(responseData['passwordStatus']);
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

  void _navigateAfterLogin(PasswordStatus passwordStatus, Map<String, dynamic> data) {
    if (passwordStatus.forceChangePassword) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChangePasswordDialog(userId: data['user']['id'], forceChange: true),
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

  @override
  Widget build(BuildContext context) {
    final isEnglish   = context.watch<LanguageProvider>().isEnglish;
    final screenWidth  = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final cardWidth    = screenWidth  * 0.5;
    final cardHeight   = screenHeight * 0.7;

    return Scaffold(
      body: Stack(
        children: [
          // ── Main login card ─────────────────────────────────────────────
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
            width:  cardWidth,
            height: cardHeight,
            child: Card(
              elevation: 8.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Image.asset(
                      'assets/images/ANAN.png',
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 10),
                    const VerticalDivider(color: Colors.grey, thickness: 1),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_person, size: 72, color: Colors.green.shade900),
                          const SizedBox(height: 10),
                          Text(
                            isEnglish ? 'Login' : 'เข้าสู่ระบบ',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: isEnglish ? 'Database' : 'ฐานข้อมูล',
                              border: const OutlineInputBorder(),
                            ),
                            value: _selectedDatabase,
                            items: _databases.map((db) => DropdownMenuItem(
                              value: db,
                              child: Text(db),
                            )).toList(),
                            onChanged: (value) => setState(() => _selectedDatabase = value),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return isEnglish
                                    ? 'Please select a database'
                                    : 'กรุณาเลือกฐานข้อมูล';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _usernameController,
                            autofocus: true,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: isEnglish ? 'Username' : 'ชื่อผู้ใช้งาน',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.person),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _login(),
                            decoration: InputDecoration(
                              labelText: isEnglish ? 'Password' : 'รหัสผ่าน',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.lock),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _isLoading
                              ? const CircularProgressIndicator()
                              : SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.yellow[100],
                                      padding: const EdgeInsets.symmetric(vertical: 15),
                                      textStyle: const TextStyle(fontSize: 18),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8.0),
                                      ),
                                    ),
                                    child: Text(isEnglish ? 'Login' : 'เข้าสู่ระบบ'),
                                  ),
                                ),
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
          // ── Language toggle (top-right) ──────────────────────────────────
          Positioned(
            top: 16,
            right: 16,
            child: Tooltip(
              message: isEnglish ? 'Switch to Thai' : 'สลับเป็นภาษาอังกฤษ',
              child: GestureDetector(
                onTap: context.read<LanguageProvider>().toggle,
                child: Container(
                  padding: const EdgeInsets.all(1.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      isEnglish ? 'ไทย' : 'ENG',
                      style: const TextStyle(color: Colors.orange, fontSize: 16),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
