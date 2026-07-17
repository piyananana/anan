import 'package:intl/intl.dart';

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  try { return DateFormat('yyyy-MM-dd').parse(v.toString().substring(0, 10)); } catch (_) { return null; }
}
double _toDouble(dynamic v) => v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;
int    _toInt(dynamic v)    => v == null ? 0   : int.tryParse(v.toString())    ?? 0;

// ── Year-End Setup ────────────────────────────────────────────────────────────
class ArYearEndSetup {
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
  final int? allowanceExpenseAccountId;
  final String? allowExpCode;
  final String? allowExpName;
  final int? allowanceContraAccountId;
  final String? allowContraCode;
  final String? allowContraName;
  final int? fxRevalGlDocId;
  final String? fxRevalDocName;
  final int? allowanceGlDocId;
  final String? allowanceDocName;

  const ArYearEndSetup({
    this.fxGainAccountId, this.fxGainCode, this.fxGainName,
    this.fxLossAccountId, this.fxLossCode, this.fxLossName,
    this.unrealizedFxGainAccountId, this.ufxGainCode, this.ufxGainName,
    this.unrealizedFxLossAccountId, this.ufxLossCode, this.ufxLossName,
    this.allowanceExpenseAccountId, this.allowExpCode, this.allowExpName,
    this.allowanceContraAccountId, this.allowContraCode, this.allowContraName,
    this.fxRevalGlDocId, this.fxRevalDocName,
    this.allowanceGlDocId, this.allowanceDocName,
  });

  factory ArYearEndSetup.fromJson(Map<String, dynamic> j) => ArYearEndSetup(
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
    allowanceExpenseAccountId:  _toInt(j['allowance_expense_account_id']),
    allowExpCode:               j['allow_exp_code'],
    allowExpName:               j['allow_exp_name'],
    allowanceContraAccountId:   _toInt(j['allowance_contra_account_id']),
    allowContraCode:            j['allow_contra_code'],
    allowContraName:            j['allow_contra_name'],
    fxRevalGlDocId:             _toInt(j['fx_reval_gl_doc_id']),
    fxRevalDocName:             j['fx_reval_doc_name'],
    allowanceGlDocId:           _toInt(j['allowance_gl_doc_id']),
    allowanceDocName:           j['allowance_doc_name'],
  );

  Map<String, dynamic> toJson() => {
    'fx_gain_account_id':             fxGainAccountId,
    'fx_loss_account_id':             fxLossAccountId,
    'unrealized_fx_gain_account_id':  unrealizedFxGainAccountId,
    'unrealized_fx_loss_account_id':  unrealizedFxLossAccountId,
    'allowance_expense_account_id':   allowanceExpenseAccountId,
    'allowance_contra_account_id':    allowanceContraAccountId,
    'fx_reval_gl_doc_id':             fxRevalGlDocId,
    'allowance_gl_doc_id':            allowanceGlDocId,
  };
}

// ── Allowance Rule ────────────────────────────────────────────────────────────
class ArAllowanceRule {
  final int? id;
  final int ageFromDays;
  final int? ageToDays;
  final double rate;
  final int sortOrder;
  final bool isActive;

