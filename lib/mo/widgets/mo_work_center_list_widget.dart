// lib/mo/widgets/mo_work_center_list_widget.dart — มิเรอร์ im_price_group_list_widget.dart ทุกประการ
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../models/mo_work_center.dart';
import '../services/mo_work_center_service.dart';

class MoWorkCenterListWidget extends StatefulWidget {
  final bool enableAddButton;
  final bool enableEditButton;
  final bool enableViewButton;
  final bool enableDeleteButton;
  final bool enableCardSelect;
  final void Function() onAdd;
  final Function(MoWorkCenter) onEdit;
  final Function(MoWorkCenter) onView;
  final Function(MoWorkCenter) onDelete;
  final void Function(MoWorkCenter) onCallback;

  const MoWorkCenterListWidget({
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
  State<MoWorkCenterListWidget> createState() => MoWorkCenterListWidgetState();

  // ใช้เป็น picker ตอนเลือกศูนย์งานในขั้นตอนการผลิต (Routing) ของ mo_bom/mo_header
  static Future<void> search(BuildContext context, {required void Function(MoWorkCenter) onSelected}) {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: Text(isEnglish ? 'Search Work Center' : 'ค้นหาศูนย์งาน', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Container(
          width: 420,
          height: 520,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
          child: MoWorkCenterListWidget(
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

class MoWorkCenterListWidgetState extends State<MoWorkCenterListWidget> with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  List<MoWorkCenter> _list = [];
  bool _isLoading = false;
  final _svc = MoWorkCenterService();

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

  String _wcName(MoWorkCenter item, bool isEnglish) =>
      isEnglish && (item.workCenterNameEn ?? '').isNotEmpty ? item.workCenterNameEn! : item.workCenterNameTh;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final q = _searchQuery.trim().toUpperCase();
    final display = q.isEmpty
        ? _list
        : _list.where((w) => w.workCenterCode.toUpperCase().contains(q) || w.workCenterNameTh.toUpperCase().contains(q) || (w.workCenterNameEn ?? '').toUpperCase().contains(q)).toList();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          if (widget.enableAddButton)
            IconButton(icon: const Icon(Icons.add), tooltip: isEnglish ? 'Add new work center' : 'เพิ่มศูนย์งานใหม่', onPressed: widget.onAdd),
          Expanded(
            child: TextField(
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
                ? Center(child: Text(isEnglish ? 'No work center data found' : 'ไม่พบข้อมูลศูนย์งาน'))
                : ListView.builder(
                    itemCount: display.length,
                    itemBuilder: (context, index) {
                      final item = display[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: item.isActive ? Colors.teal.shade100 : Colors.grey.shade200,
                            child: Icon(Icons.factory_outlined, color: item.isActive ? Colors.teal.shade700 : Colors.grey, size: 20),
                          ),
                          title: Text(
                            '${item.workCenterCode}  ${_wcName(item, isEnglish)}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: item.isActive ? null : Colors.grey),
                          ),
                          subtitle: Text(
                            isEnglish
                                ? 'Labor ${item.laborRatePerHour}/hr · Machine ${item.machineRatePerHour}/hr · OH ${item.overheadRatePerHour}/hr'
                                : 'ค่าแรง ${item.laborRatePerHour}/ชม. · ค่าเครื่องจักร ${item.machineRatePerHour}/ชม. · OH ${item.overheadRatePerHour}/ชม.',
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
                                        SnackBar(content: Text(isEnglish ? 'Cannot use: this work center is inactive' : 'ไม่สามารถใช้ได้ เนื่องจากศูนย์งานนี้หยุดใช้งาน'), backgroundColor: Colors.red),
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
