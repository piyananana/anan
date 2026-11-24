// lib/so/widgets/so_transaction_detail_widget.dart — แก้ไขรายละเอียดใบสั่งขาย (header+lines)
// มิเรอร์โครงสร้าง po_transaction_detail_widget.dart ทุกประการ (vendor->customer) — SO ไม่แตะสต็อก/GL เลย —
// Draft เท่านั้นที่แก้ไขได้ (เหมือน DLN), Approve/Close/Void เป็น action แยกกดทีละปุ่ม ดู soTransactionController.js
// สำหรับ workflow เต็ม — มีขั้น "ใบเสนอราคา" (Quote) นำหน้าได้เหมือน PR นำหน้า PO (ดู _pickQuoteLines,
// มิเรอร์ _pickPrLines ใน po_transaction_detail_widget.dart ทุกประการ)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/models/sa_document_reverse_log.dart';
import '../../sa/widgets/sa_document_reverse_widgets.dart';
import '../../ar/models/ar_customer.dart';
import '../../ar/widgets/ar_customer_list_widget.dart';
import '../../im/models/im_item.dart';
import '../../im/models/im_warehouse.dart';
import '../models/so_transaction.dart';
import '../../im/services/im_item_service.dart';
import '../services/so_transaction_service.dart';
import '../services/so_quote_transaction_service.dart';
import '../../im/widgets/im_warehouse_list_widget.dart';
import '../../cd/models/cd_currency.dart';
import '../../cd/services/cd_currency_service.dart';
import '../../sa/widgets/sa_attachment_widget.dart';
import '../../sa/models/sa_doc_approval.dart';
import '../../sa/widgets/sa_doc_approval_panel.dart';
import '../../utils/order_ref_picker.dart';
import '../../sa/models/sa_credit_approval.dart';
import '../../sa/services/sa_credit_approval_service.dart';
import '../../sa/widgets/sa_credit_limit_panel.dart';
import '../../config/app_config.dart';
import '../../cd/models/cd_doc_salesperson.dart';
import '../../cd/widgets/cd_salesperson_split_editor.dart';
import '../../ar/services/ar_customer_service.dart';
import '../../cd/models/cd_vat_rate.dart';
import '../../cd/services/cd_vat_rate_service.dart';
import '../../utils/vat_calc.dart';
import '../../gl/models/gl_dimension.dart';
import '../../gl/widgets/gl_line_account_dims.dart';
import '../../cd/models/cd_branch.dart';
import '../../cd/services/cd_branch_service.dart';
import '../../cd/widgets/cd_user_branch_picker.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../../sa/widgets/sa_doc_list_kit.dart';
import '../../gl/widgets/gl_dimension_picker_field.dart';

class SoTransactionDetailWidget extends StatefulWidget {
  final int? transactionId;
  final bool viewOnly;
  final int resetKey;
  final VoidCallback onSaveSuccess;
  final VoidCallback onCancel;
  final bool canDelete;
  /// ปุ่มของเอกสารแสดงบน AppBar ของหน้าจอแม่ (แทนแถบปุ่มเดิม)
  final DocAppBarActions? actions;
  // คัดลอกใบสั่งขายเดิมเป็นฉบับร่างใหม่ — ใช้ได้เฉพาะตอน transactionId เป็น null (โหมดสร้างใหม่) เท่านั้น
  // ดู _load()/onCopyRequested สำหรับตรรกะเต็ม (มิเรอร์ po_transaction_detail_widget.dart ทุกประการ)
  final int? copyFromId;
  final ValueChanged<int>? onCopyRequested;

  const SoTransactionDetailWidget({
    super.key,
    required this.transactionId,
    this.viewOnly = false,
    this.resetKey = 0,
    required this.onSaveSuccess,
    required this.onCancel,
    this.canDelete = true,
    this.actions,
    this.copyFromId,
    this.onCopyRequested,
  });

  @override
  State<SoTransactionDetailWidget> createState() => _SoTransactionDetailWidgetState();
}

class _LineForm {
  int? id;
  ImItem? item;
  double qtyOrdered;
  double unitPriceFc;
  double qtyDelivered;
  double discountPercent;
  // ส่วนลดขั้นบันได "10+5+2" (ไม่เกิน 5 ขั้น) + ส่วนลดเงินต่อทั้งบรรทัด — ใบเก่า/ใบเสนอราคาที่มีแต่ % = ขั้นเดียว
  String discountText = '';
  double lineDiscountAmount = 0;
  String? vatType; // ว่าง = ใบสั่งขายเก่าก่อนมี VAT ต่อบรรทัด
  double vatRate;
  int? refQuoteDetailId; // บรรทัดใบเสนอราคา (Quote) ต้นทาง ถ้าเพิ่มมาจาก picker _pickQuoteLines()
  // ราคาล่าสุดที่ระบบ auto-fill ให้จาก im_price_list — ใช้เทียบกับ unitPriceFc ปัจจุบันตอนจำนวน/ลูกค้าเปลี่ยน
  // เพื่อรู้ว่าผู้ใช้แก้ราคาเองไปแล้วหรือยัง (ถ้าแก้แล้วจะไม่ auto-fill ทับให้อีก) ดู _maybeReresolvePrice — ค่า
  // เริ่มต้นต้องเป็น 0 (ไม่ใช่ null) ให้ตรงกับ unitPriceFc เริ่มต้นของบรรทัดใหม่ ไม่เช่นนั้นบรรทัดที่เพิ่มก่อนเลือก
  // ลูกค้า (unitPriceFc=0 ไม่เคย resolve) จะถูกมองว่า "ผู้ใช้แก้ไปแล้ว" (0 != null) ตั้งแต่แรก ทำให้ไม่มีวัน
  // auto-fill ย้อนหลังได้เลยแม้จำนวนจะเปลี่ยนก็ตาม
  double lastResolvedPrice = 0;
  // หน่วยของบรรทัด — จำนวน/ราคาตามหน่วยนี้ (ไม่ระบุ = หน่วยหลัก) factor = จำนวนหน่วยหลักต่อ 1 หน่วย
  // uoms = หน่วยที่สินค้าอนุญาตให้ขาย (null = ยังไม่โหลด) บรรทัดจากใบเสนอราคาใช้หน่วยของใบเสนอราคา (เปลี่ยนไม่ได้)
  int? uomId;
  String? uomCode, uomNameTh, uomNameEn;
  double factor;
  ImItemUoms? uoms;
  String? refQuoteDocNo; // เลขที่ใบเสนอราคาของบรรทัดต้นทาง
  // ช่องกรอกในตาราง + หมายเหตุต่อบรรทัด (= so_transaction_detail.description)
  final TextEditingController qtyCtrl, priceCtrl, discTextCtrl, discAmtCtrl, remarkCtrl;
  _LineForm({this.id, this.item, this.qtyOrdered = 0, this.unitPriceFc = 0, this.qtyDelivered = 0, this.refQuoteDetailId,
      this.discountPercent = 0, this.vatType, this.vatRate = 0, String? discountText, this.lineDiscountAmount = 0,
      this.uomId, this.uomCode, this.uomNameTh, this.uomNameEn, this.factor = 1, this.refQuoteDocNo, String? remark})
      : discountText = discountText ?? (discountPercent != 0 ? _fmtPct(discountPercent) : ''),
        qtyCtrl = TextEditingController(text: _fmtPct(qtyOrdered)),
        priceCtrl = TextEditingController(text: _fmtPct(unitPriceFc)),
        discTextCtrl = TextEditingController(text: discountText ?? (discountPercent != 0 ? _fmtPct(discountPercent) : '')),
        discAmtCtrl = TextEditingController(text: lineDiscountAmount != 0 ? _fmtPct(lineDiscountAmount) : ''),
        remarkCtrl = TextEditingController(text: remark ?? '');

  String? get remark => remarkCtrl.text.trim().isEmpty ? null : remarkCtrl.text.trim();
  // ราคาที่ระบบเติม/คูณตามหน่วย/แปลงรวม-ไม่รวม VAT — ช่องกรอกแสดงตาม
  void setPrice(double p) {
    unitPriceFc = p;
    priceCtrl.text = _fmtPct(p);
  }
  void dispose() {
    qtyCtrl.dispose();
    priceCtrl.dispose();
    discTextCtrl.dispose();
    discAmtCtrl.dispose();
    remarkCtrl.dispose();
  }

