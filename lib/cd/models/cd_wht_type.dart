// lib/cd/models/cd_wht_type.dart
import '../../../utils/date_utils.dart';

const List<String> whtIncomeTypeOptions = [
  '40(1)', '40(2)', '40(3)', '40(4)', '40(5)', '40(6)', '40(7)', '40(8)', '3',
];

class CdWhtType {
  final int?   id;
  final String whtCode;
  final String whtName;
  final String? incomeType;
  final double  whtRate;
  final int?    glAccountId;
  final String? glAccountCode;
  final String? glAccountName;
  final String? description;
  final bool    isActive;
  final DateTime? effectiveDate;
  final DateTime? endDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String?   createdBy;
  final String?   updatedBy;

  const CdWhtType({
    this.id,
    required this.whtCode,
    required this.whtName,
    this.incomeType,
    this.whtRate = 0,
    this.glAccountId,
    this.glAccountCode,
    this.glAccountName,
    this.description,
    this.isActive = true,
    this.effectiveDate,
    this.endDate,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory CdWhtType.fromJson(Map<String, dynamic> j) {
    return CdWhtType(
      id:             j['id'] as int?,
      whtCode:        j['wht_code'] as String? ?? '',
      whtName:        j['wht_name'] as String? ?? '',
      incomeType:     j['income_type'] as String?,
      whtRate:        double.tryParse(j['wht_rate']?.toString() ?? '0') ?? 0,
      glAccountId:    j['gl_account_id'] as int?,
      glAccountCode:  j['gl_account_code'] as String?,
      glAccountName:  j['gl_account_name'] as String?,
      description:    j['description'] as String?,
      isActive:       j['is_active'] as bool? ?? true,
      effectiveDate:  j['effective_date'] != null ? parseLocalDate(j['effective_date']) : null,
      endDate:        j['end_date'] != null ? parseLocalDate(j['end_date']) : null,
      createdAt:      j['created_at'] != null ? DateTime.parse(j['created_at']) : null,
      updatedAt:      j['updated_at'] != null ? DateTime.parse(j['updated_at']) : null,
      createdBy:      j['created_by']?.toString(),
      updatedBy:      j['updated_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id':           id,
    'wht_code':     whtCode,
    'wht_name':     whtName,
    'income_type':  incomeType,
    'wht_rate':     whtRate,
    'gl_account_id':   glAccountId,
    'description':     description,
    'is_active':       isActive,
    'effective_date':  effectiveDate != null ? formatLocalDate(effectiveDate!) : null,
    'end_date':        endDate != null ? formatLocalDate(endDate!) : null,
  };
}
