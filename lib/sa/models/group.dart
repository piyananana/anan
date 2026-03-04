// models/group.dart

class Group {
  final String? id;
  String name;
  String? parentId;
  bool isActive;
  bool haveSubGroup;
  String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Group({
    this.id,
    required this.name,
    this.parentId,
    this.isActive = true,
    this.haveSubGroup = true,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String,
      name: json['name'] as String,
      parentId: json['parent_id'] as String?,
      isActive: json['is_active'] as bool,
      haveSubGroup: json['have_sub_group'] as bool,
      description: json['description'] as String?,
      // createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      // updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'parent_id': parentId,
      'is_active': isActive,
      'have_sub_group': haveSubGroup,
      'description': description,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}