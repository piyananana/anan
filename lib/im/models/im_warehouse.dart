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
  // Consignment-OUT — คลังนี้แทนสถานที่ของผู้รับฝากขาย สินค้าที่โอนเข้ามาด้วย TRF ยังเป็นของเราอยู่จนกว่าจะขายออก
  // ด้วย DLN ตามปกติ — เป็นแค่ flag เพื่อความชัดเจน/กรองรายงาน ไม่มีผลต่อการผ่านบัญชีใดๆ
  final bool isConsignee;
  // คลังหลัก — มีได้คลังเดียวทั้งบริษัท เอกสาร IM ใหม่ใช้เป็นคลังเริ่มต้น
  final bool isDefault;
  // บัญชีสต็อกของคลัง (ลำดับแรกของการหาบัญชีสต็อก) + โหมดบัญชีสินค้า (null = ค่าเริ่มต้นของบริษัท) + บัญชีซื้อ (Periodic)
  final int? inventoryAccountId;
  final String? inventoryAccountCode;
  final String? inventoryAccountName;
  final String? accountingMode;
  final int? purchasesAccountId;
  final String? purchasesAccountCode;
  final String? purchasesAccountName;
  // จาก GET im_warehouse?with_stock=1 เท่านั้น (หน้าจอคลังสินค้า)
  final int itemCount;
  final double totalValue;
  final int belowCount;

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
    this.isConsignee = false,
    this.isDefault = false,
    this.inventoryAccountId, this.inventoryAccountCode, this.inventoryAccountName,
    this.accountingMode,
    this.purchasesAccountId, this.purchasesAccountCode, this.purchasesAccountName,
    this.itemCount = 0,
    this.totalValue = 0,
    this.belowCount = 0,
  });

  String branchName(bool isEnglish) =>
      isEnglish && (branchNameEn ?? '').isNotEmpty ? branchNameEn! : (branchNameTh ?? '');

  // ชื่อคลังตามภาษาที่เลือก — ไม่มีชื่ออังกฤษใช้ชื่อไทย
  String warehouseName(bool isEnglish) =>
      isEnglish && (warehouseNameEn ?? '').isNotEmpty ? warehouseNameEn! : warehouseNameTh;

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
        isConsignee: json['is_consignee'] ?? false,
        isDefault: json['is_default'] ?? false,
        inventoryAccountId: json['inventory_account_id'],
        inventoryAccountCode: json['inventory_account_code'],
        inventoryAccountName: json['inventory_account_name'],
        accountingMode: json['accounting_mode'],
        purchasesAccountId: json['purchases_account_id'],
        purchasesAccountCode: json['purchases_account_code'],
        purchasesAccountName: json['purchases_account_name'],
        itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
        totalValue: double.tryParse('${json['total_value'] ?? 0}') ?? 0,
        belowCount: (json['below_count'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        if (id != 0) 'id': id,
        'warehouse_code': warehouseCode,
        'warehouse_name_th': warehouseNameTh,
        'warehouse_name_en': warehouseNameEn,
        'branch_id': branchId,
        'address': address,
        'is_active': isActive,
        'is_consignee': isConsignee,
        'is_default': isDefault,
        'inventory_account_id': inventoryAccountId,
        'accounting_mode': accountingMode,
        'purchases_account_id': purchasesAccountId,
      };
}

