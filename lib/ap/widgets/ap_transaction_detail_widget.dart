import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../cd/models/cd_branch.dart';
import '../../cd/services/cd_branch_service.dart';
import '../models/ap_transaction.dart';
import '../models/ap_vendor.dart';
import '../models/ap_gl_account_setup.dart';
import '../services/ap_transaction_service.dart';
import '../services/ap_vendor_service.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../../cd/models/cd_currency.dart';
import '../../cd/services/cd_currency_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/models/sa_user_branch.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../gl/models/gl_period.dart';
import '../../gl/services/gl_period_service.dart';
import '../../cd/models/cd_vat_rate.dart';
import '../../cd/services/cd_vat_rate_service.dart';
import '../../gl/models/gl_dimension.dart';
import '../../gl/services/gl_dimension_service.dart';
import '../../gl/widgets/gl_dimension_picker_field.dart';
import '../../gl/widgets/gl_line_account_dims.dart';
import '../../cm/models/cm_payment_method.dart';
import '../../cm/widgets/cm_payment_method_list_widget.dart';
import '../../cm/models/cm_checkbook.dart';
import '../../cm/services/cm_checkbook_service.dart';
import '../../gl/services/gl_entry_service.dart';
import '../../gl/models/gl_entry.dart' show GlEntryDetail;
import '../../cd/models/cd_wht_type.dart';
import '../../cd/services/cd_wht_type_service.dart';
import '../../sa/widgets/sa_document_reverse_widgets.dart';
import '../../sa/models/sa_doc_approval.dart';
import '../../sa/widgets/sa_doc_approval_panel.dart';
import '../../utils/vat_calc.dart';
import '../../utils/order_ref_picker.dart';
import '../../po/services/po_transaction_service.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../../sa/widgets/sa_doc_list_kit.dart';

class ApTransactionDetailWidget extends StatefulWidget {
  final int? transactionId;
  final bool viewOnly;
  final int resetKey;
  final VoidCallback onSaveSuccess;
  final VoidCallback onCancel;
  final bool canDelete;
  /// ปุ่มของเอกสารแสดงบน AppBar ของหน้าจอแม่ (แทนแถบปุ่มเดิม)
  final DocAppBarActions? actions;

  const ApTransactionDetailWidget({
    super.key,
    this.transactionId,
    this.viewOnly = false,
    this.resetKey = 0,
    required this.onSaveSuccess,
    required this.onCancel,
    this.canDelete = true,
    this.actions,
  });

  @override
  State<ApTransactionDetailWidget> createState() => _ApTransactionDetailWidgetState();
}

class _ApTransactionDetailWidgetState extends State<ApTransactionDetailWidget> implements DocAppBarActionsHost {
  final _formKey = GlobalKey<FormState>();
  final ApTransactionService _service = ApTransactionService();
  final ApVendorService _vendorService = ApVendorService();
  final AccountService _accountService = AccountService();
  final CurrencyService _currencyService = CurrencyService();
  final PeriodService _periodService = PeriodService();
  final AuthService _authService = AuthService();
  final VatRateService _vatRateService = VatRateService();
  final GlDimensionService _dimService = GlDimensionService();
  final GlEntryService _glEntryService = GlEntryService();
  final BranchService _branchService = BranchService();

  bool _isLoading = false;
  bool _isEnglish = false;
  List<Branch> _allBranches = [];

  // GL Dimensions
  List<GlDimensionType> _dimTypes = [];
  Map<String, List<GlDimensionValue>> _dimValues = {};
  Map<int, int?> _dimSelections = {};
  Map<int, String?> _dimNames = {};

  // Master data
  List<ModuleDocument> _allowedDocTypes = [];
  List<ApVendor> _vendors = [];
  List<Account> _accounts = [];
  List<Currency> _currencies = [];
  List<PostingPeriod> _openPeriods = [];
  List<VatRate> _vatRates = [];
  ApGlAccountSetup? _docSetup;

  // Form state
  ModuleDocument? _selectedDocType;
  ApVendor? _selectedVendor;
  Currency? _selectedCurrency;
  UserBranch? _selectedBranch;
  bool _isReadOnly = false;

  // GL section state
  int? _glEntryId;
  List<_GlEditRow> _glEditRows = [];
  bool _glLoading = false;
  bool _glSectionExpanded = true;
  final ScrollController _glHeaderHScroll = ScrollController();
  final ScrollController _glBodyHScroll   = ScrollController();
  final ScrollController _glFooterHScroll = ScrollController();

  // Header values
  int _transactionId = 0;
  String _docNo = 'AUTO';
  DateTime _docDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime? _dueDate;
  int? _apAccountId;
  double _exchangeRate = 1.0;
  final _refNoCtrl = TextEditingController();
  final _taxInvNoCtrl = TextEditingController(); // เลขที่ใบกำกับภาษีของผู้ขาย
  DateTime? _taxInvDate;
  // ระยะเครดิตของเอกสาร (ใบตั้งหนี้) — ค่าเริ่มต้นจากผู้ขาย แก้ได้ → วันครบกำหนดคำนวณใหม่ (แบบ AR)
  final _creditMonthsCtrl = TextEditingController();
  final _creditDaysCtrl = TextEditingController();
  int get _creditMonths => int.tryParse(_creditMonthsCtrl.text.trim()) ?? 0;
  int get _creditDays => int.tryParse(_creditDaysCtrl.text.trim()) ?? 0;
  ApCashPurchasePayment? _cashPurchase; // ใบตั้งหนี้ที่ซื้อเงินสด IM สร้าง → การ์ดจ่ายชำระ (อ่านอย่างเดียว)
  final _descCtrl = TextEditingController();
  String _status = 'Draft';
  List<DocApprovalStep> _approvals = [];
  String? _approvalMode;
  // ถอยเป็นร่าง: null = ถอยได้ / รหัสเหตุผลที่ถอยไม่ได้ (จาก backend) + ประวัติการถอย/ลบ
  String? _reverseBlock;
  String? _reverseBlockRef;
  String? _voidBlock;
  String? _voidBlockRef;
  List<DocReverseLog> _reverseHistory = [];

  // Detail rows (for PI, CN, DN)
  List<_DetailRow> _detailRows = [];
  // คอลัมน์หน่วย — แสดงเมื่อมีบรรทัดที่มีหน่วย (ใบตั้งหนี้/ลดหนี้/เพิ่มหนี้ที่สร้างจากเอกสาร IM)
  bool get _showUnitCol => _detailRows.any((r) => (r.unitCode ?? '').isNotEmpty);

  // Apply rows (for Payment 80, RA 70)
  List<_ApplyRow> _applyRows = [];
  List<ApOpenInvoice> _openInvoices = [];
  final Map<int, TextEditingController> _applyCtrlMap = {};

  // Advance rows (for Payment 80 — advance deduction)
  List<_ApplyRow> _advanceRows = [];
  List<ApOpenInvoice> _openAdvances = [];
  final Map<int, TextEditingController> _advanceCtrlMap = {};

  // RA rows (for Payment 80 — apply via RA, stored as applyType='ra_invoice')
  List<_ApplyRow> _raRows = [];

  // Advance refund rows (for Advance Refund 65)
  List<_ApplyRow> _advanceRefundRows = [];
  List<ApOpenInvoice> _openAdvancesForRefund = [];
  final Map<int, TextEditingController> _advanceRefundCtrlMap = {};

  // Payment rows
  List<_PaymentRow> _paymentRows = [];

  // WHT rows (for Payment 80, Advance Payment 60)
  List<_WhtRow> _whtRows = [];
  List<CdWhtType> _whtTypes = [];
  final Map<int, List<CmCheckbook>> _checkbooks = {}; // สมุดเช็คที่ใช้งานได้ ต่อบัญชีธนาคาร (โหลดเมื่อใช้)

  // Totals
  double _subtotalFc = 0;
  double _discountAmountFc = 0;
  double _beforeVatFc = 0;
  double _vatAmountFc = 0;
  double _totalAmountFc = 0;
  bool _priceIncludesVat = false; // ราคาที่กรอกรวม VAT — ดู lib/utils/vat_calc.dart
  // ใบมัดจำ: ใบสั่งซื้อที่อ้างอิง — ใบรับสินค้าที่อ้างอิงใบสั่งซื้อเดียวกันจะแนะนำให้หักมัดจำนี้
  int? _refPoId;
  String? _refPoDocNo;

  final _fmt = NumberFormat('#,##0.00');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  bool get _isPurchaseInvoice => _selectedDocType?.sysDocType == apDocTypePurchaseInvoice.toString();
  bool get _isCreditNote      => _selectedDocType?.sysDocType == apDocTypeCreditNote.toString();
  bool get _isDebitNote       => _selectedDocType?.sysDocType == apDocTypeDebitNote.toString();
  bool get _isAdvancePayment  => _selectedDocType?.sysDocType == apDocTypeAdvancePayment.toString();
  bool get _isAdvanceRefund   => _selectedDocType?.sysDocType == apDocTypeAdvanceRefund.toString();
  bool get _isRA              => _selectedDocType?.sysDocType == apDocTypeRemittanceAdvice.toString();
  bool get _isPayment         => _selectedDocType?.sysDocType == apDocTypePayment.toString();

  bool get _hasDetailRows     => _isPurchaseInvoice || _isCreditNote || _isDebitNote || _isAdvancePayment;
  bool get _hasApplySection   => _isPayment || _isRA;
  bool get _hasAdvanceRefund  => _isAdvanceRefund;
  bool get _hasWhtSection     => _isPayment || _isAdvancePayment;
  bool get _hasPaymentRows    => _isPayment || _isAdvancePayment || _isAdvanceRefund;
  bool get _hasDueDate        => _isPurchaseInvoice;
  // ต้องมีเลขที่ใบกำกับภาษีของผู้ขาย: เอกสารมีรายการ VAT ที่ไม่ใช่ VAT รอตัดบัญชี
  bool get _taxInvRequired => _hasDetailRows &&
      _detailRows.any((r) => r.vatType != 'NOVAT' && !r.isDeferredVat && _amt(r).vat.abs() > 0.005);
  // ใบตั้งหนี้หักเงินมัดจำตอนตั้งหนี้ (apply_type 'inv_advance') — ใบจ่ายชำระหักตอนจ่าย ('advance')
  double get _invAdvanceTotal => _isPurchaseInvoice ? _advanceRows.fold(0.0, (s, a) => s + a.appliedAmountLc) : 0;

  LineAmounts _amt(_DetailRow r) => calcLineAmounts(
        qty: double.tryParse(r.qtyCtrl.text) ?? 0,
        price: double.tryParse(r.priceCtrl.text) ?? 0,
        discountPercent: double.tryParse(r.discPctCtrl.text) ?? 0,
        vatRate: r.vatRate,
        noVat: r.vatType == 'NOVAT',
        priceIncludesVat: _priceIncludesVat,
      );

  // RA(70) ต้องขออนุมัติเสมอ; Payment(80) ต้องขออนุมัติเมื่อไม่มีเลขที่อ้างอิง
  // (ไม่ได้ดึงมาจาก RA หรือใบอนุมัติจ่าย ap_payment_run ซึ่งผ่านการอนุมัติมาแล้ว) — backend ตรวจซ้ำว่าเลขอ้างอิงมีจริง
  bool get _canRequestApproval {
    if (_isRA) return true;
    if (_isPayment) return _refNoCtrl.text.trim().isEmpty;
    return false;
  }

  bool _headerExpanded  = true;

  void _syncGlHScroll() {
    final offset = _glBodyHScroll.offset;
    if (_glHeaderHScroll.hasClients && _glHeaderHScroll.offset != offset) {
      _glHeaderHScroll.jumpTo(offset);
    }
    if (_glFooterHScroll.hasClients && _glFooterHScroll.offset != offset) {
      _glFooterHScroll.jumpTo(offset);
    }
  }

  @override
  void initState() {
    super.initState();
    widget.actions?.attach(this);
    _glBodyHScroll.addListener(_syncGlHScroll);
    _initMasterData();
  }

