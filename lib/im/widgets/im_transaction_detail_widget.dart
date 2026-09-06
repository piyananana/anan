import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/im_transaction.dart';
import '../models/im_item.dart';
import '../models/im_gl_account_setup.dart';
import '../services/im_transaction_service.dart';
import '../services/im_item_service.dart';
import '../widgets/im_item_list_widget.dart';
import '../widgets/im_warehouse_list_widget.dart';
import '../widgets/im_location_tree_widget.dart';
import '../models/im_warehouse.dart';
import '../models/im_location.dart';
import '../../gl/models/gl_period.dart';
import '../../gl/services/gl_period_service.dart';
import '../../gl/services/gl_entry_service.dart';
import '../../gl/models/gl_entry.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../ap/models/ap_vendor.dart';
import '../../ap/widgets/ap_vendor_list_widget.dart';
import '../../ar/models/ar_customer.dart';
import '../../ar/widgets/ar_customer_list_widget.dart';
import '../../cd/models/cd_vat_rate.dart';
import '../../cd/services/cd_vat_rate_service.dart';

double _parseNum(String s) => double.tryParse(s.trim()) ?? 0;

// ── Mutable UI state for one count line — kept separate from ImTransactionDetail
// so controllers/loading flags don't leak into the plain data model. ───────────
// isIssueMode (sys_doc_type='60', ISS — เบิกสินค้า) / isTransferMode (sys_doc_type='70', TRF — โอนสินค้า) /
// isReceiveMode (sys_doc_type='10'/'11'/'12', GRN — รับสินค้า) / isDeliverMode (sys_doc_type='30'/'31'/'32', DLN —
// ส่งสินค้า): ผู้ใช้กรอก "จำนวนที่เบิก/โอน/รับ/ส่ง" (delta) โดยตรง แทนที่จะกรอก "ยอดนับได้" (absolute target) แบบ AJS
// — counted ยังคงเป็น absolute target เสมอ เพื่อให้ backend (im_transaction_detail.counted_qty /
// applyStockMovement) ใช้สูตรเดียวกันได้โดยไม่ต้องแก้ engine: counted = systemQty -/+ จำนวนที่กรอก (ลบสำหรับ
// เบิก/โอนออก/ส่ง, บวกสำหรับรับเข้า) — ทุกโหมดใช้กลไกเดียวกันทุกประการ ต่างกันแค่ label ที่แสดงและทิศทางบวก/ลบ
// (ดู _isIssueMode / _isTransferMode / _isReceiveMode / _isDeliverMode ใน state)
class _CountLine {
  int? id;
  ImItem item;
  int? locationId;
  String? locationCode;
  int? toLocationId; // TRF เท่านั้น — ตำแหน่งจัดเก็บฝั่งปลายทาง
  String? toLocationCode;
  int? uomId;
  String? uomCode;
  double systemQty;
  bool loadingSystemQty = false;
  final bool isIssueMode;
  final bool isTransferMode;
  final bool isReceiveMode;
  final bool isDeliverMode;
  final bool isApReturnCnMode; // '15'/'20' (คืนสินค้าผู้ขาย/ลดหนี้เจ้าหนี้) — ลดสต็อก, AP CN
  final bool isApDnMode; // '25' (เพิ่มหนี้เจ้าหนี้) — เพิ่มสต็อก, AP DN
  final bool isArReturnCnMode; // '35'/'40' (รับคืนจากลูกค้า/ลดหนี้ลูกหนี้) — เพิ่มสต็อก, AR CN
  final bool isArDnMode; // '45' (เพิ่มหนี้ลูกหนี้) — ลดสต็อก, AR DN
  final int? refImTransactionDetailId; // '15'/'35' เท่านั้น — บรรทัดต้นฉบับ (GRN/DLN) ที่บรรทัดนี้คืน
  // VAT ต่อบรรทัด — ใช้เฉพาะประเภทเอกสารที่สร้าง/อ้างอิงใบกำกับ AP/AR อัตโนมัติ (ดู _isVatMode ใน state) เก็บเป็น
  // field ธรรมดาแทน controller เพราะเป็นค่าที่เลือกจาก dropdown ไม่ใช่กรอกอิสระ (มิเรอร์ ar_transaction_detail_widget.dart)
  String? vatType;
  double vatRate;
  final TextEditingController countedQtyCtrl;
  final TextEditingController issueQtyCtrl;
  final TextEditingController unitCostCtrl;
  final TextEditingController billedUnitCostCtrl; // '12' เท่านั้น — ต้นทุนตามใบกำกับจริง (อาจต่างจาก unitCostCtrl)
  final TextEditingController unitPriceCtrl; // '31'/'32' เท่านั้น — ราคาขายต่อหน่วย ใช้คำนวณรายได้ตอนสร้างใบแจ้งหนี้ AR
  final TextEditingController lotNoCtrl;
  final TextEditingController serialNoCtrl;

  _CountLine({
    this.id,
    required this.item,
    this.locationId,
    this.locationCode,
    this.toLocationId,
    this.toLocationCode,
    this.uomId,
    this.uomCode,
    this.systemQty = 0,
    this.isIssueMode = false,
    this.isTransferMode = false,
    this.isReceiveMode = false,
    this.isDeliverMode = false,
    this.isApReturnCnMode = false,
    this.isApDnMode = false,
    this.isArReturnCnMode = false,
    this.isArDnMode = false,
    this.refImTransactionDetailId,
    this.vatType,
    this.vatRate = 0,
    double countedQty = 0,
    double issueQty = 0,
    double? unitCost,
    double? billedUnitCost,
    double? unitPrice,
    String lotNo = '',
    String serialNo = '',
  })  : countedQtyCtrl = TextEditingController(text: countedQty == 0 ? '' : _fmtInput(countedQty)),
        issueQtyCtrl = TextEditingController(text: issueQty == 0 ? '' : _fmtInput(issueQty)),
        unitCostCtrl = TextEditingController(text: unitCost != null && unitCost != 0 ? _fmtInput(unitCost) : ''),
        billedUnitCostCtrl = TextEditingController(text: billedUnitCost != null && billedUnitCost != 0 ? _fmtInput(billedUnitCost) : ''),
        unitPriceCtrl = TextEditingController(text: unitPrice != null && unitPrice != 0 ? _fmtInput(unitPrice) : ''),
        lotNoCtrl = TextEditingController(text: lotNo),
        serialNoCtrl = TextEditingController(text: serialNo);

  bool get isDeltaMode =>
      isIssueMode || isTransferMode || isReceiveMode || isDeliverMode ||
      isApReturnCnMode || isApDnMode || isArReturnCnMode || isArDnMode;
  // ทิศทางบวก (เพิ่มสต็อก): รับสินค้า ('10'/'11'/'12'), เพิ่มหนี้เจ้าหนี้ ('25', รับของเพิ่ม), รับคืน/ลดหนี้ลูกหนี้
  // ('35'/'40', ลูกค้าคืนของ) — ที่เหลือ (เบิก/โอน/ส่ง/คืนผู้ขาย/ลดหนี้เจ้าหนี้/เพิ่มหนี้ลูกหนี้) เป็นทิศทางลบ
  bool get isIncreaseMode => isReceiveMode || isApDnMode || isArReturnCnMode;
  double get counted {
    if (!isDeltaMode) return _parseNum(countedQtyCtrl.text);
    final delta = _parseNum(issueQtyCtrl.text);
    return isIncreaseMode ? systemQty + delta : systemQty - delta;
  }

  double get variance => counted - systemQty;

  static String _fmtInput(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  void dispose() {
    countedQtyCtrl.dispose();
    issueQtyCtrl.dispose();
    unitCostCtrl.dispose();
    billedUnitCostCtrl.dispose();
    unitPriceCtrl.dispose();
    lotNoCtrl.dispose();
    serialNoCtrl.dispose();
  }
}

class ImTransactionDetailWidget extends StatefulWidget {
  final int? transactionId;
  final bool viewOnly;
  final int resetKey;
  final VoidCallback onSaveSuccess;
  final VoidCallback onCancel;
  final bool canDelete;

  const ImTransactionDetailWidget({
    super.key,
    this.transactionId,
    this.viewOnly = false,
    this.resetKey = 0,
    required this.onSaveSuccess,
    required this.onCancel,
    this.canDelete = true,
  });

  @override
  State<ImTransactionDetailWidget> createState() => _ImTransactionDetailWidgetState();
}

class _ImTransactionDetailWidgetState extends State<ImTransactionDetailWidget> {
  final ImTransactionService _service = ImTransactionService();
  final ImItemService _itemService = ImItemService();
  final PeriodService _periodService = PeriodService();
  final GlEntryService _glEntryService = GlEntryService();
  final VatRateService _vatRateService = VatRateService();
  List<VatRate> _vatRates = [];
  final _fmtQty = NumberFormat('#,##0.####');
  final _fmtMoney = NumberFormat('#,##0.00');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  bool _isEnglish = false;
  bool _isLoading = false;
  bool _isSaving = false;

  int? _id;
  int? _docId;
  String? _docCode, _docNameThai, _docNameEng;
  String? _selectedSysDocType;
  String _docNo = 'AUTO';
  DateTime _docDate = DateTime.now();
  int? _warehouseId;
  String? _warehouseLabel;
  int? _toWarehouseId;
  String? _toWarehouseLabel;
  int? _vendorId;
  String? _vendorLabel;
  int? _linkedApTransactionId;
  int? _customerId;
  String? _customerLabel;
  int? _linkedArTransactionId;
  int? _refImTransactionId; // '15'/'35' เท่านั้น — เอกสาร GRN/DLN ต้นฉบับที่จะคืน
  String? _refImTransactionLabel;
  final _refNoCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _status = 'Draft';
  int? _glEntryId;

  List<_CountLine> _lines = [];
  List<ModuleDocument> _docTypes = [];
  List<PostingPeriod> _openPeriods = [];
  ImGlAccountSetup? _docSetup;
  List<GlEntryDetail>? _postedGlDetails;

