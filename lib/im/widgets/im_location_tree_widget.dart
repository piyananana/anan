import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../models/im_location.dart';
import '../services/im_location_service.dart';

class ImLocationTreeWidget extends StatefulWidget {
  final int warehouseId;
  final bool enableAddRootButton;
  final bool enableAddChildButton;
  final bool enableEditButton;
  final bool enableViewButton;
  final bool enableDeleteButton;
  final bool enableCardSelect;
  // ถ้า true (ใช้ตอนเลือกตำแหน่งจัดเก็บ) จะแสดง/เลือกได้เฉพาะ BIN เท่านั้น
  final bool binOnly;
  final void Function() onAddRoot;
  final void Function(ImLocation) onAddChild;
  final Function(ImLocation) onEdit;
  final Function(ImLocation) onView;
  final Function(ImLocation) onDelete;
  final void Function(ImLocation) onCallback;

  const ImLocationTreeWidget({
    super.key,
    required this.warehouseId,
    required this.enableAddRootButton,
    required this.enableAddChildButton,
    required this.enableEditButton,
    required this.enableViewButton,
    required this.enableDeleteButton,
    required this.enableCardSelect,
    this.binOnly = false,
    required this.onAddRoot,
    required this.onAddChild,
    required this.onEdit,
    required this.onView,
    required this.onDelete,
    required this.onCallback,
  });

  @override
  State<ImLocationTreeWidget> createState() => ImLocationTreeWidgetState();

  static Future<void> search(BuildContext context, {required int warehouseId, required void Function(ImLocation) onSelected}) {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: Text(isEnglish ? 'Search Storage Location' : 'ค้นหาตำแหน่งจัดเก็บ',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Container(
          width: 500,
          height: 600,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
          child: ImLocationTreeWidget(
            warehouseId: warehouseId,
            enableAddRootButton: false,
            enableAddChildButton: false,
            enableEditButton: false,
            enableViewButton: false,
            enableDeleteButton: false,
            enableCardSelect: true,
            binOnly: true,
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

class ImLocationTreeWidgetState extends State<ImLocationTreeWidget>
    with AutomaticKeepAliveClientMixin {
  List<ImLocation> _lists = [];
  bool _isLoading = false;
  final Map<int, bool> _expandedState = {};
  final _svc = ImLocationService();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchLists();
  }

  @override
  void didUpdateWidget(covariant ImLocationTreeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.warehouseId != oldWidget.warehouseId) _fetchLists();
  }

  Future<void> _fetchLists() async {
    setState(() => _isLoading = true);
    try {
      final fetched = await _svc.fetchRows(warehouseId: widget.warehouseId);
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

  List<ImLocation> _children(List<ImLocation> lists, int? parentId) {
    return lists.where((c) => c.parentId == parentId).toList()
      ..sort((a, b) => a.locationCode.compareTo(b.locationCode));
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
                  label: Text(isEnglish ? 'Add Location' : 'เพิ่มตำแหน่ง'),
                ),
              )
            : const SizedBox.shrink(),
      ]),
    );
  }

  Widget _buildNode(ImLocation item, int level, bool isEnglish) {
    final bool isInactive = !item.isActive;
    final bool isGroup = item.locationType == 'GROUP';
    final bool isSelectable = !widget.binOnly || !isGroup;
    final children = _children(_lists, item.id);
    final bool hasChildren = children.isNotEmpty;
    final bool isExpanded = _expandedState[item.id] ?? false;

    final Color textColor = isInactive ? Colors.grey.shade400 : Colors.black87;
    final Color actionColor = isInactive ? Colors.grey.shade400 : Colors.teal;
    final Color deleteColor = isInactive ? Colors.grey.shade400 : Colors.red;
    final categoryName = isEnglish && (item.categoryNameEn ?? '').isNotEmpty ? item.categoryNameEn : item.categoryNameTh;

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
              Icon(
                isInactive
                    ? Icons.block
                    : isGroup
                        ? Icons.folder_outlined
                        : Icons.inventory_2_outlined,
                color: isInactive ? Colors.grey.shade400 : Colors.black54,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(children: [
                  Flexible(
                    child: Text(
                      '${item.locationCode}  ${item.locationName ?? ''}',
                      style: TextStyle(
                        fontSize: 16,
                        color: textColor,
                        fontStyle: isInactive ? FontStyle.italic : FontStyle.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isGroup && item.categoryId != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Text(
                        '${item.categoryCode} $categoryName',
                        style: TextStyle(fontSize: 11, color: Colors.teal.shade800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else if (!isGroup)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        isEnglish ? '(no category set)' : '(ยังไม่กำหนดหมวดหมู่)',
                        style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontStyle: FontStyle.italic),
                      ),
                    ),
                ]),
              ),
              if (widget.enableAddChildButton && isGroup)
                IconButton(
                  icon: Icon(Icons.add_circle_outline, size: 20, color: actionColor),
                  tooltip: isEnglish ? 'Add sub-location' : 'เพิ่มตำแหน่งย่อย',
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
                                ? 'Cannot delete a location with sub-locations. Remove them first.'
                                : 'ไม่สามารถลบตำแหน่งที่มีตำแหน่งย่อยได้ กรุณาลบตำแหน่งย่อยออกก่อน'),
                            backgroundColor: Colors.red),
                      );
                    } else {
                      widget.onDelete(item);
                    }
                  },
                ),
              if (widget.enableCardSelect)
                IconButton(
                  icon: Icon(Icons.arrow_right_outlined, color: isSelectable ? Colors.black : Colors.grey.shade300),
                  onPressed: () {
                    if (!isSelectable) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(isEnglish ? 'This is a group — select a bin instead' : 'นี่เป็นกลุ่ม — กรุณาเลือกช่องเก็บแทน'),
                            backgroundColor: Colors.red),
                      );
                    } else if (item.isActive) {
                      widget.onCallback(item);
                      Navigator.of(context).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(isEnglish ? 'Cannot use: this location is inactive' : 'ไม่สามารถใช้ได้ เนื่องจากตำแหน่งนี้หยุดใช้งาน'),
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
                ? Center(child: Text(isEnglish ? 'No location data found' : 'ไม่พบข้อมูลผังตำแหน่งจัดเก็บ'))
                : ListView.builder(
                    itemCount: topLevel.length,
                    itemBuilder: (context, index) => _buildNode(topLevel[index], 0, isEnglish),
                  ),
      ),
    ]);
  }
}
