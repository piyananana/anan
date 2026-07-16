// widgets/cd_business_type_list_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cd_business_type.dart';
import '../services/cd_business_type_service.dart';
import '../../sa/services/sa_language_provider.dart';

class BusinessTypeListWidget extends StatefulWidget {
  final bool enableAddButton;
  final bool enableEditButton;
  final bool enableViewButton;
  final bool enableDeleteButton;
  final bool enableSortButton;
  final bool enableCardSelect;
  final void Function() onAdd;
  final Function(BusinessType) onEdit;
  final Function(BusinessType) onView;
  final Function(BusinessType) onDelete;
  final void Function(BusinessType) onCallback;

  const BusinessTypeListWidget({
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
  State<BusinessTypeListWidget> createState() => BusinessTypeListWidgetState();

  static Future<void> search(BuildContext context,
      {required void Function(BusinessType) onSelected}) {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          title: Text(isEnglish ? 'Search Business Type' : 'ค้นหา ประเภทธุรกิจ',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Container(
            width: 500,
            height: 600,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: BusinessTypeListWidget(
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
              child: Text(isEnglish ? 'Close' : 'ปิด', style: const TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

class BusinessTypeListWidgetState extends State<BusinessTypeListWidget>
    with AutomaticKeepAliveClientMixin {
  String _sortBy = 'code_asc';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<BusinessType> _lists = [];
  bool _isLoading = false;

  List<BusinessType> _filterAndSort() {
    List<BusinessType> display = List.from(_lists);
    if (widget.enableCardSelect) display = display.where((e) => e.isActive).toList();
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toUpperCase();
      display = display.where((row) {
        return row.businessTypeCode.toUpperCase().contains(query) ||
            row.businessTypeNameThai.toUpperCase().contains(query) ||
            row.businessTypeNameEng.toUpperCase().contains(query);
      }).toList();
    }
    display.sort((a, b) {
      switch (_sortBy) {
        case 'code_asc':
          return a.businessTypeCode.compareTo(b.businessTypeCode);
        case 'code_desc':
          return b.businessTypeCode.compareTo(a.businessTypeCode);
        case 'name_asc':
          return a.businessTypeNameThai.compareTo(b.businessTypeNameThai);
        case 'name_desc':
          return b.businessTypeNameThai.compareTo(a.businessTypeNameThai);
        default:
          return 0;
      }
    });
    return display;
  }

  Future<void> _fetchLists() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final service = Provider.of<BusinessTypeService>(context, listen: false);
      final fetched = await service.fetchRows();
      setState(() {
        _lists = fetched;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEnglish ? 'Cannot load data: ${e.toString()}' : 'ไม่สามารถโหลดข้อมูลได้: ${e.toString()}')),
        );
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

  Widget _buildListHeader(bool isEnglish) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          if (widget.enableAddButton)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: isEnglish ? 'Add New' : 'เพิ่มข้อมูลใหม่',
              onPressed: widget.onAdd,
            ),
          if (widget.enableSortButton)
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              tooltip: isEnglish ? 'Sort' : 'จัดเรียง',
              onSelected: (value) => setState(() => _sortBy = value),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'code_asc', child: Text(isEnglish ? 'Code (A→Z)' : 'รหัส (น้อยไปมาก)')),
                PopupMenuItem(value: 'code_desc', child: Text(isEnglish ? 'Code (Z→A)' : 'รหัส (มากไปน้อย)')),
                PopupMenuItem(value: 'name_asc', child: Text(isEnglish ? 'Name (A→Z)' : 'ชื่อ (ก-ฮ)')),
                PopupMenuItem(value: 'name_desc', child: Text(isEnglish ? 'Name (Z→A)' : 'ชื่อ (ฮ-ก)')),
              ],
            ),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: isEnglish
                    ? 'Search (Code / Business Type Name)'
                    : 'ค้นหา (รหัส / ชื่อประเภทธุรกิจ)',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                border: const OutlineInputBorder(),
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
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final displayList = _filterAndSort();
    final countText = _searchQuery.isEmpty
        ? (isEnglish ? 'Total ${_lists.length} rows' : 'ทั้งหมด ${_lists.length} แถว')
        : (isEnglish
            ? 'Found ${displayList.length} of ${_lists.length} rows'
            : 'พบ ${displayList.length} จาก ${_lists.length} แถว');

    return Column(
      children: [
        _buildListHeader(isEnglish),
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
                  ? Center(child: Text(isEnglish
                      ? 'No business types found'
                      : 'ไม่พบข้อมูลประเภทธุรกิจ'))
                  : ListView.builder(
                      itemCount: displayList.length,
                      itemBuilder: (context, index) {
                        final item = displayList[index];
                        final titleName = isEnglish && item.businessTypeNameEng.isNotEmpty
                            ? item.businessTypeNameEng
                            : item.businessTypeNameThai;
                        final subtitleName = isEnglish
                            ? item.businessTypeNameThai
                            : (item.businessTypeNameEng.isNotEmpty
                                ? item.businessTypeNameEng
                                : null);
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8.0, vertical: 4.0),
                          child: Stack(children: [
                          ListTile(
                            title: Text(
                              '${item.businessTypeCode} — $titleName',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: item.isActive ? null : Colors.grey,
                              ),
                            ),
                            subtitle: subtitleName != null && subtitleName.isNotEmpty
                                ? Text(subtitleName)
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!item.isActive)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Chip(
                                      label: Text(isEnglish ? 'Inactive' : 'หยุดใช้',
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
