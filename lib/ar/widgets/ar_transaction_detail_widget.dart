import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../models/ar_transaction.dart';
import '../models/ar_customer.dart';
import '../services/ar_transaction_service.dart';
import '../services/ar_customer_service.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../../cd/models/cd_currency.dart';
import '../../cd/services/cd_currency_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/models/sa_user_branch.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../cd/models/cd_branch.dart';
import '../../cd/services/cd_branch_service.dart';
import '../../gl/models/gl_period.dart';
import '../../gl/services/gl_period_service.dart';
import '../../cd/models/cd_vat_rate.dart';
import '../../cd/services/cd_vat_rate_service.dart';
import '../models/ar_gl_account_setup.dart';
import '../services/ar_gl_account_setup_service.dart';
import '../../utils/date_utils.dart' show parseLocalDateNullable;
import '../../cm/models/cm_payment_method.dart';
import '../../cm/widgets/cm_payment_method_list_widget.dart';
import '../../gl/services/gl_entry_service.dart';
import '../../gl/models/gl_entry.dart';
import '../../gl/models/gl_dimension.dart';
import '../../gl/services/gl_dimension_service.dart';
import '../../gl/widgets/gl_dimension_picker_field.dart';

class ArTransactionDetailWidget extends StatefulWidget {
  final int? transactionId;
  final bool viewOnly;
  final int resetKey;
  final VoidCallback onSaveSuccess;
  final VoidCallback onCancel;

  const ArTransactionDetailWidget({
    super.key,
    this.transactionId,
    this.viewOnly = false,
    this.resetKey = 0,
    required this.onSaveSuccess,
    required this.onCancel,
  });

  @override
  State<ArTransactionDetailWidget> createState() => _ArTransactionDetailWidgetState();
}

class _ArTransactionDetailWidgetState extends State<ArTransactionDetailWidget> {
  final _formKey = GlobalKey<FormState>();
  final ArTransactionService _service = ArTransactionService();
  final ArCustomerService _customerService = ArCustomerService();
  final AccountService _accountService = AccountService();
  final CurrencyService _currencyService = CurrencyService();
  final PeriodService _periodService = PeriodService();
  final AuthService _authService = AuthService();
  final BranchService _branchService = BranchService();
  List<Branch> _allBranches = [];
  final VatRateService _vatRateService = VatRateService();
  final ArGlAccountSetupService _glSetupService = ArGlAccountSetupService();
  final GlEntryService _glEntryService = GlEntryService();
  final GlDimensionService _dimService = GlDimensionService();

  bool _isLoading = false;
  bool _isEnglish = false;

  // GL Dimensions
  List<GlDimensionType> _dimTypes = [];
  Map<String, List<GlDimensionValue>> _dimValues = {}; // keyed by typeCode
  Map<int, int?> _dimSelections = {};   // slotNo → selected dimValueId
  Map<int, String?> _dimNames = {};     // slotNo → display name

  // Master data
  List<ModuleDocument> _allowedDocTypes = [];
  List<ArCustomer> _customers = [];
  List<Account> _accounts = [];
  List<Currency> _currencies = [];
  List<PostingPeriod> _openPeriods = [];
  List<VatRate> _vatRates = [];
  ArGlAccountSetup? _docSetup;

  // State
  ModuleDocument? _selectedDocType;
  ArCustomer? _selectedCustomer;
  Currency? _selectedCurrency;
  UserBranch? _selectedBranch;
  bool _isReadOnly = false;

  // GL section state
  List<_GlEditRow> _glEditRows = [];
  bool _glLoading = false;
  bool _glSectionExpanded = true;
  final ScrollController _glHeaderHScroll = ScrollController();
  final ScrollController _glBodyHScroll   = ScrollController();
  final ScrollController _glFooterHScroll = ScrollController();

  // Header values
  int _transactionId = 0;
  int? _glEntryId;
  String _docNo = 'AUTO';
  DateTime _docDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime? _billingDate;
  DateTime? _dueDate;
  DateTime? _expectedPaymentDate;
  int? _arAccountId;
  double _exchangeRate = 1.0;
  final _refNoCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _status = 'Draft';

  // Detail rows
  List<_DetailRow> _detailRows = [];

  // Apply rows (for Receipt/CN)
  List<_ApplyRow> _applyRows = [];
  List<ArTransactionHeader> _openInvoices = [];
  final Map<int, TextEditingController> _applyCtrlMap = {};

  // Advance deduction rows (for Receipt)
  List<_ApplyRow> _advanceRows = [];
  List<ArTransactionHeader> _openAdvances = [];
  final Map<int, TextEditingController> _advanceCtrlMap = {};

  // CN deduction rows (for Receipt — แนวทาง B)
  List<_ApplyRow> _cnRows = [];
  List<ArTransactionHeader> _openCreditNotes = [];
  final Map<int, TextEditingController> _cnCtrlMap = {};

  // Advance refund rows (for RDP-65)
  List<_ApplyRow> _advanceRefundRows = [];
  List<ArTransactionHeader> _openAdvancesForRefund = [];
  final Map<int, TextEditingController> _advanceRefundCtrlMap = {};

  // Payment rows (for Receipt / Advance Receipt)
  List<_PaymentRow> _paymentRows = [];

  // ข้อมูลวางบิลของแต่ละ invoice (invoice_id → {bc_doc_no, billing_date, billed_amount})
  // โหลดเฉพาะเมื่อ Receipt + requiresBilling
  Map<int, Map<String, dynamic>> _invoiceBcMap = {};

  // Totals
  double _subtotalFc = 0;
  double _discountAmountFc = 0;
  double _beforeVatFc = 0;
  double _vatAmountFc = 0;
  double _totalAmountFc = 0;

  final _fmt = NumberFormat('#,##0.00');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  bool get _isReceipt              => _selectedDocType?.sysDocType == arDocTypeReceipt.toString();
  bool get _isCreditNote           => _selectedDocType?.sysDocType == arDocTypeCreditNote.toString();
  bool get _isCreditNoteWithBill   => _selectedDocType?.sysDocType == arDocTypeCreditNoteWithBill.toString();
  bool get _isDebitNoteWithBill    => _selectedDocType?.sysDocType == arDocTypeDebitNoteWithBill.toString();
  bool get _isAdvanceReceipt       => _selectedDocType?.sysDocType == arDocTypeAdvanceReceipt.toString();
  bool get _isAdvanceRefund        => _selectedDocType?.sysDocType == arDocTypeAdvanceRefund.toString();
  bool get _isBillCollection       => _selectedDocType?.sysDocType == arDocTypeBillCollection.toString();
  // Convenience
  bool get _hasDetailRows          => !_isReceipt && !_isAdvanceRefund && !_isDebitNoteWithBill && !_isCreditNoteWithBill && !_isBillCollection;
  bool get _hasApplySection        => _isReceipt || _isCreditNoteWithBill || _isDebitNoteWithBill || _isBillCollection;
  bool get _hasAdvanceRefundSection => _isAdvanceRefund;
  bool get _isInvoice              => _selectedDocType?.sysDocType == arDocTypeInvoice.toString();

