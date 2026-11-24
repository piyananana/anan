import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sa_menu.dart';
import '../../cd/services/cd_currency_service.dart';
import '../models/sa_password_status.dart';
import '../models/sa_user.dart';
import '../services/sa_menu_service.dart';
import '../services/sa_auth_service.dart';
import '../services/sa_language_provider.dart';
import '../utils/sa_menu_scope.dart';
import '../services/sa_inactivity_service.dart';
import '../services/sa_password_policy_service.dart';
import 'package:flutter/services.dart';
import '../services/sa_favorite_menu_service.dart';
import '../services/sa_login_branding_service.dart';
import '../widgets/sa_home_page.dart';
import '../widgets/sa_home_sidebar.dart';
import '../widgets/sa_home_theme.dart';
import '../widgets/sa_change_password_dialog.dart';
import '../widgets/sa_confirm_logout_dialog.dart';
import '../widgets/sa_inactivity_detector.dart';
import '../widgets/sa_font_size_button.dart';
import 'sa_login_screen.dart';
import 'sa_menu_screen.dart';
import 'sa_user_screen.dart';
import 'sa_user_menu_screen.dart';
import '../models/sa_pending_approval.dart';
import '../services/sa_pending_approval_service.dart';
import '../../ap/screens/ap_payment_run_screen.dart';
import '../../ar/screens/ar_transaction_screen.dart';
import '../../im/screens/im_transaction_screen.dart';
import '../../ap/screens/ap_transaction_screen.dart';
import '../../po/screens/po_pr_transaction_screen.dart';
import '../../po/screens/po_transaction_screen.dart';
import '../../so/screens/so_transaction_screen.dart';
import '../../im/screens/im_price_change_screen.dart';
import '../../im/screens/im_stock_count_summary_screen.dart';
import '../../mo/screens/mo_header_screen.dart';
import '../../gl/screens/gl_period_screen.dart';
import '../../so/screens/so_quote_transaction_screen.dart';

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
  bool _showHome = true; // แท็บ "หน้าแรก" — แท็บอื่นยังเปิดค้าง (คงสถานะ) อยู่ด้านหลัง

  List<Menu> _allMenus = [];
  HomeMenuIndex? _menuIndex; // โครงสร้างเมนู (ลูก/เส้นทาง/โมดูล) สำหรับแถบซ้ายและเส้นทางบนแถบบน
  final Map<int, bool> _menuExpandedState = {};
  bool _isLoading = true;
  String _error = '';
  MenuContent? _currentMenuContent;
  User? _currentUser; // เพิ่มตัวแปรเก็บข้อมูลผู้ใช้
  String? _currentDatabase;

  bool _isMenuExpanded = true; // false = แถบซ้ายย่อเหลือป้ายรหัสโมดูล
  double _menuPanelCurrentWidth = 280.0;
  bool _isDraggingDivider = false;
  bool _menuWidthInitialized = false;

  final _pendingApprovalSvc = PendingApprovalService();
  List<PendingApprovalItem> _pendingItems = [];
  int get _pendingCount => _pendingItems.length;

  // เมนูโปรดของผู้ใช้ (เก็บใน sa_user_favorite_menu)
  final _favoriteSvc = FavoriteMenuService();
  List<int> _favoriteIds = [];
  List<Menu> get _favoriteMenus =>
      _menuIndex == null ? const [] : [for (final id in _favoriteIds) if (_menuIndex!.byId[id] != null) _menuIndex!.byId[id]!];

  // ช่องค้นหาเมนูบนแถบซ้าย (Ctrl+K)
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  PasswordStatus? _currentPasswordStatus;

  @override
  void initState() {
    super.initState();

    _currentPasswordStatus = widget.passwordStatus;

    final authService = Provider.of<AuthService>(context, listen: false);
    _currentDatabase = authService.selectedDatabase;
    // ดึงข้อมูลผู้ใช้, บริษัท และเมนูจาก AuthService
    _currentUser = authService.currentUser;

    _loadUserAndMenus();
    // สกุลเงินหลักของฐานข้อมูลที่เข้าใช้งาน (CurrencyService.baseCode) — ล้างของฐานข้อมูลก่อนหน้าแล้วโหลดใหม่
    final currencyService = CurrencyService()..clearBaseCurrencyCache();
    currencyService.getBaseCurrencyCode();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  // Ctrl+K (หรือ ⌘K) = ไปที่ช่องค้นหาเมนู จากทุกหน้า
  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent || e.logicalKey != LogicalKeyboardKey.keyK) return false;
    final kb = HardwareKeyboard.instance;
    if (!(kb.isControlPressed || kb.isMetaPressed) || _menuIndex == null || !mounted) return false;
    if (!_isMenuExpanded) setState(() => _isMenuExpanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
      _searchController.selection = TextSelection(baseOffset: 0, extentOffset: _searchController.text.length);
    });
    return true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_menuWidthInitialized) {
      _menuPanelCurrentWidth = (MediaQuery.of(context).size.width * 0.2).clamp(240.0, 320.0);
      _menuWidthInitialized = true;
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    InactivityService().stop();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // --- เมนูโปรด ---
  Future<void> _loadFavorites() async {
    try {
      final ids = await _favoriteSvc.fetch();
      if (mounted) setState(() => _favoriteIds = ids);
    } catch (_) {}
  }

  Future<void> _toggleFavorite(Menu menu) async {
    final before = List<int>.from(_favoriteIds);
    setState(() {
      if (_favoriteIds.contains(menu.id)) {
        _favoriteIds.remove(menu.id);
      } else {
        _favoriteIds.add(menu.id);
      }
    });
    try {
      await _favoriteSvc.save(_favoriteIds);
    } catch (e) {
      if (!mounted) return;
      setState(() => _favoriteIds = before);
      final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEnglish ? 'Could not save favorites: $e' : 'บันทึกเมนูโปรดไม่สำเร็จ: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  // --- Functions for Tab Management ---

  void _openTab(Menu menu) {
    final existingIndex = _openTabs.indexWhere((tab) => tab.id == menu.id);
    setState(() {
      if (existingIndex != -1) {
        _currentIndex = existingIndex;
      } else {
        _openTabs.add(menu);
        _currentIndex = _openTabs.length - 1;
      }
      _showHome = false;
    });
  }

  Menu? _findMenuByTargetPath(List<Menu> menus, String targetPath) {
    for (final m in menus) {
      if (m.targetPath == targetPath) return m;
      final found = _findMenuByTargetPath(m.children, targetPath);
      if (found != null) return found;
    }
    return null;
  }

  // เปิดหน้าจอที่จะทำอนุมัติของรายการรออนุมัติหนึ่งรายการ ตรงไปที่แท็บรายละเอียด/บันทึกนั้นเลย โดยไม่ต้องเลือกเมนู
  // เองจาก panel ซ้าย — บังคับสร้าง widget ใหม่ (ไม่ใช้ menu.builder เดิมที่ cache ไว้แบบไม่มีพารามิเตอร์) เพื่อส่ง
  // id ของรายการที่ต้องเปิดตรงเข้าไปได้
  void _openPendingApprovalTarget(PendingApprovalItem item) {
    final menu = _findMenuByTargetPath(_allMenus, item.targetPath);
    if (menu == null) {
      final isEnglish =
          Provider.of<LanguageProvider>(context, listen: false).isEnglish;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEnglish
            ? 'You do not have access to this menu'
            : 'ไม่มีสิทธิ์เข้าถึงเมนูนี้'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    final id = menu.id ?? 0;
    Widget target;
    switch (item.targetPath) {
      case 'PrTransactionScreen':
        target = PrTransactionScreen(initialDetailId: item.id);
        break;
      case 'PoTransactionScreen':
        target = PoTransactionScreen(initialDetailId: item.id);
        break;
      case 'SoTransactionScreen':
        target = SoTransactionScreen(initialDetailId: item.id);
        break;
      case 'ImPriceChangeScreen':
        target = ImPriceChangeScreen(
            onFieldsChanged: () {}, initialDetailId: item.id);
        break;
      case 'ImStockCountSummaryScreen':
        target = ImStockCountSummaryScreen(initialCountId: item.id);
        break;
      case 'MoHeaderScreen':
        target = MoHeaderScreen(initialDetailId: item.id);
        break;
      case 'PeriodScreen':
        target =
            PeriodScreen(onFieldsChanged: () {}, initialFiscalYearId: item.id);
        break;
      case 'QuoteTransactionScreen':
        target = QuoteTransactionScreen(initialDetailId: item.id);
        break;
      case 'ApTransactionScreen':
        target = ApTransactionScreen(initialDetailId: item.id);
        break;
      case 'ApPaymentRunScreen':
        target = ApPaymentRunScreen(initialRunId: item.id);
        break;
      case 'ArTransactionScreen':
        target = ArTransactionScreen(initialDetailId: item.id);
        break;
      case 'ImTransactionScreen':
        target = ImTransactionScreen(initialDetailId: item.id);
        break;
      default:
        target = menu.builder(context);
    }
    setState(() {
      _cachedTabWidgets[id] = KeyedSubtree(
        key: ValueKey('${id}_pending_${item.module}_${item.id}'),
        child: MenuScope(menu: menu, child: target),
      );
      final existingIndex = _openTabs.indexWhere((tab) => tab.id == id);
      if (existingIndex != -1) {
        _currentIndex = existingIndex;
      } else {
        _openTabs.add(menu);
        _currentIndex = _openTabs.length - 1;
      }
      _showHome = false;
    });
  }

  void _closeTab(int index) {
    if (index < 0 || index >= _openTabs.length) return;
    setState(() {
      final menuId = _openTabs[index].id;
      if (menuId != null) _cachedTabWidgets.remove(menuId);
      _openTabs.removeAt(index);
      if (_openTabs.isEmpty) {
        _currentIndex = 0;
        _showHome = true;
      } else {
        int newIndex = _currentIndex;
        if (index <= _currentIndex && _currentIndex > 0)
          newIndex = _currentIndex - 1;
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
    _loadFavorites();
    // โลโก้ระบบ (ใช้แทนโลโก้บริษัทที่แถบซ้ายเมื่อบริษัทไม่มีโลโก้)
    _loadSystemLogo();
  }

  Future<void> _loadSystemLogo() async {
    try {
      await LoginBrandingService().fetch();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _loadPendingApprovals() async {
    try {
      final items = await _pendingApprovalSvc.fetchAll();
      if (mounted) setState(() => _pendingItems = items);
    } catch (_) {}
  }

  Future<void> _showPendingApprovalsDialog() async {
    await _loadPendingApprovals(); // เอาข้อมูลล่าสุดทุกครั้งที่กดกระดิ่ง เผื่อมีรายการใหม่/ถูกอนุมัติไปแล้วจากที่อื่น
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => _PendingApprovalsDialog(
        items: _pendingItems,
        onCardTap: (item) {
          Navigator.of(ctx).pop();
          _openPendingApprovalTarget(item);
        },
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
      setState(() {
        _allMenus = menus;
        _menuIndex = HomeMenuIndex(menus);
        _isLoading = false;
        _currentMenuContent = null;
      });
      // ไม่ใช่ developer และไม่มีเมนูเลย → แจ้งเตือนแล้วกลับ login
      if (menus.isEmpty && !(_currentUser?.isDeveloper ?? false)) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _showNoMenuDialog());
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
    final isEnglish =
        Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.orange, size: 28),
          const SizedBox(width: 8),
          Text(isEnglish
              ? 'No Menu Permissions Assigned'
              : 'ยังไม่ได้กำหนดสิทธิ์เมนู'),
        ]),
        content: Text(
          isEnglish
              ? 'This user account has not been assigned any menu permissions yet.\n'
                  'Please contact the system administrator to request access.'
              : 'บัญชีผู้ใช้นี้ยังไม่ได้รับการกำหนดสิทธิ์เมนูใดเลย\n'
                  'กรุณาติดต่อผู้ดูแลระบบเพื่อขอสิทธิ์การใช้งาน',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _performLogout();
            },
            child: Text(isEnglish ? 'OK' : 'ตกลง'),
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
              Tab(
                  icon: const Icon(Icons.menu_book_outlined),
                  text: isEnglish ? 'Menu Management' : 'จัดการเมนู'),
              Tab(
                  icon: const Icon(Icons.people_outline),
                  text: isEnglish ? 'User Management' : 'จัดการผู้ใช้'),
              Tab(
                  icon: const Icon(Icons.manage_accounts_outlined),
                  text:
                      isEnglish ? 'User Menu Permissions' : 'สิทธิ์เมนูผู้ใช้'),
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
    // เปิดแท็บ (หรือสลับไปแท็บเดิม) เสมอ — เมนูเดิมที่เปิดอยู่ต้องกดกลับมาได้หลังไปดูหน้าแรก
    final alreadyOpen = _openTabs.any((t) => t.id == menu.id);
    _openTab(menu);
    if (alreadyOpen) return;
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
    return Consumer2<AuthService, LanguageProvider>(
      builder: (context, authService, lang, child) {
        final isEnglish = lang.isEnglish;
        final company = authService.company;
        final companyName = isEnglish
            ? (company?.englishName?.isNotEmpty == true
                ? company!.englishName!
                : company?.thaiName ?? '** No Company **')
            : (company?.thaiName ?? '** ไม่มีชื่อบริษัท **');
        final showSidebar = !_isLoading && _error.isEmpty && _allMenus.isNotEmpty && _menuIndex != null;

        Widget content;
        if (_isLoading) {
          content = const Center(child: CircularProgressIndicator());
        } else if (_error.isNotEmpty) {
          content = Center(child: Text('Error: $_error'));
        } else if (_allMenus.isEmpty && (_currentUser?.isDeveloper ?? false)) {
          content = _buildDeveloperBootstrap(isEnglish);
        } else if (_allMenus.isEmpty) {
          content = const Center(child: CircularProgressIndicator());
        } else {
          content = Column(children: [
            _CustomTabBar(
              tabs: _openTabs,
              currentIndex: _showHome ? -1 : _currentIndex,
              isEnglish: isEnglish,
              codeOf: (m) => _menuIndex?.moduleOf(m) == null ? '' : homeModuleCode(_menuIndex!.moduleOf(m)!),
              onHome: () => setState(() => _showHome = true),
              onSelect: (i) => setState(() {
                _currentIndex = i;
                _showHome = false;
              }),
              onClose: _closeTab,
              onMove: _reorderTab,
            ),
            Expanded(
              // fit: expand — แท็บที่ซ่อน (Offstage) มีขนาด 0 ถ้าไม่บังคับ Stack เต็มพื้นที่ หน้าแรก (Positioned.fill) จะกว้าง 0 = หน้าว่าง
              child: Stack(fit: StackFit.expand, children: [
                // แท็บที่เปิดอยู่คงสถานะไว้ตลอด แม้กำลังดูหน้าแรก
                if (_openTabs.isNotEmpty)
                  Offstage(
                    offstage: _showHome,
                    child: IndexedStack(
                      index: _currentIndex.clamp(0, _openTabs.length - 1),
                      children: _openTabs.map((menu) {
                        final id = menu.id;
                        return _cachedTabWidgets.putIfAbsent(
                          id,
                          () => KeyedSubtree(
                            key: ValueKey(id),
                            child: MenuScope(menu: menu, child: menu.builder(context)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                if (_showHome || _openTabs.isEmpty)
                  Positioned.fill(
                    child: HomePage(
                      isEnglish: isEnglish,
                      firstName: _currentUser?.firstName ?? '',
                      approvals: _pendingItems,
                      onOpenApproval: _openPendingApprovalTarget,
                      onShowAllApprovals: _showPendingApprovalsDialog,
                      favorites: _favoriteMenus,
                      moduleCodeOf: (m) => _menuIndex?.moduleOf(m) == null ? '' : homeModuleCode(_menuIndex!.moduleOf(m)!),
                      onOpenMenu: _onMenuSelected,
                      onRemoveFavorite: _toggleFavorite,
                      onOpenTarget: (t) {
                        final m = _findMenuByTargetPath(_allMenus, t);
                        if (m != null) _onMenuSelected(m);
                      },
                      canOpenTarget: (t) => _findMenuByTargetPath(_allMenus, t) != null,
                    ),
                  ),
              ]),
            ),
          ]);
        }

        return Scaffold(
          backgroundColor: HomeColors.appBg,
          bottomNavigationBar: _buildPasswordExpirationBanner(context, isEnglish),
          // ไม่มีการใช้งานนาน → หมดเวลา session (เหมือนเดิม)
          body: InactivityDetector(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (showSidebar) ...[
              AnimatedContainer(
                duration: _isDraggingDivider ? Duration.zero : const Duration(milliseconds: 180),
                width: _isMenuExpanded ? _menuPanelCurrentWidth : _sidebarMiniWidth,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    minWidth: _isMenuExpanded ? _menuPanelCurrentWidth : _sidebarMiniWidth,
                    maxWidth: _isMenuExpanded ? _menuPanelCurrentWidth : _sidebarMiniWidth,
                    child: HomeSidebar(
                      index: _menuIndex!,
                      mini: !_isMenuExpanded,
                      isEnglish: isEnglish,
                      companyName: companyName,
                      // บริษัทไม่มีโลโก้ → ใช้โลโก้ระบบจากหน้าตั้งค่าหน้าล็อกอิน
                      logoUrl: (company?.logoUrl ?? '').isNotEmpty ? company!.logoUrl : LoginBrandingService().cached?.logoUrl,
                      userName: '${_currentUser?.firstName ?? ''} ${_currentUser?.lastName ?? ''}'.trim(),
                      userRole: _roleLabel(isEnglish),
                      favoriteIds: _favoriteIds.toSet(),
                      favorites: _favoriteMenus,
                      selectedMenuId: _showHome || _openTabs.isEmpty ? null : _openTabs[_currentIndex].id,
                      expandedState: _menuExpandedState,
                      searchController: _searchController,
                      searchFocus: _searchFocus,
                      onOpenMenu: (m) {
                        _searchController.clear();
                        _onMenuSelected(m);
                      },
                      onToggleFavorite: _toggleFavorite,
                      onExpandRequest: () => setState(() => _isMenuExpanded = true),
                      onChangePassword: _showChangePasswordDialog,
                      onLogout: _showConfirmLogoutDialog,
                    ),
                  ),
                ),
              ),
              // ลากปรับความกว้างแถบเมนู
              if (_isMenuExpanded)
                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    onHorizontalDragStart: (_) => setState(() => _isDraggingDivider = true),
                    onHorizontalDragUpdate: (d) => setState(() {
                      _menuPanelCurrentWidth = (_menuPanelCurrentWidth + d.delta.dx).clamp(200.0, 520.0);
                    }),
                    onHorizontalDragEnd: (_) => setState(() => _isDraggingDivider = false),
                    child: Container(width: 4, color: HomeColors.brand),
                  ),
                ),
            ],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _buildTopBar(isEnglish, showSidebar),
                Expanded(child: content),
              ]),
            ),
          ])),
        );
      },
    );
  }

  static const double _sidebarMiniWidth = 64;

  String _roleLabel(bool isEnglish) {
    switch (_currentUser?.userType) {
      case 'developer':
        return isEnglish ? 'Developer' : 'ผู้พัฒนาระบบ';
      case 'administrator':
        return isEnglish ? 'Administrator' : 'ผู้ดูแลระบบ';
      default:
        return isEnglish ? 'User' : 'ผู้ใช้งาน';
    }
  }

  // ── แถบบนสีขาว: ย่อ/ขยายเมนู, เส้นทางเมนู, ฐานข้อมูล, รออนุมัติ, ภาษา, ขนาดตัวอักษร ──
  Widget _buildTopBar(bool isEnglish, bool showSidebar) {
    final lang = context.read<LanguageProvider>();
    final current = !_showHome && _openTabs.isNotEmpty ? _openTabs[_currentIndex] : null;
    final path = current == null || _menuIndex == null ? <Menu>[] : _menuIndex!.pathOf(current);
    Widget langSeg() {
      Widget b(String t, bool on, VoidCallback tap) => InkWell(
            onTap: on ? null : tap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              color: on ? HomeColors.brand : Colors.transparent,
              child: Text(t, style: TextStyle(fontSize: 12, color: on ? HomeColors.brandInk : HomeColors.ink2)),
            ),
          );
      return Tooltip(
        message: isEnglish ? 'สลับเป็นภาษาไทย' : 'Switch to English',
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: HomeColors.line), borderRadius: BorderRadius.circular(7)),
          clipBehavior: Clip.antiAlias,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            b('ไทย', !isEnglish, lang.toggle),
            b('ENG', isEnglish, lang.toggle),
          ]),
        ),
      );
    }

    return Container(
      height: 54,
      padding: const EdgeInsets.only(left: 6, right: 14),
      decoration: const BoxDecoration(
        color: HomeColors.card,
        border: Border(bottom: BorderSide(color: HomeColors.line)),
      ),
      child: Row(children: [
        if (showSidebar)
          IconButton(
            icon: Icon(_isMenuExpanded ? Icons.menu_open_rounded : Icons.menu_rounded, color: HomeColors.ink2),
            tooltip: _isMenuExpanded
                ? (isEnglish ? 'Collapse menu' : 'ย่อแถบเมนู')
                : (isEnglish ? 'Expand menu' : 'ขยายแถบเมนู'),
            onPressed: _toggleMenuSize,
          ),
        const SizedBox(width: 4),
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              if (path.isEmpty)
                TextSpan(
                    text: isEnglish ? 'Home' : 'หน้าแรก',
                    style: const TextStyle(color: HomeColors.ink, fontWeight: FontWeight.w600))
              else ...[
                for (final m in path.take(path.length - 1))
                  TextSpan(text: '${m.localName(isEnglish)}  ›  ', style: const TextStyle(color: HomeColors.ink3)),
                TextSpan(
                    text: path.last.localName(isEnglish),
                    style: const TextStyle(color: HomeColors.ink, fontWeight: FontWeight.w600)),
              ],
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Tooltip(
          message: isEnglish ? 'Database' : 'ฐานข้อมูล',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: HomeColors.goldSoft,
              border: Border.all(color: HomeColors.goldLine),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text((_currentDatabase ?? '').isNotEmpty ? _currentDatabase! : 'N/A',
                style: const TextStyle(fontSize: 11.5, color: HomeColors.amber, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 6),
        Tooltip(
          message: isEnglish
              ? 'Pending approvals${_pendingCount > 0 ? ' ($_pendingCount)' : ''}'
              : 'รายการรออนุมัติ${_pendingCount > 0 ? ' ($_pendingCount)' : ''}',
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _showPendingApprovalsDialog,
            child: SizedBox(
              width: 38,
              height: 38,
              child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                Icon(_pendingCount > 0 ? Icons.notifications_active_outlined : Icons.notifications_none_outlined,
                    color: HomeColors.ink2),
                if (_pendingCount > 0)
                  Positioned(
                    top: 3,
                    right: 2,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 17),
                      height: 17,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: HomeColors.red, borderRadius: BorderRadius.circular(9)),
                      child: Text(_pendingCount > 99 ? '99+' : '$_pendingCount',
                          style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 6),
        langSeg(),
        const SizedBox(width: 8),
        FontSizeButton(isEnglish: isEnglish, color: HomeColors.ink2, compact: true),
        // ไม่มีแถบซ้าย (กำลังโหลด / ยังไม่มีเมนู) → ปุ่มออกจากระบบอยู่ที่แถบบน
        if (!showSidebar) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: HomeColors.ink2),
            tooltip: isEnglish ? 'Log out' : 'ออกจากระบบ',
            onPressed: _showConfirmLogoutDialog,
          ),
        ],
      ]),
    );
  }
}