  const ArAllowanceRule({
    this.id,
    required this.ageFromDays,
    this.ageToDays,
    required this.rate,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory ArAllowanceRule.fromJson(Map<String, dynamic> j) => ArAllowanceRule(
    id:           _toInt(j['id']),
    ageFromDays:  _toInt(j['age_from_days']),
    ageToDays:    j['age_to_days'] != null ? _toInt(j['age_to_days']) : null,
    rate:         _toDouble(j['rate']),
    sortOrder:    _toInt(j['sort_order']),
    isActive:     j['is_active'] == true,
  );

  Map<String, dynamic> toJson() => {
    'age_from_days': ageFromDays,
    'age_to_days':   ageToDays,
    'rate':          rate,
    'sort_order':    sortOrder,
    'is_active':     isActive,
  };

  ArAllowanceRule copyWith({int? ageFromDays, int? ageToDays, double? rate, bool? isActive}) =>
      ArAllowanceRule(
        id: id,
        ageFromDays: ageFromDays ?? this.ageFromDays,
        ageToDays:   ageToDays  ?? this.ageToDays,
        rate:        rate       ?? this.rate,
        sortOrder:   sortOrder,
        isActive:    isActive   ?? this.isActive,
      );
}

// ── Pre-Close Check ───────────────────────────────────────────────────────────
class ArPreCloseResult {
  final int periodYear;
  final int draftCount;
  final List<Map<String, dynamic>> draftDocs;
  final int openBcCount;
  final List<Map<String, dynamic>> openBcDocs;
  final int openAdvanceCount;
  final List<Map<String, dynamic>> openAdvanceDocs;
  final double arModuleBalance;
  final double glArBalance;
  final double reconcileDiff;
  final bool canProceed;

  const ArPreCloseResult({
    required this.periodYear,
    required this.draftCount,
    required this.draftDocs,
    required this.openBcCount,
    required this.openBcDocs,
    required this.openAdvanceCount,
    required this.openAdvanceDocs,
    required this.arModuleBalance,
    required this.glArBalance,
    required this.reconcileDiff,
    required this.canProceed,
  });

  factory ArPreCloseResult.fromJson(Map<String, dynamic> j) => ArPreCloseResult(
    periodYear:        _toInt(j['period_year']),
    draftCount:        _toInt(j['draft_count']),
    draftDocs:         List<Map<String, dynamic>>.from(j['draft_docs'] ?? []),
    openBcCount:       _toInt(j['open_bc_count']),
    openBcDocs:        List<Map<String, dynamic>>.from(j['open_bc_docs'] ?? []),
    openAdvanceCount:  _toInt(j['open_advance_count']),
    openAdvanceDocs:   List<Map<String, dynamic>>.from(j['open_advance_docs'] ?? []),
    arModuleBalance:   _toDouble(j['ar_module_balance']),
    glArBalance:       _toDouble(j['gl_ar_balance']),
    reconcileDiff:     _toDouble(j['reconcile_diff']),
    canProceed:        j['can_proceed'] == true,
  );
}

// ── FX Revaluation ────────────────────────────────────────────────────────────
class ArFxRevaluationHeader {
  final int id;
  final DateTime revalDate;
  final int periodYear;
  final String method;   // 'realized' | 'reversing'
  final String status;   // 'Draft' | 'Posted' | 'Void'
  final double totalFxGainLoss;
  final int? glEntryId;
  final String? glDocNo;
  final DateTime? reversalDate;
  final int? reversalGlEntryId;
  final String? reversalDocNo;
  final String? note;

  const ArFxRevaluationHeader({
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

  factory ArFxRevaluationHeader.fromJson(Map<String, dynamic> j) => ArFxRevaluationHeader(
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

class ArFxRevaluationDetail {
  final int id;
  final int invoiceId;
  final String? invoiceDocNo;
  final DateTime? invoiceDocDate;
  final int customerId;
  final String? customerCode;
  final String? customerNameTh;
  final String? customerNameEn;
  final String currencyCode;
  final double balanceAmountFc;
  final double originalRate;
  final double balanceAmountLc;
  final double yearEndRate;
  final double revaluedAmountLc;
  final double fxGainLoss;

  const ArFxRevaluationDetail({
    required this.id,
    required this.invoiceId,
    this.invoiceDocNo,
    this.invoiceDocDate,
    required this.customerId,
    this.customerCode,
    this.customerNameTh,
    this.customerNameEn,
    required this.currencyCode,
    required this.balanceAmountFc,
    required this.originalRate,
    required this.balanceAmountLc,
    required this.yearEndRate,
    required this.revaluedAmountLc,
    required this.fxGainLoss,
  });

  factory ArFxRevaluationDetail.fromJson(Map<String, dynamic> j) => ArFxRevaluationDetail(
    id:               _toInt(j['id']),
    invoiceId:        _toInt(j['invoice_id']),
    invoiceDocNo:     j['invoice_doc_no'],
    invoiceDocDate:   _parseDate(j['invoice_doc_date']),
    customerId:       _toInt(j['customer_id']),
    customerCode:     j['customer_code'],
    customerNameTh:   j['customer_name_th'],
    customerNameEn:   j['customer_name_en'],
    currencyCode:     j['currency_code'] ?? '',
    balanceAmountFc:  _toDouble(j['balance_amount_fc']),
    originalRate:     _toDouble(j['original_rate']),
    balanceAmountLc:  _toDouble(j['balance_amount_lc']),
    yearEndRate:      _toDouble(j['year_end_rate']),
    revaluedAmountLc: _toDouble(j['revalued_amount_lc']),
    fxGainLoss:       _toDouble(j['fx_gain_loss']),
  );
}

// ── Allowance Run ─────────────────────────────────────────────────────────────
class ArAllowanceRunHeader {
  final int id;
  final DateTime runDate;
  final int periodYear;
  final String status;
  final double totalAllowance;
  final double priorAllowance;
  final double adjustmentAmount;
  final int? glEntryId;
  final String? glDocNo;
  final String? note;

  const ArAllowanceRunHeader({
    required this.id,
    required this.runDate,
    required this.periodYear,
    required this.status,
    required this.totalAllowance,
    required this.priorAllowance,
    required this.adjustmentAmount,
    this.glEntryId,
    this.glDocNo,
    this.note,
  });

  factory ArAllowanceRunHeader.fromJson(Map<String, dynamic> j) => ArAllowanceRunHeader(
    id:               _toInt(j['id']),
    runDate:          _parseDate(j['run_date'])!,
    periodYear:       _toInt(j['period_year']),
    status:           j['status'] ?? 'Draft',
    totalAllowance:   _toDouble(j['total_allowance']),
    priorAllowance:   _toDouble(j['prior_allowance']),
    adjustmentAmount: _toDouble(j['adjustment_amount']),
    glEntryId:        j['gl_entry_id'] != null ? _toInt(j['gl_entry_id']) : null,
    glDocNo:          j['gl_doc_no'],
    note:             j['note'],
  );
}

class ArAllowanceRunDetail {
  final int id;
  final int invoiceId;
  final int customerId;
  final String? customerCode;
  final String? customerNameTh;
  final String? customerNameEn;
  final String? docNo;
  final String? refDocNo;
  final DateTime? docDate;
  final DateTime? dueDate;
  final int ageDays;
  final double balanceAmountLc;
  final double rate;
  final double allowanceAmount;

  const ArAllowanceRunDetail({
    required this.id,
    required this.invoiceId,
    required this.customerId,
    this.customerCode,
    this.customerNameTh,
    this.customerNameEn,
    this.docNo,
    this.refDocNo,
    this.docDate,
    this.dueDate,
    required this.ageDays,
    required this.balanceAmountLc,
    required this.rate,
    required this.allowanceAmount,
  });

  factory ArAllowanceRunDetail.fromJson(Map<String, dynamic> j) => ArAllowanceRunDetail(
    id:               _toInt(j['id']),
    invoiceId:        _toInt(j['invoice_id']),
    customerId:       _toInt(j['customer_id']),
    customerCode:     j['customer_code'],
    customerNameTh:   j['customer_name_th'],
    customerNameEn:   j['customer_name_en'],
    docNo:            j['doc_no'],
    refDocNo:         j['ref_doc_no'],
    docDate:          _parseDate(j['doc_date']),
    dueDate:          _parseDate(j['due_date']),
    ageDays:          _toInt(j['age_days']),
    balanceAmountLc:  _toDouble(j['balance_amount_lc']),
    rate:             _toDouble(j['rate']),
    allowanceAmount:  _toDouble(j['allowance_amount']),
  );
}
