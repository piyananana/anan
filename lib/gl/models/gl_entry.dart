// File: gl/models/gl_entry.dart
import '../../../utils/date_utils.dart';

class GlEntryHeader {
  final int id;
  int docId;
  String docNo;
  String docCode; // Display
  String docName; // Display
  DateTime docDate;
  DateTime postingDate;
  String refNo;
  String description;
  String status; // Draft, Posted, Deleted
  // double totalDebit;
  // double totalCredit;

// Total
  double totalDebitLc; // ยอดรวม Base Currency
  double totalCreditLc; // ยอดรวม Base Currency
  double totalDebitFc; // [NEW] ยอดรวม Foreign Currency
  double totalCreditFc; // [NEW] ยอดรวม Foreign Currency

  int periodId;
  int currencyId;
  double exchangeRate;

  // สำหรับการแสดงผล/แก้ไข
  bool isAutoNumbering;

  // เพิ่ม Fields สำหรับ Reference
  int? refDocId;       // ID ประเภทเอกสารอ้างอิง (เช่น ใบแจ้งหนี้)
  String? refDocCode;  // สำหรับแสดงผล
  String? refDocName;  // สำหรับแสดงผล
  String? refDocNo;    // เลขที่เอกสารอ้างอิง (เช่น INV-2024-001)
  DateTime? refDocDate; // วันที่เอกสารอ้างอิง
  int? externalSourceId; // ID จากระบบต้นทาง

  GlEntryHeader({
    this.id = 0,
    required this.docId,
    this.docNo = '',
    this.docCode = '',
    this.docName = '',
    required this.docDate,
    required this.postingDate,
    this.refNo = '',
    this.description = '',
    this.status = 'Draft',
    // this.totalDebit = 0.0,
    // this.totalCredit = 0.0,
    this.totalDebitLc = 0.0,
    this.totalCreditLc = 0.0,
    this.totalDebitFc = 0.0, // [NEW]
    this.totalCreditFc = 0.0, // [NEW]
    this.periodId = 0,
    this.currencyId = 1,
    this.exchangeRate = 1.0,
    this.isAutoNumbering = false,
    this.refDocId,
    this.refDocCode,
    this.refDocName,
    this.refDocNo,
    this.refDocDate,
    this.externalSourceId,
  });

