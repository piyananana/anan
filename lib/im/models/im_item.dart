// lib/im/models/im_item.dart

const List<String> imItemTypes = ['STOCK', 'SERVICE', 'NON_STOCK'];
const List<String> imCostingMethods = ['FIFO', 'AVG', 'STANDARD', 'SPECIFIC'];

const Map<String, String> imItemTypeLabelsTh = {
  'STOCK': 'สินค้าคงคลัง (นับสต็อก)',
  'SERVICE': 'บริการ (ไม่นับสต็อก)',
  'NON_STOCK': 'สินค้าไม่นับสต็อก',
};
const Map<String, String> imItemTypeLabelsEn = {
  'STOCK': 'Stock item',
  'SERVICE': 'Service (no stock tracking)',
  'NON_STOCK': 'Non-stock item',
};
String imItemTypeLabel(String type, bool isEnglish) =>
    isEnglish ? (imItemTypeLabelsEn[type] ?? type) : (imItemTypeLabelsTh[type] ?? type);

const Map<String, String> imCostingMethodLabelsTh = {
  'FIFO': 'FIFO (เข้าก่อนออกก่อน)',
  'AVG': 'ถัวเฉลี่ยเคลื่อนที่ (Moving Average)',
  'STANDARD': 'ต้นทุนมาตรฐาน (Standard Cost)',
  'SPECIFIC': 'ต้นทุนเฉพาะเจาะจง (ตาม Serial)',
};
const Map<String, String> imCostingMethodLabelsEn = {
  'FIFO': 'FIFO',
  'AVG': 'Moving Average',
  'STANDARD': 'Standard Cost',
  'SPECIFIC': 'Specific Identification (by Serial)',
};
String imCostingMethodLabel(String method, bool isEnglish) =>
    isEnglish ? (imCostingMethodLabelsEn[method] ?? method) : (imCostingMethodLabelsTh[method] ?? method);

class ImUomConversion {
  final int? id;
  final int? itemId;
  final int uomId;
  final String? uomCode;
  final String? uomNameTh;
  final String? uomNameEn;
  final double conversionFactor;
  final String? barcode;
  final bool isPurchaseDefault;
  final bool isSalesDefault;
  final bool isProductionDefault;
  final bool isCountDefault;
  final bool isReportDefault;
  final bool allowPurchase;
  final bool allowSales;
  final bool allowProduction;
  final bool isActive;

  const ImUomConversion({
    this.id,
    this.itemId,
    required this.uomId,
    this.uomCode,
    this.uomNameTh,
    this.uomNameEn,
    this.conversionFactor = 1,
    this.barcode,
    this.isPurchaseDefault = false,
    this.isSalesDefault = false,
    this.isProductionDefault = false,
    this.isCountDefault = false,
    this.isReportDefault = false,
    this.allowPurchase = true,
    this.allowSales = true,
    this.allowProduction = true,
    this.isActive = true,
  });

  String displayName(bool isEnglish) =>
      isEnglish && (uomNameEn ?? '').isNotEmpty ? uomNameEn! : (uomNameTh ?? uomNameEn ?? '');

  ImUomConversion copyWith({
    bool? isPurchaseDefault, bool? isSalesDefault, bool? isProductionDefault, bool? isCountDefault, bool? isReportDefault,
  }) => ImUomConversion(
        id: id, itemId: itemId, uomId: uomId, uomCode: uomCode, uomNameTh: uomNameTh, uomNameEn: uomNameEn,
        conversionFactor: conversionFactor, barcode: barcode,
        isPurchaseDefault: isPurchaseDefault ?? this.isPurchaseDefault,
        isSalesDefault: isSalesDefault ?? this.isSalesDefault,
        isProductionDefault: isProductionDefault ?? this.isProductionDefault,
        isCountDefault: isCountDefault ?? this.isCountDefault,
        isReportDefault: isReportDefault ?? this.isReportDefault,
        allowPurchase: allowPurchase, allowSales: allowSales, allowProduction: allowProduction, isActive: isActive,
      );

