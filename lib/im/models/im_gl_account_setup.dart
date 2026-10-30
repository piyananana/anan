// lib/im/models/im_gl_account_setup.dart

class ImGlAccountSetup {
  final int? id;
  final String docCode;
  final String? sysDocType;
  final String? docNameThai;
  final String? docNameEng;
  final bool? docIsActive;
  final String targetModule; // 'AP' / 'AR' / 'NONE' — derived server-side, not editable
  final String? targetDocCode; // sys_doc_type ของเอกสาร AR/AP ปลายทาง — derived server-side, not editable
  final bool targetAuto; // true = สร้างเอกสาร AR/AP อัตโนมัติตอน Post (ต้องตั้ง targetDocId ก่อนใช้)
  final int? targetDocId; // ประเภทเอกสาร AR/AP ปลายทางที่ผู้ใช้ตั้ง
  final String? targetDocCodeSel;
  final String? targetDocNameTh;
  final String? targetDocNameEn;
  final int? glDocId;
  final String? glDocCode;
  final String? glDocName;
  final int? inventoryAccountId;
  final String? inventoryAccountCode;
  final String? inventoryAccountName;
  final int? cogsAccountId;
  final String? cogsAccountCode;
  final String? cogsAccountName;
  final int? varianceAccountId;
  final String? varianceAccountCode;
  final String? varianceAccountName;
  final int? wipAccountId;
  final String? wipAccountCode;
  final String? wipAccountName;
  final int? grirAccountId;
  final String? grirAccountCode;
  final String? grirAccountName;
  final int? vatOutputAccountId;
  final String? vatOutputAccountCode;
  final String? vatOutputAccountName;
  final int? vatInputAccountId;
  final String? vatInputAccountCode;
  final String? vatInputAccountName;
  final int? consignmentPayableAccountId;
  final String? consignmentPayableAccountCode;
  final String? consignmentPayableAccountName;

  const ImGlAccountSetup({
    this.id,
    required this.docCode,
    this.sysDocType,
    this.docNameThai,
    this.docNameEng,
    this.docIsActive,
    this.targetModule = 'NONE',
    this.targetDocCode,
    this.targetAuto = false,
    this.targetDocId,
    this.targetDocCodeSel,
    this.targetDocNameTh,
    this.targetDocNameEn,
    this.glDocId,
    this.glDocCode,
    this.glDocName,
    this.inventoryAccountId, this.inventoryAccountCode, this.inventoryAccountName,
    this.cogsAccountId, this.cogsAccountCode, this.cogsAccountName,
    this.varianceAccountId, this.varianceAccountCode, this.varianceAccountName,
    this.wipAccountId, this.wipAccountCode, this.wipAccountName,
    this.grirAccountId, this.grirAccountCode, this.grirAccountName,
    this.vatOutputAccountId, this.vatOutputAccountCode, this.vatOutputAccountName,
    this.vatInputAccountId, this.vatInputAccountCode, this.vatInputAccountName,
    this.consignmentPayableAccountId, this.consignmentPayableAccountCode, this.consignmentPayableAccountName,
  });

  bool get isConfigured => inventoryAccountId != null || cogsAccountId != null || varianceAccountId != null || wipAccountId != null || grirAccountId != null;

  factory ImGlAccountSetup.fromJson(Map<String, dynamic> json) => ImGlAccountSetup(
        id: json['id'],
        docCode: json['doc_code'] ?? '',
        sysDocType: json['sys_doc_type'],
        docNameThai: json['doc_name_thai'],
        docNameEng: json['doc_name_eng'],
        docIsActive: json['doc_is_active'],
        targetModule: json['target_module'] ?? 'NONE',
        targetDocCode: json['target_doc_code'],
        targetAuto: json['target_auto'] ?? false,
        targetDocId: json['target_doc_id'],
        targetDocCodeSel: json['target_doc_code_sel'],
        targetDocNameTh: json['target_doc_name_th'],
        targetDocNameEn: json['target_doc_name_en'],
        glDocId: json['gl_doc_id'],
        glDocCode: json['gl_doc_code'],
        glDocName: json['gl_doc_name'],
        inventoryAccountId: json['inventory_account_id'],
        inventoryAccountCode: json['inventory_account_code'],
        inventoryAccountName: json['inventory_account_name'],
        cogsAccountId: json['cogs_account_id'],
        cogsAccountCode: json['cogs_account_code'],
        cogsAccountName: json['cogs_account_name'],
        varianceAccountId: json['variance_account_id'],
        varianceAccountCode: json['variance_account_code'],
        varianceAccountName: json['variance_account_name'],
        wipAccountId: json['wip_account_id'],
        wipAccountCode: json['wip_account_code'],
        wipAccountName: json['wip_account_name'],
        grirAccountId: json['grir_account_id'],
        grirAccountCode: json['grir_account_code'],
        grirAccountName: json['grir_account_name'],
        vatOutputAccountId: json['vat_output_account_id'],
        vatOutputAccountCode: json['vat_output_account_code'],
        vatOutputAccountName: json['vat_output_account_name'],
        vatInputAccountId: json['vat_input_account_id'],
        vatInputAccountCode: json['vat_input_account_code'],
        vatInputAccountName: json['vat_input_account_name'],
        consignmentPayableAccountId: json['consignment_payable_account_id'],
        consignmentPayableAccountCode: json['consignment_payable_account_code'],
        consignmentPayableAccountName: json['consignment_payable_account_name'],
      );

