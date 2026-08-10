import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../models/im_item_category.dart';
import '../services/im_item_category_service.dart';

class ImItemCategoryListTreeWidget extends StatefulWidget {
  final bool enableAddRootButton;
  final bool enableAddChildButton;
  final bool enableEditButton;
  final bool enableViewButton;
  final bool enableDeleteButton;
  final bool enableCardSelect;
  final void Function() onAddRoot;
  final void Function(ImItemCategory) onAddChild;
  final Function(ImItemCategory) onEdit;
  final Function(ImItemCategory) onView;
  final Function(ImItemCategory) onDelete;
  final void Function(ImItemCategory) onCallback;

  const ImItemCategoryListTreeWidget({
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
  State<ImItemCategoryListTreeWidget> createState() => ImItemCategoryListTreeWidgetState();

  static Future<void> search(BuildContext context, {required void Function(ImItemCategory) onSelected}) {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: Text(isEnglish ? 'Search Item Category' : 'ค้นหาหมวดหมู่สินค้า',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Container(
          width: 500,
          height: 600,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
          child: ImItemCategoryListTreeWidget(
            enableAddRootButton: false,
            enableAddChildButton: false,
            enableEditButton: false,
            enableViewButton: false,
            enableDeleteButton: false,
            enableCardSelect: true,
            onAddRoot: () {},
            onAddChild: (c) {},
            onEdit: (c) {},
            onView: (c) {},
            onDelete: (c) {},
            onCallback: onSelected,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(isEnglish ? 'Close' : 'ปิด', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class ImItemCategoryListTreeWidgetState extends State<ImItemCategoryListTreeWidget>
    with AutomaticKeepAliveClientMixin {
  List<ImItemCategory> _lists = [];
  bool _isLoading = false;
  final Map<int, bool> _expandedState = {};
  final _svc = ImItemCategoryService();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchLists();
  }

  Future<void> _fetchLists() async {
    setState(() => _isLoading = true);
    try {
      final fetched = await _svc.fetchRows();
      if (mounted) setState(() { _lists = fetched; _isLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEnglish ? 'Failed to load data: $e' : 'ไม่สามารถโหลดข้อมูลได้: $e')),
        );
      }
    }
  }

  void refresh() => _fetchLists();

  List<ImItemCategory> _children(List<ImItemCategory> lists, int? parentId) {
    return lists.where((c) => c.parentId == parentId).toList()
      ..sort((a, b) => a.categoryCode.compareTo(b.categoryCode));
  }

  Widget _buildListHeader(bool isEnglish) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(children: [
        widget.enableAddRootButton
            ? Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onAddRoot,
                  icon: const Icon(Icons.add),
                  label: Text(isEnglish ? 'Add Root Category' : 'เพิ่มหมวดหมู่หลัก'),
                ),
              )
            : const SizedBox.shrink(),
      ]),
    );
  }

  Widget _buildNode(ImItemCategory item, int level, bool isEnglish) {
    final bool isInactive = !item.isActive;
    final children = _children(_lists, item.id);
    final bool hasChildren = children.isNotEmpty;
    final bool isExpanded = _expandedState[item.id] ?? false;

    final Color textColor = isInactive ? Colors.grey.shade400 : Colors.black87;
    final Color actionColor = isInactive ? Colors.grey.shade400 : Colors.teal;
    final Color deleteColor = isInactive ? Colors.grey.shade400 : Colors.red;
    final name = isEnglish && (item.categoryNameEn ?? '').isNotEmpty ? item.categoryNameEn! : item.categoryNameTh;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            if (hasChildren) {
              setState(() => _expandedState[item.id] = !isExpanded);
            } else if (widget.enableViewButton) {
              widget.onView(item);
            }
          },
          child: Padding(
            padding: EdgeInsets.only(left: level * 16.0),
            child: Row(children: [
              if (hasChildren)
                Icon(isExpanded ? Icons.arrow_drop_down : Icons.arrow_right, color: textColor)
              else
                const SizedBox(width: 24),
              Icon(isInactive ? Icons.block : Icons.category_outlined,
                  color: isInactive ? Colors.grey.shade400 : Colors.black54, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${item.categoryCode} $name',
                  style: TextStyle(
                    fontSize: 16,
                    color: textColor,
                    fontStyle: isInactive ? FontStyle.italic : FontStyle.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.enableAddChildButton)
                IconButton(
                  icon: Icon(Icons.add_circle_outline, size: 20, color: actionColor),
                  tooltip: isEnglish ? 'Add sub-category' : 'เพิ่มหมวดหมู่ย่อย',
                  onPressed: () => widget.onAddChild(item),
                ),
              if (widget.enableEditButton)
                IconButton(
                  icon: Icon(Icons.edit, color: actionColor, size: 20),
                  tooltip: isEnglish ? 'Edit' : 'แก้ไข',
                  onPressed: () => widget.onEdit(item),
                ),
              if (widget.enableDeleteButton)
                IconButton(
                  icon: Icon(Icons.delete, size: 20, color: deleteColor),
                  tooltip: isEnglish ? 'Delete' : 'ลบ',
                  onPressed: () {
                    if (hasChildren) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(isEnglish
                                ? 'Cannot delete a category with sub-categories. Remove them first.'
                                : 'ไม่สามารถลบหมวดหมู่ที่มีหมวดหมู่ย่อยได้ กรุณาลบหมวดหมู่ย่อยออกก่อน'),
                            backgroundColor: Colors.red),
                      );
                    } else {
                      widget.onDelete(item);
                    }
                  },
                ),
              if (widget.enableCardSelect)
                IconButton(
                  icon: const Icon(Icons.arrow_right_outlined, color: Colors.black),
                  onPressed: () {
                    if (item.isActive) {
                      widget.onCallback(item);
                      Navigator.of(context).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(isEnglish ? 'Cannot use: this category is inactive' : 'ไม่สามารถใช้ได้ เนื่องจากหมวดหมู่นี้หยุดใช้งาน'),
                            backgroundColor: Colors.red),
                      );
                    }
                  },
                ),
            ]),
          ),
        ),
        if (isExpanded && hasChildren)
          Column(children: children.map((c) => _buildNode(c, level + 1, isEnglish)).toList()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final topLevel = _children(_lists, null);

    return Column(children: [
      _buildListHeader(isEnglish),
      Expanded(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : topLevel.isEmpty
                ? Center(child: Text(isEnglish ? 'No category data found' : 'ไม่พบข้อมูลหมวดหมู่สินค้า'))
                : ListView.builder(
                    itemCount: topLevel.length,
                    itemBuilder: (context, index) => _buildNode(topLevel[index], 0, isEnglish),
                  ),
      ),
    ]);
  }
}
