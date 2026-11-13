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

class SoTransactionDetailWidget extends StatefulWidget {
  final int? transactionId;
  final bool viewOnly;
  final int resetKey;
  final VoidCallback onSaveSuccess;
  final VoidCallback onCancel;
  final bool canDelete;
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
  _LineForm({this.id, this.item, this.qtyOrdered = 0, this.unitPriceFc = 0, this.qtyDelivered = 0, this.refQuoteDetailId,
      this.discountPercent = 0, this.vatType, this.vatRate = 0, String? discountText, this.lineDiscountAmount = 0})
      : discountText = discountText ?? (discountPercent != 0 ? _fmtPct(discountPercent) : '');

  static String _fmtPct(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

class _SoTransactionDetailWidgetState extends State<SoTransactionDetailWidget> {
  final _service = SoTransactionService();
  final _quoteService = QuoteTransactionService();
  final _itemService = ImItemService();
  final _currencyService = CurrencyService();
  final _fmtQty = NumberFormat('#,##0.####');
  final _fmtValue = NumberFormat('#,##0.00');
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
    _load();
  }

  @override
  void didUpdateWidget(covariant SoTransactionDetailWidget old) {
    super.didUpdateWidget(old);
    if (widget.transactionId != old.transactionId || widget.resetKey != old.resetKey) {
      _load();
    }
  }

  Timer? _priceResolveDebounce;

  @override
  void dispose() {
    _descCtrl.dispose();
    _poNoCtrl.dispose();
    _billDiscPctCtrl.dispose();
    _cashDiscCtrl.dispose();
    _priceResolveDebounce?.cancel();
    super.dispose();
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
    _currency = _currencies.cast<Currency?>().firstWhere((c) => c!.baseCurrencyFlag, orElse: () => null);
    _exchangeRate = _currency?.baseRate ?? 1;
    _priceIncludesVat = false;
    _billDiscPctCtrl.clear();
    _cashDiscCtrl.clear();
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
        _currency = _currencies.cast<Currency?>().firstWhere(
            (c) => c?.id == h.currencyId || c?.currencyCode == h.currencyCode, orElse: () => null);
        _exchangeRate = h.exchangeRate;
        _priceIncludesVat = h.priceIncludesVat;
        _setBillDiscount(h);
        final items = await Future.wait(h.details.map((d) => _itemService.fetchRow(d.itemId)));
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
            ),
        ];
        // ใบเก่าก่อนมี VAT ต่อบรรทัด — ใบใหม่ใช้ VAT ตั้งต้นของสินค้า
        for (final l in _lines) {
          if (l.vatType == null) _applyDefaultVat(l);
        }
        // คำนวณวันครบกำหนดใหม่จากเงื่อนไขเครดิตของลูกค้าบน doc_date ใหม่ (วันนี้) — ไม่คัดลอกวันครบกำหนดเดิมมาตรงๆ
        // เพราะเอกสารที่คัดลอกเป็นธุรกรรมใหม่ที่เกิดขึ้นวันนี้ ไม่ใช่ของเดิมที่ย้อนวันที่ไป
        if (_customer != null) _selectCustomer(_customer!);
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
        _currency = _currencies.cast<Currency?>().firstWhere(
            (c) => c?.id == h.currencyId || c?.currencyCode == h.currencyCode, orElse: () => null);
        _exchangeRate = h.exchangeRate;
        _priceIncludesVat = h.priceIncludesVat;
        _setBillDiscount(h);
        // ดึง ImItem เต็มจาก itemId เสมอ ไม่ใช้ค่า snapshot (item_code/item_name) ที่บันทึกไว้ตอนสร้างเอกสารมาแสดง
        // ตรงๆ — มิเรอร์ po_transaction_detail_widget.dart ทุกประการ
        final items = await Future.wait(h.details.map((d) => _itemService.fetchRow(d.itemId)));
        _lines = [
          for (var i = 0; i < h.details.length; i++)
            _LineForm(
              id: h.details[i].id,
              item: items[i],
              qtyOrdered: h.details[i].qtyOrdered,
              unitPriceFc: h.details[i].unitPriceFc,
              qtyDelivered: h.details[i].qtyDelivered,
              refQuoteDetailId: h.details[i].refQuoteDetailId,
              discountPercent: h.details[i].discountPercent,
              discountText: h.details[i].discountText,
              lineDiscountAmount: h.details[i].lineDiscountAmount,
              vatType: h.details[i].vatType,
              vatRate: h.details[i].vatRate,
            ),
        ];
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  void _selectCustomer(ArCustomer c) {
    if (!_isReadOnly && c.id != null) _loadCustomerSalespersons(c.id!);
    setState(() {
      _customer = c;
      // เงื่อนไขเครดิต: due_date = doc_date + creditTermMonths เดือน + creditTermDays วัน — สูตรเดียวกับ
      // po_transaction_detail_widget.dart:_selectVendor ทุกประการ ฝั่งลูกค้า
      if (c.creditTermMonths > 0 || c.creditTermDays > 0) {
        var base = _docDate;
        if (c.creditTermMonths > 0) base = DateTime(base.year, base.month + c.creditTermMonths, base.day);
        if (c.creditTermDays > 0) base = base.add(Duration(days: c.creditTermDays));
        _dueDate = base;
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
        docDate: DateFormat('yyyy-MM-dd').format(_docDate), uomId: line.item!.baseUomId,
        currencyCode: _currency?.currencyCode, priceIncludesVat: _priceIncludesVat, vatRate: _lineVatRate(line),
      );
      if (!mounted || _customer != customer) return;
      if (resolved['unit_price_fc'] != null && line.unitPriceFc == line.lastResolvedPrice) {
        final price = double.tryParse(resolved['unit_price_fc'].toString()) ?? 0;
        setState(() { line.unitPriceFc = price; line.lastResolvedPrice = price; });
      }
    }
  }

  Future<void> _addLine() async {
    final result = await showDialog<ImItem>(context: context, builder: (_) => const _ItemPickerDialog());
    if (result == null || !mounted) return;
    final line = _LineForm(item: result, qtyOrdered: 1, unitPriceFc: 0);
    _applyDefaultVat(line);
    setState(() => _lines.add(line));
    if (_customer != null) {
      final resolved = await _service.resolvePrice(
        itemId: result.id!, customerId: _customer!.id!, qty: 1, docDate: DateFormat('yyyy-MM-dd').format(_docDate),
        uomId: result.baseUomId,
        currencyCode: _currency?.currencyCode, priceIncludesVat: _priceIncludesVat, vatRate: _lineVatRate(line),
      );
      if (resolved['unit_price_fc'] != null && mounted) {
        final price = double.tryParse(resolved['unit_price_fc'].toString()) ?? 0;
        setState(() { line.unitPriceFc = price; line.lastResolvedPrice = price; });
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
        uomId: line.item!.baseUomId,
        currencyCode: _currency?.currencyCode, priceIncludesVat: _priceIncludesVat, vatRate: _lineVatRate(line),
      );
      if (resolved['unit_price_fc'] != null && mounted && line.unitPriceFc == line.lastResolvedPrice) {
        final price = double.tryParse(resolved['unit_price_fc'].toString()) ?? 0;
        setState(() { line.unitPriceFc = price; line.lastResolvedPrice = price; });
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
                        child: Text(isEnglish ? 'Remaining: ${_fmtQty.format(remaining)}' : 'คงเหลือแปลงได้: ${_fmtQty.format(remaining)}', style: const TextStyle(fontSize: 12)),
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
          discountPercent: _quoteNum(l['discount_percent']),
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
          line.unitPriceFc = qIncl ? line.unitPriceFc * 100 / (100 + line.vatRate) : line.unitPriceFc * (100 + line.vatRate) / 100;
        }
        _lines.add(line);
      }
      _refQuoteId = pickedLines.first['header_id'] as int;
      _refQuoteDocNoLabel = pickedLines.first['doc_no'] as String?;
      // มิติ: ยังไม่ได้เลือกเลย = ใช้มิติของใบเสนอราคาใบแรกที่เลือก
      if (!_dimSelections.values.any((v) => v != null)) {
        _dimSelections = {for (var i = 1; i <= 5; i++) i: pickedLines.first['dim${i}_id'] as int?};
      }
    });
    _loadQuoteSalespersons(_refQuoteId!);
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
      final header = SoTransactionHeader(
        id: _id ?? 0, docId: _docId ?? 0, docNo: _docNo, docDate: _docDate,
        customerId: _customer!.id!, warehouseId: _warehouse!.id, dueDate: _dueDate,
        customerPoNo: _poNoCtrl.text.trim().isEmpty ? null : _poNoCtrl.text.trim(), customerPoDate: _poDate,
        currencyId: _currency?.id, currencyCode: _currency?.currencyCode ?? CurrencyService.baseCode, exchangeRate: _exchangeRate,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        refQuoteId: _refQuoteId,
        priceIncludesVat: _priceIncludesVat,
        billDiscountPercent: _billDiscPct,
        cashDiscountAmount: _cashDisc,
        dim1Id: _dimSelections[1], dim2Id: _dimSelections[2], dim3Id: _dimSelections[3],
        dim4Id: _dimSelections[4], dim5Id: _dimSelections[5],
      );
      final details = _lines
          .map((l) => SoTransactionDetail(
                id: l.id, lineNo: 0, itemId: l.item!.id!, itemCode: l.item!.itemCode, itemName: l.item!.itemNameTh,
                qtyOrdered: l.qtyOrdered, unitPriceFc: l.unitPriceFc, refQuoteDetailId: l.refQuoteDetailId,
                discountPercent: l.discountPercent, vatType: l.vatType, vatRate: l.vatRate,
                discountText: parseStepDiscount(l.discountText).factor == 1 ? '' : l.discountText.trim(),
                lineDiscountAmount: l.lineDiscountAmount,
              ))
          .toList();
      if (_id == null) {
        await _service.createTransaction(header: header, details: details, salespersons: _salespersons);
      } else {
        await _service.updateTransaction(id: _id!, header: header, details: details, salespersons: _salespersons);
      }
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
  Widget _lockable(DocBlock? block, Widget Function(VoidCallback? onPressed) builder, VoidCallback action) {
    final button = builder(block == null && !_isSaving ? action : null);
    return block == null ? button : Tooltip(message: block.text(_isEnglish), child: button);
  }

