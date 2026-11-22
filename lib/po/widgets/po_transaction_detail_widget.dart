// lib/po/widgets/po_transaction_detail_widget.dart — แก้ไขรายละเอียดใบสั่งซื้อ (header+lines)
// มิเรอร์โครงสร้าง im_transaction_detail_widget.dart (list+detail tab pattern) แต่เรียบง่ายกว่ามาก เพราะ PO ไม่แตะ
// สต็อก/GL เลย — Draft เท่านั้นที่แก้ไขได้ (เหมือน GRN), Approve/Close/Void เป็น action แยกกดทีละปุ่ม (เหมือน
// im_stock_count) ดู poTransactionController.js สำหรับ workflow เต็ม
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/date_utils.dart';
import 'package:provider/provider.dart';

import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/models/sa_document_reverse_log.dart';
import '../../sa/widgets/sa_document_reverse_widgets.dart';
import '../../ap/models/ap_vendor.dart';
import '../../ap/widgets/ap_vendor_list_widget.dart';
import '../../im/models/im_item.dart';
import '../../im/models/im_warehouse.dart';
import '../models/po_transaction.dart';
import '../../im/services/im_item_service.dart';
import '../services/po_transaction_service.dart';
import '../../im/widgets/im_warehouse_list_widget.dart';
import '../services/po_pr_transaction_service.dart';
import '../../cd/models/cd_currency.dart';
import '../../cd/models/cd_vat_rate.dart';
import '../../cd/services/cd_vat_rate_service.dart';
import '../../utils/vat_calc.dart';
import '../../cd/services/cd_currency_service.dart';
import '../../sa/widgets/sa_attachment_widget.dart';
import '../../sa/models/sa_doc_approval.dart';
import '../../sa/widgets/sa_doc_approval_panel.dart';
import '../../utils/order_ref_picker.dart';
import '../../gl/models/gl_dimension.dart';
import '../../gl/widgets/gl_line_account_dims.dart';
import '../../cd/models/cd_branch.dart';
import '../../cd/services/cd_branch_service.dart';
import '../../cd/widgets/cd_user_branch_picker.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';

class PoTransactionDetailWidget extends StatefulWidget {
  final int? transactionId;
  final bool viewOnly;
  final int resetKey;
  final VoidCallback onSaveSuccess;
  final VoidCallback onCancel;
  final bool canDelete;
  /// ปุ่มของเอกสารแสดงบน AppBar ของหน้าจอแม่ (แทนแถบปุ่มเดิม)
  final DocAppBarActions? actions;
  // คัดลอกใบสั่งซื้อเดิมเป็นฉบับร่างใหม่ — ใช้ได้เฉพาะตอน transactionId เป็น null (โหมดสร้างใหม่) เท่านั้น
  // ดู _load()/onCopyRequested สำหรับตรรกะเต็ม
  final int? copyFromId;
  final ValueChanged<int>? onCopyRequested;

