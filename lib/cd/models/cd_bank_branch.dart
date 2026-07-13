// lib/cd/models/cd_bank_branch.dart
class BankBranch {
  final int? id;
  final int bankId;
  final String? branchCode;
  final String branchName;
  final String? branchAddress;
  final bool isActive;
  // JOIN fields
  final String? bankCode;
  final String? bankNameThai;
  final String? shortName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  BankBranch({
    this.id,
    required this.bankId,
    this.branchCode,
    required this.branchName,
    this.branchAddress,
    required this.isActive,
    this.bankCode,
    this.bankNameThai,
    this.shortName,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory BankBranch.fromJson(Map<String, dynamic> json) => BankBranch(
        id: json['id'],
        bankId: json['bank_id'],
        branchCode: json['branch_code'],
        branchName: json['branch_name'],
        branchAddress: json['branch_address'],
        isActive: json['is_active'] ?? true,
        bankCode: json['bank_code'],
        bankNameThai: json['bank_name_thai'],
        shortName: json['short_name'],
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
        'bank_id': bankId,
        'branch_code': branchCode,
        'branch_name': branchName,
        'branch_address': branchAddress,
        'is_active': isActive,
      };

  String get bankDisplay =>
      shortName != null && shortName!.isNotEmpty ? shortName! : (bankNameThai ?? '');
}
