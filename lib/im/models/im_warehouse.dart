// lib/im/models/im_warehouse.dart

class ImLocation {
  final int? id;
  final int? warehouseId;
  final String locationCode;
  final String? locationName;
  final bool isActive;

  const ImLocation({
    this.id,
    this.warehouseId,
    required this.locationCode,
    this.locationName,
    this.isActive = true,
  });

  factory ImLocation.fromJson(Map<String, dynamic> json) => ImLocation(
        id: json['id'],
        warehouseId: json['warehouse_id'],
        locationCode: json['location_code'] ?? '',
        locationName: json['location_name'],
        isActive: json['is_active'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'location_code': locationCode,
        'location_name': locationName,
        'is_active': isActive,
      };
}

class ImWarehouse {
  final int id;
  final String warehouseCode;
  final String warehouseNameTh;
  final String? warehouseNameEn;
  final int? branchId;
  final String? branchCode;
  final String? branchNameTh;
  final String? branchNameEn;
  final String? address;
  final bool isActive;
  final List<ImLocation> locations;

  const ImWarehouse({
    required this.id,
    required this.warehouseCode,
    required this.warehouseNameTh,
    this.warehouseNameEn,
    this.branchId,
    this.branchCode,
    this.branchNameTh,
    this.branchNameEn,
    this.address,
    this.isActive = true,
    this.locations = const [],
  });

  factory ImWarehouse.fromJson(Map<String, dynamic> json) => ImWarehouse(
        id: json['id'] as int,
        warehouseCode: json['warehouse_code'] ?? '',
        warehouseNameTh: json['warehouse_name_th'] ?? '',
        warehouseNameEn: json['warehouse_name_en'],
        branchId: json['branch_id'],
        branchCode: json['branch_code'],
        branchNameTh: json['branch_name_th'],
        branchNameEn: json['branch_name_en'],
        address: json['address'],
        isActive: json['is_active'] ?? true,
        locations: (json['locations'] as List<dynamic>? ?? []).map((e) => ImLocation.fromJson(e)).toList(),
      );

  Map<String, dynamic> toJson() => {
        if (id != 0) 'id': id,
        'warehouse_code': warehouseCode,
        'warehouse_name_th': warehouseNameTh,
        'warehouse_name_en': warehouseNameEn,
        'branch_id': branchId,
        'address': address,
        'is_active': isActive,
        'locations': locations.map((e) => e.toJson()).toList(),
      };
}
