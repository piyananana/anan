// screens/menu_management_screen.dart
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../utils/menu_scope.dart';

import '../models/group.dart';
import '../services/group_service.dart';

// Enum เพื่อบอกสถานะของ Form
enum NodeMode {
  addRoot,
  addChild,
  edit,
  none,
}

class GroupManagementScreen extends StatefulWidget {
  // final List<Group> initialMenus; // รับเมนูเริ่มต้นมา
  // final VoidCallback onChanged; // Callback เมื่อมีการเปลี่ยนแปลงเมนู
  final VoidCallback? onExit; // <-- เพิ่ม Callback นี้

  const GroupManagementScreen({
    super.key,
    // required this.initialMenus,
    // required this.onChanged,
    this.onExit, // <-- รับเข้ามา
  });

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> with AutomaticKeepAliveClientMixin {
  // late List<Group> _currentList;
  List<Group> _currentList = []; // กำหนดค่าเริ่มต้นเป็น List ว่างเปล่า
  bool _isLoading = true; // เพิ่มสถานะการโหลดเมนู
  String _errorLoading = ''; // เพิ่มข้อความ error
  final Map<String?, bool> _expandedState = {};
  Group? _selectedNode; // เมนูที่ถูกเลือกใน TreeView
  NodeMode _formMode = NodeMode.none; // โหมดของ Form
  String? _parentIdForNew; // สำหรับโหมด addChild
  String? _parentNameForNew; // สำหรับโหมด addChild

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  bool _isActive = true;
  bool _haveSubGroup = true;
  bool _canClosePeriod = false;
  final TextEditingController _descriptionController = TextEditingController();

  bool _isLeftPanelExpanded = true;
  double _leftPanelWidth = 360.0;
  bool _isDraggingDivider = false;
  // final TextEditingController _contactPersonController = TextEditingController();
  // final TextEditingController _phoneNumberController = TextEditingController();
  // final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // _currentList = List.from(widget.initialMenus); // ทำสำเนา
    _fetchData(); // <-- เรียกเมธอด fetch เพื่อโหลดเมนูเมื่อ Widget ถูกสร้าง
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    // _contactPersonController.dispose();
    // _phoneNumberController.dispose();
    // _emailController.dispose();
    super.dispose();
  }

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive => true;

