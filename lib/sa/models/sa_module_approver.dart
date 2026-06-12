// lib/sa/models/sa_module_approver.dart

class SaModuleApprover {
  final int? id;
  final String moduleCode;
  final String docCategory;
  final int approvalLevel;
  final int approverUserId;
  final String? approverUsername;
  final String? approverFirstName;
  final String? approverLastName;
  final String? approverEmail;
  final String? signatureImage; // base64 data URL
  final bool isActive;

  SaModuleApprover({
    this.id,
    required this.moduleCode,
    required this.docCategory,
    required this.approvalLevel,
    required this.approverUserId,
    this.approverUsername,
    this.approverFirstName,
    this.approverLastName,
    this.approverEmail,
    this.signatureImage,
    this.isActive = true,
  });

  String get approverFullName {
    final first = approverFirstName ?? '';
    final last  = approverLastName  ?? '';
    final full  = '$first $last'.trim();
    return full.isNotEmpty ? full : (approverUsername ?? '');
  }

  String get moduleName {
    const map = {'AP': 'บัญชีเจ้าหนี้ (AP)', 'AR': 'บัญชีลูกหนี้ (AR)', 'GL': 'บัญชีแยกประเภท (GL)'};
    return map[moduleCode] ?? moduleCode;
  }

  String get docCategoryName {
    const map = {'payment_run': 'Payment Run (ชำระเงิน)'};
    return map[docCategory] ?? docCategory;
  }

  factory SaModuleApprover.fromJson(Map<String, dynamic> json) => SaModuleApprover(
        id: json['id'],
        moduleCode: json['module_code'] ?? '',
        docCategory: json['doc_category'] ?? '',
        approvalLevel: json['approval_level'] ?? 1,
        approverUserId: json['approver_user_id'] ?? 0,
        approverUsername: json['approver_username'],
        approverFirstName: json['approver_first_name'],
        approverLastName: json['approver_last_name'],
        approverEmail: json['approver_email'],
        signatureImage: json['signature_image'],
        isActive: json['is_active'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'module_code': moduleCode,
        'doc_category': docCategory,
        'approval_level': approvalLevel,
        'approver_user_id': approverUserId,
        'signature_image': signatureImage,
        'is_active': isActive,
      };

  SaModuleApprover copyWith({
    int? id, String? moduleCode, String? docCategory, int? approvalLevel,
    int? approverUserId, String? approverUsername,
    String? approverFirstName, String? approverLastName, String? approverEmail,
    String? signatureImage, bool? isActive,
  }) => SaModuleApprover(
        id: id ?? this.id,
        moduleCode: moduleCode ?? this.moduleCode,
        docCategory: docCategory ?? this.docCategory,
        approvalLevel: approvalLevel ?? this.approvalLevel,
        approverUserId: approverUserId ?? this.approverUserId,
        approverUsername: approverUsername ?? this.approverUsername,
        approverFirstName: approverFirstName ?? this.approverFirstName,
        approverLastName: approverLastName ?? this.approverLastName,
        approverEmail: approverEmail ?? this.approverEmail,
        signatureImage: signatureImage ?? this.signatureImage,
        isActive: isActive ?? this.isActive,
      );
}