  bool get _isReadOnly => widget.viewOnly || _status != 'Draft';
  bool get _isIssueMode => _selectedSysDocType == '60'; // ISS — เบิกสินค้า
  bool get _isTransferMode => _selectedSysDocType == '70'; // TRF — โอนสินค้า
  bool get _isReceiveMode => _selectedSysDocType == '10' || _selectedSysDocType == '11' || _selectedSysDocType == '12'; // GRN — รับสินค้า
  bool get _isGrnBillingMode => _selectedSysDocType == '11'; // GRN Billing — รับสินค้า+ตั้งหนี้อัตโนมัติ
  bool get _isGrDeferredMode => _selectedSysDocType == '12'; // GR รอตั้งหนี้ — Post IM ก่อน ค่อย Post AP/GL ทีหลัง
  bool get _isDeliverMode => _selectedSysDocType == '30' || _selectedSysDocType == '31' || _selectedSysDocType == '32'; // DLN — ส่งสินค้า
  bool get _isDlnBillingMode => _selectedSysDocType == '31'; // DLN Billing — ส่งสินค้า+ตั้งหนี้อัตโนมัติ
  bool get _isDlnDeferredMode => _selectedSysDocType == '32'; // DLN รอตั้งหนี้ — Post IM ก่อน (COGS ทันที) ค่อย Post AR/GL ทีหลัง
  // Return/CN/DN family — '15'/'20'/'25' ฝั่งผู้ขาย (AP), '35'/'40'/'45' ฝั่งลูกค้า (AR) มิเรอร์ GRN/DLN แต่ทั้งคู่
  // auto-create เอกสาร AP/AR CN หรือ DN เสมอ (ต่างจาก '10'/'30' ที่ IM Post บัญชีของตัวเอง แยกจาก AP/AR) — '15'/'35'
  // เพิ่มเติมคือบังคับอ้างอิงเอกสารต้นฉบับ (GRN/DLN) เพื่อติดตามจำนวนคืนบางส่วน ส่วน '20'/'25'/'40'/'45' เป็นเอกสาร
  // อิสระเหมือน '11'/'31' ดู pattern การออกแบบใน memory project_im_grn_module/project_im_dln_module
  bool get _isReturnToSupplierMode => _selectedSysDocType == '15'; // คืนสินค้าผู้ขาย — บังคับอ้างอิงเอกสารต้นฉบับ
  bool get _isApReturnCnMode => _selectedSysDocType == '15' || _selectedSysDocType == '20'; // → AP CN (ลด AP)
  bool get _isApDnMode => _selectedSysDocType == '25'; // → AP DN (เพิ่ม AP)
  bool get _isApVendorMode => _isReceiveMode || _isApReturnCnMode || _isApDnMode; // ต้องเลือกผู้ขาย
  bool get _isReturnFromCustomerMode => _selectedSysDocType == '35'; // รับคืนจากลูกค้า — บังคับอ้างอิงเอกสารต้นฉบับ
  bool get _isArReturnCnMode => _selectedSysDocType == '35' || _selectedSysDocType == '40'; // → AR CN (ลด AR)
  bool get _isArDnMode => _selectedSysDocType == '45'; // → AR DN (เพิ่ม AR)
  bool get _isArCustomerMode => _isDeliverMode || _isArReturnCnMode || _isArDnMode; // ต้องเลือกลูกค้า
  bool get _isReturnSourceDocMode => _isReturnToSupplierMode || _isReturnFromCustomerMode;
  // VAT ต่อบรรทัด — เฉพาะประเภทเอกสารที่สร้าง/อ้างอิงใบกำกับ AP/AR อัตโนมัติ ('10'/'30' ไม่มี เพราะ IM Post บัญชีของ
  // ตัวเองแยกจาก AP/AR ไม่มีใบกำกับให้คิด VAT) มิเรอร์ ar_transaction_screen ตรงที่ VAT เลือกได้ต่อบรรทัด แต่ไม่มี
  // deferred VAT เพราะ IM Post ครั้งเดียวจบ ไม่มีขั้นตอนแยกตั้งหนี้กับรับชำระแบบ AR
  bool get _isApVatMode => _isGrnBillingMode || _isGrDeferredMode || _isApReturnCnMode || _isApDnMode;
  bool get _isArVatMode => _isDlnBillingMode || _isDlnDeferredMode || _isArReturnCnMode || _isArDnMode;
  bool get _isVatMode => _isApVatMode || _isArVatMode;
  // สถานะ Received ('12' ที่ Post IM แล้วแต่ยังไม่ Post AP/GL) หรือ Delivered ('32' ที่ Post IM แล้วแต่ยังไม่ Post
  // AR/GL) แก้ได้แค่เลขที่อ้างอิง + billed cost/ราคาขาย — ฟิลด์อื่น (จำนวน/สินค้า/คลัง) ยังคง lock ผ่าน _isReadOnly
  // ตามปกติ เพราะรับของ/ส่งของจริงไปแล้ว
  bool get _canEditBilling => !widget.viewOnly &&
      (_status == 'Draft' || (_isGrDeferredMode && _status == 'Received') || (_isDlnDeferredMode && _status == 'Delivered'));

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ImTransactionDetailWidget old) {
    super.didUpdateWidget(old);
    if (widget.resetKey != old.resetKey || widget.transactionId != old.transactionId) {
      _load();
    }
  }

