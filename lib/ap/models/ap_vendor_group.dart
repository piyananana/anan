// lib/ap/models/ap_vendor_group.dart

class ApVendorGroup {
  final int? id;
  final String groupCode;
  final String groupNameThai;
  final String groupNameEng;
  final String? description;
  final int creditTermMonths;
  final int creditTermDays;
  final String currencyCode;
  final int? apAccountId;
  final String? apAccountCode;
  final String? apAccountNameThai;
  final bool isAutoNumber;
  final String runningPrefix;
  final String runningSeparator;
  final String runningSuffixDate;
  final int runningLength;
  final int runningNextNumber;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  ApVendorGroup({
    this.id,
    required this.groupCode,
    required this.groupNameThai,
    this.groupNameEng = '',
    this.description,
    this.creditTermMonths = 0,
    this.creditTermDays = 30,
    this.currencyCode = 'THB',
    this.apAccountId,
    this.apAccountCode,
    this.apAccountNameThai,
    this.isAutoNumber = false,
    this.runningPrefix = 'VEND',
    this.runningSeparator = '-',
    this.runningSuffixDate = '',
    this.runningLength = 4,
    this.runningNextNumber = 1,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory ApVendorGroup.fromJson(Map<String, dynamic> json) => ApVendorGroup(
        id: json['id'],
        groupCode: json['group_code'] ?? '',
        groupNameThai: json['group_name_thai'] ?? '',
        groupNameEng: json['group_name_eng'] ?? '',
        description: json['description'],
        creditTermMonths: json['credit_term_months'] ?? 0,
        creditTermDays: json['credit_term_days'] ?? 30,
        currencyCode: json['currency_code'] ?? 'THB',
        apAccountId: json['ap_account_id'],
        apAccountCode: json['ap_account_code']?.toString(),
        apAccountNameThai: json['ap_account_name_thai']?.toString(),
        isAutoNumber: json['is_auto_number'] ?? false,
        runningPrefix: json['running_prefix'] ?? 'VEND',
        runningSeparator: json['running_separator'] ?? '-',
        runningSuffixDate: json['running_suffix_date'] ?? '',
        runningLength: json['running_length'] ?? 4,
        runningNextNumber: json['running_next_number'] ?? 1,
        isActive: json['is_active'] ?? true,
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
        updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
        createdBy: json['created_by']?.toString(),
        updatedBy: json['updated_by']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'group_code': groupCode,
        'group_name_thai': groupNameThai,
        'group_name_eng': groupNameEng,
        'description': description,
        'credit_term_months': creditTermMonths,
        'credit_term_days': creditTermDays,
        'currency_code': currencyCode,
        'ap_account_id': apAccountId,
        'is_auto_number': isAutoNumber,
        'running_prefix': runningPrefix,
        'running_separator': runningSeparator,
        'running_suffix_date': runningSuffixDate,
        'running_length': runningLength,
        'running_next_number': runningNextNumber,
        'is_active': isActive,
      };

  String get sampleCode {
    String code = runningPrefix;
    if (runningSuffixDate.isNotEmpty) {
      final now = DateTime.now();
      final year = now.year.toString();
      final month = now.month.toString().padLeft(2, '0');
      final day = now.day.toString().padLeft(2, '0');
      switch (runningSuffixDate) {
        case 'YY':     code += year.substring(2); break;
        case 'YYYY':   code += year; break;
        case 'YYMM':   code += year.substring(2) + month; break;
        case 'YYYYMM': code += year + month; break;
        case 'YYMMDD': code += year.substring(2) + month + day; break;
      }
    }
    code += runningSeparator;
    code += runningNextNumber.toString().padLeft(runningLength, '0');
    return code;
  }
}
