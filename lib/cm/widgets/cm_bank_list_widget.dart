// lib/cm/widgets/cm_bank_list_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cm_bank.dart';
import '../services/cm_bank_service.dart';

class CmBankListWidget extends StatefulWidget {
  final bool enableAddButton;
  final bool enableEditButton;
  final bool enableViewButton;
  final bool enableDeleteButton;
  final bool enableCardSelect;
  final void Function() onAdd;
  final Function(CmBank) onEdit;
  final Function(CmBank) onView;
  final Function(CmBank) onDelete;
  final void Function(CmBank) onCallback;

  const CmBankListWidget({
    super.key,
    required this.enableAddButton,
    required this.enableEditButton,
    required this.enableViewButton,
    required this.enableDeleteButton,
    required this.enableCardSelect,
    required this.onAdd,
    required this.onEdit,
    required this.onView,
    required this.onDelete,
    required this.onCallback,
  });

  @override
  State<CmBankListWidget> createState() => CmBankListWidgetState();

  static Future<void> search(BuildContext context,
      {required void Function(CmBank) onSelected}) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: const Text('ค้นหา ธนาคาร (CM)',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Container(
          width: 520,
          height: 580,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: CmBankListWidget(
            enableAddButton: false,
            enableEditButton: false,
            enableViewButton: false,
            enableDeleteButton: false,
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

class CmBankListWidgetState extends State<CmBankListWidget>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'code_asc';
  List<CmBank> _list = [];
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchList() async {
    setState(() => _isLoading = true);
    try {
      final service = Provider.of<CmBankService>(context, listen: false);
      final data = await service.fetchRows();
      setState(() {
        _list = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ไม่สามารถโหลดข้อมูลได้: $e')));
      }
    }
  }

  void refresh() => _fetchList();

  void _onSortSelected(String v) => setState(() => _sortBy = v);

  List<CmBank> get _filtered {
    List<CmBank> items = List.from(_list);
    if (widget.enableCardSelect) items = items.where((e) => e.isActive).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toUpperCase();
      items = items.where((r) {
        return r.bankCode.toUpperCase().contains(q) ||
            r.bankNameTh.toUpperCase().contains(q) ||
            (r.bankNameEn ?? '').toUpperCase().contains(q) ||
            (r.shortName ?? '').toUpperCase().contains(q) ||
            (r.swiftCode ?? '').toUpperCase().contains(q);
      }).toList();
    }
    switch (_sortBy) {
      case 'code_asc': items.sort((a, b) => a.bankCode.compareTo(b.bankCode)); break;
      case 'code_desc': items.sort((a, b) => b.bankCode.compareTo(a.bankCode)); break;
      case 'name_asc': items.sort((a, b) => a.bankNameTh.compareTo(b.bankNameTh)); break;
      case 'name_desc': items.sort((a, b) => b.bankNameTh.compareTo(a.bankNameTh)); break;
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final display = _filtered;
    final countText = _searchQuery.isEmpty
        ? 'ทั้งหมด ${_list.length} แถว'
        : 'พบ ${display.length} จาก ${_list.length} แถว';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              if (widget.enableAddButton)
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'เพิ่มข้อมูลใหม่',
                  onPressed: widget.onAdd,
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort),
                tooltip: 'จัดเรียง',
                onSelected: _onSortSelected,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'code_asc', child: Text('รหัส (น้อยไปมาก)')),
                  PopupMenuItem(value: 'code_desc', child: Text('รหัส (มากไปน้อย)')),
                  PopupMenuItem(value: 'name_asc', child: Text('ชื่อ (น้อยไปมาก)')),
                  PopupMenuItem(value: 'name_desc', child: Text('ชื่อ (มากไปน้อย)')),
                ],
              ),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'ค้นหา (รหัส / ชื่อ / SWIFT)',
                    prefixIcon: Icon(Icons.search),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
            ],
          ),
        ),
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
              : display.isEmpty
                  ? const Center(child: Text('ไม่พบข้อมูล'))
                  : ListView.builder(
                      itemCount: display.length,
                      itemBuilder: (ctx, i) {
                        final item = display[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Stack(children: [
                          ListTile(
                            leading: item.shortName != null
                                ? CircleAvatar(
                                    backgroundColor: Colors.teal.shade100,
                                    child: Text(
                                      item.shortName!,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  )
                                : const CircleAvatar(
                                    child: Icon(Icons.account_balance, size: 18),
                                  ),
                            title: Text(
                              '${item.bankCode} — ${item.bankNameTh}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: item.isActive ? null : Colors.grey,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((item.bankNameEn ?? '').isNotEmpty)
                                  Text(item.bankNameEn!,
                                      style: const TextStyle(fontSize: 12)),
                                if ((item.swiftCode ?? '').isNotEmpty)
                                  Text('SWIFT: ${item.swiftCode}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!item.isActive)
                                  const Chip(
                                    label: Text('หยุดใช้',
                                        style: TextStyle(fontSize: 11)),
                                    backgroundColor: Color(0xFFEEEEEE),
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
                                    icon: const Icon(Icons.arrow_right_outlined),
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
