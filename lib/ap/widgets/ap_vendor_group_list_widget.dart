// lib/ap/widgets/ap_vendor_group_list_widget.dart
import 'package:flutter/material.dart';
import '../models/ap_vendor_group.dart';
import '../services/ap_vendor_group_service.dart';

class ApVendorGroupListWidget extends StatefulWidget {
  final bool enableAddButton;
  final bool enableEditButton;
  final bool enableViewButton;
  final bool enableDeleteButton;
  final bool enableSortButton;
  final bool enableCardSelect;
  final void Function() onAdd;
  final void Function(ApVendorGroup) onEdit;
  final void Function(ApVendorGroup) onView;
  final void Function(ApVendorGroup) onDelete;
  final void Function(ApVendorGroup) onCallback;

  const ApVendorGroupListWidget({
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
  State<ApVendorGroupListWidget> createState() => ApVendorGroupListWidgetState();

  static Future<void> search(BuildContext context, {required void Function(ApVendorGroup) onSelected}) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: const Text('ค้นหา กลุ่มผู้ขาย', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Container(
          width: 520,
          height: 600,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
          child: ApVendorGroupListWidget(
            enableAddButton: false, enableEditButton: false,
            enableViewButton: false, enableDeleteButton: false,
            enableSortButton: false, enableCardSelect: true,
            onAdd: () {}, onEdit: (_) {}, onView: (_) {}, onDelete: (_) {},
            onCallback: onSelected,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('ปิด', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

class ApVendorGroupListWidgetState extends State<ApVendorGroupListWidget>
    with AutomaticKeepAliveClientMixin {
  String _sortBy = 'code_asc';
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  List<ApVendorGroup> _list = [];
  bool _isLoading = false;

  List<ApVendorGroup> _filtered() {
    var display = List<ApVendorGroup>.from(_list);
    if (widget.enableCardSelect) display = display.where((e) => e.isActive).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toUpperCase();
      display = display.where((g) =>
        g.groupCode.toUpperCase().contains(q) ||
        g.groupNameThai.toUpperCase().contains(q) ||
        g.groupNameEng.toUpperCase().contains(q)).toList();
    }
    display.sort((a, b) {
      switch (_sortBy) {
        case 'code_desc': return b.groupCode.compareTo(a.groupCode);
        case 'name_asc':  return a.groupNameThai.compareTo(b.groupNameThai);
        case 'name_desc': return b.groupNameThai.compareTo(a.groupNameThai);
        default:          return a.groupCode.compareTo(b.groupCode);
      }
    });
    return display;
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final rows = await ApVendorGroupService().fetchRows();
      if (mounted) setState(() { _list = rows; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void refresh() => _fetch();

  @override
  void initState() { super.initState(); _fetch(); }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final display = _filtered();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          if (widget.enableAddButton)
            IconButton(icon: const Icon(Icons.add), tooltip: 'เพิ่มใหม่', onPressed: widget.onAdd),
          if (widget.enableSortButton)
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              tooltip: 'จัดเรียง',
              onSelected: (v) => setState(() => _sortBy = v),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'code_asc',  child: Text('รหัส (น้อยไปมาก)')),
                PopupMenuItem(value: 'code_desc', child: Text('รหัส (มากไปน้อย)')),
                PopupMenuItem(value: 'name_asc',  child: Text('ชื่อ (ก-ฮ)')),
                PopupMenuItem(value: 'name_desc', child: Text('ชื่อ (ฮ-ก)')),
              ],
            ),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'ค้นหา (รหัส / ชื่อกลุ่มผู้ขาย)',
                prefixIcon: Icon(Icons.search),
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _searchQuery.isEmpty ? 'ทั้งหมด ${_list.length} แถว' : 'พบ ${display.length} จาก ${_list.length} แถว',
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
      ),
      Expanded(child: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : display.isEmpty
          ? const Center(child: Text('ไม่พบข้อมูลกลุ่มผู้ขาย'))
          : ListView.builder(
              itemCount: display.length,
              itemBuilder: (ctx, i) {
                final item = display[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Stack(children: [
                  ListTile(
                    title: Text('${item.groupCode} — ${item.groupNameThai}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: item.isActive ? null : Colors.grey)),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (item.groupNameEng.isNotEmpty)
                        Text(item.groupNameEng, style: const TextStyle(fontSize: 12)),
                      Text(
                        'เครดิต ${item.creditTermMonths > 0 ? '${item.creditTermMonths} เดือน ' : ''}${item.creditTermDays} วัน  |  ${item.currencyCode}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ]),
                    isThreeLine: item.groupNameEng.isNotEmpty,
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (!item.isActive)
                        Padding(padding: const EdgeInsets.only(right: 4),
                          child: Chip(label: const Text('หยุดใช้', style: TextStyle(fontSize: 11)), backgroundColor: Colors.grey.shade200)),
                      if (widget.enableViewButton)
                        IconButton(icon: const Icon(Icons.visibility, color: Colors.green), onPressed: () => widget.onView(item)),
                      if (widget.enableEditButton)
                        IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => widget.onEdit(item)),
                      if (widget.enableDeleteButton)
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => widget.onDelete(item)),
                      if (widget.enableCardSelect)
                        IconButton(
                          icon: const Icon(Icons.arrow_right_outlined, color: Colors.black),
                          onPressed: () { widget.onCallback(item); Navigator.of(ctx).pop(); },
                        ),
                    ]),
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
            )),
    ]);
  }
}
