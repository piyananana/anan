// lib/cd/widgets/cd_bank_list_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cd_bank.dart';
import '../models/cd_bank_branch.dart';
import '../services/cd_bank_service.dart';
import '../services/cd_bank_branch_service.dart';

class BankListWidget extends StatefulWidget {
  final bool enableAddButton;
  final bool enableEditButton;
  final bool enableViewButton;
  final bool enableDeleteButton;
  final bool enableSortButton;
  final bool enableCardSelect;
  final void Function() onAdd;
  final Function(Bank) onEdit;
  final Function(Bank) onView;
  final Function(Bank) onDelete;
  final void Function(Bank) onCallback;

  const BankListWidget({
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
  State<BankListWidget> createState() => BankListWidgetState();

  /// Dialog สำหรับเลือกธนาคาร
  static Future<void> search(BuildContext context,
      {required void Function(Bank) onSelected}) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: const Text('ค้นหา ธนาคาร',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Container(
          width: 520,
          height: 580,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: BankListWidget(
            enableAddButton: false,
            enableEditButton: false,
            enableViewButton: false,
            enableDeleteButton: false,
            enableSortButton: false,
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

  /// Dialog สำหรับเลือกสาขาธนาคาร (กรองตาม bankId ถ้าระบุ)
  static Future<void> searchBranch(BuildContext context,
      {int? bankId, required void Function(BankBranch) onSelected}) {
    return showDialog(
      context: context,
      builder: (context) => _BankBranchSearchDialog(
        bankId: bankId,
        onSelected: onSelected,
      ),
    );
  }
}

class BankListWidgetState extends State<BankListWidget>
    with AutomaticKeepAliveClientMixin {
  String _sortBy = 'code_asc';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Bank> _lists = [];
  bool _isLoading = false;

  List<Bank> _filterAndSort() {
    List<Bank> display = List.from(_lists);
    if (widget.enableCardSelect) display = display.where((e) => e.isActive).toList();
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toUpperCase();
      display = display.where((row) {
        return row.bankCode.toUpperCase().contains(query) ||
            row.bankNameThai.toUpperCase().contains(query) ||
            row.bankNameEng.toUpperCase().contains(query) ||
            (row.shortName ?? '').toUpperCase().contains(query);
      }).toList();
    }
    display.sort((a, b) {
      switch (_sortBy) {
        case 'code_asc':
          return a.bankCode.compareTo(b.bankCode);
        case 'code_desc':
          return b.bankCode.compareTo(a.bankCode);
        case 'name_asc':
          return a.bankNameThai.compareTo(b.bankNameThai);
        case 'name_desc':
          return b.bankNameThai.compareTo(a.bankNameThai);
        default:
          return 0;
      }
    });
    return display;
  }

  Future<void> _fetchLists() async {
    setState(() => _isLoading = true);
    try {
      final service = Provider.of<BankService>(context, listen: false);
      final fetched = await service.fetchRows();
      setState(() {
        _lists = fetched;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ไม่สามารถโหลดข้อมูลได้: $e')));
      }
    }
  }

  void refresh() => _fetchLists();

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

  @override
  bool get wantKeepAlive => true;

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          if (widget.enableAddButton)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'เพิ่มข้อมูลใหม่',
              onPressed: widget.onAdd,
            ),
          if (widget.enableSortButton)
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              tooltip: 'จัดเรียง',
              onSelected: (value) => setState(() => _sortBy = value),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'code_asc', child: Text('รหัส (น้อยไปมาก)')),
                PopupMenuItem(value: 'code_desc', child: Text('รหัส (มากไปน้อย)')),
                PopupMenuItem(value: 'name_asc', child: Text('ชื่อ (ก-ฮ)')),
                PopupMenuItem(value: 'name_desc', child: Text('ชื่อ (ฮ-ก)')),
              ],
            ),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'ค้นหา (รหัส / ชื่อธนาคาร)',
                prefixIcon: Icon(Icons.search),
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final displayList = _filterAndSort();
    final countText = _searchQuery.isEmpty
        ? 'ทั้งหมด ${_lists.length} แถว'
        : 'พบ ${displayList.length} จาก ${_lists.length} แถว';

    return Column(
      children: [
        _buildListHeader(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(countText,
                style: const TextStyle(fontSize: 12, color: Colors.black87)),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : displayList.isEmpty
                  ? const Center(child: Text('ไม่พบข้อมูลธนาคาร'))
                  : ListView.builder(
                      itemCount: displayList.length,
                      itemBuilder: (context, index) {
                        final item = displayList[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8.0, vertical: 4.0),
                          child: Stack(children: [
                          ListTile(
                            leading: item.shortName != null
                                ? CircleAvatar(
                                    backgroundColor: Colors.blue.shade100,
                                    child: Text(item.shortName!,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                  )
                                : null,
                            title: Text(
                              '${item.bankCode} — ${item.bankNameThai}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: item.isActive ? null : Colors.grey,
                              ),
                            ),
                            subtitle: item.bankNameEng.isNotEmpty
                                ? Text(item.bankNameEng)
                                : null,
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
                    ),
        ),
      ],
    );
  }
}

// =================== Branch Search Dialog ===================

class _BankBranchSearchDialog extends StatefulWidget {
  final int? bankId;
  final void Function(BankBranch) onSelected;

  const _BankBranchSearchDialog({this.bankId, required this.onSelected});

  @override
  State<_BankBranchSearchDialog> createState() =>
      _BankBranchSearchDialogState();
}

class _BankBranchSearchDialogState extends State<_BankBranchSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<BankBranch> _branches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBranches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchBranches() async {
    try {
      final service = Provider.of<BankBranchService>(context, listen: false);
      final fetched = await service.fetchRows(bankId: widget.bankId);
      setState(() {
        _branches = fetched;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<BankBranch> get _filtered {
    if (_searchQuery.isEmpty) return _branches;
    final q = _searchQuery.toUpperCase();
    return _branches.where((b) {
      return b.branchName.toUpperCase().contains(q) ||
          (b.branchCode ?? '').toUpperCase().contains(q) ||
          (b.bankNameThai ?? '').toUpperCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      title: Text(
        widget.bankId != null ? 'ค้นหา สาขาธนาคาร' : 'ค้นหา สาขาธนาคาร (ทั้งหมด)',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 520,
        height: 520,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'ค้นหา (รหัสสาขา / ชื่อสาขา)',
                  prefixIcon: Icon(Icons.search),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : list.isEmpty
                      ? const Center(child: Text('ไม่พบข้อมูลสาขา'))
                      : ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (context, index) {
                            final item = list[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 8.0, vertical: 2.0),
                              child: ListTile(
                                title: Text(
                                  item.branchName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  [
                                    if (item.branchCode != null)
                                      'รหัส: ${item.branchCode}',
                                    if (item.bankDisplay.isNotEmpty)
                                      item.bankDisplay,
                                  ].join('  '),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                      Icons.arrow_right_outlined,
                                      color: Colors.black),
                                  onPressed: () {
                                    widget.onSelected(item);
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ปิด', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}
