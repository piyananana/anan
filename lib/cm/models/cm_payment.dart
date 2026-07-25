// lib/cm/models/cm_payment.dart

import '../../utils/date_utils.dart';

class CmPayment {
  final int?     id;
  final DateTime paymentDate;
  final int?     bankAccountId;
  final String?  bankAccountCode;
  final String?  bankAccountName;
  final String?  bankName;
  final int?     paymentMethodId;
  final String   paymentMethodType;
  final String?  paymentMethodCode;
  final String?  paymentMethodName;
  final int?     apPaymentRunId;
  final String?  apDocNo;
  final String   payeeType;
  final int?     payeeId;
  final String?  payeeCode;
  final String?  payeeNameTh;
  final double   amountLc;
  final double   amountFc;
  final String   currencyCode;
  final double   exchangeRate;
  final String?  checkNo;
  final DateTime? checkDate;
  final int?     checkbookId;
  final String?  checkbookCode;
  final String   status;
  final DateTime? clearingDate;
  final String?  clearingNote;
  final int?     glEntryId;
  final String?  remark;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CmPayment({
    this.id,
    required this.paymentDate,
    this.bankAccountId,
    this.bankAccountCode,
    this.bankAccountName,
    this.bankName,
    this.paymentMethodId,
    this.paymentMethodType = 'TRANSFER',
    this.paymentMethodCode,
    this.paymentMethodName,
    this.apPaymentRunId,
    this.apDocNo,
    this.payeeType = 'VENDOR',
    this.payeeId,
    this.payeeCode,
    this.payeeNameTh,
    this.amountLc = 0,
    this.amountFc = 0,
    this.currencyCode = 'THB',
    this.exchangeRate = 1,
    this.checkNo,
    this.checkDate,
    this.checkbookId,
    this.checkbookCode,
    this.status = 'Pending',
    this.clearingDate,
    this.clearingNote,
    this.glEntryId,
    this.remark,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPending   => status == 'Pending';
  bool get isCleared   => status == 'Cleared';
  bool get isVoided    => status == 'Voided';
  bool get isCheck     => paymentMethodType == 'CHECK';
  bool get isFromAp    => apPaymentRunId != null;
  bool get isFcy       => currencyCode != 'THB';

  Map<String, dynamic> toJson() => {
    'payment_date':       formatLocalDate(paymentDate),
    'bank_account_id':    bankAccountId,
    'payment_method_id':  paymentMethodId,
    'payment_method_type': paymentMethodType,
    'payee_type':         payeeType,
    'payee_id':           payeeId,
    'payee_code':         payeeCode,
    'payee_name_th':      payeeNameTh,
    'amount_lc':          amountLc,
    'amount_fc':          amountFc,
    'currency_code':      currencyCode,
    'exchange_rate':      exchangeRate,
    'check_no':           checkNo,
    'check_date':         checkDate != null ? formatLocalDate(checkDate!) : null,
    'checkbook_id':       checkbookId,
    'remark':             remark,
  };

  factory CmPayment.fromJson(Map<String, dynamic> j) => CmPayment(
    id:                j['id'],
    paymentDate:       parseLocalDate(j['payment_date']),
    bankAccountId:     j['bank_account_id'],
    bankAccountCode:   j['bank_account_code'],
    bankAccountName:   j['bank_account_name'],
    bankName:          j['bank_name'],
    paymentMethodId:   j['payment_method_id'],
    paymentMethodType: j['payment_method_type'] ?? 'TRANSFER',
    paymentMethodCode: j['payment_method_code'],
    paymentMethodName: j['payment_method_name'],
    apPaymentRunId:    j['ap_payment_run_id'],
    apDocNo:           j['ap_doc_no'],
    payeeType:         j['payee_type'] ?? 'VENDOR',
    payeeId:           j['payee_id'],
    payeeCode:         j['payee_code'],
    payeeNameTh:       j['payee_name_th'],
    amountLc:          double.tryParse(j['amount_lc']?.toString() ?? '0') ?? 0,
    amountFc:          double.tryParse(j['amount_fc']?.toString() ?? '0') ?? 0,
    currencyCode:      j['currency_code'] ?? 'THB',
    exchangeRate:      double.tryParse(j['exchange_rate']?.toString() ?? '1') ?? 1,
    checkNo:           j['check_no'],
    checkDate:         parseLocalDateNullable(j['check_date']),
    checkbookId:       j['checkbook_id'],
    checkbookCode:     j['checkbook_code'],
    status:            j['status'] ?? 'Pending',
    clearingDate:      parseLocalDateNullable(j['clearing_date']),
    clearingNote:      j['clearing_note'],
    glEntryId:         j['gl_entry_id'],
    remark:            j['remark'],
    createdAt:         j['created_at'] != null ? DateTime.tryParse(j['created_at']) : null,
    updatedAt:         j['updated_at'] != null ? DateTime.tryParse(j['updated_at']) : null,
  );
}

const Map<String, String> cmPaymentStatusOptions = {
  'Pending': 'รอเคลียร์',
  'Cleared': 'เคลียร์แล้ว',
  'Voided':  'ยกเลิก',
};