// ── Custom Tab Bar ────────────────────────────────────────────────────────────
// แท็บแบบเบราว์เซอร์: แท็บ "หน้าแรก" อยู่ซ้ายสุดเสมอ, แท็บเมนูมีป้ายรหัสโมดูล ปิดได้ ลากสลับลำดับได้
// currentIndex = -1 → กำลังดูหน้าแรก

class _CustomTabBar extends StatefulWidget {
  final List<Menu> tabs;
  final int currentIndex;
  final bool isEnglish;
  final String Function(Menu) codeOf;
  final VoidCallback onHome;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onClose;
  final void Function(int from, int to) onMove;

  const _CustomTabBar({
    required this.tabs,
    required this.currentIndex,
    required this.isEnglish,
    required this.codeOf,
    required this.onHome,
    required this.onSelect,
    required this.onClose,
    required this.onMove,
  });

  @override
  State<_CustomTabBar> createState() => _CustomTabBarState();
}

class _CustomTabBarState extends State<_CustomTabBar> {
  static const double _barH = 40;
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
      const tabW = 170.0;
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

  Widget _tab(int i, {required VoidCallback? onClose}) => _TabItemContent(
        label: widget.tabs[i].localName(widget.isEnglish),
        code: widget.codeOf(widget.tabs[i]),
        isActive: i == widget.currentIndex,
        onClose: onClose,
      );

