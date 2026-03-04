// widgets/zipcode_list_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/module_document.dart';
import '../services/module_document_service.dart';

class ModuleDocumentListTreeWidget extends StatefulWidget {
  final bool enableAddRootButton;
  final bool enableAddChildButton;
  final bool enableEditButton;
  final bool enableViewButton;
  final bool enableDeleteButton;
  final bool enableCardSelect;
  final void Function() onAddRoot;
  final void Function(ModuleDocument) onAddChild;
  final Function(ModuleDocument) onEdit;
  final Function(ModuleDocument) onView;
  final Function(ModuleDocument) onDelete;
  final void Function(ModuleDocument) onCallback;

  const ModuleDocumentListTreeWidget({
    super.key,
    required this.enableAddRootButton,
    required this.enableAddChildButton,
    required this.enableEditButton,
    required this.enableViewButton,
    required this.enableDeleteButton,
    required this.enableCardSelect,
    required this.onAddRoot,
    required this.onAddChild,
    required this.onEdit,
    required this.onView,
    required this.onDelete,
    required this.onCallback,
  });

  @override
  State<ModuleDocumentListTreeWidget> createState() => ModuleDocumentListTreeWidgetState();

  // เมธอด static สำหรับแสดง Dialog
  static Future<void> search(BuildContext context,
      {required void Function(ModuleDocument) onSelected}) {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          // กำหนดขนาดให้ใหญ่ขึ้นเพื่อให้ใช้งานสะดวก
          contentPadding: EdgeInsets.zero,
          title: const Text('ค้นหา ประเภทเอกสาร',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Container(
            width: 500, // กำหนดความกว้างที่เหมาะสม
            height: 600, // กำหนดความสูงที่เหมาะสม
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: ModuleDocumentListTreeWidget(
              enableAddRootButton: false,
              enableAddChildButton: false,
              enableEditButton: false,
              enableViewButton: false,
              enableDeleteButton: false,
              enableCardSelect: true,
              onAddRoot: () {},
              onAddChild: (moduleDocument) {},
              onEdit: (moduleDocument) {},
              onView: (moduleDocument) {},
              onDelete: (moduleDocument) {},
              onCallback: onSelected,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ปิด', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

class ModuleDocumentListTreeWidgetState extends State<ModuleDocumentListTreeWidget>
    with AutomaticKeepAliveClientMixin {
  List<ModuleDocument> _lists = [];
  bool _isLoading = false;
  String _error = '';
  final Map<int, bool> _expandedState = {};

  Future<void> _fetchLists() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final dataService = Provider.of<ModuleDocumentService>(context, listen: false);
      final fetched = await dataService.fetchRows();
      setState(() {
        _lists = fetched;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'ไม่สามารถโหลดข้อมูลได้: ${e.toString()}';
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_error)),
        );
      }
    }
  }

  void refresh() {
    _fetchLists();
  }

  @override
  void initState() {
    super.initState();
    _fetchLists();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          widget.enableAddRootButton
              ? Expanded(child: 
                  ElevatedButton.icon(
                    onPressed: () => widget.onAddRoot(),
                    icon: const Icon(Icons.add),
                    label: const Text('เพิ่มโมดูลหลัก')
                  )
              )
              : const SizedBox.shrink(),
        ],
      ),
    );
  }

  List<ModuleDocument> _buildTree(List<ModuleDocument> lists, int? parentId) {
    return lists.where((list) => list.parentId == parentId).toList()
      // ..sort((a, b) => a.docCode.compareTo(b.docCode));
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  // --- Build Methods ---
  Widget _buildNode(ModuleDocument item, int level) {
    final bool isHeader = item.isDocType == false;
    final List<ModuleDocument> children = _buildTree(_lists, item.id);
    final bool hasChildren = children.isNotEmpty;
    final bool isExpanded = _expandedState[item.id] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            if (isHeader && hasChildren) {
              setState(() {
                _expandedState[item.id] = !isExpanded;
              });
            } else if (widget.enableViewButton) {
              widget.onView(item);
            }
          },
          child: Padding(
            padding: EdgeInsets.only(left: level * 16.0),
            child: Row(
              children: [
                if (isHeader && hasChildren)
                  Icon(isExpanded ? Icons.arrow_drop_down : Icons.arrow_right),
                if (!isHeader || !hasChildren) const SizedBox(width: 24),
                Icon(isHeader
                    ? Icons.summarize_outlined // folder
                    : Icons.list_outlined), // insert_drive_file),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${item.docCode} ${item.docNameThai}',
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Icon ปุ่ม Add สำหรับ Header
                if (isHeader && widget.enableAddChildButton)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    tooltip: 'เพิ่มรายการย่อย',
                    onPressed: () => widget.onAddChild(item),
                  ),
                // Icon ปุ่ม Edit
                widget.enableEditButton
                    ? IconButton(
                        icon: const Icon(Icons.edit,
                            color: Colors.blue, size: 20),
                        tooltip: 'แก้ไข',
                        onPressed: () => widget.onEdit(item),
                      )
                    : const SizedBox.shrink(),
                // Icon ปุ่ม Delete
                widget.enableDeleteButton
                    ? IconButton(
                        icon: const Icon(Icons.delete,
                            size: 20, color: Colors.red),
                        tooltip: 'ลบ',
                        onPressed: () {
                          if (_buildTree(_lists, item.id).isNotEmpty &&
                              item.isDocType == false) {
                            // ป้องกันการลบหัวบัญชี
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'ไม่สามารถลบรายการที่มีรายการย่อยได้ กรุณาลบรายการย่อยออกก่อน'),
                                      backgroundColor: Colors.red,),
                            );
                          } else {
                            widget.onDelete(item);
                          }
                        },
                      )
                    : const SizedBox.shrink(),
                // Icon ปุ่ม search
                widget.enableCardSelect
                    ? IconButton(
                        icon: const Icon(Icons.arrow_right_outlined,
                            color: Colors.black),
                        onPressed: () {
                          if (item.isActive && item.isDocType) {
                            widget.onCallback(item);
                            Navigator.of(context).pop();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'ไม่สามารถใช้ได้ เนื่องจากเป็นประเภทหลัก หรือ หยุดใช้'),
                                      backgroundColor: Colors.red,),
                            );
                          }
                        },
                      )
                    : const SizedBox.shrink(),
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

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final List<ModuleDocument> topLevelLists = _buildTree(_lists, null);

    return Column(
      children: [
        _buildListHeader(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Expanded(
                  child: ListView.builder(
                    itemCount: topLevelLists.length,
                    itemBuilder: (context, index) {
                      return _buildNode(topLevelLists[index], 0);
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
