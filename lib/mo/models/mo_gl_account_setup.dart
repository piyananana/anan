// บัญชีของประเภทเอกสารใบสั่งผลิต (mo_gl_account_setup) — ชุดบัญชีเดียวที่ MOI/MOR ที่อ้างอิงใบสั่งผลิต,
// บันทึกเวลาปฏิบัติงาน และปิดใบสั่งผลิตใช้ร่วมกัน (backend controllers/mo/moGlAccountSetupController.js)
class MoGlAccountSetup {
  final String docCode;
  final String? docNameThai;
  final String? docNameEng;
  final int? glDocId;
  final String? glDocCode;
  final String? glDocName;
  // key = ชื่อคอลัมน์ *_account_id ฝั่ง backend
  final Map<String, ({int? id, String? code, String? name})> accounts;

  static const accountKeys = [
    'wip_account_id', 'variance_account_id', 'applied_labor_account_id', 'applied_overhead_account_id',
  ];

  const MoGlAccountSetup({
    required this.docCode,
    this.docNameThai,
    this.docNameEng,
    this.glDocId,
    this.glDocCode,
    this.glDocName,
    required this.accounts,
  });

  bool get isConfigured => glDocId != null || accounts.values.any((a) => a.id != null);

  factory MoGlAccountSetup.fromJson(Map<String, dynamic> j) => MoGlAccountSetup(
        docCode: j['doc_code'] ?? '',
        docNameThai: j['doc_name_thai'],
        docNameEng: j['doc_name_eng'],
        glDocId: j['gl_doc_id'],
        glDocCode: j['gl_doc_code'],
        glDocName: j['gl_doc_name'],
        accounts: {
          for (final k in accountKeys)
            k: (
              id: j[k] as int?,
              code: j[k.replaceAll('_id', '_code')] as String?,
              name: j[k.replaceAll('_id', '_name')] as String?,
            ),
        },
      );

  Map<String, dynamic> toJson() => {
        'gl_doc_id': glDocId,
        for (final e in accounts.entries) e.key: e.value.id,
      };
}
