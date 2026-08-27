// lib/ap/models/ap_payment_run.dart
import '../../utils/date_utils.dart';

// ── Approval record ───────────────────────────────────────────────────────────
class ApPaymentRunApproval {
  final int id;
  final int runId;
  final int approverUserId;
  final String approverUserName;
  final int sequenceNo;
  final String status; // Pending / Approved / Rejected
  final String? remarks;
  final DateTime? approvedAt;

  const ApPaymentRunApproval({
    required this.id,
    required this.runId,
    required this.approverUserId,
    required this.approverUserName,
    required this.sequenceNo,
    required this.status,
    this.remarks,
    this.approvedAt,
  });

  factory ApPaymentRunApproval.fromJson(Map<String, dynamic> json) =>
      ApPaymentRunApproval(
        id: json['id'] as int,
        runId: json['run_id'] as int,
        approverUserId: json['approver_user_id'] as int,
        approverUserName: json['approver_user_name'] ?? '',
        sequenceNo: json['sequence_no'] ?? 1,
        status: json['status'] ?? 'Pending',
        remarks: json['remarks'],
        approvedAt: json['approved_at'] != null
            ? DateTime.parse(json['approved_at'])
            : null,
      );
}

const Map<String, String> apPaymentRunStatusLabels = {
  'Draft':     'ร่าง',
  'Submitted': 'รออนุมัติ',
  'Approved':  'อนุมัติแล้ว',
  'Rejected':  'ปฏิเสธ',
  'Completed': 'จ่ายแล้ว',
  'Void':      'ยกเลิก',
};

const Map<String, String> apPaymentRunStatusLabelsEn = {
  'Draft':     'Draft',
  'Submitted': 'On Approve',
  'Approved':  'Approved',
  'Rejected':  'Rejected',
  'Completed': 'Paid',
  'Void':      'Cancel',
};

String apPaymentRunStatusLabel(String s, bool isEnglish) =>
    (isEnglish ? apPaymentRunStatusLabelsEn[s] : apPaymentRunStatusLabels[s]) ?? s;

// ── Open invoice returned by open_invoices endpoint ───────────────────────────
class ApOpenInvoice {
  final int txnId;
  final String docNo;
  final DateTime docDate;
  final DateTime? dueDate;
  final String? refNo;
  final int vendorId;
  final String vendorCode;
  final String vendorNameTh;
  final String? vendorNameEn;
  final double totalAmountLc;
  final double balanceAmountLc;
  final String currencyCode;
  final double exchangeRate;
  final String? bankName;
  final String? bankBranchName;
  final String? accountNumber;
  final String? accountName;

  const ApOpenInvoice({
    required this.txnId,
    required this.docNo,
    required this.docDate,
    this.dueDate,
    this.refNo,
    required this.vendorId,
    required this.vendorCode,
    required this.vendorNameTh,
    this.vendorNameEn,
    required this.totalAmountLc,
    required this.balanceAmountLc,
    this.currencyCode = 'THB',
    this.exchangeRate = 1.0,
    this.bankName,
    this.bankBranchName,
    this.accountNumber,
    this.accountName,
  });

  factory ApOpenInvoice.fromJson(Map<String, dynamic> json) => ApOpenInvoice(
        txnId: json['txn_id'] as int,
        docNo: json['doc_no'] ?? '',
        docDate: parseLocalDate(json['doc_date']),
        dueDate: parseLocalDateNullable(json['due_date']),
        refNo: json['ref_no'],
        vendorId: json['vendor_id'] as int,
        vendorCode: json['vendor_code'] ?? '',
        vendorNameTh: json['vendor_name_th'] ?? '',
        vendorNameEn: json['vendor_name_en'],
        totalAmountLc: (json['total_amount_lc'] as num).toDouble(),
        balanceAmountLc: (json['balance_amount_lc'] as num).toDouble(),
        currencyCode: json['currency_code'] ?? 'THB',
        exchangeRate: (json['exchange_rate'] as num?)?.toDouble() ?? 1.0,
        bankName: json['bank_name'],
        bankBranchName: json['bank_branch_name'],
        accountNumber: json['account_number'],
        accountName: json['account_name'],
      );
}

// ── Payment run detail line ───────────────────────────────────────────────────
class ApPaymentRunLine {
  final int? id;
  final int? runId;
  final int apTransactionId;
  final int vendorId;
  final String vendorCode;
  final String vendorNameTh;
  final String? bankName;
  final String? bankBranchName;
  final String? accountNumber;
  final String? accountName;
  final String invoiceNo;
  final DateTime? invoiceDate;
  final DateTime? dueDate;
  final double invoiceAmountLc;
  final double paymentAmountLc;
  final String currencyCode;
  final double exchangeRate;
  final int sortOrder;

  const ApPaymentRunLine({
    this.id,
    this.runId,
    required this.apTransactionId,
    required this.vendorId,
    required this.vendorCode,
    required this.vendorNameTh,
    this.bankName,
    this.bankBranchName,
    this.accountNumber,
    this.accountName,
    required this.invoiceNo,
    this.invoiceDate,
    this.dueDate,
    required this.invoiceAmountLc,
    required this.paymentAmountLc,
    this.currencyCode = 'THB',
    this.exchangeRate = 1.0,
    this.sortOrder = 0,
  });