  static String _fmtPct(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

class _SoTransactionDetailWidgetState extends State<SoTransactionDetailWidget> implements DocAppBarActionsHost {
  final _service = SoTransactionService();
  final _quoteService = QuoteTransactionService();
  final _itemService = ImItemService();
  final _currencyService = CurrencyService();
  final _fmtQty = NumberFormat('#,##0.####');
  final _fmt = NumberFormat('#,##0.00');
  final _fmt4 = NumberFormat('#,##0.00##');
  bool _headerExpanded = true;
  // ระยะเครดิต (เดือน/วัน) — ค่าเริ่มต้นจากลูกค้า แก้แล้ววันครบกำหนดคำนวณใหม่ (แบบ AR/PO); ใบส่งสินค้าที่ดึงรายการใช้ค่านี้
  final _creditMonthsCtrl = TextEditingController();
  final _creditDaysCtrl = TextEditingController();
  int get _creditMonths => int.tryParse(_creditMonthsCtrl.text.trim()) ?? 0;
  int get _creditDays => int.tryParse(_creditDaysCtrl.text.trim()) ?? 0;
  DateTime _calcDueDate(DateTime from) {
    var d = DateTime(from.year, from.month + _creditMonths, from.day);
    if (_creditDays > 0) d = d.add(Duration(days: _creditDays));
    return d;
  }
  void _onCreditTermChanged() => setState(() {
        if (_creditMonths > 0 || _creditDays > 0) _dueDate = _calcDueDate(_docDate);
      });
  final _dateFmt = DateFormat('dd/MM/yyyy');
  bool _isEnglish = false;
  bool _isLoading = false;
  bool _isSaving = false;

  int? _id;
  int? _docId;
  String _docNo = 'AUTO';
  DateTime _docDate = DateTime.now();
  DateTime? _dueDate;
  final _poNoCtrl = TextEditingController(); // เลขที่ใบสั่งซื้อของลูกค้า
  DateTime? _poDate;
  ArCustomer? _customer;
  ImWarehouse? _warehouse;
  final _descCtrl = TextEditingController();
  // ส่วนลดท้ายบิล — ปันส่วนเข้าแต่ละรายการ (มิเรอร์ backend applyOrderSalesDiscounts)
  final _billDiscPctCtrl = TextEditingController();
  final _cashDiscCtrl = TextEditingController();
  String _status = 'Draft';
  String? _voidReason;
  DocActions _actions = const DocActions();
  String? _approvalMode;
  List<DocApprovalStep> _approvals = const [];
  List<OrderDeposit> _deposits = const []; // ใบมัดจำที่อ้างอิงใบสั่งนี้
  // วงเงินเครดิตลูกค้า — ตรวจตอนส่งอนุมัติ เกินวงเงินต้องขออนุมัติก่อน (กลไกเดียวกับใบแจ้งหนี้/ใบส่งสินค้า)
  final _creditService = CreditApprovalService(AppConfig.apiSo, 'so_transaction');
  DocCreditState _credit = const DocCreditState();
  int? _refQuoteId; // ใบเสนอราคา (Quote) ต้นทาง ถ้าเพิ่มรายการมาจาก _pickQuoteLines()
  String? _refQuoteDocNoLabel;
  // มิติหัวเอกสาร — ค่าเริ่มต้นจากใบเสนอราคาที่ดึงรายการมา (แก้ได้) — user-approved 2026-11-02
  List<GlDimensionType> _dimTypes = [];
  Map<String, List<GlDimensionValue>> _dimValues = {};
  Map<int, int?> _dimSelections = {};
  // สาขา (user-approved 2026-11-18): ค่าเริ่มต้น สาขาของผู้ใช้ → สาขาของคลัง; ส่งต่อให้เอกสาร IM ที่อ้างอิงใบสั่งขาย
  int? _branchId;
  List<Branch> _branches = [];
  bool _dimsLoaded = false;

  // รองรับขายสินค้าต่างประเทศเป็นสกุลเงินต่างประเทศ — unit_price_fc ต่อบรรทัดคือราคาในสกุลเงินนี้ (FC),
  // total_value_lc คำนวณจาก unit_price_fc * exchange_rate เสมอ มิเรอร์ po_transaction_detail_widget.dart ทุกประการ
  List<Currency> _currencies = [];
  Currency? _currency;
  double _exchangeRate = 1;

  // sys_module='41' มีมากกว่าหนึ่งประเภทเอกสารได้ จึงต้องกรองซ้ำด้วย sys_doc_type '10' คือ SO (ตาม soSysDocType
  // ใน sa_anan_module.dart) แล้วให้ผู้ใช้เลือกเองเหมือนหน้าจอธุรกรรม AR/AP
  static const _soSysDocType = '10';
  List<ModuleDocument> _allowedDocTypes = [];
  ModuleDocument? _docType;

  List<_LineForm> _lines = [];
  // ราคารวม VAT + ส่วนลด % + VAT ต่อบรรทัด (user-approved 2026-10-31) — ส่งต่อไปใบส่งสินค้าที่ดึงรายการ
  bool _priceIncludesVat = false;
  final _vatRateService = VatRateService();
  List<VatRate> _vatRates = [];

  // Rejected แก้ไขแล้วส่งอนุมัติใหม่ได้เหมือน Draft
  bool get _isEditable => ['Draft', 'Rejected'].contains(_status);
  bool get _isReadOnly => widget.viewOnly || !_isEditable || _credit.isPending;
  // ยอดบรรทัดเป็นบาท — มิเรอร์ backend lineAmountsLc (utils/vatCalc.js): ปัดยอดสกุลเงินเอกสารก่อนคูณอัตรา,
  // ราคารวม VAT ใช้ยอดรวมแปลงเป็นบาท ไม่รวม VAT คิด VAT จากยอดบาท
  static double _r2(double v) => ((v + 2.220446049250313e-16) * 100).roundToDouble() / 100; // = backend round2 (Number.EPSILON)
  static double _n(String s) => double.tryParse(s.trim()) ?? 0;
  double get _billDiscPct => _n(_billDiscPctCtrl.text);
  double get _cashDisc => _n(_cashDiscCtrl.text);
  // ส่วนลดของแต่ละบรรทัด (หน่วยราคาที่กรอก): own = ขั้นบันได + เงิน, bill = ส่วนที่ปันมาจากท้ายบิล
  Map<_LineForm, SalesLineDiscount> _salesDiscounts() {
    final res = computeSalesDiscounts([
      for (final l in _lines)
        SalesDiscountInput(entered: l.qtyOrdered * l.unitPriceFc, stepText: l.discountText, lineAmount: l.lineDiscountAmount),
    ], billDiscountPercent: _billDiscPct, cashDiscountAmount: _cashDisc);
    return {for (var i = 0; i < _lines.length; i++) _lines[i]: res[i]};
  }

  LineAmounts _lineLc(_LineForm l, [Map<_LineForm, SalesLineDiscount>? sd]) {
    final vat = l.vatType == null || l.vatType == 'NOVAT' ? 0.0 : l.vatRate;
    final a = calcLineAmounts(qty: l.qtyOrdered, price: l.unitPriceFc, discountAmount: (sd ?? _salesDiscounts())[l]?.total ?? 0,
        vatRate: vat, priceIncludesVat: _priceIncludesVat);
    final gross = _r2(_r2(a.gross) * _exchangeRate);
    final net = _r2(_r2(a.net) * _exchangeRate);
    final total = _priceIncludesVat && vat != 0 ? _r2(_r2(a.total) * _exchangeRate) : _r2(net + _r2(net * vat / 100));
    return LineAmounts(gross, _r2(gross - net), net, _r2(total - net), total);
  }
  LineAmounts get _totalsLc {
    double g = 0, d = 0, n = 0, v = 0, t = 0;
    final sd = _salesDiscounts();
    for (final l in _lines) {
      final a = _lineLc(l, sd);
      g += a.gross; d += a.discount; n += a.net; v += a.vat; t += a.total;
    }
    return LineAmounts(g, d, n, v, t);
  }
  // ยอดสำหรับตรวจวงเงิน (บาท): รวม VAT หลังส่วนลด — มิเรอร์ backend soDocAmount
  double get _creditAmount => _r2(_totalsLc.total);

  String _vatLabel(VatRate v) {
    final rateStr = v.rate == v.rate.roundToDouble() ? v.rate.toStringAsFixed(0) : v.rate.toString();
    return '${v.vatCode} $rateStr%';
  }
  // อัตรา VAT ที่ใช้แปลงราคาตามตารางราคา (ไม่มี VAT = 0 ไม่แปลง)
  double _lineVatRate(_LineForm l) => (l.vatType == null || l.vatType == 'NOVAT') ? 0 : l.vatRate;

  // VAT ตั้งต้นของสินค้า (ไม่มีในรายการอัตรา = อัตราแรก)
  void _applyDefaultVat(_LineForm l) {
    final code = l.item?.defaultVatType;
    final v = _vatRates.cast<VatRate?>().firstWhere((x) => x?.vatCode == code, orElse: () => _vatRates.isNotEmpty ? _vatRates.first : null);
    l.vatType = v?.vatCode ?? code;
    l.vatRate = v?.rate ?? 0;
  }
  // พนักงานขาย — ค่าเริ่มต้นจากลูกค้า หรือจากใบเสนอราคาที่ดึงรายการมา
  List<DocSalesperson> _salespersons = const [];

  @override
  void initState() {
    super.initState();
    widget.actions?.attach(this);
    _load();
  }

  @override
  void didUpdateWidget(covariant SoTransactionDetailWidget old) {
    super.didUpdateWidget(old);
    if (widget.actions != old.actions) {
      old.actions?.detach(this);
      widget.actions?.attach(this);
    }
    if (widget.transactionId != old.transactionId || widget.resetKey != old.resetKey) {
      _load();
    }
  }

  Timer? _priceResolveDebounce;

  @override
  void dispose() {
    widget.actions?.detach(this);
    _descCtrl.dispose();
    _poNoCtrl.dispose();
    _billDiscPctCtrl.dispose();
    _cashDiscCtrl.dispose();
    _creditMonthsCtrl.dispose();
    _creditDaysCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    _priceResolveDebounce?.cancel();
    super.dispose();
  }

  void _disposeLines() {
    final old = _lines;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final l in old) {
        l.dispose();
      }
    });
  }

  void _resetForm() {
    _id = null;
    _docType = _allowedDocTypes.isNotEmpty ? _allowedDocTypes.first : null;
    _docId = _docType?.id;
    _docNo = 'AUTO';
    _docDate = DateTime.now();
    _dueDate = null;
    _poNoCtrl.clear();
    _poDate = null;
    _customer = null;
    _warehouse = null;
    _descCtrl.clear();
    _credit = const DocCreditState();
    _status = 'Draft';
    _voidReason = null;
    _actions = const DocActions();
    _deposits = const [];
    _salespersons = const [];
    _refQuoteId = null;
    _refQuoteDocNoLabel = null;
    _dimSelections = {};
    _branchId = defaultDocBranchId();
    _currency = _currencies.cast<Currency?>().firstWhere((c) => c!.baseCurrencyFlag, orElse: () => null);
    _exchangeRate = _currency?.baseRate ?? 1;
    _priceIncludesVat = false;
    _billDiscPctCtrl.clear();
    _cashDiscCtrl.clear();
    _creditMonthsCtrl.clear();
    _creditDaysCtrl.clear();
    _disposeLines();
    _lines = [];
  }

  void _setBillDiscount(SoTransactionHeader h) {
    _billDiscPctCtrl.text = h.billDiscountPercent != 0 ? _LineForm._fmtPct(h.billDiscountPercent) : '';
    _cashDiscCtrl.text = h.cashDiscountAmount != 0 ? _LineForm._fmtPct(h.cashDiscountAmount) : '';
  }

  // ส่วนลดเกินยอด / ขั้นบันไดผิดรูปแบบ / ท้ายบิล % เกิน 100 / เงินสดเกินยอดคงเหลือ — backend ตรวจซ้ำ
  String? _salesDiscountError() {
    final isEnglish = _isEnglish;
    if (_billDiscPct < 0 || _billDiscPct > 100) return isEnglish ? 'Bill discount must be 0-100%' : 'ส่วนลดท้ายบิลต้องอยู่ระหว่าง 0-100%';
    double remaining = 0;
    for (final l in _lines) {
      final code = l.item?.itemCode ?? '';
      final step = parseStepDiscount(l.discountText);
      if (!step.valid) {
        return '$code: ${isEnglish ? 'discount must be % separated by + (max $maxDiscountSteps steps), e.g. 10+5+2' : 'ส่วนลดต้องเป็น % คั่นด้วย + ไม่เกิน $maxDiscountSteps ขั้น เช่น 10+5+2'}';
      }
      final entered = l.qtyOrdered * l.unitPriceFc;
      final own = entered * (1 - step.factor) + l.lineDiscountAmount;
      if (own > entered + 0.005) return '$code: ${isEnglish ? 'line discount exceeds the line amount' : 'ส่วนลดของรายการมากกว่ายอดของรายการ'}';
      remaining += entered - own;
    }
    remaining -= remaining * _billDiscPct / 100;
    if (_cashDisc < 0 || _cashDisc > remaining + 0.005) {
      return isEnglish ? 'Cash discount exceeds the remaining amount' : 'ส่วนลดเงินสดท้ายบิลมากกว่ายอดหลังส่วนลด';
    }
    return null;
  }

  Future<void> _load() async {
    final isEnglish = _isEnglish;
    setState(() => _isLoading = true);
    try {
      if (_allowedDocTypes.isEmpty) {
        final docTypes = await _service.fetchDocTypesByUser();
        _allowedDocTypes = docTypes.where((d) => d.isDocType && d.sysDocType == _soSysDocType).toList();
      }
      if (_currencies.isEmpty) {
        _currencies = await _currencyService.fetchActiveRows();
      }
      if (_vatRates.isEmpty) {
        _vatRates = (await _vatRateService.fetchRows()).where((v) => v.isActive).toList();
      }
      if (!_dimsLoaded) {
        final dims = await loadActiveDimensions();
        _dimTypes = dims.$1;
        _dimValues = dims.$2;
        _dimsLoaded = true;
      }
      if (_branches.isEmpty) {
        try {
          _branches = await BranchService().fetchActiveRows();
        } catch (_) {}
      }
      if (widget.transactionId == null && widget.copyFromId != null) {
        final h = await _service.fetchRow(widget.copyFromId!);
        _id = null;
        _docId = h.docId;
        _docType = _allowedDocTypes.isNotEmpty
            ? _allowedDocTypes.firstWhere((d) => d.id == h.docId, orElse: () => _allowedDocTypes.first)
            : null;
        _docNo = 'AUTO';
        _docDate = DateTime.now();
        _dueDate = null;
        _poNoCtrl.clear();
        _poDate = null;
        _customer = ArCustomer(id: h.customerId, customerCode: h.customerCode ?? '', customerNameTh: h.customerNameTh ?? '');
        _warehouse = ImWarehouse(id: h.warehouseId, warehouseCode: h.warehouseCode ?? '', warehouseNameTh: h.warehouseNameTh ?? '', warehouseNameEn: h.warehouseNameEn);
        _descCtrl.text = h.description ?? '';
        _status = 'Draft';
        _voidReason = null;
        _actions = const DocActions();
        _deposits = const [];
        _salespersons = const [];
        _refQuoteId = null;
        _refQuoteDocNoLabel = null;
        _dimSelections = {1: h.dim1Id, 2: h.dim2Id, 3: h.dim3Id, 4: h.dim4Id, 5: h.dim5Id};
        _branchId = h.branchId;
        _currency = _currencies.cast<Currency?>().firstWhere(
            (c) => c?.id == h.currencyId || c?.currencyCode == h.currencyCode, orElse: () => null);
        _exchangeRate = h.exchangeRate;
        _priceIncludesVat = h.priceIncludesVat;
        _setBillDiscount(h);
        final items = await Future.wait(h.details.map((d) => _itemService.fetchRow(d.itemId)));
        _disposeLines();
        _lines = [
          for (var i = 0; i < h.details.length; i++)
            _LineForm(
              item: items[i],
              qtyOrdered: h.details[i].qtyOrdered,
              unitPriceFc: h.details[i].unitPriceFc,
              discountPercent: h.details[i].discountPercent,
              discountText: h.details[i].discountText,
              lineDiscountAmount: h.details[i].lineDiscountAmount,
              vatType: h.details[i].vatType,
              vatRate: h.details[i].vatRate,
              uomId: h.details[i].uomId ?? items[i].baseUomId,
              uomCode: h.details[i].uomCode ?? items[i].baseUomCode,
              uomNameTh: h.details[i].uomId != null ? h.details[i].uomNameTh : items[i].baseUomNameTh,
              uomNameEn: h.details[i].uomId != null ? h.details[i].uomNameEn : items[i].baseUomNameEn,
              factor: h.details[i].conversionFactor,
              remark: h.details[i].description,
            ),
        ];
        for (final l in _lines) { _loadLineUoms(l); }
        // ใบเก่าก่อนมี VAT ต่อบรรทัด — ใบใหม่ใช้ VAT ตั้งต้นของสินค้า
        for (final l in _lines) {
          if (l.vatType == null) _applyDefaultVat(l);
        }
        // คำนวณวันครบกำหนดใหม่จากเงื่อนไขเครดิตของลูกค้าบน doc_date ใหม่ (วันนี้) — ไม่คัดลอกวันครบกำหนดเดิมมาตรงๆ
        // เพราะเอกสารที่คัดลอกเป็นธุรกรรมใหม่ที่เกิดขึ้นวันนี้ ไม่ใช่ของเดิมที่ย้อนวันที่ไป
        _creditMonthsCtrl.text = h.creditTermMonths?.toString() ?? '';
        _creditDaysCtrl.text = h.creditTermDays?.toString() ?? '';
        if (_creditMonths > 0 || _creditDays > 0) _dueDate = _calcDueDate(_docDate);
        if (_customer != null) _selectCustomer(_customer!, applyTerms: false);
      } else if (widget.transactionId == null) {
        _resetForm();
      } else {
        final h = await _service.fetchRow(widget.transactionId!);
        _id = h.id;
        _docId = h.docId;
        _docType = _allowedDocTypes.isNotEmpty
            ? _allowedDocTypes.firstWhere((d) => d.id == h.docId, orElse: () => _allowedDocTypes.first)
            : null;
        _docNo = h.docNo;
        _docDate = h.docDate;
        _dueDate = h.dueDate;
        _creditMonthsCtrl.text = h.creditTermMonths?.toString() ?? '';
        _creditDaysCtrl.text = h.creditTermDays?.toString() ?? '';
        _poNoCtrl.text = h.customerPoNo ?? '';
        _poDate = h.customerPoDate;
        _customer = ArCustomer(id: h.customerId, customerCode: h.customerCode ?? '', customerNameTh: h.customerNameTh ?? '');
        _warehouse = ImWarehouse(id: h.warehouseId, warehouseCode: h.warehouseCode ?? '', warehouseNameTh: h.warehouseNameTh ?? '', warehouseNameEn: h.warehouseNameEn);
        _descCtrl.text = h.description ?? '';
        _status = h.status;
        _voidReason = h.voidReason;
        _actions = h.actions;
        _approvalMode = h.approvalMode;
        _approvals = h.approvals;
        _deposits = h.deposits;
        _credit = h.credit;
        _salespersons = h.salespersons;
        _refQuoteId = h.refQuoteId;
        _refQuoteDocNoLabel = h.refQuoteDocNo;
        _dimSelections = {1: h.dim1Id, 2: h.dim2Id, 3: h.dim3Id, 4: h.dim4Id, 5: h.dim5Id};
        _branchId = h.branchId;
        _currency = _currencies.cast<Currency?>().firstWhere(
            (c) => c?.id == h.currencyId || c?.currencyCode == h.currencyCode, orElse: () => null);
        _exchangeRate = h.exchangeRate;
        _priceIncludesVat = h.priceIncludesVat;
        _setBillDiscount(h);
        // ดึง ImItem เต็มจาก itemId เสมอ ไม่ใช้ค่า snapshot (item_code/item_name) ที่บันทึกไว้ตอนสร้างเอกสารมาแสดง
        // ตรงๆ — มิเรอร์ po_transaction_detail_widget.dart ทุกประการ
        final items = await Future.wait(h.details.map((d) => _itemService.fetchRow(d.itemId)));
        _disposeLines();
        _lines = [
          for (var i = 0; i < h.details.length; i++)
            _LineForm(
              id: h.details[i].id,
              item: items[i],
              qtyOrdered: h.details[i].qtyOrdered,
              unitPriceFc: h.details[i].unitPriceFc,
              qtyDelivered: h.details[i].qtyDelivered,
              refQuoteDetailId: h.details[i].refQuoteDetailId,
              refQuoteDocNo: h.details[i].refQuoteDocNo,
              discountPercent: h.details[i].discountPercent,
              discountText: h.details[i].discountText,
              lineDiscountAmount: h.details[i].lineDiscountAmount,
              vatType: h.details[i].vatType,
              vatRate: h.details[i].vatRate,
              uomId: h.details[i].uomId ?? items[i].baseUomId,
              uomCode: h.details[i].uomCode ?? items[i].baseUomCode,
              uomNameTh: h.details[i].uomId != null ? h.details[i].uomNameTh : items[i].baseUomNameTh,
              uomNameEn: h.details[i].uomId != null ? h.details[i].uomNameEn : items[i].baseUomNameEn,
              factor: h.details[i].conversionFactor,
              remark: h.details[i].description,
            ),
        ];
        for (final l in _lines) { _loadLineUoms(l); }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _markClean();
    }
  }


  // พนักงานขายของลูกค้า → ค่าเริ่มต้นของเอกสาร (รายชื่ออย่างเดียว)
  Future<void> _loadCustomerSalespersons(int customerId) async {
    try {
      final c = await ArCustomerService().fetchRow(customerId);
      if (!mounted || _customer?.id != customerId) return;
      _applySalespersons(c.salespersons);
    } catch (_) {}
  }

  void _applySalespersons(List<DocSalesperson> src) {
    setState(() => _salespersons = DocSalesperson.namesOnly(src));
  }

  // ใบเสนอราคาที่ดึงรายการมา → ใช้พนักงานขายของใบเสนอราคา (ถ้ามี)
  Future<void> _loadQuoteSalespersons(int quoteId) async {
    try {
      final q = await _quoteService.fetchRow(quoteId);
      if (!mounted || q.salespersons.isEmpty) return;
      _applySalespersons(q.salespersons);
    } catch (_) {}
  }

  void _selectCustomer(ArCustomer c, {bool applyTerms = true}) {
    if (!_isReadOnly && c.id != null) _loadCustomerSalespersons(c.id!);
    setState(() {
      _customer = c;
      // ระยะเครดิตเริ่มต้นจากลูกค้า: due_date = doc_date + เดือน + วัน (สูตรเดียวกับ PO) ผู้ใช้แก้ไขต่อได้เสมอ
      if (applyTerms) {
        _creditMonthsCtrl.text = c.creditTermMonths > 0 ? '${c.creditTermMonths}' : '';
        _creditDaysCtrl.text = c.creditTermDays > 0 ? '${c.creditTermDays}' : '';
        if (_creditMonths > 0 || _creditDays > 0) _dueDate = _calcDueDate(_docDate);
      }
      // สกุลเงินหลักของลูกค้า (ar_customer.currency_code)
      if (c.currencyCode.isNotEmpty) {
        final matched = _currencies.cast<Currency?>().firstWhere((cur) => cur!.currencyCode == c.currencyCode, orElse: () => null);
        if (matched != null) {
          _currency = matched;
          _exchangeRate = matched.baseRate > 0 ? matched.baseRate : 1;
        }
      }
    });
    _reresolveAllLinesForCustomer();
  }

  // เลือก/เปลี่ยนลูกค้าแล้ว ให้ลองดึงราคาใหม่ให้ทุกบรรทัดที่ยังไม่ถูกผู้ใช้แก้ราคาเอง (รวมบรรทัดที่เพิ่มไว้ก่อนเลือก
  // ลูกค้า ซึ่งไม่เคย resolve มาก่อนเลย) — ไม่ใช้ debounce Timer ร่วมกับ _maybeReresolvePrice (ตัวนั้นมี Timer เดียว
  // ใช้ร่วมกันทุกบรรทัด ถ้าเรียกวนหลายบรรทัดจะตัดกันเอง เหลือแค่บรรทัดสุดท้ายที่ resolve จริง) เรียกตรงทันทีแทน
  // เพราะเป็น action ครั้งเดียวตอนเปลี่ยนลูกค้า ไม่ใช่การพิมพ์ต่อตัวอักษรที่ต้อง debounce — มิเรอร์
  // po_transaction_detail_widget.dart:_reresolveAllLinesForVendor ทุกประการ
  Future<void> _reresolveAllLinesForCustomer() async {
    final customer = _customer;
    if (customer == null) return;
    for (final line in _lines) {
      if (line.item == null || line.unitPriceFc != line.lastResolvedPrice) continue;
      final resolved = await _service.resolvePrice(
        itemId: line.item!.id!, customerId: customer.id!, qty: line.qtyOrdered,
        docDate: DateFormat('yyyy-MM-dd').format(_docDate), uomId: line.uomId ?? line.item!.baseUomId,
        currencyCode: _currency?.currencyCode, priceIncludesVat: _priceIncludesVat, vatRate: _lineVatRate(line),
      );
      if (!mounted || _customer != customer) return;
      if (resolved['unit_price_fc'] != null && line.unitPriceFc == line.lastResolvedPrice) {
        final price = double.tryParse(resolved['unit_price_fc'].toString()) ?? 0;
        setState(() { line.setPrice(price); line.lastResolvedPrice = price; });
      }
    }
  }

  Future<void> _addLine() async {
    final result = await showDialog<ImItem>(context: context, builder: (_) => const _ItemPickerDialog());
    if (result == null || !mounted) return;
    final line = _LineForm(item: result, qtyOrdered: 1, unitPriceFc: 0,
        uomId: result.baseUomId, uomCode: result.baseUomCode, uomNameTh: result.baseUomNameTh, uomNameEn: result.baseUomNameEn);
    _applyDefaultVat(line);
    setState(() => _lines.add(line));
    await _loadLineUoms(line, applyDefault: true); // หน่วยขายตั้งต้นของสินค้า
    if (!mounted) return;
    if (_customer != null) {
      final resolved = await _service.resolvePrice(
        itemId: result.id!, customerId: _customer!.id!, qty: 1, docDate: DateFormat('yyyy-MM-dd').format(_docDate),
        uomId: line.uomId ?? result.baseUomId,
        currencyCode: _currency?.currencyCode, priceIncludesVat: _priceIncludesVat, vatRate: _lineVatRate(line),
      );
      if (resolved['unit_price_fc'] != null && mounted) {
        final price = double.tryParse(resolved['unit_price_fc'].toString()) ?? 0;
        setState(() { line.setPrice(price); line.lastResolvedPrice = price; });
      }
    }
  }

  // เรียกซ้ำเมื่อจำนวนในบรรทัดเปลี่ยน เพราะ im_price_list มี tier ตาม min_qty — ถ้าจำนวนที่แก้ใหม่ควรได้ราคาขั้น
  // ต่างจากเดิม ต้องดึงราคามาใหม่ ไม่ใช่ตรึงราคาที่ resolve ไว้ครั้งเดียวตอนกดเพิ่มรายการ (qty=1 คงที่) เดิม —
  // debounce ไว้ไม่ยิง request ทุกตัวอักษรที่พิมพ์ และข้ามการ auto-fill ถ้าผู้ใช้แก้ราคาเองไปจากค่าที่ระบบเคย
  // auto-fill ให้แล้ว (ถือว่าตั้งใจ ไม่ทับราคาที่แก้เอง) — มิเรอร์ po_transaction_detail_widget.dart ทุกประการ
  void _maybeReresolvePrice(_LineForm line) {
    _priceResolveDebounce?.cancel();
    if (_customer == null || line.item == null) return;
    _priceResolveDebounce = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted || line.unitPriceFc != line.lastResolvedPrice) return;
      final resolved = await _service.resolvePrice(
        itemId: line.item!.id!, customerId: _customer!.id!, qty: line.qtyOrdered, docDate: DateFormat('yyyy-MM-dd').format(_docDate),
        uomId: line.uomId ?? line.item!.baseUomId,
        currencyCode: _currency?.currencyCode, priceIncludesVat: _priceIncludesVat, vatRate: _lineVatRate(line),
      );
      if (resolved['unit_price_fc'] != null && mounted && line.unitPriceFc == line.lastResolvedPrice) {
        final price = double.tryParse(resolved['unit_price_fc'].toString()) ?? 0;
        setState(() { line.setPrice(price); line.lastResolvedPrice = price; });
      }
    });
  }

  // ค่า NUMERIC จาก PostgreSQL ผ่าน pg driver มาเป็น String เสมอ (ไม่ใช่ num) — ต้อง parse ด้วย toString() เท่านั้น
  // ห้ามใช้ `as num?` ตรงๆ (จะ throw runtime TypeError) มิเรอร์ toDouble() ที่ใช้ทั่วทั้ง *_transaction.dart models
  double _quoteNum(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  // เพิ่มรายการเข้า SO จากบรรทัดที่ยังแปลงได้ของใบเสนอราคา (Quote) ที่อนุมัติแล้ว (multi-select ได้ ข้าม Quote
  // หลายใบในครั้งเดียว) มิเรอร์ _pickPrLines ใน po_transaction_detail_widget.dart ทุกประการ
  Future<void> _pickQuoteLines() async {
    final isEnglish = _isEnglish;
    List<Map<String, dynamic>> lines;
    try {
      lines = await _quoteService.fetchConvertibleLines();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
      return;
    }
    final alreadyPicked = _lines.map((l) => l.refQuoteDetailId).whereType<int>().toSet();
    final selectable = lines.where((l) => !alreadyPicked.contains(l['detail_id'] as int)).toList();
    if (selectable.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'No convertible Quote lines left' : 'ไม่มีรายการที่แปลงได้เหลืออยู่')));
      return;
    }
    final qtyCtrls = {for (final l in selectable) l['detail_id'] as int: TextEditingController(text: _fmtQty.format((l['qty_remaining'] as num).toDouble()))};
    final selected = {for (final l in selectable) l['detail_id'] as int: false};

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
            title: Text(isEnglish ? 'Select Lines from Sale Quote' : 'เลือกรายการจากใบเสนอราคา'),
            content: SizedBox(
              width: 620,
              height: 420,
              child: ListView.builder(
                itemCount: selectable.length,
                itemBuilder: (_, i) {
                  final l = selectable[i];
                  final id = l['detail_id'] as int;
                  final remaining = (l['qty_remaining'] as num).toDouble();
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Checkbox(value: selected[id], onChanged: (v) => setSt(() => selected[id] = v ?? false)),
                      Expanded(flex: 2, child: Text('${l['doc_no']}', style: const TextStyle(fontSize: 12, color: Colors.grey))),
                      Expanded(flex: 3, child: Text('${l['item_code'] ?? ''} ${l['item_name'] ?? ''}', overflow: TextOverflow.ellipsis)),
                      Expanded(
                        flex: 2,
                        child: Text('${isEnglish ? 'Remaining' : 'คงเหลือแปลงได้'}: ${_fmtQty.format(remaining)} ${_pickUomName(l)}', style: const TextStyle(fontSize: 12)),
                      ),
                      // ราคาเสนอของ Quote เป็นสกุลเงินของ Quote เอง ซึ่งอาจไม่ตรงกับสกุลเงินที่เลือกไว้ในใบสั่งขายนี้ —
                      // แสดงกำกับไว้เป็น hint เท่านั้น ผู้ใช้ต้องตรวจสอบ/แก้ราคาเองหลังเพิ่มรายการ ไม่ auto-convert ให้
                      Expanded(
                        flex: 1,
                        child: Text('@ ${_fmtQty.format(_quoteNum(l['unit_price_fc']))} ${l['currency_code'] ?? ''}'.trim(),
                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: qtyCtrls[id],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(isDense: true, border: const OutlineInputBorder(), labelText: isEnglish ? 'Qty' : 'จำนวน'),
                        ),
                      ),
                    ]),
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEnglish ? 'Add' : 'เพิ่ม')),
            ],
          )),
    );
    if (confirmed != true || !mounted) return;

    final pickedLines = selectable.where((l) => selected[l['detail_id']] == true && (double.tryParse(qtyCtrls[l['detail_id']]!.text) ?? 0) > 0).toList();
    if (pickedLines.isEmpty) return;
    final items = await Future.wait(pickedLines.map((l) => _itemService.fetchRow(l['item_id'] as int)));
    if (!mounted) return;
    setState(() {
      // ใบสั่งขายที่ยังไม่มีรายการ ใช้รูปแบบราคา (รวม VAT หรือไม่) ตามใบเสนอราคา — ถ้ามีรายการอยู่แล้วแปลงราคาให้ตรงกับใบนี้
      if (_lines.isEmpty) _priceIncludesVat = pickedLines.first['price_includes_vat'] == true;
      for (var i = 0; i < pickedLines.length; i++) {
        final l = pickedLines[i];
        final id = l['detail_id'] as int;
        final remaining = (l['qty_remaining'] as num).toDouble();
        final qty = (double.tryParse(qtyCtrls[id]!.text) ?? 0).clamp(0, remaining);
        final line = _LineForm(
          item: items[i],
          qtyOrdered: qty.toDouble(),
          unitPriceFc: _quoteNum(l['unit_price_fc']),
          refQuoteDetailId: id,
          refQuoteDocNo: l['doc_no']?.toString(),
          discountPercent: _quoteNum(l['discount_percent']),
          // หน่วยตามใบเสนอราคา (ใบเก่าไม่มีหน่วย = หน่วยหลัก)
          uomId: (l['uom_id'] as int?) ?? items[i].baseUomId,
          uomCode: (l['uom_code'] as String?) ?? items[i].baseUomCode,
          uomNameTh: l['uom_id'] != null ? l['uom_name_th'] as String? : items[i].baseUomNameTh,
          uomNameEn: l['uom_id'] != null ? l['uom_name_en'] as String? : items[i].baseUomNameEn,
          factor: l['conversion_factor'] == null ? 1 : _quoteNum(l['conversion_factor']),
        );
        // VAT ตามบรรทัดใบเสนอราคา (ใบเก่าที่ไม่มี VAT ต่อบรรทัด = VAT ตั้งต้นของสินค้า)
        final qVat = l['vat_type'] as String?;
        if (qVat != null && _vatRates.any((v) => v.vatCode == qVat)) {
          line.vatType = qVat;
          line.vatRate = _quoteNum(l['vat_rate']);
        } else {
          _applyDefaultVat(line);
        }
        final qIncl = l['price_includes_vat'] == true && qVat != null;
        if (line.vatType != 'NOVAT' && line.vatRate != 0 && qIncl != _priceIncludesVat) {
          line.setPrice(qIncl ? line.unitPriceFc * 100 / (100 + line.vatRate) : line.unitPriceFc * (100 + line.vatRate) / 100);
        }
        _lines.add(line);
      }
      _refQuoteId = pickedLines.first['header_id'] as int;
      _refQuoteDocNoLabel = pickedLines.first['doc_no'] as String?;
      // มิติ: ยังไม่ได้เลือกเลย = ใช้มิติของใบเสนอราคาใบแรกที่เลือก
      if (!_dimSelections.values.any((v) => v != null)) {
        _dimSelections = {for (var i = 1; i <= 5; i++) i: pickedLines.first['dim${i}_id'] as int?};
      }
      // สาขา: ใช้สาขาของใบเสนอราคาที่เลือก (ถ้ามี)
      _branchId = (pickedLines.first['branch_id'] as int?) ?? _branchId;
    });
    _loadQuoteSalespersons(_refQuoteId!);
  }

  // ชื่อหน่วยของบรรทัดใน picker (map จาก API)
  String _pickUomName(Map<String, dynamic> l) {
    final th = l['uom_name_th']?.toString() ?? '', en = l['uom_name_en']?.toString() ?? '';
    final n = _isEnglish && en.isNotEmpty ? en : th;
    return n.isNotEmpty ? n : (l['uom_code']?.toString() ?? '');
  }

  // หน่วยที่เลือกได้ของบรรทัด (หน่วยที่สินค้าอนุญาตให้ขาย) — applyDefault = ตั้งหน่วยขายตั้งต้นของสินค้า (บรรทัดใหม่)
  Future<void> _loadLineUoms(_LineForm l, {bool applyDefault = false}) async {
    final id = l.item?.id;
    if (id == null || _isReadOnly || l.refQuoteDetailId != null) return;
    try {
      final u = await _itemService.fetchItemUoms(id, purpose: 'SALES');
      if (!mounted || !_lines.contains(l)) return;
      l.uoms = u;
      final def = u.byId(u.defaultUomId);
      if (applyDefault && def != null && def.uomId != l.uomId) {
        _setLineUom(l, def, reresolve: false);
      } else {
        setState(() {});
      }
    } catch (_) {}
  }

  // เปลี่ยนหน่วยของบรรทัด — ราคาคูณตามอัตราใหม่ (ราคาต่อหน่วยหลักคงเดิม) แล้วดึงราคาตามตารางราคาของหน่วยใหม่
  void _setLineUom(_LineForm l, ImItemUomOption opt, {bool reresolve = true}) {
    final ratio = l.factor == 0 ? 1.0 : opt.factor / l.factor;
    setState(() {
      final auto = l.unitPriceFc == l.lastResolvedPrice;
      if (ratio != 1 && l.unitPriceFc != 0) {
        l.setPrice((l.unitPriceFc * ratio * 1e4).roundToDouble() / 1e4);
        if (auto) l.lastResolvedPrice = l.unitPriceFc;
      }
      l.uomId = opt.uomId;
      l.uomCode = opt.uomCode;
      l.uomNameTh = opt.uomNameTh;
      l.uomNameEn = opt.uomNameEn;
      l.factor = opt.factor;
    });
    if (reresolve) _maybeReresolvePrice(l);
  }

  String _lineUomName(_LineForm l) {
    final o = l.uoms?.byId(l.uomId);
    if (o != null) return o.displayName(_isEnglish);
    final n = _isEnglish && (l.uomNameEn ?? '').isNotEmpty ? l.uomNameEn! : (l.uomNameTh ?? '');
    return n.isNotEmpty ? n : (l.uomCode ?? '');
  }

  Widget _uomField(_LineForm l, bool isEnglish) {
    final opts = l.uoms?.units ?? const <ImItemUomOption>[];
    final it = l.item;
    final base = isEnglish && (it?.baseUomNameEn ?? '').isNotEmpty ? it!.baseUomNameEn! : (it?.baseUomNameTh ?? it?.baseUomCode ?? '');
    final tip = l.factor != 1 ? '1 ${_lineUomName(l)} = ${_fmtQty.format(l.factor)} $base' : null;
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13);
    Widget w;
    if (_isReadOnly || opts.length <= 1 || l.qtyDelivered > 0 || l.refQuoteDetailId != null) {
      w = _cBox(_lineUomName(l), right: false);
    } else {
      w = DropdownButtonFormField<int>(
        value: opts.any((u) => u.uomId == l.uomId) ? l.uomId : null,
        isExpanded: true,
        isDense: true,
        decoration: _cDec(fill: Colors.white),
        style: style?.copyWith(color: Colors.black87),
        hint: Text(_lineUomName(l), style: style),
        selectedItemBuilder: (_) => [for (final u in opts) Text(u.displayName(isEnglish), overflow: TextOverflow.ellipsis)],
        items: [
          for (final u in opts)
            DropdownMenuItem(
              value: u.uomId,
              child: Text(u.isBase ? u.displayName(isEnglish) : '${u.displayName(isEnglish)} (= ${_fmtQty.format(u.factor)} $base)',
                  overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) {
          final o = l.uoms?.byId(v);
          if (o != null && o.uomId != l.uomId) _setLineUom(l, o);
        },
      );
    }
    return tip == null ? w : Tooltip(message: tip, child: w);
  }

  // ข้อมูลที่บันทึก — ใช้ทั้งตอนบันทึกและตรวจการแก้ไขค้าง
  ({SoTransactionHeader header, List<SoTransactionDetail> details}) _savePayload() {
    final header = SoTransactionHeader(
      id: _id ?? 0, docId: _docId ?? 0, docNo: _docNo, docDate: _docDate,
      customerId: _customer!.id!, warehouseId: _warehouse!.id, dueDate: _dueDate,
      creditTermMonths: int.tryParse(_creditMonthsCtrl.text.trim()), creditTermDays: int.tryParse(_creditDaysCtrl.text.trim()),
      customerPoNo: _poNoCtrl.text.trim().isEmpty ? null : _poNoCtrl.text.trim(), customerPoDate: _poDate,
      currencyId: _currency?.id, currencyCode: _currency?.currencyCode ?? CurrencyService.baseCode, exchangeRate: _exchangeRate,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      refQuoteId: _refQuoteId,
      priceIncludesVat: _priceIncludesVat,
      billDiscountPercent: _billDiscPct,
      cashDiscountAmount: _cashDisc,
      dim1Id: _dimSelections[1], dim2Id: _dimSelections[2], dim3Id: _dimSelections[3],
      dim4Id: _dimSelections[4], dim5Id: _dimSelections[5],
      branchId: _branchId,
    );
    final details = _lines
        .map((l) => SoTransactionDetail(
              id: l.id, lineNo: 0, itemId: l.item!.id!, itemCode: l.item!.itemCode, itemName: l.item!.itemNameTh,
              uomId: l.uomId, qtyOrdered: l.qtyOrdered, unitPriceFc: l.unitPriceFc, refQuoteDetailId: l.refQuoteDetailId,
              discountPercent: l.discountPercent, vatType: l.vatType, vatRate: l.vatRate,
              discountText: parseStepDiscount(l.discountText).factor == 1 ? '' : l.discountText.trim(),
              lineDiscountAmount: l.lineDiscountAmount,
              description: l.remark,
            ))
        .toList();
    return (header: header, details: details);
  }

  Future<void> _save() async {
    final isEnglish = _isEnglish;
    if (_docType == null) { _warn(isEnglish ? 'Please select a document type' : 'กรุณาเลือกประเภทเอกสาร'); return; }
    if (_customer == null) { _warn(isEnglish ? 'Please select a customer' : 'กรุณาระบุลูกค้า'); return; }
    if (_warehouse == null) { _warn(isEnglish ? 'Please select a warehouse' : 'กรุณาระบุคลังต้นทาง'); return; }
    if (_lines.isEmpty) { _warn(isEnglish ? 'At least 1 line is required' : 'ต้องมีรายการสั่งขายอย่างน้อย 1 รายการ'); return; }
    for (final l in _lines) {
      if (l.item == null || l.qtyOrdered <= 0) { _warn(isEnglish ? 'Please complete every line' : 'กรุณากรอกรายการให้ครบถ้วน'); return; }
    }
    final discErr = _salesDiscountError();
    if (discErr != null) { _warn(discErr); return; }
    setState(() => _isSaving = true);
    try {
      final p = _savePayload();
      final header = p.header, details = p.details;
      if (_id == null) {
        await _service.createTransaction(header: header, details: details, salespersons: _salespersons);
      } else {
        await _service.updateTransaction(id: _id!, header: header, details: details, salespersons: _salespersons);
      }
      _markClean();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Saved' : 'บันทึกสำเร็จ')));
        widget.onSaveSuccess();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Save failed: $e' : 'บันทึกล้มเหลว: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmAction(String titleTh, String titleEn, String bodyTh, String bodyEn, Future<SoTransactionHeader> Function() action) async {
    final isEnglish = _isEnglish;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEnglish ? titleEn : titleTh),
        content: Text(isEnglish ? bodyEn : bodyTh),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEnglish ? 'Confirm' : 'ยืนยัน')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isSaving = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Done' : 'สำเร็จ')));
        await _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ส่งอนุมัติ — ตรวจวงเงินเครดิตก่อน: เกินวงเงินและยังไม่ได้รับอนุมัติ ถามว่าจะบันทึกร่างและขออนุมัติเกินวงเงินไหม
  Future<void> _submit(int menuId) async {
    if (_customer?.id != null && _id != null) {
      final go = await checkCreditBeforePost(
        context,
        service: _creditService,
        customerId: _customer!.id!,
        docId: _id,
        amount: _creditAmount,
        credit: _credit,
        saveDraft: () async {
          await _save();
          return _id;
        },
        onRequested: _load,
      );
      if (!go || !mounted) return;
    }
    await _confirmAction(
        'ยืนยันการส่งอนุมัติ', 'Confirm Submit for Approval',
        'ส่งอนุมัติใบสั่งขาย $_docNo? ระหว่างรออนุมัติจะแก้ไขไม่ได้ หลังอนุมัติแล้วใบส่งสินค้า (DLN) จึงอ้างอิงได้',
        'Submit SO $_docNo for approval? It cannot be edited while waiting. DLN can reference it once approved.',
        () => _service.submitTransaction(_id!, menuId: menuId));
  }

  // ถอย / ยกเลิก / ลบ — ต้องกรอกเหตุผล (บันทึกในประวัติ)
  Future<void> _reasonAction({
    required String title,
    required String message,
    required String confirmLabel,
    required Color color,
    required Future<void> Function(String reason) action,
    bool closeAfter = false,
  }) async {
    final isEnglish = _isEnglish;
    final reason = await showDocReasonDialog(context,
        isEnglish: isEnglish, title: title, message: message, confirmLabel: confirmLabel, confirmColor: color);
    if (reason == null || !mounted) return;
    setState(() => _isSaving = true);
    try {
      await action(reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Done' : 'สำเร็จ')));
      if (closeAfter) {
        widget.onSaveSuccess();
      } else {
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _reverse() {
    final isEnglish = _isEnglish;
    final fromClosed = _status == 'Closed';
    _reasonAction(
      title: fromClosed ? (isEnglish ? 'Reopen Sales Order' : 'ถอยการปิดใบสั่งขาย') : (isEnglish ? 'Reverse to Draft' : 'ถอยเป็นร่าง'),
      message: fromClosed
          ? (isEnglish
              ? 'Reopen this SO? Its status will be recalculated from the deliveries that reference it.'
              : 'ถอยการปิดใบสั่งขายนี้? สถานะจะคำนวณใหม่จากใบส่งสินค้าที่อ้างอิง')
          : (isEnglish
              ? 'Reverse this SO to draft? Pending approvals are skipped. You can edit it and submit it again with the same number.'
              : 'ถอยใบสั่งขายนี้เป็นร่าง? ผู้อนุมัติที่ยังไม่ตัดสินจะถูกข้าม แก้ไขแล้วส่งอนุมัติใหม่ได้ด้วยเลขที่เดิม'),
      confirmLabel: fromClosed ? (isEnglish ? 'Reopen' : 'ถอยการปิด') : (isEnglish ? 'Reverse to Draft' : 'ถอยเป็นร่าง'),
      color: Colors.orange[800]!,
      action: (r) => _service.reverseTransaction(_id!, r),
    );
  }

  void _voidDoc() {
    final isEnglish = _isEnglish;
    _reasonAction(
      title: isEnglish ? 'Void Sales Order' : 'ยกเลิกใบสั่งขาย',
      message: isEnglish
          ? 'Void this SO? It will no longer be usable.'
          : 'ยกเลิกใบสั่งขายนี้? จะนำไปอ้างอิงไม่ได้อีก',
      confirmLabel: isEnglish ? 'Void' : 'ยกเลิกใบสั่งขาย',
      color: Colors.red[700]!,
      action: (r) => _service.voidTransaction(_id!, r),
    );
  }

  void _deleteDoc() {
    final isEnglish = _isEnglish;
    _reasonAction(
      title: isEnglish ? 'Delete Draft' : 'ลบร่าง',
      message: isEnglish
          ? 'Delete this draft? It will be kept as Deleted for audit and cannot be used again.'
          : 'ลบร่างใบสั่งขายนี้? ระบบเก็บไว้ด้วยสถานะ "ลบแล้ว" เพื่อตรวจสอบ และนำกลับมาใช้ไม่ได้',
      confirmLabel: isEnglish ? 'Delete' : 'ลบ',
      color: Colors.red[700]!,
      action: (r) => _service.deleteTransaction(_id!, r),
      closeAfter: true,
    );
  }

  // ปุ่มที่ทำไม่ได้: ล็อกและแสดงเหตุผลเมื่อชี้เมาส์
  // ── ปุ่มของเอกสาร (แสดงบน AppBar ของหน้าจอ แทนแถวปุ่มท้ายหน้าเดิม) — ปุ่ม "ปิด" ตัดออก (ใช้ลูกศรย้อนกลับ) ──
  List<DocBarAction> _barActions(BuildContext context, bool en) {
    final perm = MenuScope.of(context);
    final canApprove = perm?.canApprove ?? false;
    final canCreate = perm?.canCreate ?? false;
    final busy = _isSaving;
    VoidCallback? guard(DocBlock? b, VoidCallback f) => b != null || busy ? null : f;
    final canSubmit = _isEditable && _id != null && !widget.viewOnly && perm?.id != null;
    final a = <DocBarAction>[];
    if (_id != null && canCreate) {
      a.add(DocBarAction.secondary(en ? 'Copy as New' : 'คัดลอกเป็นใบใหม่', busy ? null : () => widget.onCopyRequested?.call(_id!), DocBarColors.neutral));
    }
    if (_isEditable && _id != null && widget.canDelete && !widget.viewOnly) {
      a.add(DocBarAction.secondary(en ? 'Delete' : 'ลบ', guard(_actions.deleteBlock, _deleteDoc), DocBarColors.delete, tooltip: _actions.deleteBlock?.text(en)));
    }
    if ((['Approved', 'PartiallyDelivered', 'FullyDelivered', 'Closed'].contains(_status) && canApprove ||
            _status == 'Submitted') && _id != null && !widget.viewOnly) {
      a.add(DocBarAction.secondary(
          _status == 'Closed' ? (en ? 'Reopen' : 'ถอยการปิด') : (en ? 'Reverse to Draft' : 'ถอยเป็นร่าง'),
          guard(_actions.reverseBlock, _reverse), DocBarColors.reverse, tooltip: _actions.reverseBlock?.text(en)));
    }
    if (_isEditable && !widget.viewOnly) {
      a.add(canSubmit
          ? DocBarAction.secondary(en ? 'Save' : 'บันทึก', busy ? null : _save, DocBarColors.save)
          : DocBarAction.primary(en ? 'Save' : 'บันทึก', busy ? null : _save, DocBarColors.post));
    }
    // ส่งอนุมัติ — เข้าคิวผู้อนุมัติของเมนู (ไม่มีผู้อนุมัติ: ตามตัวเลือกของเมนู ให้ผ่าน/ไม่ให้ผ่าน)
    if (canSubmit) {
      a.add(DocBarAction.primary(en ? 'Submit' : 'ส่งอนุมัติ', busy ? null : () => _submit(perm!.id), DocBarColors.submit));
    }
    if (['Approved', 'PartiallyDelivered', 'FullyDelivered'].contains(_status) && canApprove && !widget.viewOnly) {
      a.add(DocBarAction.primary(en ? 'Close' : 'ปิดใบสั่งขาย', busy ? null : () => _confirmAction(
          'ยืนยันปิดใบสั่งขาย', 'Close Sale Order',
          'ปิดใบสั่งขายนี้? ใช้เมื่อไม่มีการส่งสินค้าเพิ่มแล้ว (แม้ยังส่งไม่ครบ 100%)${orderDepositCloseNote(_deposits, false)}',
          'Close this SO? Use this when no more delivery is expected (even if not 100% delivered).${orderDepositCloseNote(_deposits, true)}',
          () => _service.closeTransaction(_id!)), DocBarColors.post));
    }
    if (['Approved', 'PartiallyDelivered', 'FullyDelivered'].contains(_status) && _id != null && canApprove && !widget.viewOnly) {
      a.add(DocBarAction.primary(en ? 'Void' : 'ยกเลิก', guard(_actions.voidBlock, _voidDoc), DocBarColors.voidBg, tooltip: _actions.voidBlock?.text(en)));
    }
    return a;
  }

  @override
  Widget buildAppBarActions(BuildContext context, bool en) =>
      _isLoading ? const SizedBox.shrink() : buildDocBarActions(context, _barActions(context, en), busy: _isSaving, isEnglish: en);

  // ── มีการแก้ไขค้าง — ข้อมูลที่จะบันทึกต่างจากตอนโหลดเสร็จ (เฉพาะสถานะที่แก้ไขได้) ──
  String? _cleanFingerprint;

  String _formFingerprint() {
    try {
      final p = _savePayload();
      return docFingerprint([p.header, p.details, _salespersons]);
    } catch (_) {
      return 'incomplete|${docFingerprint([_customer?.id, _warehouse?.id, _lines.length, _descCtrl.text])}';
    }
  }

  void _markClean() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cleanFingerprint = _formFingerprint();
    });
  }

  @override
  bool get isDirty {
    if (_isLoading || _isSaving || widget.viewOnly || !(_isEditable)) return false;
    return _cleanFingerprint != null && _cleanFingerprint != _formFingerprint();
  }

  void _warn(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.orange));
  }

  String _docTypeLabel(ModuleDocument d) => _isEnglish && d.docNameEng.isNotEmpty ? d.docNameEng : d.docNameThai;

  String _currencyLabel(Currency c) => _isEnglish && c.currencyNameEng.isNotEmpty ? c.currencyNameEng : c.currencyNameThai;

  String get _baseCurrencyCode =>
      _currencies.cast<Currency?>().firstWhere((c) => c!.baseCurrencyFlag, orElse: () => null)?.currencyCode ?? CurrencyService.baseCode;

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

  Widget _footerAmount(double v) =>
      Padding(padding: const EdgeInsets.only(right: 7), child: Text(_fmt.format(v), style: _numStyle.copyWith(fontWeight: FontWeight.bold)));

  Widget _footerLabel(String t) => Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, softWrap: false, overflow: TextOverflow.visible));

  Widget _sumRow(String label, double v, {bool line = false, bool neg = false, Color? color}) => Container(
        padding: EdgeInsets.only(top: line ? 7 : 3, bottom: 3),
        margin: EdgeInsets.only(top: line ? 4 : 0),
        decoration: line ? const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFDDE3EA)))) : null,
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: color ?? const Color(0xFF33404D)))),
          Text(_fmt.format(v), style: _numStyle.copyWith(fontWeight: FontWeight.w600, color: color ?? (neg ? _errRed : null))),
        ]),
      );


  // แถบความคืบหน้าต่อบรรทัด (PR สั่งซื้อแล้ว / PO รับแล้ว) — ครบ = เขียว
  Widget _progress(double done, double total, String tip) {
    final p = total <= 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    final full = p >= 0.9999;
    return Tooltip(
      message: tip,
      child: Container(
        height: _cellH,
        decoration: BoxDecoration(color: const Color(0xFFF3F5F7), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFDDE3EA))),
        child: Stack(children: [
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: p,
              child: Container(
                  decoration: BoxDecoration(
                      color: full ? const Color(0xFFCDEBD6) : const Color(0xFFDCE9F7), borderRadius: BorderRadius.circular(3))),
            ),
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 7),
                child: Text(done > 0 ? _fmtQty.format(done) : '—',
                    style: _numStyle.copyWith(
                        fontWeight: FontWeight.w600, color: full ? const Color(0xFF1E6B3A) : (done > 0 ? const Color(0xFF1E4F8F) : _ink2))),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ช่องรหัส+ชื่อสินค้าในตาราง (เลือกตอนเพิ่มรายการ)
  Widget _itemBox(ImItem? it) {
    final name = it == null ? '' : (_isEnglish && (it.itemNameEn ?? '').isNotEmpty ? it.itemNameEn! : it.itemNameTh);
    return Tooltip(
      message: '${it?.itemCode ?? ''}  $name',
      child: Container(
        height: _cellH,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: _isReadOnly ? _hRo : Colors.white,
          border: Border.all(color: const Color(0xFFC3C9D0)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: it?.itemCode ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: '  $name', style: const TextStyle(color: _ink2)),
          ]),
          style: const TextStyle(fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _pickBox(String label, {required String? code, required String? name, required String emptyText, VoidCallback? onTap, VoidCallback? onClear, bool req = false, bool auto = false}) =>
      InkWell(
        onTap: _isReadOnly ? null : onTap,
        child: InputDecorator(
          decoration: _hDec(label, req: req, auto: auto, suffixIcon: _isReadOnly || onTap == null ? null : _searchIcon),
          child: Row(children: [
            Expanded(
              child: code == null
                  ? Text(emptyText, style: TextStyle(color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis)
                  : Text.rich(
                      TextSpan(children: [
                        TextSpan(text: code, style: const TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: '  ${name ?? ''}', style: const TextStyle(color: _ink2)),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
            ),
            if (!_isReadOnly && code != null && onClear != null)
              InkWell(onTap: onClear, child: const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.clear, size: 14, color: Colors.grey))),
          ]),
        ),
      );

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
      onSelected: (val) => setState(() => _dimSelections[dimType.slotNo] = val?.id),
    );
  }

  String _warehouseName(ImWarehouse w) => _isEnglish && (w.warehouseNameEn ?? '').isNotEmpty ? w.warehouseNameEn! : w.warehouseNameTh;

  String _salespersonNames(bool isEnglish) => _salespersons
      .map((s) => isEnglish && (s.salespersonNameEng ?? '').isNotEmpty ? s.salespersonNameEng! : s.salespersonNameThai)
      .join(', ');

  // พนักงานขาย — แก้ใน dialog (แบบหน้ารายละเอียด IM)
  Future<void> _editSalespersons(bool isEnglish) async {
    var list = List<DocSalesperson>.from(_salespersons);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(isEnglish ? 'Salespersons' : 'พนักงานขาย', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: SalespersonSplitEditor(items: list, isEnglish: isEnglish, onChanged: (l) => setD(() => list = l)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEnglish ? 'OK' : 'ตกลง')),
          ],
        ),
      ),
    );
    if (ok == true && mounted) setState(() => _salespersons = list);
  }

  Widget _salespersonField(bool isEnglish) => InkWell(
        onTap: _isReadOnly ? null : () => _editSalespersons(isEnglish),
        child: InputDecorator(
          decoration: _hDec(isEnglish ? 'Salespersons' : 'พนักงานขาย',
              auto: true, suffixIcon: _isReadOnly ? null : const Icon(Icons.edit, size: 16, color: Color(0xFF0F6E6E))),
          child: Text(_salespersons.isEmpty ? (isEnglish ? '— Not specified —' : '— ไม่ระบุ —') : _salespersonNames(isEnglish),
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _salespersons.isEmpty ? Colors.grey.shade600 : null)),
        ),
      );

  // ส่วนลดท้ายบิล (กรอบ 40) — ด้านซ้ายของการ์ดสรุปยอด
  Widget _billDiscField(String label, TextEditingController ctrl) => TextFormField(
        controller: ctrl,
        readOnly: _isReadOnly,
        textAlign: TextAlign.right,
        style: _numStyle,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: _hDec(label),
        onChanged: (_) => setState(() {}),
      );

  // ยอดส่วนลดสกุลเงินหลัก แยก ส่วนลดรายการ / ส่วนลดท้ายบิล (ตามสัดส่วนของส่วนลดที่ปันส่วน)
  ({double item, double bill}) _discountSplit(double totalDiscLc) {
    final sd = _salesDiscounts();
    final own = sd.values.fold<double>(0, (s, d) => s + d.own);
    final bill = sd.values.fold<double>(0, (s, d) => s + d.bill);
    if (own + bill <= 0) return (item: totalDiscLc, bill: 0);
    final b = _r2(totalDiscLc * bill / (own + bill));
    return (item: _r2(totalDiscLc - b), bill: b);
  }

  // ── การ์ดข้อมูลเอกสาร: 4 กลุ่มสี (เหมือน IM / AR / AP) — fix ด้านบน, ย่อเป็นแถบสรุปได้ ─────────────────────
  Widget _buildHeaderSection() {
    final isEnglish = _isEnglish;
    final isBase = _currency?.baseCurrencyFlag ?? true;
    final branch = findBranch(_branches, _branchId);

    final titleRow = Row(children: [
      Expanded(
        child: Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(isEnglish ? 'Document Header' : 'ข้อมูลเอกสาร', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          if (_docNo.isNotEmpty && _docNo != 'AUTO')
            Text(_docNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F5C5C))),
          docStatusBadge(_status, label: soTransactionStatusLabel(_status, isEnglish)),
        ]),
      ),
      // วงเงินเครดิตของลูกค้า: อยู่ในวงเงิน = แถบสั้นบรรทัดเดียว, เกินวงเงิน/มีคำขอ = แผงขอ/อนุมัติเต็ม (แบบหัวการ์ด IM)
      if (_customer?.id != null && (_isEditable || _credit.status != null))
        Flexible(
          child: Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: CreditLimitPanel(
              compact: true,
              service: _creditService,
              customerId: _customer!.id,
              docId: _id,
              docNo: _docNo,
              amount: _creditAmount,
              credit: _credit,
              isDraft: _isEditable && !widget.viewOnly,
              onChanged: _load,
            ),
          ),
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
        value: _docType,
        isExpanded: true,
        isDense: true,
        decoration: _hDec(isEnglish ? 'Document Type' : 'ประเภทเอกสาร', req: true, forcedReadOnly: _id != null),
        items: _allowedDocTypes
            .map((d) => DropdownMenuItem(value: d, child: Text('${d.docCode} ${_docTypeLabel(d)}', overflow: TextOverflow.ellipsis)))
            .toList(),
        onChanged: (_isReadOnly || _id != null) ? null : (v) => setState(() { _docType = v; _docId = v?.id; }),
      ),
      _hRow([
        InputDecorator(
          decoration: _hDec(isEnglish ? 'Doc No.' : 'เลขที่เอกสาร', auto: true, forcedReadOnly: _id != null),
          child: Text(_docNo == 'AUTO' ? (isEnglish ? 'Auto' : 'อัตโนมัติ') : _docNo,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _docNo == 'AUTO' ? Colors.grey.shade600 : null)),
        ),
        _datePick(isEnglish ? 'Doc Date' : 'วันที่เอกสาร', _docDate, () async {
          final picked = await showDatePicker(context: context, initialDate: _docDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (picked != null) {
            setState(() {
              _docDate = picked;
              if (_creditMonths > 0 || _creditDays > 0) _dueDate = _calcDueDate(_docDate);
            });
          }
        }, req: true, auto: true),
      ]),
    ]);

    // ② ลูกค้า / คลังต้นทาง (ใบเสนอราคาไม่บังคับ)
    final g2 = docFilterGroup(2, isEnglish ? 'Customer / Source' : 'ลูกค้า / คลังต้นทาง', color: _gParty, [
      _pickBox(
        isEnglish ? 'Customer' : 'ลูกค้า',
        req: true,
        code: _customer?.customerCode,
        name: _customer?.customerNameTh,
        emptyText: isEnglish ? 'Click to select customer' : 'คลิกเพื่อเลือกลูกค้า',
        onTap: () => ArCustomerListWidget.search(context, onSelected: _selectCustomer),
      ),
      _pickBox(
        isEnglish ? 'Source Warehouse' : 'คลังต้นทาง',
        req: true,
        auto: true,
        code: _warehouse?.warehouseCode,
        name: _warehouse == null ? null : _warehouseName(_warehouse!),
        emptyText: isEnglish ? 'Click to select warehouse' : 'คลิกเพื่อเลือกคลัง',
        onTap: () => ImWarehouseListWidget.search(context, onSelected: (w) => setState(() {
              _warehouse = w;
              _branchId ??= w.branchId; // ยังไม่มีสาขา → ใช้สาขาของคลัง
            })),
      ),
      _hRow([
        TextFormField(
          controller: _poNoCtrl,
          readOnly: _isReadOnly,
          inputFormatters: [LengthLimitingTextInputFormatter(50)],
          decoration: _hDec(isEnglish ? 'Customer PO No.' : 'เลขที่ใบสั่งซื้อลูกค้า'),
        ),
        _datePick(isEnglish ? 'Customer PO Date' : 'วันที่ใบสั่งซื้อลูกค้า', _poDate, () async {
          final picked = await showDatePicker(context: context, initialDate: _poDate ?? _docDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (picked != null) setState(() => _poDate = picked);
        }, onClear: () => setState(() => _poDate = null)),
      ]),
      // ใบเสนอราคาต้นทาง — เติมเมื่อดึงรายการจากใบเสนอราคา (อ่านอย่างเดียว)
      InputDecorator(
        decoration: _hDec(isEnglish ? 'Quotation' : 'อ้างอิงใบเสนอราคา', forcedReadOnly: true),
        child: Text(_refQuoteDocNoLabel ?? '—',
            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: _refQuoteDocNoLabel != null ? FontWeight.bold : null, color: _ink2)),
      ),
    ]);

    // ③ การเงิน
    final g3 = docFilterGroup(3, isEnglish ? 'Financial Terms' : 'เงื่อนไขการเงิน', color: _gFin, [
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
        _datePick(isEnglish ? 'Due Date' : 'วันครบกำหนด', _dueDate, () async {
          final picked = await showDatePicker(context: context, initialDate: _dueDate ?? _docDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (picked != null) setState(() => _dueDate = picked);
        }, auto: true, onClear: () => setState(() => _dueDate = null)),
      ]),
      _hRow([
        DropdownButtonFormField<Currency>(
          value: _currency,
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
                  setState(() { _currency = v; _exchangeRate = v?.baseRate ?? 1; });
                  _reresolveAllLinesForCustomer(); // ใช้ตารางราคาตามสกุลเงินของเอกสาร
                },
        ),
        TextFormField(
          key: ValueKey('so_rate_${widget.resetKey}_${_id}_${_currency?.currencyCode}'),
          initialValue: _exchangeRate.toStringAsFixed(6),
          readOnly: _isReadOnly || isBase,
          textAlign: TextAlign.right,
          style: _numStyle,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: _hDec(isEnglish ? 'Exchange Rate' : 'อัตราแลกเปลี่ยน', auto: true, forcedReadOnly: isBase),
          onChanged: (v) => setState(() => _exchangeRate = double.tryParse(v) ?? 1),
        ),
      ]),
    ]);

    // ④ เพิ่มเติม
    final g4 = docFilterGroup(4, isEnglish ? 'More' : 'เพิ่มเติม', color: _gMore, [
      _pickBox(
        isEnglish ? 'Branch' : 'สาขา',
        code: branch?.branchCode,
        name: branch == null ? null : (isEnglish && branch.branchNameEng.isNotEmpty ? branch.branchNameEng : branch.branchNameThai),
        emptyText: isEnglish ? '— Not specified —' : '— ไม่ระบุสาขา —',
        auto: true,
        onTap: () async {
          final r = await showUserBranchPicker(context, branches: _branches, selectedId: _branchId, isEnglish: isEnglish);
          if (r != null && mounted) setState(() => _branchId = r.$2?.id);
        },
      ),
      _salespersonField(isEnglish),
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
          if (_headerExpanded) _groupLayout([g1, g2, g3, g4], const [9, 12, 12, 12]) else _headerSummary(isEnglish),
        ]),
      ),
    );
  }

  // แถบสรุปตอนย่อการ์ด — จุดสีบอกกลุ่มที่มา
  Widget _headerSummary(bool isEnglish) {
    Widget item(Color c, String label, String value) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 6),
          Text('$label ', style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700)),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(value, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
          ),
        ]);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFF6F8FA), borderRadius: BorderRadius.circular(4)),
      child: Wrap(spacing: 22, runSpacing: 6, children: [
        if (_docType != null) item(_gDoc, isEnglish ? 'Type' : 'ประเภท', '${_docType!.docCode} ${_docTypeLabel(_docType!)}'),
        item(_gDoc, isEnglish ? 'Date' : 'วันที่', _dateFmt.format(_docDate)),
        if (_customer != null) item(_gParty, isEnglish ? 'Customer' : 'ลูกค้า', '${_customer!.customerCode} ${_customer!.customerNameTh}'),
        if (_warehouse != null) item(_gParty, isEnglish ? 'Warehouse' : 'คลัง', '${_warehouse!.warehouseCode} ${_warehouseName(_warehouse!)}'),
        if (_poNoCtrl.text.trim().isNotEmpty) item(_gParty, isEnglish ? 'Customer PO' : 'ใบสั่งซื้อลูกค้า', _poNoCtrl.text.trim()),
        if (_refQuoteDocNoLabel != null) item(_gParty, isEnglish ? 'Quote' : 'ใบเสนอราคา', _refQuoteDocNoLabel!),
        if (_creditMonths > 0 || _creditDays > 0 || _dueDate != null)
          item(_gFin, isEnglish ? 'Credit' : 'เครดิต', [
            if (_creditMonths > 0) isEnglish ? '$_creditMonths mo' : '$_creditMonths เดือน',
            if (_creditDays > 0) isEnglish ? '$_creditDays d' : '$_creditDays วัน',
            if (_dueDate != null) '${isEnglish ? 'due' : 'ครบ'} ${_dateFmt.format(_dueDate!)}',
          ].join(' · ')),
        if (_currency != null)
          item(_gFin, isEnglish ? 'Currency' : 'สกุลเงิน',
              _currency!.baseCurrencyFlag ? _currency!.currencyCode : '${_currency!.currencyCode} @ ${_exchangeRate.toStringAsFixed(4)}'),
        if (_salespersons.isNotEmpty) item(_gMore, isEnglish ? 'Salespersons' : 'พนักงานขาย', _salespersonNames(isEnglish)),
        if (_descCtrl.text.trim().isNotEmpty) item(_gMore, isEnglish ? 'Description' : 'คำอธิบาย', _descCtrl.text.trim()),
      ]),
    );
  }

  // ── การ์ดรายการ: ตารางแบบการ์ดรายการสินค้าของ IM (ช่อง 36, 4 กลุ่มสี) ──────────────────
  Widget _buildLinesSection() {
    final isEnglish = _isEnglish;
    final cur = _currency?.currencyCode ?? _baseCurrencyCode;
    final amtLabel = isEnglish ? 'Amount' : 'จำนวนเงิน';
    final showProgress = !['Draft', 'Rejected', 'Submitted'].contains(_status) || _lines.any((l) => l.qtyDelivered > 0);
    final sd = _salesDiscounts();
    final cols = <(String, double, int, bool)>[
      ('#', 28, 0, false),
      (isEnglish ? 'Item *' : 'สินค้า *', 0, 1, false),
      (isEnglish ? 'Qty' : 'จำนวน', 80, 2, true),
      (isEnglish ? 'Unit' : 'หน่วย', 92, 2, false),
      ('${isEnglish ? 'Unit Price' : 'ราคา/หน่วย'} ($cur)', 108, 3, true),
      (isEnglish ? 'Disc % (10+5)' : 'ส่วนลด % (10+5)', 92, 3, true),
      (isEnglish ? 'Disc (amt)' : 'ส่วนลด (เงิน)', 88, 3, true),
      (isEnglish ? 'Net Disc' : 'ส่วนลดสุทธิ', 92, 3, true),
      ('VAT', 100, 3, false),
      ('$amtLabel ($_baseCurrencyCode)', 116, 3, true),
      (isEnglish ? 'Quotation' : 'ใบเสนอราคา', 112, 4, false),
      if (showProgress) (isEnglish ? 'Delivered' : 'ส่งแล้ว', 100, 4, true),
      (isEnglish ? 'Remark' : 'หมายเหตุ', 0, 4, false),
      ('', 36, 0, false),
      if (!_isReadOnly) ('', 36, 0, false),
    ];

    final rows = <List<Widget>>[];
    double sum = 0;
    for (var i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      final a = _lineLc(l, sd);
      final amt = _priceIncludesVat ? a.total : a.net;
      sum += amt;
      final autoPrice = l.lastResolvedPrice != 0 && l.unitPriceFc == l.lastResolvedPrice;
      final stepOk = parseStepDiscount(l.discountText).valid;
      rows.add([
        Text('${i + 1}.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade700)),
        _itemBox(l.item),
        _cellField(l.qtyCtrl, allow: r'[0-9.]', onChanged: (v) {
          setState(() => l.qtyOrdered = double.tryParse(v) ?? 0);
          _maybeReresolvePrice(l);
        }),
        _uomField(l, isEnglish),
        _isReadOnly
            ? _cBox(_fmt4.format(l.unitPriceFc))
            : Tooltip(
                message: autoPrice ? (isEnglish ? 'Price list price' : 'ราคาตามตารางราคาขาย') : '',
                child: TextFormField(
                  controller: l.priceCtrl,
                  textAlign: TextAlign.right,
                  style: _numStyle,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: _cDec(fill: autoPrice ? _hAuto : Colors.white),
                  onChanged: (v) => setState(() => l.unitPriceFc = double.tryParse(v) ?? 0),
                ),
              ),
        _isReadOnly
            ? _cBox(l.discountText)
            : Tooltip(
                message: isEnglish ? 'Step discount, up to $maxDiscountSteps steps e.g. 10+5+2' : 'ส่วนลดขั้นบันได ไม่เกิน $maxDiscountSteps ขั้น เช่น 10+5+2',
                child: TextFormField(
                  controller: l.discTextCtrl,
                  textAlign: TextAlign.right,
                  style: _numStyle,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.+]'))],
                  decoration: _cDec(fill: Colors.white, err: !stepOk),
                  onChanged: (v) => setState(() => l.discountText = v),
                ),
              ),
        _cellField(l.discAmtCtrl, allow: r'[0-9.]', onChanged: (v) => setState(() => l.lineDiscountAmount = _n(v))),
        _cBox(_fmt.format(sd[l]?.total ?? 0), tip: isEnglish ? 'Line discount + allocated bill discount' : 'ส่วนลดของรายการ + ส่วนลดท้ายบิลที่ปันส่วน'),
        _isReadOnly
            ? _cBox(_vatRates.where((v) => v.vatCode == l.vatType).map(_vatLabel).firstOrNull ?? (l.vatType ?? ''), right: false)
            : DropdownButtonFormField<String>(
                value: l.vatType != null && _vatRates.any((v) => v.vatCode == l.vatType) ? l.vatType : null,
                isExpanded: true,
                isDense: true,
                decoration: _cDec(fill: Colors.white),
                items: _vatRates
                    .map((v) => DropdownMenuItem(value: v.vatCode, child: Text(_vatLabel(v), style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (code) {
                  setState(() {
                    final v = _vatRates.firstWhere((x) => x.vatCode == code);
                    l.vatType = v.vatCode;
                    l.vatRate = v.rate;
                  });
                  _maybeReresolvePrice(l); // ราคาตามตารางที่ต้องแปลง VAT ขึ้นกับอัตราของบรรทัด
                },
              ),
        // ยอดบรรทัดหลังส่วนลด (สกุลเงินหลัก) ตามรูปแบบราคาที่กรอก — รวม VAT เมื่อเลือกราคารวม VAT
        _cBox(_fmt.format(amt), bold: true),
        Text(l.refQuoteDocNo ?? (l.refQuoteDetailId != null ? (isEnglish ? '(quote line)' : '(จากใบเสนอราคา)') : '—'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13, fontWeight: l.refQuoteDocNo != null ? FontWeight.w600 : null, color: l.refQuoteDocNo != null ? const Color(0xFF1E4F8F) : _ink2)),
        if (showProgress)
          _progress(l.qtyDelivered, l.qtyOrdered,
              isEnglish
                  ? 'Delivered ${_fmtQty.format(l.qtyDelivered)} of ${_fmtQty.format(l.qtyOrdered)}'
                  : 'ส่งแล้ว ${_fmtQty.format(l.qtyDelivered)} จาก ${_fmtQty.format(l.qtyOrdered)}'),
        _cellField(l.remarkCtrl, numeric: false),
        AttachmentButton(moduleCode: 'so_transaction_detail', entityId: l.id, readOnly: _isReadOnly),
        if (!_isReadOnly)
          IconButton(
            tooltip: isEnglish ? 'Delete line' : 'ลบรายการ',
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            onPressed: () => setState(() {
              final removed = _lines.removeAt(i);
              WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
            }),
          ),
      ]);
    }

    final footer = <Widget>[
      for (final c in cols)
        c.$1.startsWith(amtLabel) ? _footerAmount(sum) : const SizedBox.shrink(),
    ];
    footer[1] = _footerLabel(isEnglish ? 'Total ${_lines.length} lines' : 'รวม ${_lines.length} รายการ');

    return _card(
      isEnglish ? 'Order Lines' : 'รายการสั่งขาย',
      chips: [
        _chip(isEnglish ? '${_lines.length} lines' : '${_lines.length} รายการ', const Color(0xFF1E4F8F), _hAuto),
        if (_currency != null && !_currency!.baseCurrencyFlag)
          _chip(isEnglish ? 'Unit price in $cur' : 'ราคา/หน่วยเป็น $cur', const Color(0xFF8A4B00), const Color(0xFFFFF0D9)),
      ],
      actions: [
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
        if (!_isReadOnly)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, foregroundColor: Colors.blueGrey.shade800),
            icon: const Icon(Icons.playlist_add_check, size: 16),
            label: Text(isEnglish ? 'From Quote' : 'จากใบเสนอราคา', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            onPressed: _pickQuoteLines,
          ),
        if (!_isReadOnly) _addButton(isEnglish ? 'Add Line' : 'เพิ่มรายการ', _addLine),
      ],
      [
        _gridTable(
          cols: cols,
          groupTitle: (g) => switch (g) {
            1 => isEnglish ? 'Item' : 'สินค้า',
            2 => isEnglish ? 'Quantity' : 'จำนวน',
            3 => isEnglish ? 'Price / Discount / VAT' : 'ราคา / ส่วนลด / VAT',
            _ => isEnglish ? 'Quotation / Delivered / Remark' : 'ใบเสนอราคา / ส่งแล้ว / หมายเหตุ',
          },
          rows: rows,
          footer: footer,
          empty: Text(isEnglish ? 'No items — click Add Line' : 'ไม่มีรายการ — กดเพิ่มรายการ', style: const TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  void _setPriceIncludesVat(bool v) {
    setState(() => _priceIncludesVat = v);
    _reresolveAllLinesForCustomer(); // ราคาตามตาราง: แปลงรวม/ไม่รวม VAT ใหม่
  }

  // ── การ์ดสรุปยอด: ซ้าย = ส่วนลดท้ายบิล, ขวา = ยอด → ยอดรวม 17 ตัวหนา ─────────────────────
  Widget _buildTotalsSection() {
    final isEnglish = _isEnglish;
    final base = _baseCurrencyCode;
    final t = _totalsLc;
    final split = _discountSplit(t.discount);
    // มูลค่าที่ส่งแล้ว (ก่อน VAT) ตามสัดส่วนจำนวนที่ส่ง
    final sd = _salesDiscounts();
    final delivered = _lines.fold<double>(0, (s, l) => l.qtyOrdered <= 0 ? s : s + _lineLc(l, sd).net * (l.qtyDelivered / l.qtyOrdered).clamp(0.0, 1.0));
    final showProgress = !['Draft', 'Rejected', 'Submitted'].contains(_status) || _lines.any((l) => l.qtyDelivered > 0);
    final billLabel = [
      if (_billDiscPct != 0) '${_LineForm._fmtPct(_billDiscPct)}%',
      if (_cashDisc != 0) _fmt.format(_cashDisc),
    ].join(' + ');

    final figures = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sumRow(isEnglish ? 'Before discount' : 'ยอดก่อนส่วนลด', t.gross),
      _sumRow(isEnglish ? 'Line discounts' : 'ส่วนลดรายการ', -split.item, neg: split.item.abs() >= 0.005),
      _sumRow('${isEnglish ? 'Bill discount' : 'ส่วนลดท้ายบิล'}${billLabel.isEmpty ? '' : ' ($billLabel)'}', -split.bill, neg: split.bill.abs() >= 0.005),
      _sumRow(isEnglish ? 'Before VAT' : 'ยอดก่อน VAT', t.net, line: true),
      _sumRow('VAT', t.vat),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFFE8F3F2), borderRadius: BorderRadius.circular(6)),
        child: Row(children: [
          Expanded(
              child: Text('${isEnglish ? 'Order Total' : 'ยอดรวมใบสั่งขาย'} ($base)',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F5C5C)))),
          Text(_fmt.format(t.total), style: _numStyle.copyWith(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF0F5C5C))),
        ]),
      ),
      if (showProgress && delivered > 0.005) _sumRow(isEnglish ? 'Delivered (before VAT)' : 'ส่งสินค้าแล้ว (มูลค่าก่อน VAT)', delivered, color: _ink2),
    ]);

    final billGroup = docFilterGroup(3, isEnglish ? 'Bill Discount' : 'ส่วนลดท้ายบิล', color: _gFin, [
      _hRow([
        _billDiscField(isEnglish ? 'Bill discount %' : 'ส่วนลดท้ายบิล %', _billDiscPctCtrl),
        _billDiscField(isEnglish ? 'Cash discount' : 'ส่วนลดเงินสดท้ายบิล', _cashDiscCtrl),
      ]),
      Text(
        isEnglish
            ? 'Allocated to lines by amount (shown in Net Disc) · deliveries that pull these lines use the same discounts'
            : 'ปันส่วนเข้าแต่ละรายการตามสัดส่วนยอด (แสดงในคอลัมน์ส่วนลดสุทธิ) · ใบส่งสินค้าที่ดึงรายการใช้ส่วนลดเดียวกัน',
        style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
      ),
    ]);
    final left = _deposits.isEmpty ? billGroup : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [billGroup, const SizedBox(height: 12), _depositTable()]);

    return _card(isEnglish ? 'Summary' : 'สรุปยอด', [
      LayoutBuilder(
        builder: (context, c) => c.maxWidth >= 820
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Align(alignment: Alignment.topLeft, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: left))),
                const SizedBox(width: 24),
                SizedBox(width: 380, child: figures),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: 10), figures]),
      ),
    ]);
  }

  Widget _depositTable() {
    final isEnglish = _isEnglish;
    final base = _baseCurrencyCode;
    return docFilterGroup(4, isEnglish ? 'Deposits referencing this order' : 'เงินมัดจำที่อ้างอิงใบสั่งขายนี้', color: _gMore, [
      _gridTable(
        cols: [
          (isEnglish ? 'Deposit No.' : 'เลขที่มัดจำ', 0, 0, false),
          (isEnglish ? 'Date' : 'วันที่', 92, 0, false),
          (isEnglish ? 'Status' : 'สถานะ', 96, 0, false),
          ('${isEnglish ? 'Deposit' : 'ยอดมัดจำ'} ($base)', 110, 0, true),
          (isEnglish ? 'Balance' : 'คงเหลือ', 110, 0, true),
        ],
        groupTitle: (_) => '',
        rows: [
          for (final d in _deposits)
            [
              Text(d.docNo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(d.docDate == null ? '' : _dateFmt.format(d.docDate!), style: _numStyle),
              docStatusBadge(d.status, label: docStatusLabel(d.status, isEnglish)),
              _footerAmount(d.totalAmountLc),
              Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: Text(_fmt.format(d.balanceAmountLc),
                      style: _numStyle.copyWith(fontWeight: FontWeight.w600, color: d.balanceAmountLc > 0.005 ? const Color(0xFF8A4B00) : _ink2))),
            ],
        ],
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    widget.actions?.scheduleRefresh();
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    // การ์ดข้อมูลเอกสาร fix ด้านบน (สูงไม่เกิน 60% แล้วเลื่อนในการ์ด) — การ์ดอื่นเลื่อนด้านล่าง (แบบเดียวกับ IM / AR / AP)
    return docListTheme(context, LayoutBuilder(builder: (context, box) => Column(children: [
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_status == 'Void' && (_voidReason ?? '').isNotEmpty) ...[
              Text('${isEnglish ? 'Void reason' : 'เหตุผลการยกเลิก'}: $_voidReason',
                  style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
            ],
            // แผงอนุมัติกลาง (ตามลำดับ / คนใดคนหนึ่ง) — ปฏิเสธ = เอกสารกลับเป็นร่าง
            if (_id != null && _approvals.isNotEmpty) ...[
              DocApprovalPanel(
                docNo: _docNo,
                approvals: _approvals,
                approvalMode: _approvalMode,
                awaiting: _status == 'Submitted' && !widget.viewOnly,
                onApprove: (r) => _service.approveTransaction(_id!, remarks: r),
                onReject: (r) => _service.rejectTransaction(_id!, remarks: r),
                onDone: _load,
              ),
              const SizedBox(height: 12),
            ],
            if (_actions.history.isNotEmpty || _status == 'Deleted') ...[
              DocReverseHistoryPanel(history: _actions.history, isDeleted: _status == 'Deleted', isEnglish: isEnglish, margin: EdgeInsets.zero),
              const SizedBox(height: 12),
            ],
            _buildLinesSection(),
            const SizedBox(height: 16),
            _buildTotalsSection(),
          ]),
        ),
      ),
    ])));
  }
}

