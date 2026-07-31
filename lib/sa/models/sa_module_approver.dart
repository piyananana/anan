// lib/sa/models/sa_module_approver.dart

// คิวผู้อนุมัติผูกกับ menu_id (+ doc_type ถ้าเมนูนั้น uses_doc_type) — ดูรายละเอียดที่
// sa_module_approver_screen.dart / saModuleApproverController.js
class SaModuleApprover {
  final int? id;
  final int approvalLevel;
  final int approverUserId;
  final String? approverUsername;
  final String? approverFirstName;
  final String? approverLastName;
  final String? approverEmail;
  final bool isActive;
  final String? docType; // null = คิวระดับเมนู

  SaModuleApprover({
    this.id,
    required this.approvalLevel,
    required this.approverUserId,
    this.approverUsername,
    this.approverFirstName,
    this.approverLastName,
    this.approverEmail,
    this.isActive = true,
    this.docType,
  });

  String get approverFullName {
    final first = approverFirstName ?? '';
    final last  = approverLastName  ?? '';
    final full  = '$first $last'.trim();
    return full.isNotEmpty ? full : (approverUsername ?? '');
  }

  factory SaModuleApprover.fromJson(Map<String, dynamic> json) => SaModuleApprover(
        id: json['id'],
        approvalLevel: json['approval_level'] ?? 1,
        approverUserId: json['approver_user_id'] ?? 0,
        approverUsername: json['approver_username'],
        approverFirstName: json['approver_first_name'],
        approverLastName: json['approver_last_name'],
        approverEmail: json['approver_email'],
        isActive: json['is_active'] ?? true,
        docType: json['doc_type'] as String?,
      );

  SaModuleApprover copyWith({
    int? id, int? approvalLevel,
    int? approverUserId, String? approverUsername,
    String? approverFirstName, String? approverLastName, String? approverEmail,
    bool? isActive, String? docType,
  }) => SaModuleApprover(
        id: id ?? this.id,
        approvalLevel: approvalLevel ?? this.approvalLevel,
        approverUserId: approverUserId ?? this.approverUserId,
        approverUsername: approverUsername ?? this.approverUsername,
        approverFirstName: approverFirstName ?? this.approverFirstName,
        approverLastName: approverLastName ?? this.approverLastName,
        approverEmail: approverEmail ?? this.approverEmail,
        isActive: isActive ?? this.isActive,
        docType: docType ?? this.docType,
      );
}