  factory ImUomConversion.fromJson(Map<String, dynamic> json) => ImUomConversion(
        id: json['id'],
        itemId: json['item_id'],
        uomId: json['uom_id'] as int,
        uomCode: json['uom_code'],
        uomNameTh: json['uom_name_th'],
        uomNameEn: json['uom_name_en'],
        conversionFactor: double.tryParse(json['conversion_factor']?.toString() ?? '') ?? 1,
        barcode: json['barcode'],
        isPurchaseDefault: json['is_purchase_default'] ?? false,
        isSalesDefault: json['is_sales_default'] ?? false,
        isProductionDefault: json['is_production_default'] ?? false,
        isCountDefault: json['is_count_default'] ?? false,
        isReportDefault: json['is_report_default'] ?? false,
        allowPurchase: json['allow_purchase'] ?? true,
        allowSales: json['allow_sales'] ?? true,
        allowProduction: json['allow_production'] ?? true,
        isActive: json['is_active'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'uom_id': uomId,
        'conversion_factor': conversionFactor,
        'barcode': barcode,
        'is_purchase_default': isPurchaseDefault,
        'is_sales_default': isSalesDefault,
        'is_production_default': isProductionDefault,
        'is_count_default': isCountDefault,
        'is_report_default': isReportDefault,
        'allow_purchase': allowPurchase,
        'allow_sales': allowSales,
        'allow_production': allowProduction,
        'is_active': isActive,
      };
}

class ImItemWarehouse {
  final int? id;
  final int? itemId;
  final int warehouseId;
  final String? warehouseCode;
  final String? warehouseNameTh;
  final String? warehouseNameEn;
  final double minStockQty;
  final double maxStockQty;
  final double reorderPoint;
  final int? defaultLocationId;
  final String? defaultLocationCode;

  const ImItemWarehouse({
    this.id,
    this.itemId,
    required this.warehouseId,
    this.warehouseCode,
    this.warehouseNameTh,
    this.warehouseNameEn,
    this.minStockQty = 0,
    this.maxStockQty = 0,
    this.reorderPoint = 0,
    this.defaultLocationId,
    this.defaultLocationCode,
  });

  factory ImItemWarehouse.fromJson(Map<String, dynamic> json) => ImItemWarehouse(
        id: json['id'],
        itemId: json['item_id'],
        warehouseId: json['warehouse_id'] as int,
        warehouseCode: json['warehouse_code'],
        warehouseNameTh: json['warehouse_name_th'],
        warehouseNameEn: json['warehouse_name_en'],
        minStockQty: double.tryParse(json['min_stock_qty']?.toString() ?? '') ?? 0,
        maxStockQty: double.tryParse(json['max_stock_qty']?.toString() ?? '') ?? 0,
        reorderPoint: double.tryParse(json['reorder_point']?.toString() ?? '') ?? 0,
        defaultLocationId: json['default_location_id'],
        defaultLocationCode: json['default_location_code'],
      );

  Map<String, dynamic> toJson() => {
        'warehouse_id': warehouseId,
        'min_stock_qty': minStockQty,
        'max_stock_qty': maxStockQty,
        'reorder_point': reorderPoint,
        'default_location_id': defaultLocationId,
      };
}

class ImItem {
  final int? id;
  final String itemCode;
  final String? oldItemCode;
  final String? barcode;
  final String itemNameTh;
  final String? itemNameEn;
  final String? description;
  final int? categoryId;
  final String? categoryCode;
  final String? categoryName;
  final String itemType;
  final int? baseUomId;
  final String? baseUomCode;
  final String? baseUomNameTh;
  final String? baseUomNameEn;
  final String costingMethod;
  final double standardCost;
  final bool isPurchaseItem;
  final bool isSalesItem;
  final bool isManufactured;
  final bool isLotTracked;
  final bool isSerialTracked;
  final int? shelfLifeDays;
  final int? defaultWarehouseId;
  final String? defaultWarehouseCode;
  final String? defaultWarehouseNameTh;
  final String? defaultWarehouseNameEn;
  final double minStockQty;
  final double maxStockQty;
  final double reorderPoint;
  final String defaultVatType;
  final int? inventoryAccountId;
  final String? inventoryAccountCode;
  final String? inventoryAccountName;
  final int? cogsAccountId;
  final String? cogsAccountCode;
  final String? cogsAccountName;
  final int? revenueAccountId;
  final String? revenueAccountCode;
  final String? revenueAccountName;
  final int? expenseAccountId;
  final String? expenseAccountCode;
  final String? expenseAccountName;
  final String? accountingMode; // null = ตามหมวดสินค้า → คลัง → ค่าเริ่มต้น
  final int? purchasesAccountId;
  final String? purchasesAccountCode;
  final String? purchasesAccountName;
  final bool isActive;
  final bool isCodeAutoGenerated;
  final List<ImUomConversion> uomConversions;
  // หน่วยหลักล็อกเมื่อสินค้าถูกใช้แล้ว (มาจาก fetchRow เท่านั้น) + ใช้ที่ไหนบ้าง
  final bool baseUomLocked;
  final List<String> baseUomUsedIn;
  final List<ImItemWarehouse> itemWarehouses;
  // มาจาก GET im_item?with_stock=1 เท่านั้น (หน้าจอข้อมูลสินค้า) — null = ไม่ได้ขอยอด
  final double? onHandQty;
  final double? onHandValue;
  final bool belowReorder;