  @override
  Widget build(BuildContext context) {
    final homeActive = widget.currentIndex < 0;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _updateArrows();
        return false;
      },
      child: Container(
        height: _barH,
        padding: const EdgeInsets.only(left: 8, top: 6),
        decoration: const BoxDecoration(
          color: HomeColors.appBg,
          border: Border(bottom: BorderSide(color: HomeColors.line)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // แท็บหน้าแรก
          Tooltip(
            message: widget.isEnglish ? 'Home' : 'หน้าแรก',
            child: InkWell(
              onTap: widget.onHome,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              child: Container(
                height: _barH - 6,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                decoration: _TabItemContent.deco(homeActive),
                child: Icon(Icons.home_outlined, size: 18, color: homeActive ? HomeColors.brand : HomeColors.ink3),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                _DropZone(dropIndex: 0, onMove: widget.onMove),
                for (int i = 0; i < widget.tabs.length; i++) ...[
                  Draggable<int>(
                    data: i,
                    feedback: Material(elevation: 4, child: _tab(i, onClose: null)),
                    childWhenDragging: Opacity(opacity: 0.3, child: _tab(i, onClose: null)),
                    child: GestureDetector(
                      onTap: () {
                        widget.onSelect(i);
                        _scrollToTab(i);
                      },
                      child: _tab(i, onClose: () => widget.onClose(i)),
                    ),
                  ),
                  _DropZone(dropIndex: i + 1, onMove: widget.onMove),
                ],
              ]),
            ),
          ),
          if (_showLeft || _showRight) ...[
            _TabArrowButton(icon: Icons.chevron_left, enabled: _showLeft, onTap: () => _scrollBy(-170)),
            _TabArrowButton(icon: Icons.chevron_right, enabled: _showRight, onTap: () => _scrollBy(170)),
          ],
        ]),
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
          height: 34,
          color: _hovering ? HomeColors.gold : Colors.transparent,
        );
      },
    );
  }
}

