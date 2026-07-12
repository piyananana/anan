import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/menu.dart';
import '../models/password_status.dart';
import '../models/user.dart';
import '../services/menu_service.dart';
import '../services/auth_service.dart';
import '../services/language_provider.dart';
import '../utils/menu_scope.dart';
import '../services/inactivity_service.dart';
import '../services/password_policy_service.dart';
import '../widgets/dashboard_widget.dart';
import '../widgets/menu_tree_view.dart';
import '../widgets/change_password_dialog.dart';
import '../widgets/confirm_logout_dialog.dart';
import '../widgets/inactivity_detector.dart';
import 'login_screen.dart';
import 'menu_screen.dart';
import 'user_screen.dart';
import 'user_menu_screen.dart';
import '../../ap/models/ap_payment_run.dart';
import '../../ap/services/ap_payment_run_service.dart';

class HomeScreen extends StatefulWidget {
  final PasswordStatus? passwordStatus; // รับสถานะรหัสผ่านจาก LoginScreen

  const HomeScreen({super.key, this.passwordStatus});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  // ตัวแปรสำหรับจัดการ Tab
  final List<Menu> _openTabs = []; // รายการของ Menu ที่เปิดเป็น Tab
  final Map<int, Widget> _cachedTabWidgets = {}; // cache widget ของแต่ละ tab
  int _currentIndex = 0; // Index ของ Tab ที่กำลัง Active

  List<Menu> _allMenus = [];
  final Map<int, bool> _menuExpandedState = {};
  bool _isLoading = true;
  String _error = '';
  MenuContent? _currentMenuContent;
  User? _currentUser; // เพิ่มตัวแปรเก็บข้อมูลผู้ใช้
  String? _currentDatabase;

  bool _isMenuExpanded = true;
  double _menuPanelCurrentWidth = 280.0;
  bool _isDraggingDivider = false;
  bool _menuWidthInitialized = false;

  final _paymentRunSvc = ApPaymentRunService();
  List<ApPaymentRun> _pendingRuns = [];
  int get _pendingCount => _pendingRuns.length;

  // เพิ่ม TextEditingController สำหรับ Search Bar
  final TextEditingController _searchController = TextEditingController();

  PasswordStatus? _currentPasswordStatus;

