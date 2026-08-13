// lib/im/models/im_warehouse.dart
//
// im_location (โซน/แถว/ช่องเก็บ) is a standalone tree master — see im_location.dart /
// ImLocationScreen — no longer nested inside this model.

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
      );

  Map<String, dynamic> toJson() => {
        if (id != 0) 'id': id,
        'warehouse_code': warehouseCode,
        'warehouse_name_th': warehouseNameTh,
        'warehouse_name_en': warehouseNameEn,
        'branch_id': branchId,
        'address': address,
        'is_active': isActive,
      };
}