  @override
  void dispose() {
    widget.actions?.detach(this);
    _refNoCtrl.dispose();
    _taxInvNoCtrl.dispose();
    _creditMonthsCtrl.dispose();
    _creditDaysCtrl.dispose();
    _descCtrl.dispose();
    for (final r in _detailRows) r.dispose();
    for (final c in _applyCtrlMap.values) c.dispose();
    for (final c in _advanceCtrlMap.values) c.dispose();
    for (final c in _advanceRefundCtrlMap.values) c.dispose();
    for (final r in _paymentRows) r.dispose();
    for (final r in _glEditRows) r.dispose();
    _glHeaderHScroll.dispose();
    _glBodyHScroll.dispose();
    _glFooterHScroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ApTransactionDetailWidget old) {
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
        _vendorService.fetchActiveRows(),
        _accountService.fetchRows(),
        _currencyService.fetchActiveRows(),
        _periodService.fetchOpenGlPeriods(),
        _vatRateService.fetchRows(),
        _dimService.fetchActiveTypes(),
        CdWhtTypeService().fetchActiveRows(),
        _branchService.fetchRows(),
      ]);
      _allowedDocTypes = results[0] as List<ModuleDocument>;
      _vendors = results[1] as List<ApVendor>;
      _accounts = results[2] as List<Account>;
      _currencies = results[3] as List<Currency>;
      _openPeriods = results[4] as List<PostingPeriod>;
      _vatRates = (results[5] as List<VatRate>).where((v) => v.isActive).toList();
      _dimTypes = results[6] as List<GlDimensionType>;
      _whtTypes = results[7] as List<CdWhtType>;
      _allBranches = results[8] as List<Branch>;

      final dimValueResults = await Future.wait(
        _dimTypes.map((t) => _dimService.fetchValuesByType(t.typeCode)),
      );
      for (int i = 0; i < _dimTypes.length; i++) {
        _dimValues[_dimTypes[i].typeCode] = dimValueResults[i];
      }

      if (_allowedDocTypes.isNotEmpty && _selectedDocType == null) {
        _selectedDocType = _allowedDocTypes.first;
      }
      if (_currencies.isNotEmpty) {
        _selectedCurrency = _currencies.cast<Currency?>()
            .firstWhere((c) => c!.baseCurrencyFlag, orElse: () => null)
            ?? _currencies.first;
      }
      _selectedBranch ??= _authService.defaultBranch;
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
    if (_selectedDocType == null) return;
    try {
      final setup = await _service.fetchSetupByDocCode(_selectedDocType!.docCode);
      if (mounted) {
        // บรรทัดที่ยังใช้บัญชีเริ่มต้นของประเภทเอกสารเดิม (หรือยังไม่มีบัญชี) เปลี่ยนตามประเภทเอกสารใหม่
        final oldDefault = _docSetup?.expenseAccountId;
        setState(() {
          _docSetup = setup;
          if (!_isReadOnly) {
            for (final r in _detailRows) {
              if (r.expenseAccountId == null || r.expenseAccountId == oldDefault) r.expenseAccountId = setup?.expenseAccountId;
            }
          }
        });
        if (!_isReadOnly || _status == 'Approved') _rebuildGlRows();
      }
    } catch (_) {}
  }

  Future<void> _loadTransactionData() async {
    if (widget.transactionId == null) { _resetForm(); return; }
    setState(() => _isLoading = true);
    try {
      final data = await _service.fetchRow(widget.transactionId!);
      final h = data.header;
      setState(() {
        _transactionId = h.id;
        _glEntryId = h.glEntryId;
        _docNo = h.docNo;
        _docDate = h.docDate;
        _dueDate = h.dueDate;
        _apAccountId = h.apAccountId;
        _exchangeRate = h.exchangeRate;
        _refNoCtrl.text = h.refNo ?? '';
        _taxInvNoCtrl.text = h.taxInvoiceNo ?? '';
        _taxInvDate = h.taxInvoiceDate;
        _creditMonthsCtrl.text = h.creditTermMonths?.toString() ?? '';
        _creditDaysCtrl.text = h.creditTermDays?.toString() ?? '';
        _cashPurchase = data.cashPurchase;
        _descCtrl.text = h.description ?? '';
        _status = h.status;
        _approvals = data.approvals;
        _approvalMode = data.approvalMode;
        _reverseBlock = data.reverseBlock;
        _reverseBlockRef = data.reverseBlockRef;
        _voidBlock = data.voidBlock;
        _voidBlockRef = data.voidBlockRef;
        _reverseHistory = data.reverseHistory;
        _isReadOnly = widget.viewOnly || h.status != 'Draft';
        _priceIncludesVat = h.priceIncludesVat;
        _refPoId = h.refPoId;
        _refPoDocNo = h.refPoDocNo;

        _dimSelections = { 1: h.dim1Id, 2: h.dim2Id, 3: h.dim3Id, 4: h.dim4Id, 5: h.dim5Id };
        _dimNames = { 1: h.dim1Name, 2: h.dim2Name, 3: h.dim3Name, 4: h.dim4Name, 5: h.dim5Name };

        if (_allowedDocTypes.isNotEmpty) {
          try { _selectedDocType = _allowedDocTypes.firstWhere((d) => d.id == h.docId); } catch (_) {}
        }
        if (_vendors.isNotEmpty) {
          try { _selectedVendor = _vendors.firstWhere((v) => v.id == h.vendorId); } catch (_) {}
        }
        if (_currencies.isNotEmpty) {
          try { _selectedCurrency = _currencies.firstWhere((c) => c.id == h.currencyId); } catch (_) {
            try { _selectedCurrency = _currencies.firstWhere((c) => c.currencyCode == h.currencyCode); } catch (_) {}
          }
        }
        if (h.branchId != null) {
          final found = _authService.allowedBranches.cast<UserBranch?>()
              .firstWhere((b) => b?.branchId == h.branchId, orElse: () => null);
          _selectedBranch = found ?? _authService.defaultBranch;
        }

        for (final r in _detailRows) r.dispose();
        _detailRows = data.details.map((d) => _DetailRow.fromModel(d)).toList();

        final isFc = _selectedCurrency?.baseCurrencyFlag == false;
        double _fcAmt(ApTransactionApply a) =>
            isFc && a.appliedAmountFc > 0 ? a.appliedAmountFc : a.appliedAmountLc;

        _applyRows = data.applies
            .where((a) => a.applyType == 'invoice')
            .map((a) => _ApplyRow(
                  appliedToId: a.appliedToId,
                  appliedToDocNo: a.appliedToDocNo ?? '',
                  appliedToDocDate: a.appliedToDocDate,
                  appliedToTotal: a.appliedAmountLc,
                  appliedAmountLc: _fcAmt(a),
                )).toList();
        _advanceRows = data.applies
            .where((a) => a.applyType == 'advance' || a.applyType == 'inv_advance')
            .map((a) => _ApplyRow(
                  appliedToId: a.appliedToId,
                  appliedToDocNo: a.appliedToDocNo ?? '',
                  appliedToDocDate: a.appliedToDocDate,
                  appliedToTotal: a.appliedAmountLc,
                  appliedAmountLc: _fcAmt(a),
                )).toList();
        _raRows = data.applies
            .where((a) => a.applyType == 'ra_invoice')
            .map((a) => _ApplyRow(
                  appliedToId: a.appliedToId,
                  appliedToDocNo: a.appliedToDocNo ?? '',
                  appliedToDocDate: a.appliedToDocDate,
                  appliedToTotal: a.appliedAmountLc,
                  appliedAmountLc: _fcAmt(a),
                )).toList();
        _advanceRefundRows = data.applies
            .where((a) => a.applyType == 'advance_refund')
            .map((a) => _ApplyRow(
                  appliedToId: a.appliedToId,
                  appliedToDocNo: a.appliedToDocNo ?? '',
                  appliedToDocDate: a.appliedToDocDate,
                  appliedToTotal: a.appliedAmountLc,
                  appliedAmountLc: _fcAmt(a),
                )).toList();

        for (final r in _paymentRows) r.dispose();
        _paymentRows = data.payments.map((p) => _PaymentRow.fromModel(p, isFc)).toList();
        _whtRows = data.whts.map((w) => _WhtRow.fromModel(w, _whtTypes)).toList();
      });
      _recalcTotals();
      if (h.status == 'Posted') _loadPostedGl();

      if (_hasApplySection && _selectedVendor?.id != null) {
        await _loadOpenInvoicesKeepApplied(_selectedVendor!.id!);
        await _loadOpenAdvancesKeepApplied(_selectedVendor!.id!);
      } else if (_isPurchaseInvoice && _selectedVendor?.id != null) {
        await _loadOpenAdvancesKeepApplied(_selectedVendor!.id!);
      }
      if (_hasAdvanceRefund && _selectedVendor?.id != null) {
        await _loadOpenAdvancesForRefundKeepApplied(_selectedVendor!.id!);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    setState(() {
      _transactionId = 0; _glEntryId = null;
      _docNo = 'AUTO'; _docDate = DateTime.now(); _dueDate = null;
      _apAccountId = null; _exchangeRate = 1.0;
      _priceIncludesVat = false;
      _refPoId = null; _refPoDocNo = null;
      _refNoCtrl.clear(); _descCtrl.clear();
      _taxInvNoCtrl.clear(); _taxInvDate = null;
      _creditMonthsCtrl.clear(); _creditDaysCtrl.clear(); _cashPurchase = null;
      _status = 'Draft'; _approvals = []; _isReadOnly = false;
      _reverseBlock = null; _reverseBlockRef = null; _voidBlock = null; _voidBlockRef = null; _reverseHistory = [];
      _selectedDocType = _allowedDocTypes.isNotEmpty ? _allowedDocTypes.first : null;
      _selectedBranch = _authService.defaultBranch;
      _selectedCurrency = _currencies.cast<Currency?>()
          .firstWhere((c) => c!.baseCurrencyFlag, orElse: () => null)
          ?? (_currencies.isNotEmpty ? _currencies.first : null);
      _selectedVendor = null; _docSetup = null;
      _dimSelections = {}; _dimNames = {};
      for (final r in _detailRows) r.dispose(); _detailRows = [];
      _applyRows = []; _openInvoices = [];
      for (final c in _applyCtrlMap.values) c.dispose(); _applyCtrlMap.clear();
      _advanceRows = []; _openAdvances = [];
      for (final c in _advanceCtrlMap.values) c.dispose(); _advanceCtrlMap.clear();
      _raRows = [];
      _advanceRefundRows = []; _openAdvancesForRefund = [];
      for (final c in _advanceRefundCtrlMap.values) c.dispose(); _advanceRefundCtrlMap.clear();
      for (final r in _paymentRows) r.dispose(); _paymentRows = [];
      for (final r in _glEditRows) r.dispose(); _glEditRows = [];
      _whtRows = [];
      _recalcTotals();
    });
  }

  void _recalcTotals() {
    double subFc = 0, discFc = 0, vatFc = 0;
    if (_isPayment) {
      subFc = _applyRows.fold(0.0, (s, a) => s + a.appliedAmountLc);
      final advance = _advanceRows.fold(0.0, (s, a) => s + a.appliedAmountLc);
      subFc = subFc - advance;
    } else if (_isRA) {
      subFc = _applyRows.fold(0.0, (s, a) => s + a.appliedAmountLc);
    } else if (_isAdvanceRefund) {
      subFc = _advanceRefundRows.fold(0.0, (s, a) => s + a.appliedAmountLc);
    } else {
      for (final r in _detailRows) {
        final a = _amt(r);
        subFc += a.gross; discFc += a.discount; vatFc += a.vat;
      }
    }
    final beforeVat = subFc - discFc;
    setState(() {
      _subtotalFc = subFc; _discountAmountFc = discFc;
      _beforeVatFc = beforeVat; _vatAmountFc = vatFc;
      _totalAmountFc = beforeVat + vatFc;
    });
    if (!_isReadOnly || _status == 'Approved') _rebuildGlRows();
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

  bool _validatePeriod(DateTime date) {
    if (_openPeriods.isEmpty) return true;
    return _openPeriods.any((p) {
      final from = p.periodStartDate;
      final to = p.periodEndDate;
      return !date.isBefore(from) && !date.isAfter(to);
    });
  }

  Future<void> _loadOpenInvoices(int vendorId) async {
    try {
      final inv = await _service.fetchOpenInvoices(vendorId);
      for (final c in _applyCtrlMap.values) c.dispose(); _applyCtrlMap.clear();
      if (mounted) setState(() { _openInvoices = inv; _applyRows = []; });
    } catch (_) {}
  }

  Future<void> _loadOpenInvoicesKeepApplied(int vendorId) async {
    try {
      final inv = await _service.fetchOpenInvoices(vendorId);
      final openIds = inv.map((i) => i.id).toSet();
      final missing = _applyRows.where((a) => !openIds.contains(a.appliedToId))
          .map((a) => ApOpenInvoice(id: a.appliedToId, docNo: a.appliedToDocNo,
              docDate: a.appliedToDocDate, totalAmountLc: a.appliedToTotal,
              balanceAmountLc: a.appliedAmountLc)).toList();
      if (mounted) setState(() => _openInvoices = [...inv, ...missing]);
    } catch (_) {}
  }

  Future<void> _loadOpenAdvances(int vendorId) async {
    try {
      final adv = await _service.fetchOpenAdvances(vendorId, transactionId: _transactionId);
      for (final c in _advanceCtrlMap.values) c.dispose(); _advanceCtrlMap.clear();
      if (mounted) setState(() { _openAdvances = adv; _advanceRows = []; });
    } catch (_) {}
  }

  Future<void> _loadOpenAdvancesKeepApplied(int vendorId) async {
    try {
      final adv = await _service.fetchOpenAdvances(vendorId, transactionId: _transactionId);
      final openIds = adv.map((i) => i.id).toSet();
      final missing = _advanceRows.where((a) => !openIds.contains(a.appliedToId))
          .map((a) => ApOpenInvoice(id: a.appliedToId, docNo: a.appliedToDocNo,
              docDate: a.appliedToDocDate, totalAmountLc: a.appliedToTotal,
              balanceAmountLc: a.appliedAmountLc)).toList();
      if (mounted) setState(() => _openAdvances = [...adv, ...missing]);
    } catch (_) {}
  }


  Future<void> _loadOpenAdvancesForRefund(int vendorId) async {
    try {
      final adv = await _service.fetchOpenAdvances(vendorId);
      for (final c in _advanceRefundCtrlMap.values) c.dispose(); _advanceRefundCtrlMap.clear();
      if (mounted) setState(() { _openAdvancesForRefund = adv; _advanceRefundRows = []; });
    } catch (_) {}
  }

  Future<void> _loadOpenAdvancesForRefundKeepApplied(int vendorId) async {
    try {
      final adv = await _service.fetchOpenAdvances(vendorId);
      final openIds = adv.map((i) => i.id).toSet();
      final missing = _advanceRefundRows.where((a) => !openIds.contains(a.appliedToId))
          .map((a) => ApOpenInvoice(id: a.appliedToId, docNo: a.appliedToDocNo,
              docDate: a.appliedToDocDate, totalAmountLc: a.appliedToTotal,
              balanceAmountLc: a.appliedAmountLc)).toList();
      if (mounted) setState(() => _openAdvancesForRefund = [...adv, ...missing]);
    } catch (_) {}
  }

  // ใบมัดจำ: เลือกใบสั่งซื้อของผู้ขายนี้
  Future<void> _pickRefPo() async {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    final vendorId = _selectedVendor?.id;
    if (vendorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please select a vendor first' : 'กรุณาเลือกผู้ขายก่อน')));
      return;
    }
    final o = await showOrderRefPicker(context,
        title: isEnglish ? 'Select Purchase Order' : 'เลือกใบสั่งซื้อ',
        isEnglish: isEnglish,
        load: () async => (await PoTransactionService().fetchRows(vendorId: vendorId))
            .map((h) => OrderRef(id: h.id, docNo: h.docNo, docDate: h.docDate, status: h.status,
                totalAmountLc: h.totalAmountLc != 0 ? h.totalAmountLc : h.totalValueLc))
            .toList());
    if (o != null && mounted) setState(() { _refPoId = o.id; _refPoDocNo = o.docNo; });
  }

  // วันครบกำหนด = วันที่เอกสาร + เครดิต (เดือน แล้วตามด้วยวัน)
  DateTime _calcDueDate(DateTime from) {
    var base = from;
    if (_creditMonths > 0) base = DateTime(base.year, base.month + _creditMonths, base.day);
    if (_creditDays > 0) base = base.add(Duration(days: _creditDays));
    return base;
  }

  // แก้ระยะเครดิต → วันครบกำหนดใหม่ (ว่างทั้งคู่ = คงวันครบกำหนดเดิม)
  void _onCreditTermChanged() => setState(() {
        if (_creditMonths > 0 || _creditDays > 0) _dueDate = _calcDueDate(_docDate);
      });

  void _onVendorChanged(ApVendor? vendor) {
    setState(() {
      if (vendor?.id != _selectedVendor?.id) { _refPoId = null; _refPoDocNo = null; }
      _selectedVendor = vendor;
      _apAccountId = vendor?.apAccountId;
      if (vendor != null && vendor.currencyCode.isNotEmpty) {
        final matched = _currencies.cast<Currency?>()
            .firstWhere((c) => c!.currencyCode == vendor.currencyCode, orElse: () => null);
        if (matched != null) {
          _selectedCurrency = matched;
          _exchangeRate = matched.baseRate > 0 ? matched.baseRate : 1.0;
        }
      }
      _creditMonthsCtrl.text = vendor != null && vendor.creditTermMonths > 0 ? '${vendor.creditTermMonths}' : '';
      _creditDaysCtrl.text = vendor != null && vendor.creditTermDays > 0 ? '${vendor.creditTermDays}' : '';
      if (_creditMonths > 0 || _creditDays > 0) _dueDate = _calcDueDate(_docDate);
    });
    if (_hasApplySection && vendor != null) {
      _loadOpenInvoices(vendor.id!);
      _loadOpenAdvances(vendor.id!);
    } else if (_isPurchaseInvoice && vendor != null) {
      _loadOpenAdvances(vendor.id!);
    }
    if (_hasAdvanceRefund && vendor != null) {
      _loadOpenAdvancesForRefund(vendor.id!);
    }
  }

  // ดึงข้อมูลจากใบแจ้งชำระ (RA) มา pre-fill apply rows ของ Payment — คล้ายกับ AR ที่ Receipt ดึงจากใบวางบิล
  Future<void> _lookupRemittanceAdviceFromRefNo() async {
    final isEnglish = _isEnglish;
    final docNo = _refNoCtrl.text.trim();
    if (docNo.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final ra = await _service.fetchRemittanceAdviceByDocNo(docNo);
      if (ra == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(isEnglish ? 'Remittance advice not found: $docNo' : 'ไม่พบใบแจ้งชำระ: $docNo'),
              backgroundColor: Colors.orange));
        }
        return;
      }
      final h = ra.header;
      if (_selectedVendor?.id != null && h.vendorId != _selectedVendor!.id) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(isEnglish
                  ? 'The remittance advice does not match the selected vendor'
                  : 'ใบแจ้งชำระไม่ตรงกับเจ้าหนี้ที่เลือก'),
              backgroundColor: Colors.red));
        }
        return;
      }
      // ถ้ายังไม่ได้เลือกเจ้าหนี้ ให้ set จาก RA แล้วโหลด open invoices ของเจ้าหนี้นั้น
      final vendorWasEmpty = _selectedVendor == null;
      if (vendorWasEmpty && _vendors.isNotEmpty) {
        try { _selectedVendor = _vendors.firstWhere((v) => v.id == h.vendorId); } catch (_) {}
      }
      // ─── ดึงสกุลเงินและอัตราแลกเปลี่ยนจากใบแจ้งชำระ ───
      final matchedCcy = _currencies.cast<Currency?>().firstWhere(
          (c) => c!.id == h.currencyId || c!.currencyCode == h.currencyCode,
          orElse: () => null);
      setState(() {
        if (matchedCcy != null) {
          _selectedCurrency = matchedCcy;
          _exchangeRate = h.exchangeRate > 0 ? h.exchangeRate : (matchedCcy.baseRate > 0 ? matchedCcy.baseRate : 1.0);
        }
        _applyRows = ra.applies
            .where((a) => a.applyType == 'invoice')
            .map((a) => _ApplyRow(
                  appliedToId: a.appliedToId,
                  appliedToDocNo: a.appliedToDocNo ?? '',
                  appliedToDocDate: a.appliedToDocDate,
                  appliedToTotal: a.appliedAmountLc,
                  appliedAmountLc: a.appliedAmountLc,
                ))
            .toList();
      });
      for (final a in _applyRows) {
        _applyCtrlMap.putIfAbsent(a.appliedToId, () => TextEditingController())
            .text = a.appliedAmountLc.toStringAsFixed(2);
      }
      if (_selectedVendor?.id != null) {
        await _loadOpenInvoicesKeepApplied(_selectedVendor!.id!);
      }
      _recalcTotals();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish
                ? 'Fetched remittance advice ${h.docNo} successfully'
                : 'ดึงข้อมูลใบแจ้งชำระ ${h.docNo} เรียบร้อย')));
      }
    } on RaAlreadyPaidException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.error_outline, color: Colors.red, size: 40),
            title: Text(isEnglish ? 'Remittance Advice Already Paid' : 'ใบแจ้งชำระถูกจ่ายแล้ว'),
            content: Text(isEnglish
                ? 'Remittance advice "$docNo" has already been paid.\nPayment No.: ${e.paymentDocNo}'
                : 'ใบแจ้งชำระ "$docNo" ถูกนำไปจ่ายชำระเรียบร้อยแล้ว\nโดยเลขที่ใบจ่ายชำระ: ${e.paymentDocNo}'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Close' : 'ปิด')),
            ],
          ),
        );
      }
      return;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // UserBranch (allowed branches) has no English name — resolve it from the
  // full bilingual Branch list (loaded in _initMasterData) by branchId.
  String _resolveBranchName(int? branchId, String fallbackThai) {
    if (_isEnglish) {
      final match = _allBranches.where((b) => b.id == branchId);
      if (match.isNotEmpty && match.first.branchNameEng.isNotEmpty) {
        return match.first.branchNameEng;
      }
    }
    return fallbackThai;
  }

  String _vendorLabel(ApVendor v) =>
      _isEnglish && (v.vendorNameEn ?? '').isNotEmpty ? v.vendorNameEn! : v.vendorNameTh;

  String _currencyLabel(Currency c) =>
      _isEnglish && c.currencyNameEng.isNotEmpty ? c.currencyNameEng : c.currencyNameThai;

  String _acctLabel(Account a) =>
      _isEnglish && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai;

  String _docTypeLabel(ModuleDocument d) =>
      _isEnglish && d.docNameEng.isNotEmpty ? d.docNameEng : d.docNameThai;

  Future<ApVendor?> _showVendorPicker() async {
    final isEnglish = _isEnglish;
    final searchCtrl = TextEditingController();
    List<ApVendor> filtered = List.from(_vendors);
    return showDialog<ApVendor>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        void doFilter() {
          final q = searchCtrl.text.toUpperCase();
          setS(() => filtered = q.isEmpty
              ? _vendors
              : _vendors.where((v) =>
                  v.vendorCode.toUpperCase().contains(q) ||
                  v.vendorNameTh.toUpperCase().contains(q) ||
                  (v.vendorNameEn ?? '').toUpperCase().contains(q)).toList());
        }
        return Dialog(
          child: SizedBox(
            width: 600, height: 500,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(labelText: isEnglish ? 'Search Vendor' : 'ค้นหาเจ้าหนี้', prefixIcon: const Icon(Icons.search), border: const OutlineInputBorder()),
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
  }

  Future<void> _showBranchDialog() async {
    final isEnglish = _isEnglish;
    final branches = _authService.allowedBranches;
    if (branches.isEmpty) return;
    final selected = await showDialog<UserBranch>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEnglish ? 'Select Branch' : 'เลือกสาขา'),
        content: SizedBox(
          width: 300, height: 300,
          child: ListView(children: [
            ListTile(
              title: Text(isEnglish ? '— Not specified —' : '— ไม่ระบุสาขา —'),
              onTap: () => Navigator.pop(ctx),
            ),
            ...branches.map((b) => ListTile(
              title: Text('${b.branchCode}  ${_resolveBranchName(b.branchId, b.branchNameThai)}'),
              onTap: () => Navigator.pop(ctx, b),
            )),
          ]),
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _selectedBranch = selected);
  }

  Future<void> _selectDate(bool isDueDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isDueDate ? (_dueDate ?? _docDate) : _docDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() {
      if (isDueDate) { _dueDate = picked; }
      else {
        _docDate = picked;
        if (_hasDueDate && (_creditMonths > 0 || _creditDays > 0)) _dueDate = _calcDueDate(picked);
      }
    });
  }

  // ข้อมูลที่บันทึก (หัวเอกสาร/บรรทัด/ตัดชำระ/จ่ายชำระ/ภาษีหัก ณ ที่จ่าย) — ใช้ทั้งตอนบันทึกและตรวจการแก้ไขค้าง
  ({ApTransactionHeader header, List<ApTransactionDetail> details, List<ApTransactionApply> applies,
    List<ApTransactionPayment> payments, List<ApTransactionWht> whts}) _savePayload() {
    final lc = _exchangeRate;
    final userName = _authService.currentUser?.userName ?? '';

    final header = ApTransactionHeader(
      id: _transactionId,
      docId: _selectedDocType!.id,
      docNo: _docNo,
      docDate: _docDate,
      dueDate: _hasDueDate ? _dueDate : null,
      vendorId: _selectedVendor!.id!,
      vendorCode: _selectedVendor!.vendorCode,
      vendorNameTh: _selectedVendor!.vendorNameTh,
      apAccountId: _apAccountId,
      currencyId: _selectedCurrency?.id,
      currencyCode: _selectedCurrency?.currencyCode ?? CurrencyService.baseCode,
      exchangeRate: _exchangeRate,
      subtotalFc: _subtotalFc,
      discountAmountFc: _discountAmountFc,
      beforeVatFc: _beforeVatFc,
      vatAmountFc: _vatAmountFc,
      totalAmountFc: _totalAmountFc,
      subtotalLc: _subtotalFc * lc,
      discountAmountLc: _discountAmountFc * lc,
      beforeVatLc: _beforeVatFc * lc,
      vatAmountLc: _vatAmountFc * lc,
      totalAmountLc: _totalAmountFc * lc,
      refNo: _refNoCtrl.text.isEmpty ? null : _refNoCtrl.text,
      description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
      status: _status,
      dim1Id: _dimSelections[1], dim2Id: _dimSelections[2],
      dim3Id: _dimSelections[3], dim4Id: _dimSelections[4], dim5Id: _dimSelections[5],
      branchId: _selectedBranch?.branchId,
      priceIncludesVat: _priceIncludesVat,
      refPoId: (_isAdvancePayment || _isPurchaseInvoice) ? _refPoId : null,
      creditTermMonths: _hasDueDate && _creditMonthsCtrl.text.trim().isNotEmpty ? _creditMonths : null,
      creditTermDays: _hasDueDate && _creditDaysCtrl.text.trim().isNotEmpty ? _creditDays : null,
      taxInvoiceNo: _hasDetailRows && _taxInvNoCtrl.text.trim().isNotEmpty ? _taxInvNoCtrl.text.trim() : null,
      taxInvoiceDate: _hasDetailRows && _taxInvNoCtrl.text.trim().isNotEmpty ? (_taxInvDate ?? _docDate) : null,
      createdBy: _transactionId == 0 ? userName : null,
      updatedBy: _transactionId != 0 ? userName : null,
    );

    final details = _detailRows.asMap().entries.map((e) {
      final i = e.key; final r = e.value;
      final qty = double.tryParse(r.qtyCtrl.text) ?? 0;
      final price = double.tryParse(r.priceCtrl.text) ?? 0;
      final discPct = double.tryParse(r.discPctCtrl.text) ?? 0;
      final amt = _amt(r);
      final disc = amt.discount;
      final afterDisc = amt.net;
      final vat = amt.vat;
      final itemName = r.itemNameCtrl.text.isEmpty ? null : r.itemNameCtrl.text;
      return ApTransactionDetail(
        lineNo: i + 1,
        itemCode: r.itemCodeCtrl.text.isEmpty ? null : r.itemCodeCtrl.text,
        itemName: itemName,
        description: itemName,
        quantity: qty, unitCode: r.unitCode, unitPriceFc: price,
        discountPercent: discPct, discountAmountFc: disc,
        subtotalFc: afterDisc, vatType: r.vatType, vatRate: r.vatRate,
        vatAmountFc: vat, totalAmountFc: afterDisc + vat,
        expenseAccountId: r.expenseAccountId ?? _docSetup?.expenseAccountId,
        subtotalLc: afterDisc * lc, vatAmountLc: vat * lc,
        totalAmountLc: (afterDisc + vat) * lc,
        isDeferredVat: r.isDeferredVat && r.vatType != 'NOVAT',
        dim1Id: r.dims[1], dim2Id: r.dims[2], dim3Id: r.dims[3], dim4Id: r.dims[4], dim5Id: r.dims[5],
      );
    }).toList();

    final applies = [
      ..._applyRows.map((a) => ApTransactionApply(
            appliedToId: a.appliedToId, appliedToDocNo: a.appliedToDocNo,
            appliedAmountFc: a.appliedAmountLc,
            appliedAmountLc: a.appliedAmountLc * lc,
            applyType: 'invoice',
          )),
      ..._advanceRows.map((a) => ApTransactionApply(
            appliedToId: a.appliedToId, appliedToDocNo: a.appliedToDocNo,
            appliedAmountFc: a.appliedAmountLc,
            appliedAmountLc: a.appliedAmountLc * lc,
            applyType: _isPurchaseInvoice ? 'inv_advance' : 'advance',
          )),
      ..._raRows.map((a) => ApTransactionApply(
            appliedToId: a.appliedToId, appliedToDocNo: a.appliedToDocNo,
            appliedAmountFc: a.appliedAmountLc,
            appliedAmountLc: a.appliedAmountLc * lc,
            applyType: 'ra_invoice',
          )),
      ..._advanceRefundRows.map((a) => ApTransactionApply(
            appliedToId: a.appliedToId, appliedToDocNo: a.appliedToDocNo,
            appliedAmountFc: a.appliedAmountLc,
            appliedAmountLc: a.appliedAmountLc * lc,
            applyType: 'advance_refund',
          )),
    ];

    final payments = _paymentRows.asMap().entries.map((e) {
      final i = e.key; final r = e.value;
      return ApTransactionPayment(
        lineNo: i + 1,
        paymentMethodId: r.paymentMethodId,
        paymentMethodCode: r.paymentMethodCode,
        paymentMethodName: r.paymentMethodName,
        paymentMethodType: r.paymentMethodType,
        cmBankAccountId: r.cmBankAccountId,
        glAccountId: r.glAccountId,
        amountLc: (double.tryParse(r.amountCtrl.text) ?? 0) * lc,
        amountFc: double.tryParse(r.amountCtrl.text) ?? 0,
        refNo: r.refNoCtrl.text.isEmpty ? null : r.refNoCtrl.text,
        paymentDate: r.paymentDate,
        remark: r.remarkCtrl.text.isEmpty ? null : r.remarkCtrl.text,
        drawerBankName: r.drawerBankNameCtrl.text.isEmpty ? null : r.drawerBankNameCtrl.text,
        drawerBankBranch: r.drawerBankBranchCtrl.text.isEmpty ? null : r.drawerBankBranchCtrl.text,
        drawerAccountNo: r.drawerAccountNoCtrl.text.isEmpty ? null : r.drawerAccountNoCtrl.text,
        checkbookId: _usesCheckbook(r) ? r.checkbookId : null,
      );
    }).toList();

    final whts = _whtRows.map((w) => ApTransactionWht(
          whtTypeId:    w.selectedWhtType?.id,
          whtType:      w.selectedWhtType?.whtName,
          incomeType:   w.selectedWhtType?.incomeType,
          whtRate:      w.selectedWhtType?.whtRate ?? 0,
          baseAmountLc: (double.tryParse(w.baseCtrl.text) ?? 0) * lc,
          whtAmountLc:  (double.tryParse(w.whtCtrl.text) ?? 0) * lc,
          description:  w.descCtrl.text.isEmpty ? null : w.descCtrl.text,
        )).toList();

    return (header: header, details: details, applies: applies, payments: payments, whts: whts);
  }

  Future<void> _save(String action) async {
    final isEnglish = _isEnglish;
    // เอกสารที่ผ่านการอนุมัติแล้ว (Approved) ไม่มีอะไรให้แก้ไข — Post ตรงได้เลยไม่ต้องผ่าน update
    if (action == 'Post' && _status == 'Approved') {
      setState(() => _isLoading = true);
      try {
        await _service.postTransaction(_transactionId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish ? 'Saved and posted successfully' : 'บันทึกและ Post เรียบร้อย'),
          ));
          widget.onSaveSuccess();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish
              ? 'Post failed: ${e.toString().replaceFirst('Exception: ', '')}'
              : 'Post ไม่สำเร็จ: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDocType == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please select a document type' : 'กรุณาเลือกประเภทเอกสาร')));
      return;
    }
    if (_selectedVendor == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please select a vendor' : 'กรุณาเลือกเจ้าหนี้')));
      return;
    }
    if (action == 'Post' && !_isRA && !_validatePeriod(_docDate)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Document date is not within an open accounting period' : 'วันที่เอกสารไม่อยู่ในงวดบัญชีที่เปิด')));
      return;
    }

    _recalcTotals();
    // รายงานภาษีซื้อต้องแสดงเลขที่ใบกำกับของผู้ขาย — บังคับเมื่อมี VAT (ไม่รวม VAT รอตัดบัญชี ที่รับรู้ตอนจ่ายชำระ)
    if (action == 'Post' && _taxInvRequired && _taxInvNoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish
          ? 'Please enter the vendor tax invoice no. (this document has input VAT)'
          : 'กรุณาระบุเลขที่ใบกำกับภาษีของผู้ขาย (เอกสารมีภาษีซื้อ)')));
      return;
    }
    if (_invAdvanceTotal > _totalAmountFc + 0.005) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish
          ? 'Deposit deducted exceeds the bill total'
          : 'ยอดหักเงินมัดจำเกินยอดรวมใบตั้งหนี้')));
      return;
    }
    // ใบจ่ายชำระที่หักมัดจำ แต่ใบตั้งหนี้ที่จ่ายหักมัดจำไปแล้วตอนตั้งหนี้ — เตือนก่อนหักซ้ำ
    if (action == 'Post' && _isPayment && _advanceRows.isNotEmpty) {
      final already = _openInvoices.where((inv) => inv.invAdvanceAmountFc > 0 && _applyRows.any((a) => a.appliedToId == inv.id)).toList();
      if (already.isNotEmpty) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(isEnglish ? 'Deposit already deducted on the bill' : 'ใบตั้งหนี้หักเงินมัดจำไปแล้ว'),
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isEnglish
                  ? 'These bills already deducted a deposit when recorded. Deduct another deposit in this payment?'
                  : 'ใบตั้งหนี้ต่อไปนี้หักเงินมัดจำไปแล้วตอนตั้งหนี้ ต้องการหักเงินมัดจำในใบจ่ายชำระนี้อีกหรือไม่'),
              const SizedBox(height: 8),
              for (final inv in already) Text('${inv.docNo}: ${_fmt.format(inv.invAdvanceAmountFc)}', style: const TextStyle(fontSize: 13)),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEnglish ? 'Continue' : 'ทำต่อ')),
            ],
          ),
        );
        if (ok != true || !mounted) return;
      }
    }
    final p = _savePayload();
    final header = p.header, details = p.details, applies = p.applies, payments = p.payments, whts = p.whts;

    setState(() => _isLoading = true);
    try {
      if (_transactionId == 0) {
        await _service.createTransaction(
          header: header, details: details, applies: applies,
          payments: payments, whts: whts, action: action,
        );
      } else {
        await _service.updateTransaction(
          id: _transactionId, header: header, details: details, applies: applies,
          payments: payments, whts: whts,
        );
        // เอกสาร Draft ที่บันทึกไว้แล้ว (มี id) — updateTransaction เก็บเป็น Draft เสมอ
        // ต้อง Post แยกอีกขั้นเพื่อให้ผ่านการตรวจงวดบัญชี/ลงบัญชีจริง
        if (action == 'Post') {
          await _service.postTransaction(_transactionId);
        }
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

  Future<void> _submitForApproval() async {
    final isEnglish = _isEnglish;
    final menu = MenuScope.of(context);
    final menuId = menu?.id;
    if (menuId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish ? 'Cannot determine current menu' : 'ไม่สามารถระบุเมนูปัจจุบันได้'),
          backgroundColor: Colors.red));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEnglish ? 'Confirm Submit for Approval' : 'ยืนยันการส่งอนุมัติ'),
        content: Text(isEnglish ? 'Submit $_docNo for approval?' : 'ส่งอนุมัติ $_docNo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEnglish ? 'Submit' : 'ส่งอนุมัติ')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _isLoading = true);
    try {
      await _service.submitTransaction(_transactionId, menuId: menuId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish ? 'Submitted for approval successfully' : 'ส่งอนุมัติสำเร็จ')));
        await _loadTransactionData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _void() async {
    final isEnglish = _isEnglish;
    final reasonCtrl = TextEditingController();
    final voidReason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String? errorText;
        return StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: Row(children: [Icon(Icons.cancel_outlined, color: Colors.red[700], size: 20), const SizedBox(width: 8), Text(isEnglish ? 'Confirm Void Document' : 'ยืนยันการยกเลิกเอกสาร')]),
            content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red[200]!)),
                child: Text(
                    isEnglish
                        ? 'A voided document cannot be restored.\n'
                          'The original GL entry is kept and a reversing entry is posted today (the period must be open).\n'
                          'If the original period is still open, consider "Reverse to Draft" instead.'
                        : 'เอกสารที่ยกเลิกแล้วไม่สามารถกู้คืนได้\n'
                          'รายการบัญชีเดิมยังอยู่ ระบบจะลงรายการกลับรายการ ณ วันนี้ (งวดต้องเปิดอยู่)\n'
                          'ถ้างวดของเอกสารยังเปิดอยู่ ควรใช้ "ถอยเป็นร่าง" แทน',
                    style: const TextStyle(fontSize: 13)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonCtrl, maxLines: 2, autofocus: true,
                decoration: InputDecoration(
                    labelText: isEnglish ? 'Void Reason *' : 'เหตุผลการยกเลิก *',
                    hintText: isEnglish ? 'e.g. Incorrect amount' : 'เช่น ยอดเงินผิด',
                    border: const OutlineInputBorder(), errorText: errorText),
              ),
            ])),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEnglish ? 'Close' : 'ปิด')),
              ElevatedButton.icon(
                onPressed: () {
                  if (reasonCtrl.text.trim().isEmpty) { setD(() => errorText = isEnglish ? 'Please enter a reason' : 'กรุณาระบุเหตุผล'); return; }
                  Navigator.pop(ctx, reasonCtrl.text.trim());
                },
                icon: const Icon(Icons.check, size: 16),
                label: Text(isEnglish ? 'Confirm Void' : 'ยืนยัน Void'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
              ),
            ],
          ),
        );
      },
    );
    if (voidReason == null) return;
    setState(() => _isLoading = true);
    try {
      await _service.voidTransaction(_transactionId, voidReason);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Document voided successfully' : 'ยกเลิกเอกสารเรียบร้อย'))); widget.onSaveSuccess(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // เหตุผลที่ถอยเป็นร่างไม่ได้ (ตาม reverse_block จาก backend) — null = ถอยได้
  String? _reverseBlockMessage(bool isEnglish) => _blockMessage(_reverseBlock, _reverseBlockRef, isEnglish);
  String? _voidBlockMessage(bool isEnglish) => _blockMessage(_voidBlock, _voidBlockRef, isEnglish);

  String? _blockMessage(String? code, String? blockRef, bool isEnglish) {
    final ref = blockRef != null ? ' ($blockRef)' : '';
    switch (code) {
      case 'NOT_POSTED':
        return isEnglish ? 'Only posted documents can be voided (delete drafts instead)' : 'ยกเลิกได้เฉพาะเอกสารที่โพสต์แล้ว (เอกสารร่างให้ลบแทน)';
      case null:
        return null;
      case 'NOT_REVERSIBLE':
        return isEnglish ? 'Only posted or submitted/approved documents can be reversed' : 'ถอยได้เฉพาะเอกสารที่โพสต์แล้ว หรือรออนุมัติ/อนุมัติแล้ว';
      case 'IM_SOURCE':
        return isEnglish ? 'Created by Inventory — reverse it from the source IM document' : 'สร้างจากโมดูลสินค้าคงคลัง กรุณาถอยจากเอกสาร IM ต้นทาง';
      case 'CONSIGNMENT':
        return isEnglish ? 'Created by consignment settlement — void it from that screen' : 'สร้างจากการตั้งหนี้สินค้าฝากขาย กรุณายกเลิกจากหน้าจอตั้งหนี้สินค้าฝากขาย';
      case 'IMPORTED':
        return isEnglish ? 'Imported opening balance without GL entry' : 'เอกสารยอดยกมาที่นำเข้า ไม่มีรายการบัญชี';
      case 'PERIOD_CLOSED':
        return isEnglish ? 'The accounting period of this document is closed' : 'งวดบัญชีของเอกสารนี้ปิดแล้ว';
      case 'APPLIED':
        return isEnglish ? 'Referenced by other documents$ref' : 'มีเอกสารอ้างอิงเอกสารนี้อยู่$ref';
      case 'PAID':
        return isEnglish ? 'Already paid (bulk payment)' : 'มีการจ่ายชำระแล้ว (จ่ายแบบกลุ่ม)';
      case 'RA_PAID':
        return isEnglish ? 'This remittance advice has been paid$ref' : 'ใบแจ้งชำระนี้ถูกนำไปจ่ายชำระแล้ว$ref';
      case 'PAYMENT_RUN':
        return isEnglish ? 'Included in an unfinished payment run$ref' : 'อยู่ในชุดจ่ายเงินที่ยังไม่เสร็จ$ref';
      case 'FX_REVAL':
        return isEnglish ? 'Included in an FX revaluation$ref' : 'อยู่ในการปรับมูลค่าอัตราแลกเปลี่ยน$ref';
      case 'CM_CLEARED':
        return isEnglish ? 'Bank item already cleared/reconciled$ref' : 'รายการรับ/จ่ายเงินผ่านธนาคารเคลียร์/กระทบยอดแล้ว$ref';
      default:
        return code;
    }
  }

  Future<void> _reverse() async {
    final isEnglish = _isEnglish;
    final isPosted = _status == 'Posted';
    final reason = await showDocReasonDialog(
      context,
      isEnglish: isEnglish,
      title: isEnglish ? 'Reverse to Draft' : 'ถอยเอกสารกลับเป็นร่าง',
      message: isPosted
          ? (isEnglish
              ? 'The GL entry is removed and the document returns to Draft.\n'
                'Edit it and post again with the same document no. $_docNo (and the same GL entry no.)'
              : 'ระบบจะลบรายการบัญชีออกและเอกสารกลับเป็นร่าง\n'
                'แก้ไขแล้วโพสต์ใหม่ได้ด้วยเลขที่เดิม $_docNo (เลขที่รายการบัญชีเดิม)')
          : (isEnglish
              ? 'The document returns to Draft and approvals are cleared.\nIt must be submitted for approval again.'
              : 'เอกสารจะกลับเป็นร่างและล้างขั้นตอนอนุมัติ\nต้องส่งขออนุมัติใหม่'),
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

  @override
  Widget build(BuildContext context) {
    widget.actions?.scheduleRefresh();
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    // การ์ดข้อมูลเอกสาร fix ด้านบน (สูงไม่เกิน 60% แล้วเลื่อนในการ์ด) — การ์ดอื่นเลื่อนด้านล่าง (แบบเดียวกับ IM / GL / AR)
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
                // แผงอนุมัติกลาง (ตามลำดับ / คนใดคนหนึ่ง) — ปฏิเสธ = เอกสารกลับเป็นร่าง
                if (_approvals.isNotEmpty && _status != 'Draft') ...[
                  DocApprovalPanel(
                    docNo: _docNo,
                    approvals: _approvals,
                    approvalMode: _approvalMode,
                    awaiting: _status == 'Submitted' && !widget.viewOnly,
                    onApprove: (r) => _service.approveTransaction(_transactionId, remarks: r),
                    onReject: (r) => _service.rejectTransaction(_transactionId, remarks: r),
                    onDone: _loadTransactionData,
                  ),
                  const SizedBox(height: 12),
                ],
                if (_reverseHistory.isNotEmpty) ...[
                  DocReverseHistoryPanel(
                      history: _reverseHistory, isDeleted: _status == 'Deleted', isEnglish: isEnglish,
                      margin: EdgeInsets.zero),
                  const SizedBox(height: 12),
                ],
                if (_hasDetailRows) ...[
                  _buildDetailSection(),
                  const SizedBox(height: 16),
                ],
                if (_hasApplySection) ...[
                  _buildApplySection(),
                  const SizedBox(height: 16),
                ],
                // ใบจ่ายชำระ: หักเงินมัดจำตอนจ่าย (ใบตั้งหนี้หักในการ์ดสรุปยอด)
                if (_isPayment) ...[
                  _buildAdvanceSection(),
                  const SizedBox(height: 16),
                ],
                if (_hasAdvanceRefund) ...[
                  _buildAdvanceRefundSection(),
                  const SizedBox(height: 16),
                ],
                if (_hasWhtSection) ...[
                  _buildWhtSection(),
                  const SizedBox(height: 16),
                ],
                if (_hasPaymentRows) ...[
                  _buildPaymentSection(),
                  const SizedBox(height: 16),
                ],
                _buildTotalsSection(),
                if (_isPurchaseInvoice && _cashPurchase != null) ...[
                  const SizedBox(height: 16),
                  _buildCashPurchaseSection(),
                ],
                if (_selectedVendor != null && _selectedDocType != null) ...[
                  const SizedBox(height: 12),
                  _buildGlSection(),
                ],
              ],
            ),
          ),
        ),
      ]))),
    );
  }

  // ── ปุ่มของเอกสาร (แสดงบน AppBar ของหน้าจอ แทนแถบปุ่มเดิม) — ปุ่ม "กลับ" ตัดออก (ใช้ลูกศรย้อนกลับ) ──
  List<DocBarAction> _barActions(bool en) {
    final a = <DocBarAction>[];
    final isDraft = _status == 'Draft';
    final isApproved = _status == 'Approved';
    final isPosted = _status == 'Posted';
    final canEditNow = !widget.viewOnly && isDraft;
    // RA / ใบจ่ายชำระที่ไม่มีเลขอ้างอิง บังคับขออนุมัติ — Draft ต้องส่งขออนุมัติก่อน Post ได้หลังอนุมัติแล้วเท่านั้น
    final canPostNow = !widget.viewOnly && (isApproved || (isDraft && !_canRequestApproval));
    if (canEditNow && _transactionId != 0 && widget.canDelete) {
      a.add(DocBarAction.secondary(en ? 'Delete' : 'ลบ', _delete, DocBarColors.delete));
    }
    if (!widget.viewOnly && widget.canDelete && (isPosted || _status == 'Submitted' || isApproved)) {
      final msg = _reverseBlockMessage(en);
      a.add(DocBarAction.secondary(en ? 'Reverse to Draft' : 'ถอยเป็นร่าง', msg == null ? _reverse : null, DocBarColors.reverse, tooltip: msg));
    }
    if (canEditNow) {
      a.add(DocBarAction.secondary(en ? 'Save Draft' : 'บันทึก Draft', () => _save('Draft'), DocBarColors.save));
    }
    if (canEditNow && _transactionId != 0 && _canRequestApproval) {
      a.add(DocBarAction.primary(en ? 'Request Approval' : 'ขออนุมัติ', _submitForApproval, DocBarColors.submit));
    }
    if (canPostNow) {
      a.add(DocBarAction.primary(en ? 'Post Document' : 'Post เอกสาร', () => _save('Post'), DocBarColors.post));
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
    if (_selectedDocType == null || _selectedVendor == null) {
      return 'incomplete|${_selectedDocType?.id}|${_selectedVendor?.id}|${_detailRows.length}|${_descCtrl.text}|${_refNoCtrl.text}';
    }
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
    if (_isLoading || widget.viewOnly || _status != 'Draft') return false;
    return _cleanFingerprint != null && _cleanFingerprint != _formFingerprint();
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
            child: cells(r),
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

  // ช่องยอดจับคู่ (ชำระ / หักมัดจำ / หักลดหนี้) — กรอกยอด >0 = เลือกเอกสารนั้น, ว่าง/0 = ไม่เลือก
  Widget _applyAmountCell(TextEditingController ctrl, double? existing, void Function(double amount) onAmount) => _isReadOnly
      ? _cBox(existing == null || existing == 0 ? '' : _fmt.format(existing), bold: true)
      : TextFormField(
          controller: ctrl,
          textAlign: TextAlign.right,
          style: _numStyle.copyWith(fontWeight: FontWeight.w600),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: _cDec(fill: (existing ?? 0) > 0 ? _hAuto : Colors.white),
          onChanged: (v) => onAmount(double.tryParse(v) ?? 0),
        );

  // บวก/แก้/ลบแถวจับคู่ตามยอดที่กรอก
  void _upsertApply(List<_ApplyRow> rows, _ApplyRow Function(double) make, int id, double amount) {
    final idx = rows.indexWhere((a) => a.appliedToId == id);
    setState(() {
      if (amount <= 0) {
        if (idx >= 0) rows.removeAt(idx);
      } else if (idx >= 0) {
        rows[idx] = make(amount);
      } else {
        rows.add(make(amount));
      }
      _recalcTotals();
    });
  }

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


  // ── การ์ดข้อมูลเอกสาร: 4 กลุ่มสี (เหมือน IM / AR) — fix ด้านบน, ย่อเป็นแถบสรุปได้ ─────────────────────
  Widget _buildHeaderSection() {
    final isEnglish = _isEnglish;
    final auto = _selectedDocType?.isAutoNumbering == true;
    final vendorName = _selectedVendor == null ? '' : _vendorLabel(_selectedVendor!);
    final inOpenPeriod = _validatePeriod(_docDate);
    final needApproval = _status == 'Draft' && _canRequestApproval;

    final titleRow = Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(
        child: Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(isEnglish ? 'Document Header' : 'ข้อมูลเอกสาร', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          if (_docNo.isNotEmpty && _docNo != 'AUTO')
            Text(_docNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F5C5C))),
          docStatusBadge(_status, label: apTransactionStatusLabel(_status, isEnglish)),
          if (!_isReadOnly && !_isRA && !inOpenPeriod)
            _chip(isEnglish ? 'Date is not in an open period' : 'วันที่ไม่อยู่ในงวดที่เปิด', const Color(0xFFB71C1C), const Color(0xFFFDECEA)),
          // ใบแจ้งชำระต้องขออนุมัติเสมอ / ใบจ่ายชำระที่ไม่มีเลขอ้างอิง (ไม่ได้ดึงจากใบแจ้งชำระ) ต้องขออนุมัติ
          if (needApproval)
            _chip(
                _isRA
                    ? (isEnglish ? 'Approval required' : 'ต้องขออนุมัติ')
                    : (isEnglish ? 'No reference · approval required' : 'ไม่มีเลขอ้างอิง · ต้องขออนุมัติ'),
                const Color(0xFF8A4B00),
                const Color(0xFFFFF0D9)),
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
          key: ValueKey('ap_docNo_${widget.resetKey}_$_transactionId'),
          initialValue: _docNo == 'AUTO' ? '' : _docNo,
          decoration: _hDec(isEnglish ? 'Doc No.' : 'เลขที่เอกสาร', req: !auto, auto: auto)
              .copyWith(hintText: auto ? (isEnglish ? 'Auto' : 'อัตโนมัติ') : null),
          readOnly: _isReadOnly || auto,
          onChanged: (v) => _docNo = v.isEmpty ? 'AUTO' : v,
        ),
        _datePick(isEnglish ? 'Doc Date' : 'วันที่เอกสาร', _docDate, () => _selectDate(false), req: true, auto: true),
      ]),
    ]);

    final poField = OrderRefField(
      docNo: _refPoDocNo,
      readOnly: _isReadOnly,
      decoration: _hDec(isEnglish ? 'Purchase Order' : 'อ้างอิงใบสั่งซื้อ', auto: true),
      onClear: () => setState(() {
        _refPoId = null;
        _refPoDocNo = null;
      }),
      onPick: _pickRefPo,
    );
    final refField = TextFormField(
      controller: _refNoCtrl,
      readOnly: _isReadOnly,
      decoration: _hDec(_isPayment ? (isEnglish ? 'Reference No. (remittance advice)' : 'เลขที่อ้างอิง (ใบแจ้งชำระ)') : (isEnglish ? 'Reference No.' : 'เลขที่อ้างอิง'))
          .copyWith(
        suffixIcon: (_isPayment && !_isReadOnly)
            ? IconButton(
                icon: _searchIcon,
                tooltip: isEnglish ? 'Fetch from remittance advice' : 'ดึงข้อมูลจากใบแจ้งชำระ',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onPressed: _lookupRemittanceAdviceFromRefNo,
              )
            : null,
      ),
      onChanged: _isPayment ? (_) => setState(() {}) : null,
    );

    // ② เจ้าหนี้ / อ้างอิง
    final g2 = docFilterGroup(2, isEnglish ? 'Vendor / Reference' : 'เจ้าหนี้ / อ้างอิง', color: _gParty, [
      InkWell(
        onTap: _isReadOnly
            ? null
            : () async {
                final v = await _showVendorPicker();
                if (v != null) _onVendorChanged(v);
              },
        child: InputDecorator(
          decoration: _hDec(isEnglish ? 'Vendor' : 'เจ้าหนี้', req: true, suffixIcon: _isReadOnly ? null : _searchIcon),
          child: _selectedVendor == null
              ? Text(isEnglish ? 'Click to select vendor' : 'คลิกเพื่อเลือกเจ้าหนี้', style: TextStyle(color: Colors.grey.shade600), maxLines: 1)
              : Text.rich(
                  TextSpan(children: [
                    TextSpan(text: _selectedVendor!.vendorCode, style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: '  $vendorName', style: const TextStyle(color: _ink2)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
        ),
      ),
      if (_hasDetailRows)
        _hRow([
          TextFormField(
            controller: _taxInvNoCtrl,
            readOnly: _isReadOnly,
            inputFormatters: [LengthLimitingTextInputFormatter(50)],
            decoration: _hDec(isEnglish ? 'Vendor Tax Invoice No.' : 'เลขที่ใบกำกับภาษี (ผู้ขาย)', req: _taxInvRequired),
          ),
          InkWell(
            onTap: _isReadOnly
                ? null
                : () async {
                    final picked = await showDatePicker(
                        context: context, initialDate: _taxInvDate ?? _docDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (picked != null) setState(() => _taxInvDate = picked);
                  },
            child: InputDecorator(
              decoration: _hDec(isEnglish ? 'Tax Invoice Date' : 'วันที่ใบกำกับภาษี', auto: true, suffixIcon: _isReadOnly ? null : _calIcon),
              child: Row(children: [
                Expanded(
                  child: Text(_taxInvDate != null ? _dateFmt.format(_taxInvDate!) : (isEnglish ? '(document date)' : '(วันที่เอกสาร)'),
                      maxLines: 1, style: TextStyle(color: _taxInvDate == null ? Colors.grey.shade600 : null)),
                ),
                if (!_isReadOnly && _taxInvDate != null)
                  InkWell(onTap: () => setState(() => _taxInvDate = null), child: const Icon(Icons.clear, size: 14, color: Colors.grey)),
              ]),
            ),
          ),
        ]),
      // อ้างอิงใบสั่งซื้อ + เลขที่อ้างอิง แถวเดียวกัน (ประเภทที่ไม่มีใบสั่งซื้อ = เลขที่อ้างอิงเต็มแถว)
      if (_isPurchaseInvoice || _isAdvancePayment) _hRow([poField, refField]) else refField,
    ]);

    // ③ เงื่อนไขการเงิน
    final isBase = _selectedCurrency?.baseCurrencyFlag ?? true;
    final g3 = docFilterGroup(3, isEnglish ? 'Financial Terms' : 'เงื่อนไขการเงิน', color: _gFin, [
      if (_hasDueDate)
        _hRow([
          TextFormField(
            controller: _creditMonthsCtrl,
            readOnly: _isReadOnly,
            textAlign: TextAlign.right,
            style: _numStyle,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
            decoration: _hDec(isEnglish ? 'Credit (months)' : 'เครดิต (เดือน)', auto: true),
            onChanged: (_) => _onCreditTermChanged(),
          ),
          TextFormField(
            controller: _creditDaysCtrl,
            readOnly: _isReadOnly,
            textAlign: TextAlign.right,
            style: _numStyle,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
            decoration: _hDec(isEnglish ? 'Credit (days)' : 'เครดิต (วัน)', auto: true),
            onChanged: (_) => _onCreditTermChanged(),
          ),
          _datePick(isEnglish ? 'Due Date' : 'วันครบกำหนด', _dueDate, () => _selectDate(true), auto: true),
        ]),
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
              : (v) => setState(() {
                    _selectedCurrency = v;
                    _exchangeRate = v?.baseRate ?? 1.0;
                  }),
        ),
        TextFormField(
          key: ValueKey('ap_rate_${widget.resetKey}_${_transactionId}_${_selectedCurrency?.currencyCode}'),
          initialValue: _exchangeRate.toStringAsFixed(6),
          textAlign: TextAlign.right,
          style: _numStyle,
          decoration: _hDec(isEnglish ? 'Exchange Rate' : 'อัตราแลกเปลี่ยน', auto: true, forcedReadOnly: isBase),
          keyboardType: TextInputType.number,
          readOnly: _isReadOnly || isBase,
          onChanged: (v) => setState(() => _exchangeRate = double.tryParse(v) ?? 1.0),
        ),
      ]),
    ]);

    // ④ เพิ่มเติม
    final g4 = docFilterGroup(4, isEnglish ? 'More' : 'เพิ่มเติม', color: _gMore, [
      InkWell(
        onTap: _isReadOnly ? null : _showBranchDialog,
        child: InputDecorator(
          decoration: _hDec(isEnglish ? 'Branch' : 'สาขา', auto: true, suffixIcon: _isReadOnly ? null : _searchIcon),
          child: _selectedBranch == null
              ? Text(isEnglish ? '— Not specified —' : '— ไม่ระบุสาขา —', style: TextStyle(color: Colors.grey.shade600), maxLines: 1)
              : Text.rich(
                  TextSpan(children: [
                    TextSpan(text: _selectedBranch!.branchCode, style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(
                        text: '  ${_resolveBranchName(_selectedBranch!.branchId, _selectedBranch!.branchNameThai)}',
                        style: const TextStyle(color: _ink2)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
        ),
      ),
      // มิติหัวเอกสาร — แถวละ 2 ช่อง
      for (var i = 0; i < _dimTypes.length; i += 2)
        _hRow([
          for (final t in _dimTypes.skip(i).take(2)) _headerDimPicker(t),
          if (i + 1 >= _dimTypes.length) const SizedBox.shrink(),
        ]),
      TextFormField(
        controller: _descCtrl,
        readOnly: _isReadOnly,
        decoration: _hDec(isEnglish ? 'Description' : 'คำอธิบาย'),
      ),
    ]);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          titleRow,
          const SizedBox(height: 10),
          if (_headerExpanded) _groupLayout([g1, g2, g3, g4], const [10, 12, 12, 12]) else _headerSummary(isEnglish, vendorName),
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

  // แถบสรุปตอนย่อการ์ด — จุดสีบอกกลุ่มที่มา
  Widget _headerSummary(bool isEnglish, String vendorName) {
    Widget item(Color c, String label, String value) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 6),
          Text('$label ', style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700)),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(value, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
          ),
        ]);
    final terms = [
      if (_creditMonths > 0) isEnglish ? '$_creditMonths mo' : '$_creditMonths เดือน',
      if (_creditDays > 0) isEnglish ? '$_creditDays d' : '$_creditDays วัน',
    ].join(' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFF6F8FA), borderRadius: BorderRadius.circular(4)),
      child: Wrap(spacing: 22, runSpacing: 6, children: [
        if (_selectedDocType != null) item(_gDoc, isEnglish ? 'Type' : 'ประเภท', '${_selectedDocType!.docCode} ${_docTypeLabel(_selectedDocType!)}'),
        item(_gDoc, isEnglish ? 'Date' : 'วันที่', _dateFmt.format(_docDate)),
        if (_selectedVendor != null) item(_gParty, isEnglish ? 'Vendor' : 'เจ้าหนี้', '${_selectedVendor!.vendorCode} $vendorName'),
        if (_hasDetailRows && _taxInvNoCtrl.text.trim().isNotEmpty) item(_gParty, isEnglish ? 'Tax Inv.' : 'ใบกำกับ', _taxInvNoCtrl.text.trim()),
        if ((_refPoDocNo ?? '').isNotEmpty) item(_gParty, 'PO', _refPoDocNo!),
        if (_refNoCtrl.text.trim().isNotEmpty) item(_gParty, isEnglish ? 'Ref' : 'อ้างอิง', _refNoCtrl.text.trim()),
        if (_hasDueDate && (terms.isNotEmpty || _dueDate != null))
          item(_gFin, isEnglish ? 'Credit' : 'เครดิต',
              [if (terms.isNotEmpty) terms, if (_dueDate != null) '${isEnglish ? 'due' : 'ครบ'} ${_dateFmt.format(_dueDate!)}'].join(' · ')),
        if (_selectedCurrency != null)
          item(_gFin, isEnglish ? 'Currency' : 'สกุลเงิน',
              _selectedCurrency!.baseCurrencyFlag ? _selectedCurrency!.currencyCode : '${_selectedCurrency!.currencyCode} @ ${_exchangeRate.toStringAsFixed(4)}'),
        if (_descCtrl.text.trim().isNotEmpty) item(_gMore, isEnglish ? 'Description' : 'คำอธิบาย', _descCtrl.text.trim()),
      ]),
    );
  }

  // ── Detail Section (PI / CN / DN / มัดจำ) ──────────────────────────────────────────
  void _onDetailFieldChanged(_DetailRow r) {
    r.totalCtrl.text = _amt(r).total.toStringAsFixed(2);
    _recalcTotals();
  }

  void _onTotalChanged(_DetailRow r, String value) {
    final total   = double.tryParse(value)              ?? 0;
    final qty     = double.tryParse(r.qtyCtrl.text)     ?? 0;
    final discPct = double.tryParse(r.discPctCtrl.text)  ?? 0;
    // ราคารวม VAT: ยอดรวมคือราคาที่กรอกหลังส่วนลด ไม่ต้องถอด VAT
    final netFactor = _priceIncludesVat ? 1.0 : 1 + (r.vatType == 'NOVAT' ? 0.0 : r.vatRate / 100);
    final afterDisc  = total / netFactor;
    final qtyFactor  = qty * (1 - discPct / 100);
    r.priceCtrl.text = qtyFactor != 0 ? (afterDisc / qtyFactor).toStringAsFixed(4) : '0.0000';
    _recalcTotals();
  }

  void _removeDetailRow(int i) {
    setState(() { _detailRows[i].dispose(); _detailRows.removeAt(i); });
    _recalcTotals();
  }

  void _addDetailRow() {
    final defaultVat = _vatRates.isNotEmpty ? _vatRates.first : null;
    setState(() => _detailRows.add(_DetailRow(
          vatType: defaultVat?.vatCode ?? 'VAT7',
          vatRate: defaultVat?.rate ?? 7.0,
          expenseAccountId: _docSetup?.expenseAccountId,
        )));
  }

  void _setPriceIncludesVat(bool v) {
    setState(() {
      _priceIncludesVat = v;
      for (final r in _detailRows) {
        r.totalCtrl.text = _amt(r).total.toStringAsFixed(2);
      }
    });
    _recalcTotals();
  }

  String _vatLabel(String vatCode) {
    final v = _vatRates.cast<VatRate?>()
        .firstWhere((x) => x?.vatCode == vatCode, orElse: () => null);
    if (v != null) {
      final rateStr = v.rate.toStringAsFixed(v.rate % 1 == 0 ? 0 : 2);
      return '${v.vatCode}  $rateStr%';
    }
    if (_isEnglish) {
      const enLabels = {'VAT7': 'VAT 7%', 'VAT0': 'VAT 0%', 'NOVAT': 'No VAT'};
      return enLabels[vatCode] ?? vatCode;
    }
    return vatTypeLabels[vatCode] ?? vatCode;
  }

  String _safeVatCode(String vatCode) {
    if (_vatRates.any((v) => v.vatCode == vatCode)) return vatCode;
    return _vatRates.isNotEmpty ? _vatRates.first.vatCode : vatCode;
  }

  // ── การ์ดรายการสินค้า / บริการ: ตารางแบบการ์ดรายการสินค้าของ IM (ช่อง 36, 4 กลุ่มสี) ──────────────────
  Widget _buildDetailSection() {
    final isEnglish = _isEnglish;
    final netLabel = isEnglish ? 'Net Amount' : 'ยอดสุทธิ';
    final vatAmtLabel = isEnglish ? 'VAT Amount' : 'ยอด VAT';
    final totalLabel = isEnglish ? 'Total' : 'รวม';
    final cols = <(String, double, int, bool)>[
      ('#', 28, 0, false),
      (isEnglish ? 'Item Code' : 'รหัสสินค้า', 110, 1, false),
      (isEnglish ? 'Item / Service Name *' : 'ชื่อสินค้า/บริการ *', 0, 1, false),
      (isEnglish ? 'Qty' : 'จำนวน', 80, 2, true),
      if (_showUnitCol) (isEnglish ? 'Unit' : 'หน่วย', 70, 2, false),
      (isEnglish ? 'Unit Price' : 'ราคา/หน่วย', 100, 3, true),
      (isEnglish ? 'Disc %' : 'ส่วนลด %', 70, 3, true),
      (netLabel, 110, 3, true),
      ('VAT *', 104, 4, false),
      (vatAmtLabel, 92, 4, true),
      (totalLabel, 110, 4, true),
      (isEnglish ? 'Deferred VAT' : 'VAT รอตัด', 64, 4, false),
      (isEnglish ? 'Account' : 'บัญชี', 196, 4, false),
      if (_dimTypes.isNotEmpty) (isEnglish ? 'Dimensions' : 'มิติ', 146, 4, false),
      if (!_isReadOnly) ('', 36, 0, false),
    ];

    final rows = <List<Widget>>[];
    double sumNet = 0, sumVat = 0, sumTotal = 0;
    for (var i = 0; i < _detailRows.length; i++) {
      final r = _detailRows[i];
      final amt = _amt(r);
      sumNet += amt.net;
      sumVat += amt.vat;
      sumTotal += double.tryParse(r.totalCtrl.text) ?? amt.total;
      final accountId = r.expenseAccountId ?? _docSetup?.expenseAccountId;
      rows.add([
        Text('${i + 1}.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade700)),
        _cellField(r.itemCodeCtrl, numeric: false),
        _cellField(r.itemNameCtrl, numeric: false),
        _cellField(r.qtyCtrl, allow: r'[0-9.]', onChanged: (_) => _onDetailFieldChanged(r)),
        if (_showUnitCol) _cBox(r.unitLabel(isEnglish), right: false),
        _cellField(r.priceCtrl, allow: r'[0-9.]', onChanged: (_) => _onDetailFieldChanged(r)),
        _cellField(r.discPctCtrl, allow: r'[0-9.]', onChanged: (_) => _onDetailFieldChanged(r)),
        _cBox(_fmt.format(amt.net), bold: true),
        _isReadOnly
            ? _cBox(_vatLabel(r.vatType), right: false)
            : DropdownButtonFormField<String>(
                value: _safeVatCode(r.vatType),
                isDense: true,
                isExpanded: true,
                decoration: _cDec(fill: Colors.white),
                items: _vatRates.map((v) {
                  final rateStr = v.rate.toStringAsFixed(v.rate % 1 == 0 ? 0 : 2);
                  return DropdownMenuItem<String>(
                      value: v.vatCode, child: Text('${v.vatCode}  $rateStr%', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis));
                }).toList(),
                onChanged: (code) {
                  if (code == null) return;
                  final vr = _vatRates.cast<VatRate?>().firstWhere((x) => x?.vatCode == code, orElse: () => null);
                  setState(() {
                    r.vatType = code;
                    r.vatRate = vr?.rate ?? 0.0;
                  });
                  _onDetailFieldChanged(r);
                },
              ),
        _cBox(_fmt.format(amt.vat)),
        // รวม: กรอกยอดรวมแล้วถอดราคาได้
        _isReadOnly
            ? _cBox(_fmt.format(double.tryParse(r.totalCtrl.text) ?? 0), bold: true)
            : _cellField(r.totalCtrl, allow: r'[0-9.]', bold: true, onChanged: (v) => _onTotalChanged(r, v)),
        Tooltip(
          message: isEnglish ? 'VAT recognized on payment, not on invoicing' : 'VAT บันทึกตอนจ่ายชำระ ไม่ใช่ตอนตั้งหนี้',
          child: Center(
            child: Checkbox(
              value: r.isDeferredVat,
              visualDensity: VisualDensity.compact,
              onChanged: (r.vatType == 'NOVAT' || _isReadOnly)
                  ? null
                  : (v) {
                      setState(() => r.isDeferredVat = v ?? false);
                      _recalcTotals();
                    },
            ),
          ),
        ),
        GlLineAccountCell(
          accounts: _accounts,
          accountId: accountId,
          readOnly: _isReadOnly,
          width: 196,
          boxed: true,
          onChanged: (a) {
            setState(() => r.expenseAccountId = a.id);
            _rebuildGlRows();
          },
        ),
        if (_dimTypes.isNotEmpty)
          GlLineDimsCell(
            dimTypes: _dimTypes,
            dimValues: _dimValues,
            lineDims: r.dims,
            headerDims: _dimSelections,
            account: findAccount(_accounts, accountId),
            readOnly: _isReadOnly,
            width: 146,
            boxed: true,
            onChanged: (d) {
              setState(() => r.dims = d);
              _rebuildGlRows();
            },
          ),
        if (!_isReadOnly)
          IconButton(
            tooltip: isEnglish ? 'Delete line' : 'ลบรายการ',
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            onPressed: () => _removeDetailRow(i),
          ),
      ]);
    }

    // แถวรวม: ตรงคอลัมน์ ยอดสุทธิ / ยอด VAT / รวม
    final footer = <Widget>[];
    for (final c in cols) {
      if (footer.isEmpty) {
        footer.add(const SizedBox.shrink());
      } else if (footer.length == 1) {
        footer.add(_footerLabel(isEnglish ? 'Total ${_detailRows.length} lines' : 'รวม ${_detailRows.length} รายการ'));
      } else if (c.$1 == netLabel) {
        footer.add(_footerAmount(sumNet));
      } else if (c.$1 == vatAmtLabel) {
        footer.add(_footerAmount(sumVat));
      } else if (c.$1 == totalLabel) {
        footer.add(_footerAmount(sumTotal));
      } else {
        footer.add(const SizedBox.shrink());
      }
    }

    return _card(
      isEnglish ? 'Items / Services' : 'รายการสินค้า / บริการ',
      chips: [_chip(isEnglish ? '${_detailRows.length} lines' : '${_detailRows.length} รายการ', const Color(0xFF1E4F8F), _hAuto)],
      actions: [
        // ราคารวม VAT — ยอดก่อน VAT/VAT/ยอดรวมคำนวณใหม่ทั้งเอกสาร
        InkWell(
          onTap: _isReadOnly ? null : () => _setPriceIncludesVat(!_priceIncludesVat),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Checkbox(
              value: _priceIncludesVat,
              visualDensity: VisualDensity.compact,
              onChanged: _isReadOnly ? null : (v) => _setPriceIncludesVat(v ?? false),
            ),
            Text(isEnglish ? 'Prices include VAT' : 'ราคารวม VAT', style: const TextStyle(fontSize: 13)),
          ]),
        ),
        if (!_isReadOnly) _addButton(isEnglish ? 'Add Line' : 'เพิ่มรายการ', _addDetailRow),
      ],
      [
        _gridTable(
          cols: cols,
          groupTitle: (g) => switch (g) {
            1 => isEnglish ? 'Item / Service' : 'สินค้า / บริการ',
            2 => isEnglish ? 'Quantity' : 'จำนวน',
            3 => isEnglish ? 'Price / Discount' : 'ราคา / ส่วนลด',
            _ => isEnglish ? 'VAT / Account' : 'VAT / บัญชี',
          },
          rows: rows,
          footer: footer,
          empty: Text(isEnglish ? 'No items — click Add Line' : 'ไม่มีรายการ — กดเพิ่มรายการ', style: const TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  // ยอดในสกุลเงินเอกสาร (เอกสาร FC แปลงจากยอด LC ด้วยอัตราของเอกสารต้นทาง)
  double _docAmt(ApOpenInvoice inv, double lc) {
    final isFc = _selectedCurrency?.baseCurrencyFlag == false;
    return isFc && inv.exchangeRate > 0 ? lc / inv.exchangeRate : lc;
  }

  // ตารางหักเงินมัดจำ — ใบตั้งหนี้ (หักตอนตั้งหนี้ 'inv_advance' อยู่ในการ์ดสรุปยอด) / ใบจ่ายชำระ (หักตอนจ่าย 'advance')
  Widget _advanceTable() {
    final isEnglish = _isEnglish;
    final isFc = _selectedCurrency?.baseCurrencyFlag == false;
    final sfx = isFc ? ' (${_selectedCurrency?.currencyCode ?? 'FC'})' : '';
    final totalAdv = _advanceRows.fold(0.0, (s, a) => s + a.appliedAmountLc);
    final rows = <List<Widget>>[
      for (final adv in _openAdvances)
        () {
          final existing = _advanceRows.where((a) => a.appliedToId == adv.id).firstOrNull;
          final ctrl = _advanceCtrlMap.putIfAbsent(adv.id, () => TextEditingController(text: existing?.appliedAmountLc.toStringAsFixed(2) ?? ''));
          final balance = _docAmt(adv, adv.balanceAmountLc);
          return <Widget>[
            Text(adv.docNo, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(adv.docDate != null ? _dateFmt.format(adv.docDate!) : '—', style: _numStyle),
            (adv.refPoDocNo ?? '').isEmpty ? docDash : Text(adv.refPoDocNo!, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(_fmt.format(_docAmt(adv, adv.totalAmountLc)), style: _numStyle),
            Text(_fmt.format(balance), style: _numStyle.copyWith(color: Colors.orange[800])),
            _applyAmountCell(ctrl, existing?.appliedAmountLc, (amount) => _upsertApply(
                _advanceRows,
                (a) => _ApplyRow(
                    appliedToId: adv.id, appliedToDocNo: adv.docNo, appliedToDocDate: adv.docDate, appliedToTotal: balance, appliedAmountLc: a),
                adv.id,
                amount)),
          ];
        }(),
    ];
    return _gridTable(
      cols: [
        (isEnglish ? 'Deposit No.' : 'เลขที่มัดจำ', 0, 1, false),
        (isEnglish ? 'Date' : 'วันที่', 92, 1, false),
        (isEnglish ? 'Purchase Order' : 'อ้างอิงใบสั่งซื้อ', 120, 2, false),
        ('${isEnglish ? 'Deposit' : 'ยอดมัดจำ'}$sfx', 112, 3, true),
        ('${isEnglish ? 'Balance' : 'คงเหลือ'}$sfx', 112, 3, true),
        ('${isEnglish ? 'Deduct' : 'หักมัดจำ'}$sfx', 124, 3, true),
      ],
      groupTitle: (g) => g == 1 ? (isEnglish ? 'Deposit' : 'ใบจ่ายมัดจำ') : g == 2 ? (isEnglish ? 'Reference' : 'อ้างอิง') : (isEnglish ? 'Amounts' : 'ยอด'),
      rows: rows,
      footer: [
        _footerLabel(isEnglish ? 'Total deducted' : 'หักมัดจำรวม'),
        for (var i = 0; i < 4; i++) const SizedBox.shrink(),
        _footerAmount(totalAdv),
      ],
      empty: Text(isEnglish ? 'No open deposits' : 'ไม่มีใบจ่ายมัดจำค้าง', style: const TextStyle(color: Colors.grey)),
    );
  }

  Widget _advanceChip() {
    final isEnglish = _isEnglish;
    return _chip(isEnglish ? '${_openAdvances.length} open · ${_advanceRows.length} selected' : 'ค้าง ${_openAdvances.length} ใบ · เลือก ${_advanceRows.length}',
        const Color(0xFF8A4B00), const Color(0xFFFFF0D9));
  }

  // ── หักเงินมัดจำ (ใบจ่ายชำระ) ─────────────────────────────────
  Widget _buildAdvanceSection() {
    final isEnglish = _isEnglish;
    return _card(
      isEnglish ? 'Deposit Deduction' : 'หักเงินมัดจำ',
      chips: [if (_selectedVendor != null) _advanceChip()],
      [
        if (_selectedVendor == null)
          Text(isEnglish ? 'Please select a vendor first' : 'กรุณาเลือกเจ้าหนี้ก่อน', style: const TextStyle(color: Colors.grey))
        else
          _advanceTable(),
      ],
    );
  }

  // ── จับคู่ชำระหนี้ (ใบจ่ายชำระ) / เลือกใบตั้งหนี้ (ใบแจ้งชำระ) ─────────────────────
  Widget _buildApplySection() {
    final isEnglish = _isEnglish;
    final isFc = _selectedCurrency?.baseCurrencyFlag == false;
    final sfx = isFc ? ' (${_selectedCurrency?.currencyCode ?? 'FC'})' : '';
    final totalApplied = _applyRows.fold(0.0, (s, a) => s + a.appliedAmountLc);
    final docDateOnly = DateTime(_docDate.year, _docDate.month, _docDate.day);
    final cols = <(String, double, int, bool)>[
      (isEnglish ? 'Doc No.' : 'เลขที่', 0, 1, false),
      (isEnglish ? 'Date' : 'วันที่', 92, 1, false),
      (isEnglish ? 'Due Date' : 'ครบกำหนด', 100, 1, false),
      (isEnglish ? 'Vendor Tax Inv.' : 'ใบกำกับภาษี (ผู้ขาย)', 140, 2, false),
      (isEnglish ? 'Purchase Order' : 'อ้างอิงใบสั่งซื้อ', 120, 2, false),
      ('${isEnglish ? 'Total' : 'ยอดรวม'}$sfx', 116, 3, true),
      ('${isEnglish ? 'Balance' : 'คงเหลือ'}$sfx', 116, 3, true),
      ('${_isRA ? (isEnglish ? 'Amount' : 'ยอดแจ้งชำระ') : (isEnglish ? 'Pay this time' : 'จ่ายครั้งนี้')}$sfx', 130, 3, true),
    ];
    final rows = <List<Widget>>[];
    for (final inv in _openInvoices) {
      final existing = _applyRows.where((a) => a.appliedToId == inv.id).firstOrNull;
      final ctrl = _applyCtrlMap.putIfAbsent(inv.id, () => TextEditingController(text: existing?.appliedAmountLc.toStringAsFixed(2) ?? ''));
      final balance = _docAmt(inv, inv.balanceAmountLc);
      final overdue = inv.dueDate != null && inv.dueDate!.isBefore(docDateOnly);
      rows.add([
        Text(inv.docNo, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(inv.docDate != null ? _dateFmt.format(inv.docDate!) : '—', style: _numStyle),
        inv.dueDate == null
            ? docDash
            : overdue
                ? _chip(_dateFmt.format(inv.dueDate!), const Color(0xFFB71C1C), const Color(0xFFFDECEA))
                : Text(_dateFmt.format(inv.dueDate!), style: _numStyle),
        (inv.taxInvoiceNo ?? '').isEmpty ? docDash : Text(inv.taxInvoiceNo!, maxLines: 1, overflow: TextOverflow.ellipsis),
        (inv.refPoDocNo ?? '').isEmpty ? docDash : Text(inv.refPoDocNo!, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(_fmt.format(_docAmt(inv, inv.totalAmountLc)), style: _numStyle),
        Text(_fmt.format(balance), style: _numStyle.copyWith(color: Colors.blue[700])),
        _applyAmountCell(ctrl, existing?.appliedAmountLc, (amount) => _upsertApply(
            _applyRows,
            (a) => _ApplyRow(
                appliedToId: inv.id, appliedToDocNo: inv.docNo, appliedToDocDate: inv.docDate, appliedToTotal: balance, appliedAmountLc: a),
            inv.id,
            amount)),
      ]);
    }
    return _card(
      _isRA ? (isEnglish ? 'Invoices to Pay (Remittance Advice)' : 'ใบตั้งหนี้ที่แจ้งชำระ') : (isEnglish ? 'Match Payment' : 'จับคู่ชำระหนี้'),
      chips: [
        if (_selectedVendor != null)
          _chip(isEnglish ? '${_openInvoices.length} open · ${_applyRows.length} selected' : 'ค้าง ${_openInvoices.length} ใบ · เลือก ${_applyRows.length}',
              const Color(0xFF1E4F8F), _hAuto),
      ],
      [
        if (_selectedVendor == null)
          Text(isEnglish ? 'Please select a vendor first' : 'กรุณาเลือกเจ้าหนี้ก่อน', style: const TextStyle(color: Colors.grey))
        else
          _gridTable(
            cols: cols,
            groupTitle: (g) => g == 1 ? (isEnglish ? 'Invoice' : 'ใบตั้งหนี้') : g == 2 ? (isEnglish ? 'Reference' : 'อ้างอิง') : (isEnglish ? 'Amounts' : 'ยอด'),
            rows: rows,
            footer: [
              _footerLabel(isEnglish ? 'Total selected ${_applyRows.length}' : 'รวมที่เลือก ${_applyRows.length} ใบ'),
              for (var i = 1; i < cols.length - 1; i++) const SizedBox.shrink(),
              _footerAmount(totalApplied),
            ],
            empty: Text(isEnglish ? 'No outstanding invoices found' : 'ไม่พบใบตั้งหนี้ค้างชำระ', style: const TextStyle(color: Colors.grey)),
          ),
      ],
    );
  }

  // ── รับคืนเงินมัดจำ ─────────────────────────────────────────────────
  Widget _buildAdvanceRefundSection() {
    final isEnglish = _isEnglish;
    final totalRefund = _advanceRefundRows.fold(0.0, (s, a) => s + a.appliedAmountLc);
    return _card(
      isEnglish ? 'Deposit Refund' : 'รับคืนเงินมัดจำ',
      chips: [
        if (_selectedVendor != null)
          _chip(
              isEnglish
                  ? '${_openAdvancesForRefund.length} open · ${_advanceRefundRows.length} selected'
                  : 'ค้าง ${_openAdvancesForRefund.length} ใบ · เลือก ${_advanceRefundRows.length}',
              const Color(0xFF6A1B9A),
              const Color(0xFFF3E5F5)),
      ],
      [
        if (_selectedVendor == null)
          Text(isEnglish ? 'Please select a vendor first' : 'กรุณาเลือกเจ้าหนี้ก่อน', style: const TextStyle(color: Colors.grey))
        else
          _gridTable(
            cols: [
              (isEnglish ? 'Deposit No.' : 'เลขที่มัดจำ', 0, 1, false),
              (isEnglish ? 'Date' : 'วันที่', 92, 1, false),
              (isEnglish ? 'Purchase Order' : 'อ้างอิงใบสั่งซื้อ', 120, 2, false),
              (isEnglish ? 'Deposit' : 'ยอดมัดจำ', 120, 3, true),
              (isEnglish ? 'Balance' : 'คงเหลือ', 120, 3, true),
              (isEnglish ? 'Refund' : 'รับคืน', 130, 3, true),
            ],
            groupTitle: (g) => g == 1 ? (isEnglish ? 'Deposit' : 'ใบจ่ายมัดจำ') : g == 2 ? (isEnglish ? 'Reference' : 'อ้างอิง') : (isEnglish ? 'Amounts' : 'ยอด'),
            rows: [
              for (final adv in _openAdvancesForRefund)
                () {
                  final existing = _advanceRefundRows.where((a) => a.appliedToId == adv.id).firstOrNull;
                  final ctrl = _advanceRefundCtrlMap.putIfAbsent(
                      adv.id, () => TextEditingController(text: existing?.appliedAmountLc.toStringAsFixed(2) ?? ''));
                  final balance = _docAmt(adv, adv.balanceAmountLc);
                  return <Widget>[
                    Text(adv.docNo, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(adv.docDate != null ? _dateFmt.format(adv.docDate!) : '—', style: _numStyle),
                    (adv.refPoDocNo ?? '').isEmpty ? docDash : Text(adv.refPoDocNo!, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(_fmt.format(_docAmt(adv, adv.totalAmountLc)), style: _numStyle),
                    Text(_fmt.format(balance), style: _numStyle.copyWith(color: Colors.purple[700])),
                    _applyAmountCell(ctrl, existing?.appliedAmountLc, (amount) => _upsertApply(
                        _advanceRefundRows,
                        (a) => _ApplyRow(
                            appliedToId: adv.id, appliedToDocNo: adv.docNo, appliedToDocDate: adv.docDate, appliedToTotal: balance, appliedAmountLc: a),
                        adv.id,
                        amount)),
                  ];
                }(),
            ],
            footer: [
              _footerLabel(isEnglish ? 'Total refund' : 'ยอดรับคืนรวม'),
              for (var i = 0; i < 4; i++) const SizedBox.shrink(),
              _footerAmount(totalRefund),
            ],
            empty: Text(isEnglish ? 'No deposits pending refund' : 'ไม่พบใบจ่ายมัดจำค้างรับคืน', style: const TextStyle(color: Colors.grey)),
          ),
      ],
    );
  }

  // ── ภาษีหัก ณ ที่จ่าย ──────────────────────────────────────────────────────
  double get _totalWht => _whtRows.fold(0.0, (s, w) => s + (double.tryParse(w.whtCtrl.text) ?? 0));

  Widget _buildWhtSection() {
    final isEnglish = _isEnglish;
    final base = CurrencyService.baseCode;
    final rows = <List<Widget>>[];
    for (var i = 0; i < _whtRows.length; i++) {
      final w = _whtRows[i];
      final rate = w.selectedWhtType?.whtRate ?? 0;
      void recalc() {
        final b = double.tryParse(w.baseCtrl.text) ?? 0;
        w.whtCtrl.text = (b * (w.selectedWhtType?.whtRate ?? 0) / 100).toStringAsFixed(2);
      }

      String typeLabel(CdWhtType t) => '${t.whtCode} — ${isEnglish && (t.whtNameEn ?? '').isNotEmpty ? t.whtNameEn! : t.whtName}';
      rows.add([
        _isReadOnly
            ? _cBox(w.selectedWhtType == null ? '—' : typeLabel(w.selectedWhtType!), right: false)
            : DropdownButtonFormField<CdWhtType?>(
                value: w.selectedWhtType,
                isExpanded: true,
                isDense: true,
                decoration: _cDec(fill: Colors.white, err: w.selectedWhtType == null),
                items: [
                  DropdownMenuItem(value: null, child: Text(isEnglish ? '— Select type —' : '— เลือกประเภท —', style: const TextStyle(fontSize: 13))),
                  ..._whtTypes.map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(typeLabel(t), style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (t) {
                  setState(() {
                    w.selectedWhtType = t;
                    recalc();
                  });
                  _recalcTotals();
                },
              ),
        _cBox(rate > 0 ? '${rate.toStringAsFixed(2)}%' : '—'),
        _cellField(w.baseCtrl, allow: r'[0-9.]', onChanged: (_) {
          setState(recalc);
          _recalcTotals();
        }),
        _cellField(w.whtCtrl, allow: r'[0-9.]', bold: true, onChanged: (_) => _recalcTotals()),
        _cellField(w.descCtrl, numeric: false),
        if (!_isReadOnly)
          IconButton(
            tooltip: isEnglish ? 'Delete' : 'ลบ',
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            onPressed: () {
              setState(() {
                w.dispose();
                _whtRows.removeAt(i);
              });
              _recalcTotals();
            },
          ),
      ]);
    }
    return _card(
      isEnglish ? 'Withholding Tax' : 'ภาษีหัก ณ ที่จ่าย',
      chips: [_chip(isEnglish ? '${_whtRows.length} lines' : '${_whtRows.length} รายการ', const Color(0xFF1E4F8F), _hAuto)],
      actions: [if (!_isReadOnly) _addButton(isEnglish ? 'Add WHT' : 'เพิ่มรายการ', () => setState(() => _whtRows.add(_WhtRow())))],
      [
        _gridTable(
          cols: [
            (isEnglish ? 'WHT Type *' : 'ประเภทภาษี *', 0, 1, false),
            (isEnglish ? 'Rate' : 'อัตรา', 80, 1, true),
            ('${isEnglish ? 'Tax base' : 'ฐานภาษี'} ($base)', 130, 3, true),
            ('${isEnglish ? 'WHT' : 'ภาษีที่หัก'} ($base)', 130, 3, true),
            (isEnglish ? 'Description' : 'คำอธิบาย', 0, 4, false),
            if (!_isReadOnly) ('', 36, 0, false),
          ],
          groupTitle: (g) => g == 1 ? (isEnglish ? 'Tax Type' : 'ประเภทภาษี') : g == 3 ? (isEnglish ? 'Amounts' : 'ยอด') : (isEnglish ? 'Details' : 'รายละเอียด'),
          rows: rows,
          footer: [
            _footerLabel(isEnglish ? 'Total WHT' : 'รวมภาษีหัก ณ ที่จ่าย'),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            _footerAmount(_totalWht),
            const SizedBox.shrink(),
            if (!_isReadOnly) const SizedBox.shrink(),
          ],
          empty: Text(isEnglish ? 'No withholding tax' : 'ไม่มีการหัก ณ ที่จ่าย', style: const TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  // ── Payment Section ───────────────────────────────────────────────────────
  // สมุดเช็ค: จ่ายด้วยเช็คของใบจ่ายชำระ/จ่ายมัดจำ (80/60) — เลขเช็คว่าง = backend ใช้เลขถัดไปของสมุดเช็คตอน Post
  bool _usesCheckbook(_PaymentRow r) => (_isPayment || _isAdvancePayment) && r.paymentMethodType == 'CHECK' && r.cmBankAccountId != null;
  Future<void> _ensureCheckbooks(int bankAccountId) async {
    if (_checkbooks.containsKey(bankAccountId)) return;
    _checkbooks[bankAccountId] = const [];
    try {
      final list = await CmCheckbookService().fetchCheckbooks(bankAccountId: bankAccountId);
      if (mounted) setState(() => _checkbooks[bankAccountId] = list);
    } catch (_) {}
  }
  String? _nextCheckNo(_PaymentRow r) =>
      (_checkbooks[r.cmBankAccountId] ?? const <CmCheckbook>[]).where((b) => b.id == r.checkbookId).firstOrNull?.nextCheckNo;

  // ยอดที่ต้องจ่าย/รับคืนตามวิธีชำระ: ใบจ่ายชำระ/จ่ายมัดจำ = ยอดเอกสาร − ภาษีหัก ณ ที่จ่าย, รับคืนมัดจำ = ยอดเอกสาร
  double get _paymentExpected => _hasWhtSection ? _totalAmountFc - _totalWht : _totalAmountFc;

  Widget _buildPaymentSection() {
    final isEnglish = _isEnglish;
    final currency = _selectedCurrency?.currencyCode ?? CurrencyService.baseCode;
    final totalPayments = _paymentRows.fold(0.0, (s, r) => s + (double.tryParse(r.amountCtrl.text) ?? 0));
    final expected = _paymentExpected;
    final diff = expected - totalPayments;
    final ok = diff.abs() <= 0.005;
    final statusChip = ok
        ? _chip(isEnglish ? 'Fully paid' : 'ครบยอด', const Color(0xFF1E6B3A), const Color(0xFFE6F4EA))
        : diff > 0
            ? _chip('${isEnglish ? 'Short' : 'ขาด'} ${_fmt.format(diff)}', const Color(0xFF8A4B00), const Color(0xFFFFF0D9))
            : _chip('${isEnglish ? 'Over' : 'เกิน'} ${_fmt.format(-diff)}', const Color(0xFFB71C1C), const Color(0xFFFDECEA));
    final refund = _isAdvanceRefund;

    return _card(
      refund ? (isEnglish ? 'Refund Received By' : 'วิธีรับคืนเงิน') : (isEnglish ? 'Payment Methods' : 'วิธีจ่ายชำระ'),
      chips: [if (_paymentRows.isNotEmpty || expected != 0) statusChip],
      actions: [
        if (!_isReadOnly)
          _addButton(isEnglish ? 'Add Payment Method' : 'เพิ่มวิธีชำระ', () async {
            await CmPaymentMethodListWidget.search(context, onSelected: (pm) {
              setState(() {
                _paymentRows.add(_PaymentRow(
                  paymentMethodId: pm.id,
                  paymentMethodCode: pm.methodCode,
                  paymentMethodName: isEnglish && (pm.methodNameEn ?? '').isNotEmpty ? pm.methodNameEn : pm.methodNameTh,
                  paymentMethodType: pm.methodType,
                  cmBankAccountId: pm.cmBankAccountId,
                  glAccountId: pm.glAccountId,
                  paymentDate: _docDate,
                ));
              });
              _rebuildGlRows();
            });
          }),
      ],
      [
        if (_paymentRows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                  isEnglish ? 'No payment methods yet — click "Add Payment Method"' : 'ยังไม่มีวิธีชำระ — กด "เพิ่มวิธีชำระ"',
                  style: const TextStyle(color: Colors.grey)),
            ),
          )
        else
          for (var i = 0; i < _paymentRows.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _buildPaymentRowCard(i, _paymentRows[i]),
          ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 380,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _sumRow('${refund ? (isEnglish ? 'To receive' : 'ยอดที่ต้องรับคืน') : (isEnglish ? 'To pay' : 'ยอดที่ต้องจ่าย')} ($currency)', expected),
              _sumRow('${refund ? (isEnglish ? 'Total received' : 'รวมรับคืน') : (isEnglish ? 'Total paid' : 'รวมจ่ายชำระ')} ($currency)', totalPayments),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: ok ? const Color(0xFFE6F4EA) : const Color(0xFFFDECEA), borderRadius: BorderRadius.circular(6)),
                child: Row(children: [
                  Expanded(
                    child: Text(ok ? (isEnglish ? 'Difference · fully paid' : 'ส่วนต่าง · ครบยอด') : (isEnglish ? 'Difference' : 'ส่วนต่าง'),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ok ? const Color(0xFF1E6B3A) : const Color(0xFFB71C1C))),
                  ),
                  Text(_fmt.format(diff),
                      style: _numStyle.copyWith(fontSize: 17, fontWeight: FontWeight.bold, color: ok ? const Color(0xFF1E6B3A) : const Color(0xFFB71C1C))),
                ]),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  // แถววิธีชำระ: กลุ่มย่อย (แถบสีตามประเภท) — แถวแรก วิธีชำระ/จำนวนเงิน/วันที่/หมายเหตุ, แถวสอง เลขอ้างอิง/เช็ค
  Widget _buildPaymentRowCard(int index, _PaymentRow r) {
    final isEnglish = _isEnglish;
    final type = r.paymentMethodType;
    final isCheck = type == 'CHECK';
    final ownCheck = _usesCheckbook(r);
    final typeColor = {
          'CASH': Colors.green, 'CHECK': Colors.blue, 'TRANSFER': Colors.indigo,
          'CREDIT_CARD': Colors.purple, 'DEBIT_CARD': Colors.deepPurple,
          'QR_CODE': Colors.teal, 'MOBILE_BANKING': Colors.cyan,
          'BILL_OF_EXCHANGE': Colors.brown, 'OTHER': Colors.grey,
        }[type] ??
        Colors.grey;
    final isFc = _selectedCurrency?.baseCurrencyFlag == false;

    Widget f(String label, TextEditingController c, {String? hint, bool numeric = false, bool req = false, int flex = 2, void Function(String)? onChanged}) =>
        Expanded(flex: flex, child: _payField(label: label, ctrl: c, hint: hint, numeric: numeric, req: req, onChanged: onChanged));

    final row1 = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        flex: 3,
        child: InputDecorator(
          decoration: _hDec((cmMethodTypeOptions[type] ?? type).split(' ').first, forcedReadOnly: true),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: r.paymentMethodCode ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: typeColor.shade800)),
              TextSpan(text: '  ${r.paymentMethodName ?? ''}', style: const TextStyle(color: _ink2)),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      const SizedBox(width: 8),
      f('${isEnglish ? 'Amount' : 'จำนวนเงิน'}${isFc ? ' (${_selectedCurrency?.currencyCode})' : ''}', r.amountCtrl, hint: '0.00', numeric: true, req: true,
          onChanged: (_) => _recalcTotals()),
      const SizedBox(width: 8),
      Expanded(
        flex: 2,
        child: _datePick(
          isCheck ? (isEnglish ? 'Check Date' : 'วันที่บนเช็ค') : (isEnglish ? 'Payment Date' : 'วันที่ชำระ'),
          r.paymentDate,
          () async {
            final picked = await showDatePicker(context: context, initialDate: r.paymentDate ?? _docDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
            if (picked != null) setState(() => r.paymentDate = picked);
          },
          auto: true,
        ),
      ),
      const SizedBox(width: 8),
      f(isEnglish ? 'Remark' : 'หมายเหตุ', r.remarkCtrl, flex: 3),
      if (!_isReadOnly)
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 4),
          child: IconButton(
            tooltip: isEnglish ? 'Delete' : 'ลบ',
            icon: Icon(Icons.delete_outline, color: Colors.red[400], size: 18),
            visualDensity: VisualDensity.compact,
            onPressed: () {
              setState(() {
                _paymentRows[index].dispose();
                _paymentRows.removeAt(index);
              });
              _recalcTotals();
            },
          ),
        ),
    ]);

    final Widget row2;
    if (ownCheck) {
      // เช็คที่จ่ายออก: สมุดเช็ค + เลขที่เช็ค (ว่าง = ใช้เลขถัดไปของสมุดตอน Post)
      _ensureCheckbooks(r.cmBankAccountId!);
      final books = (_checkbooks[r.cmBankAccountId!] ?? const <CmCheckbook>[]).where((b) => b.status == 'Active' || b.id == r.checkbookId).toList();
      final book = books.where((b) => b.id == r.checkbookId).firstOrNull;
      row2 = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 3,
          child: _isReadOnly
              ? InputDecorator(
                  decoration: _hDec(isEnglish ? 'Checkbook' : 'สมุดเช็ค'),
                  child: Text(book == null ? '—' : '${book.checkbookCode} (${book.startCheckNo}-${book.endCheckNo})',
                      maxLines: 1, overflow: TextOverflow.ellipsis))
              : DropdownButtonFormField<int?>(
                  value: book?.id,
                  isExpanded: true,
                  isDense: true,
                  decoration: _hDec(isEnglish ? 'Checkbook' : 'สมุดเช็ค', auto: true),
                  items: [
                    DropdownMenuItem(value: null, child: Text(isEnglish ? '— Type check no. —' : '— พิมพ์เลขเช็คเอง —')),
                    ...books.map((b) => DropdownMenuItem(
                        value: b.id, child: Text('${b.checkbookCode} (${b.startCheckNo}-${b.endCheckNo})', overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) => setState(() => r.checkbookId = v),
                ),
        ),
        const SizedBox(width: 8),
        f(isEnglish ? 'Check No.' : 'เลขที่เช็ค', r.refNoCtrl,
            hint: r.checkbookId != null ? (isEnglish ? 'Next: ${_nextCheckNo(r) ?? '-'} (on post)' : 'เลขถัดไป ${_nextCheckNo(r) ?? '-'} (ตอน Post)') : null),
        const Spacer(flex: 5),
      ]);
    } else if (isCheck) {
      // เช็คที่รับ (เช่น รับคืนมัดจำ): ธนาคารและเลขที่เช็คของผู้สั่งจ่าย
      row2 = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        f(isEnglish ? 'Reference No.' : 'เลขที่อ้างอิง', r.refNoCtrl),
        const SizedBox(width: 8),
        f(isEnglish ? 'Bank' : 'ธนาคาร', r.drawerBankNameCtrl, flex: 3),
        const SizedBox(width: 8),
        f(isEnglish ? 'Check No.' : 'เลขที่เช็ค', r.drawerAccountNoCtrl),
        const Spacer(flex: 3),
      ]);
    } else {
      row2 = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        f(type == 'TRANSFER' || type == 'MOBILE_BANKING' ? (isEnglish ? 'Reference / Slip No.' : 'เลขอ้างอิง / Slip No') : (isEnglish ? 'Reference No.' : 'เลขที่อ้างอิง'),
            r.refNoCtrl, flex: 3),
        const Spacer(flex: 7),
      ]);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFBFCFD),
          border: Border.all(color: const Color(0xFFDDE3EA)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(height: 3, color: typeColor.shade400),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [row1, const SizedBox(height: 12), row2]),
          ),
        ]),
      ),
    );
  }

  // ── การ์ดสรุปยอด: ใบตั้งหนี้ ซ้าย = หักเงินมัดจำ, ขวา = ยอด → ยอดสุดท้าย 17 ตัวหนา ─────────────────────────────
  Widget _buildTotalsSection() {
    final isEnglish = _isEnglish;
    final cur = _selectedCurrency?.currencyCode ?? CurrencyService.baseCode;
    final afterDeposit = _invAdvanceTotal > 0;
    final wht = _hasWhtSection ? _totalWht : 0.0;
    final payTotal = _applyRows.fold(0.0, (s, a) => s + a.appliedAmountLc);
    final payAdvance = _isPayment ? _advanceRows.fold(0.0, (s, a) => s + a.appliedAmountLc) : 0.0;

    final double finalAmount;
    final String finalLabel;
    if (_hasDetailRows && afterDeposit) {
      finalAmount = _totalAmountFc - _invAdvanceTotal;
      finalLabel = isEnglish ? 'Payable after deposit' : 'ยอดเจ้าหนี้หลังหักมัดจำ';
    } else if (_hasWhtSection) {
      finalAmount = _totalAmountFc - wht;
      finalLabel = isEnglish ? 'Net payment' : 'ยอดจ่ายสุทธิ';
    } else if (_isRA) {
      finalAmount = _totalAmountFc;
      finalLabel = isEnglish ? 'Amount to pay' : 'ยอดแจ้งชำระ';
    } else if (_isAdvanceRefund) {
      finalAmount = _totalAmountFc;
      finalLabel = isEnglish ? 'Refund amount' : 'ยอดรับคืนมัดจำ';
    } else {
      finalAmount = _totalAmountFc;
      finalLabel = isEnglish ? 'Net Total' : 'ยอดรวมสุทธิ';
    }

    final figures = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_hasDetailRows) ...[
        _sumRow(isEnglish ? 'Subtotal' : 'ยอดรวมสินค้า', _subtotalFc),
        _sumRow(isEnglish ? 'Total Discount' : 'ส่วนลดรวม', -_discountAmountFc, neg: _discountAmountFc != 0),
        _sumRow(isEnglish ? 'Amount Before VAT' : 'ยอดก่อน VAT', _beforeVatFc, line: true),
        ..._vatSumRows(),
        if (afterDeposit || wht > 0) _sumRow(isEnglish ? 'Net Total' : 'ยอดรวมสุทธิ', _totalAmountFc, line: true),
        if (afterDeposit) _sumRow(isEnglish ? 'Less: deposit deducted' : 'หัก เงินมัดจำ', -_invAdvanceTotal, neg: true),
      ],
      if (_isPayment) ...[
        _sumRow(isEnglish ? 'Invoices paid' : 'ยอดชำระใบตั้งหนี้', payTotal),
        if (payAdvance > 0) _sumRow(isEnglish ? 'Less: deposit deducted' : 'หัก เงินมัดจำ', -payAdvance, neg: true),
      ],
      if (wht > 0) _sumRow(isEnglish ? 'Less: withholding tax' : 'หัก ภาษี ณ ที่จ่าย', -wht, neg: true),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFFE8F3F2), borderRadius: BorderRadius.circular(6)),
        child: Row(children: [
          Expanded(child: Text('$finalLabel ($cur)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F5C5C)))),
          Text(_fmt.format(finalAmount), style: _numStyle.copyWith(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF0F5C5C))),
        ]),
      ),
      if (_exchangeRate != 1.0)
        _sumRow(isEnglish ? 'Total (${CurrencyService.baseCode})' : 'ยอดรวม (${CurrencyService.baseCode})', finalAmount * _exchangeRate),
    ]);

    // ใบตั้งหนี้: หักเงินมัดจำตอนตั้งหนี้ (apply_type 'inv_advance') อยู่ด้านซ้ายของการ์ดนี้
    final showDeposit = _isPurchaseInvoice && _selectedVendor != null && (_openAdvances.isNotEmpty || _advanceRows.isNotEmpty);
    final left = showDeposit
        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(isEnglish ? 'Deposit deduction' : 'หักเงินมัดจำ', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              _advanceChip(),
            ]),
            const SizedBox(height: 6),
            _advanceTable(),
          ])
        : const SizedBox.shrink();

    return _card(isEnglish ? 'Summary' : 'สรุปยอด', [
      LayoutBuilder(
        builder: (context, c) => c.maxWidth >= 900 || (!showDeposit && c.maxWidth >= 420)
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Align(alignment: Alignment.topLeft, child: left)),
                const SizedBox(width: 24),
                SizedBox(width: 380, child: figures),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: 10), figures]),
      ),
    ]);
  }

  List<Widget> _vatSumRows() {
    final isEnglish = _isEnglish;
    final deferredVat = _detailRows.where((r) => r.isDeferredVat && r.vatType != 'NOVAT').fold(0.0, (s, r) => s + _amt(r).vat);
    if (deferredVat > 0) {
      return [
        _sumRow(isEnglish ? 'VAT (Immediate)' : 'VAT (ทันที)', _vatAmountFc - deferredVat),
        _sumRow(isEnglish ? 'VAT (Deferred)' : 'VAT (รอตัดบัญชี)', deferredVat, color: Colors.orange[800]),
      ];
    }
    return [_sumRow('VAT', _vatAmountFc)];
  }

  // ── จ่ายชำระ (ซื้อเงินสด) — ใบตั้งหนี้ที่ซื้อเงินสด IM สร้าง: วิธีจ่ายจากใบจ่ายคู่กัน (อ่านอย่างเดียว แก้ที่เอกสาร IM) ──
  Widget _buildCashPurchaseSection() {
    final cp = _cashPurchase!;
    final isEnglish = _isEnglish;
    final currency = _selectedCurrency?.currencyCode ?? CurrencyService.baseCode;
    final base = CurrencyService.baseCode;
    const typeColors = <String, Color>{
      'CASH': Colors.green, 'CHECK': Colors.blue, 'TRANSFER': Colors.indigo,
      'CREDIT_CARD': Colors.purple, 'DEBIT_CARD': Colors.deepPurple,
      'QR_CODE': Colors.teal, 'MOBILE_BANKING': Colors.cyan,
      'BILL_OF_EXCHANGE': Colors.brown, 'OTHER': Colors.grey,
    };
    String join(List<String?> xs, String sep) => xs.whereType<String>().where((x) => x.isNotEmpty).join(sep);
    String details(ApTransactionPayment p) {
      final parts = <String>[
        join([p.bankAccountCode, p.bankAccountNameTh], ' '),
        join([p.drawerBankName, p.drawerBankBranch, p.drawerAccountNo], ' / '),
        p.remark ?? '',
      ].where((x) => x.isNotEmpty).toList();
      return parts.isEmpty ? '—' : parts.join(' · ');
    }

    final isFc = _selectedCurrency?.baseCurrencyFlag == false;
    double amt(ApTransactionPayment p) => isFc && p.amountFc > 0 ? p.amountFc : p.amountLc;
    final payTotal = cp.payments.fold(0.0, (s, p) => s + amt(p));
    final whtTotal = cp.whts.fold(0.0, (s, w) => s + w.whtAmountLc);
    final kind = cp.taxInvoiceKind;

    return _card(
      isEnglish ? 'Payment (Cash Purchase)' : 'จ่ายชำระ (ซื้อเงินสด)',
      chips: [
        if (cp.paymentDocNo != null) _chip('${isEnglish ? 'Payment' : 'ใบจ่าย'} ${cp.paymentDocNo}', const Color(0xFF1E4F8F), _hAuto),
        if (cp.paymentStatus != null) docStatusBadge(cp.paymentStatus!, label: apTransactionStatusLabel(cp.paymentStatus!, isEnglish)),
        if (cp.imDocNo != null) _chip('${isEnglish ? 'From' : 'จาก'} ${cp.imDocNo}', _gMore, _hRo),
        if (kind == 'ABB' || kind == 'NONE')
          _chip(
              kind == 'ABB'
                  ? (isEnglish ? 'Abbreviated tax invoice · VAT to cost' : 'ใบกำกับอย่างย่อ · VAT รวมต้นทุน')
                  : (isEnglish ? 'No tax invoice · VAT to cost' : 'ไม่มีใบกำกับ · VAT รวมต้นทุน'),
              const Color(0xFF8A4B00),
              const Color(0xFFFFF0D9)),
      ],
      [
        if (cp.paymentDocNo == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                  isEnglish
                      ? 'No payment voucher — the deposit covers the whole purchase, or the cash purchase is not posted yet'
                      : 'ไม่มีใบจ่าย — เงินมัดจำครอบคลุมยอดซื้อทั้งหมด หรือเอกสารซื้อเงินสดยังไม่ผ่านรายการ',
                  style: const TextStyle(color: Colors.grey)),
            ),
          )
        else ...[
          _gridTable(
            cols: [
              (isEnglish ? 'Payment Method' : 'วิธีจ่าย', 220, 1, false),
              (isEnglish ? 'Bank / Remark' : 'บัญชีธนาคาร / หมายเหตุ', 0, 2, false),
              (isEnglish ? 'Ref / Cheque No.' : 'เลขอ้างอิง / เลขที่เช็ค', 150, 2, false),
              (isEnglish ? 'Date' : 'วันที่', 100, 2, false),
              ('${isEnglish ? 'Amount' : 'จำนวนเงิน'} ($currency)', 130, 3, true),
            ],
            groupTitle: (g) => g == 1 ? (isEnglish ? 'Method' : 'วิธีจ่าย') : g == 2 ? (isEnglish ? 'Details' : 'รายละเอียด') : (isEnglish ? 'Amount' : 'ยอด'),
            rows: [
              for (final p in cp.payments)
                <Widget>[
                  Row(children: [
                    Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(color: typeColors[p.paymentMethodType] ?? Colors.grey, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 6),
                    Expanded(child: _cBox(join([p.paymentMethodCode, p.paymentMethodName], ' — '), right: false, fill: _hRo)),
                  ]),
                  _cBox(details(p), right: false, fill: _hRo, tip: details(p)),
                  _cBox((p.refNo ?? '').isEmpty ? '—' : p.refNo!, right: false, fill: _hRo),
                  _cBox(p.paymentDate == null ? '—' : _dateFmt.format(p.paymentDate!), right: false, fill: _hRo),
                  _cBox(_fmt.format(amt(p)), bold: true, fill: _hRo),
                ],
            ],
            footer: [
              _footerLabel(isEnglish ? 'Total paid' : 'รวมจ่ายชำระ'),
              const SizedBox.shrink(),
              const SizedBox.shrink(),
              const SizedBox.shrink(),
              _footerAmount(payTotal),
            ],
            empty: Text(isEnglish ? 'No payment methods' : 'ไม่มีวิธีจ่าย', style: const TextStyle(color: Colors.grey)),
          ),
          if (cp.whts.isNotEmpty) ...[
            const SizedBox(height: 12),
            _gridTable(
              cols: [
                (isEnglish ? 'WHT Type' : 'ประเภทภาษี', 0, 1, false),
                (isEnglish ? 'Rate' : 'อัตรา', 80, 1, true),
                ('${isEnglish ? 'Tax base' : 'ฐานภาษี'} ($base)', 130, 3, true),
                ('${isEnglish ? 'WHT' : 'ภาษีที่หัก'} ($base)', 130, 3, true),
                (isEnglish ? 'Description' : 'คำอธิบาย', 180, 4, false),
              ],
              groupTitle: (g) => g == 1
                  ? (isEnglish ? 'Withholding Tax' : 'ภาษีหัก ณ ที่จ่าย')
                  : g == 3
                      ? (isEnglish ? 'Amounts' : 'ยอด')
                      : (isEnglish ? 'Details' : 'รายละเอียด'),
              rows: [
                for (final w in cp.whts)
                  <Widget>[
                    _cBox(w.whtType ?? '—', right: false, fill: _hRo),
                    _cBox(w.whtRate > 0 ? '${w.whtRate.toStringAsFixed(2)}%' : '—', fill: _hRo),
                    _cBox(_fmt.format(w.baseAmountLc), fill: _hRo),
                    _cBox(_fmt.format(w.whtAmountLc), bold: true, fill: _hRo),
                    _cBox((w.description ?? '').isEmpty ? '—' : w.description!, right: false, fill: _hRo),
                  ],
              ],
              footer: [
                _footerLabel(isEnglish ? 'Total WHT' : 'รวมภาษีหัก ณ ที่จ่าย'),
                const SizedBox.shrink(),
                const SizedBox.shrink(),
                _footerAmount(whtTotal),
                const SizedBox.shrink(),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 380,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _sumRow('${isEnglish ? 'Total paid' : 'รวมจ่ายชำระ'} ($currency)', payTotal),
                if (whtTotal > 0) _sumRow('${isEnglish ? 'WHT deducted' : 'ภาษีหัก ณ ที่จ่าย'} ($base)', whtTotal),
              ]),
            ),
          ),
        ],
      ],
    );
  }

  // ── Inline GL Section ────────────────────────────────────────────────────
  Widget _buildGlSection() {
    final isEnglish = _isEnglish;
    final fmt = NumberFormat('#,##0.00');
    final totalDebit  = _glEditRows.fold(0.0, (s, r) => s + r.debit);
    final totalCredit = _glEditRows.fold(0.0, (s, r) => s + r.credit);
    final isBalanced  = _glEditRows.isEmpty || (totalDebit - totalCredit).abs() < 0.005;
    final hasFc = _glEditRows.any((r) => r.debitFc > 0 || r.creditFc > 0);
    final lcLabel = _currencies.cast<Currency?>()
        .firstWhere((c) => c!.baseCurrencyFlag, orElse: () => null)?.currencyCode ?? CurrencyService.baseCode;
    final fcLabel = _selectedCurrency?.currencyCode ?? 'FC';
    final activeDims = _dimTypes.where((t) => t.slotNo >= 1 && t.slotNo <= 5).toList();

    // Table built with LayoutBuilder for flexible column widths
    Widget tableContent;
    if (_glLoading) {
      tableContent = const Padding(padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()));
    } else if (_glEditRows.isEmpty) {
      tableContent = Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(isEnglish ? 'No entries yet — please enter items/services above' : 'ยังไม่มีรายการ — กรุณาป้อนรายการสินค้า/บริการด้านบน',
          style: const TextStyle(color: Colors.grey, fontSize: 13)),
      );
    } else {
      const double wNo   = 36;
      const double wCode = 130;
      const double wAmt  = 120;
      const double wDim  = 120;
      const double wNameMin = 160;
      const double wDescMin = 180;

      tableContent = LayoutBuilder(builder: (context, constraints) {
        final double fixedTotal = wNo + wCode + wAmt * (2 + (hasFc ? 2 : 0)) + wDim * activeDims.length;
        final double remaining = constraints.maxWidth - fixedTotal;
        final double wName, wDesc;
        if (remaining > wNameMin + wDescMin) {
          final extra = remaining - wNameMin - wDescMin;
          wName = wNameMin + extra * 0.4;
          wDesc = wDescMin + extra * 0.6;
        } else {
          wName = wNameMin;
          wDesc = wDescMin;
        }

        Widget hdr(String t, {required double w, TextAlign align = TextAlign.left}) =>
            Container(width: w, color: Colors.blue[50],
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                textAlign: align, overflow: TextOverflow.ellipsis));

        Widget buildRow(int i, _GlEditRow r) {
          final hasErr = r.acctCodeCtrl.text.startsWith('!');
          final bg = hasErr ? Colors.red[50]! : (i.isOdd ? Colors.grey[50]! : Colors.white);
          return Container(color: bg, child: Row(children: [
            SizedBox(width: wNo, child: Center(
              child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Colors.grey)))),
            SizedBox(width: wCode, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Text(r.acctCodeCtrl.text,
                    style: TextStyle(fontSize: 12, color: hasErr ? Colors.red : null),
                    overflow: TextOverflow.ellipsis))),
            SizedBox(width: wName, child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Text(r.accountName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
            SizedBox(width: wDesc, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Text(r.descCtrl.text, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
            if (hasFc) ...[
              SizedBox(width: wAmt, child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Text(r.debitFc  > 0 ? fmt.format(r.debitFc)  : '',
                  style: TextStyle(fontSize: 12, color: Colors.blue[700]), textAlign: TextAlign.right))),
              SizedBox(width: wAmt, child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Text(r.creditFc > 0 ? fmt.format(r.creditFc) : '',
                  style: TextStyle(fontSize: 12, color: Colors.red[700]), textAlign: TextAlign.right))),
            ],
            SizedBox(width: wAmt, child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Text(r.debit  > 0 ? fmt.format(r.debit)  : '',
                style: TextStyle(fontSize: 12, color: Colors.blue[800]), textAlign: TextAlign.right))),
            SizedBox(width: wAmt, child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Text(r.credit > 0 ? fmt.format(r.credit) : '',
                style: TextStyle(fontSize: 12, color: Colors.red[800]), textAlign: TextAlign.right))),
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
        }

        final headerRow = Row(children: [
          hdr('#', w: wNo, align: TextAlign.center),
          hdr(isEnglish ? 'Account Code' : 'รหัสบัญชี', w: wCode),
          hdr(isEnglish ? 'Account Name' : 'ชื่อบัญชี', w: wName),
          hdr(isEnglish ? 'Description' : 'รายละเอียด', w: wDesc),
          if (hasFc) ...[
            hdr('${isEnglish ? 'Debit' : 'เดบิต'} ($fcLabel)', w: wAmt, align: TextAlign.right),
            hdr('${isEnglish ? 'Credit' : 'เครดิต'} ($fcLabel)', w: wAmt, align: TextAlign.right),
          ],
          hdr('${isEnglish ? 'Debit' : 'เดบิต'} ($lcLabel)', w: wAmt, align: TextAlign.right),
          hdr('${isEnglish ? 'Credit' : 'เครดิต'} ($lcLabel)', w: wAmt, align: TextAlign.right),
          for (final dt in activeDims) hdr(isEnglish && (dt.nameEng ?? '').isNotEmpty ? dt.nameEng! : dt.nameThai, w: wDim),
        ]);

        final totalsRow = Row(children: [
          SizedBox(width: wNo + wCode + wName),
          Container(width: wDesc, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Text(isEnglish ? 'Total' : 'รวม', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right)),
          if (hasFc) ...[
            Container(width: wAmt, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Text(fmt.format(_glEditRows.fold(0.0, (s, r) => s + r.debitFc)),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[700]),
                textAlign: TextAlign.right)),
            Container(width: wAmt, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Text(fmt.format(_glEditRows.fold(0.0, (s, r) => s + r.creditFc)),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red[700]),
                textAlign: TextAlign.right)),
          ],
          Container(width: wAmt, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Text(fmt.format(totalDebit),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[800]),
              textAlign: TextAlign.right)),
          Container(width: wAmt, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Text(fmt.format(totalCredit),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red[800]),
              textAlign: TextAlign.right)),
        ]);

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _glHeaderHScroll,
            physics: const NeverScrollableScrollPhysics(),
            child: headerRow),
          const Divider(height: 1, thickness: 1),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: _glBodyHScroll,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: _glEditRows.asMap().entries.map((e) => buildRow(e.key, e.value)).toList())))),
          const Divider(height: 1, thickness: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _glFooterHScroll,
            physics: const NeverScrollableScrollPhysics(),
            child: totalsRow),
        ]);
      });
    }

    // หัวการ์ดแบบเดียวกับการ์ดอื่น (16 ตัวหนา + ชิปสมดุล + ปุ่มย่อ/ขยาย)
    final posted = _status == 'Posted';
    return _card(
      posted ? (isEnglish ? 'GL Entries (Posted)' : 'รายการบัญชี (Posted)') : (isEnglish ? 'GL Preview (Draft)' : 'ตัวอย่างรายการบัญชี (Draft)'),
      chips: [
        if (!_glLoading && _glEditRows.isNotEmpty) ...[
          isBalanced
              ? _chip(isEnglish ? 'Balanced' : 'สมดุล', const Color(0xFF1E6B3A), const Color(0xFFE6F4EA))
              : _chip(isEnglish ? 'Unbalanced' : 'ไม่สมดุล', const Color(0xFFB71C1C), const Color(0xFFFDECEA)),
          Text('Dr ${fmt.format(totalDebit)} · Cr ${fmt.format(totalCredit)}', style: _numStyle.copyWith(fontSize: 12, color: _ink2)),
        ],
      ],
      actions: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 10), foregroundColor: Colors.blueGrey.shade800),
          icon: Icon(_glSectionExpanded ? Icons.expand_less : Icons.expand_more, size: 18),
          label: Text(_glSectionExpanded ? (isEnglish ? 'Collapse' : 'ย่อ') : (isEnglish ? 'Expand' : 'ขยาย'), style: const TextStyle(fontSize: 12)),
          onPressed: () => setState(() => _glSectionExpanded = !_glSectionExpanded),
        ),
      ],
      [
        if (_glSectionExpanded) ...[
          tableContent,
          if (_status != 'Posted' && !_glLoading && _glEditRows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(isEnglish ? '* Accounts come from the document type\'s GL account setup; the account and dimensions of each item line can be chosen on the line (blank line dimensions use the header) — the entry is recalculated on Post' : '* รหัสบัญชีกำหนดจากการตั้งค่ารหัสบัญชีของประเภทเอกสาร ส่วนบัญชีและมิติของแต่ละบรรทัดรายการเลือกได้ที่บรรทัด (มิติที่ว่างใช้ตามหัวเอกสาร) — ระบบคำนวณรายการบัญชีใหม่ตอน Post',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.blueGrey.shade600)),
            ),
        ],
      ],
    );
  }

  // ── Client-side GL preview for Draft ──────────────────────────────────────

  // VAT ที่ต้อง reverse จากมัดจำเดิม ตามสัดส่วนของยอดที่คืนต่อยอดมัดจำเต็มใบ
  // VAT รอตัดของใบมัดจำ (pendFc) ล้างบัญชีภาษีซื้อรอตัด ไม่ใช่ภาษีซื้อ (เหมือน backend)
  ({double vatLc, double vatFc, double pendFc}) _advanceRefundVatTotals() {
    double vatLc = 0, vatFc = 0, pendFc = 0;
    for (final row in _advanceRefundRows) {
      final adv = _openAdvancesForRefund.where((a) => a.id == row.appliedToId).firstOrNull;
      if (adv == null || adv.totalAmountFc == 0) continue;
      final ratio = row.appliedAmountLc / adv.totalAmountFc;
      vatFc += (adv.vatAmountFc - adv.deferredVatAmountFc) * ratio;
      vatLc += (adv.vatAmountLc - adv.deferredVatAmountLc) * ratio;
      pendFc += adv.deferredVatAmountFc * ratio;
    }
    return (vatLc: vatLc, vatFc: vatFc, pendFc: pendFc);
  }

  List<_GlLine> _computeGlPreview() {
    final isEnglish = _isEnglish;
    final lines = <_GlLine>[];
    final lc = _exchangeRate;
    final isFcDoc = _selectedCurrency?.baseCurrencyFlag == false;
    final setup = _docSetup;
    final sysType = int.tryParse(_selectedDocType?.sysDocType ?? '');

    final expenseDefaultDesc = isEnglish ? 'Expense' : 'ค่าใช้จ่าย';
    final notSetupExpenseLabel = isEnglish ? '!Expense account not configured' : '!ยังไม่ตั้งค่าบัญชีค่าใช้จ่าย';
    final notSetupLabel = isEnglish ? 'Not configured' : 'ยังไม่ตั้งค่าบัญชี';
    final notSetupVatLabel = isEnglish ? '!VAT account not configured' : '!ยังไม่ตั้งค่าบัญชี VAT';
    final vatDesc = isEnglish ? 'VAT' : 'ภาษีมูลค่าเพิ่ม';
    final notSetupApLabel = isEnglish ? '!AP account not configured' : '!ยังไม่ตั้งค่าบัญชีเจ้าหนี้';
    final apDesc = isEnglish ? 'Accounts Payable' : 'เจ้าหนี้การค้า';
    final notSetupAdvanceLabel = isEnglish ? '!Advance account not configured' : '!ยังไม่ตั้งค่าบัญชีมัดจำ';
    final advanceLabel = isEnglish ? 'Advance' : 'เงินมัดจำ';
    final payAdvanceDesc = isEnglish ? 'Pay Advance' : 'จ่ายมัดจำ';
    final notSetupCashLabel = isEnglish ? '!Cash account not configured' : '!ยังไม่ตั้งค่าบัญชีเงินสด';
    final cashBankLabel = isEnglish ? 'Cash/Bank' : 'เงินสด/ธนาคาร';
    final payDesc = isEnglish ? 'Pay' : 'ชำระ';
    final receiveAdvanceRefundDesc = isEnglish ? 'Receive Advance Refund' : 'รับมัดจำคืน';
    final refundAdvanceDesc = isEnglish ? 'Refund Advance' : 'คืนมัดจำ';
    final payTransactionDesc = isEnglish ? 'Payment' : 'ชำระเงิน';
    final cashFallback = isEnglish ? 'Cash' : 'เงินสด';

    // When AP GL Account Setup is not configured yet, generate skeleton rows
    // with error-prefix codes so user can see and manually fill them in.
    if (setup == null) {
      if (_totalAmountFc == 0 && _detailRows.isEmpty) return lines;
      if (sysType == apDocTypePurchaseInvoice || sysType == apDocTypeDebitNote) {
        for (final r in _detailRows) {
          final amt = _amt(r);
          final afterDisc = amt.net;
          final vat      = amt.vat;
          final desc     = r.itemNameCtrl.text.isNotEmpty ? r.itemNameCtrl.text : expenseDefaultDesc;
          lines.add(_GlLine(notSetupExpenseLabel, notSetupLabel, desc, afterDisc * lc, 0, isFcDoc ? afterDisc : 0, 0));
          if (vat > 0) {
            lines.add(_GlLine(notSetupVatLabel, 'VAT Input', vatDesc, vat * lc, 0, isFcDoc ? vat : 0, 0));
          }
        }
        lines.add(_GlLine(notSetupApLabel, apDesc, apDesc, 0, (_totalAmountFc - _invAdvanceTotal) * lc, 0, isFcDoc ? _totalAmountFc - _invAdvanceTotal : 0));
        _addInvAdvancePreview(lines, notSetupAdvanceLabel, advanceLabel, notSetupVatLabel, 'VAT Input', lc, isFcDoc);
      } else if (sysType == apDocTypeCreditNote) {
        lines.add(_GlLine(notSetupApLabel, apDesc, apDesc, _totalAmountFc * lc, 0, isFcDoc ? _totalAmountFc : 0, 0));
        for (final r in _detailRows) {
          final amt = _amt(r);
          final afterDisc = amt.net;
          final vat      = amt.vat;
          final desc     = r.itemNameCtrl.text.isNotEmpty ? r.itemNameCtrl.text : expenseDefaultDesc;
          lines.add(_GlLine(notSetupExpenseLabel, notSetupLabel, desc, 0, afterDisc * lc, 0, isFcDoc ? afterDisc : 0));
          if (vat > 0) {
            lines.add(_GlLine(notSetupVatLabel, 'VAT Input', vatDesc, 0, vat * lc, 0, isFcDoc ? vat : 0));
          }
        }
      } else if (sysType == apDocTypeAdvancePayment) {
        lines.add(_GlLine(notSetupAdvanceLabel, advanceLabel, payAdvanceDesc, _beforeVatFc * lc, 0, isFcDoc ? _beforeVatFc : 0, 0));
        if (_vatAmountFc > 0) {
          lines.add(_GlLine(notSetupVatLabel, 'VAT Input', vatDesc, _vatAmountFc * lc, 0, isFcDoc ? _vatAmountFc : 0, 0));
        }
        lines.add(_GlLine(notSetupCashLabel, cashBankLabel, payDesc, 0, _totalAmountFc * lc, 0, isFcDoc ? _totalAmountFc : 0));
      } else if (sysType == apDocTypeAdvanceRefund) {
        final refundVat = _advanceRefundVatTotals();
        final advanceNetFc = _totalAmountFc - refundVat.vatFc - refundVat.pendFc;
        lines.add(_GlLine(notSetupCashLabel, cashBankLabel, receiveAdvanceRefundDesc, _totalAmountFc * lc, 0, isFcDoc ? _totalAmountFc : 0, 0));
        lines.add(_GlLine(notSetupAdvanceLabel, advanceLabel, refundAdvanceDesc, 0, advanceNetFc * lc, 0, isFcDoc ? advanceNetFc : 0));
        if (refundVat.vatFc > 0) {
          lines.add(_GlLine(notSetupVatLabel, 'VAT Input', vatDesc, 0, refundVat.vatFc * lc, 0, isFcDoc ? refundVat.vatFc : 0));
        }
      } else if (sysType == apDocTypePayment) {
        for (final a in _applyRows) {
          lines.add(_GlLine(notSetupApLabel, apDesc, '$payDesc ${a.appliedToDocNo}', a.appliedAmountLc * lc, 0, isFcDoc ? a.appliedAmountLc : 0, 0));
        }
        if (lines.isNotEmpty) {
          lines.add(_GlLine(notSetupCashLabel, cashBankLabel, payTransactionDesc, 0, _totalAmountFc * lc, 0, isFcDoc ? _totalAmountFc : 0));
        }
      }
      return lines;
    }

    String acctCode(int? id, String? fallback) {
      if (id != null) {
        try { return _accounts.firstWhere((a) => a.id == id).accountCode; } catch (_) {}
      }
      return fallback ?? '—';
    }
    String acctName(int? id, String? fallback) {
      if (id != null) {
        try { return _acctLabel(_accounts.firstWhere((a) => a.id == id)); } catch (_) {}
      }
      return fallback ?? '';
    }

    // AP account: vendor → vendor group → document type setup (เหมือน backend utils/apAccount.js)
    final apAccountId = _selectedVendor?.apAccountId
        ?? _selectedVendor?.groupApAccountId
        ?? setup.apAccountId;
    final apCode = acctCode(apAccountId, _selectedVendor?.apAccountCode
        ?? _selectedVendor?.groupApAccountCode
        ?? setup.apAccountCode);
    final apName = acctName(apAccountId, _selectedVendor?.apAccountNameThai
        ?? _selectedVendor?.groupApAccountNameThai
        ?? setup.apAccountName
        ?? apDesc);

    String payAcctCode(_PaymentRow p) {
      int? sid; String? sCode;
      switch (p.paymentMethodType) {
        case 'CHECK':    sid = setup.checkAccountId;    sCode = setup.checkAccountCode; break;
        case 'TRANSFER': sid = setup.transferAccountId; sCode = setup.transferAccountCode; break;
        default: break;
      }
      if (sCode != null) return sCode;
      if (sid != null) return acctCode(sid, setup.cashAccountCode ?? '—');
      return acctCode(p.glAccountId, setup.cashAccountCode ?? '—');
    }
    String payAcctName(_PaymentRow p) {
      int? sid; String? sName;
      switch (p.paymentMethodType) {
        case 'CHECK':    sid = setup.checkAccountId;    sName = setup.checkAccountName; break;
        case 'TRANSFER': sid = setup.transferAccountId; sName = setup.transferAccountName; break;
        default: break;
      }
      if (sid != null) {
        final n = acctName(sid, sName);
        return n.isEmpty ? (setup.cashAccountName ?? cashFallback) : n;
      }
      if (sName != null && sName.isNotEmpty) return sName;
      return acctName(p.glAccountId, setup.cashAccountName ?? cashFallback);
    }

    // ── PI (10) / DN (50) ────────────────────────────────────────────────
    if (sysType == apDocTypePurchaseInvoice || sysType == apDocTypeDebitNote) {
      for (final r in _detailRows) {
        final amt = _amt(r);
        final sub      = amt.gross;
        final disc     = amt.discount;
        final afterDisc = amt.net;
        final vat      = amt.vat;
        final expAccId = r.expenseAccountId ?? setup.expenseAccountId;
        final expCode  = acctCode(expAccId, setup.expenseAccountCode);
        final expName  = acctName(expAccId, setup.expenseAccountName);
        final desc     = r.itemNameCtrl.text.isNotEmpty ? r.itemNameCtrl.text : expenseDefaultDesc;
        final notSetupDiscountLabel = isEnglish ? '!Discount account not configured' : '!ยังไม่ตั้งค่าบัญชีส่วนลด';
        final discountReceivedLabel = isEnglish ? 'Discount Received' : 'ส่วนลดรับ';
        final dims = effectiveLineDims(r.dims, _dimSelections);
        if (setup.discountAccountId != null && disc > 0) {
          lines.add(_GlLine(expCode, expName.isEmpty ? 'Expense' : expName, desc, sub * lc, 0, isFcDoc ? sub : 0, 0, dims));
          final discCode = setup.discountAccountCode ?? acctCode(setup.discountAccountId, notSetupDiscountLabel);
          final discName = acctName(setup.discountAccountId, setup.discountAccountName ?? discountReceivedLabel);
          lines.add(_GlLine(discCode, discName.isEmpty ? discountReceivedLabel : discName, discountReceivedLabel, 0, disc * lc, 0, isFcDoc ? disc : 0, dims));
        } else {
          lines.add(_GlLine(expCode, expName.isEmpty ? 'Expense' : expName, desc, afterDisc * lc, 0, isFcDoc ? afterDisc : 0, 0, dims));
        }
        if (vat > 0) {
          final notSetupVatPendingLabel = isEnglish ? '!Deferred VAT not configured' : '!ยังไม่ตั้งค่า VAT รอตัด';
          final deferredVatLabel = isEnglish ? 'Deferred VAT' : 'VAT รอตัดบัญชี';
          String vatAcctCode, vatAcctName;
          if (r.isDeferredVat) {
            vatAcctCode = setup.vatPendingInputAccountCode ?? notSetupVatPendingLabel;
            vatAcctName = acctName(setup.vatPendingInputAccountId, setup.vatPendingInputAccountName ?? deferredVatLabel);
          } else {
            final vr = _vatRates.cast<VatRate?>().firstWhere((v) => v?.vatCode == r.vatType, orElse: () => null);
            if (vr?.glAccountCode != null && vr!.glAccountCode!.isNotEmpty) {
              vatAcctCode = vr.glAccountCode!;
              vatAcctName = acctName(vr.glAccountId, vr.glAccountName ?? setup.vatInputAccountName ?? 'VAT Input');
            } else if (setup.vatInputAccountCode != null && setup.vatInputAccountCode!.isNotEmpty) {
              vatAcctCode = setup.vatInputAccountCode!;
              vatAcctName = acctName(setup.vatInputAccountId, setup.vatInputAccountName ?? 'VAT Input');
            } else {
              vatAcctCode = notSetupVatLabel;
              vatAcctName = 'VAT Input';
            }
          }
          lines.add(_GlLine(vatAcctCode, vatAcctName, vatDesc, vat * lc, 0, isFcDoc ? vat : 0, 0));
        }
      }
      lines.add(_GlLine(apCode, apName.isEmpty ? 'AP Account' : apName, apDesc, 0, (_totalAmountFc - _invAdvanceTotal) * lc, 0, isFcDoc ? _totalAmountFc - _invAdvanceTotal : 0));
      _addInvAdvancePreview(lines,
          setup.advanceAccountCode ?? notSetupAdvanceLabel, acctName(setup.advanceAccountId, setup.advanceAccountName ?? advanceLabel),
          setup.vatInputAccountCode ?? notSetupVatLabel, acctName(setup.vatInputAccountId, setup.vatInputAccountName ?? 'VAT Input'), lc, isFcDoc);
    }
    // ── CN (30) ─────────────────────────────────────────────────────────
    else if (sysType == apDocTypeCreditNote) {
      lines.add(_GlLine(apCode, apName.isEmpty ? 'AP Account' : apName, apDesc, _totalAmountFc * lc, 0, isFcDoc ? _totalAmountFc : 0, 0));
      for (final r in _detailRows) {
        final amt = _amt(r);
        final sub      = amt.gross;
        final disc     = amt.discount;
        final afterDisc = amt.net;
        final vat      = amt.vat;
        final expAccId = r.expenseAccountId ?? setup.expenseAccountId;
        final expCode  = acctCode(expAccId, setup.expenseAccountCode);
        final expName  = acctName(expAccId, setup.expenseAccountName);
        final desc     = r.itemNameCtrl.text.isNotEmpty ? r.itemNameCtrl.text : expenseDefaultDesc;
        final notSetupDiscountLabel = isEnglish ? '!Discount account not configured' : '!ยังไม่ตั้งค่าบัญชีส่วนลด';
        final discountReceivedLabel = isEnglish ? 'Discount Received' : 'ส่วนลดรับ';
        final dims = effectiveLineDims(r.dims, _dimSelections);
        if (setup.discountAccountId != null && disc > 0) {
          lines.add(_GlLine(expCode, expName.isEmpty ? 'Expense' : expName, desc, 0, sub * lc, 0, isFcDoc ? sub : 0, dims));
          final discCode = setup.discountAccountCode ?? acctCode(setup.discountAccountId, notSetupDiscountLabel);
          final discName = acctName(setup.discountAccountId, setup.discountAccountName ?? discountReceivedLabel);
          lines.add(_GlLine(discCode, discName.isEmpty ? discountReceivedLabel : discName, discountReceivedLabel, disc * lc, 0, isFcDoc ? disc : 0, 0, dims));
        } else {
          lines.add(_GlLine(expCode, expName.isEmpty ? 'Expense' : expName, desc, 0, afterDisc * lc, 0, isFcDoc ? afterDisc : 0, dims));
        }
        if (vat > 0) {
          final notSetupVatPendingLabel = isEnglish ? '!Deferred VAT not configured' : '!ยังไม่ตั้งค่า VAT รอตัด';
          final deferredVatLabel = isEnglish ? 'Deferred VAT' : 'VAT รอตัดบัญชี';
          String vatAcctCode, vatAcctName;
          if (r.isDeferredVat) {
            vatAcctCode = setup.vatPendingInputAccountCode ?? notSetupVatPendingLabel;
            vatAcctName = acctName(setup.vatPendingInputAccountId, setup.vatPendingInputAccountName ?? deferredVatLabel);
          } else {
            final vr = _vatRates.cast<VatRate?>().firstWhere((v) => v?.vatCode == r.vatType, orElse: () => null);
            if (vr?.glAccountCode != null && vr!.glAccountCode!.isNotEmpty) {
              vatAcctCode = vr.glAccountCode!;
              vatAcctName = acctName(vr.glAccountId, vr.glAccountName ?? setup.vatInputAccountName ?? 'VAT Input');
            } else if (setup.vatInputAccountCode != null && setup.vatInputAccountCode!.isNotEmpty) {
              vatAcctCode = setup.vatInputAccountCode!;
              vatAcctName = acctName(setup.vatInputAccountId, setup.vatInputAccountName ?? 'VAT Input');
            } else {
              vatAcctCode = notSetupVatLabel;
              vatAcctName = 'VAT Input';
            }
          }
          lines.add(_GlLine(vatAcctCode, vatAcctName, vatDesc, 0, vat * lc, 0, isFcDoc ? vat : 0));
        }
      }
    }
    // ── Advance Payment (60) ─────────────────────────────────────────────
    else if (sysType == apDocTypeAdvancePayment) {
      lines.add(_GlLine(setup.advanceAccountCode ?? '—', acctName(setup.advanceAccountId, setup.advanceAccountName ?? advanceLabel), payAdvanceDesc, _beforeVatFc * lc, 0, isFcDoc ? _beforeVatFc : 0, 0));
      // บรรทัดที่ติ๊ก VAT รอตัด → บัญชีภาษีซื้อรอตัด (เหมือน backend)
      final pendVatFc = _detailRows.where((r) => r.isDeferredVat && r.vatType != 'NOVAT').fold(0.0, (s, r) => s + _amt(r).vat);
      final nowVatFc = _vatAmountFc - pendVatFc;
      if (nowVatFc > 0.005) {
        final vatCode = setup.vatInputAccountCode ?? notSetupVatLabel;
        final vatName = acctName(setup.vatInputAccountId, setup.vatInputAccountName ?? 'VAT Input');
        lines.add(_GlLine(vatCode, vatName.isEmpty ? 'VAT Input' : vatName, vatDesc, nowVatFc * lc, 0, isFcDoc ? nowVatFc : 0, 0));
      }
      if (pendVatFc > 0.005) {
        final deferredVatLabel = isEnglish ? 'Deferred VAT' : 'VAT รอตัดบัญชี';
        lines.add(_GlLine(setup.vatPendingInputAccountCode ?? (isEnglish ? '!Deferred VAT not configured' : '!ยังไม่ตั้งค่า VAT รอตัด'),
            acctName(setup.vatPendingInputAccountId, setup.vatPendingInputAccountName ?? deferredVatLabel), deferredVatLabel,
            pendVatFc * lc, 0, isFcDoc ? pendVatFc : 0, 0));
      }
      if (_paymentRows.isEmpty) {
        lines.add(_GlLine(setup.cashAccountCode ?? '—', acctName(setup.cashAccountId, setup.cashAccountName ?? cashFallback), payDesc, 0, _totalAmountFc * lc, 0, isFcDoc ? _totalAmountFc : 0));
      } else {
        for (final p in _paymentRows) {
          final amt = double.tryParse(p.amountCtrl.text) ?? 0;
          if (amt <= 0) continue;
          lines.add(_GlLine(payAcctCode(p), payAcctName(p).isEmpty ? cashFallback : payAcctName(p), p.paymentMethodName ?? payDesc, 0, amt * lc, 0, isFcDoc ? amt : 0));
        }
      }
    }
    // ── Advance Refund (65) ──────────────────────────────────────────────
    else if (sysType == apDocTypeAdvanceRefund) {
      final refundVat = _advanceRefundVatTotals();
      final advanceNetFc = _totalAmountFc - refundVat.vatFc - refundVat.pendFc;
      lines.add(_GlLine(setup.cashAccountCode ?? '—', acctName(setup.cashAccountId, setup.cashAccountName ?? cashFallback), receiveAdvanceRefundDesc, _totalAmountFc * lc, 0, isFcDoc ? _totalAmountFc : 0, 0));
      lines.add(_GlLine(setup.advanceAccountCode ?? '—', acctName(setup.advanceAccountId, setup.advanceAccountName ?? advanceLabel), refundAdvanceDesc, 0, advanceNetFc * lc, 0, isFcDoc ? advanceNetFc : 0));
      if (refundVat.vatFc > 0) {
        final vatCode = setup.vatInputAccountCode ?? notSetupVatLabel;
        final vatName = acctName(setup.vatInputAccountId, setup.vatInputAccountName ?? 'VAT Input');
        lines.add(_GlLine(vatCode, vatName.isEmpty ? 'VAT Input' : vatName, vatDesc, 0, refundVat.vatFc * lc, 0, isFcDoc ? refundVat.vatFc : 0));
      }
      if (refundVat.pendFc > 0.005) {
        lines.add(_GlLine('—', _depositPendingVatLabel, refundAdvanceDesc, 0, refundVat.pendFc * lc, 0, isFcDoc ? refundVat.pendFc : 0));
      }
    }
    // ── Payment (80) ─────────────────────────────────────────────────────
    else if (sysType == apDocTypePayment) {
      final totalWht = _whtRows.fold(0.0, (s, w) => s + (double.tryParse(w.whtCtrl.text) ?? 0));
      final totalAdv = _advanceRows.fold(0.0, (s, a) => s + a.appliedAmountLc);
      // ล้างเข้าบัญชีเจ้าหนี้ที่ใบตั้งหนี้แต่ละใบลงไว้ (เหมือน backend)
      final invAccount = <int, int?>{for (final inv in _openInvoices) inv.id: inv.apAccountId};
      for (final a in _applyRows) {
        final acc = invAccount[a.appliedToId] ?? apAccountId;
        final code = acc == apAccountId ? apCode : acctCode(acc, '—');
        final name = acc == apAccountId ? apName : acctName(acc, apName);
        lines.add(_GlLine(code, name.isEmpty ? 'AP Account' : name, '$payDesc ${a.appliedToDocNo}', a.appliedAmountLc * lc, 0, isFcDoc ? a.appliedAmountLc : 0, 0));
      }
      if (totalWht > 0) {
        lines.add(_GlLine(setup.whtPayableAccountCode ?? '—', acctName(setup.whtPayableAccountId, setup.whtPayableAccountName ?? 'WHT Payable'), isEnglish ? 'Withholding Tax' : 'ภาษีหัก ณ ที่จ่าย', 0, totalWht * lc, 0, isFcDoc ? totalWht : 0));
      }
      if (totalAdv > 0) {
        // ส่วนก่อน VAT ล้างเงินมัดจำจ่าย ส่วน VAT ของมัดจำกลับรายการภาษีซื้อ (เหมือน backend)
        double advVat = 0, advPend = 0;
        for (final a in _advanceRows) {
          final s = _depositSplit(a.appliedToId, a.appliedAmountLc);
          advVat += s.vat; advPend += s.pend;
        }
        final advNet = totalAdv - advVat - advPend;
        lines.add(_GlLine(setup.advanceAccountCode ?? '—', acctName(setup.advanceAccountId, setup.advanceAccountName ?? advanceLabel), isEnglish ? 'Advance Deducted' : 'หักมัดจำ', 0, advNet * lc, 0, isFcDoc ? advNet : 0));
        if (advVat > 0.005) {
          lines.add(_GlLine(setup.vatInputAccountCode ?? '—', acctName(setup.vatInputAccountId, setup.vatInputAccountName ?? 'VAT Input'), isEnglish ? 'Deposit VAT' : 'ภาษีซื้อของมัดจำ', 0, advVat * lc, 0, isFcDoc ? advVat : 0));
        }
        if (advPend > 0.005) {
          lines.add(_GlLine('—', _depositPendingVatLabel, isEnglish ? 'Advance Deducted' : 'หักมัดจำ', 0, advPend * lc, 0, isFcDoc ? advPend : 0));
        }
      }
      // รับรู้ VAT รอตัดบัญชีของใบแจ้งหนี้ตามสัดส่วนที่จ่าย — Dr ภาษีซื้อ / Cr ภาษีซื้อรอตัด (มิเรอร์ backend)
      double deferredVatLc = 0, deferredVatFc = 0;
      for (final a in _applyRows) {
        final inv = _openInvoices.where((i) => i.id == a.appliedToId).firstOrNull;
        if (inv == null || inv.totalAmountFc == 0 || inv.deferredVatAmountLc == 0) continue;
        final ratio = a.appliedAmountLc / inv.totalAmountFc;
        deferredVatLc += inv.deferredVatAmountLc * ratio;
        deferredVatFc += inv.deferredVatAmountFc * ratio;
      }
      if (deferredVatLc > 0.005) {
        lines.add(_GlLine(setup.vatInputAccountCode ?? '—', acctName(setup.vatInputAccountId, setup.vatInputAccountName ?? 'VAT Input'),
            isEnglish ? 'Recognize Deferred VAT' : 'รับรู้ VAT รอตัดบัญชี', deferredVatLc, 0, isFcDoc ? deferredVatFc : 0, 0));
        lines.add(_GlLine(setup.vatPendingInputAccountCode ?? '—', acctName(setup.vatPendingInputAccountId, setup.vatPendingInputAccountName ?? 'Deferred VAT'),
            isEnglish ? 'Deferred VAT Recognized' : 'VAT รอตัดบัญชีที่รับรู้', 0, deferredVatLc, 0, isFcDoc ? deferredVatFc : 0));
      }
      if (_paymentRows.isEmpty) {
        final netCash = _applyRows.fold(0.0, (s, a) => s + a.appliedAmountLc) - totalAdv - totalWht;
        if (netCash > 0.005) lines.add(_GlLine(setup.cashAccountCode ?? '—', acctName(setup.cashAccountId, setup.cashAccountName ?? cashFallback), payTransactionDesc, 0, netCash * lc, 0, isFcDoc ? netCash : 0));
      } else {
        for (final p in _paymentRows) {
          final amt = double.tryParse(p.amountCtrl.text) ?? 0;
          if (amt <= 0) continue;
          lines.add(_GlLine(payAcctCode(p), payAcctName(p).isEmpty ? cashFallback : payAcctName(p), p.paymentMethodName ?? payTransactionDesc, 0, amt * lc, 0, isFcDoc ? amt : 0));
        }
      }
    }
    return lines;
  }

  // มัดจำที่หัก แยกเป็น ส่วนก่อน VAT / VAT ที่ขอคืนแล้ว / VAT รอตัด ตามสัดส่วนของใบมัดจำ (เหมือน backend depositParts)
  ({double net, double vat, double pend}) _depositSplit(int depositId, double amount) {
    final dep = _openAdvances.where((d) => d.id == depositId).firstOrNull;
    if (dep == null || dep.totalAmountLc == 0) return (net: amount, vat: 0, pend: 0);
    final vat = amount * (dep.vatAmountLc - dep.deferredVatAmountLc) / dep.totalAmountLc;
    final pend = amount * dep.deferredVatAmountLc / dep.totalAmountLc;
    return (net: amount - vat - pend, vat: vat, pend: pend);
  }

  // บัญชีภาษีซื้อรอตัดที่ใบมัดจำลงไว้ (ตั้งที่ประเภทเอกสารจ่ายมัดจำ — ไม่ใช่ประเภทเอกสารนี้)
  String get _depositPendingVatLabel =>
      _isEnglish ? 'Deferred VAT (per deposit document type)' : 'VAT รอตัด (ตามประเภทเอกสารจ่ายมัดจำ)';

  // หักเงินมัดจำตอนตั้งหนี้: Cr เงินมัดจำจ่าย (ส่วนก่อน VAT) + Cr ภาษีซื้อ (VAT ของมัดจำ) แทนเจ้าหนี้ส่วนนั้น
  void _addInvAdvancePreview(List<_GlLine> lines, String advCode, String advName, String vatCode, String vatName, double lc, bool isFcDoc) {
    if (_invAdvanceTotal <= 0) return;
    final depLabel = _isEnglish ? 'Deposit deducted' : 'หักเงินมัดจำ';
    for (final a in _advanceRows) {
      final split = _depositSplit(a.appliedToId, a.appliedAmountLc);
      final vatPart = split.vat;
      final netPart = split.net;
      lines.add(_GlLine(advCode, advName, '$depLabel ${a.appliedToDocNo}', 0, netPart * lc, 0, isFcDoc ? netPart : 0));
      if (vatPart > 0) {
        lines.add(_GlLine(vatCode, vatName, '$depLabel ${a.appliedToDocNo}', 0, vatPart * lc, 0, isFcDoc ? vatPart : 0));
      }
      if (split.pend > 0.005) {
        lines.add(_GlLine('—', _depositPendingVatLabel, '$depLabel ${a.appliedToDocNo}', 0, split.pend * lc, 0, isFcDoc ? split.pend : 0));
      }
    }
  }

}

