import 'package:flutter/material.dart';
import '../models/menu.dart';

class MenuTreeView extends StatefulWidget {
  final List<Menu> menus;
  final ValueChanged<Menu> onMenuSelected;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onRefreshMenus; // เพิ่ม callback สำหรับ refresh
  final TextEditingController searchController; // <-- เพิ่มตรงนี้

  const MenuTreeView({
    super.key,
    required this.menus,
    required this.onMenuSelected,
    required this.onSearchSubmitted,
    required this.onRefreshMenus,
    required this.searchController,
  });

  @override
  MenuTreeViewState createState() => MenuTreeViewState();
}

class MenuTreeViewState extends State<MenuTreeView>
    with AutomaticKeepAliveClientMixin {
  final Map<int, bool> _expandedState = {}; // เก็บสถานะการขยายของแต่ละโหนด
  // final TextEditingController _searchController = TextEditingController();

  List<Menu> _buildTree(List<Menu> menus, int? parentId) {
    return menus.where((menu) => menu.parentId == parentId).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  Widget _buildMenuNode(Menu menu, List<Menu> allMenus, int level) {
    final bool isFolder = menu.menuType == 'folder';
    final List<Menu> children = _buildTree(allMenus, menu.id);
    final bool hasChildren = children.isNotEmpty;
    final bool isExpanded = _expandedState[menu.id] ?? false;

    return
        // KeyedSubtree(
        //   key: ValueKey('menu_node_${menu.id}'),
        //   child:

        Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () {
            if (isFolder && hasChildren) {
              setState(() {
                _expandedState[menu.id] = !isExpanded;
              });
            } else {
              setState(() {
                widget.searchController.text =
                    menu.targetPath ?? ''; // แสดงชื่อ widget ในช่องค้นหา
              });
              widget.onMenuSelected(menu);
              widget.onSearchSubmitted(menu.targetPath ?? '');
            }
          },
          child: Padding(
            padding: EdgeInsets.only(left: level * 16.0),
            child: Row(
              children: [
                if (isFolder && hasChildren)
                  Icon(isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                      color: Colors.black),
                if (!isFolder || !hasChildren)
                  const SizedBox(width: 24), // เพื่อให้ icon alignment ตรงกัน
                Icon(
                    menu.menuType == 'folder'
                        ? Icons.folder
                        : menu.menuType == 'link'
                            ? Icons.link
                            : menu.menuType == 'widget'
                                ? Icons.widgets
                                : menu.menuType == 'html'
                                    ? Icons.web
                                    : menu.menuType == 'markdown'
                                        ? Icons.text_format
                                        : menu.menuType == 'url'
                                            ? Icons.link_outlined
                                            : Icons.insert_drive_file_outlined,
                    color: isFolder ? Colors.blue : Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    menu.menuName,
                    style: const TextStyle(fontSize: 16, color: Colors.black),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded && hasChildren)
          Column(
            children: children
                .map((child) => _buildMenuNode(child, allMenus, level + 1))
                .toList(),
          ),
      ],
    );

    // );
    // return Padding(
    //   padding: EdgeInsets.only(left: level * 16.0),
    //   child: isFolder
    //       ? ExpansionTile(
    //           dense: true,
    //           // ** แก้ไข: เพิ่ม Key ที่ไม่ซ้ำกันสำหรับ ExpansionTile **
    //           // Key นี้สำคัญมากเพื่อให้ Flutter เก็บสถานะการขยาย (Expanded state)
    //           // ของโหนดนี้ไว้ แม้ว่า parent widget (HomeScreen) จะถูก rebuild
    //           key: ValueKey('folder_${menu.id}'),
    //           title: Text(
    //             menu.menuName,
    //             style: const TextStyle(fontSize: 14),
    //           ),
    //           // ใช้ _expandedState เพื่อควบคุมสถานะเริ่มต้น (ถ้ามี)
    //           initiallyExpanded: _expandedState[menu.id] ?? false,
    //           leading: Icon(
    //             _expandedState[menu.id] ?? false
    //                 ? Icons.folder_open
    //                 : Icons.folder,
    //             color: Colors.blue.shade700,
    //           ),
    //           onExpansionChanged: (expanded) {
    //             // อัปเดตสถานะการขยายใน Map ภายใน setState
    //             setState(() {
    //               _expandedState[menu.id] = expanded;
    //             });
    //           },
    //           children: children
    //               .map((child) => _buildMenuNode(child, allMenus, level + 1))
    //               .toList(),
    //         )
    //       : ListTile(
    //           dense: true,
    //           // ** แก้ไข: เพิ่ม Key ที่ไม่ซ้ำกันสำหรับ ListTile **
    //           // แม้จะเป็น ListTile การมี Key ก็ช่วยเรื่องความเสถียรเมื่อถูก Rebuild
    //           key: ValueKey('leaf_${menu.id}'),
    //           title: Text(
    //             menu.menuName,
    //             style: const TextStyle(fontSize: 14),
    //           ),
    //           leading: const Icon(
    //             Icons.description,
    //             color: Colors.grey,
    //           ),
    //           onTap: () => widget.onMenuSelected(menu),
    //         ),
    // );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeExpansionState();
  }

  void _initializeExpansionState() {
    for (var menu in widget.menus) {
      // ขยายเมนูย่อยของเมนูหลัก (level 0) ทั้งหมด
      if (menu.menuType == 'folder' && menu.parentId == null) {
        _expandedState[menu.id] = true;
      }
    }
  }

  @override
  void dispose() {
    // _searchController.dispose(); // <-- ไม่ต้อง dispose ที่นี่แล้ว
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final List<Menu> topLevelMenus = _buildTree(widget.menus, null);

    return 
        // const SizedBox(height: 8),
        // Padding(
        //   padding: const EdgeInsets.all(8.0),
        //   child: Row(
        //     children: [
        //       Container(
        //         padding: const EdgeInsets.all(3.0),
        //         decoration: BoxDecoration(
        //           border: Border.all(color: Colors.grey.shade600), // สีขอบเริ่มต้น
        //           borderRadius: BorderRadius.circular(6.0), // กำหนดความโค้งของขอบ
        //         ),
        //         child: IconButton(
        //           icon: const Icon(Icons.refresh),
        //           onPressed: () {
        //             widget.onRefreshMenus(); // เรียกใช้ callback
        //             widget.searchController.clear(); // อาจจะต้องการเคลียร์ช่องค้นหาด้วย
        //           },
        //           tooltip: 'โหลดเมนูใหม่',
        //         ),
        //       ),
        //       const SizedBox(width: 8.0),
        //       Expanded(
        //         child: TextField(
        //           controller: widget.searchController,
        //           decoration: InputDecoration(
        //             labelText:
        //                 'ใส่ชื่อ/รหัส/เส้นทาง หรือคลิกเลือกจากเมนู',
        //             labelStyle: TextStyle(
        //               color: Colors.grey[600],
        //             ),
        //             suffixIcon: IconButton(
        //               icon: const Icon(Icons.play_arrow_outlined),
        //               onPressed: () {
        //                 if (widget.searchController.text.isNotEmpty) {
        //                   widget.onSearchSubmitted(widget.searchController.text);
        //                 }
        //               },
        //             ),
        //             border: const OutlineInputBorder(),
        //           ),
        //           onSubmitted: (value) {
        //             if (value.isNotEmpty) {
        //               widget.onSearchSubmitted(value);
        //             }
        //           },
        //         ),
        //       ),
        //     ],
        //   ),
        // ),
        Column(
          children: [
            Expanded(
              child: 
              ListView.builder(
                itemCount: topLevelMenus.length,
                itemBuilder: (context, index) {
                  return _buildMenuNode(topLevelMenus[index], widget.menus, 0);
                  // return KeyedSubtree(
                  //   key: ValueKey('top_menu_key_${topLevelMenus[index].id}'),
                  //   child: _buildMenuNode(topLevelMenus[index], widget.menus, 0),
                  // );
                },
              ),
            ),
          ],
        );
  }
}
