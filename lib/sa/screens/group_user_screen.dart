// // lib/screens/manage_organization_users_screen.dart

// import 'package:flutter/material.dart';
// import 'package:flutter_resizable_container/flutter_resizable_container.dart';
// import 'package:provider/provider.dart'; // อาจจะใช้ provider สำหรับ state management ถ้าต้องการ

// import '../models/group.dart';
// import '../models/app_user.dart';
// import '../services/group_service.dart';
// import '../services/group_user_service.dart';

// // Enum สำหรับโหมดการแสดงผลของ Panel ขวา
// enum UserPanelMode {
//   view,   // ดูรายชื่อผู้ใช้ที่สังกัดอยู่
//   edit,   // แก้ไข (เลือก/ไม่เลือก) รายชื่อผู้ใช้ทั้งหมด
//   empty,  // ไม่มีกลุ่มถูกเลือก
// }

// // Enum สำหรับตัวเลือกการจัดเรียง
// enum UserSortOption {
//   username,
//   firstName,
//   lastName,
// }

// class GroupUserManagementScreen extends StatefulWidget {
//   const GroupUserManagementScreen({super.key});

//   @override
//   State<GroupUserManagementScreen> createState() => _GroupUserManagementScreenState();
// }

// class _GroupUserManagementScreenState extends State<GroupUserManagementScreen> {
//   final GroupService _groupService = GroupService();
//   final GroupUserService _groupUserService = GroupUserService();

//   List<Group> _rootGroup = [];
//   Group? _selectedGroup; // กลุ่มที่เลือกใน TreeView
//   UserPanelMode _userPanelMode = UserPanelMode.empty;

//   List<AppUser> _usersInPanel = []; // ผู้ใช้ที่แสดงใน Panel ขวา (อาจเป็นสมาชิกหรือทั้งหมด)
//   bool _isLoadingPanel = false; // สถานะโหลดข้อมูลใน Panel ขวา

//   UserSortOption _currentSortOption = UserSortOption.username; // ตัวเลือกการจัดเรียงปัจจุบัน

//   @override
//   void initState() {
//     super.initState();
//     _fetchRootGroup();
//   }

//   Future<void> _fetchRootGroup() async {
//     setState(() {
//       // ไม่ต้องใช้ _isLoadingTree ทั่วไป เพราะ TreeView มี FutureBuilder ของตัวเอง
//     });
//     try {
//       _rootGroup = await _groupService.fetchRootGroup();
//       setState(() {}); // เพื่อให้ TreeView สร้างใหม่
//     } catch (e) {
//       _showSnackBar('Error loading group: $e', Colors.red);
//     }
//   }

//   Future<List<Group>> _fetchChildren(String parentId) async {
//     try {
//       return await _groupService.fetchSubGroup(parentId);
//     } catch (e) {
//       print('Error fetching children for $parentId: $e');
//       return [];
//     }
//   }

//   void _showSnackBar(String message, Color color) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(message),
//           backgroundColor: color,
//         ),
//       );
//     }
//   }

//   // --- Panel ขวา: Logic การแสดงผลและการจัดการผู้ใช้ ---

//   // ดึงข้อมูลผู้ใช้สำหรับ Panel ขวา ตามโหมดที่เลือก
//   Future<void> _fetchUserForPanel() async {
//     if (_selectedGroup == null) {
//       setState(() {
//         _userPanelMode = UserPanelMode.empty;
//         _usersInPanel = [];
//       });
//       return;
//     }

//     setState(() {
//       _isLoadingPanel = true;
//       _usersInPanel = []; // Clear current list while loading
//     });

//     try {
//       List<AppUser> fetchedUser;
//       if (_userPanelMode == UserPanelMode.edit) {
//         // โหมดแก้ไข: ดึงผู้ใช้ทั้งหมดที่เป็น active และระบุว่าใครเป็นสมาชิก
//         fetchedUser = await _groupUserService.getGroupUser(_selectedGroup!.id!);
//       } else {
//         // โหมดดู: ดึงเฉพาะผู้ใช้ที่เป็นสมาชิกของกลุ่มนี้เท่านั้น
//         fetchedUser = await _groupUserService.getMembersOfGroup(_selectedGroup!.id!);
//       }
//       _usersInPanel = fetchedUser;
//       _sortUser(); // จัดเรียงทันทีหลังจากโหลด
//     } catch (e) {
//       _showSnackBar('Failed to load users: $e', Colors.red);
//       _usersInPanel = [];
//     } finally {
//       setState(() {
//         _isLoadingPanel = false;
//       });
//     }
//   }

