// widgets/zipcode_list_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/currency.dart';
import '../services/currency_service.dart';

class CurrencyListWidget extends StatefulWidget {
  final bool enableAddButton;
  final bool enableEditButton;
  final bool enableViewButton;
  final bool enableDeleteButton;
  final bool enableSortButton;
  final bool enableCardSelect;
  final void Function() onAdd;
  final Function(Currency) onEdit;
  final Function(Currency) onView;
  final Function(Currency) onDelete;
  final void Function(Currency) onCallback;

  const CurrencyListWidget({
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
  State<CurrencyListWidget> createState() => CurrencyListWidgetState();

  // เมธอด static สำหรับแสดง Dialog
  static Future<void> search(BuildContext context,
      {required void Function(Currency) onSelected}) {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          // กำหนดขนาดให้ใหญ่ขึ้นเพื่อให้ใช้งานสะดวก
          contentPadding: EdgeInsets.zero,
          title: const Text('ค้นหา สกุลเงินและอัตราแลกเปลี่ยน',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Container(
            width: 500, // กำหนดความกว้างที่เหมาะสม
            height: 600, // กำหนดความสูงที่เหมาะสม
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: CurrencyListWidget(
              enableAddButton: false,
              enableEditButton: false,
              enableViewButton: false,
              enableDeleteButton: false,
              enableSortButton: false,
              enableCardSelect: true,
              onAdd: () {},
              onEdit: (currency) {},
              onView: (currency) {},
              onDelete: (currency) {},
              onCallback: onSelected,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ปิด', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

class CurrencyListWidgetState extends State<CurrencyListWidget>
    with AutomaticKeepAliveClientMixin {
  String _sortBy = 'province_asc';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Currency> _searchResult = [];

  List<Currency> _lists = [];
  bool _isLoading = false;
  String _error = '';

  List<Currency> _filterAndSort() {
    List<Currency> displayLists = List.from(_lists);
    // 1. Filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toUpperCase();
      displayLists = displayLists.where((row) {
        return row.currencyCode.toUpperCase().contains(query) ||
            row.currencyNameThai.toUpperCase().contains(query) ||
            row.baseCurrencyFlag;
      }).toList();
    }
    // 2. Sort
    displayLists.sort((a, b) {
      switch (_sortBy) {
        case 'base_asc':
          return a.baseCurrencyFlag.toString().compareTo(b.baseCurrencyFlag.toString());
        case 'base_desc':
          return b.baseCurrencyFlag.toString().compareTo(a.baseCurrencyFlag.toString());
        case 'code_asc':
          return a.currencyCode.compareTo(b.currencyCode);
        case 'code_desc':
          return b.currencyCode.compareTo(a.currencyCode);
        default:
          return 0;
      }
    });

    return displayLists;
  }

  Future<void> _fetchLists() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final dataService = Provider.of<CurrencyService>(context, listen: false);
      final fetched = await dataService.fetchRows();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_error)),
        );
      }
    }
  }

  void refresh() {
    _fetchLists();
  }

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

  void _onSortSelected(String sortBy) {
    setState(() {
      _sortBy = sortBy;
    });
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          widget.enableAddButton
              ? IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'เพิ่มข้อมูลใหม่',
                  onPressed: () => widget.onAdd(),
                )
              : const SizedBox.shrink(),
          widget.enableSortButton
              ? PopupMenuButton<String>(
                  icon: const Icon(Icons.sort),
                  tooltip: 'จัดเรียง',
                  onSelected: (result) {
                    _onSortSelected(result);
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'base_asc',
                      child: Text('สกุลเงินหลักอยู่ท้าย'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'base_desc',
                      child: Text('สกุลเงินหลักขึ้นก่อน'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'code_asc',
                      child: Text('รหัสสกุลเงิน (น้อยไปมาก)'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'code_desc',
                      child: Text('รหัสสกุลเงิน (มากไปน้อย)'),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'ค้นหา (สกุลเงินและอัตราแลกเปลี่ยน)',
                prefixIcon: Icon(Icons.search),
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
                // border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    _searchResult = _filterAndSort();
    final countText = _searchQuery.isEmpty
        ? 'ทั้งหมด ${_lists.length} แถว'
        : 'พบ ${_searchResult.length} จาก ${_lists.length} แถว';

    return Column(
      children: [
        _buildListHeader(),
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
            : _searchResult.isEmpty
              ? const Center(child: Text('ไม่พบสกุลเงินและอัตราแลกเปลี่ยน'))
              : ListView.builder(
                  itemCount: _searchResult.length,
                  itemBuilder: (context, index) {
                    final item = _searchResult[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 4.0),
                      child: ListTile(
                        // leading: Text('${(index + 1).toString()}.'),
                        // // CircleAvatar(
                        // //   child: Text((index + 1).toString()),
                        // // ),
                        // // title: Text(item.item),
                        title: Text(
                            '${item.currencyCode} (${item.symbol}) ${item.currencyNameThai} ${item.baseCurrencyFlag ? "(สกุลเงินหลัก)" : ""}',
                            style: TextStyle(fontWeight: item.baseCurrencyFlag ? FontWeight.bold : FontWeight.normal),),
                        // subtitle: Text(
                        //     '${item.subDistrict} ${item.district} ${item.province}'),
                        // isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            widget.enableViewButton
                                ? IconButton(
                                    icon: const Icon(Icons.visibility,
                                        color: Colors.green),
                                    onPressed: () => widget.onView(item),
                                  )
                                : const SizedBox.shrink(),
                            widget.enableEditButton
                                ? IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue),
                                    onPressed: () => widget.onEdit(item),
                                  )
                                : const SizedBox.shrink(),
                            widget.enableDeleteButton
                                ? IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => widget.onDelete(item),
                                  )
                                : const SizedBox.shrink(),
                            widget.enableCardSelect
                                ? IconButton(
                                    icon: const Icon(Icons.arrow_right_outlined,
                                        color: Colors.black),
                                    onPressed: () {
                                      widget.onCallback(item);
                                      Navigator.of(context).pop();
                                    },
                                  )
                                : const SizedBox.shrink(),
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