DateTime? _ymdOf(dynamic v) {
  final s = v?.toString();
  if (s == null || s.length < 10) return null;
  final p = s.substring(0, 10).split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// โซน (ตำแหน่งระดับบนสุด) ของคลัง
class ImWarehouseZone {
  final int id;
  final String code;
  final String? nameTh;
  final String? nameEn;
  final String? categoryCode;
  final int binCount;
  final int defaultItemCount;
  final bool isActive;
  const ImWarehouseZone({required this.id, required this.code, this.nameTh, this.nameEn, this.categoryCode,
      this.binCount = 0, this.defaultItemCount = 0, this.isActive = true});

  String displayName(bool isEnglish) => isEnglish && (nameEn ?? '').isNotEmpty ? nameEn! : (nameTh ?? '');

  factory ImWarehouseZone.fromJson(Map<String, dynamic> j) => ImWarehouseZone(
        id: j['id'] as int,
        code: j['location_code'] ?? '',
        nameTh: j['location_name'],
        nameEn: j['location_name_en'],
        categoryCode: j['category_code'],
        binCount: (j['bin_count'] as num?)?.toInt() ?? 0,
        defaultItemCount: (j['default_item_count'] as num?)?.toInt() ?? 0,
        isActive: j['is_active'] ?? true,
      );
}

/// สินค้า 1 รายการในคลัง (ยอด + จุดสั่งซื้อของคลัง)
class ImWarehouseItemStock {
  final int itemId;
  final String itemCode;
  final String itemNameTh;
  final String? itemNameEn;
  final String? uomCode;
  final String? uomNameTh;
  final String? uomNameEn;
  final double qty;
  final double value;
  final double? reorderPoint;
  final double? maxStockQty;
  final bool belowReorder;
  const ImWarehouseItemStock({required this.itemId, required this.itemCode, required this.itemNameTh, this.itemNameEn,
      this.uomCode, this.uomNameTh, this.uomNameEn, this.qty = 0, this.value = 0, this.reorderPoint, this.maxStockQty,
      this.belowReorder = false});

  String displayName(bool isEnglish) => isEnglish && (itemNameEn ?? '').isNotEmpty ? itemNameEn! : itemNameTh;
  String uomName(bool isEnglish) => isEnglish && (uomNameEn ?? '').isNotEmpty ? uomNameEn! : (uomNameTh ?? uomCode ?? '');

  factory ImWarehouseItemStock.fromJson(Map<String, dynamic> j) => ImWarehouseItemStock(
        itemId: j['item_id'] as int,
        itemCode: j['item_code'] ?? '',
        itemNameTh: j['item_name_th'] ?? '',
        itemNameEn: j['item_name_en'],
        uomCode: j['uom_code'],
        uomNameTh: j['uom_name_th'],
        uomNameEn: j['uom_name_en'],
        qty: double.tryParse('${j['qty'] ?? 0}') ?? 0,
        value: double.tryParse('${j['value'] ?? 0}') ?? 0,
        reorderPoint: j['reorder_point'] == null ? null : double.tryParse('${j['reorder_point']}'),
        maxStockQty: j['max_stock_qty'] == null ? null : double.tryParse('${j['max_stock_qty']}'),
        belowReorder: j['below_reorder'] == true,
      );
}

/// สรุปคลัง — GET im_warehouse/:id/summary
class ImWarehouseSummary {
  final int itemCount;
  final int settingCount;
  final double totalValue;
  final int belowCount;
  final DateTime? lastMovementDate;
  final String? lastMovementDocNo;
  final String? lastMovementDocCode;
  final int zoneCount;
  final int binCount;
  final List<ImWarehouseZone> zones;
  final List<ImWarehouseItemStock> items;
  const ImWarehouseSummary({this.itemCount = 0, this.settingCount = 0, this.totalValue = 0, this.belowCount = 0,
      this.lastMovementDate, this.lastMovementDocNo, this.lastMovementDocCode, this.zoneCount = 0, this.binCount = 0,
      this.zones = const [], this.items = const []});

  factory ImWarehouseSummary.fromJson(Map<String, dynamic> j) {
    final lm = j['last_movement'] as Map<String, dynamic>?;
    return ImWarehouseSummary(
      itemCount: (j['item_count'] as num?)?.toInt() ?? 0,
      settingCount: (j['setting_count'] as num?)?.toInt() ?? 0,
      totalValue: double.tryParse('${j['total_value'] ?? 0}') ?? 0,
      belowCount: (j['below_count'] as num?)?.toInt() ?? 0,
      lastMovementDate: _ymdOf(lm?['doc_date']),
      lastMovementDocNo: lm?['doc_no'],
      lastMovementDocCode: lm?['doc_code'],
      zoneCount: (j['zone_count'] as num?)?.toInt() ?? 0,
      binCount: (j['bin_count'] as num?)?.toInt() ?? 0,
      zones: (j['zones'] as List<dynamic>? ?? []).map((e) => ImWarehouseZone.fromJson(e)).toList(),
      items: (j['items'] as List<dynamic>? ?? []).map((e) => ImWarehouseItemStock.fromJson(e)).toList(),
    );
  }
}
