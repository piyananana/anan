// import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/menu.dart';
import '../models/password_status.dart';
import '../models/user.dart';
import '../services/menu_service.dart';
import '../services/auth_service.dart';
import '../widgets/menu_tree_view.dart';
// import '../widgets/dynamic_content_display.dart';
import '../widgets/change_password_dialog.dart';
import '../widgets/confirm_logout_dialog.dart';
import 'login_screen.dart';
import 'menu_screen.dart';

class HomeScreen extends StatefulWidget {
  final PasswordStatus? passwordStatus; // รับสถานะรหัสผ่านจาก LoginScreen

  const HomeScreen({super.key, this.passwordStatus});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // ตัวแปรสำหรับจัดการ Tab
  late TabController _tabController;
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
    _tabController = TabController(length: _openTabs.length, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_menuWidthInitialized) {
      _menuPanelCurrentWidth = MediaQuery.of(context).size.width * 0.30;
      _menuWidthInitialized = true;
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();

    _searchController.dispose();
    super.dispose();
  }

  // ฟังก์ชันนี้จะถูกเรียกเมื่อมีการเปลี่ยนแปลง Tab
  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentIndex = _tabController.index;
      });
    }
  }

  // --- Functions for Tab Management ---

  void _openTab(Menu menu) {
    int existingIndex = _openTabs.indexWhere((tab) => tab.id == menu.id);

    if (existingIndex != -1) {
      _tabController.animateTo(existingIndex); // สลับไปที่ Tab ที่มีอยู่แล้ว
    } else {
      setState(() {
        _openTabs.add(menu);
        _tabController = TabController(
            length: _openTabs.length,
            vsync: this,
            initialIndex: _openTabs.length - 1);
        _tabController.addListener(
            _handleTabSelection); // ต้องเพิ่ม listener ใหม่เพราะ controller ถูกสร้างใหม่
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
        // ถ้าไม่มี Tab เหลืออยู่
        _tabController =
            TabController(length: 0, vsync: this); // สร้างใหม่ด้วย length 0
        _tabController
            .removeListener(_handleTabSelection); // ต้อง remove listener ก่อน
        _currentIndex = 0;
      } else {
        // คำนวณ Index ใหม่หลังจากลบ Tab
        // หาก Index ที่ถูกลบ น้อยกว่าหรือเท่ากับ _currentIndex และ _currentIndex ไม่ใช่ 0
        // ให้ลด _currentIndex ลง 1
        int newIndex = _currentIndex;
        if (index <= _currentIndex && _currentIndex > 0) {
          newIndex = _currentIndex - 1;
        } else if (_openTabs.length <= newIndex) {
          newIndex = _openTabs.length - 1;
        }
        newIndex = newIndex.clamp(0, _openTabs.length - 1);

        _tabController
            .removeListener(_handleTabSelection); // ต้อง remove listener ก่อน
        _tabController.dispose(); // ทิ้ง controller เก่า

        _tabController = TabController(
            length: _openTabs.length, vsync: this, initialIndex: newIndex);
        _tabController.addListener(_handleTabSelection); // เพิ่ม listener ใหม่
        _currentIndex = newIndex;
      }
    });
  }

  Future<void> _loadUserAndMenus() async {
    await _fetchUser();
    await _fetchMenus();
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
      // Initialize top-level folders ให้ expand เป็น default (เฉพาะครั้งแรก)
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
    } catch (e) {
      setState(() {
        _error = 'Failed to load menus: $e';
        _isLoading = false;
      });
      // ถ้า Error เป็น Unauthorized (401) อาจจะพาไปหน้า Login
      if (e.toString().contains('Unauthorized')) {
        _performLogout(); // บังคับ logout
      }
    }
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
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false, // ลบทุก Route เก่า
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
  Widget _buildPasswordExpirationBanner(BuildContext context) {
    if (_currentPasswordStatus == null) return const SizedBox.shrink();

    String message = '';
    Color backgroundColor = Colors.amber; // Default for warning

    if (_currentPasswordStatus!.isPasswordExpired) {
      message = 'รหัสผ่านของคุณหมดอายุแล้ว! กรุณาเปลี่ยนรหัสผ่านทันที';
      backgroundColor = Colors.red.shade700;
    } else if (_currentPasswordStatus!.daysUntilExpiration != null &&
        _currentPasswordStatus!.daysUntilExpiration! > 0) {
      message =
          'รหัสผ่านของคุณจะหมดอายุในอีก ${_currentPasswordStatus!.daysUntilExpiration} วัน';
      backgroundColor = Colors.orange.shade700;
    } else {
      return const SizedBox.shrink(); // ไม่มีแจ้งเตือน
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
            child: const Text('เปลี่ยนรหัสผ่าน',
                style: TextStyle(color: Colors.white)),
          ),
          widget.passwordStatus!.forceChangePassword
              ? const SizedBox.shrink() // ไม่แสดงปุ่มถ้าบังคับเปลี่ยนรหัสผ่าน
              : TextButton(
                  onPressed: () {
                    // Dismiss the banner (for forced changes)
                    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                    setState(() {
                      _currentPasswordStatus = null; // ซ่อน Banner หลังคลิก
                    });
                  },
                  child:
                      const Text('ปิด', style: TextStyle(color: Colors.white)),
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
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final currentCompany = authService.company;
        // final currentCompany = _company;
        return Scaffold(
          bottomNavigationBar: _buildPasswordExpirationBanner(context),
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
                Text(currentCompany?.thaiName ?? '** ไม่มีชื่อบริษัท **'),
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
              const SizedBox(width: 8), // ช่องว่าง
              // ปุ่มเปลี่ยนรหัสผ่าน
              Container(
                padding: const EdgeInsets.all(1.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.orange), // สีขอบเริ่มต้น
                  borderRadius:
                      BorderRadius.circular(6.0), // กำหนดความโค้งของขอบ
                ),
                child: IconButton(
                  icon: const Icon(Icons.password_outlined,
                      color: Colors.orange), // ไอคอนเปลี่ยนรหัสผ่าน
                  onPressed: _showChangePasswordDialog,
                  tooltip: 'เปลี่ยนรหัสผ่าน',
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
                  icon: const Icon(Icons.logout_outlined,
                      color: Colors.orange), // ไอคอนเปลี่ยนรหัสผ่าน
                  onPressed: _showConfirmLogoutDialog,
                  tooltip: 'ออกจากระบบ',
                ),
              ),
              const SizedBox(width: 8), // เพื่อให้มีพื้นที่ขอบขวาเล็กน้อย
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error.isNotEmpty
                  ? Center(child: Text('Error: $_error'))
                  : _allMenus.isEmpty // <-- ตรวจเช็คว่ามีเมนูหรือไม่
                      ? MenuScreen(
                          // <-- แสดง MenuManagementScreen ถ้าไม่มีเมนู
                          // initialMenus: _allMenus,
                          onMenusChanged:
                              _fetchMenus, // Callback ให้ HomeScreen โหลดเมนูใหม่
                          onExit: _onExitContent, // <-- ส่ง Callback นี้ไป
                        )
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
                                      ? Icons.arrow_back_ios_new_rounded
                                      : Icons.arrow_forward_ios_rounded,
                                  color: Colors.orange,
                                ),
                                onPressed: _toggleMenuSize,
                                tooltip: _isMenuExpanded
                                    ? 'ย่อช่องเมนู'
                                    : 'ขยายช่องเมนู',
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
                                  _openTabs.isEmpty
                                      ? Container()
                                      : TabBar(
                                          onTap: (int index) {
                                            setState(() {
                                              _currentIndex = index;
                                            });
                                          },
                                          controller: _tabController,
                                          isScrollable: true,
                                          indicatorColor: Colors.deepOrange,
                                          labelColor: Colors.deepOrange[900],
                                          unselectedLabelColor: Colors.black54,
                                          tabs: _openTabs
                                              .asMap()
                                              .entries
                                              .map((entry) {
                                            int idx = entry.key;
                                            Menu tabMenu = entry.value;
                                            return Tab(
                                              child: Row(
                                                children: [
                                                  Text(tabMenu.menuName),
                                                  const SizedBox(width: 8),
                                                  InkWell(
                                                    onTap: () => _closeTab(idx),
                                                    child: const Icon(
                                                        Icons.close,
                                                        size: 18),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                  Expanded(
                                    child: _openTabs.isEmpty
                                        ? const Center(
                                            child: Text(
                                              'กรุณาเลือกเมนูจากด้านซ้ายเพื่อเปิดหน้าจอ',
                                              style: TextStyle(
                                                  fontSize: 20,
                                                  color: Colors.grey),
                                            ),
                                          )
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
                                                  child:
                                                      menu.builder(context),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
        );
      },
    );
  }

}

