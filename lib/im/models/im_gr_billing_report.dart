// lib/im/models/im_gr_billing_report.dart
//
// Model for GET /api/im/im_transaction/gr_billing_report — review report for sys_doc_type='12'
// (GR รอตั้งหนี้): groups documents by vendor. See
// anan_backend/controllers/im/imGrBillingReportController.js for the exact response shape.
// vendor_name_en is not returned by the backend (known bilingual gap — same pattern as other
// AP/IM denormalized vendor name snapshots), so we fall back to vendor_name_th for both languages.

class ImGrBillingReportDoc {
  final int id;
  final String docNo;
  final DateTime docDate;
  final String status; // 'Received' | 'Posted'
  final String? warehouseCode;
  final String? warehouseNameTh;
  final String? refNo;
  final int? linkedApTransactionId;
  final int? daysOutstanding; // non-null only when status == 'Received'
  final double stockValue;
  final double? billedValue; // non-null only when status == 'Posted'
  final double varianceValue;

  ImGrBillingReportDoc({
    required this.id,
    required this.docNo,
    required this.docDate,
    required this.status,
    this.warehouseCode,
    this.warehouseNameTh,
    this.refNo,
    this.linkedApTransactionId,
    this.daysOutstanding,
    required this.stockValue,
    this.billedValue,
    this.varianceValue = 0,
  });

  factory ImGrBillingReportDoc.fromJson(Map<String, dynamic> json) => ImGrBillingReportDoc(
        id: json['id'] as int,
        docNo: json['doc_no'] ?? '',
        docDate: DateTime.parse(json['doc_date'].toString()),
        status: json['status'] ?? '',
        warehouseCode: json['warehouse_code'],
        warehouseNameTh: json['warehouse_name_th'],
        refNo: json['ref_no'],
        linkedApTransactionId: json['linked_ap_transaction_id'],
        daysOutstanding: json['days_outstanding'] == null ? null : (json['days_outstanding'] as num).toInt(),
        stockValue: (json['stock_value'] as num?)?.toDouble() ?? 0.0,
        billedValue: json['billed_value'] == null ? null : (json['billed_value'] as num).toDouble(),
        varianceValue: (json['variance_value'] as num?)?.toDouble() ?? 0.0,
      );
}

class ImGrBillingReportVendor {
  final int vendorId;
  final String vendorCode;
  final String vendorNameTh;
  final List<ImGrBillingReportDoc> documents;

  ImGrBillingReportVendor({
    required this.vendorId,
    required this.vendorCode,
    required this.vendorNameTh,
    this.documents = const [],
  });

  factory ImGrBillingReportVendor.fromJson(Map<String, dynamic> json) => ImGrBillingReportVendor(
        vendorId: json['vendor_id'] as int,
        vendorCode: json['vendor_code'] ?? '',
        vendorNameTh: json['vendor_name_th'] ?? '',
        documents: (json['documents'] as List<dynamic>? ?? [])
            .map((e) => ImGrBillingReportDoc.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
