// widgets/zipcode_list_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/module_document.dart';
import '../services/language_provider.dart';
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

  static Future<void> search(BuildContext context,
      {required void Function(ModuleDocument) onSelected}) {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          title: Text(
            isEnglish ? 'Search Document Type' : 'ค้นหา ประเภทเอกสาร',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Container(
            width: 500,
            height: 600,
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
              child: Text(isEnglish ? 'Close' : 'ปิด',
                  style: const TextStyle(color: Colors.red)),
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
      final isEnglish = mounted
          ? Provider.of<LanguageProvider>(context, listen: false).isEnglish
          : false;
      setState(() {
        _error = isEnglish
            ? 'Cannot load data: ${e.toString()}'
            : 'ไม่สามารถโหลดข้อมูลได้: ${e.toString()}';
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

  Widget _buildListHeader(bool isEnglish) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          widget.enableAddRootButton
              ? Expanded(child:
                  ElevatedButton.icon(
                    onPressed: () => widget.onAddRoot(),
                    icon: const Icon(Icons.add),
                    label: Text(isEnglish ? 'Add Main Module' : 'เพิ่มโมดูลหลัก'),
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

  Widget _buildNode(ModuleDocument item, int level, bool isEnglish) {
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
                if (isHeader && widget.enableAddChildButton)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    tooltip: isEnglish ? 'Add Sub-item' : 'เพิ่มรายการย่อย',
                    onPressed: () => widget.onAddChild(item),
                  ),
                widget.enableEditButton
                    ? IconButton(
                        icon: const Icon(Icons.edit,
                            color: Colors.blue, size: 20),
                        tooltip: isEnglish ? 'Edit' : 'แก้ไข',
                        onPressed: () => widget.onEdit(item),
                      )
                    : const SizedBox.shrink(),
                widget.enableDeleteButton
                    ? IconButton(
                        icon: const Icon(Icons.delete,
                            size: 20, color: Colors.red),
                        tooltip: isEnglish ? 'Delete' : 'ลบ',
                        onPressed: () {
                          if (_buildTree(_lists, item.id).isNotEmpty &&
                              item.isDocType == false) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isEnglish
                                    ? 'Cannot delete an item with sub-items. Please delete sub-items first.'
                                    : 'ไม่สามารถลบรายการที่มีรายการย่อยได้ กรุณาลบรายการย่อยออกก่อน'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } else {
                            widget.onDelete(item);
                          }
                        },
                      )
                    : const SizedBox.shrink(),
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
                              SnackBar(
                                content: Text(isEnglish
                                    ? 'Cannot select: this is a main type or inactive'
                                    : 'ไม่สามารถใช้ได้ เนื่องจากเป็นประเภทหลัก หรือ หยุดใช้'),
                                backgroundColor: Colors.red,
                              ),
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
                children.map((child) => _buildNode(child, level + 1, isEnglish)).toList(),
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
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final List<ModuleDocument> topLevelLists = _buildTree(_lists, null);

    return Column(
      children: [
        _buildListHeader(isEnglish),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Expanded(
                  child: ListView.builder(
                    itemCount: topLevelLists.length,
                    itemBuilder: (context, index) {
                      return _buildNode(topLevelLists[index], 0, isEnglish);
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
