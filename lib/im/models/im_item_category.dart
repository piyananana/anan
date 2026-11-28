// lib/im/models/im_item_category.dart

const List<String> imCategoryTypes = ['HEADER', 'CATEGORY'];

String imCategoryTypeLabel(String type, bool isEnglish) {
  if (type == 'HEADER') return isEnglish ? 'Header' : 'หัวข้อ';
  return isEnglish ? 'Category' : 'หมวดหมู่';
}

class ImItemCategory {
  final int id;
  final String categoryCode;
  final String categoryNameTh;
  final String? categoryNameEn;
  final int? parentId;
  final int level;
  final String categoryType; // 'HEADER' / 'CATEGORY'
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
  final int? varianceAccountId;
  final String? varianceAccountCode;
  final String? varianceAccountName;
  final int? wipAccountId;
  final String? wipAccountCode;
  final String? wipAccountName;
  final String? accountingMode; // null = ตามคลัง → ค่าเริ่มต้น
  final int? purchasesAccountId;
  final String? purchasesAccountCode;
  final String? purchasesAccountName;
  final bool isActive;
  final bool isAutoNumber;
  final String runningPrefix;
  final String runningSeparator;
  final String runningSuffixDate;
  final int runningLength;
  final int runningNextNumber;
  // จาก GET im_item_category?with_usage=1 เท่านั้น (หน้าจอหมวดหมู่) — จำนวนสินค้าที่อยู่ในหมวดนี้โดยตรง
  final int itemCount;

  const ImItemCategory({
    required this.id,
    required this.categoryCode,
    required this.categoryNameTh,
    this.categoryNameEn,
    this.parentId,
    this.level = 1,
    this.categoryType = 'CATEGORY',
    this.inventoryAccountId, this.inventoryAccountCode, this.inventoryAccountName,
    this.cogsAccountId, this.cogsAccountCode, this.cogsAccountName,
    this.revenueAccountId, this.revenueAccountCode, this.revenueAccountName,
    this.expenseAccountId, this.expenseAccountCode, this.expenseAccountName,
    this.varianceAccountId, this.varianceAccountCode, this.varianceAccountName,
    this.wipAccountId, this.wipAccountCode, this.wipAccountName,
    this.accountingMode,
    this.purchasesAccountId, this.purchasesAccountCode, this.purchasesAccountName,
    this.isActive = true,
    this.isAutoNumber = false,
    this.runningPrefix = 'ITEM',
    this.runningSeparator = '-',
    this.runningSuffixDate = '',
    this.runningLength = 4,
    this.runningNextNumber = 1,
    this.itemCount = 0,
  });

  String displayName(bool isEnglish) => isEnglish && (categoryNameEn ?? '').isNotEmpty ? categoryNameEn! : categoryNameTh;

  factory ImItemCategory.fromJson(Map<String, dynamic> json) => ImItemCategory(
        id: json['id'] as int,
        categoryCode: json['category_code'] ?? '',
        categoryNameTh: json['category_name_th'] ?? '',
        categoryNameEn: json['category_name_en'],
        parentId: json['parent_id'],
        level: json['level'] ?? 1,
        categoryType: json['category_type'] ?? 'CATEGORY',
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
        varianceAccountId: json['variance_account_id'],
        varianceAccountCode: json['variance_account_code'],
        varianceAccountName: json['variance_account_name'],
        wipAccountId: json['wip_account_id'],
        wipAccountCode: json['wip_account_code'],
        wipAccountName: json['wip_account_name'],
        accountingMode: json['accounting_mode'],
        purchasesAccountId: json['purchases_account_id'],
        purchasesAccountCode: json['purchases_account_code'],
        purchasesAccountName: json['purchases_account_name'],
        isActive: json['is_active'] ?? true,
        isAutoNumber: json['is_auto_number'] ?? false,
        runningPrefix: json['running_prefix'] ?? 'ITEM',
        runningSeparator: json['running_separator'] ?? '-',
        runningSuffixDate: json['running_suffix_date'] ?? '',
        runningLength: json['running_length'] ?? 4,
        runningNextNumber: json['running_next_number'] ?? 1,
        itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        if (id != 0) 'id': id,
        'category_code': categoryCode,
        'category_name_th': categoryNameTh,
        'category_name_en': categoryNameEn,
        'parent_id': parentId,
        'category_type': categoryType,
        'inventory_account_id': inventoryAccountId,
        'cogs_account_id': cogsAccountId,
        'revenue_account_id': revenueAccountId,
        'expense_account_id': expenseAccountId,
        'variance_account_id': varianceAccountId,
        'wip_account_id': wipAccountId,
        'accounting_mode': accountingMode,
        'purchases_account_id': purchasesAccountId,
        'is_active': isActive,
        'is_auto_number': isAutoNumber,
        'running_prefix': runningPrefix,
        'running_separator': runningSeparator,
        'running_suffix_date': runningSuffixDate,
        'running_length': runningLength,
        'running_next_number': runningNextNumber,
      };
}