  factory ApPaymentRunLine.fromJson(Map<String, dynamic> json) => ApPaymentRunLine(
        id: json['id'],
        runId: json['run_id'],
        apTransactionId: json['ap_transaction_id'] as int,
        vendorId: json['vendor_id'] as int,
        vendorCode: json['vendor_code'] ?? '',
        vendorNameTh: json['vendor_name_th'] ?? '',
        bankName: json['bank_name'],
        bankBranchName: json['bank_branch_name'],
        accountNumber: json['account_number'],
        accountName: json['account_name'],
        invoiceNo: json['invoice_no'] ?? '',
        invoiceDate: parseLocalDateNullable(json['invoice_date']),
        dueDate: parseLocalDateNullable(json['due_date']),
        invoiceAmountLc: (json['invoice_amount_lc'] as num).toDouble(),
        paymentAmountLc: (json['payment_amount_lc'] as num).toDouble(),
        currencyCode: json['currency_code'] ?? 'THB',
        exchangeRate: (json['exchange_rate'] as num?)?.toDouble() ?? 1.0,
        sortOrder: json['sort_order'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (runId != null) 'run_id': runId,
        'ap_transaction_id': apTransactionId,
        'vendor_id': vendorId,
        'vendor_code': vendorCode,
        'vendor_name_th': vendorNameTh,
        'bank_name': bankName,
        'bank_branch_name': bankBranchName,
        'account_number': accountNumber,
        'account_name': accountName,
        'invoice_no': invoiceNo,
        'invoice_date': invoiceDate != null ? formatLocalDate(invoiceDate!) : null,
        'due_date': dueDate != null ? formatLocalDate(dueDate!) : null,
        'invoice_amount_lc': invoiceAmountLc,
        'payment_amount_lc': paymentAmountLc,
        'currency_code': currencyCode,
        'exchange_rate': exchangeRate,
        'sort_order': sortOrder,
      };

  ApPaymentRunLine copyWith({double? paymentAmountLc}) => ApPaymentRunLine(
        id: id,
        runId: runId,
        apTransactionId: apTransactionId,
        vendorId: vendorId,
        vendorCode: vendorCode,
        vendorNameTh: vendorNameTh,
        bankName: bankName,
        bankBranchName: bankBranchName,
        accountNumber: accountNumber,
        accountName: accountName,
        invoiceNo: invoiceNo,
        invoiceDate: invoiceDate,
        dueDate: dueDate,
        invoiceAmountLc: invoiceAmountLc,
        paymentAmountLc: paymentAmountLc ?? this.paymentAmountLc,
        currencyCode: currencyCode,
        exchangeRate: exchangeRate,
        sortOrder: sortOrder,
      );
}

// ── Payment run header ────────────────────────────────────────────────────────
class ApPaymentRun {
  final int? id;
  final String? runNumber;
  final DateTime runDate;
  final String? description;
  final int? bankFileFormatId;
  final String? bankFileFormatCode;
  final String? bankFileFormatName;
  final int? checkPrintConfigId;
  final String? checkPrintConfigName;
  final DateTime? paymentDate;
  final int? paymentMethodId;
  final String? paymentMethodCode;
  final String? paymentMethodName;
  final DateTime? dueDateFilter;
  final double totalAmountLc;
  final String status;
  final List<ApPaymentRunLine> lines;
  final List<ApPaymentRunApproval> approvals;
  final int? glEntryId;
  final String? glDocNo;
  final String? createdBy;
  final String? updatedBy;

  const ApPaymentRun({
    this.id,
    this.runNumber,
    required this.runDate,
    this.description,
    this.bankFileFormatId,
    this.bankFileFormatCode,
    this.bankFileFormatName,
    this.checkPrintConfigId,
    this.checkPrintConfigName,
    this.paymentDate,
    this.paymentMethodId,
    this.paymentMethodCode,
    this.paymentMethodName,
    this.dueDateFilter,
    this.totalAmountLc = 0,
    this.status = 'Draft',
    this.lines = const [],
    this.approvals = const [],
    this.glEntryId,
    this.glDocNo,
    this.createdBy,
    this.updatedBy,
  });

  factory ApPaymentRun.fromJson(Map<String, dynamic> json) => ApPaymentRun(
        id: json['id'],
        runNumber: json['run_number'],
        runDate: parseLocalDate(json['run_date']),
        description: json['description'],
        bankFileFormatId: json['bank_file_format_id'],
        bankFileFormatCode: json['bank_file_format_code'],
        bankFileFormatName: json['bank_file_format_name'],
        checkPrintConfigId: json['check_print_config_id'],
        checkPrintConfigName: json['check_print_config_name'],
        paymentDate: parseLocalDateNullable(json['payment_date']),
        paymentMethodId: json['payment_method_id'],
        paymentMethodCode: json['payment_method_code'],
        paymentMethodName: json['payment_method_name'],
        dueDateFilter: parseLocalDateNullable(json['due_date_filter']),
        totalAmountLc: (json['total_amount_lc'] as num?)?.toDouble() ?? 0,
        status: json['status'] ?? 'Draft',
        lines: (json['lines'] as List<dynamic>? ?? [])
            .map((e) => ApPaymentRunLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        approvals: (json['approvals'] as List<dynamic>? ?? [])
            .map((e) => ApPaymentRunApproval.fromJson(e as Map<String, dynamic>))
            .toList(),
        glEntryId: json['gl_entry_id'],
        glDocNo: json['gl_doc_no'],
        createdBy: json['created_by'],
        updatedBy: json['updated_by'],
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'run_date': formatLocalDate(runDate),
        'description': description,
        'bank_file_format_id': bankFileFormatId,
        'check_print_config_id': checkPrintConfigId,
        'payment_date': paymentDate != null ? formatLocalDate(paymentDate!) : null,
        'payment_method_id': paymentMethodId,
        'due_date_filter': dueDateFilter != null ? formatLocalDate(dueDateFilter!) : null,
        'lines': lines.map((l) => l.toJson()).toList(),
      };
}
