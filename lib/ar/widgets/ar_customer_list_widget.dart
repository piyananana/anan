import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ar_customer.dart';
import '../services/ar_customer_service.dart';
import '../../sa/services/sa_language_provider.dart';

class ArCustomerListWidget extends StatefulWidget {
  final bool enableAddButton;
  final bool enableEditButton;
  final bool enableViewButton;
  final bool enableDeleteButton;
  final bool enableCardSelect;
  final void Function() onAdd;
  final Function(ArCustomer) onEdit;
  final Function(ArCustomer) onView;
  final Function(ArCustomer) onDelete;
  final void Function(ArCustomer) onCallback;

  const ArCustomerListWidget({
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
  State<ArCustomerListWidget> createState() => ArCustomerListWidgetState();

  static Future<void> search(BuildContext context, {required void Function(ArCustomer) onSelected}) {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: Text(isEnglish ? 'Search Customer' : 'ค้นหาลูกค้า', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Container(
          width: 480,
          height: 560,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
          child: ArCustomerListWidget(
            enableAddButton: false,
            enableEditButton: false,
            enableViewButton: false,
            enableDeleteButton: false,
            enableCardSelect: true,
            onAdd: () {},
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

class ArCustomerListWidgetState extends State<ArCustomerListWidget>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'code_asc';
  List<ArCustomer> _lists = [];
  int _totalCount = 0;
  bool _isLoading = false;
  String _error = '';

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
    final isEnglish =
        Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final svc = Provider.of<ArCustomerService>(context, listen: false);
      final fetched = await svc.fetchRows(search: _searchQuery.isEmpty ? null : _searchQuery);
      setState(() {
        _lists = fetched;
        if (_searchQuery.isEmpty) _totalCount = fetched.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = isEnglish
            ? 'Failed to load data: ${e.toString()}'
            : 'ไม่สามารถโหลดข้อมูลได้: ${e.toString()}';
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

  Widget _buildHeader(bool isEnglish) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          if (widget.enableAddButton)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: isEnglish ? 'Add New Customer' : 'เพิ่มลูกหนี้ใหม่',
              onPressed: widget.onAdd,
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: isEnglish ? 'Sort' : 'จัดเรียง',
            onSelected: _onSortSelected,
            itemBuilder: (_) => [
              PopupMenuItem(value: 'code_asc', child: Text(isEnglish ? 'Code (A→Z)' : 'รหัส (น้อยไปมาก)')),
              PopupMenuItem(value: 'code_desc', child: Text(isEnglish ? 'Code (Z→A)' : 'รหัส (มากไปน้อย)')),
              PopupMenuItem(value: 'name_asc', child: Text(isEnglish ? 'Name (A→Z)' : 'ชื่อ (น้อยไปมาก)')),
              PopupMenuItem(value: 'name_desc', child: Text(isEnglish ? 'Name (Z→A)' : 'ชื่อ (มากไปน้อย)')),
            ],
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: isEnglish
                    ? 'Search (Code / Old Code / Name)'
                    : 'ค้นหา (รหัส / รหัสเก่า / ชื่อ)',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) {
                setState(() => _searchQuery = v);
                _fetchLists();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRowCount(bool isEnglish) {
    final text = _searchQuery.isEmpty
        ? (isEnglish ? 'Total $_totalCount rows' : 'ทั้งหมด $_totalCount แถว')
        : (isEnglish
            ? 'Found ${_lists.length} of $_totalCount rows'
            : 'พบ ${_lists.length} จาก $_totalCount แถว');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: const TextStyle(fontSize: 12, color: Colors.black87)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    var display = List<ArCustomer>.from(_lists);
    if (widget.enableCardSelect) display = display.where((e) => e.isActive).toList();
    switch (_sortBy) {
      case 'code_asc': display.sort((a, b) => a.customerCode.compareTo(b.customerCode)); break;
      case 'code_desc': display.sort((a, b) => b.customerCode.compareTo(a.customerCode)); break;
      case 'name_asc': display.sort((a, b) => a.customerNameTh.compareTo(b.customerNameTh)); break;
      case 'name_desc': display.sort((a, b) => b.customerNameTh.compareTo(a.customerNameTh)); break;
    }
    return Column(
      children: [
        _buildHeader(isEnglish),
        _buildRowCount(isEnglish),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : display.isEmpty
                  ? Center(
                      child: Text(isEnglish
                          ? 'No customers found'
                          : 'ไม่พบข้อมูลลูกหนี้'))
                  : ListView.builder(
                      itemCount: display.length,
                      itemBuilder: (context, index) {
                        final item = display[index];
                        final hasNameEn =
                            item.customerNameEn?.isNotEmpty ?? false;
                        final displayName = isEnglish && hasNameEn
                            ? item.customerNameEn!
                            : item.customerNameTh;
                        final altName = hasNameEn
                            ? (isEnglish
                                ? item.customerNameTh
                                : item.customerNameEn)
                            : null;
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8.0, vertical: 4.0),
                          child: Stack(children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: item.isActive
                                  ? Colors.orange.shade100
                                  : Colors.grey.shade200,
                              child: Icon(
                                Icons.person,
                                color: item.isActive
                                    ? Colors.orange.shade700
                                    : Colors.grey,
                              ),
                            ),
                            title: Text(
                              '${item.customerCode}  $displayName',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: item.isActive ? null : Colors.grey,
                              ),
                            ),
                            subtitle: Text(
                              '${item.businessTypeNameThai ?? ''}${item.businessTypeNameThai != null ? '  •  ' : ''}'
                              '${isEnglish ? 'Credit ' : 'เครดิต '}${item.creditTermMonths > 0 ? '${item.creditTermMonths}${isEnglish ? ' mo ' : ' เดือน '}' : ''}${item.creditTermDays}${isEnglish ? ' days' : ' วัน'}'
                              '${item.customerGroupCode != null ? (isEnglish ? '  •  Group: ${item.customerGroupCode}' : '  •  กลุ่ม: ${item.customerGroupCode}') : ''}'
                              '${altName != null && altName.isNotEmpty ? '\n$altName' : ''}',
                            ),
                            isThreeLine: altName != null && altName.isNotEmpty,
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
