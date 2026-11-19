// widgets/cd_zipcode_list_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/gl_account.dart';
import '../services/gl_account_service.dart';
import '../../sa/services/sa_language_provider.dart';

class AccountListTreeWidget extends StatefulWidget {
  final bool enableAddRootButton;
  final bool enableAddChildButton;
  final bool enableEditButton;
  final bool enableViewButton;
  final bool enableDeleteButton;
  final bool enableCardSelect;
  final bool showInactive;
  final void Function() onAddRoot;
  final void Function(Account) onAddChild;
  final Function(Account) onEdit;
  final Function(Account) onView;
  final Function(Account) onDelete;
  final void Function(Account) onCallback;

  const AccountListTreeWidget({
    super.key,
    required this.enableAddRootButton,
    required this.enableAddChildButton,
    required this.enableEditButton,
    required this.enableViewButton,
    required this.enableDeleteButton,
    required this.enableCardSelect,
    this.showInactive = false,
    required this.onAddRoot,
    required this.onAddChild,
    required this.onEdit,
    required this.onView,
    required this.onDelete,
    required this.onCallback,
  });

  @override
  State<AccountListTreeWidget> createState() => AccountListTreeWidgetState();

  // เมธอด static สำหรับแสดง Dialog
  static Future<void> search(BuildContext context,
      {required void Function(Account) onSelected}) {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          title: Text(isEnglish ? 'Search Chart of Accounts' : 'ค้นหา ผังบัญชี',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Container(
            width: 500,
            height: 600,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: AccountListTreeWidget(
              enableAddRootButton: false,
              enableAddChildButton: false,
              enableEditButton: false,
              enableViewButton: false,
              enableDeleteButton: false,
              enableCardSelect: true,
              onAddRoot: () {},
              onAddChild: (account) {},
              onEdit: (account) {},
              onView: (account) {},
              onDelete: (account) {},
              onCallback: onSelected,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(isEnglish ? 'Close' : 'ปิด', style: const TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

class AccountListTreeWidgetState extends State<AccountListTreeWidget>
    with AutomaticKeepAliveClientMixin {
  List<Account> _lists = [];
  bool _isLoading = false;
  final Map<int, bool> _expandedState = {};

  // ค้นหารหัส/ชื่อบัญชี (ไทย/อังกฤษ): แสดงเฉพาะบัญชีที่ตรง + โหนดแม่ทุกชั้น (แตกออกให้อัตโนมัติ) + บัญชีย่อยของหัวบัญชีที่ตรง
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  Set<int> _matchedIds = {};
  Set<int>? _visibleIds; // null = แสดงทั้งหมด (ไม่ได้ค้นหา)
  Map<int, bool>? _expandedBeforeSearch; // สถานะแตก/หุบก่อนค้นหา — คืนให้เมื่อล้างคำค้น

  bool _matches(Account a, String q) =>
      a.accountCode.toLowerCase().contains(q) ||
      a.accountNameThai.toLowerCase().contains(q) ||
      a.accountNameEng.toLowerCase().contains(q);

  void _onSearchChanged(String raw) {
    final q = raw.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        if (_expandedBeforeSearch != null) {
          _expandedState
            ..clear()
            ..addAll(_expandedBeforeSearch!);
          _expandedBeforeSearch = null;
        }
        _query = '';
        _matchedIds = {};
        _visibleIds = null;
        return;
      }
      _expandedBeforeSearch ??= Map.of(_expandedState);
      _query = q;
      _recomputeSearch();
    });
  }

  void _recomputeSearch() {
    if (_query.isEmpty) return;
    final byId = {for (final a in _lists) a.id: a};
    final childrenOf = <int?, List<int>>{};
    for (final a in _lists) {
      childrenOf.putIfAbsent(a.parentId, () => []).add(a.id);
    }
    _matchedIds = _lists.where((a) => _matches(a, _query)).map((a) => a.id).toSet();
    final visible = <int>{..._matchedIds};
    for (final id in _matchedIds) {
      // โหนดแม่ทุกชั้นของบัญชีที่ตรง: แสดงและแตกออก
      var p = byId[id]?.parentId;
      final seen = <int>{};
      while (p != null && byId.containsKey(p) && seen.add(p)) {
        visible.add(p);
        _expandedState[p] = true;
        p = byId[p]!.parentId;
      }
      // บัญชีย่อยของหัวบัญชีที่ตรง: แสดงได้ (หุบไว้ตามเดิม)
      final stack = [...?childrenOf[id]];
      while (stack.isNotEmpty) {
        final c = stack.removeLast();
        if (visible.add(c)) stack.addAll(childrenOf[c] ?? const []);
      }
    }
    _visibleIds = visible;
  }

  Future<void> _fetchLists() async {
    setState(() => _isLoading = true);
    try {
      final dataService = Provider.of<AccountService>(context, listen: false);
      final fetched = widget.showInactive
          ? await dataService.fetchAllRows()
          : await dataService.fetchRows();
      setState(() {
        _lists = fetched;
        _isLoading = false;
        _recomputeSearch();
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEnglish
              ? 'Failed to load data: ${e.toString()}'
              : 'ไม่สามารถโหลดข้อมูลได้: ${e.toString()}')),
        );
      }
    }
  }

  void refresh() {
    _fetchLists();
  }

  @override
  void initState() {
    super.initState();
    _fetchLists();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Widget _buildListHeader(bool isEnglish) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            autofocus: ModalRoute.of(context) is PopupRoute,
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              isDense: true,
              hintText: isEnglish ? 'Search account code / name' : 'ค้นหารหัส/ชื่อบัญชี',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: isEnglish ? 'Clear' : 'ล้าง',
                      onPressed: () {
                        _searchCtrl.clear();
                        _onSearchChanged('');
                      },
                    ),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          if (_query.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                isEnglish ? 'Found ${_matchedIds.length} account(s)' : 'พบ ${_matchedIds.length} บัญชี',
                style: TextStyle(fontSize: 12, color: _matchedIds.isEmpty ? Colors.red : Colors.black54),
              ),
            ),
          if (widget.enableAddRootButton) ...[
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => widget.onAddRoot(),
              icon: const Icon(Icons.add),
              label: Text(isEnglish ? 'Add Root Account' : 'เพิ่มหมวดหลัก'),
            ),
          ],
        ],
      ),
    );
  }

  List<Account> _buildTree(List<Account> lists, int? parentId) {
    final visible = _visibleIds;
    return lists
        .where((list) => list.parentId == parentId && (visible == null || visible.contains(list.id)))
        .toList()
      ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
  }

  // --- Build Methods ---
  Widget _buildNode(Account item, int level, bool isEnglish) {
    final bool isHeader   = item.isNormalAccount == false;
    final bool isInactive = !item.isActive;
    final List<Account> children = _buildTree(_lists, item.id);
    final bool hasChildren = children.isNotEmpty;
    final bool isExpanded  = _expandedState[item.id] ?? false;

    // สี/ความชัดตามสถานะ
    final Color textColor   = isInactive ? Colors.grey.shade400 : Colors.black87;
    final Color actionColor = isInactive ? Colors.grey.shade400 : Colors.blue;
    final Color deleteColor = isInactive ? Colors.grey.shade400 : Colors.red;

    // Icon แสดงประเภทบัญชี — inactive ใช้ Icons.block แทน
    final IconData typeIcon = isInactive
        ? Icons.block                // แสดงว่าหยุดใช้งาน
        : (isHeader
            ? Icons.summarize_outlined
            : Icons.list_outlined);
    final Color typeIconColor = isInactive ? Colors.grey.shade400 : Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            if (isHeader && hasChildren) {
              setState(() {
                _expandedState[item.id] = !isExpanded;
              });
            } else if (widget.enableViewButton) {
              widget.onView(item);
            }
          },
          child: Padding(
            padding: EdgeInsets.only(left: level * 16.0),
            child: Row(
              children: [
                if (isHeader && hasChildren)
                  Icon(isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                      color: textColor),
                if (!isHeader || !hasChildren) const SizedBox(width: 24),
                Icon(typeIcon, color: typeIconColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isEnglish && item.accountNameEng.isNotEmpty
                        ? '${item.accountCode} ${item.accountNameEng}'
                        : '${item.accountCode} ${item.accountNameThai}',
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor,
                      fontStyle: isInactive ? FontStyle.italic : FontStyle.normal,
                      // บัญชีที่ตรงกับคำค้น: ตัวหนา + พื้นเหลือง
                      fontWeight: _matchedIds.contains(item.id) ? FontWeight.bold : null,
                      backgroundColor: _matchedIds.contains(item.id) ? Colors.yellow.shade200 : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Icon ปุ่ม Add สำหรับ Header
                if (isHeader && widget.enableAddChildButton)
                  IconButton(
                    icon: Icon(Icons.add_circle_outline,
                        size: 20, color: actionColor),
                    tooltip: isEnglish ? 'Add child' : 'เพิ่มรายการย่อย',
                    onPressed: () => widget.onAddChild(item),
                  ),
                // Icon ปุ่ม Edit
                widget.enableEditButton
                    ? IconButton(
                        icon: Icon(Icons.edit, color: actionColor, size: 20),
                        tooltip: isEnglish ? 'Edit' : 'แก้ไข',
                        onPressed: () => widget.onEdit(item),
                      )
                    : const SizedBox.shrink(),
                // Icon ปุ่ม Delete — เฉพาะบัญชีที่ยังไม่มีธุรกรรมและไม่มีบัญชีย่อย
                widget.enableDeleteButton && !item.hasTransactions && !hasChildren
                    ? IconButton(
                        icon: Icon(Icons.delete, size: 20, color: deleteColor),
                        tooltip: isEnglish ? 'Delete (no transactions yet)' : 'ลบ (ยังไม่มีธุรกรรม)',
                        onPressed: () => widget.onDelete(item),
                      )
                    : const SizedBox.shrink(),
                // Icon ปุ่ม search
                widget.enableCardSelect
                    ? IconButton(
                        icon: const Icon(Icons.arrow_right_outlined,
                            color: Colors.black),
                        onPressed: () {
                          if (item.isActive && item.isNormalAccount) {
                            widget.onCallback(item);
                            Navigator.of(context).pop();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(isEnglish
                                      ? 'Cannot use: this is a header account or inactive'
                                      : 'ไม่สามารถใช้ได้ เนื่องจากเป็นหัวบัญชี หรือ หยุดใช้'),
                                  backgroundColor: Colors.red),
                            );
                          }
                        },
                      )
                    : const SizedBox.shrink(),
              ],
            ),
          ),
        ),
        if (isExpanded && hasChildren)
          Column(
            children:
                children.map((child) => _buildNode(child, level + 1, isEnglish)).toList(),
          ),
      ],
    );
  }

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;

    final List<Account> topLevelLists = _buildTree(_lists, null);

    return Column(
      children: [
        _buildListHeader(isEnglish),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: topLevelLists.length,
                  itemBuilder: (context, index) {
                    return _buildNode(topLevelLists[index], 0, isEnglish);
                  },
                ),
          // ListView.builder(
          //     itemCount: _searchResult.length,
          //     itemBuilder: (context, index) {
          //       final item = _searchResult[index];
          //       return Card(
          //         margin: const EdgeInsets.symmetric(
          //             horizontal: 8.0, vertical: 4.0),
          //         child: ListTile(
          //           // leading: Text('${(index + 1).toString()}.'),
          //           // // CircleAvatar(
          //           // //   child: Text((index + 1).toString()),
          //           // // ),
          //           // // title: Text(item.item),
          //           title: Text(
          //               '${item.subDistrict} ${item.district} ${item.province} ${item.zipcode}'),
          //           // subtitle: Text(
          //           //     '${item.subDistrict} ${item.district} ${item.province}'),
          //           // isThreeLine: true,
          //           trailing: Row(
          //             mainAxisSize: MainAxisSize.min,
          //             children: [
          //               widget.enableViewButton
          //                   ? IconButton(
          //                       icon: const Icon(Icons.visibility,
          //                           color: Colors.green),
          //                       onPressed: () => widget.onView(item),
          //                     )
          //                   : const SizedBox.shrink(),
          //               widget.enableEditButton
          //                   ? IconButton(
          //                       icon: const Icon(Icons.edit,
          //                           color: Colors.blue),
          //                       onPressed: () => widget.onEdit(item),
          //                     )
          //                   : const SizedBox.shrink(),
          //               widget.enableDeleteButton
          //                   ? IconButton(
          //                       icon: const Icon(Icons.delete,
          //                           color: Colors.red),
          //                       onPressed: () => widget.onDelete(item),
          //                     )
          //                   : const SizedBox.shrink(),
          //               widget.enableCardSelect
          //                   ? IconButton(
          //                       icon: const Icon(Icons.arrow_right_outlined,
          //                           color: Colors.black),
          //                       onPressed: () {
          //                         widget.onCallback(item);
          //                         Navigator.of(context).pop();
          //                       },
          //                     )
          //                   : const SizedBox.shrink(),
          //             ],
          //           ),
          //         ),
          //       );
          //     },
          //   ),
        ),
      ],
    );
  }
}