  const ImItem({
    this.id,
    required this.itemCode,
    this.oldItemCode,
    this.barcode,
    required this.itemNameTh,
    this.itemNameEn,
    this.description,
    this.categoryId,
    this.categoryCode,
    this.categoryName,
    this.itemType = 'STOCK',
    this.baseUomId,
    this.baseUomCode,
    this.baseUomNameTh,
    this.baseUomNameEn,
    this.costingMethod = 'AVG',
    this.standardCost = 0,
    this.isPurchaseItem = true,
    this.isSalesItem = true,
    this.isManufactured = false,
    this.isLotTracked = false,
    this.isSerialTracked = false,
    this.shelfLifeDays,
    this.defaultWarehouseId,
    this.defaultWarehouseCode,
    this.defaultWarehouseNameTh,
    this.defaultWarehouseNameEn,
    this.minStockQty = 0,
    this.maxStockQty = 0,
    this.reorderPoint = 0,
    this.defaultVatType = 'VAT7',
    this.inventoryAccountId, this.inventoryAccountCode, this.inventoryAccountName,
    this.cogsAccountId, this.cogsAccountCode, this.cogsAccountName,
    this.revenueAccountId, this.revenueAccountCode, this.revenueAccountName,
    this.expenseAccountId, this.expenseAccountCode, this.expenseAccountName,
    this.accountingMode,
    this.purchasesAccountId, this.purchasesAccountCode, this.purchasesAccountName,
    this.isActive = true,
    this.isCodeAutoGenerated = false,
    this.uomConversions = const [],
    this.baseUomLocked = false,
    this.baseUomUsedIn = const [],
    this.itemWarehouses = const [],
    this.onHandQty,
    this.onHandValue,
    this.belowReorder = false,
  });

