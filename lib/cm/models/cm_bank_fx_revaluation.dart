// lib/cm/models/cm_bank_fx_revaluation.dart

import '../../utils/date_utils.dart';

class CmBankFxRevaluationLine {
  final int id;
  final int revaluationId;
  final int? bankAccountId;
  final String? bankAccountCode;
  final String? bankAccountName;
  final String? bankShortName;
  final int? glAccountId;
  final String? glAccountCode;
  final String currencyCode;
  final double balanceFc;
  final double balanceLcBook;
  final double newRate;
  final double balanceLcNew;
  final double fxGainLoss;

  const CmBankFxRevaluationLine({
    required this.id,
    required this.revaluationId,
    this.bankAccountId,
    this.bankAccountCode,
    this.bankAccountName,
    this.bankShortName,
    this.glAccountId,
    this.glAccountCode,
    required this.currencyCode,
    required this.balanceFc,
    required this.balanceLcBook,
    required this.newRate,
    required this.balanceLcNew,
    required this.fxGainLoss,
  });

  factory CmBankFxRevaluationLine.fromJson(Map<String, dynamic> j) =>
      CmBankFxRevaluationLine(
        id:               j['id'] as int,
        revaluationId:    j['revaluation_id'] as int,
        bankAccountId:    j['bank_account_id'] as int?,
        bankAccountCode:  j['bank_account_code'] as String?,
        bankAccountName:  j['bank_account_name'] as String?,
        bankShortName:    j['bank_short_name'] as String?,
        glAccountId:      j['gl_account_id'] as int?,
        glAccountCode:    j['gl_account_code'] as String?,
        currencyCode:     j['currency_code'] as String? ?? 'USD',
        balanceFc:        double.tryParse(j['balance_fc']?.toString()      ?? '0') ?? 0,
        balanceLcBook:    double.tryParse(j['balance_lc_book']?.toString() ?? '0') ?? 0,
        newRate:          double.tryParse(j['new_rate']?.toString()        ?? '1') ?? 1,
        balanceLcNew:     double.tryParse(j['balance_lc_new']?.toString()  ?? '0') ?? 0,
        fxGainLoss:       double.tryParse(j['fx_gain_loss']?.toString()    ?? '0') ?? 0,
      );
}

// Preview line (from POST /preview) — has no id yet
class CmFxPreviewLine {
  final int? bankAccountId;
  final String? bankAccountCode;
  final String? bankAccountName;
  final String? bankShortName;
  final int? glAccountId;
  final String? glAccountCode;
  final String currencyCode;
  final double balanceFc;
  final double balanceLcBook;
  final double newRate;
  final double balanceLcNew;
  final double fxGainLoss;

  const CmFxPreviewLine({
    this.bankAccountId,
    this.bankAccountCode,
    this.bankAccountName,
    this.bankShortName,
    this.glAccountId,
    this.glAccountCode,
    required this.currencyCode,
    required this.balanceFc,
    required this.balanceLcBook,
    required this.newRate,
    required this.balanceLcNew,
    required this.fxGainLoss,
  });

  factory CmFxPreviewLine.fromJson(Map<String, dynamic> j) => CmFxPreviewLine(
    bankAccountId:   j['bank_account_id'] as int?,
    bankAccountCode: j['bank_account_code'] as String?,
    bankAccountName: j['bank_account_name'] as String?,
    bankShortName:   j['bank_short_name'] as String?,
    glAccountId:     j['gl_account_id'] as int?,
    glAccountCode:   j['gl_account_code'] as String?,
    currencyCode:    j['currency_code'] as String? ?? 'USD',
    balanceFc:       double.tryParse(j['balance_fc']?.toString()      ?? '0') ?? 0,
    balanceLcBook:   double.tryParse(j['balance_lc_book']?.toString() ?? '0') ?? 0,
    newRate:         double.tryParse(j['new_rate']?.toString()        ?? '1') ?? 1,
    balanceLcNew:    double.tryParse(j['balance_lc_new']?.toString()  ?? '0') ?? 0,
    fxGainLoss:      double.tryParse(j['fx_gain_loss']?.toString()    ?? '0') ?? 0,
  );
}

class CmBankFxRevaluation {
  final int id;
  final DateTime revaluationDate;
  final String? description;
  final int? glDocId;
  final String? glDocCode;
  final String? glDocName;
  final int? fxGainAccountId;
  final String? fxGainAccountCode;
  final String? fxGainAccountName;
  final int? fxLossAccountId;
  final String? fxLossAccountCode;
  final String? fxLossAccountName;
  final double totalGainLoss;
  final String status; // Draft / Posted / Voided
  final int? glEntryId;
  final String? glDocNo;
  final List<CmBankFxRevaluationLine> lines;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CmBankFxRevaluation({
    required this.id,
    required this.revaluationDate,
    this.description,
    this.glDocId,
    this.glDocCode,
    this.glDocName,
    this.fxGainAccountId,
    this.fxGainAccountCode,
    this.fxGainAccountName,
    this.fxLossAccountId,
    this.fxLossAccountCode,
    this.fxLossAccountName,
    required this.totalGainLoss,
    required this.status,
    this.glEntryId,
    this.glDocNo,
    this.lines = const [],
    this.createdAt,
    this.updatedAt,
  });

  bool get isDraft  => status == 'Draft';
  bool get isPosted => status == 'Posted';
  bool get isVoided => status == 'Voided';

  factory CmBankFxRevaluation.fromJson(Map<String, dynamic> j) {
    final rawLines = j['lines'] as List?;
    return CmBankFxRevaluation(
      id:                  j['id'] as int,
      revaluationDate:     parseLocalDate(j['revaluation_date']),
      description:         j['description'] as String?,
      glDocId:             j['gl_doc_id'] as int?,
      glDocCode:           j['gl_doc_code'] as String?,
      glDocName:           j['gl_doc_name'] as String?,
      fxGainAccountId:     j['fx_gain_account_id'] as int?,
      fxGainAccountCode:   j['fx_gain_account_code'] as String?,
      fxGainAccountName:   j['fx_gain_account_name'] as String?,
      fxLossAccountId:     j['fx_loss_account_id'] as int?,
      fxLossAccountCode:   j['fx_loss_account_code'] as String?,
      fxLossAccountName:   j['fx_loss_account_name'] as String?,
      totalGainLoss:       double.tryParse(j['total_gain_loss']?.toString() ?? '0') ?? 0,
      status:              j['status'] as String? ?? 'Draft',
      glEntryId:           j['gl_entry_id'] as int?,
      glDocNo:             j['gl_doc_no'] as String?,
      lines:               rawLines != null
          ? rawLines.map((e) => CmBankFxRevaluationLine.fromJson(e as Map<String, dynamic>)).toList()
          : const [],
      createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at'].toString()) : null,
      updatedAt: j['updated_at'] != null ? DateTime.tryParse(j['updated_at'].toString()) : null,
    );
  }
}

const Map<String, String> cmFxRevalStatusOptions = {
  'Draft':  'ร่าง',
  'Posted': 'บันทึก GL แล้ว',
  'Voided': 'ยกเลิก',
};
