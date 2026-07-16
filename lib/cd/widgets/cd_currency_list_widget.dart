// widgets/cd_zipcode_list_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../models/cd_currency.dart';
import '../services/cd_currency_service.dart';

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

  static Future<void> search(BuildContext context,
      {required void Function(Currency) onSelected}) {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          title: Text(
              isEnglish ? 'Search Currency & Exchange Rate' : 'ค้นหา สกุลเงินและอัตราแลกเปลี่ยน',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Container(
            width: 500,
            height: 600,
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
              child: Text(isEnglish ? 'Close' : 'ปิด',
                  style: const TextStyle(color: Colors.red)),
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

  List<Currency> _filterAndSort(bool isEnglish) {
    List<Currency> displayLists = List.from(_lists);
    if (widget.enableCardSelect) displayLists = displayLists.where((e) => e.isActive).toList();
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toUpperCase();
      displayLists = displayLists.where((row) {
        return row.currencyCode.toUpperCase().contains(query) ||
            row.currencyNameThai.toUpperCase().contains(query) ||
            row.currencyNameEng.toUpperCase().contains(query) ||
            row.baseCurrencyFlag;
      }).toList();
    }
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

  Widget _buildListHeader(bool isEnglish) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          widget.enableAddButton
              ? IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: isEnglish ? 'Add New' : 'เพิ่มข้อมูลใหม่',
                  onPressed: () => widget.onAdd(),
                )
              : const SizedBox.shrink(),
          widget.enableSortButton
              ? PopupMenuButton<String>(
                  icon: const Icon(Icons.sort),
                  tooltip: isEnglish ? 'Sort' : 'จัดเรียง',
                  onSelected: (result) {
                    _onSortSelected(result);
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'base_asc',
                      child: Text(isEnglish ? 'Base currency last' : 'สกุลเงินหลักอยู่ท้าย'),
                    ),
                    PopupMenuItem<String>(
                      value: 'base_desc',
                      child: Text(isEnglish ? 'Base currency first' : 'สกุลเงินหลักขึ้นก่อน'),
                    ),
                    PopupMenuItem<String>(
                      value: 'code_asc',
                      child: Text(isEnglish ? 'Code (A→Z)' : 'รหัสสกุลเงิน (น้อยไปมาก)'),
                    ),
                    PopupMenuItem<String>(
                      value: 'code_desc',
                      child: Text(isEnglish ? 'Code (Z→A)' : 'รหัสสกุลเงิน (มากไปน้อย)'),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: isEnglish
                    ? 'Search (Currency Code / Name)'
                    : 'ค้นหา (สกุลเงินและอัตราแลกเปลี่ยน)',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                border: const OutlineInputBorder(),
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
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;

    _searchResult = _filterAndSort(isEnglish);
    final countText = _searchQuery.isEmpty
        ? (isEnglish ? 'Total ${_lists.length} rows' : 'ทั้งหมด ${_lists.length} แถว')
        : (isEnglish
            ? 'Found ${_searchResult.length} of ${_lists.length} rows'
            : 'พบ ${_searchResult.length} จาก ${_lists.length} แถว');

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
            : _searchResult.isEmpty
              ? Center(child: Text(isEnglish
                  ? 'No currencies found'
                  : 'ไม่พบสกุลเงินและอัตราแลกเปลี่ยน'))
              : ListView.builder(
                  itemCount: _searchResult.length,
                  itemBuilder: (context, index) {
                    final item = _searchResult[index];
                    final displayName = isEnglish ? item.currencyNameEng : item.currencyNameThai;
                    final baseFlagLabel = isEnglish ? '(Base Currency)' : '(สกุลเงินหลัก)';
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 4.0),
                      child: ListTile(
                        title: Text(
                            '${item.currencyCode} (${item.symbol}) $displayName'
                            '${item.baseCurrencyFlag ? ' $baseFlagLabel' : ''}',
                            style: TextStyle(fontWeight: item.baseCurrencyFlag ? FontWeight.bold : FontWeight.normal),),
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
