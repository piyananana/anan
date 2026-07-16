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

  // สาขา — ระดับ document ทั้งใบ (ย้ายมาจาก detail เพราะสาขาเป็น structural entity)
  int? branchId;
  String? branchCode;
  String? branchName;

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
    this.branchId,
    this.branchCode,
    this.branchName,
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
      refDocCode: json['ref_doc_code'],
      refDocName: json['ref_doc_name'],
      refDocNo: json['ref_doc_no'],
      refDocDate: json['ref_doc_date'] != null ? parseLocalDate(json['ref_doc_date']) : null,
      externalSourceId: json['external_source_id'],
      branchId: json['branch_id'] as int?,
      branchCode: json['branch_code'] as String?,
      branchName: json['branch_name_thai'] as String?,
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
      'branch_id': branchId,
    };
  }
}

class GlEntryDetail {
  int id;
  int accountId;
  String accountCode; // Display
  String accountName; // Display (Thai)
  String accountNameEng; // Display (English)
  String description;
  // double debit;
  // double credit;
  // Amounts
  double debitFc; // [NEW] Foreign Currency Input
  double creditFc; // [NEW] Foreign Currency Input
  double debitLc; // Calculated (FC * Rate)
  double creditLc; // Calculated (FC * Rate)

  // Configurable dimensions (dim1–dim5)
  int? dim1Id; String? dim1Code; String? dim1Name;
  int? dim2Id; String? dim2Code; String? dim2Name;
  int? dim3Id; String? dim3Code; String? dim3Name;
  int? dim4Id; String? dim4Code; String? dim4Name;
  int? dim5Id; String? dim5Code; String? dim5Name;

  GlEntryDetail({
    this.id = 0,
    required this.accountId,
    this.accountCode = '',
    this.accountName = '',
    this.accountNameEng = '',
    this.description = '',
    this.debitFc = 0.0,
    this.creditFc = 0.0,
    this.debitLc = 0.0,
    this.creditLc = 0.0,
    this.dim1Id, this.dim1Code, this.dim1Name,
    this.dim2Id, this.dim2Code, this.dim2Name,
    this.dim3Id, this.dim3Code, this.dim3Name,
    this.dim4Id, this.dim4Code, this.dim4Name,
    this.dim5Id, this.dim5Code, this.dim5Name,
  });

  factory GlEntryDetail.fromJson(Map<String, dynamic> json) {
    return GlEntryDetail(
      id:          json['id'] ?? 0,
      accountId:   json['account_id'] ?? 0,
      accountCode: json['account_code'] ?? '',
      accountName: json['account_name_thai'] ?? '',
      accountNameEng: json['account_name_eng'] ?? '',
      description: json['description'] ?? '',
      debitFc:     double.tryParse(json['debit_fc'].toString()) ?? 0.0,
      creditFc:    double.tryParse(json['credit_fc'].toString()) ?? 0.0,
      debitLc:     double.tryParse(json['debit_lc'].toString()) ?? 0.0,
      creditLc:    double.tryParse(json['credit_lc'].toString()) ?? 0.0,
      dim1Id:   json['dim1_id'] as int?,   dim1Code: json['dim1_code'] as String?, dim1Name: json['dim1_name'] as String?,
      dim2Id:   json['dim2_id'] as int?,   dim2Code: json['dim2_code'] as String?, dim2Name: json['dim2_name'] as String?,
      dim3Id:   json['dim3_id'] as int?,   dim3Code: json['dim3_code'] as String?, dim3Name: json['dim3_name'] as String?,
      dim4Id:   json['dim4_id'] as int?,   dim4Code: json['dim4_code'] as String?, dim4Name: json['dim4_name'] as String?,
      dim5Id:   json['dim5_id'] as int?,   dim5Code: json['dim5_code'] as String?, dim5Name: json['dim5_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'account_id':  accountId,
        'description': description,
        'debit_fc':    debitFc,
        'credit_fc':   creditFc,
        'debit_lc':    debitLc,
        'credit_lc':   creditLc,
        'dim1_id':     dim1Id,
        'dim2_id':     dim2Id,
        'dim3_id':     dim3Id,
        'dim4_id':     dim4Id,
        'dim5_id':     dim5Id,
      };
}