// ── Helper: GL line ─────────────────────────────────────────────────────────
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

// ── Helper: editable GL row for inline section ───────────────────────────────
class _GlEditRow {
  String accountName;
  double debit;
  double credit;
  double debitFc;
  double creditFc;
  Map<int, int?> dimIds;
  Map<int, String?> dimCodes;
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
    Map<int, String?>? dimCodes,
    Map<int, String?>? dimNames,
  })  : acctCodeCtrl = TextEditingController(text: accountCode),
        descCtrl = TextEditingController(text: description),
        dimIds = dimIds ?? {},
        dimCodes = dimCodes ?? {},
        dimNames = dimNames ?? {};

  factory _GlEditRow.fromLine(_GlLine l, {
    Map<int, int?>? dimIds,
    Map<int, String?>? dimCodes,
    Map<int, String?>? dimNames,
  }) =>
      _GlEditRow(
        accountCode: l.accountCode,
        accountName: l.accountName,
        description: l.description,
        debit: l.debit,
        credit: l.credit,
        debitFc: l.debitFc,
        creditFc: l.creditFc,
        dimIds: dimIds,
        dimCodes: dimCodes,
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
        dimCodes: {1: d.dim1Code, 2: d.dim2Code, 3: d.dim3Code, 4: d.dim4Code, 5: d.dim5Code},
        dimNames: {1: d.dim1Name, 2: d.dim2Name, 3: d.dim3Name, 4: d.dim4Name, 5: d.dim5Name},
      );

  void dispose() {
    acctCodeCtrl.dispose();
    descCtrl.dispose();
  }
}