  const PoTransactionDetailWidget({
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
  State<PoTransactionDetailWidget> createState() => _PoTransactionDetailWidgetState();
}

class _LineForm {
  int? id;
  ImItem? item;
  double qtyOrdered;
  double unitPriceFc;
  double qtyReceived;
  int? refPrDetailId; // บรรทัดใบขอซื้อ (PR) ต้นทาง ถ้าเพิ่มมาจาก picker _pickPrLines()
  // ราคาล่าสุดที่ระบบ auto-fill ให้จาก im_price_list — ใช้เทียบกับ unitPriceFc ปัจจุบันตอนจำนวน/ผู้ขายเปลี่ยน
  // เพื่อรู้ว่าผู้ใช้แก้ราคาเองไปแล้วหรือยัง (ถ้าแก้แล้วจะไม่ auto-fill ทับให้อีก) ดู _maybeReresolvePrice — ค่า
  // เริ่มต้นต้องเป็น 0 (ไม่ใช่ null) ให้ตรงกับ unitPriceFc เริ่มต้นของบรรทัดใหม่ ไม่เช่นนั้นบรรทัดที่เพิ่มก่อนเลือก
  // ผู้ขาย (unitPriceFc=0 ไม่เคย resolve) จะถูกมองว่า "ผู้ใช้แก้ไปแล้ว" (0 != null) ตั้งแต่แรก ทำให้ไม่มีวัน
  // auto-fill ย้อนหลังได้เลยแม้จำนวนจะเปลี่ยนก็ตาม
  double lastResolvedPrice = 0;
  String? priceSourceNote; // ที่มาของราคาที่ระบบเติม (ตารางราคา / ราคาซื้อล่าสุด เลขที่+วันที่) แสดงเป็น tooltip
  double discountPercent;
  String? vatType; // ว่าง = ใบสั่งซื้อเก่าก่อนมี VAT ต่อบรรทัด
  double vatRate;
  // หน่วยของบรรทัด — จำนวน/ราคาตามหน่วยนี้ (ไม่ระบุ = หน่วยหลัก) factor = จำนวนหน่วยหลักต่อ 1 หน่วย
  // uoms = หน่วยที่สินค้าอนุญาตให้ซื้อ (null = ยังไม่โหลด) บรรทัดจากใบขอซื้อใช้หน่วยของใบขอซื้อ (เปลี่ยนไม่ได้)
  int? uomId;
  String? uomCode, uomNameTh, uomNameEn;
  double factor;
  ImItemUoms? uoms;
  _LineForm({this.id, this.item, this.qtyOrdered = 0, this.unitPriceFc = 0, this.qtyReceived = 0, this.refPrDetailId,
      this.discountPercent = 0, this.vatType, this.vatRate = 0,
      this.uomId, this.uomCode, this.uomNameTh, this.uomNameEn, this.factor = 1});
}

class _PoTransactionDetailWidgetState extends State<PoTransactionDetailWidget> implements DocAppBarActionsHost {
  final _service = PoTransactionService();
  final _itemService = ImItemService();
  final _prService = PrTransactionService();
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
  ApVendor? _vendor;
  ImWarehouse? _warehouse;
  final _descCtrl = TextEditingController();
  String _status = 'Draft';
  String? _voidReason;
  DocActions _actions = const DocActions();
  String? _approvalMode;
  List<DocApprovalStep> _approvals = const [];
  List<OrderDeposit> _deposits = const []; // ใบมัดจำที่อ้างอิงใบสั่งนี้
  int? _refPrId; // ใบขอซื้อ (PR) ต้นทาง ถ้าเพิ่มรายการมาจาก _pickPrLines()
  String? _refPrDocNoLabel;
  // มิติหัวเอกสาร — ค่าเริ่มต้นจากใบขอซื้อที่ดึงรายการมา (แก้ได้) — user-approved 2026-11-02
  List<GlDimensionType> _dimTypes = [];
  Map<String, List<GlDimensionValue>> _dimValues = {};
  Map<int, int?> _dimSelections = {};
  // สาขา (user-approved 2026-11-18): ค่าเริ่มต้น สาขาของผู้ใช้ → สาขาของคลัง; ส่งต่อให้เอกสารที่อ้างอิง
  int? _branchId;
  List<Branch> _branches = [];
  bool _dimsLoaded = false;

  // รองรับสั่งซื้อสินค้าต่างประเทศเป็นสกุลเงินต่างประเทศ — unit_price_fc ต่อบรรทัดคือราคาในสกุลเงินนี้ (FC),
  // total_value_lc คำนวณจาก unit_price_fc * exchange_rate เสมอ มิเรอร์ ap_transaction_detail_widget.dart ทุกประการ
  List<Currency> _currencies = [];
  Currency? _currency;
  double _exchangeRate = 1;

  // ราคารวม VAT + ส่วนลด % + VAT ต่อบรรทัด (user-approved 2026-10-31) — ส่งต่อไปใบรับสินค้าที่ดึงรายการ
  bool _priceIncludesVat = false;
  final _vatRateService = VatRateService();
  List<VatRate> _vatRates = [];

  // ยอดบรรทัดเป็นบาท — มิเรอร์ backend lineAmountsLc (utils/vatCalc.js): ปัดยอดสกุลเงินเอกสารก่อนคูณอัตรา,
  // ราคารวม VAT ใช้ยอดรวมแปลงเป็นบาท ไม่รวม VAT คิด VAT จากยอดบาท
  static double _r2(double v) => ((v + 2.220446049250313e-16) * 100).roundToDouble() / 100; // = backend round2 (Number.EPSILON)
  LineAmounts _lineLc(_LineForm l) {
    final vat = l.vatType == null || l.vatType == 'NOVAT' ? 0.0 : l.vatRate;
    final a = calcLineAmounts(qty: l.qtyOrdered, price: l.unitPriceFc, discountPercent: l.discountPercent, vatRate: vat, priceIncludesVat: _priceIncludesVat);
    final gross = _r2(_r2(a.gross) * _exchangeRate);
    final net = _r2(_r2(a.net) * _exchangeRate);
    final total = _priceIncludesVat && vat != 0 ? _r2(_r2(a.total) * _exchangeRate) : _r2(net + _r2(net * vat / 100));
    return LineAmounts(gross, _r2(gross - net), net, _r2(total - net), total);
  }
  LineAmounts get _totalsLc {
    double g = 0, d = 0, n = 0, v = 0, t = 0;
    for (final l in _lines) {
      final a = _lineLc(l);
      g += a.gross; d += a.discount; n += a.net; v += a.vat; t += a.total;
    }
    return LineAmounts(g, d, n, v, t);
  }

  String _vatLabel(VatRate v) {
    final rateStr = v.rate == v.rate.roundToDouble() ? v.rate.toStringAsFixed(0) : v.rate.toString();
    return '${v.vatCode} $rateStr%';
  }
  // ที่มาของราคาที่ระบบเติมให้ — ตารางราคา หรือราคาซื้อล่าสุดจากผู้ขายรายนี้ (เอกสาร + วันที่)
  String? _priceSourceNote(Map<String, dynamic> r) {
    final isEnglish = _isEnglish;
    if (r['source'] == 'LIST') return isEnglish ? 'Price list price' : 'ราคาตามตารางราคา';
    if (r['source'] != 'LAST') return null;
    final d = parseLocalDateNullable(r['ref_doc_date']?.toString());
    final date = d != null ? DateFormat('dd/MM/yyyy').format(d) : '';
    return isEnglish ? 'Last purchase price: ${r['ref_doc_no'] ?? ''} $date' : 'ราคาซื้อล่าสุด: ${r['ref_doc_no'] ?? ''} $date';
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

  // sys_module='51' มีมากกว่าหนึ่งประเภทเอกสารได้ (เช่น POR ของ PO, PRQ ของ PR) จึงต้องกรองซ้ำด้วย sys_doc_type
  // '10' คือ PO (ตาม poSysDocType ใน sa_anan_module.dart) แล้วให้ผู้ใช้เลือกเองเหมือนหน้าจอธุรกรรม AR/AP — เผื่อ
  // ผู้ใช้สร้างประเภทเอกสาร PO มากกว่าหนึ่งชุดสำหรับกลุ่มรายการบัญชีที่ต่างกัน
  static const _poSysDocType = '10';
  List<ModuleDocument> _allowedDocTypes = [];
  ModuleDocument? _docType;

  List<_LineForm> _lines = [];

  // Rejected แก้ไขแล้วส่งอนุมัติใหม่ได้เหมือน Draft
  bool get _isEditable => ['Draft', 'Rejected'].contains(_status);
  bool get _isReadOnly => widget.viewOnly || !_isEditable;

  @override
  void initState() {
    super.initState();
    widget.actions?.attach(this);
    _load();
  }

  @override
  void didUpdateWidget(covariant PoTransactionDetailWidget old) {
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
    _vendor = null;
    _warehouse = null;
    _descCtrl.clear();
    _status = 'Draft';
    _voidReason = null;
    _actions = const DocActions();
    _deposits = const [];
    _refPrId = null;
    _refPrDocNoLabel = null;
    _dimSelections = {};
    _branchId = defaultDocBranchId();
    _currency = _currencies.cast<Currency?>().firstWhere((c) => c!.baseCurrencyFlag, orElse: () => null);
    _exchangeRate = _currency?.baseRate ?? 1;
    _priceIncludesVat = false;
    _lines = [];
  }

  Future<void> _load() async {
    final isEnglish = _isEnglish;
    setState(() => _isLoading = true);
    try {
      if (_allowedDocTypes.isEmpty) {
        final docTypes = await _service.fetchDocTypesByUser();
        _allowedDocTypes = docTypes.where((d) => d.isDocType && d.sysDocType == _poSysDocType).toList();
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
        _vendor = ApVendor(id: h.vendorId, vendorCode: h.vendorCode ?? '', vendorNameTh: h.vendorNameTh ?? '');
        _warehouse = ImWarehouse(id: h.warehouseId, warehouseCode: h.warehouseCode ?? '', warehouseNameTh: h.warehouseNameTh ?? '', warehouseNameEn: h.warehouseNameEn);
        _descCtrl.text = h.description ?? '';
        _status = 'Draft';
        _voidReason = null;
        _actions = const DocActions();
        _deposits = const [];
        _refPrId = null;
        _refPrDocNoLabel = null;
        _dimSelections = {1: h.dim1Id, 2: h.dim2Id, 3: h.dim3Id, 4: h.dim4Id, 5: h.dim5Id};
        _branchId = h.branchId;
        _currency = _currencies.cast<Currency?>().firstWhere(
            (c) => c?.id == h.currencyId || c?.currencyCode == h.currencyCode, orElse: () => null);
        _exchangeRate = h.exchangeRate;
        _priceIncludesVat = h.priceIncludesVat;
        final items = await Future.wait(h.details.map((d) => _itemService.fetchRow(d.itemId)));
        _lines = [
          for (var i = 0; i < h.details.length; i++)
            _LineForm(
              item: items[i],
              qtyOrdered: h.details[i].qtyOrdered,
              unitPriceFc: h.details[i].unitPriceFc,
              discountPercent: h.details[i].discountPercent,
              vatType: h.details[i].vatType,
              vatRate: h.details[i].vatRate,
              uomId: h.details[i].uomId ?? items[i].baseUomId,
              uomCode: h.details[i].uomCode ?? items[i].baseUomCode,
              uomNameTh: h.details[i].uomId != null ? h.details[i].uomNameTh : items[i].baseUomNameTh,
              uomNameEn: h.details[i].uomId != null ? h.details[i].uomNameEn : items[i].baseUomNameEn,
              factor: h.details[i].conversionFactor,
            ),
        ];
        for (final l in _lines) { _loadLineUoms(l); }
        // ใบเก่าก่อนมี VAT ต่อบรรทัด — ใบใหม่ใช้ VAT ตั้งต้นของสินค้า
        for (final l in _lines) {
          if (l.vatType == null) _applyDefaultVat(l);
        }
        // คำนวณวันครบกำหนดใหม่จากเงื่อนไขเครดิตของผู้ขายบน doc_date ใหม่ (วันนี้) — ไม่คัดลอกวันครบกำหนดเดิมมาตรงๆ
        // เพราะเอกสารที่คัดลอกเป็นธุรกรรมใหม่ที่เกิดขึ้นวันนี้ ไม่ใช่ของเดิมที่ย้อนวันที่ไป
        if (_vendor != null) _selectVendor(_vendor!);
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
        _vendor = ApVendor(id: h.vendorId, vendorCode: h.vendorCode ?? '', vendorNameTh: h.vendorNameTh ?? '');
        _warehouse = ImWarehouse(id: h.warehouseId, warehouseCode: h.warehouseCode ?? '', warehouseNameTh: h.warehouseNameTh ?? '', warehouseNameEn: h.warehouseNameEn);
        _descCtrl.text = h.description ?? '';
        _status = h.status;
        _voidReason = h.voidReason;
        _actions = h.actions;
        _approvalMode = h.approvalMode;
        _approvals = h.approvals;
        _deposits = h.deposits;
        _refPrId = h.refPrId;
        _refPrDocNoLabel = h.refPrDocNo;
        _dimSelections = {1: h.dim1Id, 2: h.dim2Id, 3: h.dim3Id, 4: h.dim4Id, 5: h.dim5Id};
        _branchId = h.branchId;
        _currency = _currencies.cast<Currency?>().firstWhere(
            (c) => c?.id == h.currencyId || c?.currencyCode == h.currencyCode, orElse: () => null);
        _exchangeRate = h.exchangeRate;
        _priceIncludesVat = h.priceIncludesVat;
        // ดึง ImItem เต็มจาก itemId เสมอ ไม่ใช้ค่า snapshot (item_code/item_name) ที่บันทึกไว้ตอนสร้างเอกสารมาแสดง
        // ตรงๆ — มิเรอร์ im_transaction_detail_widget.dart:366 (โหลด GRN) ทุกประการ เพื่อให้ชื่อสินค้าที่แสดงตรงกับ
        // ข้อมูลสินค้าปัจจุบันเสมอ ไม่ขึ้นกับว่า snapshot ตอนสร้างถูกบันทึกไว้ครบหรือไม่
        final items = await Future.wait(h.details.map((d) => _itemService.fetchRow(d.itemId)));
        _lines = [
          for (var i = 0; i < h.details.length; i++)
            _LineForm(
              id: h.details[i].id,
              item: items[i],
              qtyOrdered: h.details[i].qtyOrdered,
              unitPriceFc: h.details[i].unitPriceFc,
              qtyReceived: h.details[i].qtyReceived,
              refPrDetailId: h.details[i].refPrDetailId,
              discountPercent: h.details[i].discountPercent,
              vatType: h.details[i].vatType,
              vatRate: h.details[i].vatRate,
              uomId: h.details[i].uomId ?? items[i].baseUomId,
              uomCode: h.details[i].uomCode ?? items[i].baseUomCode,
              uomNameTh: h.details[i].uomId != null ? h.details[i].uomNameTh : items[i].baseUomNameTh,
              uomNameEn: h.details[i].uomId != null ? h.details[i].uomNameEn : items[i].baseUomNameEn,
              factor: h.details[i].conversionFactor,
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

  void _selectVendor(ApVendor v) {
    setState(() {
      _vendor = v;
      // เงื่อนไขเครดิต: due_date = doc_date + creditTermMonths เดือน + creditTermDays วัน — สูตรเดียวกับ
      // ap_transaction_detail_widget.dart (เลือกผู้ขายแล้วคำนวณอัตโนมัติ) ผู้ใช้แก้ไขต่อได้เสมอ
      if (v.creditTermMonths > 0 || v.creditTermDays > 0) {
        var base = _docDate;
        if (v.creditTermMonths > 0) base = DateTime(base.year, base.month + v.creditTermMonths, base.day);
        if (v.creditTermDays > 0) base = base.add(Duration(days: v.creditTermDays));
        _dueDate = base;
      }
      // สกุลเงินหลักของผู้ขาย (ap_vendor.currency_code) — มิเรอร์ ap_transaction_detail_widget.dart:_onVendorChanged
      if (v.currencyCode.isNotEmpty) {
        final matched = _currencies.cast<Currency?>().firstWhere((c) => c!.currencyCode == v.currencyCode, orElse: () => null);
        if (matched != null) {
          _currency = matched;
          _exchangeRate = matched.baseRate > 0 ? matched.baseRate : 1;
        }
      }
    });
    _reresolveAllLinesForVendor();
  }

  // เลือก/เปลี่ยนผู้ขายแล้ว ให้ลองดึงราคาใหม่ให้ทุกบรรทัดที่ยังไม่ถูกผู้ใช้แก้ราคาเอง (รวมบรรทัดที่เพิ่มไว้ก่อนเลือก
  // ผู้ขาย ซึ่งไม่เคย resolve มาก่อนเลย) — ไม่ใช้ debounce Timer ร่วมกับ _maybeReresolvePrice (ตัวนั้นมี Timer เดียว
  // ใช้ร่วมกันทุกบรรทัด ถ้าเรียกวนหลายบรรทัดจะตัดกันเอง เหลือแค่บรรทัดสุดท้ายที่ resolve จริง) เรียกตรงทันทีแทน
  // เพราะเป็น action ครั้งเดียวตอนเปลี่ยนผู้ขาย ไม่ใช่การพิมพ์ต่อตัวอักษรที่ต้อง debounce
  Future<void> _reresolveAllLinesForVendor() async {
    final vendor = _vendor;
    if (vendor == null) return;
    for (final line in _lines) {
      if (line.item == null || line.unitPriceFc != line.lastResolvedPrice) continue;
      final resolved = await _service.resolvePrice(
        itemId: line.item!.id!, vendorId: vendor.id!, qty: line.qtyOrdered,
        docDate: DateFormat('yyyy-MM-dd').format(_docDate), uomId: line.uomId ?? line.item!.baseUomId,
        currencyCode: _currency?.currencyCode, priceIncludesVat: _priceIncludesVat, vatRate: _lineVatRate(line), fallbackLastPurchase: true,
      );
      if (!mounted || _vendor != vendor) return;
      if (resolved['unit_price_fc'] != null && line.unitPriceFc == line.lastResolvedPrice) {
        final price = double.tryParse(resolved['unit_price_fc'].toString()) ?? 0;
        setState(() { line.unitPriceFc = price; line.lastResolvedPrice = price; line.priceSourceNote = _priceSourceNote(resolved); });
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
    await _loadLineUoms(line, applyDefault: true); // หน่วยซื้อตั้งต้นของสินค้า
    if (!mounted) return;
    if (_vendor != null) {
      final resolved = await _service.resolvePrice(
        itemId: result.id!, vendorId: _vendor!.id!, qty: 1, docDate: DateFormat('yyyy-MM-dd').format(_docDate),
        uomId: line.uomId ?? result.baseUomId,
        currencyCode: _currency?.currencyCode, priceIncludesVat: _priceIncludesVat, vatRate: _lineVatRate(line), fallbackLastPurchase: true,
      );
      if (resolved['unit_price_fc'] != null && mounted) {
        final price = double.tryParse(resolved['unit_price_fc'].toString()) ?? 0;
        setState(() { line.unitPriceFc = price; line.lastResolvedPrice = price; line.priceSourceNote = _priceSourceNote(resolved); });
      }
    }
  }

  // เรียกซ้ำเมื่อจำนวนในบรรทัดเปลี่ยน เพราะ im_price_list มี tier ตาม min_qty — ถ้าจำนวนที่แก้ใหม่ควรได้ราคาขั้น
  // ต่างจากเดิม ต้องดึงราคามาใหม่ ไม่ใช่ตรึงราคาที่ resolve ไว้ครั้งเดียวตอนกดเพิ่มรายการ (qty=1 คงที่) เดิม —
  // debounce ไว้ไม่ยิง request ทุกตัวอักษรที่พิมพ์ และข้ามการ auto-fill ถ้าผู้ใช้แก้ราคาเองไปจากค่าที่ระบบเคย
  // auto-fill ให้แล้ว (ถือว่าตั้งใจ ไม่ทับราคาที่แก้เอง)
  void _maybeReresolvePrice(_LineForm line) {
    _priceResolveDebounce?.cancel();
    if (_vendor == null || line.item == null) return;
    _priceResolveDebounce = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted || line.unitPriceFc != line.lastResolvedPrice) return;
      final resolved = await _service.resolvePrice(
        itemId: line.item!.id!, vendorId: _vendor!.id!, qty: line.qtyOrdered, docDate: DateFormat('yyyy-MM-dd').format(_docDate),
        uomId: line.uomId ?? line.item!.baseUomId,
        currencyCode: _currency?.currencyCode, priceIncludesVat: _priceIncludesVat, vatRate: _lineVatRate(line), fallbackLastPurchase: true,
      );
      if (resolved['unit_price_fc'] != null && mounted && line.unitPriceFc == line.lastResolvedPrice) {
        final price = double.tryParse(resolved['unit_price_fc'].toString()) ?? 0;
        setState(() { line.unitPriceFc = price; line.lastResolvedPrice = price; line.priceSourceNote = _priceSourceNote(resolved); });
      }
    });
  }

  // ค่า NUMERIC จาก PostgreSQL ผ่าน pg driver มาเป็น String เสมอ (ไม่ใช่ num) — ต้อง parse ด้วย toString() เท่านั้น
  // ห้ามใช้ `as num?` ตรงๆ (จะ throw runtime TypeError) มิเรอร์ toDouble() ที่ใช้ทั่วทั้ง *_transaction.dart models
  double _prNum(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  // เพิ่มรายการเข้า PO จากบรรทัดที่ยังแปลงได้ของใบขอซื้อ (PR) ที่อนุมัติแล้ว (multi-select ได้ ข้าม PR หลายใบใน
  // ครั้งเดียว) มิเรอร์ _pickPoLines ใน im_transaction_detail_widget.dart (เพิ่มรายการเข้า GRN จาก PO) ทุกประการ
  Future<void> _pickPrLines() async {
    final isEnglish = _isEnglish;
    List<Map<String, dynamic>> lines;
    try {
      lines = await _prService.fetchConvertibleLines();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
      return;
    }
    final alreadyPicked = _lines.map((l) => l.refPrDetailId).whereType<int>().toSet();
    final selectable = lines.where((l) => !alreadyPicked.contains(l['detail_id'] as int)).toList();
    if (selectable.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'No convertible PR lines left' : 'ไม่มีรายการที่แปลงได้เหลืออยู่')));
      return;
    }
    final qtyCtrls = {for (final l in selectable) l['detail_id'] as int: TextEditingController(text: _fmtQty.format((l['qty_remaining'] as num).toDouble()))};
    final selected = {for (final l in selectable) l['detail_id'] as int: false};

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
            title: Text(isEnglish ? 'Select Lines from Purchase Requisition' : 'เลือกรายการจากใบขอซื้อ'),
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
                      // ราคาประมาณของ PR เป็นสกุลเงินของ PR เอง ซึ่งอาจไม่ตรงกับสกุลเงินที่เลือกไว้ในใบสั่งซื้อนี้ —
                      // แสดงกำกับไว้เป็น hint เท่านั้น ผู้ใช้ต้องตรวจสอบ/แก้ราคาเองหลังเพิ่มรายการ ไม่ auto-convert ให้
                      // (ต่างจาก PO→GRN ที่ exchange_rate ของ PO ต้นทางนำมาใช้แปลงได้ตรงๆ เพราะเป็นเอกสารเดียวกัน)
                      Expanded(
                        flex: 1,
                        child: Text('@ ${_fmtQty.format(_prNum(l['estimated_unit_cost']))} ${l['currency_code'] ?? ''}'.trim(),
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
      for (var i = 0; i < pickedLines.length; i++) {
        final l = pickedLines[i];
        final id = l['detail_id'] as int;
        final remaining = (l['qty_remaining'] as num).toDouble();
        final qty = (double.tryParse(qtyCtrls[id]!.text) ?? 0).clamp(0, remaining);
        final line = _LineForm(
          item: items[i],
          qtyOrdered: qty.toDouble(),
          unitPriceFc: _prNum(l['estimated_unit_cost']),
          refPrDetailId: id,
          // หน่วยตามใบขอซื้อ (ใบเก่าไม่มีหน่วย = หน่วยหลัก)
          uomId: (l['uom_id'] as int?) ?? items[i].baseUomId,
          uomCode: (l['uom_code'] as String?) ?? items[i].baseUomCode,
          uomNameTh: l['uom_id'] != null ? l['uom_name_th'] as String? : items[i].baseUomNameTh,
          uomNameEn: l['uom_id'] != null ? l['uom_name_en'] as String? : items[i].baseUomNameEn,
          factor: l['conversion_factor'] == null ? 1 : _prNum(l['conversion_factor']),
        );
        _applyDefaultVat(line);
        _lines.add(line);
      }
      _refPrId = pickedLines.first['header_id'] as int;
      _refPrDocNoLabel = pickedLines.first['doc_no'] as String?;
      // มิติ: ยังไม่ได้เลือกเลย = ใช้มิติของใบขอซื้อใบแรกที่เลือก
      if (!_dimSelections.values.any((v) => v != null)) {
        _dimSelections = {for (var i = 1; i <= 5; i++) i: pickedLines.first['dim${i}_id'] as int?};
      }
      // สาขา: ใช้สาขาของเอกสารต้นทางที่เลือก (ถ้ามี)
      _branchId = (pickedLines.first['branch_id'] as int?) ?? _branchId;
    });
  }

  // ชื่อหน่วยของบรรทัดใน picker (map จาก API)
  String _pickUomName(Map<String, dynamic> l) {
    final th = l['uom_name_th']?.toString() ?? '', en = l['uom_name_en']?.toString() ?? '';
    final n = _isEnglish && en.isNotEmpty ? en : th;
    return n.isNotEmpty ? n : (l['uom_code']?.toString() ?? '');
  }

  // หน่วยที่เลือกได้ของบรรทัด (หน่วยที่สินค้าอนุญาตให้ซื้อ) — applyDefault = ตั้งหน่วยซื้อตั้งต้นของสินค้า (บรรทัดใหม่)
  Future<void> _loadLineUoms(_LineForm l, {bool applyDefault = false}) async {
    final id = l.item?.id;
    if (id == null || _isReadOnly || l.refPrDetailId != null) return;
    try {
      final u = await _itemService.fetchItemUoms(id, purpose: 'PURCHASE');
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

  // เปลี่ยนหน่วยของบรรทัด — ราคาคูณตามอัตราใหม่ (ราคาต่อหน่วยหลักคงเดิม) แล้วดึงราคาตามตารางราคา/ราคาซื้อล่าสุดของหน่วยใหม่
  void _setLineUom(_LineForm l, ImItemUomOption opt, {bool reresolve = true}) {
    final ratio = l.factor == 0 ? 1.0 : opt.factor / l.factor;
    setState(() {
      final auto = l.unitPriceFc == l.lastResolvedPrice;
      if (ratio != 1 && l.unitPriceFc != 0) {
        l.unitPriceFc = (l.unitPriceFc * ratio * 1e4).roundToDouble() / 1e4;
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
    final deco = InputDecoration(labelText: isEnglish ? 'Unit' : 'หน่วย', isDense: true, border: const OutlineInputBorder());
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13);
    Widget w;
    if (_isReadOnly || opts.length <= 1 || l.qtyReceived > 0 || l.refPrDetailId != null) {
      w = InputDecorator(decoration: deco, child: Text(_lineUomName(l), style: style, overflow: TextOverflow.ellipsis));
    } else {
      w = DropdownButtonFormField<int>(
        value: opts.any((u) => u.uomId == l.uomId) ? l.uomId : null,
        isExpanded: true,
        isDense: true,
        decoration: deco,
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
  ({PoTransactionHeader header, List<PoTransactionDetail> details}) _savePayload() {
    final header = PoTransactionHeader(
      id: _id ?? 0, docId: _docId ?? 0, docNo: _docNo, docDate: _docDate,
      vendorId: _vendor!.id!, warehouseId: _warehouse!.id, dueDate: _dueDate,
      currencyId: _currency?.id, currencyCode: _currency?.currencyCode ?? CurrencyService.baseCode, exchangeRate: _exchangeRate,
      priceIncludesVat: _priceIncludesVat,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      refPrId: _refPrId,
      dim1Id: _dimSelections[1], dim2Id: _dimSelections[2], dim3Id: _dimSelections[3],
      dim4Id: _dimSelections[4], dim5Id: _dimSelections[5],
      branchId: _branchId,
    );
    final details = _lines
        .map((l) => PoTransactionDetail(
              id: l.id, lineNo: 0, itemId: l.item!.id!, itemCode: l.item!.itemCode, itemName: l.item!.itemNameTh,
              uomId: l.uomId, qtyOrdered: l.qtyOrdered, unitPriceFc: l.unitPriceFc, refPrDetailId: l.refPrDetailId,
              discountPercent: l.discountPercent, vatType: l.vatType, vatRate: l.vatRate,
            ))
        .toList();
    return (header: header, details: details);
  }

  Future<void> _save() async {
    final isEnglish = _isEnglish;
    if (_docType == null) { _warn(isEnglish ? 'Please select a document type' : 'กรุณาเลือกประเภทเอกสาร'); return; }
    if (_vendor == null) { _warn(isEnglish ? 'Please select a vendor' : 'กรุณาระบุผู้ขาย'); return; }
    if (_warehouse == null) { _warn(isEnglish ? 'Please select a warehouse' : 'กรุณาระบุคลังปลายทาง'); return; }
    if (_lines.isEmpty) { _warn(isEnglish ? 'At least 1 line is required' : 'ต้องมีรายการสั่งซื้ออย่างน้อย 1 รายการ'); return; }
    for (final l in _lines) {
      if (l.item == null || l.qtyOrdered <= 0) { _warn(isEnglish ? 'Please complete every line' : 'กรุณากรอกรายการให้ครบถ้วน'); return; }
    }
    setState(() => _isSaving = true);
    try {
      final p = _savePayload();
      final header = p.header, details = p.details;
      if (_id == null) {
        await _service.createTransaction(header: header, details: details);
      } else {
        await _service.updateTransaction(id: _id!, header: header, details: details);
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

  Future<void> _confirmAction(String titleTh, String titleEn, String bodyTh, String bodyEn, Future<PoTransactionHeader> Function() action) async {
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
      title: fromClosed ? (isEnglish ? 'Reopen Purchase Order' : 'ถอยการปิดใบสั่งซื้อ') : (isEnglish ? 'Reverse to Draft' : 'ถอยเป็นร่าง'),
      message: fromClosed
          ? (isEnglish
              ? 'Reopen this PO? Its status will be recalculated from the goods receipts that reference it.'
              : 'ถอยการปิดใบสั่งซื้อนี้? สถานะจะคำนวณใหม่จากใบรับสินค้าที่อ้างอิง')
          : (isEnglish
              ? 'Reverse this PO to draft? Pending approvals are skipped. You can edit it and submit it again with the same number.'
              : 'ถอยใบสั่งซื้อนี้เป็นร่าง? ผู้อนุมัติที่ยังไม่ตัดสินจะถูกข้าม แก้ไขแล้วส่งอนุมัติใหม่ได้ด้วยเลขที่เดิม'),
      confirmLabel: fromClosed ? (isEnglish ? 'Reopen' : 'ถอยการปิด') : (isEnglish ? 'Reverse to Draft' : 'ถอยเป็นร่าง'),
      color: Colors.orange[800]!,
      action: (r) => _service.reverseTransaction(_id!, r),
    );
  }

  void _voidDoc() {
    final isEnglish = _isEnglish;
    _reasonAction(
      title: isEnglish ? 'Void Purchase Order' : 'ยกเลิกใบสั่งซื้อ',
      message: isEnglish
          ? 'Void this PO? It will no longer be usable.'
          : 'ยกเลิกใบสั่งซื้อนี้? จะนำไปอ้างอิงไม่ได้อีก',
      confirmLabel: isEnglish ? 'Void' : 'ยกเลิกใบสั่งซื้อ',
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
          : 'ลบร่างใบสั่งซื้อนี้? ระบบเก็บไว้ด้วยสถานะ "ลบแล้ว" เพื่อตรวจสอบ และนำกลับมาใช้ไม่ได้',
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
    if ((['Approved', 'PartiallyReceived', 'FullyReceived', 'Closed'].contains(_status) && canApprove ||
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
      a.add(DocBarAction.primary(en ? 'Submit' : 'ส่งอนุมัติ', busy ? null : () => _confirmAction(
          'ยืนยันการส่งอนุมัติ', 'Confirm Submit for Approval',
          'ส่งอนุมัติใบสั่งซื้อ $_docNo? ระหว่างรออนุมัติจะแก้ไขไม่ได้ หลังอนุมัติแล้วใบรับสินค้า (GRN) จึงอ้างอิงได้',
          'Submit PO $_docNo for approval? It cannot be edited while waiting. GRN can reference it once approved.',
          () => _service.submitTransaction(_id!, menuId: perm!.id)), DocBarColors.submit));
    }
    if (['Approved', 'PartiallyReceived', 'FullyReceived'].contains(_status) && canApprove && !widget.viewOnly) {
      a.add(DocBarAction.primary(en ? 'Close' : 'ปิดใบสั่งซื้อ', busy ? null : () => _confirmAction(
          'ยืนยันปิดใบสั่งซื้อ', 'Close Purchase Order',
          'ปิดใบสั่งซื้อนี้? ใช้เมื่อไม่มีการรับสินค้าเพิ่มแล้ว (แม้ยังรับไม่ครบ 100%)${orderDepositCloseNote(_deposits, false)}',
          'Close this PO? Use this when no more receiving is expected (even if not 100% received).${orderDepositCloseNote(_deposits, true)}',
          () => _service.closeTransaction(_id!)), DocBarColors.post));
    }
    if (['Approved', 'PartiallyReceived', 'FullyReceived'].contains(_status) && _id != null && canApprove && !widget.viewOnly) {
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
      return docFingerprint([p.header, p.details, ]);
    } catch (_) {
      return 'incomplete|${docFingerprint([_vendor?.id, _warehouse?.id, _lines.length, _descCtrl.text])}';
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
    widget.actions?.scheduleRefresh();
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;

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
                Expanded(child: Text('${isEnglish ? "PO No." : "เลขที่ใบสั่งซื้อ"}: $_docNo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blueGrey.shade100, borderRadius: BorderRadius.circular(12)),
                  child: Text(poTransactionStatusLabel(_status, isEnglish), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
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
                  flex: 2,
                  child: _fkField(
                    label: isEnglish ? 'Vendor *' : 'ผู้ขาย *',
                    hasValue: _vendor != null,
                    displayText: '${_vendor?.vendorCode ?? ''}  ${_vendor?.vendorNameTh ?? ''}',
                    onSearch: _isReadOnly ? null : () => ApVendorListWidget.search(context, onSelected: _selectVendor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _fkField(
                    label: isEnglish ? 'Warehouse *' : 'คลังปลายทาง *',
                    hasValue: _warehouse != null,
                    displayText: '${_warehouse?.warehouseCode ?? ''}  ${_warehouse?.warehouseNameTh ?? ''}',
                    onSearch: _isReadOnly ? null : () => ImWarehouseListWidget.search(context, onSelected: (w) => setState(() {
                      _warehouse = w;
                      _branchId ??= w.branchId; // ยังไม่มีสาขา → ใช้สาขาของคลัง
                    })),
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
                      _reresolveAllLinesForVendor(); // ใช้ตารางราคาตามสกุลเงินของเอกสาร
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('po_rate_${widget.resetKey}_$_id'),
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
              // สาขา — อยู่หน้ามิติ
              const SizedBox(height: 12),
              _fkField(
                label: isEnglish ? 'Branch' : 'สาขา',
                hasValue: _branchId != null,
                displayText: branchLabel(findBranch(_branches, _branchId), isEnglish),
                onSearch: _isReadOnly ? null : () async {
                  final r = await showUserBranchPicker(context, branches: _branches, selectedId: _branchId, isEnglish: isEnglish);
                  if (r != null && mounted) setState(() => _branchId = r.$2?.id);
                },
              ),
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(isEnglish ? 'Lines' : 'รายการสั่งซื้อ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                if (_currency != null && !_currency!.baseCurrencyFlag) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                    child: Text(isEnglish ? 'Unit price in ${_currency!.currencyCode}' : 'ราคา/หน่วยเป็น ${_currency!.currencyCode}', style: TextStyle(fontSize: 11, color: Colors.orange[800])),
                  ),
                ],
                if (_refPrDocNoLabel != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text(isEnglish ? 'From PR: $_refPrDocNoLabel' : 'อ้างอิงจากใบขอซื้อ: $_refPrDocNoLabel', style: TextStyle(fontSize: 11, color: Colors.indigo[700])),
                  ),
                ],
                const Spacer(),
                Checkbox(
                  value: _priceIncludesVat,
                  visualDensity: VisualDensity.compact,
                  onChanged: _isReadOnly ? null : (v) {
                    setState(() => _priceIncludesVat = v ?? false);
                    _reresolveAllLinesForVendor(); // ราคาตามตาราง: แปลงรวม/ไม่รวม VAT ใหม่
                  },
                ),
                Text(isEnglish ? 'Prices include VAT' : 'ราคารวม VAT'),
                const SizedBox(width: 12),
                if (!_isReadOnly) ...[
                  OutlinedButton.icon(onPressed: _pickPrLines, icon: const Icon(Icons.playlist_add_check, size: 16), label: Text(isEnglish ? 'From PR' : 'จากใบขอซื้อ')),
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
                    SizedBox(width: 110, child: _uomField(l, isEnglish)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      child: TextFormField(
                        // ราคาที่ระบบเติมให้ภายหลัง (ตารางราคา) / ราคาที่คูณตามหน่วยใหม่ ต้องแสดงในช่อง — initialValue
                        // ไม่อัปเดตเอง จึงสร้างช่องใหม่เมื่อราคาตั้งต้นหรือหน่วยเปลี่ยน
                        key: ValueKey('price_${identityHashCode(l)}_${l.lastResolvedPrice}_${l.uomId}'),
                        initialValue: _fmtValue.format(l.unitPriceFc),
                        enabled: !_isReadOnly,
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          labelText: (isEnglish ? 'Unit Price' : 'ราคา/หน่วย') + (_currency != null ? ' (${_currency!.currencyCode})' : ''),
                          isDense: true, border: const OutlineInputBorder(),
                          suffixIcon: l.priceSourceNote != null && l.unitPriceFc == l.lastResolvedPrice
                              ? Tooltip(message: l.priceSourceNote!, child: Icon(
                                  l.priceSourceNote!.startsWith(isEnglish ? 'Last' : 'ราคาซื้อล่าสุด') ? Icons.history : Icons.list_alt,
                                  size: 14, color: Colors.grey.shade600))
                              : null,
                          suffixIconConstraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                        ),
                        onChanged: (v) => setState(() => l.unitPriceFc = double.tryParse(v) ?? 0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 70,
                      child: TextFormField(
                        initialValue: _fmtQty.format(l.discountPercent),
                        enabled: !_isReadOnly,
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(labelText: isEnglish ? 'Disc %' : 'ส่วนลด %', isDense: true, border: const OutlineInputBorder()),
                        onChanged: (v) => setState(() => l.discountPercent = (double.tryParse(v) ?? 0).clamp(0, 100).toDouble()),
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
                    if (l.qtyReceived > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(isEnglish ? 'Recv: ${_fmtQty.format(l.qtyReceived)}' : 'รับแล้ว: ${_fmtQty.format(l.qtyReceived)}',
                            style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
                      ),
                    AttachmentButton(moduleCode: 'po_transaction_detail', entityId: l.id, readOnly: _isReadOnly),
                    if (!_isReadOnly)
                      IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), onPressed: () => setState(() => _lines.removeAt(i))),
                  ]),
                );
              }),
              const Divider(),
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
// Item picker dialog — มิเรอร์ im_stock_aging_report_screen.dart
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
