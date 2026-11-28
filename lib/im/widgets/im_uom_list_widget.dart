import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../models/im_uom.dart';
import '../services/im_uom_service.dart';
import 'im_master_kit.dart';

class ImUomListWidget extends StatefulWidget {
  final bool enableAddButton;
  final bool enableEditButton;
  final bool enableViewButton;
  final bool enableDeleteButton;
  final bool enableCardSelect;
  /// หน่วยที่เปิดอยู่ทางขวา (หน้าจอหน่วยนับ) — ไฮไลต์การ์ด
  final int? selectedId;
  final void Function() onAdd;
  final Function(ImUom) onEdit;
  final Function(ImUom) onView;
  final Function(ImUom) onDelete;
  final void Function(ImUom) onCallback;

  const ImUomListWidget({
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
  State<ImUomListWidget> createState() => ImUomListWidgetState();

  static Future<void> search(BuildContext context, {required void Function(ImUom) onSelected}) {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: Text(isEnglish ? 'Search Unit of Measure' : 'ค้นหาหน่วยนับ', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Container(
          width: 420,
          height: 520,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
          child: ImUomListWidget(
            enableAddButton: false,
            enableEditButton: false,
            enableViewButton: false,
            enableDeleteButton: false,
            enableCardSelect: true,
            onAdd: () {},
            onEdit: (u) {},
            onView: (u) {},
            onDelete: (u) {},
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

class ImUomListWidgetState extends State<ImUomListWidget> with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  List<ImUom> _list = [];
  bool _isLoading = false;
  String? _dimFilter; // ประเภทหน่วย | '_inactive'
  final _svc = ImUomService();

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
      // หน้าจอหน่วยนับขอจำนวนสินค้าที่ใช้ด้วย; dialog ค้นหาไม่ต้อง
      final rows = await _svc.fetchRows(withUsage: !widget.enableCardSelect);
      if (mounted) setState(() { _list = rows; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void refresh() => _fetchList();

  String _uomName(ImUom item, bool isEnglish) =>
      isEnglish && (item.uomNameEn ?? '').isNotEmpty ? item.uomNameEn! : item.uomNameTh;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    if (!widget.enableCardSelect) return _buildScreenList(isEnglish);
    final q = _searchQuery.trim().toUpperCase();
    final display = q.isEmpty
        ? _list
        : _list.where((u) => u.uomCode.toUpperCase().contains(q) || u.uomNameTh.toUpperCase().contains(q) || (u.uomNameEn ?? '').toUpperCase().contains(q)).toList();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          if (widget.enableAddButton)
            IconButton(icon: const Icon(Icons.add), tooltip: isEnglish ? 'Add new UOM' : 'เพิ่มหน่วยนับใหม่', onPressed: widget.onAdd),
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
                ? Center(child: Text(isEnglish ? 'No UOM data found' : 'ไม่พบข้อมูลหน่วยนับ'))
                : ListView.builder(
                    itemCount: display.length,
                    itemBuilder: (context, index) {
                      final item = display[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: item.isActive ? Colors.teal.shade100 : Colors.grey.shade200,
                            child: Icon(Icons.straighten, color: item.isActive ? Colors.teal.shade700 : Colors.grey, size: 20),
                          ),
                          title: Text(
                            '${item.uomCode}  ${_uomName(item, isEnglish)}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: item.isActive ? null : Colors.grey),
                          ),
                          subtitle: Text(
                            '${uomDimensionLabel(item.uomDimension, isEnglish)} · '
                            '${isEnglish ? 'Decimals' : 'ทศนิยม'} ${item.decimalPlaces}',
                            style: const TextStyle(fontSize: 12),
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
                                        SnackBar(content: Text(isEnglish ? 'Cannot use: this UOM is inactive' : 'ไม่สามารถใช้ได้ เนื่องจากหน่วยนับนี้หยุดใช้งาน'), backgroundColor: Colors.red),
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

  // ── หน้าจอหน่วยนับ (แบบ B, user 2026-11-25): การ์ดพร้อมประเภท/ทศนิยม/จำนวนสินค้าที่ใช้ + กรองตามประเภท ──
  Widget _dimChip(String dim, bool isEnglish) {
    switch (dim) {
      case 'WEIGHT': return ImKit.chip(uomDimensionLabel(dim, isEnglish), ImKit.goldSoft, ImKit.amber);
      case 'LENGTH': return ImKit.chip(uomDimensionLabel(dim, isEnglish), ImKit.purSoft, ImKit.pur);
      case 'COUNT': return ImKit.chip(uomDimensionLabel(dim, isEnglish), ImKit.blueSoft, ImKit.blue);
      default: return ImKit.chip(uomDimensionLabel(dim, isEnglish), ImKit.ro, ImKit.gMore);
    }
  }

  Widget _buildScreenList(bool isEnglish) {
    final q = _searchQuery.trim().toUpperCase();
    final searched = q.isEmpty
        ? _list
        : _list.where((u) => u.uomCode.toUpperCase().contains(q) || u.uomNameTh.toUpperCase().contains(q) || (u.uomNameEn ?? '').toUpperCase().contains(q)).toList();
    final dimCounts = <String, int>{};
    for (final u in searched) {
      dimCounts[u.uomDimension] = (dimCounts[u.uomDimension] ?? 0) + 1;
    }
    final inactive = searched.where((u) => !u.isActive).length;
    final display = searched.where((u) {
      if (_dimFilter == null) return true;
      if (_dimFilter == '_inactive') return !u.isActive;
      return u.uomDimension == _dimFilter;
    }).toList()
      ..sort((a, b) => a.uomCode.compareTo(b.uomCode));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ImMasterListHeader(
        searchCtrl: _searchCtrl,
        hint: isEnglish ? 'Search code / unit name' : 'ค้นหา รหัส / ชื่อหน่วย',
        onSearch: (v) => setState(() => _searchQuery = v),
        filters: [
          ImMasterFilterChip(label: isEnglish ? 'All' : 'ทั้งหมด', on: _dimFilter == null, onTap: () => setState(() => _dimFilter = null)),
          for (final d in kUomDimensions)
            if ((dimCounts[d] ?? 0) > 0)
              ImMasterFilterChip(
                label: '${uomDimensionLabel(d, isEnglish)} ${dimCounts[d]}',
                on: _dimFilter == d,
                onTap: () => setState(() => _dimFilter = _dimFilter == d ? null : d),
              ),
          ImMasterFilterChip(
            label: isEnglish ? 'Inactive $inactive' : 'หยุดใช้ $inactive',
            on: _dimFilter == '_inactive',
            onTap: () => setState(() => _dimFilter = _dimFilter == '_inactive' ? null : '_inactive'),
          ),
        ],
        countText: isEnglish ? 'Showing ${display.length} of ${_list.length} unit(s)' : 'แสดง ${display.length} จาก ${_list.length} รายการ',
      ),
      Expanded(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : display.isEmpty
                ? Center(child: Text(isEnglish ? 'No unit found' : 'ไม่พบหน่วยนับ', style: const TextStyle(color: ImKit.ink2)))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 10),
                    itemCount: display.length,
                    itemBuilder: (context, i) {
                      final u = display[i];
                      final used = u.baseItemCount + u.altItemCount;
                      return ImMasterListCard(
                        code: u.uomCode,
                        active: u.isActive,
                        chips: [
                          if (!u.isActive) ImKit.chip(isEnglish ? 'Inactive' : 'หยุดใช้', ImKit.redSoft, ImKit.red),
                          _dimChip(u.uomDimension, isEnglish),
                        ],
                        name: [u.uomNameTh, if ((u.uomNameEn ?? '').isNotEmpty) u.uomNameEn!].join(' · '),
                        meta: TextSpan(children: [
                          TextSpan(text: isEnglish ? 'Decimals ${u.decimalPlaces} · ' : 'ทศนิยม ${u.decimalPlaces} · '),
                          if (used == 0)
                            TextSpan(text: isEnglish ? 'not used by any item' : 'ไม่มีสินค้าใช้')
                          else ...[
                            TextSpan(text: isEnglish ? 'used by ' : 'ใช้ใน '),
                            TextSpan(text: '$used', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                            TextSpan(text: isEnglish ? ' item(s)' : ' สินค้า'),
                          ],
                        ]),
                        selected: widget.selectedId == u.id,
                        onTap: () => widget.onView(u),
                      );
                    },
                  ),
      ),
    ]);
  }
}
