import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../models/cm_transaction.dart';
import '../models/cm_transaction_gl_setup.dart';
import '../services/cm_transaction_service.dart';
import '../services/cm_transaction_gl_setup_service.dart';
import '../models/cm_bank_account.dart';
import '../services/cm_bank_account_service.dart';
import '../models/cm_payment_method.dart';
import '../services/cm_payment_method_service.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../services/cm_period_service.dart';
import '../../gl/services/gl_entry_service.dart';
import '../../gl/models/gl_entry.dart' show GlEntryDetail;
import '../../gl/models/gl_dimension.dart';
import '../../gl/services/gl_dimension_service.dart';
import '../../gl/widgets/gl_dimension_picker_field.dart';
import '../../gl/widgets/gl_line_account_dims.dart';
import '../../cd/models/cd_currency.dart';
import '../../cd/services/cd_currency_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/models/sa_document_reverse_log.dart';
import '../../sa/widgets/sa_document_reverse_widgets.dart';
import '../../sa/models/sa_doc_approval.dart';
import '../../sa/widgets/sa_doc_approval_panel.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../ap/models/ap_vendor.dart';
import '../../ap/services/ap_vendor_service.dart';
import '../../ar/models/ar_customer.dart';
import '../../ar/services/ar_customer_service.dart';
import '../../cd/models/cd_vat_rate.dart';
import '../../cd/services/cd_vat_rate_service.dart';
import '../../cd/models/cd_wht_type.dart';
import '../../cd/services/cd_wht_type_service.dart';
import '../../utils/vat_calc.dart';
import '../models/cm_checkbook.dart';
import '../../cd/models/cd_branch.dart';
import '../../cd/services/cd_branch_service.dart';
import '../../cd/widgets/cd_user_branch_picker.dart';
import '../services/cm_checkbook_service.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../../sa/widgets/sa_doc_list_kit.dart';
import '../../ar/widgets/ar_transaction_detail_widget.dart';
import '../../ap/widgets/ap_transaction_detail_widget.dart';

class CmTransactionDetailWidget extends StatefulWidget {
  final int? transactionId;
  final int? initialSysDocType; // จำเป็นสำหรับแยกแยะ 15/25 (อ่านจาก cm_receipt/cm_payment แทน cm_transaction)
  final bool viewOnly;
  final int resetKey;
  final VoidCallback onSaveSuccess;
  final VoidCallback onCancel;
  final bool canDelete;
  /// ปุ่มของเอกสารแสดงบน AppBar ของหน้าจอแม่ (แทนแถบปุ่มเดิม)
  final DocAppBarActions? actions;

  const CmTransactionDetailWidget({
    super.key,
    this.transactionId,
    this.initialSysDocType,
    this.viewOnly = false,
    this.resetKey = 0,
    required this.onSaveSuccess,
    required this.onCancel,
    this.canDelete = true,
    this.actions,
  });

  @override
  State<CmTransactionDetailWidget> createState() => _CmTransactionDetailWidgetState();
}

class _DetailRow {
  final descCtrl = TextEditingController();
  final amountCtrl = TextEditingController(text: '0.00');
  int? expenseAccountId;
  String? expenseAccountCode;
  String? expenseAccountName;
  String vatType = 'NOVAT'; // รายรับ/รายจ่ายหลายบรรทัด (10/20), เบิกเงินสดย่อย (40)
  double vatRate = 0;
  // เบิกเงินสดย่อย (40): ผู้ขายและใบกำกับภาษีของบรรทัดที่มี VAT
  final sellerNameCtrl = TextEditingController();
  final sellerTaxIdCtrl = TextEditingController();
  final sellerBranchCtrl = TextEditingController();
  final taxInvNoCtrl = TextEditingController();
  DateTime? taxInvDate;
  Map<int, int?> dims = {}; // มิติของบรรทัด slot → value id (ว่าง = ใช้มิติหัวเอกสาร)

  _DetailRow();

  factory _DetailRow.fromModel(CmTransactionDetail d) {
    final r = _DetailRow();
    r.descCtrl.text = d.description ?? '';
    r.amountCtrl.text = (d.enteredAmountFc ?? d.amountFc).toStringAsFixed(2);
    r.vatType = d.vatType;
    r.vatRate = d.vatRate;
    r.sellerNameCtrl.text = d.sellerName ?? '';
    r.sellerTaxIdCtrl.text = d.sellerTaxId ?? '';
    r.sellerBranchCtrl.text = d.sellerBranchCode ?? '';
    r.taxInvNoCtrl.text = d.taxInvoiceNo ?? '';
    r.taxInvDate = d.taxInvoiceDate;
    r.expenseAccountId = d.expenseAccountId;
    r.expenseAccountCode = d.expenseAccountCode;
    r.expenseAccountName = d.expenseAccountName;
    r.dims = {1: d.dim1Id, 2: d.dim2Id, 3: d.dim3Id, 4: d.dim4Id, 5: d.dim5Id};
    return r;
  }

  void dispose() {
    descCtrl.dispose();
    amountCtrl.dispose();
    sellerNameCtrl.dispose();
    sellerTaxIdCtrl.dispose();
    sellerBranchCtrl.dispose();
    taxInvNoCtrl.dispose();
  }
}

class _ApplyRow {
  final int appliedToId;
  final String appliedToDocNo;
  final DateTime? appliedToDocDate;
  final double balanceAvailable; // ยอดคงเหลือของใบเบิก (LC จากฝั่งเซิร์ฟเวอร์)
  double appliedAmountFc; // จำนวนที่นำมาเติม กรอกเป็นสกุลเงินที่เลือกไว้ (FC)

  _ApplyRow({
    required this.appliedToId,
    required this.appliedToDocNo,
    this.appliedToDocDate,
    this.balanceAvailable = 0,
    this.appliedAmountFc = 0,
  });
}

class _PaymentRow {
  int? paymentMethodId;
  String? paymentMethodCode;
  String? paymentMethodName;
  String paymentMethodType;
  int? cmBankAccountId;
  int? checkbookId; // จ่ายด้วยเช็ค: สมุดเช็ค
  final amountCtrl = TextEditingController(text: '0.00');
  final refNoCtrl = TextEditingController();

  _PaymentRow({this.paymentMethodType = 'CASH'});

  factory _PaymentRow.fromModel(CmTransactionPayment p) {
    final r = _PaymentRow(paymentMethodType: p.paymentMethodType);
    r.paymentMethodId = p.paymentMethodId;
    r.paymentMethodCode = p.paymentMethodCode;
    r.paymentMethodName = p.paymentMethodName;
    r.cmBankAccountId = p.cmBankAccountId;
    r.checkbookId = p.checkbookId;
    r.amountCtrl.text = p.amountFc.toStringAsFixed(2);
    r.refNoCtrl.text = p.refNo ?? '';
    return r;
  }

  void dispose() {
    amountCtrl.dispose();
    refNoCtrl.dispose();
  }
}

// ภาษีหัก ณ ที่จ่าย — ยอดเป็นสกุลเงินของเอกสาร
class _WhtRow {
  CdWhtType? whtType;
  final baseCtrl = TextEditingController();
  final whtCtrl = TextEditingController();
  final descCtrl = TextEditingController();

  _WhtRow({this.whtType, double base = 0, double wht = 0, String? desc}) {
    baseCtrl.text = base > 0 ? base.toStringAsFixed(2) : '';
    whtCtrl.text = wht > 0 ? wht.toStringAsFixed(2) : '';
    descCtrl.text = desc ?? '';
  }

  void dispose() {
    baseCtrl.dispose();
    whtCtrl.dispose();
    descCtrl.dispose();
  }
}

class _GlLine {
  final String accountCode;
  final String accountName;
  final String description;
  final double debit;
  final double credit;
  final double debitFc;
  final double creditFc;
  final Map<int, int?>? dims; // มิติของบรรทัด (null = มิติหัวเอกสาร)
  const _GlLine(this.accountCode, this.accountName, this.description, this.debit, this.credit, this.debitFc, this.creditFc, [this.dims]);
}

// ── GL row (read-only preview — the server derives accounts from the GL setup,
// applies the header-level dimension selection to every line and recomputes on Post) ──
class _GlEditRow {
  String accountName;
  double debit;
  double credit;
  double debitFc;
  double creditFc;
  Map<int, int?> dimIds;
  Map<int, String?> dimNames;
  final TextEditingController acctCodeCtrl;
  final TextEditingController descCtrl;

  _GlEditRow({
    required String accountCode,
    required this.accountName,
    required String description,
    required this.debit,
    required this.credit,
    required this.debitFc,
    required this.creditFc,
    Map<int, int?>? dimIds,
    Map<int, String?>? dimNames,
  })  : acctCodeCtrl = TextEditingController(text: accountCode),
        descCtrl = TextEditingController(text: description),
        dimIds = dimIds ?? {},
        dimNames = dimNames ?? {};

  factory _GlEditRow.fromLine(_GlLine l, {Map<int, int?>? dimIds, Map<int, String?>? dimNames}) => _GlEditRow(
        accountCode: l.accountCode,
        accountName: l.accountName,
        description: l.description,
        debit: l.debit,
        credit: l.credit,
        debitFc: l.debitFc,
        creditFc: l.creditFc,
        dimIds: dimIds,
        dimNames: dimNames,
      );

  factory _GlEditRow.fromDetail(GlEntryDetail d, {bool isEnglish = false}) => _GlEditRow(
        accountCode: d.accountCode,
        accountName: isEnglish && d.accountNameEng.isNotEmpty ? d.accountNameEng : d.accountName,
        description: d.description,
        debit: d.debitLc,
        credit: d.creditLc,
        debitFc: d.debitFc,
        creditFc: d.creditFc,
        dimIds:   {1: d.dim1Id,   2: d.dim2Id,   3: d.dim3Id,   4: d.dim4Id,   5: d.dim5Id},
        dimNames: {1: d.dim1Name, 2: d.dim2Name, 3: d.dim3Name, 4: d.dim4Name, 5: d.dim5Name},
      );

  void dispose() {
    acctCodeCtrl.dispose();
    descCtrl.dispose();
  }
}

class _CmTransactionDetailWidgetState extends State<CmTransactionDetailWidget> implements DocAppBarActionsHost {
  final _formKey = GlobalKey<FormState>();
  final CmTransactionService _service = CmTransactionService();
  final CmTransactionGlSetupService _glSetupSvc = CmTransactionGlSetupService();
  final CmBankAccountService _bankAccountSvc = CmBankAccountService();
  final CmPaymentMethodService _paymentMethodSvc = CmPaymentMethodService();
  final AccountService _acctSvc = AccountService();
  final AuthService _authService = AuthService();
  final CurrencyService _currencySvc = CurrencyService();
  final GlEntryService _glEntryService = GlEntryService();
  final GlDimensionService _dimService = GlDimensionService();

  bool _isLoading = false;
  bool _isEnglish = false;

  List<ModuleDocument> _allowedDocTypes = [];
  List<CmBankAccount> _bankAccounts = [];
  List<CmPaymentMethod> _paymentMethods = [];
  List<Account> _accounts = [];
  List<Currency> _currencies = [];
  List<VatRate> _vatRates = [];
  List<CdWhtType> _whtTypes = [];
  List<ApVendor> _vendors = [];
  List<ArCustomer>? _customers; // โหลดเมื่อเปิดค้นหาลูกค้าครั้งแรก
  final Map<int, List<CmCheckbook>> _checkbooks = {}; // สมุดเช็คที่ใช้งานได้ ต่อบัญชีธนาคาร (โหลดเมื่อใช้)
  CmTransactionGlSetup? _docSetup;

  // GL Dimensions
  List<GlDimensionType> _dimTypes = [];
  Map<String, List<GlDimensionValue>> _dimValues = {};
  Map<int, int?> _dimSelections = {};
  Map<int, String?> _dimNames = {};
  // สาขา (user-approved 2026-11-18): ค่าเริ่มต้น สาขาของผู้ใช้ → สาขาของบัญชีธนาคารที่เลือก; รายการบัญชีลงสาขานี้
  int? _branchId;
  List<Branch> _branches = [];

  ModuleDocument? _selectedDocType;
  bool _isReadOnly = false;

  int _transactionId = 0;
  String _docNo = 'AUTO';
  DateTime _docDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  final _refNoCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _counterpartyCtrl = TextEditingController();
  final _amountCtrl = TextEditingController(text: '0.00'); // Transfer(50) / BankCharge-Interest(70/90)
  // คู่ค้า (20): เลือกจากผู้ขาย AP = แสดงอย่างเดียว (backend ดึงจากข้อมูลหลัก), ไม่เลือก = พิมพ์เอง
  String? _partySource;
  int? _partyId;
  String? _partyCode;
  String? _partyType;
  final _partyTaxIdCtrl = TextEditingController();
  final _partyBranchCtrl = TextEditingController();
  final _partyAddressCtrl = TextEditingController();
  bool _priceIncludesVat = false;
  final _taxInvNoCtrl = TextEditingController(); // เลขที่ใบกำกับภาษีของผู้ขาย (20)
  DateTime? _taxInvDate;
  List<_WhtRow> _whtRows = [];
  double _subtotalFc = 0;
  double _vatFc = 0;
  double _whtFc = 0;
  // ค่าธรรมเนียมธนาคาร (70): VAT ของค่าธรรมเนียม — ผู้ขาย = ธนาคาร (ชื่อ/เลขผู้เสียภาษีใช้ช่องคู่ค้า)
  String _chargeVatType = 'NOVAT';
  double _chargeVatRate = 0;
  // ดอกเบี้ยรับ (90): ภาษีที่ธนาคารหักไว้
  final _intWhtRateCtrl = TextEditingController();
  final _intWhtCtrl = TextEditingController();
  String _status = 'Draft';
  // ถอยเป็นร่าง / ยกเลิก: null = ทำได้ หรือรหัสเหตุผลจาก backend
  String? _reverseBlock;
  String? _reverseBlockRef;
  String? _voidBlock;
  String? _voidBlockRef;
  List<DocReverseLog> _reverseHistory = [];
  List<DocApprovalStep> _approvals = [];
  String? _approvalMode;

  int? _fromBankAccountId;
  int? _toBankAccountId;
  int? _bankAccountId; // เงินสดย่อย(30/40) หรือบัญชีที่ได้รับผลกระทบ(70/90)
  int? _glAccountId;   // บัญชีฝั่งตรงข้าม (10/20/70/90)
  String? _chargeType; // BANK_CHARGE / INTEREST_INCOME / INTEREST_EXPENSE

  Currency? _selectedCurrency;
  double _exchangeRate = 1.0;

  List<_DetailRow> _detailRows = [];
  List<_ApplyRow> _applyRows = [];
  List<CmOpenVoucher> _openVouchers = [];
  List<_PaymentRow> _paymentRows = [];

  // GL section state
  int? _glEntryId;
  List<_GlEditRow> _glEditRows = [];
  bool _glLoading = false;

  double _totalAmountFc = 0;
  double _totalAmountLc = 0;

  // สำหรับดูข้อมูล read-only ของ 15 (รายรับจาก AR) / 25 (รายจ่ายจาก AP)
  bool _isReadOnlyView = false;
  CmLegacyMirrorRow? _legacyRow;

  bool _headerExpanded = true;
  bool _glExpanded = true;
  final Map<String, double?> _bankBalances = {}; // ยอดคงเหลือ "id@วันที่" (โอนเงิน 50)
  final Map<int, TextEditingController> _applyCtrls = {}; // ช่องยอดเติมต่อใบเบิก (30)
  void _clearApplyCtrls() {
    for (final c in _applyCtrls.values) {
      c.dispose();
    }
    _applyCtrls.clear();
  }

  final _fmt = NumberFormat('#,##0.00');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  bool get _isReceipt        => _selectedDocType?.sysDocType == cmDocTypeReceipt.toString();
  bool get _isPayment        => _selectedDocType?.sysDocType == cmDocTypePayment.toString();
  bool get _isReplenishment  => _selectedDocType?.sysDocType == cmDocTypePettyCashReplenishment.toString();
  bool get _isVoucher        => _selectedDocType?.sysDocType == cmDocTypePettyCashVoucher.toString();
  bool get _isTransfer       => _selectedDocType?.sysDocType == cmDocTypeInterBankTransfer.toString();
  bool get _isBankCharge     => _selectedDocType?.sysDocType == cmDocTypeBankCharge.toString();
  bool get _isInterest       => _selectedDocType?.sysDocType == cmDocTypeInterest.toString();
  // 20/30/40/50 ต้องส่งขออนุมัติและได้รับอนุมัติก่อน Post (backend APPROVAL_TYPES)
  bool get _requiresApproval => _isPayment || _isReplenishment || _isVoucher || _isTransfer;

  // รายรับ (10) / รายจ่าย (20): บรรทัดรายการแบบ VAT + ภาษีหัก ณ ที่จ่าย + คู่ค้า
  // (20 = เราหักผู้รับเงิน, 10 = ผู้จ่ายหักเรา; ใบกำกับของผู้ขายและประเภท ภ.ง.ด. เฉพาะ 20)
  bool get _hasTaxLines      => _isPayment || _isReceipt;
  bool get _hasDetailRows    => _isVoucher || _hasTaxLines;
  bool get _hasVatLines      => _hasTaxLines || _isVoucher; // บรรทัดที่เลือก VAT ได้
  bool get _isInterestIncome => _isInterest && _chargeType == 'INTEREST_INCOME';
  bool get _hasSellerInfo    => _hasPartySection || _isBankCharge; // ชื่อ/เลขผู้เสียภาษี/สาขา ของคู่ค้า
  bool get _showsWht         => _hasWhtSection || _isInterestIncome;
  // ค่าธรรมเนียมธนาคาร (70): บัญชีธนาคารที่ตั้งเลขผู้เสียภาษีไว้ = ผู้ขายจากบัญชี (backend ดึงซ้ำตอนบันทึก)
  CmBankAccount? get _chargeBank => _bankAccounts.where((b) => b.id == _bankAccountId).firstOrNull;
  bool get _bankHasTaxId => _isBankCharge && (_chargeBank?.taxId ?? '').trim().isNotEmpty;
  void _fillBankSeller() {
    final b = _chargeBank;
    if (b == null) return;
    if ((b.taxId ?? '').trim().isNotEmpty) {
      _counterpartyCtrl.text = b.bankNameTh ?? '';
      _partyTaxIdCtrl.text = b.taxId!;
      _partyBranchCtrl.text = b.taxBranchCode ?? '00000';
    } else if (_counterpartyCtrl.text.trim().isEmpty) {
      _counterpartyCtrl.text = b.bankNameTh ?? '';
    }
  }
  bool get _hasPartySection  => _isPayment || _isReceipt;
  bool get _hasWhtSection    => _isPayment || _isReceipt;
  bool get _hasApplySection  => _isReplenishment;
  bool get _hasPaymentSection => _isReceipt || _isPayment || _isReplenishment;
  bool get _hasCounterparty  => false; // ชื่อคู่ค้าอยู่ในส่วนคู่ค้าแล้ว (10/20)
  bool get _hasPettyCashAccountField => _isReplenishment || _isVoucher;
  bool get _hasTransferFields => _isTransfer;
  bool get _hasBankChargeFields => _isBankCharge || _isInterest;
  bool get _hasSingleAmountField => _isTransfer || _isBankCharge || _isInterest;

  @override
  void initState() {
    super.initState();
    widget.actions?.attach(this);
    _initMasterData();
  }

  @override
  void dispose() {
    widget.actions?.detach(this);
    _refNoCtrl.dispose();
    _clearApplyCtrls();
    _descCtrl.dispose();
    _counterpartyCtrl.dispose();
    _amountCtrl.dispose();
    _partyTaxIdCtrl.dispose();
    _partyBranchCtrl.dispose();
    _partyAddressCtrl.dispose();
    _taxInvNoCtrl.dispose();
    _intWhtRateCtrl.dispose();
    _intWhtCtrl.dispose();
    for (final r in _whtRows) {
      r.dispose();
    }
    for (final r in _detailRows) r.dispose();
    for (final r in _paymentRows) r.dispose();
    for (final r in _glEditRows) r.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CmTransactionDetailWidget old) {
    super.didUpdateWidget(old);
    if (widget.actions != old.actions) {
      old.actions?.detach(this);
      widget.actions?.attach(this);
    }
    if (widget.transactionId != old.transactionId ||
        widget.viewOnly != old.viewOnly ||
        widget.resetKey != old.resetKey) {
      _loadTransactionData().then((_) async { if (mounted) await _loadDocSetup(); _markClean(); });
    }
  }

