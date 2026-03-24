// lib/ar/widgets/ar_collector_list_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ar_collector.dart';
import '../services/ar_collector_service.dart';

class ArCollectorListWidget extends StatefulWidget {
  final bool enableAddButton;
  final bool enableEditButton;
  final bool enableViewButton;
  final bool enableDeleteButton;
  final bool enableCardSelect;
  final void Function() onAdd;
  final Function(ArCollector) onEdit;
  final Function(ArCollector) onView;
  final Function(ArCollector) onDelete;
  final void Function(ArCollector) onCallback;

  const ArCollectorListWidget({
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
  State<ArCollectorListWidget> createState() => ArCollectorListWidgetState();

  static Future<void> search(BuildContext context,
      {required void Function(ArCollector) onSelected}) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: const Text('ค้นหา ผู้วางบิล/รับชำระ',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Container(
          width: 520,
          height: 600,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: ArCollectorListWidget(
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
            child: const Text('ปิด', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class ArCollectorListWidgetState extends State<ArCollectorListWidget>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<ArCollector> _list = [];
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final svc = Provider.of<ArCollectorService>(context, listen: false);
      final rows = await svc.fetchRows(
          search: _searchQuery.isEmpty ? null : _searchQuery);
      setState(() {
        _list = rows;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('โหลดข้อมูลล้มเหลว: $e')));
      }
    }
  }

  void refresh() => _fetch();

  List<ArCollector> get _filtered {
    if (_searchQuery.isEmpty) return _list;
    final q = _searchQuery.toUpperCase();
    return _list.where((c) {
      return c.collectorCode.toUpperCase().contains(q) ||
          c.collectorNameThai.toUpperCase().contains(q) ||
          (c.collectorNameEng?.toUpperCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final display = _filtered;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              if (widget.enableAddButton)
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'เพิ่มข้อมูลใหม่',
                  onPressed: widget.onAdd,
                ),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'ค้นหา (รหัส / ชื่อ)',
                    prefixIcon: Icon(Icons.search),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                  onSubmitted: (_) => _fetch(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : display.isEmpty
                  ? const Center(child: Text('ไม่พบข้อมูลผู้วางบิล/รับชำระ'))
                  : ListView.builder(
                      itemCount: display.length,
                      itemBuilder: (ctx, i) {
                        final item = display[i];
                        final typeLabel =
                            arCollectorTypeOptions[item.collectorType] ??
                                item.collectorType;
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: ListTile(
                            title: Text(
                              '${item.collectorCode} — ${item.collectorNameThai}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: item.isActive ? null : Colors.grey,
                              ),
                            ),
                            subtitle: Text(typeLabel,
                                style: const TextStyle(fontSize: 12)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!item.isActive)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Chip(
                                      label: Text('หยุดใช้',
                                          style: TextStyle(fontSize: 11)),
                                      backgroundColor: Color(0xFFEEEEEE),
                                    ),
                                  ),
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
