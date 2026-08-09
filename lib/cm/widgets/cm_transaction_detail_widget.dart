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
import '../../cd/models/cd_currency.dart';
import '../../cd/services/cd_currency_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/services/sa_auth_service.dart';

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

  _DetailRow();

  factory _DetailRow.fromModel(CmTransactionDetail d) {
    final r = _DetailRow();
    r.descCtrl.text = d.description ?? '';
    r.amountCtrl.text = d.amountFc.toStringAsFixed(2);
    r.expenseAccountId = d.expenseAccountId;
    r.expenseAccountCode = d.expenseAccountCode;
    r.expenseAccountName = d.expenseAccountName;
    return r;
  }

  void dispose() {
    descCtrl.dispose();
    amountCtrl.dispose();
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
  final amountCtrl = TextEditingController(text: '0.00');
  final refNoCtrl = TextEditingController();

  _PaymentRow({this.paymentMethodType = 'CASH'});

  factory _PaymentRow.fromModel(CmTransactionPayment p) {
    final r = _PaymentRow(paymentMethodType: p.paymentMethodType);
    r.paymentMethodId = p.paymentMethodId;
    r.paymentMethodCode = p.paymentMethodCode;
    r.paymentMethodName = p.paymentMethodName;
    r.cmBankAccountId = p.cmBankAccountId;
    r.amountCtrl.text = p.amountFc.toStringAsFixed(2);
    r.refNoCtrl.text = p.refNo ?? '';
    return r;
  }

  void dispose() {
    amountCtrl.dispose();
    refNoCtrl.dispose();
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
  const _GlLine(this.accountCode, this.accountName, this.description, this.debit, this.credit, this.debitFc, this.creditFc);
}

// ── Editable GL row (cosmetic preview like AP — account/description/dimension
// overrides here do not change what actually posts; the server always applies
// the header-level dimension selection to every line and recomputes on Post) ──
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
  String _status = 'Draft';

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

  bool get _hasDetailRows    => _isVoucher;
  bool get _hasApplySection  => _isReplenishment;
  bool get _hasPaymentSection => _isReceipt || _isPayment || _isReplenishment;
  bool get _hasCounterparty  => _isReceipt || _isPayment;
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
      ]);
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
        _status = h.status;
        _isReadOnly = widget.viewOnly || h.status != 'Draft';
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
      _amountCtrl.text = '0.00';
      _status = 'Draft';
      _isReadOnly = false;
      _isReadOnlyView = false;
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

  void _recalcTotals() {
    double totalFc = 0;
    if (_isVoucher) {
      totalFc = _detailRows.fold(0.0, (s, r) => s + (double.tryParse(r.amountCtrl.text) ?? 0));
    } else if (_isReplenishment) {
      totalFc = _applyRows.fold(0.0, (s, a) => s + a.appliedAmountFc);
    } else if (_isReceipt || _isPayment) {
      totalFc = _paymentRows.fold(0.0, (s, r) => s + (double.tryParse(r.amountCtrl.text) ?? 0));
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
        dimIds: Map<int, int?>.from(_dimSelections),
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
    if (_hasBankChargeFields && _bankAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please select a bank account' : 'กรุณาเลือกบัญชีธนาคาร')));
      return;
    }
    if (_isInterest && (_chargeType == null || _chargeType!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please select income or expense' : 'กรุณาเลือกดอกเบี้ยรับหรือดอกเบี้ยจ่าย')));
      return;
    }
    if (action == 'Post' && !(await CmPeriodService.canPost(context, _docDate))) {
      return;
    }

    _recalcTotals();
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
      counterpartyName: _hasCounterparty && _counterpartyCtrl.text.isNotEmpty ? _counterpartyCtrl.text : null,
      currencyId: _selectedCurrency?.id,
      currencyCode: _selectedCurrency?.currencyCode ?? 'THB',
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
            );
          }).toList()
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
            );
          }).toList()
        : <CmTransactionPayment>[];

    setState(() => _isLoading = true);
    try {
      if (_transactionId == 0) {
        await _service.createTransaction(header: header, details: details, applies: applies, payments: payments, action: action);
      } else {
        await _service.updateTransaction(id: _transactionId, header: header, details: details, applies: applies, payments: payments, action: action);
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

  Future<void> _void() async {
    final isEnglish = _isEnglish;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEnglish ? 'Confirm Void Document' : 'ยืนยันการยกเลิกเอกสาร'),
        content: Text(isEnglish
            ? 'A voided document cannot be restored. The system will create a Reversing GL Entry.'
            : 'เอกสารที่ยกเลิกแล้วไม่สามารถกู้คืนได้ ระบบจะสร้าง Reversing GL Entry เพื่อยกเลิกผลกระทบทางบัญชี'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(isEnglish ? 'Close' : 'ปิด')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
            child: Text(isEnglish ? 'Confirm Void' : 'ยืนยัน Void'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isLoading = true);
    try {
      await _service.voidTransaction(_transactionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Document voided successfully' : 'ยกเลิกเอกสารเรียบร้อย')));
        widget.onSaveSuccess();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
            _buildHeaderSection(),
            if (_hasDetailRows) ...[const SizedBox(height: 8), _buildDetailSection()],
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
          ElevatedButton.icon(
            onPressed: () => _save('Post'),
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: Text(isEnglish ? 'Post Document' : 'Post เอกสาร'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
          ),
          const SizedBox(width: 8),
          if (_transactionId != 0 && widget.canDelete)
            OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(isEnglish ? 'Delete Draft' : 'ลบ Draft'),
                    content: Text(isEnglish ? 'Do you want to delete this Draft document?' : 'ต้องการลบเอกสาร Draft นี้?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
                      ElevatedButton(onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: Text(isEnglish ? 'Delete' : 'ลบ')),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _service.deleteTransaction(_transactionId);
                  if (mounted) widget.onSaveSuccess();
                }
              },
              icon: const Icon(Icons.delete_outline, size: 16),
              label: Text(isEnglish ? 'Delete' : 'ลบ'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            ),
        ],
        if (isPosted && widget.canDelete)
          ElevatedButton.icon(
            onPressed: _void,
            icon: const Icon(Icons.cancel_outlined, size: 16),
            label: Text(isEnglish ? 'Void' : 'ยกเลิก (Void)'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
          ),
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
              onChanged: _isReadOnly ? null : (v) => setState(() => _bankAccountId = v),
              validator: (v) => v == null ? (isEnglish ? 'Required' : 'กรุณาเลือก') : null,
            )),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: DropdownButtonFormField<int?>(
              value: _glAccountId,
              isExpanded: true,
              decoration: _fieldDeco(isEnglish
                  ? (_isInterest ? 'Interest Income/Expense Account' : 'Expense Account')
                  : (_isInterest ? 'บัญชีดอกเบี้ยรับ/จ่าย' : 'บัญชีค่าใช้จ่าย')),
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
                onChanged: _isReadOnly ? null : (v) => setState(() => _chargeType = v),
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
            onChanged: (_) => _recalcTotals(),
            validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? (isEnglish ? 'Enter an amount' : 'กรุณาระบุจำนวนเงิน') : null,
          )),
        ],
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
          Text(isEnglish ? 'Expense Items' : 'รายการค่าใช้จ่าย', style: const TextStyle(fontWeight: FontWeight.bold)),
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
              child: Row(children: [
                Expanded(flex: 3, child: TextFormField(
                  controller: r.descCtrl,
                  decoration: _fieldDeco(isEnglish ? 'Description' : 'รายละเอียด'),
                  readOnly: _isReadOnly,
                )),
                const SizedBox(width: 8),
                Expanded(flex: 3, child: DropdownButtonFormField<int?>(
                  value: r.expenseAccountId,
                  isExpanded: true,
                  decoration: _fieldDeco(isEnglish ? 'Expense Account *' : 'บัญชีค่าใช้จ่าย *'),
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
                if (!_isReadOnly) IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  onPressed: () { setState(() { r.dispose(); _detailRows.removeAt(i); }); _recalcTotals(); },
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
                const SizedBox(width: 8),
                Expanded(flex: 2, child: TextFormField(
                  controller: r.refNoCtrl,
                  decoration: _fieldDeco(isEnglish ? 'Ref./Check No.' : 'เลขที่อ้างอิง/เช็ค'),
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

  Widget _buildTotalsRow() {
    final isEnglish = _isEnglish;
    final isForeign = _selectedCurrency != null && _selectedCurrency!.baseCurrencyFlag == false;
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

    void addLine(({String code, String name}) acct, String desc, double fcDebit, double fcCredit) {
      lines.add(_GlLine(acct.code, acct.name, desc, fcDebit * lc, fcCredit * lc, fcDebit, fcCredit));
    }

    if (_isReceipt) {
      for (final p in _paymentRows) {
        final amt = double.tryParse(p.amountCtrl.text) ?? 0;
        if (amt == 0) continue;
        addLine(_bankAcctCodeName(p.cmBankAccountId), '${isEnglish ? 'Receive' : 'รับเงิน'} ${p.paymentMethodCode ?? ''}', amt, 0);
      }
      final revAcct = _glAccountId != null
          ? _acctCodeName(_glAccountId)
          : _setupAcctCodeName(_docSetup!.revenueAccountId, _docSetup!.revenueAccountCode, _docSetup!.revenueAccountName);
      addLine(revAcct, isEnglish ? 'Revenue' : 'รายรับ', 0, _totalAmountFc);
    } else if (_isPayment) {
      final expAcct = _glAccountId != null
          ? _acctCodeName(_glAccountId)
          : _setupAcctCodeName(_docSetup!.expenseAccountId, _docSetup!.expenseAccountCode, _docSetup!.expenseAccountName);
      addLine(expAcct, isEnglish ? 'Expense' : 'รายจ่าย', _totalAmountFc, 0);
      for (final p in _paymentRows) {
        final amt = double.tryParse(p.amountCtrl.text) ?? 0;
        if (amt == 0) continue;
        addLine(_bankAcctCodeName(p.cmBankAccountId), '${isEnglish ? 'Pay' : 'จ่ายเงิน'} ${p.paymentMethodCode ?? ''}', 0, amt);
      }
    } else if (_isReplenishment) {
      final payableAcct = _setupAcctCodeName(_docSetup!.pettyCashPayableAccountId, _docSetup!.pettyCashPayableAccountCode, _docSetup!.pettyCashPayableAccountName);
      addLine(payableAcct, isEnglish ? 'Petty cash replenishment' : 'เติมเงินสดย่อย', _totalAmountFc, 0);
      for (final p in _paymentRows) {
        final amt = double.tryParse(p.amountCtrl.text) ?? 0;
        if (amt == 0) continue;
        addLine(_bankAcctCodeName(p.cmBankAccountId), '${isEnglish ? 'Pay' : 'เติมเงินสดย่อย'} ${p.paymentMethodCode ?? ''}', 0, amt);
      }
    } else if (_isVoucher) {
      for (final d in _detailRows) {
        final amt = double.tryParse(d.amountCtrl.text) ?? 0;
        if (amt == 0) continue;
        final acct = d.expenseAccountId != null
            ? _acctCodeName(d.expenseAccountId)
            : (code: '!', name: isEnglish ? 'Select account' : 'ยังไม่เลือกบัญชี');
        addLine(acct, d.descCtrl.text.isEmpty ? (isEnglish ? 'Petty cash expense' : 'เบิกเงินสดย่อย') : d.descCtrl.text, amt, 0);
      }
      final payableAcct = _setupAcctCodeName(_docSetup!.pettyCashPayableAccountId, _docSetup!.pettyCashPayableAccountCode, _docSetup!.pettyCashPayableAccountName);
      addLine(payableAcct, isEnglish ? 'Petty cash voucher' : 'เบิกเงินสดย่อย', 0, _totalAmountFc);
    } else if (_isTransfer) {
      addLine(_bankAcctCodeName(_toBankAccountId), isEnglish ? 'Transfer in' : 'รับโอนเข้า', _totalAmountFc, 0);
      addLine(_bankAcctCodeName(_fromBankAccountId), isEnglish ? 'Transfer out' : 'โอนออก', 0, _totalAmountFc);
    } else if (_isBankCharge || _isInterest) {
      final isIncome = _chargeType == 'INTEREST_INCOME';
      final offsetAcct = _glAccountId != null
          ? _acctCodeName(_glAccountId)
          : _setupAcctCodeName(_docSetup!.expenseAccountId, _docSetup!.expenseAccountCode, _docSetup!.expenseAccountName);
      final bankAcct = _bankAcctCodeName(_bankAccountId);
      final label = _isInterest
          ? (isIncome ? (isEnglish ? 'Interest income' : 'ดอกเบี้ยรับ') : (isEnglish ? 'Interest expense' : 'ดอกเบี้ยจ่าย'))
          : (isEnglish ? 'Bank charge' : 'ค่าธรรมเนียมธนาคาร');
      if (isIncome) {
        addLine(bankAcct, label, _totalAmountFc, 0);
        addLine(offsetAcct, label, 0, _totalAmountFc);
      } else {
        addLine(offsetAcct, label, _totalAmountFc, 0);
        addLine(bankAcct, label, 0, _totalAmountFc);
      }
    }
    return lines;
  }

  // ── Account picker for the editable GL grid (cosmetic override, like AP) ───
  Future<void> _showGlAccountSearchDialog(_GlEditRow r) async {
    final isEnglish = _isEnglish;
    final searchCtrl = TextEditingController();
    final available = _accounts.where((a) => a.isNormalAccount && a.isActive).toList();
    List<Account> filtered = List.from(available);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlgState) {
        void doFilter(String q) {
          setDlgState(() {
            if (q.isEmpty) {
              filtered = List.from(available);
            } else {
              final lq = q.toLowerCase();
              filtered = available.where((a) =>
                  a.accountCode.toLowerCase().contains(lq) ||
                  a.accountNameThai.toLowerCase().contains(lq) ||
                  a.accountNameEng.toLowerCase().contains(lq)).toList();
            }
          });
        }
        return AlertDialog(
          title: Text(isEnglish ? 'Select Account Code' : 'เลือกรหัสบัญชี'),
          content: SizedBox(
            width: 520, height: 420,
            child: Column(children: [
              TextField(
                controller: searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: isEnglish ? 'Search account code / name' : 'ค้นหา รหัส / ชื่อบัญชี',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onChanged: doFilter,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text(isEnglish ? 'No accounts found' : 'ไม่พบบัญชี'))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final a = filtered[i];
                          final isSelected = r.acctCodeCtrl.text == a.accountCode;
                          return ListTile(
                            dense: true,
                            selected: isSelected,
                            selectedTileColor: Colors.indigo.shade50,
                            leading: isSelected
                                ? Icon(Icons.check_circle, color: Colors.indigo[700], size: 18)
                                : const SizedBox(width: 18),
                            title: Row(children: [
                              SizedBox(width: 90, child: Text(a.accountCode,
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo[700]))),
                              Expanded(child: Text(_acctLabel(a), overflow: TextOverflow.ellipsis)),
                            ]),
                            onTap: () {
                              setState(() {
                                r.acctCodeCtrl.text = a.accountCode;
                                r.accountName = _acctLabel(a);
                              });
                              Navigator.of(ctx).pop();
                            },
                          );
                        },
                      ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ],
        );
      }),
    );
    searchCtrl.dispose();
  }

  Widget _buildGlSection() {
    final isEnglish = _isEnglish;
    final totalDebit = _glEditRows.fold(0.0, (s, r) => s + r.debit);
    final totalCredit = _glEditRows.fold(0.0, (s, r) => s + r.credit);
    final isBalanced = _glEditRows.isEmpty || (totalDebit - totalCredit).abs() < 0.005;
    final hasFc = _glEditRows.any((r) => r.debitFc > 0 || r.creditFc > 0);
    final lcLabel = _currencies.cast<Currency?>()
        .firstWhere((c) => c!.baseCurrencyFlag, orElse: () => null)?.currencyCode ?? 'THB';
    final fcLabel = _selectedCurrency?.currencyCode ?? 'FC';
    final isGlEditable = _status == 'Draft' && !_isReadOnly;
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
                SizedBox(width: 90, child: isGlEditable
                    ? InkWell(
                        onTap: () => _showGlAccountSearchDialog(r),
                        child: Row(children: [
                          Expanded(child: Text(r.acctCodeCtrl.text,
                              style: TextStyle(fontSize: 12, color: hasErr ? Colors.red[700] : Colors.indigo[800]), overflow: TextOverflow.ellipsis)),
                          Icon(Icons.search, size: 12, color: Colors.grey[400]),
                        ]))
                    : Text(r.acctCodeCtrl.text, style: TextStyle(fontSize: 12, color: hasErr ? Colors.red : null), overflow: TextOverflow.ellipsis)),
                Expanded(flex: 2, child: Text(r.accountName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                Expanded(flex: 2, child: isGlEditable
                    ? TextFormField(
                        controller: r.descCtrl,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6), border: InputBorder.none))
                    : Text(r.descCtrl.text, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
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
                    readOnly: !isGlEditable, isDense: true,
                    onSelected: (v) => setState(() {
                      r.dimIds[dt.slotNo] = v?.id;
                      r.dimNames[dt.slotNo] = v?.valueNameThai;
                    }),
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
      ]),
    ));
  }
}
