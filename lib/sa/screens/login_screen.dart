// screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/password_status.dart';
import '../services/auth_service.dart';
import '../widgets/change_password_dialog.dart';
import 'home_screen.dart'; // หน้าหลักหลังจาก login

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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
        _selectedDatabase!
      );
      final passwordStatus =
          PasswordStatus.fromJson(responseData['passwordStatus']);

      if (passwordStatus.forceChangePassword) {
        // บังคับเปลี่ยนรหัสผ่าน
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            // builder: (context) => ChangePasswordDialog(userId: responseData['userId'], forceChange: true),
            builder: (context) => ChangePasswordDialog(userId: responseData['user']['id'], forceChange: true),
          ),
        );
      } else {
        // Login สำเร็จ ไปหน้า Home
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => HomeScreen(
                passwordStatus: passwordStatus), // ส่ง passwordStatus ไป Home
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เข้าสู่ระบบไม่สำเร็จ: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
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
                            const Icon(
                              Icons.lock_person,
                              size: 72,
                              color: Colors.blueAccent,
                            ),
                            const SizedBox(height: 10), //25
                            const Text(
                              'เข้าสู่ระบบ',
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                            ),
                            // Dropdown สำหรับเลือกฐานข้อมูล
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'ฐานข้อมูล',
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
                                  return 'กรุณาเลือกฐานข้อมูล';
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
                                labelText: 'ชื่อผู้ใช้งาน',
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
                                labelText: 'รหัสผ่าน',
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
                                      child: const Text('เข้าสู่ระบบ'),
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
