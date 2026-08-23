// lib/im/models/im_accounting_setting.dart — โหมดบัญชีสินค้าระดับบริษัท (PERPETUAL/PERIODIC)

class ImAccountingSetting {
  final int? id;
  final String inventoryAccountingMode; // 'PERPETUAL' | 'PERIODIC'
  final int? modeEffectivePeriodId;
  final String? modeEffectivePeriodName;
  final int? inventoryAccountId;
  final String? inventoryAccountCode;
  final String? inventoryAccountName;
  final int? cogsAccountId;
  final String? cogsAccountCode;
  final String? cogsAccountName;
  final int? purchasesAccountId;
  final String? purchasesAccountCode;
  final String? purchasesAccountName;
  final int? closingGlDocId;
  final String? closingDocCode;
  final String? closingDocNameThai;
  final String? closingDocNameEng;

  const ImAccountingSetting({
    this.id,
    this.inventoryAccountingMode = 'PERPETUAL',
    this.modeEffectivePeriodId,
    this.modeEffectivePeriodName,
    this.inventoryAccountId, this.inventoryAccountCode, this.inventoryAccountName,
    this.cogsAccountId, this.cogsAccountCode, this.cogsAccountName,
    this.purchasesAccountId, this.purchasesAccountCode, this.purchasesAccountName,
    this.closingGlDocId, this.closingDocCode, this.closingDocNameThai, this.closingDocNameEng,
  });

  bool get isPeriodic => inventoryAccountingMode == 'PERIODIC';

  factory ImAccountingSetting.fromJson(Map<String, dynamic> json) => ImAccountingSetting(
        id: json['id'],
        inventoryAccountingMode: json['inventory_accounting_mode'] ?? 'PERPETUAL',
        modeEffectivePeriodId: json['mode_effective_period_id'],
        modeEffectivePeriodName: json['mode_effective_period_name'],
        inventoryAccountId: json['inventory_account_id'],
        inventoryAccountCode: json['inventory_account_code'],
        inventoryAccountName: json['inventory_account_name'],
        cogsAccountId: json['cogs_account_id'],
        cogsAccountCode: json['cogs_account_code'],
        cogsAccountName: json['cogs_account_name'],
        purchasesAccountId: json['purchases_account_id'],
        purchasesAccountCode: json['purchases_account_code'],
        purchasesAccountName: json['purchases_account_name'],
        closingGlDocId: json['closing_gl_doc_id'],
        closingDocCode: json['closing_doc_code'],
        closingDocNameThai: json['closing_doc_name_thai'],
        closingDocNameEng: json['closing_doc_name_eng'],
      );

  Map<String, dynamic> toJson() => {
        'inventory_accounting_mode': inventoryAccountingMode,
        'mode_effective_period_id': modeEffectivePeriodId,
        'inventory_account_id': inventoryAccountId,
        'cogs_account_id': cogsAccountId,
        'purchases_account_id': purchasesAccountId,
        'closing_gl_doc_id': closingGlDocId,
      };
}
