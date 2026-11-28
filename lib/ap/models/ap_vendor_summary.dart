// lib/ap/models/ap_vendor_summary.dart — ตัวเลขสรุปของหน้าจอข้อมูลหลัก AP แบบใหม่ (2026-11-28)
// ผู้ขาย (ยอดค้างจ่าย/อายุหนี้/ที่มาบัญชีเจ้าหนี้), กลุ่มผู้ขาย, รหัส/เลขที่อัตโนมัติ, ตั้งค่าสิ้นปี AP
double _d(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
int _i(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);
String _s(dynamic v) => v?.toString() ?? '';

DateTime? _date(dynamic v) {
  final s = v?.toString() ?? '';
  if (s.length < 10) return null;
  final p = s.substring(0, 10).split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// ยอดค้างจ่ายต่อผู้ขาย (การ์ดรายการ)
class ApVendorBalance {
  final int vendorId;
  final double outstanding;
  final double overdue;
  final int overdueCount;
  final int openCount;
  final double deposit;
  final int bankAccountCount;
  const ApVendorBalance({
    required this.vendorId, this.outstanding = 0, this.overdue = 0, this.overdueCount = 0,
    this.openCount = 0, this.deposit = 0, this.bankAccountCount = 0,
  });

  factory ApVendorBalance.fromJson(Map<String, dynamic> j) => ApVendorBalance(
        vendorId: _i(j['vendor_id']),
        outstanding: _d(j['outstanding']),
        overdue: _d(j['overdue']),
        overdueCount: _i(j['overdue_count']),
        openCount: _i(j['open_count']),
        deposit: _d(j['deposit']),
        bankAccountCount: _i(j['bank_account_count']),
      );
}

class ApSummaryAccount {
  final int? id;
  final String code;
  final String nameThai;
  final String nameEng;
  const ApSummaryAccount({this.id, required this.code, required this.nameThai, required this.nameEng});

  String name(bool isEnglish) => isEnglish && nameEng.isNotEmpty ? nameEng : nameThai;

  static ApSummaryAccount? fromJson(dynamic j) {
    if (j is! Map) return null;
    return ApSummaryAccount(
      id: j['id'] == null ? null : _i(j['id']),
      code: _s(j['code'] ?? j['account_code']),
      nameThai: _s(j['name_thai'] ?? j['account_name_thai']),
      nameEng: _s(j['name_eng'] ?? j['account_name_eng']),
    );
  }
}

class ApDocTypeAccount {
  final String docCode;
  final String sysDocType;
  final ApSummaryAccount? account;
  const ApDocTypeAccount(this.docCode, this.sysDocType, this.account);
}

class ApOpenDoc {
  final int id;
  final String docNo;
  final String docCode;
  final DateTime? docDate;
  final DateTime? dueDate;
  final double balance;
  final int daysOverdue;
  const ApOpenDoc(this.id, this.docNo, this.docCode, this.docDate, this.dueDate, this.balance, this.daysOverdue);
}

class ApLastDoc {
  final String docNo;
  final DateTime? docDate;
  const ApLastDoc(this.docNo, this.docDate);
  static ApLastDoc? fromJson(dynamic j) => j is Map ? ApLastDoc(_s(j['doc_no']), _date(j['doc_date'])) : null;
}

class ApVendorSummary {
  final double outstanding;
  final double creditLimit;
  final int openCount;
  final double overdue;
  final int overdueCount;
  final int maxDaysOverdue;
  final double deposit;
  final int depositCount;
  final double notDue, d1_30, d31_60, d61_90, over90, agingTotal;
  final List<ApOpenDoc> oldestDocs;
  final ApLastDoc? lastBill;
  final ApLastDoc? lastPayment;
  final ApSummaryAccount? vendorAccount;
  final String? groupCode;
  final ApSummaryAccount? groupAccount;
  final List<ApDocTypeAccount> docTypeAccounts;

  const ApVendorSummary({
    required this.outstanding, required this.creditLimit, required this.openCount, required this.overdue,
    required this.overdueCount, required this.maxDaysOverdue, required this.deposit, required this.depositCount,
    required this.notDue, required this.d1_30, required this.d31_60, required this.d61_90, required this.over90, required this.agingTotal,
    required this.oldestDocs, this.lastBill, this.lastPayment, this.vendorAccount, this.groupCode, this.groupAccount,
    required this.docTypeAccounts,
  });

  factory ApVendorSummary.fromJson(Map<String, dynamic> j) {
    final ag = (j['aging'] as Map?) ?? const {};
    final acc = (j['ap_account'] as Map?) ?? const {};
    return ApVendorSummary(
      outstanding: _d(j['outstanding']),
      creditLimit: _d(j['credit_limit']),
      openCount: _i(j['open_count']),
      overdue: _d(j['overdue']),
      overdueCount: _i(j['overdue_count']),
      maxDaysOverdue: _i(j['max_days_overdue']),
      deposit: _d(j['deposit']),
      depositCount: _i(j['deposit_count']),
      notDue: _d(ag['not_due']),
      d1_30: _d(ag['d1_30']),
      d31_60: _d(ag['d31_60']),
      d61_90: _d(ag['d61_90']),
      over90: _d(ag['over_90']),
      agingTotal: _d(ag['total']),
      oldestDocs: [
        for (final o in (j['oldest_docs'] as List? ?? const []))
          ApOpenDoc(_i(o['id']), _s(o['doc_no']), _s(o['doc_code']), _date(o['doc_date']), _date(o['due_date']),
              _d(o['balance']), _i(o['days_overdue'])),
      ],
      lastBill: ApLastDoc.fromJson(j['last_bill']),
      lastPayment: ApLastDoc.fromJson(j['last_payment']),
      vendorAccount: ApSummaryAccount.fromJson(acc['vendor']),
      groupCode: acc['group_code']?.toString(),
      groupAccount: ApSummaryAccount.fromJson(acc['group']),
      docTypeAccounts: [
        for (final d in (acc['doc_types'] as List? ?? const []))
          ApDocTypeAccount(_s(d['doc_code']), _s(d['sys_doc_type']), d['account_code'] == null ? null : ApSummaryAccount.fromJson(d)),
      ],
    );
  }
}

/// ผู้ขายในกลุ่ม (หน้ากลุ่มผู้ขาย)
class ApGroupVendor {
  final int id;
  final String vendorCode;
  final String nameTh;
  final String nameEn;
  final bool isActive;
  final int creditTermMonths;
  final int creditTermDays;
  final String currencyCode;
  final bool ownAccount;
  final double outstanding;
  final double overdue;
  final bool sameTerm;
  final bool sameCurrency;
  const ApGroupVendor({
    required this.id, required this.vendorCode, required this.nameTh, required this.nameEn, required this.isActive,
    required this.creditTermMonths, required this.creditTermDays, required this.currencyCode, required this.ownAccount,
    required this.outstanding, required this.overdue, required this.sameTerm, required this.sameCurrency,
  });

  String name(bool isEnglish) => isEnglish && nameEn.isNotEmpty ? nameEn : nameTh;
  bool get usesGroup => sameTerm && sameCurrency;

  factory ApGroupVendor.fromJson(Map<String, dynamic> j) => ApGroupVendor(
        id: _i(j['id']),
        vendorCode: _s(j['vendor_code']),
        nameTh: _s(j['vendor_name_th']),
        nameEn: _s(j['vendor_name_en']),
        isActive: j['is_active'] != false,
        creditTermMonths: _i(j['credit_term_months']),
        creditTermDays: _i(j['credit_term_days']),
        currencyCode: _s(j['currency_code']),
        ownAccount: j['ap_account_id'] != null,
        outstanding: _d(j['outstanding']),
        overdue: _d(j['overdue']),
        sameTerm: j['same_term'] == true,
        sameCurrency: j['same_currency'] == true,
      );
}

class ApVendorGroupSummary {
  final int vendorCount;
  final int activeCount;
  final double outstanding;
  final double overdue;
  final int overdueVendors;
  final int ownTermsCount;
  final int ownAccountCount;
  final List<ApGroupVendor> vendors;
  const ApVendorGroupSummary({
    required this.vendorCount, required this.activeCount, required this.outstanding, required this.overdue,
    required this.overdueVendors, required this.ownTermsCount, required this.ownAccountCount, required this.vendors,
  });

  factory ApVendorGroupSummary.fromJson(Map<String, dynamic> j) => ApVendorGroupSummary(
        vendorCount: _i(j['vendor_count']),
        activeCount: _i(j['active_count']),
        outstanding: _d(j['outstanding']),
        overdue: _d(j['overdue']),
        overdueVendors: _i(j['overdue_vendors']),
        ownTermsCount: _i(j['own_terms_count']),
        ownAccountCount: _i(j['own_account_count']),
        vendors: [for (final v in (j['vendors'] as List? ?? const [])) ApGroupVendor.fromJson(Map<String, dynamic>.from(v as Map))],
      );
}

/// ตัวอย่างรหัสถัดไปของกลุ่มที่ออกรหัสเอง
class ApCodePreview {
  final List<String> nextCodes;
  final String? lastCode;
  const ApCodePreview(this.nextCodes, this.lastCode);
  factory ApCodePreview.fromJson(Map<String, dynamic> j) =>
      ApCodePreview([for (final c in (j['next_codes'] as List? ?? const [])) c.toString()], j['last_code']?.toString());
}

/// ใบสั่งจ่ายล่าสุด (หน้าเลขที่ใบสั่งจ่ายอัตโนมัติ)
class ApRecentRun {
  final String runNumber;
  final DateTime? runDate;
  final DateTime? paymentDate;
  final String status;
  final double total;
  final int vendorCount;
  const ApRecentRun(this.runNumber, this.runDate, this.paymentDate, this.status, this.total, this.vendorCount);
  factory ApRecentRun.fromJson(Map<String, dynamic> j) => ApRecentRun(
      _s(j['run_number']), _date(j['run_date']), _date(j['payment_date']), _s(j['status']), _d(j['total_amount_lc']), _i(j['vendor_count']));
}

class ApPaymentRunRunningSummary {
  final List<String> nextCodes;
  final String? collisionCode;
  final int? nextFree;
  final ApRecentRun? lastIssued;
  final List<ApRecentRun> recent;
  final int monthCount;
  final double monthAmount;
  final int draftCount;
  final int submittedCount;
  final int approvedCount;
  const ApPaymentRunRunningSummary({
    required this.nextCodes, this.collisionCode, this.nextFree, this.lastIssued, required this.recent,
    required this.monthCount, required this.monthAmount, required this.draftCount, required this.submittedCount, required this.approvedCount,
  });

  factory ApPaymentRunRunningSummary.fromJson(Map<String, dynamic> j) {
    final c = j['collision'] as Map?;
    return ApPaymentRunRunningSummary(
      nextCodes: [for (final x in (j['next_codes'] as List? ?? const [])) x.toString()],
      collisionCode: c?['code']?.toString(),
      nextFree: c == null ? null : _i(c['next_free']),
      lastIssued: j['last_issued'] is Map ? ApRecentRun.fromJson(Map<String, dynamic>.from(j['last_issued'] as Map)) : null,
      recent: [for (final r in (j['recent'] as List? ?? const [])) ApRecentRun.fromJson(Map<String, dynamic>.from(r as Map))],
      monthCount: _i(j['month_count']),
      monthAmount: _d(j['month_amount']),
      draftCount: _i(j['draft_count']),
      submittedCount: _i(j['submitted_count']),
      approvedCount: _i(j['approved_count']),
    );
  }
}

/// เจ้าหนี้สกุลต่างประเทศที่ค้าง (หน้าตั้งค่าสิ้นปี AP)
class ApFxOpenCurrency {
  final String currencyCode;
  final int docCount;
  final int vendorCount;
  final double balanceFc;
  final double balanceLc;
  const ApFxOpenCurrency(this.currencyCode, this.docCount, this.vendorCount, this.balanceFc, this.balanceLc);
}

class ApYearEndSummary {
  final List<ApFxOpenCurrency> currencies;
  final int docCount;
  final double balanceLc;
  const ApYearEndSummary(this.currencies, this.docCount, this.balanceLc);

  factory ApYearEndSummary.fromJson(Map<String, dynamic> j) => ApYearEndSummary(
        [
          for (final c in (j['fx_currencies'] as List? ?? const []))
            ApFxOpenCurrency(_s(c['currency_code']), _i(c['doc_count']), _i(c['vendor_count']), _d(c['balance_fc']), _d(c['balance_lc'])),
        ],
        _i(j['fx_doc_count']),
        _d(j['fx_balance_lc']),
      );
}
