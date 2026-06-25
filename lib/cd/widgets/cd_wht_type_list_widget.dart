// lib/cd/widgets/cd_wht_type_list_widget.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/cd_wht_type.dart';
import '../services/cd_wht_type_service.dart';

class CdWhtTypeListWidget extends StatefulWidget {
  final bool enableAddButton;
  final bool enableEditButton;
  final bool enableViewButton;
  final bool enableDeleteButton;
  final bool enableCardSelect;
  final VoidCallback onAdd;
  final Function(CdWhtType) onEdit;
  final Function(CdWhtType) onView;
  final Function(CdWhtType) onDelete;
  final Function(CdWhtType) onCallback;

  const CdWhtTypeListWidget({
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
  State<CdWhtTypeListWidget> createState() => CdWhtTypeListWidgetState();

  /// Dialog picker — ใช้เลือก WHT type ใน form อื่น
  static Future<void> search(BuildContext context,
      {required void Function(CdWhtType) onSelected}) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: const Text('เลือก ประเภทภาษีหัก ณ ที่จ่าย',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Container(
          width: 560,
          height: 600,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: CdWhtTypeListWidget(
            enableAddButton: false,
            enableEditButton: false,
            enableViewButton: false,
            enableDeleteButton: false,
            enableCardSelect: true,
            onAdd: () {},
            onEdit: (_) {},
            onView: (_) {},
            onDelete: (_) {},
            onCallback: (row) {
              Navigator.of(context).pop();
              onSelected(row);
            },
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

class CdWhtTypeListWidgetState extends State<CdWhtTypeListWidget>
    with AutomaticKeepAliveClientMixin {
  static final _dateFmt = DateFormat('dd/MM/yyyy');
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'code_asc';
  List<CdWhtType> _rows = [];
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchRows();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchRows() async {
    setState(() => _isLoading = true);
    try {
      final svc = Provider.of<CdWhtTypeService>(context, listen: false);
      final rows = await svc.fetchRows();
      setState(() {
        _rows = rows;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('โหลดข้อมูลไม่สำเร็จ: $e')));
      }
    }
  }

  void refresh() => _fetchRows();

  void _onSortSelected(String v) => setState(() => _sortBy = v);

  List<CdWhtType> get _filtered {
    List<CdWhtType> items = List.from(_rows);
    if (widget.enableCardSelect) items = items.where((e) => e.isActive).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items.where((r) =>
        r.whtCode.toLowerCase().contains(q) ||
        r.whtName.toLowerCase().contains(q) ||
        (r.incomeType?.toLowerCase().contains(q) ?? false)
      ).toList();
    }
    switch (_sortBy) {
      case 'code_asc': items.sort((a, b) => a.whtCode.compareTo(b.whtCode)); break;
      case 'code_desc': items.sort((a, b) => b.whtCode.compareTo(a.whtCode)); break;
      case 'name_asc': items.sort((a, b) => a.whtName.compareTo(b.whtName)); break;
      case 'name_desc': items.sort((a, b) => b.whtName.compareTo(a.whtName)); break;
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final rows = _filtered;
    final countText = _searchQuery.isEmpty
        ? 'ทั้งหมด ${_rows.length} แถว'
        : 'พบ ${rows.length} จาก ${_rows.length} แถว';

    return Column(
      children: [
        // Search bar + add button
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            if (widget.enableAddButton)
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'เพิ่มประเภท WHT ใหม่',
                onPressed: widget.onAdd,
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              tooltip: 'จัดเรียง',
              onSelected: _onSortSelected,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'code_asc', child: Text('รหัส (น้อยไปมาก)')),
                PopupMenuItem(value: 'code_desc', child: Text('รหัส (มากไปน้อย)')),
                PopupMenuItem(value: 'name_asc', child: Text('ชื่อ (น้อยไปมาก)')),
                PopupMenuItem(value: 'name_desc', child: Text('ชื่อ (มากไปน้อย)')),
              ],
            ),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  hintText: 'ค้นหา (รหัส / ชื่อ / ประเภทเงินได้)',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
          ]),
        ),
        // Count label
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(countText,
                style: const TextStyle(fontSize: 12, color: Colors.black87)),
          ),
        ),
        // Card list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : rows.isEmpty
                  ? const Center(child: Text('ไม่พบข้อมูลประเภทภาษีหัก ณ ที่จ่าย'))
                  : ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (ctx, i) {
                        final row = rows[i];
                        // อัตราสำหรับ CircleAvatar — ตัดเศษ .00 ออก
                        final rateLabel =
                            '${row.whtRate % 1 == 0 ? row.whtRate.toInt() : row.whtRate}%';
                        // subtitle: ชื่อ + อัตรา + ประเภทเงินได้ + วันที่ + บัญชี GL
                        final dateRange = row.effectiveDate != null
                            ? '${_dateFmt.format(row.effectiveDate!)} – '
                              '${row.endDate != null ? _dateFmt.format(row.endDate!) : 'ปัจจุบัน'}'
                            : null;
                        final subtitleParts = [
                          row.whtName,
                          'อัตรา ${row.whtRate.toStringAsFixed(row.whtRate % 1 == 0 ? 0 : 2)}%',
                          if (row.incomeType != null) 'มาตรา ${row.incomeType}',
                          if (dateRange != null) dateRange,
                          if (row.glAccountCode != null) row.glAccountCode!,
                        ];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Stack(children: [
                          ListTile(
                            // leading: อัตราภาษีใน CircleAvatar
                            leading: CircleAvatar(
                              backgroundColor: row.isActive
                                  ? Colors.orange.shade100
                                  : Colors.grey.shade200,
                              child: Text(
                                rateLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: row.isActive
                                      ? Colors.orange.shade800
                                      : Colors.grey,
                                ),
                              ),
                            ),
                            // title (บรรทัดบน): รหัส WHT
                            title: Text(
                              row.whtCode,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: row.isActive ? null : Colors.grey,
                              ),
                            ),
                            // subtitle (บรรทัดล่าง): ชื่อ  •  อัตรา%  •  มาตรา
                            subtitle: Text(
                              subtitleParts.join('  •  '),
                              style: TextStyle(
                                color: row.isActive
                                    ? Colors.grey.shade700
                                    : Colors.grey,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.enableViewButton)
                                  IconButton(
                                    icon: const Icon(Icons.visibility,
                                        color: Colors.green),
                                    onPressed: () => widget.onView(row),
                                  ),
                                if (widget.enableEditButton)
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue),
                                    onPressed: () => widget.onEdit(row),
                                  ),
                                if (widget.enableDeleteButton)
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => widget.onDelete(row),
                                  ),
                                if (widget.enableCardSelect)
                                  IconButton(
                                    icon: const Icon(
                                        Icons.arrow_right_outlined),
                                    onPressed: () => widget.onCallback(row),
                                  ),
                              ],
                            ),
                            onTap: widget.enableCardSelect
                                ? () => widget.onCallback(row)
                                : null,
                          ),
                          if (!row.isActive)
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
                    ),
        ),
      ],
    );
  }
}
