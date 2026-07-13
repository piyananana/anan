// lib/cd/models/cd_salesperson.dart
import '../../../utils/date_utils.dart';

class SalespersonTerritory {
  final int? id;
  final int? salespersonId;
  final int territoryId;
  final String? territoryCode;
  final String? territoryNameThai;
  final bool isPrimary;
  final DateTime? effectiveDateFrom;
  final DateTime? effectiveDateTo;

  SalespersonTerritory({
    this.id,
    this.salespersonId,
    required this.territoryId,
    this.territoryCode,
    this.territoryNameThai,
    this.isPrimary = false,
    this.effectiveDateFrom,
    this.effectiveDateTo,
  });

  factory SalespersonTerritory.fromJson(Map<String, dynamic> json) =>
      SalespersonTerritory(
        id: json['id'] as int?,
        salespersonId: json['salesperson_id'] as int?,
        territoryId: json['territory_id'] as int,
        territoryCode: json['territory_code'] as String?,
        territoryNameThai: json['territory_name_thai'] as String?,
        isPrimary: json['is_primary'] as bool? ?? false,
        effectiveDateFrom: parseLocalDateNullable(json['effective_date_from']),
        effectiveDateTo: parseLocalDateNullable(json['effective_date_to']),
      );

  Map<String, dynamic> toJson() => {
        'territory_id': territoryId,
        'is_primary': isPrimary,
        'effective_date_from':
            effectiveDateFrom != null ? formatLocalDate(effectiveDateFrom!) : null,
        'effective_date_to':
            effectiveDateTo != null ? formatLocalDate(effectiveDateTo!) : null,
      };

  SalespersonTerritory copyWith({
    bool? isPrimary,
    DateTime? effectiveDateFrom,
    DateTime? effectiveDateTo,
  }) =>
      SalespersonTerritory(
        id: id,
        salespersonId: salespersonId,
        territoryId: territoryId,
        territoryCode: territoryCode,
        territoryNameThai: territoryNameThai,
        isPrimary: isPrimary ?? this.isPrimary,
        effectiveDateFrom: effectiveDateFrom ?? this.effectiveDateFrom,
        effectiveDateTo: effectiveDateTo ?? this.effectiveDateTo,
      );
}

const salespersonTypeOptions = {
  'EMPLOYEE': 'พนักงานภายใน',
  'INDIVIDUAL': 'บุคคลภายนอก',
  'COMPANY': 'บริษัท/นิติบุคคล',
};

class Salesperson {
  final int? id;
  final String salespersonCode;
  final String salespersonNameThai;
  final String? salespersonNameEng;
  final String salespersonType;
  final int? userId;
  final String? userNameRef;
  final String? taxId;
  final int? branchId;
  final String? branchNameThai;
  final int? businessUnitId;
  final String? businessUnitName;
  final String? phone;
  final String? email;
  final String? address;
  final double commissionRate;
  final DateTime? effectiveDateFrom;
  final DateTime? effectiveDateTo;
  final bool isActive;
  final List<SalespersonTerritory> territories;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  Salesperson({
    this.id,
    required this.salespersonCode,
    required this.salespersonNameThai,
    this.salespersonNameEng,
    this.salespersonType = 'EMPLOYEE',
    this.userId,
    this.userNameRef,
    this.taxId,
    this.branchId,
    this.branchNameThai,
    this.businessUnitId,
    this.businessUnitName,
    this.phone,
    this.email,
    this.address,
    this.commissionRate = 0,
    this.effectiveDateFrom,
    this.effectiveDateTo,
    this.isActive = true,
    this.territories = const [],
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory Salesperson.fromJson(Map<String, dynamic> json) => Salesperson(
        id: json['id'] as int?,
        salespersonCode: json['salesperson_code'] as String? ?? '',
        salespersonNameThai: json['salesperson_name_thai'] as String? ?? '',
        salespersonNameEng: json['salesperson_name_eng'] as String?,
        salespersonType: json['salesperson_type'] as String? ?? 'EMPLOYEE',
        userId: json['user_id'] as int?,
        userNameRef: json['user_name_ref'] as String?,
        taxId: json['tax_id'] as String?,
        branchId: json['branch_id'] as int?,
        branchNameThai: json['branch_name_thai'] as String?,
        businessUnitId: json['business_unit_id'] as int?,
        businessUnitName: json['business_unit_name'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        address: json['address'] as String?,
        commissionRate:
            double.tryParse(json['commission_rate']?.toString() ?? '0') ?? 0,
        effectiveDateFrom: parseLocalDateNullable(json['effective_date_from']),
        effectiveDateTo: parseLocalDateNullable(json['effective_date_to']),
        isActive: json['is_active'] as bool? ?? true,
        territories: (json['territories'] as List<dynamic>? ?? [])
            .map((e) => SalespersonTerritory.fromJson(e))
            .toList(),
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
        'salesperson_code': salespersonCode,
        'salesperson_name_thai': salespersonNameThai,
        'salesperson_name_eng': salespersonNameEng,
        'salesperson_type': salespersonType,
        'user_id': userId,
        'tax_id': taxId,
        'branch_id': branchId,
        'business_unit_id': businessUnitId,
        'phone': phone,
        'email': email,
        'address': address,
        'commission_rate': commissionRate,
        'effective_date_from':
            effectiveDateFrom != null ? formatLocalDate(effectiveDateFrom!) : null,
        'effective_date_to':
            effectiveDateTo != null ? formatLocalDate(effectiveDateTo!) : null,
        'is_active': isActive,
        'territories': territories.map((t) => t.toJson()).toList(),
      };
}