// ── Helper: detail row ──────────────────────────────────────────────────────
class _DetailRow {
  final TextEditingController itemCodeCtrl;
  final TextEditingController itemNameCtrl;
  final TextEditingController descCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController discPctCtrl;
  final TextEditingController totalCtrl;
  String vatType;
  double vatRate;
  int? expenseAccountId;
  bool isDeferredVat;
  Map<int, int?> dims; // มิติของบรรทัด slot → value id (ว่าง = ใช้มิติหัวเอกสาร)
  // หน่วยของบรรทัด (บรรทัดที่สร้างจากเอกสาร IM) — แสดงอย่างเดียว ส่งรหัสกลับตอนบันทึกเพื่อไม่ให้หาย
  String? unitCode, unitNameTh, unitNameEn;

  _DetailRow({
    String? itemCode,
    String? itemName,
    String? desc,
    double qty = 1,
    double price = 0,
    double discPct = 0,
    this.vatType = 'VAT7',
    this.vatRate = 7.0,
    this.expenseAccountId,
    this.isDeferredVat = false,
    double totalFc = 0,
    Map<int, int?>? dims,
    this.unitCode,
    this.unitNameTh,
    this.unitNameEn,
  })  : dims = dims ?? {},
        itemCodeCtrl = TextEditingController(text: itemCode ?? ''),
        itemNameCtrl = TextEditingController(text: itemName ?? ''),
        descCtrl = TextEditingController(text: desc ?? ''),
        qtyCtrl = TextEditingController(text: qty.toString()),
        priceCtrl = TextEditingController(text: price.toStringAsFixed(2)),
        discPctCtrl = TextEditingController(text: discPct.toStringAsFixed(2)),
        totalCtrl = TextEditingController(text: totalFc.toStringAsFixed(2));

