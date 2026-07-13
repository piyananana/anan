// import 'package:flutter/material.dart';
// import '../models/sa_menu.dart';
// import '../screens/menu_management_screen.dart';
// import '../screens/sa_user_screen.dart';
// import '../screens/sa_user_menu_screen.dart';
// import '../screens/sa_company_profile_screen.dart';
// import '../screens/sa_group_management_screen.dart';
// import '../screens/sa_group_menu_management_screen.dart';
// import '../screens/sa_group_user_management_screen.dart';
// import '../screens/organization_management_screen.dart';

// class DynamicContentDisplay extends StatelessWidget {
//   final MenuContent? menuContent;
//   final String? directTargetPath;
//   final VoidCallback? onExit;

//   const DynamicContentDisplay({
//     super.key,
//     this.menuContent,
//     this.directTargetPath,
//     this.onExit,
//   });

//   Widget _buildContentWidget(BuildContext context) {
// // Import All Your Custom Widgets Here
// // --- Strategy 1: Using a Map to Map String to Widget Builders ---
// // This strategy requires you to manually map each widget.
// // For 1000 widgets, this will be a very large file.
// // Consider generating this map from a script or using a more advanced
// // plugin/package for dynamic widget loading if available.
//     final Map<String, Widget Function(BuildContext context)> widgetBuilders = {
//       'MenuManagementScreen': (context) => MenuManagementScreen(
//             onMenusChanged: () {},
//             onExit: onExit,
//           ),
//       'UserManagementScreen': (context) => UserManagementScreen(
//             onExit: onExit, // onExit ที่ส่งมาจาก HomeScreen
//           ),
//       'UserMenuScreen': (context) => UserMenuScreen(
//             onExit: onExit,
//           ),
//       'CompanyProfileScreen': (context) => CompanyProfileScreen(
//             onExit: onExit, // onExit ที่ส่งมาจาก HomeScreen
//           ),
//       'GroupManagementScreen': (context) => GroupManagementScreen(
//             onExit: onExit, // onExit ที่ส่งมาจาก HomeScreen
//           ),
//       'GroupMenuManagementScreen': (context) => GroupMenuManagementScreen(
//             onExit: onExit, // onExit ที่ส่งมาจาก HomeScreen
//           ),
//       'GroupUserManagementScreen': (context) => GroupUserManagementScreen(
//             onExit: onExit, // onExit ที่ส่งมาจาก HomeScreen
//           ),
//       'OrganizationManagementScreen': (context) => OrganizationManagementScreen(
//             onExit: onExit, // onExit ที่ส่งมาจาก HomeScreen
//           ),
//       'HomePage': (context) => const Text('This is the Home Page content!'),
//       'ProductListScreen': (context) => const Text('List of Products!'),
//       'UserProfileView': (context) => const Text('User Profile Details!'),
//       // Add all your custom widgets here
//       // 'YourCustomWidget1': (context) => const YourCustomWidget1(),
//       // 'YourCustomWidget2': (context) => const YourCustomWidget2(),
//     };

//     if (menuContent != null) {
//       switch (menuContent!.contentType) {
//         case 'widget':
//           if (directTargetPath != null) {
//             // Handle direct search input before checking menuContent
//             if (widgetBuilders.containsKey(directTargetPath)) {
//               return widgetBuilders[directTargetPath]!(context);
//             }
//             return Center(
//                 child: Text(
//                     'ไม่พบวิดเจ็ต "$directTargetPath" หรือไม่สามารถโหลดได้'));
//           } else {
//             final widgetName = menuContent!.contentData;
//             if (widgetName != null && widgetBuilders.containsKey(widgetName)) {
//               return widgetBuilders[widgetName]!(context);
//             }
//             return Center(
//                 child: Text('ไม่พบวิดเจ็ต "$widgetName" หรือไม่สามารถโหลดได้'));
//           }
//         case 'html':
//           // You would use a package like flutter_html to render HTML
//           // return Html(data: menuContent!.contentData ?? '');
//           return SingleChildScrollView(
//               child: Text('HTML Content: ${menuContent!.contentData ?? ''}'));
//         case 'markdown':
//           // You would use a package like flutter_markdown
//           // return Markdown(data: menuContent!.contentData ?? '');
//           return SingleChildScrollView(
//               child:
//                   Text('Markdown Content: ${menuContent!.contentData ?? ''}'));
//         case 'url':
//           // You could open a webview or use a package like url_launcher
//           // to open in external browser
//           return Center(
//               child: Text(
//                   'URL: ${menuContent!.contentData ?? ''} (คลิกเพื่อเปิด)'));
//         default:  // ใช้ลอจิกเดียวกับ 'widget' เพื่อจัดการกับเส้นทางที่ตรง
//           // return const Center(child: Text('ไม่พบประเภทเนื้อหาที่ต้องการ'));
//           if (directTargetPath != null) {
//             // Handle direct search input before checking menuContent
//             if (widgetBuilders.containsKey(directTargetPath)) {
//               return widgetBuilders[directTargetPath]!(context);
//             }
//             return Center(
//                 child: Text(
//                     'ไม่พบวิดเจ็ต "$directTargetPath" หรือไม่สามารถโหลดได้'));
//           } else {
//             final widgetName = menuContent!.contentData;
//             if (widgetName != null && widgetBuilders.containsKey(widgetName)) {
//               return widgetBuilders[widgetName]!(context);
//             }
//             return Center(
//                 child: Text('ไม่พบวิดเจ็ต "$widgetName" หรือไม่สามารถโหลดได้'));
//           }
//       }
//     } else if (directTargetPath != null) {
//       // Handle direct search input
//       if (widgetBuilders.containsKey(directTargetPath)) {
//         return widgetBuilders[directTargetPath]!(context);
//       }
//       return Center(
//           child: Text('ไม่พบวิดเจ็ต "$directTargetPath" หรือไม่สามารถโหลดได้'));
//     }
//     return const Center(
//         child: Text('ไม่พบรายการเมนูที่เลือก หรือไม่สามารถโหลดได้'));
//   }

//   @override
//   Widget build(BuildContext context) {
//     // เมื่อ directTargetPath เป็น null
//     // และ menuContent เป็น null
//     // จะเข้ามาที่เงื่อนไขนี้
//     if (menuContent == null && directTargetPath == null) {
//       // <-- เพิ่มเช็ค directTargetPath ด้วย
//       return const Center(
//           child:
//               Text('เลือกเมนูการทำงาน หรือใส่ชื่อ/รหัส/เส้นทางเมนูที่ต้องการ'));
//     }

//     return Container(
//       padding: const EdgeInsets.all(10.0),
//       child: _buildContentWidget(context),
//     );
//   }
// }
