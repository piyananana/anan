import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../models/cd_vat_rate.dart';
import '../services/cd_vat_rate_service.dart';

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
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: Text(
            isEnglish ? 'Search VAT Rate' : 'ค้นหา อัตราภาษีมูลค่าเพิ่ม',
            style: const TextStyle(fontWeight: FontWeight.bold)),
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
            child: Text(isEnglish ? 'Close' : 'ปิด',
                style: const TextStyle(color: Colors.red)),
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
    if (widget.enableCardSelect) items = items.where((e) => e.isActive).toList();
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

  Widget _buildHeader(bool isEnglish) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          if (widget.enableAddButton)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: isEnglish ? 'Add New VAT Rate' : 'เพิ่มอัตราภาษีใหม่',
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
                hintText: isEnglish ? 'Search (Code / VAT Name)' : 'ค้นหา (รหัส / ชื่อภาษี)',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                border: const OutlineInputBorder(),
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
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final items = _filtered();
    final countText = _searchQuery.isEmpty
        ? (isEnglish ? 'Total ${_lists.length} rows' : 'ทั้งหมด ${_lists.length} แถว')
        : (isEnglish
            ? 'Found ${items.length} of ${_lists.length} rows'
            : 'พบ ${items.length} จาก ${_lists.length} แถว');
    return Column(
      children: [
        _buildHeader(isEnglish),
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
                  ? Center(child: Text(isEnglish
                      ? 'No VAT rates found'
                      : 'ไม่พบข้อมูลอัตราภาษีมูลค่าเพิ่ม'))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final displayName = isEnglish && item.vatNameEn != null
                            ? item.vatNameEn!
                            : item.vatNameTh;
                        final presentLabel = isEnglish ? 'Present' : 'ปัจจุบัน';
                        final endLabel = item.endDate != null
                            ? _dateFmt.format(item.endDate!)
                            : presentLabel;
                        final activeRange = isEnglish
                            ? 'Valid: ${_dateFmt.format(item.effectiveDate)} – $endLabel'
                            : 'ใช้งาน: ${_dateFmt.format(item.effectiveDate)} – $endLabel';
                        final accountLabel = item.glAccountCode != null
                            ? (isEnglish ? 'Account' : 'บัญชี')
                            : null;
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8.0, vertical: 4.0),
                          child: Stack(children: [
                          ListTile(
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
                              '${item.vatCode}  $displayName',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: item.isActive ? null : Colors.grey,
                              ),
                            ),
                            subtitle: Text(
                              [
                                activeRange,
                                if (item.glAccountCode != null)
                                  '$accountLabel: ${item.glAccountCode}  ${item.glAccountName ?? ''}',
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
