import '../../utils/date_utils.dart';

DateTime? _parseDate(dynamic v) => parseLocalDateNullable(v);
double _toDouble(dynamic v) => v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;
int    _toInt(dynamic v)    => v == null ? 0   : int.tryParse(v.toString())    ?? 0;

// ── Year-End Setup ────────────────────────────────────────────────────────────
class ApYearEndSetup {
  final int? fxGainAccountId;
  final String? fxGainCode;
  final String? fxGainName;
  final int? fxLossAccountId;
  final String? fxLossCode;
  final String? fxLossName;
  final int? unrealizedFxGainAccountId;
  final String? ufxGainCode;
  final String? ufxGainName;
  final int? unrealizedFxLossAccountId;
  final String? ufxLossCode;
  final String? ufxLossName;
  final int? fxRevalGlDocId;
  final String? fxRevalDocName;

  const ApYearEndSetup({
    this.fxGainAccountId, this.fxGainCode, this.fxGainName,
    this.fxLossAccountId, this.fxLossCode, this.fxLossName,
    this.unrealizedFxGainAccountId, this.ufxGainCode, this.ufxGainName,
    this.unrealizedFxLossAccountId, this.ufxLossCode, this.ufxLossName,
    this.fxRevalGlDocId, this.fxRevalDocName,
  });

  factory ApYearEndSetup.fromJson(Map<String, dynamic> j) => ApYearEndSetup(
    fxGainAccountId:            _toInt(j['fx_gain_account_id']),
    fxGainCode:                 j['fx_gain_code'],
    fxGainName:                 j['fx_gain_name'],
    fxLossAccountId:            _toInt(j['fx_loss_account_id']),
    fxLossCode:                 j['fx_loss_code'],
    fxLossName:                 j['fx_loss_name'],
    unrealizedFxGainAccountId:  _toInt(j['unrealized_fx_gain_account_id']),
    ufxGainCode:                j['ufx_gain_code'],
    ufxGainName:                j['ufx_gain_name'],
    unrealizedFxLossAccountId:  _toInt(j['unrealized_fx_loss_account_id']),
    ufxLossCode:                j['ufx_loss_code'],
    ufxLossName:                j['ufx_loss_name'],
    fxRevalGlDocId:             _toInt(j['fx_reval_gl_doc_id']),
    fxRevalDocName:             j['fx_reval_doc_name'],
  );

  Map<String, dynamic> toJson() => {
    'fx_gain_account_id':            fxGainAccountId,
    'fx_loss_account_id':            fxLossAccountId,
    'unrealized_fx_gain_account_id': unrealizedFxGainAccountId,
    'unrealized_fx_loss_account_id': unrealizedFxLossAccountId,
    'fx_reval_gl_doc_id':            fxRevalGlDocId,
  };
}

// ── Pre-Close Check ───────────────────────────────────────────────────────────
class ApPreCloseResult {
  final int periodYear;
  final int draftCount;
  final List<Map<String, dynamic>> draftDocs;
  final int openAdvanceCount;
  final List<Map<String, dynamic>> openAdvanceDocs;
  final double apModuleBalance;
  final double glApBalance;
  final double reconcileDiff;
  final bool canProceed;

  const ApPreCloseResult({
    required this.periodYear,
    required this.draftCount,
    required this.draftDocs,
    required this.openAdvanceCount,
    required this.openAdvanceDocs,
    required this.apModuleBalance,
    required this.glApBalance,
    required this.reconcileDiff,
    required this.canProceed,
  });

  factory ApPreCloseResult.fromJson(Map<String, dynamic> j) => ApPreCloseResult(
    periodYear:        _toInt(j['period_year']),
    draftCount:        _toInt(j['draft_count']),
    draftDocs:         List<Map<String, dynamic>>.from(j['draft_docs'] ?? []),
    openAdvanceCount:  _toInt(j['open_advance_count']),
    openAdvanceDocs:   List<Map<String, dynamic>>.from(j['open_advance_docs'] ?? []),
    apModuleBalance:   _toDouble(j['ap_module_balance']),
    glApBalance:       _toDouble(j['gl_ap_balance']),
    reconcileDiff:     _toDouble(j['reconcile_diff']),
    canProceed:        j['can_proceed'] == true,
  );
}