  Future<void> _initMasterData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _service.fetchDocTypesByUser(),
        _bankAccountSvc.fetchRows(),
        _paymentMethodSvc.fetchRows(),
        _acctSvc.fetchRows(),
        _currencySvc.fetchActiveRows(),
        _dimService.fetchActiveTypes(),
        VatRateService().fetchRows(),
        CdWhtTypeService().fetchActiveRows(),
        ApVendorService().fetchActiveRows(),
      ]);
      try {
        _branches = await BranchService().fetchActiveRows();
      } catch (_) {}
      _vatRates = (results[6] as List<VatRate>).where((v) => v.isActive).toList();
      _whtTypes = results[7] as List<CdWhtType>;
      _vendors = results[8] as List<ApVendor>;
      _allowedDocTypes = (results[0] as List<ModuleDocument>)
          .where((d) => d.isDocType && !cmReadOnlyDocTypes.contains(int.tryParse(d.sysDocType)))
          .toList();
      _bankAccounts = (results[1] as List<CmBankAccount>).where((b) => b.isActive).toList();
      _paymentMethods = (results[2] as List<CmPaymentMethod>).where((m) => m.isActive).toList();
      _accounts = (results[3] as List<Account>).where((a) => a.isActive && a.isNormalAccount).toList();
      _currencies = results[4] as List<Currency>;
      _dimTypes = results[5] as List<GlDimensionType>;

      final dimValueResults = await Future.wait(
        _dimTypes.map((t) => _dimService.fetchValuesByType(t.typeCode)),
      );
      for (int i = 0; i < _dimTypes.length; i++) {
        _dimValues[_dimTypes[i].typeCode] = dimValueResults[i];
      }

      if (_allowedDocTypes.isNotEmpty && _selectedDocType == null) {
        _selectedDocType = _allowedDocTypes.first;
      }
      if (_currencies.isNotEmpty && _selectedCurrency == null) {
        _selectedCurrency = _currencies.cast<Currency?>()
            .firstWhere((c) => c!.baseCurrencyFlag, orElse: () => null)
            ?? _currencies.first;
      }
      await _loadTransactionData();
      await _loadDocSetup();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading master: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _markClean();
    }
  }

  Future<void> _loadDocSetup() async {
    if (_selectedDocType == null || _isReadOnlyView) return;
    try {
      final setup = await _glSetupSvc.fetchRow(_selectedDocType!.docCode);
      if (mounted) {
        setState(() => _docSetup = setup);
        if (!_isReadOnly) _rebuildGlRows();
      }
    } catch (_) {}
  }

  Future<void> _loadPostedGl() async {
    if (_glEntryId == null || !mounted) return;
    setState(() => _glLoading = true);
    try {
      final result = await _glEntryService.fetchEntryDetail(_glEntryId!);
      final details = result['details'] as List<GlEntryDetail>;
      for (final r in _glEditRows) r.dispose();
      if (mounted) {
        setState(() {
          _glEditRows = details.map((d) => _GlEditRow.fromDetail(d, isEnglish: _isEnglish)).toList();
          _glLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _glLoading = false);
    }
  }

  Future<void> _loadOpenVouchers(int pettyCashAccountId) async {
    try {
      final vouchers = await _service.fetchOpenVouchers(bankAccountId: pettyCashAccountId);
      if (mounted) setState(() => _openVouchers = vouchers);
    } catch (_) {}
  }

  Future<void> _loadTransactionData() async {
    if (widget.transactionId == null) { _resetForm(); return; }
    setState(() => _isLoading = true);
    try {
      if (widget.initialSysDocType == cmDocTypeReceiptFromAr) {
        final row = await _service.fetchReceiptView(widget.transactionId!);
        setState(() { _legacyRow = row; _isReadOnlyView = true; _status = 'Posted'; _glEntryId = row.sourceGlEntryId; });
        await _loadPostedGl();
        return;
      }
      if (widget.initialSysDocType == cmDocTypePaymentFromAp) {
        final row = await _service.fetchPaymentView(widget.transactionId!);
        setState(() { _legacyRow = row; _isReadOnlyView = true; _status = 'Posted'; _glEntryId = row.sourceGlEntryId; });
        await _loadPostedGl();
        return;
      }
      _isReadOnlyView = false;
      final data = await _service.fetchRow(widget.transactionId!);
      final h = data.header;
      setState(() {
        _transactionId = h.id;
        _docNo = h.docNo;
        _docDate = h.docDate;
        _refNoCtrl.text = h.refNo ?? '';
        _descCtrl.text = h.description ?? '';
        _counterpartyCtrl.text = h.counterpartyName ?? '';
        _partySource = h.partySource;
        _partyId = h.partyId;
        _partyCode = h.partyCode;
        _partyType = h.partyType;
        _partyTaxIdCtrl.text = h.partyTaxId ?? '';
        _partyBranchCtrl.text = h.partyBranchCode ?? '';
        _partyAddressCtrl.text = h.partyAddress ?? '';
        _priceIncludesVat = h.priceIncludesVat;
        _taxInvNoCtrl.text = h.taxInvoiceNo ?? '';
        _taxInvDate = h.taxInvoiceDate;
        for (final r in _whtRows) {
          r.dispose();
        }
        _whtRows = data.whts.map((w) => _WhtRow(
              whtType: _whtTypes.cast<CdWhtType?>().firstWhere((t) => t?.id == w.whtTypeId, orElse: () => null),
              base: w.baseAmountFc, wht: w.whtAmountFc, desc: w.description,
            )).toList();
        _status = h.status;
        _isReadOnly = widget.viewOnly || h.status != 'Draft';
        // 70: บรรทัดเดียวของค่าธรรมเนียม (ยอดที่กรอก + VAT), 90: ภาษีถูกหัก ณ ที่จ่าย
        _chargeVatType = 'NOVAT'; _chargeVatRate = 0;
        _intWhtRateCtrl.clear(); _intWhtCtrl.clear();
        _reverseBlock = data.reverseBlock;
        _reverseBlockRef = data.reverseBlockRef;
        _voidBlock = data.voidBlock;
        _voidBlockRef = data.voidBlockRef;
        _reverseHistory = data.reverseHistory;
        _approvals = data.approvals;
        _approvalMode = data.approvalMode;
        _fromBankAccountId = h.fromBankAccountId;
        _toBankAccountId = h.toBankAccountId;
        _bankAccountId = h.bankAccountId;
        _glAccountId = h.glAccountId;
        _chargeType = h.chargeType;
        _glEntryId = h.glEntryId;
        _exchangeRate = h.exchangeRate;
        _totalAmountFc = h.totalAmountFc;
        _totalAmountLc = h.totalAmountLc;
        _amountCtrl.text = h.totalAmountFc.toStringAsFixed(2);
        if (h.sysDocType == cmDocTypeBankCharge && data.details.isNotEmpty) {
          final d = data.details.first;
          _chargeVatType = d.vatType;
          _chargeVatRate = d.vatRate;
          _amountCtrl.text = (d.enteredAmountFc ?? d.amountFc).toStringAsFixed(2);
        }
        if (h.sysDocType == cmDocTypeInterest && data.whts.isNotEmpty) {
          _intWhtRateCtrl.text = data.whts.first.whtRate > 0 ? data.whts.first.whtRate.toStringAsFixed(2) : '';
          _intWhtCtrl.text = data.whts.first.whtAmountFc.toStringAsFixed(2);
        }
        if (_currencies.isNotEmpty) {
          try { _selectedCurrency = _currencies.firstWhere((c) => c.id == h.currencyId); } catch (_) {
            try { _selectedCurrency = _currencies.firstWhere((c) => c.currencyCode == h.currencyCode); } catch (_) {}
          }
        }
        _dimSelections = {1: h.dim1Id, 2: h.dim2Id, 3: h.dim3Id, 4: h.dim4Id, 5: h.dim5Id};
        _dimNames = {1: h.dim1Name, 2: h.dim2Name, 3: h.dim3Name, 4: h.dim4Name, 5: h.dim5Name};
        _branchId = h.branchId;

        if (_allowedDocTypes.isNotEmpty) {
          try { _selectedDocType = _allowedDocTypes.firstWhere((d) => d.id == h.docId); } catch (_) {}
        }

        for (final r in _detailRows) r.dispose();
        _detailRows = data.details.map((d) => _DetailRow.fromModel(d)).toList();

        for (final r in _paymentRows) r.dispose();
        _paymentRows = data.payments.map((p) => _PaymentRow.fromModel(p)).toList();

        _clearApplyCtrls();
        _applyRows = data.applies.map((a) => _ApplyRow(
              appliedToId: a.appliedToId,
              appliedToDocNo: a.appliedToDocNo ?? '',
              appliedToDocDate: a.appliedToDocDate,
              appliedAmountFc: a.appliedAmountFc,
            )).toList();
      });
      if (_isReplenishment && _bankAccountId != null) {
        await _loadOpenVouchers(_bankAccountId!);
      }
      if (h.status == 'Posted') {
        _recalcTotals(); // ยอดก่อน VAT/VAT/ภาษีหัก ณ ที่จ่าย ของแถบยอดรวม (อ่านอย่างเดียว ไม่สร้าง GL ตัวอย่าง)
        await _loadPostedGl();
      } else {
        _recalcTotals();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ยังไม่มีสาขา → ใช้สาขาของบัญชีธนาคารที่เลือก (ตั้งที่หน้าบัญชีธนาคาร)
  void _fillBranchFromBank(int? bankAccountId) {
    if (_branchId != null || bankAccountId == null) return;
    for (final b in _bankAccounts) {
      if (b.id == bankAccountId) { _branchId = b.branchId; return; }
    }
  }

  void _resetForm() {
    setState(() {
      _transactionId = 0;
      _docNo = 'AUTO';
      _docDate = DateTime.now();
      _refNoCtrl.clear();
      _descCtrl.clear();
      _counterpartyCtrl.clear();
      _partySource = null; _partyId = null; _partyCode = null; _partyType = null;
      _partyTaxIdCtrl.clear(); _partyBranchCtrl.clear(); _partyAddressCtrl.clear();
      _priceIncludesVat = false;
      _taxInvNoCtrl.clear(); _taxInvDate = null;
      for (final r in _whtRows) {
        r.dispose();
      }
      _whtRows = [];
      _subtotalFc = 0; _vatFc = 0; _whtFc = 0;
      _chargeVatType = 'NOVAT'; _chargeVatRate = 0;
      _intWhtRateCtrl.clear(); _intWhtCtrl.clear();
      _amountCtrl.text = '0.00';
      _status = 'Draft';
      _isReadOnly = false;
      _isReadOnlyView = false;
      _reverseBlock = null; _reverseBlockRef = null; _voidBlock = null; _voidBlockRef = null; _reverseHistory = [];
      _approvals = []; _approvalMode = null;
      _legacyRow = null;
      _selectedDocType = _allowedDocTypes.isNotEmpty ? _allowedDocTypes.first : null;
      _fromBankAccountId = null;
      _toBankAccountId = null;
      _bankAccountId = null;
      _glAccountId = null;
      _chargeType = null;
      _glEntryId = null;
      _selectedCurrency = _currencies.cast<Currency?>()
          .firstWhere((c) => c!.baseCurrencyFlag, orElse: () => null)
          ?? (_currencies.isNotEmpty ? _currencies.first : null);
      _exchangeRate = 1.0;
      _dimSelections = {};
      _dimNames = {};
      _branchId = defaultDocBranchId();
      for (final r in _detailRows) r.dispose(); _detailRows = [];
      for (final r in _paymentRows) r.dispose(); _paymentRows = [];
      for (final r in _glEditRows) r.dispose(); _glEditRows = [];
      _applyRows = [];
      _clearApplyCtrls();
      _openVouchers = [];
      _totalAmountFc = 0;
      _totalAmountLc = 0;
      _docSetup = null;
    });
  }

// สมุดเช็ค: ช่องทางจ่ายด้วยเช็คของเอกสารจ่ายเงิน (20/30) — เลขเช็คว่าง = backend ใช้เลขถัดไปของสมุดเช็คตอน Post
  bool _usesCheckbook(_PaymentRow r) => (_isPayment || _isReplenishment) && r.paymentMethodType == 'CHECK' && r.cmBankAccountId != null;
  Future<void> _ensureCheckbooks(int bankAccountId) async {
    if (_checkbooks.containsKey(bankAccountId)) return;
    _checkbooks[bankAccountId] = const [];
    try {
      final list = await CmCheckbookService().fetchCheckbooks(bankAccountId: bankAccountId);
      if (mounted) setState(() => _checkbooks[bankAccountId] = list);
    } catch (_) {}
  }

  // ยอดของบรรทัดรายการแบบ VAT (เหมือน backend calcTaxDoc)
  LineAmounts _lineAmt(_DetailRow r) => calcLineAmounts(
        qty: 1,
        price: double.tryParse(r.amountCtrl.text) ?? 0,
        vatRate: r.vatRate,
        noVat: r.vatType == 'NOVAT',
        priceIncludesVat: _priceIncludesVat,
      );
  double get _netPayFc => _totalAmountFc - _whtFc; // ยอดที่จ่ายจริง = ยอดรวม − ภาษีหัก ณ ที่จ่าย

  void _recalcTotals() {
    double totalFc = 0;
    _subtotalFc = 0; _vatFc = 0; _whtFc = 0;
    if (_hasVatLines && _detailRows.isNotEmpty) {
      for (final r in _detailRows) {
        final a = _lineAmt(r);
        _subtotalFc += a.net;
        _vatFc += a.vat;
      }
      totalFc = _subtotalFc + _vatFc;
      _whtFc = _whtRows.fold(0.0, (t, w) => t + (double.tryParse(w.whtCtrl.text) ?? 0));
    } else if (_isVoucher) {
      totalFc = _detailRows.fold(0.0, (s, r) => s + (double.tryParse(r.amountCtrl.text) ?? 0));
    } else if (_isReplenishment) {
      totalFc = _applyRows.fold(0.0, (s, a) => s + a.appliedAmountFc);
    } else if (_isReceipt || _isPayment) {
      totalFc = _paymentRows.fold(0.0, (s, r) => s + (double.tryParse(r.amountCtrl.text) ?? 0));
    } else if (_isBankCharge) {
      final a = calcLineAmounts(qty: 1, price: double.tryParse(_amountCtrl.text) ?? 0, vatRate: _chargeVatRate,
          noVat: _chargeVatType == 'NOVAT', priceIncludesVat: _priceIncludesVat);
      _subtotalFc = a.net;
      _vatFc = a.vat;
      totalFc = a.total;
    } else if (_isInterestIncome) {
      totalFc = double.tryParse(_amountCtrl.text) ?? 0;
      _whtFc = double.tryParse(_intWhtCtrl.text) ?? 0;
    } else if (_hasSingleAmountField) {
      totalFc = double.tryParse(_amountCtrl.text) ?? 0;
    }
    setState(() {
      _totalAmountFc = totalFc;
      _totalAmountLc = totalFc * _exchangeRate;
    });
    if (!_isReadOnly) _rebuildGlRows();
  }

  void _rebuildGlRows() {
    final lines = _computeGlPreview();
    for (final r in _glEditRows) r.dispose();
    setState(() {
      _glEditRows = lines.map((l) => _GlEditRow.fromLine(l,
        dimIds: l.dims ?? Map<int, int?>.from(_dimSelections),
        dimNames: Map<int, String?>.from(_dimNames),
      )).toList();
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: _docDate,
      firstDate: DateTime(2000), lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _docDate = picked);
  }

  String _docTypeLabel(ModuleDocument d) =>
      _isEnglish && d.docNameEng.isNotEmpty ? d.docNameEng : d.docNameThai;

  String _acctLabel(Account a) =>
      _isEnglish && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai;

  String _bankAcctLabel(CmBankAccount b) {
    final name = _isEnglish && (b.accountNameEn ?? '').isNotEmpty ? b.accountNameEn! : b.accountNameTh;
    return '${b.accountCode}  $name';
  }

  String _currencyLabel(Currency c) =>
      _isEnglish && c.currencyNameEng.isNotEmpty ? c.currencyNameEng : c.currencyNameThai;

  // ข้อมูลที่บันทึก — ใช้ทั้งตอนบันทึกและตรวจการแก้ไขค้าง
  ({CmTransactionHeader header, List<CmTransactionDetail> details, List<CmTransactionApply> applies,
    List<CmTransactionPayment> payments, List<CmTransactionWht> whts}) _savePayload() {
    final userName = _authService.currentUser?.userName ?? '';
    final lc = _exchangeRate;

    final header = CmTransactionHeader(
      id: _transactionId,
      docId: _selectedDocType!.id,
      docNo: _docNo,
      docDate: _docDate,
      fromBankAccountId: _isTransfer ? _fromBankAccountId : null,
      toBankAccountId: _isTransfer ? _toBankAccountId : null,
      bankAccountId: (_hasPettyCashAccountField || _hasBankChargeFields) ? _bankAccountId : null,
      glAccountId: (_hasCounterparty || _hasBankChargeFields) ? _glAccountId : null,
      chargeType: _isBankCharge ? 'BANK_CHARGE' : (_isInterest ? _chargeType : null),
      counterpartyName: (_hasCounterparty || _hasSellerInfo) && _counterpartyCtrl.text.isNotEmpty ? _counterpartyCtrl.text : null,
      partySource: _hasPartySection ? _partySource : null,
      partyId: _hasPartySection ? _partyId : null,
      partyTaxId: _hasSellerInfo ? _partyTaxIdCtrl.text.trim() : null,
      partyBranchCode: _hasSellerInfo ? _partyBranchCtrl.text.trim() : null,
      partyType: _isPayment ? _partyType : null,
      partyAddress: _hasPartySection ? _partyAddressCtrl.text.trim() : null,
      priceIncludesVat: (_hasVatLines || _isBankCharge) && _priceIncludesVat,
      taxInvoiceNo: (_isPayment || _isBankCharge) && _taxInvNoCtrl.text.trim().isNotEmpty ? _taxInvNoCtrl.text.trim() : null,
      taxInvoiceDate: (_isPayment || _isBankCharge) && _taxInvNoCtrl.text.trim().isNotEmpty ? (_taxInvDate ?? _docDate) : null,
      currencyId: _selectedCurrency?.id,
      currencyCode: _selectedCurrency?.currencyCode ?? CurrencyService.baseCode,
      exchangeRate: _exchangeRate,
      totalAmountFc: _totalAmountFc,
      totalAmountLc: _totalAmountLc,
      refNo: _refNoCtrl.text.isEmpty ? null : _refNoCtrl.text,
      description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
      status: _status,
      dim1Id: _dimSelections[1], dim2Id: _dimSelections[2],
      dim3Id: _dimSelections[3], dim4Id: _dimSelections[4], dim5Id: _dimSelections[5],
      branchId: _branchId,
      createdBy: _transactionId == 0 ? userName : null,
      updatedBy: _transactionId != 0 ? userName : null,
    );

    final details = _hasDetailRows
        ? _detailRows.asMap().entries.map((e) {
            final fc = double.tryParse(e.value.amountCtrl.text) ?? 0;
            return CmTransactionDetail(
              lineNo: e.key + 1,
              description: e.value.descCtrl.text.isEmpty ? null : e.value.descCtrl.text,
              expenseAccountId: e.value.expenseAccountId,
              amountLc: fc * lc,
              amountFc: fc,
              // 10/20: ยอดที่กรอก + VAT — backend คำนวณยอดก่อน VAT/VAT/ยอดบาทใหม่
              enteredAmountFc: _hasVatLines ? fc : null,
              vatType: _hasVatLines ? e.value.vatType : 'NOVAT',
              vatRate: _hasVatLines ? e.value.vatRate : 0,
              // 40: ผู้ขาย/ใบกำกับของบรรทัดที่มี VAT
              sellerName: _isVoucher && e.value.vatType != 'NOVAT' ? e.value.sellerNameCtrl.text.trim() : null,
              sellerTaxId: _isVoucher && e.value.vatType != 'NOVAT' ? e.value.sellerTaxIdCtrl.text.trim() : null,
              sellerBranchCode: _isVoucher && e.value.vatType != 'NOVAT' ? e.value.sellerBranchCtrl.text.trim() : null,
              taxInvoiceNo: _isVoucher && e.value.vatType != 'NOVAT' && e.value.taxInvNoCtrl.text.trim().isNotEmpty ? e.value.taxInvNoCtrl.text.trim() : null,
              taxInvoiceDate: _isVoucher && e.value.vatType != 'NOVAT' && e.value.taxInvNoCtrl.text.trim().isNotEmpty ? (e.value.taxInvDate ?? _docDate) : null,
              dim1Id: e.value.dims[1], dim2Id: e.value.dims[2], dim3Id: e.value.dims[3],
              dim4Id: e.value.dims[4], dim5Id: e.value.dims[5],
            );
          }).toList()
        : _isBankCharge
            // ค่าธรรมเนียมธนาคาร: บรรทัดเดียว (ยอดที่กรอก + VAT) — backend คำนวณยอดก่อน VAT/VAT
            ? [CmTransactionDetail(
                lineNo: 1,
                description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
                expenseAccountId: _glAccountId,
                amountFc: double.tryParse(_amountCtrl.text) ?? 0,
                amountLc: (double.tryParse(_amountCtrl.text) ?? 0) * lc,
                enteredAmountFc: double.tryParse(_amountCtrl.text) ?? 0,
                vatType: _chargeVatType,
                vatRate: _chargeVatRate,
              )]
            : <CmTransactionDetail>[];

    final applies = _hasApplySection
        ? _applyRows.map((a) => CmTransactionApply(
              appliedToId: a.appliedToId,
              appliedAmountLc: a.appliedAmountFc * lc,
              appliedAmountFc: a.appliedAmountFc,
            )).toList()
        : <CmTransactionApply>[];

    final payments = _hasPaymentSection
        ? _paymentRows.map((p) {
            final fc = double.tryParse(p.amountCtrl.text) ?? 0;
            return CmTransactionPayment(
              paymentMethodId: p.paymentMethodId,
              paymentMethodCode: p.paymentMethodCode,
              paymentMethodName: p.paymentMethodName,
              paymentMethodType: p.paymentMethodType,
              cmBankAccountId: p.cmBankAccountId,
              amountLc: fc * lc,
              amountFc: fc,
              refNo: p.refNoCtrl.text.isEmpty ? null : p.refNoCtrl.text,
              paymentDate: _docDate,
              checkbookId: _usesCheckbook(p) ? p.checkbookId : null,
            );
          }).toList()
        : <CmTransactionPayment>[];

    final whts = _hasWhtSection && _hasTaxLines
        ? _whtRows.where((w) => (double.tryParse(w.whtCtrl.text) ?? 0) > 0).map((w) => CmTransactionWht(
              whtTypeId: w.whtType?.id,
              whtType: w.whtType?.whtName,
              incomeType: w.whtType?.incomeType,
              whtRate: w.whtType?.whtRate ?? 0,
              baseAmountFc: double.tryParse(w.baseCtrl.text) ?? 0,
              whtAmountFc: double.tryParse(w.whtCtrl.text) ?? 0,
              description: w.descCtrl.text.trim().isEmpty ? null : w.descCtrl.text.trim(),
            )).toList()
        : _isInterestIncome && (double.tryParse(_intWhtCtrl.text) ?? 0) > 0
            ? [CmTransactionWht(
                whtRate: double.tryParse(_intWhtRateCtrl.text) ?? 0,
                baseAmountFc: double.tryParse(_amountCtrl.text) ?? 0,
                whtAmountFc: double.tryParse(_intWhtCtrl.text) ?? 0,
                description: 'ภาษีถูกหัก ณ ที่จ่าย (ดอกเบี้ยรับ)',
              )]
            : <CmTransactionWht>[];

    return (header: header, details: details, applies: applies, payments: payments, whts: whts);
  }

  Future<void> _save(String action) async {
    final isEnglish = _isEnglish;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDocType == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please select a document type' : 'กรุณาเลือกประเภทเอกสาร')));
      return;
    }
    if (_isTransfer && (_fromBankAccountId == null || _toBankAccountId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please select both accounts' : 'กรุณาเลือกบัญชีต้นทางและปลายทาง')));
      return;
    }
    if (_isTransfer && _fromBankAccountId == _toBankAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Source and destination accounts must differ' : 'บัญชีต้นทางและปลายทางต้องไม่ใช่บัญชีเดียวกัน')));
      return;
    }
    if (_isTransfer) {
      // ยังไม่รองรับโอนข้ามสกุลเงิน (เหมือน backend)
      final from = _bankAccounts.where((b) => b.id == _fromBankAccountId);
      final to = _bankAccounts.where((b) => b.id == _toBankAccountId);
      if (from.isNotEmpty && to.isNotEmpty && from.first.currencyCode != to.first.currencyCode) {
        final pair = '${from.first.currencyCode} → ${to.first.currencyCode}';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish
            ? 'Transfers between accounts in different currencies are not supported yet ($pair)'
            : 'ยังไม่รองรับการโอนเงินระหว่างบัญชีต่างสกุลเงิน ($pair)')));
        return;
      }
    }
    if (_hasBankChargeFields && _bankAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please select a bank account' : 'กรุณาเลือกบัญชีธนาคาร')));
      return;
    }
    if (_isInterest && (_chargeType == null || _chargeType!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please select income or expense' : 'กรุณาเลือกดอกเบี้ยรับหรือดอกเบี้ยจ่าย')));
      return;
    }
    _recalcTotals();
    if (_hasTaxLines && _detailRows.isNotEmpty) {
      final payFc = _paymentRows.fold(0.0, (t, r) => t + (double.tryParse(r.amountCtrl.text) ?? 0));
      if ((payFc - _netPayFc).abs() > 0.005) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish
            ? 'Payment channels (${_fmt.format(payFc)}) must equal the net amount (${_fmt.format(_netPayFc)})'
            : 'ยอดช่องทางรับ/จ่ายเงิน (${_fmt.format(payFc)}) ต้องเท่ากับยอดสุทธิ (${_fmt.format(_netPayFc)})')));
        return;
      }
      if (action == 'Post' && _isPayment && _vatFc.abs() > 0.005 && _taxInvNoCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish
            ? 'Please enter the vendor tax invoice no. (this document has input VAT)'
            : 'กรุณาระบุเลขที่ใบกำกับภาษีของผู้ขาย (เอกสารมีภาษีซื้อ)')));
        return;
      }
    }
    if (action == 'Post' && _isBankCharge && _vatFc.abs() > 0.005 &&
        (_taxInvNoCtrl.text.trim().isEmpty || _counterpartyCtrl.text.trim().isEmpty || _partyTaxIdCtrl.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish
          ? 'The bank charge has input VAT — enter the bank name, tax ID and tax invoice no.'
          : 'ค่าธรรมเนียมมีภาษีซื้อ กรุณาระบุชื่อธนาคาร เลขประจำตัวผู้เสียภาษี และเลขที่ใบกำกับภาษี')));
      return;
    }
    if (action == 'Post' && _isVoucher) {
      final bad = _detailRows.indexWhere((r) => _lineAmt(r).vat.abs() > 0.005 &&
          (r.sellerNameCtrl.text.trim().isEmpty || r.sellerTaxIdCtrl.text.trim().isEmpty || r.taxInvNoCtrl.text.trim().isEmpty));
      if (bad >= 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish
            ? 'Line ${bad + 1}: has input VAT — enter the seller name, tax ID and tax invoice no.'
            : 'บรรทัดที่ ${bad + 1}: มีภาษีซื้อ กรุณาระบุชื่อผู้ขาย เลขประจำตัวผู้เสียภาษี และเลขที่ใบกำกับภาษี')));
        return;
      }
    }
    if (action == 'Post' && !(await CmPeriodService.canPost(context, _docDate))) {
      return;
    }

    final p = _savePayload();
    final header = p.header, details = p.details, applies = p.applies, payments = p.payments, whts = p.whts;

    setState(() => _isLoading = true);
    try {
      if (_transactionId == 0) {
        await _service.createTransaction(header: header, details: details, applies: applies, payments: payments, whts: whts, action: action);
      } else {
        await _service.updateTransaction(id: _transactionId, header: header, details: details, applies: applies, payments: payments, whts: whts, action: action);
      }
      _markClean();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(action == 'Post'
              ? (isEnglish ? 'Saved and posted successfully' : 'บันทึกและ Post เรียบร้อย')
              : (isEnglish ? 'Draft saved successfully' : 'บันทึก Draft เรียบร้อย')),
        ));
        widget.onSaveSuccess();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEnglish
            ? 'Save failed: ${e.toString().replaceFirst('Exception: ', '')}'
            : 'บันทึกไม่สำเร็จ: ${e.toString().replaceFirst('Exception: ', '')}'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // เหตุผลที่ถอยเป็นร่าง / ยกเลิกไม่ได้ (ตามรหัสจาก backend) — null = ทำได้
  String? _reverseBlockMessage(bool isEnglish) => _blockMessage(_reverseBlock, _reverseBlockRef, isEnglish);
  String? _voidBlockMessage(bool isEnglish) => _blockMessage(_voidBlock, _voidBlockRef, isEnglish);

  String? _blockMessage(String? code, String? blockRef, bool isEnglish) {
    final ref = blockRef != null ? ' ($blockRef)' : '';
    switch (code) {
      case null:
        return null;
      case 'NOT_REVERSIBLE':
        return isEnglish ? 'Only posted documents can be reversed' : 'ถอยได้เฉพาะเอกสารที่โพสต์แล้ว';
      case 'NOT_POSTED':
        return isEnglish ? 'Only posted documents can be voided (delete drafts instead)' : 'ยกเลิกได้เฉพาะเอกสารที่โพสต์แล้ว (เอกสารร่างให้ลบแทน)';
      case 'PERIOD_CLOSED':
        return isEnglish ? 'The accounting period of this document is closed' : 'งวดบัญชีของเอกสารนี้ปิดแล้ว';
      case 'APPLIED':
        return isEnglish ? 'This voucher has been replenished$ref' : 'ใบเบิกนี้ถูกนำไปเติมเงินสดย่อยแล้ว$ref';
      case 'CM_CLEARED':
        return isEnglish ? 'Bank item already cleared/reconciled$ref' : 'รายการรับ/จ่ายเงินผ่านธนาคารเคลียร์/กระทบยอดแล้ว$ref';
      default:
        return code;
    }
  }

  Future<void> _void() async {
    final isEnglish = _isEnglish;
    final reason = await showDocReasonDialog(
      context,
      isEnglish: isEnglish,
      title: isEnglish ? 'Confirm Void Document' : 'ยืนยันการยกเลิกเอกสาร',
      message: isEnglish
          ? 'A voided document cannot be restored.\n'
            'The original GL entry is kept and a reversing entry is posted today (the period must be open).\n'
            'If the original period is still open, consider "Reverse to Draft" instead.'
          : 'เอกสารที่ยกเลิกแล้วไม่สามารถกู้คืนได้\n'
            'รายการบัญชีเดิมยังอยู่ ระบบจะลงรายการกลับรายการ ณ วันนี้ (งวดต้องเปิดอยู่)\n'
            'ถ้างวดของเอกสารยังเปิดอยู่ ควรใช้ "ถอยเป็นร่าง" แทน',
      confirmLabel: isEnglish ? 'Confirm Void' : 'ยืนยัน Void',
      confirmColor: Colors.red[700]!,
    );
    if (reason == null) return;
    setState(() => _isLoading = true);
    try {
      await _service.voidTransaction(_transactionId, reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Document voided successfully' : 'ยกเลิกเอกสารเรียบร้อย')));
        widget.onSaveSuccess();
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish ? 'Void failed: $msg' : 'ยกเลิกไม่สำเร็จ: $msg'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ส่งขออนุมัติ (20/30/40/50) — เอกสารต้องบันทึกร่างไว้ก่อน แก้ไขไม่ได้ระหว่างรออนุมัติ
  Future<void> _submitForApproval() async {
    final isEnglish = _isEnglish;
    final menuId = MenuScope.of(context)?.id;
    if (menuId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish ? 'Cannot determine current menu' : 'ไม่สามารถระบุเมนูปัจจุบันได้'), backgroundColor: Colors.red));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEnglish ? 'Confirm Submit for Approval' : 'ยืนยันการส่งขออนุมัติ'),
        content: Text(isEnglish
            ? 'Submit $_docNo for approval?\nThe document cannot be edited while awaiting approval.'
            : 'ส่งขออนุมัติ $_docNo?\nระหว่างรออนุมัติจะแก้ไขเอกสารไม่ได้'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEnglish ? 'Submit' : 'ส่งขออนุมัติ')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _isLoading = true);
    try {
      await _service.submitTransaction(_transactionId, menuId: menuId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish ? 'Submitted for approval' : 'ส่งขออนุมัติเรียบร้อย')));
        widget.onSaveSuccess();
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish ? 'Submit failed: $msg' : 'ส่งขออนุมัติไม่สำเร็จ: $msg'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Post เอกสารที่อนุมัติแล้ว — ใช้ข้อมูลที่บันทึกไว้ (ไม่ส่งข้อมูลจากหน้าจอ)
  Future<void> _postApproved() async {
    final isEnglish = _isEnglish;
    if (!(await CmPeriodService.canPost(context, _docDate))) return;
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEnglish ? 'Confirm Post' : 'ยืนยันการ Post'),
        content: Text(isEnglish ? 'Post $_docNo?' : 'Post เอกสาร $_docNo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEnglish ? 'Post' : 'Post')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _isLoading = true);
    try {
      await _service.postTransaction(_transactionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish ? 'Posted successfully' : 'Post เรียบร้อย')));
        widget.onSaveSuccess();
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish ? 'Post failed: $msg' : 'Post ไม่สำเร็จ: $msg'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reverse() async {
    final isEnglish = _isEnglish;
    final awaiting = _status == 'Submitted' || _status == 'Approved';
    final reason = await showDocReasonDialog(
      context,
      isEnglish: isEnglish,
      title: isEnglish ? 'Reverse to Draft' : 'ถอยเอกสารกลับเป็นร่าง',
      message: awaiting
          ? (isEnglish
              ? 'The approval request is withdrawn and the document returns to Draft.\nIt must be submitted for approval again.'
              : 'ระบบจะถอนคำขออนุมัติและเอกสารกลับเป็นร่าง\nต้องส่งขออนุมัติใหม่ก่อน Post')
          : isEnglish
          ? 'The GL entry is removed and the document returns to Draft.\n'
            'Edit it and post again with the same document no. $_docNo (and the same GL entry no.)'
          : 'ระบบจะลบรายการบัญชีออกและเอกสารกลับเป็นร่าง\n'
            'แก้ไขแล้วโพสต์ใหม่ได้ด้วยเลขที่เดิม $_docNo (เลขที่รายการบัญชีเดิม)',
      confirmLabel: isEnglish ? 'Reverse to Draft' : 'ถอยเป็นร่าง',
      confirmColor: Colors.orange[800]!,
    );
    if (reason == null) return;
    setState(() => _isLoading = true);
    try {
      await _service.reverseTransaction(_transactionId, reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish ? 'Reversed to draft' : 'ถอยเป็นร่างเรียบร้อย')));
        widget.onSaveSuccess();
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish ? 'Reverse failed: $msg' : 'ถอยไม่สำเร็จ: $msg'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final isEnglish = _isEnglish;
    final reason = await showDocReasonDialog(
      context,
      isEnglish: isEnglish,
      title: isEnglish ? 'Delete Draft' : 'ลบ Draft',
      message: isEnglish
          ? 'Delete document $_docNo?\nThe document is kept for audit but cannot be used again.'
          : 'ต้องการลบเอกสาร $_docNo ใช่หรือไม่?\nระบบจะเก็บเอกสารไว้เพื่อตรวจสอบ แต่นำกลับมาใช้ต่อไม่ได้',
      confirmLabel: isEnglish ? 'Delete' : 'ลบ',
    );
    if (reason == null) return;
    try {
      await _service.deleteTransaction(_transactionId, reason);
      if (mounted) widget.onSaveSuccess();
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish ? 'Delete failed: $msg' : 'ลบไม่สำเร็จ: $msg'), backgroundColor: Colors.red));
      }
    }
  }

  // ── รูปแบบช่อง (user design 2026-11-23 — เหมือนหน้ารายละเอียด IM / GL) ──────────────────────────
  // หัวเอกสาร: กรอบ 40 / ตัวอักษร 13 / ป้ายลอย 12; ตาราง: กรอบ 36 / ตัวอักษร 13
  // สีช่อง: ขาว = กรอกเอง, ฟ้า = ระบบเติมให้ (แก้ได้), เทา = อ่านอย่างเดียว
  static const _gDoc = Color(0xFF1E5AA8);
  static const _gParty = Color(0xFF1F7A4D);
  static const _gFin = Color(0xFFB45309);
  static const _gMore = Color(0xFF5B6B7C);
  static const _hAuto = Color(0xFFE3EEFA);
  static const _hRo = Color(0xFFEEF0F2);
  static const _errRed = Color(0xFFC62828);
  static const _ink2 = Color(0xFF4A5562);
  static const double _hFieldH = 40;
  static const double _cellH = 36;
  static const _numStyle = TextStyle(fontSize: 13, fontFeatures: [FontFeature.tabularFigures()]);
  static const _calIcon = Icon(Icons.calendar_today, size: 16, color: Color(0xFF0F6E6E));
  static const _searchIcon = Icon(Icons.search, size: 18, color: Color(0xFF0F6E6E));

  // ไม่ dense (กรอบขั้นต่ำ 48) + จำกัดความสูง → กรอบเท่ากันทุกช่อง; ข้อความผิดพลาดซ่อน (กรอบแดงแทน)
  InputDecoration _hDec(String label, {bool req = false, bool auto = false, bool forcedReadOnly = false, Widget? suffixIcon}) {
    final ro = _isReadOnly || forcedReadOnly;
    return InputDecoration(
      label: req
          ? Text.rich(TextSpan(text: label, children: const [TextSpan(text: ' *', style: TextStyle(color: _errRed))]))
          : Text(label),
      border: const OutlineInputBorder(),
      isDense: false,
      constraints: const BoxConstraints.tightFor(height: _hFieldH),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      suffixIcon: suffixIcon,
      suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 24, maxHeight: 24),
      filled: ro || auto,
      fillColor: ro ? _hRo : _hAuto,
      errorStyle: const TextStyle(height: 0, fontSize: 0),
    );
  }

  // ช่องในตาราง: กรอบ 36
  InputDecoration _cDec({Color? fill, bool err = false, String? hint}) => InputDecoration(
        isDense: false,
        constraints: const BoxConstraints.tightFor(height: _cellH),
        contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        border: const OutlineInputBorder(),
        enabledBorder: err ? const OutlineInputBorder(borderSide: BorderSide(color: _errRed, width: 1.4)) : null,
        filled: fill != null,
        fillColor: fill,
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
      );

  // ช่องแสดงค่า (อ่านอย่างเดียว / คำนวณ) ขนาดเท่าช่องกรอกในตาราง
  Widget _cBox(String text, {bool right = true, bool bold = false, Color? fill, Color? color, String? tip}) {
    final f = fill ?? _hRo;
    final box = Container(
      height: _cellH,
      alignment: right ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: f,
        border: Border.all(color: f == _hAuto ? const Color(0xFF8FB0D6) : const Color(0xFFC3C9D0)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _numStyle.copyWith(fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color ?? (f == _hRo ? _ink2 : Colors.black87))),
    );
    return tip == null ? box : Tooltip(message: tip, child: box);
  }

  Widget _chip(String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg), overflow: TextOverflow.ellipsis),
      );

  Widget _groupLabel(int no, String title, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9)),
          child: Text('$no', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 6),
        Flexible(child: Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
      ]);

  // การ์ดมาตรฐาน: หัวการ์ด 16 ตัวหนา + ชิป + ปุ่มด้านขวา
  Widget _card(String title, List<Widget> children, {List<Widget> chips = const [], List<Widget> actions = const []}) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ...chips,
                ]),
              ),
              for (final a in actions) ...[const SizedBox(width: 8), a],
            ]),
            const SizedBox(height: 10),
            ...children,
          ]),
        ),
      );

  Widget _addButton(String label, VoidCallback? onPressed) => OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          foregroundColor: const Color(0xFF0F6E6E),
          side: const BorderSide(color: Color(0xFF0F6E6E)),
        ),
        icon: const Icon(Icons.add, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        onPressed: onPressed,
      );

  // ตารางแบบการ์ดรายการสินค้า: แถบสีกลุ่มเหนือหัวคอลัมน์ + หัวคอลัมน์ 12 ตัวหนา + แถว (ช่อง 36)
  // cols: (หัวคอลัมน์, กว้าง, กลุ่ม, ชิดขวา) — กว้าง 0 = ยืดตามพื้นที่ที่เหลือ; rows: เซลล์ต่อแถว; footer: เซลล์แถวรวม (null = ไม่มี)
  Widget _gridTable({
    required List<(String, double, int, bool)> cols,
    required String Function(int group) groupTitle,
    required List<List<Widget>> rows,
    List<Widget>? footer,
    Widget? empty,
  }) {
    const gap = 6.0;
    return LayoutBuilder(builder: (context, cons) {
      final fixed = cols.fold<double>(0, (s, c) => s + c.$2) + gap * (cols.length - 1);
      final flexN = cols.where((c) => c.$2 == 0).length;
      final free = cons.maxWidth - fixed;
      final flexW = flexN == 0 ? 0.0 : (free / flexN > 160 ? free / flexN : 160.0);
      final tableW = fixed + flexW * flexN;
      double w((String, double, int, bool) c) => c.$2 == 0 ? flexW : c.$2;
      Widget cells(List<Widget> ws) => Row(children: [
            for (var i = 0; i < cols.length; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              SizedBox(
                width: w(cols[i]),
                child: Align(alignment: cols[i].$4 ? Alignment.centerRight : Alignment.centerLeft, child: i < ws.length ? ws[i] : null),
              ),
            ],
          ]);
      Color gc(int g) => g == 1 ? _gDoc : g == 2 ? _gParty : g == 3 ? _gFin : _gMore;
      final groupRow = <Widget>[];
      var i = 0;
      while (i < cols.length) {
        var j = i;
        var span = w(cols[i]);
        while (j + 1 < cols.length && cols[j + 1].$3 == cols[i].$3) {
          j++;
          span += gap + w(cols[j]);
        }
        if (i > 0) groupRow.add(const SizedBox(width: gap));
        final g = cols[i].$3;
        groupRow.add(SizedBox(
          width: span,
          child: g == 0
              ? null
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(height: 3, decoration: BoxDecoration(color: gc(g), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 3),
                  _groupLabel(g, groupTitle(g), gc(g)),
                ]),
        ));
        i = j + 1;
      }
      const hd = TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _ink2);
      Widget head((String, double, int, bool) c) {
        final req = c.$1.endsWith(' *');
        final t = req ? c.$1.substring(0, c.$1.length - 2) : c.$1;
        return Tooltip(
          message: t,
          child: Text.rich(
            TextSpan(text: t, children: [if (req) const TextSpan(text: ' *', style: TextStyle(color: _errRed))]),
            style: hd,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: c.$4 ? TextAlign.right : TextAlign.left,
          ),
        );
      }

      final table = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (cols.any((c) => c.$3 != 0)) Row(crossAxisAlignment: CrossAxisAlignment.start, children: groupRow),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFDDE3EA)))),
          child: cells([for (final c in cols) head(c)]),
        ),
        if (rows.isEmpty && empty != null) Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Center(child: empty)),
        for (final r in rows)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEF1F4)))),
            child: r.length == 1 && cols.length > 1
                ? Padding(
                    padding: EdgeInsets.only(left: w(cols[0]) + gap),
                    child: SizedBox(width: tableW - w(cols[0]) - gap, child: r[0]))
                : cells(r),
          ),
        if (footer != null && rows.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(color: Color(0xFFF6F8FA), border: Border(top: BorderSide(color: Color(0xFFDDE3EA)))),
            child: cells(footer),
          ),
      ]);
      if (tableW <= cons.maxWidth + 0.5) return table;
      return _HScrollBox(width: tableW, child: table);
    });
  }

  Widget _datePick(String label, DateTime? value, VoidCallback? onTap, {bool req = false, bool auto = false, bool forcedReadOnly = false, VoidCallback? onClear}) =>
      InkWell(
        onTap: _isReadOnly || forcedReadOnly ? null : onTap,
        child: InputDecorator(
          decoration: _hDec(label, req: req, auto: auto, forcedReadOnly: forcedReadOnly,
              suffixIcon: _isReadOnly || forcedReadOnly ? null : _calIcon),
          child: Row(children: [
            Expanded(child: Text(value != null ? _dateFmt.format(value) : '—', maxLines: 1)),
            if (!_isReadOnly && !forcedReadOnly && value != null && onClear != null)
              InkWell(onTap: onClear, child: const Icon(Icons.clear, size: 14, color: Colors.grey)),
          ]),
        ),
      );

  // 4 กลุ่มเรียงตามความกว้าง: จอกว้างแถวเดียว / จอกลาง 2×2 / จอแคบเรียงลง
  Widget _groupLayout(List<Widget> groups, List<int> flexes) => LayoutBuilder(builder: (context, c) {
        Widget row(List<(Widget, int)> items) => IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(flex: items[i].$2, child: items[i].$1),
                ],
              ]),
            );
        if (c.maxWidth >= 1150) return row([for (var i = 0; i < groups.length; i++) (groups[i], flexes[i])]);
        if (c.maxWidth >= 640) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < groups.length; i += 2) ...[
              if (i > 0) const SizedBox(height: 10),
              i + 1 < groups.length ? row([(groups[i], 1), (groups[i + 1], 1)]) : groups[i],
            ],
          ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < groups.length; i++) ...[if (i > 0) const SizedBox(height: 10), groups[i]],
        ]);
      });

  Widget _hRow(List<Widget> children) => Row(children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: children[i])],
      ]);

  Widget _cellField(TextEditingController c,
          {bool numeric = true, String? allow, bool bold = false, Color? color, ValueChanged<String>? onChanged, bool forcedReadOnly = false}) =>
      TextFormField(
        controller: c,
        readOnly: _isReadOnly || forcedReadOnly,
        textAlign: numeric ? TextAlign.right : TextAlign.left,
        keyboardType: numeric ? TextInputType.number : null,
        inputFormatters: allow == null ? null : [FilteringTextInputFormatter.allow(RegExp(allow))],
        style: _numStyle.copyWith(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color ?? (_isReadOnly || forcedReadOnly ? _ink2 : Colors.black87)),
        decoration: _cDec(fill: _isReadOnly || forcedReadOnly ? _hRo : null),
        onChanged: onChanged,
      );

  Widget _footerAmount(double v) =>
      Padding(padding: const EdgeInsets.only(right: 7), child: Text(_fmt.format(v), style: _numStyle.copyWith(fontWeight: FontWeight.bold)));

  Widget _footerLabel(String t) => Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, softWrap: false, overflow: TextOverflow.visible));

  // ── ช่องรายละเอียดการชำระ (กรอบ 40) ─────────────────
  Widget _payField({
    required String label,
    required TextEditingController ctrl,
    String? hint,
    bool numeric = false,
    int? maxLength,
    bool req = false,
    void Function(String)? onChanged,
  }) {
    if (_isReadOnly) {
      return InputDecorator(
        decoration: _hDec(label),
        child: Text(ctrl.text.isEmpty ? '—' : ctrl.text, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: numeric ? TextAlign.right : TextAlign.left,
            style: numeric ? _numStyle : null),
      );
    }
    return TextFormField(
      controller: ctrl,
      decoration: _hDec(label, req: req).copyWith(hintText: hint),
      textAlign: numeric ? TextAlign.right : TextAlign.left,
      style: numeric ? _numStyle : null,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      inputFormatters: [
        if (numeric) FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
      ],
      onChanged: onChanged,
    );
  }

  Widget _sumRow(String label, double v, {bool line = false, bool neg = false, Color? color}) => Container(
        padding: EdgeInsets.only(top: line ? 7 : 3, bottom: 3),
        margin: EdgeInsets.only(top: line ? 4 : 0),
        decoration: line ? const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFDDE3EA)))) : null,
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: color ?? const Color(0xFF33404D)))),
          Text(_fmt.format(v), style: _numStyle.copyWith(fontWeight: FontWeight.w600, color: color ?? (neg ? _errRed : null))),
        ]),
      );


  @override
  Widget build(BuildContext context) {
    widget.actions?.scheduleRefresh();
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_isReadOnlyView) return _buildMirrorView();
    // การ์ดข้อมูลเอกสาร fix ด้านบน (สูงไม่เกิน 60% แล้วเลื่อนในการ์ด) — การ์ดอื่นเลื่อนด้านล่าง (แบบเดียวกับ IM / GL / AR / AP)
    return Form(
      key: _formKey,
      child: docListTheme(context, LayoutBuilder(builder: (context, box) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: box.maxHeight.isFinite ? box.maxHeight * 0.6 : double.infinity),
            child: SingleChildScrollView(child: _buildHeaderSection()),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_approvals.isNotEmpty) ...[
                  DocApprovalPanel(
                    docNo: _docNo,
                    approvals: _approvals,
                    approvalMode: _approvalMode,
                    awaiting: _status == 'Submitted',
                    onApprove: (r) => _service.approveTransaction(_transactionId, remarks: r),
                    onReject: (r) => _service.rejectTransaction(_transactionId, remarks: r),
                    onDone: () async => widget.onSaveSuccess(),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_reverseHistory.isNotEmpty) ...[
                  DocReverseHistoryPanel(
                      history: _reverseHistory, isDeleted: _status == 'Deleted', isEnglish: isEnglish,
                      margin: EdgeInsets.zero),
                  const SizedBox(height: 12),
                ],
                if (_hasDetailRows) ...[_buildDetailSection(), const SizedBox(height: 16)],
                if (_hasApplySection) ...[_buildApplySection(), const SizedBox(height: 16)],
                if (_hasWhtSection) ...[_buildWhtSection(), const SizedBox(height: 16)],
                if (_hasPaymentSection) ...[_buildPaymentSection(), const SizedBox(height: 16)],
                if (!_isTransfer && _selectedDocType != null) ...[_buildTotalsSection(), const SizedBox(height: 16)],
                if (_selectedDocType != null) _buildGlSection(),
              ],
            ),
          ),
        ),
      ]))),
    );
  }

  // ── 15 (รายรับจาก AR) / 25 (รายจ่ายจาก AP): หน้าตาเดียวกัน อ่านอย่างเดียว + เปิดเอกสารต้นทาง + รายการบัญชีของเอกสารต้นทาง ──
  Widget _roField(String label, String value, {bool numeric = false, bool bold = false}) => InputDecorator(
        decoration: _hDec(label, forcedReadOnly: true),
        child: Text(value.isEmpty ? '—' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: numeric ? TextAlign.right : TextAlign.left,
            style: (numeric ? _numStyle : const TextStyle(fontSize: 13)).copyWith(fontWeight: bold ? FontWeight.bold : null)),
      );

  Future<void> _openSourceDoc() async {
    final r = _legacyRow;
    if (r == null || r.sourceId == null) return;
    final isEnglish = _isEnglish;
    await Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue[800],
          foregroundColor: Colors.white,
          title: Text('${r.isReceipt ? (isEnglish ? 'AR Transaction' : 'ธุรกรรมลูกหนี้') : (isEnglish ? 'AP Transaction' : 'ธุรกรรมเจ้าหนี้')}  >  ${r.sourceDocNo ?? ''}'),
        ),
        body: r.isReceipt
            ? ArTransactionDetailWidget(transactionId: r.sourceId, viewOnly: true, canDelete: false, onSaveSuccess: () {}, onCancel: () {})
            : ApTransactionDetailWidget(transactionId: r.sourceId, viewOnly: true, canDelete: false, onSaveSuccess: () {}, onCancel: () {}),
      ),
    ));
  }

  Widget _buildMirrorView() {
    final isEnglish = _isEnglish;
    final r = _legacyRow;
    if (r == null) return const SizedBox.shrink();
    final base = CurrencyService.baseCode;
    final isFc = r.currencyCode != base;
    final party = [r.partyCode ?? '', r.counterpartyName ?? ''].where((s) => s.isNotEmpty).join('  ');
    final src = r.isReceipt ? 'AR' : 'AP';
    final banner = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: _hAuto, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        const Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF1E4F8F)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
              isEnglish
                  ? 'Read-only — created automatically when $src document ${r.sourceDocNo ?? r.docNo ?? ''} was posted. Edit or void it on the source document.'
                  : 'อ่านอย่างเดียว · สร้างอัตโนมัติตอน Post เอกสาร $src ${r.sourceDocNo ?? r.docNo ?? ''} · แก้ไขหรือยกเลิกที่เอกสารต้นทาง',
              style: const TextStyle(fontSize: 13, color: Color(0xFF1E4F8F))),
        ),
        if (r.sourceId != null) ...[
          const SizedBox(width: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, foregroundColor: const Color(0xFF1E4F8F)),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(isEnglish ? 'Open source document' : 'เปิดเอกสารต้นทาง', style: const TextStyle(fontSize: 12)),
            onPressed: _openSourceDoc,
          ),
        ],
      ]),
    );

    final g1 = docFilterGroup(1, isEnglish ? 'Document' : 'เอกสาร', color: _gDoc, [
      _roField(isEnglish ? 'Document Type' : 'ประเภทเอกสาร',
          r.isReceipt ? '15 ${isEnglish ? 'Receipt from AR' : 'รายรับจาก AR'}' : '25 ${isEnglish ? 'Payment from AP' : 'รายจ่ายจาก AP'}'),
      _hRow([
        _roField(isEnglish ? 'Source Doc No.' : 'เลขที่เอกสารต้นทาง', r.sourceDocNo ?? r.docNo ?? ''),
        _roField(isEnglish ? 'Date' : 'วันที่', r.date != null ? _dateFmt.format(r.date!) : ''),
      ]),
    ]);
    final g2 = docFilterGroup(2, r.isReceipt ? (isEnglish ? 'Payer' : 'ผู้จ่ายเงิน') : (isEnglish ? 'Payee' : 'ผู้รับเงิน'), color: _gParty, [
      _roField(r.isReceipt ? (isEnglish ? 'Payer' : 'ผู้จ่ายเงิน') : (isEnglish ? 'Payee' : 'ผู้รับเงิน'), party),
      _roField(isEnglish ? 'Source Description' : 'คำอธิบายเอกสารต้นทาง', r.sourceDescription ?? ''),
    ]);
    final g3 = docFilterGroup(3, isEnglish ? 'Amount' : 'การเงิน', color: _gFin, [
      _hRow([
        _roField(isEnglish ? 'Currency' : 'สกุลเงิน', r.currencyCode),
        _roField(isEnglish ? 'Exchange Rate' : 'อัตราแลกเปลี่ยน', r.exchangeRate.toStringAsFixed(6), numeric: true),
      ]),
      _roField('${isEnglish ? 'Amount' : 'จำนวนเงิน'} ($base)', _fmt.format(r.amountLc), numeric: true, bold: true),
    ]);
    final g4 = docFilterGroup(4, isEnglish ? 'Status' : 'สถานะ', color: _gMore, [
      _roField(isEnglish ? 'Bank Item Status' : 'สถานะรายการ', r.status),
      _roField(isEnglish ? 'Clearing Note' : 'หมายเหตุการเคลียร์', r.clearingNote ?? ''),
    ]);

    final type = r.paymentMethodType ?? '';
    final payBlock = _payBlock(_methodColor(type), [
      _hRow([
        _roField(cmMethodTypeLabel(type, isEnglish), [r.paymentMethodCode ?? '', r.paymentMethodName ?? ''].where((s) => s.isNotEmpty).join('  ')),
        _roField(isEnglish ? 'Bank Account' : 'บัญชีธนาคาร', [r.bankAccountCode ?? '', r.bankAccountName ?? ''].where((s) => s.isNotEmpty).join('  ')),
        _roField('${isEnglish ? 'Amount' : 'จำนวนเงิน'} (${isFc ? r.currencyCode : base})', _fmt.format(isFc ? r.amountFc : r.amountLc), numeric: true, bold: true),
      ]),
      if ((r.checkNo ?? '').isNotEmpty || r.checkDate != null || (r.drawerBank ?? '').isNotEmpty)
        _hRow([
          _roField(isEnglish ? 'Check No.' : 'เลขที่เช็ค', r.checkNo ?? ''),
          _roField(isEnglish ? 'Check Date' : 'วันที่บนเช็ค', r.checkDate != null ? _dateFmt.format(r.checkDate!) : ''),
          _roField(isEnglish ? 'Drawer Bank' : 'ธนาคารผู้สั่งจ่าย', r.drawerBank ?? ''),
        ]),
    ]);

    return docListTheme(context, SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        banner,
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(isEnglish ? 'Document Header' : 'ข้อมูลเอกสาร', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if ((r.sourceDocNo ?? r.docNo ?? '').isNotEmpty)
                  Text(r.sourceDocNo ?? r.docNo!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F5C5C))),
                docStatusBadge(r.status),
              ]),
              const SizedBox(height: 10),
              _groupLayout([g1, g2, g3, g4], const [10, 12, 12, 12]),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        _card(r.isReceipt ? (isEnglish ? 'Money Received' : 'การรับเงิน') : (isEnglish ? 'Money Paid' : 'การจ่ายเงิน'),
            chips: [_chip(isEnglish ? 'Read-only' : 'อ่านอย่างเดียว', const Color(0xFF1E4F8F), _hAuto)], [payBlock]),
        if (_glEntryId != null) ...[const SizedBox(height: 16), _buildGlSection()],
      ]),
    ));
  }

  // สีแถบตามประเภทช่องทาง (เหมือน AR / AP)
  MaterialColor _methodColor(String type) =>
      {
        'CASH': Colors.green, 'CHECK': Colors.blue, 'TRANSFER': Colors.indigo,
        'CREDIT_CARD': Colors.purple, 'DEBIT_CARD': Colors.deepPurple,
        'QR_CODE': Colors.teal, 'MOBILE_BANKING': Colors.cyan,
        'BILL_OF_EXCHANGE': Colors.brown, 'OTHER': Colors.grey,
      }[type] ??
      Colors.grey;

  // กลุ่มย่อยของช่องทางรับ-จ่ายเงิน: แถบสีด้านบน + แถวช่อง 40
  Widget _payBlock(MaterialColor color, List<Widget> rows) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFBFCFD),
            border: Border.all(color: const Color(0xFFDDE3EA)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(height: 3, color: color.shade400),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (var i = 0; i < rows.length; i++) ...[if (i > 0) const SizedBox(height: 12), rows[i]],
              ]),
            ),
          ]),
        ),
      );

  // ── ปุ่มของเอกสาร (แสดงบน AppBar ของหน้าจอ แทนแถบปุ่มเดิม) — ปุ่ม "กลับ" ตัดออก (ใช้ลูกศรย้อนกลับ) ──
  List<DocBarAction> _barActions(bool en) {
    final a = <DocBarAction>[];
    if (_isReadOnlyView) return a;
    final isDraft = _status == 'Draft';
    final isPosted = _status == 'Posted';
    final canEditNow = !widget.viewOnly && isDraft;
    if (canEditNow && _transactionId != 0 && widget.canDelete) {
      a.add(DocBarAction.secondary(en ? 'Delete' : 'ลบ', _delete, DocBarColors.delete));
    }
    if ((_status == 'Submitted' || _status == 'Approved') && widget.canDelete && !widget.viewOnly) {
      a.add(DocBarAction.secondary(en ? 'Reverse to Draft' : 'ถอยเป็นร่าง', _reverse, DocBarColors.reverse));
    }
    if (isPosted && widget.canDelete && !widget.viewOnly) {
      final msg = _reverseBlockMessage(en);
      a.add(DocBarAction.secondary(en ? 'Reverse to Draft' : 'ถอยเป็นร่าง', msg == null ? _reverse : null, DocBarColors.reverse, tooltip: msg));
    }
    if (canEditNow) {
      a.add(DocBarAction.secondary(en ? 'Save Draft' : 'บันทึก Draft', () => _save('Draft'), DocBarColors.save));
      // 20/30/40/50 ต้องส่งขออนุมัติก่อน (บันทึกร่างก่อน) — Post ได้หลังอนุมัติแล้วเท่านั้น
      if (_requiresApproval && _transactionId != 0) {
        a.add(DocBarAction.primary(en ? 'Request Approval' : 'ขออนุมัติ', _submitForApproval, DocBarColors.submit));
      }
      if (!_requiresApproval) {
        a.add(DocBarAction.primary(en ? 'Post Document' : 'Post เอกสาร', () => _save('Post'), DocBarColors.post));
      }
    }
    if (_status == 'Approved' && !widget.viewOnly) {
      a.add(DocBarAction.primary(en ? 'Post Document' : 'Post เอกสาร', _postApproved, DocBarColors.post));
    }
    if (isPosted && widget.canDelete) {
      final msg = _voidBlockMessage(en);
      a.add(DocBarAction.primary(en ? 'Void' : 'ยกเลิก (Void)', msg == null ? _void : null, DocBarColors.voidBg, tooltip: msg));
    }
    return a;
  }

  @override
  Widget buildAppBarActions(BuildContext context, bool en) =>
      _isLoading ? const SizedBox.shrink() : buildDocBarActions(context, _barActions(en), isEnglish: en);

  // ── มีการแก้ไขค้าง — ข้อมูลที่จะบันทึกต่างจากตอนโหลดเสร็จ (เฉพาะร่างที่แก้ไขได้) ──
  String? _cleanFingerprint;

  String _formFingerprint() {
    if (_selectedDocType == null) return 'incomplete|${_amountCtrl.text}';
    try {
      final p = _savePayload();
      return docFingerprint([p.header, p.details, p.applies, p.payments, p.whts]);
    } catch (_) {
      return '';
    }
  }

  void _markClean() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cleanFingerprint = _formFingerprint();
    });
  }

  @override
  bool get isDirty {
    if (_isLoading || widget.viewOnly || _isReadOnlyView || _status != 'Draft') return false;
    return _cleanFingerprint != null && _cleanFingerprint != _formFingerprint();
  }

  // ── การ์ดข้อมูลเอกสาร: 4 กลุ่มสี (เหมือน IM / AR / AP) — กลุ่ม ② ③ เปลี่ยนตามประเภทเอกสาร ─────────────────────
  // ยอดคงเหลือของบัญชี ณ วันที่เอกสาร (ป้ายช่องบัญชีของเอกสารโอนเงิน 50)
  String _balKey(int id) => '$id@${DateFormat('yyyy-MM-dd').format(_docDate)}';
  void _ensureBalance(int? id) {
    if (id == null || _bankBalances.containsKey(_balKey(id))) return;
    final key = _balKey(id);
    _bankBalances[key] = null;
    _service.fetchBankBalance(id, DateFormat('yyyy-MM-dd').format(_docDate)).then((v) {
      if (mounted) setState(() => _bankBalances[key] = v);
    }).catchError((_) {});
  }

  // ช่องเลือกบัญชีธนาคาร/เงินสดย่อย (กรอบ 40) — แสดงรหัสตัวหนา + ชื่อ
  Widget _bankField(String label, int? value, String cmType, ValueChanged<int?> onChanged, {bool req = true, bool showBalance = false}) {
    final isEnglish = _isEnglish;
    final list = _bankAccounts.where((b) => b.cmType == cmType || b.id == value).toList();
    var text = label;
    if (showBalance && value != null) {
      _ensureBalance(value);
      final bal = _bankBalances[_balKey(value)];
      if (bal != null) text = '$label · ${isEnglish ? 'Bal.' : 'คงเหลือ'} ${_fmt.format(bal)}';
    }
    Widget item(CmBankAccount b) => Text.rich(
          TextSpan(children: [
            TextSpan(text: b.accountCode, style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: '  ${_isEnglish && (b.accountNameEn ?? '').isNotEmpty ? b.accountNameEn! : b.accountNameTh}', style: const TextStyle(color: _ink2)),
          ]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
    return DropdownButtonFormField<int?>(
      value: list.any((b) => b.id == value) ? value : null,
      isExpanded: true,
      isDense: true,
      decoration: _hDec(text, req: req),
      items: list.map((b) => DropdownMenuItem(value: b.id, child: item(b))).toList(),
      selectedItemBuilder: (_) => [for (final b in list) item(b)],
      onChanged: _isReadOnly ? null : onChanged,
      validator: (v) => req && v == null ? (isEnglish ? 'Required' : 'กรุณาเลือก') : null,
    );
  }

  Widget _plainField(String label, TextEditingController c, {bool req = false, bool forcedReadOnly = false, bool auto = false}) => TextFormField(
        controller: c,
        readOnly: _isReadOnly || forcedReadOnly,
        decoration: _hDec(label, req: req, forcedReadOnly: forcedReadOnly, auto: auto),
      );

  Widget _taxInvDateField(DateTime? value, ValueChanged<DateTime?> onPicked) {
    final isEnglish = _isEnglish;
    return InkWell(
      onTap: _isReadOnly
          ? null
          : () async {
              final d = await showDatePicker(context: context, initialDate: value ?? _docDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (d != null) onPicked(d);
            },
      child: InputDecorator(
        decoration: _hDec(isEnglish ? 'Tax Invoice Date' : 'วันที่ใบกำกับภาษี', auto: true, suffixIcon: _isReadOnly ? null : _calIcon),
        child: Row(children: [
          Expanded(
            child: Text(value != null ? _dateFmt.format(value) : (isEnglish ? '(document date)' : '(วันที่เอกสาร)'),
                maxLines: 1, style: TextStyle(color: value == null ? Colors.grey.shade600 : null)),
          ),
          if (!_isReadOnly && value != null) InkWell(onTap: () => onPicked(null), child: const Icon(Icons.clear, size: 14, color: Colors.grey)),
        ]),
      ),
    );
  }

  Widget _headerDimPicker(GlDimensionType dimType) {
    final values = _dimValues[dimType.typeCode] ?? [];
    final selectedId = _dimSelections[dimType.slotNo];
    GlDimensionValue? selectedVal;
    for (final v in values) {
      if (v.id == selectedId) selectedVal = v;
    }
    return GlDimensionPickerField(
      dimType: dimType,
      values: values,
      selected: selectedVal,
      readOnly: _isReadOnly,
      fontSize: 13,
      decoration: _hDec(_isEnglish && (dimType.nameEng ?? '').isNotEmpty ? dimType.nameEng! : dimType.nameThai),
      onSelected: (val) => setState(() {
        _dimSelections[dimType.slotNo] = val?.id;
        _dimNames[dimType.slotNo] = val?.valueNameThai;
      }),
    );
  }

  Widget _buildHeaderSection() {
    final isEnglish = _isEnglish;
    final auto = _selectedDocType?.isAutoNumbering == true;

    final titleRow = Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(
        child: Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(isEnglish ? 'Document Header' : 'ข้อมูลเอกสาร', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          if (_docNo.isNotEmpty && _docNo != 'AUTO')
            Text(_docNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F5C5C))),
          docStatusBadge(_status, label: cmTransactionStatusLabel(_status, isEnglish)),
          if (_status == 'Draft' && _requiresApproval)
            _chip(isEnglish ? 'Approval required before posting' : 'ต้องขออนุมัติก่อน Post', const Color(0xFF8A4B00), const Color(0xFFFFF0D9)),
        ]),
      ),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 10), foregroundColor: Colors.blueGrey.shade800),
        icon: Icon(_headerExpanded ? Icons.expand_less : Icons.expand_more, size: 18),
        label: Text(_headerExpanded ? (isEnglish ? 'Collapse' : 'ย่อ') : (isEnglish ? 'Expand' : 'ขยาย'), style: const TextStyle(fontSize: 12)),
        onPressed: () => setState(() => _headerExpanded = !_headerExpanded),
      ),
    ]);

    // ① เอกสาร
    final g1 = docFilterGroup(1, isEnglish ? 'Document' : 'เอกสาร', color: _gDoc, [
      DropdownButtonFormField<ModuleDocument>(
        value: _selectedDocType,
        isExpanded: true,
        isDense: true,
        decoration: _hDec(isEnglish ? 'Document Type' : 'ประเภทเอกสาร', req: true),
        items: _allowedDocTypes
            .map((d) => DropdownMenuItem(value: d, child: Text('${d.docCode} ${_docTypeLabel(d)}', overflow: TextOverflow.ellipsis)))
            .toList(),
        onChanged: _isReadOnly
            ? null
            : (v) {
                _resetForm();
                setState(() => _selectedDocType = v);
                _loadDocSetup();
              },
        validator: (v) => v == null ? (isEnglish ? 'Please select' : 'กรุณาเลือก') : null,
      ),
      _hRow([
        TextFormField(
          key: ValueKey('cm_docNo_${widget.resetKey}_$_transactionId'),
          initialValue: _docNo == 'AUTO' ? '' : _docNo,
          decoration: _hDec(isEnglish ? 'Doc No.' : 'เลขที่เอกสาร', req: !auto, auto: auto)
              .copyWith(hintText: auto ? (isEnglish ? 'Auto' : 'อัตโนมัติ') : null),
          readOnly: _isReadOnly || auto,
          onChanged: (v) => _docNo = v.isEmpty ? 'AUTO' : v,
        ),
        _datePick(isEnglish ? 'Doc Date' : 'วันที่เอกสาร', _docDate, _selectDate, req: true, auto: true),
      ]),
    ]);

    final refField = _plainField(isEnglish ? 'Reference No.' : 'เลขที่อ้างอิง', _refNoCtrl);

    // ② คู่ค้า / บัญชี — ตามประเภทเอกสาร
    final String g2Title;
    final List<Widget> g2Rows;
    if (_hasPartySection) {
      // ผู้รับเงิน (20) / ผู้จ่ายเงิน (10): ค้นหาจากผู้ขาย/ลูกค้า = แสดงอย่างเดียว, ไม่เลือก = พิมพ์เอง
      final fromMaster = _partySource != null;
      final partyLabel = _isReceipt ? (isEnglish ? 'Payer' : 'ผู้จ่ายเงิน') : (isEnglish ? 'Payee' : 'ผู้รับเงิน');
      final srcNote = !fromMaster
          ? ''
          : _partySource == 'AR'
              ? (isEnglish ? ' · customer ${_partyCode ?? ''}' : ' · จากลูกค้า ${_partyCode ?? ''}')
              : (isEnglish ? ' · vendor ${_partyCode ?? ''}' : ' · จากผู้ขาย ${_partyCode ?? ''}');
      g2Title = '$partyLabel / ${isEnglish ? 'Reference' : 'อ้างอิง'}';
      g2Rows = [
        TextFormField(
          controller: _counterpartyCtrl,
          readOnly: _isReadOnly || fromMaster,
          decoration: _hDec('$partyLabel$srcNote', forcedReadOnly: fromMaster).copyWith(
            suffixIcon: _isReadOnly
                ? null
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    if (fromMaster)
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF0F6E6E)),
                        tooltip: isEnglish ? 'Type manually' : 'พิมพ์เอง',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () => setState(() { _partySource = null; _partyId = null; _partyCode = null; }),
                      ),
                    IconButton(
                      icon: _searchIcon,
                      tooltip: _isReceipt ? (isEnglish ? 'Select customer' : 'ค้นหาจากลูกค้า') : (isEnglish ? 'Select vendor' : 'ค้นหาจากผู้ขาย'),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: _isReceipt ? _pickCustomer : _pickVendor,
                    ),
                  ]),
          ),
        ),
        _hRow([
          _plainField(isEnglish ? 'Tax ID' : 'เลขประจำตัวผู้เสียภาษี', _partyTaxIdCtrl, forcedReadOnly: fromMaster),
          _plainField(isEnglish ? 'Branch (00000=HQ)' : 'สาขา (00000=สนญ.)', _partyBranchCtrl, forcedReadOnly: fromMaster),
        ]),
        if (_isPayment)
          _hRow([
            DropdownButtonFormField<String?>(
              value: _partyType == 'individual' || _partyType == 'juristic' ? _partyType : null,
              isExpanded: true,
              isDense: true,
              decoration: _hDec(isEnglish ? 'Type (PND)' : 'ประเภท (ภ.ง.ด.)', forcedReadOnly: fromMaster),
              items: [
                DropdownMenuItem(value: 'individual', child: Text(isEnglish ? 'Individual (PND 3)' : 'บุคคลธรรมดา (ภ.ง.ด.3)', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'juristic', child: Text(isEnglish ? 'Juristic (PND 53)' : 'นิติบุคคล (ภ.ง.ด.53)', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: _isReadOnly || fromMaster ? null : (v) => setState(() => _partyType = v),
            ),
            refField,
          ])
        else
          refField,
        _plainField(isEnglish ? 'Address' : 'ที่อยู่', _partyAddressCtrl, forcedReadOnly: fromMaster),
      ];
    } else if (_hasPettyCashAccountField) {
      g2Title = isEnglish ? 'Petty Cash / Reference' : 'เงินสดย่อย / อ้างอิง';
      g2Rows = [
        _bankField(isEnglish ? 'Petty Cash Account' : 'บัญชีเงินสดย่อย', _bankAccountId, 'PETTY_CASH', (v) {
          setState(() { _bankAccountId = v; _fillBranchFromBank(v); });
          if (_isReplenishment && v != null) _loadOpenVouchers(v);
        }),
        refField,
      ];
    } else if (_hasTransferFields) {
      g2Title = isEnglish ? 'From / To Account' : 'บัญชีต้นทาง / ปลายทาง';
      g2Rows = [
        _bankField(isEnglish ? 'From Account' : 'บัญชีต้นทาง', _fromBankAccountId, 'BANK',
            (v) => setState(() { _fromBankAccountId = v; _fillBranchFromBank(v); }), showBalance: true),
        _bankField(isEnglish ? 'To Account' : 'บัญชีปลายทาง', _toBankAccountId, 'BANK',
            (v) => setState(() { _toBankAccountId = v; _fillBranchFromBank(v); }), showBalance: true),
        refField,
      ];
    } else {
      // ค่าธรรมเนียม (70) / ดอกเบี้ย (90)
      g2Title = _isBankCharge ? (isEnglish ? 'Bank Account / Tax Invoice' : 'บัญชีธนาคาร / ใบกำกับ') : (isEnglish ? 'Bank Account' : 'บัญชีธนาคาร');
      final acctField = DropdownButtonFormField<int?>(
        value: _glAccountId,
        isExpanded: true,
        isDense: true,
        // ไม่บังคับ — ว่างไว้จะใช้บัญชีจากการตั้งค่า (ดอกเบี้ยรับ → ช่องดอกเบี้ยรับ, ดอกเบี้ยจ่าย → ช่องดอกเบี้ยจ่าย)
        decoration: _hDec(isEnglish
            ? '${!_isInterest ? 'Expense Account' : _chargeType == 'INTEREST_INCOME' ? 'Interest Income Account' : 'Interest Expense Account'} (blank = setup)'
            : '${!_isInterest ? 'บัญชีค่าใช้จ่าย' : _chargeType == 'INTEREST_INCOME' ? 'บัญชีดอกเบี้ยรับ' : 'บัญชีดอกเบี้ยจ่าย'} (ว่าง = ตามการตั้งค่า)'),
        items: [
          DropdownMenuItem<int?>(value: null, child: Text(isEnglish ? '— Per setup —' : '— ตามการตั้งค่า —', style: TextStyle(color: Colors.grey.shade600))),
          ..._accounts.map((a) => DropdownMenuItem<int?>(value: a.id, child: Text('${a.accountCode} ${_acctLabel(a)}', overflow: TextOverflow.ellipsis))),
        ],
        onChanged: _isReadOnly ? null : (v) => setState(() => _glAccountId = v),
      );
      final bankHasTax = _bankHasTaxId;
      g2Rows = [
        _bankField(isEnglish ? 'Bank Account' : 'บัญชีธนาคาร', _bankAccountId, 'BANK', (v) => setState(() {
              _bankAccountId = v;
              _fillBranchFromBank(v);
              if (_isBankCharge && _chargeVatType != 'NOVAT') _fillBankSeller();
            })),
        if (_isInterest) ...[
          acctField,
          _hRow([
            DropdownButtonFormField<String?>(
              value: _chargeType,
              isExpanded: true,
              isDense: true,
              decoration: _hDec(isEnglish ? 'Direction' : 'ประเภทดอกเบี้ย', req: true),
              items: [
                DropdownMenuItem(value: 'INTEREST_INCOME', child: Text(isEnglish ? 'Interest Income' : 'ดอกเบี้ยรับ')),
                DropdownMenuItem(value: 'INTEREST_EXPENSE', child: Text(isEnglish ? 'Interest Expense' : 'ดอกเบี้ยจ่าย')),
              ],
              onChanged: _isReadOnly ? null : (v) { setState(() => _chargeType = v); _recalcTotals(); },
              validator: (v) => v == null ? (isEnglish ? 'Required' : 'กรุณาเลือก') : null,
            ),
            refField,
          ]),
        ] else ...[
          _hRow([acctField, refField]),
          if (_chargeVatType != 'NOVAT') ...[
            // ผู้ขาย = ธนาคารของบัญชีที่เลือก (ธนาคารมีเลขผู้เสียภาษีแล้ว = แสดงอย่างเดียว)
            _plainField(isEnglish ? 'Bank (seller)' : 'ชื่อธนาคาร (ผู้ขาย)', _counterpartyCtrl, req: true, forcedReadOnly: bankHasTax),
            _hRow([
              _plainField(isEnglish ? 'Tax ID' : 'เลขผู้เสียภาษี', _partyTaxIdCtrl, req: true, forcedReadOnly: bankHasTax),
              _plainField(isEnglish ? 'Branch' : 'สาขา', _partyBranchCtrl, forcedReadOnly: bankHasTax),
            ]),
            _hRow([
              _plainField(isEnglish ? 'Tax Invoice No.' : 'เลขที่ใบกำกับ', _taxInvNoCtrl, req: true),
              _taxInvDateField(_taxInvDate, (d) => setState(() => _taxInvDate = d)),
            ]),
          ],
        ],
      ];
    }
    final g2 = docFilterGroup(2, g2Title, color: _gParty, g2Rows);

    // ③ การเงิน
    final isBase = _selectedCurrency?.baseCurrencyFlag ?? true;
    final amountField = TextFormField(
      controller: _amountCtrl,
      readOnly: _isReadOnly,
      textAlign: TextAlign.right,
      style: _numStyle.copyWith(fontWeight: FontWeight.bold),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: _hDec(_isTransfer ? (isEnglish ? 'Transfer Amount' : 'จำนวนเงินโอน') : (isEnglish ? 'Amount' : 'จำนวนเงิน'), req: true),
      onChanged: (v) {
        // ดอกเบี้ยรับ: ภาษีถูกหักตามอัตราที่กรอกไว้
        final r = double.tryParse(_intWhtRateCtrl.text);
        if (_isInterestIncome && r != null) _intWhtCtrl.text = ((double.tryParse(v) ?? 0) * r / 100).toStringAsFixed(2);
        _recalcTotals();
      },
      validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? (isEnglish ? 'Enter an amount' : 'กรุณาระบุจำนวนเงิน') : null,
    );
    final g3 = docFilterGroup(
        3,
        _isPayment
            ? (isEnglish ? 'Currency / Tax Invoice' : 'การเงิน / ใบกำกับภาษี')
            : _hasBankChargeFields
                ? (isEnglish ? 'Amount / VAT' : 'จำนวนเงิน / VAT')
                : (isEnglish ? 'Currency' : 'การเงิน'),
        color: _gFin,
        [
          _hRow([
            DropdownButtonFormField<Currency>(
              value: _selectedCurrency,
              isExpanded: true,
              isDense: true,
              decoration: _hDec(isEnglish ? 'Currency' : 'สกุลเงิน', auto: true),
              items: _currencies
                  .map((c) => DropdownMenuItem(value: c, child: Text('${c.currencyCode} - ${_currencyLabel(c)}', overflow: TextOverflow.ellipsis)))
                  .toList(),
              selectedItemBuilder: (_) => [for (final c in _currencies) Text(c.currencyCode, overflow: TextOverflow.ellipsis)],
              onChanged: _isReadOnly
                  ? null
                  : (v) {
                      setState(() { _selectedCurrency = v; _exchangeRate = v?.baseRate ?? 1.0; });
                      _recalcTotals();
                    },
            ),
            TextFormField(
              key: ValueKey('cm_rate_${widget.resetKey}_${_transactionId}_${_selectedCurrency?.currencyCode}'),
              initialValue: _exchangeRate.toStringAsFixed(6),
              textAlign: TextAlign.right,
              style: _numStyle,
              decoration: _hDec(isEnglish ? 'Exchange Rate' : 'อัตราแลกเปลี่ยน', auto: true, forcedReadOnly: isBase),
              keyboardType: TextInputType.number,
              readOnly: _isReadOnly || isBase,
              onChanged: (v) { _exchangeRate = double.tryParse(v) ?? 1.0; _recalcTotals(); },
            ),
          ]),
          if (_isPayment)
            _hRow([
              _plainField(isEnglish ? 'Vendor Tax Invoice No.' : 'เลขที่ใบกำกับภาษี (ผู้ขาย)', _taxInvNoCtrl),
              _taxInvDateField(_taxInvDate, (d) => setState(() => _taxInvDate = d)),
            ]),
          if (_hasSingleAmountField) amountField,
          if (_isBankCharge)
            _hRow([
              DropdownButtonFormField<String>(
                value: _vatRates.any((v) => v.vatCode == _chargeVatType) || _chargeVatType == 'NOVAT' ? _chargeVatType : 'NOVAT',
                isExpanded: true,
                isDense: true,
                decoration: _hDec(isEnglish ? 'VAT on the charge' : 'VAT ของค่าธรรมเนียม'),
                items: [
                  if (!_vatRates.any((v) => v.vatCode == 'NOVAT')) DropdownMenuItem(value: 'NOVAT', child: Text(isEnglish ? 'No VAT' : 'ไม่มี VAT')),
                  ..._vatRates.map((v) => DropdownMenuItem(
                      value: v.vatCode, child: Text('${v.vatCode} ${v.rate.toStringAsFixed(v.rate % 1 == 0 ? 0 : 2)}%', overflow: TextOverflow.ellipsis))),
                ],
                onChanged: _isReadOnly
                    ? null
                    : (code) {
                        final vr = _vatRates.cast<VatRate?>().firstWhere((v) => v?.vatCode == code, orElse: () => null);
                        setState(() {
                          _chargeVatType = code ?? 'NOVAT';
                          _chargeVatRate = _chargeVatType == 'NOVAT' ? 0 : (vr?.rate ?? 0);
                          if (_chargeVatType != 'NOVAT') _fillBankSeller();
                        });
                        _recalcTotals();
                      },
              ),
              _vatIncludedBox(),
            ]),
          if (_isInterestIncome)
            _hRow([
              TextFormField(
                controller: _intWhtRateCtrl,
                readOnly: _isReadOnly,
                textAlign: TextAlign.right,
                style: _numStyle,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: _hDec(isEnglish ? 'WHT rate (%)' : 'อัตราภาษีถูกหัก (%)'),
                onChanged: (v) {
                  final amt = double.tryParse(_amountCtrl.text) ?? 0;
                  _intWhtCtrl.text = (amt * (double.tryParse(v) ?? 0) / 100).toStringAsFixed(2);
                  _recalcTotals();
                },
              ),
              TextFormField(
                controller: _intWhtCtrl,
                readOnly: _isReadOnly,
                textAlign: TextAlign.right,
                style: _numStyle,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: _hDec(isEnglish ? 'WHT deducted by bank' : 'ภาษีถูกหัก ณ ที่จ่าย', auto: true),
                onChanged: (_) => _recalcTotals(),
              ),
            ]),
        ]);

    // ④ เพิ่มเติม
    final g4 = docFilterGroup(4, isEnglish ? 'More' : 'เพิ่มเติม', color: _gMore, [
      InkWell(
        onTap: _isReadOnly
            ? null
            : () async {
                final r = await showUserBranchPicker(context, branches: _branches, selectedId: _branchId, isEnglish: isEnglish);
                if (r != null && mounted) setState(() => _branchId = r.$2?.id);
              },
        child: InputDecorator(
          decoration: _hDec(isEnglish ? 'Branch' : 'สาขา', auto: true, suffixIcon: _isReadOnly ? null : _searchIcon),
          child: Text(
              _branchId == null ? (isEnglish ? '— Not specified —' : '— ไม่ระบุ —') : branchLabel(findBranch(_branches, _branchId), isEnglish),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _branchId == null ? Colors.grey.shade600 : null)),
        ),
      ),
      // มิติหัวเอกสาร — แถวละ 2 ช่อง
      for (var i = 0; i < _dimTypes.length; i += 2)
        _hRow([
          for (final t in _dimTypes.skip(i).take(2)) _headerDimPicker(t),
          if (i + 1 >= _dimTypes.length) const SizedBox.shrink(),
        ]),
      _plainField(isEnglish ? 'Description' : 'คำอธิบาย', _descCtrl),
    ]);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          titleRow,
          const SizedBox(height: 10),
          if (_headerExpanded) _groupLayout([g1, g2, g3, g4], const [10, 12, 12, 12]) else _headerSummary(isEnglish),
        ]),
      ),
    );
  }

  // ช่องติ๊ก "ราคารวม VAT" ขนาดเท่าช่อง 40
  Widget _vatIncludedBox({double height = _hFieldH}) => InkWell(
        onTap: _isReadOnly ? null : () { setState(() => _priceIncludesVat = !_priceIncludesVat); _recalcTotals(); },
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFDDE3EA)), borderRadius: BorderRadius.circular(4), color: Colors.white),
          child: Row(children: [
            Checkbox(
              value: _priceIncludesVat,
              visualDensity: VisualDensity.compact,
              onChanged: _isReadOnly ? null : (v) { setState(() => _priceIncludesVat = v ?? false); _recalcTotals(); },
            ),
            Flexible(child: Text(_isEnglish ? 'Amount includes VAT' : 'จำนวนเงินรวม VAT', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
          ]),
        ),
      );

  // แถบสรุปตอนย่อการ์ด — จุดสีบอกกลุ่มที่มา
  Widget _headerSummary(bool isEnglish) {
    Widget item(Color c, String label, String value) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 6),
          Text('$label ', style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700)),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 360), child: Text(value, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
        ]);
    String bank(int? id) {
      final b = _bankAccounts.where((x) => x.id == id).firstOrNull;
      return b == null ? '' : _bankAcctLabel(b);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFF6F8FA), borderRadius: BorderRadius.circular(4)),
      child: Wrap(spacing: 22, runSpacing: 6, children: [
        if (_selectedDocType != null) item(_gDoc, isEnglish ? 'Type' : 'ประเภท', '${_selectedDocType!.docCode} ${_docTypeLabel(_selectedDocType!)}'),
        item(_gDoc, isEnglish ? 'Date' : 'วันที่', _dateFmt.format(_docDate)),
        if (_hasPartySection && _counterpartyCtrl.text.trim().isNotEmpty)
          item(_gParty, _isReceipt ? (isEnglish ? 'Payer' : 'ผู้จ่ายเงิน') : (isEnglish ? 'Payee' : 'ผู้รับเงิน'), _counterpartyCtrl.text.trim()),
        if (_hasTransferFields && _fromBankAccountId != null) item(_gParty, isEnglish ? 'From' : 'ต้นทาง', bank(_fromBankAccountId)),
        if (_hasTransferFields && _toBankAccountId != null) item(_gParty, isEnglish ? 'To' : 'ปลายทาง', bank(_toBankAccountId)),
        if ((_hasPettyCashAccountField || _hasBankChargeFields) && _bankAccountId != null) item(_gParty, isEnglish ? 'Account' : 'บัญชี', bank(_bankAccountId)),
        if (_refNoCtrl.text.trim().isNotEmpty) item(_gParty, isEnglish ? 'Ref' : 'อ้างอิง', _refNoCtrl.text.trim()),
        if (_selectedCurrency != null)
          item(_gFin, isEnglish ? 'Currency' : 'สกุลเงิน',
              _selectedCurrency!.baseCurrencyFlag ? _selectedCurrency!.currencyCode : '${_selectedCurrency!.currencyCode} @ ${_exchangeRate.toStringAsFixed(4)}'),
        if (_hasSingleAmountField) item(_gFin, isEnglish ? 'Amount' : 'จำนวนเงิน', _amountCtrl.text),
        if (_descCtrl.text.trim().isNotEmpty) item(_gMore, isEnglish ? 'Description' : 'คำอธิบาย', _descCtrl.text.trim()),
      ]),
    );
  }

  // ── ผู้รับเงิน (20): เลือกจากผู้ขาย AP = แสดงอย่างเดียว, ไม่เลือก = พิมพ์เอง ─────────────────────────
  String _vendorLabel(ApVendor v) =>
      _isEnglish && (v.vendorNameEn ?? '').isNotEmpty ? v.vendorNameEn! : v.vendorNameTh;

  Future<void> _pickVendor() async {
    final isEnglish = _isEnglish;
    final searchCtrl = TextEditingController();
    List<ApVendor> filtered = List.from(_vendors);
    final picked = await showDialog<ApVendor>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        void doFilter() {
          final q = searchCtrl.text.toUpperCase();
          setS(() => filtered = q.isEmpty
              ? _vendors
              : _vendors.where((v) =>
                  v.vendorCode.toUpperCase().contains(q) ||
                  v.vendorNameTh.toUpperCase().contains(q) ||
                  (v.vendorNameEn ?? '').toUpperCase().contains(q) ||
                  (v.taxId ?? '').contains(q)).toList());
        }
        return Dialog(
          child: SizedBox(
            width: 600, height: 500,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(labelText: isEnglish ? 'Search Vendor' : 'ค้นหาผู้ขาย', prefixIcon: const Icon(Icons.search), border: const OutlineInputBorder()),
                  onChanged: (_) => doFilter(),
                  autofocus: true,
                ),
              ),
              Expanded(child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final v = filtered[i];
                  return ListTile(
                    dense: true,
                    title: Text('${v.vendorCode} - ${_vendorLabel(v)}', style: const TextStyle(fontSize: 13)),
                    subtitle: v.taxId != null ? Text(v.taxId!, style: const TextStyle(fontSize: 11)) : null,
                    onTap: () => Navigator.pop(ctx, v),
                  );
                },
              )),
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
            ]),
          ),
        );
      }),
    );
    searchCtrl.dispose();
    if (picked == null || picked.id == null) return;
    // ดึงที่อยู่จากข้อมูลผู้ขาย (backend ดึงซ้ำตอนบันทึก — ค่าที่แสดงนี้เพื่อให้เห็นก่อนบันทึก)
    ApVendor full = picked;
    try { full = await ApVendorService().fetchRow(picked.id!); } catch (_) {}
    final addr = full.addresses.isEmpty
        ? null
        : (full.addresses.where((a) => a.addressType == 'billing' && a.isDefault).firstOrNull ??
            full.addresses.where((a) => a.addressType == 'billing').firstOrNull ?? full.addresses.first);
    if (!mounted) return;
    setState(() {
      _partySource = 'AP';
      _partyId = full.id;
      _partyCode = full.vendorCode;
      _partyType = full.vendorType;
      _counterpartyCtrl.text = full.vendorNameTh;
      _partyTaxIdCtrl.text = full.taxId ?? '';
      _partyBranchCtrl.text = full.taxBranchCode ?? '';
      _partyAddressCtrl.text = addr == null
          ? ''
          : [addr.addressNo, addr.addressBuildingVillage, addr.addressAlley, addr.addressRoad,
             addr.addressSubDistrict, addr.addressDistrict, addr.addressProvince, addr.addressZipCode]
              .where((x) => (x ?? '').trim().isNotEmpty).join(' ');
    });
  }

  Future<void> _pickCustomer() async {
    final isEnglish = _isEnglish;
    try { _customers ??= (await ArCustomerService().fetchRows()).where((c) => c.isActive).toList(); } catch (_) { _customers = []; }
    if (!mounted) return;
    final all = _customers!;
    final searchCtrl = TextEditingController();
    List<ArCustomer> filtered = List.from(all);
    String label(ArCustomer c) => isEnglish && (c.customerNameEn ?? '').isNotEmpty ? c.customerNameEn! : c.customerNameTh;
    final picked = await showDialog<ArCustomer>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        void doFilter() {
          final q = searchCtrl.text.toUpperCase();
          setS(() => filtered = q.isEmpty
              ? all
              : all.where((c) =>
                  c.customerCode.toUpperCase().contains(q) ||
                  c.customerNameTh.toUpperCase().contains(q) ||
                  (c.customerNameEn ?? '').toUpperCase().contains(q) ||
                  (c.taxId ?? '').contains(q)).toList());
        }
        return Dialog(
          child: SizedBox(
            width: 600, height: 500,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(labelText: isEnglish ? 'Search Customer' : 'ค้นหาลูกค้า', prefixIcon: const Icon(Icons.search), border: const OutlineInputBorder()),
                  onChanged: (_) => doFilter(),
                  autofocus: true,
                ),
              ),
              Expanded(child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final c = filtered[i];
                  return ListTile(
                    dense: true,
                    title: Text('${c.customerCode} - ${label(c)}', style: const TextStyle(fontSize: 13)),
                    subtitle: c.taxId != null ? Text(c.taxId!, style: const TextStyle(fontSize: 11)) : null,
                    onTap: () => Navigator.pop(ctx, c),
                  );
                },
              )),
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
            ]),
          ),
        );
      }),
    );
    searchCtrl.dispose();
    if (picked == null || picked.id == null) return;
    // ที่อยู่จากข้อมูลลูกค้า (backend ดึงซ้ำตอนบันทึก)
    ArCustomer full = picked;
    try { full = await ArCustomerService().fetchRow(picked.id!); } catch (_) {}
    final addr = full.addresses.isEmpty
        ? null
        : (full.addresses.where((a) => a.addressType == 'billing' && a.isDefault).firstOrNull ??
            full.addresses.where((a) => a.addressType == 'billing').firstOrNull ?? full.addresses.first);
    if (!mounted) return;
    setState(() {
      _partySource = 'AR';
      _partyId = full.id;
      _partyCode = full.customerCode;
      _partyType = null;
      _counterpartyCtrl.text = full.customerNameTh;
      _partyTaxIdCtrl.text = full.taxId ?? '';
      _partyBranchCtrl.text = full.taxBranchCode ?? '';
      _partyAddressCtrl.text = addr == null
          ? ''
          : [addr.addressNo, addr.addressBuildingVillage, addr.addressAlley, addr.addressRoad,
             addr.addressSubDistrict, addr.addressDistrict, addr.addressProvince, addr.addressZipCode]
              .where((x) => (x ?? '').trim().isNotEmpty).join(' ');
    });
  }

  Widget _delButton(VoidCallback onPressed) => IconButton(
        tooltip: _isEnglish ? 'Delete' : 'ลบ',
        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
        onPressed: onPressed,
      );

  // ── การ์ดรายการ (10 รายรับ / 20 รายจ่าย / 40 เบิกเงินสดย่อย): ตารางช่อง 36 แบบ IM ─────────────────────
  // เบิกเงินสดย่อย: บรรทัดที่มี VAT มีแถวย่อยใบกำกับภาษีของบรรทัดนั้น (ผู้ขาย เลขผู้เสียภาษี สาขา เลขที่ วันที่)
  Widget _buildDetailSection() {
    final isEnglish = _isEnglish;
    final hasDims = _dimTypes.isNotEmpty;
    final cur = _selectedCurrency?.currencyCode ?? CurrencyService.baseCode;
    final rows = <List<Widget>>[];
    double sumAmt = 0, sumVat = 0;
    for (var i = 0; i < _detailRows.length; i++) {
      final r = _detailRows[i];
      final a = _lineAmt(r);
      sumAmt += double.tryParse(r.amountCtrl.text) ?? 0;
      sumVat += a.vat;
      final acct = findAccount(_accounts, r.expenseAccountId);
      rows.add([
        Text('${i + 1}.', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _ink2)),
        _cellField(r.descCtrl, numeric: false),
        _isReadOnly
            ? _cBox(acct == null ? '—' : '${acct.accountCode}  ${_acctLabel(acct)}', right: false)
            : DropdownButtonFormField<int?>(
                value: _accounts.any((x) => x.id == r.expenseAccountId) ? r.expenseAccountId : null,
                isExpanded: true,
                isDense: true,
                decoration: _cDec(fill: Colors.white, err: r.expenseAccountId == null),
                items: _accounts
                    .map((x) => DropdownMenuItem<int?>(
                        value: x.id,
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(text: x.accountCode, style: const TextStyle(fontWeight: FontWeight.bold)),
                            TextSpan(text: '  ${_acctLabel(x)}', style: const TextStyle(color: _ink2)),
                          ]),
                          style: const TextStyle(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )))
                    .toList(),
                onChanged: (v) => setState(() {
                  r.expenseAccountId = v;
                  final m = _accounts.where((x) => x.id == v);
                  if (m.isNotEmpty) { r.expenseAccountCode = m.first.accountCode; r.expenseAccountName = m.first.accountNameThai; }
                  _rebuildGlRows();
                }),
                validator: (v) => v == null ? (isEnglish ? 'Required' : 'กรุณาเลือก') : null,
              ),
        _cellField(r.amountCtrl, allow: r'[0-9.]', onChanged: (_) => _recalcTotals()),
        _isReadOnly
            ? _cBox(r.vatType == 'NOVAT' ? (isEnglish ? 'No VAT' : 'ไม่มี VAT') : '${r.vatType} ${r.vatRate.toStringAsFixed(r.vatRate % 1 == 0 ? 0 : 2)}%', right: false)
            : DropdownButtonFormField<String>(
                value: _vatRates.any((v) => v.vatCode == r.vatType) || r.vatType == 'NOVAT' ? r.vatType : 'NOVAT',
                isExpanded: true,
                isDense: true,
                decoration: _cDec(fill: Colors.white),
                items: [
                  if (!_vatRates.any((v) => v.vatCode == 'NOVAT'))
                    DropdownMenuItem(value: 'NOVAT', child: Text(isEnglish ? 'No VAT' : 'ไม่มี VAT', style: const TextStyle(fontSize: 13))),
                  ..._vatRates.map((v) => DropdownMenuItem(
                      value: v.vatCode,
                      child: Text('${v.vatCode} ${v.rate.toStringAsFixed(v.rate % 1 == 0 ? 0 : 2)}%', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))),
                ],
                onChanged: (code) {
                  final vr = _vatRates.cast<VatRate?>().firstWhere((v) => v?.vatCode == code, orElse: () => null);
                  setState(() { r.vatType = code ?? 'NOVAT'; r.vatRate = r.vatType == 'NOVAT' ? 0 : (vr?.rate ?? 0); });
                  _recalcTotals();
                },
              ),
        _cBox(_fmt.format(a.vat)),
        if (hasDims)
          GlLineDimsCell(
            dimTypes: _dimTypes,
            dimValues: _dimValues,
            lineDims: r.dims,
            headerDims: _dimSelections,
            account: acct,
            readOnly: _isReadOnly,
            width: 140,
            onChanged: (d) { setState(() => r.dims = d); _rebuildGlRows(); },
          ),
        if (!_isReadOnly) _delButton(() { setState(() { r.dispose(); _detailRows.removeAt(i); }); _recalcTotals(); }),
      ]);
      if (_isVoucher && r.vatType != 'NOVAT') rows.add([_voucherTaxRow(i + 1, r)]);
    }
    return _card(
      _isReceipt ? (isEnglish ? 'Revenue Items' : 'รายการรายรับ') : (isEnglish ? 'Expense Items' : 'รายการค่าใช้จ่าย'),
      chips: [_chip(isEnglish ? '${_detailRows.length} lines' : '${_detailRows.length} รายการ', const Color(0xFF1E4F8F), _hAuto)],
      actions: [
        SizedBox(width: 170, child: _vatIncludedBox(height: 34)),
        if (!_isReadOnly) _addButton(isEnglish ? 'Add Item' : 'เพิ่มรายการ', () => setState(() => _detailRows.add(_DetailRow()))),
      ],
      [
        _gridTable(
          cols: [
            ('#', 30, 0, false),
            (isEnglish ? 'Description' : 'รายละเอียด', 0, 1, false),
            (_isReceipt ? (isEnglish ? 'Revenue Account *' : 'บัญชีรายได้ *') : (isEnglish ? 'Expense Account *' : 'บัญชีค่าใช้จ่าย *'), 0, 1, false),
            ('${isEnglish ? 'Amount' : 'จำนวนเงิน'} ($cur)', 130, 3, true),
            ('VAT', 110, 3, false),
            (isEnglish ? 'VAT Amt' : 'ภาษี', 100, 3, true),
            if (hasDims) (isEnglish ? 'Line Dimensions' : 'มิติของบรรทัด', 150, 4, false),
            if (!_isReadOnly) ('', 36, 0, false),
          ],
          groupTitle: (g) => g == 1
              ? (isEnglish ? 'Item / Account' : 'รายการ / บัญชี')
              : g == 3
                  ? (isEnglish ? 'Amount / VAT' : 'ยอด / VAT')
                  : (isEnglish ? 'Dimensions' : 'มิติ'),
          rows: rows,
          footer: [
            const SizedBox.shrink(),
            _footerLabel(isEnglish ? 'Total ${_detailRows.length} lines' : 'รวม ${_detailRows.length} รายการ'),
            const SizedBox.shrink(),
            _footerAmount(sumAmt),
            const SizedBox.shrink(),
            _footerAmount(sumVat),
            if (hasDims) const SizedBox.shrink(),
            if (!_isReadOnly) const SizedBox.shrink(),
          ],
          empty: Text(isEnglish ? 'No items yet — click "Add Item"' : 'ยังไม่มีรายการ — กด "เพิ่มรายการ"', style: const TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  // แถวย่อยใบกำกับภาษีของบรรทัดเบิกเงินสดย่อยที่มี VAT (รายงานภาษีซื้อ)
  Widget _voucherTaxRow(int no, _DetailRow r) {
    final isEnglish = _isEnglish;
    Widget f(String label, TextEditingController c, int flex, {bool req = false}) => Expanded(
          flex: flex,
          child: TextFormField(
            controller: c,
            readOnly: _isReadOnly,
            style: const TextStyle(fontSize: 13),
            decoration: _cDec(fill: _isReadOnly ? _hRo : Colors.white, err: req && !_isReadOnly && c.text.trim().isEmpty, hint: '$label${req ? ' *' : ''}')
                .copyWith(prefixText: '$label: ', prefixStyle: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600)),
            onChanged: (_) => setState(() {}),
          ),
        );
    return Container(
      padding: const EdgeInsets.only(left: 10),
      decoration: const BoxDecoration(border: Border(left: BorderSide(color: _gMore, width: 3))),
      child: Row(children: [
        Text(isEnglish ? 'Tax invoice of line $no' : 'ใบกำกับภาษีของรายการ $no',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _ink2)),
        const SizedBox(width: 8),
        f(isEnglish ? 'Seller' : 'ผู้ขาย', r.sellerNameCtrl, 3, req: true),
        const SizedBox(width: 6),
        f(isEnglish ? 'Tax ID' : 'เลขผู้เสียภาษี', r.sellerTaxIdCtrl, 2, req: true),
        const SizedBox(width: 6),
        f(isEnglish ? 'Branch' : 'สาขา', r.sellerBranchCtrl, 1),
        const SizedBox(width: 6),
        f(isEnglish ? 'No.' : 'เลขที่', r.taxInvNoCtrl, 2, req: true),
        const SizedBox(width: 6),
        Expanded(
          flex: 2,
          child: InkWell(
            onTap: _isReadOnly
                ? null
                : () async {
                    final d = await showDatePicker(context: context, initialDate: r.taxInvDate ?? _docDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (d != null) setState(() => r.taxInvDate = d);
                  },
            child: InputDecorator(
              decoration: _cDec(fill: _isReadOnly ? _hRo : _hAuto)
                  .copyWith(prefixText: '${isEnglish ? 'Date' : 'วันที่'}: ', prefixStyle: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600)),
              child: Text(r.taxInvDate != null ? _dateFmt.format(r.taxInvDate!) : (isEnglish ? '(doc date)' : '(วันที่เอกสาร)'),
                  maxLines: 1, style: TextStyle(fontSize: 13, color: r.taxInvDate == null ? Colors.grey.shade600 : null)),
            ),
          ),
        ),
      ]),
    );
  }

  // ── ใบเบิกเงินสดย่อยที่นำมาเติม (30): ติ๊กเลือก → เติมยอดคงเหลือให้ (แก้ได้) แบบการ์ดจับคู่ชำระหนี้ของ AP ───────
  TextEditingController _applyCtrl(int id, double amount) =>
      _applyCtrls.putIfAbsent(id, () => TextEditingController(text: amount > 0 ? amount.toStringAsFixed(2) : ''));

  void _setApply(int id, String docNo, DateTime? docDate, double balance, double amount) {
    setState(() {
      final idx = _applyRows.indexWhere((a) => a.appliedToId == id);
      if (amount <= 0) {
        if (idx >= 0) _applyRows.removeAt(idx);
      } else if (idx >= 0) {
        _applyRows[idx].appliedAmountFc = amount;
      } else {
        _applyRows.add(_ApplyRow(appliedToId: id, appliedToDocNo: docNo, appliedToDocDate: docDate, balanceAvailable: balance, appliedAmountFc: amount));
      }
    });
    _recalcTotals();
  }

  Widget _buildApplySection() {
    final isEnglish = _isEnglish;
    final applied = {for (final a in _applyRows) a.appliedToId: a};
    final items = <(int, String, DateTime?, String?, double?, double)>[
      for (final v in _openVouchers) (v.id, v.docNo, v.docDate, v.description, v.totalAmountLc, v.balanceAmountLc),
      for (final a in _applyRows)
        if (!_openVouchers.any((v) => v.id == a.appliedToId)) (a.appliedToId, a.appliedToDocNo, a.appliedToDocDate, null, null, a.balanceAvailable),
    ];
    final rows = <List<Widget>>[];
    for (final it in items) {
      final (id, docNo, date, desc, total, bal) = it;
      final a = applied[id];
      final ctrl = _applyCtrl(id, a?.appliedAmountFc ?? 0);
      rows.add([
        Checkbox(
          value: a != null,
          visualDensity: VisualDensity.compact,
          onChanged: _isReadOnly
              ? null
              : (v) {
                  final amt = v == true ? bal : 0.0;
                  ctrl.text = amt > 0 ? amt.toStringAsFixed(2) : '';
                  _setApply(id, docNo, date, bal, amt);
                },
        ),
        Text(docNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
        Text(date != null ? _dateFmt.format(date) : '', style: const TextStyle(fontSize: 13)),
        Text(desc ?? '', style: const TextStyle(fontSize: 13, color: _ink2), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(total == null ? '' : _fmt.format(total), style: _numStyle),
        Text(bal == 0 && total == null ? '' : _fmt.format(bal), style: _numStyle),
        _isReadOnly
            ? _cBox(a == null ? '' : _fmt.format(a.appliedAmountFc), bold: true)
            : TextFormField(
                controller: ctrl,
                textAlign: TextAlign.right,
                style: _numStyle.copyWith(fontWeight: FontWeight.w600),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: _cDec(fill: a != null ? _hAuto : Colors.white),
                onChanged: (v) => _setApply(id, docNo, date, bal, double.tryParse(v) ?? 0),
              ),
      ]);
    }
    final selectedTotal = _applyRows.fold(0.0, (s, a) => s + a.appliedAmountFc);
    final Widget empty = Text(
        _bankAccountId == null
            ? (isEnglish ? 'Select a petty cash account first' : 'กรุณาเลือกบัญชีเงินสดย่อยก่อน')
            : (isEnglish ? 'No open vouchers found' : 'ไม่พบใบเบิกที่รอเติมเงิน'),
        style: const TextStyle(color: Colors.grey));
    return _card(
      isEnglish ? 'Vouchers to Reimburse' : 'ใบเบิกเงินสดย่อยที่นำมาเติม',
      chips: [
        if (items.isNotEmpty)
          _chip(isEnglish ? '${_openVouchers.length} open · ${_applyRows.length} selected' : 'รอเติม ${_openVouchers.length} ใบ · เลือก ${_applyRows.length}',
              const Color(0xFF1E4F8F), _hAuto),
      ],
      [
        _gridTable(
          cols: [
            ('', 36, 0, false),
            (isEnglish ? 'Doc No.' : 'เลขที่', 140, 1, false),
            (isEnglish ? 'Date' : 'วันที่', 100, 1, false),
            (isEnglish ? 'Description' : 'คำอธิบาย', 0, 1, false),
            (isEnglish ? 'Voucher Total' : 'ยอดเบิก', 120, 3, true),
            (isEnglish ? 'Not yet reimbursed' : 'ยังไม่เติม', 120, 3, true),
            (isEnglish ? 'Reimburse now' : 'เติมครั้งนี้', 130, 3, true),
          ],
          groupTitle: (g) => g == 1 ? (isEnglish ? 'Petty Cash Voucher' : 'ใบเบิกเงินสดย่อย') : '${isEnglish ? 'Amounts' : 'ยอด'} (${CurrencyService.baseCode})',
          rows: rows,
          footer: [
            const SizedBox.shrink(),
            _footerLabel(isEnglish ? 'Selected ${_applyRows.length}' : 'รวมที่เลือก ${_applyRows.length} ใบ'),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            _footerAmount(selectedTotal),
          ],
          empty: empty,
        ),
      ],
    );
  }

  // ── ภาษีหัก ณ ที่จ่าย (20: เราหัก / 10: ผู้จ่ายหักเรา) ────────────────────────────────────────────────
  Widget _buildWhtSection() {
    final isEnglish = _isEnglish;
    final cur = _selectedCurrency?.currencyCode ?? CurrencyService.baseCode;
    final rows = <List<Widget>>[];
    for (var i = 0; i < _whtRows.length; i++) {
      final w = _whtRows[i];
      final rate = w.whtType?.whtRate ?? 0;
      String typeLabel(CdWhtType t) => '${t.whtCode} — ${isEnglish && (t.whtNameEn ?? '').isNotEmpty ? t.whtNameEn! : t.whtName}';
      rows.add([
        _isReadOnly
            ? _cBox(w.whtType == null ? '—' : typeLabel(w.whtType!), right: false)
            : DropdownButtonFormField<CdWhtType?>(
                value: w.whtType,
                isExpanded: true,
                isDense: true,
                decoration: _cDec(fill: Colors.white, err: w.whtType == null),
                items: [
                  DropdownMenuItem(value: null, child: Text(isEnglish ? '— Select type —' : '— เลือกประเภท —', style: const TextStyle(fontSize: 13))),
                  ..._whtTypes.map((t) => DropdownMenuItem(value: t, child: Text(typeLabel(t), style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))),
                ],
                onChanged: (t) {
                  setState(() {
                    w.whtType = t;
                    final base = double.tryParse(w.baseCtrl.text) ?? 0;
                    w.whtCtrl.text = (base * (t?.whtRate ?? 0) / 100).toStringAsFixed(2);
                  });
                  _recalcTotals();
                },
              ),
        _cBox(rate > 0 ? '${rate.toStringAsFixed(2)}%' : '—'),
        _cellField(w.baseCtrl, allow: r'[0-9.]', onChanged: (v) {
          setState(() => w.whtCtrl.text = ((double.tryParse(v) ?? 0) * rate / 100).toStringAsFixed(2));
          _recalcTotals();
        }),
        _cellField(w.whtCtrl, allow: r'[0-9.]', bold: true, onChanged: (_) => _recalcTotals()),
        _cellField(w.descCtrl, numeric: false),
        if (!_isReadOnly) _delButton(() { setState(() { w.dispose(); _whtRows.removeAt(i); }); _recalcTotals(); }),
      ]);
    }
    return _card(
      _isReceipt ? (isEnglish ? 'Withholding Tax Deducted by Payer' : 'ภาษีถูกหัก ณ ที่จ่าย') : (isEnglish ? 'Withholding Tax' : 'ภาษีหัก ณ ที่จ่าย'),
      chips: [_chip(isEnglish ? '${_whtRows.length} lines' : '${_whtRows.length} รายการ', const Color(0xFF1E4F8F), _hAuto)],
      actions: [if (!_isReadOnly) _addButton(isEnglish ? 'Add WHT' : 'เพิ่มรายการ', () => setState(() => _whtRows.add(_WhtRow())))],
      [
        _gridTable(
          cols: [
            (isEnglish ? 'Income Type *' : 'ประเภทเงินได้ *', 0, 1, false),
            (isEnglish ? 'Rate' : 'อัตรา', 80, 1, true),
            ('${isEnglish ? 'Tax base' : 'ฐานภาษี'} ($cur)', 130, 3, true),
            ('${isEnglish ? 'WHT' : 'ภาษีที่หัก'} ($cur)', 130, 3, true),
            (isEnglish ? 'Description' : 'คำอธิบาย', 0, 4, false),
            if (!_isReadOnly) ('', 36, 0, false),
          ],
          groupTitle: (g) => g == 1 ? (isEnglish ? 'Income Type' : 'ประเภทเงินได้') : g == 3 ? (isEnglish ? 'Amounts' : 'ยอด') : (isEnglish ? 'Details' : 'รายละเอียด'),
          rows: rows,
          footer: [
            _footerLabel(isEnglish ? 'Total WHT' : 'รวมภาษีหัก ณ ที่จ่าย'),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            _footerAmount(_whtFc),
            const SizedBox.shrink(),
            if (!_isReadOnly) const SizedBox.shrink(),
          ],
          empty: Text(isEnglish ? 'No withholding tax' : 'ไม่มีการหัก ณ ที่จ่าย', style: const TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  // ── ช่องทางรับ-จ่ายเงิน (10/20/30): กลุ่มย่อยต่อช่องทาง แถบสีตามประเภท (แบบ AR / AP) ─────────────────────
  double get _paymentTotalFc => _paymentRows.fold(0.0, (s, r) => s + (double.tryParse(r.amountCtrl.text) ?? 0));

  Widget _payStatusChip() {
    final isEnglish = _isEnglish;
    final diff = _netPayFc - _paymentTotalFc;
    if (diff.abs() <= 0.005) return _chip(isEnglish ? 'Fully covered' : 'ครบยอด', const Color(0xFF1E6B3A), const Color(0xFFE6F4EA));
    return diff > 0
        ? _chip('${isEnglish ? 'Short' : 'ขาด'} ${_fmt.format(diff)}', const Color(0xFF8A4B00), const Color(0xFFFFF0D9))
        : _chip('${isEnglish ? 'Over' : 'เกิน'} ${_fmt.format(-diff)}', const Color(0xFFB71C1C), const Color(0xFFFDECEA));
  }

  Widget _buildPaymentSection() {
    final isEnglish = _isEnglish;
    return _card(
      _isReceipt ? (isEnglish ? 'Received Via' : 'ช่องทางรับเงิน') : (isEnglish ? 'Paid Via' : 'ช่องทางจ่ายเงิน'),
      chips: [if (_paymentRows.isNotEmpty || _netPayFc != 0) _payStatusChip()],
      actions: [if (!_isReadOnly) _addButton(isEnglish ? 'Add Channel' : 'เพิ่มช่องทาง', () => setState(() => _paymentRows.add(_PaymentRow())))],
      [
        if (_paymentRows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
                child: Text(isEnglish ? 'No channels yet — click "Add Channel"' : 'ยังไม่มีช่องทาง — กด "เพิ่มช่องทาง"', style: const TextStyle(color: Colors.grey))),
          )
        else
          for (var i = 0; i < _paymentRows.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _buildPaymentRowCard(i, _paymentRows[i]),
          ],
      ],
    );
  }

  Widget _buildPaymentRowCard(int index, _PaymentRow r) {
    final isEnglish = _isEnglish;
    final type = r.paymentMethodType;
    final isFc = _selectedCurrency?.baseCurrencyFlag == false;
    final method = _paymentMethods.where((m) => m.id == r.paymentMethodId).firstOrNull;
    final methodField = _isReadOnly
        ? _roField(cmMethodTypeLabel(type, isEnglish), [r.paymentMethodCode ?? '', r.paymentMethodName ?? ''].where((s) => s.isNotEmpty).join('  '))
        : DropdownButtonFormField<int?>(
            value: method?.id,
            isExpanded: true,
            isDense: true,
            decoration: _hDec(isEnglish ? 'Payment Method' : 'ประเภทการชำระ', req: true),
            items: _paymentMethods
                .map((m) => DropdownMenuItem<int?>(
                    value: m.id,
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: m.methodCode, style: TextStyle(fontWeight: FontWeight.bold, color: _methodColor(m.methodType).shade800)),
                        TextSpan(text: '  ${isEnglish && (m.methodNameEn ?? '').isNotEmpty ? m.methodNameEn! : m.methodNameTh}', style: const TextStyle(color: _ink2)),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )))
                .toList(),
            onChanged: (v) => setState(() {
              r.paymentMethodId = v;
              final m = _paymentMethods.where((x) => x.id == v);
              if (m.isNotEmpty) {
                r.paymentMethodCode = m.first.methodCode;
                r.paymentMethodName = m.first.methodNameTh;
                r.paymentMethodType = m.first.methodType;
                r.cmBankAccountId = m.first.cmBankAccountId;
              }
              _rebuildGlRows();
            }),
          );
    final bankField = _bankField(isEnglish ? 'Bank Account' : 'บัญชีธนาคาร', r.cmBankAccountId, 'BANK', (v) => setState(() { r.cmBankAccountId = v; _rebuildGlRows(); }),
        req: false);
    final amountField = _payField(
      label: '${isEnglish ? 'Amount' : 'จำนวนเงิน'}${isFc ? ' (${_selectedCurrency?.currencyCode})' : ''}',
      ctrl: r.amountCtrl,
      hint: '0.00',
      numeric: true,
      req: true,
      onChanged: (_) => _recalcTotals(),
    );
    final row1 = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: 3, child: methodField),
      const SizedBox(width: 8),
      Expanded(flex: 3, child: bankField),
      const SizedBox(width: 8),
      Expanded(flex: 2, child: amountField),
      if (!_isReadOnly)
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 4),
          child: _delButton(() { setState(() { r.dispose(); _paymentRows.removeAt(index); }); _recalcTotals(); }),
        ),
    ]);

    final Widget row2;
    if (_usesCheckbook(r)) {
      // เช็คที่จ่ายออก: สมุดเช็ค + เลขที่เช็ค (ว่าง = ใช้เลขถัดไปของสมุดตอน Post)
      _ensureCheckbooks(r.cmBankAccountId!);
      final books = (_checkbooks[r.cmBankAccountId!] ?? const <CmCheckbook>[]).where((b) => b.status == 'Active' || b.id == r.checkbookId).toList();
      final book = books.where((b) => b.id == r.checkbookId).firstOrNull;
      row2 = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 3,
          child: _isReadOnly
              ? _roField(isEnglish ? 'Checkbook' : 'สมุดเช็ค', book == null ? '' : '${book.checkbookCode} (${book.startCheckNo}-${book.endCheckNo})')
              : DropdownButtonFormField<int?>(
                  value: book?.id,
                  isExpanded: true,
                  isDense: true,
                  decoration: _hDec(isEnglish ? 'Checkbook' : 'สมุดเช็ค', auto: true),
                  items: [
                    DropdownMenuItem(value: null, child: Text(isEnglish ? '— Type check no. —' : '— พิมพ์เลขเช็คเอง —')),
                    ...books.map((b) => DropdownMenuItem(value: b.id, child: Text('${b.checkbookCode} (${b.startCheckNo}-${b.endCheckNo})', overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) => setState(() => r.checkbookId = v),
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: _payField(
              label: isEnglish ? 'Check No.' : 'เลขที่เช็ค',
              ctrl: r.refNoCtrl,
              hint: r.checkbookId != null ? (isEnglish ? 'Next: ${_nextCheckNo(r) ?? '-'} (on post)' : 'เลขถัดไป ${_nextCheckNo(r) ?? '-'} (ตอน Post)') : null),
        ),
        const Spacer(flex: 2),
        if (!_isReadOnly) const SizedBox(width: 38),
      ]);
    } else {
      row2 = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 3,
          child: _payField(
              label: type == 'CHECK'
                  ? (isEnglish ? 'Check No.' : 'เลขที่เช็ค')
                  : type == 'TRANSFER' || type == 'MOBILE_BANKING'
                      ? (isEnglish ? 'Reference / Slip No.' : 'เลขอ้างอิง / Slip No')
                      : (isEnglish ? 'Reference No.' : 'เลขที่อ้างอิง'),
              ctrl: r.refNoCtrl),
        ),
        const Spacer(flex: 5),
        if (!_isReadOnly) const SizedBox(width: 38),
      ]);
    }
    return _payBlock(_methodColor(type), [row1, row2]);
  }

  String? _nextCheckNo(_PaymentRow r) =>
      (_checkbooks[r.cmBankAccountId] ?? const <CmCheckbook>[]).where((b) => b.id == r.checkbookId).firstOrNull?.nextCheckNo;

  // ── การ์ดสรุปยอด: ซ้าย = คำอธิบาย, ขวา = ยอด → ยอดสุดท้าย 17 ตัวหนา + ส่วนต่างกับช่องทางรับ-จ่ายเงิน ─────────
  Widget _buildTotalsSection() {
    final isEnglish = _isEnglish;
    final cur = _selectedCurrency?.currencyCode ?? CurrencyService.baseCode;
    final hasVatSplit = (_hasVatLines && _detailRows.isNotEmpty) || _isBankCharge;
    final String finalLabel;
    final double finalAmount;
    final String hint;
    if (_isInterestIncome) {
      finalLabel = isEnglish ? 'Net received' : 'ยอดรับสุทธิเข้าบัญชี';
      finalAmount = _netPayFc;
      hint = isEnglish ? 'The bank account receives the interest less the tax the bank withheld' : 'บัญชีธนาคารได้รับดอกเบี้ยหลังหักภาษีที่ธนาคารหักไว้';
    } else if (_isInterest) {
      finalLabel = isEnglish ? 'Deducted from bank' : 'ตัดจากบัญชีธนาคาร';
      finalAmount = _totalAmountFc;
      hint = isEnglish ? 'Interest expense charged to the bank account' : 'ดอกเบี้ยจ่ายตัดจากบัญชีธนาคาร';
    } else if (_isBankCharge) {
      finalLabel = isEnglish ? 'Deducted from bank' : 'ตัดจากบัญชีธนาคาร';
      finalAmount = _totalAmountFc;
      hint = isEnglish ? 'The charge is deducted from the bank account in full · VAT goes to input VAT' : 'ค่าธรรมเนียมตัดจากบัญชีธนาคารเต็มจำนวน · VAT เข้าภาษีซื้อ';
    } else if (_isVoucher) {
      finalLabel = isEnglish ? 'Voucher total' : 'ยอดเบิกเงินสดย่อย';
      finalAmount = _totalAmountFc;
      hint = isEnglish ? 'Once posted, the voucher waits to be reimbursed by a replenishment document (30)' : 'ใบเบิกที่ Post แล้วจะรอนำไปเติมในเอกสารเติมเงินสดย่อย (30)';
    } else if (_isReplenishment) {
      finalLabel = isEnglish ? 'Replenishment' : 'ยอดเติมเงินสดย่อย';
      finalAmount = _totalAmountFc;
      hint = isEnglish ? 'Replenishment = selected vouchers · payment channels must equal this amount' : 'ยอดเติม = ยอดรวมใบเบิกที่เลือก · ช่องทางจ่ายเงินรวมต้องเท่ากับยอดเติม';
    } else if (_isReceipt) {
      finalLabel = isEnglish ? 'Net received' : 'ยอดรับสุทธิ';
      finalAmount = _netPayFc;
      hint = isEnglish ? 'Net received = total − tax withheld by payer · receipt channels must equal it' : 'ยอดรับสุทธิ = ยอดรวม − ภาษีถูกหัก ณ ที่จ่าย · ช่องทางรับเงินรวมต้องเท่ากับยอดรับสุทธิ';
    } else {
      finalLabel = isEnglish ? 'Net to pay' : 'ยอดจ่ายสุทธิ';
      finalAmount = _netPayFc;
      hint = isEnglish ? 'Net to pay = total − withholding tax · payment channels must equal it' : 'ยอดจ่ายสุทธิ = ยอดรวม − ภาษีหัก ณ ที่จ่าย · ช่องทางจ่ายเงินรวมต้องเท่ากับยอดจ่ายสุทธิ';
    }
    final diff = _netPayFc - _paymentTotalFc;
    final ok = diff.abs() <= 0.005;

    final figures = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (hasVatSplit) ...[
        _sumRow(isEnglish ? 'Amount Before VAT' : 'ยอดก่อน VAT', _subtotalFc),
        _sumRow('VAT', _vatFc),
        if (_showsWht) _sumRow(isEnglish ? 'Total' : 'ยอดรวม', _totalAmountFc, line: true),
      ] else if (_showsWht)
        _sumRow(_isInterestIncome ? (isEnglish ? 'Interest' : 'ดอกเบี้ย') : (isEnglish ? 'Total' : 'ยอดรวม'), _totalAmountFc),
      if (_showsWht && _whtFc != 0)
        _sumRow(_isPayment ? (isEnglish ? 'Less: withholding tax' : 'หัก ณ ที่จ่าย') : (isEnglish ? 'Less: tax withheld' : 'ถูกหัก ณ ที่จ่าย'), -_whtFc, neg: true),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFFE8F3F2), borderRadius: BorderRadius.circular(6)),
        child: Row(children: [
          Expanded(child: Text('$finalLabel ($cur)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F5C5C)))),
          Text(_fmt.format(finalAmount), style: _numStyle.copyWith(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF0F5C5C))),
        ]),
      ),
      if (_exchangeRate != 1.0) _sumRow('${isEnglish ? 'Total' : 'ยอดรวม'} (${CurrencyService.baseCode})', finalAmount * _exchangeRate),
      if (_hasPaymentSection) ...[
        _sumRow('${_isReceipt ? (isEnglish ? 'Received via channels' : 'ช่องทางรับเงินรวม') : (isEnglish ? 'Paid via channels' : 'ช่องทางจ่ายเงินรวม')} ($cur)', _paymentTotalFc,
            line: true),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: ok ? const Color(0xFFE6F4EA) : const Color(0xFFFDECEA), borderRadius: BorderRadius.circular(6)),
          child: Row(children: [
            Expanded(
              child: Text(ok ? (isEnglish ? 'Difference · fully covered' : 'ส่วนต่าง · ครบยอด') : (isEnglish ? 'Difference' : 'ส่วนต่าง'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ok ? const Color(0xFF1E6B3A) : const Color(0xFFB71C1C))),
            ),
            Text(_fmt.format(diff), style: _numStyle.copyWith(fontSize: 17, fontWeight: FontWeight.bold, color: ok ? const Color(0xFF1E6B3A) : const Color(0xFFB71C1C))),
          ]),
        ),
      ],
    ]);
    final left = Text(hint, style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600));
    return _card(isEnglish ? 'Summary' : 'สรุปยอด', [
      LayoutBuilder(
        builder: (context, c) => c.maxWidth >= 640
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Align(alignment: Alignment.topLeft, child: left)),
                const SizedBox(width: 24),
                SizedBox(width: 380, child: figures),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: 10), figures]),
      ),
    ]);
  }

  ({String code, String name}) _acctCodeName(int? id) {
    final isEnglish = _isEnglish;
    if (id == null) return (code: '!', name: isEnglish ? 'Not configured' : 'ยังไม่ตั้งค่า');
    final m = _accounts.where((a) => a.id == id);
    if (m.isEmpty) return (code: '#$id', name: '');
    final a = m.first;
    return (code: a.accountCode, name: _acctLabel(a));
  }

  ({String code, String name}) _bankAcctCodeName(int? bankAccountId) {
    final isEnglish = _isEnglish;
    final m = _bankAccounts.where((b) => b.id == bankAccountId);
    if (m.isEmpty) return (code: '!', name: isEnglish ? 'Select bank account' : 'ยังไม่เลือกบัญชี');
    final b = m.first;
    if (b.glAccountId == null) return (code: '!', name: isEnglish ? 'Bank account has no GL account' : 'บัญชีนี้ยังไม่ผูก GL');
    return (code: b.glAccountCode ?? '', name: b.glAccountName ?? '');
  }

  // บัญชีของช่องทางรับ/จ่ายเงิน: บัญชี GL ของประเภทการชำระ → บัญชี GL ของบัญชีธนาคาร (เหมือน backend)
  ({String code, String name}) _paymentAcctCodeName(_PaymentRow p) {
    final m = _paymentMethods.where((x) => x.id == p.paymentMethodId);
    if (m.isNotEmpty && m.first.glAccountId != null) return _acctCodeName(m.first.glAccountId);
    return _bankAcctCodeName(p.cmBankAccountId);
  }

  // บัญชีเงินสดย่อย (30/40): บัญชี GL ของกองเงินสดย่อยที่เลือก → บัญชีเงินสดย่อยในการตั้งค่า (เหมือน backend)
  ({String code, String name}) _pettyCashAcctCodeName() {
    final m = _bankAccounts.where((b) => b.id == _bankAccountId);
    if (m.isNotEmpty && m.first.glAccountId != null) {
      return (code: m.first.glAccountCode ?? '', name: m.first.glAccountName ?? '');
    }
    return _setupAcctCodeName(_docSetup!.pettyCashPayableAccountId, _docSetup!.pettyCashPayableAccountCode, _docSetup!.pettyCashPayableAccountName);
  }

  ({String code, String name}) _setupAcctCodeName(int? id, String? code, String? name) {
    final isEnglish = _isEnglish;
    if (id == null) return (code: '!', name: isEnglish ? 'Not configured' : 'ยังไม่ตั้งค่า');
    return (code: code ?? '', name: name ?? '');
  }

  // ── Client-side GL preview for Draft — mirrors backend postGlEntry ─────────
  List<_GlLine> _computeGlPreview() {
    final isEnglish = _isEnglish;
    final lines = <_GlLine>[];
    if (_docSetup == null) return lines;
    final lc = _exchangeRate;

    void addLine(({String code, String name}) acct, String desc, double fcDebit, double fcCredit, [Map<int, int?>? dims]) {
      lines.add(_GlLine(acct.code, acct.name, desc, fcDebit * lc, fcCredit * lc, fcDebit, fcCredit, dims));
    }

    if (_isReceipt && _detailRows.isNotEmpty) {
      for (final p in _paymentRows) {
        final amt = double.tryParse(p.amountCtrl.text) ?? 0;
        if (amt == 0) continue;
        addLine(_paymentAcctCodeName(p), '${isEnglish ? 'Receive' : 'รับเงิน'} ${p.paymentMethodCode ?? ''}', amt, 0);
      }
      if (_whtFc != 0) {
        addLine(_setupAcctCodeName(_docSetup!.whtPrepaidAccountId, _docSetup!.whtPrepaidAccountCode, _docSetup!.whtPrepaidAccountName),
            isEnglish ? 'WHT deducted by payer' : 'ภาษีถูกหัก ณ ที่จ่าย', _whtFc, 0);
      }
      for (final d in _detailRows) {
        final a = _lineAmt(d);
        if (a.net == 0) continue;
        final acct = d.expenseAccountId != null
            ? _acctCodeName(d.expenseAccountId)
            : _setupAcctCodeName(_docSetup!.revenueAccountId, _docSetup!.revenueAccountCode, _docSetup!.revenueAccountName);
        addLine(acct, d.descCtrl.text.isEmpty ? (isEnglish ? 'Revenue' : 'รายรับ') : d.descCtrl.text, 0, a.net, effectiveLineDims(d.dims, _dimSelections));
      }
      if (_vatFc != 0) {
        addLine(_setupAcctCodeName(_docSetup!.vatOutputAccountId, _docSetup!.vatOutputAccountCode, _docSetup!.vatOutputAccountName),
            isEnglish ? 'Output VAT' : 'ภาษีขาย', 0, _vatFc);
      }
    } else if (_isReceipt) {
      for (final p in _paymentRows) {
        final amt = double.tryParse(p.amountCtrl.text) ?? 0;
        if (amt == 0) continue;
        addLine(_paymentAcctCodeName(p), '${isEnglish ? 'Receive' : 'รับเงิน'} ${p.paymentMethodCode ?? ''}', amt, 0);
      }
      final revAcct = _glAccountId != null
          ? _acctCodeName(_glAccountId)
          : _setupAcctCodeName(_docSetup!.revenueAccountId, _docSetup!.revenueAccountCode, _docSetup!.revenueAccountName);
      addLine(revAcct, isEnglish ? 'Revenue' : 'รายรับ', 0, _totalAmountFc);
    } else if (_isPayment && _detailRows.isNotEmpty) {
      for (final d in _detailRows) {
        final a = _lineAmt(d);
        if (a.net == 0) continue;
        final acct = d.expenseAccountId != null
            ? _acctCodeName(d.expenseAccountId)
            : _setupAcctCodeName(_docSetup!.expenseAccountId, _docSetup!.expenseAccountCode, _docSetup!.expenseAccountName);
        addLine(acct, d.descCtrl.text.isEmpty ? (isEnglish ? 'Expense' : 'รายจ่าย') : d.descCtrl.text, a.net, 0, effectiveLineDims(d.dims, _dimSelections));
      }
      if (_vatFc != 0) {
        addLine(_setupAcctCodeName(_docSetup!.vatInputAccountId, _docSetup!.vatInputAccountCode, _docSetup!.vatInputAccountName),
            isEnglish ? 'Input VAT' : 'ภาษีซื้อ', _vatFc, 0);
      }
      if (_whtFc != 0) {
        addLine(_setupAcctCodeName(_docSetup!.whtPayableAccountId, _docSetup!.whtPayableAccountCode, _docSetup!.whtPayableAccountName),
            isEnglish ? 'Withholding tax' : 'ภาษีหัก ณ ที่จ่าย', 0, _whtFc);
      }
      for (final p in _paymentRows) {
        final amt = double.tryParse(p.amountCtrl.text) ?? 0;
        if (amt == 0) continue;
        addLine(_paymentAcctCodeName(p), '${isEnglish ? 'Pay' : 'จ่ายเงิน'} ${p.paymentMethodCode ?? ''}', 0, amt);
      }
    } else if (_isPayment) {
      final expAcct = _glAccountId != null
          ? _acctCodeName(_glAccountId)
          : _setupAcctCodeName(_docSetup!.expenseAccountId, _docSetup!.expenseAccountCode, _docSetup!.expenseAccountName);
      addLine(expAcct, isEnglish ? 'Expense' : 'รายจ่าย', _totalAmountFc, 0);
      for (final p in _paymentRows) {
        final amt = double.tryParse(p.amountCtrl.text) ?? 0;
        if (amt == 0) continue;
        addLine(_paymentAcctCodeName(p), '${isEnglish ? 'Pay' : 'จ่ายเงิน'} ${p.paymentMethodCode ?? ''}', 0, amt);
      }
    } else if (_isReplenishment) {
      final payableAcct = _pettyCashAcctCodeName();
      addLine(payableAcct, isEnglish ? 'Petty cash replenishment' : 'เติมเงินสดย่อย', _totalAmountFc, 0);
      for (final p in _paymentRows) {
        final amt = double.tryParse(p.amountCtrl.text) ?? 0;
        if (amt == 0) continue;
        addLine(_paymentAcctCodeName(p), '${isEnglish ? 'Pay' : 'เติมเงินสดย่อย'} ${p.paymentMethodCode ?? ''}', 0, amt);
      }
    } else if (_isVoucher) {
      for (final d in _detailRows) {
        final amt = _lineAmt(d).net; // ก่อน VAT — ภาษีซื้อแยกบรรทัด
        if (amt == 0) continue;
        final acct = d.expenseAccountId != null
            ? _acctCodeName(d.expenseAccountId)
            : (code: '!', name: isEnglish ? 'Select account' : 'ยังไม่เลือกบัญชี');
        addLine(acct, d.descCtrl.text.isEmpty ? (isEnglish ? 'Petty cash expense' : 'เบิกเงินสดย่อย') : d.descCtrl.text, amt, 0, effectiveLineDims(d.dims, _dimSelections));
      }
      if (_vatFc != 0) {
        addLine(_setupAcctCodeName(_docSetup!.vatInputAccountId, _docSetup!.vatInputAccountCode, _docSetup!.vatInputAccountName),
            isEnglish ? 'Input VAT' : 'ภาษีซื้อ', _vatFc, 0);
      }
      final payableAcct = _pettyCashAcctCodeName();
      addLine(payableAcct, isEnglish ? 'Petty cash voucher' : 'เบิกเงินสดย่อย', 0, _totalAmountFc);
    } else if (_isTransfer) {
      addLine(_bankAcctCodeName(_toBankAccountId), isEnglish ? 'Transfer in' : 'รับโอนเข้า', _totalAmountFc, 0);
      addLine(_bankAcctCodeName(_fromBankAccountId), isEnglish ? 'Transfer out' : 'โอนออก', 0, _totalAmountFc);
    } else if (_isBankCharge || _isInterest) {
      final isIncome = _chargeType == 'INTEREST_INCOME';
      // ดอกเบี้ยรับใช้บัญชีรายได้ ดอกเบี้ยจ่าย/ค่าธรรมเนียมใช้บัญชีค่าใช้จ่าย (เหมือน backend)
      final offsetAcct = _glAccountId != null
          ? _acctCodeName(_glAccountId)
          : isIncome
              ? _setupAcctCodeName(_docSetup!.revenueAccountId, _docSetup!.revenueAccountCode, _docSetup!.revenueAccountName)
              : _setupAcctCodeName(_docSetup!.expenseAccountId, _docSetup!.expenseAccountCode, _docSetup!.expenseAccountName);
      final bankAcct = _bankAcctCodeName(_bankAccountId);
      final label = _isInterest
          ? (isIncome ? (isEnglish ? 'Interest income' : 'ดอกเบี้ยรับ') : (isEnglish ? 'Interest expense' : 'ดอกเบี้ยจ่าย'))
          : (isEnglish ? 'Bank charge' : 'ค่าธรรมเนียมธนาคาร');
      if (isIncome) {
        addLine(bankAcct, label, _totalAmountFc - _whtFc, 0);
        if (_whtFc != 0) {
          addLine(_setupAcctCodeName(_docSetup!.whtPrepaidAccountId, _docSetup!.whtPrepaidAccountCode, _docSetup!.whtPrepaidAccountName),
              isEnglish ? 'WHT deducted by bank' : 'ภาษีถูกหัก ณ ที่จ่าย', _whtFc, 0);
        }
        addLine(offsetAcct, label, 0, _totalAmountFc);
      } else if (_isBankCharge) {
        addLine(offsetAcct, label, _subtotalFc, 0);
        if (_vatFc != 0) {
          addLine(_setupAcctCodeName(_docSetup!.vatInputAccountId, _docSetup!.vatInputAccountCode, _docSetup!.vatInputAccountName),
              isEnglish ? 'Input VAT' : 'ภาษีซื้อ', _vatFc, 0);
        }
        addLine(bankAcct, label, 0, _totalAmountFc);
      } else {
        addLine(offsetAcct, label, _totalAmountFc, 0);
        addLine(bankAcct, label, 0, _totalAmountFc);
      }
    }
    return lines;
  }

  Widget _buildGlSection() {
    final isEnglish = _isEnglish;
    final totalDebit = _glEditRows.fold(0.0, (s, r) => s + r.debit);
    final totalCredit = _glEditRows.fold(0.0, (s, r) => s + r.credit);
    final isBalanced = _glEditRows.isEmpty || (totalDebit - totalCredit).abs() < 0.005;
    final hasFc = _glEditRows.any((r) => r.debitFc > 0 || r.creditFc > 0);
    final lcLabel = _currencies.cast<Currency?>()
        .firstWhere((c) => c!.baseCurrencyFlag, orElse: () => null)?.currencyCode ?? CurrencyService.baseCode;
    final fcLabel = _selectedCurrency?.currencyCode ?? 'FC';
    final activeDims = _dimTypes.where((t) => t.slotNo >= 1 && t.slotNo <= 5).toList();
    const double wDim = 130;

    final posted = _status == 'Posted';
    return _card(
      _isReadOnlyView
          ? (isEnglish ? 'GL Entries of Source Document' : 'รายการบัญชีของเอกสารต้นทาง')
          : posted
              ? (isEnglish ? 'GL Entries (Posted)' : 'รายการบัญชี (Posted)')
              : (isEnglish ? 'GL Preview (Draft)' : 'ตัวอย่างรายการบัญชี (Draft)'),
      chips: [
        if (!_glLoading && _glEditRows.isNotEmpty) ...[
          isBalanced
              ? _chip(isEnglish ? 'Balanced' : 'สมดุล', const Color(0xFF1E6B3A), const Color(0xFFE6F4EA))
              : _chip(isEnglish ? 'Unbalanced' : 'ไม่สมดุล', const Color(0xFFB71C1C), const Color(0xFFFDECEA)),
          Text('Dr ${_fmt.format(totalDebit)} · Cr ${_fmt.format(totalCredit)}', style: _numStyle.copyWith(fontSize: 12, color: _ink2)),
        ],
      ],
      actions: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 10), foregroundColor: Colors.blueGrey.shade800),
          icon: Icon(_glExpanded ? Icons.expand_less : Icons.expand_more, size: 18),
          label: Text(_glExpanded ? (isEnglish ? 'Collapse' : 'ย่อ') : (isEnglish ? 'Expand' : 'ขยาย'), style: const TextStyle(fontSize: 12)),
          onPressed: () => setState(() => _glExpanded = !_glExpanded),
        ),
      ],
      [
        if (_glExpanded) ...[
        if (_glLoading)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (_docSetup == null && _status != 'Posted')
          Padding(padding: const EdgeInsets.all(12), child: Text(
              isEnglish ? 'GL account setup for this document type is not configured yet' : 'ยังไม่ได้ตั้งค่าบัญชี GL สำหรับประเภทเอกสารนี้',
              style: TextStyle(color: Colors.orange[800])))
        else if (_glEditRows.isEmpty)
          Padding(padding: const EdgeInsets.all(12), child: Text(isEnglish ? 'Enter data above to preview the journal entry' : 'กรอกข้อมูลด้านบนเพื่อดูตัวอย่างรายการบัญชี'))
        else
          Column(children: [
            Row(children: [
              SizedBox(width: 90, child: Text(isEnglish ? 'Account' : 'รหัสบัญชี', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text(isEnglish ? 'Account Name' : 'ชื่อบัญชี', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text(isEnglish ? 'Description' : 'รายละเอียด', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              if (hasFc) ...[
                SizedBox(width: 100, child: Text('${isEnglish ? 'Debit' : 'เดบิต'} ($fcLabel)', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                SizedBox(width: 100, child: Text('${isEnglish ? 'Credit' : 'เครดิต'} ($fcLabel)', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
              SizedBox(width: 100, child: Text('${isEnglish ? 'Debit' : 'เดบิต'} ($lcLabel)', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              SizedBox(width: 100, child: Text('${isEnglish ? 'Credit' : 'เครดิต'} ($lcLabel)', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              for (final dt in activeDims)
                SizedBox(width: wDim, child: Text(isEnglish && (dt.nameEng ?? '').isNotEmpty ? dt.nameEng! : dt.nameThai,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis)),
            ]),
            const Divider(),
            ..._glEditRows.map((r) {
              final hasErr = r.acctCodeCtrl.text.startsWith('!');
              return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
                SizedBox(width: 90, child: Text(r.acctCodeCtrl.text, style: TextStyle(fontSize: 12, color: hasErr ? Colors.red : null), overflow: TextOverflow.ellipsis)),
                Expanded(flex: 2, child: Text(r.accountName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                Expanded(flex: 2, child: Text(r.descCtrl.text, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                if (hasFc) ...[
                  SizedBox(width: 100, child: Text(r.debitFc > 0 ? _fmt.format(r.debitFc) : '', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: Colors.blue[700]))),
                  SizedBox(width: 100, child: Text(r.creditFc > 0 ? _fmt.format(r.creditFc) : '', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: Colors.red[700]))),
                ],
                SizedBox(width: 100, child: Text(r.debit > 0 ? _fmt.format(r.debit) : '', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: Colors.blue[800]))),
                SizedBox(width: 100, child: Text(r.credit > 0 ? _fmt.format(r.credit) : '', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: Colors.red[800]))),
                for (final dt in activeDims)
                  SizedBox(width: wDim, child: GlDimensionPickerField(
                    dimType: dt, values: _dimValues[dt.typeCode] ?? [],
                    selected: () {
                      final vid = r.dimIds[dt.slotNo];
                      if (vid == null) return null;
                      final vals = _dimValues[dt.typeCode] ?? [];
                      try { return vals.firstWhere((v) => v.id == vid); } catch (_) { return null; }
                    }(),
                    readOnly: true, isDense: true,
                    onSelected: (_) {},
                  )),
              ]));
            }),
            const Divider(),
            Row(children: [
              const SizedBox(width: 90),
              Expanded(flex: 2, child: Text(isEnglish ? 'Total' : 'รวม', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              const Expanded(flex: 2, child: SizedBox()),
              if (hasFc) ...[
                SizedBox(width: 100, child: Text(_fmt.format(_glEditRows.fold(0.0, (s, r) => s + r.debitFc)), textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue[700]))),
                SizedBox(width: 100, child: Text(_fmt.format(_glEditRows.fold(0.0, (s, r) => s + r.creditFc)), textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red[700]))),
              ],
              SizedBox(width: 100, child: Text(_fmt.format(totalDebit), textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue[800]))),
              SizedBox(width: 100, child: Text(_fmt.format(totalCredit), textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red[800]))),
              for (final dt in activeDims) SizedBox(key: ValueKey('gltot_${dt.slotNo}'), width: wDim),
            ]),
          ]),
        if (_status != 'Posted' && !_glLoading && _glEditRows.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(isEnglish ? '* Accounts come from the document type\'s GL account setup (revenue/expense accounts can be chosen on each item line) and dimensions follow the header selection — the entry is recalculated on Post' : '* รหัสบัญชีกำหนดจากการตั้งค่ารหัสบัญชีของประเภทเอกสาร (บัญชีรายได้/ค่าใช้จ่ายเลือกได้ที่แต่ละบรรทัดของรายการ) และมิติใช้ตามที่เลือกที่หัวเอกสาร — ระบบคำนวณรายการบัญชีใหม่ตอน Post',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.blueGrey.shade600)),
          ),
        ],
      ],
    );
  }
}

class _HScrollBox extends StatefulWidget {
  final double width;
  final Widget child;
  const _HScrollBox({required this.width, required this.child});

  @override
  State<_HScrollBox> createState() => _HScrollBoxState();
}

class _HScrollBoxState extends State<_HScrollBox> {
  final ScrollController _ctrl = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
        controller: _ctrl,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _ctrl,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(width: widget.width, child: widget.child),
        ),
      );
}
