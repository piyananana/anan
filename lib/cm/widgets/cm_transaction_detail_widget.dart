import 'package:flutter/material.dart';
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
import '../services/cm_checkbook_service.dart';

class CmTransactionDetailWidget extends StatefulWidget {
  final int? transactionId;
  final int? initialSysDocType; // จำเป็นสำหรับแยกแยะ 15/25 (อ่านจาก cm_receipt/cm_payment แทน cm_transaction)
  final bool viewOnly;
  final int resetKey;
  final VoidCallback onSaveSuccess;
  final VoidCallback onCancel;
  final bool canDelete;

  const CmTransactionDetailWidget({
    super.key,
    this.transactionId,
    this.initialSysDocType,
    this.viewOnly = false,
    this.resetKey = 0,
    required this.onSaveSuccess,
    required this.onCancel,
    this.canDelete = true,
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

class _CmTransactionDetailWidgetState extends State<CmTransactionDetailWidget> {
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
    _initMasterData();
  }

  @override
  void dispose() {
    _refNoCtrl.dispose();
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
    if (widget.transactionId != old.transactionId ||
        widget.viewOnly != old.viewOnly ||
        widget.resetKey != old.resetKey) {
      _loadTransactionData().then((_) { if (mounted) _loadDocSetup(); });
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
        setState(() { _legacyRow = row; _isReadOnlyView = true; });
        return;
      }
      if (widget.initialSysDocType == cmDocTypePaymentFromAp) {
        final row = await _service.fetchPaymentView(widget.transactionId!);
        setState(() { _legacyRow = row; _isReadOnlyView = true; });
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

        if (_allowedDocTypes.isNotEmpty) {
          try { _selectedDocType = _allowedDocTypes.firstWhere((d) => d.id == h.docId); } catch (_) {}
        }

        for (final r in _detailRows) r.dispose();
        _detailRows = data.details.map((d) => _DetailRow.fromModel(d)).toList();

        for (final r in _paymentRows) r.dispose();
        _paymentRows = data.payments.map((p) => _PaymentRow.fromModel(p)).toList();

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
      for (final r in _detailRows) r.dispose(); _detailRows = [];
      for (final r in _paymentRows) r.dispose(); _paymentRows = [];
      for (final r in _glEditRows) r.dispose(); _glEditRows = [];
      _applyRows = [];
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

    setState(() => _isLoading = true);
    try {
      if (_transactionId == 0) {
        await _service.createTransaction(header: header, details: details, applies: applies, payments: payments, whts: whts, action: action);
      } else {
        await _service.updateTransaction(id: _transactionId, header: header, details: details, applies: applies, payments: payments, whts: whts, action: action);
      }
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

  InputDecoration _fieldDeco(String label, {bool forcedReadOnly = false}) {
    final isRO = _isReadOnly || forcedReadOnly;
    return InputDecoration(
      labelText: label, border: const OutlineInputBorder(), isDense: true,
      filled: true, fillColor: isRO ? Colors.grey[100] : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    );
  }

  MaterialColor _statusBadgeColor(String s) {
    switch (s) {
      case 'Posted': return Colors.green;
      case 'Void':   return Colors.red;
      case 'Submitted': return Colors.orange;
      case 'Approved':  return Colors.blue;
      default:       return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_isReadOnlyView) return _buildReadOnlyView();
    return Form(
      key: _formKey,
      child: Column(children: [
        _buildActionButtons(),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            if (_reverseHistory.isNotEmpty) ...[
              DocReverseHistoryPanel(
                  history: _reverseHistory, isDeleted: _status == 'Deleted', isEnglish: isEnglish,
                  margin: EdgeInsets.zero),
              const SizedBox(height: 8),
            ],
            if (_approvals.isNotEmpty)
              DocApprovalPanel(
                docNo: _docNo,
                approvals: _approvals,
                approvalMode: _approvalMode,
                awaiting: _status == 'Submitted',
                onApprove: (r) => _service.approveTransaction(_transactionId, remarks: r),
                onReject: (r) => _service.rejectTransaction(_transactionId, remarks: r),
                onDone: () async => widget.onSaveSuccess(),
              ),
            _buildHeaderSection(),
            if (_hasPartySection) ...[const SizedBox(height: 8), _buildPartySection()],
            if (_hasDetailRows) ...[const SizedBox(height: 8), _buildDetailSection()],
            if (_hasWhtSection) ...[const SizedBox(height: 8), _buildWhtSection()],
            if (_hasApplySection) ...[const SizedBox(height: 8), _buildApplySection()],
            if (_hasPaymentSection) ...[const SizedBox(height: 8), _buildPaymentSection()],
            const SizedBox(height: 8),
            _buildTotalsRow(),
            if (_selectedDocType != null) ...[
              const SizedBox(height: 8),
              _buildGlSection(),
            ],
          ]),
        )),
      ]),
    );
  }

  // ── Read-only view สำหรับ 15 (รายรับจาก AR) / 25 (รายจ่ายจาก AP) ─────────────
  Widget _buildReadOnlyView() {
    final isEnglish = _isEnglish;
    final r = _legacyRow;
    return Column(children: [
      Container(
        color: Colors.blue[50],
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          Icon(Icons.visibility_outlined, size: 16, color: Colors.blue[800]),
          const SizedBox(width: 6),
          Text(isEnglish ? 'Read-only — created automatically by AR/AP posting' : 'อ่านอย่างเดียว — สร้างอัตโนมัติจากการ Post ฝั่ง AR/AP',
              style: TextStyle(fontSize: 12, color: Colors.blue[800])),
          const Spacer(),
          TextButton(onPressed: widget.onCancel, child: Text(isEnglish ? 'Back' : 'กลับ')),
        ]),
      ),
      if (r != null)
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.docNo ?? '#${r.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              _roLine(isEnglish ? 'Date' : 'วันที่', r.date != null ? _dateFmt.format(r.date!) : '-'),
              _roLine(isEnglish ? 'Counterparty' : 'คู่ค้า', r.counterpartyName ?? '-'),
              _roLine(isEnglish ? 'Amount' : 'จำนวนเงิน', '${_fmt.format(r.amountLc)} ${r.currencyCode}'),
              _roLine(isEnglish ? 'Payment Method' : 'ช่องทาง', r.paymentMethodType ?? '-'),
              if ((r.checkNo ?? '').isNotEmpty) _roLine(isEnglish ? 'Check No.' : 'เลขที่เช็ค', r.checkNo!),
              _roLine(isEnglish ? 'Status' : 'สถานะ', r.status),
              if ((r.clearingNote ?? '').isNotEmpty) _roLine(isEnglish ? 'Note' : 'หมายเหตุ', r.clearingNote!),
            ]),
          )),
        )),
    ]);
  }

  Widget _roLine(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 140, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ]),
      );

  Widget _buildActionButtons() {
    final isEnglish = _isEnglish;
    final isDraft = _status == 'Draft';
    final isPosted = _status == 'Posted';
    final canEditNow = !widget.viewOnly && isDraft;
    return Container(
      color: Colors.blue[50],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        if (canEditNow) ...[
          ElevatedButton.icon(
            onPressed: () => _save('Draft'),
            icon: const Icon(Icons.save_outlined, size: 16),
            label: Text(isEnglish ? 'Save Draft' : 'บันทึก Draft'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700], foregroundColor: Colors.white),
          ),
          const SizedBox(width: 8),
          // 20/30/40/50 ต้องส่งขออนุมัติก่อน (บันทึกร่างก่อน) — Post ได้หลังอนุมัติแล้วเท่านั้น
          if (!_requiresApproval) ...[
            ElevatedButton.icon(
              onPressed: () => _save('Post'),
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: Text(isEnglish ? 'Post Document' : 'Post เอกสาร'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          if (_requiresApproval && _transactionId != 0) ...[
            OutlinedButton.icon(
              onPressed: _submitForApproval,
              icon: const Icon(Icons.how_to_reg_outlined, size: 16),
              label: Text(isEnglish ? 'Request Approval' : 'ขออนุมัติ'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.orange[800]),
            ),
            const SizedBox(width: 8),
          ],
          if (_transactionId != 0 && widget.canDelete)
            OutlinedButton.icon(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline, size: 16),
              label: Text(isEnglish ? 'Delete' : 'ลบ'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            ),
        ],
        if (_status == 'Approved' && !widget.viewOnly) ...[
          ElevatedButton.icon(
            onPressed: _postApproved,
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: Text(isEnglish ? 'Post Document' : 'Post เอกสาร'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
          ),
          const SizedBox(width: 8),
        ],
        if ((_status == 'Submitted' || _status == 'Approved') && widget.canDelete && !widget.viewOnly) ...[
          ElevatedButton.icon(
            onPressed: _reverse,
            icon: const Icon(Icons.undo, size: 16),
            label: Text(isEnglish ? 'Reverse to Draft' : 'ถอยเป็นร่าง'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white),
          ),
          const SizedBox(width: 8),
        ],
        if (isPosted && widget.canDelete && !widget.viewOnly) ...[
          Builder(builder: (_) {
            final blockMsg = _reverseBlockMessage(isEnglish);
            final btn = ElevatedButton.icon(
              onPressed: blockMsg == null ? _reverse : null,
              icon: Icon(blockMsg == null ? Icons.undo : Icons.lock_outline, size: 16),
              label: Text(isEnglish ? 'Reverse to Draft' : 'ถอยเป็นร่าง'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white),
            );
            return blockMsg == null ? btn : Tooltip(message: blockMsg, child: btn);
          }),
          const SizedBox(width: 8),
        ],
        if (isPosted && widget.canDelete)
          Builder(builder: (_) {
            final blockMsg = _voidBlockMessage(isEnglish);
            final btn = ElevatedButton.icon(
              onPressed: blockMsg == null ? _void : null,
              icon: Icon(blockMsg == null ? Icons.cancel_outlined : Icons.lock_outline, size: 16),
              label: Text(isEnglish ? 'Void' : 'ยกเลิก (Void)'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
            );
            return blockMsg == null ? btn : Tooltip(message: blockMsg, child: btn);
          }),
        const Spacer(),
        TextButton(onPressed: widget.onCancel, child: Text(isEnglish ? 'Back' : 'กลับ')),
      ]),
    );
  }

  Widget _buildHeaderSection() {
    final isEnglish = _isEnglish;
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.article_outlined, size: 18),
          const SizedBox(width: 6),
          Text(isEnglish ? 'Document Header' : 'ข้อมูลหัวเอกสาร', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          if (_status != 'Draft') ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _statusBadgeColor(_status).withOpacity(0.1),
                border: Border.all(color: _statusBadgeColor(_status)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(cmTransactionStatusLabel(_status, isEnglish),
                  style: TextStyle(color: _statusBadgeColor(_status).shade800, fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(flex: 2, child: DropdownButtonFormField<ModuleDocument>(
            value: _selectedDocType,
            isExpanded: true,
            decoration: _fieldDeco(isEnglish ? 'Document Type *' : 'ประเภทเอกสาร *'),
            items: _allowedDocTypes.map((d) => DropdownMenuItem(
              value: d,
              child: Text('${d.docCode} ${_docTypeLabel(d)}', overflow: TextOverflow.ellipsis),
            )).toList(),
            onChanged: _isReadOnly ? null : (v) {
              final newDocType = v;
              _resetForm();
              setState(() => _selectedDocType = newDocType);
              _loadDocSetup();
            },
            validator: (v) => v == null ? (isEnglish ? 'Please select' : 'กรุณาเลือก') : null,
          )),
          const SizedBox(width: 8),
          Expanded(flex: 1, child: TextFormField(
            key: ValueKey('cm_docNo_${widget.resetKey}_$_transactionId'),
            initialValue: _docNo == 'AUTO' ? '' : _docNo,
            decoration: _fieldDeco(
              _selectedDocType?.isAutoNumbering == true ? (isEnglish ? 'Auto Number' : 'เลขที่อัตโนมัติ') : (isEnglish ? 'Document No.' : 'เลขที่เอกสาร'),
              forcedReadOnly: _selectedDocType?.isAutoNumbering == true,
            ).copyWith(hintText: _selectedDocType?.isAutoNumbering == true ? (isEnglish ? '(Auto-assigned)' : '(อัตโนมัติ)') : null),
            readOnly: _isReadOnly || (_selectedDocType?.isAutoNumbering == true),
            onChanged: (v) => _docNo = v.isEmpty ? 'AUTO' : v,
          )),
          const SizedBox(width: 8),
          Expanded(flex: 1, child: InkWell(
            onTap: _isReadOnly ? null : _selectDate,
            child: InputDecorator(
              decoration: _fieldDeco(isEnglish ? 'Document Date *' : 'วันที่เอกสาร *'),
              child: Row(children: [
                Expanded(child: Text(_dateFmt.format(_docDate))),
                if (!_isReadOnly) const Icon(Icons.calendar_today, size: 14),
              ]),
            ),
          )),
          const SizedBox(width: 8),
          Expanded(flex: 1, child: TextFormField(
            controller: _refNoCtrl,
            decoration: _fieldDeco(isEnglish ? 'Reference No.' : 'เลขที่อ้างอิง'),
            readOnly: _isReadOnly,
          )),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(flex: 1, child: DropdownButtonFormField<Currency>(
            value: _selectedCurrency,
            isExpanded: true,
            decoration: _fieldDeco(isEnglish ? 'Currency' : 'สกุลเงิน'),
            items: _currencies.map((c) => DropdownMenuItem(
              value: c,
              child: Text('${c.currencyCode} - ${_currencyLabel(c)}', overflow: TextOverflow.ellipsis),
            )).toList(),
            onChanged: _isReadOnly ? null : (v) {
              setState(() { _selectedCurrency = v; _exchangeRate = v?.baseRate ?? 1.0; });
              _recalcTotals();
            },
          )),
          const SizedBox(width: 8),
          Expanded(flex: 1, child: TextFormField(
            key: ValueKey('cm_rate_${widget.resetKey}_$_transactionId'),
            initialValue: _exchangeRate.toStringAsFixed(6),
            decoration: _fieldDeco(isEnglish ? 'Exchange Rate' : 'อัตราแลกเปลี่ยน'),
            keyboardType: TextInputType.number,
            readOnly: _isReadOnly,
            onChanged: (v) { _exchangeRate = double.tryParse(v) ?? 1.0; _recalcTotals(); },
          )),
          const Expanded(flex: 2, child: SizedBox()),
        ]),
        if (_dimTypes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(children: [
            ..._dimTypes.expand((t) {
              final vals = _dimValues[t.typeCode] ?? [];
              final selId = _dimSelections[t.slotNo];
              final selVal = vals.cast<GlDimensionValue?>().firstWhere((v) => v?.id == selId, orElse: () => null);
              return [
                if (_dimTypes.first != t) const SizedBox(width: 8),
                Expanded(flex: 1, child: GlDimensionPickerField(
                  dimType: t, values: vals, selected: selVal, readOnly: _isReadOnly, isDense: false,
                  onSelected: (val) => setState(() { _dimSelections[t.slotNo] = val?.id; _dimNames[t.slotNo] = val?.valueNameThai; }),
                )),
              ];
            }),
          ]),
        ],
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_hasCounterparty)
            Expanded(flex: 2, child: TextFormField(
              controller: _counterpartyCtrl,
              decoration: _fieldDeco(isEnglish ? 'Counterparty (payee/payer)' : 'ชื่อคู่ค้า (ผู้รับ/ผู้จ่ายเงิน)'),
              readOnly: _isReadOnly,
            )),
          if (_hasPettyCashAccountField)
            Expanded(flex: 2, child: DropdownButtonFormField<int?>(
              value: _bankAccountId,
              isExpanded: true,
              decoration: _fieldDeco(isEnglish ? 'Petty Cash Account *' : 'บัญชีเงินสดย่อย *'),
              items: _bankAccounts.where((b) => b.cmType == 'PETTY_CASH').map((b) => DropdownMenuItem(
                    value: b.id, child: Text(_bankAcctLabel(b), overflow: TextOverflow.ellipsis))).toList(),
              onChanged: _isReadOnly ? null : (v) {
                setState(() => _bankAccountId = v);
                if (_isReplenishment && v != null) _loadOpenVouchers(v);
              },
              validator: (v) => v == null ? (isEnglish ? 'Required' : 'กรุณาเลือก') : null,
            )),
          if (_hasTransferFields) ...[
            Expanded(flex: 2, child: DropdownButtonFormField<int?>(
              value: _fromBankAccountId,
              isExpanded: true,
              decoration: _fieldDeco(isEnglish ? 'From Account *' : 'บัญชีต้นทาง *'),
              items: _bankAccounts.where((b) => b.cmType == 'BANK').map((b) => DropdownMenuItem(
                    value: b.id, child: Text(_bankAcctLabel(b), overflow: TextOverflow.ellipsis))).toList(),
              onChanged: _isReadOnly ? null : (v) => setState(() => _fromBankAccountId = v),
              validator: (v) => v == null ? (isEnglish ? 'Required' : 'กรุณาเลือก') : null,
            )),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: DropdownButtonFormField<int?>(
              value: _toBankAccountId,
              isExpanded: true,
              decoration: _fieldDeco(isEnglish ? 'To Account *' : 'บัญชีปลายทาง *'),
              items: _bankAccounts.where((b) => b.cmType == 'BANK').map((b) => DropdownMenuItem(
                    value: b.id, child: Text(_bankAcctLabel(b), overflow: TextOverflow.ellipsis))).toList(),
              onChanged: _isReadOnly ? null : (v) => setState(() => _toBankAccountId = v),
              validator: (v) => v == null ? (isEnglish ? 'Required' : 'กรุณาเลือก') : null,
            )),
          ],
          if (_hasBankChargeFields) ...[
            Expanded(flex: 2, child: DropdownButtonFormField<int?>(
              value: _bankAccountId,
              isExpanded: true,
              decoration: _fieldDeco(isEnglish ? 'Bank Account *' : 'บัญชีธนาคาร *'),
              items: _bankAccounts.where((b) => b.cmType == 'BANK').map((b) => DropdownMenuItem(
                    value: b.id, child: Text(_bankAcctLabel(b), overflow: TextOverflow.ellipsis))).toList(),
              onChanged: _isReadOnly ? null : (v) => setState(() {
                _bankAccountId = v;
                if (_isBankCharge && _chargeVatType != 'NOVAT') _fillBankSeller();
              }),
              validator: (v) => v == null ? (isEnglish ? 'Required' : 'กรุณาเลือก') : null,
            )),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: DropdownButtonFormField<int?>(
              value: _glAccountId,
              isExpanded: true,
              // ไม่บังคับ — ว่างไว้จะใช้บัญชีจากการตั้งค่า (ดอกเบี้ยรับ → ช่องดอกเบี้ยรับ, ดอกเบี้ยจ่าย → ช่องดอกเบี้ยจ่าย)
              decoration: _fieldDeco(isEnglish
                  ? '${!_isInterest ? 'Expense Account' : _chargeType == 'INTEREST_INCOME' ? 'Interest Income Account' : 'Interest Expense Account'} (blank = setup)'
                  : '${!_isInterest ? 'บัญชีค่าใช้จ่าย' : _chargeType == 'INTEREST_INCOME' ? 'บัญชีดอกเบี้ยรับ' : 'บัญชีดอกเบี้ยจ่าย'} (ว่าง = ตามการตั้งค่า)'),
              items: _accounts.map((a) => DropdownMenuItem(
                    value: a.id, child: Text('${a.accountCode} ${_acctLabel(a)}', overflow: TextOverflow.ellipsis))).toList(),
              onChanged: _isReadOnly ? null : (v) => setState(() => _glAccountId = v),
            )),
            if (_isInterest) ...[
              const SizedBox(width: 8),
              Expanded(flex: 2, child: DropdownButtonFormField<String?>(
                value: _chargeType,
                isExpanded: true,
                decoration: _fieldDeco(isEnglish ? 'Direction *' : 'ประเภทดอกเบี้ย *'),
                items: [
                  DropdownMenuItem(value: 'INTEREST_INCOME', child: Text(isEnglish ? 'Interest Income' : 'ดอกเบี้ยรับ')),
                  DropdownMenuItem(value: 'INTEREST_EXPENSE', child: Text(isEnglish ? 'Interest Expense' : 'ดอกเบี้ยจ่าย')),
                ],
                onChanged: _isReadOnly ? null : (v) { setState(() => _chargeType = v); _recalcTotals(); },
                validator: (v) => v == null ? (isEnglish ? 'Required' : 'กรุณาเลือก') : null,
              )),
            ],
          ],
        ]),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descCtrl,
          decoration: _fieldDeco(isEnglish ? 'Description' : 'คำอธิบาย'),
          readOnly: _isReadOnly,
        ),
        if (_hasSingleAmountField) ...[
          const SizedBox(height: 12),
          SizedBox(width: 240, child: TextFormField(
            controller: _amountCtrl,
            decoration: _fieldDeco(isEnglish ? 'Amount *' : 'จำนวนเงิน *'),
            keyboardType: TextInputType.number,
            readOnly: _isReadOnly,
            onChanged: (v) {
              // ดอกเบี้ยรับ: ภาษีถูกหักตามอัตราที่กรอกไว้
              final r = double.tryParse(_intWhtRateCtrl.text);
              if (_isInterestIncome && r != null) _intWhtCtrl.text = ((double.tryParse(v) ?? 0) * r / 100).toStringAsFixed(2);
              _recalcTotals();
            },
            validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? (isEnglish ? 'Enter an amount' : 'กรุณาระบุจำนวนเงิน') : null,
          )),
        ],
        if (_isBankCharge) ...[
          const SizedBox(height: 12),
          Row(children: [
            SizedBox(width: 240, child: DropdownButtonFormField<String>(
              value: _vatRates.any((v) => v.vatCode == _chargeVatType) || _chargeVatType == 'NOVAT' ? _chargeVatType : 'NOVAT',
              isExpanded: true,
              decoration: _fieldDeco(isEnglish ? 'VAT on the charge' : 'VAT ของค่าธรรมเนียม'),
              items: [
                if (!_vatRates.any((v) => v.vatCode == 'NOVAT'))
                  DropdownMenuItem(value: 'NOVAT', child: Text(isEnglish ? 'No VAT' : 'ไม่มี VAT')),
                ..._vatRates.map((v) => DropdownMenuItem(
                      value: v.vatCode,
                      child: Text('${v.vatCode} ${v.rate.toStringAsFixed(v.rate % 1 == 0 ? 0 : 2)}%', overflow: TextOverflow.ellipsis))),
              ],
              onChanged: _isReadOnly ? null : (code) {
                final vr = _vatRates.cast<VatRate?>().firstWhere((v) => v?.vatCode == code, orElse: () => null);
                setState(() {
                  _chargeVatType = code ?? 'NOVAT';
                  _chargeVatRate = _chargeVatType == 'NOVAT' ? 0 : (vr?.rate ?? 0);
                  // ผู้ขาย = ธนาคารของบัญชีที่เลือก
                  if (_chargeVatType != 'NOVAT') _fillBankSeller();
                });
                _recalcTotals();
              },
            )),
            const SizedBox(width: 12),
            Checkbox(
              value: _priceIncludesVat,
              visualDensity: VisualDensity.compact,
              onChanged: _isReadOnly ? null : (v) { setState(() => _priceIncludesVat = v ?? false); _recalcTotals(); },
            ),
            Text(isEnglish ? 'Amount includes VAT' : 'จำนวนเงินรวม VAT', style: const TextStyle(fontSize: 13)),
          ]),
          if (_chargeVatType != 'NOVAT') ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(flex: 3, child: TextFormField(
                controller: _counterpartyCtrl,
                decoration: _fieldDeco(isEnglish ? 'Bank (seller) *' : 'ชื่อธนาคาร (ผู้ขาย) *', forcedReadOnly: _bankHasTaxId),
                readOnly: _isReadOnly || _bankHasTaxId,
              )),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: TextFormField(
                controller: _partyTaxIdCtrl,
                decoration: _fieldDeco(isEnglish ? 'Tax ID *' : 'เลขผู้เสียภาษี *', forcedReadOnly: _bankHasTaxId),
                readOnly: _isReadOnly || _bankHasTaxId,
              )),
              const SizedBox(width: 8),
              Expanded(flex: 1, child: TextFormField(
                controller: _partyBranchCtrl,
                decoration: _fieldDeco(isEnglish ? 'Branch' : 'สาขา', forcedReadOnly: _bankHasTaxId),
                readOnly: _isReadOnly || _bankHasTaxId,
              )),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: TextFormField(
                controller: _taxInvNoCtrl,
                decoration: _fieldDeco(isEnglish ? 'Tax Invoice No. *' : 'เลขที่ใบกำกับ *'),
                readOnly: _isReadOnly,
              )),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: InkWell(
                onTap: _isReadOnly ? null : () async {
                  final d = await showDatePicker(context: context, initialDate: _taxInvDate ?? _docDate,
                      firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (d != null) setState(() => _taxInvDate = d);
                },
                child: InputDecorator(
                  decoration: _fieldDeco(isEnglish ? 'Invoice Date' : 'วันที่ใบกำกับ'),
                  child: Text(_taxInvDate != null ? _dateFmt.format(_taxInvDate!) : (isEnglish ? '(doc date)' : '(วันที่เอกสาร)'),
                      style: TextStyle(color: _taxInvDate == null ? Colors.grey[500] : null)),
                ),
              )),
            ]),
          ],
        ],
        if (_isInterestIncome) ...[
          const SizedBox(height: 12),
          Row(children: [
            SizedBox(width: 160, child: TextFormField(
              controller: _intWhtRateCtrl,
              decoration: _fieldDeco(isEnglish ? 'WHT rate (%)' : 'อัตราภาษีถูกหัก (%)'),
              keyboardType: TextInputType.number,
              readOnly: _isReadOnly,
              onChanged: (v) {
                final amt = double.tryParse(_amountCtrl.text) ?? 0;
                _intWhtCtrl.text = (amt * (double.tryParse(v) ?? 0) / 100).toStringAsFixed(2);
                _recalcTotals();
              },
            )),
            const SizedBox(width: 12),
            SizedBox(width: 240, child: TextFormField(
              controller: _intWhtCtrl,
              decoration: _fieldDeco(isEnglish ? 'WHT deducted by bank' : 'ภาษีถูกหัก ณ ที่จ่าย'),
              keyboardType: TextInputType.number,
              readOnly: _isReadOnly,
              onChanged: (_) => _recalcTotals(),
            )),
            const SizedBox(width: 12),
            Expanded(child: Text(isEnglish
                ? 'Enter the full interest amount above; the bank account receives the net amount'
                : 'กรอกดอกเบี้ยเต็มจำนวนในช่องจำนวนเงิน — บัญชีธนาคารได้รับยอดสุทธิหลังหักภาษี',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
          ]),
        ],
      ]),
    ));
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

  Widget _buildPartySection() {
    final isEnglish = _isEnglish;
    final fromMaster = _partySource != null;
    final ro = _isReadOnly || fromMaster;
    return Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.person_outline, size: 18),
          const SizedBox(width: 6),
          Text(_isReceipt ? (isEnglish ? 'Payer' : 'ผู้จ่ายเงิน') : (isEnglish ? 'Payee' : 'ผู้รับเงิน'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          if (fromMaster) ...[
            const SizedBox(width: 8),
            Text(_partySource == 'AR'
                    ? (isEnglish ? '(from customer ${_partyCode ?? ''})' : '(จากข้อมูลลูกค้า ${_partyCode ?? ''})')
                    : (isEnglish ? '(from vendor ${_partyCode ?? ''})' : '(จากข้อมูลผู้ขาย ${_partyCode ?? ''})'),
                style: TextStyle(fontSize: 12, color: Colors.blue[700])),
          ],
          const Spacer(),
          if (!_isReadOnly) TextButton.icon(
            onPressed: _isReceipt ? _pickCustomer : _pickVendor,
            icon: const Icon(Icons.search, size: 16),
            label: Text(_isReceipt
                ? (isEnglish ? 'Select customer' : 'ค้นหาจากลูกค้า')
                : (isEnglish ? 'Select vendor' : 'ค้นหาจากผู้ขาย')),
          ),
          if (!_isReadOnly && fromMaster) TextButton.icon(
            onPressed: () => setState(() { _partySource = null; _partyId = null; _partyCode = null; }),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: Text(isEnglish ? 'Type manually' : 'พิมพ์เอง'),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(flex: 3, child: TextFormField(
            controller: _counterpartyCtrl,
            decoration: _fieldDeco(isEnglish ? 'Name' : (_isReceipt ? 'ชื่อผู้จ่ายเงิน' : 'ชื่อผู้รับเงิน'), forcedReadOnly: fromMaster),
            readOnly: ro,
          )),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: TextFormField(
            controller: _partyTaxIdCtrl,
            decoration: _fieldDeco(isEnglish ? 'Tax ID' : 'เลขประจำตัวผู้เสียภาษี', forcedReadOnly: fromMaster),
            readOnly: ro,
          )),
          const SizedBox(width: 8),
          Expanded(flex: 1, child: TextFormField(
            controller: _partyBranchCtrl,
            decoration: _fieldDeco(isEnglish ? 'Branch (00000=HQ)' : 'สาขา (00000=สนญ.)', forcedReadOnly: fromMaster),
            readOnly: ro,
          )),
          const SizedBox(width: 8),
          if (!_isPayment) const Expanded(flex: 2, child: SizedBox()),
          if (_isPayment) Expanded(flex: 2, child: DropdownButtonFormField<String?>(
            value: _partyType == 'individual' || _partyType == 'juristic' ? _partyType : null,
            isExpanded: true,
            decoration: _fieldDeco(isEnglish ? 'Type (PND)' : 'ประเภท (ภ.ง.ด.)', forcedReadOnly: fromMaster),
            items: [
              DropdownMenuItem(value: 'individual', child: Text(isEnglish ? 'Individual (PND 3)' : 'บุคคลธรรมดา (ภ.ง.ด.3)')),
              DropdownMenuItem(value: 'juristic', child: Text(isEnglish ? 'Juristic (PND 53)' : 'นิติบุคคล (ภ.ง.ด.53)')),
            ],
            onChanged: ro ? null : (v) => setState(() => _partyType = v),
          )),
        ]),
        const SizedBox(height: 8),
        TextFormField(
          controller: _partyAddressCtrl,
          decoration: _fieldDeco(isEnglish ? 'Address' : 'ที่อยู่', forcedReadOnly: fromMaster),
          readOnly: ro,
        ),
        if (_isPayment) ...[
        const SizedBox(height: 8),
        Row(children: [
          Expanded(flex: 1, child: TextFormField(
            controller: _taxInvNoCtrl,
            decoration: _fieldDeco(isEnglish ? 'Vendor Tax Invoice No.' : 'เลขที่ใบกำกับภาษี (ผู้ขาย)'),
            readOnly: _isReadOnly,
          )),
          const SizedBox(width: 8),
          Expanded(flex: 1, child: InkWell(
            onTap: _isReadOnly ? null : () async {
              final d = await showDatePicker(context: context, initialDate: _taxInvDate ?? _docDate,
                  firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (d != null) setState(() => _taxInvDate = d);
            },
            child: InputDecorator(
              decoration: _fieldDeco(isEnglish ? 'Tax Invoice Date' : 'วันที่ใบกำกับภาษี'),
              child: Text(_taxInvDate != null ? _dateFmt.format(_taxInvDate!) : (isEnglish ? '(document date)' : '(วันที่เอกสาร)'),
                  style: TextStyle(color: _taxInvDate == null ? Colors.grey[500] : null)),
            ),
          )),
          const Expanded(flex: 2, child: SizedBox()),
        ]),
        ],
      ]),
    ));
  }

  // ── ภาษีหัก ณ ที่จ่าย (20: เราหัก / 10: ผู้จ่ายหักเรา) ────────────────────────────────────────────────
  Widget _buildWhtSection() {
    final isEnglish = _isEnglish;
    return Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.percent, size: 18),
          const SizedBox(width: 6),
          Text(_isReceipt
                  ? (isEnglish ? 'Withholding Tax Deducted by Payer' : 'ภาษีถูกหัก ณ ที่จ่าย')
                  : (isEnglish ? 'Withholding Tax (WHT)' : 'ภาษีหัก ณ ที่จ่าย'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          if (!_isReadOnly) TextButton.icon(
            onPressed: () => setState(() => _whtRows.add(_WhtRow())),
            icon: const Icon(Icons.add, size: 16),
            label: Text(isEnglish ? 'Add WHT' : 'เพิ่มรายการ'),
          ),
        ]),
        if (_whtRows.isEmpty)
          Padding(padding: const EdgeInsets.all(8), child: Text(isEnglish ? 'No WHT items' : 'ไม่มีรายการ', style: const TextStyle(color: Colors.grey)))
        else
          ..._whtRows.asMap().entries.map((e) {
            final i = e.key; final w = e.value;
            final rate = w.whtType?.whtRate ?? 0;
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                Expanded(flex: 3, child: DropdownButtonFormField<CdWhtType?>(
                  value: w.whtType,
                  isExpanded: true,
                  decoration: _fieldDeco(isEnglish ? 'WHT Type' : 'ประเภทเงินได้'),
                  items: [
                    DropdownMenuItem(value: null, child: Text(isEnglish ? '— Select type —' : '— เลือกประเภท —')),
                    ..._whtTypes.map((t) => DropdownMenuItem(
                          value: t,
                          child: Text('${t.whtCode} — ${isEnglish && (t.whtNameEn ?? '').isNotEmpty ? t.whtNameEn! : t.whtName}', overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: _isReadOnly ? null : (t) {
                    setState(() {
                      w.whtType = t;
                      final base = double.tryParse(w.baseCtrl.text) ?? 0;
                      w.whtCtrl.text = (base * (t?.whtRate ?? 0) / 100).toStringAsFixed(2);
                    });
                    _recalcTotals();
                  },
                )),
                const SizedBox(width: 8),
                SizedBox(width: 70, child: InputDecorator(
                  decoration: _fieldDeco(isEnglish ? 'Rate' : 'อัตรา'),
                  child: Text(rate > 0 ? '${rate.toStringAsFixed(2)}%' : '—', textAlign: TextAlign.right),
                )),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: TextFormField(
                  controller: w.baseCtrl,
                  decoration: _fieldDeco(isEnglish ? 'Tax Base' : 'ฐานภาษี'),
                  keyboardType: TextInputType.number, textAlign: TextAlign.right,
                  readOnly: _isReadOnly,
                  onChanged: (v) {
                    setState(() => w.whtCtrl.text = ((double.tryParse(v) ?? 0) * rate / 100).toStringAsFixed(2));
                    _recalcTotals();
                  },
                )),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: TextFormField(
                  controller: w.whtCtrl,
                  decoration: _fieldDeco(isEnglish ? 'WHT Amount' : 'ภาษีที่หัก'),
                  keyboardType: TextInputType.number, textAlign: TextAlign.right,
                  readOnly: _isReadOnly,
                  onChanged: (_) => _recalcTotals(),
                )),
                const SizedBox(width: 8),
                Expanded(flex: 3, child: TextFormField(
                  controller: w.descCtrl,
                  decoration: _fieldDeco(isEnglish ? 'Description' : 'คำอธิบาย'),
                  readOnly: _isReadOnly,
                )),
                if (!_isReadOnly) IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  onPressed: () { setState(() { w.dispose(); _whtRows.removeAt(i); }); _recalcTotals(); },
                ),
              ]),
            );
          }),
      ]),
    ));
  }

  // ── Detail Section (Voucher 40 — expense lines) ─────────────────────────────
  Widget _buildDetailSection() {
    final isEnglish = _isEnglish;
    return Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.list_alt, size: 18),
          const SizedBox(width: 6),
          Text(_isReceipt ? (isEnglish ? 'Revenue Items' : 'รายการรายรับ') : (isEnglish ? 'Expense Items' : 'รายการค่าใช้จ่าย'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          if (_hasVatLines) ...[
            const SizedBox(width: 16),
            Checkbox(
              value: _priceIncludesVat,
              visualDensity: VisualDensity.compact,
              onChanged: _isReadOnly ? null : (v) { setState(() => _priceIncludesVat = v ?? false); _recalcTotals(); },
            ),
            Text(isEnglish ? 'Amounts include VAT' : 'ราคารวม VAT', style: const TextStyle(fontSize: 13)),
          ],
          const Spacer(),
          if (!_isReadOnly) TextButton.icon(
            onPressed: () => setState(() => _detailRows.add(_DetailRow())),
            icon: const Icon(Icons.add, size: 16),
            label: Text(isEnglish ? 'Add Item' : 'เพิ่มรายการ'),
          ),
        ]),
        if (_detailRows.isEmpty)
          Padding(padding: const EdgeInsets.all(12), child: Text(isEnglish ? 'No items yet' : 'ยังไม่มีรายการ'))
        else
          ..._detailRows.asMap().entries.map((e) {
            final i = e.key; final r = e.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [Row(children: [
                Expanded(flex: 3, child: TextFormField(
                  controller: r.descCtrl,
                  decoration: _fieldDeco(isEnglish ? 'Description' : 'รายละเอียด'),
                  readOnly: _isReadOnly,
                )),
                const SizedBox(width: 8),
                Expanded(flex: 3, child: DropdownButtonFormField<int?>(
                  value: r.expenseAccountId,
                  isExpanded: true,
                  decoration: _fieldDeco(_isReceipt
                      ? (isEnglish ? 'Revenue Account *' : 'บัญชีรายได้ *')
                      : (isEnglish ? 'Expense Account *' : 'บัญชีค่าใช้จ่าย *')),
                  items: _accounts.map((a) => DropdownMenuItem(
                        value: a.id, child: Text('${a.accountCode} ${_acctLabel(a)}', overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: _isReadOnly ? null : (v) => setState(() {
                    r.expenseAccountId = v;
                    final m = _accounts.where((a) => a.id == v);
                    if (m.isNotEmpty) { r.expenseAccountCode = m.first.accountCode; r.expenseAccountName = m.first.accountNameThai; }
                  }),
                  validator: (v) => v == null ? (isEnglish ? 'Required' : 'กรุณาเลือก') : null,
                )),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: TextFormField(
                  controller: r.amountCtrl,
                  decoration: _fieldDeco(isEnglish ? 'Amount' : 'จำนวนเงิน'),
                  keyboardType: TextInputType.number,
                  readOnly: _isReadOnly,
                  onChanged: (_) => _recalcTotals(),
                )),
                if (_dimTypes.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  SizedBox(width: 150, child: InputDecorator(
                    decoration: _fieldDeco(isEnglish ? 'Line Dimensions' : 'มิติของบรรทัด'),
                    child: GlLineDimsCell(
                      dimTypes: _dimTypes,
                      dimValues: _dimValues,
                      lineDims: r.dims,
                      headerDims: _dimSelections,
                      account: findAccount(_accounts, r.expenseAccountId),
                      readOnly: _isReadOnly,
                      width: 120,
                      onChanged: (d) { setState(() => r.dims = d); _rebuildGlRows(); },
                    ),
                  )),
                ],
                if (_hasVatLines) ...[
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: DropdownButtonFormField<String>(
                    value: _vatRates.any((v) => v.vatCode == r.vatType) || r.vatType == 'NOVAT' ? r.vatType : 'NOVAT',
                    isExpanded: true,
                    decoration: _fieldDeco('VAT'),
                    items: [
                      if (!_vatRates.any((v) => v.vatCode == 'NOVAT'))
                        DropdownMenuItem(value: 'NOVAT', child: Text(isEnglish ? 'No VAT' : 'ไม่มี VAT')),
                      ..._vatRates.map((v) => DropdownMenuItem(
                            value: v.vatCode,
                            child: Text('${v.vatCode} ${v.rate.toStringAsFixed(v.rate % 1 == 0 ? 0 : 2)}%', overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: _isReadOnly ? null : (code) {
                      final vr = _vatRates.cast<VatRate?>().firstWhere((v) => v?.vatCode == code, orElse: () => null);
                      setState(() { r.vatType = code ?? 'NOVAT'; r.vatRate = r.vatType == 'NOVAT' ? 0 : (vr?.rate ?? 0); });
                      _recalcTotals();
                    },
                  )),
                  const SizedBox(width: 8),
                  SizedBox(width: 100, child: Text(_fmt.format(_lineAmt(r).vat), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
                ],
                if (!_isReadOnly) IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  onPressed: () { setState(() { r.dispose(); _detailRows.removeAt(i); }); _recalcTotals(); },
                ),
              ]),
              // เบิกเงินสดย่อย: ใบเสร็จที่มี VAT ต้องระบุผู้ขายและใบกำกับภาษีของบรรทัดนั้น (รายงานภาษีซื้อ)
              if (_isVoucher && r.vatType != 'NOVAT') Padding(
                padding: const EdgeInsets.only(top: 6, left: 24),
                child: Row(children: [
                  Expanded(flex: 3, child: TextFormField(
                    controller: r.sellerNameCtrl,
                    decoration: _fieldDeco(isEnglish ? 'Seller *' : 'ชื่อผู้ขาย *'),
                    readOnly: _isReadOnly,
                  )),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: TextFormField(
                    controller: r.sellerTaxIdCtrl,
                    decoration: _fieldDeco(isEnglish ? 'Tax ID *' : 'เลขผู้เสียภาษี *'),
                    readOnly: _isReadOnly,
                  )),
                  const SizedBox(width: 8),
                  Expanded(flex: 1, child: TextFormField(
                    controller: r.sellerBranchCtrl,
                    decoration: _fieldDeco(isEnglish ? 'Branch' : 'สาขา'),
                    readOnly: _isReadOnly,
                  )),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: TextFormField(
                    controller: r.taxInvNoCtrl,
                    decoration: _fieldDeco(isEnglish ? 'Tax Invoice No. *' : 'เลขที่ใบกำกับ *'),
                    readOnly: _isReadOnly,
                  )),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: InkWell(
                    onTap: _isReadOnly ? null : () async {
                      final d = await showDatePicker(context: context, initialDate: r.taxInvDate ?? _docDate,
                          firstDate: DateTime(2000), lastDate: DateTime(2100));
                      if (d != null) setState(() => r.taxInvDate = d);
                    },
                    child: InputDecorator(
                      decoration: _fieldDeco(isEnglish ? 'Invoice Date' : 'วันที่ใบกำกับ'),
                      child: Text(r.taxInvDate != null ? _dateFmt.format(r.taxInvDate!) : (isEnglish ? '(doc date)' : '(วันที่เอกสาร)'),
                          style: TextStyle(color: r.taxInvDate == null ? Colors.grey[500] : null)),
                    ),
                  )),
                  if (!_isReadOnly) const SizedBox(width: 40),
                ]),
              ),
              ]),
            );
          }),
      ]),
    ));
  }

  // ── Apply Section (Replenishment 30 — pick open Vouchers) ───────────────────
  Widget _buildApplySection() {
    final isEnglish = _isEnglish;
    final appliedIds = _applyRows.map((a) => a.appliedToId).toSet();
    return Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.receipt_long_outlined, size: 18),
          const SizedBox(width: 6),
          Text(isEnglish ? 'Vouchers to Reimburse' : 'ใบเบิกเงินสดย่อยที่นำมาเติม', style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        if (_bankAccountId == null)
          Padding(padding: const EdgeInsets.all(12), child: Text(isEnglish ? 'Select a petty cash account first' : 'กรุณาเลือกบัญชีเงินสดย่อยก่อน'))
        else if (_openVouchers.where((v) => !appliedIds.contains(v.id)).isEmpty && _applyRows.isEmpty)
          Padding(padding: const EdgeInsets.all(12), child: Text(isEnglish ? 'No open vouchers found' : 'ไม่พบใบเบิกที่รอเติมเงิน'))
        else ...[
          if (!_isReadOnly)
            ..._openVouchers.where((v) => !appliedIds.contains(v.id)).map((v) => ListTile(
                  dense: true,
                  title: Text('${v.docNo}  (${_fmt.format(v.balanceAmountLc)})', style: const TextStyle(fontSize: 13)),
                  subtitle: v.docDate != null ? Text(_dateFmt.format(v.docDate!), style: const TextStyle(fontSize: 11)) : null,
                  trailing: TextButton(
                    onPressed: () => setState(() {
                      _applyRows.add(_ApplyRow(
                        appliedToId: v.id, appliedToDocNo: v.docNo, appliedToDocDate: v.docDate,
                        balanceAvailable: v.balanceAmountLc, appliedAmountFc: v.balanceAmountLc,
                      ));
                      _recalcTotals();
                    }),
                    child: Text(isEnglish ? 'Add' : 'เพิ่ม'),
                  ),
                )),
          if (_applyRows.isNotEmpty) ...[
            const Divider(),
            ..._applyRows.asMap().entries.map((e) {
              final i = e.key; final a = e.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Expanded(flex: 2, child: Text(a.appliedToDocNo, style: const TextStyle(fontSize: 13))),
                  Expanded(flex: 2, child: Text(a.appliedToDocDate != null ? _dateFmt.format(a.appliedToDocDate!) : '', style: const TextStyle(fontSize: 12))),
                  Expanded(flex: 2, child: Text(isEnglish ? 'Balance: ${_fmt.format(a.balanceAvailable)}' : 'คงเหลือ: ${_fmt.format(a.balanceAvailable)}', style: const TextStyle(fontSize: 12))),
                  Expanded(flex: 2, child: TextFormField(
                    initialValue: a.appliedAmountFc.toStringAsFixed(2),
                    decoration: _fieldDeco(isEnglish ? 'Amount' : 'จำนวนที่เติม'),
                    keyboardType: TextInputType.number,
                    readOnly: _isReadOnly,
                    onChanged: (v) { a.appliedAmountFc = double.tryParse(v) ?? 0; _recalcTotals(); },
                  )),
                  if (!_isReadOnly) IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    onPressed: () { setState(() => _applyRows.removeAt(i)); _recalcTotals(); },
                  ),
                ]),
              );
            }),
          ],
        ],
      ]),
    ));
  }

  // ── Payment Section (bank/payment-method rows — 10/20/30) ──────────────────
  Widget _buildPaymentSection() {
    final isEnglish = _isEnglish;
    return Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.payments_outlined, size: 18),
          const SizedBox(width: 6),
          Text(isEnglish ? 'Payment Channels' : 'ช่องทางการรับ-จ่ายเงิน', style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          if (!_isReadOnly) TextButton.icon(
            onPressed: () => setState(() => _paymentRows.add(_PaymentRow())),
            icon: const Icon(Icons.add, size: 16),
            label: Text(isEnglish ? 'Add Row' : 'เพิ่มรายการ'),
          ),
        ]),
        if (_paymentRows.isEmpty)
          Padding(padding: const EdgeInsets.all(12), child: Text(isEnglish ? 'No payment rows yet' : 'ยังไม่มีรายการ'))
        else
          ..._paymentRows.asMap().entries.map((e) {
            final i = e.key; final r = e.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(flex: 3, child: DropdownButtonFormField<int?>(
                  value: r.paymentMethodId,
                  isExpanded: true,
                  decoration: _fieldDeco(isEnglish ? 'Payment Method' : 'ประเภทการชำระ'),
                  items: _paymentMethods.map((m) => DropdownMenuItem(
                        value: m.id, child: Text(m.displayName, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: _isReadOnly ? null : (v) => setState(() {
                    r.paymentMethodId = v;
                    final m = _paymentMethods.where((x) => x.id == v);
                    if (m.isNotEmpty) {
                      r.paymentMethodCode = m.first.methodCode;
                      r.paymentMethodName = m.first.methodNameTh;
                      r.paymentMethodType = m.first.methodType;
                      r.cmBankAccountId = m.first.cmBankAccountId;
                    }
                  }),
                )),
                const SizedBox(width: 8),
                Expanded(flex: 3, child: DropdownButtonFormField<int?>(
                  value: r.cmBankAccountId,
                  isExpanded: true,
                  decoration: _fieldDeco(isEnglish ? 'Bank Account' : 'บัญชีธนาคาร'),
                  items: _bankAccounts.where((b) => b.cmType == 'BANK').map((b) => DropdownMenuItem(
                        value: b.id, child: Text(_bankAcctLabel(b), overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: _isReadOnly ? null : (v) => setState(() => r.cmBankAccountId = v),
                )),
                if (_usesCheckbook(r)) ...[
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: Builder(builder: (_) {
                    _ensureCheckbooks(r.cmBankAccountId!);
                    final books = (_checkbooks[r.cmBankAccountId!] ?? const <CmCheckbook>[])
                        .where((b) => b.status == 'Active' || b.id == r.checkbookId).toList();
                    return DropdownButtonFormField<int?>(
                      value: books.any((b) => b.id == r.checkbookId) ? r.checkbookId : null,
                      isExpanded: true,
                      decoration: _fieldDeco(isEnglish ? 'Checkbook' : 'สมุดเช็ค'),
                      items: [
                        DropdownMenuItem(value: null, child: Text(isEnglish ? '— Type check no. —' : '— พิมพ์เลขเช็คเอง —')),
                        ...books.map((b) => DropdownMenuItem(value: b.id,
                            child: Text('${b.checkbookCode} (${b.startCheckNo}-${b.endCheckNo})', overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: _isReadOnly ? null : (v) => setState(() => r.checkbookId = v),
                    );
                  })),
                ],
                const SizedBox(width: 8),
                Expanded(flex: 2, child: TextFormField(
                  controller: r.refNoCtrl,
                  decoration: _fieldDeco(isEnglish ? 'Ref./Check No.' : 'เลขที่อ้างอิง/เช็ค').copyWith(
                    hintText: _usesCheckbook(r) && r.checkbookId != null
                        ? (isEnglish ? 'Next: ${_nextCheckNo(r) ?? '-'} (on post)' : 'เลขถัดไป ${_nextCheckNo(r) ?? '-'} (ตอน Post)')
                        : null,
                  ),
                  readOnly: _isReadOnly,
                )),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: TextFormField(
                  controller: r.amountCtrl,
                  decoration: _fieldDeco(isEnglish ? 'Amount' : 'จำนวนเงิน'),
                  keyboardType: TextInputType.number,
                  readOnly: _isReadOnly,
                  onChanged: (_) => _recalcTotals(),
                )),
                if (!_isReadOnly) IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  onPressed: () { setState(() { r.dispose(); _paymentRows.removeAt(i); }); _recalcTotals(); },
                ),
              ]),
            );
          }),
      ]),
    ));
  }

  String? _nextCheckNo(_PaymentRow r) =>
      (_checkbooks[r.cmBankAccountId] ?? const <CmCheckbook>[]).where((b) => b.id == r.checkbookId).firstOrNull?.nextCheckNo;

  Widget _buildTotalsRow() {
    final isEnglish = _isEnglish;
    final isForeign = _selectedCurrency != null && _selectedCurrency!.baseCurrencyFlag == false;
    if ((_hasVatLines && _detailRows.isNotEmpty) || _isBankCharge || _isInterestIncome) {
      Widget cell(String label, double v, {bool bold = false, Color? color}) => Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text(_fmt.format(v), style: TextStyle(fontSize: bold ? 16 : 14, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color)),
            ]),
          );
      return Card(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (isForeign) Text('${_selectedCurrency!.currencyCode} × ${_exchangeRate.toStringAsFixed(4)}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          if (!_isInterestIncome) cell(isEnglish ? 'Before VAT' : 'ก่อน VAT', _subtotalFc),
          if (!_isInterestIncome) cell('VAT', _vatFc),
          cell(isEnglish ? 'Total' : 'ยอดรวม', _totalAmountFc, bold: !_showsWht, color: _showsWht ? null : Colors.blue),
          if (_showsWht) cell(isEnglish ? 'Less WHT' : (_isPayment ? 'หัก ณ ที่จ่าย' : 'ถูกหัก ณ ที่จ่าย'), _whtFc),
          if (_showsWht)
            cell(!_isPayment ? (isEnglish ? 'Net received' : 'ยอดรับสุทธิ') : (isEnglish ? 'Net to pay' : 'ยอดจ่ายสุทธิ'),
                _netPayFc, bold: true, color: Colors.blue),
        ]),
      ));
    }
    return Card(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        if (isForeign) ...[
          Text('${_fmt.format(_totalAmountFc)} ${_selectedCurrency!.currencyCode}  ×  ${_exchangeRate.toStringAsFixed(4)}  =  ',
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        ],
        Text(isEnglish ? 'Total: ' : 'ยอดรวม: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(_fmt.format(_totalAmountLc), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
      ]),
    ));
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

    return Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.account_balance_outlined, size: 18),
          const SizedBox(width: 6),
          Text(isEnglish ? 'GL Entries' : 'รายการบัญชี GL', style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          if (!_glLoading && _glEditRows.isNotEmpty) ...[
            Icon(isBalanced ? Icons.check_circle_outline : Icons.warning_amber_outlined,
                size: 14, color: isBalanced ? Colors.green[700] : Colors.red[700]),
            const SizedBox(width: 4),
            Text(isBalanced ? (isEnglish ? 'Balanced' : 'สมดุล') : (isEnglish ? 'Unbalanced' : 'ไม่สมดุล'),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isBalanced ? Colors.green[700] : Colors.red[700])),
            const SizedBox(width: 12),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _status == 'Posted' ? Colors.blue[100] : Colors.orange[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_status == 'Posted' ? (isEnglish ? 'Actual GL (Posted)' : 'GL จริง (Posted)') : (isEnglish ? 'GL Preview (Draft)' : 'ตัวอย่าง GL (Draft)'),
                style: TextStyle(fontSize: 11, color: _status == 'Posted' ? Colors.blue[800] : Colors.orange[800])),
          ),
        ]),
        const SizedBox(height: 8),
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
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.blueGrey.shade600)),
          ),
      ]),
    ));
  }
}
