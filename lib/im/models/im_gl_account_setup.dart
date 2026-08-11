// lib/im/models/im_gl_account_setup.dart

class ImGlAccountSetup {
  final int? id;
  final String docCode;
  final String? sysDocType;
  final String? docNameThai;
  final String? docNameEng;
  final bool? docIsActive;
  final String targetModule; // 'AP' / 'AR' / 'NONE' — derived server-side, not editable
  final String? targetDocCode; // derived server-side, not editable
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

  const ImGlAccountSetup({
    this.id,
    required this.docCode,
    this.sysDocType,
    this.docNameThai,
    this.docNameEng,
    this.docIsActive,
    this.targetModule = 'NONE',
    this.targetDocCode,
    this.glDocId,
    this.glDocCode,
    this.glDocName,
    this.inventoryAccountId, this.inventoryAccountCode, this.inventoryAccountName,
    this.cogsAccountId, this.cogsAccountCode, this.cogsAccountName,
    this.varianceAccountId, this.varianceAccountCode, this.varianceAccountName,
    this.wipAccountId, this.wipAccountCode, this.wipAccountName,
  });

  bool get isConfigured => inventoryAccountId != null || cogsAccountId != null || varianceAccountId != null || wipAccountId != null;

  factory ImGlAccountSetup.fromJson(Map<String, dynamic> json) => ImGlAccountSetup(
        id: json['id'],
        docCode: json['doc_code'] ?? '',
        sysDocType: json['sys_doc_type'],
        docNameThai: json['doc_name_thai'],
        docNameEng: json['doc_name_eng'],
        docIsActive: json['doc_is_active'],
        targetModule: json['target_module'] ?? 'NONE',
        targetDocCode: json['target_doc_code'],
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
      );

  Map<String, dynamic> toJson() => {
        'inventory_account_id': inventoryAccountId,
        'cogs_account_id': cogsAccountId,
        'variance_account_id': varianceAccountId,
        'wip_account_id': wipAccountId,
        'gl_doc_id': glDocId,
      };
}
