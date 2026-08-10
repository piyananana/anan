// lib/im/models/im_item_category.dart

class ImItemCategory {
  final int id;
  final String categoryCode;
  final String categoryNameTh;
  final String? categoryNameEn;
  final int? parentId;
  final int level;
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
  final bool isActive;

  const ImItemCategory({
    required this.id,
    required this.categoryCode,
    required this.categoryNameTh,
    this.categoryNameEn,
    this.parentId,
    this.level = 1,
    this.inventoryAccountId, this.inventoryAccountCode, this.inventoryAccountName,
    this.cogsAccountId, this.cogsAccountCode, this.cogsAccountName,
    this.revenueAccountId, this.revenueAccountCode, this.revenueAccountName,
    this.expenseAccountId, this.expenseAccountCode, this.expenseAccountName,
    this.varianceAccountId, this.varianceAccountCode, this.varianceAccountName,
    this.wipAccountId, this.wipAccountCode, this.wipAccountName,
    this.isActive = true,
  });

  factory ImItemCategory.fromJson(Map<String, dynamic> json) => ImItemCategory(
        id: json['id'] as int,
        categoryCode: json['category_code'] ?? '',
        categoryNameTh: json['category_name_th'] ?? '',
        categoryNameEn: json['category_name_en'],
        parentId: json['parent_id'],
        level: json['level'] ?? 1,
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
        isActive: json['is_active'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        if (id != 0) 'id': id,
        'category_code': categoryCode,
        'category_name_th': categoryNameTh,
        'category_name_en': categoryNameEn,
        'parent_id': parentId,
        'inventory_account_id': inventoryAccountId,
        'cogs_account_id': cogsAccountId,
        'revenue_account_id': revenueAccountId,
        'expense_account_id': expenseAccountId,
        'variance_account_id': varianceAccountId,
        'wip_account_id': wipAccountId,
        'is_active': isActive,
      };
}
