import '../../../utils/date_utils.dart';

class VatRate {
  final int? id;
  final String vatCode;
  final String vatNameTh;
  final String? vatNameEn;
  final double rate;
  final DateTime effectiveDate;
  final DateTime? endDate;
  final bool isActive;
  final String? remark;
  final int?    glAccountId;
  final String? glAccountCode;
  final String? glAccountName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  VatRate({
    this.id,
    required this.vatCode,
    required this.vatNameTh,
    this.vatNameEn,
    required this.rate,
    required this.effectiveDate,
    this.endDate,
    required this.isActive,
    this.remark,
    this.glAccountId,
    this.glAccountCode,
    this.glAccountName,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory VatRate.fromJson(Map<String, dynamic> json) {
    return VatRate(
      id: json['id'],
      vatCode: json['vat_code'],
      vatNameTh: json['vat_name_th'],
      vatNameEn: json['vat_name_en'],
      rate: double.tryParse(json['rate'].toString()) ?? 0.0,
      effectiveDate: parseLocalDate(json['effective_date']),
      endDate: json['end_date'] != null ? parseLocalDate(json['end_date']) : null,
      isActive: json['is_active'] ?? true,
      remark: json['remark'],
      glAccountId: json['gl_account_id'],
      glAccountCode: json['gl_account_code'],
      glAccountName: json['gl_account_name'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      createdBy: json['created_by']?.toString(),
      updatedBy: json['updated_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vat_code': vatCode,
      'vat_name_th': vatNameTh,
      'vat_name_en': vatNameEn,
      'rate': rate,
      'effective_date': formatLocalDate(effectiveDate),
      'end_date': endDate != null ? formatLocalDate(endDate!) : null,
      'is_active': isActive,
      'remark': remark,
      'gl_account_id': glAccountId,
    };
  }
}