  factory _DetailRow.fromModel(ApTransactionDetail d) => _DetailRow(
        itemCode: d.itemCode,
        itemName: d.itemName ?? d.description,
        desc: d.description,
        qty: d.quantity, price: d.unitPriceFc,
        discPct: d.discountPercent, vatType: d.vatType, vatRate: d.vatRate,
        expenseAccountId: d.expenseAccountId, isDeferredVat: d.isDeferredVat,
        totalFc: d.totalAmountFc,
        dims: {1: d.dim1Id, 2: d.dim2Id, 3: d.dim3Id, 4: d.dim4Id, 5: d.dim5Id},
        unitCode: d.unitCode, unitNameTh: d.unitNameTh, unitNameEn: d.unitNameEn,
      );

  String unitLabel(bool isEnglish) {
    final n = isEnglish && (unitNameEn ?? '').isNotEmpty ? unitNameEn! : (unitNameTh ?? '');
    return n.isNotEmpty ? n : (unitCode ?? '');
  }

  void dispose() {
    itemCodeCtrl.dispose(); itemNameCtrl.dispose(); descCtrl.dispose();
    qtyCtrl.dispose(); priceCtrl.dispose();
    discPctCtrl.dispose(); totalCtrl.dispose();
  }
}

// ── Helper: apply row ───────────────────────────────────────────────────────
class _ApplyRow {
  final int appliedToId;
  final String appliedToDocNo;
  final DateTime? appliedToDocDate;
  final double appliedToTotal;
  double appliedAmountLc;

