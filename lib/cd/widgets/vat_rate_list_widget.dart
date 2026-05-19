import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/vat_rate.dart';
import '../services/vat_rate_service.dart';

class VatRateListWidget extends StatefulWidget {
  final bool enableAddButton;
  final bool enableEditButton;
  final bool enableViewButton;
  final bool enableDeleteButton;
  final bool enableCardSelect;
  final void Function() onAdd;
  final Function(VatRate) onEdit;
  final Function(VatRate) onView;
  final Function(VatRate) onDelete;
  final void Function(VatRate) onCallback;

  const VatRateListWidget({
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
  State<VatRateListWidget> createState() => VatRateListWidgetState();

  static Future<void> search(BuildContext context,
      {required void Function(VatRate) onSelected}) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: const Text('ค้นหา อัตราภาษีมูลค่าเพิ่ม',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Container(
          width: 500,
          height: 600,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: VatRateListWidget(
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

class VatRateListWidgetState extends State<VatRateListWidget>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'code_asc';
  List<VatRate> _lists = [];
  bool _isLoading = false;
  String _error = '';

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  bool get wantKeepAlive => true;

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

  Future<void> _fetchLists() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final svc = Provider.of<VatRateService>(context, listen: false);
      final fetched = await svc.fetchRows();
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

  void _onSortSelected(String v) => setState(() => _sortBy = v);

  List<VatRate> _filtered() {
    List<VatRate> items = List.from(_lists);
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toUpperCase();
      items = items.where((r) {
        return r.vatCode.toUpperCase().contains(q) ||
            r.vatNameTh.toUpperCase().contains(q) ||
            (r.vatNameEn?.toUpperCase().contains(q) ?? false);
      }).toList();
    }
    switch (_sortBy) {
      case 'code_asc': items.sort((a, b) => a.vatCode.compareTo(b.vatCode)); break;
      case 'code_desc': items.sort((a, b) => b.vatCode.compareTo(a.vatCode)); break;
      case 'name_asc': items.sort((a, b) => a.vatNameTh.compareTo(b.vatNameTh)); break;
      case 'name_desc': items.sort((a, b) => b.vatNameTh.compareTo(a.vatNameTh)); break;
    }
    return items;
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          if (widget.enableAddButton)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'เพิ่มอัตราภาษีใหม่',
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
                hintText: 'ค้นหา (รหัส / ชื่อภาษี)',
                prefixIcon: Icon(Icons.search),
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final items = _filtered();
    final countText = _searchQuery.isEmpty
        ? 'ทั้งหมด ${_lists.length} แถว'
        : 'พบ ${items.length} จาก ${_lists.length} แถว';
    return Column(
      children: [
        _buildHeader(),
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
              : items.isEmpty
                  ? const Center(child: Text('ไม่พบข้อมูลอัตราภาษีมูลค่าเพิ่ม'))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final endLabel = item.endDate != null
                            ? _dateFmt.format(item.endDate!)
                            : 'ปัจจุบัน';
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8.0, vertical: 4.0),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: item.isActive
                                  ? Colors.green.shade100
                                  : Colors.grey.shade200,
                              child: Text(
                                '${item.rate.toStringAsFixed(item.rate % 1 == 0 ? 0 : 2)}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: item.isActive
                                      ? Colors.green.shade800
                                      : Colors.grey,
                                ),
                              ),
                            ),
                            title: Text(
                              '${item.vatCode}  ${item.vatNameTh}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: item.isActive ? null : Colors.grey,
                              ),
                            ),
                            subtitle: Text(
                              [
                                'ใช้งาน: ${_dateFmt.format(item.effectiveDate)} – $endLabel',
                                if (item.glAccountCode != null)
                                  'บัญชี: ${item.glAccountCode}  ${item.glAccountName ?? ''}',
                                if (item.remark != null && item.remark!.isNotEmpty)
                                  item.remark!,
                              ].join('\n'),
                            ),
                            isThreeLine: item.glAccountCode != null ||
                                (item.remark != null && item.remark!.isNotEmpty),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
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
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
