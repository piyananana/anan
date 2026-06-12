import 'package:flutter/material.dart';
import '../models/ap_vendor.dart';
import '../services/ap_vendor_service.dart';

class ApVendorListWidget extends StatefulWidget {
  final bool enableAddButton;
  final bool enableEditButton;
  final bool enableViewButton;
  final bool enableDeleteButton;
  final void Function() onAdd;
  final Function(ApVendor) onEdit;
  final Function(ApVendor) onView;
  final Function(ApVendor) onDelete;
  final void Function(ApVendor) onCallback;

  const ApVendorListWidget({
    super.key,
    required this.enableAddButton,
    required this.enableEditButton,
    required this.enableViewButton,
    required this.enableDeleteButton,
    required this.onAdd,
    required this.onEdit,
    required this.onView,
    required this.onDelete,
    required this.onCallback,
  });

  @override
  State<ApVendorListWidget> createState() => ApVendorListWidgetState();
}

class ApVendorListWidgetState extends State<ApVendorListWidget>
    with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'code_asc';
  List<ApVendor> _list = [];
  int _totalCount = 0;
  bool _isLoading = false;
  final _svc = ApVendorService();

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
    setState(() { _isLoading = true; });
    try {
      final rows = await _svc.fetchRows(search: _searchQuery.isEmpty ? null : _searchQuery);
      if (mounted) setState(() {
        _list = rows;
        if (_searchQuery.isEmpty) _totalCount = rows.length;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  void refresh() => _fetchList();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final display = List<ApVendor>.from(_list);
    switch (_sortBy) {
      case 'code_asc':  display.sort((a, b) => a.vendorCode.compareTo(b.vendorCode)); break;
      case 'code_desc': display.sort((a, b) => b.vendorCode.compareTo(a.vendorCode)); break;
      case 'name_asc':  display.sort((a, b) => a.vendorNameTh.compareTo(b.vendorNameTh)); break;
      case 'name_desc': display.sort((a, b) => b.vendorNameTh.compareTo(a.vendorNameTh)); break;
    }

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          if (widget.enableAddButton)
            IconButton(icon: const Icon(Icons.add), tooltip: 'เพิ่มเจ้าหนี้ใหม่', onPressed: widget.onAdd),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'จัดเรียง',
            onSelected: (v) => setState(() => _sortBy = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'code_asc',  child: Text('รหัส (น้อยไปมาก)')),
              PopupMenuItem(value: 'code_desc', child: Text('รหัส (มากไปน้อย)')),
              PopupMenuItem(value: 'name_asc',  child: Text('ชื่อ (น้อยไปมาก)')),
              PopupMenuItem(value: 'name_desc', child: Text('ชื่อ (มากไปน้อย)')),
            ],
          ),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'ค้นหา (รหัส / ชื่อ / เลขผู้เสียภาษี)',
                prefixIcon: Icon(Icons.search),
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
                border: OutlineInputBorder(),
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
                ? 'ทั้งหมด $_totalCount แถว'
                : 'พบ ${_list.length} จาก $_totalCount แถว',
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
      ),
      Expanded(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : display.isEmpty
                ? const Center(child: Text('ไม่พบข้อมูลเจ้าหนี้'))
                : ListView.builder(
                    itemCount: display.length,
                    itemBuilder: (context, index) {
                      final item = display[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: item.isActive
                                ? Colors.blue.shade100
                                : Colors.grey.shade200,
                            child: Icon(
                              Icons.business,
                              color: item.isActive ? Colors.blue.shade700 : Colors.grey,
                            ),
                          ),
                          title: Text(
                            '${item.vendorCode}  ${item.vendorNameTh}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: item.isActive ? null : Colors.grey,
                            ),
                          ),
                          subtitle: Text(
                            '${item.businessTypeNameThai ?? ''}'
                            '${item.businessTypeNameThai != null ? '  •  ' : ''}'
                            'เครดิต ${item.creditTermMonths > 0 ? '${item.creditTermMonths} เดือน ' : ''}${item.creditTermDays} วัน'
                            '${item.taxId != null ? '\nเลขผู้เสียภาษี: ${item.taxId}' : ''}',
                            maxLines: 2,
                          ),
                          isThreeLine: item.taxId != null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.enableViewButton)
                                IconButton(
                                  icon: const Icon(Icons.visibility, size: 18),
                                  tooltip: 'ดูข้อมูล',
                                  onPressed: () => widget.onView(item),
                                ),
                              if (widget.enableEditButton)
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  tooltip: 'แก้ไข',
                                  onPressed: () => widget.onEdit(item),
                                ),
                              if (widget.enableDeleteButton)
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                  tooltip: 'ลบ',
                                  onPressed: () => widget.onDelete(item),
                                ),
                            ],
                          ),
                          onTap: () => widget.onCallback(item),
                        ),
                      );
                    },
                  ),
      ),
    ]);
  }
}
