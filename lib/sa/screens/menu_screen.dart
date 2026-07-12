// screens/menu_management_screen.dart
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/menu.dart';
import '../services/menu_service.dart';
import '../services/language_provider.dart';
import '../utils/app_l10n.dart';
import '../utils/menu_scope.dart';

// Enum เพื่อบอกสถานะของ Node ใน TreeView
enum NodeMode {
  addRoot,
  addChild,
  edit,
  none,
}

class MenuScreen extends StatefulWidget {
  final VoidCallback onMenusChanged; // Callback เมื่อมีการเปลี่ยนแปลงเมนู
  final VoidCallback? onExit; // <-- เพิ่ม Callback นี้

  const MenuScreen({
    super.key,
    required this.onMenusChanged,
    this.onExit, // <-- รับเข้ามา
  });

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen>
    with AutomaticKeepAliveClientMixin {
  // late List<Menu> _currentList;
  List<Menu> _currentList = []; // กำหนดค่าเริ่มต้นเป็น List ว่างเปล่า
  bool _isLoading = true; // เพิ่มสถานะการโหลดเมนู
  String _errorLoading = ''; // เพิ่มข้อความ error
  final Map<int, bool> _expandedState = {};
  Menu? _selectedNode; // เมนูที่ถูกเลือกใน TreeView
  NodeMode _nodeMode = NodeMode.none; // โหมดของ Form
  int? _parentIdForNewNode; // สำหรับโหมด addChild

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _menuNameController = TextEditingController();
  final TextEditingController _menuNameEnController = TextEditingController();
  final TextEditingController _targetPathController = TextEditingController();
  final TextEditingController _sortOrderController = TextEditingController();
  String _menuType = 'folder'; // Default
  String _contentType = 'widget'; // Default for content
  final TextEditingController _contentDataController = TextEditingController();
  bool _isActive = true;
  bool _isSystem = false;

  bool _isLeftPanelExpanded = true;
  double _leftPanelWidth = 360.0;
  bool _isDraggingDivider = false;
  bool _isImportingOrExporting = false; // สำหรับแสดงสถานะ Loading

  @override
  void initState() {
    super.initState();
    // _currentList = List.from(widget.initialMenus); // ทำสำเนา
    _fetchNodes(); // <-- เรียกเมธอด fetch เพื่อโหลดเมนูเมื่อ Widget ถูกสร้าง
  }

  @override
  void dispose() {
    _menuNameController.dispose();
    _menuNameEnController.dispose();
    _targetPathController.dispose();
    _sortOrderController.dispose();
    _contentDataController.dispose();
    super.dispose();
  }

  @override
  // TODO: implement wantKeepAlive
  // bool get wantKeepAlive => throw UnimplementedError();
  bool get wantKeepAlive => true;

  // *** NEW: Method สำหรับ Fetch เมนูทั้งหมด ***
  Future<void> _fetchNodes() async {
    // setState(() {
    //   _isLoading = true;
    //   _errorLoading = '';
    // });
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorLoading = '';
      });
    }
    try {
      final masterService = Provider.of<MenuService>(context, listen: false);
      final fetchedMenus = await masterService.fetchMenus();
      // setState(() {
      //   _currentList = fetchedMenus;
      //   _isLoading = false;
      // });
      if (mounted) {
        setState(() {
          _currentList = fetchedMenus;
          _isLoading = false;
        });
      }
    } catch (e) {
      // setState(() {
      //   _errorLoading = 'ไม่สามารถโหลดเมนูได้: ${e.toString()}';
      //   _isLoading = false;
      // });
      if (mounted) {
        setState(() {
          _errorLoading = 'ไม่สามารถโหลดเมนูได้: ${e.toString()}';
          _isLoading = false;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorLoading)),
      );
    }
  }

  // --- Utility Methods ---
  List<Menu> _buildTree(List<Menu> menus, int? parentId) {
    return menus.where((menu) => menu.parentId == parentId).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  void _clearForm() {
    _menuNameController.clear();
    _menuNameEnController.clear();
    _targetPathController.clear();
    _sortOrderController.clear();
    _contentDataController.clear();
    setState(() {
      _menuType = 'folder';
      _contentType = 'widget';
      _isActive = true;
      _isSystem = false;
      _selectedNode = null;
      _nodeMode = NodeMode.none;
      _parentIdForNewNode = null;
    });
  }

  // --- Form Logic ---
  void _setAddRootMode() {
    _clearForm();
    setState(() {
      _nodeMode = NodeMode.addRoot;
      _selectedNode = null; // Clear selected node
      _parentIdForNewNode = null; // Clear parent ID
      _menuNameController.text = ''; // Clear for new input
      _menuType = 'folder'; // เมนูย่อยเริ่มต้นเป็น folder
      _targetPathController.text = '';
      _contentType = 'widget';
      _contentDataController.text = '';
      _isActive = true;
    });
  }

  void _setAddChildMode(Menu parentMenu) {
    _clearForm();
    setState(() {
      _nodeMode = NodeMode.addChild;
      _selectedNode = parentMenu;
      _parentIdForNewNode = parentMenu.id;
      // ตั้งค่าเริ่มต้นสำหรับเมนูย่อย
      _menuNameController.text = ''; // Clear for new input
      _sortOrderController.text =
          ((_buildTree(_currentList, parentMenu.id).length + 1) * 10)
              .toString(); // ลำดับเริ่มต้น
      _menuType = 'folder'; // เมนูย่อยเริ่มต้นเป็น folder
      _targetPathController.text = '';
      _contentType = 'widget';
      _contentDataController.text = '';
      _isActive = true;
    });
  }

  void _setEditMode(Menu menu) {
    _clearForm();
    setState(() {
      _nodeMode = NodeMode.edit;
      _selectedNode = menu;
      _menuNameController.text = menu.menuName;
      _menuNameEnController.text = menu.menuNameEn;
      _targetPathController.text = menu.targetPath ?? '';
      _sortOrderController.text = menu.sortOrder.toString();
      _menuType = menu.menuType;
      // ถ้ามีการเก็บ content ใน model/db (ตอนนี้ Menu model ไม่มี field นี้โดยตรง)
      // คุณอาจจะต้อง fetch menu_contents แยก หรือให้ Menu model มี fields นี้
      // สำหรับตอนนี้ เราสมมติว่า content data จะถูกโหลดในฟอร์มเมื่อแก้ไข
      _loadContentForEdit(menu.id);
      _isActive = true;
      _isSystem = menu.isSystem;
    });
  }

  Future<void> _loadContentForEdit(int menuId) async {
    try {
      final menuContent = await Provider.of<MenuService>(context, listen: false)
          .fetchMenuContent(menuId);
      setState(() {
        _contentType = menuContent.contentType ?? 'widget';
        _contentDataController.text = menuContent.contentData ?? '';
      });
    } catch (e) {
      print('Error loading content for edit: $e');
      setState(() {
        _contentType = 'widget'; // Fallback
        _contentDataController.text = '';
      });
    }
  }

  Future<void> _submitMenu() async {
    if (!_formKey.currentState!.validate()) return;

    final masterService = Provider.of<MenuService>(context, listen: false);
    String? message;

    try {
      if (_nodeMode == NodeMode.addRoot || _nodeMode == NodeMode.addChild) {
        final newMenu = await masterService.addMenu(
          parentId: _nodeMode == NodeMode.addChild ? _parentIdForNewNode : null,
          menuName: _menuNameController.text,
          menuNameEn: _menuNameEnController.text,
          menuType: _menuType,
          targetPath: _targetPathController.text.isEmpty ? null : _targetPathController.text,
          sortOrder: int.tryParse(_sortOrderController.text),
          isSystem: _isSystem,
          contentType: _contentType,
          contentData: _contentDataController.text.isEmpty ? null : _contentDataController.text,
        );
        message = 'เพิ่มเมนู "${newMenu.menuName}" สำเร็จ';
      } else if (_nodeMode == NodeMode.edit && _selectedNode != null) {
        final updatedMenu = await masterService.updateMenu(
          _selectedNode!.id,
          menuName: _menuNameController.text,
          menuNameEn: _menuNameEnController.text,
          menuType: _menuType,
          targetPath: _targetPathController.text.isEmpty ? null : _targetPathController.text,
          sortOrder: int.tryParse(_sortOrderController.text) ?? _selectedNode!.sortOrder,
          isActive: _isActive,
          isSystem: _isSystem,
          contentType: _contentType,
          contentData: _contentDataController.text.isEmpty ? null : _contentDataController.text,
        );
        message = 'แก้ไขเมนู "${updatedMenu.menuName}" สำเร็จ';
      }
      _clearForm();
      await _refreshAllMenus(); // โหลดเมนูใหม่หลังจากเพิ่ม/แก้ไข
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message!)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('เกิดข้อผิดพลาด: ${e.toString()}')));
      }
    }
  }

  Future<void> _confirmDeleteMenu(Menu menu) async {
    final l = AppL10n(Provider.of<LanguageProvider>(context, listen: false).isEnglish);
    if (_buildTree(_currentList, menu.id).isNotEmpty &&
        menu.menuType == 'folder') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.isEnglish
            ? 'Cannot delete a folder that has sub-menus. Please delete sub-menus first.'
            : 'ไม่สามารถลบ Folder ที่มีเมนูย่อยได้ กรุณาลบเมนูย่อยออกก่อน')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(l.isEnglish ? 'Confirm Delete Menu' : 'ยืนยันการลบเมนู'),
          content: Text(l.isEnglish
              ? 'Are you sure you want to delete "${menu.localName(l.isEnglish)}"?'
              : 'คุณแน่ใจหรือไม่ว่าต้องการลบเมนู "${menu.menuName}"?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l.cancel)),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(l.delete, style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await Provider.of<MenuService>(context, listen: false)
            .deleteMenu(menu.id);
        _clearForm();
        await _refreshAllMenus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(l.isEnglish
                  ? 'Menu "${menu.localName(l.isEnglish)}" deleted successfully'
                  : 'ลบเมนู "${menu.menuName}" สำเร็จ')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('${l.isEnglish ? 'Error deleting' : 'เกิดข้อผิดพลาดในการลบ'}: ${e.toString()}')));
        }
      }
    }
  }

  Future<void> _confirmDeleteAllNode() async {
    final l = AppL10n(Provider.of<LanguageProvider>(context, listen: false).isEnglish);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(l.isEnglish ? 'Confirm Delete All Menus' : 'ยืนยันการลบเมนูทั้งหมด'),
          content: Text(l.isEnglish
              ? 'Are you sure you want to delete ALL menu data? This action cannot be undone!'
              : 'คุณแน่ใจหรือไม่ว่าต้องการลบข้อมูลเมนูทั้งหมด? การกระทำนี้ไม่สามารถย้อนกลับได้!'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l.cancel)),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(l.isEnglish ? 'Delete All' : 'ลบทั้งหมด',
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await Provider.of<MenuService>(context, listen: false).deleteAllMenu();
        _clearForm();
        await _refreshAllMenus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ลบเมนูทั้งหมดสำเร็จ')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('เกิดข้อผิดพลาดในการลบทั้งหมด: ${e.toString()}')));
        }
      }
    }
  }

  // ปรับปรุง _refreshAllMenus ให้เรียก _fetchNodes ของตัวเอง
  // และแจ้ง Home Screen ด้วย
  Future<void> _refreshAllMenus() async {
    await _fetchNodes(); // โหลดเมนูใหม่สำหรับหน้าจอนี้
    widget.onMenusChanged(); // แจ้ง Home Screen ด้วย
  }

