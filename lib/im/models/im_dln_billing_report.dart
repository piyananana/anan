// lib/im/models/im_dln_billing_report.dart
//
// Model for GET /api/im/im_transaction/dln_billing_report — review report for sys_doc_type='32'
// (ส่งสินค้า รอตั้งหนี้): groups documents by customer. See
// anan_backend/controllers/im/imDlnBillingReportController.js for the exact response shape.
// customer_name_en is not returned by the backend (known bilingual gap — same pattern as other
// AR/IM denormalized customer name snapshots), so we fall back to customer_name_th for both languages.
// Unlike the GR billing report, there is no "variance" field here — unit_price is a single column,
// edited in place before Post, so there's no separate before/after value preserved once posted.

class ImDlnBillingReportDoc {
  final int id;
  final String docNo;
  final DateTime docDate;
  final String status; // 'Delivered' | 'Posted'
  final String? warehouseCode;
  final String? warehouseNameTh;
  final String? refNo;
  final int? linkedArTransactionId;
  final int? daysOutstanding; // non-null only when status == 'Delivered'
  final double cogsValue;
  final double? estimatedRevenue; // non-null only when status == 'Delivered'
  final double? billedRevenue; // non-null only when status == 'Posted'

  ImDlnBillingReportDoc({
    required this.id,
    required this.docNo,
    required this.docDate,
    required this.status,
    this.warehouseCode,
    this.warehouseNameTh,
    this.refNo,
    this.linkedArTransactionId,
    this.daysOutstanding,
    required this.cogsValue,
    this.estimatedRevenue,
    this.billedRevenue,
  });

  factory ImDlnBillingReportDoc.fromJson(Map<String, dynamic> json) => ImDlnBillingReportDoc(
        id: json['id'] as int,
        docNo: json['doc_no'] ?? '',
        docDate: DateTime.parse(json['doc_date'].toString()),
        status: json['status'] ?? '',
        warehouseCode: json['warehouse_code'],
        warehouseNameTh: json['warehouse_name_th'],
        refNo: json['ref_no'],
        linkedArTransactionId: json['linked_ar_transaction_id'],
        daysOutstanding: json['days_outstanding'] == null ? null : (json['days_outstanding'] as num).toInt(),
        cogsValue: (json['cogs_value'] as num?)?.toDouble() ?? 0.0,
        estimatedRevenue: json['estimated_revenue'] == null ? null : (json['estimated_revenue'] as num).toDouble(),
        billedRevenue: json['billed_revenue'] == null ? null : (json['billed_revenue'] as num).toDouble(),
      );
}

class ImDlnBillingReportCustomer {
  final int customerId;
  final String customerCode;
  final String customerNameTh;
  final List<ImDlnBillingReportDoc> documents;

  ImDlnBillingReportCustomer({
    required this.customerId,
    required this.customerCode,
    required this.customerNameTh,
    this.documents = const [],
  });

  factory ImDlnBillingReportCustomer.fromJson(Map<String, dynamic> json) => ImDlnBillingReportCustomer(
        customerId: json['customer_id'] as int,
        customerCode: json['customer_code'] ?? '',
        customerNameTh: json['customer_name_th'] ?? '',
        documents: (json['documents'] as List<dynamic>? ?? [])
            .map((e) => ImDlnBillingReportDoc.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
