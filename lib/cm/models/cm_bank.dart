// lib/cm/models/cm_bank.dart
class CmBank {
  final int? id;
  final String bankCode;
  final String bankNameTh;
  final String? bankNameEn;
  final String? shortName;
  final String? swiftCode;
  final bool isActive;
  final String? remark;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  CmBank({
    this.id,
    required this.bankCode,
    required this.bankNameTh,
    this.bankNameEn,
    this.shortName,
    this.swiftCode,
    required this.isActive,
    this.remark,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory CmBank.fromJson(Map<String, dynamic> json) => CmBank(
        id: json['id'],
        bankCode: json['bank_code'] ?? '',
        bankNameTh: json['bank_name_th'] ?? '',
        bankNameEn: json['bank_name_en'],
        shortName: json['short_name'],
        swiftCode: json['swift_code'],
        isActive: json['is_active'] ?? true,
        remark: json['remark'],
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
        updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
        createdBy: json['created_by']?.toString(),
        updatedBy: json['updated_by']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'bank_code': bankCode,
        'bank_name_th': bankNameTh,
        'bank_name_en': bankNameEn,
        'short_name': shortName,
        'swift_code': swiftCode,
        'is_active': isActive,
        'remark': remark,
      };

  String get displayName =>
      shortName != null && shortName!.isNotEmpty ? shortName! : bankNameTh;
}
