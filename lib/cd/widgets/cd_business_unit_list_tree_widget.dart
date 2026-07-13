// widgets/cd_zipcode_list_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cd_business_unit.dart';
import '../services/cd_business_unit_service.dart';

class BusinessUnitListTreeWidget extends StatefulWidget {
  final bool enableAddRootButton;
  final bool enableAddChildButton;
  final bool enableEditButton;
  final bool enableViewButton;
  final bool enableDeleteButton;
  final bool enableCardSelect;
  final void Function() onAddRoot;
  final void Function(BusinessUnit) onAddChild;
  final Function(BusinessUnit) onEdit;
  final Function(BusinessUnit) onView;
  final Function(BusinessUnit) onDelete;
  final void Function(BusinessUnit) onCallback;

  const BusinessUnitListTreeWidget({
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
  State<BusinessUnitListTreeWidget> createState() =>
      BusinessUnitListTreeWidgetState();

  // เมธอด static สำหรับแสดง Dialog
  static Future<void> search(BuildContext context,
      {required void Function(BusinessUnit) onSelected}) {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          // กำหนดขนาดให้ใหญ่ขึ้นเพื่อให้ใช้งานสะดวก
          contentPadding: EdgeInsets.zero,
          title: const Text('ค้นหา หน่วยงาน',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Container(
            width: 500, // กำหนดความกว้างที่เหมาะสม
            height: 600, // กำหนดความสูงที่เหมาะสม
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: BusinessUnitListTreeWidget(
              enableAddRootButton: false,
              enableAddChildButton: false,
              enableEditButton: false,
              enableViewButton: false,
              enableDeleteButton: false,
              enableCardSelect: true,
              onAddRoot: () {},
              onAddChild: (bu) {},
              onEdit: (bu) {},
              onView: (bu) {},
              onDelete: (bu) {},
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

class BusinessUnitListTreeWidgetState extends State<BusinessUnitListTreeWidget>
    with AutomaticKeepAliveClientMixin {
  List<BusinessUnit> _lists = [];
  bool _isLoading = false;
  String _error = '';
  final Map<int, bool> _expandedState = {};

  Future<void> _fetchLists() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final dataService =
          Provider.of<BusinessUnitService>(context, listen: false);
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
              ? Expanded(
                  child: ElevatedButton.icon(
                      onPressed: () => widget.onAddRoot(),
                      icon: const Icon(Icons.add),
                      label: const Text('เพิ่มหน่วยหลัก')))
              : const SizedBox.shrink(),
        ],
      ),
    );
  }

  List<BusinessUnit> _buildTree(List<BusinessUnit> lists, int? parentId) {
    return lists.where((list) => list.parentId == parentId).toList()
      ..sort((a, b) => a.buCode.compareTo(b.buCode));
  }

  // --- Build Methods ---
  Widget _buildNode(BusinessUnit item, int level) {
    final bool isHeader = item.isControlBU == false;
    final List<BusinessUnit> children = _buildTree(_lists, item.id);
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
                    '${item.buCode} ${item.buNameThai}',
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Icon ปุ่ม Add สำหรับ Header
                if (isHeader && widget.enableAddChildButton)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    tooltip: 'เพิ่มหน่วยย่อย',
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
                              item.isControlBU == false) {
                            // ป้องกันการลบหัวบัญชี
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'ไม่สามารถลบรายการที่มีหน่วยย่อยได้ กรุณาลบหน่วยย่อยออกก่อน'),
                                backgroundColor: Colors.red,
                              ),
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
                          if (item.isActive && item.isControlBU) {
                            widget.onCallback(item);
                            Navigator.of(context).pop();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'ไม่สามารถใช้ได้ เนื่องจากเป็นหน่วยหลัก หรือ หยุดใช้'),
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

    final List<BusinessUnit> topLevelLists = _buildTree(_lists, null);

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
          // ListView.builder(
          //     itemCount: _searchResult.length,
          //     itemBuilder: (context, index) {
          //       final item = _searchResult[index];
          //       return Card(
          //         margin: const EdgeInsets.symmetric(
          //             horizontal: 8.0, vertical: 4.0),
          //         child: ListTile(
          //           // leading: Text('${(index + 1).toString()}.'),
          //           // // CircleAvatar(
          //           // //   child: Text((index + 1).toString()),
          //           // // ),
          //           // // title: Text(item.item),
          //           title: Text(
          //               '${item.subDistrict} ${item.district} ${item.province} ${item.zipcode}'),
          //           // subtitle: Text(
          //           //     '${item.subDistrict} ${item.district} ${item.province}'),
          //           // isThreeLine: true,
          //           trailing: Row(
          //             mainAxisSize: MainAxisSize.min,
          //             children: [
          //               widget.enableViewButton
          //                   ? IconButton(
          //                       icon: const Icon(Icons.visibility,
          //                           color: Colors.green),
          //                       onPressed: () => widget.onView(item),
          //                     )
          //                   : const SizedBox.shrink(),
          //               widget.enableEditButton
          //                   ? IconButton(
          //                       icon: const Icon(Icons.edit,
          //                           color: Colors.blue),
          //                       onPressed: () => widget.onEdit(item),
          //                     )
          //                   : const SizedBox.shrink(),
          //               widget.enableDeleteButton
          //                   ? IconButton(
          //                       icon: const Icon(Icons.delete,
          //                           color: Colors.red),
          //                       onPressed: () => widget.onDelete(item),
          //                     )
          //                   : const SizedBox.shrink(),
          //               widget.enableCardSelect
          //                   ? IconButton(
          //                       icon: const Icon(Icons.arrow_right_outlined,
          //                           color: Colors.black),
          //                       onPressed: () {
          //                         widget.onCallback(item);
          //                         Navigator.of(context).pop();
          //                       },
          //                     )
          //                   : const SizedBox.shrink(),
          //             ],
          //           ),
          //         ),
          //       );
          //     },
          //   ),
        ),
      ],
    );
  }
}