  @override
  void initState() {
    super.initState();

    _currentPasswordStatus = widget.passwordStatus;

    final authService = Provider.of<AuthService>(context, listen: false);
    _currentDatabase = authService.selectedDatabase;
    // ดึงข้อมูลผู้ใช้, บริษัท และเมนูจาก AuthService
    _currentUser = authService.currentUser;
    // _company = authService.company;
    // _allMenus = authService.userMenus;

    _loadUserAndMenus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_menuWidthInitialized) {
      _menuPanelCurrentWidth = MediaQuery.of(context).size.width * 0.25;
      _menuWidthInitialized = true;
    }
  }

  @override
  void dispose() {
    InactivityService().stop();
    _searchController.dispose();
    super.dispose();
  }

  // --- Functions for Tab Management ---

  void _openTab(Menu menu) {
    final existingIndex = _openTabs.indexWhere((tab) => tab.id == menu.id);
    if (existingIndex != -1) {
      setState(() => _currentIndex = existingIndex);
    } else {
      setState(() {
        _openTabs.add(menu);
        _currentIndex = _openTabs.length - 1;
      });
    }
  }

  void _closeTab(int index) {
    if (index < 0 || index >= _openTabs.length) return;
    setState(() {
      final menuId = _openTabs[index].id;
      if (menuId != null) _cachedTabWidgets.remove(menuId);
      _openTabs.removeAt(index);
      if (_openTabs.isEmpty) {
        _currentIndex = 0;
      } else {
        int newIndex = _currentIndex;
        if (index <= _currentIndex && _currentIndex > 0) newIndex = _currentIndex - 1;
        _currentIndex = newIndex.clamp(0, _openTabs.length - 1);
      }
    });
  }

  void _reorderTab(int from, int to) {
    if (to == from || to == from + 1) return;
    setState(() {
      final insertAt = to > from ? to - 1 : to;
      final tab = _openTabs.removeAt(from);
      _openTabs.insert(insertAt, tab);
      if (_currentIndex == from) {
        _currentIndex = insertAt;
      } else {
        int adj = _currentIndex;
        if (from < adj) adj--;
        if (insertAt <= adj) adj++;
        _currentIndex = adj.clamp(0, _openTabs.length - 1);
      }
    });
  }

  Future<void> _loadUserAndMenus() async {
    await _fetchUser();
    await _fetchMenus();
    await _startInactivityTimer();
    _loadPendingApprovals();
  }

  Future<void> _loadPendingApprovals() async {
    try {
      final runs = await _paymentRunSvc.fetchMyPending();
      if (mounted) setState(() => _pendingRuns = runs);
    } catch (_) {}
  }

  void _showPendingApprovalsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _PendingApprovalsDialog(
        runs: _pendingRuns,
        svc: _paymentRunSvc,
        onActioned: _loadPendingApprovals,
      ),
    );
  }

  Future<void> _startInactivityTimer() async {
    try {
      final policy = await PasswordPolicyService().getPasswordPolicy();
      InactivityService().configure(policy.sessionTimeoutMinutes);
    } catch (_) {
      InactivityService().configure(5); // fallback default
    }
    InactivityService().start();
  }

  Future<void> _fetchUser() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = await authService.getCurrentUser();
      setState(() {
        _currentUser = user;
      });
    } catch (e) {
      print('Error loading user data: $e');
      // Handle error, e.g., force logout if user data is corrupted
    }
  }

  Future<void> _fetchMenus() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });
      final menus =
          await MenuService().fetchMenuByUserId(_currentUser?.id ?? 0);
      for (var menu in menus) {
        if (menu.menuType == 'folder' && menu.parentId == null) {
          _menuExpandedState.putIfAbsent(menu.id, () => true);
        }
      }
      setState(() {
        _allMenus = menus;
        _isLoading = false;
        _currentMenuContent = null;
      });
      // ไม่ใช่ developer และไม่มีเมนูเลย → แจ้งเตือนแล้วกลับ login
      if (menus.isEmpty && !(_currentUser?.isDeveloper ?? false)) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showNoMenuDialog());
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load menus: $e';
        _isLoading = false;
      });
      if (e.toString().contains('Unauthorized')) {
        _performLogout();
      }
    }
  }

  Future<void> _showNoMenuDialog() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
          SizedBox(width: 8),
          Text('ยังไม่ได้กำหนดสิทธิ์เมนู'),
        ]),
        content: const Text(
          'บัญชีผู้ใช้นี้ยังไม่ได้รับการกำหนดสิทธิ์เมนูใดเลย\n'
          'กรุณาติดต่อผู้ดูแลระบบเพื่อขอสิทธิ์การใช้งาน',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _performLogout();
            },
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperBootstrap(bool isEnglish) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            labelColor: Colors.green.shade900,
            indicatorColor: Colors.green.shade900,
            tabs: [
              Tab(icon: const Icon(Icons.menu_book_outlined),   text: isEnglish ? 'Menu Management'       : 'จัดการเมนู'),
              Tab(icon: const Icon(Icons.people_outline),        text: isEnglish ? 'User Management'       : 'จัดการผู้ใช้'),
              Tab(icon: const Icon(Icons.manage_accounts_outlined), text: isEnglish ? 'User Menu Permissions' : 'สิทธิ์เมนูผู้ใช้'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                MenuScreen(onMenusChanged: _fetchMenus, onExit: _onExitContent),
                const UserScreen(),
                const UserMenuScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onMenuSelected(Menu menu) async {
    if (_currentMenuContent?.menuName == menu.menuName) {
      // ถ้าเลือกเมนูเดิม ไม่ต้องทำอะไร
      return;
    }

    _openTab(menu); // เปิด Tab ใหม่สำหรับเมนูที่เลือก

    setState(() {
      _searchController.text =
          menu.targetPath ?? ''; // แสดงชื่อ widget ในช่องค้นหา
      // leftPanelWidth = 0.06;
    });
    try {
      final content = await Provider.of<MenuService>(context, listen: false)
          .fetchMenuContent(menu.id);
      setState(() {
        _currentMenuContent = content;
      });
    } catch (e) {
      setState(() {
        _currentMenuContent = MenuContent(
            menuName: menu.menuName,
            menuType: menu.menuType,
            contentData: 'Error loading content: $e');
      });
      if (e.toString().contains('Unauthorized')) {
        _performLogout(); // บังคับ logout
      }
    }
  }

  void _onSearchSubmitted(String targetPath) async {
    setState(() {
      _currentMenuContent = null;
      // leftPanelWidth = 0.06; // <-- กำหนดค่าเริ่มต้นของ panel ซ้าย
    });
  }

  void _toggleMenuSize() {
    setState(() {
      _isMenuExpanded = !_isMenuExpanded;
    });
  }

  // --- NEW: Callback สำหรับออกจาก Content ---
  void _onExitContent() {
    setState(() {
      _currentMenuContent = null;
      _searchController.clear(); // <-- เคลียร์ search controller เมื่อเลือกเมนู
      // หากต้องการให้ panel ซ้ายกลับมาขนาดปกติเมื่อออกจากหน้าจัดการเมนู:
      // _leftPanelWeightNotifier.value = _initialLeftPanelWeight;
      // หรือหากต้องการให้มันยังคงย่ออยู่: ไม่ต้องทำอะไรตรงนี้
      // leftPanelWidth = 0.3; // <-- กำหนดค่าเริ่มต้นของ panel ซ้าย
    });
  }

  // *** ฟังก์ชันสำหรับ Logout ***
  Future<void> _performLogout() async {
    InactivityService().stop();
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  // *** ฟังก์ชันสำหรับแสดง Dialog เปลี่ยนรหัสผ่าน ***
  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ChangePasswordDialog(
          userId: _currentUser!.id,
          // onChangePassword: (currentPassword, newPassword) async {
          //   final authService =
          //       Provider.of<AuthService>(context, listen: false);
          //   try {
          //     await authService.changePassword(
          //         _currentUser!.id, currentPassword, newPassword);
          //     // แสดง SnackBar เมื่อเปลี่ยนรหัสผ่านสำเร็จ
          //     if (mounted) {
          //       ScaffoldMessenger.of(context).showSnackBar(
          //         const SnackBar(content: Text('เปลี่ยนรหัสผ่านสำเร็จ')),
          //       );
          //     }
          //   } catch (e) {
          //     // Error ถูกจัดการใน ChangePasswordDialog แล้ว
          //     rethrow; // โยน Error กลับไปให้ dialog จัดการแสดงผล
          //   }
          // },
        );
      },
    ).then((result) {
      if (result == true) {
        // หากเปลี่ยนรหัสผ่านสำเร็จ (callback return true)
        // อาจจะไม่ต้องทำอะไร หรือ refresh token / force relogin (ขึ้นอยู่กับ backend)
        // สำหรับตัวอย่างนี้ สมมติว่าสำเร็จแล้ว
      }
    });
  }

  // *** ฟังก์ชันสำหรับแสดง Dialog ยืนยัน Logout ***
  void _showConfirmLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const ConfirmLogoutDialog();
      },
    ).then((confirmed) {
      if (confirmed == true) {
        _performLogout();
      }
    });
  }

  // ฟังก์ชันสำหรับสร้างแถบแจ้งเตือนรหัสผ่าน
  Widget _buildPasswordExpirationBanner(BuildContext context, bool isEnglish) {
    if (_currentPasswordStatus == null) return const SizedBox.shrink();

    String message = '';
    Color backgroundColor = Colors.amber;

    if (_currentPasswordStatus!.isPasswordExpired) {
      message = isEnglish
          ? 'Your password has expired! Please change it immediately.'
          : 'รหัสผ่านของคุณหมดอายุแล้ว! กรุณาเปลี่ยนรหัสผ่านทันที';
      backgroundColor = Colors.red.shade700;
    } else if (_currentPasswordStatus!.daysUntilExpiration != null &&
        _currentPasswordStatus!.daysUntilExpiration! > 0) {
      message = isEnglish
          ? 'Your password will expire in ${_currentPasswordStatus!.daysUntilExpiration} days'
          : 'รหัสผ่านของคุณจะหมดอายุในอีก ${_currentPasswordStatus!.daysUntilExpiration} วัน';
      backgroundColor = Colors.orange.shade700;
    } else {
      return const SizedBox.shrink();
    }

    return MaterialBanner(
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.white, size: 30),
          Text(
            message,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      // leading: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 30),
      backgroundColor: backgroundColor,
      actions: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton(
            onPressed: () async {
              // ไปหน้าเปลี่ยนรหัสผ่าน
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ChangePasswordDialog(
                    userId: _currentUser!.id,
                  ),
                ),
              );
              // หลังจากกลับมาจากการเปลี่ยนรหัสผ่าน อาจจะต้องเรียก API เพื่ออัปเดตสถานะรหัสผ่านอีกครั้ง
              // หรือ Login ใหม่อีกครั้งเพื่อรับสถานะล่าสุด (แล้วแต่การออกแบบ)
              // สำหรับตัวอย่างนี้ อาจจะแค่ปิด Banner
              setState(() {
                _currentPasswordStatus = null; // ซ่อน Banner หลังคลิก
              });
            },
            child: Text(isEnglish ? 'Change Password' : 'เปลี่ยนรหัสผ่าน',
                style: const TextStyle(color: Colors.white)),
          ),
          widget.passwordStatus!.forceChangePassword
              ? const SizedBox.shrink()
              : TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                    setState(() {
                      _currentPasswordStatus = null;
                    });
                  },
                  child: Text(isEnglish ? 'Dismiss' : 'ปิด',
                      style: const TextStyle(color: Colors.white)),
                ),
        ]),
      ],
      // For persistent banner, you might not want to automatically dismiss
      forceActionsBelow: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  @override
  Widget build(BuildContext context) {
    
    // ใช้ Consumer เพื่อ rebuild เฉพาะ AppBar เมื่อข้อมูลเปลี่ยน
    return Consumer2<AuthService, LanguageProvider>(
      builder: (context, authService, lang, child) {
        final currentCompany = authService.company;
        return Scaffold(
          bottomNavigationBar: _buildPasswordExpirationBanner(context, lang.isEnglish),
          appBar: AppBar(
            // title: const Text('ANAN System'),
            title: Row(
              children: [
                const SizedBox(width: 15), // ช่องว่างด้านซ้าย
                // แสดงโลโก้บริษัท ถ้ามี
                if (currentCompany?.logoUrl != null &&
                    currentCompany!.logoUrl!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(1.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.yellow), // สีขอบเริ่มต้น
                      borderRadius:
                          BorderRadius.circular(6.0), // กำหนดความโค้งของขอบ
                      color: Colors.white,
                    ),
                    child: Image.network(
                      currentCompany.logoUrl!,
                      fit: BoxFit.contain,
                      width: 40,
                      height: 40,
                      errorBuilder: (context, error, stackTrace) {
                        print('Error loading image: $error');
                        return const Icon(Icons.business);
                      },
                    ),
                  ),
                const SizedBox(width: 8), // ช่องว่าง
                // แสดงชื่อบริษัท ถ้ามี
                Text(
                  lang.isEnglish
                      ? (currentCompany?.englishName?.isNotEmpty == true
                          ? currentCompany!.englishName!
                          : currentCompany?.thaiName ?? '** No Company **')
                      : (currentCompany?.thaiName ?? '** ไม่มีชื่อบริษัท **'),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade900,
            foregroundColor: Colors.yellow,
            actions: [
              // แสดงชื่อและนามสกุลผู้ใช้
              Container(
                padding: const EdgeInsets.all(1.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.yellow), // สีขอบเริ่มต้น
                  borderRadius:
                      BorderRadius.circular(6.0), // กำหนดความโค้งของขอบ
                ),
                child: Text(
                  ' ${_currentUser?.firstName ?? ''} ${_currentUser?.lastName ?? ''} ',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.yellow, // สีเหลือง
                    fontSize: 18,
                    // fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8), // ช่องว่าง
              // แสดงชื่อฐานข้อมูลที่เลือก
              Container(
                padding: const EdgeInsets.all(1.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.yellow), // สีขอบเริ่มต้น
                  borderRadius:
                      BorderRadius.circular(6.0), // กำหนดความโค้งของขอบ
                ),
                child: Text(
                  _currentDatabase!.isNotEmpty
                      ? ' $_currentDatabase '
                      : ' N/A ',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.yellow, // สีเหลือง
                    fontSize: 18,
                    // fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // ── Language toggle ───────────────────────────────────────
              Tooltip(
                message: lang.isEnglish ? 'Switch to Thai' : 'สลับเป็นภาษาอังกฤษ',
                child: GestureDetector(
                  onTap: lang.toggle,
                  child: Container(
                    padding: const EdgeInsets.all(1.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(6.0),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        lang.isEnglish ? 'ไทย' : 'ENG',
                        style: const TextStyle(color: Colors.orange, fontSize: 16,),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // ── Pending approvals bell ────────────────────────────────
              Tooltip(
                message: lang.isEnglish
                    ? 'Pending Approvals${_pendingCount > 0 ? ' ($_pendingCount)' : ''}'
                    : 'รายการรออนุมัติ${_pendingCount > 0 ? ' ($_pendingCount)' : ''}',
                child: GestureDetector(
                onTap: _showPendingApprovalsDialog,
                child: Container(
                  padding: const EdgeInsets.all(1.0),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: _pendingCount > 0 ? Colors.red : Colors.orange),
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.notifications_outlined,
                            color: Colors.orange),
                      ),
                      if (_pendingCount > 0)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                                minWidth: 16, minHeight: 16),
                            child: Text(
                              '$_pendingCount',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              ), // end Tooltip (bell)
              const SizedBox(width: 8),
              // ── เปลี่ยนรหัสผ่าน ───────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(1.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: IconButton(
                  icon: const Icon(Icons.password_outlined, color: Colors.orange),
                  onPressed: _showChangePasswordDialog,
                  tooltip: lang.isEnglish ? 'Change Password' : 'เปลี่ยนรหัสผ่าน',
                ),
              ),
              const SizedBox(width: 8), // ช่องว่าง
              // ปุ่ม Logout
              Container(
                padding: const EdgeInsets.all(1.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.orange), // สีขอบเริ่มต้น
                  borderRadius:
                      BorderRadius.circular(6.0), // กำหนดความโค้งของขอบ
                ),
                child: IconButton(
                  icon: const Icon(Icons.logout_outlined, color: Colors.orange),
                  onPressed: _showConfirmLogoutDialog,
                  tooltip: lang.isEnglish ? 'Logout' : 'ออกจากระบบ',
                ),
              ),
              const SizedBox(width: 8), // เพื่อให้มีพื้นที่ขอบขวาเล็กน้อย
            ],
          ),
          body: InactivityDetector(child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error.isNotEmpty
                  ? Center(child: Text('Error: $_error'))
                  : _allMenus.isEmpty && (_currentUser?.isDeveloper ?? false)
                      ? _buildDeveloperBootstrap(lang.isEnglish)
                      : _allMenus.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Toggle button — fixed width, always same element
                            Container(
                              width: 40,
                              color: Colors.green.shade900,
                              child: IconButton(
                                icon: Icon(
                                  _isMenuExpanded
                                      ? Icons.menu_open_rounded
                                      : Icons.menu_rounded,
                                  color: Colors.orange,
                                ),
                                onPressed: _toggleMenuSize,
                                tooltip: _isMenuExpanded
                                    ? (lang.isEnglish ? 'Collapse Menu' : 'ย่อช่องเมนู')
                                    : (lang.isEnglish ? 'Expand Menu' : 'ขยายช่องเมนู'),
                              ),
                            ),
                            // Menu panel — animated width, always mounted
                            AnimatedContainer(
                              duration: _isDraggingDivider
                                  ? Duration.zero
                                  : const Duration(milliseconds: 200),
                              width: _isMenuExpanded ? _menuPanelCurrentWidth : 0,
                              child: ClipRect(
                                child: OverflowBox(
                                  // Always give MenuTreeView at least 280px so nested
                                  // items never overflow regardless of panel width
                                  maxWidth: _menuPanelCurrentWidth < 280.0
                                      ? 280.0
                                      : _menuPanelCurrentWidth,
                                  minWidth: _menuPanelCurrentWidth < 280.0
                                      ? 280.0
                                      : _menuPanelCurrentWidth,
                                  alignment: Alignment.topLeft,
                                  child: Container(
                                    color: Colors.blueGrey[200],
                                    child: MenuTreeView(
                                      menus: _allMenus,
                                      onMenuSelected: _onMenuSelected,
                                      onSearchSubmitted: _onSearchSubmitted,
                                      onRefreshMenus: _fetchMenus,
                                      searchController: _searchController,
                                      expandedState: _menuExpandedState,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Draggable divider
                            if (_isMenuExpanded)
                              MouseRegion(
                                cursor: SystemMouseCursors.resizeColumn,
                                child: GestureDetector(
                                  onHorizontalDragStart: (_) =>
                                      setState(() => _isDraggingDivider = true),
                                  onHorizontalDragUpdate: (details) {
                                    setState(() {
                                      _menuPanelCurrentWidth =
                                          (_menuPanelCurrentWidth +
                                                  details.delta.dx)
                                              .clamp(100.0, 800.0);
                                    });
                                  },
                                  onHorizontalDragEnd: (_) =>
                                      setState(() => _isDraggingDivider = false),
                                  child: Container(
                                    width: 5,
                                    color: Colors.blueGrey[400],
                                  ),
                                ),
                              ),
                            // Right panel — always Expanded, element is never recreated
                            Expanded(
                              child: Column(
                                children: [
                                  _CustomTabBar(
                                    tabs: _openTabs,
                                    currentIndex: _currentIndex,
                                    isEnglish: lang.isEnglish,
                                    onSelect: (i) => setState(() => _currentIndex = i),
                                    onClose: _closeTab,
                                    onMove: _reorderTab,
                                  ),
                                  Expanded(
                                    child: _openTabs.isEmpty
                                        ? const DashboardWidget()
                                        : IndexedStack(
                                            index: _currentIndex,
                                            children:
                                                _openTabs.map((menu) {
                                              final id = menu.id ?? 0;
                                              return _cachedTabWidgets
                                                  .putIfAbsent(
                                                id,
                                                () => KeyedSubtree(
                                                  key: ValueKey(id),
                                                  child: MenuScope(
                                                    menu: menu,
                                                    child: menu.builder(context),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )),
        );
      },
    );
  }

}

// ── Custom Tab Bar ────────────────────────────────────────────────────────────

class _CustomTabBar extends StatefulWidget {
  final List<Menu> tabs;
  final int currentIndex;
  final bool isEnglish;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onClose;
  final void Function(int from, int to) onMove;

  const _CustomTabBar({
    required this.tabs,
    required this.currentIndex,
    required this.isEnglish,
    required this.onSelect,
    required this.onClose,
    required this.onMove,
  });

  @override
  State<_CustomTabBar> createState() => _CustomTabBarState();
}

class _CustomTabBarState extends State<_CustomTabBar> {
  final ScrollController _scroll = ScrollController();
  bool _showLeft = false;
  bool _showRight = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateArrows);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
  }

  @override
  void didUpdateWidget(_CustomTabBar old) {
    super.didUpdateWidget(old);
    if (widget.tabs.length > old.tabs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        }
        _updateArrows();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_updateArrows);
    _scroll.dispose();
    super.dispose();
  }

  void _updateArrows() {
    if (!_scroll.hasClients || !mounted) return;
    setState(() {
      _showLeft = _scroll.offset > 0;
      _showRight = _scroll.offset < _scroll.position.maxScrollExtent - 0.5;
    });
  }

  void _scrollBy(double delta) {
    final target = (_scroll.offset + delta).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  void _scrollToTab(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      const tabW = 160.0;
      final left = index * tabW;
      final right = left + tabW;
      if (left < _scroll.offset) {
        _scroll.animateTo(left, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      } else if (right > _scroll.offset + _scroll.position.viewportDimension) {
        _scroll.animateTo(right - _scroll.position.viewportDimension,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tabs.isEmpty) return const SizedBox.shrink();

    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) { _updateArrows(); return false; },
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // leading drop zone (index 0)
                    _DropZone(dropIndex: 0, onMove: widget.onMove),
                    for (int i = 0; i < widget.tabs.length; i++) ...[
                      Draggable<int>(
                        data: i,
                        feedback: Material(
                          elevation: 4,
                          child: _TabItemContent(
                            label: widget.tabs[i].localName(widget.isEnglish),
                            isActive: i == widget.currentIndex,
                            onClose: null,
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: _TabItemContent(
                            label: widget.tabs[i].localName(widget.isEnglish),
                            isActive: i == widget.currentIndex,
                            onClose: null,
                          ),
                        ),
                        child: GestureDetector(
                          onTap: () {
                            widget.onSelect(i);
                            _scrollToTab(i);
                          },
                          child: _TabItemContent(
                            label: widget.tabs[i].localName(widget.isEnglish),
                            isActive: i == widget.currentIndex,
                            onClose: () => widget.onClose(i),
                          ),
                        ),
                      ),
                      // drop zone after each tab (index i+1)
                      _DropZone(dropIndex: i + 1, onMove: widget.onMove),
                    ],
                  ],
                ),
              ),
            ),
            if (_showLeft || _showRight) ...[
              _TabArrowButton(
                icon: Icons.arrow_left,
                enabled: _showLeft,
                onTap: () => _scrollBy(-160),
              ),
              _TabArrowButton(
                icon: Icons.arrow_right,
                enabled: _showRight,
                onTap: () => _scrollBy(160),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DropZone extends StatefulWidget {
  final int dropIndex;
  final void Function(int from, int to) onMove;
  const _DropZone({required this.dropIndex, required this.onMove});

  @override
  State<_DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<_DropZone> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        setState(() => _hovering = true);
        return true;
      },
      onLeave: (_) => setState(() => _hovering = false),
      onAcceptWithDetails: (details) {
        setState(() => _hovering = false);
        widget.onMove(details.data, widget.dropIndex);
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: _hovering ? 6 : 2,
          height: 46,
          color: _hovering ? Colors.deepOrange : Colors.transparent,
        );
      },
    );
  }
}

class _TabItemContent extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback? onClose;

  const _TabItemContent({
    required this.label,
    required this.isActive,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(
            color: isActive ? Colors.deepOrange : Colors.transparent,
            width: 2,
          ),
          right: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.deepOrange.shade900 : Colors.black54,
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (onClose != null) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(10),
              child: const Icon(Icons.close, size: 16, color: Colors.black45),
            ),
          ],
        ],
      ),
    );
  }
}

class _TabArrowButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _TabArrowButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28,
        height: 46,
        color: Colors.grey.shade100,
        child: Icon(
          icon,
          size: 20,
          color: enabled ? Colors.black54 : Colors.grey.shade300,
        ),
      ),
    );
  }
}

// ── Pending Approvals Dialog ──────────────────────────────────────────────────
class _PendingApprovalsDialog extends StatefulWidget {
  final List<ApPaymentRun> runs;
  final ApPaymentRunService svc;
  final VoidCallback onActioned;

  const _PendingApprovalsDialog({
    required this.runs,
    required this.svc,
    required this.onActioned,
  });

  @override
  State<_PendingApprovalsDialog> createState() =>
      _PendingApprovalsDialogState();
}

class _PendingApprovalsDialogState extends State<_PendingApprovalsDialog> {
  late List<ApPaymentRun> _runs;
  bool _busy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _runs = List.of(widget.runs);
  }

  Future<void> _act(ApPaymentRun run, bool approve) async {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    final remarksCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve
            ? (isEnglish ? 'Approve Payment Run' : 'อนุมัติ Payment Run')
            : (isEnglish ? 'Reject Payment Run'  : 'ปฏิเสธ Payment Run')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${isEnglish ? 'No.' : 'เลขที่'}: ${run.runNumber ?? '-'}'),
            const SizedBox(height: 12),
            TextField(
              controller: remarksCtrl,
              decoration: InputDecoration(
                labelText: isEnglish ? 'Remarks' : 'หมายเหตุ',
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isEnglish ? 'Cancel' : 'ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: approve
                ? null
                : ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(approve
                ? (isEnglish ? 'Approve' : 'อนุมัติ')
                : (isEnglish ? 'Reject'  : 'ปฏิเสธ')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() { _busy = true; _err = null; });
    try {
      final remarks = remarksCtrl.text.trim();
      if (approve) {
        await widget.svc.approveRun(run.id!, remarks: remarks.isEmpty ? null : remarks);
      } else {
        await widget.svc.rejectRun(run.id!, remarks: remarks.isEmpty ? null : remarks);
      }
      setState(() => _runs.removeWhere((r) => r.id == run.id));
      widget.onActioned();
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final fmt = (DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final numFmt = (double v) =>
        v.toStringAsFixed(2).replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.notifications_active, color: Colors.orange),
        const SizedBox(width: 8),
        Text(isEnglish ? 'Pending Approvals' : 'รายการรออนุมัติ'),
        const Spacer(),
        Text('(${_runs.length})', style: const TextStyle(color: Colors.grey)),
      ]),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 600,
        child: _runs.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                      isEnglish ? 'No pending approvals' : 'ไม่มีรายการรออนุมัติ',
                      style: const TextStyle(color: Colors.grey)),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_err != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        border: Border.all(color: Colors.red),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_err!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  // Header row
                  Container(
                    color: Colors.blueGrey[100],
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    child: Row(children: [
                      SizedBox(
                          width: 140,
                          child: Text(isEnglish ? 'Run No.' : 'เลขที่',
                              style: const TextStyle(fontWeight: FontWeight.bold))),
                      SizedBox(
                          width: 100,
                          child: Text(isEnglish ? 'Date' : 'วันที่',
                              style: const TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(
                          child: Text(isEnglish ? 'Description' : 'รายละเอียด',
                              style: const TextStyle(fontWeight: FontWeight.bold))),
                      SizedBox(
                          width: 110,
                          child: Text(isEnglish ? 'Amount' : 'จำนวนเงิน',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontWeight: FontWeight.bold))),
                      const SizedBox(width: 180),
                    ]),
                  ),
                  const Divider(height: 1),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _runs.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final run = _runs[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          child: Row(children: [
                            SizedBox(
                              width: 140,
                              child: Text(run.runNumber ?? '-',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500)),
                            ),
                            SizedBox(
                              width: 100,
                              child: Text(fmt(run.runDate)),
                            ),
                            Expanded(
                              child: Text(
                                run.description ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(
                              width: 110,
                              child: Text(
                                numFmt(run.totalAmountLc),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 172,
                              child: _busy
                                  ? const Center(
                                      child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child:
                                              CircularProgressIndicator(
                                                  strokeWidth: 2)))
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () =>
                                              _act(run, true),
                                          icon: const Icon(
                                              Icons.check_circle_outline,
                                              size: 14),
                                          label: Text(isEnglish ? 'Approve' : 'อนุมัติ'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.green[700],
                                            foregroundColor: Colors.white,
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4),
                                            minimumSize: Size.zero,
                                            tapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        ElevatedButton.icon(
                                          onPressed: () =>
                                              _act(run, false),
                                          icon: const Icon(
                                              Icons.cancel_outlined,
                                              size: 14),
                                          label: Text(isEnglish ? 'Reject' : 'ปฏิเสธ'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red[700],
                                            foregroundColor: Colors.white,
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4),
                                            minimumSize: Size.zero,
                                            tapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ]),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(isEnglish ? 'Close' : 'ปิด'),
        ),
      ],
    );
  }
}