  bool _headerExpanded  = true;
  bool _detailExpanded  = true;
  bool _applyExpanded   = true;
  bool _advanceExpanded = true;
  bool _cnExpanded      = true;
  bool _paymentExpanded = true;

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
    _glBodyHScroll.addListener(_syncGlHScroll);
    _initMasterData();
  }

  @override
  void dispose() {
    _refNoCtrl.dispose();
    _descCtrl.dispose();
    for (final r in _detailRows) r.dispose();
    for (final c in _applyCtrlMap.values) c.dispose();
    for (final c in _advanceCtrlMap.values) c.dispose();
    for (final c in _cnCtrlMap.values) c.dispose();
    for (final c in _advanceRefundCtrlMap.values) c.dispose();
    for (final r in _paymentRows) r.dispose();
    for (final r in _glEditRows) r.dispose();
    _glHeaderHScroll.dispose();
    _glBodyHScroll.dispose();
    _glFooterHScroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ArTransactionDetailWidget old) {
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
        _customerService.fetchRows(),
        _accountService.fetchRows(),
        _currencyService.fetchActiveRows(),
        _periodService.fetchOpenGlPeriods(),
        _vatRateService.fetchRows(),
        _dimService.fetchActiveTypes(),
        _branchService.fetchRows(),
      ]);
      _allowedDocTypes = results[0] as List<ModuleDocument>;
      _customers = results[1] as List<ArCustomer>;
      _accounts = results[2] as List<Account>;
      _currencies = results[3] as List<Currency>;
      _openPeriods = results[4] as List<PostingPeriod>;
      _vatRates = (results[5] as List<VatRate>).where((v) => v.isActive).toList();
      _dimTypes = results[6] as List<GlDimensionType>;
      _allBranches = results[7] as List<Branch>;

      // Load values for each active dimension type
      final dimValueResults = await Future.wait(
        _dimTypes.map((t) => _dimService.fetchValuesByType(t.typeCode)),
      );
      for (int i = 0; i < _dimTypes.length; i++) {
        _dimValues[_dimTypes[i].typeCode] = dimValueResults[i];
      }

      // Set default doc type
      if (_allowedDocTypes.isNotEmpty && _selectedDocType == null) {
        _selectedDocType = _allowedDocTypes.first;
      }
      // Set default currency (สกุลเงินหลัก)
      if (_currencies.isNotEmpty) {
        _selectedCurrency = _currencies.cast<Currency?>()
            .firstWhere((c) => c!.baseCurrencyFlag, orElse: () => null)
            ?? _currencies.first;
      }
      // Set default branch from user's default
      _selectedBranch ??= _authService.defaultBranch;
      await _loadTransactionData();
      await _loadDocSetup();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading master: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTransactionData() async {
    if (widget.transactionId == null) {
      _resetForm();
      return;
    }
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
        _billingDate = h.billingDate;
        _expectedPaymentDate = h.expectedPaymentDate;
        _arAccountId = h.arAccountId;
        _exchangeRate = h.exchangeRate;
        _refNoCtrl.text = h.refNo ?? '';
        _descCtrl.text = h.description ?? '';
        _status = h.status;
        _isReadOnly = widget.viewOnly || h.status != 'Draft';

        // Populate dimension selections from loaded header
        _dimSelections = {
          1: h.dim1Id, 2: h.dim2Id, 3: h.dim3Id, 4: h.dim4Id, 5: h.dim5Id,
        };
        _dimNames = {
          1: h.dim1Name, 2: h.dim2Name, 3: h.dim3Name, 4: h.dim4Name, 5: h.dim5Name,
        };

        if (_allowedDocTypes.isNotEmpty) {
          try { _selectedDocType = _allowedDocTypes.firstWhere((d) => d.id == h.docId); } catch (_) {}
        }
        if (_customers.isNotEmpty) {
          try { _selectedCustomer = _customers.firstWhere((c) => c.id == h.customerId); } catch (_) {}
        }
        if (_currencies.isNotEmpty) {
          try { _selectedCurrency = _currencies.firstWhere((c) => c.id == h.currencyId); } catch (_) {
            try { _selectedCurrency = _currencies.firstWhere((c) => c.currencyCode == h.currencyCode); } catch (_) {}
          }
        }
        // Restore branch from allowed list
        if (h.branchId != null) {
          final branches = _authService.allowedBranches;
          final found = branches.cast<UserBranch?>()
              .firstWhere((b) => b?.branchId == h.branchId, orElse: () => null);
          _selectedBranch = found ?? _authService.defaultBranch;
        }

        // Load detail rows
        for (final r in _detailRows) r.dispose();
        _detailRows = data.details.map((d) => _DetailRow.fromModel(d)).toList();

        // Load apply rows — BC ใช้ bc_* apply types, เอกสารอื่นใช้ invoice/advance/cn
        // _selectedDocType ถูก set แล้วข้างบน ดังนั้น _isBillCollection ใช้งานได้เลย
        // สำหรับ FC transaction ใช้ appliedAmountFc เป็น "entered amount" ใน controller
        final isBc = _isBillCollection;
        final isFcLoad = _selectedCurrency?.baseCurrencyFlag == false;
        double _fcAmt(ArTransactionApply a) =>
            isFcLoad && a.appliedAmountFc > 0 ? a.appliedAmountFc : a.appliedAmountLc;
        _applyRows = data.applies
            .where((a) => isBc
                ? a.applyType == 'bc_invoice'
                : (a.applyType == 'invoice' || a.applyType == 'dn_ref'))
            .map((a) => _ApplyRow(
                  appliedToId: a.appliedToId,
                  appliedToDocNo: a.appliedToDocNo ?? '',
                  appliedToDocDate: a.appliedToDocDate,
                  appliedToTotal: a.appliedToTotal ?? 0,
                  appliedToTotalFc: a.appliedToTotalFc,
                  appliedToExchangeRate: a.appliedToExchangeRate,
                  appliedToDueDate: a.appliedToDueDate,
                  appliedToExpectedPaymentDate: a.appliedToExpectedPaymentDate,
                  appliedAmountLc: _fcAmt(a),
                ))
            .toList();
        _advanceRows = data.applies
            .where((a) => isBc ? a.applyType == 'bc_advance' : a.applyType == 'advance')
            .map((a) => _ApplyRow(
                  appliedToId: a.appliedToId,
                  appliedToDocNo: a.appliedToDocNo ?? '',
                  appliedToDocDate: a.appliedToDocDate,
                  appliedToTotal: a.appliedToTotal ?? 0,
                  appliedToTotalFc: a.appliedToTotalFc,
                  appliedToExchangeRate: a.appliedToExchangeRate,
                  appliedToDueDate: a.appliedToDueDate,
                  appliedToExpectedPaymentDate: a.appliedToExpectedPaymentDate,
                  appliedAmountLc: _fcAmt(a),
                ))
            .toList();
        _cnRows = data.applies
            .where((a) => isBc ? a.applyType == 'bc_cn' : a.applyType == 'cn')
            .map((a) => _ApplyRow(
                  appliedToId: a.appliedToId,
                  appliedToDocNo: a.appliedToDocNo ?? '',
                  appliedToDocDate: a.appliedToDocDate,
                  appliedToTotal: a.appliedToTotal ?? 0,
                  appliedToTotalFc: a.appliedToTotalFc,
                  appliedToExchangeRate: a.appliedToExchangeRate,
                  appliedToDueDate: a.appliedToDueDate,
                  appliedToExpectedPaymentDate: a.appliedToExpectedPaymentDate,
                  appliedAmountLc: _fcAmt(a),
                ))
            .toList();
        _advanceRefundRows = data.applies
            .where((a) => a.applyType == 'advance_refund')
            .map((a) => _ApplyRow(
                  appliedToId: a.appliedToId,
                  appliedToDocNo: a.appliedToDocNo ?? '',
                  appliedToDocDate: a.appliedToDocDate,
                  appliedToTotal: a.appliedToTotal ?? 0,
                  appliedToTotalFc: a.appliedToTotalFc,
                  appliedToExchangeRate: a.appliedToExchangeRate,
                  appliedToDueDate: a.appliedToDueDate,
                  appliedToExpectedPaymentDate: a.appliedToExpectedPaymentDate,
                  appliedAmountLc: _fcAmt(a),
                ))
            .toList();
        for (final r in _paymentRows) r.dispose();
        _paymentRows = data.payments.map((p) => _PaymentRow.fromModel(p, isFcLoad)).toList();
      });
      _recalcTotals();
      if (h.status == 'Posted') _loadPostedGl();

      // โหลด open invoices สำหรับ Receipt, CN-55, DN-35
      if ((_isReceipt || _isCreditNoteWithBill || _isDebitNoteWithBill || _isBillCollection) && _selectedCustomer?.id != null) {
        await _loadOpenInvoicesKeepApplied(_selectedCustomer!.id!);
      }
      // โหลด open advances และ open CNs สำหรับ Receipt, BC
      if ((_isReceipt || _isBillCollection) && _selectedCustomer?.id != null) {
        await _loadOpenAdvancesKeepApplied(_selectedCustomer!.id!);
        await _loadOpenCreditNotesKeepApplied(_selectedCustomer!.id!);
      }
      // โหลดข้อมูลวางบิลเฉพาะ Receipt + ลูกค้าที่ต้องวางบิล
      if (_isReceipt && _selectedCustomer?.id != null &&
          (_selectedCustomer!.requiresBilling)) {
        await _loadInvoiceBillingSummary(_selectedCustomer!.id!);
      }
      // โหลดข้อมูล BC จาก ref_no เพื่อแสดงคอลัมน์วางบิลใน view mode
      if (_isReceipt && _refNoCtrl.text.trim().isNotEmpty && _invoiceBcMap.isEmpty) {
        await _loadBcMapForView(_refNoCtrl.text.trim());
      }
      // โหลด open advances for refund สำหรับ RDP-65
      if (_isAdvanceRefund && _selectedCustomer?.id != null) {
        await _loadOpenAdvancesForRefundKeepApplied(_selectedCustomer!.id!);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _fieldDeco(String label, {bool forcedReadOnly = false}) {
    final isRO = _isReadOnly || forcedReadOnly;
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
      filled: true,
      fillColor: isRO ? Colors.grey[100] : Colors.white,
    );
  }

  void _resetForm() {
    setState(() {
      _transactionId = 0;
      _glEntryId = null;
      _docNo = 'AUTO';
      _docDate = DateTime.now();
      _billingDate = null;
      _dueDate = null;
      _expectedPaymentDate = null;
      _arAccountId = null;
      _exchangeRate = 1.0;
      _refNoCtrl.clear();
      _descCtrl.clear();
      _status = 'Draft';
      _isReadOnly = false;

      // reset selections ที่ไม่ได้ clear ก่อนหน้านี้
      _selectedDocType = null;
      _selectedBranch  = _authService.defaultBranch;
      _selectedCurrency = _currencies.cast<Currency?>()
          .firstWhere((c) => c!.baseCurrencyFlag, orElse: () => null)
          ?? (_currencies.isNotEmpty ? _currencies.first : null);
      _selectedCustomer = null;
      _docSetup = null;

      _dimSelections = {};
      _dimNames = {};

      for (final r in _detailRows) r.dispose();
      _detailRows = [];

      _applyRows = [];
      _openInvoices = [];
      for (final c in _applyCtrlMap.values) c.dispose();
      _applyCtrlMap.clear();

      _advanceRows = [];
      _openAdvances = [];
      for (final c in _advanceCtrlMap.values) c.dispose();
      _advanceCtrlMap.clear();

      _cnRows = [];
      _openCreditNotes = [];
      for (final c in _cnCtrlMap.values) c.dispose();
      _cnCtrlMap.clear();

      _advanceRefundRows = [];
      _openAdvancesForRefund = [];
      for (final c in _advanceRefundCtrlMap.values) c.dispose();
      _advanceRefundCtrlMap.clear();

      for (final r in _paymentRows) r.dispose();
      _paymentRows = [];

      for (final r in _glEditRows) r.dispose();
      _glEditRows = [];

      _invoiceBcMap = {};

      _recalcTotals();
    });
  }

  // คำนวณวันครบกำหนด — ตรงกับ _previewCalcDueDate ใน ar_customer_detail_widget
  DateTime _calcDueDate(
      DateTime invoiceDate,
      DateTime? billingDate,
      List<ArCustomerBillingCondition> conditions,
      int months,
      int days) {
    final useFromBilling =
        billingDate != null && conditions.any((c) => c.dueFromBillingDate);
    var base = useFromBilling ? billingDate! : invoiceDate;
    if (months > 0) base = DateTime(base.year, base.month + months, base.day);
    if (days > 0) base = base.add(Duration(days: days));
    return base;
  }

  // คำนวณวันที่วางบิล — ตรงกับ _previewCalcBillingDate ใน ar_customer_detail_widget
  DateTime? _calcBillingDate(DateTime docDate, List<ArCustomerBillingCondition> conditions) {
    if (conditions.isEmpty) return null;
    final cond = conditions.reduce((a, b) => a.sortOrder <= b.sortOrder ? a : b);

    if (cond.billWithDelivery) return docDate;

    if (cond.billingDayOfMonth.isNotEmpty) {
      final days = [...cond.billingDayOfMonth]..sort();
      for (final day in days) {
        final lastDay = DateTime(docDate.year, docDate.month + 1, 0).day;
        final candidate = day == 31
            ? DateTime(docDate.year, docDate.month + 1, 0)
            : DateTime(docDate.year, docDate.month, day.clamp(1, lastDay));
        if (!candidate.isBefore(docDate)) return candidate;
      }
      final d = days.first;
      return d == 31
          ? DateTime(docDate.year, docDate.month + 2, 0)
          : DateTime(docDate.year, docDate.month + 1, d.clamp(1, 28));
    }

    if (cond.billingDayOfWeek.isNotEmpty) {
      if (cond.billingWeekOfMonth.isNotEmpty) {
        for (int m = 0; m <= 2; m++) {
          final totalMonth = docDate.month + m;
          final y = docDate.year + (totalMonth - 1) ~/ 12;
          final mo = ((totalMonth - 1) % 12) + 1;
          for (final wd in cond.billingDayOfWeek) {
            for (final wom in cond.billingWeekOfMonth) {
              final d = _nthWeekdayOfMonth(y, mo, wd, wom);
              if (d != null && !d.isBefore(docDate)) return d;
            }
          }
        }
      } else {
        for (int offset = 0; offset <= 13; offset++) {
          final candidate = docDate.add(Duration(days: offset));
          if (cond.billingDayOfWeek.contains(candidate.weekday % 7)) return candidate;
        }
      }
    }

    return null;
  }

  // คำนวณวันที่ weekday ลำดับที่ weekOfMonth ของเดือน
  DateTime? _nthWeekdayOfMonth(int year, int month, int weekday, int weekOfMonth) {
    if (weekOfMonth == -1) {
      final last = DateTime(year, month + 1, 0).day;
      for (int d = last; d >= 1; d--) {
        if (DateTime(year, month, d).weekday % 7 == weekday) return DateTime(year, month, d);
      }
    } else {
      int count = 0;
      for (int d = 1; d <= 31; d++) {
        final date = DateTime(year, month, d);
        if (date.month != month) break;
        if (date.weekday % 7 == weekday) {
          count++;
          if (count == weekOfMonth) return date;
        }
      }
    }
    return null;
  }

  List<DateTime> _generatePaymentCandidates(
      DateTime startDate, ArCustomerPaymentCondition cond, int maxMonths) {
    final result = <DateTime>[];
    for (int m = 0; m <= maxMonths; m++) {
      final totalMonth = startDate.month + m;
      final y  = startDate.year + (totalMonth - 1) ~/ 12;
      final mo = ((totalMonth - 1) % 12) + 1;
      if (cond.paymentDayOfMonth.isNotEmpty) {
        for (final day in cond.paymentDayOfMonth) {
          final lastDay = DateTime(y, mo + 1, 0).day;
          final d = day == 31
              ? DateTime(y, mo + 1, 0)
              : DateTime(y, mo, day.clamp(1, lastDay));
          if (!d.isBefore(startDate)) result.add(d.add(Duration(days: cond.additionalDays)));
        }
      } else if (cond.paymentDayOfWeek.isNotEmpty) {
        if (cond.paymentWeekOfMonth.isNotEmpty) {
          for (final wd in cond.paymentDayOfWeek) {
            for (final wom in cond.paymentWeekOfMonth) {
              final d = _nthWeekdayOfMonth(y, mo, wd, wom);
              if (d != null && !d.isBefore(startDate)) result.add(d.add(Duration(days: cond.additionalDays)));
            }
          }
        } else {
          for (int day = 1; day <= 31; day++) {
            final d = DateTime(y, mo, day);
            if (d.month != mo) break;
            if (!d.isBefore(startDate) && cond.paymentDayOfWeek.contains(d.weekday % 7)) {
              result.add(d.add(Duration(days: cond.additionalDays)));
            }
          }
        }
      }
    }
    return result;
  }

  // คำนวณวันที่ชำระ (คาด) จากเงื่อนไขการรับชำระของลูกค้า
  DateTime? _calcExpectedPaymentDate(DateTime? billingDate, DateTime? dueDate) {
    if (dueDate == null) return null;
    final conditions = _selectedCustomer?.paymentConditions ?? [];
    if (conditions.isEmpty) return dueDate;
    final cond = conditions.reduce((a, b) => a.sortOrder <= b.sortOrder ? a : b);
    final base = billingDate ?? dueDate;
    final maxM = cond.withinMonthsFromBilling > 0 ? cond.withinMonthsFromBilling + 1 : 6;
    var candidates = _generatePaymentCandidates(base, cond, maxM);
    if (cond.withinMonthsFromBilling > 0) {
      final limit = DateTime(base.year, base.month + cond.withinMonthsFromBilling, base.day);
      candidates = candidates.where((d) => !d.isAfter(limit)).toList();
    }
    if (candidates.isEmpty) return dueDate;
    final onOrAfter = candidates.where((d) => !d.isBefore(dueDate)).toList();
    if (onOrAfter.isNotEmpty) { onOrAfter.sort(); return onOrAfter.first; }
    candidates.sort((a, b) => b.compareTo(a));
    return candidates.first;
  }

  Future<void> _selectBillingDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _billingDate ?? _docDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() {
      _billingDate = picked;
      // ถ้า dueFromBillingDate ให้คำนวณวันครบกำหนดใหม่จากวันวางบิลที่เปลี่ยน
      if (_selectedCustomer != null &&
          (_selectedCustomer!.creditTermMonths > 0 || _selectedCustomer!.creditTermDays > 0)) {
        _dueDate = _calcDueDate(_docDate, _billingDate, _selectedCustomer!.billingConditions,
            _selectedCustomer!.creditTermMonths, _selectedCustomer!.creditTermDays);
      }
      _expectedPaymentDate = _calcExpectedPaymentDate(_billingDate, _dueDate);
    });
  }

  void _onCustomerChanged(ArCustomer? customer) {
    setState(() {
      _selectedCustomer = customer;
      // Default AR account from customer
      _arAccountId = customer?.arAccountId;
      // Default billing date from billing conditions
      _billingDate = customer != null
          ? _calcBillingDate(_docDate, customer.billingConditions)
          : null;
      // Default due date based on credit term
      if (customer != null && (customer.creditTermMonths > 0 || customer.creditTermDays > 0)) {
        _dueDate = _calcDueDate(_docDate, _billingDate, customer.billingConditions,
            customer.creditTermMonths, customer.creditTermDays);
      }
      _expectedPaymentDate = _calcExpectedPaymentDate(_billingDate, _dueDate);
      // Default currency and exchange rate from customer
      if (customer != null && customer.currencyCode.isNotEmpty) {
        final matched = _currencies.cast<Currency?>()
            .firstWhere((c) => c!.currencyCode == customer.currencyCode, orElse: () => null);
        if (matched != null) {
          _selectedCurrency = matched;
          _exchangeRate = matched.baseRate > 0 ? matched.baseRate : 1.0;
        }
      }
    });
    // Load open invoices สำหรับ Receipt, CN-55, DN-35, BC
    if ((_isReceipt || _isCreditNoteWithBill || _isDebitNoteWithBill || _isBillCollection) && customer != null) {
      _loadOpenInvoices(customer.id!);
    }
    // Load open advances และ CNs สำหรับ Receipt, BC
    if ((_isReceipt || _isBillCollection) && customer != null) {
      _loadOpenAdvances(customer.id!);
      _loadOpenCreditNotes(customer.id!);
    }
    // โหลดข้อมูลวางบิลเฉพาะ Receipt + ลูกค้าที่ต้องวางบิล
    if (_isReceipt && customer != null && customer.requiresBilling) {
      _loadInvoiceBillingSummary(customer.id!);
    }
    // Load open advances for refund สำหรับ RDP-65
    if (_isAdvanceRefund && customer != null) {
      _loadOpenAdvancesForRefund(customer.id!);
    }
  }

  Future<void> _loadOpenInvoices(int customerId) async {
    try {
      final invoices = await _service.fetchOpenInvoices(customerId);
      // dispose controllers ของ invoice เก่าก่อน
      for (final c in _applyCtrlMap.values) c.dispose();
      _applyCtrlMap.clear();
      setState(() => _openInvoices = invoices);
      // auto-fill ยอดคงเหลือสำหรับ invoice ที่ billing_date ตรงกับ doc_date
      _autoFillBillCollection();
    } catch (_) {}
  }

  // สำหรับวางบิล: ถ้า billing_date ของ invoice ตรงกับ doc_date ของเอกสาร
  // ให้ pre-fill ยอดคงเหลือเข้าช่องชำระ/หักกลบ (ยังแก้ไขได้)
  void _autoFillBillCollection() {
    if (!_isBillCollection) return;
    final isFc = _selectedCurrency?.baseCurrencyFlag == false;
    final dd = DateTime(_docDate.year, _docDate.month, _docDate.day);
    bool changed = false;
    for (final inv in _openInvoices) {
      if (inv.billingDate == null) continue;
      final bd = DateTime(
          inv.billingDate!.year, inv.billingDate!.month, inv.billingDate!.day);
      if (bd != dd) continue;
      if (inv.balanceAmountLc <= 0) continue;
      // ไม่ override ถ้ามีค่าอยู่แล้ว
      if (_applyRows.any((a) => a.appliedToId == inv.id)) continue;
      final fillAmt = isFc && inv.exchangeRate > 0
          ? inv.balanceAmountLc / inv.exchangeRate
          : inv.balanceAmountLc;
      _applyRows.add(_ApplyRow(
        appliedToId: inv.id,
        appliedToDocNo: inv.docNo,
        appliedToDocDate: inv.docDate,
        appliedToTotal: isFc ? inv.totalAmountFc : inv.totalAmountLc,
        appliedAmountLc: fillAmt,
      ));
      final ctrl = _applyCtrlMap[inv.id];
      if (ctrl != null) {
        ctrl.text = fillAmt.toStringAsFixed(2);
      } else {
        _applyCtrlMap[inv.id] = TextEditingController(
            text: fillAmt.toStringAsFixed(2));
      }
      changed = true;
    }
    if (changed && mounted) setState(() => _recalcTotals());
  }

  // โหลด open invoices โดยไม่ clear _applyCtrlMap
  // ใช้เมื่อ _applyRows มีข้อมูลอยู่แล้ว (กรณีโหลดเอกสารที่บันทึกไว้)
  Future<void> _loadOpenInvoicesKeepApplied(int customerId) async {
    try {
      final invoices = await _service.fetchOpenInvoices(customerId);
      // เพิ่ม invoices ที่อยู่ใน _applyRows แต่ไม่อยู่ใน open list
      // (เช่น invoice ที่ชำระครบแล้วหลัง Post จึงหายจาก open list แต่ยังต้องแสดง)
      final openIds = invoices.map((i) => i.id).toSet();
      final missingApplied = _applyRows
          .where((a) => !openIds.contains(a.appliedToId))
          .map((a) => ArTransactionHeader(
                id: a.appliedToId,
                docId: 0,
                docNo: a.appliedToDocNo,
                docDate: a.appliedToDocDate ?? DateTime.now(),
                customerId: customerId,
                exchangeRate: a.appliedToExchangeRate ?? 1.0,
                totalAmountLc: a.appliedToTotal ?? 0,
                totalAmountFc: a.appliedToTotalFc ?? a.appliedToTotal ?? 0,
                paidAmountLc: a.appliedToTotal ?? 0,
                balanceAmountLc: 0,
                dueDate: a.appliedToDueDate,
                expectedPaymentDate: a.appliedToExpectedPaymentDate,
                status: 'Posted',
              ))
          .toList();
      if (!mounted) return;
      setState(() => _openInvoices = [...invoices, ...missingApplied]);
      // sync controllers จาก _applyRows ให้มี text ถูกต้อง
      for (final a in _applyRows) {
        if (_applyCtrlMap.containsKey(a.appliedToId)) {
          _applyCtrlMap[a.appliedToId]!.text = a.appliedAmountLc.toStringAsFixed(2);
        } else {
          _applyCtrlMap[a.appliedToId] =
              TextEditingController(text: a.appliedAmountLc.toStringAsFixed(2));
        }
      }
    } catch (_) {}
  }

  Future<void> _loadOpenAdvances(int customerId) async {
    try {
      final advances = await _service.fetchOpenAdvances(customerId);
      for (final c in _advanceCtrlMap.values) c.dispose();
      _advanceCtrlMap.clear();
      setState(() => _openAdvances = advances);
    } catch (_) {}
  }

  Future<void> _loadOpenAdvancesKeepApplied(int customerId) async {
    try {
      final advances = await _service.fetchOpenAdvances(customerId);
      final openIds = advances.map((a) => a.id).toSet();
      final missing = _advanceRows
          .where((a) => !openIds.contains(a.appliedToId))
          .map((a) => ArTransactionHeader(
                id: a.appliedToId,
                docId: 0,
                docNo: a.appliedToDocNo,
                docDate: a.appliedToDocDate ?? DateTime.now(),
                customerId: customerId,
                exchangeRate: a.appliedToExchangeRate ?? 1.0,
                totalAmountLc: a.appliedToTotal ?? 0,
                totalAmountFc: a.appliedToTotalFc ?? a.appliedToTotal ?? 0,
                paidAmountLc: a.appliedToTotal ?? 0,
                balanceAmountLc: 0,
                status: 'Posted',
              ))
          .toList();
      if (!mounted) return;
      setState(() => _openAdvances = [...advances, ...missing]);
      for (final a in _advanceRows) {
        if (_advanceCtrlMap.containsKey(a.appliedToId)) {
          _advanceCtrlMap[a.appliedToId]!.text = a.appliedAmountLc.toStringAsFixed(2);
        } else {
          _advanceCtrlMap[a.appliedToId] =
              TextEditingController(text: a.appliedAmountLc.toStringAsFixed(2));
        }
      }
    } catch (_) {}
  }

  Future<void> _loadOpenCreditNotes(int customerId) async {
    try {
      final cns = await _service.fetchOpenCreditNotes(customerId);
      for (final c in _cnCtrlMap.values) c.dispose();
      _cnCtrlMap.clear();
      if (mounted) setState(() => _openCreditNotes = cns);
    } catch (_) {}
  }

  Future<void> _loadOpenCreditNotesKeepApplied(int customerId) async {
    try {
      final cns = await _service.fetchOpenCreditNotes(customerId);
      final openIds = cns.map((c) => c.id).toSet();
      final missing = _cnRows
          .where((r) => !openIds.contains(r.appliedToId))
          .map((r) => ArTransactionHeader(
                id: r.appliedToId,
                docId: 0,
                docNo: r.appliedToDocNo,
                docDate: r.appliedToDocDate ?? DateTime.now(),
                customerId: customerId,
                exchangeRate: r.appliedToExchangeRate ?? 1.0,
                totalAmountLc: r.appliedToTotal ?? 0,
                totalAmountFc: r.appliedToTotalFc ?? r.appliedToTotal ?? 0,
                paidAmountLc: r.appliedToTotal ?? 0,
                balanceAmountLc: 0,
                status: 'Posted',
              ))
          .toList();
      if (!mounted) return;
      setState(() => _openCreditNotes = [...cns, ...missing]);
      for (final r in _cnRows) {
        if (_cnCtrlMap.containsKey(r.appliedToId)) {
          _cnCtrlMap[r.appliedToId]!.text = r.appliedAmountLc.toStringAsFixed(2);
        } else {
          _cnCtrlMap[r.appliedToId] =
              TextEditingController(text: r.appliedAmountLc.toStringAsFixed(2));
        }
      }
    } catch (_) {}
  }

  // โหลดข้อมูลวางบิลเฉพาะเมื่อ Receipt + ลูกค้าต้องวางบิล
  Future<void> _loadInvoiceBillingSummary(int customerId) async {
    try {
      final map = await _service.fetchInvoiceBillingSummary(customerId);
      if (mounted) setState(() => _invoiceBcMap = map);
    } catch (_) {}
  }

  // โหลดข้อมูล BC จาก ref_no เพื่อแสดงคอลัมน์วางบิลใน view mode
  // ใช้ viewOnly=true เพื่อข้ามการตรวจสอบสถานะ (BC ที่ชำระแล้วก็ดึงได้)
  Future<void> _loadBcMapForView(String refNo) async {
    try {
      final bc = await _service.fetchBillCollectionByDocNo(refNo, viewOnly: true);
      if (bc == null || !mounted) return;
      final bcDate = bc.header.billingDate ?? bc.header.docDate;
      final matchedCcy = _currencies.cast<Currency?>().firstWhere(
        (c) => c!.id == bc.header.currencyId || c!.currencyCode == bc.header.currencyCode,
        orElse: () => null,
      );
      final isFcBc = matchedCcy?.baseCurrencyFlag == false;
      double bcAmt(ArTransactionApply a) =>
          isFcBc && a.appliedAmountFc > 0 ? a.appliedAmountFc : a.appliedAmountLc;
      final newBcMap = <int, Map<String, dynamic>>{};
      for (final a in bc.applies.where((a) => a.applyType == 'bc_invoice')) {
        newBcMap[a.appliedToId] = {
          'bc_doc_no': bc.header.docNo,
          'billing_date': bcDate.toIso8601String(),
          'billed_amount': bcAmt(a),
        };
      }
      if (mounted) setState(() => _invoiceBcMap = newBcMap);
    } catch (_) {}
  }

  Future<void> _loadOpenAdvancesForRefund(int customerId) async {
    try {
      final advances = await _service.fetchOpenAdvancesForRefund(customerId);
      for (final c in _advanceRefundCtrlMap.values) c.dispose();
      _advanceRefundCtrlMap.clear();
      if (mounted) setState(() => _openAdvancesForRefund = advances);
    } catch (_) {}
  }

  Future<void> _loadOpenAdvancesForRefundKeepApplied(int customerId) async {
    try {
      final advances = await _service.fetchOpenAdvancesForRefund(customerId);
      final openIds = advances.map((a) => a.id).toSet();
      final missing = _advanceRefundRows
          .where((a) => !openIds.contains(a.appliedToId))
          .map((a) => ArTransactionHeader(
                id: a.appliedToId,
                docId: 0,
                docNo: a.appliedToDocNo,
                docDate: a.appliedToDocDate ?? DateTime.now(),
                customerId: customerId,
                exchangeRate: a.appliedToExchangeRate ?? 1.0,
                totalAmountLc: a.appliedToTotal ?? 0,
                totalAmountFc: a.appliedToTotalFc ?? a.appliedToTotal ?? 0,
                paidAmountLc: a.appliedToTotal ?? 0,
                balanceAmountLc: 0,
                status: 'Posted',
              ))
          .toList();
      if (!mounted) return;
      setState(() => _openAdvancesForRefund = [...advances, ...missing]);
      for (final a in _advanceRefundRows) {
        if (_advanceRefundCtrlMap.containsKey(a.appliedToId)) {
          _advanceRefundCtrlMap[a.appliedToId]!.text = a.appliedAmountLc.toStringAsFixed(2);
        } else {
          _advanceRefundCtrlMap[a.appliedToId] =
              TextEditingController(text: a.appliedAmountLc.toStringAsFixed(2));
        }
      }
    } catch (_) {}
  }

  Future<void> _loadDocSetup() async {
    final docCode = _selectedDocType?.docCode;
    if (docCode == null) {
      if (mounted) setState(() => _docSetup = null);
      return;
    }
    try {
      final setup = await _glSetupService.fetchRow(docCode);
      if (mounted) {
        setState(() => _docSetup = setup);
        if (!_isReadOnly) _rebuildGlRows();
      }
    } catch (_) {
      if (mounted) setState(() => _docSetup = null);
    }
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

  Future<void> _loadPostedGl() async {
    if (_glEntryId == null || !mounted) return;
    setState(() => _glLoading = true);
    try {
      final result = await _glEntryService.fetchEntryDetail(_glEntryId!);
      final details = result['details'] as List<GlEntryDetail>;
      for (final r in _glEditRows) r.dispose();
      if (mounted) {
        setState(() {
          _glEditRows = details.map(_GlEditRow.fromDetail).toList();
          _glLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _glLoading = false);
    }
  }

  bool _validatePeriod(DateTime date) {
    final d = DateTime(date.year, date.month, date.day); // strip time component
    return _openPeriods.any((p) =>
        !d.isBefore(p.periodStartDate) && !d.isAfter(p.periodEndDate));
  }

  // วันที่เอกสารอ้างอิงต้องไม่เกินวันที่เอกสารธุรกรรม
  bool _isInvoiceDateValid(DateTime? docDate) {
    if (docDate == null) return true;
    final d = DateTime(docDate.year, docDate.month, docDate.day);
    final txDate = DateTime(_docDate.year, _docDate.month, _docDate.day);
    return !d.isAfter(txDate);
  }

  Future<void> _selectDate(bool isDueDate) async {
    final initial = isDueDate ? (_dueDate ?? _docDate) : _docDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    if (!isDueDate && !_validatePeriod(picked)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEnglish ? 'Document date must be within an open accounting period' : 'วันที่เอกสารต้องอยู่ในงวดบัญชีที่เปิดใช้งาน'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() {
      if (isDueDate) {
        _dueDate = picked;
      } else {
        _docDate = picked;
        if (_selectedCustomer != null) {
          _billingDate = _calcBillingDate(picked, _selectedCustomer!.billingConditions);
          if (_selectedCustomer!.creditTermMonths > 0 || _selectedCustomer!.creditTermDays > 0) {
            _dueDate = _calcDueDate(picked, _billingDate, _selectedCustomer!.billingConditions,
                _selectedCustomer!.creditTermMonths, _selectedCustomer!.creditTermDays);
          }
        }
      }
      _expectedPaymentDate = _calcExpectedPaymentDate(_billingDate, _dueDate);
    });
  }

  void _addDetailRow() {
    final defaultVat = _vatRates.cast<VatRate?>()
        .firstWhere((v) => v!.rate > 0, orElse: () => _vatRates.isNotEmpty ? _vatRates.first : null);
    setState(() => _detailRows.add(_DetailRow(
      revenueAccountId: _docSetup?.revenueAccountId,
      vatType: defaultVat?.vatCode ?? '',
      vatRate: defaultVat?.rate ?? 0.0,
    )));
  }

  void _removeDetailRow(int index) {
    setState(() {
      _detailRows[index].dispose();
      _detailRows.removeAt(index);
      _recalcTotals();
    });
  }

  void _recalcTotals() {
    double subFc = 0;
    double discFc = 0;
    double vatFc = 0;
    if (_isReceipt || _isBillCollection) {
      // Receipt / BC: total = sum(invoice applies) - advance - CN deductions
      final applied    = _applyRows.fold(0.0, (s, a) => s + a.appliedAmountLc);
      final advanced   = _advanceRows.fold(0.0, (s, a) => s + a.appliedAmountLc);
      final cnDeducted = _cnRows.fold(0.0, (s, a) => s + a.appliedAmountLc);
      subFc = applied - advanced - cnDeducted;
    } else if (_isCreditNoteWithBill || _isDebitNoteWithBill) {
      // CN-55 / DN-35: total = sum of apply rows (no detail lines)
      subFc = _applyRows.fold(0.0, (s, a) => s + a.appliedAmountLc);
    } else if (_isAdvanceRefund) {
      // For advance refund: total = sum of refunded advances
      subFc = _advanceRefundRows.fold(0.0, (s, a) => s + a.appliedAmountLc);
    } else {
      for (final r in _detailRows) {
        final qty = double.tryParse(r.qtyCtrl.text) ?? 0;
        final price = double.tryParse(r.priceCtrl.text) ?? 0;
        final discPct = double.tryParse(r.discPctCtrl.text) ?? 0;
        final sub = qty * price;
        final disc = sub * discPct / 100;
        final afterDisc = sub - disc;
        final vat = afterDisc * r.vatRate / 100;
        subFc += sub;
        discFc += disc;
        vatFc += vat;
      }
    }
    final beforeVat = subFc - discFc;
    setState(() {
      _subtotalFc = subFc;
      _discountAmountFc = discFc;
      _beforeVatFc = beforeVat;
      _vatAmountFc = vatFc;
      _totalAmountFc = beforeVat + vatFc;
    });
    if (!_isReadOnly) _rebuildGlRows();
  }

  Future<void> _save(String action) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDocType == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEnglish ? 'Please select a document type' : 'กรุณาเลือกประเภทเอกสาร')));
      return;
    }
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEnglish ? 'Please select a customer' : 'กรุณาเลือกลูกค้า')));
      return;
    }
    // BC ไม่ลงบัญชี จึงไม่ต้องตรวจสอบงวดบัญชี
    if (action == 'Post' && !_isBillCollection && !_validatePeriod(_docDate)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEnglish ? 'Document date is not within an open accounting period' : 'วันที่เอกสารไม่อยู่ในงวดบัญชีที่เปิด')));
      return;
    }

    // ตรวจสอบวันที่เอกสารอ้างอิงต้องไม่เกินวันที่เอกสาร
    final hasInvalidRef = [
      ..._applyRows, ..._advanceRows, ..._cnRows, ..._advanceRefundRows,
    ].any((a) => !_isInvoiceDateValid(a.appliedToDocDate));
    if (hasInvalidRef) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEnglish
            ? 'There are referenced documents dated after the document date. Please check the rows highlighted in red.'
            : 'มีเอกสารอ้างอิงที่มีวันที่หลังวันที่เอกสาร กรุณาตรวจสอบรายการที่ไฮไลท์สีแดง'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ));
      return;
    }

    _recalcTotals();
    final userName = _authService.currentUser?.userName ?? '';
    final lc = _exchangeRate;

    final header = ArTransactionHeader(
      id: _transactionId,
      docId: _selectedDocType!.id,
      docNo: _docNo,
      docDate: _docDate,
      dueDate: _dueDate,
      billingDate: _isInvoice ? _billingDate : null,
      expectedPaymentDate: _isInvoice ? _expectedPaymentDate : null,
      customerId: _selectedCustomer!.id!,
      customerCode: _selectedCustomer!.customerCode,
      customerNameTh: _selectedCustomer!.customerNameTh,
      arAccountId: _arAccountId,
      vatAccountId: _docSetup?.vatOutputAccountId,
      glDocId: _docSetup?.glDocId,
      currencyId: _selectedCurrency?.id,
      currencyCode: _selectedCurrency?.currencyCode ?? 'THB',
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
      createdBy: _transactionId == 0 ? userName : null,
      updatedBy: _transactionId != 0 ? userName : null,
      dim1Id: _dimSelections[1],
      dim2Id: _dimSelections[2],
      dim3Id: _dimSelections[3],
      dim4Id: _dimSelections[4],
      dim5Id: _dimSelections[5],
      branchId: _selectedBranch?.branchId,
    );

    final details = _detailRows.asMap().entries.map((e) {
      final i = e.key;
      final r = e.value;
      final qty = double.tryParse(r.qtyCtrl.text) ?? 0;
      final price = double.tryParse(r.priceCtrl.text) ?? 0;
      final discPct = double.tryParse(r.discPctCtrl.text) ?? 0;
      final sub = qty * price;
      final disc = sub * discPct / 100;
      final afterDisc = sub - disc;
      final vat = r.vatType == 'NOVAT' ? 0.0 : afterDisc * r.vatRate / 100;
      return ArTransactionDetail(
        lineNo: i + 1,
        itemCode: r.itemCodeCtrl.text.isEmpty ? null : r.itemCodeCtrl.text,
        itemName: r.itemNameCtrl.text.isEmpty ? null : r.itemNameCtrl.text,
        description: r.descCtrl.text.isEmpty ? null : r.descCtrl.text,
        quantity: qty,
        unitPriceFc: price,
        discountPercent: discPct,
        discountAmountFc: disc,
        subtotalFc: afterDisc,
        vatType: r.vatType,
        vatRate: r.vatRate,
        vatAmountFc: vat,
        totalAmountFc: afterDisc + vat,
        revenueAccountId: r.revenueAccountId,
        subtotalLc: afterDisc * lc,
        vatAmountLc: vat * lc,
        totalAmountLc: (afterDisc + vat) * lc,
        isDeferredVat: r.isDeferredVat && r.vatType != 'NOVAT',
      );
    }).toList();

    // _ApplyRow.appliedAmountLc เก็บ "ยอดที่ผู้ใช้ป้อน" ซึ่งเป็น FC สำหรับ FC transaction
    // appliedAmountFc = ยอด FC, appliedAmountLc = FC × exchangeRate = LC
    final applies = [
      ..._applyRows.map((a) => ArTransactionApply(
            appliedToId: a.appliedToId,
            appliedAmountFc: a.appliedAmountLc,
            appliedAmountLc: a.appliedAmountLc * lc,
            applyType: _isDebitNoteWithBill ? 'dn_ref' : _isBillCollection ? 'bc_invoice' : 'invoice',
          )),
      ..._advanceRows.map((a) => ArTransactionApply(
            appliedToId: a.appliedToId,
            appliedAmountFc: a.appliedAmountLc,
            appliedAmountLc: a.appliedAmountLc * lc,
            applyType: _isBillCollection ? 'bc_advance' : 'advance',
          )),
      ..._cnRows.map((a) => ArTransactionApply(
            appliedToId: a.appliedToId,
            appliedAmountFc: a.appliedAmountLc,
            appliedAmountLc: a.appliedAmountLc * lc,
            applyType: _isBillCollection ? 'bc_cn' : 'cn',
          )),
      ..._advanceRefundRows.map((a) => ArTransactionApply(
            appliedToId: a.appliedToId,
            appliedAmountFc: a.appliedAmountLc,
            appliedAmountLc: a.appliedAmountLc * lc,
            applyType: 'advance_refund',
          )),
    ];

    final payments = _paymentRows.asMap().entries.map((e) {
      final i = e.key;
      final r = e.value;
      return ArTransactionPayment(
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
        cardType: r.cardType,
        cardLast4: r.cardLast4Ctrl.text.isEmpty ? null : r.cardLast4Ctrl.text,
        approvalCode: r.approvalCodeCtrl.text.isEmpty ? null : r.approvalCodeCtrl.text,
        terminalId: r.terminalIdCtrl.text.isEmpty ? null : r.terminalIdCtrl.text,
        batchNo: r.batchNoCtrl.text.isEmpty ? null : r.batchNoCtrl.text,
      );
    }).toList();

    setState(() => _isLoading = true);
    try {
      if (_transactionId == 0) {
        await _service.createTransaction(
          header: header, details: details, applies: applies, payments: payments, action: action,
        );
      } else {
        await _service.updateTransaction(
          id: _transactionId, header: header, details: details, applies: applies, payments: payments, action: action,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(action == 'Post'
              ? (_isEnglish ? 'Saved and posted successfully' : 'บันทึกและ Post เรียบร้อย')
              : (_isEnglish ? 'Draft saved successfully' : 'บันทึก Draft เรียบร้อย'))),
        );
        widget.onSaveSuccess();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEnglish
              ? 'Save failed: ${e.toString().replaceFirst('Exception: ', '')}'
              : 'บันทึกไม่สำเร็จ: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
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
          builder: (ctx, setStateDialog) => AlertDialog(
            title: Row(children: [
              Icon(Icons.cancel_outlined, color: Colors.red[700], size: 20),
              const SizedBox(width: 8),
              Text(isEnglish ? 'Confirm Void Document' : 'ยืนยันการยกเลิกเอกสาร'),
            ]),
            content: SizedBox(
              width: 400,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red[200]!)),
                  child: Text(_isBillCollection
                      ? (isEnglish
                          ? 'A voided document cannot be restored.\nThe billed amount will be cleared.'
                          : 'เอกสารที่ยกเลิกแล้วไม่สามารถกู้คืนได้\nยอดวางบิลจะถูกเคลียร์ออก')
                      : (isEnglish
                          ? 'A voided document cannot be restored.\nThe system will create a Reversing GL Entry to reverse the accounting impact.'
                          : 'เอกสารที่ยกเลิกแล้วไม่สามารถกู้คืนได้\nระบบจะสร้าง Reversing GL Entry เพื่อยกเลิกผลกระทบทางบัญชี'),
                      style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: isEnglish ? 'Void Reason *' : 'เหตุผลการยกเลิก *',
                    hintText: isEnglish ? 'e.g. incorrect amount, wrong customer' : 'เช่น ยอดเงินผิด, ลูกหนี้ผิดราย',
                    border: const OutlineInputBorder(),
                    errorText: errorText,
                  ),
                  autofocus: true,
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEnglish ? 'Close' : 'ปิด')),
              ElevatedButton.icon(
                onPressed: () {
                  if (reasonCtrl.text.trim().isEmpty) {
                    setStateDialog(() => errorText = isEnglish ? 'Please specify a reason' : 'กรุณาระบุเหตุผล');
                    return;
                  }
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
      await _service.voidTransaction(_transactionId, voidReason: voidReason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Document voided successfully' : 'ยกเลิกเอกสารเรียบร้อย')));
        widget.onSaveSuccess();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Bill Collection lookup (ใช้ใน Receipt เท่านั้น) ─────────────────────
  // ดึงข้อมูลจากใบวางบิลมา pre-fill apply rows ของ Receipt
  Future<void> _lookupBillCollectionFromRefNo() async {
    final isEnglish = _isEnglish;
    final docNo = _refNoCtrl.text.trim();
    if (docNo.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final bc = await _service.fetchBillCollectionByDocNo(docNo);
      if (bc == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEnglish ? 'Bill collection not found: $docNo' : 'ไม่พบใบวางบิล: $docNo'), backgroundColor: Colors.orange));
        return;
      }
      if (_selectedCustomer?.id != null && bc.header.customerId != _selectedCustomer!.id) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEnglish ? 'The bill collection does not match the selected customer' : 'ใบวางบิลไม่ตรงกับลูกค้าที่เลือก'), backgroundColor: Colors.red));
        return;
      }
      // ถ้ายังไม่ได้เลือกลูกค้า ให้ set จาก BC
      if (_selectedCustomer == null && _customers.isNotEmpty) {
        try { _selectedCustomer = _customers.firstWhere((c) => c.id == bc.header.customerId); } catch (_) {}
        if (_selectedCustomer != null) await _loadOpenInvoicesKeepApplied(_selectedCustomer!.id!);
      }
      // ─── ดึงสกุลเงินและอัตราแลกเปลี่ยนจากใบวางบิล ───
      final matchedCcy = _currencies.cast<Currency?>()
          .firstWhere(
            (c) => c!.id == bc.header.currencyId || c!.currencyCode == bc.header.currencyCode,
            orElse: () => null);
      final isFcBc = matchedCcy?.baseCurrencyFlag == false;
      double bcAmt(ArTransactionApply a) =>
          isFcBc && a.appliedAmountFc > 0 ? a.appliedAmountFc : a.appliedAmountLc;
      // สร้าง invoiceBcMap สำหรับแสดงคอลัมน์วางบิลวันที่
      final bcDate = bc.header.billingDate ?? bc.header.docDate;
      final newBcMap = <int, Map<String, dynamic>>{};
      for (final a in bc.applies.where((a) => a.applyType == 'bc_invoice')) {
        newBcMap[a.appliedToId] = {
          'bc_doc_no': bc.header.docNo,
          'billing_date': bcDate.toIso8601String(),
          'billed_amount': bcAmt(a),
        };
      }
      setState(() {
        if (matchedCcy != null) {
          _selectedCurrency = matchedCcy;
          _exchangeRate = bc.header.exchangeRate > 0
              ? bc.header.exchangeRate
              : (matchedCcy.baseRate > 0 ? matchedCcy.baseRate : 1.0);
        }
        _invoiceBcMap = newBcMap;
        _applyRows = bc.applies
            .where((a) => a.applyType == 'bc_invoice')
            .map((a) => _ApplyRow(
                  appliedToId: a.appliedToId,
                  appliedToDocNo: a.appliedToDocNo ?? '',
                  appliedToDocDate: a.appliedToDocDate,
                  appliedToTotal: a.appliedToTotal ?? 0,
                  appliedAmountLc: bcAmt(a),
                ))
            .toList();
        _advanceRows = bc.applies
            .where((a) => a.applyType == 'bc_advance')
            .map((a) => _ApplyRow(
                  appliedToId: a.appliedToId,
                  appliedToDocNo: a.appliedToDocNo ?? '',
                  appliedToDocDate: a.appliedToDocDate,
                  appliedToTotal: a.appliedToTotal ?? 0,
                  appliedAmountLc: bcAmt(a),
                ))
            .toList();
        _cnRows = bc.applies
            .where((a) => a.applyType == 'bc_cn')
            .map((a) => _ApplyRow(
                  appliedToId: a.appliedToId,
                  appliedToDocNo: a.appliedToDocNo ?? '',
                  appliedToDocDate: a.appliedToDocDate,
                  appliedToTotal: a.appliedToTotal ?? 0,
                  appliedAmountLc: bcAmt(a),
                ))
            .toList();
      });
      // ซิงค์ค่า controller ให้ตรงกับยอดในใบวางบิล
      for (final a in _applyRows) {
        _applyCtrlMap.putIfAbsent(a.appliedToId, () => TextEditingController())
            .text = a.appliedAmountLc.toStringAsFixed(2);
      }
      for (final a in _advanceRows) {
        _advanceCtrlMap.putIfAbsent(a.appliedToId, () => TextEditingController())
            .text = a.appliedAmountLc.toStringAsFixed(2);
      }
      for (final a in _cnRows) {
        _cnCtrlMap.putIfAbsent(a.appliedToId, () => TextEditingController())
            .text = a.appliedAmountLc.toStringAsFixed(2);
      }
      _recalcTotals();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEnglish ? 'Fetched bill collection ${bc.header.docNo} successfully' : 'ดึงข้อมูลวางบิล ${bc.header.docNo} เรียบร้อย')));
    } on BcAlreadyPaidException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.error_outline, color: Colors.red, size: 40),
            title: Text(isEnglish ? 'Bill Collection Already Paid' : 'ใบวางบิลถูกชำระแล้ว'),
            content: Text(
              isEnglish
                  ? 'Bill collection "$docNo" has already been paid.\nReceipt No.: ${e.receiptDocNo}'
                  : 'ใบวางบิล "$docNo" ถูกนำไปชำระเรียบร้อยแล้ว\n'
                    'โดยเลขที่ใบรับชำระ: ${e.receiptDocNo}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(isEnglish ? 'Close' : 'ปิด'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Detail row sync helpers ───────────────────────────────────────────────
  // เมื่อ qty / price / disc / vat เปลี่ยน → คำนวณ total ใหม่ แล้วอัปเดต totalCtrl
  void _onDetailFieldChanged(_DetailRow r) {
    final qty     = double.tryParse(r.qtyCtrl.text)    ?? 0;
    final price   = double.tryParse(r.priceCtrl.text)  ?? 0;
    final discPct = double.tryParse(r.discPctCtrl.text) ?? 0;
    final afterDisc = qty * price * (1 - discPct / 100);
    final vat     = afterDisc * r.vatRate / 100;
    r.totalCtrl.text = (afterDisc + vat).toStringAsFixed(2);
    _recalcTotals();
  }

  // เมื่อ total ถูกแก้ไข → ถอด VAT ออก แล้วคำนวณราคา/หน่วยใหม่
  void _onTotalChanged(_DetailRow r, String value) {
    final total   = double.tryParse(value) ?? 0;
    final qty     = double.tryParse(r.qtyCtrl.text)    ?? 0;
    final discPct = double.tryParse(r.discPctCtrl.text) ?? 0;
    // total = afterDisc × (1 + vatRate/100)  →  afterDisc = total / (1 + vatRate/100)
    final afterDisc = total / (1 + r.vatRate / 100);
    // afterDisc = qty × price × (1 - discPct/100)  →  price = afterDisc / (qty × (1-discPct/100))
    final qtyFactor = qty * (1 - discPct / 100);
    r.priceCtrl.text = qtyFactor != 0
        ? (afterDisc / qtyFactor).toStringAsFixed(4)
        : '0.0000';
    _recalcTotals();
  }

  // ── VAT helpers ───────────────────────────────────────────────────────────
  String _vatLabel(String vatCode) {
    final v = _vatRates.cast<VatRate?>()
        .firstWhere((x) => x?.vatCode == vatCode, orElse: () => null);
    if (v != null) {
      final rateStr = v.rate.toStringAsFixed(v.rate % 1 == 0 ? 0 : 2);
      return '${v.vatCode}  $rateStr%';
    }
    return vatCode;
  }

  String _safeVatCode(String vatCode) {
    if (_vatRates.any((v) => v.vatCode == vatCode)) return vatCode;
    return _vatRates.isNotEmpty ? _vatRates.first.vatCode : vatCode;
  }

  // UserBranch (allowed branches) has no English name — resolve it from the
  // full bilingual Branch list (loaded in _initMasterData) by branchId.
  String _resolveBranchName(int? branchId, String fallbackThai, bool isEnglish) {
    if (isEnglish) {
      final match = _allBranches.where((b) => b.id == branchId);
      if (match.isNotEmpty && match.first.branchNameEng.isNotEmpty) {
        return match.first.branchNameEng;
      }
    }
    return fallbackThai;
  }

  // ---- Show branch picker dialog ----
  Future<void> _showBranchDialog() async {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    final branches = _authService.allowedBranches;
    if (branches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEnglish ? 'No authorized branches configured. Please contact the administrator.' : 'ยังไม่ได้กำหนดสาขาที่มีสิทธิ์ กรุณาติดต่อผู้ดูแลระบบ')),
      );
      return;
    }
    final result = await showDialog<UserBranch>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.business, size: 20, color: Colors.teal),
          const SizedBox(width: 8),
          Text(isEnglish ? 'Select Branch' : 'เลือกสาขา'),
        ]),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: branches.map((b) => ListTile(
              dense: true,
              selected: _selectedBranch?.branchId == b.branchId,
              selectedTileColor: Colors.teal.shade50,
              leading: _selectedBranch?.branchId == b.branchId
                  ? const Icon(Icons.check_circle, color: Colors.teal, size: 18)
                  : const SizedBox(width: 18),
              title: Text('${b.branchCode}  ${_resolveBranchName(b.branchId, b.branchNameThai, isEnglish)}',
                  style: const TextStyle(fontSize: 14)),
              onTap: () => Navigator.of(ctx).pop(b),
            )).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Close' : 'ปิด')),
        ],
      ),
    );
    if (result != null && mounted) setState(() => _selectedBranch = result);
  }

  // ---- Show customer picker dialog ----
  Future<ArCustomer?> _showCustomerPicker() async {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    final searchCtrl = TextEditingController();
    List<ArCustomer> filtered = List.from(_customers);

    return showDialog<ArCustomer>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        void doFilter() {
          final q = searchCtrl.text.toUpperCase();
          setS(() => filtered = q.isEmpty
              ? _customers
              : _customers.where((c) =>
                  c.customerCode.toUpperCase().contains(q) ||
                  c.customerNameTh.toUpperCase().contains(q) ||
                  (c.customerNameEn ?? '').toUpperCase().contains(q)).toList());
        }
        return Dialog(
          child: SizedBox(
            width: 500, height: 500,
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
                  final displayName = isEnglish && (c.customerNameEn ?? '').isNotEmpty ? c.customerNameEn! : c.customerNameTh;
                  return ListTile(
                    dense: true,
                    title: Text('${c.customerCode} - $displayName', style: const TextStyle(fontSize: 13)),
                    subtitle: !isEnglish && c.customerNameEn != null ? Text(c.customerNameEn!, style: const TextStyle(fontSize: 11)) : null,
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
  }

  // ---- Show account picker dialog ----
  Future<Account?> _showAccountPicker() async {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    final searchCtrl = TextEditingController();
    // Only show normal accounts (can receive transactions) that are not control accounts
    final available = _accounts.where((a) => a.isNormalAccount && !a.isControlAccount && a.isActive).toList();
    List<Account> filtered = List.from(available);

    return showDialog<Account>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        void doFilter() {
          final q = searchCtrl.text.toUpperCase();
          setS(() => filtered = q.isEmpty
              ? available
              : available.where((a) =>
                  a.accountCode.toUpperCase().contains(q) ||
                  a.accountNameThai.toUpperCase().contains(q) ||
                  a.accountNameEng.toUpperCase().contains(q)).toList());
        }
        return Dialog(
          child: SizedBox(
            width: 520, height: 500,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(labelText: isEnglish ? 'Search Account' : 'ค้นหาบัญชี', prefixIcon: const Icon(Icons.search), border: const OutlineInputBorder()),
                  onChanged: (_) => doFilter(),
                  autofocus: true,
                ),
              ),
              Expanded(child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final a = filtered[i];
                  final displayName = isEnglish && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai;
                  return ListTile(
                    dense: true,
                    title: Text('${a.accountCode} - $displayName', style: const TextStyle(fontSize: 13)),
                    onTap: () => Navigator.pop(ctx, a),
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

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return Form(
      key: _formKey,
      child: Column(children: [
        _buildActionButtons(),
        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderSection(),
                const SizedBox(height: 4),
                if (_hasDetailRows) ...[
                  _buildDetailSection(),
                  const SizedBox(height: 16),
                ],
                if (_hasApplySection) ...[
                  _buildApplySection(),
                  const SizedBox(height: 16),
                ],
                if (_hasAdvanceRefundSection) ...[
                  _buildAdvanceRefundSection(),
                  const SizedBox(height: 16),
                ],
                if (_isReceipt || _isAdvanceReceipt) ...[
                  _buildPaymentSection(),
                  const SizedBox(height: 16),
                ],
                _buildTotalsSection(),
                if (_selectedCustomer != null && _selectedDocType != null && !_isBillCollection) ...[
                  const SizedBox(height: 16),
                  _buildGlSection(),
                ],
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildHeaderSection() {
    final isEnglish = _isEnglish;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header title row — ประกอบด้วย title + 4 fields หลัก
          Row(children: [
            const Icon(Icons.article_outlined, size: 18),
            const SizedBox(width: 6),
            Text(isEnglish ? 'Document Header' : 'ข้อมูลหัวเอกสาร', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(_headerExpanded ? Icons.expand_less : Icons.expand_more, size: 18),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _headerExpanded = !_headerExpanded),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: DropdownButtonFormField<ModuleDocument>(
                value: _selectedDocType,
                isExpanded: true,
                decoration: _fieldDeco(isEnglish ? 'Document Type *' : 'ประเภทเอกสาร *'),
                items: _allowedDocTypes.map((d) => DropdownMenuItem(
                  value: d,
                  child: Text('${d.docCode} ${isEnglish && d.docNameEng.isNotEmpty ? d.docNameEng : d.docNameThai}', overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: _isReadOnly ? null : (v) {
                  setState(() {
                    _selectedDocType = v;
                    _detailRows.clear();
                    _applyRows.clear();
                    _advanceRows.clear();
                    _cnRows.clear();
                    _advanceRefundRows.clear();
                    for (final r in _paymentRows) r.dispose();
                    _paymentRows.clear();
                    _openInvoices.clear();
                    _openAdvances.clear();
                    _openCreditNotes.clear();
                    _openAdvancesForRefund.clear();
                  });
                  if (_selectedCustomer != null) {
                    if (_isReceipt || _isCreditNoteWithBill || _isDebitNoteWithBill || _isBillCollection) {
                      _loadOpenInvoices(_selectedCustomer!.id!);
                    }
                    if (_isReceipt || _isBillCollection) {
                      _loadOpenAdvances(_selectedCustomer!.id!);
                      _loadOpenCreditNotes(_selectedCustomer!.id!);
                    }
                    if (_isAdvanceRefund) {
                      _loadOpenAdvancesForRefund(_selectedCustomer!.id!);
                    }
                  }
                  _recalcTotals();
                  _loadDocSetup();
                },
                validator: (v) => v == null ? (isEnglish ? 'Please select' : 'กรุณาเลือก') : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: TextFormField(
                key: ValueKey('ar_docNo_${widget.resetKey}_$_transactionId'),
                initialValue: _docNo == 'AUTO' ? '' : _docNo,
                decoration: _fieldDeco(
                    _selectedDocType?.isAutoNumbering == true
                        ? (isEnglish ? 'Auto Number' : 'เลขที่อัตโนมัติ')
                        : (isEnglish ? 'Doc No.' : 'เลขที่เอกสาร'),
                    forcedReadOnly: _selectedDocType?.isAutoNumbering == true).copyWith(
                  hintText: _selectedDocType?.isAutoNumbering == true
                      ? (isEnglish ? '(auto-generated)' : '(ระบบกำหนดให้อัตโนมัติ)')
                      : (isEnglish ? 'Enter doc no.' : 'ระบุเลขที่'),
                ),
                readOnly: _isReadOnly || (_selectedDocType?.isAutoNumbering == true),
                onChanged: (v) => _docNo = v.isEmpty ? 'AUTO' : v,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: InkWell(
                onTap: _isReadOnly ? null : () => _selectDate(false),
                child: InputDecorator(
                  decoration: _fieldDeco(isEnglish ? 'Doc Date *' : 'วันที่เอกสาร *'),
                  child: Row(children: [
                    Expanded(child: Text(_dateFmt.format(_docDate))),
                    if (!_isReadOnly) const Icon(Icons.calendar_today, size: 14),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: TextFormField(
                controller: _refNoCtrl,
                decoration: _fieldDeco(isEnglish ? 'Reference No.' : 'เลขที่อ้างอิง').copyWith(
                  suffixIcon: (_isReceipt && !_isReadOnly)
                      ? IconButton(
                          icon: const Icon(Icons.search, size: 16),
                          tooltip: isEnglish ? 'Fetch from bill collection' : 'ดึงข้อมูลจากใบวางบิล',
                          visualDensity: VisualDensity.compact,
                          onPressed: _lookupBillCollectionFromRefNo,
                        )
                      : null,
                ),
                readOnly: _isReadOnly,
              ),
            ),
            if (_status != 'Draft') ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _status == 'Posted' ? Colors.green[50] : Colors.red[50],
                  border: Border.all(color: _status == 'Posted' ? Colors.green : Colors.red),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isEnglish
                      ? (_status == 'Posted' ? 'Posted' : _status == 'Void' ? 'Void' : _status)
                      : (_status == 'Posted' ? 'บันทึกแล้ว' : _status == 'Void' ? 'ยกเลิกแล้ว' : _status),
                  style: TextStyle(color: _status == 'Posted' ? Colors.green[800] : Colors.red[800], fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ]),
          if (_headerExpanded) ...[
          const SizedBox(height: 12),
          // Branch + Dimensions row (all flex: 1)
          Row(children: [
            Expanded(
              flex: 1,
              child: InkWell(
                onTap: _isReadOnly ? null : _showBranchDialog,
                child: InputDecorator(
                  decoration: _fieldDeco(isEnglish ? 'Branch' : 'สาขา').copyWith(
                    suffixIcon: _isReadOnly ? null : const Icon(Icons.search, size: 16),
                  ),
                  child: Text(
                    _selectedBranch != null
                        ? '${_selectedBranch!.branchCode}  ${_resolveBranchName(_selectedBranch!.branchId, _selectedBranch!.branchNameThai, isEnglish)}'
                        : (isEnglish ? '— Not specified —' : '— ไม่ระบุสาขา —'),
                    style: TextStyle(
                        color: _selectedBranch == null ? Colors.grey[500] : null,
                        fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            ..._dimTypes.expand((dimType) {
              final values = _dimValues[dimType.typeCode] ?? [];
              final selectedId = _dimSelections[dimType.slotNo];
              final selectedVal = values.cast<GlDimensionValue?>()
                  .firstWhere((v) => v?.id == selectedId, orElse: () => null);
              return [
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: GlDimensionPickerField(
                    dimType:    dimType,
                    values:     values,
                    selected:   selectedVal,
                    readOnly:   _isReadOnly,
                    isDense:    false,
                    onSelected: (val) => setState(() {
                      _dimSelections[dimType.slotNo] = val?.id;
                      _dimNames[dimType.slotNo] = val?.valueNameThai;
                    }),
                  ),
                ),
              ];
            }),
          ]),
          const SizedBox(height: 12),
          // Row 2: Customer (3) | Currency (1) | ExchangeRate (1) | Description (3)
          Row(children: [
            Expanded(
              flex: 3,
              child: InkWell(
                onTap: _isReadOnly ? null : () async {
                  final c = await _showCustomerPicker();
                  if (c != null && c.id != null) {
                    try {
                      // fetch full customer เพื่อให้ได้ billingConditions + paymentConditions
                      final full = await _customerService.fetchRow(c.id!);
                      if (mounted) _onCustomerChanged(full);
                    } catch (_) {
                      if (mounted) _onCustomerChanged(c);
                    }
                  }
                },
                child: InputDecorator(
                  decoration: _fieldDeco(isEnglish ? 'Customer *' : 'ลูกค้า *').copyWith(
                    suffixIcon: _isReadOnly ? null : const Icon(Icons.search, size: 16),
                  ),
                  child: Text(
                    _selectedCustomer != null
                        ? '${_selectedCustomer!.customerCode} - ${isEnglish && (_selectedCustomer!.customerNameEn ?? '').isNotEmpty ? _selectedCustomer!.customerNameEn! : _selectedCustomer!.customerNameTh}'
                        : (isEnglish ? 'Click to select customer' : 'คลิกเพื่อเลือกลูกค้า'),
                    style: TextStyle(color: _selectedCustomer == null ? Colors.grey : null),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: DropdownButtonFormField<Currency>(
                value: _selectedCurrency,
                isExpanded: true,
                decoration: _fieldDeco(isEnglish ? 'Currency' : 'สกุลเงิน'),
                items: _currencies.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text('${c.currencyCode} - ${isEnglish && c.currencyNameEng.isNotEmpty ? c.currencyNameEng : c.currencyNameThai}', overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: _isReadOnly ? null : (v) => setState(() { _selectedCurrency = v; _exchangeRate = v?.baseRate ?? 1.0; }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: TextFormField(
                key: ValueKey('ar_rate_${widget.resetKey}_${_transactionId}_${_selectedCurrency?.currencyCode}'),
                initialValue: _exchangeRate.toStringAsFixed(6),
                decoration: _fieldDeco(isEnglish ? 'Exchange Rate' : 'อัตราแลกเปลี่ยน'),
                keyboardType: TextInputType.number,
                readOnly: _isReadOnly,
                onChanged: (v) => setState(() => _exchangeRate = double.tryParse(v) ?? 1.0),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _descCtrl,
                decoration: _fieldDeco(isEnglish ? 'Description' : 'คำอธิบาย'),
                readOnly: _isReadOnly,
              ),
            ),
          ]),
          // แถววันที่ — แสดงเฉพาะประเภทเอกสารตั้งหนี้ (ต้องเลือกลูกค้าก่อน)
          if (_isInvoice) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                flex: 1,
                child: InkWell(
                  onTap: _isReadOnly ? null : _selectBillingDate,
                  child: InputDecorator(
                    decoration: _fieldDeco(isEnglish ? 'Billing Date' : 'วันที่วางบิล'),
                    child: Row(children: [
                      Expanded(child: Text(_billingDate != null ? _dateFmt.format(_billingDate!) : '-')),
                      if (!_isReadOnly) const Icon(Icons.calendar_today, size: 14),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: InkWell(
                  onTap: _isReadOnly ? null : () => _selectDate(true),
                  child: InputDecorator(
                    decoration: _fieldDeco(isEnglish ? 'Due Date' : 'วันครบกำหนด'),
                    child: Row(children: [
                      Expanded(child: Text(_dueDate != null ? _dateFmt.format(_dueDate!) : '-')),
                      if (!_isReadOnly) const Icon(Icons.calendar_today, size: 14),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: InputDecorator(
                  decoration: _fieldDeco(isEnglish ? 'Expected Payment Date' : 'วันที่ชำระ (คาด)', forcedReadOnly: true),
                  child: Text(
                    _expectedPaymentDate != null ? _dateFmt.format(_expectedPaymentDate!) : '-',
                    style: TextStyle(color: _expectedPaymentDate != null ? null : Colors.grey[500]),
                  ),
                ),
              ),
            ]),
          ],
          ], // end _headerExpanded
        ]),
      ),
    );
  }

  Widget _buildDetailSection() {
    final isEnglish = _isEnglish;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.list_alt, size: 18),
            const SizedBox(width: 6),
            Text(isEnglish ? 'Item / Service Details' : 'รายละเอียดสินค้า/บริการ', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(_detailExpanded ? Icons.expand_less : Icons.expand_more, size: 18),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _detailExpanded = !_detailExpanded),
            ),
            const Spacer(),
            if (!_isReadOnly)
              ElevatedButton.icon(
                onPressed: _addDetailRow,
                icon: const Icon(Icons.add, size: 14),
                label: Text(isEnglish ? 'Add Line' : 'เพิ่มรายการ'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700], foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
              ),
          ]),
          if (_detailExpanded) ...[
          const SizedBox(height: 12),
          if (_detailRows.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(isEnglish ? 'No items' : 'ไม่มีรายการ', style: const TextStyle(color: Colors.grey))))
          else
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.teal[50]),
                columnSpacing: 8,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 52,
                columns: [
                  const DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text(isEnglish ? 'Item Code' : 'รหัสสินค้า', style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text(isEnglish ? 'Item / Service Name' : 'ชื่อสินค้า/บริการ', style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text(isEnglish ? 'Qty' : 'จำนวน', style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                  DataColumn(label: Text(isEnglish ? 'Unit Price' : 'ราคา/หน่วย', style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                  DataColumn(label: Text(isEnglish ? 'Disc %' : 'ส่วนลด%', style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                  DataColumn(label: Text(isEnglish ? 'Net Amount' : 'ยอดสุทธิ', style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                  DataColumn(label: Text('VAT', style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text(isEnglish ? 'VAT Amount' : 'ยอด VAT', style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                  DataColumn(label: Text(isEnglish ? 'Total' : 'รวม', style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                  DataColumn(label: Tooltip(message: isEnglish ? 'VAT recorded at payment, not at billing' : 'VAT บันทึกตอนรับชำระ ไม่ใช่ตอนตั้งหนี้', child: Text(isEnglish ? 'Deferred\nVAT' : 'VAT\nรอตัด', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center))),
                  if (!_isReadOnly) const DataColumn(label: Text('')),
                ],
                rows: _detailRows.asMap().entries.map((e) {
                  final i = e.key;
                  final r = e.value;
                  final qty = double.tryParse(r.qtyCtrl.text) ?? 0;
                  final price = double.tryParse(r.priceCtrl.text) ?? 0;
                  final discPct = double.tryParse(r.discPctCtrl.text) ?? 0;
                  final sub = qty * price;
                  final disc = sub * discPct / 100;
                  final afterDisc = sub - disc;
                  final vat = afterDisc * r.vatRate / 100;

                  return DataRow(cells: [
                    DataCell(Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                    DataCell(SizedBox(width: 90, child: TextFormField(
                      controller: r.itemCodeCtrl,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: !_isReadOnly,
                        fillColor: Colors.white,
                        border: InputBorder.none,
                        enabledBorder: _isReadOnly ? InputBorder.none : const UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal, width: 1)),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal, width: 2)),
                      ),
                      style: const TextStyle(fontSize: 12),
                      readOnly: _isReadOnly,
                    ))),
                    DataCell(SizedBox(width: 160, child: TextFormField(
                      controller: r.itemNameCtrl,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: !_isReadOnly,
                        fillColor: Colors.white,
                        border: InputBorder.none,
                        enabledBorder: _isReadOnly ? InputBorder.none : const UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal, width: 1)),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal, width: 2)),
                      ),
                      style: const TextStyle(fontSize: 12),
                      readOnly: _isReadOnly,
                    ))),
                    DataCell(SizedBox(width: 70, child: TextFormField(
                      controller: r.qtyCtrl,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: !_isReadOnly,
                        fillColor: Colors.white,
                        border: InputBorder.none,
                        enabledBorder: _isReadOnly ? InputBorder.none : const UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal, width: 1)),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal, width: 2)),
                      ),
                      style: const TextStyle(fontSize: 12),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      textAlign: TextAlign.right,
                      readOnly: _isReadOnly,
                      onChanged: (_) => _onDetailFieldChanged(r),
                    ))),
                    DataCell(SizedBox(width: 100, child: TextFormField(
                      controller: r.priceCtrl,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: !_isReadOnly,
                        fillColor: Colors.white,
                        border: InputBorder.none,
                        enabledBorder: _isReadOnly ? InputBorder.none : const UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal, width: 1)),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal, width: 2)),
                      ),
                      style: const TextStyle(fontSize: 12),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      textAlign: TextAlign.right,
                      readOnly: _isReadOnly,
                      onChanged: (_) => _onDetailFieldChanged(r),
                    ))),
                    DataCell(SizedBox(width: 60, child: TextFormField(
                      controller: r.discPctCtrl,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: !_isReadOnly,
                        fillColor: Colors.white,
                        border: InputBorder.none,
                        enabledBorder: _isReadOnly ? InputBorder.none : const UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal, width: 1)),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal, width: 2)),
                      ),
                      style: const TextStyle(fontSize: 12),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      textAlign: TextAlign.right,
                      readOnly: _isReadOnly,
                      onChanged: (_) => _onDetailFieldChanged(r),
                    ))),
                    DataCell(Text(_fmt.format(afterDisc), style: const TextStyle(fontSize: 12))),
                    DataCell(SizedBox(width: 110, child: _isReadOnly
                        ? Text(_vatLabel(r.vatType), style: const TextStyle(fontSize: 12))
                        : DropdownButtonHideUnderline(child: DropdownButton<String>(
                            value: _safeVatCode(r.vatType),
                            isDense: true,
                            isExpanded: true,
                            style: const TextStyle(fontSize: 12, color: Colors.black),
                            items: _vatRates.map((v) {
                              final rateStr = v.rate.toStringAsFixed(v.rate % 1 == 0 ? 0 : 2);
                              return DropdownMenuItem<String>(
                                value: v.vatCode,
                                child: Text('${v.vatCode}  $rateStr%'),
                              );
                            }).toList(),
                            onChanged: (code) {
                              if (code == null) return;
                              final v = _vatRates.cast<VatRate?>()
                                  .firstWhere((x) => x?.vatCode == code, orElse: () => null);
                              setState(() {
                                r.vatType = code;
                                r.vatRate = v?.rate ?? 0.0;
                              });
                              _onDetailFieldChanged(r);
                            },
                          )))),
                    DataCell(Text(_fmt.format(vat), style: const TextStyle(fontSize: 12))),
                    DataCell(SizedBox(width: 100, child: _isReadOnly
                        ? Text(_fmt.format(double.tryParse(r.totalCtrl.text) ?? 0),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.right)
                        : TextFormField(
                            controller: r.totalCtrl,
                            decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                            textAlign: TextAlign.right,
                            onChanged: (v) => _onTotalChanged(r, v),
                          ))),
                    DataCell(Checkbox(
                      value: r.isDeferredVat,
                      tristate: false,
                      visualDensity: VisualDensity.compact,
                      onChanged: (r.vatType == 'NOVAT' || _isReadOnly) ? null : (v) {
                        setState(() => r.isDeferredVat = v ?? false);
                        _rebuildGlRows();
                      },
                    )),
                    if (!_isReadOnly)
                      DataCell(IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red), onPressed: () => _removeDetailRow(i), visualDensity: VisualDensity.compact)),
                  ]);
                }).toList(),
                  ),
                ),
              ),
            ),
          ], // end _detailExpanded
          if (_detailRows.isNotEmpty) ...[
            const Divider(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${isEnglish ? 'Net Total' : 'ยอดรวมสุทธิ'}: ${_fmt.format(_totalAmountFc)} ${_selectedCurrency?.currencyCode ?? 'THB'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildApplySection() {
    final isEnglish = _isEnglish;
    final totalApplied   = _applyRows.fold(0.0, (s, a) => s + a.appliedAmountLc);
    final totalAdvance   = _advanceRows.fold(0.0, (s, a) => s + a.appliedAmountLc);
    final totalCnDeduct  = _cnRows.fold(0.0, (s, a) => s + a.appliedAmountLc);
    final totalCash      = totalApplied - totalAdvance - totalCnDeduct;
    final currency       = _selectedCurrency?.currencyCode ?? '';
    final showBcCols        = _isReceipt &&
        (_selectedCustomer?.requiresBilling == true ||
         _invoiceBcMap.isNotEmpty ||
         _refNoCtrl.text.trim().isNotEmpty);
    final showBcBillingCol  = _isBillCollection; // วางบิล: แสดงคอลัมน์วันที่วางบิลตามใบแจ้งหนี้
    final isFcDoc = _selectedCurrency?.baseCurrencyFlag == false; // เอกสารเป็น FC

    // เงื่อนไขการแสดง card หักมัดจำ / หักใบลดหนี้ (Receipt และ BC)
    final showAdvanceCard = (_isReceipt || _isBillCollection) &&
        (_openAdvances.isNotEmpty || _advanceRows.isNotEmpty);
    final showCnCard = (_isReceipt || _isBillCollection) &&
        (_openCreditNotes.isNotEmpty || _cnRows.isNotEmpty);

    return Column(children: [
      // ── ส่วน 1: จับคู่ชำระหนี้ / จับคู่กับใบแจ้งหนี้ ────────────
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.link, size: 18),
              const SizedBox(width: 6),
              Text(
                _isDebitNoteWithBill
                    ? (isEnglish ? 'Referenced Invoices (Debit Note)' : 'ใบแจ้งหนี้อ้างอิง (เพิ่มหนี้)')
                    : _isCreditNoteWithBill
                        ? (isEnglish ? 'Match with Invoices (Credit Note)' : 'จับคู่กับใบแจ้งหนี้ (ลดหนี้)')
                        : _isBillCollection
                            ? (isEnglish ? 'Bill Collection Items' : 'รายการวางบิล')
                            : (isEnglish ? 'Match Payment' : 'จับคู่ชำระหนี้'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(_applyExpanded ? Icons.expand_less : Icons.expand_more, size: 18),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onPressed: () => setState(() => _applyExpanded = !_applyExpanded),
              ),
            ]),
            if (_applyExpanded) ...[
            const SizedBox(height: 12),
            if (_selectedCustomer == null)
              Text(isEnglish ? 'Please select a customer first' : 'กรุณาเลือกลูกค้าก่อน', style: const TextStyle(color: Colors.grey))
            else if (_openInvoices.isEmpty)
              Text(isEnglish ? 'No outstanding invoices found' : 'ไม่พบใบแจ้งหนี้ค้างชำระ', style: const TextStyle(color: Colors.grey))
            else
              LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.teal[50]),
                      columnSpacing: 12,
                      dataRowMinHeight: 36,
                      dataRowMaxHeight: 46,
                      columns: [
                        DataColumn(label: Text(isEnglish ? 'Doc No.' : 'เลขที่เอกสาร', style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(isEnglish ? 'Date' : 'วันที่', style: const TextStyle(fontWeight: FontWeight.bold))),
                        if (showBcCols) ...[
                          DataColumn(label: Text(isEnglish ? 'Billed Date' : 'วางบิลวันที่', style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text(isEnglish ? 'Billed Amount' : 'ยอดวางบิล', style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        ],
                        if (showBcBillingCol)
                          DataColumn(label: Text(isEnglish ? 'Billing Date' : 'วันที่วางบิล', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
                        DataColumn(label: Text(isEnglish ? 'Due Date' : 'ครบกำหนด', style: const TextStyle(fontWeight: FontWeight.bold))),
                        if (_isReceipt)
                          DataColumn(label: Text(isEnglish ? 'Expected' : 'ชำระ(คาด)', style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(isFcDoc ? '${isEnglish ? 'Total' : 'ยอดรวม'} ($currency)' : (isEnglish ? 'Total' : 'ยอดรวม'), style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        DataColumn(label: Text(isFcDoc ? '${isEnglish ? 'Balance' : 'คงเหลือ'} ($currency)' : (isEnglish ? 'Balance' : 'คงเหลือ'), style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        DataColumn(label: Text(isFcDoc ? '${isEnglish ? 'Pay' : 'ชำระ'} ($currency)' : (isEnglish ? 'Pay/Offset' : 'ชำระ/หักกลบ'), style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      ],
                      rows: _openInvoices.where((inv) => _isInvoiceDateValid(inv.docDate)).map((inv) {
                        final existing = _applyRows.where((a) => a.appliedToId == inv.id).firstOrNull;
                        final applyCtrl = _applyCtrlMap.putIfAbsent(
                          inv.id,
                          () => TextEditingController(text: existing?.appliedAmountLc.toStringAsFixed(2) ?? ''),
                        );
                        final bcInfo = _invoiceBcMap[inv.id];
                        // วางบิล: ตรวจว่า billing_date ตรงกับ doc_date หรือไม่
                        final invBdOnly = inv.billingDate == null ? null
                            : DateTime(inv.billingDate!.year, inv.billingDate!.month, inv.billingDate!.day);
                        final docDateOnly = DateTime(_docDate.year, _docDate.month, _docDate.day);
                        final isBillingMatch = showBcBillingCol &&
                            invBdOnly != null && invBdOnly == docDateOnly;
                        return DataRow(
                          color: isBillingMatch
                              ? WidgetStateProperty.all(Colors.amber[100])
                              : null,
                          cells: [
                          DataCell(Text(inv.docNo, style: const TextStyle(fontSize: 12))),
                          DataCell(Text(_dateFmt.format(inv.docDate), style: const TextStyle(fontSize: 12))),
                          if (showBcCols) ...[
                            DataCell(() {
                              final hasRefNo = _refNoCtrl.text.trim().isNotEmpty;
                              DateTime? displayDate;
                              if (hasRefNo) {
                                displayDate = bcInfo != null && bcInfo['billing_date'] != null
                                    ? parseLocalDateNullable(bcInfo['billing_date'])
                                    : null;
                              } else {
                                displayDate = inv.billingDate;
                              }
                              return Text(
                                displayDate != null ? _dateFmt.format(displayDate) : '-',
                                style: TextStyle(fontSize: 12, color: displayDate != null ? Colors.blue[700] : Colors.grey),
                              );
                            }()),
                            DataCell(Text(
                              bcInfo != null ? _fmt.format(num.tryParse(bcInfo['billed_amount'].toString()) ?? 0) : '-',
                              style: TextStyle(fontSize: 12, color: bcInfo != null ? Colors.blue[700] : Colors.grey),
                            )),
                          ],
                          if (showBcBillingCol)
                            DataCell(Text(
                              inv.billingDate != null ? _dateFmt.format(inv.billingDate!) : '-',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isBillingMatch ? FontWeight.bold : FontWeight.normal,
                                color: isBillingMatch ? Colors.teal[800] : Colors.black54,
                              ),
                            )),
                          DataCell(Text(inv.dueDate != null ? _dateFmt.format(inv.dueDate!) : '-', style: const TextStyle(fontSize: 12))),
                          if (_isReceipt) ...[
                            DataCell(() {
                              final epd = inv.expectedPaymentDate;
                              if (epd == null) return const Text('-', style: TextStyle(fontSize: 12));
                              final epdOnly = DateTime(epd.year, epd.month, epd.day);
                              final isLate = epdOnly != docDateOnly;
                              return Text(
                                _dateFmt.format(epd),
                                style: TextStyle(fontSize: 12, color: isLate ? Colors.red : null, fontWeight: isLate ? FontWeight.bold : null),
                              );
                            }()),
                          ],
                          DataCell(Text(_fmt.format(isFcDoc ? inv.totalAmountFc : inv.totalAmountLc), style: const TextStyle(fontSize: 12))),
                          DataCell(Text(
                              _fmt.format(isFcDoc && inv.exchangeRate > 0
                                  ? inv.balanceAmountLc / inv.exchangeRate
                                  : inv.balanceAmountLc),
                              style: TextStyle(fontSize: 12, color: Colors.blue[700]))),
                          DataCell(SizedBox(width: 140, child: _isReadOnly
                            ? Text(_fmt.format(existing?.appliedAmountLc ?? 0),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                textAlign: TextAlign.right)
                            : TextFormField(
                                controller: applyCtrl,
                                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                                style: const TextStyle(fontSize: 12),
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.right,
                                onChanged: (v) {
                                  final amount = double.tryParse(v) ?? 0;
                                  final idx = _applyRows.indexWhere((a) => a.appliedToId == inv.id);
                                  if (amount <= 0) {
                                    if (idx >= 0) setState(() { _applyRows.removeAt(idx); _recalcTotals(); });
                                  } else {
                                    final row = _ApplyRow(
                                      appliedToId: inv.id, appliedToDocNo: inv.docNo,
                                      appliedToDocDate: inv.docDate,
                                      appliedToTotal: isFcDoc ? inv.totalAmountFc : inv.totalAmountLc,
                                      appliedAmountLc: amount,
                                    );
                                    setState(() {
                                      if (idx >= 0) _applyRows[idx] = row; else _applyRows.add(row);
                                      _recalcTotals();
                                    });
                                  }
                                },
                              )))
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ], // end _applyExpanded
            const SizedBox(height: 8),
            Text(
              _isDebitNoteWithBill
                  ? '${isEnglish ? 'Referenced Debit Amount' : 'ยอดเพิ่มหนี้อ้างอิง'}: ${_fmt.format(totalApplied)} $currency'
                  : _isCreditNoteWithBill
                      ? '${isEnglish ? 'Matched Credit Amount' : 'ยอดลดหนี้ที่จับคู่'}: ${_fmt.format(totalApplied)} $currency'
                      : _isBillCollection
                          ? '${isEnglish ? 'Billed Amount' : 'ยอดวางบิล'}: ${_fmt.format(totalApplied)} $currency'
                          : '${isEnglish ? 'Invoice Payment Amount' : 'ยอดชำระ Invoice'}: ${_fmt.format(totalApplied)} $currency',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ]),
        ),
      ),

      // ── ส่วน 2: หักมัดจำ (แสดงเฉพาะ Receipt และมีเอกสารมัดจำ) ──
      if (showAdvanceCard) ...[
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.currency_exchange, size: 18, color: Colors.orange[700]),
                const SizedBox(width: 6),
                Text(isEnglish ? 'Advance Deduction' : 'หักมัดจำ', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.orange[800])),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(_advanceExpanded ? Icons.expand_less : Icons.expand_more, size: 18),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  onPressed: () => setState(() => _advanceExpanded = !_advanceExpanded),
                ),
              ]),
              if (_advanceExpanded) ...[
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.orange[50]),
                      columnSpacing: 12,
                      dataRowMinHeight: 36,
                      dataRowMaxHeight: 46,
                      columns: [
                        DataColumn(label: Text(isEnglish ? 'Advance No.' : 'เลขที่มัดจำ', style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(isEnglish ? 'Date' : 'วันที่', style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(isFcDoc ? '${isEnglish ? 'Advance Amount' : 'ยอดมัดจำ'} ($currency)' : (isEnglish ? 'Advance Amount' : 'ยอดมัดจำ'), style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        DataColumn(label: Text(isFcDoc ? '${isEnglish ? 'Balance' : 'คงเหลือ'} ($currency)' : (isEnglish ? 'Balance' : 'คงเหลือ'), style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        DataColumn(label: Text(isFcDoc ? '${isEnglish ? 'Deduct' : 'หักมัดจำ'} ($currency)' : (isEnglish ? 'Deduct' : 'หักมัดจำ'), style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      ],
                      rows: _openAdvances.where((adv) => _isInvoiceDateValid(adv.docDate)).map((adv) {
                        final existing = _advanceRows.where((a) => a.appliedToId == adv.id).firstOrNull;
                        final advCtrl = _advanceCtrlMap.putIfAbsent(
                          adv.id,
                          () => TextEditingController(text: existing?.appliedAmountLc.toStringAsFixed(2) ?? ''),
                        );
                        final advTotalDisplay = isFcDoc ? adv.totalAmountFc : adv.totalAmountLc;
                        final advBalanceDisplay = isFcDoc && adv.exchangeRate > 0
                            ? adv.balanceAmountLc / adv.exchangeRate
                            : adv.balanceAmountLc;
                        return DataRow(cells: [
                          DataCell(Text(adv.docNo, style: const TextStyle(fontSize: 12))),
                          DataCell(Text(_dateFmt.format(adv.docDate), style: const TextStyle(fontSize: 12))),
                          DataCell(Text(_fmt.format(advTotalDisplay), style: const TextStyle(fontSize: 12))),
                          DataCell(Text(_fmt.format(advBalanceDisplay),
                              style: TextStyle(fontSize: 12, color: Colors.orange[700]))),
                          DataCell(SizedBox(width: 140, child: _isReadOnly
                            ? Text(_fmt.format(existing?.appliedAmountLc ?? 0),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                textAlign: TextAlign.right)
                            : TextFormField(
                                controller: advCtrl,
                                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                                style: const TextStyle(fontSize: 12),
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.right,
                                onChanged: (v) {
                                  final amount = double.tryParse(v) ?? 0;
                                  final idx = _advanceRows.indexWhere((a) => a.appliedToId == adv.id);
                                  if (amount <= 0) {
                                    if (idx >= 0) setState(() { _advanceRows.removeAt(idx); _recalcTotals(); });
                                  } else {
                                    final row = _ApplyRow(
                                      appliedToId: adv.id, appliedToDocNo: adv.docNo,
                                      appliedToDocDate: adv.docDate,
                                      appliedToTotal: isFcDoc ? adv.totalAmountFc : adv.totalAmountLc,
                                      appliedAmountLc: amount,
                                    );
                                    setState(() {
                                      if (idx >= 0) _advanceRows[idx] = row; else _advanceRows.add(row);
                                      _recalcTotals();
                                    });
                                  }
                                },
                              ))),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
              ], // end _advanceExpanded
              const SizedBox(height: 8),
              Text('${isEnglish ? 'Total Advance Deducted' : 'หักมัดจำรวม'}: ${_fmt.format(totalAdvance)} $currency',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[800])),
            ]),
          ),
        ),
      ],

      // ── ส่วน 3: หักใบลดหนี้ (แสดงเฉพาะ Receipt และมีเอกสารลดหนี้) ──
      if (showCnCard) ...[
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.remove_circle_outline, size: 18, color: Colors.red[700]),
                const SizedBox(width: 6),
                Text(isEnglish ? 'Credit Note Deduction' : 'หักใบลดหนี้', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.red[800])),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(_cnExpanded ? Icons.expand_less : Icons.expand_more, size: 18),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  onPressed: () => setState(() => _cnExpanded = !_cnExpanded),
                ),
              ]),
              if (_cnExpanded) ...[
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.red[50]),
                      columnSpacing: 12,
                      dataRowMinHeight: 36,
                      dataRowMaxHeight: 46,
                      columns: [
                        DataColumn(label: Text(isEnglish ? 'CN No.' : 'เลขที่ลดหนี้', style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(isEnglish ? 'Date' : 'วันที่', style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(isFcDoc ? '${isEnglish ? 'CN Amount' : 'ยอดลดหนี้'} ($currency)' : (isEnglish ? 'CN Amount' : 'ยอดลดหนี้'), style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        DataColumn(label: Text(isFcDoc ? '${isEnglish ? 'Balance' : 'คงเหลือ'} ($currency)' : (isEnglish ? 'Balance' : 'คงเหลือ'), style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        DataColumn(label: Text(isFcDoc ? '${isEnglish ? 'Deduct' : 'หักลดหนี้'} ($currency)' : (isEnglish ? 'Deduct' : 'หักลดหนี้'), style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      ],
                      rows: _openCreditNotes.where((cn) => _isInvoiceDateValid(cn.docDate)).map((cn) {
                        final existing = _cnRows.where((r) => r.appliedToId == cn.id).firstOrNull;
                        final cnCtrl = _cnCtrlMap.putIfAbsent(
                          cn.id,
                          () => TextEditingController(text: existing?.appliedAmountLc.toStringAsFixed(2) ?? ''),
                        );
                        final cnTotalDisplay = isFcDoc ? cn.totalAmountFc : cn.totalAmountLc;
                        final cnBalanceDisplay = isFcDoc && cn.exchangeRate > 0
                            ? cn.balanceAmountLc / cn.exchangeRate
                            : cn.balanceAmountLc;
                        return DataRow(cells: [
                          DataCell(Text(cn.docNo, style: const TextStyle(fontSize: 12))),
                          DataCell(Text(_dateFmt.format(cn.docDate), style: const TextStyle(fontSize: 12))),
                          DataCell(Text(_fmt.format(cnTotalDisplay), style: const TextStyle(fontSize: 12))),
                          DataCell(Text(_fmt.format(cnBalanceDisplay),
                              style: TextStyle(fontSize: 12, color: Colors.red[700]))),
                          DataCell(SizedBox(width: 140, child: _isReadOnly
                            ? Text(_fmt.format(existing?.appliedAmountLc ?? 0),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                textAlign: TextAlign.right)
                            : TextFormField(
                                controller: cnCtrl,
                                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                                style: const TextStyle(fontSize: 12),
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.right,
                                onChanged: (v) {
                                  final amount = double.tryParse(v) ?? 0;
                                  final idx = _cnRows.indexWhere((r) => r.appliedToId == cn.id);
                                  if (amount <= 0) {
                                    if (idx >= 0) setState(() { _cnRows.removeAt(idx); _recalcTotals(); });
                                  } else {
                                    final row = _ApplyRow(
                                      appliedToId: cn.id, appliedToDocNo: cn.docNo,
                                      appliedToDocDate: cn.docDate,
                                      appliedToTotal: isFcDoc ? cn.totalAmountFc : cn.totalAmountLc,
                                      appliedAmountLc: amount,
                                    );
                                    setState(() {
                                      if (idx >= 0) _cnRows[idx] = row; else _cnRows.add(row);
                                      _recalcTotals();
                                    });
                                  }
                                },
                              ))),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
              ], // end _cnExpanded
              const SizedBox(height: 8),
              Text('${isEnglish ? 'Total Credit Note Deducted' : 'หักใบลดหนี้รวม'}: ${_fmt.format(totalCnDeduct)} $currency',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[800])),
            ]),
          ),
        ),
      ],

      // ── สรุปยอดสุทธิ (เฉพาะ Receipt) ───────────────────────────
      if (_isReceipt && (showAdvanceCard || showCnCard)) ...[
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${isEnglish ? 'Net Cash Received' : 'รับเงินสุทธิ'}: ${_fmt.format(totalCash)} $currency',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ],
    ]);
  }

  Widget _buildAdvanceRefundSection() {
    final isEnglish = _isEnglish;
    final currency = _selectedCurrency?.currencyCode ?? '';
    final totalRefund = _advanceRefundRows.fold(0.0, (s, a) => s + a.appliedAmountLc);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.undo, size: 18, color: Colors.purple[700]),
            const SizedBox(width: 6),
            Text(isEnglish ? 'Advance Refund' : 'คืนเงินมัดจำ', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold, color: Colors.purple[800])),
          ]),
          const SizedBox(height: 12),
          if (_selectedCustomer == null)
            Text(isEnglish ? 'Please select a customer first' : 'กรุณาเลือกลูกค้าก่อน', style: const TextStyle(color: Colors.grey))
          else if (_openAdvancesForRefund.isEmpty)
            Text(isEnglish ? 'No advance receipts pending refund' : 'ไม่พบใบรับเงินมัดจำค้างคืน', style: const TextStyle(color: Colors.grey))
          else
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(Colors.purple[50]),
                    columnSpacing: 12,
                    dataRowMinHeight: 36,
                    dataRowMaxHeight: 46,
                    columns: [
                      DataColumn(label: Text(isEnglish ? 'Advance No.' : 'เลขที่มัดจำ', style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text(isEnglish ? 'Date' : 'วันที่', style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text(isEnglish ? 'Advance Amount' : 'ยอดมัดจำ', style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      DataColumn(label: Text(isEnglish ? 'Balance' : 'คงเหลือ', style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      DataColumn(label: Text(isEnglish ? 'Refund' : 'คืนมัดจำ', style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                    ],
                    rows: _openAdvancesForRefund.where((adv) => _isInvoiceDateValid(adv.docDate)).map((adv) {
                      final existing = _advanceRefundRows.where((a) => a.appliedToId == adv.id).firstOrNull;
                      final ctrl = _advanceRefundCtrlMap.putIfAbsent(
                        adv.id,
                        () => TextEditingController(text: existing?.appliedAmountLc.toStringAsFixed(2) ?? ''),
                      );
                      return DataRow(cells: [
                        DataCell(Text(adv.docNo, style: const TextStyle(fontSize: 12))),
                        DataCell(Text(_dateFmt.format(adv.docDate), style: const TextStyle(fontSize: 12))),
                        DataCell(Text(_fmt.format(adv.totalAmountLc), style: const TextStyle(fontSize: 12))),
                        DataCell(Text(_fmt.format(adv.balanceAmountLc),
                            style: TextStyle(fontSize: 12, color: Colors.purple[700]))),
                        DataCell(SizedBox(width: 140, child: _isReadOnly
                          ? Text(_fmt.format(existing?.appliedAmountLc ?? 0),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              textAlign: TextAlign.right)
                          : TextFormField(
                              controller: ctrl,
                              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                              style: const TextStyle(fontSize: 12),
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.right,
                              onChanged: (v) {
                                final amount = double.tryParse(v) ?? 0;
                                final idx = _advanceRefundRows.indexWhere((a) => a.appliedToId == adv.id);
                                if (amount <= 0) {
                                  if (idx >= 0) setState(() { _advanceRefundRows.removeAt(idx); _recalcTotals(); });
                                } else {
                                  final row = _ApplyRow(
                                    appliedToId: adv.id, appliedToDocNo: adv.docNo,
                                    appliedToDocDate: adv.docDate, appliedToTotal: adv.totalAmountLc,
                                    appliedAmountLc: amount,
                                  );
                                  setState(() {
                                    if (idx >= 0) _advanceRefundRows[idx] = row; else _advanceRefundRows.add(row);
                                    _recalcTotals();
                                  });
                                }
                              },
                            ))),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text('${isEnglish ? 'Total Advance Refund' : 'ยอดคืนมัดจำรวม'}: ${_fmt.format(totalRefund)} $currency',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple[800])),
        ]),
      ),
    );
  }

  Widget _buildPaymentSection() {
    final isEnglish = _isEnglish;
    final currency = _selectedCurrency?.currencyCode ?? 'THB';
    final totalPayments = _paymentRows.fold(0.0, (s, r) => s + (double.tryParse(r.amountCtrl.text) ?? 0));
    final cashExpected = _totalAmountFc;
    final diff = cashExpected - totalPayments;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row
          Row(children: [
            Icon(Icons.payment, size: 18, color: Colors.green[700]),
            const SizedBox(width: 6),
            Text(isEnglish ? 'Payment Methods' : 'วิธีรับชำระเงิน', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold, color: Colors.green[800])),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(_paymentExpanded ? Icons.expand_less : Icons.expand_more, size: 18),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _paymentExpanded = !_paymentExpanded),
            ),
            const Spacer(),
            if (!_isReadOnly)
              ElevatedButton.icon(
                onPressed: () async {
                  await CmPaymentMethodListWidget.search(context, onSelected: (pm) {
                    setState(() {
                      _paymentRows.add(_PaymentRow(
                        paymentMethodId: pm.id,
                        paymentMethodCode: pm.methodCode,
                        paymentMethodName: pm.methodNameTh,
                        paymentMethodType: pm.methodType,
                        cmBankAccountId: pm.cmBankAccountId,
                        glAccountId: pm.glAccountId,
                        paymentDate: _docDate,
                      ));
                    });
                  });
                },
                icon: const Icon(Icons.add, size: 14),
                label: Text(isEnglish ? 'Add Payment Method' : 'เพิ่มวิธีชำระ'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact),
              ),
          ]),
          if (_paymentExpanded) ...[
          const SizedBox(height: 12),

          // Payment row cards
          if (_paymentRows.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                  isEnglish
                      ? 'No payment methods yet — click "Add Payment Method" to add'
                      : 'ยังไม่มีรายการวิธีชำระ — คลิก "เพิ่มวิธีชำระ" เพื่อเพิ่ม',
                  style: const TextStyle(color: Colors.grey)),
            ))
          else
            ...(_paymentRows.asMap().entries.map((e) {
              final i = e.key;
              final r = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildPaymentRowCard(i, r),
              );
            })),
          ], // end _paymentExpanded

          const Divider(),
          // Summary row
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(
              '${isEnglish ? 'Total Paid' : 'รวมชำระ'}: ${_fmt.format(totalPayments)} $currency   |   ${isEnglish ? 'Expected' : 'ยอดคาดหวัง'}: ${_fmt.format(cashExpected)} $currency',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800]),
            ),
            if (diff.abs() > 0.005)
              Text(
                '${isEnglish ? 'Difference' : 'ส่วนต่าง'}: ${_fmt.format(diff)} $currency',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: diff > 0 ? Colors.orange[800] : Colors.red[700]),
              ),
          ]),
        ]),
      ),
    );
  }

  Widget _buildPaymentRowCard(int index, _PaymentRow r) {
    final isEnglish = _isEnglish;
    final type = r.paymentMethodType;
    final isCheck     = type == 'CHECK';
    final isTransfer  = type == 'TRANSFER' || type == 'MOBILE_BANKING';
    final isBillOfEx  = type == 'BILL_OF_EXCHANGE';
    final isCard      = type == 'CREDIT_CARD' || type == 'DEBIT_CARD';
    final isQr        = type == 'QR_CODE';
    final needDrawer  = isCheck || isTransfer || isBillOfEx;

    final typeColor = {
      'CASH': Colors.green, 'CHECK': Colors.blue, 'TRANSFER': Colors.indigo,
      'CREDIT_CARD': Colors.purple, 'DEBIT_CARD': Colors.deepPurple,
      'QR_CODE': Colors.teal, 'MOBILE_BANKING': Colors.cyan,
      'BILL_OF_EXCHANGE': Colors.brown, 'OTHER': Colors.grey,
    }[type] ?? Colors.grey;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: typeColor.shade200),
        borderRadius: BorderRadius.circular(8),
        color: typeColor.shade50,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Row 1: Method name chip + amount + date + delete ──────────
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: typeColor.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: typeColor.shade300),
            ),
            child: Text('${r.paymentMethodCode ?? ''} — ${r.paymentMethodName ?? ''}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: typeColor.shade800)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: typeColor.shade200, borderRadius: BorderRadius.circular(10)),
            child: Text(
              (cmMethodTypeOptions[type] ?? type).split(' ').first,
              style: TextStyle(fontSize: 11, color: typeColor.shade900),
            ),
          ),
          const Spacer(),
          if (!_isReadOnly)
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red[400], size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() {
                _paymentRows[index].dispose();
                _paymentRows.removeAt(index);
              }),
            ),
        ]),
        const SizedBox(height: 10),

        // ── Row 2: Amount + Date + Remark (always) ────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            flex: 2,
            child: _payField(
              label: isEnglish ? 'Amount *' : 'จำนวนเงิน *',
              ctrl: r.amountCtrl,
              hint: '0.00',
              numeric: true,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: _isReadOnly ? null : () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: r.paymentDate ?? _docDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => r.paymentDate = picked);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: isCheck
                      ? (isEnglish ? 'Check Date' : 'วันที่บนเช็ค')
                      : isBillOfEx
                          ? (isEnglish ? 'Due Date' : 'วันครบกำหนด')
                          : (isEnglish ? 'Payment Date' : 'วันที่ชำระ'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: _isReadOnly ? null : const Icon(Icons.calendar_today, size: 14),
                ),
                child: Text(r.paymentDate != null ? _dateFmt.format(r.paymentDate!) : '-',
                    style: const TextStyle(fontSize: 13)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: _payField(label: isEnglish ? 'Remark' : 'หมายเหตุ', ctrl: r.remarkCtrl),
          ),
        ]),

        // ── Row 3: Type-specific fields ───────────────────────────────

        // CHECK / TRANSFER / MOBILE_BANKING / BILL_OF_EXCHANGE
        if (needDrawer) ...[
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 2,
              child: _payField(
                label: isCheck
                    ? (isEnglish ? 'Check No. *' : 'เลขที่เช็ค *')
                    : isBillOfEx
                        ? (isEnglish ? 'Bill No. *' : 'เลขที่ตั๋ว *')
                        : (isEnglish ? 'Reference / Slip No.' : 'เลขอ้างอิง / Slip No'),
                ctrl: r.refNoCtrl,
                hint: isCheck ? 'XXXXXXXXXX' : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _payField(
                label: isCheck
                    ? (isEnglish ? 'Issuing Bank' : 'ธนาคารผู้ออกเช็ค')
                    : isBillOfEx
                        ? (isEnglish ? 'Bank (Payer)' : 'ธนาคาร (ผู้จ่าย)')
                        : (isEnglish ? 'Transfer From Bank' : 'โอนจากธนาคาร'),
                ctrl: r.drawerBankNameCtrl,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _payField(
                label: isEnglish ? 'Branch' : 'สาขา',
                ctrl: r.drawerBankBranchCtrl,
              ),
            ),
            if (isCheck) ...[
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _payField(
                  label: isEnglish ? 'Account No. (Drawer)' : 'เลขที่บัญชี (เจ้าของเช็ค)',
                  ctrl: r.drawerAccountNoCtrl,
                ),
              ),
            ],
          ]),
        ]

        // QR_CODE — ref_no only
        else if (isQr) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              flex: 3,
              child: _payField(
                label: isEnglish ? 'Reference No. (Ref No) *' : 'เลขที่อ้างอิง (Ref No) *',
                ctrl: r.refNoCtrl,
                hint: isEnglish ? 'Transaction No. from PromptPay system' : 'เลขที่ Transaction จากระบบ PromptPay',
              ),
            ),
          ]),
        ]

        // CREDIT_CARD / DEBIT_CARD
        else if (isCard) ...[
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 2,
              child: _isReadOnly
                ? _payField(label: isEnglish ? 'Card Type' : 'ประเภทบัตร', ctrl: TextEditingController(text: cmCardNetworkOptions[r.cardType] ?? r.cardType ?? ''))
                : InputDecorator(
                    decoration: InputDecoration(labelText: isEnglish ? 'Card Type' : 'ประเภทบัตร', border: const OutlineInputBorder(), isDense: true),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: r.cardType,
                        isDense: true,
                        hint: Text(isEnglish ? 'Select' : 'เลือก', style: const TextStyle(fontSize: 12)),
                        items: cmCardNetworkOptions.entries.map((e) =>
                            DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12)))).toList(),
                        onChanged: (v) => setState(() => r.cardType = v),
                      ),
                    ),
                  ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: _payField(
                label: isEnglish ? 'Last 4 Digits *' : '4 หลักท้าย *',
                ctrl: r.cardLast4Ctrl,
                hint: 'XXXX',
                maxLength: 4,
                numeric: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _payField(
                label: isEnglish ? 'Approval Code *' : 'รหัสอนุมัติ (Approval Code) *',
                ctrl: r.approvalCodeCtrl,
                hint: isEnglish ? 'For later verification' : 'ใช้ตรวจสอบย้อนหลัง',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _payField(
                label: isEnglish ? 'Terminal ID (EDC)' : 'รหัสเครื่อง EDC (Terminal ID)',
                ctrl: r.terminalIdCtrl,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _payField(
                label: 'Batch No',
                ctrl: r.batchNoCtrl,
              ),
            ),
          ]),
        ]

        // TRANSFER (ref_no + drawer info already covered by needDrawer)
        // CASH / OTHER — no extra fields
        ,
      ]),
    );
  }

  // ── Reusable compact TextField for payment details ─────────────────
  Widget _payField({
    required String label,
    required TextEditingController ctrl,
    String? hint,
    bool numeric = false,
    int? maxLength,
    void Function(String)? onChanged,
  }) {
    if (_isReadOnly) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: label, border: const OutlineInputBorder(), isDense: true,
          filled: true, fillColor: Colors.grey[100],
        ),
        child: Text(ctrl.text.isEmpty ? '—' : ctrl.text, style: const TextStyle(fontSize: 13)),
      );
    }
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        counterText: '',
      ),
      style: const TextStyle(fontSize: 13),
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      inputFormatters: numeric ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
      maxLength: maxLength,
      onChanged: onChanged,
    );
  }

  Widget _buildTotalsSection() {
    final isEnglish = _isEnglish;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          SizedBox(
            width: 320,
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                if (!_isReceipt && !_isAdvanceRefund && !_isBillCollection) ...[
                  _totalRow(isEnglish ? 'Subtotal' : 'ยอดรวมสินค้า', _subtotalFc),
                  _totalRow(isEnglish ? 'Total Discount' : 'ส่วนลดรวม', _discountAmountFc),
                  _totalRow(isEnglish ? 'Amount Before VAT' : 'ยอดก่อน VAT', _beforeVatFc),
                  ..._buildVatRows(),
                ],
                TableRow(children: [
                  Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(isEnglish ? 'Net Total' : 'ยอดรวมสุทธิ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(
                    '${_fmt.format(_totalAmountFc)} ${_selectedCurrency?.currencyCode ?? 'THB'}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    textAlign: TextAlign.right,
                  )),
                ]),
                if (_exchangeRate != 1.0)
                  _totalRow(isEnglish ? 'Total (THB)' : 'ยอดรวม (THB)', _totalAmountFc * _exchangeRate),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  TableRow _totalRow(String label, double amount) {
    return TableRow(children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(label, style: const TextStyle(fontSize: 13))),
      Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(_fmt.format(amount), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
    ]);
  }

  TableRow _totalRowColored(String label, double amount, Color color) {
    return TableRow(children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(label, style: TextStyle(fontSize: 13, color: color))),
      Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(_fmt.format(amount), textAlign: TextAlign.right, style: TextStyle(fontSize: 13, color: color))),
    ]);
  }

  List<TableRow> _buildVatRows() {
    final isEnglish = _isEnglish;
    final deferredVat = _detailRows
        .where((r) => r.isDeferredVat && r.vatType != 'NOVAT')
        .fold(0.0, (s, r) {
          final qty = double.tryParse(r.qtyCtrl.text) ?? 0;
          final price = double.tryParse(r.priceCtrl.text) ?? 0;
          final discPct = double.tryParse(r.discPctCtrl.text) ?? 0;
          final afterDisc = qty * price * (1 - discPct / 100);
          return s + afterDisc * r.vatRate / 100;
        });
    if (deferredVat > 0) {
      return [
        _totalRow(isEnglish ? 'VAT (Immediate)' : 'VAT (ทันที)', _vatAmountFc - deferredVat),
        _totalRowColored(isEnglish ? 'VAT (Deferred)' : 'VAT (รอตัด)', deferredVat, Colors.orange[800]!),
      ];
    }
    return [_totalRow('VAT', _vatAmountFc)];
  }

  Widget _buildActionButtons() {
    final isEnglish = _isEnglish;
    final isDraft = _status == 'Draft';
    final isPosted = _status == 'Posted';
    return Container(
      color: Colors.teal[50],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
      if (!_isReadOnly && isDraft) ...[
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
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700], foregroundColor: Colors.white),
        ),
        const SizedBox(width: 8),
        if (_transactionId != 0)
          OutlinedButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(isEnglish ? 'Delete Draft' : 'ลบ Draft'),
                  content: Text(isEnglish ? 'Do you want to delete this draft document?' : 'ต้องการลบเอกสาร Draft นี้?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
                    ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: Text(isEnglish ? 'Delete' : 'ลบ')),
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
      if (isPosted)
        ElevatedButton.icon(
          onPressed: _void,
          icon: const Icon(Icons.cancel_outlined, size: 16),
          label: Text(isEnglish ? 'Void' : 'ยกเลิก (Void)'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
        ),
      const Spacer(),
      if (_selectedDocType != null && _selectedCustomer != null && !_isBillCollection) ...[
        OutlinedButton.icon(
          onPressed: _showGlEntryDialog,
          icon: const Icon(Icons.account_balance_outlined, size: 16),
          label: Text(isPosted ? 'GL Entry' : (isEnglish ? 'GL Preview' : 'ตัวอย่าง GL')),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.indigo[700]),
        ),
        const SizedBox(width: 8),
      ],
      TextButton(
        onPressed: widget.onCancel,
        child: Text(isEnglish ? 'Back' : 'กลับ'),
      ),
    ]));
  }

  // ── GL Account Search Dialog ────────────────────────────────────────────────
  Future<void> _showGlAccountSearchDialog(_GlEditRow r) async {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    final searchCtrl = TextEditingController();
    final available = _accounts.where((a) => a.isNormalAccount && a.isActive).toList();
    List<Account> filtered = List.from(available);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
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
              width: 520,
              height: 420,
              child: Column(children: [
                TextField(
                  controller: searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: isEnglish ? 'Search code / account name' : 'ค้นหา รหัส / ชื่อบัญชี',
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
                          final displayName = isEnglish && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai;
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
                              Expanded(child: Text(displayName, overflow: TextOverflow.ellipsis)),
                            ]),
                            onTap: () {
                              setState(() {
                                r.acctCodeCtrl.text = a.accountCode;
                                r.accountName = displayName;
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
        },
      ),
    );
    searchCtrl.dispose();
  }

  Widget _sectionHeader(String title, bool expanded, VoidCallback onToggle, {Widget? trailing, IconData? icon}) {
    return Row(children: [
      if (icon != null) ...[
        Icon(icon, size: 18),
        const SizedBox(width: 6),
      ],
      Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(width: 4),
      IconButton(
        icon: Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 18),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        onPressed: onToggle,
      ),
      if (trailing != null) ...[const Spacer(), trailing],
    ]);
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
        .firstWhere((c) => c!.baseCurrencyFlag, orElse: () => null)?.currencyCode ?? 'THB';
    final fcLabel = _selectedCurrency?.currencyCode ?? 'FC';
    final activeDims = _dimTypes.where((t) => t.slotNo >= 1 && t.slotNo <= 5).toList();
    final isGlEditable = _status == 'Draft' && !_isReadOnly;

    final Widget sectionTrailing = Row(mainAxisSize: MainAxisSize.min, children: [
      if (!_glLoading && _glEditRows.isNotEmpty) ...[
        Icon(isBalanced ? Icons.check_circle_outline : Icons.warning_amber_outlined,
          size: 14, color: isBalanced ? Colors.green[700] : Colors.red[700]),
        const SizedBox(width: 4),
        Text(isBalanced ? (isEnglish ? 'Balanced' : 'สมดุล') : (isEnglish ? 'Unbalanced' : 'ไม่สมดุล'),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
            color: isBalanced ? Colors.green[700] : Colors.red[700])),
        const SizedBox(width: 12),
        Text('Dr: ${fmt.format(totalDebit)}  Cr: ${fmt.format(totalCredit)}',
          style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(width: 12),
      ],
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: _status == 'Posted' ? Colors.blue[100] : Colors.orange[100],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          _status == 'Posted' ? (isEnglish ? 'Actual GL (Posted)' : 'GL จริง (Posted)') : (isEnglish ? 'GL Preview (Draft)' : 'ตัวอย่าง GL (Draft)'),
          style: TextStyle(fontSize: 11,
            color: _status == 'Posted' ? Colors.blue[800] : Colors.orange[800])),
      ),
    ]);

    Widget tableContent;
    if (_glLoading) {
      tableContent = const Padding(padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()));
    } else if (_glEditRows.isEmpty) {
      tableContent = Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          isEnglish
              ? 'No items yet — please enter item/service details above'
              : 'ยังไม่มีรายการ — กรุณาป้อนรายการสินค้า/บริการด้านบน',
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
            SizedBox(width: wCode, child: isGlEditable
              ? InkWell(
                  onTap: () => _showGlAccountSearchDialog(r),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    child: Row(children: [
                      Expanded(child: Text(r.acctCodeCtrl.text,
                        style: TextStyle(fontSize: 12,
                          color: hasErr ? Colors.red[700] : Colors.indigo[800]),
                        overflow: TextOverflow.ellipsis)),
                      Icon(Icons.search, size: 13, color: Colors.grey[400]),
                    ]),
                  ))
              : Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Text(r.acctCodeCtrl.text,
                    style: TextStyle(fontSize: 12, color: hasErr ? Colors.red : null),
                    overflow: TextOverflow.ellipsis))),
            SizedBox(width: wName, child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Text(r.accountName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
            SizedBox(width: wDesc, child: isGlEditable
              ? TextFormField(
                  controller: r.descCtrl,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    border: InputBorder.none))
              : Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
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
                readOnly: !isGlEditable, isDense: true,
                onSelected: (v) => setState(() {
                  r.dimIds[dt.slotNo]   = v?.id;
                  r.dimCodes[dt.slotNo] = v?.valueCode;
                  r.dimNames[dt.slotNo] = v?.valueNameThai;
                }),
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

    return Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader(isEnglish ? 'GL Entries' : 'รายการบัญชี GL', _glSectionExpanded,
          () => setState(() => _glSectionExpanded = !_glSectionExpanded),
          icon: Icons.account_balance_outlined,
          trailing: sectionTrailing),
        if (_glSectionExpanded) ...[
          const SizedBox(height: 8),
          tableContent,
        ],
      ]),
    ));
  }

  // ── GL Entry dialog ───────────────────────────────────────────────────────

  Future<void> _showGlEntryDialog() async {
    final isEnglish = _isEnglish;
    final isPosted = _status == 'Posted';

    if (isPosted && _glEntryId != null) {
      // Show loading, then fetch real GL
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      try {
        final result = await _glEntryService.fetchEntryDetail(_glEntryId!);
        if (!mounted) return;
        Navigator.of(context).pop();
        final header = result['header'] as GlEntryHeader;
        final details = result['details'] as List<GlEntryDetail>;
        _showGlDialog(
          title: isEnglish ? 'GL Entry — Actual Posted Entries' : 'GL Entry — รายการลงบัญชีจริง',
          statusLabel: 'Posted',
          statusColor: Colors.teal,
          glDocNo: header.docNo,
          refDocNo: header.refDocNo?.isNotEmpty == true ? header.refDocNo! : _docNo,
          docDate: header.docDate,
          description: header.description,
          lines: details.map((d) => _GlLine(d.accountCode, isEnglish && d.accountNameEng.isNotEmpty ? d.accountNameEng : d.accountName, d.description, d.debitLc, d.creditLc, d.debitFc, d.creditFc)).toList(),
          currencyCode: _selectedCurrency?.currencyCode ?? '',
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Failed to load GL: $e' : 'โหลด GL ล้มเหลว: $e')));
      }
    } else {
      // Draft preview: fetch deferred VAT proportions first (only for Receipt)
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      double deferredVatLc = 0;
      if (_isReceipt && _applyRows.isNotEmpty) {
        try {
          deferredVatLc = await _fetchDeferredVatForPreview();
        } catch (_) { /* ถ้าดึงไม่ได้ ให้ใช้ 0 */ }
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      _showGlDialog(
        title: isEnglish ? 'GL Entry Preview (Draft)' : 'ตัวอย่าง GL Entry (Draft)',
        statusLabel: 'Draft Preview',
        statusColor: Colors.orange[700]!,
        glDocNo: '—',
        refDocNo: _docNo,
        docDate: _docDate,
        description: _descCtrl.text,
        lines: _computeGlPreview(deferredVatLc: deferredVatLc),
        currencyCode: _selectedCurrency?.currencyCode ?? '',
      );
    }
  }

  /// คำนวณ VAT รอตัดบัญชี ตามสัดส่วนที่ชำระ (เหมือน backend insertDeferredVtRecordsForReceipt)
  Future<double> _fetchDeferredVatForPreview() async {
    double total = 0;
    for (final a in _applyRows) {
      if (a.appliedToId == 0 || a.appliedAmountLc <= 0 || (a.appliedToTotal ?? 0) <= 0) continue;
      final ratio = a.appliedAmountLc / (a.appliedToTotal ?? 1);
      try {
        final inv = await _service.fetchRow(a.appliedToId);
        for (final d in inv.details) {
          if (d.isDeferredVat && d.vatType != 'NOVAT') {
            total += d.vatAmountLc * ratio;
          }
        }
      } catch (_) { continue; }
    }
    return total;
  }

  void _showGlDialog({
    required String title,
    required String statusLabel,
    required Color statusColor,
    required String glDocNo,
    required String refDocNo,
    required DateTime docDate,
    required String description,
    required List<_GlLine> lines,
    String currencyCode = '',
  }) {
    final isEnglish = _isEnglish;
    final fmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd/MM/yyyy');
    final totalDebit   = lines.fold(0.0, (s, l) => s + l.debit);
    final totalCredit  = lines.fold(0.0, (s, l) => s + l.credit);
    final isBalanced   = (totalDebit - totalCredit).abs() < 0.005;
    final hasFc        = lines.any((l) => l.debitFc > 0 || l.creditFc > 0);
    final totalDebitFc  = hasFc ? lines.fold(0.0, (s, l) => s + l.debitFc)  : 0.0;
    final totalCreditFc = hasFc ? lines.fold(0.0, (s, l) => s + l.creditFc) : 0.0;
    final fcLabel = currencyCode.isNotEmpty ? currencyCode : 'FC';
    final lcLabel = _currencies.cast<Currency?>()
        .firstWhere((c) => c!.baseCurrencyFlag, orElse: () => null)?.currencyCode ?? 'THB';

    Widget cell(String text, {TextAlign align = TextAlign.left, bool bold = false, Color? color}) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(text,
              style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color),
              textAlign: align),
        );

    TableRow headerRow = hasFc
        ? TableRow(
            decoration: BoxDecoration(color: Colors.grey[200]),
            children: [
              cell('#',                   bold: true, align: TextAlign.center),
              cell(isEnglish ? 'Account Code' : 'รหัสบัญชี',            bold: true),
              cell(isEnglish ? 'Account Name' : 'ชื่อบัญชี',             bold: true),
              cell(isEnglish ? 'Description' : 'รายละเอียด',            bold: true),
              cell('${isEnglish ? 'Debit' : 'เดบิต'} ($fcLabel)',      bold: true, align: TextAlign.right),
              cell('${isEnglish ? 'Credit' : 'เครดิต'} ($fcLabel)',     bold: true, align: TextAlign.right),
              cell('${isEnglish ? 'Debit' : 'เดบิต'} ($lcLabel)',      bold: true, align: TextAlign.right),
              cell('${isEnglish ? 'Credit' : 'เครดิต'} ($lcLabel)',     bold: true, align: TextAlign.right),
            ],
          )
        : TableRow(
            decoration: BoxDecoration(color: Colors.grey[200]),
            children: [
              cell('#',        bold: true, align: TextAlign.center),
              cell(isEnglish ? 'Account Code' : 'รหัสบัญชี', bold: true),
              cell(isEnglish ? 'Account Name' : 'ชื่อบัญชี',  bold: true),
              cell(isEnglish ? 'Description' : 'รายละเอียด', bold: true),
              cell(isEnglish ? 'Debit' : 'เดบิต',     bold: true, align: TextAlign.right),
              cell(isEnglish ? 'Credit' : 'เครดิต',    bold: true, align: TextAlign.right),
            ],
          );

    List<TableRow> dataRows = lines.asMap().entries.map((e) {
      final i = e.key;
      final l = e.value;
      final bg = i.isOdd ? Colors.grey[50] : Colors.white;
      return hasFc
          ? TableRow(decoration: BoxDecoration(color: bg), children: [
              cell('${i + 1}', align: TextAlign.center),
              cell(l.accountCode),
              cell(l.accountName),
              cell(l.description),
              cell(l.debitFc  > 0 ? fmt.format(l.debitFc)  : '', align: TextAlign.right, color: Colors.blue[700]),
              cell(l.creditFc > 0 ? fmt.format(l.creditFc) : '', align: TextAlign.right, color: Colors.red[700]),
              cell(l.debit  > 0 ? fmt.format(l.debit)  : '', align: TextAlign.right, color: Colors.blue[800]),
              cell(l.credit > 0 ? fmt.format(l.credit) : '', align: TextAlign.right, color: Colors.red[800]),
            ])
          : TableRow(decoration: BoxDecoration(color: bg), children: [
              cell('${i + 1}', align: TextAlign.center),
              cell(l.accountCode),
              cell(l.accountName),
              cell(l.description),
              cell(l.debit  > 0 ? fmt.format(l.debit)  : '', align: TextAlign.right, color: Colors.blue[700]),
              cell(l.credit > 0 ? fmt.format(l.credit) : '', align: TextAlign.right, color: Colors.red[700]),
            ]);
    }).toList();

    TableRow totalsRow = hasFc
        ? TableRow(decoration: BoxDecoration(color: Colors.grey[100]), children: [
            cell(''), cell(''), cell(''),
            cell(isEnglish ? 'Total' : 'รวม', bold: true, align: TextAlign.right),
            cell(fmt.format(totalDebitFc),  bold: true, align: TextAlign.right, color: Colors.blue[700]),
            cell(fmt.format(totalCreditFc), bold: true, align: TextAlign.right, color: Colors.red[700]),
            cell(fmt.format(totalDebit),    bold: true, align: TextAlign.right, color: Colors.blue[800]),
            cell(fmt.format(totalCredit),   bold: true, align: TextAlign.right, color: Colors.red[800]),
          ])
        : TableRow(decoration: BoxDecoration(color: Colors.grey[100]), children: [
            cell(''), cell(''), cell(''),
            cell(isEnglish ? 'Total' : 'รวม', bold: true, align: TextAlign.right),
            cell(fmt.format(totalDebit),  bold: true, align: TextAlign.right, color: Colors.blue[800]),
            cell(fmt.format(totalCredit), bold: true, align: TextAlign.right, color: Colors.red[800]),
          ]);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: hasFc ? 1100 : 900, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Title row ──
              Row(children: [
                Icon(Icons.account_balance_outlined, color: Colors.indigo[700], size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (hasFc) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.indigo[50], borderRadius: BorderRadius.circular(8)),
                    child: Text('${isEnglish ? 'Currency' : 'สกุลเงิน'}: $fcLabel', style: TextStyle(fontSize: 11, color: Colors.indigo[700], fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ]),
              const Divider(height: 20),
              // ── Header info chips ──
              Wrap(spacing: 24, runSpacing: 6, children: [
                _glInfoChip('GL Doc', glDocNo),
                _glInfoChip('AR Doc', refDocNo),
                _glInfoChip(isEnglish ? 'Date' : 'วันที่', dateFmt.format(docDate)),
                if (description.isNotEmpty) _glInfoChip(isEnglish ? 'Description' : 'คำอธิบาย', description),
              ]),
              const SizedBox(height: 16),
              // ── Table ──
              Expanded(
                child: SingleChildScrollView(
                  child: Table(
                    columnWidths: hasFc
                        ? const {
                            0: FixedColumnWidth(36),
                            1: FixedColumnWidth(90),
                            2: FlexColumnWidth(1.8),
                            3: FlexColumnWidth(2.0),
                            4: FixedColumnWidth(100),
                            5: FixedColumnWidth(100),
                            6: FixedColumnWidth(100),
                            7: FixedColumnWidth(100),
                          }
                        : const {
                            0: FixedColumnWidth(36),
                            1: FixedColumnWidth(100),
                            2: FlexColumnWidth(2.0),
                            3: FlexColumnWidth(2.5),
                            4: FixedColumnWidth(115),
                            5: FixedColumnWidth(115),
                          },
                    border: TableBorder.all(color: Colors.grey[300]!, width: 0.5),
                    children: [headerRow, ...dataRows, totalsRow],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // ── Balance status + close ──
              Row(children: [
                Icon(
                  isBalanced ? Icons.check_circle_outline : Icons.warning_amber_outlined,
                  color: isBalanced ? Colors.teal : Colors.orange,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  isBalanced
                      ? (isEnglish ? 'Balanced' : 'บาลานซ์ถูกต้อง (Balanced)')
                      : '${isEnglish ? 'Unbalanced — difference' : 'ไม่บาลานซ์ — ส่วนต่าง'} ${fmt.format((totalDebit - totalCredit).abs())} $lcLabel',
                  style: TextStyle(
                    color: isBalanced ? Colors.teal : Colors.orange,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                TextButton(onPressed: () => Navigator.pop(context), child: Text(isEnglish ? 'Close' : 'ปิด')),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _glInfoChip(String label, String value) => Row(mainAxisSize: MainAxisSize.min, children: [
    Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
    Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
  ]);

  // ── Client-side GL preview for Draft ──────────────────────────────────────

  List<_GlLine> _computeGlPreview({double deferredVatLc = 0}) {
    final isEnglish = _isEnglish;
    final lines = <_GlLine>[];
    final lc = _exchangeRate;
    final isFcDoc = _selectedCurrency?.baseCurrencyFlag == false;
    final setup = _docSetup;
    final sysType = int.tryParse(_selectedDocType?.sysDocType ?? '');
    final cashFallback = isEnglish ? 'Cash' : 'เงินสด';
    final advanceFallback = isEnglish ? 'Advance' : 'เงินมัดจำ';

    if (setup == null) {
      if (_totalAmountFc == 0 && _detailRows.isEmpty && _applyRows.isEmpty && _advanceRefundRows.isEmpty) return lines;
      final arLabel = isEnglish ? 'Accounts Receivable' : 'ลูกหนี้การค้า';
      final notSetupArLabel = isEnglish ? '!AR account not configured' : '!ยังไม่ตั้งค่าบัญชีลูกหนี้';
      final notSetupRevLabel = isEnglish ? '!Revenue account not configured' : '!ยังไม่ตั้งค่าบัญชีรายได้';
      final notSetupLabel = isEnglish ? 'Not configured' : 'ยังไม่ตั้งค่าบัญชี';
      final revenueDefaultDesc = isEnglish ? 'Revenue' : 'รายได้';
      final notSetupVatLabel = isEnglish ? '!VAT account not configured' : '!ยังไม่ตั้งค่าบัญชี VAT';
      final vatDesc = isEnglish ? 'VAT' : 'ภาษีมูลค่าเพิ่ม';
      final notSetupCashLabel = isEnglish ? '!Cash account not configured' : '!ยังไม่ตั้งค่าบัญชีเงินสด';
      final cashBankLabel = isEnglish ? 'Cash/Bank' : 'เงินสด/ธนาคาร';
      final advanceReceivedDesc = isEnglish ? 'Advance Received' : 'รับมัดจำ';
      final notSetupAdvanceLabel = isEnglish ? '!Advance account not configured' : '!ยังไม่ตั้งค่าบัญชีมัดจำ';
      final advanceReceivedLabel = isEnglish ? 'Advance Received' : 'มัดจำรับ';
      final advanceRefundDesc = isEnglish ? 'Advance Refund' : 'คืนมัดจำ';
      final payAdvanceRefundDesc = isEnglish ? 'Pay Advance Refund' : 'จ่ายคืนเงินมัดจำ';
      final receivePaymentDesc = isEnglish ? 'Receive Payment' : 'รับชำระ';
      final settleDebtDesc = isEnglish ? 'Settle Debt' : 'ชำระหนี้';
      if (sysType == arDocTypeInvoice || sysType == arDocTypeDebitNote || sysType == arDocTypeDebitNoteWithBill) {
        lines.add(_GlLine(notSetupArLabel, arLabel, arLabel, _totalAmountFc * lc, 0, isFcDoc ? _totalAmountFc : 0, 0));
        for (final r in _detailRows) {
          final qty      = double.tryParse(r.qtyCtrl.text)    ?? 0;
          final price    = double.tryParse(r.priceCtrl.text)  ?? 0;
          final discPct  = double.tryParse(r.discPctCtrl.text) ?? 0;
          final afterDisc = qty * price * (1 - discPct / 100);
          final vat      = r.vatType == 'NOVAT' ? 0.0 : afterDisc * r.vatRate / 100;
          final desc     = r.itemNameCtrl.text.isNotEmpty ? r.itemNameCtrl.text : revenueDefaultDesc;
          lines.add(_GlLine(notSetupRevLabel, notSetupLabel, desc, 0, afterDisc * lc, 0, isFcDoc ? afterDisc : 0));
          if (vat > 0) lines.add(_GlLine(notSetupVatLabel, 'VAT Output', vatDesc, 0, vat * lc, 0, isFcDoc ? vat : 0));
        }
      } else if (sysType == arDocTypeCreditNote) {
        lines.add(_GlLine(notSetupArLabel, arLabel, arLabel, 0, _totalAmountFc * lc, 0, isFcDoc ? _totalAmountFc : 0));
        for (final r in _detailRows) {
          final qty      = double.tryParse(r.qtyCtrl.text)    ?? 0;
          final price    = double.tryParse(r.priceCtrl.text)  ?? 0;
          final discPct  = double.tryParse(r.discPctCtrl.text) ?? 0;
          final afterDisc = qty * price * (1 - discPct / 100);
          final vat      = r.vatType == 'NOVAT' ? 0.0 : afterDisc * r.vatRate / 100;
          final desc     = r.itemNameCtrl.text.isNotEmpty ? r.itemNameCtrl.text : revenueDefaultDesc;
          lines.add(_GlLine(notSetupRevLabel, notSetupLabel, desc, afterDisc * lc, 0, isFcDoc ? afterDisc : 0, 0));
          if (vat > 0) lines.add(_GlLine(notSetupVatLabel, 'VAT Output', vatDesc, vat * lc, 0, isFcDoc ? vat : 0, 0));
        }
      } else if (sysType == arDocTypeCreditNoteWithBill) {
        for (final a in _applyRows) {
          lines.add(_GlLine(notSetupRevLabel, notSetupLabel, '${isEnglish ? 'Credit Note' : 'ลดหนี้'} ${a.appliedToDocNo}', a.appliedAmountLc * lc, 0, isFcDoc ? a.appliedAmountLc : 0, 0));
        }
        lines.add(_GlLine(notSetupArLabel, arLabel, arLabel, 0, _totalAmountFc * lc, 0, isFcDoc ? _totalAmountFc : 0));
      } else if (sysType == arDocTypeAdvanceReceipt) {
        lines.add(_GlLine(notSetupCashLabel, cashBankLabel, advanceReceivedDesc, _totalAmountFc * lc, 0, isFcDoc ? _totalAmountFc : 0, 0));
        lines.add(_GlLine(notSetupAdvanceLabel, advanceReceivedLabel, advanceReceivedLabel, 0, _beforeVatFc * lc, 0, isFcDoc ? _beforeVatFc : 0));
        if (_vatAmountFc > 0) {
          lines.add(_GlLine(notSetupVatLabel, 'VAT Output', vatDesc, 0, _vatAmountFc * lc, 0, isFcDoc ? _vatAmountFc : 0));
        }
      } else if (sysType == arDocTypeAdvanceRefund) {
        lines.add(_GlLine(notSetupAdvanceLabel, advanceReceivedLabel, advanceRefundDesc, _totalAmountFc * lc, 0, isFcDoc ? _totalAmountFc : 0, 0));
        lines.add(_GlLine(notSetupCashLabel, cashBankLabel, payAdvanceRefundDesc, 0, _totalAmountFc * lc, 0, isFcDoc ? _totalAmountFc : 0));
      } else if (sysType == arDocTypeReceipt) {
        for (final a in _applyRows) {
          lines.add(_GlLine(notSetupCashLabel, cashBankLabel, '$receivePaymentDesc ${a.appliedToDocNo}', a.appliedAmountLc * lc, 0, isFcDoc ? a.appliedAmountLc : 0, 0));
        }
        if (lines.isNotEmpty) {
          lines.add(_GlLine(notSetupArLabel, arLabel, settleDebtDesc, 0, _totalAmountFc * lc, 0, isFcDoc ? _totalAmountFc : 0));
        }
      }
      return lines;
    }


    // Lookup account code/name from _accounts list, falling back to setup fields
    String acctCode(int? id, String? fallback) {
      if (id != null) {
        try { return _accounts.firstWhere((a) => a.id == id).accountCode; } catch (_) {}
      }
      return fallback ?? '—';
    }
    String acctName(int? id, String? fallback) {
      if (id != null) {
        try {
          final acc = _accounts.firstWhere((a) => a.id == id);
          return _isEnglish && acc.accountNameEng.isNotEmpty ? acc.accountNameEng : acc.accountNameThai;
        } catch (_) {}
      }
      return fallback ?? '';
    }

    final arDesc = isEnglish ? 'Accounts Receivable' : 'ลูกหนี้การค้า';
    final revenueDefaultDesc = isEnglish ? 'Revenue' : 'รายได้';
    final notSetupDiscountLabel = isEnglish ? '!Discount account not configured' : '!ยังไม่ตั้งค่าบัญชีส่วนลด';
    final discountPaidLabel = isEnglish ? 'Discount Paid' : 'ส่วนลดจ่าย';
    final notSetupVatPendingLabel = isEnglish ? '!Deferred VAT not configured' : '!ยังไม่ตั้งค่า VAT รอตัด';
    final deferredVatLabel = isEnglish ? 'Deferred VAT' : 'VAT รอตัดบัญชี';
    final notSetupVatLabel2 = isEnglish ? '!VAT account not configured' : '!ยังไม่ตั้งค่าบัญชี VAT';
    final vatDesc2 = isEnglish ? 'VAT' : 'ภาษีมูลค่าเพิ่ม';
    final creditNoteDesc = isEnglish ? 'Credit Note' : 'ลดหนี้';
    final advanceReceivedDesc2 = isEnglish ? 'Advance Received' : 'รับมัดจำ';
    final advanceReceivedLabel2 = isEnglish ? 'Advance Received' : 'มัดจำรับ';
    final advanceRefundDesc2 = isEnglish ? 'Advance Refund' : 'คืนมัดจำ';
    final payAdvanceRefundDesc2 = isEnglish ? 'Pay Advance Refund' : 'จ่ายคืนเงินมัดจำ';
    final receivePaymentDesc2 = isEnglish ? 'Receive Payment' : 'รับชำระ';
    final advanceDeductDesc = isEnglish ? 'Advance Deducted' : 'ตัดมัดจำ';
    final settleDebtDesc2 = isEnglish ? 'Settle Debt' : 'ชำระหนี้';
    final fxGainName = isEnglish ? 'Exchange Gain' : 'กำไรอัตราแลกเปลี่ยน';
    final fxGainDesc = isEnglish ? 'Exchange Gain' : 'กำไรจากอัตราแลกเปลี่ยน';
    final fxLossName = isEnglish ? 'Exchange Loss' : 'ขาดทุนอัตราแลกเปลี่ยน';
    final fxLossDesc = isEnglish ? 'Exchange Loss' : 'ขาดทุนจากอัตราแลกเปลี่ยน';
    final deferredVatRecognizedName = isEnglish ? 'Deferred VAT' : 'VAT รอตัดบัญชี';
    final deferredVatRecognizeDesc = isEnglish ? 'Recognize Deferred VAT' : 'รับรู้ VAT รอตัดบัญชี';
    final deferredVatRecognizedDesc = isEnglish ? 'Deferred VAT Recognized' : 'VAT รอตัดบัญชีที่รับรู้';

    // AR account: setup → customer group → customer
    final arAccountId = setup.arAccountId
        ?? _selectedCustomer?.groupArAccountId
        ?? _selectedCustomer?.arAccountId;
    final arCode = setup.arAccountCode
        ?? _selectedCustomer?.groupArAccountCode
        ?? _selectedCustomer?.arAccountCode
        ?? acctCode(arAccountId, '—');
    final arName = acctName(arAccountId, setup.arAccountName
        ?? _selectedCustomer?.groupArAccountNameThai
        ?? _selectedCustomer?.arAccountNameThai
        ?? (isEnglish ? 'AR Account' : 'บัญชีลูกหนี้'));

    // Resolve payment GL account: per-type setup → CM (p.glAccountId) → cash default
    String paymentAcctCode(_PaymentRow p) {
      final type = p.paymentMethodType;
      int? setupId;
      String? setupCode;
      switch (type) {
        case 'CHECK':            setupId = setup.checkAccountId;           setupCode = setup.checkAccountCode; break;
        case 'TRANSFER':         setupId = setup.transferAccountId;        setupCode = setup.transferAccountCode; break;
        case 'CREDIT_CARD':      setupId = setup.creditCardAccountId;      setupCode = setup.creditCardAccountCode; break;
        case 'DEBIT_CARD':       setupId = setup.debitCardAccountId;       setupCode = setup.debitCardAccountCode; break;
        case 'QR_CODE':          setupId = setup.qrCodeAccountId;          setupCode = setup.qrCodeAccountCode; break;
        case 'MOBILE_BANKING':   setupId = setup.mobileBankingAccountId;   setupCode = setup.mobileBankingAccountCode; break;
        case 'BILL_OF_EXCHANGE': setupId = setup.billOfExchangeAccountId;  setupCode = setup.billOfExchangeAccountCode; break;
        default: break; // CASH / OTHER → fall through to CM or cash default
      }
      if (setupCode != null) return setupCode;
      if (setupId != null) {
        final c = acctCode(setupId, setup.cashAccountCode);
        return c.isEmpty ? (setup.cashAccountCode ?? '—') : c;
      }
      return acctCode(p.glAccountId, setup.cashAccountCode ?? '—');
    }

    String paymentAcctName(_PaymentRow p) {
      final type = p.paymentMethodType;
      int? setupId;
      String? setupName;
      switch (type) {
        case 'CHECK':            setupId = setup.checkAccountId;           setupName = setup.checkAccountName; break;
        case 'TRANSFER':         setupId = setup.transferAccountId;        setupName = setup.transferAccountName; break;
        case 'CREDIT_CARD':      setupId = setup.creditCardAccountId;      setupName = setup.creditCardAccountName; break;
        case 'DEBIT_CARD':       setupId = setup.debitCardAccountId;       setupName = setup.debitCardAccountName; break;
        case 'QR_CODE':          setupId = setup.qrCodeAccountId;          setupName = setup.qrCodeAccountName; break;
        case 'MOBILE_BANKING':   setupId = setup.mobileBankingAccountId;   setupName = setup.mobileBankingAccountName; break;
        case 'BILL_OF_EXCHANGE': setupId = setup.billOfExchangeAccountId;  setupName = setup.billOfExchangeAccountName; break;
        default: break;
      }
      if (setupId != null) {
        final n = acctName(setupId, setupName);
        return n.isEmpty ? (setup.cashAccountName ?? cashFallback) : n;
      }
      if (setupName != null && setupName.isNotEmpty) return setupName;
      return acctName(p.glAccountId, setup.cashAccountName ?? cashFallback);
    }

    // ── Invoice (10) / DN (30) / DN-with-bill (35) ────────────────────────
    if (sysType == arDocTypeInvoice || sysType == arDocTypeDebitNote || sysType == arDocTypeDebitNoteWithBill) {
      lines.add(_GlLine(arCode, arName, arDesc, _totalAmountFc * lc, 0, isFcDoc ? _totalAmountFc : 0, 0));
      for (final r in _detailRows) {
        final qty      = double.tryParse(r.qtyCtrl.text) ?? 0;
        final price    = double.tryParse(r.priceCtrl.text) ?? 0;
        final discPct  = double.tryParse(r.discPctCtrl.text) ?? 0;
        final sub      = qty * price;
        final disc     = sub * discPct / 100;
        final afterDisc = sub - disc;
        final vat      = afterDisc * r.vatRate / 100;
        final revCode  = acctCode(r.revenueAccountId, setup.revenueAccountCode);
        final revName  = acctName(r.revenueAccountId, setup.revenueAccountName);
        final desc     = r.itemNameCtrl.text.isNotEmpty ? r.itemNameCtrl.text : (r.descCtrl.text.isNotEmpty ? r.descCtrl.text : revenueDefaultDesc);
        final revenueFallback = isEnglish ? 'Revenue' : 'รายได้';
        if (setup.discountAccountId != null && disc > 0) {
          lines.add(_GlLine(revCode, revName.isEmpty ? revenueFallback : revName, desc, 0, sub * lc, 0, isFcDoc ? sub : 0));
          final discCode = setup.discountAccountCode ?? acctCode(setup.discountAccountId, notSetupDiscountLabel);
          final discName = acctName(setup.discountAccountId, setup.discountAccountName ?? discountPaidLabel);
          lines.add(_GlLine(discCode, discName.isEmpty ? discountPaidLabel : discName, discountPaidLabel, disc * lc, 0, isFcDoc ? disc : 0, 0));
        } else {
          lines.add(_GlLine(revCode, revName.isEmpty ? revenueFallback : revName, desc, 0, afterDisc * lc, 0, isFcDoc ? afterDisc : 0));
        }
        if (vat > 0) {
          final vatOutputFallback = isEnglish ? 'VAT Output' : 'ภาษีขาย';
          String vatAcctCode, vatAcctName;
          if (r.isDeferredVat) {
            vatAcctCode = setup.vatPendingOutputAccountCode ?? notSetupVatPendingLabel;
            vatAcctName = acctName(setup.vatPendingOutputAccountId, setup.vatPendingOutputAccountName ?? deferredVatLabel);
          } else {
            final vr = _vatRates.cast<VatRate?>().firstWhere((v) => v?.vatCode == r.vatType, orElse: () => null);
            if (vr?.glAccountCode != null && vr!.glAccountCode!.isNotEmpty) {
              vatAcctCode = vr.glAccountCode!;
              vatAcctName = acctName(vr.glAccountId, vr.glAccountName ?? setup.vatOutputAccountName ?? vatOutputFallback);
            } else if (setup.vatOutputAccountCode != null && setup.vatOutputAccountCode!.isNotEmpty) {
              vatAcctCode = setup.vatOutputAccountCode!;
              vatAcctName = acctName(setup.vatOutputAccountId, setup.vatOutputAccountName ?? vatOutputFallback);
            } else {
              vatAcctCode = notSetupVatLabel2;
              vatAcctName = vatOutputFallback;
            }
          }
          lines.add(_GlLine(vatAcctCode, vatAcctName, vatDesc2, 0, vat * lc, 0, isFcDoc ? vat : 0));
        }
      }
    }
    // ── Credit Note (50) ──────────────────────────────────────────────────
    else if (sysType == arDocTypeCreditNote) {
      lines.add(_GlLine(arCode, arName, arDesc, 0, _totalAmountFc * lc, 0, isFcDoc ? _totalAmountFc : 0));
      for (final r in _detailRows) {
        final qty      = double.tryParse(r.qtyCtrl.text) ?? 0;
        final price    = double.tryParse(r.priceCtrl.text) ?? 0;
        final discPct  = double.tryParse(r.discPctCtrl.text) ?? 0;
        final sub      = qty * price;
        final disc     = sub * discPct / 100;
        final afterDisc = sub - disc;
        final vat      = afterDisc * r.vatRate / 100;
        final revCode  = acctCode(r.revenueAccountId, setup.revenueAccountCode);
        final revName  = acctName(r.revenueAccountId, setup.revenueAccountName);
        final desc     = r.itemNameCtrl.text.isNotEmpty ? r.itemNameCtrl.text : (r.descCtrl.text.isNotEmpty ? r.descCtrl.text : revenueDefaultDesc);
        final revenueFallback = isEnglish ? 'Revenue' : 'รายได้';
        if (setup.discountAccountId != null && disc > 0) {
          lines.add(_GlLine(revCode, revName.isEmpty ? revenueFallback : revName, desc, sub * lc, 0, isFcDoc ? sub : 0, 0));
          final discCode = setup.discountAccountCode ?? acctCode(setup.discountAccountId, notSetupDiscountLabel);
          final discName = acctName(setup.discountAccountId, setup.discountAccountName ?? discountPaidLabel);
          lines.add(_GlLine(discCode, discName.isEmpty ? discountPaidLabel : discName, discountPaidLabel, 0, disc * lc, 0, isFcDoc ? disc : 0));
        } else {
          lines.add(_GlLine(revCode, revName.isEmpty ? revenueFallback : revName, desc, afterDisc * lc, 0, isFcDoc ? afterDisc : 0, 0));
        }
        if (vat > 0) {
          final vatOutputFallback = isEnglish ? 'VAT Output' : 'ภาษีขาย';
          String vatAcctCode, vatAcctName;
          if (r.isDeferredVat) {
            vatAcctCode = setup.vatPendingOutputAccountCode ?? notSetupVatPendingLabel;
            vatAcctName = acctName(setup.vatPendingOutputAccountId, setup.vatPendingOutputAccountName ?? deferredVatLabel);
          } else {
            final vr = _vatRates.cast<VatRate?>().firstWhere((v) => v?.vatCode == r.vatType, orElse: () => null);
            if (vr?.glAccountCode != null && vr!.glAccountCode!.isNotEmpty) {
              vatAcctCode = vr.glAccountCode!;
              vatAcctName = acctName(vr.glAccountId, vr.glAccountName ?? setup.vatOutputAccountName ?? vatOutputFallback);
            } else if (setup.vatOutputAccountCode != null && setup.vatOutputAccountCode!.isNotEmpty) {
              vatAcctCode = setup.vatOutputAccountCode!;
              vatAcctName = acctName(setup.vatOutputAccountId, setup.vatOutputAccountName ?? vatOutputFallback);
            } else {
              vatAcctCode = notSetupVatLabel2;
              vatAcctName = vatOutputFallback;
            }
          }
          lines.add(_GlLine(vatAcctCode, vatAcctName, vatDesc2, vat * lc, 0, isFcDoc ? vat : 0, 0));
        }
      }
    }
    // ── CN-with-bill (55) ────────────────────────────────────────────────
    else if (sysType == arDocTypeCreditNoteWithBill) {
      final revCode = setup.revenueAccountCode ?? '—';
      final revName = acctName(setup.revenueAccountId, setup.revenueAccountName ?? (isEnglish ? 'Revenue' : 'รายได้'));
      for (final a in _applyRows) {
        lines.add(_GlLine(revCode, revName, '$creditNoteDesc ${a.appliedToDocNo}', a.appliedAmountLc * lc, 0, isFcDoc ? a.appliedAmountLc : 0, 0));
      }
      lines.add(_GlLine(arCode, arName, arDesc, 0, _totalAmountFc * lc, 0, isFcDoc ? _totalAmountFc : 0));
    }
    // ── Advance Receipt (60) ────────────────────────────────────────────
    else if (sysType == arDocTypeAdvanceReceipt) {
      if (_paymentRows.isEmpty) {
        lines.add(_GlLine(setup.cashAccountCode ?? '—', acctName(setup.cashAccountId, setup.cashAccountName ?? cashFallback), advanceReceivedDesc2, _totalAmountFc * lc, 0, isFcDoc ? _totalAmountFc : 0, 0));
      } else {
        for (final p in _paymentRows) {
          final amt = double.tryParse(p.amountCtrl.text) ?? 0;
          lines.add(_GlLine(
            paymentAcctCode(p),
            paymentAcctName(p).isEmpty ? cashFallback : paymentAcctName(p),
            p.paymentMethodName ?? advanceReceivedDesc2,
            amt * lc, 0, isFcDoc ? amt : 0, 0,
          ));
        }
      }
      lines.add(_GlLine(setup.advanceAccountCode ?? '—', acctName(setup.advanceAccountId, setup.advanceAccountName ?? advanceFallback), advanceReceivedLabel2, 0, _beforeVatFc * lc, 0, isFcDoc ? _beforeVatFc : 0));
      if (_vatAmountFc > 0) {
        final vatOutputFallback2 = isEnglish ? 'VAT Output' : 'ภาษีขาย';
        final vatCode = setup.vatOutputAccountCode ?? notSetupVatLabel2;
        final vatName = acctName(setup.vatOutputAccountId, setup.vatOutputAccountName ?? vatOutputFallback2);
        lines.add(_GlLine(vatCode, vatName.isEmpty ? vatOutputFallback2 : vatName, vatDesc2, 0, _vatAmountFc * lc, 0, isFcDoc ? _vatAmountFc : 0));
      }
    }
    // ── Advance Refund (65) ──────────────────────────────────────────────
    else if (sysType == arDocTypeAdvanceRefund) {
      lines.add(_GlLine(setup.advanceAccountCode ?? '—', acctName(setup.advanceAccountId, setup.advanceAccountName ?? advanceFallback), advanceRefundDesc2, _totalAmountFc * lc, 0, isFcDoc ? _totalAmountFc : 0, 0));
      lines.add(_GlLine(setup.cashAccountCode ?? '—', acctName(setup.cashAccountId, setup.cashAccountName ?? cashFallback), payAdvanceRefundDesc2, 0, _totalAmountFc * lc, 0, isFcDoc ? _totalAmountFc : 0));
    }
    // ── Receipt (80) ────────────────────────────────────────────────────
    else if (sysType == arDocTypeReceipt) {
      final isFcReceipt = _selectedCurrency?.baseCurrencyFlag == false;
      final totalInvoiceApplied = _applyRows.fold(0.0, (s, a) => s + a.appliedAmountLc);
      final totalAdvanceDeducted = _advanceRows.fold(0.0, (s, a) => s + a.appliedAmountLc);
      final totalCnDeducted = _cnRows.fold(0.0, (s, a) => s + a.appliedAmountLc);
      final totalCashLc = _totalAmountFc * lc;

      // Build invoice rate map for FX calculation (keyed by invoice ID)
      final invRateMap = <int, double>{
        for (final inv in _openInvoices) if (inv.id != 0) inv.id: inv.exchangeRate,
      };

      // Compute AR credit at invoice exchange rate and receipt exchange rate (FC only)
      double totalInvAtInvRate = 0; // FC × invoiceRate → LC needed to zero-out AR
      double totalInvAtRecRate = 0; // FC × receiptRate → LC actually received
      double totalCnAtInvRate  = 0; // CN FC × looked-up rate
      if (isFcReceipt) {
        for (final a in _applyRows) {
          final invRate = invRateMap[a.appliedToId] ?? lc;
          totalInvAtInvRate += a.appliedAmountLc * invRate;
          totalInvAtRecRate += a.appliedAmountLc * lc;
        }
        for (final a in _cnRows) {
          totalCnAtInvRate += a.appliedAmountLc * (invRateMap[a.appliedToId] ?? lc);
        }
      }

      // DR: Cash/Bank per payment method (or single cash line)
      if (_paymentRows.isEmpty) {
        if (totalCashLc > 0.005) {
          lines.add(_GlLine(setup.cashAccountCode ?? '—', acctName(setup.cashAccountId, setup.cashAccountName ?? cashFallback), receivePaymentDesc2, totalCashLc, 0, isFcReceipt ? _totalAmountFc : 0, 0));
        }
      } else {
        for (final p in _paymentRows) {
          final amt = double.tryParse(p.amountCtrl.text) ?? 0;
          if (amt <= 0) continue;
          lines.add(_GlLine(
            paymentAcctCode(p),
            paymentAcctName(p).isEmpty ? cashFallback : paymentAcctName(p),
            p.paymentMethodName ?? receivePaymentDesc2,
            amt * lc, 0, isFcReceipt ? amt : 0, 0,
          ));
        }
      }

      // DR: เงินมัดจำรับ (ตัดมัดจำ)
      if (totalAdvanceDeducted > 0.005) {
        lines.add(_GlLine(
          setup.advanceAccountCode ?? '—', acctName(setup.advanceAccountId, setup.advanceAccountName ?? advanceFallback),
          advanceDeductDesc, totalAdvanceDeducted * lc, 0, isFcReceipt ? totalAdvanceDeducted : 0, 0,
        ));
      }

      // CR: ลูกหนี้การค้า — FC = applied FC, LC = at invoice rate
      final arCreditFc = isFcReceipt ? (totalInvoiceApplied - totalCnDeducted) : 0.0;
      final arCreditLc = isFcReceipt
          ? (totalInvAtInvRate > 0 ? totalInvAtInvRate - totalCnAtInvRate : totalCashLc)
          : (totalInvoiceApplied > 0 ? (totalInvoiceApplied - totalCnDeducted) * lc : totalCashLc);
      if (arCreditLc > 0.005) {
        lines.add(_GlLine(arCode, arName, settleDebtDesc2, 0, arCreditLc, 0, arCreditFc));
      }

      // FX Gain/Loss: difference between LC at receipt rate vs invoice rate (pure LC — no FC equivalent)
      if (isFcReceipt) {
        final fxNet = totalInvAtRecRate - totalInvAtInvRate;
        if (fxNet >= 0.005 && setup.fxGainAccountId != null) {
          lines.add(_GlLine(
            setup.fxGainAccountCode ?? acctCode(setup.fxGainAccountId, '—'),
            acctName(setup.fxGainAccountId, setup.fxGainAccountName ?? fxGainName),
            fxGainDesc,
            0, fxNet,
          ));
        } else if (fxNet <= -0.005 && setup.fxLossAccountId != null) {
          lines.add(_GlLine(
            setup.fxLossAccountCode ?? acctCode(setup.fxLossAccountId, '—'),
            acctName(setup.fxLossAccountId, setup.fxLossAccountName ?? fxLossName),
            fxLossDesc,
            fxNet.abs(), 0,
          ));
        }
      }

      // DR: ภาษีขายรอตัดบัญชี / CR: ภาษีขาย (รับรู้ VAT รอตัดบัญชีตามสัดส่วนที่ชำระ)
      if (deferredVatLc > 0.005 && setup.vatPendingOutputAccountId != null && setup.vatOutputAccountId != null) {
        lines.add(_GlLine(
          setup.vatPendingOutputAccountCode ?? acctCode(setup.vatPendingOutputAccountId, '—'),
          acctName(setup.vatPendingOutputAccountId, setup.vatPendingOutputAccountName ?? deferredVatRecognizedName),
          deferredVatRecognizeDesc, deferredVatLc, 0,
        ));
        lines.add(_GlLine(
          setup.vatOutputAccountCode ?? acctCode(setup.vatOutputAccountId, '—'),
          acctName(setup.vatOutputAccountId, setup.vatOutputAccountName ?? (isEnglish ? 'VAT Output' : 'ภาษีขาย')),
          deferredVatRecognizedDesc, 0, deferredVatLc,
        ));
      }
    }

    return lines;
  }
}

// ---- Helper: editable detail row state ----
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
  int? revenueAccountId;
  bool isDeferredVat;

  _DetailRow({
    String? itemCode,
    String? itemName,
    String? desc,
    double qty = 1,
    double price = 0,
    double discPct = 0,
    this.vatType = '',
    this.vatRate = 0.0,
    this.revenueAccountId,
    this.isDeferredVat = false,
    double totalFc = 0,
  })  : itemCodeCtrl = TextEditingController(text: itemCode ?? ''),
        itemNameCtrl = TextEditingController(text: itemName ?? ''),
        descCtrl = TextEditingController(text: desc ?? ''),
        qtyCtrl = TextEditingController(text: qty.toString()),
        priceCtrl = TextEditingController(text: price.toStringAsFixed(2)),
        discPctCtrl = TextEditingController(text: discPct.toStringAsFixed(2)),
        totalCtrl = TextEditingController(text: totalFc.toStringAsFixed(2));

  factory _DetailRow.fromModel(ArTransactionDetail d) {
    return _DetailRow(
      itemCode: d.itemCode,
      itemName: d.itemName,
      desc: d.description,
      qty: d.quantity,
      price: d.unitPriceFc,
      discPct: d.discountPercent,
      vatType: d.vatType,
      vatRate: d.vatRate,
      revenueAccountId: d.revenueAccountId,
      isDeferredVat: d.isDeferredVat,
      totalFc: d.totalAmountFc,
    );
  }

  void dispose() {
    itemCodeCtrl.dispose();
    itemNameCtrl.dispose();
    descCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
    discPctCtrl.dispose();
    totalCtrl.dispose();
  }
}

// ---- Helper: apply row state ----
class _ApplyRow {
  final int appliedToId;
  final String appliedToDocNo;
  final DateTime? appliedToDocDate;
  final double appliedToTotal;
  final double? appliedToTotalFc;
  final double? appliedToExchangeRate;
  final DateTime? appliedToDueDate;
  final DateTime? appliedToExpectedPaymentDate;
  double appliedAmountLc;

  _ApplyRow({
    required this.appliedToId,
    required this.appliedToDocNo,
    this.appliedToDocDate,
    this.appliedToTotal = 0,
    this.appliedToTotalFc,
    this.appliedToExchangeRate,
    this.appliedToDueDate,
    this.appliedToExpectedPaymentDate,
    this.appliedAmountLc = 0,
  });
}

// ---- Helper: payment row state ----
class _PaymentRow {
  final int? paymentMethodId;
  final String? paymentMethodCode;
  final String? paymentMethodName;
  final String paymentMethodType;
  final int? cmBankAccountId;
  final int? glAccountId;
  // ── controllers (common) ──
  final TextEditingController amountCtrl;
  final TextEditingController refNoCtrl;
  final TextEditingController remarkCtrl;
  DateTime? paymentDate;
  // ── CHECK / TRANSFER / BILL_OF_EXCHANGE ──
  final TextEditingController drawerBankNameCtrl;
  final TextEditingController drawerBankBranchCtrl;
  final TextEditingController drawerAccountNoCtrl;
  // ── CREDIT_CARD / DEBIT_CARD ──
  String? cardType;
  final TextEditingController cardLast4Ctrl;
  final TextEditingController approvalCodeCtrl;
  final TextEditingController terminalIdCtrl;
  final TextEditingController batchNoCtrl;

  _PaymentRow({
    this.paymentMethodId,
    this.paymentMethodCode,
    this.paymentMethodName,
    this.paymentMethodType = 'CASH',
    this.cmBankAccountId,
    this.glAccountId,
    double amount = 0,
    String? refNo,
    String? remark,
    this.paymentDate,
    String? drawerBankName,
    String? drawerBankBranch,
    String? drawerAccountNo,
    this.cardType,
    String? cardLast4,
    String? approvalCode,
    String? terminalId,
    String? batchNo,
  })  : amountCtrl = TextEditingController(text: amount > 0 ? amount.toStringAsFixed(2) : ''),
        refNoCtrl = TextEditingController(text: refNo ?? ''),
        remarkCtrl = TextEditingController(text: remark ?? ''),
        drawerBankNameCtrl = TextEditingController(text: drawerBankName ?? ''),
        drawerBankBranchCtrl = TextEditingController(text: drawerBankBranch ?? ''),
        drawerAccountNoCtrl = TextEditingController(text: drawerAccountNo ?? ''),
        cardLast4Ctrl = TextEditingController(text: cardLast4 ?? ''),
        approvalCodeCtrl = TextEditingController(text: approvalCode ?? ''),
        terminalIdCtrl = TextEditingController(text: terminalId ?? ''),
        batchNoCtrl = TextEditingController(text: batchNo ?? '');

  factory _PaymentRow.fromModel(ArTransactionPayment p, [bool isFc = false]) {
    return _PaymentRow(
      paymentMethodId: p.paymentMethodId,
      paymentMethodCode: p.paymentMethodCode,
      paymentMethodName: p.paymentMethodName,
      paymentMethodType: p.paymentMethodType,
      cmBankAccountId: p.cmBankAccountId,
      glAccountId: p.glAccountId,
      amount: isFc && p.amountFc > 0 ? p.amountFc : p.amountLc,
      refNo: p.refNo,
      remark: p.remark,
      paymentDate: p.paymentDate,
      drawerBankName: p.drawerBankName,
      drawerBankBranch: p.drawerBankBranch,
      drawerAccountNo: p.drawerAccountNo,
      cardType: p.cardType,
      cardLast4: p.cardLast4,
      approvalCode: p.approvalCode,
      terminalId: p.terminalId,
      batchNo: p.batchNo,
    );
  }

  void dispose() {
    amountCtrl.dispose();
    refNoCtrl.dispose();
    remarkCtrl.dispose();
    drawerBankNameCtrl.dispose();
    drawerBankBranchCtrl.dispose();
    drawerAccountNoCtrl.dispose();
    cardLast4Ctrl.dispose();
    approvalCodeCtrl.dispose();
    terminalIdCtrl.dispose();
    batchNoCtrl.dispose();
  }
}

// ---- Helper: GL preview line ----
class _GlLine {
  final String accountCode;
  final String accountName;
  final String description;
  final double debit;    // LC amount
  final double credit;   // LC amount
  final double debitFc;  // FC amount (0 for base-currency docs)
  final double creditFc; // FC amount

  const _GlLine(this.accountCode, this.accountName, this.description, this.debit, this.credit, [this.debitFc = 0, this.creditFc = 0]);
}

// ---- Helper: editable GL row for inline section ----
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

  factory _GlEditRow.fromDetail(GlEntryDetail d) => _GlEditRow(
        accountCode: d.accountCode,
        accountName: d.accountName,
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
