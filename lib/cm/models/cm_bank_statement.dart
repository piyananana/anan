// lib/cm/models/cm_bank_statement.dart

import '../../utils/date_utils.dart';

class CmBankStatement {
  final int id;
  final int? bankAccountId;
  final String? bankAccountCode;
  final String? bankAccountName;
  final String? bankName;
  final String? bankShortName;
  final DateTime statementDateFrom;
  final DateTime statementDateTo;
  final double openingBalance;
  final double closingBalance;
  final String currencyCode;
  final String status; // Draft / Confirmed / Voided
  final String? fileName;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CmBankStatement({
    required this.id,
    this.bankAccountId,
    this.bankAccountCode,
    this.bankAccountName,
    this.bankName,
    this.bankShortName,
    required this.statementDateFrom,
    required this.statementDateTo,
    required this.openingBalance,
    required this.closingBalance,
    required this.currencyCode,
    required this.status,
    this.fileName,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  bool get isDraft     => status == 'Draft';
  bool get isConfirmed => status == 'Confirmed';
  bool get isVoided    => status == 'Voided';

  factory CmBankStatement.fromJson(Map<String, dynamic> j) => CmBankStatement(
    id:                  j['id'] as int,
    bankAccountId:       j['bank_account_id'] as int?,
    bankAccountCode:     j['bank_account_code'] as String?,
    bankAccountName:     j['bank_account_name'] as String?,
    bankName:            j['bank_name'] as String?,
    bankShortName:       j['bank_short_name'] as String?,
    statementDateFrom:   parseLocalDate(j['statement_date_from']),
    statementDateTo:     parseLocalDate(j['statement_date_to']),
    openingBalance:      double.tryParse(j['opening_balance']?.toString() ?? '0') ?? 0,
    closingBalance:      double.tryParse(j['closing_balance']?.toString() ?? '0') ?? 0,
    currencyCode:        j['currency_code'] as String? ?? 'THB',
    status:              j['status'] as String? ?? 'Draft',
    fileName:            j['file_name'] as String?,
    notes:               j['notes'] as String?,
    createdAt:           j['created_at'] != null ? DateTime.tryParse(j['created_at'].toString()) : null,
    updatedAt:           j['updated_at'] != null ? DateTime.tryParse(j['updated_at'].toString()) : null,
  );
}

const Map<String, String> cmStmtStatusOptions = {
  'Draft':     'ร่าง',
  'Confirmed': 'ยืนยัน',
  'Voided':    'ยกเลิก',
};

const Map<String, String> cmStmtStatusOptionsEng = {
  'Draft':     'Draft',
  'Confirmed': 'Confirmed',
  'Voided':    'Voided',
};

String cmStmtStatusLabel(String s, bool isEnglish) =>
    (isEnglish ? cmStmtStatusOptionsEng[s] : cmStmtStatusOptions[s]) ?? s;

// ---------------------------------------------------------------------------

class CmBankStatementLine {
  final int id;
  final int statementId;
  final DateTime lineDate;
  final String? description;
  final double withdrawalAmount;
  final double depositAmount;
  final double balance;
  final String? reference;
  final bool isReconciled;
  final DateTime? reconcileDate;
  final String? cmRecordType;
  final int? cmRecordId;

  const CmBankStatementLine({
    required this.id,
    required this.statementId,
    required this.lineDate,
    this.description,
    required this.withdrawalAmount,
    required this.depositAmount,
    required this.balance,
    this.reference,
    required this.isReconciled,
    this.reconcileDate,
    this.cmRecordType,
    this.cmRecordId,
  });

  factory CmBankStatementLine.fromJson(Map<String, dynamic> j) => CmBankStatementLine(
    id:               j['id'] as int,
    statementId:      j['statement_id'] as int,
    lineDate:         parseLocalDate(j['line_date']),
    description:      j['description'] as String?,
    withdrawalAmount: double.tryParse(j['withdrawal_amount']?.toString() ?? '0') ?? 0,
    depositAmount:    double.tryParse(j['deposit_amount']?.toString() ?? '0') ?? 0,
    balance:          double.tryParse(j['balance']?.toString() ?? '0') ?? 0,
    reference:        j['reference'] as String?,
    isReconciled:     j['is_reconciled'] == true || j['is_reconciled'] == 'true',
    reconcileDate:    parseLocalDateNullable(j['reconcile_date']),
    cmRecordType: j['cm_record_type'] as String?,
    cmRecordId:   j['cm_record_id'] as int?,
  );
}

// ---------------------------------------------------------------------------

class CmReconcileRecord {
  final int id;
  final String recordType; // RECEIPT / PAYMENT
  final DateTime recordDate;
  final String? docNo;
  final String? description;
  final double amount;
  final bool isReconciled;
  final DateTime? reconcileDate;
  final int? statementLineId;
  final String? status;

  const CmReconcileRecord({
    required this.id,
    required this.recordType,
    required this.recordDate,
    this.docNo,
    this.description,
    required this.amount,
    required this.isReconciled,
    this.reconcileDate,
    this.statementLineId,
    this.status,
  });

  factory CmReconcileRecord.fromJson(Map<String, dynamic> j) => CmReconcileRecord(
    id:              j['id'] as int,
    recordType:      j['record_type'] as String,
    recordDate:      parseLocalDate(j['record_date']),
    docNo:           j['doc_no'] as String?,
    description:     j['description'] as String?,
    amount:          double.tryParse(j['amount']?.toString() ?? '0') ?? 0,
    isReconciled:    j['is_reconciled'] == true || j['is_reconciled'] == 'true',
    reconcileDate:   parseLocalDateNullable(j['reconcile_date']),
    statementLineId: j['statement_line_id'] as int?,
    status:          j['status'] as String?,
  );
}