class _TabItemContent extends StatefulWidget {
  final String label;
  final String code;
  final bool isActive;
  final VoidCallback? onClose;

  const _TabItemContent({
    required this.label,
    required this.code,
    required this.isActive,
    required this.onClose,
  });

  static BoxDecoration deco(bool active) => BoxDecoration(
        color: active ? HomeColors.card : Colors.transparent,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        border: active
            ? const Border(
                top: BorderSide(color: HomeColors.line),
                left: BorderSide(color: HomeColors.line),
                right: BorderSide(color: HomeColors.line),
              )
            : null,
      );

  @override
  State<_TabItemContent> createState() => _TabItemContentState();
}

class _TabItemContentState extends State<_TabItemContent> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isActive;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        height: 34,
        constraints: const BoxConstraints(maxWidth: 240),
        padding: const EdgeInsets.only(left: 10, right: 6),
        decoration: _TabItemContent.deco(active).copyWith(
          color: active ? HomeColors.card : (_hover ? HomeColors.hover : Colors.transparent),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (widget.code.isNotEmpty) ...[
            HomeModuleBadge(widget.code, width: 24, height: 18, fontSize: 9),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? HomeColors.ink : HomeColors.ink2,
                fontSize: 12.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (widget.onClose != null) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: widget.onClose,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.close, size: 14, color: HomeColors.ink3),
              ),
            ),
          ],
        ]),
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
      child: SizedBox(
        width: 28,
        height: 34,
        child: Icon(icon, size: 20, color: enabled ? HomeColors.ink2 : HomeColors.line),
      ),
    );
  }
}