//   // เมื่อกด "ดู" ที่ TreeView
//   void _onViewUser(Group unit) {
//     setState(() {
//       _selectedGroup = unit;
//       _userPanelMode = UserPanelMode.view;
//     });
//     _fetchUserForPanel();
//   }

//   // เมื่อกด "แก้ไข" ที่ TreeView
//   void _onEditUser(Group unit) {
//     setState(() {
//       _selectedGroup = unit;
//       _userPanelMode = UserPanelMode.edit;
//     });
//     _fetchUserForPanel();
//   }

//   // เมื่อเปลี่ยนสถานะ CheckBox ของผู้ใช้
//   Future<void> _toggleUserMembership(AppUser user, bool? newValue) async {
//     if (_selectedGroup == null || newValue == null) return;

//     setState(() {
//       user.isMember = newValue;
//     });

//     // รวบรวม user IDs ที่ถูกเลือกทั้งหมด
//     List<String> selectedUserIds = _usersInPanel
//         .where((u) => u.isMember)
//         .map((u) => u.id)
//         .toList();

//     try {
//       await _groupUserService.updateGroupMembers(_selectedGroup!.id!, selectedUserIds);
//       _showSnackBar('สมาชิกกลุ่มอัปเดตแล้ว', Colors.green);

//       // ถ้าผู้ใช้ถูกยกเลิกการเลือก ให้ลบสิทธิ์เมนูด้วย
//       if (!newValue) {
//         await _groupUserService.copyGroupMenuToUser(_selectedGroup!.id!, user.id); // คัดลอกสิทธิ์ (ซึ่งในกรณีนี้คือการลบสิทธิ์เฉพาะผู้ใช้นั้นออก)
//          _showSnackBar('สิทธิ์ผู้ใช้ ${user.username} ถูกอัปเดต (ลบสิทธิ์ถ้าไม่เป็นสมาชิกแล้ว)', Colors.blue);
//       } else {
//         // หากเลือกผู้ใช้เป็นสมาชิกใหม่ หรือเลือกผู้ใช้เดิมอีกครั้ง
//         // ให้คัดลอกสิทธิ์จาก organization_menu ไปทับสิทธิ์ผู้ใช้
//         await _groupUserService.copyGroupMenuToUser(_selectedGroup!.id!, user.id);
//         _showSnackBar('สิทธิ์ผู้ใช้ ${user.username} ถูกคัดลอกจากกลุ่มแล้ว', Colors.blue);
//       }
//     } catch (e) {
//       // Rollback UI change if API fails
//       setState(() {
//         user.isMember = !newValue;
//       });
//       _showSnackBar('Failed to update membership: $e', Colors.red);
//     }
//   }


//   // ลบผู้ใช้ทั้งหมดจากกลุ่ม
//   Future<void> _onDeleteAllUserFromGroup(Group unit) async {
//     final bool? confirm = await showDialog<bool>(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text('ยืนยันการลบผู้ใช้ทั้งหมด'),
//           content: Text('คุณแน่ใจหรือไม่ที่ต้องการลบผู้ใช้ทั้งหมดออกจากกลุ่ม "${unit.name}"?'),
//           actions: <Widget>[
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(false),
//               child: const Text('ยกเลิก'),
//             ),
//             ElevatedButton(
//               onPressed: () => Navigator.of(context).pop(true),
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
//               child: const Text('ลบทั้งหมด'),
//             ),
//           ],
//         );
//       },
//     );

//     if (confirm == true) {
//       try {
//         await _groupUserService.deleteAllUserFromGroup(unit.id!);
//         _showSnackBar('ลบผู้ใช้ทั้งหมดจากกลุ่ม ${unit.name} เรียบร้อยแล้ว', Colors.green);
//         if (_selectedGroup?.id == unit.id) {
//           // ถ้าเป็นกลุ่มที่กำลังแสดงอยู่ ให้รีเฟรช panel
//           _fetchUserForPanel();
//         }
//       } catch (e) {
//         _showSnackBar('Failed to delete all users from organization: $e', Colors.red);
//       }
//     }
//   }

