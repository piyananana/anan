// widgets/user_list_panel.dart
import 'package:flutter/material.dart';
import '../models/user.dart';

enum UserSortBy {
  userName,
  firstName,
  lastName,
  status,
  userType
} // <-- เพิ่ม userType

class UserListPanel extends StatefulWidget {
  final List<User> users;
  final Function(User) onViewPermissions; // <-- เพิ่ม Callback
  final Function(User) onEditPermissions; // <-- เปลี่ยนชื่อ Callback
  final Function(User) onDeletePermissions; // <-- เปลี่ยนชื่อ Callback
  final Function(User) onEdit;
  final Function(User) onView;
  final Function(User) onDelete;
  final TextEditingController searchController;
  final UserSortBy sortBy;
  final String searchQuery;

  const UserListPanel({
    super.key,
    required this.users,
    required this.onViewPermissions, // <-- รับเข้ามา
    required this.onEditPermissions, // <-- รับเข้ามา
    required this.onDeletePermissions, // <-- รับเข้ามา
    required this.onEdit,
    required this.onView,
    required this.onDelete,
    required this.searchController,
    required this.sortBy,
    required this.searchQuery,
  });

  @override
  State<UserListPanel> createState() => _UserListPanelState();
}

class _UserListPanelState extends State<UserListPanel> {
  List<User> _getFilteredAndSortedUsers() {
    List<User> displayUsers = List.from(widget.users);

    // 1. Filter
    if (widget.searchQuery.isNotEmpty) {
      final query = widget.searchQuery.toLowerCase();
      displayUsers = displayUsers.where((user) {
        return user.userName.toLowerCase().contains(query) ||
            user.firstName!.toLowerCase().contains(query) ||
            user.lastName!.toLowerCase().contains(query) ||
            user.status.toLowerCase().contains(query) ||
            user.userType.toLowerCase().contains(query) ||
            user.email!.toLowerCase().contains(query);
      }).toList();
    }

    // 2. Sort
    displayUsers.sort((a, b) {
      switch (widget.sortBy) {
        case UserSortBy.userName:
          return a.userName.compareTo(b.userName);
        case UserSortBy.firstName:
          return a.firstName!.compareTo(b.firstName!);
        case UserSortBy.lastName:
          return a.lastName!.compareTo(b.lastName!);
        case UserSortBy.status:
          return a.status.compareTo(b.status);
        case UserSortBy.userType: // <-- เพิ่มการจัดเรียงตาม userType
          return a.userType.compareTo(b.userType);
      }
    });

    return displayUsers;
  }

  @override
  Widget build(BuildContext context) {
    final filteredAndSortedUsers = _getFilteredAndSortedUsers();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: widget.searchController,
            decoration: const InputDecoration(
              hintText:
                  'คำค้นใน รหัสผู้ใช้, ชื่อ, นามสกุล, ประเภทผู้ใช้...', // <-- อัปเดต hintText
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
            ),
          ),
        ),
        Expanded(
          child: filteredAndSortedUsers.isEmpty
              ? const Center(child: Text('ไม่พบผู้ใช้'))
              : ListView.builder(
                  itemCount: filteredAndSortedUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredAndSortedUsers[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 4.0),
                      child: ListTile(
                        title: Text(
                            '${user.firstName} ${user.lastName} (${user.userName})'),
                        subtitle: Text(
                            'อีเมล: ${user.email ?? '(ไม่มี)'}\nสถานะ: ${user.status}, ประเภท: ${user.userType}'), // <-- แสดง User Type
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility, color: Colors.green), // <-- ปุ่ม View
                              // onPressed: () => widget.onViewPermissions(user),
                              onPressed: () => widget.onView(user),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => widget.onEdit(user),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
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
