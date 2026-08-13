// lib/im/models/im_location.dart

const List<String> imLocationTypes = ['GROUP', 'BIN'];

String imLocationTypeLabel(String type, bool isEnglish) {
  if (type == 'GROUP') return isEnglish ? 'Group (zone/aisle)' : 'กลุ่ม (โซน/แถว)';
  return isEnglish ? 'Bin (storage slot)' : 'ช่องเก็บ';
}

class ImLocation {
  final int id;
  final int warehouseId;
  final String? warehouseCode;
  final String? warehouseNameTh;
  final String? warehouseNameEn;
  final int? parentId;
  final int level;
  final String locationCode;
  final String? locationName;
  final String locationType; // 'GROUP' / 'BIN'
  final int? categoryId;
  final String? categoryCode;
  final String? categoryNameTh;
  final String? categoryNameEn;
  final bool isActive;

  const ImLocation({
    required this.id,
    required this.warehouseId,
    this.warehouseCode,
    this.warehouseNameTh,
    this.warehouseNameEn,
    this.parentId,
    this.level = 1,
    required this.locationCode,
    this.locationName,
    this.locationType = 'BIN',
    this.categoryId,
    this.categoryCode,
    this.categoryNameTh,
    this.categoryNameEn,
    this.isActive = true,
  });

  factory ImLocation.fromJson(Map<String, dynamic> json) => ImLocation(
        id: json['id'] as int,
        warehouseId: json['warehouse_id'] as int,
        warehouseCode: json['warehouse_code'],
        warehouseNameTh: json['warehouse_name_th'],
        warehouseNameEn: json['warehouse_name_en'],
        parentId: json['parent_id'],
        level: json['level'] ?? 1,
        locationCode: json['location_code'] ?? '',
        locationName: json['location_name'],
        locationType: json['location_type'] ?? 'BIN',
        categoryId: json['category_id'],
        categoryCode: json['category_code'],
        categoryNameTh: json['category_name_th'],
        categoryNameEn: json['category_name_en'],
        isActive: json['is_active'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        if (id != 0) 'id': id,
        'warehouse_id': warehouseId,
        'parent_id': parentId,
        'location_code': locationCode,
        'location_name': locationName,
        'location_type': locationType,
        'category_id': categoryId,
        'is_active': isActive,
      };
}