  _ApplyRow({
    required this.appliedToId,
    required this.appliedToDocNo,
    this.appliedToDocDate,
    this.appliedToTotal = 0,
    this.appliedAmountLc = 0,
  });
}

// ── Helper: payment row ─────────────────────────────────────────────────────
class _PaymentRow {
  final int? paymentMethodId;
  final String? paymentMethodCode;
  final String? paymentMethodName;
  final String paymentMethodType;
  final int? cmBankAccountId;
  final int? glAccountId;
  final TextEditingController amountCtrl;
  final TextEditingController refNoCtrl;
  final TextEditingController remarkCtrl;
  final TextEditingController drawerBankNameCtrl;
  final TextEditingController drawerBankBranchCtrl;
  final TextEditingController drawerAccountNoCtrl;
  DateTime? paymentDate;
  int? checkbookId; // จ่ายด้วยเช็ค (60/80): สมุดเช็ค

  _PaymentRow({
    this.paymentMethodId, this.paymentMethodCode, this.paymentMethodName,
    this.paymentMethodType = 'CASH',
    this.cmBankAccountId, this.glAccountId,
    double amount = 0, String? refNo, String? remark, this.paymentDate,
    String? drawerBankName, String? drawerBankBranch, String? drawerAccountNo, this.checkbookId,
  })  : amountCtrl = TextEditingController(text: amount > 0 ? amount.toStringAsFixed(2) : ''),
        refNoCtrl = TextEditingController(text: refNo ?? ''),
        remarkCtrl = TextEditingController(text: remark ?? ''),
        drawerBankNameCtrl = TextEditingController(text: drawerBankName ?? ''),
        drawerBankBranchCtrl = TextEditingController(text: drawerBankBranch ?? ''),
        drawerAccountNoCtrl = TextEditingController(text: drawerAccountNo ?? '');

