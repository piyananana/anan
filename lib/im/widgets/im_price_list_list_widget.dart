import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../models/im_price_list.dart';
import '../services/im_price_list_service.dart';
import 'im_master_kit.dart';

class ImPriceListListWidget extends StatefulWidget {
  final bool enableAddButton;
  final bool enableEditButton;
  final bool enableViewButton;
  final bool enableDeleteButton;
  final bool enableCardSelect;
  /// ตารางที่เปิดอยู่ทางขวา (หน้าจอตารางราคา) — ไฮไลต์การ์ด
  final int? selectedId;
  final void Function() onAdd;
  final Function(ImPriceListHeader) onEdit;
  final Function(ImPriceListHeader) onView;
  final Function(ImPriceListHeader) onDelete;
  final void Function(ImPriceListHeader) onCallback;
  // กรองตาม list_type (SALES/PURCHASE) — ใช้ตอนเป็น picker จากหน้าจอ ar_customer (SALES)/ap_vendor (PURCHASE)
  // เพื่อไม่ให้เลือกตารางราคาประเภทผิด null = ไม่กรอง (ใช้ตอนเป็นหน้าจอหลักของตารางราคาเอง)
  final String? listTypeFilter;

  const ImPriceListListWidget({
    super.key,
    required this.enableAddButton,
    required this.enableEditButton,
    required this.enableViewButton,
    required this.enableDeleteButton,
    this.enableCardSelect = false,
    this.selectedId,
    required this.onAdd,
    required this.onEdit,
    required this.onView,
    required this.onDelete,
    required this.onCallback,
    this.listTypeFilter,
  });

  @override
  State<ImPriceListListWidget> createState() => ImPriceListListWidgetState();