// ---------------------------------------------------------------------------
// Item picker dialog — มิเรอร์ po_transaction_detail_widget.dart ทุกประการ
// ---------------------------------------------------------------------------
class _ItemPickerDialog extends StatefulWidget {
  const _ItemPickerDialog();

  @override
  State<_ItemPickerDialog> createState() => _ItemPickerDialogState();
}

class _ItemPickerDialogState extends State<_ItemPickerDialog> {
  final _ctrl = TextEditingController();
  final _svc = ImItemService();
  List<ImItem> _list = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final list = await _svc.fetchRows(keyword: q.trim().isEmpty ? null : q.trim());
      if (mounted) setState(() => _list = list);
    } catch (_) {
      if (mounted) setState(() => _list = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    return Dialog(
      child: SizedBox(
        width: 520, height: 480,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.teal[800],
            child: Text(isEnglish ? 'Search Item' : 'ค้นหาสินค้า', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(hintText: isEnglish ? 'Search by item code or name' : 'ค้นหาจากรหัสหรือชื่อสินค้า', prefixIcon: const Icon(Icons.search, size: 18), border: const OutlineInputBorder(), isDense: true),
              onChanged: _search,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _list.isEmpty
                    ? Center(child: Text(isEnglish ? 'No data found' : 'ไม่พบข้อมูล', style: const TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        itemCount: _list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 12),
                        itemBuilder: (ctx, i) {
                          final it = _list[i];
                          final displayName = isEnglish && (it.itemNameEn ?? '').isNotEmpty ? it.itemNameEn! : it.itemNameTh;
                          return InkWell(
                            onTap: () => Navigator.pop(ctx, it),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(children: [
                                SizedBox(width: 100, child: Text(it.itemCode, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                Expanded(child: Text(displayName, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                              ]),
                            ),
                          );
                        }),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
            ]),
          ),
        ]),
      ),
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