  factory ImItem.fromJson(Map<String, dynamic> json) => ImItem(
        id: json['id'],
        itemCode: json['item_code'] ?? '',
        oldItemCode: json['old_item_code'],
        barcode: json['barcode'],
        itemNameTh: json['item_name_th'] ?? '',
        itemNameEn: json['item_name_en'],
        description: json['description'],
        categoryId: json['category_id'],
        categoryCode: json['category_code'],
        categoryName: json['category_name'],
        itemType: json['item_type'] ?? 'STOCK',
        baseUomId: json['base_uom_id'],
        baseUomCode: json['base_uom_code'],
        baseUomNameTh: json['base_uom_name_th'],
        baseUomNameEn: json['base_uom_name_en'],
        costingMethod: json['costing_method'] ?? 'AVG',
        standardCost: double.tryParse(json['standard_cost']?.toString() ?? '') ?? 0,
        isPurchaseItem: json['is_purchase_item'] ?? true,
        isSalesItem: json['is_sales_item'] ?? true,
        isManufactured: json['is_manufactured'] ?? false,
        isLotTracked: json['is_lot_tracked'] ?? false,
        isSerialTracked: json['is_serial_tracked'] ?? false,
        shelfLifeDays: json['shelf_life_days'],
        defaultWarehouseId: json['default_warehouse_id'],
        defaultWarehouseCode: json['default_warehouse_code'],
        defaultWarehouseNameTh: json['default_warehouse_name_th'],
        defaultWarehouseNameEn: json['default_warehouse_name_en'],
        minStockQty: double.tryParse(json['min_stock_qty']?.toString() ?? '') ?? 0,
        maxStockQty: double.tryParse(json['max_stock_qty']?.toString() ?? '') ?? 0,
        reorderPoint: double.tryParse(json['reorder_point']?.toString() ?? '') ?? 0,
        defaultVatType: json['default_vat_type'] ?? 'VAT7',
        inventoryAccountId: json['inventory_account_id'],
        inventoryAccountCode: json['inventory_account_code'],
        inventoryAccountName: json['inventory_account_name'],
        cogsAccountId: json['cogs_account_id'],
        cogsAccountCode: json['cogs_account_code'],
        cogsAccountName: json['cogs_account_name'],
        revenueAccountId: json['revenue_account_id'],
        revenueAccountCode: json['revenue_account_code'],
        revenueAccountName: json['revenue_account_name'],
        expenseAccountId: json['expense_account_id'],
        expenseAccountCode: json['expense_account_code'],
        expenseAccountName: json['expense_account_name'],
        accountingMode: json['accounting_mode'],
        purchasesAccountId: json['purchases_account_id'],
        purchasesAccountCode: json['purchases_account_code'],
        purchasesAccountName: json['purchases_account_name'],
        isActive: json['is_active'] ?? true,
        isCodeAutoGenerated: json['is_code_auto_generated'] ?? false,
        uomConversions: (json['uom_conversions'] as List<dynamic>? ?? []).map((e) => ImUomConversion.fromJson(e)).toList(),
        baseUomLocked: json['base_uom_locked'] ?? false,
        baseUomUsedIn: (json['base_uom_used_in'] as List<dynamic>? ?? []).map((e) => '$e').toList(),
        itemWarehouses: (json['item_warehouses'] as List<dynamic>? ?? []).map((e) => ImItemWarehouse.fromJson(e)).toList(),
        onHandQty: json['on_hand_qty'] == null ? null : double.tryParse('${json['on_hand_qty']}'),
        onHandValue: json['on_hand_value'] == null ? null : double.tryParse('${json['on_hand_value']}'),
        belowReorder: json['below_reorder'] == true,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'item_code': itemCode,
        'old_item_code': oldItemCode,
        'barcode': barcode,
        'item_name_th': itemNameTh,
        'item_name_en': itemNameEn,
        'description': description,
        'category_id': categoryId,
        'item_type': itemType,
        'base_uom_id': baseUomId,
        'costing_method': costingMethod,
        'standard_cost': standardCost,
        'is_purchase_item': isPurchaseItem,
        'is_sales_item': isSalesItem,
        'is_manufactured': isManufactured,
        'is_lot_tracked': isLotTracked,
        'is_serial_tracked': isSerialTracked,
        'shelf_life_days': shelfLifeDays,
        'default_warehouse_id': defaultWarehouseId,
        'min_stock_qty': minStockQty,
        'max_stock_qty': maxStockQty,
        'reorder_point': reorderPoint,
        'default_vat_type': defaultVatType,
        'inventory_account_id': inventoryAccountId,
        'cogs_account_id': cogsAccountId,
        'revenue_account_id': revenueAccountId,
        'expense_account_id': expenseAccountId,
        'accounting_mode': accountingMode,
        'purchases_account_id': purchasesAccountId,
        'is_active': isActive,
        'uom_conversions': uomConversions.map((e) => e.toJson()).toList(),
        'item_warehouses': itemWarehouses.map((e) => e.toJson()).toList(),
      };
}

// หน่วยที่เลือกได้ในบรรทัดเอกสารของสินค้า (GET /im_item/:id/uoms?purpose=) — factor = จำนวนหน่วยหลักต่อ 1 หน่วยนี้
class ImItemUomOption {
  final int uomId;
  final String uomCode;
  final String? uomNameTh;
  final String? uomNameEn;
  final double factor;
  final int decimalPlaces;
  final String uomDimension;
  final String source; // BASE | ITEM | STANDARD
  final String? barcode;

