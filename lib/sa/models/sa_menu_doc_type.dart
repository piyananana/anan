// lib/sa/models/sa_menu_doc_type.dart

// "การ์ด" ประเภทเอกสารที่ผูกไว้กับเมนู (เมื่อเมนูนั้นเปิดใช้ "ใช้ประเภทเอกสาร")
// เพิ่มโดย admin ผ่าน dialog ค้นหาจากตาราง sa_module_document ที่หน้าจอ sa_module_approver_screen
class SaMenuDocType {
  final int? id;
  final int menuId;
  final String docType; // = doc_code ของ sa_module_document ที่เลือก
  final String? docNameThai;
  final String? docNameEng;
  final String? sysModule;

  SaMenuDocType({
    this.id,
    required this.menuId,
    required this.docType,
    this.docNameThai,
    this.docNameEng,
    this.sysModule,
  });

  String localName(bool isEnglish) =>
      isEnglish && (docNameEng ?? '').isNotEmpty ? docNameEng! : (docNameThai ?? docType);

  factory SaMenuDocType.fromJson(Map<String, dynamic> json) => SaMenuDocType(
        id: json['id'],
        menuId: json['menu_id'],
        docType: json['doc_type'] ?? '',
        docNameThai: json['doc_name_thai'] as String?,
        docNameEng: json['doc_name_eng'] as String?,
        sysModule: json['sys_module'] as String?,
      );
}
