// lib/cm/models/cm_receipt.dart

import '../../utils/date_utils.dart';

class CmReceipt {
  final int?     id;
  final DateTime receiptDate;
  final int?     bankAccountId;
  final String?  bankAccountCode;
  final String?  bankAccountName;
  final String?  bankName;
  final int?     paymentMethodId;
  final String   paymentMethodType;
  final String?  paymentMethodCode;
  final String?  paymentMethodName;
  final int?     arTransactionId;
  final String?  arDocNo;
  final int?     customerId;
  final String?  customerCode;
  final String?  customerNameTh;
  final double   amountLc;
  final double   amountFc;
  final String   currencyCode;
  final double   exchangeRate;
  final String?  checkNo;
  final DateTime? checkDate;
  final String?  drawerBank;
  final String   status;
  final DateTime? clearingDate;
  final String?  clearingNote;
  final int?     glEntryId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CmReceipt({
    this.id,
    required this.receiptDate,
    this.bankAccountId,
    this.bankAccountCode,
    this.bankAccountName,
    this.bankName,
    this.paymentMethodId,
    this.paymentMethodType = 'CASH',
    this.paymentMethodCode,
    this.paymentMethodName,
    this.arTransactionId,
    this.arDocNo,
    this.customerId,
    this.customerCode,
    this.customerNameTh,
    this.amountLc = 0,
    this.amountFc = 0,
    this.currencyCode = 'THB',
    this.exchangeRate = 1,
    this.checkNo,
    this.checkDate,
    this.drawerBank,
    this.status = 'Pending',
    this.clearingDate,
    this.clearingNote,
    this.glEntryId,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPending  => status == 'Pending';
  bool get isCleared  => status == 'Cleared';
  bool get isBounced  => status == 'Bounced';
  bool get isVoided   => status == 'Voided';
  bool get isCheck    => paymentMethodType == 'CHECK';
  bool get isFcy      => currencyCode != 'THB';

  factory CmReceipt.fromJson(Map<String, dynamic> j) => CmReceipt(
    id:                  j['id'],
    receiptDate:         parseLocalDate(j['receipt_date']),
    bankAccountId:       j['bank_account_id'],
    bankAccountCode:     j['bank_account_code'],
    bankAccountName:     j['bank_account_name'],
    bankName:            j['bank_name'],
    paymentMethodId:     j['payment_method_id'],
    paymentMethodType:   j['payment_method_type'] ?? 'CASH',
    paymentMethodCode:   j['payment_method_code'],
    paymentMethodName:   j['payment_method_name'],
    arTransactionId:     j['ar_transaction_id'],
    arDocNo:             j['ar_doc_no'],
    customerId:          j['customer_id'],
    customerCode:        j['customer_code'],
    customerNameTh:      j['customer_name_th'],
    amountLc:            double.tryParse(j['amount_lc']?.toString() ?? '0') ?? 0,
    amountFc:            double.tryParse(j['amount_fc']?.toString() ?? '0') ?? 0,
    currencyCode:        j['currency_code'] ?? 'THB',
    exchangeRate:        double.tryParse(j['exchange_rate']?.toString() ?? '1') ?? 1,
    checkNo:             j['check_no'],
    checkDate:           parseLocalDateNullable(j['check_date']),
    drawerBank:          j['drawer_bank'],
    status:              j['status'] ?? 'Pending',
    clearingDate:        parseLocalDateNullable(j['clearing_date']),
    clearingNote:        j['clearing_note'],
    glEntryId:           j['gl_entry_id'],
    createdAt:           j['created_at'] != null ? DateTime.tryParse(j['created_at']) : null,
    updatedAt:           j['updated_at'] != null ? DateTime.tryParse(j['updated_at']) : null,
  );
}

const Map<String, String> cmReceiptStatusOptions = {
  'Pending': 'รอเคลียร์',
  'Cleared': 'เคลียร์แล้ว',
  'Bounced': 'เช็คคืน',
  'Voided':  'ยกเลิก',
};

const Map<String, String> cmReceiptStatusOptionsEng = {
  'Pending': 'Pending',
  'Cleared': 'Cleared',
  'Bounced': 'Bounced',
  'Voided':  'Voided',
};

String cmReceiptStatusLabel(String s, bool isEnglish) =>
    (isEnglish ? cmReceiptStatusOptionsEng[s] : cmReceiptStatusOptions[s]) ?? s;

const Map<String, String> cmPaymentMethodTypeLabels = {
  'CASH':             'เงินสด',
  'CHECK':            'เช็ค',
  'TRANSFER':         'โอนเงิน',
  'CREDIT_CARD':      'บัตรเครดิต',
  'DEBIT_CARD':       'บัตรเดบิต',
  'QR_CODE':          'QR Code',
  'MOBILE_BANKING':   'Mobile Banking',
  'BILL_OF_EXCHANGE': 'ตั๋วแลกเงิน',
};

const Map<String, String> cmPaymentMethodTypeLabelsEng = {
  'CASH':             'Cash',
  'CHECK':            'Check',
  'TRANSFER':         'Transfer',
  'CREDIT_CARD':      'Credit Card',
  'DEBIT_CARD':       'Debit Card',
  'QR_CODE':          'QR Code',
  'MOBILE_BANKING':   'Mobile Banking',
  'BILL_OF_EXCHANGE': 'Bill of Exchange',
};

String cmPaymentMethodTypeLabel(String t, bool isEnglish) =>
    (isEnglish ? cmPaymentMethodTypeLabelsEng[t] : cmPaymentMethodTypeLabels[t]) ?? t;
