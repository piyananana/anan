// lib/cd/models/bank.dart
class Bank {
  final int? id;
  final String bankCode;
  final String bankNameThai;
  final String bankNameEng;
  final String? shortName;
  final String? swiftCode;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  Bank({
    this.id,
    required this.bankCode,
    required this.bankNameThai,
    required this.bankNameEng,
    this.shortName,
    this.swiftCode,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory Bank.fromJson(Map<String, dynamic> json) => Bank(
        id: json['id'],
        bankCode: json['bank_code'],
        bankNameThai: json['bank_name_thai'],
        bankNameEng: json['bank_name_eng'] ?? '',
        shortName: json['short_name'],
        swiftCode: json['swift_code'],
        isActive: json['is_active'] ?? true,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'])
            : null,
        createdBy: json['created_by']?.toString(),
        updatedBy: json['updated_by']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'bank_code': bankCode,
        'bank_name_thai': bankNameThai,
        'bank_name_eng': bankNameEng,
        'short_name': shortName,
        'swift_code': swiftCode,
        'is_active': isActive,
      };

  String get displayName =>
      shortName != null && shortName!.isNotEmpty ? shortName! : bankNameThai;
}