// ── Pending Approvals Dialog ──────────────────────────────────────────────────
// รายการรออนุมัติแบบ card รวมทุกโมดูล — คลิก card แล้วปิด dialog ไปเปิดหน้าจอที่ทำอนุมัติจริงในแท็บทันที (ผ่าน
// onCardTap) ไม่มีปุ่มอนุมัติ/ปฏิเสธในนี้อีกต่อไป (ย้ายไปทำที่หน้าจอปลายทางแทน ซึ่งมีปุ่มนี้อยู่แล้วทุกโมดูล)
class _PendingApprovalsDialog extends StatelessWidget {
  final List<PendingApprovalItem> items;
  final ValueChanged<PendingApprovalItem> onCardTap;

  const _PendingApprovalsDialog({required this.items, required this.onCardTap});

  IconData _moduleIcon(String module) {
    switch (module) {
      case 'ap_payment_run':
        return Icons.payments_outlined;
      case 'ap_transaction':
        return Icons.receipt_long_outlined;
      case 'pr_transaction':
        return Icons.assignment_outlined;
      case 'po_transaction':
        return Icons.shopping_cart_outlined;
      case 'so_transaction':
        return Icons.point_of_sale_outlined;
      case 'im_price_change':
        return Icons.price_change_outlined;
      case 'im_stock_count':
        return Icons.fact_check_outlined;
      case 'mo_header':
        return Icons.precision_manufacturing_outlined;
      case 'gl_period_close_request':
        return Icons.event_busy_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final fmt = (DateTime? d) => d == null
        ? ''
        : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final numFmt = (double v) => v
        .toStringAsFixed(2)
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.notifications_active, color: Colors.orange),
        const SizedBox(width: 8),
        Text(isEnglish ? 'Pending Approvals' : 'รายการรออนุมัติ'),
        const Spacer(),
        Text('(${items.length})', style: const TextStyle(color: Colors.grey)),
      ]),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 520,
        child: items.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                      isEnglish
                          ? 'No pending approvals'
                          : 'ไม่มีรายการรออนุมัติ',
                      style: const TextStyle(color: Colors.grey)),
                ),
              )
            : ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final item = items[i];
                    return Card(
                      margin: EdgeInsets.zero,
                      elevation: 1,
                      color: Colors.orange[50],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.orange.shade200),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => onCardTap(item),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            CircleAvatar(
                              backgroundColor: Colors.orange[100],
                              child: Icon(_moduleIcon(item.module),
                                  color: Colors.orange[800], size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.title(isEnglish),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Text(
                                    isEnglish
                                        ? 'From: ${item.submittedBy ?? '-'}'
                                        : 'จาก: ${item.submittedBy ?? '-'}',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[700]),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      if (item.date != null) fmt(item.date),
                                      if (item.amount != 0) numFmt(item.amount),
                                    ].join('   •   '),
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: Colors.grey[500]),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
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