// ── FX Revaluation ────────────────────────────────────────────────────────────
class ApFxRevaluationHeader {
  final int id;
  final DateTime revalDate;
  final int periodYear;
  final String method;
  final String status;
  final double totalFxGainLoss;
  final int? glEntryId;
  final String? glDocNo;
  final DateTime? reversalDate;
  final int? reversalGlEntryId;
  final String? reversalDocNo;
  final String? note;

  const ApFxRevaluationHeader({
    required this.id,
    required this.revalDate,
    required this.periodYear,
    required this.method,
    required this.status,
    required this.totalFxGainLoss,
    this.glEntryId,
    this.glDocNo,
    this.reversalDate,
    this.reversalGlEntryId,
    this.reversalDocNo,
    this.note,
  });

  factory ApFxRevaluationHeader.fromJson(Map<String, dynamic> j) => ApFxRevaluationHeader(
    id:                 _toInt(j['id']),
    revalDate:          _parseDate(j['reval_date'])!,
    periodYear:         _toInt(j['period_year']),
    method:             j['method'] ?? 'realized',
    status:             j['status'] ?? 'Draft',
    totalFxGainLoss:    _toDouble(j['total_fx_gain_loss']),
    glEntryId:          j['gl_entry_id'] != null ? _toInt(j['gl_entry_id']) : null,
    glDocNo:            j['gl_doc_no'],
    reversalDate:       _parseDate(j['reversal_date']),
    reversalGlEntryId:  j['reversal_gl_entry_id'] != null ? _toInt(j['reversal_gl_entry_id']) : null,
    reversalDocNo:      j['reversal_doc_no'],
    note:               j['note'],
  );
}

class ApFxRevaluationDetail {
  final int id;
  final int invoiceId;
  final String? invoiceDocNo;
  final DateTime? invoiceDocDate;
  final int vendorId;
  final String? vendorCode;
  final String? vendorNameTh;
  final String? vendorNameEn;
  final String currencyCode;
  final double balanceAmountFc;
  final double originalRate;
  final double balanceAmountLc;
  final double yearEndRate;
  final double revaluedAmountLc;
  final double fxGainLoss;

  const ApFxRevaluationDetail({
    required this.id,
    required this.invoiceId,
    this.invoiceDocNo,
    this.invoiceDocDate,
    required this.vendorId,
    this.vendorCode,
    this.vendorNameTh,
    this.vendorNameEn,
    required this.currencyCode,
    required this.balanceAmountFc,
    required this.originalRate,
    required this.balanceAmountLc,
    required this.yearEndRate,
    required this.revaluedAmountLc,
    required this.fxGainLoss,
  });

  factory ApFxRevaluationDetail.fromJson(Map<String, dynamic> j) => ApFxRevaluationDetail(
    id:               _toInt(j['id']),
    invoiceId:        _toInt(j['invoice_id']),
    invoiceDocNo:     j['invoice_doc_no'],
    invoiceDocDate:   _parseDate(j['invoice_doc_date']),
    vendorId:         _toInt(j['vendor_id']),
    vendorCode:       j['vendor_code'],
    vendorNameTh:     j['vendor_name_th'],
    vendorNameEn:     j['vendor_name_en'],
    currencyCode:     j['currency_code'] ?? '',
    balanceAmountFc:  _toDouble(j['balance_amount_fc']),
    originalRate:     _toDouble(j['original_rate']),
    balanceAmountLc:  _toDouble(j['balance_amount_lc']),
    yearEndRate:      _toDouble(j['year_end_rate']),
    revaluedAmountLc: _toDouble(j['revalued_amount_lc']),
    fxGainLoss:       _toDouble(j['fx_gain_loss']),
  );
}
