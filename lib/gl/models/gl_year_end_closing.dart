// lib/gl/models/gl_year_end_closing.dart

class ClosingConfig {
  final int? id;
  final int incomeSummaryAccountId;
  final String incomeSummaryAccountCode;
  final String incomeSummaryAccountName;
  final int retainedEarningsAccountId;
  final String retainedEarningsAccountCode;
  final String retainedEarningsAccountName;
  final List<String> revenueAccountTypes;
  final List<String> expenseAccountTypes;
  final int? closingDocId;
  final int? carryForwardDocId;

  ClosingConfig({
    this.id,
    required this.incomeSummaryAccountId,
    this.incomeSummaryAccountCode = '',
    this.incomeSummaryAccountName = '',
    required this.retainedEarningsAccountId,
    this.retainedEarningsAccountCode = '',
    this.retainedEarningsAccountName = '',
    this.revenueAccountTypes = const ['REVENUE'],
    this.expenseAccountTypes = const ['EXPENSE'],
    this.closingDocId,
    this.carryForwardDocId,
  });

  factory ClosingConfig.fromJson(Map<String, dynamic> json) {
    return ClosingConfig(
      id: json['id'],
      incomeSummaryAccountId: json['income_summary_account_id'],
      incomeSummaryAccountCode: json['income_summary_account_code'] ?? '',
      incomeSummaryAccountName: json['income_summary_account_name'] ?? '',
      retainedEarningsAccountId: json['retained_earnings_account_id'],
      retainedEarningsAccountCode: json['retained_earnings_account_code'] ?? '',
      retainedEarningsAccountName: json['retained_earnings_account_name'] ?? '',
      revenueAccountTypes: List<String>.from(json['revenue_account_types'] ?? ['REVENUE']),
      expenseAccountTypes: List<String>.from(json['expense_account_types'] ?? ['EXPENSE']),
      closingDocId: json['closing_doc_id'],
      carryForwardDocId: json['carry_forward_doc_id'],
    );
  }

  Map<String, dynamic> toJson() => {
        'income_summary_account_id': incomeSummaryAccountId,
        'retained_earnings_account_id': retainedEarningsAccountId,
        'revenue_account_types': revenueAccountTypes,
        'expense_account_types': expenseAccountTypes,
        'closing_doc_id': closingDocId,
        'carry_forward_doc_id': carryForwardDocId,
      };
}

class AdjustingTemplate {
  final int id;
  final String templateName;
  final String description;
  final int? debitAccountId;
  final String debitAccountCode;
  final String debitAccountName;
  final int? creditAccountId;
  final String creditAccountCode;
  final String creditAccountName;
  final double defaultAmount;
  final bool isActive;
  final int sortOrder;