  factory _PaymentRow.fromModel(ApTransactionPayment p, [bool isFc = false]) => _PaymentRow(
        paymentMethodId: p.paymentMethodId, paymentMethodCode: p.paymentMethodCode,
        paymentMethodName: p.paymentMethodName, paymentMethodType: p.paymentMethodType,
        cmBankAccountId: p.cmBankAccountId, glAccountId: p.glAccountId,
        amount: isFc && p.amountFc > 0 ? p.amountFc : p.amountLc,
        refNo: p.refNo, remark: p.remark, paymentDate: p.paymentDate,
        drawerBankName: p.drawerBankName, drawerBankBranch: p.drawerBankBranch, drawerAccountNo: p.drawerAccountNo,
        checkbookId: p.checkbookId,
      );

  void dispose() {
    amountCtrl.dispose(); refNoCtrl.dispose(); remarkCtrl.dispose();
    drawerBankNameCtrl.dispose(); drawerBankBranchCtrl.dispose(); drawerAccountNoCtrl.dispose();
  }
}

// ── Helper: WHT row ─────────────────────────────────────────────────────────
class _WhtRow {
  CdWhtType? selectedWhtType;
  final TextEditingController baseCtrl;
  final TextEditingController whtCtrl;
  final TextEditingController descCtrl;

  _WhtRow({this.selectedWhtType, double base = 0, double wht = 0, String? desc})
      : baseCtrl = TextEditingController(text: base > 0 ? base.toStringAsFixed(2) : ''),
        whtCtrl  = TextEditingController(text: wht  > 0 ? wht.toStringAsFixed(2)  : ''),
        descCtrl = TextEditingController(text: desc ?? '');

  static _WhtRow fromModel(ApTransactionWht w, List<CdWhtType> whtTypes) {
    final matched = w.whtTypeId != null
        ? whtTypes.cast<CdWhtType?>().firstWhere((t) => t!.id == w.whtTypeId, orElse: () => null)
        : null;
    return _WhtRow(
      selectedWhtType: matched,
      base: w.baseAmountLc, wht: w.whtAmountLc, desc: w.description,
    );
  }

  void dispose() {
    baseCtrl.dispose(); whtCtrl.dispose(); descCtrl.dispose();
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