  // *** NEW: Method สำหรับ Fetch เมนูทั้งหมด ***
  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorLoading = '';
    });
    try {
      final service = Provider.of<GroupService>(context, listen: false);
      final fetchedData = await service.fetchData();
      setState(() {
        _currentList = fetchedData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorLoading = 'ไม่สามารถโหลดข้อมูลได้: ${e.toString()}';
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorLoading)),
      );
    }
  }

  // --- Utility Methods ---
  List<Group> _buildTree(List<Group> dataList, String? parentId) {
    return dataList
        .where((data) => data.parentId == parentId)
        .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
  }

  void _clearForm() {
    _nameController.clear();
    _descriptionController.clear();
    // _contactPersonController.clear();
    // _phoneNumberController.clear();
    // _emailController.clear();
    setState(() {
      _isActive = true;
      _haveSubGroup = true;
      _canClosePeriod = false;
      _selectedNode = null;
      _formMode = NodeMode.none;
      _parentIdForNew = null;
      _parentNameForNew = null;
    });
  }

  // --- Form Logic ---
  void _setAddRootMode() {
    _clearForm();
    setState(() {
      _formMode = NodeMode.addRoot;
      _selectedNode = null;
      _parentIdForNew = null; // Clear parent ID
      _nameController.text = '';
      _descriptionController.text = '';
      _isActive = true;
      _haveSubGroup = true;
      _canClosePeriod = false;
    });
  }

  void _setAddChildMode(Group parentRowData) {
    _clearForm();
    setState(() {
      _formMode = NodeMode.addChild;
      _selectedNode = parentRowData;
      _parentIdForNew = parentRowData.id;
      _parentNameForNew = parentRowData.name;
      _nameController.text = '';
      _descriptionController.text = '';
      _isActive = true;
      _haveSubGroup = true;
      _canClosePeriod = false;
    });
  }

  void _setEditMode(Group rowData) {
    _clearForm();
    setState(() {
      _formMode = NodeMode.edit;
      _selectedNode = rowData;
      _nameController.text = rowData.name;
      _descriptionController.text = rowData.description ?? '';
      _isActive = rowData.isActive;
      _haveSubGroup = rowData.haveSubGroup;
      _canClosePeriod = rowData.canClosePeriod;
    });
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;

    final service = Provider.of<GroupService>(context, listen: false);
    String? message;

    try {
      final data = Group(
        id: _selectedNode?.id,
        name: _nameController.text,
        parentId: _formMode == NodeMode.addRoot ? null
            : _formMode == NodeMode.addChild ? _parentIdForNew
            : _selectedNode?.parentId,
        isActive: _isActive,
        haveSubGroup: _haveSubGroup,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        canClosePeriod: _canClosePeriod,
      );
      if (_formMode == NodeMode.addRoot || _formMode == NodeMode.addChild) {
        final newData = await service.createData(data);
        message = 'เพิ่มข้อมูล "${newData.name}" สำเร็จ';
      } else if (_formMode == NodeMode.edit && _selectedNode != null) {
        final updatedData = await service.updateData(data);
        message = 'แก้ไขข้อมูล "${updatedData.name}" สำเร็จ';
      }
      _clearForm();
      await _refreshAllData(); // โหลดข้อมูลใหม่หลังจากเพิ่ม/แก้ไข
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message!)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: ${e.toString()}')));
      }
    }
  }

  Future<void> _confirmDeleteData(Group rowData) async {
    if (_buildTree(_currentList, rowData.id).isNotEmpty && rowData.haveSubGroup) {
      // ป้องกันการลบ Folder ที่มีเมนูย่อย
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถลบรายการที่มีรายการย่อยได้ กรุณาลบรายการย่อยออกก่อน')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ยืนยันการลบข้อมูล'),
          content: Text('คุณแน่ใจหรือไม่ว่าต้องการลบข้อมูล "${rowData.name}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('ยกเลิก')),
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
        await Provider.of<GroupService>(context, listen: false).deleteData(rowData.id);
        _clearForm();
        await _refreshAllData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ลบข้อมูล "${rowData.name}" สำเร็จ')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดในการลบ: ${e.toString()}')));
        }
      }
    }
  }

  // ปรับปรุง _refreshAllData ให้เรียก _fetchData ของตัวเอง
  // และแจ้ง Home Screen ด้วย
  Future<void> _refreshAllData() async {
    await _fetchData(); // โหลดเมนูใหม่สำหรับหน้าจอนี้
    // widget.onChanged(); // แจ้ง Home Screen ด้วย
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    // ต้องตรวจสอบสถานะการโหลดก่อนสร้าง UI
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorLoading.isNotEmpty) {
      return Center(child: Text(_errorLoading));
    }

    final List<Group> topLevelData = _buildTree(_currentList, null);

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
            tooltip: 'รีเฟรชรายการ',
            onPressed: _refreshAllData,
          ),
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
                  tooltip: _isLeftPanelExpanded ? 'ย่อรายการ' : 'ขยายรายการ',
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
                                label: const Text('เพิ่มรายกาารหลัก'),
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: topLevelData.length,
                              itemBuilder: (context, index) {
                                return _buildNode(topLevelData[index], 0);
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
                child: _selectedNode == null && _formMode == NodeMode.none
                    ? const Center(
                        child: Text('กรุณาเลือกกลุ่ม หรือ ปุ่มการทำงานจากด้านซ้าย'))
                    : _buildDetailForm(),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Build Methods ---
  Widget _buildNode(Group rowData, int level) {
    final bool isFolder = rowData.haveSubGroup;
    final List<Group> children = _buildTree(_currentList, rowData.id);
    final bool hasChildren = children.isNotEmpty;
    final bool isExpanded = _expandedState[rowData.id] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: () {
                if (isFolder && hasChildren) {
                  setState(() {
                    _expandedState[rowData.id] = !isExpanded;
                  });
                } else {
                  _setEditMode(rowData); // คลิกเมนูเพื่อแก้ไขรายละเอียด
                }
              },
              child: Padding(
                padding: EdgeInsets.only(left: level * 16.0),
                child: Row(
                  children: [
                    if (isFolder && hasChildren)
                      Icon(isExpanded ? Icons.arrow_drop_down : Icons.arrow_right),
                    if (!isFolder || !hasChildren)
                      const SizedBox(width: 24),
                    Icon(isFolder ? Icons.group_work
                      : Icons.groups_3),
                    const SizedBox(width: 8),
                    // Icon(Icons.groups_3),
                    Expanded(
                      child: Text(
                        rowData.name,
                        style: const TextStyle(fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Icon ปุ่ม Add สำหรับ Folder
                    if (isFolder)
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        tooltip: 'เพิ่มรายการย่อย',
                        onPressed: () => _setAddChildMode(rowData),
                      ),
                    // Icon ปุ่ม Edit
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                      tooltip: 'แก้ไข',
                      onPressed: () => _setEditMode(rowData),
                    ),
                    // Icon ปุ่ม Delete
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                      tooltip: 'ลบ',
                      onPressed: () => _confirmDeleteData(rowData),
                    ),
                  ],
                ),
              ),
            ),
            if (!rowData.isActive)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Icon(Icons.block, size: 48,
                        color: Colors.red.withOpacity(0.12)),
                  ),
                ),
              ),
          ],
        ),
        if (isExpanded && hasChildren)
          Column(
            children: children
                .map((child) => _buildNode(child, level + 1))
                .toList(),
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
              _formMode == NodeMode.addRoot
                  ? 'เพิ่มรายการหลัก'
                  : _formMode == NodeMode.addChild
                      ? 'เพิ่มรายการย่อย: ${_parentNameForNew ?? ''}'
                      : _formMode == NodeMode.edit
                          ? 'แก้ไข: ${_selectedNode?.name ?? ''}'
                          : 'เลือกรายการหรือเพิ่มรายการหลักใหม่',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'ชื่อ',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณาป้อนชื่อ';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text('สถานะ: ${_isActive ? 'ใช้งาน' : 'หยุดใช้'}'),
              value: _isActive,
              onChanged: (bool value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),
            SwitchListTile(
              title: Text(_haveSubGroup ? 'มีใต้สังกัด' : 'ไม่มีใต้สังกัด'),
              value: _haveSubGroup,
              onChanged: (bool value) {
                setState(() {
                  _haveSubGroup = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('สิทธิ์อนุมัติการปิดงวดบัญชี'),
              subtitle: const Text(
                'กลุ่มนี้สามารถอนุมัติการเปลี่ยนสถานะงวดบัญชีเป็น CLOSED ได้',
                style: TextStyle(fontSize: 12),
              ),
              secondary: Icon(
                Icons.lock,
                color: _canClosePeriod ? Colors.red : Colors.grey,
              ),
              value: _canClosePeriod,
              onChanged: (bool value) {
                setState(() {
                  _canClosePeriod = value;
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'คำอธิบาย',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            // const SizedBox(height: 16),
            // TextFormField(
            //   controller: _contactPersonController,
            //   decoration: const InputDecoration(
            //     labelText: 'ผู้ประสานงานหลัก',
            //     border: OutlineInputBorder(),
            //   ),
            // ),
            // const SizedBox(height: 16),
            // TextFormField(
            //   controller: _phoneNumberController,
            //   decoration: const InputDecoration(
            //     labelText: 'เบอร์โทรศัพท์',
            //     border: OutlineInputBorder(),
            //   ),
            //   keyboardType: TextInputType.phone,
            // ),
            // const SizedBox(height: 16),
            // TextFormField(
            //   controller: _emailController,
            //   decoration: const InputDecoration(
            //     labelText: 'อีเมล',
            //     border: OutlineInputBorder(),
            //   ),
            //   keyboardType: TextInputType.emailAddress,
            // ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_formMode != NodeMode.none)
                  TextButton(
                    onPressed: _clearForm,
                    child: const Text('ยกเลิก'),
                  ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _formMode == NodeMode.none ? null : _submitData,
                  child: Text(_formMode == NodeMode.edit ? 'บันทึกการแก้ไข' : 'บันทึกข้อมูลใหม่'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
}