  factory GlEntryHeader.fromJson(Map<String, dynamic> json) {
    return GlEntryHeader(
      id: json['id'] ?? 0,
      docId: json['doc_id'] ?? 0,
      docNo: json['doc_no'] ?? '',
      docCode: json['doc_code'] ?? '',
      docName: json['doc_name_thai'] ?? '',
      docDate: json['doc_date'] != null
          ? parseLocalDate(json['doc_date'])
          : DateTime.now(),
      postingDate: json['posting_date'] != null
          ? parseLocalDate(json['posting_date'])
          : DateTime.now(),
      refNo: json['ref_no'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'Draft',
      // totalDebit: double.tryParse(json['total_debit_lc'].toString()) ?? 0.0,
      // totalCredit: double.tryParse(json['total_credit_lc'].toString()) ?? 0.0,
      // Map LC fields
      totalDebitLc: double.tryParse(json['total_debit_lc'].toString()) ?? 0.0,
      totalCreditLc: double.tryParse(json['total_credit_lc'].toString()) ?? 0.0,
      // Map FC fields
      totalDebitFc: double.tryParse(json['total_debit_fc'].toString()) ?? 0.0,
      totalCreditFc: double.tryParse(json['total_credit_fc'].toString()) ?? 0.0,
      periodId: json['period_id'] ?? 0,
      currencyId: json['currency_id'] ?? 1,
      exchangeRate: double.tryParse(json['exchange_rate'].toString()) ?? 1.0,
      isAutoNumbering: json['is_auto_numbering'] ?? false,
      refDocId: json['ref_doc_id'],
      refDocCode: json['ref_doc_code'], // จากการ JOIN ใน Controller
      refDocName: json['ref_doc_name'], // จากการ JOIN ใน Controller
      refDocNo: json['ref_doc_no'],
      refDocDate: json['ref_doc_date'] != null ? parseLocalDate(json['ref_doc_date']) : null,
      externalSourceId: json['external_source_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'doc_id': docId,
      'doc_no': docNo,
      'doc_date': formatLocalDate(docDate),
      'posting_date': formatLocalDate(postingDate),
      'ref_no': refNo,
      'description': description,
      'period_id': periodId,
      'currency_id': currencyId,
      'exchange_rate': exchangeRate,
      // 'total_debit': totalDebit,
      // 'total_credit': totalCredit,
      'total_debit_lc': totalDebitLc,
      'total_credit_lc': totalCreditLc,
      'total_debit_fc': totalDebitFc, // [NEW]
      'total_credit_fc': totalCreditFc, // [NEW]
      'created_by': 1, // Replace with actual user ID
      'updated_by': 1,
      'ref_doc_id': refDocId,
      'ref_doc_no': refDocNo,
      'ref_doc_date': refDocDate != null ? formatLocalDate(refDocDate!) : null,
      'external_source_id': externalSourceId,
    };
  }
}

class GlEntryDetail {
  int id;
  int accountId;
  String accountCode; // Display
  String accountName; // Display
  String description;
  // double debit;
  // double credit;
  // Amounts
  double debitFc; // [NEW] Foreign Currency Input
  double creditFc; // [NEW] Foreign Currency Input
  double debitLc; // Calculated (FC * Rate)
  double creditLc; // Calculated (FC * Rate)

  int? branchId;
  String? branchCode; // Display
  String? branchName; // Display
  int? projectId;
  String? projectCode; // Display
  String? projectName; // Display
  int? businessUnitId;
  String? businessUnitCode; // Display
  String? businessUnitName; // Display

  GlEntryDetail({
    this.id = 0,
    required this.accountId,
    this.accountCode = '',
    this.accountName = '',
    this.description = '',
    // this.debit = 0.0,
    // this.credit = 0.0,
    this.debitFc = 0.0,
    this.creditFc = 0.0,
    this.debitLc = 0.0,
    this.creditLc = 0.0,
    this.branchId,
    this.branchCode = '',
    this.branchName = '',
    this.projectId,
    this.projectCode = '',
    this.projectName = '',
    this.businessUnitId,
    this.businessUnitCode = '',
    this.businessUnitName = '',
  });

  factory GlEntryDetail.fromJson(Map<String, dynamic> json) {
    return GlEntryDetail(
      id: json['id'] ?? 0,
      accountId: json['account_id'] ?? 0,
      accountCode: json['account_code'] ?? '',
      accountName: json['account_name_thai'] ?? '',
      description: json['description'] ?? '',
      // debit: double.tryParse(json['debit_lc'].toString()) ?? 0.0,
      // credit: double.tryParse(json['credit_lc'].toString()) ?? 0.0,
      // Map FC & LC
      debitFc: double.tryParse(json['debit_fc'].toString()) ?? 0.0,
      creditFc: double.tryParse(json['credit_fc'].toString()) ?? 0.0,
      debitLc: double.tryParse(json['debit_lc'].toString()) ?? 0.0,
      creditLc: double.tryParse(json['credit_lc'].toString()) ?? 0.0,
      branchId: json['branch_id'],
      branchCode: json['branch_code'] ?? '',
      branchName: json['branch_name_thai'] ?? '',
      projectId: json['project_id'],
      projectCode: json['project_code'] ?? '',
      projectName: json['project_name_thai'] ?? '',
      businessUnitId: json['business_unit_id'],
      businessUnitCode: json['bu_code'] ?? '',
      businessUnitName: json['bu_name_thai'] ?? '',
    );
  }
}

// class GlEntryHeader {
//   final int id;
//   int docId;
//   String docNo;
//   String docCode; // Display
//   String docName; // Display
//   DateTime docDate;
//   DateTime postingDate;
//   String refNo;
//   String description;
//   String status; // Draft, Posted, Deleted
//   double totalDebit;
//   double totalCredit;
//   int periodId;
//   int currencyId;
//   double exchangeRate;

//   // สำหรับการแสดงผล/แก้ไข
//   bool isAutoNumbering;

//   GlEntryHeader({
//     this.id = 0,
//     required this.docId,
//     this.docNo = '',
//     this.docCode = '',
//     this.docName = '',
//     required this.docDate,
//     required this.postingDate,
//     this.refNo = '',
//     this.description = '',
//     this.status = 'Draft',
//     this.totalDebit = 0.0,
//     this.totalCredit = 0.0,
//     this.periodId = 0,
//     this.currencyId = 1,
//     this.exchangeRate = 1.0,
//     this.isAutoNumbering = false,
//   });

//   factory GlEntryHeader.fromJson(Map<String, dynamic> json) {
//     return GlEntryHeader(
//       id: json['id'] ?? 0,
//       docId: json['doc_id'] ?? 0,
//       docNo: json['doc_no'] ?? '',
//       docCode: json['doc_code'] ?? '',
//       docName: json['doc_name_thai'] ?? '',
//       docDate: json['doc_date'] != null ? DateTime.parse(json['doc_date']) : DateTime.now(),
//       postingDate: json['posting_date'] != null ? DateTime.parse(json['posting_date']) : DateTime.now(),
//       refNo: json['ref_no'] ?? '',
//       description: json['description'] ?? '',
//       status: json['status'] ?? 'Draft',
//       totalDebit: double.tryParse(json['total_debit_lc'].toString()) ?? 0.0,
//       totalCredit: double.tryParse(json['total_credit_lc'].toString()) ?? 0.0,
//       periodId: json['period_id'] ?? 0,
//       currencyId: json['currency_id'] ?? 1,
//       exchangeRate: double.tryParse(json['exchange_rate'].toString()) ?? 1.0,
//       isAutoNumbering: json['is_auto_numbering'] ?? false,
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'doc_id': docId,
//       'doc_no': docNo,
//       'doc_date': docDate.toIso8601String(),
//       'posting_date': postingDate.toIso8601String(),
//       'ref_no': refNo,
//       'description': description,
//       'period_id': periodId,
//       'currency_id': currencyId,
//       'exchange_rate': exchangeRate,
//       'total_debit': totalDebit,
//       'total_credit': totalCredit,
//       'created_by': 1, // Replace with actual user ID
//       'updated_by': 1,
//     };
//   }
// }

// class GlEntryDetail {
//   int id;
//   int accountId;
//   String accountCode; // Display
//   String accountName; // Display
//   String description;
//   double debit;
//   double credit;
//   int? branchId;
//   int? projectId;
//   int? businessUnitId;

//   GlEntryDetail({
//     this.id = 0,
//     required this.accountId,
//     this.accountCode = '',
//     this.accountName = '',
//     this.description = '',
//     this.debit = 0.0,
//     this.credit = 0.0,
//     this.branchId,
//     this.projectId,
//     this.businessUnitId,
//   });

//   factory GlEntryDetail.fromJson(Map<String, dynamic> json) {
//     return GlEntryDetail(
//       id: json['id'] ?? 0,
//       accountId: json['account_id'] ?? 0,
//       accountCode: json['account_code'] ?? '',
//       accountName: json['account_name_thai'] ?? '',
//       description: json['description'] ?? '',
//       debit: double.tryParse(json['debit_lc'].toString()) ?? 0.0,
//       credit: double.tryParse(json['credit_lc'].toString()) ?? 0.0,
//       branchId: json['branch_id'],
//       projectId: json['project_id'],
//       businessUnitId: json['business_unit_id'],
//     );
//   }
// }
