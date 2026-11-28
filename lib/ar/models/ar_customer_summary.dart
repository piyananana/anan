// lib/ar/models/ar_customer_summary.dart — ยอดค้าง/อายุหนี้/ที่มาบัญชีลูกหนี้ของหน้าจอลูกค้าแบบใหม่ (2026-11-28)
double _d(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
int _i(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);

/// ยอดค้างต่อลูกค้า (การ์ดรายการ)
class ArCustomerBalance {
  final int customerId;
  final double outstanding;
  final double overdue;
  final int overdueCount;
  final int openCount;
  const ArCustomerBalance({required this.customerId, this.outstanding = 0, this.overdue = 0, this.overdueCount = 0, this.openCount = 0});

  factory ArCustomerBalance.fromJson(Map<String, dynamic> j) => ArCustomerBalance(
        customerId: _i(j['customer_id']),
        outstanding: _d(j['outstanding']),
        overdue: _d(j['overdue']),
        overdueCount: _i(j['overdue_count']),
        openCount: _i(j['open_count']),
      );
}

class ArSummaryAccount {
  final int? id;
  final String code;
  final String nameThai;
  final String nameEng;
  const ArSummaryAccount({this.id, required this.code, required this.nameThai, required this.nameEng});

  String name(bool isEnglish) => isEnglish && nameEng.isNotEmpty ? nameEng : nameThai;

  static ArSummaryAccount? fromJson(dynamic j) {
    if (j is! Map) return null;
    return ArSummaryAccount(
      id: j['id'] == null ? null : _i(j['id']),
      code: (j['code'] ?? j['account_code'] ?? '').toString(),
      nameThai: (j['name_thai'] ?? j['account_name_thai'] ?? '').toString(),
      nameEng: (j['name_eng'] ?? j['account_name_eng'] ?? '').toString(),
    );
  }
}

class ArDocTypeAccount {
  final String docCode;
  final String sysDocType;
  final ArSummaryAccount? account;
  const ArDocTypeAccount(this.docCode, this.sysDocType, this.account);
}

class ArOpenDoc {
  final int id;
  final String docNo;
  final String docCode;
  final DateTime? docDate;
  final DateTime? dueDate;
  final double balance;
  final int daysOverdue;
  const ArOpenDoc(this.id, this.docNo, this.docCode, this.docDate, this.dueDate, this.balance, this.daysOverdue);
}

DateTime? _date(dynamic v) {
  final s = v?.toString() ?? '';
  if (s.length < 10) return null;
  final p = s.substring(0, 10).split('-');
  if (p.length != 3) return null;
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

class ArLastDoc {
  final String docNo;
  final DateTime? docDate;
  const ArLastDoc(this.docNo, this.docDate);
  static ArLastDoc? fromJson(dynamic j) => j is Map ? ArLastDoc((j['doc_no'] ?? '').toString(), _date(j['doc_date'])) : null;
}

class ArCustomerSummary {
  final double outstanding;
  final double unbilledDelivery;
  final double creditUsed;
  final double creditLimit;
  final int openCount;
  final double overdue;
  final int overdueCount;
  final int maxDaysOverdue;
  final double openCredits;
  final int openCreditCount;
  final double notDue, d1_30, d31_60, d61_90, over90, agingTotal;
  final List<ArOpenDoc> oldestDocs;
  final ArLastDoc? lastSale;
  final ArLastDoc? lastReceipt;
  final ArSummaryAccount? customerAccount;
  final String? groupCode;
  final ArSummaryAccount? groupAccount;
  final List<ArDocTypeAccount> docTypeAccounts;

  const ArCustomerSummary({
    required this.outstanding, required this.unbilledDelivery, required this.creditUsed, required this.creditLimit,
    required this.openCount, required this.overdue, required this.overdueCount, required this.maxDaysOverdue,
    required this.openCredits, required this.openCreditCount,
    required this.notDue, required this.d1_30, required this.d31_60, required this.d61_90, required this.over90, required this.agingTotal,
    required this.oldestDocs, this.lastSale, this.lastReceipt, this.customerAccount, this.groupCode, this.groupAccount,
    required this.docTypeAccounts,
  });

  factory ArCustomerSummary.fromJson(Map<String, dynamic> j) {
    final ag = (j['aging'] as Map?) ?? const {};
    final acc = (j['ar_account'] as Map?) ?? const {};
    return ArCustomerSummary(
      outstanding: _d(j['outstanding']),
      unbilledDelivery: _d(j['unbilled_delivery']),
      creditUsed: _d(j['credit_used']),
      creditLimit: _d(j['credit_limit']),
      openCount: _i(j['open_count']),
      overdue: _d(j['overdue']),
      overdueCount: _i(j['overdue_count']),
      maxDaysOverdue: _i(j['max_days_overdue']),
      openCredits: _d(j['open_credits']),
      openCreditCount: _i(j['open_credit_count']),
      notDue: _d(ag['not_due']),
      d1_30: _d(ag['d1_30']),
      d31_60: _d(ag['d31_60']),
      d61_90: _d(ag['d61_90']),
      over90: _d(ag['over_90']),
      agingTotal: _d(ag['total']),
      oldestDocs: [
        for (final o in (j['oldest_docs'] as List? ?? const []))
          ArOpenDoc(_i(o['id']), (o['doc_no'] ?? '').toString(), (o['doc_code'] ?? '').toString(), _date(o['doc_date']),
              _date(o['due_date']), _d(o['balance']), _i(o['days_overdue'])),
      ],
      lastSale: ArLastDoc.fromJson(j['last_sale']),
      lastReceipt: ArLastDoc.fromJson(j['last_receipt']),
      customerAccount: ArSummaryAccount.fromJson(acc['customer']),
      groupCode: acc['group_code']?.toString(),
      groupAccount: ArSummaryAccount.fromJson(acc['group']),
      docTypeAccounts: [
        for (final d in (acc['doc_types'] as List? ?? const []))
          ArDocTypeAccount((d['doc_code'] ?? '').toString(), (d['sys_doc_type'] ?? '').toString(),
              d['account_code'] == null ? null : ArSummaryAccount.fromJson(d)),
      ],
    );
  }
}

/// ลูกค้าในกลุ่ม 1 ราย (หน้าจอกลุ่มลูกค้า)
class ArGroupCustomer {
  final int id;
  final String code;
  final String nameTh;
  final String nameEn;
  final bool isActive;
  final int creditTermMonths;
  final int creditTermDays;
  final double creditLimit;
  final double discountPercent;
  final bool ownAccount;
  final bool autoCode;
  final double outstanding;
  final double overdue;
  final bool sameTerm;
  final bool sameLimit;
  final bool sameDiscount;
  const ArGroupCustomer({
    required this.id, required this.code, required this.nameTh, required this.nameEn, required this.isActive,
    required this.creditTermMonths, required this.creditTermDays, required this.creditLimit, required this.discountPercent,
    required this.ownAccount, required this.autoCode, required this.outstanding, required this.overdue,
    required this.sameTerm, required this.sameLimit, required this.sameDiscount,
  });
  String name(bool isEnglish) => isEnglish && nameEn.isNotEmpty ? nameEn : nameTh;
  bool get usesGroup => sameTerm && sameLimit && sameDiscount;
}

class ArCustomerGroupSummary {
  final int customerCount;
  final int activeCount;
  final double outstanding;
  final double overdue;
  final int overdueCustomers;
  final int ownTermsCount;
  final int ownAccountCount;
  final List<ArGroupCustomer> customers;
  const ArCustomerGroupSummary({
    required this.customerCount, required this.activeCount, required this.outstanding, required this.overdue,
    required this.overdueCustomers, required this.ownTermsCount, required this.ownAccountCount, required this.customers,
  });

  factory ArCustomerGroupSummary.fromJson(Map<String, dynamic> j) => ArCustomerGroupSummary(
        customerCount: _i(j['customer_count']),
        activeCount: _i(j['active_count']),
        outstanding: _d(j['outstanding']),
        overdue: _d(j['overdue']),
        overdueCustomers: _i(j['overdue_customers']),
        ownTermsCount: _i(j['own_terms_count']),
        ownAccountCount: _i(j['own_account_count']),
        customers: [
          for (final c in (j['customers'] as List? ?? const []))
            ArGroupCustomer(
              id: _i(c['id']),
              code: (c['customer_code'] ?? '').toString(),
              nameTh: (c['customer_name_th'] ?? '').toString(),
              nameEn: (c['customer_name_en'] ?? '').toString(),
              isActive: c['is_active'] == true,
              creditTermMonths: _i(c['credit_term_months']),
              creditTermDays: _i(c['credit_term_days']),
              creditLimit: _d(c['credit_limit']),
              discountPercent: _d(c['discount_percent']),
              ownAccount: c['ar_account_id'] != null,
              autoCode: c['is_code_auto_generated'] == true,
              outstanding: _d(c['outstanding']),
              overdue: _d(c['overdue']),
              sameTerm: c['same_term'] == true,
              sameLimit: c['same_limit'] == true,
              sameDiscount: c['same_discount'] == true,
            ),
        ],
      );
}

/// ตัวอย่างรหัสลูกค้าอัตโนมัติจาก server (ข้ามรหัสที่มีลูกค้าใช้แล้ว)
class ArCodePreview {
  final List<String> nextCodes;
  final String? lastCode;
  const ArCodePreview(this.nextCodes, this.lastCode);
  factory ArCodePreview.fromJson(Map<String, dynamic> j) => ArCodePreview(
        [for (final c in (j['next_codes'] as List? ?? [j['customer_code']])) if (c != null) c.toString()],
        j['last_code']?.toString(),
      );
}

/// ลูกค้าที่ผู้วางบิล/ผู้เก็บเงินรับผิดชอบ
class ArCollectorCustomer {
  final int id;
  final String code;
  final String nameTh;
  final String nameEn;
  final bool isActive;
  final bool isBiller;
  final bool isCollector;
  final double outstanding;
  final double overdue;
  final int openCount;
  const ArCollectorCustomer(this.id, this.code, this.nameTh, this.nameEn, this.isActive, this.isBiller, this.isCollector,
      this.outstanding, this.overdue, this.openCount);
  String name(bool isEnglish) => isEnglish && nameEn.isNotEmpty ? nameEn : nameTh;
}

class ArCollectorSummary {
  final int billingCount;
  final int collectionCount;
  final double outstanding;
  final double overdue;
  final int overdueCustomers;
  final int openDocs;
  final List<ArCollectorCustomer> customers;
  const ArCollectorSummary(this.billingCount, this.collectionCount, this.outstanding, this.overdue, this.overdueCustomers, this.openDocs,
      this.customers);

  factory ArCollectorSummary.fromJson(Map<String, dynamic> j) => ArCollectorSummary(
        _i(j['billing_count']),
        _i(j['collection_count']),
        _d(j['outstanding']),
        _d(j['overdue']),
        _i(j['overdue_customers']),
        _i(j['open_docs']),
        [
          for (final c in (j['customers'] as List? ?? const []))
            ArCollectorCustomer(_i(c['id']), (c['customer_code'] ?? '').toString(), (c['customer_name_th'] ?? '').toString(),
                (c['customer_name_en'] ?? '').toString(), c['is_active'] == true, c['is_biller'] == true, c['is_collector'] == true,
                _d(c['outstanding']), _d(c['overdue']), _i(c['open_count'])),
        ],
      );
}
