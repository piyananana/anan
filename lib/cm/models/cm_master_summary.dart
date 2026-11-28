// lib/cm/models/cm_master_summary.dart — ข้อมูลสรุปของหน้าจอข้อมูลหลัก CM แบบ B (user 2026-11-28)
import '../../utils/date_utils.dart';

double _d(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
int _i(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);
int? _iN(dynamic v) => v == null ? null : _i(v);
DateTime? _dt(dynamic v) => v == null || v.toString().isEmpty ? null : parseLocalDateNullable(v.toString());

/// การ์ดแผงซ้ายของหน้าบัญชีธนาคาร
class CmBankBalance {
  final int id;
  final double balance;
  final int unreconciledCount;
  final int? checksLeft;
  final int activeBooks;
  const CmBankBalance({required this.id, required this.balance, required this.unreconciledCount, this.checksLeft, required this.activeBooks});
  factory CmBankBalance.fromJson(Map<String, dynamic> j) => CmBankBalance(
        id: _i(j['id']),
        balance: _d(j['balance']),
        unreconciledCount: _i(j['unreconciled_count']),
        checksLeft: _iN(j['checks_left']),
        activeBooks: _i(j['active_books']),
      );
}

/// บัญชี GL ที่ใช้ตามประเภทการชำระเงิน (source: method / bank / none)
class CmMethodGl {
  final String methodCode;
  final String methodNameTh;
  final String? methodNameEn;
  final String methodType;
  final String source;
  final String? glCode;
  final String? glNameTh;
  final String? glNameEn;
  const CmMethodGl(
      {required this.methodCode, required this.methodNameTh, this.methodNameEn, required this.methodType, required this.source, this.glCode, this.glNameTh, this.glNameEn});
  factory CmMethodGl.fromJson(Map<String, dynamic> j) => CmMethodGl(
        methodCode: j['method_code'] ?? '',
        methodNameTh: j['method_name_th'] ?? '',
        methodNameEn: j['method_name_en'],
        methodType: j['method_type'] ?? '',
        source: j['source'] ?? 'none',
        glCode: j['gl_account_code'],
        glNameTh: j['gl_account_name_th'],
        glNameEn: j['gl_account_name_en'],
      );
  String name(bool e) => e && (methodNameEn ?? '').isNotEmpty ? methodNameEn! : methodNameTh;
  String glText(bool e) => glCode == null ? '' : '$glCode ${e && (glNameEn ?? '').isNotEmpty ? glNameEn : (glNameTh ?? '')}'.trim();
}

/// รายการเข้า-ออกของบัญชี (cm_receipt / cm_payment)
class CmBankItem {
  final bool isIn;
  final DateTime? date;
  final String? docNo;
  final String? party;
  final String? methodType;
  final String? checkNo;
  final double amount;
  final String status;
  final bool reconciled;
  const CmBankItem(
      {required this.isIn, this.date, this.docNo, this.party, this.methodType, this.checkNo, required this.amount, required this.status, required this.reconciled});
  factory CmBankItem.fromJson(Map<String, dynamic> j) => CmBankItem(
        isIn: j['dir'] == 'IN',
        date: _dt(j['date']),
        docNo: j['doc_no'],
        party: j['party'],
        methodType: j['payment_method_type'],
        checkNo: j['check_no'],
        amount: _d(j['amount_lc']),
        status: j['status'] ?? '',
        reconciled: j['is_reconciled'] == true,
      );
}

/// สมุดเช็ค (ย่อ) พร้อมจำนวนคงเหลือ
class CmBookInfo {
  final int id;
  final String code;
  final String startNo;
  final String endNo;
  final String? nextNo;
  final String status;
  final DateTime? receivedDate;
  final int? remaining;
  final int? size;
  final int issuedCount;
  final String? note;
  const CmBookInfo(
      {required this.id, required this.code, required this.startNo, required this.endNo, this.nextNo, required this.status, this.receivedDate, this.remaining, this.size,
      this.issuedCount = 0, this.note});
  factory CmBookInfo.fromJson(Map<String, dynamic> j) => CmBookInfo(
        id: _i(j['id']),
        code: j['checkbook_code'] ?? '',
        startNo: j['start_check_no'] ?? '',
        endNo: j['end_check_no'] ?? '',
        nextNo: j['next_check_no'],
        status: j['status'] ?? 'Active',
        receivedDate: _dt(j['received_date']),
        remaining: _iN(j['remaining']),
        size: _iN(j['size']),
        issuedCount: _i(j['issued_count']),
        note: j['note'],
      );
  int? get used => size == null || remaining == null ? null : (status == 'Active' ? size! - remaining! : size);
}

class CmBankSummary {
  final double balance;
  final int unrecInCount;
  final double unrecInAmount;
  final int unrecOutCount;
  final double unrecOutAmount;
  final DateTime? lastReconcileDate;
  final DateTime? lastStatementFrom;
  final DateTime? lastStatementTo;
  final double? lastStatementClosing;
  final String? lastStatementStatus;
  final List<CmMethodGl> methods;
  final List<CmBankItem> recent;
  final List<CmBookInfo> checkbooks;
  final int checksLeft;
  final int activeBooks;
  final String? nextCheckNo;
  final String? nextCheckbookCode;
  const CmBankSummary({
    required this.balance,
    required this.unrecInCount,
    required this.unrecInAmount,
    required this.unrecOutCount,
    required this.unrecOutAmount,
    this.lastReconcileDate,
    this.lastStatementFrom,
    this.lastStatementTo,
    this.lastStatementClosing,
    this.lastStatementStatus,
    required this.methods,
    required this.recent,
    required this.checkbooks,
    required this.checksLeft,
    required this.activeBooks,
    this.nextCheckNo,
    this.nextCheckbookCode,
  });
  factory CmBankSummary.fromJson(Map<String, dynamic> j) {
    final u = (j['unreconciled'] as Map?) ?? const {};
    final st = j['last_statement'] as Map?;
    return CmBankSummary(
      balance: _d(j['balance']),
      unrecInCount: _i(u['in_count']),
      unrecInAmount: _d(u['in_amount']),
      unrecOutCount: _i(u['out_count']),
      unrecOutAmount: _d(u['out_amount']),
      lastReconcileDate: _dt(j['last_reconcile_date']),
      lastStatementFrom: _dt(st?['date_from']),
      lastStatementTo: _dt(st?['date_to']),
      lastStatementClosing: st == null ? null : _d(st['closing_balance']),
      lastStatementStatus: st?['status'],
      methods: [for (final m in (j['methods'] as List? ?? const [])) CmMethodGl.fromJson(Map<String, dynamic>.from(m))],
      recent: [for (final r in (j['recent'] as List? ?? const [])) CmBankItem.fromJson(Map<String, dynamic>.from(r))],
      checkbooks: [for (final c in (j['checkbooks'] as List? ?? const [])) CmBookInfo.fromJson(Map<String, dynamic>.from(c))],
      checksLeft: _i(j['checks_left']),
      activeBooks: _i(j['active_books']),
      nextCheckNo: j['next_check_no'],
      nextCheckbookCode: j['next_checkbook_code'],
    );
  }
  int get unrecCount => unrecInCount + unrecOutCount;
}

// ─── ประเภทการชำระเงิน ─────────────────────────────────────────────────────────
String _gl(String? code, String? th, String? en, bool e) =>
    code == null ? '' : '$code ${e && (en ?? '').isNotEmpty ? en : (th ?? '')}'.trim();

class CmMethodVendor {
  final String code;
  final String nameTh;
  final String? nameEn;
  final bool isActive;
  final String? groupCode;
  final String? bankName;
  final String? accountNumber;
  const CmMethodVendor({required this.code, required this.nameTh, this.nameEn, required this.isActive, this.groupCode, this.bankName, this.accountNumber});
  factory CmMethodVendor.fromJson(Map<String, dynamic> j) => CmMethodVendor(
        code: j['vendor_code'] ?? '',
        nameTh: j['vendor_name_th'] ?? '',
        nameEn: j['vendor_name_en'],
        isActive: j['is_active'] != false,
        groupCode: j['group_code'],
        bankName: j['bank_name'],
        accountNumber: j['account_number'],
      );
  String name(bool e) => e && (nameEn ?? '').isNotEmpty ? nameEn! : nameTh;
}

class CmMethodBankGl {
  final String code;
  final String nameTh;
  final String? nameEn;
  final String? glCode;
  final String? glNameTh;
  final String? glNameEn;
  const CmMethodBankGl({required this.code, required this.nameTh, this.nameEn, this.glCode, this.glNameTh, this.glNameEn});
  factory CmMethodBankGl.fromJson(Map<String, dynamic> j) => CmMethodBankGl(
        code: j['account_code'] ?? '',
        nameTh: j['account_name_th'] ?? '',
        nameEn: j['account_name_en'],
        glCode: j['gl_account_code'],
        glNameTh: j['gl_account_name_th'],
        glNameEn: j['gl_account_name_en'],
      );
  String name(bool e) => e && (nameEn ?? '').isNotEmpty ? nameEn! : nameTh;
  String glText(bool e) => _gl(glCode, glNameTh, glNameEn, e);
}

class CmMethodSummary {
  final int monthInCount;
  final double monthInAmount;
  final int monthOutCount;
  final double monthOutAmount;
  final int vendorCount;
  final int vendorTotal;
  final List<CmMethodVendor> vendors;
  final String glSource; // method / bank
  final String? glCode;
  final String? glNameTh;
  final String? glNameEn;
  final List<CmMethodBankGl> bankAccounts;
  final int bankAccountCount;
  const CmMethodSummary({
    required this.monthInCount,
    required this.monthInAmount,
    required this.monthOutCount,
    required this.monthOutAmount,
    required this.vendorCount,
    required this.vendorTotal,
    required this.vendors,
    required this.glSource,
    this.glCode,
    this.glNameTh,
    this.glNameEn,
    required this.bankAccounts,
    required this.bankAccountCount,
  });
  factory CmMethodSummary.fromJson(Map<String, dynamic> j) {
    final mi = (j['month_in'] as Map?) ?? const {};
    final mo = (j['month_out'] as Map?) ?? const {};
    return CmMethodSummary(
      monthInCount: _i(mi['count']),
      monthInAmount: _d(mi['amount']),
      monthOutCount: _i(mo['count']),
      monthOutAmount: _d(mo['amount']),
      vendorCount: _i(j['vendor_count']),
      vendorTotal: _i(j['vendor_total']),
      vendors: [for (final v in (j['vendors'] as List? ?? const [])) CmMethodVendor.fromJson(Map<String, dynamic>.from(v))],
      glSource: j['gl_source'] ?? 'bank',
      glCode: j['gl_account_code'],
      glNameTh: j['gl_account_name_th'],
      glNameEn: j['gl_account_name_en'],
      bankAccounts: [for (final b in (j['bank_accounts'] as List? ?? const [])) CmMethodBankGl.fromJson(Map<String, dynamic>.from(b))],
      bankAccountCount: _i(j['bank_account_count']),
    );
  }
  String glText(bool e) => _gl(glCode, glNameTh, glNameEn, e);
}

// ─── สมุดเช็ค ──────────────────────────────────────────────────────────────────
class CmCheckbookAccountSummary {
  final List<CmBookInfo> books;
  final int checksLeft;
  final int activeBooks;
  final String? nextCheckNo;
  final String? nextCheckbookCode;
  final int monthCount;
  final double monthAmount;
  final int pendingCount;
  final double pendingAmount;
  const CmCheckbookAccountSummary({
    required this.books,
    required this.checksLeft,
    required this.activeBooks,
    this.nextCheckNo,
    this.nextCheckbookCode,
    required this.monthCount,
    required this.monthAmount,
    required this.pendingCount,
    required this.pendingAmount,
  });
  factory CmCheckbookAccountSummary.fromJson(Map<String, dynamic> j) => CmCheckbookAccountSummary(
        books: [for (final b in (j['books'] as List? ?? const [])) CmBookInfo.fromJson(Map<String, dynamic>.from(b))],
        checksLeft: _i(j['checks_left']),
        activeBooks: _i(j['active_books']),
        nextCheckNo: j['next_check_no'],
        nextCheckbookCode: j['next_checkbook_code'],
        monthCount: _i(j['month_count']),
        monthAmount: _d(j['month_amount']),
        pendingCount: _i(j['pending_count']),
        pendingAmount: _d(j['pending_amount']),
      );
}

/// เช็คที่ออกจากเล่ม (cm_payment)
class CmBookCheck {
  final String? checkNo;
  final DateTime? checkDate;
  final DateTime? paymentDate;
  final String? payee;
  final String? docNo;
  final double amount;
  final String status; // Pending / Cleared / Voided
  final DateTime? clearingDate;
  const CmBookCheck({this.checkNo, this.checkDate, this.paymentDate, this.payee, this.docNo, required this.amount, required this.status, this.clearingDate});
  factory CmBookCheck.fromJson(Map<String, dynamic> j) => CmBookCheck(
        checkNo: j['check_no'],
        checkDate: _dt(j['check_date']),
        paymentDate: _dt(j['payment_date']),
        payee: j['payee_name_th'],
        docNo: j['ap_doc_no'],
        amount: _d(j['amount_lc']),
        status: j['status'] ?? '',
        clearingDate: _dt(j['clearing_date']),
      );
}
