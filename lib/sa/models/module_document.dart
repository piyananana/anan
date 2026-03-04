// lib/sa/models/module_document.dart

class ModuleDocument {
  final int id;
  final String docCode;
  final String docNameThai;
  final String docNameEng;
  final int? parentId;
  final int sortOrder;
  final bool
      isDocType; // TRUE: ใช้เป็นประเภทเอกสาร, FALSE: เป็นโมดูลของประเภทเอกสาร
  final bool
      isAutoNumbering; // TRUE: เลขที่เอกสารอัตโนมัติ, FALSE: ระบุเลขที่เอกสารเอง
  final String formatPrefix;
  final String formatSeparator;
  final String formatSuffixDate;
  final int nextRunningNumber;
  final int runningLength;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? createdBy;
  final int? updatedBy;
  final String sysModule;
  final String sysDocType;

  List<ModuleDocument> children = [];

  ModuleDocument({
    required this.id,
    required this.docCode,
    required this.docNameThai,
    required this.docNameEng,
    this.parentId,
    required this.sortOrder,
    required this.isDocType,
    required this.isAutoNumbering,
    required this.formatPrefix,
    required this.formatSeparator,
    required this.formatSuffixDate,
    this.nextRunningNumber = 1,
    this.runningLength = 0,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    required this.sysModule,
    required this.sysDocType,
    this.children = const [],
  });

  // สร้าง ModuleDocument object จาก JSON (มาจาก Backend)
  factory ModuleDocument.fromJson(Map<String, dynamic> json) {
    return ModuleDocument(
        id: json['id'],
        docCode: json['doc_code'],
        docNameThai: json['doc_name_thai'],
        docNameEng: json['doc_name_eng'],
        parentId: json['parent_id'],
        sortOrder: json['sort_order'],
        isDocType: json['is_doc_type'],
        isAutoNumbering: json['is_auto_numbering'],
        formatPrefix: json['format_prefix'],
        formatSeparator: json['format_separator'],
        formatSuffixDate: json['format_suffix_date'],
        nextRunningNumber: json['next_running_number'] as int? ?? 1,
        runningLength: json['running_length'] as int? ?? 3,
        isActive: json['is_active'],
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'])
            : null,
        createdBy: json['created_by'],
        updatedBy: json['updated_by'],
        sysModule: json['sys_module'],
        sysDocType: json['sys_doc_type'],
        children: []
    );
  }

  // แปลง ModuleDocument object เป็น JSON สำหรับส่งไปยัง Backend
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'doc_code': docCode,
      'doc_name_thai': docNameThai,
      'doc_name_eng': docNameEng,
      'parent_id': parentId,
      'sort_order': sortOrder,
      'is_doc_type': isDocType,
      'is_auto_numbering': isAutoNumbering,
      'format_prefix': formatPrefix,
      'format_separator': formatSeparator,
      'format_suffix_date': formatSuffixDate,
      'next_running_number': nextRunningNumber,
      'running_length': runningLength,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
      'sys_module': sysModule,
      'sys_doc_type': sysDocType,
    };
  }
}
