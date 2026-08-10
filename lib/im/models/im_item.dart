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

class ImItem {
  final int? id;
  final String itemCode;
  final String? barcode;
  final String itemNameTh;
  final String? itemNameEn;
  final String? description;
  final int? categoryId;
  final String? categoryCode;
  final String? categoryName;
  final String itemType;
  final int? baseUomId;
  final String costingMethod;
  final double standardCost;
  final bool isPurchaseItem;
  final bool isSalesItem;
  final bool isManufactured;
  final bool isLotTracked;
  final bool isSerialTracked;
  final int? shelfLifeDays;
  final int? defaultWarehouseId;
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

  const ImItem({
    this.id,
    required this.itemCode,
    this.barcode,
    required this.itemNameTh,
    this.itemNameEn,
    this.description,
    this.categoryId,
    this.categoryCode,
    this.categoryName,
    this.itemType = 'STOCK',
    this.baseUomId,
    this.costingMethod = 'AVG',
    this.standardCost = 0,
    this.isPurchaseItem = true,
    this.isSalesItem = true,
    this.isManufactured = false,
    this.isLotTracked = false,
    this.isSerialTracked = false,
    this.shelfLifeDays,
    this.defaultWarehouseId,
    this.minStockQty = 0,
    this.maxStockQty = 0,
    this.reorderPoint = 0,
    this.defaultVatType = 'VAT7',
    this.inventoryAccountId, this.inventoryAccountCode, this.inventoryAccountName,
    this.cogsAccountId, this.cogsAccountCode, this.cogsAccountName,
    this.revenueAccountId, this.revenueAccountCode, this.revenueAccountName,
    this.expenseAccountId, this.expenseAccountCode, this.expenseAccountName,
    this.isActive = true,
  });

  factory ImItem.fromJson(Map<String, dynamic> json) => ImItem(
        id: json['id'],
        itemCode: json['item_code'] ?? '',
        barcode: json['barcode'],
        itemNameTh: json['item_name_th'] ?? '',
        itemNameEn: json['item_name_en'],
        description: json['description'],
        categoryId: json['category_id'],
        categoryCode: json['category_code'],
        categoryName: json['category_name'],
        itemType: json['item_type'] ?? 'STOCK',
        baseUomId: json['base_uom_id'],
        costingMethod: json['costing_method'] ?? 'AVG',
        standardCost: double.tryParse(json['standard_cost']?.toString() ?? '') ?? 0,
        isPurchaseItem: json['is_purchase_item'] ?? true,
        isSalesItem: json['is_sales_item'] ?? true,
        isManufactured: json['is_manufactured'] ?? false,
        isLotTracked: json['is_lot_tracked'] ?? false,
        isSerialTracked: json['is_serial_tracked'] ?? false,
        shelfLifeDays: json['shelf_life_days'],
        defaultWarehouseId: json['default_warehouse_id'],
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
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'item_code': itemCode,
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
      };
}