//   // คัดลอกสิทธิ์เมนูจากกลุ่มไปยังผู้ใช้ (ปุ่ม "คัดลอกสิทธิ์")
//   Future<void> _onCopyPermissionsToUser(AppUser user) async {
//     if (_selectedGroup == null) {
//       _showSnackBar('กรุณาเลือกกลุ่มก่อน', Colors.orange);
//       return;
//     }
//     final bool? confirm = await showDialog<bool>(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text('คัดลอกสิทธิ์เมนู'),
//           content: Text('คุณต้องการคัดลอกสิทธิ์เมนูของกลุ่ม "${_selectedGroup!.name}" ไปทับสิทธิ์ปัจจุบันของ "${user.username}" หรือไม่?'),
//           actions: <Widget>[
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(false),
//               child: const Text('ยกเลิก'),
//             ),
//             ElevatedButton(
//               onPressed: () => Navigator.of(context).pop(true),
//               child: const Text('คัดลอก'),
//             ),
//           ],
//         );
//       },
//     );

//     if (confirm == true) {
//       try {
//         await _groupUserService.copyGroupPermissionsToUser(_selectedGroup!.id!, user.id);
//         _showSnackBar('สิทธิ์เมนูถูกคัดลอกไปยังผู้ใช้ ${user.username} เรียบร้อยแล้ว', Colors.green);
//       } catch (e) {
//         _showSnackBar('Failed to copy permissions: $e', Colors.red);
//       }
//     }
//   }

