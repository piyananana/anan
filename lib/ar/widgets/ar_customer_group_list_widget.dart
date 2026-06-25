// widgets/ar_customer_group_list_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ar_customer_group.dart';
import '../services/ar_customer_group_service.dart';

class ArCustomerGroupListWidget extends StatefulWidget {
  final bool enableAddButton;
  final bool enableEditButton;
  final bool enableViewButton;
  final bool enableDeleteButton;
  final bool enableSortButton;
  final bool enableCardSelect;
  final void Function() onAdd;
  final Function(ArCustomerGroup) onEdit;
  final Function(ArCustomerGroup) onView;
  final Function(ArCustomerGroup) onDelete;
  final void Function(ArCustomerGroup) onCallback;

  const ArCustomerGroupListWidget({
    super.key,
    required this.enableAddButton,
    required this.enableEditButton,
    required this.enableViewButton,
    required this.enableDeleteButton,
    required this.enableSortButton,
    required this.enableCardSelect,
    required this.onAdd,
    required this.onEdit,
    required this.onView,
    required this.onDelete,
    required this.onCallback,
  });

  @override
  State<ArCustomerGroupListWidget> createState() =>
      ArCustomerGroupListWidgetState();

  static Future<void> search(BuildContext context,
      {required void Function(ArCustomerGroup) onSelected}) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: const Text('ค้นหา กลุ่มลูกค้า',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Container(
          width: 520,
          height: 600,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: ArCustomerGroupListWidget(
            enableAddButton: false,
            enableEditButton: false,
            enableViewButton: false,
            enableDeleteButton: false,
            enableSortButton: false,
            enableCardSelect: true,
            onAdd: () {},
            onEdit: (_) {},
            onView: (_) {},
            onDelete: (_) {},
            onCallback: onSelected,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ปิด', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class ArCustomerGroupListWidgetState extends State<ArCustomerGroupListWidget>
    with AutomaticKeepAliveClientMixin {
  String _sortBy = 'code_asc';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<ArCustomerGroup> _lists = [];
  bool _isLoading = false;
  String _error = '';

  List<ArCustomerGroup> _filterAndSort() {
    List<ArCustomerGroup> display = List.from(_lists);
    if (widget.enableCardSelect) display = display.where((e) => e.isActive).toList();
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toUpperCase();
      display = display.where((row) {
        return row.groupCode.toUpperCase().contains(query) ||
            row.groupNameThai.toUpperCase().contains(query) ||
            row.groupNameEng.toUpperCase().contains(query);
      }).toList();
    }
    display.sort((a, b) {
      switch (_sortBy) {
        case 'code_asc':
          return a.groupCode.compareTo(b.groupCode);
        case 'code_desc':
          return b.groupCode.compareTo(a.groupCode);
        case 'name_asc':
          return a.groupNameThai.compareTo(b.groupNameThai);
        case 'name_desc':
          return b.groupNameThai.compareTo(a.groupNameThai);
        default:
          return 0;
      }
    });
    return display;
  }

  Future<void> _fetchLists() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final service =
          Provider.of<ArCustomerGroupService>(context, listen: false);
      final fetched = await service.fetchRows();
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_error)));
      }
    }
  }

  void refresh() => _fetchLists();

  @override
  void initState() {
    super.initState();
    _fetchLists();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          if (widget.enableAddButton)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'เพิ่มข้อมูลใหม่',
              onPressed: widget.onAdd,
            ),
          if (widget.enableSortButton)
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              tooltip: 'จัดเรียง',
              onSelected: (value) => setState(() => _sortBy = value),
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'code_asc', child: Text('รหัส (น้อยไปมาก)')),
                PopupMenuItem(
                    value: 'code_desc', child: Text('รหัส (มากไปน้อย)')),
                PopupMenuItem(value: 'name_asc', child: Text('ชื่อ (ก-ฮ)')),
                PopupMenuItem(value: 'name_desc', child: Text('ชื่อ (ฮ-ก)')),
              ],
            ),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'ค้นหา (รหัส / ชื่อกลุ่มลูกค้า)',
                prefixIcon: Icon(Icons.search),
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final displayList = _filterAndSort();
    final countText = _searchQuery.isEmpty
        ? 'ทั้งหมด ${_lists.length} แถว'
        : 'พบ ${displayList.length} จาก ${_lists.length} แถว';

    return Column(
      children: [
        _buildListHeader(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(countText,
                style: const TextStyle(fontSize: 12, color: Colors.black87)),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : displayList.isEmpty
                  ? const Center(child: Text('ไม่พบข้อมูลกลุ่มลูกค้า'))
                  : ListView.builder(
                      itemCount: displayList.length,
                      itemBuilder: (context, index) {
                        final item = displayList[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8.0, vertical: 4.0),
                          child: Stack(children: [
                          ListTile(
                            title: Text(
                              '${item.groupCode} — ${item.groupNameThai}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: item.isActive ? null : Colors.grey,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (item.groupNameEng.isNotEmpty)
                                  Text(item.groupNameEng,
                                      style: const TextStyle(fontSize: 12)),
                                Text(
                                  'เครดิต ${item.creditTermMonths > 0 ? '${item.creditTermMonths} เดือน ' : ''}${item.creditTermDays} วัน  |  วงเงิน ${item.creditLimit.toStringAsFixed(2)}  |  ส่วนลด ${item.discountPercent.toStringAsFixed(2)}%',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                            isThreeLine: item.groupNameEng.isNotEmpty,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!item.isActive)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Chip(
                                      label: const Text('หยุดใช้',
                                          style: TextStyle(fontSize: 11)),
                                      backgroundColor: Colors.grey.shade200,
                                    ),
                                  ),
                                if (widget.enableViewButton)
                                  IconButton(
                                    icon: const Icon(Icons.visibility,
                                        color: Colors.green),
                                    onPressed: () => widget.onView(item),
                                  ),
                                if (widget.enableEditButton)
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue),
                                    onPressed: () => widget.onEdit(item),
                                  ),
                                if (widget.enableDeleteButton)
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => widget.onDelete(item),
                                  ),
                                if (widget.enableCardSelect)
                                  IconButton(
                                    icon: const Icon(
                                        Icons.arrow_right_outlined,
                                        color: Colors.black),
                                    onPressed: () {
                                      widget.onCallback(item);
                                      Navigator.of(context).pop();
                                    },
                                  ),
                              ],
                            ),
                          ),
                          if (!item.isActive)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Center(
                                  child: Icon(Icons.block, size: 72,
                                      color: Colors.red.withOpacity(0.12)),
                                ),
                              ),
                            ),
                          ]),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
