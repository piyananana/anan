import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../models/im_item.dart';
import '../services/im_item_service.dart';

class ImItemListWidget extends StatefulWidget {
  final bool enableAddButton;
  final bool enableEditButton;
  final bool enableViewButton;
  final bool enableDeleteButton;
  final void Function() onAdd;
  final Function(ImItem) onEdit;
  final Function(ImItem) onView;
  final Function(ImItem) onDelete;
  final void Function(ImItem) onCallback;

  const ImItemListWidget({
    super.key,
    required this.enableAddButton,
    required this.enableEditButton,
    required this.enableViewButton,
    required this.enableDeleteButton,
    required this.onAdd,
    required this.onEdit,
    required this.onView,
    required this.onDelete,
    required this.onCallback,
  });

  @override
  State<ImItemListWidget> createState() => ImItemListWidgetState();
}

class ImItemListWidgetState extends State<ImItemListWidget> with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'code_asc';
  List<ImItem> _list = [];
  int _totalCount = 0;
  bool _isLoading = false;
  final _svc = ImItemService();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchList() async {
    setState(() => _isLoading = true);
    try {
      final rows = await _svc.fetchRows(keyword: _searchQuery.isEmpty ? null : _searchQuery);
      if (mounted) {
        setState(() {
          _list = rows;
          if (_searchQuery.isEmpty) _totalCount = rows.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void refresh() => _fetchList();

  String _itemName(ImItem item, bool isEnglish) =>
      isEnglish && (item.itemNameEn ?? '').isNotEmpty ? item.itemNameEn! : item.itemNameTh;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final display = List<ImItem>.from(_list);
    switch (_sortBy) {
      case 'code_asc':  display.sort((a, b) => a.itemCode.compareTo(b.itemCode)); break;
      case 'code_desc': display.sort((a, b) => b.itemCode.compareTo(a.itemCode)); break;
      case 'name_asc':  display.sort((a, b) => a.itemNameTh.compareTo(b.itemNameTh)); break;
      case 'name_desc': display.sort((a, b) => b.itemNameTh.compareTo(a.itemNameTh)); break;
    }

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          if (widget.enableAddButton)
            IconButton(icon: const Icon(Icons.add), tooltip: isEnglish ? 'Add new item' : 'เพิ่มสินค้าใหม่', onPressed: widget.onAdd),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: isEnglish ? 'Sort' : 'จัดเรียง',
            onSelected: (v) => setState(() => _sortBy = v),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'code_asc',  child: Text(isEnglish ? 'Code (ascending)' : 'รหัส (น้อยไปมาก)')),
              PopupMenuItem(value: 'code_desc', child: Text(isEnglish ? 'Code (descending)' : 'รหัส (มากไปน้อย)')),
              PopupMenuItem(value: 'name_asc',  child: Text(isEnglish ? 'Name (ascending)' : 'ชื่อ (น้อยไปมาก)')),
              PopupMenuItem(value: 'name_desc', child: Text(isEnglish ? 'Name (descending)' : 'ชื่อ (มากไปน้อย)')),
            ],
          ),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: isEnglish ? 'Search (code / name / barcode)' : 'ค้นหา (รหัส / ชื่อ / บาร์โค้ด)',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) { setState(() => _searchQuery = v); _fetchList(); },
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _searchQuery.isEmpty
                ? (isEnglish ? 'Total $_totalCount rows' : 'ทั้งหมด $_totalCount แถว')
                : (isEnglish ? 'Found ${_list.length} of $_totalCount rows' : 'พบ ${_list.length} จาก $_totalCount แถว'),
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
      ),
      Expanded(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : display.isEmpty
                ? Center(child: Text(isEnglish ? 'No item data found' : 'ไม่พบข้อมูลสินค้า'))
                : ListView.builder(
                    itemCount: display.length,
                    itemBuilder: (context, index) {
                      final item = display[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Stack(children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: item.isActive ? Colors.teal.shade100 : Colors.grey.shade200,
                              child: Icon(
                                item.itemType == 'SERVICE' ? Icons.design_services : Icons.inventory_2,
                                color: item.isActive ? Colors.teal.shade700 : Colors.grey,
                              ),
                            ),
                            title: Text(
                              '${item.itemCode}  ${_itemName(item, isEnglish)}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: item.isActive ? null : Colors.grey),
                            ),
                            subtitle: Text(
                              '${imItemTypeLabel(item.itemType, isEnglish)}'
                              '${item.categoryCode != null ? '  •  ${item.categoryCode}' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.enableViewButton)
                                  IconButton(icon: const Icon(Icons.visibility, size: 18), tooltip: isEnglish ? 'View' : 'ดูข้อมูล', onPressed: () => widget.onView(item)),
                                if (widget.enableEditButton)
                                  IconButton(icon: const Icon(Icons.edit, size: 18), tooltip: isEnglish ? 'Edit' : 'แก้ไข', onPressed: () => widget.onEdit(item)),
                                if (widget.enableDeleteButton)
                                  IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), tooltip: isEnglish ? 'Delete' : 'ลบ', onPressed: () => widget.onDelete(item)),
                              ],
                            ),
                            onTap: () => widget.onCallback(item),
                          ),
                          if (!item.isActive)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Center(child: Icon(Icons.block, size: 72, color: Colors.red.withOpacity(0.12))),
                              ),
                            ),
                        ]),
                      );
                    },
                  ),
      ),
    ]);
  }
}
