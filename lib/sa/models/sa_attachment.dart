// lib/sa/models/sa_attachment.dart — ไฟล์แนบท้ายรายการแบบ generic ใช้ร่วมกันได้ทุกโมดูล (moduleCode + entityId คือ
// id ของแถวที่แนบ เช่น pr_transaction_detail.id/po_transaction_detail.id)
class SaAttachment {
  final int id;
  final String moduleCode;
  final int entityId;
  final String fileName;
  final String fullUrl;
  final int? fileSize;
  final String? mimeType;
  final DateTime? createdAt;

  const SaAttachment({
    required this.id,
    required this.moduleCode,
    required this.entityId,
    required this.fileName,
    required this.fullUrl,
    this.fileSize,
    this.mimeType,
    this.createdAt,
  });

  bool get isImage => (mimeType ?? '').startsWith('image/');
  bool get isPdf => mimeType == 'application/pdf';

  factory SaAttachment.fromJson(Map<String, dynamic> json) => SaAttachment(
        id: json['id'] as int,
        moduleCode: json['module_code'] ?? '',
        entityId: json['entity_id'] ?? 0,
        fileName: json['file_name'] ?? '',
        fullUrl: json['full_url'] ?? '',
        fileSize: json['file_size'],
        mimeType: json['mime_type'],
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      );
}