  @override
  void dispose() {
    _refNoCtrl.dispose();
    _descCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _resetForm() {
    for (final l in _lines) {
      l.dispose();
    }
    _id = null;
    _docId = null;
    _docCode = null; _docNameThai = null; _docNameEng = null;
    _selectedSysDocType = null;
    _docNo = 'AUTO';
    _docDate = DateTime.now();
    _warehouseId = null;
    _warehouseLabel = null;
    _toWarehouseId = null;
    _toWarehouseLabel = null;
    _vendorId = null;
    _vendorLabel = null;
    _linkedApTransactionId = null;
    _customerId = null;
    _customerLabel = null;
    _linkedArTransactionId = null;
    _refImTransactionId = null;
    _refImTransactionLabel = null;
    _refNoCtrl.clear();
    _descCtrl.clear();
    _status = 'Draft';
    _glEntryId = null;
    _lines = [];
    _docSetup = null;
    _postedGlDetails = null;
  }

  Future<void> _load() async {
    final isEnglish = _isEnglish;
    setState(() => _isLoading = true);
    _resetForm();
    try {
      final results = await Future.wait([
        _service.fetchDocTypesByUser(),
        _periodService.fetchOpenGlPeriods(),
        _vatRateService.fetchRows(),
      ]);
      _docTypes = (results[0] as List<ModuleDocument>).where((d) => d.isDocType).toList();
      _openPeriods = results[1] as List<PostingPeriod>;
      _vatRates = (results[2] as List<VatRate>).where((v) => v.isActive).toList();
      if (_docTypes.length == 1) {
        await _selectDocType(_docTypes.first);
      }

      if (widget.transactionId != null) {
        await _loadExisting(widget.transactionId!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadExisting(int id) async {
    final tx = await _service.fetchRow(id);
    final h = tx.header;
    _id = h.id;
    _docId = h.docId;
    _docCode = h.docCode;
    _docNameThai = h.docNameThai;
    _docNameEng = h.docNameEng;
    _selectedSysDocType = h.sysDocType?.toString();
    _docNo = h.docNo;
    _docDate = h.docDate;
    _warehouseId = h.warehouseId;
    _warehouseLabel = '${h.warehouseCode ?? ''} ${h.warehouseNameTh ?? ''}'.trim();
    _toWarehouseId = h.toWarehouseId;
    _toWarehouseLabel = '${h.toWarehouseCode ?? ''} ${h.toWarehouseNameTh ?? ''}'.trim();
    _vendorId = h.vendorId;
    _vendorLabel = '${h.vendorCode ?? ''} ${h.vendorNameTh ?? ''}'.trim();
    _linkedApTransactionId = h.linkedApTransactionId;
    _customerId = h.customerId;
    _customerLabel = '${h.customerCode ?? ''} ${h.customerNameTh ?? ''}'.trim();
    _linkedArTransactionId = h.linkedArTransactionId;
    _refImTransactionId = h.refImTransactionId;
    _refImTransactionLabel = h.refImTransactionDocNo;
    _refNoCtrl.text = h.refNo ?? '';
    _descCtrl.text = h.description ?? '';
    _status = h.status;
    _glEntryId = h.glEntryId;

    final items = await Future.wait(tx.details.map((d) => _itemService.fetchRow(d.itemId)));
    final lines = <_CountLine>[];
    final isIncrease = _isReceiveMode || _isApDnMode || _isArReturnCnMode;
    final isDecrease = _isIssueMode || _isTransferMode || _isDeliverMode || _isApReturnCnMode || _isArDnMode;
    for (var i = 0; i < tx.details.length; i++) {
      final d = tx.details[i];
      lines.add(_CountLine(
        id: d.id,
        item: items[i],
        locationId: d.locationId,
        locationCode: d.locationCode,
        toLocationId: d.toLocationId,
        toLocationCode: d.toLocationCode,
        uomId: d.uomId,
        uomCode: d.uomCode,
        systemQty: d.systemQty,
        isIssueMode: _isIssueMode,
        isTransferMode: _isTransferMode,
        isReceiveMode: _isReceiveMode,
        isDeliverMode: _isDeliverMode,
        isApReturnCnMode: _isApReturnCnMode,
        isApDnMode: _isApDnMode,
        isArReturnCnMode: _isArReturnCnMode,
        isArDnMode: _isArDnMode,
        refImTransactionDetailId: d.refImTransactionDetailId,
        countedQty: d.countedQty,
        issueQty: isIncrease ? (d.countedQty - d.systemQty) : isDecrease ? (d.systemQty - d.countedQty) : 0,
        unitCost: d.unitCost,
        billedUnitCost: d.billedUnitCost,
        unitPrice: d.unitPrice,
        vatType: d.vatType,
        vatRate: d.vatRate ?? 0,
        lotNo: d.lotNo ?? '',
        serialNo: d.serialNo ?? '',
      ));
    }
    _lines = lines;

    if (_docCode != null) {
      _docSetup = await _service.fetchSetupByDocCode(_docCode!).catchError((_) => null);
    }
    // '32' ที่ Delivered แล้ว: ต้นทุนขาย (COGS) Post ไปแล้วตอน Post IM (gl_entry_id ถูกตั้งค่าจริง) ต่างจาก '12' ที่
    // ยังไม่มี GL ใดๆ เลยตอน Received — จึงต้อง fetch entry จริงมาแสดงเหมือนสถานะ Posted ทั่วไป
    if ((_status == 'Posted' || (_isDlnDeferredMode && _status == 'Delivered')) && _glEntryId != null) {
      final result = await _glEntryService.fetchEntryDetail(_glEntryId!);
      _postedGlDetails = result['details'] as List<GlEntryDetail>;
    }
  }

  Future<void> _selectDocType(ModuleDocument d) async {
    setState(() {
      _docId = d.id;
      _docCode = d.docCode;
      _docNameThai = d.docNameThai;
      _docNameEng = d.docNameEng;
      _selectedSysDocType = d.sysDocType;
    });
    _docSetup = await _service.fetchSetupByDocCode(d.docCode).catchError((_) => null);
    if (mounted) setState(() {});
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _docDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _docDate = picked);
  }

  void _selectWarehouse(ImWarehouse w) {
    setState(() {
      _warehouseId = w.id;
      _warehouseLabel = '${w.warehouseCode} ${w.warehouseNameTh}';
    });
  }

  void _selectToWarehouse(ImWarehouse w) {
    setState(() {
      _toWarehouseId = w.id;
      _toWarehouseLabel = '${w.warehouseCode} ${w.warehouseNameTh}';
    });
  }

  void _selectVendor(ApVendor v) {
    setState(() {
      _vendorId = v.id;
      _vendorLabel = '${v.vendorCode} ${v.vendorNameTh}';
    });
  }

  void _selectCustomer(ArCustomer c) {
    setState(() {
      _customerId = c.id;
      _customerLabel = '${c.customerCode} ${c.customerNameTh}';
    });
  }

  Future<void> _refreshSystemQty(_CountLine line) async {
    if (_warehouseId == null || line.item.id == null) return;
    setState(() => line.loadingSystemQty = true);
    try {
      final qty = await _service.fetchSystemQty(
        itemId: line.item.id!,
        warehouseId: _warehouseId!,
        locationId: line.locationId,
        lotNo: line.lotNoCtrl.text.trim().isEmpty ? null : line.lotNoCtrl.text.trim(),
        serialNo: line.serialNoCtrl.text.trim().isEmpty ? null : line.serialNoCtrl.text.trim(),
      );
      if (mounted) setState(() { line.systemQty = qty; line.loadingSystemQty = false; });
    } catch (_) {
      if (mounted) setState(() => line.loadingSystemQty = false);
    }
  }

  // ── VAT helpers ───────────────────────────────────────────────────────────
  String _vatLabel(String vatCode) {
    final v = _vatRates.cast<VatRate?>().firstWhere((x) => x?.vatCode == vatCode, orElse: () => null);
    if (v != null) {
      final rateStr = v.rate == v.rate.roundToDouble() ? v.rate.toStringAsFixed(0) : v.rate.toString();
      return '${v.vatCode}  $rateStr%';
    }
    return vatCode;
  }

  String _safeVatCode(String? vatCode) {
    if (vatCode != null && _vatRates.any((v) => v.vatCode == vatCode)) return vatCode;
    return _vatRates.isNotEmpty ? _vatRates.first.vatCode : (vatCode ?? 'NOVAT');
  }

  double _rateForVatCode(String vatCode) {
    final v = _vatRates.cast<VatRate?>().firstWhere((x) => x?.vatCode == vatCode, orElse: () => null);
    return v?.rate ?? 0.0;
  }

  void _addLine() {
    final isEnglish = _isEnglish;
    if (_warehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish ? 'Please select a warehouse first' : 'กรุณาเลือกคลังสินค้าก่อน')));
      return;
    }
    ImItemListWidget.search(context, itemTypeFilter: 'STOCK', onSelected: (ImItem item) {
      // prefill VAT ตอนเพิ่มบรรทัดจาก default_vat_type ของสินค้า (ถ้ามีตั้งค่าไว้และเอกสารประเภทนี้ใช้ VAT)
      final vatType = _isVatMode ? _safeVatCode(item.defaultVatType) : null;
      final line = _CountLine(
        item: item, uomId: item.baseUomId, uomCode: item.baseUomCode,
        isIssueMode: _isIssueMode, isTransferMode: _isTransferMode, isReceiveMode: _isReceiveMode, isDeliverMode: _isDeliverMode,
        isApReturnCnMode: _isApReturnCnMode, isApDnMode: _isApDnMode, isArReturnCnMode: _isArReturnCnMode, isArDnMode: _isArDnMode,
        vatType: vatType, vatRate: vatType != null ? _rateForVatCode(vatType) : 0,
      );
      setState(() => _lines.add(line));
      _refreshSystemQty(line);
    });
  }

  // '15'/'35' — เลือกเอกสารต้นฉบับ (GRN/DLN) ที่จะคืน ต้องทำก่อนเพิ่มบรรทัด (ดู _pickReturnLines) เปลี่ยนเอกสาร
  // ต้นฉบับ = ล้างบรรทัดเดิมทิ้งทั้งหมด เพราะอ้างอิงเอกสารเก่าไม่ตรงกับที่เลือกใหม่แล้ว
  Future<void> _pickReturnSourceDoc() async {
    final isEnglish = _isEnglish;
    final family = _isReturnToSupplierMode ? 'GRN' : 'DLN';
    final searchCtrl = TextEditingController();
    List<ImReturnableDoc> results = [];
    bool loading = true;
    bool searched = false;

    final picked = await showDialog<ImReturnableDoc>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        Future<void> doSearch() async {
          setSt(() => loading = true);
          try {
            results = await _service.fetchReturnableDocs(
              family: family,
              vendorId: _isReturnToSupplierMode ? _vendorId : null,
              customerId: _isReturnFromCustomerMode ? _customerId : null,
              search: searchCtrl.text.trim().isEmpty ? null : searchCtrl.text.trim(),
            );
          } catch (_) {
            results = [];
          }
          setSt(() => loading = false);
        }
        if (!searched) {
          searched = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => doSearch());
        }
        return AlertDialog(
            title: Text(isEnglish ? 'Select Source Document' : 'เลือกเอกสารต้นฉบับ'),
            content: SizedBox(
              width: 480,
              height: 420,
              child: Column(children: [
                TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(
                    labelText: isEnglish ? 'Search doc no.' : 'ค้นหาเลขที่เอกสาร',
                    border: const OutlineInputBorder(), isDense: true,
                    suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: doSearch),
                  ),
                  onSubmitted: (_) => doSearch(),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : results.isEmpty
                          ? Center(child: Text(isEnglish ? 'No documents found' : 'ไม่พบเอกสาร'))
                          : ListView.builder(
                              itemCount: results.length,
                              itemBuilder: (_, i) {
                                final d = results[i];
                                final partyLabel = _isReturnToSupplierMode
                                    ? '${d.vendorCode ?? ''} ${d.vendorNameTh ?? ''}'
                                    : '${d.customerCode ?? ''} ${d.customerNameTh ?? ''}';
                                return ListTile(
                                  dense: true,
                                  title: Text(d.docNo, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('${_dateFmt.format(d.docDate)} · $partyLabel · ${d.status}'),
                                  onTap: () => Navigator.pop(ctx, d),
                                );
                              },
                            ),
                ),
              ]),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก'))],
        );
      }),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _refImTransactionId = picked.id;
      _refImTransactionLabel = picked.docNo;
      if (_isReturnToSupplierMode) {
        _vendorId = picked.vendorId;
        _vendorLabel = '${picked.vendorCode ?? ''} ${picked.vendorNameTh ?? ''}'.trim();
      } else {
        _customerId = picked.customerId;
        _customerLabel = '${picked.customerCode ?? ''} ${picked.customerNameTh ?? ''}'.trim();
      }
      for (final l in _lines) {
        l.dispose();
      }
      _lines = [];
    });
  }

  // '15'/'35' — เลือกบรรทัดจากเอกสารต้นฉบับที่จะคืน (partial return ได้) ต้องเลือกเอกสารต้นฉบับก่อนเสมอ
  Future<void> _pickReturnLines() async {
    final isEnglish = _isEnglish;
    if (_refImTransactionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish ? 'Please select a source document first' : 'กรุณาเลือกเอกสารต้นฉบับก่อน')));
      return;
    }
    List<ImReturnableLine> lines;
    try {
      lines = await _service.fetchReturnableLines(_refImTransactionId!);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
      return;
    }
    final alreadyPicked = _lines.map((l) => l.refImTransactionDetailId).whereType<int>().toSet();
    final selectable = lines.where((l) => l.remainingQty > 0.0001 && !alreadyPicked.contains(l.id)).toList();
    if (selectable.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish ? 'No returnable lines left' : 'ไม่มีรายการที่คืนได้เหลืออยู่')));
      return;
    }
    final qtyCtrls = {for (final l in selectable) l.id: TextEditingController(text: _CountLine._fmtInput(l.remainingQty))};
    final selected = {for (final l in selectable) l.id: false};

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
            title: Text(isEnglish ? 'Select Lines to Return' : 'เลือกรายการที่จะคืน'),
            content: SizedBox(
              width: 560,
              height: 420,
              child: ListView.builder(
                itemCount: selectable.length,
                itemBuilder: (_, i) {
                  final l = selectable[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Checkbox(value: selected[l.id], onChanged: (v) => setSt(() => selected[l.id] = v ?? false)),
                      Expanded(flex: 3, child: Text('${l.itemCode ?? ''} ${l.itemName ?? ''}', overflow: TextOverflow.ellipsis)),
                      Expanded(
                        flex: 2,
                        child: Text(
                          isEnglish ? 'Remaining: ${_fmtQty.format(l.remainingQty)}' : 'คงเหลือคืนได้: ${_fmtQty.format(l.remainingQty)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: qtyCtrls[l.id],
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

    final pickedLines = selectable.where((l) => selected[l.id] == true && _parseNum(qtyCtrls[l.id]!.text) > 0).toList();
    if (pickedLines.isEmpty) return;
    final items = await Future.wait(pickedLines.map((l) => _itemService.fetchRow(l.itemId)));
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < pickedLines.length; i++) {
        final l = pickedLines[i];
        final qty = _parseNum(qtyCtrls[l.id]!.text).clamp(0, l.remainingQty);
        final vatType = _isVatMode ? _safeVatCode(items[i].defaultVatType) : null;
        final line = _CountLine(
          item: items[i],
          locationId: l.locationId, locationCode: l.locationCode,
          uomId: l.uomId, uomCode: l.uomCode,
          isApReturnCnMode: _isApReturnCnMode, isApDnMode: _isApDnMode,
          isArReturnCnMode: _isArReturnCnMode, isArDnMode: _isArDnMode,
          issueQty: qty.toDouble(),
          unitCost: l.unitCost,
          lotNo: l.lotNo ?? '',
          serialNo: l.serialNo ?? '',
          refImTransactionDetailId: l.id,
          vatType: vatType, vatRate: vatType != null ? _rateForVatCode(vatType) : 0,
        );
        _lines.add(line);
        _refreshSystemQty(line);
      }
    });
  }

  void _removeLine(_CountLine line) {
    setState(() => _lines.remove(line));
    line.dispose();
  }

  Future<void> _save(String action) async {
    final isEnglish = _isEnglish;
    void warn(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

    if (_docId == null) { warn(isEnglish ? 'Please select a document type' : 'กรุณาเลือกประเภทเอกสาร'); return; }
    if (_warehouseId == null) { warn(isEnglish ? 'Please select a warehouse' : 'กรุณาเลือกคลังสินค้า'); return; }
    if (_isTransferMode && _toWarehouseId == null) {
      warn(isEnglish ? 'Please select a destination warehouse' : 'กรุณาเลือกคลังปลายทาง');
      return;
    }
    if (_isApVendorMode && _vendorId == null) {
      warn(isEnglish ? 'Please select a vendor' : 'กรุณาเลือกผู้ขาย');
      return;
    }
    if (_isGrnBillingMode && _refNoCtrl.text.trim().isEmpty) {
      warn(isEnglish ? 'Please enter the vendor invoice number' : 'กรุณาระบุเลขที่ใบกำกับสินค้าผู้ขาย');
      return;
    }
    if (_isArCustomerMode && _customerId == null) {
      warn(isEnglish ? 'Please select a customer' : 'กรุณาเลือกลูกค้า');
      return;
    }
    if (_isReturnSourceDocMode && _refImTransactionId == null) {
      warn(isEnglish ? 'Please select a source document' : 'กรุณาเลือกเอกสารต้นฉบับ');
      return;
    }
    if (_lines.isEmpty) {
      warn(_isTransferMode
          ? (isEnglish ? 'Please add at least one transfer line' : 'กรุณาเพิ่มรายการโอนสินค้าอย่างน้อย 1 รายการ')
          : _isReceiveMode
              ? (isEnglish ? 'Please add at least one receiving line' : 'กรุณาเพิ่มรายการรับสินค้าอย่างน้อย 1 รายการ')
              : _isIssueMode
                  ? (isEnglish ? 'Please add at least one issue line' : 'กรุณาเพิ่มรายการเบิกสินค้าอย่างน้อย 1 รายการ')
                  : _isDeliverMode
                      ? (isEnglish ? 'Please add at least one delivery line' : 'กรุณาเพิ่มรายการส่งสินค้าอย่างน้อย 1 รายการ')
                      : (_isApReturnCnMode || _isApDnMode || _isArReturnCnMode || _isArDnMode)
                          ? (isEnglish ? 'Please add at least one line' : 'กรุณาเพิ่มรายการอย่างน้อย 1 รายการ')
                          : (isEnglish ? 'Please add at least one count line' : 'กรุณาเพิ่มรายการนับสต็อกอย่างน้อย 1 รายการ'));
      return;
    }

    if (action == 'Post') {
      final inOpenPeriod = _openPeriods.any((p) =>
          !_docDate.isBefore(p.periodStartDate) && !_docDate.isAfter(p.periodEndDate));
      if (!inOpenPeriod) {
        warn(isEnglish ? 'Document date is outside any open accounting period' : 'วันที่เอกสารอยู่นอกงวดบัญชีที่เปิดใช้งาน');
        return;
      }
      for (final l in _lines) {
        if (l.isDeltaMode && _parseNum(l.issueQtyCtrl.text) <= 0) {
          warn('${l.item.itemCode}: ${l.isTransferMode ? (isEnglish ? 'Transfer qty is required' : 'กรุณาระบุจำนวนที่โอน') : l.isReceiveMode ? (isEnglish ? 'Receive qty is required' : 'กรุณาระบุจำนวนที่รับ') : l.isDeliverMode ? (isEnglish ? 'Delivery qty is required' : 'กรุณาระบุจำนวนที่ส่ง') : l.isIssueMode ? (isEnglish ? 'Issue qty is required' : 'กรุณาระบุจำนวนที่เบิก') : (isEnglish ? 'Qty is required' : 'กรุณาระบุจำนวน')}');
          return;
        }
        if (l.isDeltaMode && !l.isIncreaseMode && l.counted < 0) {
          warn('${l.item.itemCode}: ${l.isTransferMode ? (isEnglish ? 'Transfer qty exceeds current balance' : 'จำนวนที่โอนเกินยอดคงเหลือ') : l.isDeliverMode ? (isEnglish ? 'Delivery qty exceeds current balance' : 'จำนวนที่ส่งเกินยอดคงเหลือ') : l.isIssueMode ? (isEnglish ? 'Issue qty exceeds current balance' : 'จำนวนที่เบิกเกินยอดคงเหลือ') : (isEnglish ? 'Qty exceeds current balance' : 'จำนวนเกินยอดคงเหลือ')}');
          return;
        }
        if (l.isTransferMode && _warehouseId == _toWarehouseId && l.locationId != null && l.locationId == l.toLocationId) {
          warn('${l.item.itemCode}: ${isEnglish ? 'Source and destination bin must differ' : 'ตำแหน่งต้นทางและปลายทางต้องไม่ใช่ตำแหน่งเดียวกัน'}');
          return;
        }
        if (l.item.costingMethod == 'SPECIFIC' && l.serialNoCtrl.text.trim().isEmpty) {
          warn('${l.item.itemCode}: ${isEnglish ? 'Serial No. is required' : 'กรุณาระบุ Serial No.'}');
          return;
        }
        if (l.variance > 0 && l.item.costingMethod != 'STANDARD' && _parseNum(l.unitCostCtrl.text) <= 0) {
          warn('${l.item.itemCode}: ${isEnglish ? 'Unit cost is required' : 'กรุณาระบุต้นทุนต่อหน่วย'}');
          return;
        }
        if (_isVatMode && (l.vatType == null || l.vatType!.isEmpty)) {
          warn('${l.item.itemCode}: ${isEnglish ? 'VAT type is required' : 'กรุณาระบุประเภทภาษี VAT'}');
          return;
        }
      }
    }

    setState(() => _isSaving = true);
    try {
      final header = ImTransactionHeader(
        id: _id ?? 0,
        docId: _docId!,
        docNo: _docNo,
        docDate: _docDate,
        warehouseId: _warehouseId!,
        toWarehouseId: _isTransferMode ? _toWarehouseId : null,
        vendorId: _isApVendorMode ? _vendorId : null,
        customerId: _isArCustomerMode ? _customerId : null,
        refNo: _refNoCtrl.text.trim().isEmpty ? null : _refNoCtrl.text.trim(),
        refImTransactionId: _isReturnSourceDocMode ? _refImTransactionId : null,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      );
      final details = _lines.map((l) => ImTransactionDetail(
            id: l.id,
            itemId: l.item.id!,
            itemCode: l.item.itemCode,
            itemName: l.item.itemNameTh,
            locationId: l.locationId,
            toLocationId: l.isTransferMode ? l.toLocationId : null,
            lotNo: l.lotNoCtrl.text.trim().isEmpty ? null : l.lotNoCtrl.text.trim(),
            serialNo: l.serialNoCtrl.text.trim().isEmpty ? null : l.serialNoCtrl.text.trim(),
            uomId: l.uomId,
            systemQty: l.systemQty,
            countedQty: l.counted,
            unitCost: l.unitCostCtrl.text.trim().isEmpty ? null : _parseNum(l.unitCostCtrl.text),
            unitPrice: l.unitPriceCtrl.text.trim().isEmpty ? null : _parseNum(l.unitPriceCtrl.text),
            vatType: _isVatMode ? l.vatType : null,
            vatRate: _isVatMode ? l.vatRate : null,
            refImTransactionDetailId: l.refImTransactionDetailId,
          )).toList();

      if (_id == null) {
        final result = await _service.createTransaction(header: header, details: details, action: action);
        _id = result.header.id;
      } else {
        if (_status == 'Draft') {
          await _service.updateTransaction(id: _id!, header: header, details: details);
        }
        if (action == 'Post') {
          await _service.postTransaction(_id!);
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish ? 'Saved successfully' : 'บันทึกสำเร็จ')));
        widget.onSaveSuccess();
      }
    } catch (e) {
      if (mounted) warn(isEnglish ? 'Save failed: $e' : 'บันทึกล้มเหลว: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // '12' สถานะ Received — บันทึกแค่เลขที่ใบกำกับ + billed cost รายบรรทัด ไม่แตะจำนวน/สินค้า/คลัง (รับของจริงไปแล้ว)
  Future<void> _saveBillingInfo() async {
    if (_id == null) return;
    final isEnglish = _isEnglish;
    void warn(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    setState(() => _isSaving = true);
    try {
      final header = ImTransactionHeader(
        id: _id!, docId: _docId!, docNo: _docNo, docDate: _docDate, warehouseId: _warehouseId!,
        vendorId: _vendorId, refNo: _refNoCtrl.text.trim().isEmpty ? null : _refNoCtrl.text.trim(),
      );
      final details = _lines.map((l) => ImTransactionDetail(
            id: l.id,
            itemId: l.item.id!,
            billedUnitCost: l.billedUnitCostCtrl.text.trim().isEmpty ? null : _parseNum(l.billedUnitCostCtrl.text),
          )).toList();
      await _service.updateTransaction(id: _id!, header: header, details: details);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Saved successfully' : 'บันทึกสำเร็จ')));
        await _loadExisting(_id!);
        setState(() {});
      }
    } catch (e) {
      if (mounted) warn(isEnglish ? 'Save failed: $e' : 'บันทึกล้มเหลว: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // '12' สถานะ Received -> Posted — สร้าง+โพสต์ ap_transaction ด้วย billed cost (ถ้าไม่กรอก = ใช้ unit_cost เดิม)
  Future<void> _postBilling() async {
    if (_id == null) return;
    final isEnglish = _isEnglish;
    void warn(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    final refNo = _refNoCtrl.text.trim();
    if (refNo.isEmpty) {
      warn(isEnglish ? 'Please enter the vendor invoice number' : 'กรุณาระบุเลขที่ใบกำกับสินค้าผู้ขาย');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final details = _lines.map((l) => ImTransactionDetail(
            id: l.id,
            itemId: l.item.id!,
            billedUnitCost: l.billedUnitCostCtrl.text.trim().isEmpty ? null : _parseNum(l.billedUnitCostCtrl.text),
            vatType: _isVatMode ? l.vatType : null,
            vatRate: _isVatMode ? l.vatRate : null,
          )).toList();
      await _service.postBilling(id: _id!, refNo: refNo, details: details);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Posted successfully' : 'Post สำเร็จ')));
        widget.onSaveSuccess();
      }
    } catch (e) {
      if (mounted) warn(isEnglish ? 'Post failed: $e' : 'Post ล้มเหลว: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // '32' สถานะ Delivered — บันทึกแค่เลขที่อ้างอิง + ราคาขายรายบรรทัด ไม่แตะจำนวน/สินค้า/คลัง (ส่งของจริงไปแล้ว
  // ต้นทุนขายก็ Post ไปแล้วตอน Post IM)
  Future<void> _saveBillingInfoDln() async {
    if (_id == null) return;
    final isEnglish = _isEnglish;
    void warn(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    setState(() => _isSaving = true);
    try {
      final header = ImTransactionHeader(
        id: _id!, docId: _docId!, docNo: _docNo, docDate: _docDate, warehouseId: _warehouseId!,
        customerId: _customerId, refNo: _refNoCtrl.text.trim().isEmpty ? null : _refNoCtrl.text.trim(),
      );
      final details = _lines.map((l) => ImTransactionDetail(
            id: l.id,
            itemId: l.item.id!,
            unitPrice: l.unitPriceCtrl.text.trim().isEmpty ? null : _parseNum(l.unitPriceCtrl.text),
          )).toList();
      await _service.updateTransaction(id: _id!, header: header, details: details);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Saved successfully' : 'บันทึกสำเร็จ')));
        await _loadExisting(_id!);
        setState(() {});
      }
    } catch (e) {
      if (mounted) warn(isEnglish ? 'Save failed: $e' : 'บันทึกล้มเหลว: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // '32' สถานะ Delivered -> Posted — สร้าง+โพสต์ ar_transaction ด้วยราคาขายที่บันทึกไว้ (ต้นทุนขาย Post ไปแล้วตอน Post IM)
  Future<void> _postBillingDln() async {
    if (_id == null) return;
    final isEnglish = _isEnglish;
    void warn(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    setState(() => _isSaving = true);
    try {
      final details = _lines.map((l) => ImTransactionDetail(
            id: l.id,
            itemId: l.item.id!,
            unitPrice: l.unitPriceCtrl.text.trim().isEmpty ? null : _parseNum(l.unitPriceCtrl.text),
            vatType: _isVatMode ? l.vatType : null,
            vatRate: _isVatMode ? l.vatRate : null,
          )).toList();
      await _service.postBillingDln(id: _id!, refNo: _refNoCtrl.text.trim(), details: details);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Posted successfully' : 'Post สำเร็จ')));
        widget.onSaveSuccess();
      }
    } catch (e) {
      if (mounted) warn(isEnglish ? 'Post failed: $e' : 'Post ล้มเหลว: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _void() async {
    if (_id == null) return;
    final isEnglish = _isEnglish;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEnglish ? 'Void Document' : 'ยกเลิกเอกสาร'),
        content: Text(isEnglish
            ? 'Void this document? Stock and GL impact will be reversed.'
            : 'ยกเลิกเอกสารนี้? ผลกระทบต่อสต็อกและบัญชีจะถูกย้อนกลับ'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEnglish ? 'Void' : 'ยืนยัน Void')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isSaving = true);
    try {
      await _service.voidTransaction(_id!);
      if (mounted) widget.onSaveSuccess();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish ? 'Void failed: $e' : 'Void ล้มเหลว: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    if (_id == null) return;
    final isEnglish = _isEnglish;
    setState(() => _isSaving = true);
    try {
      await _service.deleteTransaction(_id!);
      if (mounted) widget.onSaveSuccess();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish ? 'Delete failed: $e' : 'ลบล้มเหลว: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(isEnglish),
                const SizedBox(height: 12),
                _buildDetailCard(isEnglish),
                const SizedBox(height: 12),
                _buildGlCard(isEnglish),
                if (_isDlnBillingMode || _isDlnDeferredMode || _isArReturnCnMode || _isArDnMode) ...[
                  const SizedBox(height: 12),
                  _buildArPreviewCard(isEnglish),
                ],
                const SizedBox(height: 12),
                _buildTotalsCard(isEnglish),
              ],
            ),
          ),
        ),
        _buildActionBar(isEnglish),
      ],
    );
  }

  Widget _card({required String title, required List<Widget> children}) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Divider(),
              ...children,
            ],
          ),
        ),
      );

  Widget _fkField({required String label, required String? displayText, required bool hasValue, VoidCallback? onSearch}) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
      child: Row(children: [
        Expanded(
          child: hasValue
              ? Text(displayText ?? '', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)
              : Text(_isEnglish ? '— Not specified —' : '— ไม่ระบุ —', style: TextStyle(color: Colors.grey.shade600)),
        ),
        if (onSearch != null)
          IconButton(icon: const Icon(Icons.search, color: Colors.teal, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onSearch),
      ]),
    );
  }

  Widget _buildHeaderCard(bool isEnglish) {
    final canEditDocType = !_isReadOnly && _id == null;
    return _card(title: isEnglish ? 'Document Header' : 'ข้อมูลเอกสาร', children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 1,
          child: canEditDocType && _docTypes.length > 1
              ? DropdownButtonFormField<int>(
                  value: _docId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: isEnglish ? 'Document Type *' : 'ประเภทเอกสาร *', border: const OutlineInputBorder(), isDense: true),
                  items: _docTypes.map((d) => DropdownMenuItem(value: d.id, child: Text('${d.docCode} ${isEnglish && d.docNameEng.isNotEmpty ? d.docNameEng : d.docNameThai}'))).toList(),
                  onChanged: (v) {
                    final d = _docTypes.firstWhere((e) => e.id == v);
                    _selectDocType(d);
                  },
                )
              : _fkField(
                  label: isEnglish ? 'Document Type' : 'ประเภทเอกสาร',
                  hasValue: _docCode != null,
                  displayText: '${_docCode ?? ''} ${isEnglish && (_docNameEng ?? '').isNotEmpty ? _docNameEng : (_docNameThai ?? '')}',
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: TextFormField(
            readOnly: true,
            decoration: InputDecoration(labelText: isEnglish ? 'Doc No.' : 'เลขที่เอกสาร', border: const OutlineInputBorder(), isDense: true),
            controller: TextEditingController(text: _docNo),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: InkWell(
            onTap: _isReadOnly ? null : _pickDate,
            child: InputDecorator(
              decoration: InputDecoration(labelText: isEnglish ? 'Doc Date *' : 'วันที่เอกสาร *', border: const OutlineInputBorder(), isDense: true),
              child: Text(_dateFmt.format(_docDate)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: TextField(
            controller: _refNoCtrl,
            readOnly: !_canEditBilling,
            decoration: InputDecoration(
                labelText: (_isGrnBillingMode || (_isGrDeferredMode && _status == 'Received'))
                    ? (isEnglish ? 'Vendor Invoice No. *' : 'เลขที่ใบกำกับสินค้าผู้ขาย *')
                    : _isDeliverMode
                        ? (isEnglish ? 'Customer Ref. No.' : 'เลขที่อ้างอิงลูกค้า')
                        : (isEnglish ? 'Ref No.' : 'เลขที่อ้างอิง'),
                border: const OutlineInputBorder(), isDense: true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: _fkField(
            label: _isTransferMode ? (isEnglish ? 'From Warehouse *' : 'คลังต้นทาง *') : (isEnglish ? 'Warehouse *' : 'คลังสินค้า *'),
            hasValue: _warehouseId != null,
            displayText: _warehouseLabel,
            onSearch: _isReadOnly ? null : () => ImWarehouseListWidget.search(context, onSelected: _selectWarehouse),
          ),
        ),
        if (_isTransferMode) ...[
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: _fkField(
              label: isEnglish ? 'To Warehouse *' : 'คลังปลายทาง *',
              hasValue: _toWarehouseId != null,
              displayText: _toWarehouseLabel,
              onSearch: _isReadOnly ? null : () => ImWarehouseListWidget.search(context, onSelected: _selectToWarehouse),
            ),
          ),
        ],
        if (_isApVendorMode) ...[
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: _fkField(
              label: isEnglish ? 'Vendor *' : 'ผู้ขาย *',
              hasValue: _vendorId != null,
              displayText: _vendorLabel,
              onSearch: _isReadOnly ? null : () => ApVendorListWidget.search(context, onSelected: _selectVendor),
            ),
          ),
        ],
        if (_isArCustomerMode) ...[
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: _fkField(
              label: isEnglish ? 'Customer *' : 'ลูกค้า *',
              hasValue: _customerId != null,
              displayText: _customerLabel,
              onSearch: _isReadOnly ? null : () => ArCustomerListWidget.search(context, onSelected: _selectCustomer),
            ),
          ),
        ],
        if (_isReturnSourceDocMode) ...[
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: _fkField(
              label: isEnglish ? 'Source Document *' : 'เอกสารต้นฉบับ *',
              hasValue: _refImTransactionId != null,
              displayText: _refImTransactionLabel,
              onSearch: _isReadOnly ? null : _pickReturnSourceDoc,
            ),
          ),
        ],
      ]),
      const SizedBox(height: 6),
      TextField(
        controller: _descCtrl,
        readOnly: _isReadOnly,
        decoration: InputDecoration(labelText: isEnglish ? 'Description' : 'คำอธิบาย', border: const OutlineInputBorder(), isDense: true),
      ),
      const SizedBox(height: 6),
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: _statusColor(_status).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
          child: Text(_status, style: TextStyle(color: _statusColor(_status), fontWeight: FontWeight.w600)),
        ),
        if (_linkedApTransactionId != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Text(
              isEnglish ? 'AP bill created (#$_linkedApTransactionId)' : 'สร้างใบตั้งหนี้ AP แล้ว (#$_linkedApTransactionId)',
              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
        if (_linkedArTransactionId != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Text(
              isEnglish ? 'AR invoice created (#$_linkedArTransactionId)' : 'สร้างใบแจ้งหนี้ AR แล้ว (#$_linkedArTransactionId)',
              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
      ]),
    ]);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Draft':  return Colors.orange;
      case 'Posted': return Colors.green;
      case 'Void':   return Colors.red;
      default:       return Colors.grey;
    }
  }

  Widget _buildDetailCard(bool isEnglish) {
    return _card(
      title: _isTransferMode
          ? (isEnglish ? 'Transfer Lines' : 'รายการโอนสินค้า')
          : _isReceiveMode
              ? (isEnglish ? 'Receiving Lines' : 'รายการรับสินค้า')
              : _isIssueMode
                  ? (isEnglish ? 'Issue Lines' : 'รายการเบิกสินค้า')
                  : _isDeliverMode
                      ? (isEnglish ? 'Delivery Lines' : 'รายการส่งสินค้า')
                      : _isReturnSourceDocMode
                          ? (isEnglish ? 'Return Lines' : 'รายการคืนสินค้า')
                          : (_isApDnMode || _isArDnMode)
                              ? (isEnglish ? 'Lines' : 'รายการ')
                              : (isEnglish ? 'Count Lines' : 'รายการปรับยอดสินค้า'),
      children: [
        if (_lines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(isEnglish ? 'No lines yet' : 'ยังไม่มีรายการ', style: TextStyle(color: Colors.grey.shade600)),
          ),
        ..._lines.map((l) => _buildLineCard(l, isEnglish)),
        if (!_isReadOnly)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: _isReturnSourceDocMode ? _pickReturnLines : _addLine,
              icon: const Icon(Icons.add),
              label: Text(_isReturnSourceDocMode
                  ? (isEnglish ? 'Add Return Lines' : 'เพิ่มรายการคืนสินค้า')
                  : (isEnglish ? 'Add Item' : 'เพิ่มสินค้า')),
            ),
          ),
      ],
    );
  }

  Widget _buildLineCard(_CountLine line, bool isEnglish) {
    final itemName = isEnglish && (line.item.itemNameEn ?? '').isNotEmpty ? line.item.itemNameEn! : line.item.itemNameTh;
    final variance = line.variance;
    final varianceColor = variance > 0 ? Colors.green.shade700 : (variance < 0 ? Colors.red.shade700 : Colors.black87);
    final showLot = line.item.isLotTracked;
    final showSerial = line.item.isSerialTracked || line.item.costingMethod == 'SPECIFIC';
    final canEditUnitCost = variance > 0 && line.item.costingMethod != 'STANDARD';
    final unitCostDisplay = line.item.costingMethod == 'STANDARD'
        ? _fmtMoney.format(line.item.standardCost)
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.blueGrey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text('${line.item.itemCode} — $itemName',
                  style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            ),
            Text(line.item.costingMethod, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
            if (!_isReadOnly)
              IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 18), onPressed: () => _removeLine(line)),
          ]),
          Wrap(spacing: 10, runSpacing: 6, children: [
            SizedBox(
              width: 220,
              child: _fkField(
                label: isEnglish ? 'Location' : 'ตำแหน่งจัดเก็บ',
                hasValue: line.locationId != null,
                displayText: line.locationCode,
                onSearch: _isReadOnly || _warehouseId == null
                    ? null
                    : () => ImLocationTreeWidget.search(context, warehouseId: _warehouseId!, onSelected: (ImLocation loc) {
                          setState(() { line.locationId = loc.id; line.locationCode = loc.locationCode; });
                          _refreshSystemQty(line);
                        }),
              ),
            ),
            if (line.isTransferMode)
              SizedBox(
                width: 220,
                child: _fkField(
                  label: isEnglish ? 'To Location' : 'ตำแหน่งจัดเก็บปลายทาง',
                  hasValue: line.toLocationId != null,
                  displayText: line.toLocationCode,
                  onSearch: _isReadOnly || _toWarehouseId == null
                      ? null
                      : () => ImLocationTreeWidget.search(context, warehouseId: _toWarehouseId!, onSelected: (ImLocation loc) {
                            setState(() { line.toLocationId = loc.id; line.toLocationCode = loc.locationCode; });
                          }),
                ),
              ),
            if (showLot)
              SizedBox(
                width: 130,
                child: TextField(
                  controller: line.lotNoCtrl,
                  readOnly: _isReadOnly,
                  decoration: InputDecoration(labelText: isEnglish ? 'Lot No.' : 'ล็อต', border: const OutlineInputBorder(), isDense: true),
                  onChanged: (_) => _refreshSystemQty(line),
                ),
              ),
            if (showSerial)
              SizedBox(
                width: 150,
                child: TextField(
                  controller: line.serialNoCtrl,
                  readOnly: _isReadOnly,
                  decoration: InputDecoration(labelText: isEnglish ? 'Serial No.' : 'Serial No.', border: const OutlineInputBorder(), isDense: true),
                  onChanged: (_) => _refreshSystemQty(line),
                ),
              ),
            SizedBox(
              width: 110,
              child: InputDecorator(
                decoration: InputDecoration(labelText: isEnglish ? 'System Qty' : 'ยอดระบบ', border: const OutlineInputBorder(), isDense: true),
                child: line.loadingSystemQty
                    ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_fmtQty.format(line.systemQty)),
              ),
            ),
            SizedBox(
              width: 110,
              child: TextField(
                controller: line.isDeltaMode ? line.issueQtyCtrl : line.countedQtyCtrl,
                readOnly: _isReadOnly,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: line.isTransferMode
                        ? (isEnglish ? 'Transfer Qty *' : 'จำนวนที่โอน *')
                        : line.isReceiveMode
                            ? (isEnglish ? 'Receive Qty *' : 'จำนวนที่รับ *')
                            : line.isIssueMode
                                ? (isEnglish ? 'Issue Qty *' : 'จำนวนที่เบิก *')
                                : line.isDeliverMode
                                    ? (isEnglish ? 'Delivery Qty *' : 'จำนวนที่ส่ง *')
                                    : (line.isApReturnCnMode || line.isArDnMode || line.isApDnMode || line.isArReturnCnMode)
                                        ? (isEnglish ? 'Qty *' : 'จำนวน *')
                                        : (isEnglish ? 'Counted Qty *' : 'ยอดนับได้ *'),
                    border: const OutlineInputBorder(),
                    isDense: true),
                onChanged: (_) => setState(() {}),
              ),
            ),
            SizedBox(
              width: 110,
              child: InputDecorator(
                decoration: InputDecoration(
                    labelText: line.isTransferMode
                        ? (isEnglish ? 'Balance After' : 'คงเหลือหลังโอน')
                        : line.isReceiveMode
                            ? (isEnglish ? 'Balance After' : 'คงเหลือหลังรับ')
                            : line.isIssueMode
                                ? (isEnglish ? 'Balance After' : 'คงเหลือหลังเบิก')
                                : line.isDeliverMode
                                    ? (isEnglish ? 'Balance After' : 'คงเหลือหลังส่ง')
                                    : line.isDeltaMode
                                        ? (isEnglish ? 'Balance After' : 'คงเหลือหลังทำรายการ')
                                        : (isEnglish ? 'Variance' : 'ผลต่าง'),
                    border: const OutlineInputBorder(),
                    isDense: true),
                child: Text(
                  _fmtQty.format(line.isDeltaMode ? line.counted : variance),
                  style: TextStyle(color: line.isDeltaMode ? Colors.black87 : varianceColor, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(
              width: 120,
              child: canEditUnitCost
                  ? TextField(
                      controller: line.unitCostCtrl,
                      readOnly: _isReadOnly,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: isEnglish ? 'Unit Cost *' : 'ต้นทุน/หน่วย *', border: const OutlineInputBorder(), isDense: true),
                    )
                  : InputDecorator(
                      decoration: InputDecoration(labelText: isEnglish ? 'Unit Cost' : 'ต้นทุน/หน่วย', border: const OutlineInputBorder(), isDense: true),
                      child: Text(unitCostDisplay ?? (isEnglish ? '(auto at Post)' : '(คำนวณตอน Post)'),
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ),
            ),
            if (_isGrDeferredMode && (_status == 'Received' || _status == 'Posted'))
              SizedBox(
                width: 120,
                child: TextField(
                  controller: line.billedUnitCostCtrl,
                  readOnly: !_canEditBilling,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: isEnglish ? 'Billed Unit Cost' : 'ต้นทุนตามใบกำกับ',
                      helperText: isEnglish ? 'Blank = same as Unit Cost' : 'เว้นว่าง = เท่ากับต้นทุน/หน่วย',
                      helperMaxLines: 2,
                      border: const OutlineInputBorder(), isDense: true),
                ),
              ),
            if (_isDlnBillingMode || _isDlnDeferredMode || _isArReturnCnMode || _isArDnMode)
              SizedBox(
                width: 120,
                child: TextField(
                  controller: line.unitPriceCtrl,
                  readOnly: !_canEditBilling,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: isEnglish ? 'Unit Price' : 'ราคาขาย/หน่วย',
                      border: const OutlineInputBorder(), isDense: true),
                ),
              ),
            if (_isVatMode)
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<String>(
                  value: line.vatType != null && _vatRates.any((v) => v.vatCode == line.vatType) ? line.vatType : null,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: isEnglish ? 'VAT *' : 'VAT *', border: const OutlineInputBorder(), isDense: true),
                  items: _vatRates.map((v) => DropdownMenuItem(value: v.vatCode, child: Text(_vatLabel(v.vatCode), style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: _isReadOnly ? null : (v) => setState(() {
                        line.vatType = v;
                        line.vatRate = v != null ? _rateForVatCode(v) : 0;
                      }),
                ),
              ),
          ]),
        ]),
      ),
    );
  }

  Widget _buildGlCard(bool isEnglish) {
    // '32' ที่ Delivered แล้ว: ต้นทุนขาย (COGS) Post ไปแล้วตอน Post IM (gl_entry_id ตั้งค่าจริง) จึงแสดง entry จริง
    // เหมือนสถานะ Posted ทั่วไป ต่างจาก '12' ที่ยังไม่มี GL ใดๆ เลยตอน Received
    if ((_status == 'Posted' || (_isDlnDeferredMode && _status == 'Delivered')) && _postedGlDetails != null) {
      return _card(title: isEnglish ? 'GL Entries (Posted)' : 'รายการบัญชี (Posted จริง)', children: [
        ..._postedGlDetails!.map((d) => _glLine(d.accountCode, isEnglish && d.accountNameEng.isNotEmpty ? d.accountNameEng : d.accountName, d.debitLc, d.creditLc)),
      ]);
    }

    // '12' ไม่มี im_gl_account_setup ของตัวเองเลย (Stage 1 ไม่มี GL, Stage 2 ใช้บัญชีของ AP) จึงต้องดักก่อนเช็ค
    // _docSetup ด้านล่าง — และ gl_entry_id ของ im_transaction เองก็เป็น null เสมอแม้ Posted แล้ว (entry อยู่ที่
    // ap_transaction ที่สร้างให้ เหมือน '11') จึงแสดงตัวอย่างที่คำนวณจากค่าปัจจุบันแทนของจริงจาก server เสมอ
    if (_isGrDeferredMode) {
      if (_status == 'Draft') {
        return _card(title: isEnglish ? 'GL Preview' : 'ตัวอย่างรายการบัญชี', children: [
          Text(
            isEnglish
                ? 'No GL posts at "Post IM" — GL is only posted later when this document is billed via "Post AP/GL".'
                : 'ตอน "Post IM" จะยังไม่มีการโพสต์บัญชี — จะโพสต์บัญชีก็ต่อเมื่อ "Post AP/GL" ภายหลังเมื่อได้รับใบกำกับ',
            style: TextStyle(color: Colors.grey.shade700, fontStyle: FontStyle.italic),
          ),
        ]);
      }
      double billedValue = 0, vatValue = 0;
      for (final l in _lines) {
        final billed = l.billedUnitCostCtrl.text.trim().isEmpty ? _parseNum(l.unitCostCtrl.text) : _parseNum(l.billedUnitCostCtrl.text);
        billedValue += l.counted * billed;
        if (l.vatType != null && l.vatType != 'NOVAT') vatValue += l.counted * billed * l.vatRate / 100;
      }
      final isPostedYet = _status == 'Posted';
      return _card(
        title: isPostedYet
            ? (isEnglish ? 'GL Preview (Posted reference)' : 'ตัวอย่างรายการบัญชี (อ้างอิงยอดที่ Posted แล้ว)')
            : (isEnglish ? 'GL Preview (not posted yet)' : 'ตัวอย่างรายการบัญชี (ยังไม่ได้ Post)'),
        children: [
          _glLine(_docSetup?.inventoryAccountCode, isEnglish ? 'Inventory (on the AP bill)' : 'สินค้าคงคลัง (บนใบตั้งหนี้ AP)', billedValue, 0),
          if (vatValue > 0)
            _glLine(_docSetup?.vatInputAccountCode, isEnglish ? '${_docSetup?.vatInputAccountName ?? 'VAT Input'} (on the AP bill)' : '${_docSetup?.vatInputAccountName ?? 'VAT ซื้อ'} (บนใบตั้งหนี้ AP)', vatValue, 0),
          _glLine(null, isEnglish ? 'AP payable' : 'เจ้าหนี้การค้า', 0, billedValue + vatValue),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              isPostedYet
                  ? (isEnglish
                      ? 'This reflects the billed cost currently saved on this document — it should match what was actually posted to AP/GL.'
                      : 'ยอดนี้คำนวณจากต้นทุนตามใบกำกับที่บันทึกไว้ในเอกสารนี้ — ควรตรงกับยอดที่ Post จริงในโมดูล AP/GL')
                  : (isEnglish
                      ? 'Not posted yet — enter the vendor invoice number and Post AP/GL to create the real entry. Leaving Billed Unit Cost blank uses the original received cost.'
                      : 'ยังไม่ได้ Post — กรอกเลขที่ใบกำกับแล้วกด Post AP/GL เพื่อสร้าง entry จริง หากเว้นว่างต้นทุนตามใบกำกับจะใช้ต้นทุนตอนรับของเดิม'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      );
    }

    if (_docSetup == null || !_docSetup!.isConfigured) {
      return _card(title: isEnglish ? 'GL Preview' : 'ตัวอย่างรายการบัญชี', children: [
        Text(
          isEnglish
              ? 'GL accounts not configured for this document type — set them up in IM GL Account Setup.'
              : 'ยังไม่ได้ตั้งค่าบัญชีสำหรับประเภทเอกสารนี้ — กรุณาตั้งค่าที่หน้าจอ ตั้งค่าบัญชี GL (IM)',
          style: const TextStyle(color: Colors.red),
        ),
      ]);
    }

    if (_isTransferMode) {
      // TRF: Dr บัญชีสต็อกปลายทาง / Cr บัญชีสต็อกต้นทาง — resolve ตามคลัง (im_warehouse.inventory_account_id) ก่อน
      // ค่อย fallback ไปที่สินค้า/ค่า default ของ docSetup (ดู resolveInventoryAccount ฝั่ง backend) วันนี้ im_warehouse
      // ยังไม่ตั้งค่าที่ไหนเลย ทั้งสองฝั่งจึงชี้บัญชีเดียวกันเสมอ และจะไม่มีการโพสต์ GL จริงจนกว่าจะตั้งค่าแยกตามคลัง
      double transferValue = 0;
      for (final l in _lines) {
        final qty = _parseNum(l.issueQtyCtrl.text);
        if (qty <= 0) continue;
        final cost = l.item.costingMethod == 'STANDARD' ? l.item.standardCost : null;
        if (cost != null) transferValue += qty * cost;
      }
      return _card(title: isEnglish ? 'GL Preview (Draft)' : 'ตัวอย่างรายการบัญชี (Draft)', children: [
        _glLine(_docSetup!.inventoryAccountCode, isEnglish ? '${_docSetup!.inventoryAccountName ?? ''} (destination)' : '${_docSetup!.inventoryAccountName ?? ''} (คลังปลายทาง)',
            transferValue, 0),
        _glLine(_docSetup!.inventoryAccountCode, isEnglish ? '${_docSetup!.inventoryAccountName ?? ''} (source)' : '${_docSetup!.inventoryAccountName ?? ''} (คลังต้นทาง)',
            0, transferValue),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            isEnglish
                ? 'Inventory accounts are not yet warehouse-specific, so both sides resolve to the same account today — no GL entry will actually be posted until per-warehouse accounts are configured.'
                : 'บัญชีสต็อกยังไม่ได้แยกตามคลัง ทั้งสองฝั่งจึงชี้ไปที่บัญชีเดียวกันในวันนี้ — จะยังไม่มีการโพสต์ GL จริงจนกว่าจะตั้งค่าบัญชีแยกตามคลัง',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
          ),
        ),
      ]);
    }

    if (_isReceiveMode) {
      double receiveValue = 0;
      for (final l in _lines) {
        final qty = _parseNum(l.issueQtyCtrl.text);
        if (qty <= 0) continue;
        final cost = l.item.costingMethod == 'STANDARD' ? l.item.standardCost : _parseNum(l.unitCostCtrl.text);
        receiveValue += qty * cost;
      }
      if (_isGrnBillingMode) {
        // '11' GRN Billing — ไม่ Post บัญชีที่นี่เลย สร้าง ap_transaction อัตโนมัติแล้วโพสต์ที่นั่นแทน
        double vatValue = 0;
        for (final l in _lines) {
          final qty = _parseNum(l.issueQtyCtrl.text);
          if (qty <= 0 || l.vatType == null || l.vatType == 'NOVAT') continue;
          final cost = l.item.costingMethod == 'STANDARD' ? l.item.standardCost : _parseNum(l.unitCostCtrl.text);
          vatValue += qty * cost * l.vatRate / 100;
        }
        return _card(title: isEnglish ? 'GL Preview (Draft)' : 'ตัวอย่างรายการบัญชี (Draft)', children: [
          _glLine(_docSetup!.inventoryAccountCode, isEnglish ? '${_docSetup!.inventoryAccountName ?? ''} (on the AP bill)' : '${_docSetup!.inventoryAccountName ?? ''} (บนใบตั้งหนี้ AP)',
              receiveValue, 0),
          if (vatValue > 0)
            _glLine(_docSetup!.vatInputAccountCode, isEnglish ? '${_docSetup!.vatInputAccountName ?? 'VAT Input'} (on the AP bill)' : '${_docSetup!.vatInputAccountName ?? 'VAT ซื้อ'} (บนใบตั้งหนี้ AP)',
                vatValue, 0),
          _glLine(null, isEnglish ? 'AP payable (auto-created)' : 'เจ้าหนี้การค้า (สร้างอัตโนมัติ)', 0, receiveValue + vatValue),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              isEnglish
                  ? 'This document does not post its own GL entry — Posting it will create a linked AP Purchase Invoice automatically, and its entry is shown above for reference.'
                  : 'เอกสารนี้ไม่ได้ Post บัญชีของตัวเอง — เมื่อ Post จะสร้างใบตั้งหนี้ AP ให้อัตโนมัติ และ entry ที่แสดงด้านบนคือ entry ของใบตั้งหนี้นั้น',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
            ),
          ),
        ]);
      }
      // '10' GRN (ไม่มีเลขที่อ้างอิง) — Dr คลัง (Perpetual) หรือ Dr ซื้อสินค้า (Periodic) / Cr พักรอใบกำกับ (GR/IR)
      return _card(title: isEnglish ? 'GL Preview (Draft)' : 'ตัวอย่างรายการบัญชี (Draft)', children: [
        _glLine(_docSetup!.inventoryAccountCode, isEnglish ? '${_docSetup!.inventoryAccountName ?? ''} (Perpetual mode)' : '${_docSetup!.inventoryAccountName ?? ''} (โหมด Perpetual)',
            receiveValue, 0),
        _glLine(_docSetup!.grirAccountCode, _docSetup!.grirAccountName, 0, receiveValue),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            isEnglish
                ? 'Under Periodic mode, the debit side lands on the Purchases account instead of Inventory.'
                : 'ในโหมด Periodic ฝั่ง Dr จะเป็นบัญชีซื้อสินค้าแทนบัญชีสต็อก',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
          ),
        ),
      ]);
    }

    if (_isApReturnCnMode || _isApDnMode) {
      // '15'/'20'/'25' — มิเรอร์ '11' ทุกประการ (ไม่ Post บัญชีที่นี่เลย สร้าง ap_transaction อัตโนมัติแล้ว Post ที่นั่น
      // แทน) ต่างกันแค่ Dr/Cr กลับด้านสำหรับ CN ('15'/'20') เทียบกับ DN ('25') และยอดฝั่งลดสต็อก ('15'/'20') ยังไม่ทราบ
      // ต้นทุนที่แน่นอนจนกว่าจะ Post (ตัดจาก stock layer จริง) จึงแสดงเป็น undetermined เหมือน AJS/ISS ทั่วไป
      double value = 0, vatValue = 0, undetermined = 0;
      for (final l in _lines) {
        final v = l.variance;
        if (v == 0) continue;
        final cost = l.item.costingMethod == 'STANDARD' ? l.item.standardCost : (v > 0 ? _parseNum(l.unitCostCtrl.text) : null);
        if (cost == null) {
          undetermined += v.abs();
        } else {
          value += v * cost;
          if (l.vatType != null && l.vatType != 'NOVAT') vatValue += v.abs() * cost * l.vatRate / 100;
        }
      }
      final noteLabel = _isApReturnCnMode
          ? (isEnglish ? 'AP Credit Note' : 'ใบลดหนี้ AP')
          : (isEnglish ? 'AP Debit Note' : 'ใบเพิ่มหนี้ AP');
      final grandValue = value + (value >= 0 ? vatValue : -vatValue);
      return _card(title: isEnglish ? 'GL Preview (Draft)' : 'ตัวอย่างรายการบัญชี (Draft)', children: [
        _glLine(_docSetup!.inventoryAccountCode,
            isEnglish ? '${_docSetup!.inventoryAccountName ?? ''} (on the $noteLabel)' : '${_docSetup!.inventoryAccountName ?? ''} (บน$noteLabel)',
            value > 0 ? value : 0, value < 0 ? -value : 0),
        if (vatValue > 0)
          _glLine(_docSetup!.vatInputAccountCode,
              isEnglish ? '${_docSetup!.vatInputAccountName ?? 'VAT Input'} (on the $noteLabel)' : '${_docSetup!.vatInputAccountName ?? 'VAT ซื้อ'} (บน$noteLabel)',
              value > 0 ? vatValue : 0, value < 0 ? vatValue : 0),
        _glLine(null, isEnglish ? '$noteLabel (auto-created)' : '$noteLabel (สร้างอัตโนมัติ)',
            grandValue < 0 ? -grandValue : 0, grandValue > 0 ? grandValue : 0),
        if (undetermined > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              isEnglish
                  ? 'Some lines have decreases whose exact cost is determined at Post time from existing stock — not included above.'
                  : 'บางรายการเป็นยอดลดที่ยังไม่ทราบต้นทุนที่แน่นอน (ระบบจะคำนวณจากสต็อกจริงตอน Post) — ยังไม่รวมในตัวเลขข้างต้น',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            isEnglish
                ? 'This document does not post its own GL entry — Posting it will create a linked $noteLabel automatically, and its entry is shown above for reference.'
                : 'เอกสารนี้ไม่ได้ Post บัญชีของตัวเอง — เมื่อ Post จะสร้าง$noteLabelให้อัตโนมัติ และ entry ที่แสดงด้านบนคือ entry ของใบนั้น',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
          ),
        ),
      ]);
    }

    double positiveValue = 0, undetermined = 0;
    for (final l in _lines) {
      final v = l.variance;
      if (v == 0) continue;
      final cost = l.item.costingMethod == 'STANDARD'
          ? l.item.standardCost
          : (v > 0 ? _parseNum(l.unitCostCtrl.text) : null);
      if (cost == null) {
        undetermined += v.abs();
      } else {
        positiveValue += v * cost;
      }
    }

    // บัญชีคู่บัญชี (counterpart ของคลัง) ต้องตรงกับที่ postGlEntry ใช้จริง — ISS/DLN/RTC/CNC/DNC ใช้ cogs, ที่เหลือใช้
    // variance (AJS) — ดู pattern_sys_doc_type_vs_doc_code: ตัดสินจาก sys_doc_type ไม่ใช่ doc_code
    final isCogsCounter = _isIssueMode || _isDeliverMode || _isArReturnCnMode || _isArDnMode;
    final counterCode = isCogsCounter ? _docSetup!.cogsAccountCode : _docSetup!.varianceAccountCode;
    final counterName = isCogsCounter ? _docSetup!.cogsAccountName : _docSetup!.varianceAccountName;
    return _card(title: isEnglish ? 'GL Preview (Draft)' : 'ตัวอย่างรายการบัญชี (Draft)', children: [
      _glLine(_docSetup!.inventoryAccountCode, _docSetup!.inventoryAccountName,
          positiveValue > 0 ? positiveValue : 0, positiveValue < 0 ? -positiveValue : 0),
      _glLine(counterCode, counterName,
          positiveValue < 0 ? -positiveValue : 0, positiveValue > 0 ? positiveValue : 0),
      if (undetermined > 0)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            isEnglish
                ? 'Some lines have decreases whose exact cost is determined at Post time from existing stock — not included above.'
                : 'บางรายการเป็นยอดลดที่ยังไม่ทราบต้นทุนที่แน่นอน (ระบบจะคำนวณจากสต็อกจริงตอน Post) — ยังไม่รวมในตัวเลขข้างต้น',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
          ),
        ),
    ]);
  }

  // ใบแจ้งหนี้ลูกหนี้ที่ระบบสร้างให้อัตโนมัติจาก DLN Billing ('31' Post ทันที / '32' Post AR/GL แยกต่างหาก) — แยกจาก
  // _buildGlCard เพราะการขายมี 2 journal entry แยกกันตามหลักบัญชีคู่ (ต้นทุนขายฝั่ง IM เอง + ใบแจ้งหนี้ฝั่ง AR)
  // ไม่ได้ fetch entry จริงของ ar_transaction ต่างหาก (gl_entry_id ของ ar_transaction เอง ไม่ใช่ im_transaction.gl_entry_id)
  // จึงแสดงตัวอย่างที่คำนวณจากค่าที่บันทึกไว้เสมอ แม้ Posted แล้ว — known gap เดียวกับที่ '11' มีต่อ AP bill ของตัวเอง
  // แสดงเอกสารฝั่งลูกหนี้ที่ระบบสร้างให้อัตโนมัติ — ใบแจ้งหนี้ ('31'/'32'), ใบลดหนี้ ('35'/'40', isCredit=true กลับ
  // ทิศทาง Dr/Cr) หรือใบเพิ่มหนี้ ('45', ทิศทางเดียวกับใบแจ้งหนี้ปกติ) — ดูเหตุผลการแยกการ์ดนี้จาก _buildGlCard ที่
  // comment ของฟังก์ชันนี้ด้านบน (2 journal entry แยกกันตามหลักบัญชีคู่)
  Widget _buildArPreviewCard(bool isEnglish) {
    double subtotal = 0, vat = 0;
    for (final l in _lines) {
      final lineSubtotal = l.variance.abs() * _parseNum(l.unitPriceCtrl.text);
      subtotal += lineSubtotal;
      if (l.vatType != null && l.vatType != 'NOVAT') vat += lineSubtotal * l.vatRate / 100;
    }
    final total = subtotal + vat;
    final vatAcctCode = _docSetup?.vatOutputAccountCode;
    final vatAcctName = isEnglish ? (_docSetup?.vatOutputAccountName ?? 'VAT Output') : (_docSetup?.vatOutputAccountName ?? 'ภาษีขาย');
    final isCredit = _isArReturnCnMode; // '35'/'40' — ลด AR (กลับทิศทางจาก DN/ใบแจ้งหนี้ปกติ)
    final docLabel = isCredit
        ? (isEnglish ? 'AR Credit Note' : 'ใบลดหนี้ลูกหนี้')
        : _isArDnMode
            ? (isEnglish ? 'AR Debit Note' : 'ใบเพิ่มหนี้ลูกหนี้')
            : (isEnglish ? 'AR Invoice' : 'ใบแจ้งหนี้ลูกหนี้');

    if (_status == 'Posted' && _linkedArTransactionId != null) {
      return _card(title: '$docLabel (${isEnglish ? 'Posted reference' : 'อ้างอิงยอดที่ Posted แล้ว'})', children: [
        _glLine(null, isEnglish ? 'Accounts Receivable' : 'ลูกหนี้การค้า', isCredit ? 0 : total, isCredit ? total : 0),
        _glLine(null, isEnglish ? 'Revenue' : 'รายได้', isCredit ? subtotal : 0, isCredit ? 0 : subtotal),
        _glLine(vatAcctCode, vatAcctName, isCredit ? vat : 0, isCredit ? 0 : vat),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            isEnglish
                ? 'This reflects the unit price currently saved on this document — it should match what was actually posted to AR/GL.'
                : 'ยอดนี้คำนวณจากราคาขายที่บันทึกไว้ในเอกสารนี้ — ควรตรงกับยอดที่ Post จริงในโมดูล AR/GL',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
          ),
        ),
      ]);
    }

    final isDeferredPending = _isDlnDeferredMode && _status == 'Delivered';
    return _card(
      title: isDeferredPending
          ? '$docLabel (${isEnglish ? 'not posted yet' : 'ยังไม่ได้ Post'})'
          : '$docLabel (Draft)',
      children: [
        _glLine(null, isEnglish ? 'Accounts Receivable' : 'ลูกหนี้การค้า', isCredit ? 0 : total, isCredit ? total : 0),
        _glLine(null, isEnglish ? 'Revenue' : 'รายได้', isCredit ? subtotal : 0, isCredit ? 0 : subtotal),
        _glLine(vatAcctCode, vatAcctName, isCredit ? vat : 0, isCredit ? 0 : vat),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            isDeferredPending
                ? (isEnglish
                    ? 'Not posted yet — enter unit price per line and Post AR/GL to create the real invoice.'
                    : 'ยังไม่ได้ Post — กรอกราคาขายต่อหน่วยรายบรรทัดแล้วกด Post AR/GL เพื่อสร้างใบแจ้งหนี้จริง')
                : (isEnglish
                    ? 'This document does not post its own AR entry separately — Posting it will create a linked $docLabel automatically, and its entry is shown above for reference.'
                    : 'เอกสารนี้ไม่ได้ Post บัญชีลูกหนี้ของตัวเองแยกต่างหาก — เมื่อ Post จะสร้าง$docLabelให้อัตโนมัติ และ entry ที่แสดงด้านบนคือ entry ของใบนั้น'),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
          ),
        ),
      ],
    );
  }

  Widget _glLine(String? code, String? name, double debit, double credit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(flex: 3, child: Text('${code ?? '-'} ${name ?? ''}', style: const TextStyle(fontSize: 13))),
        Expanded(flex: 1, child: Text(debit != 0 ? _fmtMoney.format(debit) : '', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
        Expanded(flex: 1, child: Text(credit != 0 ? _fmtMoney.format(credit) : '', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
      ]),
    );
  }

  Widget _buildTotalsCard(bool isEnglish) {
    final totalQty = _lines.fold<double>(0, (s, l) => s + l.variance);
    return _card(title: isEnglish ? 'Totals' : 'สรุปยอด', children: [
      Text(_isTransferMode
          ? '${isEnglish ? 'Total transferred qty' : 'จำนวนที่โอนรวม'}: ${_fmtQty.format(-totalQty)}'
          : _isReceiveMode
              ? '${isEnglish ? 'Total received qty' : 'จำนวนที่รับรวม'}: ${_fmtQty.format(totalQty)}'
              : _isIssueMode
                  ? '${isEnglish ? 'Total issued qty' : 'จำนวนที่เบิกรวม'}: ${_fmtQty.format(-totalQty)}'
                  : _isDeliverMode
                      ? '${isEnglish ? 'Total delivered qty' : 'จำนวนที่ส่งรวม'}: ${_fmtQty.format(-totalQty)}'
                      : (_isApReturnCnMode || _isApDnMode || _isArReturnCnMode || _isArDnMode)
                          ? '${isEnglish ? 'Total qty' : 'จำนวนรวม'}: ${_fmtQty.format(totalQty.abs())}'
                          : '${isEnglish ? 'Total variance qty' : 'จำนวนผลต่างรวม'}: ${_fmtQty.format(totalQty)}'),
    ]);
  }

  Widget _buildActionBar(bool isEnglish) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade300))),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        TextButton(onPressed: _isSaving ? null : widget.onCancel, child: Text(isEnglish ? 'Close' : 'ปิด')),
        const SizedBox(width: 8),
        if (_status == 'Draft' && !widget.viewOnly) ...[
          if (_id != null && widget.canDelete)
            TextButton(
              onPressed: _isSaving ? null : _delete,
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(isEnglish ? 'Delete' : 'ลบ'),
            ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _isSaving ? null : () => _save('Draft'),
            child: Text(isEnglish ? 'Save Draft' : 'บันทึกร่าง'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _isSaving ? null : () => _save('Post'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
            child: Text((_isGrDeferredMode || _isDlnDeferredMode) ? (isEnglish ? 'Post IM' : 'Post IM') : (isEnglish ? 'Post' : 'Post')),
          ),
        ],
        if (_status == 'Received' && _isGrDeferredMode && !widget.viewOnly) ...[
          OutlinedButton(
            onPressed: _isSaving ? null : _saveBillingInfo,
            child: Text(isEnglish ? 'Save' : 'บันทึก'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _isSaving ? null : _postBilling,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
            child: Text(isEnglish ? 'Post AP/GL' : 'Post AP/GL'),
          ),
          const SizedBox(width: 8),
        ],
        if (_status == 'Delivered' && _isDlnDeferredMode && !widget.viewOnly) ...[
          OutlinedButton(
            onPressed: _isSaving ? null : _saveBillingInfoDln,
            child: Text(isEnglish ? 'Save' : 'บันทึก'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _isSaving ? null : _postBillingDln,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
            child: Text(isEnglish ? 'Post AR/GL' : 'Post AR/GL'),
          ),
          const SizedBox(width: 8),
        ],
        if ((_status == 'Posted' || _status == 'Received' || _status == 'Delivered') && !widget.viewOnly)
          ElevatedButton(
            onPressed: _isSaving ? null : _void,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
            child: Text(isEnglish ? 'Void' : 'Void'),
          ),
        if (_isSaving) ...[
          const SizedBox(width: 12),
          const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ]),
    );
  }
}