  static Future<void> search(BuildContext context, {required void Function(ImPriceListHeader) onSelected, String? listType}) {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: Text(isEnglish ? 'Search Price List' : 'ค้นหาตารางราคา', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Container(
          width: 460,
          height: 520,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
          child: ImPriceListListWidget(
            enableAddButton: false,
            enableEditButton: false,
            enableViewButton: false,
            enableDeleteButton: false,
            enableCardSelect: true,
            listTypeFilter: listType,
            onAdd: () {},
            onEdit: (h) {},
            onView: (h) {},
            onDelete: (h) {},
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

class ImPriceListListWidgetState extends State<ImPriceListListWidget> with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  List<ImPriceListHeader> _list = [];
  bool _isLoading = false;
  String? _typeFilter; // SALES | PURCHASE | _inactive
  String? _groupFilter;
  final _svc = ImPriceListService();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchList() async {
    setState(() => _isLoading = true);
    try {
      final rows = await _svc.fetchRows();
      if (mounted) setState(() { _list = rows; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void refresh() => _fetchList();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    if (!widget.enableCardSelect) return _buildScreenList(isEnglish);
    final q = _searchQuery.trim().toUpperCase();
    final typeFiltered = widget.listTypeFilter == null ? _list : _list.where((h) => h.listType == widget.listTypeFilter).toList();
    final display = q.isEmpty
        ? typeFiltered
        : typeFiltered.where((h) => h.priceListCode.toUpperCase().contains(q) || h.priceListName.toUpperCase().contains(q)).toList();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          if (widget.enableAddButton)
            IconButton(icon: const Icon(Icons.add), tooltip: isEnglish ? 'Add new price list' : 'เพิ่มตารางราคาใหม่', onPressed: widget.onAdd),
          Expanded(
            child: TextField(
              autofocus: ModalRoute.of(context) is PopupRoute,
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: isEnglish ? 'Search (code / name)' : 'ค้นหา (รหัส / ชื่อ)',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ]),
      ),
      Expanded(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : display.isEmpty
                ? Center(child: Text(isEnglish ? 'No price list data found' : 'ไม่พบข้อมูลตารางราคา'))
                : ListView.builder(
                    itemCount: display.length,
                    itemBuilder: (context, index) {
                      final item = display[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: item.isActive ? Colors.teal.shade100 : Colors.grey.shade200,
                            child: Icon(
                              item.listType == 'PURCHASE' ? Icons.shopping_cart_outlined : Icons.sell_outlined,
                              color: item.isActive ? Colors.teal.shade700 : Colors.grey,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            '${item.priceListCode}  ${item.priceListName}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: item.isActive ? null : Colors.grey),
                          ),
                          subtitle: Text(
                            '${imPriceListTypeLabel(item.listType, isEnglish)}'
                            '${item.currencyCode != null ? '  •  ${item.currencyCode}' : ''}'
                            '${item.priceIncludesVat ? (isEnglish ? '  •  incl. VAT' : '  •  รวม VAT') : ''}'
                            '  •  ${isEnglish ? '${item.lineCount} items' : '${item.lineCount} รายการ'}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.enableViewButton)
                                IconButton(icon: const Icon(Icons.visibility, size: 18), tooltip: isEnglish ? 'View' : 'ดูข้อมูล', onPressed: () => widget.onView(item)),
                              if (widget.enableEditButton)
                                IconButton(icon: const Icon(Icons.edit, size: 18), tooltip: isEnglish ? 'Edit' : 'แก้ไข', onPressed: () => widget.onEdit(item)),
                              if (widget.enableDeleteButton)
                                IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), tooltip: isEnglish ? 'Delete' : 'ลบ', onPressed: () => widget.onDelete(item)),
                              if (widget.enableCardSelect)
                                IconButton(
                                  icon: const Icon(Icons.arrow_right_outlined, color: Colors.black),
                                  onPressed: () {
                                    if (item.isActive) {
                                      widget.onCallback(item);
                                      Navigator.of(context).pop();
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(isEnglish ? 'Cannot use: this price list is inactive' : 'ไม่สามารถใช้ได้ เนื่องจากตารางราคานี้หยุดใช้งาน'), backgroundColor: Colors.red),
                                      );
                                    }
                                  },
                                ),
                            ],
                          ),
                          onTap: widget.enableCardSelect ? null : () => widget.onCallback(item),
                        ),
                      );
                    },
                  ),
      ),
    ]);
  }

  // ── หน้าจอตารางราคา (แบบ B, user 2026-11-25): การ์ดพร้อมประเภท/ค่าเริ่มต้น/กลุ่ม/สกุลเงิน/จำนวนรายการ ──
  Widget _buildScreenList(bool isEnglish) {
    final q = _searchQuery.trim().toUpperCase();
    final searched = q.isEmpty
        ? _list
        : _list.where((h) => h.priceListCode.toUpperCase().contains(q) || h.priceListName.toUpperCase().contains(q) || (h.priceListNameEn ?? '').toUpperCase().contains(q)).toList();
    final groups = <String, String>{};
    for (final h in _list) {
      if ((h.priceGroupCode ?? '').isNotEmpty) {
        groups[h.priceGroupCode!] = '${h.priceGroupCode}  ${isEnglish && (h.priceGroupNameEn ?? '').isNotEmpty ? h.priceGroupNameEn : (h.priceGroupNameTh ?? '')}';
      }
    }
    final groupKeys = groups.keys.toList()..sort();
    final sales = searched.where((h) => h.listType == 'SALES').length;
    final purchase = searched.where((h) => h.listType == 'PURCHASE').length;
    final inactive = searched.where((h) => !h.isActive).length;
    final display = searched.where((h) {
      if (_groupFilter != null && h.priceGroupCode != _groupFilter) return false;
      if (_typeFilter == '_inactive') return !h.isActive;
      if (_typeFilter != null) return h.listType == _typeFilter;
      return true;
    }).toList()
      ..sort((a, b) => a.priceListCode.compareTo(b.priceListCode));
    void toggle(String f) => setState(() => _typeFilter = _typeFilter == f ? null : f);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ImMasterListHeader(
        searchCtrl: _searchCtrl,
        hint: isEnglish ? 'Search code / price list name' : 'ค้นหา รหัส / ชื่อตารางราคา',
        onSearch: (v) => setState(() => _searchQuery = v),
        filters: [
          ImMasterFilterChip(label: isEnglish ? 'All' : 'ทั้งหมด', on: _typeFilter == null && _groupFilter == null,
              onTap: () => setState(() { _typeFilter = null; _groupFilter = null; })),
          ImMasterFilterChip(label: isEnglish ? 'Sales $sales' : 'ราคาขาย $sales', on: _typeFilter == 'SALES', onTap: () => toggle('SALES')),
          ImMasterFilterChip(label: isEnglish ? 'Purchase $purchase' : 'ราคาซื้อ $purchase', on: _typeFilter == 'PURCHASE', onTap: () => toggle('PURCHASE')),
          if (groupKeys.isNotEmpty)
            ImMasterPopupFilter(
              label: isEnglish ? 'Group' : 'กลุ่ม',
              value: _groupFilter,
              options: [for (final k in groupKeys) (k, groups[k]!)],
              allLabel: isEnglish ? 'All groups' : 'ทุกกลุ่ม',
              onChanged: (v) => setState(() => _groupFilter = v),
            ),
          ImMasterFilterChip(label: isEnglish ? 'Inactive $inactive' : 'หยุดใช้ $inactive', on: _typeFilter == '_inactive', onTap: () => toggle('_inactive')),
        ],
        countText: isEnglish ? 'Showing ${display.length} of ${_list.length} list(s)' : 'แสดง ${display.length} จาก ${_list.length} รายการ',
      ),
      Expanded(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : display.isEmpty
                ? Center(child: Text(isEnglish ? 'No price list found' : 'ไม่พบตารางราคา', style: const TextStyle(color: ImKit.ink2)))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 10),
                    itemCount: display.length,
                    itemBuilder: (context, i) {
                      final h = display[i];
                      return ImMasterListCard(
                        code: h.priceListCode,
                        active: h.isActive,
                        chips: [
                          if (!h.isActive) ImKit.chip(isEnglish ? 'Inactive' : 'หยุดใช้', ImKit.redSoft, ImKit.red),
                          if (h.isDefault) ImKit.chip(isEnglish ? 'Default' : 'ค่าเริ่มต้น', ImKit.goldSoft, ImKit.amber),
                          h.listType == 'PURCHASE'
                              ? ImKit.chip(isEnglish ? 'Purchase' : 'ซื้อ', ImKit.purSoft, ImKit.pur)
                              : ImKit.chip(isEnglish ? 'Sales' : 'ขาย', ImKit.blueSoft, ImKit.blue),
                        ],
                        name: h.displayName(isEnglish),
                        meta: TextSpan(children: [
                          if ((h.priceGroupCode ?? '').isNotEmpty) TextSpan(text: '${h.priceGroupCode} · '),
                          TextSpan(text: '${h.currencyCode ?? ''} ${h.priceIncludesVat ? (isEnglish ? 'incl. VAT' : 'รวม VAT') : (isEnglish ? 'excl. VAT' : 'ไม่รวม VAT')} · '),
                          TextSpan(text: '${h.lineCount}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                          TextSpan(text: isEnglish ? ' line(s)' : ' รายการ'),
                        ]),
                        selected: widget.selectedId == h.id,
                        onTap: () => widget.onView(h),
                      );
                    },
                  ),
      ),
    ]);
  }
}
