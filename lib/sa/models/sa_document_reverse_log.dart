// ประวัติการถอยเอกสารกลับเป็นร่าง / การลบเอกสาร (backend: sa_document_reverse_log, utils/reverseLog.js)
// ใช้ร่วมทุกโมดูล (GL, AP, ...)
class DocReverseLog {
  final String? fromStatus;
  final String? toStatus; // Draft = ถอยเป็นร่าง, Deleted = ลบ
  final String reason;
  final String? createdByName;
  final DateTime? createdAt;

  DocReverseLog({this.fromStatus, this.toStatus, required this.reason, this.createdByName, this.createdAt});

  bool get isDelete => toStatus == 'Deleted';

  factory DocReverseLog.fromJson(Map<String, dynamic> json) => DocReverseLog(
        fromStatus: json['from_status'] as String?,
        toStatus: json['to_status'] as String?,
        reason: json['reason'] ?? '',
        createdByName: json['created_by_name'] as String?,
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal(),
      );

  static List<DocReverseLog> listFromJson(dynamic list) => (list as List? ?? [])
      .map((e) => DocReverseLog.fromJson(e as Map<String, dynamic>))
      .toList();
}
