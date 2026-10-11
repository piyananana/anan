import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../models/mo_bom.dart';
import '../services/mo_bom_service.dart';

class MoBomListWidget extends StatefulWidget {
  final bool enableAddButton;
  final bool enableEditButton;
  final bool enableViewButton;
  final bool enableDeleteButton;
  final bool enableCardSelect;
  final void Function() onAdd;
  final Function(MoBomHeader) onEdit;
  final Function(MoBomHeader) onView;
  final Function(MoBomHeader) onDelete;
  final void Function(MoBomHeader) onCallback;

  const MoBomListWidget({
    super.key,
    required this.enableAddButton,
    required this.enableEditButton,
    required this.enableViewButton,
    required this.enableDeleteButton,
    this.enableCardSelect = false,
    required this.onAdd,
    required this.onEdit,
    required this.onView,
    required this.onDelete,
    required this.onCallback,
  });

  @override
  State<MoBomListWidget> createState() => MoBomListWidgetState();

  // ใช้เป็น picker ตอนเลือกสูตรการผลิตในหน้าจอใบสั่งผลิต (mo_header) — เฉพาะสูตรที่ active อยู่เท่านั้น
  static Future<void> search(BuildContext context, {required void Function(MoBomHeader) onSelected}) {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: Text(isEnglish ? 'Search BOM' : 'ค้นหาสูตรการผลิต', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Container(
          width: 480,
          height: 560,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
          child: MoBomListWidget(
            enableAddButton: false,
            enableEditButton: false,
            enableViewButton: false,
            enableDeleteButton: false,
            enableCardSelect: true,
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

class MoBomListWidgetState extends State<MoBomListWidget> with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  List<MoBomHeader> _list = [];
  bool _isLoading = false;
  final _svc = MoBomService();

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

  String _itemName(MoBomHeader h, bool isEnglish) =>
      isEnglish && (h.parentItemNameEn ?? '').isNotEmpty ? h.parentItemNameEn! : (h.parentItemNameTh ?? '');

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final q = _searchQuery.trim().toUpperCase();
    final display = q.isEmpty
        ? _list
        : _list.where((h) => (h.parentItemCode ?? '').toUpperCase().contains(q) || _itemName(h, isEnglish).toUpperCase().contains(q)).toList();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          if (widget.enableAddButton)
            IconButton(icon: const Icon(Icons.add), tooltip: isEnglish ? 'Add new BOM' : 'เพิ่มสูตรการผลิตใหม่', onPressed: widget.onAdd),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: isEnglish ? 'Search (item code / name)' : 'ค้นหา (รหัส / ชื่อสินค้า)',
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
                ? Center(child: Text(isEnglish ? 'No BOM data found' : 'ไม่พบข้อมูลสูตรการผลิต'))
                : ListView.builder(
                    itemCount: display.length,
                    itemBuilder: (context, index) {
                      final item = display[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: item.isActive ? Colors.teal.shade100 : Colors.grey.shade200,
                            child: Icon(Icons.precision_manufacturing, color: item.isActive ? Colors.teal.shade700 : Colors.grey, size: 20),
                          ),
                          title: Text(
                            '${item.parentItemCode}  ${_itemName(item, isEnglish)}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: item.isActive ? null : Colors.grey),
                          ),
                          subtitle: Text(
                            isEnglish
                                ? 'Version ${item.bomVersion} · ${item.componentCount} components'
                                : 'เวอร์ชัน ${item.bomVersion} · ${item.componentCount} ส่วนประกอบ',
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
                                        SnackBar(content: Text(isEnglish ? 'Cannot use: this BOM is inactive' : 'ไม่สามารถใช้ได้ เนื่องจากสูตรนี้หยุดใช้งาน'), backgroundColor: Colors.red),
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
}
