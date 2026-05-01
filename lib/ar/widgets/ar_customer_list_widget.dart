import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ar_customer.dart';
import '../services/ar_customer_service.dart';

class ArCustomerListWidget extends StatefulWidget {
  final bool enableAddButton;
  final bool enableEditButton;
  final bool enableViewButton;
  final bool enableDeleteButton;
  final bool enableCardSelect;
  final void Function() onAdd;
  final Function(ArCustomer) onEdit;
  final Function(ArCustomer) onView;
  final Function(ArCustomer) onDelete;
  final void Function(ArCustomer) onCallback;

  const ArCustomerListWidget({
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
  State<ArCustomerListWidget> createState() => ArCustomerListWidgetState();
}

class ArCustomerListWidgetState extends State<ArCustomerListWidget>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<ArCustomer> _lists = [];
  int _totalCount = 0;
  bool _isLoading = false;
  String _error = '';

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
      final svc = Provider.of<ArCustomerService>(context, listen: false);
      final fetched = await svc.fetchRows(search: _searchQuery.isEmpty ? null : _searchQuery);
      setState(() {
        _lists = fetched;
        if (_searchQuery.isEmpty) _totalCount = fetched.length;
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


  Widget _buildHeader() {
    return Container(
      color: Colors.blueGrey[50],
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          if (widget.enableAddButton)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'เพิ่มลูกหนี้ใหม่',
              onPressed: widget.onAdd,
            ),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'ค้นหา (รหัส / รหัสเก่า / ชื่อ)',
                prefixIcon: Icon(Icons.search),
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                setState(() => _searchQuery = v);
                _fetchLists();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRowCount() {
    final text = _searchQuery.isEmpty
        ? 'ทั้งหมด $_totalCount แถว'
        : 'พบ ${_lists.length} จาก $_totalCount แถว';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _buildHeader(),
        _buildRowCount(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _lists.isEmpty
                  ? const Center(child: Text('ไม่พบข้อมูลลูกหนี้'))
                  : ListView.builder(
                      itemCount: _lists.length,
                      itemBuilder: (context, index) {
                        final item = _lists[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8.0, vertical: 4.0),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: item.isActive
                                  ? Colors.orange.shade100
                                  : Colors.grey.shade200,
                              child: Icon(
                                Icons.person,
                                color: item.isActive
                                    ? Colors.orange.shade700
                                    : Colors.grey,
                              ),
                            ),
                            title: Text(
                              '${item.customerCode}  ${item.customerNameTh}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: item.isActive ? null : Colors.grey,
                              ),
                            ),
                            subtitle: Text(
                              '${item.businessTypeNameThai ?? ''}${item.businessTypeNameThai != null ? '  •  ' : ''}'
                              'เครดิต ${item.creditTermMonths > 0 ? '${item.creditTermMonths} เดือน ' : ''}${item.creditTermDays} วัน'
                              '${item.customerGroupCode != null ? '  •  กลุ่ม: ${item.customerGroupCode}' : ''}'
                              '${item.customerNameEn != null ? '\n${item.customerNameEn}' : ''}',
                            ),
                            isThreeLine: item.customerNameEn != null,
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
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