  AdjustingTemplate({
    this.id = 0,
    required this.templateName,
    this.description = '',
    this.debitAccountId,
    this.debitAccountCode = '',
    this.debitAccountName = '',
    this.creditAccountId,
    this.creditAccountCode = '',
    this.creditAccountName = '',
    this.defaultAmount = 0,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory AdjustingTemplate.fromJson(Map<String, dynamic> json) {
    return AdjustingTemplate(
      id: json['id'] ?? 0,
      templateName: json['template_name'] ?? '',
      description: json['description'] ?? '',
      debitAccountId: json['debit_account_id'],
      debitAccountCode: json['debit_account_code'] ?? '',
      debitAccountName: json['debit_account_name'] ?? '',
      creditAccountId: json['credit_account_id'],
      creditAccountCode: json['credit_account_code'] ?? '',
      creditAccountName: json['credit_account_name'] ?? '',
      defaultAmount: double.tryParse(json['default_amount']?.toString() ?? '0') ?? 0,
      isActive: json['is_active'] ?? true,
      sortOrder: json['sort_order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'template_name': templateName,
        'description': description,
        'debit_account_id': debitAccountId,
        'credit_account_id': creditAccountId,
        'default_amount': defaultAmount,
        'is_active': isActive,
        'sort_order': sortOrder,
      };
}

class YearEndClosing {
  final int id;
  final int fiscalYearId;
  final String status; // IN_PROGRESS, COMPLETED, CANCELLED
  final bool? step1ChecklistOk;
  final Map<String, dynamic>? step1Result;
  final bool? step2AdjustingOk;
  final bool? step3ClosingOk;
  final int? step3EntryId;
  final bool? step4TransferOk;
  final int? step4EntryId;
  final bool? step5CarryForwardOk;
  final int? step5EntryId;
  final int? nextFiscalYearId;
  final bool? step6LockOk;

  YearEndClosing({
    required this.id,
    required this.fiscalYearId,
    this.status = 'IN_PROGRESS',
    this.step1ChecklistOk,
    this.step1Result,
    this.step2AdjustingOk,
    this.step3ClosingOk,
    this.step3EntryId,
    this.step4TransferOk,
    this.step4EntryId,
    this.step5CarryForwardOk,
    this.step5EntryId,
    this.nextFiscalYearId,
    this.step6LockOk,
  });

  factory YearEndClosing.fromJson(Map<String, dynamic> json) {
    return YearEndClosing(
      id: json['id'],
      fiscalYearId: json['fiscal_year_id'],
      status: json['status'] ?? 'IN_PROGRESS',
      step1ChecklistOk: json['step1_checklist_ok'],
      step1Result: json['step1_result'] is Map
          ? Map<String, dynamic>.from(json['step1_result'])
          : null,
      step2AdjustingOk: json['step2_adjusting_ok'],
      step3ClosingOk: json['step3_closing_ok'],
      step3EntryId: json['step3_entry_id'],
      step4TransferOk: json['step4_transfer_ok'],
      step4EntryId: json['step4_entry_id'],
      step5CarryForwardOk: json['step5_carry_forward_ok'],
      step5EntryId: json['step5_entry_id'],
      nextFiscalYearId: json['next_fiscal_year_id'],
      step6LockOk: json['step6_lock_ok'],
    );
  }

  // Current active step index (0-based)
  int get currentStep {
    if (step1ChecklistOk != true) return 0;
    if (step2AdjustingOk != true) return 1;
    if (step3ClosingOk != true) return 2;
    if (step4TransferOk != true) return 3;
    if (step5CarryForwardOk != true) return 4;
    if (step6LockOk != true) return 5;
    return 5;
  }
}

class ClosingPreviewLine {
  final int accountId;
  final String accountCode;
  final String accountName;
  final String accountType;
  final double netBalance; // positive = Dr balance, negative = Cr balance
  // สาขาของยอด (ปิดบัญชีแยกตามสาขา) — ว่าง = ไม่ระบุสาขา
  final String branchCode;

  ClosingPreviewLine({
    required this.accountId,
    required this.accountCode,
    required this.accountName,
    required this.accountType,
    required this.netBalance,
    this.branchCode = '',
  });

  factory ClosingPreviewLine.fromJson(Map<String, dynamic> json) {
    return ClosingPreviewLine(
      accountId: json['account_id'],
      accountCode: json['account_code'] ?? '',
      accountName: json['account_name_thai'] ?? '',
      accountType: json['account_type'] ?? '',
      netBalance: double.tryParse(json['net_balance']?.toString() ?? '0') ?? 0,
      branchCode: json['branch_code']?.toString() ?? '',
    );
  }

  double get debit => netBalance > 0 ? netBalance : 0;
  double get credit => netBalance < 0 ? -netBalance : 0;
}

// ── สรุปของหน้าจอตั้งค่าปิดบัญชีสิ้นปี (GET /gl_closing_config/summary, user 2026-11-28) ──
double _ycD(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
int _ycI(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);

class ClosingHistoryRow {
  final String fyCode;
  final String status;
  final DateTime? updatedAt;
  final String? closingDocNo;
  final String? carryDocNo;
  final double netIncome;
  const ClosingHistoryRow({required this.fyCode, required this.status, this.updatedAt, this.closingDocNo, this.carryDocNo, required this.netIncome});
  factory ClosingHistoryRow.fromJson(Map<String, dynamic> j) => ClosingHistoryRow(
        fyCode: j['fy_code']?.toString() ?? '',
        status: j['status']?.toString() ?? '',
        updatedAt: j['updated_at'] == null ? null : DateTime.tryParse(j['updated_at'].toString())?.toLocal(),
        closingDocNo: j['closing_doc_no']?.toString(),
        carryDocNo: j['carry_doc_no']?.toString(),
        netIncome: _ycD(j['net_income']),
      );
}

class ClosingConfigSummary {
  final String? currentFyCode;
  final ClosingHistoryRow? lastClosed;
  final String? nextFyCode;
  final int nextTotalPeriods;
  final int nextClosedPeriods;
  final int nextDraftEntries;
  /// ขั้นตอนที่ทำแล้วของปีถัดไป: step1..step6 (ไม่มีแถวปิดบัญชี = ว่าง)
  final Map<int, bool> nextSteps;
  final double netIncomeYtd;
  final double retainedEarnings;
  final List<ClosingHistoryRow> history;
  const ClosingConfigSummary({this.currentFyCode, this.lastClosed, this.nextFyCode, required this.nextTotalPeriods, required this.nextClosedPeriods,
      required this.nextDraftEntries, required this.nextSteps, required this.netIncomeYtd, required this.retainedEarnings, required this.history});
  factory ClosingConfigSummary.fromJson(Map<String, dynamic> j) {
    final next = j['next_year'] as Map<String, dynamic>?;
    final st = next?['steps'] as Map<String, dynamic>?;
    const keys = ['step1_checklist_ok', 'step2_adjusting_ok', 'step3_closing_ok', 'step4_transfer_ok', 'step5_carry_forward_ok', 'step6_lock_ok'];
    return ClosingConfigSummary(
      currentFyCode: (j['current_fiscal_year'] as Map<String, dynamic>?)?['fy_code']?.toString(),
      lastClosed: j['last_closed'] == null ? null : ClosingHistoryRow.fromJson(j['last_closed'] as Map<String, dynamic>),
      nextFyCode: next?['fy_code']?.toString(),
      nextTotalPeriods: _ycI(next?['total_periods']),
      nextClosedPeriods: _ycI(next?['closed_periods']),
      nextDraftEntries: _ycI(next?['draft_entries']),
      nextSteps: st == null ? const {} : {for (var i = 0; i < keys.length; i++) i + 1: st[keys[i]] == true},
      netIncomeYtd: _ycD(j['net_income_ytd']),
      retainedEarnings: _ycD(j['retained_earnings']),
      history: [for (final x in (j['history'] as List? ?? const [])) ClosingHistoryRow.fromJson(x as Map<String, dynamic>)],
    );
  }
}
