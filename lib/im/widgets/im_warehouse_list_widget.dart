import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../models/im_warehouse.dart';
import 'package:intl/intl.dart';
import '../services/im_warehouse_service.dart';
import 'im_master_kit.dart';

class ImWarehouseListWidget extends StatefulWidget {
  final bool enableAddButton;
  final bool enableEditButton;
  final bool enableViewButton;
  final bool enableDeleteButton;
  final bool enableCardSelect;
  /// คลังที่เปิดอยู่ทางขวา (หน้าจอคลังสินค้า) — ไฮไลต์การ์ด
  final int? selectedId;
  final void Function() onAdd;
  final Function(ImWarehouse) onEdit;
  final Function(ImWarehouse) onView;
  final Function(ImWarehouse) onDelete;
  final void Function(ImWarehouse) onCallback;

  const ImWarehouseListWidget({
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
  });

  @override
  State<ImWarehouseListWidget> createState() => ImWarehouseListWidgetState();

  static Future<void> search(BuildContext context, {required void Function(ImWarehouse) onSelected}) {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: Text(isEnglish ? 'Search Warehouse' : 'ค้นหาคลังสินค้า', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Container(
          width: 480,
          height: 560,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
          child: ImWarehouseListWidget(
            enableAddButton: false,
            enableEditButton: false,
            enableViewButton: false,
            enableDeleteButton: false,
            enableCardSelect: true,
            onAdd: () {},
            onEdit: (w) {},
            onView: (w) {},
            onDelete: (w) {},
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

class ImWarehouseListWidgetState extends State<ImWarehouseListWidget> with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  List<ImWarehouse> _list = [];
  bool _isLoading = false;
  String? _branchFilter;
  String? _statusFilter; // consignee | inactive | low
  final _svc = ImWarehouseService();

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
      // หน้าจอคลังสินค้าขอยอดรวมต่อคลังด้วย; dialog ค้นหาไม่ต้อง
      final rows = await _svc.fetchRows(withStock: !widget.enableCardSelect);
      if (mounted) setState(() { _list = rows; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void refresh() => _fetchList();

  String _warehouseName(ImWarehouse item, bool isEnglish) =>
      isEnglish && (item.warehouseNameEn ?? '').isNotEmpty ? item.warehouseNameEn! : item.warehouseNameTh;

  String _branchName(ImWarehouse item, bool isEnglish) =>
      isEnglish && (item.branchNameEn ?? '').isNotEmpty ? item.branchNameEn! : (item.branchNameTh ?? '');

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    if (!widget.enableCardSelect) return _buildScreenList(isEnglish);
    final q = _searchQuery.trim().toUpperCase();
    final display = q.isEmpty
        ? _list
        : _list.where((w) => w.warehouseCode.toUpperCase().contains(q) || w.warehouseNameTh.toUpperCase().contains(q) || (w.warehouseNameEn ?? '').toUpperCase().contains(q)).toList();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          if (widget.enableAddButton)
            IconButton(icon: const Icon(Icons.add), tooltip: isEnglish ? 'Add new warehouse' : 'เพิ่มคลังสินค้าใหม่', onPressed: widget.onAdd),
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
                ? Center(child: Text(isEnglish ? 'No warehouse data found' : 'ไม่พบข้อมูลคลังสินค้า'))
                : ListView.builder(
                    itemCount: display.length,
                    itemBuilder: (context, index) {
                      final item = display[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: item.isActive ? Colors.teal.shade100 : Colors.grey.shade200,
                            child: Icon(item.isConsignee ? Icons.handshake_outlined : Icons.warehouse,
                                color: item.isActive ? Colors.teal.shade700 : Colors.grey, size: 20),
                          ),
                          title: Text(
                            '${item.warehouseCode}  ${_warehouseName(item, isEnglish)}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: item.isActive ? null : Colors.grey),
                          ),
                          subtitle: (item.isDefault || item.isConsignee || item.branchId != null)
                              ? Text([
                                  if (item.isDefault) (isEnglish ? 'Main warehouse' : 'คลังหลัก'),
                                  if (item.isConsignee) (isEnglish ? 'Consignee warehouse' : 'คลังผู้รับฝากขาย'),
                                  if (item.branchId != null) _branchName(item, isEnglish),
                                ].join('  •  '))
                              : null,
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
                                        SnackBar(content: Text(isEnglish ? 'Cannot use: this warehouse is inactive' : 'ไม่สามารถใช้ได้ เนื่องจากคลังสินค้านี้หยุดใช้งาน'), backgroundColor: Colors.red),
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

  // ── หน้าจอคลังสินค้า (แบบ B, user 2026-11-25): การ์ดพร้อมสาขา/จำนวนสินค้า/มูลค่า + กรองสาขา/ฝากขาย/ต่ำกว่าจุดสั่งซื้อ ──
  static String _millions(double v, bool isEnglish) => v.abs() >= 1000000
      ? '${NumberFormat('#,##0.00').format(v / 1000000)} ${isEnglish ? 'M' : 'ล้าน'}'
      : NumberFormat('#,##0').format(v);

  Widget _buildScreenList(bool isEnglish) {
    final q = _searchQuery.trim().toUpperCase();
    final searched = q.isEmpty
        ? _list
        : _list.where((w) => w.warehouseCode.toUpperCase().contains(q) || w.warehouseNameTh.toUpperCase().contains(q) || (w.warehouseNameEn ?? '').toUpperCase().contains(q)).toList();
    final branches = <String, String>{};
    for (final w in _list) {
      if ((w.branchCode ?? '').isNotEmpty) branches[w.branchCode!] = '${w.branchCode}  ${w.branchName(isEnglish)}';
    }
    final branchKeys = branches.keys.toList()..sort();
    final consignee = searched.where((w) => w.isConsignee).length;
    final inactive = searched.where((w) => !w.isActive).length;
    final low = searched.where((w) => w.belowCount > 0).length;
    final display = searched.where((w) {
      if (_branchFilter != null && w.branchCode != _branchFilter) return false;
      switch (_statusFilter) {
        case 'consignee': return w.isConsignee;
        case 'inactive': return !w.isActive;
        case 'low': return w.belowCount > 0;
        default: return true;
      }
    }).toList()
      ..sort((a, b) => a.warehouseCode.compareTo(b.warehouseCode));
    void toggle(String f) => setState(() => _statusFilter = _statusFilter == f ? null : f);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ImMasterListHeader(
        searchCtrl: _searchCtrl,
        hint: isEnglish ? 'Search code / warehouse name' : 'ค้นหา รหัส / ชื่อคลัง',
        onSearch: (v) => setState(() => _searchQuery = v),
        filters: [
          ImMasterFilterChip(label: isEnglish ? 'All' : 'ทั้งหมด', on: _statusFilter == null && _branchFilter == null,
              onTap: () => setState(() { _statusFilter = null; _branchFilter = null; })),
          if (branchKeys.length > 1)
            ImMasterPopupFilter(
              label: isEnglish ? 'Branch' : 'สาขา',
              value: _branchFilter,
              options: [for (final k in branchKeys) (k, branches[k]!)],
              allLabel: isEnglish ? 'All branches' : 'ทุกสาขา',
              onChanged: (v) => setState(() => _branchFilter = v),
            ),
          ImMasterFilterChip(label: isEnglish ? 'Below reorder $low' : 'มีสินค้าต่ำกว่าจุดสั่งซื้อ $low', on: _statusFilter == 'low',
              onTap: () => toggle('low'), fg: low > 0 ? ImKit.red : null),
          ImMasterFilterChip(label: isEnglish ? 'Consignee $consignee' : 'ฝากขาย $consignee', on: _statusFilter == 'consignee', onTap: () => toggle('consignee')),
          ImMasterFilterChip(label: isEnglish ? 'Inactive $inactive' : 'หยุดใช้ $inactive', on: _statusFilter == 'inactive', onTap: () => toggle('inactive')),
        ],
        countText: isEnglish ? 'Showing ${display.length} of ${_list.length} warehouse(s)' : 'แสดง ${display.length} จาก ${_list.length} รายการ',
      ),
      Expanded(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : display.isEmpty
                ? Center(child: Text(isEnglish ? 'No warehouse found' : 'ไม่พบคลังสินค้า', style: const TextStyle(color: ImKit.ink2)))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 10),
                    itemCount: display.length,
                    itemBuilder: (context, i) {
                      final w = display[i];
                      return ImMasterListCard(
                        code: w.warehouseCode,
                        active: w.isActive,
                        chips: [
                          if (!w.isActive) ImKit.chip(isEnglish ? 'Inactive' : 'หยุดใช้', ImKit.redSoft, ImKit.red),
                          if (w.isDefault) ImKit.chip(isEnglish ? 'Main' : 'คลังหลัก', ImKit.goldSoft, ImKit.amber),
                          if (w.isConsignee) ImKit.chip(isEnglish ? 'Consignee' : 'ฝากขาย', ImKit.purSoft, ImKit.pur),
                        ],
                        name: w.warehouseName(isEnglish),
                        meta: TextSpan(children: [
                          if ((w.branchCode ?? '').isNotEmpty) TextSpan(text: '${w.branchName(isEnglish).isNotEmpty ? w.branchName(isEnglish) : w.branchCode} · '),
                          TextSpan(text: '${w.itemCount}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                          TextSpan(text: isEnglish ? ' item(s) · ' : ' สินค้า · '),
                          TextSpan(text: _millions(w.totalValue, isEnglish)),
                          if (w.belowCount > 0)
                            TextSpan(text: isEnglish ? ' · below reorder ${w.belowCount}' : ' · ต่ำกว่าจุดสั่งซื้อ ${w.belowCount}', style: const TextStyle(color: ImKit.red)),
                        ]),
                        selected: widget.selectedId == w.id,
                        onTap: () => widget.onView(w),
                      );
                    },
                  ),
      ),
    ]);
  }
}
