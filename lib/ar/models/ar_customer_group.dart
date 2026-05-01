// models/ar_customer_group.dart
import 'ar_customer.dart';

class ArCustomerGroup {
  final int? id;
  final String groupCode;
  final String groupNameThai;
  final String groupNameEng;
  final String? description;
  final int creditTermMonths;
  final int creditTermDays;
  final double creditLimit;
  final double discountPercent;
  final int? glAccountId;
  final String? glAccountCode;
  final String? glAccountNameThai;
  // รหัสอัตโนมัติ
  final bool isAutoNumber;
  final String runningPrefix;
  final String runningSeparator;
  final String runningSuffixDate;
  final int runningLength;
  final int runningNextNumber;
  final bool isActive;
  final bool requiresBilling;
  final List<ArCustomerBillingCondition> billingConditions;
  final List<ArCustomerPaymentCondition> paymentConditions;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  ArCustomerGroup({
    this.id,
    required this.groupCode,
    required this.groupNameThai,
    this.groupNameEng = '',
    this.description,
    this.creditTermMonths = 0,
    this.creditTermDays = 30,
    this.creditLimit = 0,
    this.discountPercent = 0,
    this.glAccountId,
    this.glAccountCode,
    this.glAccountNameThai,
    this.isAutoNumber = false,
    this.runningPrefix = 'CUST',
    this.runningSeparator = '-',
    this.runningSuffixDate = '',
    this.runningLength = 4,
    this.runningNextNumber = 1,
    this.isActive = true,
    this.requiresBilling = false,
    this.billingConditions = const [],
    this.paymentConditions = const [],
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory ArCustomerGroup.fromJson(Map<String, dynamic> json) {
    return ArCustomerGroup(
      id: json['id'],
      groupCode: json['group_code'] ?? '',
      groupNameThai: json['group_name_thai'] ?? '',
      groupNameEng: json['group_name_eng'] ?? '',
      description: json['description'],
      creditTermMonths: json['credit_term_months'] ?? 0,
      creditTermDays: json['credit_term_days'] ?? 30,
      creditLimit:
          double.tryParse(json['credit_limit']?.toString() ?? '0') ?? 0,
      discountPercent:
          double.tryParse(json['discount_percent']?.toString() ?? '0') ?? 0,
      glAccountId: json['gl_account_id'],
      glAccountCode: json['gl_account_code']?.toString(),
      glAccountNameThai: json['gl_account_name_thai']?.toString(),
      isAutoNumber: json['is_auto_number'] ?? false,
      runningPrefix: json['running_prefix'] ?? 'CUST',
      runningSeparator: json['running_separator'] ?? '-',
      runningSuffixDate: json['running_suffix_date'] ?? '',
      runningLength: json['running_length'] ?? 4,
      runningNextNumber: json['running_next_number'] ?? 1,
      isActive: json['is_active'] ?? true,
      requiresBilling: json['requires_billing'] ?? false,
      billingConditions: (json['billing_conditions'] as List<dynamic>? ?? [])
          .map((e) => ArCustomerBillingCondition.fromJson(e))
          .toList(),
      paymentConditions: (json['payment_conditions'] as List<dynamic>? ?? [])
          .map((e) => ArCustomerPaymentCondition.fromJson(e))
          .toList(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      createdBy: json['created_by']?.toString(),
      updatedBy: json['updated_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_code': groupCode,
      'group_name_thai': groupNameThai,
      'group_name_eng': groupNameEng,
      'description': description,
      'credit_term_months': creditTermMonths,
      'credit_term_days': creditTermDays,
      'credit_limit': creditLimit,
      'discount_percent': discountPercent,
      'gl_account_id': glAccountId,
      'is_auto_number': isAutoNumber,
      'running_prefix': runningPrefix,
      'running_separator': runningSeparator,
      'running_suffix_date': runningSuffixDate,
      'running_length': runningLength,
      'running_next_number': runningNextNumber,
      'is_active': isActive,
      'requires_billing': requiresBilling,
      'billing_conditions': billingConditions.map((e) => e.toJson()).toList(),
      'payment_conditions': paymentConditions.map((e) => e.toJson()).toList(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
    };
  }

  /// สร้างตัวอย่างรหัสลูกหนี้สำหรับกลุ่มนี้ (client-side preview)
  String get sampleCode {
    String code = runningPrefix;
    if (runningSuffixDate.isNotEmpty) {
      final now = DateTime.now();
      final year = now.year.toString();
      final month = now.month.toString().padLeft(2, '0');
      final day = now.day.toString().padLeft(2, '0');
      switch (runningSuffixDate) {
        case 'YY':
          code += year.substring(2);
          break;
        case 'YYYY':
          code += year;
          break;
        case 'YYMM':
          code += year.substring(2) + month;
          break;
        case 'YYYYMM':
          code += year + month;
          break;
        case 'YYMMDD':
          code += year.substring(2) + month + day;
          break;
      }
    }
    code += runningSeparator;
    code += runningNextNumber.toString().padLeft(runningLength, '0');
    return code;
  }
}
