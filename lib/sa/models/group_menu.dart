// models/group_menu.dart
class GroupMenu {
  final String? groupId;
  final int menuId;

  GroupMenu({
    required this.groupId,
    required this.menuId,
  });

  factory GroupMenu.fromJson(Map<String, dynamic> json) {
    return GroupMenu(
      groupId: json['group_id'],
      menuId: json['menu_id'],
    );
  }

  // Add this method for storing in SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'group_id': groupId,
      'menu_id': menuId,
    };
  }

  GroupMenu copyWith({
    String? groupId,
    int? menuId,
  }) {
    return GroupMenu(
      groupId: groupId ?? this.groupId,
      menuId: menuId ?? this.menuId,
    );
  }
}
