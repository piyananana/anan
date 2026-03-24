// lib/ar/models/ar_collector.dart
import '../../../utils/date_utils.dart';

const arCollectorTypeOptions = {
  'EMPLOYEE': 'พนักงานภายใน',
  'INDIVIDUAL': 'บุคคลภายนอก',
  'COMPANY': 'บริษัท/นิติบุคคล',
};

class ArCollector {
  final int? id;
  final String collectorCode;
  final String collectorNameThai;
  final String? collectorNameEng;
  final String collectorType;
  final String? taxId;
  final int? branchId;
  final String? branchNameThai;
  final int? businessUnitId;
  final String? businessUnitName;
  final String? phone;
  final String? email;
  final String? address;
  final DateTime? effectiveDateFrom;
  final DateTime? effectiveDateTo;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  ArCollector({
    this.id,
    required this.collectorCode,
    required this.collectorNameThai,
    this.collectorNameEng,
    this.collectorType = 'EMPLOYEE',
    this.taxId,
    this.branchId,
    this.branchNameThai,
    this.businessUnitId,
    this.businessUnitName,
    this.phone,
    this.email,
    this.address,
    this.effectiveDateFrom,
    this.effectiveDateTo,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory ArCollector.fromJson(Map<String, dynamic> json) => ArCollector(
        id: json['id'] as int?,
        collectorCode: json['collector_code'] as String? ?? '',
        collectorNameThai: json['collector_name_thai'] as String? ?? '',
        collectorNameEng: json['collector_name_eng'] as String?,
        collectorType: json['collector_type'] as String? ?? 'EMPLOYEE',
        taxId: json['tax_id'] as String?,
        branchId: json['branch_id'] as int?,
        branchNameThai: json['branch_name_thai'] as String?,
        businessUnitId: json['business_unit_id'] as int?,
        businessUnitName: json['business_unit_name'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        address: json['address'] as String?,
        effectiveDateFrom: parseLocalDateNullable(json['effective_date_from']),
        effectiveDateTo: parseLocalDateNullable(json['effective_date_to']),
        isActive: json['is_active'] as bool? ?? true,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'].toString()).toLocal()
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'].toString()).toLocal()
            : null,
        createdBy: json['created_by'] as String?,
        updatedBy: json['updated_by'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'collector_code': collectorCode,
        'collector_name_thai': collectorNameThai,
        'collector_name_eng': collectorNameEng,
        'collector_type': collectorType,
        'tax_id': taxId,
        'branch_id': branchId,
        'business_unit_id': businessUnitId,
        'phone': phone,
        'email': email,
        'address': address,
        'effective_date_from':
            effectiveDateFrom != null ? formatLocalDate(effectiveDateFrom!) : null,
        'effective_date_to':
            effectiveDateTo != null ? formatLocalDate(effectiveDateTo!) : null,
        'is_active': isActive,
      };
}
