// lib/cm/models/cm_inter_bank_transfer.dart

import '../../utils/date_utils.dart';

class CmInterBankTransfer {
  final int? id;
  final String? transferNo;
  final DateTime transferDate;
  final int fromBankAccountId;
  final String? fromAccountCode;
  final String? fromAccountName;
  final int? fromGlAccountId;
  final String? fromBankShortName;
  final int toBankAccountId;
  final String? toAccountCode;
  final String? toAccountName;
  final int? toGlAccountId;
  final String? toBankShortName;
  final double amount;
  final String currencyCode;
  final double exchangeRate;
  final double amountLc;
  final String? description;
  final String status;
  final int? glDocId;
  final String? glDocCode;
  final String? glDocName;
  final String? glDocNo;
  final int? glEntryId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CmInterBankTransfer({
    this.id,
    this.transferNo,
    required this.transferDate,
    required this.fromBankAccountId,
    this.fromAccountCode,
    this.fromAccountName,
    this.fromGlAccountId,
    this.fromBankShortName,
    required this.toBankAccountId,
    this.toAccountCode,
    this.toAccountName,
    this.toGlAccountId,
    this.toBankShortName,
    required this.amount,
    this.currencyCode = 'THB',
    this.exchangeRate = 1,
    required this.amountLc,
    this.description,
    this.status = 'Draft',
    this.glDocId,
    this.glDocCode,
    this.glDocName,
    this.glDocNo,
    this.glEntryId,
    this.createdAt,
    this.updatedAt,
  });

  bool get isDraft  => status == 'Draft';
  bool get isPosted => status == 'Posted';
  bool get isVoided => status == 'Voided';

  factory CmInterBankTransfer.fromJson(Map<String, dynamic> j) =>
      CmInterBankTransfer(
        id:                j['id'],
        transferNo:        j['transfer_no'],
        transferDate:      parseLocalDate(j['transfer_date']),
        fromBankAccountId: j['from_bank_account_id'],
        fromAccountCode:   j['from_account_code'],
        fromAccountName:   j['from_account_name'],
        fromGlAccountId:   j['from_gl_account_id'],
        fromBankShortName: j['from_bank_short_name'],
        toBankAccountId:   j['to_bank_account_id'],
        toAccountCode:     j['to_account_code'],
        toAccountName:     j['to_account_name'],
        toGlAccountId:     j['to_gl_account_id'],
        toBankShortName:   j['to_bank_short_name'],
        amount:            double.tryParse(j['amount']?.toString()       ?? '0') ?? 0,
        currencyCode:      j['currency_code'] ?? 'THB',
        exchangeRate:      double.tryParse(j['exchange_rate']?.toString() ?? '1') ?? 1,
        amountLc:          double.tryParse(j['amount_lc']?.toString()    ?? '0') ?? 0,
        description:       j['description'],
        status:            j['status'] ?? 'Draft',
        glDocId:           j['gl_doc_id'],
        glDocCode:         j['gl_doc_code'],
        glDocName:         j['gl_doc_name'],
        glDocNo:           j['gl_doc_no'],
        glEntryId:         j['gl_entry_id'],
        createdAt:  j['created_at'] != null ? DateTime.parse(j['created_at'].toString()) : null,
        updatedAt:  j['updated_at'] != null ? DateTime.parse(j['updated_at'].toString()) : null,
      );
}

const Map<String, String> cmTransferStatusOptions = {
  'Draft':  'ร่าง',
  'Posted': 'บันทึก GL แล้ว',
  'Voided': 'ยกเลิก',
};