/// บัญชีที่ใช้เมื่อหมวดเว้นว่าง ต่อชนิด (inventory | cogs | revenue | purchases | expense)
class ImCategoryGlDefault {
  final String key;
  final bool docType;
  final String? companyCode;
  final String? companyNameTh;
  final String? companyNameEn;
  const ImCategoryGlDefault({required this.key, this.docType = false, this.companyCode, this.companyNameTh, this.companyNameEn});

  factory ImCategoryGlDefault.fromJson(Map<String, dynamic> j) {
    final c = j['company_account'] as Map<String, dynamic>?;
    return ImCategoryGlDefault(
      key: j['key'] ?? '',
      docType: j['doc_type'] == true,
      companyCode: c?['account_code'],
      companyNameTh: c?['account_name_thai'],
      companyNameEn: c?['account_name_eng'],
    );
  }
}

class ImCategoryItemRow {
  final int id;
  final String itemCode;
  final String itemNameTh;
  final String? itemNameEn;
  final String itemType;
  final bool isActive;
  final String? uomCode;
  final String? uomNameTh;
  final String? uomNameEn;
  final String? categoryCode;
  final double onHand;
  const ImCategoryItemRow({required this.id, required this.itemCode, required this.itemNameTh, this.itemNameEn,
      this.itemType = 'STOCK', this.isActive = true, this.uomCode, this.uomNameTh, this.uomNameEn, this.categoryCode, this.onHand = 0});

  String displayName(bool isEnglish) => isEnglish && (itemNameEn ?? '').isNotEmpty ? itemNameEn! : itemNameTh;
  String uomName(bool isEnglish) => isEnglish && (uomNameEn ?? '').isNotEmpty ? uomNameEn! : (uomNameTh ?? uomCode ?? '');

  factory ImCategoryItemRow.fromJson(Map<String, dynamic> j) => ImCategoryItemRow(
        id: j['id'] as int,
        itemCode: j['item_code'] ?? '',
        itemNameTh: j['item_name_th'] ?? '',
        itemNameEn: j['item_name_en'],
        itemType: j['item_type'] ?? 'STOCK',
        isActive: j['is_active'] ?? true,
        uomCode: j['uom_code'],
        uomNameTh: j['uom_name_th'],
        uomNameEn: j['uom_name_en'],
        categoryCode: j['category_code'],
        onHand: double.tryParse('${j['on_hand'] ?? 0}') ?? 0,
      );
}

/// สรุปหมวดหมู่ — GET im_item_category/:id/summary (id 0 = เฉพาะ glDefaults)
class ImCategorySummary {
  final int itemCount;
  final int activeCount;
  final int inactiveCount;
  final double stockValue;
  final int childCount;
  final List<String> locations; // "W01 Z01"
  final List<ImCategoryItemRow> items;
  final List<ImCategoryGlDefault> glDefaults;
  const ImCategorySummary({this.itemCount = 0, this.activeCount = 0, this.inactiveCount = 0, this.stockValue = 0,
      this.childCount = 0, this.locations = const [], this.items = const [], this.glDefaults = const []});

  factory ImCategorySummary.fromJson(Map<String, dynamic> j) => ImCategorySummary(
        itemCount: (j['item_count'] as num?)?.toInt() ?? 0,
        activeCount: (j['active_count'] as num?)?.toInt() ?? 0,
        inactiveCount: (j['inactive_count'] as num?)?.toInt() ?? 0,
        stockValue: double.tryParse('${j['stock_value'] ?? 0}') ?? 0,
        childCount: (j['child_count'] as num?)?.toInt() ?? 0,
        locations: [for (final l in (j['locations'] as List<dynamic>? ?? [])) '${l['warehouse_code']} ${l['location_code']}'],
        items: (j['items'] as List<dynamic>? ?? []).map((e) => ImCategoryItemRow.fromJson(e)).toList(),
        glDefaults: (j['gl_defaults'] as List<dynamic>? ?? []).map((e) => ImCategoryGlDefault.fromJson(e)).toList(),
      );
}