  Map<String, dynamic> toJson() => {
        'inventory_account_id': inventoryAccountId,
        'cogs_account_id': cogsAccountId,
        'variance_account_id': varianceAccountId,
        'wip_account_id': wipAccountId,
        'grir_account_id': grirAccountId,
        'vat_output_account_id': vatOutputAccountId,
        'vat_input_account_id': vatInputAccountId,
        'consignment_payable_account_id': consignmentPayableAccountId,
        'gl_doc_id': glDocId,
        'target_doc_id': targetDocId,
      };
}

// บัญชีที่ตอน Post จะใช้จริงต่อสินค้า (POST /im_transaction/gl_accounts) — resolver ชุดเดียวกับ backend:
// สต็อก: คลัง → สินค้า → หมวดสินค้า → ประเภทเอกสาร, ต้นทุน/รายได้: สินค้า → หมวดสินค้า → ประเภทเอกสาร
class ImGlAcct {
  final int id;
  final String code;
  final String nameTh;
  final String nameEn;
  const ImGlAcct({required this.id, required this.code, required this.nameTh, required this.nameEn});

  static ImGlAcct? fromJson(dynamic j) => j is Map<String, dynamic>
      ? ImGlAcct(id: j['id'] as int, code: j['code'] ?? '', nameTh: j['name_th'] ?? '', nameEn: j['name_en'] ?? '')
      : null;

  String name(bool isEnglish) => isEnglish && nameEn.isNotEmpty ? nameEn : nameTh;
}

// บัญชีและโหมดของสินค้าในคลังต้นทาง/ปลายทาง — mode = สินค้า → หมวดสินค้า → คลัง → ค่าเริ่มต้นของบริษัท
class ImItemGlAccts {
  final String mode; // PERPETUAL / PERIODIC
  final String? toMode; // คลังปลายทางของ TRF
  final ImGlAcct? inventory;
  final ImGlAcct? toInventory;
  final ImGlAcct? purchases; // บัญชีซื้อสินค้า (ใช้แทนบัญชีสต็อกเมื่อเป็น Periodic)
  final ImGlAcct? toPurchases;
  final ImGlAcct? cogs;
  final ImGlAcct? revenue;
  const ImItemGlAccts({required this.mode, this.toMode, this.inventory, this.toInventory, this.purchases, this.toPurchases, this.cogs, this.revenue});

  bool get isPeriodic => mode == 'PERIODIC';
  bool get isToPeriodic => toMode == 'PERIODIC';

  factory ImItemGlAccts.fromJson(Map<String, dynamic> j) => ImItemGlAccts(
        mode: j['mode'] ?? 'PERPETUAL',
        toMode: j['to_mode'],
        inventory: ImGlAcct.fromJson(j['inventory']),
        toInventory: ImGlAcct.fromJson(j['to_inventory']),
        purchases: ImGlAcct.fromJson(j['purchases']),
        toPurchases: ImGlAcct.fromJson(j['to_purchases']),
        cogs: ImGlAcct.fromJson(j['cogs']),
        revenue: ImGlAcct.fromJson(j['revenue']),
      );
}

class ImGlAccounts {
  final String mode; // โหมดเริ่มต้นของบริษัท — โหมดจริงต่อสินค้าอยู่ที่ items[id].mode
  final Map<int, ImItemGlAccts> items;
  const ImGlAccounts({required this.mode, required this.items});

  factory ImGlAccounts.fromJson(Map<String, dynamic> j) => ImGlAccounts(
        mode: j['mode'] ?? 'PERPETUAL',
        items: {
          for (final e in ((j['items'] ?? {}) as Map<String, dynamic>).entries)
            int.parse(e.key): ImItemGlAccts.fromJson(e.value as Map<String, dynamic>),
        },
      );
}
