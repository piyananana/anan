import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../models/im_price_list.dart';
import '../services/im_price_list_service.dart';

class ImPriceListListWidget extends StatefulWidget {
  final bool enableAddButton;
  final bool enableEditButton;
  final bool enableViewButton;
  final bool enableDeleteButton;
  final void Function() onAdd;
  final Function(ImPriceListHeader) onEdit;
  final Function(ImPriceListHeader) onView;
  final Function(ImPriceListHeader) onDelete;
  final void Function(ImPriceListHeader) onCallback;

  const ImPriceListListWidget({
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
  State<ImPriceListListWidget> createState() => ImPriceListListWidgetState();
}

class ImPriceListListWidgetState extends State<ImPriceListListWidget> with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  List<ImPriceListHeader> _list = [];
  bool _isLoading = false;
  final _svc = ImPriceListService();

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
      final rows = await _svc.fetchRows();
      if (mounted) setState(() { _list = rows; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void refresh() => _fetchList();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final q = _searchQuery.trim().toUpperCase();
    final display = q.isEmpty
        ? _list
        : _list.where((h) => h.priceListCode.toUpperCase().contains(q) || h.priceListName.toUpperCase().contains(q)).toList();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          if (widget.enableAddButton)
            IconButton(icon: const Icon(Icons.add), tooltip: isEnglish ? 'Add new price list' : 'เพิ่มตารางราคาใหม่', onPressed: widget.onAdd),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: isEnglish ? 'Search (code / name)' : 'ค้นหา (รหัส / ชื่อ)',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ]),
      ),
      Expanded(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : display.isEmpty
                ? Center(child: Text(isEnglish ? 'No price list data found' : 'ไม่พบข้อมูลตารางราคา'))
                : ListView.builder(
                    itemCount: display.length,
                    itemBuilder: (context, index) {
                      final item = display[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: item.isActive ? Colors.teal.shade100 : Colors.grey.shade200,
                            child: Icon(
                              item.listType == 'PURCHASE' ? Icons.shopping_cart_outlined : Icons.sell_outlined,
                              color: item.isActive ? Colors.teal.shade700 : Colors.grey,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            '${item.priceListCode}  ${item.priceListName}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: item.isActive ? null : Colors.grey),
                          ),
                          subtitle: Text(
                            '${imPriceListTypeLabel(item.listType, isEnglish)}'
                            '${item.currencyCode != null ? '  •  ${item.currencyCode}' : ''}'
                            '  •  ${isEnglish ? '${item.lineCount} items' : '${item.lineCount} รายการ'}',
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
                      );
                    },
                  ),
      ),
    ]);
  }
}
