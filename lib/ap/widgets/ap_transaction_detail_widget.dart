import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/ap_transaction.dart';
import '../models/ap_vendor.dart';
import '../models/ap_gl_account_setup.dart';
import '../services/ap_transaction_service.dart';
import '../services/ap_vendor_service.dart';
import '../../gl/models/account.dart';
import '../../gl/services/account_service.dart';
import '../../cd/models/currency.dart';
import '../../cd/services/currency_service.dart';
import '../../sa/models/module_document.dart';
import '../../sa/models/user_branch.dart';
import '../../sa/services/auth_service.dart';
import '../../gl/models/period.dart';
import '../../gl/services/period_service.dart';
import '../../cd/models/vat_rate.dart';
import '../../cd/services/vat_rate_service.dart';
import '../../gl/models/gl_dimension.dart';
import '../../gl/services/gl_dimension_service.dart';
import '../../gl/widgets/gl_dimension_picker_field.dart';
import '../../cm/models/cm_payment_method.dart';
import '../../cm/widgets/cm_payment_method_list_widget.dart';
import '../../gl/services/gl_entry_service.dart';
import '../../gl/models/gl_entry.dart' show GlEntryHeader, GlEntryDetail;
import '../../cd/models/cd_wht_type.dart';
import '../../cd/services/cd_wht_type_service.dart';

class ApTransactionDetailWidget extends StatefulWidget {
  final int? transactionId;
  final bool viewOnly;
  final int resetKey;
  final VoidCallback onSaveSuccess;
  final VoidCallback onCancel;

  const ApTransactionDetailWidget({
    super.key,
    this.transactionId,
    this.viewOnly = false,
    this.resetKey = 0,
    required this.onSaveSuccess,
    required this.onCancel,
  });

  @override
  State<ApTransactionDetailWidget> createState() => _ApTransactionDetailWidgetState();
}

class _ApTransactionDetailWidgetState extends State<ApTransactionDetailWidget> {
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

  bool _isLoading = false;

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

  // Header values
  int _transactionId = 0;
  int? _glEntryId;
  String _docNo = 'AUTO';
  DateTime _docDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime? _dueDate;
  int? _apAccountId;
  double _exchangeRate = 1.0;
  final _refNoCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _status = 'Draft';

  // Detail rows (for PI, CN, DN)
  List<_DetailRow> _detailRows = [];

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

  // Totals
  double _subtotalFc = 0;
  double _discountAmountFc = 0;
  double _beforeVatFc = 0;
  double _vatAmountFc = 0;
  double _totalAmountFc = 0;

  final _fmt = NumberFormat('#,##0.00');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  bool get _isPurchaseInvoice => _selectedDocType?.sysDocType == apDocTypePurchaseInvoice.toString();
  bool get _isCreditNote      => _selectedDocType?.sysDocType == apDocTypeCreditNote.toString();
  bool get _isDebitNote       => _selectedDocType?.sysDocType == apDocTypeDebitNote.toString();
  bool get _isAdvancePayment  => _selectedDocType?.sysDocType == apDocTypeAdvancePayment.toString();
  bool get _isAdvanceRefund   => _selectedDocType?.sysDocType == apDocTypeAdvanceRefund.toString();
  bool get _isRA              => _selectedDocType?.sysDocType == apDocTypeRemittanceAdvice.toString();
  bool get _isPayment         => _selectedDocType?.sysDocType == apDocTypePayment.toString();

  bool get _hasDetailRows     => _isPurchaseInvoice || _isCreditNote || _isDebitNote;
  bool get _hasApplySection   => _isPayment || _isRA;
  bool get _hasAdvanceRefund  => _isAdvanceRefund;
  bool get _hasWhtSection     => _isPayment || _isAdvancePayment;
  bool get _hasPaymentRows    => _isPayment || _isAdvancePayment || _isAdvanceRefund;
  bool get _hasDueDate        => _isPurchaseInvoice;

  bool _headerExpanded  = true;
  bool _detailExpanded  = true;
  bool _applyExpanded   = true;
  bool _advanceExpanded = true;
  bool _whtExpanded     = true;
  bool _paymentExpanded = true;

  @override
  void initState() {
    super.initState();
    _initMasterData();
  }

