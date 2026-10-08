import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../models/im_price_change.dart';
import '../services/im_price_change_service.dart';

class ImPriceChangeListWidget extends StatefulWidget {
  final bool enableAddButton;
  final bool enableEditButton;
  final bool enableViewButton;
  final void Function() onAdd;
  final Function(ImPriceChangeHeader) onEdit;
  final Function(ImPriceChangeHeader) onView;
  final void Function(ImPriceChangeHeader) onCallback;

  const ImPriceChangeListWidget({
    super.key,
    required this.enableAddButton,
    required this.enableEditButton,
    required this.enableViewButton,
    required this.onAdd,
    required this.onEdit,
    required this.onView,
    required this.onCallback,
  });

  @override
  State<ImPriceChangeListWidget> createState() => ImPriceChangeListWidgetState();
}

Color _statusColor(String status) {
  switch (status) {
    case 'Pending':  return Colors.orange;
    case 'Approved': return Colors.green;
    case 'Void':      return Colors.grey;
    default:          return Colors.blueGrey;
  }
}

class ImPriceChangeListWidgetState extends State<ImPriceChangeListWidget> with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  List<ImPriceChangeHeader> _list = [];
  bool _isLoading = false;
  final _svc = ImPriceChangeService();

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
        : _list.where((h) =>
            (h.changeNo ?? '').toUpperCase().contains(q) ||
            (h.priceListCode ?? '').toUpperCase().contains(q) ||
            (h.priceListName ?? '').toUpperCase().contains(q)).toList();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          if (widget.enableAddButton)
            IconButton(icon: const Icon(Icons.add), tooltip: isEnglish ? 'New price change' : 'สร้างธุรกรรมเปลี่ยนแปลงราคา', onPressed: widget.onAdd),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: isEnglish ? 'Search (no. / price list)' : 'ค้นหา (เลขที่ / ตารางราคา)',
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
                ? Center(child: Text(isEnglish ? 'No price change transactions found' : 'ไม่พบธุรกรรมเปลี่ยนแปลงราคา'))
                : ListView.builder(
                    itemCount: display.length,
                    itemBuilder: (context, index) {
                      final item = display[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _statusColor(item.status).withOpacity(0.15),
                            child: Icon(
                              item.changeType == 'PROMOTION' ? Icons.local_offer_outlined : Icons.price_change_outlined,
                              color: _statusColor(item.status),
                              size: 20,
                            ),
                          ),
                          title: Text('${item.changeNo ?? ''}  ${item.priceListCode ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '${imPriceChangeTypeLabel(item.changeType, isEnglish)}'
                            '  •  ${isEnglish ? '${item.selectedCount}/${item.lineCount} selected' : 'เลือก ${item.selectedCount}/${item.lineCount} รายการ'}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(color: _statusColor(item.status).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                                child: Text(imPriceChangeStatusLabel(item.status, isEnglish), style: TextStyle(fontSize: 11, color: _statusColor(item.status), fontWeight: FontWeight.bold)),
                              ),
                              if (widget.enableViewButton)
                                IconButton(icon: const Icon(Icons.visibility, size: 18), tooltip: isEnglish ? 'View' : 'ดูข้อมูล', onPressed: () => widget.onView(item)),
                              if (widget.enableEditButton && item.status == 'Draft')
                                IconButton(icon: const Icon(Icons.edit, size: 18), tooltip: isEnglish ? 'Edit' : 'แก้ไข', onPressed: () => widget.onEdit(item)),
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