// --- ปรับปรุง: Import/Export Logic ---
  Future<void> _importData() async {
    setState(() {
      _isImportingOrExporting = true;
    });
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        // สำหรับเว็บ, ต้องตั้งค่า bytes ให้เป็น true เพื่อให้ได้ข้อมูลไฟล์มาเลย
        // เนื่องจากไม่สามารถเข้าถึง path ได้
        withData: kIsWeb,
      );

      if (result != null && result.files.single.bytes != null ||
          result?.files.single.path != null) {
        // ตรวจสอบ bytes หรือ path
        PlatformFile platformFile = result!.files.single;

        // ส่ง PlatformFile เข้าไปใน service
        await Provider.of<MenuService>(context, listen: false)
            .importMenu(platformFile);
        await _refreshAllMenus(); // <-- เรียก _refreshAllMenus ที่ถูกปรับปรุง
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Import เมนูสำเร็จ!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ยกเลิกการเลือกไฟล์')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('เกิดข้อผิดพลาดในการ Import: ${e.toString()}')),
        );
      }
    } finally {
      setState(() {
        _isImportingOrExporting = false;
      });
    }
  }

  Future<void> _exportData() async {
    setState(() {
      _isImportingOrExporting = true;
    });
    try {
      await Provider.of<MenuService>(context, listen: false).exportMenu();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Export เมนูสำเร็จ! ไฟล์ถูกบันทึกใน Downloads')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('เกิดข้อผิดพลาดในการ Export: ${e.toString()}')),
        );
      }
    } finally {
      setState(() {
        _isImportingOrExporting = false;
      });
    }
  }

  // --- Build Methods ---
  Widget _buildNode(Menu menu, int level, AppL10n l) {
    final bool isFolder = menu.menuType == 'folder';
    final List<Menu> children = _buildTree(_currentList, menu.id);
    final bool hasChildren = children.isNotEmpty;
    final bool isExpanded = _expandedState[menu.id] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            if (isFolder && hasChildren) {
              setState(() {
                _expandedState[menu.id] = !isExpanded;
              });
            } else {
              _setEditMode(menu); // คลิกเมนูเพื่อแก้ไขรายละเอียด
            }
          },
          child: Padding(
            padding: EdgeInsets.only(left: level * 16.0),
            child: Row(
              children: [
                if (isFolder && hasChildren)
                  Icon(isExpanded ? Icons.arrow_drop_down : Icons.arrow_right),
                if (!isFolder || !hasChildren) const SizedBox(width: 24),
                Icon(isFolder ? Icons.folder : Icons.insert_drive_file),
                const SizedBox(width: 8),
                Expanded(
                  child: Consumer<LanguageProvider>(
                    builder: (ctx, lang, _) => Text(
                      menu.localName(lang.isEnglish),
                      style: const TextStyle(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // Icon ปุ่ม Add สำหรับ Folder
                if (isFolder)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    tooltip: l.isEnglish ? 'Add Sub Menu' : 'เพิ่มเมนูย่อย',
                    onPressed: () => _setAddChildMode(menu),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                  tooltip: l.isEnglish ? 'Edit Menu' : 'แก้ไขเมนู',
                  onPressed: () => _setEditMode(menu),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  tooltip: l.isEnglish ? 'Delete Menu' : 'ลบเมนู',
                  onPressed: () => _confirmDeleteMenu(menu),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded && hasChildren)
          Column(
            children:
                children.map((child) => _buildNode(child, level + 1, l)).toList(),
          ),
      ],
    );
  }

  Widget _buildDetailForm(AppL10n l) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _nodeMode == NodeMode.addRoot
                  ? (l.isEnglish ? 'Add Root Menu' : 'เพิ่มเมนูหลัก')
                  : _nodeMode == NodeMode.addChild
                      ? '${l.isEnglish ? 'Add Sub Menu' : 'เพิ่มเมนูย่อย'}: ${_selectedNode?.localName(l.isEnglish) ?? ''}'
                      : _nodeMode == NodeMode.edit
                          ? '${l.isEnglish ? 'Edit Menu' : 'แก้ไขเมนู'}: ${_selectedNode?.localName(l.isEnglish) ?? ''}'
                          : (l.isEnglish ? 'Select a menu or add a new one' : 'เลือกเมนูหรือเพิ่มเมนูใหม่'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _menuNameController,
              decoration: InputDecoration(
                labelText: l.isEnglish ? 'Menu Name (TH)' : 'ชื่อเมนู (ไทย)',
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l.isEnglish ? 'Please enter menu name' : 'กรุณาป้อนชื่อเมนู';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _menuNameEnController,
              decoration: InputDecoration(
                labelText: l.isEnglish ? 'Menu Name (EN)' : 'ชื่อเมนู (อังกฤษ)',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _menuType,
              decoration: InputDecoration(
                labelText: l.isEnglish ? 'Menu Type' : 'ประเภทเมนู',
                border: const OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'folder', child: Text('Folder')),
                DropdownMenuItem(value: 'link', child: Text('Link')),
                DropdownMenuItem(value: 'widget', child: Text('Widget')),
              ],
              onChanged: (value) {
                setState(() {
                  _menuType = value!;
                  // ถ้าเปลี่ยนเป็น folder จะเคลียร์ target_path
                  if (_menuType == 'folder') {
                    _targetPathController.clear();
                    _contentDataController.clear();
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            // แสดง TextField สำหรับ target_path เมื่อไม่ใช่ folder
            if (_menuType != 'folder')
              TextFormField(
                controller: _targetPathController,
                decoration: InputDecoration(
                  labelText: l.isEnglish ? 'Widget/Class Name or Link Path' : 'Widget/Class Name หรือ Link Path',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (_menuType != 'folder' && value == null) {
                    return l.isEnglish ? 'Please enter Widget/Class Name or Link Path' : 'กรุณาป้อน Widget/Class Name หรือ Link Path';
                  }
                  return null;
                },
              ),
            if (_menuType != 'folder') const SizedBox(height: 16),
            // ส่วนสำหรับ Content (ถ้าเป็น link/widget)
            if (_menuType != 'folder')
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _contentType,
                decoration: InputDecoration(
                  labelText: l.isEnglish ? 'Content Type' : 'ประเภท Content',
                  border: const OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'widget', child: Text('Widget Name')),
                  DropdownMenuItem(value: 'html', child: Text('HTML Content')),
                  DropdownMenuItem(
                      value: 'markdown', child: Text('Markdown Content')),
                  DropdownMenuItem(value: 'url', child: Text('URL')),
                ],
                onChanged: (value) {
                  setState(() {
                    _contentType = value!;
                  });
                },
              ),
            if (_menuType != 'folder') const SizedBox(height: 16),
            if (_menuType != 'folder')
              TextFormField(
                controller: _contentDataController,
                decoration: InputDecoration(
                  labelText: _contentType == 'widget'
                      ? 'Widget Name (e.g. HomePage)'
                      : _contentType == 'html'
                          ? 'HTML Content'
                          : _contentType == 'markdown'
                              ? 'Markdown Content'
                              : 'URL (e.g. https://google.com)',
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: _contentType == 'html' || _contentType == 'markdown'
                    ? 5
                    : 1,
                keyboardType:
                    _contentType == 'html' || _contentType == 'markdown'
                        ? TextInputType.multiline
                        : TextInputType.text,
                validator: (value) {
                  if (_menuType != 'folder' && value == null) {
                    // (value == null || value.isEmpty)) {
                    return 'กรุณาป้อนข้อมูล Content';
                  }
                  return null;
                },
              ),
            if (_menuType != 'folder') const SizedBox(height: 16),
            TextFormField(
              controller: _sortOrderController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l.isEnglish ? 'Sort Order' : 'ลำดับการแสดงผล',
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l.isEnglish ? 'Please enter sort order' : 'กรุณาป้อนลำดับ';
                }
                if (int.tryParse(value) == null) {
                  return l.isEnglish ? 'Must be a number' : 'ต้องเป็นตัวเลขเท่านั้น';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            if (_nodeMode == NodeMode.edit)
              Row(
                children: [
                  Text(l.isEnglish ? 'Status: ' : 'สถานะ: '),
                  Switch(
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                  Text(_isActive ? l.active : l.inactive),
                ],
              ),
            Row(
              children: [
                Text(l.isEnglish ? 'System Menu: ' : 'เมนูระบบ (System): '),
                Switch(
                  value: _isSystem,
                  activeColor: Colors.red,
                  onChanged: (v) => setState(() => _isSystem = v),
                ),
                Text(
                  _isSystem
                      ? (l.isEnglish ? 'Developer Only' : 'เฉพาะ Developer')
                      : (l.isEnglish ? 'General' : 'ทั่วไป'),
                  style: TextStyle(
                    color: _isSystem ? Colors.red : Colors.grey,
                    fontWeight: _isSystem ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_nodeMode != NodeMode.none)
                  TextButton(
                    onPressed: _clearForm,
                    child: Text(l.cancel),
                  ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _nodeMode == NodeMode.none ? null : _submitMenu,
                  child: Text(_nodeMode == NodeMode.edit
                      ? (l.isEnglish ? 'Save Changes' : 'บันทึกการแก้ไข')
                      : (l.isEnglish ? 'Save New' : 'บันทึกข้อมูลใหม่')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // *** สำคัญ: ต้องเรียก super.build(context); ที่จุดเริ่มต้นของ build method ***
    super.build(context); // This is crucial for AutomaticKeepAliveClientMixin
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);

    // ต้องตรวจสอบสถานะการโหลดก่อนสร้าง UI
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorLoading.isNotEmpty) {
      return Center(child: Text(_errorLoading));
    }

    final List<Menu> topLevelMenus = _buildTree(_currentList, null);

    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        // leading: IconButton(
        //   icon: const Icon(Icons.arrow_back),
        //   onPressed: () {
        //     // // เรียก callback เมื่อต้องการ "ออกจาก" หน้าจัดการเมนู
        //     // // แทนการใช้ Navigator.pop()
        //     if (widget.onExit != null) {
        //       widget.onExit!();
        //     }
        //   },
        // ),
        backgroundColor: Colors.deepOrange.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l.isEnglish ? 'Refresh' : 'รีเฟรชรายการ',
            onPressed: _refreshAllMenus,
          ),
          // ปุ่ม Import/Export
          if (_isImportingOrExporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child:
                  Center(child: CircularProgressIndicator(color: Colors.white)),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: l.isEnglish ? 'Import from Excel' : 'Import จาก Excel',
              onPressed: _importData,
            ),
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: l.isEnglish ? 'Export to Excel' : 'Export ไป Excel',
              onPressed: _exportData,
            ),
          ],
          // ปุ่ม Add/Empty
          // if (_currentList.isEmpty)
          //   IconButton(
          //     icon: const Icon(Icons.add),
          //     tooltip: 'เพิ่มเมนูหลักแรก',
          //     onPressed: _setAddRootMode,
          //   )
          // else
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: l.isEnglish ? 'Delete All' : 'ลบทั้งหมด',
            onPressed: _confirmDeleteAllNode,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double maxLeftWidth =
              (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 36,
                color: Colors.deepOrange[900],
                child: IconButton(
                  icon: Icon(
                    _isLeftPanelExpanded ? Icons.filter_list_off : Icons.filter_list,
                    color: Colors.white,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () =>
                      setState(() => _isLeftPanelExpanded = !_isLeftPanelExpanded),
                  tooltip: _isLeftPanelExpanded
                      ? (l.isEnglish ? 'Collapse' : 'ย่อรายการ')
                      : (l.isEnglish ? 'Expand' : 'ขยายรายการ'),
                ),
              ),
              AnimatedContainer(
                duration: _isDraggingDivider
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                width: _isLeftPanelExpanded ? _leftPanelWidth : 0.0,
                child: ClipRect(
                  child: OverflowBox(
                    maxWidth: _leftPanelWidth,
                    minWidth: _leftPanelWidth,
                    alignment: Alignment.topLeft,
                    child: Container(
                      color: Colors.blueGrey[100],
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _setAddRootMode,
                                icon: const Icon(Icons.add),
                                label: Text(l.isEnglish ? 'Add Root Menu' : 'เพิ่มเมนูหลักใหม่'),
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: topLevelMenus.length,
                              itemBuilder: (context, index) {
                                return _buildNode(topLevelMenus[index], 0, l);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_isLeftPanelExpanded)
                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    onHorizontalDragStart: (_) =>
                        setState(() => _isDraggingDivider = true),
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _leftPanelWidth = (_leftPanelWidth + details.delta.dx)
                            .clamp(200.0, maxLeftWidth);
                      });
                    },
                    onHorizontalDragEnd: (_) =>
                        setState(() => _isDraggingDivider = false),
                    child: Container(width: 5, color: Colors.grey[400]),
                  ),
                ),
              Expanded(
                child: _selectedNode == null && _nodeMode == NodeMode.none
                    ? Center(
                        child: Text(l.isEnglish
                            ? 'Please select a menu or use the left panel buttons'
                            : 'กรุณาเลือกเมนู หรือ ปุ่มการทำงานด้านซ้าย'))
                    : _buildDetailForm(l),
              ),
            ],
          );
        },
      ),
    );
  }
}