  @override
  void dispose() {
    _refNoCtrl.dispose();
    _descCtrl.dispose();
    for (final r in _detailRows) r.dispose();
    for (final c in _applyCtrlMap.values) c.dispose();
    for (final c in _advanceCtrlMap.values) c.dispose();
    for (final c in _advanceRefundCtrlMap.values) c.dispose();
    for (final r in _paymentRows) r.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ApTransactionDetailWidget old) {
    super.didUpdateWidget(old);
    if (widget.transactionId != old.transactionId ||
        widget.viewOnly != old.viewOnly ||
        widget.resetKey != old.resetKey) {
      _loadTransactionData();
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
      ]);
      _allowedDocTypes = results[0] as List<ModuleDocument>;
      _vendors = results[1] as List<ApVendor>;
      _accounts = results[2] as List<Account>;
      _currencies = results[3] as List<Currency>;
      _openPeriods = results[4] as List<PostingPeriod>;
      _vatRates = (results[5] as List<VatRate>).where((v) => v.isActive).toList();
      _dimTypes = results[6] as List<GlDimensionType>;
      _whtTypes = results[7] as List<CdWhtType>;

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
    }
  }

  Future<void> _loadDocSetup() async {
    if (_selectedDocType == null) return;
    try {
      final setup = await _service.fetchSetupByDocCode(_selectedDocType!.docCode);
      if (mounted) setState(() => _docSetup = setup);
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
        _descCtrl.text = h.description ?? '';
        _status = h.status;
        _isReadOnly = widget.viewOnly || h.status != 'Draft';

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
            .where((a) => a.applyType == 'advance')
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

      if (_hasApplySection && _selectedVendor?.id != null) {
        await _loadOpenInvoicesKeepApplied(_selectedVendor!.id!);
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
      _refNoCtrl.clear(); _descCtrl.clear();
      _status = 'Draft'; _isReadOnly = false;
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
    } else if (_isAdvancePayment) {
      subFc = _paymentRows.fold(0.0, (s, r) => s + (double.tryParse(r.amountCtrl.text) ?? 0));
    } else {
      for (final r in _detailRows) {
        final qty = double.tryParse(r.qtyCtrl.text) ?? 0;
        final price = double.tryParse(r.priceCtrl.text) ?? 0;
        final discPct = double.tryParse(r.discPctCtrl.text) ?? 0;
        final sub = qty * price;
        final disc = sub * discPct / 100;
        final afterDisc = sub - disc;
        final vat = r.vatType == 'NOVAT' ? 0.0 : afterDisc * r.vatRate / 100;
        subFc += sub; discFc += disc; vatFc += vat;
      }
    }
    final beforeVat = subFc - discFc;
    setState(() {
      _subtotalFc = subFc; _discountAmountFc = discFc;
      _beforeVatFc = beforeVat; _vatAmountFc = vatFc;
      _totalAmountFc = beforeVat + vatFc;
    });
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
      final adv = await _service.fetchOpenAdvances(vendorId);
      for (final c in _advanceCtrlMap.values) c.dispose(); _advanceCtrlMap.clear();
      if (mounted) setState(() { _openAdvances = adv; _advanceRows = []; });
    } catch (_) {}
  }

  Future<void> _loadOpenAdvancesKeepApplied(int vendorId) async {
    try {
      final adv = await _service.fetchOpenAdvances(vendorId);
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

  void _onVendorChanged(ApVendor? vendor) {
    setState(() {
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
      if (vendor != null && (vendor.creditTermMonths > 0 || vendor.creditTermDays > 0)) {
        var base = _docDate;
        if (vendor.creditTermMonths > 0) {
          base = DateTime(base.year, base.month + vendor.creditTermMonths, base.day);
        }
        if (vendor.creditTermDays > 0) base = base.add(Duration(days: vendor.creditTermDays));
        _dueDate = base;
      }
    });
    if (_hasApplySection && vendor != null) {
      _loadOpenInvoices(vendor.id!);
      _loadOpenAdvances(vendor.id!);
    }
    if (_hasAdvanceRefund && vendor != null) {
      _loadOpenAdvancesForRefund(vendor.id!);
    }
  }

  Future<ApVendor?> _showVendorPicker() async {
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
                  v.vendorNameTh.toUpperCase().contains(q)).toList());
        }
        return Dialog(
          child: SizedBox(
            width: 600, height: 500,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: searchCtrl,
                  decoration: const InputDecoration(labelText: 'ค้นหาเจ้าหนี้', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
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
                    title: Text('${v.vendorCode} - ${v.vendorNameTh}', style: const TextStyle(fontSize: 13)),
                    subtitle: v.taxId != null ? Text(v.taxId!, style: const TextStyle(fontSize: 11)) : null,
                    onTap: () => Navigator.pop(ctx, v),
                  );
                },
              )),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
            ]),
          ),
        );
      }),
    );
  }

  Future<void> _showBranchDialog() async {
    final branches = _authService.allowedBranches;
    if (branches.isEmpty) return;
    final selected = await showDialog<UserBranch>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('เลือกสาขา'),
        content: SizedBox(
          width: 300, height: 300,
          child: ListView(children: [
            ListTile(
              title: const Text('— ไม่ระบุสาขา —'),
              onTap: () => Navigator.pop(ctx),
            ),
            ...branches.map((b) => ListTile(
              title: Text('${b.branchCode}  ${b.branchNameThai}'),
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
      else { _docDate = picked; }
    });
  }

  Future<void> _save(String action) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDocType == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาเลือกประเภทเอกสาร')));
      return;
    }
    if (_selectedVendor == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาเลือกเจ้าหนี้')));
      return;
    }
    if (action == 'Post' && !_isRA && !_validatePeriod(_docDate)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('วันที่เอกสารไม่อยู่ในงวดบัญชีที่เปิด')));
      return;
    }

    _recalcTotals();
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
      dim1Id: _dimSelections[1], dim2Id: _dimSelections[2],
      dim3Id: _dimSelections[3], dim4Id: _dimSelections[4], dim5Id: _dimSelections[5],
      branchId: _selectedBranch?.branchId,
      createdBy: _transactionId == 0 ? userName : null,
      updatedBy: _transactionId != 0 ? userName : null,
    );

    final details = _detailRows.asMap().entries.map((e) {
      final i = e.key; final r = e.value;
      final qty = double.tryParse(r.qtyCtrl.text) ?? 0;
      final price = double.tryParse(r.priceCtrl.text) ?? 0;
      final discPct = double.tryParse(r.discPctCtrl.text) ?? 0;
      final sub = qty * price;
      final disc = sub * discPct / 100;
      final afterDisc = sub - disc;
      final vat = r.vatType == 'NOVAT' ? 0.0 : afterDisc * r.vatRate / 100;
      final itemName = r.itemNameCtrl.text.isEmpty ? null : r.itemNameCtrl.text;
      return ApTransactionDetail(
        lineNo: i + 1,
        itemCode: r.itemCodeCtrl.text.isEmpty ? null : r.itemCodeCtrl.text,
        itemName: itemName,
        description: itemName,
        quantity: qty, unitPriceFc: price,
        discountPercent: discPct, discountAmountFc: disc,
        subtotalFc: afterDisc, vatType: r.vatType, vatRate: r.vatRate,
        vatAmountFc: vat, totalAmountFc: afterDisc + vat,
        expenseAccountId: r.expenseAccountId ?? _docSetup?.expenseAccountId,
        subtotalLc: afterDisc * lc, vatAmountLc: vat * lc,
        totalAmountLc: (afterDisc + vat) * lc,
        isDeferredVat: r.isDeferredVat && r.vatType != 'NOVAT',
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
            applyType: 'advance',
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
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(action == 'Post' ? 'บันทึกและ Post เรียบร้อย' : 'บันทึก Draft เรียบร้อย'),
        ));
        widget.onSaveSuccess();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('บันทึกไม่สำเร็จ: ${e.toString().replaceFirst('Exception: ', '')}'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _void() async {
    final reasonCtrl = TextEditingController();
    final voidReason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String? errorText;
        return StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: Row(children: [Icon(Icons.cancel_outlined, color: Colors.red[700], size: 20), const SizedBox(width: 8), const Text('ยืนยันการยกเลิกเอกสาร')]),
            content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red[200]!)),
                child: const Text('เอกสารที่ยกเลิกแล้วไม่สามารถกู้คืนได้\nระบบจะสร้าง Reversing GL Entry เพื่อยกเลิกผลกระทบทางบัญชี', style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonCtrl, maxLines: 2, autofocus: true,
                decoration: InputDecoration(labelText: 'เหตุผลการยกเลิก *', hintText: 'เช่น ยอดเงินผิด', border: const OutlineInputBorder(), errorText: errorText),
              ),
            ])),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ปิด')),
              ElevatedButton.icon(
                onPressed: () {
                  if (reasonCtrl.text.trim().isEmpty) { setD(() => errorText = 'กรุณาระบุเหตุผล'); return; }
                  Navigator.pop(ctx, reasonCtrl.text.trim());
                },
                icon: const Icon(Icons.check, size: 16),
                label: const Text('ยืนยัน Void'),
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
      await _service.voidTransaction(_transactionId);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ยกเลิกเอกสารเรียบร้อย'))); widget.onSaveSuccess(); }
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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
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
            if (_hasApplySection && _isPayment) ...[const SizedBox(height: 8), _buildAdvanceSection()],
            if (_hasAdvanceRefund) ...[const SizedBox(height: 8), _buildAdvanceRefundSection()],
            if (_hasWhtSection) ...[const SizedBox(height: 8), _buildWhtSection()],
            if (_hasPaymentRows) ...[const SizedBox(height: 8), _buildPaymentSection()],
            const SizedBox(height: 8),
            _buildTotalsRow(),
          ]),
        )),
      ]),
    );
  }

  Widget _buildActionButtons() {
    final isDraft = _status == 'Draft';
    final isPosted = _status == 'Posted';
    return Container(
      color: Colors.blue[50],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        if (!_isReadOnly && isDraft) ...[
          ElevatedButton.icon(
            onPressed: () => _save('Draft'),
            icon: const Icon(Icons.save_outlined, size: 16),
            label: const Text('บันทึก Draft'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700], foregroundColor: Colors.white),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _save('Post'),
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('Post เอกสาร'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
          ),
          const SizedBox(width: 8),
          if (_transactionId != 0)
            OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('ลบ Draft'),
                    content: const Text('ต้องการลบเอกสาร Draft นี้?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
                      ElevatedButton(onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('ลบ')),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _service.deleteTransaction(_transactionId);
                  if (mounted) widget.onSaveSuccess();
                }
              },
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('ลบ'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            ),
        ],
        if (isPosted)
          ElevatedButton.icon(
            onPressed: _void,
            icon: const Icon(Icons.cancel_outlined, size: 16),
            label: const Text('ยกเลิก (Void)'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
          ),
        const Spacer(),
        if (_selectedVendor != null && _selectedDocType != null) ...[
          OutlinedButton.icon(
            onPressed: _showGlEntryDialog,
            icon: const Icon(Icons.account_balance_outlined, size: 16),
            label: Text(isPosted ? 'GL Entry' : 'ตัวอย่าง GL'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.indigo[700]),
          ),
          const SizedBox(width: 8),
        ],
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('กลับ'),
        ),
      ]),
    );
  }

  Widget _buildHeaderSection() {
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Row 0: Icon + Title + Expand + DocType + DocNo + DocDate + RefNo + Status badge
        Row(children: [
          const Icon(Icons.article_outlined, size: 18),
          const SizedBox(width: 6),
          Text('ข้อมูลหัวเอกสาร', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(_headerExpanded ? Icons.expand_less : Icons.expand_more, size: 18),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            onPressed: () => setState(() => _headerExpanded = !_headerExpanded),
          ),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: DropdownButtonFormField<ModuleDocument>(
            value: _selectedDocType,
            isExpanded: true,
            decoration: _fieldDeco('ประเภทเอกสาร *'),
            items: _allowedDocTypes.map((d) => DropdownMenuItem(
              value: d,
              child: Text('${d.docCode} ${d.docNameThai}', overflow: TextOverflow.ellipsis),
            )).toList(),
            onChanged: _isReadOnly ? null : (v) {
              setState(() => _selectedDocType = v);
              _resetForm();
              _loadDocSetup();
            },
            validator: (v) => v == null ? 'กรุณาเลือก' : null,
          )),
          const SizedBox(width: 8),
          Expanded(flex: 1, child: TextFormField(
            key: ValueKey('ap_docNo_${widget.resetKey}_$_transactionId'),
            initialValue: _docNo == 'AUTO' ? '' : _docNo,
            decoration: _fieldDeco(
              _selectedDocType?.isAutoNumbering == true ? 'เลขที่อัตโนมัติ' : 'เลขที่เอกสาร',
              forcedReadOnly: _selectedDocType?.isAutoNumbering == true,
            ).copyWith(hintText: _selectedDocType?.isAutoNumbering == true ? '(ระบบกำหนดให้อัตโนมัติ)' : 'ระบุเลขที่'),
            readOnly: _isReadOnly || (_selectedDocType?.isAutoNumbering == true),
            onChanged: (v) => _docNo = v.isEmpty ? 'AUTO' : v,
          )),
          const SizedBox(width: 8),
          Expanded(flex: 1, child: InkWell(
            onTap: _isReadOnly ? null : () => _selectDate(false),
            child: InputDecorator(
              decoration: _fieldDeco('วันที่เอกสาร *'),
              child: Row(children: [
                Expanded(child: Text(_dateFmt.format(_docDate))),
                if (!_isReadOnly) const Icon(Icons.calendar_today, size: 14),
              ]),
            ),
          )),
          const SizedBox(width: 8),
          Expanded(flex: 1, child: TextFormField(
            controller: _refNoCtrl,
            decoration: _fieldDeco('เลขที่อ้างอิง'),
            readOnly: _isReadOnly,
          )),
          if (_status != 'Draft') ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _status == 'Posted' ? Colors.green[50] : Colors.red[50],
                border: Border.all(color: _status == 'Posted' ? Colors.green : Colors.red),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_status, style: TextStyle(color: _status == 'Posted' ? Colors.green[800] : Colors.red[800], fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
        if (_headerExpanded) ...[
          const SizedBox(height: 12),
          // Row 1: Branch + Dims
          Row(children: [
            Expanded(flex: 1, child: InkWell(
              onTap: _isReadOnly ? null : _showBranchDialog,
              child: InputDecorator(
                decoration: _fieldDeco('สาขา').copyWith(suffixIcon: _isReadOnly ? null : const Icon(Icons.search, size: 16)),
                child: Text(
                  _selectedBranch != null ? '${_selectedBranch!.branchCode}  ${_selectedBranch!.branchNameThai}' : '— ไม่ระบุสาขา —',
                  style: TextStyle(color: _selectedBranch == null ? Colors.grey[500] : null, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )),
            ..._dimTypes.expand((t) {
              final vals = _dimValues[t.typeCode] ?? [];
              final selId = _dimSelections[t.slotNo];
              final selVal = vals.cast<GlDimensionValue?>().firstWhere((v) => v?.id == selId, orElse: () => null);
              return [
                const SizedBox(width: 8),
                Expanded(flex: 1, child: GlDimensionPickerField(
                  dimType: t, values: vals, selected: selVal, readOnly: _isReadOnly, isDense: false,
                  onSelected: (val) => setState(() { _dimSelections[t.slotNo] = val?.id; _dimNames[t.slotNo] = val?.valueNameThai; }),
                )),
              ];
            }),
          ]),
          const SizedBox(height: 12),
          // Row 2: Vendor | Currency | ExchangeRate | Description
          Row(children: [
            Expanded(flex: 3, child: InkWell(
              onTap: _isReadOnly ? null : () async {
                final v = await _showVendorPicker();
                if (v != null) _onVendorChanged(v);
              },
              child: InputDecorator(
                decoration: _fieldDeco('เจ้าหนี้ *').copyWith(suffixIcon: _isReadOnly ? null : const Icon(Icons.search, size: 16)),
                child: Text(
                  _selectedVendor != null
                      ? '${_selectedVendor!.vendorCode} - ${_selectedVendor!.vendorNameTh}'
                      : 'คลิกเพื่อเลือกเจ้าหนี้',
                  style: TextStyle(color: _selectedVendor == null ? Colors.grey : null),
                ),
              ),
            )),
            const SizedBox(width: 8),
            Expanded(flex: 1, child: DropdownButtonFormField<Currency>(
              value: _selectedCurrency,
              isExpanded: true,
              decoration: _fieldDeco('สกุลเงิน'),
              items: _currencies.map((c) => DropdownMenuItem(
                value: c,
                child: Text('${c.currencyCode} - ${c.currencyNameThai}', overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: _isReadOnly ? null : (v) => setState(() { _selectedCurrency = v; _exchangeRate = v?.baseRate ?? 1.0; }),
            )),
            const SizedBox(width: 8),
            Expanded(flex: 1, child: TextFormField(
              key: ValueKey('ap_rate_${widget.resetKey}_$_transactionId'),
              initialValue: _exchangeRate.toStringAsFixed(6),
              decoration: _fieldDeco('อัตราแลกเปลี่ยน'),
              keyboardType: TextInputType.number,
              readOnly: _isReadOnly,
              onChanged: (v) => setState(() => _exchangeRate = double.tryParse(v) ?? 1.0),
            )),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: TextFormField(
              controller: _descCtrl,
              decoration: _fieldDeco('คำอธิบาย'),
              readOnly: _isReadOnly,
            )),
          ]),
          if (_hasDueDate) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(flex: 1, child: InkWell(
                onTap: _isReadOnly ? null : () => _selectDate(true),
                child: InputDecorator(
                  decoration: _fieldDeco('วันครบกำหนด'),
                  child: Row(children: [
                    Expanded(child: Text(_dueDate != null ? _dateFmt.format(_dueDate!) : '— ไม่กำหนด —',
                        style: TextStyle(color: _dueDate == null ? Colors.grey : null))),
                    if (!_isReadOnly) const Icon(Icons.calendar_today, size: 14),
                  ]),
                ),
              )),
              const Expanded(flex: 3, child: SizedBox()),
            ]),
          ],
        ],
      ]),
    ));
  }

  // ── Detail Section (PI / CN / DN) ──────────────────────────────────────────
  void _onDetailFieldChanged(_DetailRow r) {
    final qty     = double.tryParse(r.qtyCtrl.text)     ?? 0;
    final price   = double.tryParse(r.priceCtrl.text)   ?? 0;
    final discPct = double.tryParse(r.discPctCtrl.text)  ?? 0;
    final afterDisc = qty * price * (1 - discPct / 100);
    final vat = r.vatType == 'NOVAT' ? 0.0 : afterDisc * r.vatRate / 100;
    r.totalCtrl.text = (afterDisc + vat).toStringAsFixed(2);
    _recalcTotals();
  }

  void _onTotalChanged(_DetailRow r, String value) {
    final total   = double.tryParse(value)              ?? 0;
    final qty     = double.tryParse(r.qtyCtrl.text)     ?? 0;
    final discPct = double.tryParse(r.discPctCtrl.text)  ?? 0;
    final netFactor = 1 + (r.vatType == 'NOVAT' ? 0.0 : r.vatRate / 100);
    final afterDisc  = total / netFactor;
    final qtyFactor  = qty * (1 - discPct / 100);
    r.priceCtrl.text = qtyFactor != 0 ? (afterDisc / qtyFactor).toStringAsFixed(4) : '0.0000';
    _recalcTotals();
  }

  void _removeDetailRow(int i) {
    setState(() { _detailRows[i].dispose(); _detailRows.removeAt(i); });
    _recalcTotals();
  }

  Widget _buildDetailSection() {
    final inputBorder = _isReadOnly
        ? InputBorder.none
        : const UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue, width: 1));
    const focusBorder = UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue, width: 2));

    return Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader('รายละเอียดสินค้า/บริการ', _detailExpanded, () => setState(() => _detailExpanded = !_detailExpanded),
          icon: Icons.list_alt,
          trailing: _isReadOnly ? null : TextButton.icon(
            onPressed: () {
              final defaultVat = _vatRates.isNotEmpty ? _vatRates.first : null;
              setState(() => _detailRows.add(_DetailRow(
                vatType: defaultVat?.vatCode ?? 'VAT7',
                vatRate: defaultVat?.rate ?? 7.0,
                expenseAccountId: _docSetup?.expenseAccountId,
              )));
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('เพิ่มรายการ'),
          ),
        ),
        if (_detailExpanded) ...[
          const SizedBox(height: 8),
          if (_detailRows.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('ยังไม่มีรายการ กดปุ่ม "เพิ่มรายการ" เพื่อเพิ่ม'),
            ))
          else
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    columnSpacing: 8, dataRowMinHeight: 36, dataRowMaxHeight: 52,
                    headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
                    columns: [
                      const DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('รหัสสินค้า', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('ชื่อสินค้า/บริการ', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('จำนวน', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      const DataColumn(label: Text('ราคา/หน่วย', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      const DataColumn(label: Text('ส่วนลด%', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      const DataColumn(label: Text('ยอดสุทธิ', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      const DataColumn(label: Text('VAT', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('ยอด VAT', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      const DataColumn(label: Text('รวม', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), numeric: true),
                      const DataColumn(label: Tooltip(message: 'VAT บันทึกตอนรับชำระ ไม่ใช่ตอนตั้งหนี้', child: Text('VAT\nรอตัด', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center))),
                      if (!_isReadOnly) const DataColumn(label: SizedBox()),
                    ],
                    rows: _detailRows.asMap().entries.map((e) {
                      final i = e.key; final r = e.value;
                      final qty     = double.tryParse(r.qtyCtrl.text)    ?? 0;
                      final price   = double.tryParse(r.priceCtrl.text)  ?? 0;
                      final discPct = double.tryParse(r.discPctCtrl.text) ?? 0;
                      final afterDisc = qty * price * (1 - discPct / 100);
                      final vat = r.vatType == 'NOVAT' ? 0.0 : afterDisc * r.vatRate / 100;
                      return DataRow(cells: [
                        DataCell(Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                        DataCell(SizedBox(width: 90, child: TextFormField(
                          controller: r.itemCodeCtrl,
                          decoration: InputDecoration(
                            isDense: true, border: inputBorder, enabledBorder: inputBorder,
                            focusedBorder: focusBorder, filled: !_isReadOnly, fillColor: Colors.white,
                          ),
                          style: const TextStyle(fontSize: 12),
                          readOnly: _isReadOnly,
                        ))),
                        DataCell(SizedBox(width: 180, child: TextFormField(
                          controller: r.itemNameCtrl,
                          decoration: InputDecoration(
                            isDense: true, border: inputBorder, enabledBorder: inputBorder,
                            focusedBorder: focusBorder, filled: !_isReadOnly, fillColor: Colors.white,
                            hintText: _isReadOnly ? null : 'ระบุรายการ',
                          ),
                          style: const TextStyle(fontSize: 12),
                          readOnly: _isReadOnly,
                        ))),
                        DataCell(SizedBox(width: 70, child: TextFormField(
                          controller: r.qtyCtrl,
                          decoration: InputDecoration(
                            isDense: true, border: inputBorder, enabledBorder: inputBorder, focusedBorder: focusBorder,
                            filled: !_isReadOnly, fillColor: Colors.white,
                          ),
                          style: const TextStyle(fontSize: 12),
                          keyboardType: TextInputType.number, textAlign: TextAlign.right,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                          readOnly: _isReadOnly,
                          onChanged: (_) => _onDetailFieldChanged(r),
                        ))),
                        DataCell(SizedBox(width: 100, child: TextFormField(
                          controller: r.priceCtrl,
                          decoration: InputDecoration(
                            isDense: true, border: inputBorder, enabledBorder: inputBorder, focusedBorder: focusBorder,
                            filled: !_isReadOnly, fillColor: Colors.white,
                          ),
                          style: const TextStyle(fontSize: 12),
                          keyboardType: TextInputType.number, textAlign: TextAlign.right,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                          readOnly: _isReadOnly,
                          onChanged: (_) => _onDetailFieldChanged(r),
                        ))),
                        DataCell(SizedBox(width: 60, child: TextFormField(
                          controller: r.discPctCtrl,
                          decoration: InputDecoration(
                            isDense: true, border: inputBorder, enabledBorder: inputBorder, focusedBorder: focusBorder,
                            filled: !_isReadOnly, fillColor: Colors.white,
                          ),
                          style: const TextStyle(fontSize: 12),
                          keyboardType: TextInputType.number, textAlign: TextAlign.right,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                          readOnly: _isReadOnly,
                          onChanged: (_) => _onDetailFieldChanged(r),
                        ))),
                        DataCell(Text(_fmt.format(afterDisc), style: const TextStyle(fontSize: 12))),
                        DataCell(SizedBox(width: 120, child: _isReadOnly
                            ? Text(vatTypeLabels[r.vatType] ?? r.vatType, style: const TextStyle(fontSize: 12))
                            : DropdownButtonHideUnderline(child: DropdownButton<String>(
                                value: r.vatType,
                                isDense: true,
                                isExpanded: true,
                                style: const TextStyle(fontSize: 12, color: Colors.black),
                                items: vatTypeOptions.map((vt) => DropdownMenuItem(value: vt, child: Text(vatTypeLabels[vt] ?? vt))).toList(),
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() {
                                    r.vatType = v;
                                    r.vatRate = v == 'NOVAT' ? 0 : (_vatRates.cast<VatRate?>().firstWhere((vr) => vr!.vatCode == v, orElse: () => null)?.rate ?? 7.0);
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
                          onChanged: (r.vatType == 'NOVAT' || _isReadOnly) ? null : (v) => setState(() => r.isDeferredVat = v ?? false),
                        )),
                        if (!_isReadOnly)
                          DataCell(IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                            onPressed: () => _removeDetailRow(i),
                            visualDensity: VisualDensity.compact,
                          )),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
        ],
        if (_detailRows.isNotEmpty) ...[
          const Divider(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'ยอดรวมสุทธิ: ${_fmt.format(_totalAmountFc)} ${_selectedCurrency?.currencyCode ?? 'THB'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ]),
    ));
  }


  // ── Apply Section (Payment invoice selection) ────────────────────────────
  Widget _buildApplySection() {
    final label = _isRA ? 'เลือกใบแจ้งหนี้ (RA)' : 'เลือกใบแจ้งหนี้ที่ชำระ';
    final totalApplied = _applyRows.fold(0.0, (s, a) => s + a.appliedAmountLc);
    final currency = _selectedCurrency?.currencyCode ?? 'THB';
    return Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader(label, _applyExpanded, () => setState(() => _applyExpanded = !_applyExpanded), icon: Icons.link),
        if (_applyExpanded)
          _buildInvoiceSelectionTable(
            open: _openInvoices,
            selected: _applyRows,
            ctrlMap: _applyCtrlMap,
          ),
        const SizedBox(height: 8),
        Text(
          _isRA ? 'ยอดชำระ RA: ${_fmt.format(totalApplied)} $currency' : 'ยอดชำระ Invoice: ${_fmt.format(totalApplied)} $currency',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ]),
    ));
  }

  // ── Advance Deduction Section (for Payment) ───────────────────────────────
  Widget _buildAdvanceSection() {
    final totalAdv = _advanceRows.fold(0.0, (s, a) => s + a.appliedAmountLc);
    final currency = _selectedCurrency?.currencyCode ?? 'THB';
    return Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader('หักมัดจำล่วงหน้า', _advanceExpanded, () => setState(() => _advanceExpanded = !_advanceExpanded), icon: Icons.money_off),
        if (_advanceExpanded)
          _buildInvoiceSelectionTable(
            open: _openAdvances,
            selected: _advanceRows,
            ctrlMap: _advanceCtrlMap,
          ),
        const SizedBox(height: 8),
        Text('ยอดหักมัดจำ: ${_fmt.format(totalAdv)} $currency', style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
    ));
  }

  // ── Advance Refund Section ─────────────────────────────────────────────────
  Widget _buildAdvanceRefundSection() {
    final totalRef = _advanceRefundRows.fold(0.0, (s, a) => s + a.appliedAmountLc);
    final currency = _selectedCurrency?.currencyCode ?? 'THB';
    return Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader('เลือกมัดจำที่จะรับคืน', _advanceExpanded, () => setState(() => _advanceExpanded = !_advanceExpanded), icon: Icons.undo),
        if (_advanceExpanded)
          _buildInvoiceSelectionTable(
            open: _openAdvancesForRefund,
            selected: _advanceRefundRows,
            ctrlMap: _advanceRefundCtrlMap,
          ),
        const SizedBox(height: 8),
        Text('ยอดรับมัดจำคืน: ${_fmt.format(totalRef)} $currency', style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
    ));
  }

  Widget _buildInvoiceSelectionTable({
    required List<ApOpenInvoice> open,
    required List<_ApplyRow> selected,
    required Map<int, TextEditingController> ctrlMap,
  }) {
    final isFc = _selectedCurrency?.baseCurrencyFlag == false;
    if (open.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text('ไม่มีรายการที่ค้างชำระ', style: TextStyle(color: Colors.grey)),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
            columnSpacing: 12,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 46,
            columns: [
              const DataColumn(label: Text('เลขที่เอกสาร', style: TextStyle(fontWeight: FontWeight.bold))),
              const DataColumn(label: Text('วันที่', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(isFc ? 'ยอดรวม (FC)' : 'ยอดรวม', style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text(isFc ? 'คงเหลือ (FC)' : 'คงเหลือ', style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text(isFc ? 'ชำระ (FC)' : 'ชำระ/หักกลบ', style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
            ],
            rows: open.map((inv) {
              final existing = selected.cast<_ApplyRow?>().firstWhere((a) => a?.appliedToId == inv.id, orElse: () => null);
              final total = isFc && inv.exchangeRate > 0 ? inv.totalAmountLc / inv.exchangeRate : inv.totalAmountLc;
              final balance = isFc && inv.exchangeRate > 0 ? inv.balanceAmountLc / inv.exchangeRate : inv.balanceAmountLc;
              ctrlMap.putIfAbsent(inv.id, () => TextEditingController(
                text: existing != null ? existing.appliedAmountLc.toStringAsFixed(2) : balance.toStringAsFixed(2),
              ));
              return DataRow(cells: [
                DataCell(Text(inv.docNo, style: const TextStyle(fontSize: 12))),
                DataCell(Text(inv.docDate != null ? _dateFmt.format(inv.docDate!) : '', style: const TextStyle(fontSize: 12))),
                DataCell(Text(_fmt.format(total), style: const TextStyle(fontSize: 12))),
                DataCell(Text(_fmt.format(balance), style: TextStyle(fontSize: 12, color: Colors.blue[700]))),
                DataCell(SizedBox(width: 140, child: _isReadOnly
                  ? Text(_fmt.format(existing?.appliedAmountLc ?? 0),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.right)
                  : TextFormField(
                      controller: ctrlMap[inv.id],
                      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                      style: const TextStyle(fontSize: 12),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      onChanged: (v) {
                        final amount = double.tryParse(v) ?? 0;
                        final idx = selected.indexWhere((a) => a.appliedToId == inv.id);
                        if (amount <= 0) {
                          if (idx >= 0) setState(() { selected.removeAt(idx); _recalcTotals(); });
                        } else {
                          final row = _ApplyRow(
                            appliedToId: inv.id, appliedToDocNo: inv.docNo,
                            appliedToDocDate: inv.docDate,
                            appliedToTotal: balance,
                            appliedAmountLc: amount,
                          );
                          setState(() {
                            if (idx >= 0) selected[idx] = row; else selected.add(row);
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
    );
  }

  // ── WHT Section ───────────────────────────────────────────────────────────
  Widget _buildWhtSection() {
    return Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader('ภาษีหัก ณ ที่จ่าย (WHT)', _whtExpanded, () => setState(() => _whtExpanded = !_whtExpanded),
          icon: Icons.percent,
          trailing: _isReadOnly ? null : TextButton.icon(
            onPressed: () => setState(() => _whtRows.add(_WhtRow())),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('เพิ่ม WHT'),
          ),
        ),
        if (_whtExpanded) ...[
          if (_whtRows.isEmpty)
            const Padding(padding: EdgeInsets.all(8), child: Text('ไม่มีรายการ WHT', style: TextStyle(color: Colors.grey)))
          else
            ...(_whtRows.asMap().entries.map((e) {
              final i = e.key; final w = e.value;
              final rate = w.selectedWhtType?.whtRate ?? 0;
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  Expanded(flex: 3, child: DropdownButtonFormField<CdWhtType?>(
                    value: w.selectedWhtType,
                    decoration: _fieldDeco('ประเภท WHT'),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('— เลือกประเภท —')),
                      ..._whtTypes.map((t) => DropdownMenuItem(
                        value: t,
                        child: Text('${t.whtCode} — ${t.whtName}', overflow: TextOverflow.ellipsis),
                      )),
                    ],
                    onChanged: _isReadOnly ? null : (t) {
                      setState(() {
                        w.selectedWhtType = t;
                        final base = double.tryParse(w.baseCtrl.text) ?? 0;
                        final r = t?.whtRate ?? 0;
                        w.whtCtrl.text = (base * r / 100).toStringAsFixed(2);
                      });
                    },
                  )),
                  const SizedBox(width: 8),
                  SizedBox(width: 70, child: InputDecorator(
                    decoration: _fieldDeco('อัตรา (%)'),
                    child: Text(
                      rate > 0 ? '${rate.toStringAsFixed(2)}%' : '—',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 14),
                    ),
                  )),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: TextFormField(
                    controller: w.baseCtrl,
                    decoration: _fieldDeco('ฐานภาษี (LC)'),
                    keyboardType: TextInputType.number, textAlign: TextAlign.right,
                    readOnly: _isReadOnly,
                    onChanged: (v) {
                      final base = double.tryParse(v) ?? 0;
                      setState(() => w.whtCtrl.text = (base * rate / 100).toStringAsFixed(2));
                    },
                  )),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: TextFormField(
                    controller: w.whtCtrl,
                    decoration: _fieldDeco('ภาษี WHT (LC)'),
                    keyboardType: TextInputType.number, textAlign: TextAlign.right,
                    readOnly: _isReadOnly,
                  )),
                  const SizedBox(width: 8),
                  Expanded(flex: 3, child: TextFormField(
                    controller: w.descCtrl,
                    decoration: _fieldDeco('คำอธิบาย'),
                    readOnly: _isReadOnly,
                  )),
                  if (!_isReadOnly) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                      onPressed: () => setState(() { w.dispose(); _whtRows.removeAt(i); }),
                    ),
                  ],
                ]),
              );
            })),
          if (_whtRows.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: Text(
              'รวม WHT: ${_fmt.format(_whtRows.fold(0.0, (s, w) => s + (double.tryParse(w.whtCtrl.text) ?? 0)))} บาท',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            )),
          ],
        ],
      ]),
    ));
  }

  // ── Payment Section ───────────────────────────────────────────────────────
  Widget _buildPaymentSection() {
    return Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader('ช่องทางการชำระเงิน', _paymentExpanded, () => setState(() => _paymentExpanded = !_paymentExpanded),
          icon: Icons.payment,
          trailing: _isReadOnly ? null : TextButton.icon(
            onPressed: () async {
              final method = await showDialog<CmPaymentMethod>(
                context: context,
                builder: (ctx) => Dialog(child: SizedBox(
                  width: 500, height: 400,
                  child: Column(children: [
                    AppBar(title: const Text('เลือกช่องทางการชำระเงิน'), backgroundColor: Colors.blue[700], foregroundColor: Colors.white, automaticallyImplyLeading: false,
                      actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))]),
                    Expanded(child: CmPaymentMethodListWidget(
                      enableAddButton: false, enableEditButton: false, enableViewButton: false, enableDeleteButton: false,
                      enableCardSelect: false,
                      onAdd: () {}, onEdit: (_) {}, onView: (_) {}, onDelete: (_) {},
                      onCallback: (m) => Navigator.pop(ctx, m),
                    )),
                  ]),
                )),
              );
              if (method != null) {
                setState(() => _paymentRows.add(_PaymentRow(
                  paymentMethodId: method.id, paymentMethodCode: method.methodCode,
                  paymentMethodName: method.methodNameTh, paymentMethodType: method.methodType,
                  cmBankAccountId: method.cmBankAccountId, glAccountId: method.glAccountId,
                )));
              }
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('เพิ่มช่องทาง'),
          ),
        ),
        if (_paymentExpanded) ...[
          if (_paymentRows.isEmpty)
            const Padding(padding: EdgeInsets.all(8), child: Text('ยังไม่มีช่องทางการชำระเงิน', style: TextStyle(color: Colors.grey)))
          else
            ...(_paymentRows.asMap().entries.map((e) {
              final i = e.key; final r = e.value;
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 2, child: InputDecorator(
                    decoration: _fieldDeco('ช่องทาง', forcedReadOnly: true),
                    child: Text('${r.paymentMethodCode ?? ''} ${r.paymentMethodName ?? ''}'.trim(), overflow: TextOverflow.ellipsis),
                  )),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: TextFormField(
                    controller: r.amountCtrl,
                    decoration: _fieldDeco(_selectedCurrency?.baseCurrencyFlag == false ? 'จำนวนเงิน (FC)' : 'จำนวนเงิน (THB)'),
                    keyboardType: TextInputType.number, textAlign: TextAlign.right,
                    readOnly: _isReadOnly,
                    onChanged: (_) => _recalcTotals(),
                  )),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: TextFormField(
                    controller: r.refNoCtrl,
                    decoration: _fieldDeco('เลขที่อ้างอิง'),
                    readOnly: _isReadOnly,
                  )),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: InkWell(
                    onTap: _isReadOnly ? null : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: r.paymentDate ?? _docDate,
                        firstDate: DateTime(2000), lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => r.paymentDate = picked);
                    },
                    child: InputDecorator(
                      decoration: _fieldDeco('วันที่ชำระ'),
                      child: Row(children: [
                        Expanded(child: Text(r.paymentDate != null ? _dateFmt.format(r.paymentDate!) : '—')),
                        if (!_isReadOnly) const Icon(Icons.calendar_today, size: 14),
                      ]),
                    ),
                  )),
                  if (r.paymentMethodType == 'CHECK') ...[
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: TextFormField(
                      controller: r.drawerBankNameCtrl,
                      decoration: _fieldDeco('ธนาคาร'),
                      readOnly: _isReadOnly,
                    )),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: TextFormField(
                      controller: r.drawerAccountNoCtrl,
                      decoration: _fieldDeco('เลขที่เช็ค'),
                      readOnly: _isReadOnly,
                    )),
                  ],
                  if (!_isReadOnly) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                      onPressed: () => setState(() { r.dispose(); _paymentRows.removeAt(i); }),
                    ),
                  ],
                ]),
              );
            })),
        ],
      ]),
    ));
  }

  // ── Totals Row ────────────────────────────────────────────────────────────
  Widget _buildTotalsRow() {
    final lc = _exchangeRate;
    final isFc = _selectedCurrency?.baseCurrencyFlag == false;
    final totalWht = _whtRows.fold(0.0, (s, w) => s + (double.tryParse(w.whtCtrl.text) ?? 0));
    final totalPayment = _paymentRows.fold(0.0, (s, r) => s + (double.tryParse(r.amountCtrl.text) ?? 0));

    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (_hasDetailRows) ...[
            _totalsLine('ยอดรวมก่อน VAT${isFc ? ' (FC)' : ''}', _beforeVatFc),
            if (_vatAmountFc > 0) _totalsLine('VAT${isFc ? ' (FC)' : ''}', _vatAmountFc),
          ],
          _totalsLine(
            isFc ? 'ยอดรวม (FC)' : 'ยอดรวม (THB)',
            _totalAmountFc,
            bold: true, color: Colors.blue[800],
          ),
          if (isFc) _totalsLine('ยอดรวม (THB)', _totalAmountFc * lc, bold: true, color: Colors.blue[800]),
          if (_hasWhtSection && totalWht > 0) ...[
            const Divider(),
            _totalsLine('WHT หัก ณ ที่จ่าย', totalWht, color: Colors.red),
          ],
          if (_hasPaymentRows && totalPayment > 0) ...[
            const Divider(),
            _totalsLine('ยอดชำระ${isFc ? ' (FC)' : ''}', totalPayment),
            if (isFc) _totalsLine('ยอดชำระ (THB)', totalPayment * lc),
          ],
        ]),
      ),
    );
  }

  Widget _totalsLine(String label, double amount, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Text('$label: ', style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        SizedBox(width: 120, child: Text(
          _fmt.format(amount),
          textAlign: TextAlign.right,
          style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color),
        )),
      ]),
    );
  }

  // ── GL Entry Dialog ───────────────────────────────────────────────────────
  Future<void> _showGlEntryDialog() async {
    final isPosted = _status == 'Posted';
    if (isPosted && _glEntryId != null) {
      showDialog(context: context, barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()));
      try {
        final result = await _glEntryService.fetchEntryDetail(_glEntryId!);
        if (!mounted) return;
        Navigator.of(context).pop();
        final header = result['header'] as GlEntryHeader;
        final details = result['details'] as List<GlEntryDetail>;
        _showGlDialog(
          title: 'GL Entry — รายการลงบัญชีจริง',
          statusLabel: 'Posted',
          statusColor: Colors.blue,
          glDocNo: header.docNo,
          refDocNo: _docNo,
          docDate: header.docDate,
          description: header.description,
          lines: details.map((d) => _GlLine(d.accountCode, d.accountName, d.description, d.debitLc, d.creditLc, d.debitFc, d.creditFc)).toList(),
          currencyCode: _selectedCurrency?.currencyCode ?? '',
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('โหลด GL ล้มเหลว: $e')));
      }
    } else {
      // Draft: compute GL preview from current form data
      if (_docSetup == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาตั้งค่าผังบัญชี AP ก่อน (AP GL Account Setup) เพื่อดูตัวอย่าง GL')),
        );
        return;
      }
      final previewLines = _computeGlPreview();
      if (previewLines.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่มีข้อมูล GL — กรุณาป้อนรายการก่อน')),
        );
        return;
      }
      _showGlDialog(
        title: 'ตัวอย่าง GL Entry (Draft)',
        statusLabel: 'Draft Preview',
        statusColor: Colors.orange[700]!,
        glDocNo: '—',
        refDocNo: _docNo,
        docDate: _docDate,
        description: _descCtrl.text,
        lines: previewLines,
        currencyCode: _selectedCurrency?.currencyCode ?? '',
      );
    }
  }

  // ── Client-side GL preview for Draft ──────────────────────────────────────
  List<_GlLine> _computeGlPreview() {
    final lines = <_GlLine>[];
    final lc = _exchangeRate;
    final isFcDoc = _selectedCurrency?.baseCurrencyFlag == false;
    final setup = _docSetup;
    if (setup == null) return lines;

    final sysType = int.tryParse(_selectedDocType?.sysDocType ?? '');

    String acctCode(int? id, String? fallback) {
      if (id != null) {
        try { return _accounts.firstWhere((a) => a.id == id).accountCode; } catch (_) {}
      }
      return fallback ?? '—';
    }
    String acctName(int? id, String? fallback) {
      if (id != null) {
        try { return _accounts.firstWhere((a) => a.id == id).accountNameThai; } catch (_) {}
      }
      return fallback ?? '';
    }

    final apCode = setup.apAccountCode ?? _selectedVendor?.apAccountCode ?? acctCode(_apAccountId ?? setup.apAccountId, '—');
    final apName = setup.apAccountName ?? _selectedVendor?.apAccountNameThai ?? acctName(_apAccountId ?? setup.apAccountId, 'เจ้าหนี้การค้า');

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
      if (sName != null && sName.isNotEmpty) return sName;
      if (sid != null) return acctName(sid, setup.cashAccountName ?? 'Cash');
      return acctName(p.glAccountId, setup.cashAccountName ?? 'Cash');
    }

    // ── PI (10) / DN (50) ────────────────────────────────────────────────
    if (sysType == apDocTypePurchaseInvoice || sysType == apDocTypeDebitNote) {
      for (final r in _detailRows) {
        final qty      = double.tryParse(r.qtyCtrl.text)    ?? 0;
        final price    = double.tryParse(r.priceCtrl.text)  ?? 0;
        final discPct  = double.tryParse(r.discPctCtrl.text) ?? 0;
        final afterDisc = qty * price * (1 - discPct / 100);
        final vat      = r.vatType == 'NOVAT' ? 0.0 : afterDisc * r.vatRate / 100;
        final expAccId = r.expenseAccountId ?? setup.expenseAccountId;
        final expCode  = acctCode(expAccId, setup.expenseAccountCode);
        final expName  = acctName(expAccId, setup.expenseAccountName);
        final desc     = r.itemNameCtrl.text.isNotEmpty ? r.itemNameCtrl.text : 'ค่าใช้จ่าย';
        lines.add(_GlLine(expCode, expName.isEmpty ? 'Expense' : expName, desc, afterDisc * lc, 0, isFcDoc ? afterDisc : 0, 0));
        if (vat > 0) {
          final vatId  = r.isDeferredVat ? setup.vatPendingInputAccountId : setup.vatInputAccountId;
          final vatFb  = r.isDeferredVat ? setup.vatPendingInputAccountCode : setup.vatInputAccountCode;
          final vatNFb = r.isDeferredVat ? setup.vatPendingInputAccountName : setup.vatInputAccountName;
          lines.add(_GlLine(acctCode(vatId, vatFb), acctName(vatId, vatNFb).isEmpty ? 'VAT Input' : acctName(vatId, vatNFb), 'ภาษีมูลค่าเพิ่ม', vat * lc, 0, isFcDoc ? vat : 0, 0));
        }
      }
      lines.add(_GlLine(apCode, apName.isEmpty ? 'AP Account' : apName, 'เจ้าหนี้การค้า', 0, _totalAmountFc * lc, 0, isFcDoc ? _totalAmountFc : 0));
    }
    // ── CN (30) ─────────────────────────────────────────────────────────
    else if (sysType == apDocTypeCreditNote) {
      lines.add(_GlLine(apCode, apName.isEmpty ? 'AP Account' : apName, 'เจ้าหนี้การค้า', _totalAmountFc * lc, 0, isFcDoc ? _totalAmountFc : 0, 0));
      for (final r in _detailRows) {
        final qty      = double.tryParse(r.qtyCtrl.text)    ?? 0;
        final price    = double.tryParse(r.priceCtrl.text)  ?? 0;
        final discPct  = double.tryParse(r.discPctCtrl.text) ?? 0;
        final afterDisc = qty * price * (1 - discPct / 100);
        final vat      = r.vatType == 'NOVAT' ? 0.0 : afterDisc * r.vatRate / 100;
        final expAccId = r.expenseAccountId ?? setup.expenseAccountId;
        final expCode  = acctCode(expAccId, setup.expenseAccountCode);
        final expName  = acctName(expAccId, setup.expenseAccountName);
        final desc     = r.itemNameCtrl.text.isNotEmpty ? r.itemNameCtrl.text : 'ค่าใช้จ่าย';
        lines.add(_GlLine(expCode, expName.isEmpty ? 'Expense' : expName, desc, 0, afterDisc * lc, 0, isFcDoc ? afterDisc : 0));
        if (vat > 0) {
          final vatId  = r.isDeferredVat ? setup.vatPendingInputAccountId : setup.vatInputAccountId;
          final vatFb  = r.isDeferredVat ? setup.vatPendingInputAccountCode : setup.vatInputAccountCode;
          final vatNFb = r.isDeferredVat ? setup.vatPendingInputAccountName : setup.vatInputAccountName;
          lines.add(_GlLine(acctCode(vatId, vatFb), acctName(vatId, vatNFb).isEmpty ? 'VAT Input' : acctName(vatId, vatNFb), 'ภาษีมูลค่าเพิ่ม', 0, vat * lc, 0, isFcDoc ? vat : 0));
        }
      }
    }
    // ── Advance Payment (60) ─────────────────────────────────────────────
    else if (sysType == apDocTypeAdvancePayment) {
      lines.add(_GlLine(setup.advanceAccountCode ?? '—', setup.advanceAccountName ?? 'Advance', 'จ่ายมัดจำ', _totalAmountFc * lc, 0, isFcDoc ? _totalAmountFc : 0, 0));
      if (_paymentRows.isEmpty) {
        lines.add(_GlLine(setup.cashAccountCode ?? '—', setup.cashAccountName ?? 'Cash', 'ชำระ', 0, _totalAmountFc * lc, 0, isFcDoc ? _totalAmountFc : 0));
      } else {
        for (final p in _paymentRows) {
          final amt = double.tryParse(p.amountCtrl.text) ?? 0;
          if (amt <= 0) continue;
          lines.add(_GlLine(payAcctCode(p), payAcctName(p).isEmpty ? 'Cash' : payAcctName(p), p.paymentMethodName ?? 'ชำระ', 0, amt * lc, 0, isFcDoc ? amt : 0));
        }
      }
    }
    // ── Advance Refund (65) ──────────────────────────────────────────────
    else if (sysType == apDocTypeAdvanceRefund) {
      lines.add(_GlLine(setup.cashAccountCode ?? '—', setup.cashAccountName ?? 'Cash', 'รับมัดจำคืน', _totalAmountFc * lc, 0, isFcDoc ? _totalAmountFc : 0, 0));
      lines.add(_GlLine(setup.advanceAccountCode ?? '—', setup.advanceAccountName ?? 'Advance', 'คืนมัดจำ', 0, _totalAmountFc * lc, 0, isFcDoc ? _totalAmountFc : 0));
    }
    // ── Payment (80) ─────────────────────────────────────────────────────
    else if (sysType == apDocTypePayment) {
      final totalWht = _whtRows.fold(0.0, (s, w) => s + (double.tryParse(w.whtCtrl.text) ?? 0));
      final totalAdv = _advanceRows.fold(0.0, (s, a) => s + a.appliedAmountLc);
      for (final a in _applyRows) {
        lines.add(_GlLine(apCode, apName.isEmpty ? 'AP Account' : apName, 'ชำระ ${a.appliedToDocNo}', a.appliedAmountLc * lc, 0, isFcDoc ? a.appliedAmountLc : 0, 0));
      }
      if (totalWht > 0) {
        lines.add(_GlLine(setup.whtPayableAccountCode ?? '—', setup.whtPayableAccountName ?? 'WHT Payable', 'ภาษีหัก ณ ที่จ่าย', 0, totalWht * lc, 0, isFcDoc ? totalWht : 0));
      }
      if (totalAdv > 0) {
        lines.add(_GlLine(setup.advanceAccountCode ?? '—', setup.advanceAccountName ?? 'Advance', 'หักมัดจำ', 0, totalAdv * lc, 0, isFcDoc ? totalAdv : 0));
      }
      if (_paymentRows.isEmpty) {
        final netCash = _applyRows.fold(0.0, (s, a) => s + a.appliedAmountLc) - totalAdv - totalWht;
        if (netCash > 0.005) lines.add(_GlLine(setup.cashAccountCode ?? '—', setup.cashAccountName ?? 'Cash', 'ชำระเงิน', 0, netCash * lc, 0, isFcDoc ? netCash : 0));
      } else {
        for (final p in _paymentRows) {
          final amt = double.tryParse(p.amountCtrl.text) ?? 0;
          if (amt <= 0) continue;
          lines.add(_GlLine(payAcctCode(p), payAcctName(p).isEmpty ? 'Cash' : payAcctName(p), p.paymentMethodName ?? 'ชำระเงิน', 0, amt * lc, 0, isFcDoc ? amt : 0));
        }
      }
    }
    return lines;
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
    final fmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd/MM/yyyy');
    final totalDebit  = lines.fold(0.0, (s, l) => s + l.debit);
    final totalCredit = lines.fold(0.0, (s, l) => s + l.credit);
    final isBalanced  = (totalDebit - totalCredit).abs() < 0.005;
    final hasFc = lines.any((l) => l.debitFc > 0 || l.creditFc > 0);
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

    final headerRow = hasFc
        ? TableRow(decoration: BoxDecoration(color: Colors.grey[200]), children: [
            cell('#', bold: true, align: TextAlign.center), cell('รหัสบัญชี', bold: true),
            cell('ชื่อบัญชี', bold: true), cell('รายละเอียด', bold: true),
            cell('เดบิต ($fcLabel)', bold: true, align: TextAlign.right),
            cell('เครดิต ($fcLabel)', bold: true, align: TextAlign.right),
            cell('เดบิต ($lcLabel)', bold: true, align: TextAlign.right),
            cell('เครดิต ($lcLabel)', bold: true, align: TextAlign.right),
          ])
        : TableRow(decoration: BoxDecoration(color: Colors.grey[200]), children: [
            cell('#', bold: true, align: TextAlign.center), cell('รหัสบัญชี', bold: true),
            cell('ชื่อบัญชี', bold: true), cell('รายละเอียด', bold: true),
            cell('เดบิต', bold: true, align: TextAlign.right),
            cell('เครดิต', bold: true, align: TextAlign.right),
          ]);

    final dataRows = lines.asMap().entries.map((e) {
      final i = e.key; final l = e.value;
      final bg = i.isOdd ? Colors.grey[50] : Colors.white;
      return hasFc
          ? TableRow(decoration: BoxDecoration(color: bg), children: [
              cell('${i + 1}', align: TextAlign.center), cell(l.accountCode),
              cell(l.accountName), cell(l.description),
              cell(l.debitFc  > 0 ? fmt.format(l.debitFc)  : '', align: TextAlign.right, color: Colors.blue[700]),
              cell(l.creditFc > 0 ? fmt.format(l.creditFc) : '', align: TextAlign.right, color: Colors.red[700]),
              cell(l.debit  > 0 ? fmt.format(l.debit)  : '', align: TextAlign.right, color: Colors.blue[800]),
              cell(l.credit > 0 ? fmt.format(l.credit) : '', align: TextAlign.right, color: Colors.red[800]),
            ])
          : TableRow(decoration: BoxDecoration(color: bg), children: [
              cell('${i + 1}', align: TextAlign.center), cell(l.accountCode),
              cell(l.accountName), cell(l.description),
              cell(l.debit  > 0 ? fmt.format(l.debit)  : '', align: TextAlign.right, color: Colors.blue[700]),
              cell(l.credit > 0 ? fmt.format(l.credit) : '', align: TextAlign.right, color: Colors.red[700]),
            ]);
    }).toList();

    final totalsRow = hasFc
        ? TableRow(decoration: BoxDecoration(color: Colors.grey[100]), children: [
            cell(''), cell(''), cell(''),
            cell('รวม', bold: true, align: TextAlign.right),
            cell(fmt.format(lines.fold(0.0, (s, l) => s + l.debitFc)),  bold: true, align: TextAlign.right, color: Colors.blue[700]),
            cell(fmt.format(lines.fold(0.0, (s, l) => s + l.creditFc)), bold: true, align: TextAlign.right, color: Colors.red[700]),
            cell(fmt.format(totalDebit),  bold: true, align: TextAlign.right, color: Colors.blue[800]),
            cell(fmt.format(totalCredit), bold: true, align: TextAlign.right, color: Colors.red[800]),
          ])
        : TableRow(decoration: BoxDecoration(color: Colors.grey[100]), children: [
            cell(''), cell(''), cell(''),
            cell('รวม', bold: true, align: TextAlign.right),
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
              Row(children: [
                Icon(Icons.account_balance_outlined, color: Colors.indigo[700], size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (hasFc) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.indigo[50], borderRadius: BorderRadius.circular(8)),
                    child: Text('สกุลเงิน: $fcLabel', style: TextStyle(fontSize: 11, color: Colors.indigo[700], fontWeight: FontWeight.w600)),
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
              Wrap(spacing: 24, runSpacing: 6, children: [
                _glInfoChip('GL Doc', glDocNo),
                _glInfoChip('AP Doc', refDocNo),
                _glInfoChip('วันที่', dateFmt.format(docDate)),
                if (description.isNotEmpty) _glInfoChip('คำอธิบาย', description),
              ]),
              const SizedBox(height: 16),
              Expanded(child: SingleChildScrollView(
                child: Table(
                  columnWidths: hasFc
                      ? const {
                          0: FixedColumnWidth(36), 1: FixedColumnWidth(90),
                          2: FlexColumnWidth(1.8), 3: FlexColumnWidth(2.0),
                          4: FixedColumnWidth(100), 5: FixedColumnWidth(100),
                          6: FixedColumnWidth(100), 7: FixedColumnWidth(100),
                        }
                      : const {
                          0: FixedColumnWidth(36), 1: FixedColumnWidth(100),
                          2: FlexColumnWidth(2.0), 3: FlexColumnWidth(2.5),
                          4: FixedColumnWidth(115), 5: FixedColumnWidth(115),
                        },
                  border: TableBorder.all(color: Colors.grey[300]!, width: 0.5),
                  children: [headerRow, ...dataRows, totalsRow],
                ),
              )),
              const SizedBox(height: 12),
              Row(children: [
                Icon(
                  isBalanced ? Icons.check_circle_outline : Icons.warning_amber_outlined,
                  color: isBalanced ? Colors.blue : Colors.orange,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  isBalanced
                      ? 'บาลานซ์ถูกต้อง (Balanced)'
                      : 'ไม่บาลานซ์ — ส่วนต่าง ${fmt.format((totalDebit - totalCredit).abs())} $lcLabel',
                  style: TextStyle(
                    color: isBalanced ? Colors.blue : Colors.orange,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('ปิด')),
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
  const _GlLine(this.accountCode, this.accountName, this.description, this.debit, this.credit, this.debitFc, this.creditFc);
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
  })  : itemCodeCtrl = TextEditingController(text: itemCode ?? ''),
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
      );

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

  _PaymentRow({
    this.paymentMethodId, this.paymentMethodCode, this.paymentMethodName,
    this.paymentMethodType = 'CASH',
    this.cmBankAccountId, this.glAccountId,
    double amount = 0, String? refNo, String? remark, this.paymentDate,
    String? drawerBankName, String? drawerBankBranch, String? drawerAccountNo,
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
