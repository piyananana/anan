// lib/cd/widgets/cd_salesperson_list_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../models/cd_salesperson.dart';
import '../services/cd_salesperson_service.dart';

class SalespersonListWidget extends StatefulWidget {
  final bool enableAddButton;
  final bool enableEditButton;
  final bool enableViewButton;
  final bool enableDeleteButton;
  final bool enableCardSelect;
  final void Function() onAdd;
  final Function(Salesperson) onEdit;
  final Function(Salesperson) onView;
  final Function(Salesperson) onDelete;
  final void Function(Salesperson) onCallback;

  const SalespersonListWidget({
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
  State<SalespersonListWidget> createState() => SalespersonListWidgetState();

  static Future<void> search(BuildContext context,
      {required void Function(Salesperson) onSelected}) {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: Text(isEnglish ? 'Search Salesperson' : 'ค้นหา พนักงานขาย',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Container(
          width: 520,
          height: 600,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SalespersonListWidget(
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
            child: Text(isEnglish ? 'Close' : 'ปิด',
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class SalespersonListWidgetState extends State<SalespersonListWidget>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'code_asc';
  List<Salesperson> _list = [];
  int _totalCount = 0;
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final svc = Provider.of<SalespersonService>(context, listen: false);
      final rows = await svc.fetchRows(
          search: _searchQuery.isEmpty ? null : _searchQuery);
      setState(() {
        _list = rows;
        if (_searchQuery.isEmpty) _totalCount = rows.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(isEnglish ? 'Failed to load data: $e' : 'โหลดข้อมูลล้มเหลว: $e')));
      }
    }
  }

  void refresh() => _fetch();

  void _onSortSelected(String v) => setState(() => _sortBy = v);

  List<Salesperson> get _filtered {
    List<Salesperson> items = List.from(_list);
    if (widget.enableCardSelect) items = items.where((e) => e.isActive).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toUpperCase();
      items = items.where((s) {
        return s.salespersonCode.toUpperCase().contains(q) ||
            s.salespersonNameThai.toUpperCase().contains(q) ||
            (s.salespersonNameEng?.toUpperCase().contains(q) ?? false);
      }).toList();
    }
    switch (_sortBy) {
      case 'code_asc': items.sort((a, b) => a.salespersonCode.compareTo(b.salespersonCode)); break;
      case 'code_desc': items.sort((a, b) => b.salespersonCode.compareTo(a.salespersonCode)); break;
      case 'name_asc': items.sort((a, b) => a.salespersonNameThai.compareTo(b.salespersonNameThai)); break;
      case 'name_desc': items.sort((a, b) => b.salespersonNameThai.compareTo(a.salespersonNameThai)); break;
    }
    return items;
  }

  String _typeLabel(String type, bool isEnglish) {
    if (isEnglish) {
      const map = {
        'EMPLOYEE': 'Internal Employee',
        'INDIVIDUAL': 'External Individual',
        'COMPANY': 'Company / Legal Entity',
      };
      return map[type] ?? type;
    }
    return salespersonTypeOptions[type] ?? type;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final display = _filtered;
    final countText = _searchQuery.isEmpty
        ? (isEnglish ? 'Total $_totalCount rows' : 'ทั้งหมด $_totalCount แถว')
        : (isEnglish
            ? 'Found ${display.length} of $_totalCount rows'
            : 'พบ ${display.length} จาก $_totalCount แถว');
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
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
                  PopupMenuItem(value: 'code_asc',  child: Text(isEnglish ? 'Code (A→Z)'  : 'รหัส (น้อยไปมาก)')),
                  PopupMenuItem(value: 'code_desc', child: Text(isEnglish ? 'Code (Z→A)'  : 'รหัส (มากไปน้อย)')),
                  PopupMenuItem(value: 'name_asc',  child: Text(isEnglish ? 'Name (A→Z)'  : 'ชื่อ (น้อยไปมาก)')),
                  PopupMenuItem(value: 'name_desc', child: Text(isEnglish ? 'Name (Z→A)'  : 'ชื่อ (มากไปน้อย)')),
                ],
              ),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: isEnglish
                        ? 'Search (Code / Salesperson Name)'
                        : 'ค้นหา (รหัส / ชื่อพนักงานขาย)',
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                  onSubmitted: (_) => _fetch(),
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
                  ? Center(child: Text(isEnglish
                      ? 'No salespersons found'
                      : 'ไม่พบข้อมูลพนักงานขาย'))
                  : ListView.builder(
                      itemCount: display.length,
                      itemBuilder: (ctx, i) {
                        final item = display[i];
                        final displayName = isEnglish &&
                                item.salespersonNameEng != null &&
                                item.salespersonNameEng!.isNotEmpty
                            ? item.salespersonNameEng!
                            : item.salespersonNameThai;
                        final typeLabel = _typeLabel(item.salespersonType, isEnglish);
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Stack(children: [
                          ListTile(
                            title: Text(
                              '${item.salespersonCode} — $displayName',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: item.isActive ? null : Colors.grey,
                              ),
                            ),
                            subtitle: Text(typeLabel,
                                style: const TextStyle(fontSize: 12)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!item.isActive)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Chip(
                                      label: Text(
                                          isEnglish ? 'Inactive' : 'หยุดใช้',
                                          style: const TextStyle(fontSize: 11)),
                                      backgroundColor: const Color(0xFFEEEEEE),
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
