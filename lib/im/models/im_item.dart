// lib/im/models/im_item.dart

const List<String> imItemTypes = ['STOCK', 'SERVICE', 'NON_STOCK'];
const List<String> imCostingMethods = ['FIFO', 'AVG', 'STANDARD'];

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
};
const Map<String, String> imCostingMethodLabelsEn = {
  'FIFO': 'FIFO',
  'AVG': 'Moving Average',
  'STANDARD': 'Standard Cost',
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
  });

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
      );

  Map<String, dynamic> toJson() => {
        'uom_id': uomId,
        'conversion_factor': conversionFactor,
        'barcode': barcode,
        'is_purchase_default': isPurchaseDefault,
        'is_sales_default': isSalesDefault,
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
  final bool isActive;
  final bool isCodeAutoGenerated;
  final List<ImUomConversion> uomConversions;
  final List<ImItemWarehouse> itemWarehouses;

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
    this.isActive = true,
    this.isCodeAutoGenerated = false,
    this.uomConversions = const [],
    this.itemWarehouses = const [],
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
        isActive: json['is_active'] ?? true,
        isCodeAutoGenerated: json['is_code_auto_generated'] ?? false,
        uomConversions: (json['uom_conversions'] as List<dynamic>? ?? []).map((e) => ImUomConversion.fromJson(e)).toList(),
        itemWarehouses: (json['item_warehouses'] as List<dynamic>? ?? []).map((e) => ImItemWarehouse.fromJson(e)).toList(),
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
        'is_active': isActive,
        'uom_conversions': uomConversions.map((e) => e.toJson()).toList(),
        'item_warehouses': itemWarehouses.map((e) => e.toJson()).toList(),
      };
}
