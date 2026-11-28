import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../models/im_item.dart';
import '../services/im_item_service.dart';
import '../../sa/utils/sa_menu_theme.dart';

class ImItemListWidget extends StatefulWidget {
  final bool enableAddButton;
  final bool enableEditButton;
  final bool enableViewButton;
  final bool enableDeleteButton;
  final bool enableCardSelect;
  final String? itemTypeFilter;
  /// สินค้าที่เปิดอยู่ทางขวา (หน้าจอข้อมูลสินค้า) — ไฮไลต์การ์ด
  final int? selectedId;
  final void Function() onAdd;
  final Function(ImItem) onEdit;
  final Function(ImItem) onView;
  final Function(ImItem) onDelete;
  final void Function(ImItem) onCallback;

  const ImItemListWidget({
    super.key,
    required this.enableAddButton,
    required this.enableEditButton,
    required this.enableViewButton,
    required this.enableDeleteButton,
    this.enableCardSelect = false,
    this.itemTypeFilter,
    this.selectedId,
    required this.onAdd,
    required this.onEdit,
    required this.onView,
    required this.onDelete,
    required this.onCallback,
  });

  @override
  State<ImItemListWidget> createState() => ImItemListWidgetState();

  /// Picker dialog. Pass [itemTypeFilter] (e.g. 'STOCK') to restrict selectable items.
  static Future<void> search(BuildContext context,
      {required void Function(ImItem) onSelected, String? itemTypeFilter}) {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: Text(isEnglish ? 'Search Item' : 'ค้นหาสินค้า', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Container(
          width: 520,
          height: 600,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
          child: ImItemListWidget(
            enableAddButton: false,
            enableEditButton: false,
            enableViewButton: false,
            enableDeleteButton: false,
            enableCardSelect: true,
            itemTypeFilter: itemTypeFilter,
            onAdd: () {},
            onEdit: (i) {},
            onView: (i) {},
            onDelete: (i) {},
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

class ImItemListWidgetState extends State<ImItemListWidget> with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'code_asc';
  String? _statusFilter; // null | low | inactive
  String? _categoryFilter;
  final _qtyFmt = NumberFormat('#,##0.##');
  List<ImItem> _list = [];
  int _totalCount = 0;
  bool _isLoading = false;
  final _svc = ImItemService();

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
      // หน้าจอข้อมูลสินค้าขอยอดคงเหลือด้วย; dialog ค้นหาไม่ต้อง (เร็วกว่า)
      var rows = await _svc.fetchRows(keyword: _searchQuery.isEmpty ? null : _searchQuery, withStock: !widget.enableCardSelect);
      if (widget.itemTypeFilter != null) {
        rows = rows.where((i) => i.itemType == widget.itemTypeFilter).toList();
      }
      if (mounted) {
        setState(() {
          _list = rows;
          if (_searchQuery.isEmpty) _totalCount = rows.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void refresh() => _fetchList();

  String _itemName(ImItem item, bool isEnglish) =>
      isEnglish && (item.itemNameEn ?? '').isNotEmpty ? item.itemNameEn! : item.itemNameTh;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    if (!widget.enableCardSelect) return _buildScreenList(context, isEnglish);
    final display = _sorted(List<ImItem>.from(_list));

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          if (widget.enableAddButton)
            IconButton(icon: const Icon(Icons.add), tooltip: isEnglish ? 'Add new item' : 'เพิ่มสินค้าใหม่', onPressed: widget.onAdd),
          _sortMenu(isEnglish),
          Expanded(
            child: TextField(
              autofocus: ModalRoute.of(context) is PopupRoute,
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: isEnglish ? 'Search (code / name / barcode)' : 'ค้นหา (รหัส / ชื่อ / บาร์โค้ด)',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) { setState(() => _searchQuery = v); _fetchList(); },
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _searchQuery.isEmpty
                ? (isEnglish ? 'Total $_totalCount rows' : 'ทั้งหมด $_totalCount แถว')
                : (isEnglish ? 'Found ${_list.length} of $_totalCount rows' : 'พบ ${_list.length} จาก $_totalCount แถว'),
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
      ),
      Expanded(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : display.isEmpty
                ? Center(child: Text(isEnglish ? 'No item data found' : 'ไม่พบข้อมูลสินค้า'))
                : ListView.builder(
                    itemCount: display.length,
                    itemBuilder: (context, index) {
                      final item = display[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Stack(children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: item.isActive ? Colors.teal.shade100 : Colors.grey.shade200,
                              child: Icon(
                                item.itemType == 'SERVICE' ? Icons.design_services : Icons.inventory_2,
                                color: item.isActive ? Colors.teal.shade700 : Colors.grey,
                              ),
                            ),
                            title: Text(
                              '${item.itemCode}  ${_itemName(item, isEnglish)}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: item.isActive ? null : Colors.grey),
                            ),
                            subtitle: Text(
                              '${imItemTypeLabel(item.itemType, isEnglish)}'
                              '${item.categoryCode != null ? '  •  ${item.categoryCode}' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                                          SnackBar(content: Text(isEnglish ? 'Cannot use: this item is inactive' : 'ไม่สามารถใช้ได้ เนื่องจากสินค้านี้หยุดใช้งาน'), backgroundColor: Colors.red),
                                        );
                                      }
                                    },
                                  ),
                              ],
                            ),
                            onTap: widget.enableCardSelect ? null : () => widget.onCallback(item),
                          ),
                          if (!item.isActive)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Center(child: Icon(Icons.block, size: 72, color: Colors.red.withOpacity(0.12))),
                              ),
                            ),
                        ]),
                      );
                    },
                  ),
      ),
    ]);
  }

  List<ImItem> _sorted(List<ImItem> display) {
    switch (_sortBy) {
      case 'code_asc':  display.sort((a, b) => a.itemCode.compareTo(b.itemCode)); break;
      case 'code_desc': display.sort((a, b) => b.itemCode.compareTo(a.itemCode)); break;
      case 'name_asc':  display.sort((a, b) => a.itemNameTh.compareTo(b.itemNameTh)); break;
      case 'name_desc': display.sort((a, b) => b.itemNameTh.compareTo(a.itemNameTh)); break;
    }
    return display;
  }

  Widget _sortMenu(bool isEnglish) => PopupMenuButton<String>(
        icon: const Icon(Icons.sort),
        tooltip: isEnglish ? 'Sort' : 'จัดเรียง',
        onSelected: (v) => setState(() => _sortBy = v),
        itemBuilder: (_) => [
          PopupMenuItem(value: 'code_asc',  child: Text(isEnglish ? 'Code (ascending)' : 'รหัส (น้อยไปมาก)')),
          PopupMenuItem(value: 'code_desc', child: Text(isEnglish ? 'Code (descending)' : 'รหัส (มากไปน้อย)')),
          PopupMenuItem(value: 'name_asc',  child: Text(isEnglish ? 'Name (ascending)' : 'ชื่อ (น้อยไปมาก)')),
          PopupMenuItem(value: 'name_desc', child: Text(isEnglish ? 'Name (descending)' : 'ชื่อ (มากไปน้อย)')),
        ],
      );

  // ── หน้าจอข้อมูลสินค้า (แบบ B, user 2026-11-25): การ์ดเล็กมีคงเหลือ + ตัวกรองสถานะ/หมวด ──────────────
  Color get _im => ScreenTheme.of(context).ink;
  static const _ink2 = Color(0xFF55625B);
  static const _ink3 = Color(0xFF8B968F);
  static const _red = Color(0xFFC62828);
  static const _gold = Color(0xFFE0A526);

  Widget _chip(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
      );

  Widget _filterChip(String label, bool on, VoidCallback onTap, {Color? fg}) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: on ? _im : Colors.white.withOpacity(0.65),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(label, style: TextStyle(fontSize: 12, color: on ? Colors.white : (fg ?? _ink2), fontWeight: on ? FontWeight.w600 : null)),
        ),
      );

  Widget _typeChip(ImItem item, bool isEnglish) {
    switch (item.itemType) {
      case 'SERVICE':
        return _chip(isEnglish ? 'SERVICE' : 'บริการ', const Color(0xFFEFE8FB), const Color(0xFF5B3B9A));
      case 'NON_STOCK':
        return _chip(isEnglish ? 'NON-STOCK' : 'ไม่นับสต็อก', const Color(0xFFEEF0F2), const Color(0xFF5B6B7C));
      default:
        return _chip(isEnglish ? 'STOCK' : 'สต็อก', const Color(0xFFE3EEFA), const Color(0xFF1E4F8F));
    }
  }

  Widget _itemCard(ImItem item, bool isEnglish) {
    final selected = widget.selectedId != null && item.id == widget.selectedId;
    final uom = isEnglish && (item.baseUomNameEn ?? '').isNotEmpty ? item.baseUomNameEn! : (item.baseUomNameTh ?? item.baseUomCode ?? '');
    final stock = item.itemType == 'STOCK';
    final low = stock && item.belowReorder;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => widget.onView(item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: selected ? _gold : Colors.transparent, width: selected ? 1.5 : 1),
              boxShadow: selected ? [BoxShadow(color: _gold.withOpacity(0.25), spreadRadius: 2)] : null,
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(item.itemCode, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: item.isActive ? _im : _ink3,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                ),
                if (!item.isActive) ...[_chip(isEnglish ? 'Inactive' : 'หยุดใช้', const Color(0xFFFDECEA), _red), const SizedBox(width: 4)],
                if (item.isLotTracked) ...[_chip('Lot', const Color(0xFFFFF4DA), const Color(0xFF8A5A00)), const SizedBox(width: 4)],
                if (item.isSerialTracked) ...[_chip('Serial', const Color(0xFFFFF4DA), const Color(0xFF8A5A00)), const SizedBox(width: 4)],
                _typeChip(item, isEnglish),
              ]),
              const SizedBox(height: 2),
              Text(_itemName(item, isEnglish), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: item.isActive ? null : _ink3)),
              const SizedBox(height: 3),
              if (stock)
                Text.rich(
                  TextSpan(style: const TextStyle(fontSize: 11.5, color: _ink3), children: [
                    TextSpan(text: isEnglish ? 'On hand ' : 'คงเหลือ '),
                    TextSpan(
                      text: _qtyFmt.format(item.onHandQty ?? 0),
                      style: TextStyle(fontWeight: FontWeight.bold, color: low ? _red : Colors.black87,
                          fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                    TextSpan(text: ' $uom · ${item.costingMethod}'),
                    if (low) TextSpan(text: isEnglish ? ' · below reorder' : ' · ต่ำกว่าจุดสั่งซื้อ', style: const TextStyle(color: _red)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              else
                Text(isEnglish ? 'No stock tracking' : 'ไม่ตัดสต็อก', style: const TextStyle(fontSize: 11.5, color: _ink3)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildScreenList(BuildContext context, bool isEnglish) {
    // หมวดที่มีในรายการ (เรียงตามรหัส) — จำนวนต่อหมวด
    final cats = <String, (String, int)>{};
    for (final i in _list) {
      final code = i.categoryCode ?? '';
      if (code.isEmpty) continue;
      final cur = cats[code];
      cats[code] = (i.categoryName ?? '', (cur?.$2 ?? 0) + 1);
    }
    final catKeys = cats.keys.toList()..sort();
    final lowCount = _list.where((i) => i.itemType == 'STOCK' && i.belowReorder).length;
    final inactiveCount = _list.where((i) => !i.isActive).length;

    var display = _list.where((i) {
      if (_categoryFilter != null && i.categoryCode != _categoryFilter) return false;
      switch (_statusFilter) {
        case 'low': return i.itemType == 'STOCK' && i.belowReorder;
        case 'inactive': return !i.isActive;
        default: return true;
      }
    }).toList();
    display = _sorted(display);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
        child: Row(children: [
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: isEnglish ? 'Search code / name / barcode' : 'ค้นหา รหัส / ชื่อ / บาร์โค้ด',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onChanged: (v) {
                  setState(() => _searchQuery = v);
                  _fetchList();
                },
              ),
            ),
          ),
          _sortMenu(isEnglish),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        child: Wrap(spacing: 4, runSpacing: 4, children: [
          _filterChip(isEnglish ? 'All' : 'ทั้งหมด', _statusFilter == null && _categoryFilter == null,
              () => setState(() { _statusFilter = null; _categoryFilter = null; })),
          if (catKeys.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: isEnglish ? 'Filter by category' : 'กรองตามหมวด',
              onSelected: (v) => setState(() => _categoryFilter = v.isEmpty ? null : v),
              itemBuilder: (_) => [
                PopupMenuItem(value: '', child: Text(isEnglish ? 'All categories' : 'ทุกหมวด')),
                for (final k in catKeys)
                  PopupMenuItem(value: k, child: Text('$k  ${cats[k]!.$1}  (${cats[k]!.$2})', overflow: TextOverflow.ellipsis)),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: _categoryFilter != null ? _im : Colors.white.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_categoryFilter == null ? (isEnglish ? 'Category' : 'หมวด') : _categoryFilter!,
                      style: TextStyle(fontSize: 12, color: _categoryFilter != null ? Colors.white : _ink2,
                          fontWeight: _categoryFilter != null ? FontWeight.w600 : null)),
                  Icon(Icons.arrow_drop_down, size: 16, color: _categoryFilter != null ? Colors.white : _ink2),
                ]),
              ),
            ),
          _filterChip(isEnglish ? 'Below reorder $lowCount' : 'ต่ำกว่าจุดสั่งซื้อ $lowCount', _statusFilter == 'low',
              () => setState(() => _statusFilter = _statusFilter == 'low' ? null : 'low'), fg: lowCount > 0 ? _red : null),
          _filterChip(isEnglish ? 'Inactive $inactiveCount' : 'หยุดใช้ $inactiveCount', _statusFilter == 'inactive',
              () => setState(() => _statusFilter = _statusFilter == 'inactive' ? null : 'inactive')),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        child: Text(
          isEnglish
              ? 'Showing ${display.length} of ${_searchQuery.isEmpty ? _totalCount : _list.length} item(s)'
              : 'แสดง ${display.length} จาก ${_searchQuery.isEmpty ? _totalCount : _list.length} รายการ',
          style: const TextStyle(fontSize: 11.5, color: _ink2),
        ),
      ),
      Expanded(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : display.isEmpty
                ? Center(child: Text(isEnglish ? 'No item data found' : 'ไม่พบข้อมูลสินค้า', style: const TextStyle(color: _ink2)))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 10),
                    itemCount: display.length,
                    itemBuilder: (context, index) => _itemCard(display[index], isEnglish),
                  ),
      ),
    ]);
  }
}
