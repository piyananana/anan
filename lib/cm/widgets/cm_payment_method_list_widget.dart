// lib/cm/widgets/cm_payment_method_list_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cm_payment_method.dart';
import '../services/cm_payment_method_service.dart';
import '../../sa/services/sa_language_provider.dart';

class CmPaymentMethodListWidget extends StatefulWidget {
  final bool enableAddButton;
  final bool enableEditButton;
  final bool enableViewButton;
  final bool enableDeleteButton;
  final bool enableCardSelect;
  final void Function() onAdd;
  final Function(CmPaymentMethod) onEdit;
  final Function(CmPaymentMethod) onView;
  final Function(CmPaymentMethod) onDelete;
  final void Function(CmPaymentMethod) onCallback;

  const CmPaymentMethodListWidget({
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
  State<CmPaymentMethodListWidget> createState() =>
      CmPaymentMethodListWidgetState();

  static Future<void> search(BuildContext context,
      {String? filterType,
      required void Function(CmPaymentMethod) onSelected}) {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: Text(isEnglish ? 'Search Payment Method' : 'ค้นหา ประเภทการชำระเงิน',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Container(
          width: 540,
          height: 580,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: CmPaymentMethodListWidget(
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
            child: Text(isEnglish ? 'Close' : 'ปิด', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class CmPaymentMethodListWidgetState extends State<CmPaymentMethodListWidget>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'code_asc';
  List<CmPaymentMethod> _list = [];
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
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    setState(() => _isLoading = true);
    try {
      final service = Provider.of<CmPaymentMethodService>(context, listen: false);
      final data = await service.fetchRows();
      setState(() {
        _list = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(isEnglish ? 'Failed to load data: $e' : 'ไม่สามารถโหลดข้อมูลได้: $e')));
      }
    }
  }

  void refresh() => _fetchList();

  void _onSortSelected(String v) => setState(() => _sortBy = v);

  List<CmPaymentMethod> get _filtered {
    List<CmPaymentMethod> items = List.from(_list);
    if (widget.enableCardSelect) items = items.where((e) => e.isActive).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toUpperCase();
      items = items.where((r) {
        return r.methodCode.toUpperCase().contains(q) ||
            r.methodNameTh.toUpperCase().contains(q) ||
            (r.methodNameEn ?? '').toUpperCase().contains(q) ||
            r.methodType.toUpperCase().contains(q);
      }).toList();
    }
    switch (_sortBy) {
      case 'code_asc': items.sort((a, b) => a.methodCode.compareTo(b.methodCode)); break;
      case 'code_desc': items.sort((a, b) => b.methodCode.compareTo(a.methodCode)); break;
      case 'name_asc': items.sort((a, b) => a.methodNameTh.compareTo(b.methodNameTh)); break;
      case 'name_desc': items.sort((a, b) => b.methodNameTh.compareTo(a.methodNameTh)); break;
    }
    return items;
  }

  IconData _typeIcon(String t) {
    switch (t) {
      case 'CHECK':
        return Icons.receipt_long;
      case 'TRANSFER':
        return Icons.account_balance;
      case 'BILL_OF_EXCHANGE':
        return Icons.description;
      default:
        return Icons.payments;
    }
  }

  Color _typeColor(String t) {
    switch (t) {
      case 'CHECK':
        return Colors.orange.shade700;
      case 'TRANSFER':
        return Colors.indigo;
      case 'BILL_OF_EXCHANGE':
        return Colors.purple;
      default:
        return Colors.green.shade700;
    }
  }

  String _methodName(CmPaymentMethod item, bool isEnglish) =>
      isEnglish && (item.methodNameEn ?? '').isNotEmpty ? item.methodNameEn! : item.methodNameTh;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final display = _filtered;
    final countText = _searchQuery.isEmpty
        ? (isEnglish ? 'Total ${_list.length} rows' : 'ทั้งหมด ${_list.length} แถว')
        : (isEnglish ? 'Found ${display.length} of ${_list.length} rows' : 'พบ ${display.length} จาก ${_list.length} แถว');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              if (widget.enableAddButton)
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: isEnglish ? 'Add new' : 'เพิ่มข้อมูลใหม่',
                  onPressed: widget.onAdd,
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort),
                tooltip: isEnglish ? 'Sort' : 'จัดเรียง',
                onSelected: _onSortSelected,
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'code_asc', child: Text(isEnglish ? 'Code (ascending)' : 'รหัส (น้อยไปมาก)')),
                  PopupMenuItem(value: 'code_desc', child: Text(isEnglish ? 'Code (descending)' : 'รหัส (มากไปน้อย)')),
                  PopupMenuItem(value: 'name_asc', child: Text(isEnglish ? 'Name (ascending)' : 'ชื่อ (น้อยไปมาก)')),
                  PopupMenuItem(value: 'name_desc', child: Text(isEnglish ? 'Name (descending)' : 'ชื่อ (มากไปน้อย)')),
                ],
              ),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: isEnglish ? 'Search (code / name / type)' : 'ค้นหา (รหัส / ชื่อ / ประเภท)',
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: const OutlineInputBorder(),
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
                  ? Center(child: Text(isEnglish ? 'No data found' : 'ไม่พบข้อมูล'))
                  : ListView.builder(
                      itemCount: display.length,
                      itemBuilder: (ctx, i) {
                        final item = display[i];
                        final typeLabel = cmMethodTypeOptions[item.methodType] ??
                            item.methodType;
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Stack(children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  _typeColor(item.methodType).withOpacity(0.15),
                              child: Icon(_typeIcon(item.methodType),
                                  color: _typeColor(item.methodType), size: 20),
                            ),
                            title: Text(
                              '${item.methodCode} — ${_methodName(item, isEnglish)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: item.isActive ? null : Colors.grey,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(typeLabel,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: _typeColor(item.methodType))),
                                if ((item.bankAccountCode ?? '').isNotEmpty)
                                  Text(
                                    '${item.bankShortName ?? item.bankNameTh ?? ''} — ${item.bankAccountCode}',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!item.isActive)
                                  Chip(
                                    label: Text(isEnglish ? 'Inactive' : 'หยุดใช้',
                                        style: const TextStyle(fontSize: 11)),
                                    backgroundColor: const Color(0xFFEEEEEE),
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