  const ImItemUomOption({
    required this.uomId,
    required this.uomCode,
    this.uomNameTh,
    this.uomNameEn,
    this.factor = 1,
    this.decimalPlaces = 0,
    this.uomDimension = 'COUNT',
    this.source = 'BASE',
    this.barcode,
  });

  bool get isBase => source == 'BASE';

  String displayName(bool isEnglish) {
    final n = isEnglish && (uomNameEn ?? '').isNotEmpty ? uomNameEn! : (uomNameTh ?? '');
    return n.isEmpty ? uomCode : n;
  }

  factory ImItemUomOption.fromJson(Map<String, dynamic> j) => ImItemUomOption(
        uomId: j['uom_id'] as int,
        uomCode: j['uom_code']?.toString() ?? '',
        uomNameTh: j['uom_name_th']?.toString(),
        uomNameEn: j['uom_name_en']?.toString(),
        factor: double.tryParse(j['factor']?.toString() ?? '') ?? 1,
        decimalPlaces: int.tryParse(j['decimal_places']?.toString() ?? '') ?? 0,
        uomDimension: j['uom_dimension']?.toString() ?? 'COUNT',
        source: j['source']?.toString() ?? 'BASE',
        barcode: j['barcode']?.toString(),
      );
}

class ImItemUoms {
  final int? baseUomId;
  final int? defaultUomId;
  final List<ImItemUomOption> units;

  const ImItemUoms({this.baseUomId, this.defaultUomId, this.units = const []});

  ImItemUomOption? byId(int? id) {
    for (final u in units) {
      if (u.uomId == id) return u;
    }
    return null;
  }

