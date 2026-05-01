// lib/cd/widgets/sales_territory_list_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sales_territory.dart';
import '../services/sales_territory_service.dart';

class SalesTerritoryListWidget extends StatefulWidget {
  final bool enableAddButton;
  final bool enableAddChildButton;
  final bool enableEditButton;
  final bool enableViewButton;
  final bool enableDeleteButton;
  final bool enableCardSelect;
  final void Function() onAdd;
  final void Function(SalesTerritory) onAddChild;
  final Function(SalesTerritory) onEdit;
  final Function(SalesTerritory) onView;
  final Function(SalesTerritory) onDelete;
  final void Function(SalesTerritory) onCallback;

  const SalesTerritoryListWidget({
    super.key,
    required this.enableAddButton,
    this.enableAddChildButton = false,
    required this.enableEditButton,
    required this.enableViewButton,
    required this.enableDeleteButton,
    required this.enableCardSelect,
    required this.onAdd,
    this.onAddChild = _noop,
    required this.onEdit,
    required this.onView,
    required this.onDelete,
    required this.onCallback,
  });

  static void _noop(SalesTerritory _) {}

  @override
  State<SalesTerritoryListWidget> createState() =>
      SalesTerritoryListWidgetState();

  static Future<void> search(BuildContext context,
      {required void Function(SalesTerritory) onSelected}) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: const Text('ค้นหา เขตการขาย',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Container(
          width: 520,
          height: 600,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SalesTerritoryListWidget(
            enableAddButton: false,
            enableAddChildButton: false,
            enableEditButton: false,
            enableViewButton: false,
            enableDeleteButton: false,
            enableCardSelect: true,
            onAdd: () {},
            onAddChild: (_) {},
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

class SalesTerritoryListWidgetState extends State<SalesTerritoryListWidget>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<SalesTerritory> _list = [];
  bool _isLoading = false;
  final Map<int, bool> _expandedState = {};

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
      final svc = Provider.of<SalesTerritoryService>(context, listen: false);
      final rows = await svc.fetchRows();
      setState(() {
        _list = rows;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดข้อมูลล้มเหลว: $e')),
        );
      }
    }
  }

  void refresh() => _fetch();

  // Build children list for a given parentId
  List<SalesTerritory> _childrenOf(int? parentId, List<SalesTerritory> source) {
    return source
        .where((t) => t.parentId == parentId)
        .toList()
      ..sort((a, b) {
        final bySort = a.sortOrder.compareTo(b.sortOrder);
        return bySort != 0 ? bySort : a.territoryCode.compareTo(b.territoryCode);
      });
  }

  // Check if item matches search query (used when filtering)
  bool _matchesSearch(SalesTerritory t, String q) {
    if (q.isEmpty) return true;
    final upper = q.toUpperCase();
    return t.territoryCode.toUpperCase().contains(upper) ||
        t.territoryNameThai.toUpperCase().contains(upper) ||
        (t.territoryNameEng?.toUpperCase().contains(upper) ?? false);
  }

  Widget _buildNode(SalesTerritory item, int level, List<SalesTerritory> allFiltered) {
    final children = _childrenOf(item.id, allFiltered);
    final hasChildren = children.isNotEmpty;
    final isExpanded = _expandedState[item.id] ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            if (hasChildren) {
              setState(() => _expandedState[item.id!] = !isExpanded);
            } else if (widget.enableViewButton) {
              widget.onView(item);
            }
          },
          child: Padding(
            padding: EdgeInsets.only(left: level * 16.0, top: 2, bottom: 2),
            child: Row(
              children: [
                // expand/collapse arrow
                SizedBox(
                  width: 24,
                  child: hasChildren
                      ? Icon(
                          isExpanded
                              ? Icons.arrow_drop_down
                              : Icons.arrow_right,
                          size: 20,
                        )
                      : null,
                ),
                // node icon
                Icon(
                  hasChildren
                      ? Icons.folder_outlined
                      : Icons.map_outlined,
                  size: 18,
                  color: item.isActive
                      ? (hasChildren ? Colors.amber[700] : Colors.teal[600])
                      : Colors.grey,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${item.territoryCode}  ${item.territoryNameThai}',
                    style: TextStyle(
                      fontSize: 14,
                      color: item.isActive ? null : Colors.grey,
                      fontWeight:
                          hasChildren ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // inactive chip
                if (!item.isActive)
                  const Padding(
                    padding: EdgeInsets.only(right: 2),
                    child: Chip(
                      label: Text('หยุดใช้',
                          style: TextStyle(fontSize: 10)),
                      backgroundColor: Color(0xFFEEEEEE),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                // add child button
                if (widget.enableAddChildButton)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    tooltip: 'เพิ่มเขตย่อย',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => widget.onAddChild(item),
                  ),
                // view button
                if (widget.enableViewButton)
                  IconButton(
                    icon: const Icon(Icons.visibility,
                        color: Colors.green, size: 18),
                    tooltip: 'ดู',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => widget.onView(item),
                  ),
                // edit button
                if (widget.enableEditButton)
                  IconButton(
                    icon: const Icon(Icons.edit,
                        color: Colors.blue, size: 18),
                    tooltip: 'แก้ไข',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => widget.onEdit(item),
                  ),
                // delete button
                if (widget.enableDeleteButton)
                  IconButton(
                    icon: const Icon(Icons.delete,
                        color: Colors.red, size: 18),
                    tooltip: 'ลบ',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () {
                      if (hasChildren) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'ไม่สามารถลบรายการที่มีรายการย่อยได้ กรุณาลบรายการย่อยออกก่อน'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } else {
                        widget.onDelete(item);
                      }
                    },
                  ),
                // select button (search dialog)
                if (widget.enableCardSelect)
                  IconButton(
                    icon: const Icon(Icons.arrow_right_outlined,
                        color: Colors.black, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () {
                      widget.onCallback(item);
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          ),
        ),
        if (isExpanded && hasChildren)
          Column(
            children: children
                .map((child) => _buildNode(child, level + 1, allFiltered))
                .toList(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // When searching, flatten the list to only matching items + their ancestors
    final List<SalesTerritory> displayList;
    if (_searchQuery.isEmpty) {
      displayList = _list;
    } else {
      final matchedIds = _list
          .where((t) => _matchesSearch(t, _searchQuery))
          .map((t) => t.id)
          .toSet();
      // Also include ancestors of matched items
      final includedIds = <int?>{};
      for (final t in _list) {
        if (matchedIds.contains(t.id)) {
          includedIds.add(t.id);
          // walk up ancestors
          int? pid = t.parentId;
          while (pid != null) {
            includedIds.add(pid);
            final parent = _list.where((x) => x.id == pid).firstOrNull;
            pid = parent?.parentId;
          }
        }
      }
      displayList = _list.where((t) => includedIds.contains(t.id)).toList();
    }

    final topLevel = _childrenOf(null, displayList);

    return Column(
      children: [
        // toolbar
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              if (widget.enableAddButton)
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'เพิ่มเขตหลักใหม่',
                  onPressed: widget.onAdd,
                ),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'ค้นหา (รหัส / ชื่อเขต)',
                    prefixIcon: Icon(Icons.search),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _searchQuery.isEmpty
                  ? 'ทั้งหมด ${_list.length} แถว'
                  : 'พบ ${displayList.length} จาก ${_list.length} แถว',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ),
        // tree
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : topLevel.isEmpty
                  ? const Center(child: Text('ไม่พบข้อมูลเขตการขาย'))
                  : ListView.builder(
                      itemCount: topLevel.length,
                      itemBuilder: (ctx, i) =>
                          _buildNode(topLevel[i], 0, displayList),
                    ),
        ),
      ],
    );
  }
}
