// screens/menu_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_resizable_container/flutter_resizable_container.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/menu.dart';
import '../services/menu_service.dart';

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
  final TextEditingController _targetPathController = TextEditingController();
  final TextEditingController _sortOrderController = TextEditingController();
  String _menuType = 'folder'; // Default
  String _contentType = 'widget'; // Default for content
  final TextEditingController _contentDataController = TextEditingController();
  bool _isActive = true;
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
    _targetPathController.clear();
    _sortOrderController.clear();
    _contentDataController.clear();
    setState(() {
      _menuType = 'folder';
      _contentType = 'widget';
      _isActive = true;
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
      _targetPathController.text = menu.targetPath ?? '';
      _sortOrderController.text = menu.sortOrder.toString();
      _menuType = menu.menuType;
      // ถ้ามีการเก็บ content ใน model/db (ตอนนี้ Menu model ไม่มี field นี้โดยตรง)
      // คุณอาจจะต้อง fetch menu_contents แยก หรือให้ Menu model มี fields นี้
      // สำหรับตอนนี้ เราสมมติว่า content data จะถูกโหลดในฟอร์มเมื่อแก้ไข
      _loadContentForEdit(menu.id); // โหลด content เพิ่มเติม
      _isActive = true; // จาก DB
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
          menuType: _menuType,
          targetPath: _targetPathController.text.isEmpty
              ? null
              : _targetPathController.text,
          sortOrder: int.tryParse(_sortOrderController.text),
          contentType: _contentType,
          contentData: _contentDataController.text.isEmpty
              ? null
              : _contentDataController.text,
        );
        message = 'เพิ่มเมนู "${newMenu.menuName}" สำเร็จ';
      } else if (_nodeMode == NodeMode.edit && _selectedNode != null) {
        final updatedMenu = await masterService.updateMenu(
          _selectedNode!.id,
          menuName: _menuNameController.text,
          menuType: _menuType,
          targetPath: _targetPathController.text.isEmpty
              ? null
              : _targetPathController.text,
          sortOrder: int.tryParse(_sortOrderController.text) ??
              _selectedNode!.sortOrder,
          isActive: _isActive, // ต้องมาจาก Form หรือ DB
          contentType: _contentType,
          contentData: _contentDataController.text.isEmpty
              ? null
              : _contentDataController.text,
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
    if (_buildTree(_currentList, menu.id).isNotEmpty &&
        menu.menuType == 'folder') {
      // ป้องกันการลบ Folder ที่มีเมนูย่อย
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'ไม่สามารถลบ Folder ที่มีเมนูย่อยได้ กรุณาลบเมนูย่อยออกก่อน')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ยืนยันการลบเมนู'),
          content: Text('คุณแน่ใจหรือไม่ว่าต้องการลบเมนู "${menu.menuName}"?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('ยกเลิก')),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('ลบ', style: TextStyle(color: Colors.white)),
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
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('ลบเมนู "${menu.menuName}" สำเร็จ')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('เกิดข้อผิดพลาดในการลบ: ${e.toString()}')));
        }
      }
    }
  }

  Future<void> _confirmDeleteAllNode() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ยืนยันการลบเมนูทั้งหมด'),
          content: const Text(
              'คุณแน่ใจหรือไม่ว่าต้องการลบข้อมูลเมนูทั้งหมด? การกระทำนี้ไม่สามารถย้อนกลับได้!'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('ยกเลิก')),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('ลบทั้งหมด',
                  style: TextStyle(color: Colors.white)),
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
  Widget _buildNode(Menu menu, int level) {
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
                  child: Text(
                    menu.menuName,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Icon ปุ่ม Add สำหรับ Folder
                if (isFolder)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    tooltip: 'เพิ่มเมนูย่อย',
                    onPressed: () => _setAddChildMode(menu),
                  ),
                // Icon ปุ่ม Edit
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                  tooltip: 'แก้ไขเมนู',
                  onPressed: () => _setEditMode(menu),
                ),
                // Icon ปุ่ม Delete
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  tooltip: 'ลบเมนู',
                  onPressed: () => _confirmDeleteMenu(menu),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded && hasChildren)
          Column(
            children:
                children.map((child) => _buildNode(child, level + 1)).toList(),
          ),
      ],
    );
  }

  Widget _buildDetailForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _nodeMode == NodeMode.addRoot
                  ? 'เพิ่มเมนูหลัก'
                  : _nodeMode == NodeMode.addChild
                      ? 'เพิ่มเมนูย่อย: ${_selectedNode?.menuName ?? ''}'
                      : _nodeMode == NodeMode.edit
                          ? 'แก้ไขเมนู: ${_selectedNode?.menuName ?? ''}'
                          : 'เลือกเมนูหรือเพิ่มเมนูใหม่',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _menuNameController,
              decoration: const InputDecoration(
                labelText: 'ชื่อเมนู',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณาป้อนชื่อเมนู';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _menuType,
              decoration: const InputDecoration(
                labelText: 'ประเภทเมนู',
                border: OutlineInputBorder(),
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
                decoration: const InputDecoration(
                  labelText: 'Widget/Class Name หรือ Link Path',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (_menuType != 'folder' && value == null) {
                    // (value == null || value.isEmpty)) {
                    return 'กรุณาป้อน Widget/Class Name หรือ Link Path';
                  }
                  return null;
                },
              ),
            if (_menuType != 'folder') const SizedBox(height: 16),
            // ส่วนสำหรับ Content (ถ้าเป็น link/widget)
            if (_menuType != 'folder')
              DropdownButtonFormField<String>(
                value: _contentType,
                decoration: const InputDecoration(
                  labelText: 'ประเภท Content',
                  border: OutlineInputBorder(),
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
              decoration: const InputDecoration(
                labelText: 'ลำดับการแสดงผล',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณาป้อนลำดับ';
                }
                if (int.tryParse(value) == null) {
                  return 'ต้องเป็นตัวเลขเท่านั้น';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            if (_nodeMode == NodeMode.edit)
              Row(
                children: [
                  const Text('สถานะ: '),
                  Switch(
                    value: _isActive,
                    onChanged: (bool value) {
                      setState(() {
                        _isActive = value;
                      });
                    },
                  ),
                  Text(_isActive ? 'Active' : 'Inactive'),
                ],
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_nodeMode != NodeMode.none)
                  TextButton(
                    onPressed: _clearForm,
                    child: const Text('ยกเลิก'),
                  ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _nodeMode == NodeMode.none ? null : _submitMenu,
                  child: Text(_nodeMode == NodeMode.edit
                      ? 'บันทึกการแก้ไข'
                      : 'บันทึกข้อมูลใหม่'),
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
        title: const Text('จัดการเมนู'),
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
              tooltip: 'Import จาก Excel',
              onPressed: _importData,
            ),
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Export ไป Excel',
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
            tooltip: 'ลบทั้งหมด',
            onPressed: _confirmDeleteAllNode,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ResizableContainer(
        controller: ResizableController(),
        direction: Axis.horizontal,
        children: [
          ResizableChild(
            divider: ResizableDivider(
              color: Colors.blueGrey[200]!,
              thickness: 5,
            ),
            size: const ResizableSize.ratio(0.4), // 30% สำหรับ panel ซ้าย
            child: Container(
              color: Colors.blueGrey[100],
              child: Column(
                children: [
                  // ปุ่มเพิ่มเมนูหลัก เมื่อมีเมนูอยู่แล้ว (ไม่ซ้ำกับ AppBar)
                  // if (_currentList.isNotEmpty && _nodeMode == NodeMode.none)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _setAddRootMode,
                        icon: const Icon(Icons.add),
                        label: const Text('เพิ่มเมนูหลักใหม่'),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: topLevelMenus.length,
                      itemBuilder: (context, index) {
                        return _buildNode(topLevelMenus[index], 0);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          ResizableChild(
            size: const ResizableSize.ratio(0.6), // 60% สำหรับ panel ขวา
            child: _selectedNode == null && _nodeMode == NodeMode.none
                ? const Center(
                    child: Text('กรุณาเลือกเมนู หรือ ปุ่มการทำงานด้านซ้าย'))
                : _buildDetailForm(),
          ),
        ],
      ),
    );
  }
}