  factory ImItemUoms.fromJson(Map<String, dynamic> j) => ImItemUoms(
        baseUomId: j['base_uom_id'] as int?,
        defaultUomId: j['default_uom_id'] as int?,
        units: (j['units'] as List<dynamic>? ?? []).map((e) => ImItemUomOption.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

double _numOf(dynamic v) => double.tryParse('${v ?? ''}') ?? 0;
double? _numOrNull(dynamic v) => v == null ? null : double.tryParse('$v');

/// สรุปสต็อก/บัญชีของสินค้า — GET im_item/:id/summary (หน้าจอข้อมูลสินค้า แบบ B, 2026-11-25)
class ImItemStockRow {
  final int warehouseId;
  final String warehouseCode;
  final String? warehouseNameTh;
  final String? warehouseNameEn;
  final double qty;
  final double value;
  final bool hasSetting;
  final double? minStockQty;
  final double? maxStockQty;
  final double? reorderPoint;
  final String? defaultLocationCode;
  final bool belowReorder;

  const ImItemStockRow({
    required this.warehouseId, required this.warehouseCode, this.warehouseNameTh, this.warehouseNameEn,
    this.qty = 0, this.value = 0, this.hasSetting = false, this.minStockQty, this.maxStockQty, this.reorderPoint,
    this.defaultLocationCode, this.belowReorder = false,
  });

  String displayName(bool isEnglish) =>
      isEnglish && (warehouseNameEn ?? '').isNotEmpty ? warehouseNameEn! : (warehouseNameTh ?? '');

  factory ImItemStockRow.fromJson(Map<String, dynamic> j) => ImItemStockRow(
        warehouseId: j['warehouse_id'] as int,
        warehouseCode: j['warehouse_code'] ?? '',
        warehouseNameTh: j['warehouse_name_th'],
        warehouseNameEn: j['warehouse_name_en'],
        qty: _numOf(j['qty']),
        value: _numOf(j['value']),
        hasSetting: j['has_setting'] == true,
        minStockQty: _numOrNull(j['min_stock_qty']),
        maxStockQty: _numOrNull(j['max_stock_qty']),
        reorderPoint: _numOrNull(j['reorder_point']),
        defaultLocationCode: j['default_location_code'],
        belowReorder: j['below_reorder'] == true,
      );
}

/// บัญชี GL 1 รายการ (รหัส/ชื่อ)
class ImGlAccountRef {
  final int id;
  final String code;
  final String nameThai;
  final String nameEng;
  const ImGlAccountRef({required this.id, required this.code, this.nameThai = '', this.nameEng = ''});

  String name(bool isEnglish) => isEnglish && nameEng.isNotEmpty ? nameEng : nameThai;

  static ImGlAccountRef? fromJson(dynamic j) {
    if (j is! Map) return null;
    return ImGlAccountRef(
      id: j['account_id'] as int,
      code: j['account_code'] ?? '',
      nameThai: j['account_name_thai'] ?? '',
      nameEng: j['account_name_eng'] ?? '',
    );
  }
}

/// บัญชีแต่ละชั้นของ 1 ชนิด (inventory | cogs | revenue | purchases | expense) — หน้าจอเลือกชั้นที่ใช้จริงเอง
/// ลำดับ: สินค้า → หมวด → ค่าตั้งต้นประเภทเอกสาร (docType) → ค่าเริ่มต้นบริษัท; คลังที่ตั้งบัญชีเองใช้ก่อน (warehouseOverride)
class ImItemGlLayers {
  final String key;
  final ImGlAccountRef? item;
  final ImGlAccountRef? category;
  final bool docType;
  final ImGlAccountRef? company;
  final List<String> warehouseOverride;

  const ImItemGlLayers({required this.key, this.item, this.category, this.docType = false, this.company,
      this.warehouseOverride = const []});

  factory ImItemGlLayers.fromJson(Map<String, dynamic> j) => ImItemGlLayers(
        key: j['key'] ?? '',
        item: ImGlAccountRef.fromJson(j['item_account']),
        category: ImGlAccountRef.fromJson(j['category_account']),
        docType: j['doc_type'] == true,
        company: ImGlAccountRef.fromJson(j['company_account']),
        warehouseOverride: (j['warehouse_override'] as List<dynamic>? ?? []).map((e) => '$e').toList(),
      );
}

class ImItemSummary {
  final double totalQty;
  final double totalValue;
  final double avgCost;
  final int warehouseCount;
  final List<Map<String, dynamic>> belowWarehouses; // {warehouse_code, qty, reorder_point}
  final bool belowItemLevel;
  final double itemReorderPoint;
  final DateTime? lastMovementDate;
  final String? lastMovementDocNo;
  final String? lastMovementDocCode;
  final double? lastMovementQty;
  final List<ImItemStockRow> warehouses;
  final List<ImItemGlLayers> gl;

  const ImItemSummary({
    this.totalQty = 0, this.totalValue = 0, this.avgCost = 0, this.warehouseCount = 0,
    this.belowWarehouses = const [], this.belowItemLevel = false, this.itemReorderPoint = 0,
    this.lastMovementDate, this.lastMovementDocNo, this.lastMovementDocCode, this.lastMovementQty,
    this.warehouses = const [], this.gl = const [],
  });

  int get belowCount => belowWarehouses.length + (belowItemLevel ? 1 : 0);

  factory ImItemSummary.fromJson(Map<String, dynamic> j) {
    final lm = j['last_movement'] as Map<String, dynamic>?;
    DateTime? d;
    final ds = lm?['doc_date']?.toString();
    if (ds != null && ds.length >= 10) {
      final p = ds.substring(0, 10).split('-');
      if (p.length == 3) d = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    }
    return ImItemSummary(
      totalQty: _numOf(j['total_qty']),
      totalValue: _numOf(j['total_value']),
      avgCost: _numOf(j['avg_cost']),
      warehouseCount: (j['warehouse_count'] as num?)?.toInt() ?? 0,
      belowWarehouses: (j['below_warehouses'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      belowItemLevel: j['below_item_level'] == true,
      itemReorderPoint: _numOf(j['item_reorder_point']),
      lastMovementDate: d,
      lastMovementDocNo: lm?['doc_no'],
      lastMovementDocCode: lm?['doc_code'],
      lastMovementQty: _numOrNull(lm?['qty']),
      warehouses: (j['warehouses'] as List<dynamic>? ?? []).map((e) => ImItemStockRow.fromJson(e)).toList(),
      gl: (j['gl'] as List<dynamic>? ?? []).map((e) => ImItemGlLayers.fromJson(e)).toList(),
    );
  }
}
