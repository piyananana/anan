// screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/password_status.dart';
import '../services/auth_service.dart';
import '../widgets/change_password_dialog.dart';
import '../widgets/session_conflict_dialog.dart';
import 'home_screen.dart'; // หน้าหลักหลังจาก login

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
    setState(() {
      _isLoading = true;
    });
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final databases = await authService.fetchDatabases();
      final defaultDb = await authService.getDefaultDatabase();
      if (!mounted) return;
      setState(() {
        _databases = databases;
        _selectedDatabase = defaultDb ?? (databases.isNotEmpty ? databases[0] : null);
        _isLoading = false;
      });
      print('defaultDb = $defaultDb');
      print('_selectedDatabase = $_selectedDatabase');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _login() async {
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

      // มี session เดิม — แสดง dialog ให้เลือก
      if (responseData['requiresConfirmation'] == true) {
        setState(() => _isLoading = false);
        final confirmToken = responseData['confirmToken'] as String;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เข้าสู่ระบบไม่สำเร็จ: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
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
    // กำหนดความกว้างของ Card ให้เป็น 70% ของหน้าจอ
    // เพื่อให้ Card ไม่ใหญ่เกินไปบนหน้าจอ Desktop และ Tablet
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double cardWidth = screenWidth * 0.5; // 70% ของความกว้างหน้าจอ
    final double cardHeight = screenHeight * 0.7; // 70% ของความสูงหน้าจอ

    // สำหรับหน้าจอมือถือ อาจจะใช้ค่าคงที่ หรือ 85-90% ของหน้าจอ
    // if (screenWidth < 600) { // เป็นการเช็คว่าอยู่บนมือถือหรือไม่ (ไม่แม่นยำ 100%)
    //   cardWidth = screenWidth * 0.85;
    // }

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            // <--- เพิ่ม SizedBox ห่อ AspectRatio เพื่อจำกัดความกว้างสูงสุด
            // width: cardWidth > 500
            //     ? 500
            //     : cardWidth, // จำกัดความกว้างสูงสุดที่ 400px
            // หรือใช้ cardWidth ถ้าหน้าจอเล็กกว่า
            // child: AspectRatio(
            //   // <--- ใช้ AspectRatio ห่อ Card
            //   aspectRatio: 1.0, // กำหนดอัตราส่วน 1:1 เพื่อให้เป็นจัตุรัส
            width: cardWidth,
            height: cardHeight,
              child: Card(
                elevation: 8.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                // ไม่ต้องมี margin ที่ Card แล้ว เพราะเราใช้ Padding และ SizedBox/AspectRatio จัดการ
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Image.asset(  
                        'assets/images/ANAN.png',
                        fit: BoxFit.contain,
                        // width: 140,
                        // height: 140,
                      ),
                      const SizedBox(width: 10),
                      const VerticalDivider(
                        color: Colors.grey,
                        thickness: 1,
                      ),
                      const SizedBox(width: 10),
                      // ใช้ Expanded เพื่อให้ TextField กินพื้นที่เท่าที่จำเป็นใน Column
                      // และ Push ปุ่มลงด้านล่าง หากมีพื้นที่เหลือ
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment
                              .center, // จัดกลางแนวตั้งในพื้นที่ Expanded
                          children: [
                            Icon(
                              Icons.lock_person,
                              size: 72,
                              color: Colors.green.shade900,
                            ),
                            const SizedBox(height: 10), //25
                            Text(
                              'เข้าสู่ระบบ (Login)',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade900,
                              ),
                            ),
                            // Dropdown สำหรับเลือกฐานข้อมูล
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'ฐานข้อมูล (Database)',
                                border: OutlineInputBorder(),
                              ),
                              value: _selectedDatabase,
                              items: _databases.map((db) {
                                return DropdownMenuItem(
                                  value: db,
                                  child: Text(db),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedDatabase = value;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'กรุณาเลือกฐานข้อมูล (Please select a database)';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _usernameController,
                              autofocus: true,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'ชื่อผู้ใช้งาน (User Name)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person),
                              ),
                            ),
                            const SizedBox(height: 10), //20
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _login(),
                              decoration: const InputDecoration(
                                labelText: 'รหัสผ่าน (Password)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.lock),
                              ),
                            ),
                            const SizedBox(height: 10), //
                            _isLoading
                                ? const CircularProgressIndicator()
                                : SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _login,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.yellow[100],
                                        padding:
                                            const EdgeInsets.symmetric(vertical: 15),
                                        textStyle: const TextStyle(fontSize: 18),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8.0),
                                        ),
                                      ),
                                      child: const Text('เข้าสู่ระบบ (Login)'),
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
            // ),
          ),
        ),
      ),
    );
  }
}
