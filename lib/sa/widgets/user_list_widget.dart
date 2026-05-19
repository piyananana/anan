import 'package:flutter/material.dart';
import '../models/user.dart';

class UserListPanel extends StatefulWidget {
  final List<User> users;
  final bool enableAddButton;
  final bool enableSortButton;
  final VoidCallback onAdd;
  final Function(User) onEdit;
  final Function(User) onView;
  final Function(User) onDelete;

  const UserListPanel({
    super.key,
    required this.users,
    required this.enableAddButton,
    required this.enableSortButton,
    required this.onAdd,
    required this.onEdit,
    required this.onView,
    required this.onDelete,
  });

  @override
  State<UserListPanel> createState() => _UserListPanelState();
}

class _UserListPanelState extends State<UserListPanel> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'userName_asc';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<User> _filterAndSort() {
    List<User> items = List.from(widget.users);
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items.where((u) {
        return u.userName.toLowerCase().contains(q) ||
            (u.firstName?.toLowerCase().contains(q) ?? false) ||
            (u.lastName?.toLowerCase().contains(q) ?? false) ||
            u.status.toLowerCase().contains(q) ||
            u.userType.toLowerCase().contains(q) ||
            (u.email?.toLowerCase().contains(q) ?? false);
      }).toList();
    }
    switch (_sortBy) {
      case 'userName_asc':
        items.sort((a, b) => a.userName.compareTo(b.userName));
        break;
      case 'userName_desc':
        items.sort((a, b) => b.userName.compareTo(a.userName));
        break;
      case 'name_asc':
        items.sort((a, b) => '${a.firstName}${a.lastName}'.compareTo('${b.firstName}${b.lastName}'));
        break;
      case 'name_desc':
        items.sort((a, b) => '${b.firstName}${b.lastName}'.compareTo('${a.firstName}${a.lastName}'));
        break;
    }
    return items;
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          if (widget.enableAddButton)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'เพิ่มผู้ใช้ใหม่',
              onPressed: widget.onAdd,
            ),
          if (widget.enableSortButton)
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              tooltip: 'จัดเรียง',
              onSelected: (v) => setState(() => _sortBy = v),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'userName_asc', child: Text('Username (น้อยไปมาก)')),
                PopupMenuItem(value: 'userName_desc', child: Text('Username (มากไปน้อย)')),
                PopupMenuItem(value: 'name_asc', child: Text('ชื่อ (น้อยไปมาก)')),
                PopupMenuItem(value: 'name_desc', child: Text('ชื่อ (มากไปน้อย)')),
              ],
            ),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'ค้นหา (รหัสผู้ใช้, ชื่อ, นามสกุล, ประเภทผู้ใช้)',
                prefixIcon: Icon(Icons.search),
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filterAndSort();
    final countText = _searchQuery.isEmpty
        ? 'ทั้งหมด ${widget.users.length} แถว'
        : 'พบ ${items.length} จาก ${widget.users.length} แถว';

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
          child: items.isEmpty
              ? const Center(child: Text('ไม่พบผู้ใช้'))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final user = items[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 4.0),
                      child: ListTile(
                        title: Text(
                            '${user.firstName} ${user.lastName} (${user.userName})'),
                        subtitle: Text(
                            'อีเมล: ${user.email ?? '(ไม่มี)'}\nสถานะ: ${user.status}, ประเภท: ${user.userType}'),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility,
                                  color: Colors.green),
                              onPressed: () => widget.onView(user),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => widget.onEdit(user),
                            ),
                            IconButton(
                              icon:
                                  const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => widget.onDelete(user),
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
