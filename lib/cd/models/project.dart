// Models
class Project {
  final int? id;
  final String projectCode;
  final String projectNameThai;
  final String projectNameEng;
  final bool isActive;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  Project({
    this.id,
    required this.projectCode,
    required this.projectNameThai,
    required this.projectNameEng,
    required this.isActive,
    required this.startDate,
    required this.endDate,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      projectCode: json['project_code'],
      projectNameThai: json['project_name_thai'],
      projectNameEng: json['project_name_eng'],
      isActive: json['is_active'] ?? false,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'])
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      createdBy: json['created_by'] ?? '',
      updatedBy: json['updated_by'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_code': projectCode,
      'project_name_thai': projectNameThai,
      'project_name_eng': projectNameEng,
      'is_active': isActive,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
    };
  }
}
