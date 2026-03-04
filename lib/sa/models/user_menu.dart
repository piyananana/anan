// models/user_menu.dart
class UserMenu {
  final int userId;
  final int menuId;

  UserMenu({
    required this.userId,
    required this.menuId,
  });

  factory UserMenu.fromJson(Map<String, dynamic> json) {
    return UserMenu(
      userId: json['user_id'],
      menuId: json['menu_id'],
    );
  }

  // Add this method for storing in SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'menu_id': menuId,
    };
  }

  UserMenu copyWith({
    int? userId,
    int? menuId,
  }) {
    return UserMenu(
      userId: userId ?? this.userId,
      menuId: menuId ?? this.menuId,
    );
  }
}