//   // จัดเรียงผู้ใช้
//   void _sortUser() {
//     _usersInPanel.sort((a, b) {
//       switch (_currentSortOption) {
//         case UserSortOption.username:
//           return a.username.compareTo(b.username);
//         case UserSortOption.firstName:
//           return a.firstName.compareTo(b.firstName);
//         case UserSortOption.lastName:
//           return a.lastName.compareTo(b.lastName);
//       }
//     });
//     setState(() {}); // บังคับให้ UI อัปเดต
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () => Navigator.of(context).pop(),
//         ),
//         title: const Text('จัดการผู้ใช้ของกลุ่ม', style: TextStyle(color: Colors.white)),
//         backgroundColor: Colors.deepOrange[900],
//       ),
//       body: ResizableContainer(
//         direction: Axis.horizontal,
//         dividerColor: Colors.blueGrey[200], // สีของ divider
//         dividerThickness: 5.0, // ความหนาของ divider
//         children: [
//           // Panel ซ้าย: TreeView ของกลุ่ม
//           ResizableChild(
//             size: const ResizableSize.flex(0.4),
//             child: Container(
//               color: Colors.grey[100],
//               child: Column(
//                 children: [
//                   Padding(
//                     padding: const EdgeInsets.all(8.0),
//                     child: Text(
//                       'โครงสร้างกลุ่ม',
//                       style: Theme.of(context).textTheme.titleLarge,
//                     ),
//                   ),
//                   Expanded(
//                     child: _rootGroup.isEmpty
//                         ? const Center(child: Text('ไม่มีกลุ่ม'))
//                         : ListView.builder(
//                             itemCount: _rootGroup.length,
//                             itemBuilder: (context, index) {
//                               final unit = _rootGroup[index];
//                               return _buildOrgUnitNode(unit);
//                             },
//                           ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           // Panel ขวา: รายชื่อผู้ใช้ของกลุ่มที่เลือก
//           ResizableChild(
//             size: const ResizableSize.flex(0.6),
//             child: Column(
//               children: [
//                 // ส่วนหัว Panel ขวา
//                 AppBar(
//                   automaticallyImplyLeading: false, // ไม่ต้องมีปุ่ม Back
//                   backgroundColor: Colors.blue.shade700,
//                   foregroundColor: Colors.white,
//                   title: Text(
//                     _selectedGroup == null
//                         ? 'เลือกกลุ่มเพื่อจัดการผู้ใช้'
//                         : 'ผู้ใช้ของ: ${_selectedGroup!.name}',
//                     style: const TextStyle(fontSize: 18),
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                   actions: [
//                     if (_selectedGroup != null && _userPanelMode == UserPanelMode.edit)
//                       PopupMenuButton<UserSortOption>(
//                         icon: const Icon(Icons.sort),
//                         onSelected: (UserSortOption result) {
//                           setState(() {
//                             _currentSortOption = result;
//                           });
//                           _sortUser();
//                         },
//                         itemBuilder: (BuildContext context) => <PopupMenuEntry<UserSortOption>>[
//                           const PopupMenuItem<UserSortOption>(
//                             value: UserSortOption.username,
//                             child: Text('เรียงตาม Username'),
//                           ),
//                           const PopupMenuItem<UserSortOption>(
//                             value: UserSortOption.firstName,
//                             child: Text('เรียงตามชื่อจริง'),
//                           ),
//                           const PopupMenuItem<UserSortOption>(
//                             value: UserSortOption.lastName,
//                             child: Text('เรียงตามนามสกุล'),
//                           ),
//                         ],
//                       ),
//                   ],
//                 ),
//                 // Body Panel ขวา
//                 Expanded(
//                   child: _isLoadingPanel
//                       ? const Center(child: CircularProgressIndicator())
//                       : _selectedGroup == null
//                           ? const Center(child: Text('กรุณาเลือกกลุ่มจาก Panel ซ้าย'))
//                           : _usersInPanel.isEmpty
//                               ? const Center(child: Text('ไม่พบผู้ใช้ในกลุ่มนี้'))
//                               : ListView.builder(
//                                   itemCount: _usersInPanel.length,
//                                   itemBuilder: (context, index) {
//                                     final user = _usersInPanel[index];
//                                     return Card(
//                                       margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
//                                       elevation: 1,
//                                       child: ListTile(
//                                         leading: _userPanelMode == UserPanelMode.edit
//                                             ? Checkbox(
//                                                 value: user.isMember,
//                                                 onChanged: (newValue) => _toggleUserMembership(user, newValue),
//                                               )
//                                             : null,
//                                         title: Text('${user.firstName} ${user.lastName} (${user.username})'),
//                                         subtitle: Text(user.email),
//                                         trailing: _userPanelMode == UserPanelMode.edit
//                                             ? IconButton(
//                                                 icon: const Icon(Icons.copy_all, color: Colors.indigo),
//                                                 tooltip: 'คัดลอกสิทธิ์จากกลุ่ม',
//                                                 onPressed: () => _onCopyPermissionsToUser(user),
//                                               )
//                                             : null,
//                                       ),
//                                     );
//                                   },
//                                 ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // Widget สำหรับสร้าง Node ของกลุ่มใน TreeView
//   Widget _buildOrgUnitNode(Group unit) {
//     return FutureBuilder<List<Group>>(
//       future: _fetchChildren(unit.id!), // โหลดลูกของกลุ่มนี้
//       builder: (context, snapshot) {
//         List<Widget> childrenWidgets = [];
//         if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
//           if (snapshot.data!.isNotEmpty) {
//             childrenWidgets = snapshot.data!.map((child) => _buildOrgUnitNode(child)).toList();
//           }
//         } else if (snapshot.connectionState == ConnectionState.waiting) {
//           childrenWidgets.add(const Padding(
//             padding: EdgeInsets.only(left: 20.0, top: 8.0, bottom: 8.0),
//             child: CircularProgressIndicator(strokeWidth: 2),
//           ));
//         }

//         return Card(
//           margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
//           color: _selectedGroup?.id == unit.id ? Colors.blue.shade100 : Colors.white,
//           child: Column(
//             children: [
//               ListTile(
//                 contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0),
//                 title: Text(unit.name, style: const TextStyle(fontWeight: FontWeight.bold)),
//                 subtitle: Text('ID: ${unit.id?.substring(0, 8)}...'), // แสดง ID สั้นๆ
//                 trailing: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     IconButton(
//                       icon: const Icon(Icons.visibility, color: Colors.green),
//                       tooltip: 'ดูผู้ใช้',
//                       onPressed: () => _onViewUser(unit),
//                     ),
//                     IconButton(
//                       icon: const Icon(Icons.edit, color: Colors.blue),
//                       tooltip: 'แก้ไขผู้ใช้',
//                       onPressed: () => _onEditUser(unit),
//                     ),
//                     IconButton(
//                       icon: const Icon(Icons.delete_forever, color: Colors.red),
//                       tooltip: 'ลบผู้ใช้ทั้งหมดจากกลุ่ม',
//                       onPressed: () => _onDeleteAllUserFromGroup(unit),
//                     ),
//                   ],
//                 ),
//                 onTap: () => _onViewUser(unit), // แตะที่ Node เพื่อ "ดู" เป็นค่าเริ่มต้น
//               ),
//               if (childrenWidgets.isNotEmpty)
//                 Padding(
//                   padding: const EdgeInsets.only(left: 20.0),
//                   child: Column(children: childrenWidgets),
//                 ),
//             ],
//           ),
//         );
//       },
//     );
//   }
// }