// lib/cm/widgets/cm_bank_account_list_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../models/cm_bank_account.dart'; // includes cmAccountTypeOptions
import '../services/cm_bank_account_service.dart';

class CmBankAccountListWidget extends StatefulWidget {
  final bool enableAddButton;
  final bool enableEditButton;
  final bool enableViewButton;
  final bool enableDeleteButton;
  final bool enableCardSelect;
  final void Function() onAdd;
  final Function(CmBankAccount) onEdit;
  final Function(CmBankAccount) onView;
  final Function(CmBankAccount) onDelete;
  final void Function(CmBankAccount) onCallback;

  const CmBankAccountListWidget({
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
  State<CmBankAccountListWidget> createState() => CmBankAccountListWidgetState();

  static Future<void> search(BuildContext context,
      {required void Function(CmBankAccount) onSelected}) {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: Text(isEnglish ? 'Search Bank Account' : 'ค้นหา บัญชีธนาคาร',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Container(
          width: 560,
          height: 580,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: CmBankAccountListWidget(
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

class CmBankAccountListWidgetState extends State<CmBankAccountListWidget>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'code_asc';
  List<CmBankAccount> _list = [];
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
      final service = Provider.of<CmBankAccountService>(context, listen: false);
      final data = await service.fetchRows();
      setState(() {
        _list = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        final isEnglish = context.read<LanguageProvider>().isEnglish;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${isEnglish ? 'Failed to load data' : 'ไม่สามารถโหลดข้อมูลได้'}: $e')));
      }
    }
  }

  void refresh() => _fetchList();

  void _onSortSelected(String v) => setState(() => _sortBy = v);

  List<CmBankAccount> get _filtered {
    List<CmBankAccount> items = List.from(_list);
    if (widget.enableCardSelect) items = items.where((e) => e.isActive).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toUpperCase();
      items = items.where((r) {
        return r.accountCode.toUpperCase().contains(q) ||
            r.accountNameTh.toUpperCase().contains(q) ||
            (r.accountNameEn ?? '').toUpperCase().contains(q) ||
            (r.accountNumber ?? '').toUpperCase().contains(q) ||
            (r.bankNameTh ?? '').toUpperCase().contains(q);
      }).toList();
    }
    switch (_sortBy) {
      case 'code_asc': items.sort((a, b) => a.accountCode.compareTo(b.accountCode)); break;
      case 'code_desc': items.sort((a, b) => b.accountCode.compareTo(a.accountCode)); break;
      case 'name_asc': items.sort((a, b) => a.accountNameTh.compareTo(b.accountNameTh)); break;
      case 'name_desc': items.sort((a, b) => b.accountNameTh.compareTo(a.accountNameTh)); break;
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final display = _filtered;
    final countText = isEnglish
        ? (_searchQuery.isEmpty
            ? 'All ${_list.length} rows'
            : 'Found ${display.length} of ${_list.length} rows')
        : (_searchQuery.isEmpty
            ? 'ทั้งหมด ${_list.length} แถว'
            : 'พบ ${display.length} จาก ${_list.length} แถว');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              if (widget.enableAddButton)
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: isEnglish ? 'Add New' : 'เพิ่มข้อมูลใหม่',
                  onPressed: widget.onAdd,
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort),
                tooltip: isEnglish ? 'Sort' : 'จัดเรียง',
                onSelected: _onSortSelected,
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'code_asc', child: Text(isEnglish ? 'Code (A-Z)' : 'รหัส (น้อยไปมาก)')),
                  PopupMenuItem(value: 'code_desc', child: Text(isEnglish ? 'Code (Z-A)' : 'รหัส (มากไปน้อย)')),
                  PopupMenuItem(value: 'name_asc', child: Text(isEnglish ? 'Name (A-Z)' : 'ชื่อ (น้อยไปมาก)')),
                  PopupMenuItem(value: 'name_desc', child: Text(isEnglish ? 'Name (Z-A)' : 'ชื่อ (มากไปน้อย)')),
                ],
              ),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: isEnglish ? 'Search (code / name / account no. / bank)' : 'ค้นหา (รหัส / ชื่อ / เลขบัญชี / ธนาคาร)',
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
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Stack(children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.indigo.shade100,
                              child: const Icon(Icons.savings, size: 18),
                            ),
                            title: Text(
                              item.accountCode,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: item.isActive ? null : Colors.grey,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEnglish && (item.accountNameEn ?? '').isNotEmpty
                                      ? item.accountNameEn! : item.accountNameTh,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: item.isActive ? Colors.black87 : Colors.grey,
                                  ),
                                ),
                                Text(
                                  [
                                    cmCmTypeLabel(item.cmType, isEnglish),
                                    if (item.bankDisplay.isNotEmpty) item.bankDisplay,
                                    if ((item.accountNumber ?? '').isNotEmpty) item.accountNumber!,
                                    if (!item.isPettyCash) cmAccountTypeLabel(item.accountType, isEnglish),
                                    if (item.isFcy) item.currencyCode,
                                    if (item.isCheckAccount) (isEnglish ? 'Check' : 'เช็ค'),
                                  ].join(' · '),
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
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
