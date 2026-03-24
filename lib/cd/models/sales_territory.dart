// lib/cd/models/sales_territory.dart
import '../../../utils/date_utils.dart';

/// พนักงานขายที่รับผิดชอบเขตนี้ (ผลลัพธ์จาก GET /cd_salesperson/by_territory/:id)
class TerritoryMember {
  final int id;
  final String salespersonCode;
  final String salespersonNameThai;
  final String? salespersonNameEng;
  final String salespersonType;
  final bool isActive;
  final bool isPrimary;
  final DateTime? effectiveDateFrom;
  final DateTime? effectiveDateTo;

  TerritoryMember({
    required this.id,
    required this.salespersonCode,
    required this.salespersonNameThai,
    this.salespersonNameEng,
    this.salespersonType = 'EMPLOYEE',
    this.isActive = true,
    this.isPrimary = false,
    this.effectiveDateFrom,
    this.effectiveDateTo,
  });

  factory TerritoryMember.fromJson(Map<String, dynamic> json) => TerritoryMember(
        id: json['id'] as int,
        salespersonCode: json['salesperson_code'] as String? ?? '',
        salespersonNameThai: json['salesperson_name_thai'] as String? ?? '',
        salespersonNameEng: json['salesperson_name_eng'] as String?,
        salespersonType: json['salesperson_type'] as String? ?? 'EMPLOYEE',
        isActive: json['is_active'] as bool? ?? true,
        isPrimary: json['is_primary'] as bool? ?? false,
        effectiveDateFrom: parseLocalDateNullable(json['effective_date_from']),
        effectiveDateTo: parseLocalDateNullable(json['effective_date_to']),
      );
}

class SalesTerritory {
  final int? id;
  final String territoryCode;
  final String territoryNameThai;
  final String? territoryNameEng;
  final int? parentId;
  final String? parentNameThai;
  final int sortOrder;
  final String? description;
  final DateTime? effectiveDateFrom;
  final DateTime? effectiveDateTo;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  SalesTerritory({
    this.id,
    required this.territoryCode,
    required this.territoryNameThai,
    this.territoryNameEng,
    this.parentId,
    this.parentNameThai,
    this.sortOrder = 0,
    this.description,
    this.effectiveDateFrom,
    this.effectiveDateTo,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory SalesTerritory.fromJson(Map<String, dynamic> json) => SalesTerritory(
        id: json['id'] as int?,
        territoryCode: json['territory_code'] as String? ?? '',
        territoryNameThai: json['territory_name_thai'] as String? ?? '',
        territoryNameEng: json['territory_name_eng'] as String?,
        parentId: json['parent_id'] as int?,
        parentNameThai: json['parent_name_thai'] as String?,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        description: json['description'] as String?,
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
        'territory_code': territoryCode,
        'territory_name_thai': territoryNameThai,
        'territory_name_eng': territoryNameEng,
        'parent_id': parentId,
        'sort_order': sortOrder,
        'description': description,
        'effective_date_from': effectiveDateFrom != null ? formatLocalDate(effectiveDateFrom!) : null,
        'effective_date_to': effectiveDateTo != null ? formatLocalDate(effectiveDateTo!) : null,
        'is_active': isActive,
      };
}