  void _warn(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.orange));
  }

  String _docTypeLabel(ModuleDocument d) => _isEnglish && d.docNameEng.isNotEmpty ? d.docNameEng : d.docNameThai;

  String _currencyLabel(Currency c) => _isEnglish && c.currencyNameEng.isNotEmpty ? c.currencyNameEng : c.currencyNameThai;

  String get _baseCurrencyCode =>
      _currencies.cast<Currency?>().firstWhere((c) => c!.baseCurrencyFlag, orElse: () => null)?.currencyCode ?? CurrencyService.baseCode;

  Widget _fkField({required String label, required bool hasValue, required String displayText, VoidCallback? onSearch}) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label, border: const OutlineInputBorder(), isDense: true,
        suffixIcon: onSearch == null ? null : IconButton(icon: const Icon(Icons.search, size: 18), onPressed: onSearch),
      ),
      child: Text(hasValue ? displayText : (_isEnglish ? '— Not specified —' : '— ไม่ระบุ —'),
          style: TextStyle(fontSize: 13, color: hasValue ? Colors.black87 : Colors.black38)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final perm = MenuScope.of(context);
    final canApprove = perm?.canApprove ?? false;
    final canCreate = perm?.canCreate ?? false;

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<ModuleDocument>(
                    value: _docType,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: isEnglish ? 'Document Type *' : 'ประเภทเอกสาร *', border: const OutlineInputBorder(), isDense: true),
                    items: _allowedDocTypes.map((d) => DropdownMenuItem(
                          value: d,
                          child: Text('${d.docCode} ${_docTypeLabel(d)}', overflow: TextOverflow.ellipsis),
                        )).toList(),
                    // เลือกเปลี่ยนได้เฉพาะตอนยังไม่บันทึกครั้งแรก (_id == null) — endpoint update ไม่รองรับการเปลี่ยน
                    // doc_id ของเอกสารที่มีอยู่แล้ว (เลขที่เอกสาร/ชุดเลขวิ่งผูกกับประเภทเอกสารตอนสร้างเท่านั้น)
                    onChanged: (_isReadOnly || _id != null) ? null : (v) => setState(() { _docType = v; _docId = v?.id; }),
                    validator: (v) => v == null ? (isEnglish ? 'Please select' : 'กรุณาเลือก') : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('${isEnglish ? "SO No." : "เลขที่ใบสั่งขาย"}: $_docNo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blueGrey.shade100, borderRadius: BorderRadius.circular(12)),
                  child: Text(soTransactionStatusLabel(_status, isEnglish), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              ]),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: InkWell(
                    onTap: _isReadOnly ? null : () async {
                      final picked = await showDatePicker(context: context, initialDate: _docDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                      if (picked != null) setState(() => _docDate = picked);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(labelText: isEnglish ? 'Doc Date *' : 'วันที่เอกสาร *', border: const OutlineInputBorder(), isDense: true),
                      child: Text(_dateFmt.format(_docDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _isReadOnly ? null : () async {
                      final picked = await showDatePicker(context: context, initialDate: _dueDate ?? _docDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                      if (picked != null) setState(() => _dueDate = picked);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(labelText: isEnglish ? 'Due Date' : 'วันครบกำหนด', border: const OutlineInputBorder(), isDense: true),
                      child: Text(_dueDate != null ? _dateFmt.format(_dueDate!) : '-'),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: TextFormField(
                    controller: _poNoCtrl,
                    enabled: !_isReadOnly,
                    maxLength: 50,
                    decoration: InputDecoration(
                      labelText: isEnglish ? 'Customer PO No.' : 'เลขที่ใบสั่งซื้อลูกค้า',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _isReadOnly ? null : () async {
                      final picked = await showDatePicker(context: context, initialDate: _poDate ?? _docDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                      if (picked != null) setState(() => _poDate = picked);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Customer PO Date' : 'วันที่ใบสั่งซื้อลูกค้า',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: (_poDate == null || _isReadOnly)
                            ? null
                            : IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _poDate = null)),
                      ),
                      child: Text(_poDate != null ? _dateFmt.format(_poDate!) : '-'),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  flex: 2,
                  child: _fkField(
                    label: isEnglish ? 'Customer *' : 'ลูกค้า *',
                    hasValue: _customer != null,
                    displayText: '${_customer?.customerCode ?? ''}  ${_customer?.customerNameTh ?? ''}',
                    onSearch: _isReadOnly ? null : () => ArCustomerListWidget.search(context, onSelected: _selectCustomer),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _fkField(
                    label: isEnglish ? 'Warehouse *' : 'คลังต้นทาง *',
                    hasValue: _warehouse != null,
                    displayText: '${_warehouse?.warehouseCode ?? ''}  ${_warehouse?.warehouseNameTh ?? ''}',
                    onSearch: _isReadOnly ? null : () => ImWarehouseListWidget.search(context, onSelected: (w) => setState(() => _warehouse = w)),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: DropdownButtonFormField<Currency>(
                    value: _currency,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: isEnglish ? 'Currency' : 'สกุลเงิน', border: const OutlineInputBorder(), isDense: true),
                    items: _currencies.map((c) => DropdownMenuItem(
                          value: c,
                          child: Text('${c.currencyCode} - ${_currencyLabel(c)}', overflow: TextOverflow.ellipsis),
                        )).toList(),
                    onChanged: _isReadOnly ? null : (v) {
                      setState(() { _currency = v; _exchangeRate = v?.baseRate ?? 1; });
                      _reresolveAllLinesForCustomer(); // ใช้ตารางราคาตามสกุลเงินของเอกสาร
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('so_rate_${widget.resetKey}_$_id'),
                    initialValue: _exchangeRate.toStringAsFixed(6),
                    enabled: !_isReadOnly,
                    decoration: InputDecoration(labelText: isEnglish ? 'Exchange Rate' : 'อัตราแลกเปลี่ยน', border: const OutlineInputBorder(), isDense: true),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => setState(() => _exchangeRate = double.tryParse(v) ?? 1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _descCtrl,
                    enabled: !_isReadOnly,
                    decoration: InputDecoration(labelText: isEnglish ? 'Description' : 'คำอธิบาย', border: const OutlineInputBorder(), isDense: true),
                  ),
                ),
              ]),
              if (_dimTypes.isNotEmpty) ...[
                const SizedBox(height: 12),
                GlHeaderDimsRow(
                  dimTypes: _dimTypes,
                  dimValues: _dimValues,
                  selections: _dimSelections,
                  readOnly: _isReadOnly,
                  onChanged: (slot, id) => setState(() => _dimSelections[slot] = id),
                ),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 12),
        SalespersonSplitEditor(
          items: _salespersons,
          isEnglish: isEnglish,
          readOnly: _isReadOnly,
          onChanged: (list) => setState(() => _salespersons = list),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(isEnglish ? 'Lines' : 'รายการสั่งขาย', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                if (_currency != null && !_currency!.baseCurrencyFlag) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                    child: Text(isEnglish ? 'Unit price in ${_currency!.currencyCode}' : 'ราคา/หน่วยเป็น ${_currency!.currencyCode}', style: TextStyle(fontSize: 11, color: Colors.orange[800])),
                  ),
                ],
                if (_refQuoteDocNoLabel != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text(isEnglish ? 'From Quote: $_refQuoteDocNoLabel' : 'อ้างอิงจากใบเสนอราคา: $_refQuoteDocNoLabel', style: TextStyle(fontSize: 11, color: Colors.indigo[700])),
                  ),
                ],
                const Spacer(),
                Checkbox(
                  value: _priceIncludesVat,
                  visualDensity: VisualDensity.compact,
                  onChanged: _isReadOnly ? null : (v) {
                    setState(() => _priceIncludesVat = v ?? false);
                    _reresolveAllLinesForCustomer(); // ราคาตามตาราง: แปลงรวม/ไม่รวม VAT ใหม่
                  },
                ),
                Text(isEnglish ? 'Prices include VAT' : 'ราคารวม VAT'),
                const SizedBox(width: 12),
                if (!_isReadOnly) ...[
                  OutlinedButton.icon(onPressed: _pickQuoteLines, icon: const Icon(Icons.playlist_add_check, size: 16), label: Text(isEnglish ? 'From Quote' : 'จากใบเสนอราคา')),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(onPressed: _addLine, icon: const Icon(Icons.add, size: 16), label: Text(isEnglish ? 'Add Line' : 'เพิ่มรายการ')),
                ],
              ]),
              const Divider(),
              ..._lines.asMap().entries.map((entry) {
                final i = entry.key;
                final l = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    // ลำดับที่ — ตรงกับ line_no ที่บันทึก (เรียงตามหน้าจอ)
                    SizedBox(
                      width: 30,
                      child: Text('${i + 1}.', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                    ),
                    Expanded(flex: 3, child: Text('${l.item?.itemCode ?? ''}  ${l.item?.itemNameTh ?? ''}', style: const TextStyle(fontSize: 13))),
                    SizedBox(
                      width: 90,
                      child: TextFormField(
                        initialValue: _fmtQty.format(l.qtyOrdered),
                        enabled: !_isReadOnly,
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(labelText: isEnglish ? 'Qty' : 'จำนวน', isDense: true, border: const OutlineInputBorder()),
                        onChanged: (v) {
                          setState(() => l.qtyOrdered = double.tryParse(v) ?? 0);
                          _maybeReresolvePrice(l);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      child: TextFormField(
                        initialValue: _fmtValue.format(l.unitPriceFc),
                        enabled: !_isReadOnly,
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          labelText: (isEnglish ? 'Unit Price' : 'ราคา/หน่วย') + (_currency != null ? ' (${_currency!.currencyCode})' : ''),
                          isDense: true, border: const OutlineInputBorder(),
                        ),
                        onChanged: (v) => setState(() => l.unitPriceFc = double.tryParse(v) ?? 0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      child: Tooltip(
                        message: isEnglish ? 'Step discount, up to $maxDiscountSteps steps e.g. 10+5+2' : 'ส่วนลดขั้นบันได ไม่เกิน $maxDiscountSteps ขั้น เช่น 10+5+2',
                        child: TextFormField(
                          initialValue: l.discountText,
                          enabled: !_isReadOnly,
                          textAlign: TextAlign.right,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.+]'))],
                          decoration: InputDecoration(
                            labelText: isEnglish ? 'Disc % (10+5)' : 'ส่วนลด % (10+5)', isDense: true, border: const OutlineInputBorder(),
                            errorText: parseStepDiscount(l.discountText).valid ? null : (isEnglish ? 'Invalid' : 'ไม่ถูกต้อง'),
                          ),
                          onChanged: (v) => setState(() => l.discountText = v),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      child: TextFormField(
                        initialValue: l.lineDiscountAmount != 0 ? _fmtValue.format(l.lineDiscountAmount) : '',
                        enabled: !_isReadOnly,
                        textAlign: TextAlign.right,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                        decoration: InputDecoration(labelText: isEnglish ? 'Disc (amt)' : 'ส่วนลด (เงิน)', isDense: true, border: const OutlineInputBorder()),
                        onChanged: (v) => setState(() => l.lineDiscountAmount = _n(v)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // ส่วนลดสุทธิ = ของรายการ + ส่วนลดท้ายบิลที่ปันส่วน (สกุลเงินเอกสาร หน่วยราคาที่กรอก)
                    SizedBox(
                      width: 90,
                      child: InputDecorator(
                        decoration: InputDecoration(labelText: isEnglish ? 'Net Disc' : 'ส่วนลดสุทธิ', isDense: true, border: const OutlineInputBorder()),
                        child: Text(_fmtValue.format(_salesDiscounts()[l]?.total ?? 0), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 110,
                      child: DropdownButtonFormField<String>(
                        value: l.vatType != null && _vatRates.any((v) => v.vatCode == l.vatType) ? l.vatType : null,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'VAT', isDense: true, border: OutlineInputBorder()),
                        items: _vatRates.map((v) => DropdownMenuItem(value: v.vatCode, child: Text(_vatLabel(v), style: const TextStyle(fontSize: 12)))).toList(),
                        onChanged: _isReadOnly ? null : (code) {
                          setState(() {
                            final v = _vatRates.firstWhere((x) => x.vatCode == code);
                            l.vatType = v.vatCode;
                            l.vatRate = v.rate;
                          });
                          _maybeReresolvePrice(l); // ราคาตามตารางที่ต้องแปลง VAT ขึ้นกับอัตราของบรรทัด
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // ยอดบรรทัดหลังส่วนลด (บาท) ตามรูปแบบราคาที่กรอก — รวม VAT เมื่อเลือกราคารวม VAT
                    SizedBox(width: 100, child: Text(_fmtValue.format(_priceIncludesVat ? _lineLc(l).total : _lineLc(l).net), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    if (l.qtyDelivered > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(isEnglish ? 'Delivered: ${_fmtQty.format(l.qtyDelivered)}' : 'ส่งแล้ว: ${_fmtQty.format(l.qtyDelivered)}',
                            style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
                      ),
                    AttachmentButton(moduleCode: 'so_transaction_detail', entityId: l.id, readOnly: _isReadOnly),
                    if (!_isReadOnly)
                      IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), onPressed: () => setState(() => _lines.removeAt(i))),
                  ]),
                );
              }),
              const Divider(),
              // ส่วนลดท้ายบิล — % ของยอดหลังส่วนลดรายการ แล้วตามด้วยส่วนลดเงินสด ปันส่วนเข้าแต่ละรายการตามสัดส่วนยอด
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _billDiscPctCtrl,
                      readOnly: _isReadOnly,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      decoration: InputDecoration(labelText: isEnglish ? 'Bill discount %' : 'ส่วนลดท้ายบิล %', border: const OutlineInputBorder(), isDense: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(
                    width: 170,
                    child: TextField(
                      controller: _cashDiscCtrl,
                      readOnly: _isReadOnly,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      decoration: InputDecoration(labelText: isEnglish ? 'Cash discount' : 'ส่วนลดเงินสดท้ายบิล', border: const OutlineInputBorder(), isDense: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  Text(isEnglish ? 'Allocated to lines by amount' : 'ปันส่วนเข้าแต่ละรายการตามสัดส่วนยอด',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ]),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Builder(builder: (_) {
                  final t = _totalsLc;
                  Widget row(String label, double v, {bool bold = false}) => Text(
                        '$label ($_baseCurrencyCode): ${_fmtValue.format(v)}',
                        style: bold ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 15) : const TextStyle(fontSize: 13),
                      );
                  return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    if (t.discount.abs() >= 0.005) ...[
                      row(isEnglish ? 'Before discount' : 'ก่อนส่วนลด', t.gross),
                      row(isEnglish ? 'Discount' : 'ส่วนลด', t.discount),
                    ],
                    row(isEnglish ? 'Before VAT' : 'ก่อน VAT', t.net),
                    row('VAT', t.vat),
                    row(isEnglish ? 'Total' : 'รวม', t.total, bold: true),
                  ]);
                }),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(onPressed: widget.onCancel, child: Text(isEnglish ? 'Close' : 'ปิด')),
          const SizedBox(width: 8),
          if (_id != null && canCreate) ...[
            OutlinedButton.icon(
              onPressed: _isSaving ? null : () => widget.onCopyRequested?.call(_id!),
              icon: const Icon(Icons.copy, size: 18),
              label: Text(isEnglish ? 'Copy as New' : 'คัดลอกเป็นใบใหม่'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.teal[800]),
            ),
            const SizedBox(width: 8),
          ],
          if (_isEditable && !widget.viewOnly)
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: const Icon(Icons.save, size: 18),
              label: Text(isEnglish ? 'Save' : 'บันทึก'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[800], foregroundColor: Colors.white),
            ),
          // ส่งอนุมัติ — เข้าคิวผู้อนุมัติของเมนู (ไม่มีผู้อนุมัติ: ตามตัวเลือกของเมนู ให้ผ่าน/ไม่ให้ผ่าน)
          if (_isEditable && _id != null && !widget.viewOnly && perm?.id != null) ...[
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : () => _submit(perm!.id),
              icon: const Icon(Icons.send, size: 18),
              label: Text(isEnglish ? 'Submit' : 'ส่งอนุมัติ'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[700], foregroundColor: Colors.white),
            ),
          ],
          if (['Approved', 'PartiallyDelivered', 'FullyDelivered'].contains(_status) && canApprove && !widget.viewOnly) ...[
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : () => _confirmAction(
                  'ยืนยันปิดใบสั่งขาย', 'Close Sale Order',
                  'ปิดใบสั่งขายนี้? ใช้เมื่อไม่มีการส่งสินค้าเพิ่มแล้ว (แม้ยังส่งไม่ครบ 100%)${orderDepositCloseNote(_deposits, false)}',
                  'Close this SO? Use this when no more delivery is expected (even if not 100% delivered).${orderDepositCloseNote(_deposits, true)}',
                  () => _service.closeTransaction(_id!)),
              icon: const Icon(Icons.lock_outline, size: 18),
              label: Text(isEnglish ? 'Close' : 'ปิดใบสั่งขาย'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
            ),
          ],
          if (_isEditable && _id != null && widget.canDelete && !widget.viewOnly) ...[
            const SizedBox(width: 8),
            _lockable(_actions.deleteBlock, (onPressed) => OutlinedButton.icon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(isEnglish ? 'Delete' : 'ลบ'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red[700]),
                ), _deleteDoc),
          ],
          if ((['Approved', 'PartiallyDelivered', 'FullyDelivered', 'Closed'].contains(_status) && canApprove ||
                  _status == 'Submitted') && _id != null && !widget.viewOnly) ...[
            const SizedBox(width: 8),
            _lockable(_actions.reverseBlock, (onPressed) => OutlinedButton.icon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.undo, size: 18),
                  label: Text(_status == 'Closed'
                      ? (isEnglish ? 'Reopen' : 'ถอยการปิด')
                      : (isEnglish ? 'Reverse to Draft' : 'ถอยเป็นร่าง')),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.orange[800]),
                ), _reverse),
          ],
          if (['Approved', 'PartiallyDelivered', 'FullyDelivered'].contains(_status) && _id != null && canApprove && !widget.viewOnly) ...[
            const SizedBox(width: 8),
            _lockable(_actions.voidBlock, (onPressed) => OutlinedButton.icon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: Text(isEnglish ? 'Void' : 'ยกเลิก'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red[700]),
                ), _voidDoc),
          ],
        ]),
        // วงเงินเครดิตของลูกค้า + ขอ/อนุมัติเกินวงเงิน
        if (_customer?.id != null && (_isEditable || _credit.status != null))
          CreditLimitPanel(
            service: _creditService,
            customerId: _customer!.id,
            docId: _id,
            docNo: _docNo,
            amount: _creditAmount,
            credit: _credit,
            isDraft: _isEditable && !widget.viewOnly,
            onChanged: _load,
          ),
        if (_id != null && _deposits.isNotEmpty)
          OrderDepositPanel(deposits: _deposits, isEnglish: isEnglish, baseCurrencyCode: _baseCurrencyCode),
        if (_id != null && _approvals.isNotEmpty)
          DocApprovalPanel(
            docNo: _docNo,
            approvals: _approvals,
            approvalMode: _approvalMode,
            awaiting: _status == 'Submitted' && !widget.viewOnly,
            onApprove: (r) => _service.approveTransaction(_id!, remarks: r),
            onReject: (r) => _service.rejectTransaction(_id!, remarks: r),
            onDone: _load,
          ),
        if (_status == 'Void' && (_voidReason ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('${isEnglish ? 'Void reason' : 'เหตุผลการยกเลิก'}: $_voidReason',
              style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 12),
        DocReverseHistoryPanel(
          history: _actions.history,
          isDeleted: _status == 'Deleted',
          isEnglish: isEnglish,
          margin: EdgeInsets.zero,
        ),
      ]),
    );
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
