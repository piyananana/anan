import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/im_transaction.dart';
import '../models/im_item.dart';
import '../models/im_gl_account_setup.dart';
import '../services/im_transaction_service.dart';
import '../services/im_item_service.dart';
import '../services/im_warehouse_service.dart';
import '../services/im_location_service.dart';
import '../../po/services/po_transaction_service.dart';
import '../../so/services/so_transaction_service.dart';
import '../../utils/date_utils.dart';
import '../../utils/vat_calc.dart';
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
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/widgets/sa_document_reverse_widgets.dart';
import '../../ap/models/ap_vendor.dart';
import '../../ap/widgets/ap_vendor_list_widget.dart';
import '../../ap/services/ap_vendor_service.dart';
import 'im_payment_approval_panel.dart';
import '../../ar/models/ar_customer.dart';
import '../../ar/widgets/ar_customer_list_widget.dart';
import '../../cd/models/cd_vat_rate.dart';
import '../../cd/models/cd_branch.dart';
import '../../cd/services/cd_branch_service.dart';
import '../../cd/widgets/cd_user_branch_picker.dart';
import '../../cd/services/cd_vat_rate_service.dart';
import '../../cd/models/cd_currency.dart';
import '../../cd/services/cd_currency_service.dart';
import '../../cd/models/cd_doc_salesperson.dart';
import '../../cd/models/cd_salesperson.dart';
import '../../cd/services/cd_salesperson_service.dart';
import '../../cd/widgets/cd_salesperson_split_editor.dart';
import '../../config/app_config.dart';
import '../../sa/models/sa_credit_approval.dart';
import '../../sa/services/sa_credit_approval_service.dart';
import '../../sa/widgets/sa_credit_limit_panel.dart';
import '../../ar/services/ar_customer_service.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../../gl/models/gl_dimension.dart';
import '../../gl/services/gl_dimension_service.dart';
import '../../gl/widgets/gl_dimension_picker_field.dart';
import '../../gl/widgets/gl_line_account_dims.dart';
import '../../cd/models/cd_wht_type.dart';
import '../../cd/services/cd_wht_type_service.dart';
import 'im_cash_sale_panel.dart';

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
// บัญชีที่แสดงในตัวอย่างรายการบัญชี (รหัส + ชื่อ)
typedef _Acct = ({String? code, String? name});

class _CountLine {
  int? id;
  ImItem item;
  int? locationId;
  String? locationCode;
  int? toLocationId; // TRF เท่านั้น — ตำแหน่งจัดเก็บฝั่งปลายทาง
  String? toLocationCode;
  int? uomId;
  String? uomCode;
  String? uomNameTh, uomNameEn; // ชื่อหน่วยของบรรทัด (จากเอกสารที่บันทึก) — ใช้แสดงเมื่อยังไม่ได้โหลดรายการหน่วย
  // หน่วยนับหลายหน่วย: factor = จำนวนหน่วยหลักต่อ 1 หน่วยของบรรทัด (จำนวน/ราคาที่กรอกเป็นหน่วยของบรรทัด, ยอดระบบ/
  // คงเหลือเป็นหน่วยหลัก) uoms = หน่วยที่เลือกได้ของสินค้า (null = ยังไม่โหลด) uomLocked = บรรทัดจากเอกสารอ้างอิงใช้หน่วยหลัก
  double factor = 1;
  ImItemUoms? uoms;
  bool uomLocked = false;
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
  int? refPoDetailId; // '10'/'11'/'12' เท่านั้น — บรรทัด PO ต้นฉบับที่บรรทัดนี้รับตาม (ไม่ final — ผู้ใช้เลือกทีหลังได้ผ่าน picker)
  double? poUnitPrice; // ราคาต่อหน่วยในใบสั่งซื้อ (สกุลเงินเดียวกับหัวเอกสาร) — เตือนเมื่อราคารับ/ตั้งหนี้ต่างจาก PO
  double? soUnitPrice; // ราคาต่อหน่วยในใบสั่งขาย (สกุลเงินเดียวกับหัวเอกสาร) — เตือนเมื่อราคาขายต่างจาก SO
  // ราคาขายมาจากตารางราคา ('LIST') — ล็อกช่องราคา (บรรทัดจากใบสั่งขายล็อกด้วย refSoDetailId) ดู _priceLocked
  String? priceSource;
  bool priceOverridden = false; // ผู้ดูแลระบบแก้ราคาเอง — ไม่ดึงราคาจากตารางราคาทับอีก
  int priceSeq = 0; // กันผลดึงราคาที่มาช้ากว่าการแก้จำนวนครั้งล่าสุด
  // ฝั่งซื้อ ('11'/'12' เพิ่มบรรทัดตรง): ราคาที่ระบบเติม + ที่มา (ตารางราคา / ราคาซื้อล่าสุด) — แสดงไอคอนเมื่อราคายังเท่าค่าที่เติม
  double? purchasePriceAuto;
  String? purchasePriceNote;
  int? refSoDetailId; // '30'/'31'/'32' เท่านั้น — บรรทัด SO ต้นฉบับที่บรรทัดนี้ส่งตาม (ไม่ final — ผู้ใช้เลือกทีหลังได้ผ่าน picker)
  // VAT ต่อบรรทัด — ใช้เฉพาะประเภทเอกสารที่สร้าง/อ้างอิงใบกำกับ AP/AR อัตโนมัติ (ดู _isVatMode ใน state) เก็บเป็น
  // field ธรรมดาแทน controller เพราะเป็นค่าที่เลือกจาก dropdown ไม่ใช่กรอกอิสระ (มิเรอร์ ar_transaction_detail_widget.dart)
  String? vatType;
  double vatRate;
  // ของแถม — ฝั่งรับ (isReceiveMode) ยกเว้นบังคับ unitCostCtrl>0, ฝั่งขาย (isDeliverMode) auto-zero+lock unitPriceCtrl
  // (ดู build() ของบรรทัดและ validation ตอน save) เป็น field ธรรมดาเหมือน vatType เพราะเป็น toggle ไม่ใช่กรอกอิสระ
  bool isFree;
  // เบิกสินค้า ('60'): บัญชีที่ใช้ลงบัญชีของบรรทัด (null = สินค้า → หมวดสินค้า → ตั้งค่า) + มิติของบรรทัด (ว่าง = หัวเอกสาร)
  int? glAccountId;
  Map<int, int?> dims = {};
  final TextEditingController countedQtyCtrl;
  final TextEditingController issueQtyCtrl;
  final TextEditingController unitCostCtrl;
  final TextEditingController billedUnitCostCtrl; // '12' เท่านั้น — ต้นทุนตามใบกำกับจริง (อาจต่างจาก unitCostCtrl)
  final TextEditingController unitPriceCtrl; // '31'/'32' เท่านั้น — ราคาขายต่อหน่วย ใช้คำนวณรายได้ตอนสร้างใบแจ้งหนี้ AR
  final TextEditingController discPctCtrl; // ส่วนลด % ของบรรทัดที่มีราคา (ฝั่งซื้อ = ส่วนลดรับ, ฝั่งขาย = ส่วนลดขาย)
  final TextEditingController lotNoCtrl;
  final TextEditingController serialNoCtrl;
  // ส่วนลดเงินของรายการ (ต่อทั้งรายการ) — เอกสารขาย; ส่วนลด % ของเอกสารขายใช้ discPctCtrl เป็นขั้นบันได "10+5+2"
  final TextEditingController lineDiscAmtCtrl;
  // ราคาสุทธิ/หน่วย (ก่อนส่วนลดท้ายบิล) ที่ผู้ใช้กรอกเอง — เอกสารขาย; มีค่า = ส่วนลด (เงิน) คำนวณย้อนจากค่านี้เสมอ
  // (จำนวน/ราคา/ส่วนลด % เปลี่ยน → ส่วนลด (เงิน) เปลี่ยนตาม ราคาสุทธิคงเดิม) ว่าง = กรอกส่วนลด (เงิน) เอง
  final TextEditingController netPriceCtrl;
  final TextEditingController remarkCtrl; // หมายเหตุของรายการ (im_transaction_detail.description) — บริการพิมพ์แทนชื่อสินค้า

  _CountLine({
    this.id,
    required this.item,
    this.locationId,
    this.locationCode,
    this.toLocationId,
    this.toLocationCode,
    this.uomId,
    this.uomCode,
    this.uomNameTh,
    this.uomNameEn,
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
    this.refPoDetailId,
    this.poUnitPrice,
    this.soUnitPrice,
    this.refSoDetailId,
    this.vatType,
    this.vatRate = 0,
    this.isFree = false,
    double countedQty = 0,
    double issueQty = 0,
    double? unitCost,
    double? billedUnitCost,
    double? unitPrice,
    double discountPercent = 0,
    String lotNo = '',
    String serialNo = '',
    String remark = '',
    String? discountText, // เอกสารขาย: ขั้นบันไดที่บันทึกไว้ (null = ใช้ discountPercent เป็นขั้นเดียว)
    double lineDiscountAmount = 0,
    double? netUnitPrice,
  })  : remarkCtrl = TextEditingController(text: remark),
        netPriceCtrl = TextEditingController(text: netUnitPrice != null ? _fmtInput(netUnitPrice) : ''),
        lineDiscAmtCtrl = TextEditingController(text: lineDiscountAmount != 0 ? _fmtInput(lineDiscountAmount) : ''),
        countedQtyCtrl = TextEditingController(text: countedQty == 0 ? '' : _fmtInput(countedQty)),
        issueQtyCtrl = TextEditingController(text: issueQty == 0 ? '' : _fmtInput(issueQty)),
        unitCostCtrl = TextEditingController(text: unitCost != null && unitCost != 0 ? _fmtInput(unitCost) : ''),
        billedUnitCostCtrl = TextEditingController(text: billedUnitCost != null && billedUnitCost != 0 ? _fmtInput(billedUnitCost) : ''),
        unitPriceCtrl = TextEditingController(text: unitPrice != null && unitPrice != 0 ? _fmtInput(unitPrice) : ''),
        discPctCtrl = TextEditingController(text: discountText ?? (discountPercent != 0 ? _fmtInput(discountPercent) : '')),
        lotNoCtrl = TextEditingController(text: lotNo),
        serialNoCtrl = TextEditingController(text: serialNo);

  // สินค้าบริการ/ไม่นับสต็อก (เฉพาะเอกสารฝั่งขาย) — ไม่มีตำแหน่ง/ล็อต/ยอดคงเหลือ ไม่ตัดสต็อก
  bool get isNonStock => item.itemType != 'STOCK';

  bool get isDeltaMode =>
      isIssueMode || isTransferMode || isReceiveMode || isDeliverMode ||
      isApReturnCnMode || isApDnMode || isArReturnCnMode || isArDnMode;
  // ทิศทางบวก (เพิ่มสต็อก): รับสินค้า ('10'/'11'/'12'), เพิ่มหนี้เจ้าหนี้ ('25', รับของเพิ่ม), รับคืน/ลดหนี้ลูกหนี้
  // ('35'/'40', ลูกค้าคืนของ) — ที่เหลือ (เบิก/โอน/ส่ง/คืนผู้ขาย/ลดหนี้เจ้าหนี้/เพิ่มหนี้ลูกหนี้) เป็นทิศทางลบ
  bool get isIncreaseMode => isReceiveMode || isApDnMode || isArReturnCnMode;
  double get counted {
    if (!isDeltaMode) return _parseNum(countedQtyCtrl.text);
    final delta = baseDelta;
    return isIncreaseMode ? systemQty + delta : systemQty - delta;
  }

  // จำนวนที่กรอก แปลงเป็นหน่วยหลัก (ตัวอย่างบนหน้าจอ — backend ปัดตามทศนิยมของหน่วยหลักตอนบันทึก)
  double get baseDelta => ((_parseNum(issueQtyCtrl.text) * factor) * 1e6).roundToDouble() / 1e6;
  // จำนวนตามหน่วยของบรรทัด — ใช้คิดยอดเงิน (ราคาที่กรอกเป็นต่อหน่วยของบรรทัด)
  double get docQty => isDeltaMode ? _parseNum(issueQtyCtrl.text) : variance.abs();

  double get variance => counted - systemQty;

  static String _fmtInput(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  void dispose() {
    countedQtyCtrl.dispose();
    issueQtyCtrl.dispose();
    unitCostCtrl.dispose();
    billedUnitCostCtrl.dispose();
    unitPriceCtrl.dispose();
    discPctCtrl.dispose();
    lotNoCtrl.dispose();
    serialNoCtrl.dispose();
    remarkCtrl.dispose();
    lineDiscAmtCtrl.dispose();
    netPriceCtrl.dispose();
  }
}

// ใบมัดจำที่เลือกหักได้ + ยอดที่หัก (สกุลเงินเอกสาร)
class _AdvanceRow {
  final int id;
  final String docNo;
  final DateTime? docDate;
  final double balanceFc;
  final double vatRatio; // สัดส่วน VAT ของใบมัดจำ (ที่ออกแล้ว)
  final double pendingVatRatio; // สัดส่วน VAT รอตัดของใบมัดจำ (AR) — ล้างบัญชี VAT รอตัด
  final double rate; // อัตราแลกเปลี่ยนของใบมัดจำ
  final int? refOrderId; // ใบสั่งซื้อ/ใบสั่งขายที่ใบมัดจำอ้างอิง
  final String? refOrderDocNo;
  final TextEditingController ctrl;

  _AdvanceRow({required this.id, required this.docNo, this.docDate, required this.balanceFc, required this.vatRatio,
      this.pendingVatRatio = 0, this.rate = 1, double amount = 0, this.refOrderId, this.refOrderDocNo})
      : ctrl = TextEditingController(text: amount > 0 ? amount.toStringAsFixed(2) : '');
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
  final PoTransactionService _poService = PoTransactionService();
  final SoTransactionService _soService = SoTransactionService();
  final PeriodService _periodService = PeriodService();
  final GlEntryService _glEntryService = GlEntryService();
  final VatRateService _vatRateService = VatRateService();
  final AccountService _accountService = AccountService();
  final GlDimensionService _dimService = GlDimensionService();
  // มิติหัวเอกสาร (ลงทุกบรรทัดรายการบัญชีของ IM และเอกสาร AR/AP ที่สร้างอัตโนมัติ) — อ้างอิงใบสั่งซื้อ/ใบสั่งขาย/ใบสั่งผลิต
  // ที่มีมิติ = ใช้มิติของเอกสารนั้นและแก้ไม่ได้ (_refDims != null) — user-approved 2026-11-02
  List<Account> _accounts = [];
  List<GlDimensionType> _dimTypes = [];
  final Map<String, List<GlDimensionValue>> _dimValues = {};
  Map<int, int?> _dimSelections = {};
  // สาขาของเอกสาร (user-approved 2026-11-18): เริ่มต้น = สาขาหลักของผู้ใช้ → สาขาของคลัง → ผู้ใช้เลือกเอง
  int? _branchId;
  List<Branch> _branches = [];
  Map<int, int?>? _refDims;
  int? _refMoId;
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
  // การ์ดข้อมูลเอกสาร ย่อ/ขยาย — ค่าที่ผู้ใช้กดของเอกสารนี้ (_hdrCollapsedId) ไม่งั้นใช้ค่าที่จำไว้ตามกลุ่มสถานะ
  bool? _hdrCollapsed;
  int? _hdrCollapsedId;
  bool _hdrPrefPosted = true;
  bool _hdrPrefDraft = false;
  DateTime _docDate = DateTime.now();
  int? _warehouseId;
  // เก็บรหัส + ชื่อทั้ง 2 ภาษาของคลัง/คลังปลายทาง — ป้ายชื่อคำนวณตามภาษาตอนแสดง (สลับภาษาแล้วเปลี่ยนตาม)
  String? _whCode, _whNameTh, _whNameEn;
  int? _toWarehouseId;
  String? _toWhCode, _toWhNameTh, _toWhNameEn;
  String _whLabel(String? code, String? th, String? en) =>
      '${code ?? ''} ${(_isEnglish && (en ?? '').isNotEmpty ? en : th) ?? ''}'.trim();
  String? get _warehouseLabel => _warehouseId == null ? null : _whLabel(_whCode, _whNameTh, _whNameEn);
  String? get _toWarehouseLabel => _toWarehouseId == null ? null : _whLabel(_toWhCode, _toWhNameTh, _toWhNameEn);
  int? _vendorId;
  String? _vendorLabel;
  int? _linkedApTransactionId;
  int? _customerId;
  String? _customerLabel;
  int? _linkedArTransactionId;
  int? _refImTransactionId; // '15'/'35' เท่านั้น — เอกสาร GRN/DLN ต้นฉบับที่จะคืน
  String? _refImTransactionLabel;
  String? _refImSourceSysDocType; // '15' — ประเภท/สถานะของใบรับสินค้าต้นฉบับ ใช้เตือนผลกระทบก่อน Post
  String? _refImSourceStatus;
  int? _refPoId; // '10'/'11'/'12' เท่านั้น — PO ที่อ้างอิง (สะดวก/แสดงผล — เก็บจากบรรทัดแรกที่เลือกผ่าน picker เท่านั้น)
  String? _refPoDocNoLabel;
  int? _refSoId; // '30'/'31'/'32' เท่านั้น — SO ที่อ้างอิง (สะดวก/แสดงผล — เก็บจากบรรทัดแรกที่เลือกผ่าน picker เท่านั้น)
  String? _refSoDocNoLabel;
  final _refNoCtrl = TextEditingController();
  final _poNoCtrl = TextEditingController(); // '30'/'31'/'32' — เลขที่ใบสั่งซื้อของลูกค้า
  // ส่วนลดท้ายบิลของเอกสารขาย (% แล้วตามด้วยเงินสด) — ปันส่วนเข้าแต่ละรายการ
  final _billDiscPctCtrl = TextEditingController();
  final _cashDiscCtrl = TextEditingController();
  DateTime? _poDate;
  // เอกสารขายเงินเชื่อ ('31'/'32'/'45'): ระยะเครดิต เดือน/วัน (ค่าเริ่มต้นจากลูกค้า แก้ได้) + วันที่ครบกำหนด (แก้ได้)
  final _creditMonthsCtrl = TextEditingController();
  final _creditDaysCtrl = TextEditingController();
  DateTime? _dueDate;
  final _fmt4 = NumberFormat('#,##0.0000');
  final _descCtrl = TextEditingController();
  String _status = 'Draft';
  // เหตุที่ถอย / ยกเลิก / ลบไม่ได้ (null = ทำได้) + สถานะปลายทางของการถอย + ประวัติ — จาก backend ตอนโหลด
  ImDocBlock? _reverseBlock;
  String? _reverseTo;
  ImDocBlock? _voidBlock;
  ImDocBlock? _deleteBlock;
  List<DocReverseLog> _reverseHistory = const [];
  // พนักงานขาย (เอกสารฝั่งขาย) — ค่าเริ่มต้นจากลูกค้า แก้ได้ระหว่างร่าง และตอน '32' รอตั้งหนี้
  List<DocSalesperson> _salespersons = const [];
  // วงเงินเครดิต: คำขออนุมัติเกินวงเงิน — รออนุมัติ = แก้เอกสารไม่ได้จนกว่าจะถอนคำขอ
  DocCreditState _credit = const DocCreditState();
  final _creditService = CreditApprovalService(AppConfig.apiIm, 'im_transaction');
  // ซื้อเงินสด ('14'): ขออนุมัติจ่าย (endpoint payment_*)
  DocCreditState _payApproval = const DocCreditState();
  final _payService = CreditApprovalService(AppConfig.apiIm, 'im_transaction', prefix: 'payment');
  int? _glEntryId;

  // รองรับรับสินค้าจากผู้ขายต่างประเทศเป็นสกุลเงินต่างประเทศ (เฉพาะ _isApVendorMode) — มิเรอร์
  // po_transaction_detail_widget.dart ทุกประการ unit_cost (LC) ยังคงใช้ตีมูลค่าสต็อก/โพสต์ GL เหมือนเดิมเสมอ
  final CurrencyService _currencyService = CurrencyService();
  // คลังหลัก (im_warehouse.is_default) = คลังเริ่มต้นของเอกสารใหม่, ตำแหน่งหลักของแต่ละคลัง (im_location.is_default) =
  // ตำแหน่งเริ่มต้นของรายการ — cache ตามคลัง (null = คลังนั้นไม่มีตำแหน่งหลัก)
  ImWarehouse? _mainWarehouse;
  final Map<int, ImLocation?> _mainLocations = {};
  List<Currency> _currencies = [];
  Currency? _currency;
  double _exchangeRate = 1;

  List<_CountLine> _lines = [];
  // ราคารวม VAT (เอกสารที่มี VAT ต่อบรรทัด) + ส่วนลด % ต่อบรรทัดที่มีราคา — user-approved 2026-10-31
  bool _priceIncludesVat = false;
  // วันที่ใบกำกับผู้ขาย ('11'/'12') — null = ค่าตั้งต้น ('11' วันที่เอกสาร, '12' วันนี้) ดู _invoiceDate
  DateTime? _vendorInvoiceDate;
  // เงินมัดจำที่หักในใบตั้งหนี้/ใบแจ้งหนี้ที่สร้างอัตโนมัติ ('11'/'12' ใบจ่ายมัดจำ AP, '31'/'32' ใบรับมัดจำ AR)
  List<_AdvanceRow> _advRows = [];
  List<ModuleDocument> _docTypes = [];
  List<PostingPeriod> _openPeriods = [];
  ImGlAccountSetup? _docSetup;
  List<GlEntryDetail>? _postedGlDetails;
  // ขายเงินสด ('33') — ผู้ซื้อ วิธีรับชำระ ภาษีถูกหัก ณ ที่จ่าย เงินที่รับมา (ดู im_cash_sale_panel.dart)
  final ImCashSaleController _cash = ImCashSaleController();
  List<CdWhtType> _whtTypes = [];

  bool get _isReadOnly => widget.viewOnly || _status != 'Draft' || _credit.isPending || _payApproval.isPending;
  // วันที่ใบกำกับผู้ขาย: '11' ตั้งแต่ร่าง, '12' ตอนตั้งหนี้ (Received) และหลัง Post
  bool get _showInvoiceDate => _isGrnBillingMode || (_isGrDeferredMode && _status != 'Draft') || _isApCnDnDoc;
  // '15'/'20'/'25' → ใบลดหนี้/เพิ่มหนี้ AP: เลขที่อ้างอิง = เลขที่เอกสารของผู้ขาย, วันที่ (ไม่บังคับ ว่าง = วันที่เอกสาร) → รายงานภาษีซื้อ
  bool get _isApCnDnDoc => _isApReturnCnMode || _isApDnMode;
  DateTime get _invoiceDate => _vendorInvoiceDate ?? (_isGrDeferredMode ? DateTime.now() : _docDate);
  // ราคารวม VAT แก้ได้ตอนร่าง หรือตอนตั้งหนี้ของ '12' ตามรูปแบบของใบกำกับจริง
  bool get _canEditPriceInclVat => !_isReadOnly || (_isGrDeferredMode && _status == 'Received' && !widget.viewOnly);
  bool get _isIssueMode => _selectedSysDocType == '60'; // ISS — เบิกสินค้า
  bool get _isTransferMode => _selectedSysDocType == '70'; // TRF — โอนสินค้า
  bool get _isReceiveMode => _selectedSysDocType == '10' || _selectedSysDocType == '11' || _selectedSysDocType == '12' || _selectedSysDocType == '13' || _isCashPurchaseMode; // GRN — รับสินค้า (รวมรับฝากขาย '13' และซื้อเงินสด '14')
  // รับสินค้าตามใบสั่งซื้อ (PO) — ไม่รวม '13' (รับฝากขาย) เพราะฝากขายไม่มีแนวคิด PO ผูกไว้เลยในระบบนี้
  bool get _isPoReceiveMode => _selectedSysDocType == '10' || _selectedSysDocType == '11' || _selectedSysDocType == '12';
  bool get _isGrnBillingMode => _selectedSysDocType == '11' || _isCashPurchaseMode; // GRN Billing — รับสินค้า+ตั้งหนี้อัตโนมัติ ('14' ทำเหมือน '11' แล้วสร้างใบจ่ายต่อ)
  // ซื้อเงินสด — รับของ ตั้งหนี้ และจ่ายเงินในครั้งเดียว ต้องอนุมัติจ่ายก่อน Post (ยอดที่ต้องจ่าย = _cashDueFc เหมือนขายเงินสด)
  bool get _isCashPurchaseMode => _selectedSysDocType == '14';
  bool get _isCashMode => _isCashSaleMode || _isCashPurchaseMode;
  // เลขที่ใบกำกับผู้ขายบังคับ: '11' เสมอ, '14' เฉพาะใบกำกับภาษีเต็มรูป
  bool get _vendorRefRequired => !_isCashPurchaseMode || _cash.taxInvoiceKind == 'FULL';
  double get _cashPaidLc => double.parse((_cash.paymentTotal * _exchangeRate).toStringAsFixed(2));
  bool get _isGrDeferredMode => _selectedSysDocType == '12'; // GR รอตั้งหนี้ — Post IM ก่อน ค่อย Post AP/GL ทีหลัง
  // รับฝากขาย (Consignment) — ต้นทุนจริงตั้งแต่รับ (ไม่ใช่ 0 เหมือนของแถม) แต่ยังไม่เป็นหนี้ AP จริงจนกว่าจะขายออก
  // (ตั้งหนี้เป็นก้อนภายหลังผ่านหน้า Consignment Settlement) บังคับ FIFO/SPECIFIC เท่านั้น ไม่ให้ปนกับต้นทุนเฉลี่ย
  // ของสินค้าของเราเอง และไม่ให้ใช้ ของแถม (is_free) ร่วมกัน เพราะเป็นคนละแนวคิดกัน
  bool get _isConsignmentReceiveMode => _selectedSysDocType == '13';
  bool get _isDeliverMode => _selectedSysDocType == '30' || _selectedSysDocType == '31' || _selectedSysDocType == '32' || _isCashSaleMode; // DLN — ส่งสินค้า
  // DLN Billing — ส่งสินค้า+ตั้งหนี้อัตโนมัติ ('33' ขายเงินสดทำเหมือน '31' ทุกอย่าง แล้วสร้างใบเสร็จรับเงินต่อ)
  bool get _isDlnBillingMode => _selectedSysDocType == '31' || _isCashSaleMode;
  bool get _isCashSaleMode => _selectedSysDocType == '33';
  // ยอดที่ต้องรับชำระของขายเงินสด = ใบแจ้งหนี้ (รวม VAT) − เงินมัดจำที่หัก
  double get _cashDueFc => _billTotalFc - _advTotalFc;
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
  // เอกสารสกุลเงินต่างประเทศ (ไม่ใช่สกุลเงินหลัก) — ใช้ตัดสินว่าแก้อัตราตอนตั้งหนี้ '32' ได้ และแสดงรหัสสกุลเงินที่ช่องราคา
  bool get _isForeignCurrency => _currency != null && !_currency!.baseCurrencyFlag;
  // บรรทัดที่มีราคาซื้อ/ขาย (ส่วนลด %) — '30' ส่งสินค้าไม่ตั้งหนี้ไม่มีราคา
  bool get _showDiscount => _isApVendorMode || _isArVatMode;
  bool get _inclVat => _priceIncludesVat && _isVatMode;
  // หักเงินมัดจำได้เฉพาะเอกสารที่สร้างใบตั้งหนี้ AP / ใบแจ้งหนี้ AR
  bool get _showAdvances => _isGrnBillingMode || _isGrDeferredMode || _isDlnBillingMode || _isDlnDeferredMode;
  double get _advTotalFc => _advRows.fold(0.0, (t, r) => t + _parseNum(r.ctrl.text));
  List<ImAdvance> get _advancesForSave => [
        for (final r in _advRows)
          if (_parseNum(r.ctrl.text) > 0) ImAdvance(advanceId: r.id, appliedAmountFc: _parseNum(r.ctrl.text)),
      ];

  // ยอดบรรทัด (สกุลเงินเอกสาร) ตามส่วนลด/ราคารวม VAT — billed: '12' ใช้ราคาตามใบกำกับถ้ากรอกไว้ (มิเรอร์ backend imLineAmounts)
  // ส่วนลดเอกสารขาย: ขั้นบันได + เงินของรายการ + ส่วนลดท้ายบิลที่ปันส่วน (มิเรอร์ backend computeSalesDiscounts)
  bool get _salesDiscountMode => _isArVatMode;
  double get _billDiscPct => _parseNum(_billDiscPctCtrl.text);
  double get _cashDisc => _parseNum(_cashDiscCtrl.text);
  Map<_CountLine, SalesLineDiscount> _salesDiscounts() {
    final res = computeSalesDiscounts([
      for (final l in _lines)
        SalesDiscountInput(
          entered: l.docQty * _parseNum(l.unitPriceCtrl.text),
          stepText: l.discPctCtrl.text,
          lineAmount: _lineDiscOf(l),
          isFree: l.isFree,
        ),
    ], billDiscountPercent: _billDiscPct, cashDiscountAmount: _cashDisc);
    return {for (var i = 0; i < _lines.length; i++) _lines[i]: res[i]};
  }

  LineAmounts _amt(_CountLine l, {bool billed = false}) {
    if (_salesDiscountMode) {
      return calcLineAmounts(
        qty: l.docQty,
        price: _parseNum(l.unitPriceCtrl.text),
        discountAmount: _salesDiscounts()[l]?.total ?? 0,
        vatRate: l.vatRate,
        noVat: !_isVatMode || l.vatType == null || l.vatType == 'NOVAT',
        priceIncludesVat: _inclVat,
      );
    }
    final ctrl = _isArVatMode
        ? l.unitPriceCtrl
        : (billed && l.billedUnitCostCtrl.text.trim().isNotEmpty ? l.billedUnitCostCtrl : l.unitCostCtrl);
    return calcLineAmounts(
      qty: l.docQty,
      price: _parseNum(ctrl.text),
      discountPercent: _showDiscount ? _parseNum(l.discPctCtrl.text) : 0,
      vatRate: l.vatRate,
      noVat: !_isVatMode || l.vatType == null || l.vatType == 'NOVAT',
      priceIncludesVat: _inclVat,
    );
  }

  // เอกสารขาย: ราคาขาย/หน่วยสุทธิหลังส่วนลดทั้งหมด (ของรายการ + ท้ายบิลที่ปันส่วน) ในหน่วยเดียวกับราคาที่กรอก
  // (ราคารวม VAT = สุทธิรวม VAT) — แสดงบนบรรทัดเท่านั้น
  double _salesNetUnit(_CountLine l, SalesLineDiscount? d) {
    final qty = l.docQty;
    if (qty == 0) return 0;
    return (qty * _parseNum(l.unitPriceCtrl.text) - (d?.total ?? 0)) / qty;
  }

  // ราคาสุทธิ/หน่วยก่อนส่วนลดท้ายบิล (หลังส่วนลดของรายการ) — ค่าที่ผู้ใช้กรอกเองได้ในช่อง netPriceCtrl
  double _netBeforeBill(_CountLine l, SalesLineDiscount? d) {
    final qty = l.docQty;
    if (qty == 0) return 0;
    return (qty * _parseNum(l.unitPriceCtrl.text) - (d?.own ?? 0)) / qty;
  }

  // จำนวนเงินของรายการ = จำนวน × ราคาขายสุทธิ/หน่วย (หลังส่วนลดทั้งหมด) ในหน่วยเดียวกับราคาที่กรอก
  double _salesLineAmount(_CountLine l, SalesLineDiscount? d) =>
      l.docQty * _parseNum(l.unitPriceCtrl.text) - (d?.total ?? 0);

  static double _round2(double v) => (v * 100).roundToDouble() / 100; // ส่วนลดเป็นเงิน 2 ตำแหน่ง (backend เก็บแบบเดียวกัน)
  bool _netEntered(_CountLine l) => _salesDiscountMode && !l.isFree && l.netPriceCtrl.text.trim().isNotEmpty;
  // ส่วนลด (เงิน) ที่ให้ได้ราคาสุทธิที่กรอก = จำนวน × ราคาหลังหักส่วนลด % − จำนวน × ราคาสุทธิ (ติดลบ = ราคาสุทธิสูงเกิน)
  double _netBackSolveDisc(_CountLine l) {
    final qty = l.docQty;
    final afterStep = _parseNum(l.unitPriceCtrl.text) * parseStepDiscount(l.discPctCtrl.text).factor;
    return _round2(qty * afterStep - qty * _parseNum(l.netPriceCtrl.text));
  }
  // ส่วนลด (เงิน) ของรายการที่ใช้คำนวณ/บันทึกจริง
  double _lineDiscOf(_CountLine l) {
    if (!_netEntered(l)) return _parseNum(l.lineDiscAmtCtrl.text);
    final v = _netBackSolveDisc(l);
    return v < 0 ? 0 : v;
  }
  bool _netTooHigh(_CountLine l) => _netEntered(l) && _netBackSolveDisc(l) < 0;
  // ส่วนลด (เงิน) ที่กรอกเองติดลบ = ขายสูงกว่าราคา ไม่อนุญาต (ต้องแก้ราคาขายแทน)
  bool _lineDiscNegative(_CountLine l) => _salesDiscountMode && !_netEntered(l) && _parseNum(l.lineDiscAmtCtrl.text) < 0;

  // Post: จำนวนจ่ายออกรวมทุกบรรทัดของสินค้า/ตำแหน่ง/ล็อตเดียวกัน ต้องไม่เกินยอดคงเหลือ (สินค้าไม่นับสต็อกไม่ตรวจ)
  // คืนข้อความเตือนของกลุ่มแรกที่ไม่พอ หรือ null
  String? _stockShortage(bool isEnglish) {
    final need = <String, double>{};
    final onHand = <String, double>{};
    final code = <String, String>{};
    for (final l in _lines) {
      if (!l.isDeltaMode || l.isIncreaseMode || l.isNonStock) continue;
      final serial = l.item.costingMethod == 'SPECIFIC' ? l.serialNoCtrl.text.trim() : '';
      final key = '${l.item.id}|${l.locationId ?? ''}|${l.lotNoCtrl.text.trim()}|$serial';
      need[key] = (need[key] ?? 0) + l.baseDelta;
      onHand[key] = l.systemQty;
      code[key] = l.item.itemCode;
    }
    for (final k in need.keys) {
      if (need[k]! > onHand[k]! + 0.00005) {
        final msg = isEnglish
            ? 'Not enough stock (on hand ${_fmtQty.format(onHand[k])}, required ${_fmtQty.format(need[k])})'
            : 'ยอดคงเหลือไม่พอ (คงเหลือ ${_fmtQty.format(onHand[k])} ต้องการ ${_fmtQty.format(need[k])})';
        return '${code[k]}: $msg';
      }
    }
    return null;
  }

  // ราคาต่อหน่วยหลังส่วนลด ก่อน VAT — ใช้เทียบกับราคาในใบสั่งซื้อ/ใบสั่งขาย
  double _netUnit(_CountLine l, {bool billed = false}) {
    final qty = l.docQty;
    return qty == 0 ? 0 : _amt(l, billed: billed).net / qty;
  }

  // ยอดรวมของใบตั้งหนี้/ใบแจ้งหนี้ที่จะสร้าง (สกุลเงินเอกสาร รวม VAT) — ใช้จำกัดยอดหักมัดจำ
  double get _billTotalFc => _lines.fold(0.0, (t, l) => t + _amt(l, billed: _isGrDeferredMode).total);

  // ใบมัดจำที่เลือกหักได้ — ใบที่ยังมียอดคงเหลือ สกุลเงินเดียวกับเอกสาร รวมกับที่บันทึกไว้แล้ว
  // เอกสารที่ตั้งหนี้แล้ว (Posted) แสดงเฉพาะที่หักไปแล้ว (ยอดคงเหลือของใบมัดจำถูกตัดไปแล้ว)
  Future<void> _loadAdvances({List<ImAdvance> saved = const []}) async {
    final typed = {for (final r in _advRows) r.id: _parseNum(r.ctrl.text)};
    for (final r in _advRows) {
      r.ctrl.dispose();
    }
    _advRows = [];
    if (!_showAdvances || (_vendorId == null && _customerId == null)) {
      if (mounted) setState(() {});
      return;
    }
    final rows = <_AdvanceRow>[];
    if (_status == 'Posted' || _status == 'Void') {
      for (final a in saved) {
        rows.add(_AdvanceRow(id: a.advanceId, docNo: a.docNo ?? '', balanceFc: a.appliedAmountFc, vatRatio: 0, amount: a.appliedAmountFc));
      }
    } else {
      try {
        final open = await _service.fetchOpenAdvances(
            vendorId: _isApVendorMode ? _vendorId : null, customerId: _isApVendorMode ? null : _customerId);
        final cur = _currency?.currencyCode ?? CurrencyService.baseCode;
        for (final o in open) {
          if ((o.currencyCode ?? CurrencyService.baseCode) != cur) continue;
          final prev = saved.isNotEmpty
              ? saved.where((a) => a.advanceId == o.id).fold(0.0, (t, a) => t + a.appliedAmountFc)
              : (typed[o.id] ?? 0);
          rows.add(_AdvanceRow(id: o.id, docNo: o.docNo, docDate: o.docDate, balanceFc: o.balanceFc, vatRatio: o.vatRatio,
              pendingVatRatio: o.pendingVatRatio, rate: o.exchangeRate, amount: prev, refOrderId: o.refOrderId, refOrderDocNo: o.refOrderDocNo));
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _advRows = rows);
  }
  // ใบมัดจำที่อ้างอิงใบสั่งซื้อ/ใบสั่งขายของเอกสารนี้ — แสดงก่อน และเตือนตอนตั้งหนี้ถ้ายังไม่ได้หัก
  bool _isLinkedAdvance(_AdvanceRow r) {
    final ref = _isApVendorMode ? _refPoId : _refSoId;
    return ref != null && r.refOrderId == ref;
  }
  List<_AdvanceRow> get _advRowsSorted {
    final linked = _advRows.where(_isLinkedAdvance).toList();
    return [...linked, ..._advRows.where((r) => !_isLinkedAdvance(r))];
  }
  Future<bool> _confirmLinkedAdvances() async {
    if (!_showAdvances) return true;
    final pending = _advRows.where((r) => _isLinkedAdvance(r) && _parseNum(r.ctrl.text) <= 0 && r.balanceFc > 0.005).toList();
    if (pending.isEmpty) return true;
    final isEnglish = _isEnglish;
    final src = _isApVendorMode ? (isEnglish ? 'purchase order' : 'ใบสั่งซื้อ') : (isEnglish ? 'sales order' : 'ใบสั่งขาย');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEnglish ? 'Deposit not deducted' : 'ยังไม่ได้หักเงินมัดจำ'),
        content: SizedBox(
          width: 460,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isEnglish
                ? 'These deposits reference the same $src but are not deducted on this bill (they can still be deducted at payment). Post anyway?'
                : 'ใบมัดจำต่อไปนี้อ้างอิง$srcเดียวกันแต่ยังไม่ได้หักในใบนี้ (หักตอนรับ/จ่ายชำระได้) ต้องการ Post ต่อหรือไม่'),
            const SizedBox(height: 8),
            for (final r in pending)
              Text('${r.docNo}  ${isEnglish ? 'balance' : 'คงเหลือ'} ${_fmtMoney.format(r.balanceFc)}', style: const TextStyle(fontSize: 13)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEnglish ? 'Post anyway' : 'Post ต่อ')),
        ],
      ),
    );
    return ok == true;
  }

  // ใบลดหนี้/เพิ่มหนี้ AP ที่มี VAT ต้องมีเลขที่เอกสารของผู้ขาย (รายงานภาษีซื้อ) — บังคับเหมือนหน้าจอ AP
  bool get _vendorCnDnNoRequired => _isApCnDnDoc && _lines.fold(0.0, (t, l) => t + _amt(l).vat).abs() > 0.005;
  bool _checkVendorCnDnNo() {
    if (!_vendorCnDnNoRequired || _refNoCtrl.text.trim().isNotEmpty) return true;
    final isEnglish = _isEnglish;
    final doc = _isApDnMode ? (isEnglish ? 'debit note' : 'ใบเพิ่มหนี้') : (isEnglish ? 'credit note' : 'ใบลดหนี้');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish
        ? 'Please enter the vendor $doc no. (this document has input VAT)'
        : 'กรุณาระบุเลขที่$docของผู้ขาย (เอกสารมีภาษีซื้อ)')));
    return false;
  }

  bool get _canEditBilling => !widget.viewOnly &&
      ((_status == 'Draft' && !_credit.isPending) || (_isGrDeferredMode && _status == 'Received') || (_isDlnDeferredMode && _status == 'Delivered'));
  // ยอดเอกสารสำหรับตรวจวงเงิน: Σ |จำนวน| × ราคาขาย × (1 + VAT) — รับคืน/ลดหนี้ลูกหนี้ติดลบ
  // วงเงินเครดิตเป็นบาท — ราคาขาย × อัตราแลกเปลี่ยน แล้วคิด VAT จากยอดบาท (มิเรอร์ backend imDocAmount)
  double get _creditAmount {
    double r2(double v) => (v * 100).roundToDouble() / 100;
    final sum = _lines.fold<double>(0, (s, l) {
      final vat = (l.vatType == null || l.vatType == 'NOVAT') ? 0 : l.vatRate;
      final a = _amt(l);
      if (_inclVat && vat > 0) return s + r2(a.total * _exchangeRate);
      final lc = r2(a.net * _exchangeRate);
      return s + lc + r2(lc * vat / 100);
    });
    return _isArReturnCnMode ? -sum : sum;
  }

  @override
  void initState() {
    super.initState();
    _loadHeaderPrefs();
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
    _lineHScroll.dispose();
    _refNoCtrl.dispose();
    _poNoCtrl.dispose();
    _creditMonthsCtrl.dispose();
    _creditDaysCtrl.dispose();
    _billDiscPctCtrl.dispose();
    _cashDiscCtrl.dispose();
    _descCtrl.dispose();
    _cash.dispose();
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
    _whCode = _whNameTh = _whNameEn = null;
    _toWarehouseId = null;
    _toWhCode = _toWhNameTh = _toWhNameEn = null;
    _vendorId = null;
    _vendorLabel = null;
    _linkedApTransactionId = null;
    _customerId = null;
    _customerLabel = null;
    _linkedArTransactionId = null;
    _refImTransactionId = null;
    _refImTransactionLabel = null;
    _refImSourceSysDocType = null;
    _refImSourceStatus = null;
    _refPoId = null;
    _refPoDocNoLabel = null;
    _refSoId = null;
    _refSoDocNoLabel = null;
    _refMoId = null;
    _dimSelections = {};
    _branchId = null;
    _refDims = null;
    _refNoCtrl.clear();
    _poNoCtrl.clear();
    _billDiscPctCtrl.clear();
    _cashDiscCtrl.clear();
    _poDate = null;
    _creditMonthsCtrl.clear();
    _creditDaysCtrl.clear();
    _dueDate = null;
    _descCtrl.clear();
    _status = 'Draft';
    _reverseBlock = null;
    _reverseTo = null;
    _voidBlock = null;
    _deleteBlock = null;
    _reverseHistory = const [];
    _credit = const DocCreditState();
    _payApproval = const DocCreditState();
    _salespersons = const [];
    _glEntryId = null;
    _currency = _currencies.cast<Currency?>().firstWhere((c) => c?.baseCurrencyFlag == true, orElse: () => null);
    _exchangeRate = _currency?.baseRate ?? 1;
    _lines = [];
    _priceIncludesVat = false;
    _vendorInvoiceDate = null;
    for (final r in _advRows) {
      r.ctrl.dispose();
    }
    _advRows = [];
    _docSetup = null;
    _postedGlDetails = null;
    _cash.clear();
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
        _currencyService.fetchActiveRows(),
        _accountService.fetchRows(),
        _dimService.fetchActiveTypes(),
        ImWarehouseService().fetchActiveRows(),
        BranchService().fetchActiveRows(),
      ]);
      _branches = results[7] as List<Branch>;
      _mainWarehouse = (results[6] as List<ImWarehouse>).cast<ImWarehouse?>().firstWhere((w) => w!.isDefault, orElse: () => null);
      _accounts = results[4] as List<Account>;
      _dimTypes = results[5] as List<GlDimensionType>;
      final dimValueResults = await Future.wait(_dimTypes.map((t) => _dimService.fetchValuesByType(t.typeCode)));
      for (var i = 0; i < _dimTypes.length; i++) {
        _dimValues[_dimTypes[i].typeCode] = dimValueResults[i];
      }
      _docTypes = (results[0] as List<ModuleDocument>).where((d) => d.isDocType).toList();
      _openPeriods = results[1] as List<PostingPeriod>;
      _vatRates = (results[2] as List<VatRate>).where((v) => v.isActive).toList();
      _currencies = results[3] as List<Currency>;
      _currency = _currencies.cast<Currency?>().firstWhere((c) => c?.baseCurrencyFlag == true, orElse: () => null);
      _exchangeRate = _currency?.baseRate ?? 1;
      if (_docTypes.any((d) => d.sysDocType == '33')) {
        try { _whtTypes = await CdWhtTypeService().fetchActiveRows(); } catch (_) { _whtTypes = []; }
      }
      if (_docTypes.length == 1) {
        await _selectDocType(_docTypes.first);
      }

      if (widget.transactionId != null) {
        await _loadExisting(widget.transactionId!);
      } else {
        if (_mainWarehouse != null) {
          _warehouseId = _mainWarehouse!.id;
          _whCode = _mainWarehouse!.warehouseCode; _whNameTh = _mainWarehouse!.warehouseNameTh; _whNameEn = _mainWarehouse!.warehouseNameEn;
        }
        _branchId = defaultDocBranchId(warehouseBranchId: _mainWarehouse?.branchId);
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
    _whCode = h.warehouseCode; _whNameTh = h.warehouseNameTh; _whNameEn = h.warehouseNameEn;
    _toWarehouseId = h.toWarehouseId;
    _toWhCode = h.toWarehouseCode; _toWhNameTh = h.toWarehouseNameTh; _toWhNameEn = h.toWarehouseNameEn;
    _vendorId = h.vendorId;
    _vendorLabel = '${h.vendorCode ?? ''} ${h.vendorNameTh ?? ''}'.trim();
    _linkedApTransactionId = h.linkedApTransactionId;
    _customerId = h.customerId;
    _customerLabel = '${h.customerCode ?? ''} ${h.customerNameTh ?? ''}'.trim();
    _linkedArTransactionId = h.linkedArTransactionId;
    _refImTransactionId = h.refImTransactionId;
    _refImTransactionLabel = h.refImTransactionDocNo;
    _refImSourceSysDocType = h.refImSysDocType;
    _refImSourceStatus = h.refImTransactionStatus;
    _refPoId = h.refPoId;
    _refPoDocNoLabel = h.refPoDocNo;
    _refSoId = h.refSoId;
    _refSoDocNoLabel = h.refSoDocNo;
    _refMoId = h.refMoId;
    _dimSelections = {1: h.dim1Id, 2: h.dim2Id, 3: h.dim3Id, 4: h.dim4Id, 5: h.dim5Id};
    _branchId = h.branchId;
    _refNoCtrl.text = h.refNo ?? '';
    _poNoCtrl.text = h.customerPoNo ?? '';
    _billDiscPctCtrl.text = h.billDiscountPercent != 0 ? _CountLine._fmtInput(h.billDiscountPercent) : '';
    _cashDiscCtrl.text = h.cashDiscountAmount != 0 ? _CountLine._fmtInput(h.cashDiscountAmount) : '';
    _poDate = h.customerPoDate;
    _creditMonthsCtrl.text = h.creditTermMonths?.toString() ?? '';
    _creditDaysCtrl.text = h.creditTermDays?.toString() ?? '';
    _dueDate = h.dueDate;
    _descCtrl.text = h.description ?? '';
    _status = h.status;
    _reverseBlock = tx.reverseBlock;
    _reverseTo = tx.reverseTo;
    _voidBlock = tx.voidBlock;
    _deleteBlock = tx.deleteBlock;
    _reverseHistory = tx.reverseHistory;
    _credit = tx.credit;
    _payApproval = tx.payApproval;
    _salespersons = tx.salespersons;
    _glEntryId = h.glEntryId;
    _currency = _currencies.cast<Currency?>().firstWhere(
        (c) => c?.id == h.currencyId || c?.currencyCode == h.currencyCode, orElse: () => null);
    _exchangeRate = h.exchangeRate;
    _priceIncludesVat = h.priceIncludesVat;
    _vendorInvoiceDate = h.vendorInvoiceDate;

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
        uomNameTh: d.uomNameTh,
        uomNameEn: d.uomNameEn,
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
        refPoDetailId: d.refPoDetailId,
        poUnitPrice: d.refPoUnitPriceFc,
        soUnitPrice: d.refSoUnitPriceFc,
        refSoDetailId: d.refSoDetailId,
        countedQty: d.countedQty,
        // บรรทัดที่บันทึกเป็นหน่วยอื่น: จำนวน/ราคาแสดงตามหน่วยนั้น (uom_*) — ยอดระบบ/คงเหลือยังเป็นหน่วยหลัก
        issueQty: d.isConverted
            ? d.uomQty!
            : isIncrease ? (d.countedQty - d.systemQty) : isDecrease ? (d.systemQty - d.countedQty) : 0,
        // _isApVendorMode: unitCostCtrl แสดงราคาที่กรอกจริงในสกุลเงินของ header (unitCostFc) ไม่ใช่ unitCost (LC) —
        // fallback เป็น unitCost เดิมสำหรับแถวเก่าก่อนมีฟีเจอร์นี้ (ถือว่าเป็น THB, unitCostFc == unitCost พอดี)
        unitCost: d.isConverted
            ? (_isApVendorMode ? (d.uomUnitCostFc ?? d.uomUnitCost) : d.uomUnitCost)
            : (_isApVendorMode ? (d.unitCostFc ?? d.unitCost) : d.unitCost),
        billedUnitCost: d.isConverted
            ? (_isApVendorMode ? (d.uomBilledUnitCostFc ?? d.uomBilledUnitCost) : d.uomBilledUnitCost)
            : (_isApVendorMode ? (d.billedUnitCostFc ?? d.billedUnitCost) : d.billedUnitCost),
        unitPrice: d.isConverted ? d.uomUnitPrice : d.unitPrice,
        discountPercent: d.discountPercent ?? 0,
        vatType: d.vatType,
        vatRate: d.vatRate ?? 0,
        isFree: d.isFree,
        lotNo: d.lotNo ?? '',
        serialNo: d.serialNo ?? '',
        remark: d.description ?? '',
        discountText: d.discountText,
        lineDiscountAmount: d.lineDiscountAmount,
        netUnitPrice: d.isConverted ? d.uomNetUnitPrice : d.netUnitPrice,
      )
        ..factor = d.isConverted ? d.conversionFactor : 1
        ..uomLocked = d.refPoDetailId != null || d.refSoDetailId != null || d.refImTransactionDetailId != null ||
            d.refMoComponentDetailId != null || d.refMoOutputDetailId != null
        ..glAccountId = d.glAccountId
        ..dims = {1: d.dim1Id, 2: d.dim2Id, 3: d.dim3Id, 4: d.dim4Id, 5: d.dim5Id});
    }
    _lines = lines;
    if (_status == 'Draft') await Future.wait(lines.map((l) => _loadLineUoms(l)));
    if (_isCashMode) {
      if (_whtTypes.isEmpty) {
        try { _whtTypes = await CdWhtTypeService().fetchActiveRows(); } catch (_) {}
      }
      _cash.load(tx, _whtTypes);
    }
    if (_status == 'Draft') await _loadRefDims();
    await _loadAdvances(saved: tx.advances);
    await _refreshListPrices(null, true);

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

  // มิติของใบสั่งซื้อ/ใบสั่งขาย/ใบสั่งผลิตที่อ้างอิง — มีมิติ = ใช้มิตินั้นและล็อก, ไม่มี = แก้ที่เอกสาร IM ได้
  Future<void> _loadRefDims() async {
    Map<int, int?>? d;
    try {
      d = await _service.fetchRefDims(
          poId: _isReceiveMode ? _refPoId : null, soId: _isDeliverMode ? _refSoId : null, moId: _refMoId);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _refDims = d;
      if (d != null) _dimSelections = Map<int, int?>.from(d);
    });
  }

  // เปลี่ยนประเภทเอกสารระหว่างป้อน (เอกสารใหม่): ล้างทุกฟิลด์เหมือนเริ่มเอกสารใหม่ แล้วค่อยตั้งประเภทใหม่
  // (ค่าเริ่มต้นเหมือนเปิดเอกสารใหม่: คลังหลัก + สาขา) — มีรายการสินค้าแล้วถามยืนยันก่อน
  int _docTypeFieldSeq = 0; // เปลี่ยน key ของ dropdown เพื่อดึงค่ากลับเมื่อผู้ใช้ยกเลิก
  Future<void> _changeDocType(int? newId) async {
    if (newId == null || newId == _docId) return;
    final d = _docTypes.firstWhere((e) => e.id == newId);
    if (_docId != null && _lines.isNotEmpty) {
      final isEnglish = _isEnglish;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isEnglish ? 'Change Document Type' : 'เปลี่ยนประเภทเอกสาร'),
          content: Text(isEnglish
              ? 'Changing the document type clears everything entered so far (header and lines). Continue?'
              : 'การเปลี่ยนประเภทเอกสารจะล้างข้อมูลที่ป้อนไว้ทั้งหมด (หัวเอกสารและรายการ) ต้องการดำเนินการต่อหรือไม่?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEnglish ? 'Change and clear' : 'เปลี่ยนและล้างข้อมูล')),
          ],
        ),
      );
      if (ok != true) {
        if (mounted) setState(() => _docTypeFieldSeq++);
        return;
      }
    }
    if (!mounted) return;
    if (_docId != null) {
      setState(() {
        _resetForm();
        if (_mainWarehouse != null) {
          _warehouseId = _mainWarehouse!.id;
          _whCode = _mainWarehouse!.warehouseCode; _whNameTh = _mainWarehouse!.warehouseNameTh; _whNameEn = _mainWarehouse!.warehouseNameEn;
        }
        _branchId = defaultDocBranchId(warehouseBranchId: _mainWarehouse?.branchId);
      });
    }
    await _selectDocType(d);
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
    // ขายเงินสด: เอกสารใหม่ที่ยังไม่เลือกลูกค้า → ลูกค้าเงินสดตามที่ตั้งค่าไว้ในหน้าตั้งค่าบัญชี IM
    final defaultCustomerId = _docSetup?.defaultCustomerId;
    if (_isCashSaleMode && _id == null && _customerId == null && defaultCustomerId != null) {
      try {
        final c = await ArCustomerService().fetchRow(defaultCustomerId);
        if (mounted && _customerId == null && _docId == d.id) {
          _selectCustomer(c);
          return; // _selectCustomer โหลดเงินมัดจำให้แล้ว
        }
      } catch (_) {}
    }
    // ซื้อเงินสด: เอกสารใหม่ที่ยังไม่เลือกผู้ขาย → ผู้ขายเงินสดตามที่ตั้งค่าไว้
    final defaultVendorId = _docSetup?.defaultVendorId;
    if (_isCashPurchaseMode && _id == null && _vendorId == null && defaultVendorId != null) {
      try {
        final v = await ApVendorService().fetchRow(defaultVendorId);
        if (mounted && _vendorId == null && _docId == d.id) _selectVendor(v);
      } catch (_) {}
    }
    await _loadAdvances();
  }

  // วันที่ใบกำกับผู้ขาย = วันที่/งวดของใบตั้งหนี้ AP อัตโนมัติ (วันที่รับสินค้าของ IM ไม่เปลี่ยน)
  Future<void> _pickInvoiceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _invoiceDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _vendorInvoiceDate = picked);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _docDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _docDate = picked;
        _recalcDueDate(); // วันครบกำหนด = วันที่เอกสาร + ระยะเครดิต
      });
      _refreshListPrices(); // ราคาตามช่วงวันที่มีผลของตารางราคา
    }
  }

  // เปลี่ยนคลัง → ตำแหน่งของรายการเดิมเป็นของคลังเก่า ใช้ไม่ได้ จึงเปลี่ยนเป็นตำแหน่งหลักของคลังใหม่
  void _selectWarehouse(ImWarehouse w) {
    final changed = _warehouseId != w.id;
    setState(() {
      _warehouseId = w.id;
      _whCode = w.warehouseCode; _whNameTh = w.warehouseNameTh; _whNameEn = w.warehouseNameEn;
      // ยังไม่มีสาขา (ผู้ใช้ไม่มีสาขาหลัก) → ใช้สาขาของคลัง
      if (_branchId == null && w.branchId != null) _branchId = w.branchId;
      if (changed) {
        for (final l in _lines) {
          l.locationId = null;
          l.locationCode = null;
        }
      }
    });
    if (changed) {
      for (final l in _lines) {
        _applyMainLocation(l);
      }
    }
  }

  void _selectToWarehouse(ImWarehouse w) {
    final changed = _toWarehouseId != w.id;
    setState(() {
      _toWarehouseId = w.id;
      _toWhCode = w.warehouseCode; _toWhNameTh = w.warehouseNameTh; _toWhNameEn = w.warehouseNameEn;
      if (changed) {
        for (final l in _lines) {
          l.toLocationId = null;
          l.toLocationCode = null;
        }
      }
    });
    if (changed) {
      for (final l in _lines) {
        _applyMainLocation(l);
      }
    }
  }

  Future<ImLocation?> _mainLocationOf(int warehouseId) async {
    if (_mainLocations.containsKey(warehouseId)) return _mainLocations[warehouseId];
    try {
      final locs = await ImLocationService().fetchActiveRows(warehouseId: warehouseId);
      _mainLocations[warehouseId] = locs.cast<ImLocation?>().firstWhere((l) => l!.isDefault, orElse: () => null);
    } catch (_) {
      return null; // โหลดไม่ได้ → ปล่อยว่างให้ผู้ใช้เลือกเอง (ไม่ cache เพื่อให้ลองใหม่ได้)
    }
    return _mainLocations[warehouseId];
  }

  // ใส่ตำแหน่งหลักของคลังให้รายการที่ยังไม่มีตำแหน่ง (โอนย้าย: ตำแหน่งปลายทางด้วย) แล้วโหลดยอดคงเหลือตามตำแหน่ง
  Future<void> _applyMainLocation(_CountLine line) async {
    if (line.isNonStock) return; // บริการไม่มีตำแหน่ง/ยอดคงเหลือ
    final whId = _warehouseId;
    if (whId != null && line.locationId == null) {
      final loc = await _mainLocationOf(whId);
      if (loc != null && mounted && _warehouseId == whId && line.locationId == null && _lines.contains(line)) {
        setState(() { line.locationId = loc.id; line.locationCode = loc.locationCode; });
      }
    }
    final toWhId = _toWarehouseId;
    if (line.isTransferMode && toWhId != null && line.toLocationId == null) {
      final loc = await _mainLocationOf(toWhId);
      if (loc != null && mounted && _toWarehouseId == toWhId && line.toLocationId == null && _lines.contains(line)) {
        setState(() { line.toLocationId = loc.id; line.toLocationCode = loc.locationCode; });
      }
    }
    if (mounted && _lines.contains(line)) _refreshSystemQty(line);
  }

  void _selectVendor(ApVendor v) {
    setState(() {
      _vendorId = v.id;
      _vendorLabel = '${v.vendorCode} ${v.vendorNameTh}';
      // สกุลเงินหลักของผู้ขาย (ap_vendor.currency_code) — มิเรอร์ po_transaction_detail_widget.dart:_selectVendor
      if (v.currencyCode.isNotEmpty) {
        final matched = _currencies.cast<Currency?>().firstWhere((c) => c?.currencyCode == v.currencyCode, orElse: () => null);
        if (matched != null) {
          _currency = matched;
          _exchangeRate = matched.baseRate > 0 ? matched.baseRate : 1;
        }
      }
    });
    _loadAdvances();
  }

  void _selectCustomer(ArCustomer c) {
    setState(() {
      _customerId = c.id;
      _customerLabel = '${c.customerCode} ${c.customerNameTh}';
      // สกุลเงินหลักของลูกค้า (ar_customer.currency_code) — มิเรอร์ _selectVendor
      if (c.currencyCode.isNotEmpty) {
        final matched = _currencies.cast<Currency?>().firstWhere((x) => x?.currencyCode == c.currencyCode, orElse: () => null);
        if (matched != null) {
          _currency = matched;
          _exchangeRate = matched.baseRate > 0 ? matched.baseRate : 1;
        }
      }
    });
    if (c.id != null) _loadCustomerSalespersons(c.id!);
    _loadAdvances();
    _refreshListPrices(); // ตารางราคาของลูกค้า
  }

  // ใบสั่งขายที่ดึงรายการมา → ใช้พนักงานขายของใบสั่งขาย (ถ้ามี) แทนค่าเริ่มต้นของลูกค้า
  Future<void> _loadSoSalespersons(int soId) async {
    try {
      final so = await _soService.fetchRow(soId);
      if (!mounted || so.salespersons.isEmpty) return;
      setState(() => _salespersons = DocSalesperson.namesOnly(so.salespersons));
    } catch (_) {}
  }

  // พนักงานขายที่ผูกกับผู้ใช้ที่ login (cd_salesperson.user_id) ใช้งานอยู่และอยู่ในช่วงวันที่มีผล ณ วันที่เอกสาร
  List<Salesperson>? _allSalespersons;
  Future<List<DocSalesperson>> _loginUserSalespersons() async {
    final uid = AuthService().currentUser?.id;
    if (uid == null) return const [];
    try {
      _allSalespersons ??= await SalespersonService().fetchRows();
    } catch (_) {
      return const [];
    }
    final d = DateTime(_docDate.year, _docDate.month, _docDate.day);
    final mine = _allSalespersons!.where((s) =>
        s.id != null &&
        s.userId == uid &&
        s.isActive &&
        (s.effectiveDateFrom == null || !s.effectiveDateFrom!.isAfter(d)) &&
        (s.effectiveDateTo == null || !s.effectiveDateTo!.isBefore(d)));
    if (mine.isEmpty) return const [];
    final s = mine.first; // ผู้ใช้ 1 คนควรผูกกับพนักงานขาย 1 คน — ถ้ามีหลายคนใช้คนแรก
    return [
      DocSalesperson(
        salespersonId: s.id!,
        salespersonCode: s.salespersonCode,
        salespersonNameThai: s.salespersonNameThai,
        salespersonNameEng: s.salespersonNameEng,
        isPrimary: true,
      ),
    ];
  }

  // พนักงานขายเริ่มต้นของเอกสาร: ใบสั่งขาย (_loadSoSalespersons) → ลูกค้า → ผู้ใช้ที่ login (ถ้าเป็นพนักงานขาย) → ว่าง
  Future<void> _loadCustomerSalespersons(int customerId) async {
    try {
      final c = await ArCustomerService().fetchRow(customerId);
      if (!mounted || _customerId != customerId) return;
      final fromUser = c.salespersons.isEmpty ? await _loginUserSalespersons() : const <DocSalesperson>[];
      if (!mounted || _customerId != customerId) return;
      setState(() {
        _salespersons = c.salespersons.isNotEmpty ? DocSalesperson.namesOnly(c.salespersons) : fromUser;
        // ระยะเครดิตของลูกค้า → ค่าเริ่มต้นของเอกสาร (แก้ได้)
        _creditMonthsCtrl.text = '${c.creditTermMonths}';
        _creditDaysCtrl.text = '${c.creditTermDays}';
        _recalcDueDate();
      });
    } catch (_) {}
  }

  bool get _showCreditTerm => (_isDlnBillingMode && !_isCashSaleMode) || _isDlnDeferredMode || _isArDnMode;
  int? get _creditMonths => int.tryParse(_creditMonthsCtrl.text.trim());
  int? get _creditDays => int.tryParse(_creditDaysCtrl.text.trim());

  // วันครบกำหนด = วันที่เอกสาร + เดือน (วันที่เกินสิ้นเดือน → สิ้นเดือน เหมือน PostgreSQL) + วัน; ไม่ได้ระบุระยะเครดิต = คงค่าเดิม
  void _recalcDueDate() {
    if (_creditMonthsCtrl.text.trim().isEmpty && _creditDaysCtrl.text.trim().isEmpty) return;
    final months = _creditMonths ?? 0, days = _creditDays ?? 0;
    final lastDay = DateTime(_docDate.year, _docDate.month + months + 1, 0).day;
    final day = _docDate.day > lastDay ? lastDay : _docDate.day;
    _dueDate = DateTime(_docDate.year, _docDate.month + months, day + days);
  }

  Future<void> _refreshSystemQty(_CountLine line) async {
    if (_warehouseId == null || line.item.id == null || line.isNonStock) return;
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
    // เอกสารฝั่งขายใส่สินค้าบริการ/ไม่นับสต็อกได้ (ไม่ตัดสต็อก ลงแค่รายได้) — ประเภทอื่นเฉพาะสินค้านับสต็อก
    ImItemListWidget.search(context, itemTypeFilter: _isArCustomerMode ? null : 'STOCK', onSelected: (ImItem item) async {
      // รับฝากขาย ('13') บังคับ FIFO/SPECIFIC เท่านั้น — กันปนกับต้นทุนเฉลี่ยของสินค้าของเราเอง (มิเรอร์ validation
      // ฝั่ง backend ใน insertAndPostAdjustment) เช็คที่นี่เพื่อไม่ให้ผู้ใช้เพิ่มบรรทัดที่จะถูก reject ตอน save
      if (_isConsignmentReceiveMode && item.costingMethod != 'FIFO' && item.costingMethod != 'SPECIFIC') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish
            ? '${item.itemCode}: consignment items must use FIFO or Specific costing (this item uses ${item.costingMethod})'
            : '${item.itemCode}: สินค้าฝากขายต้องใช้วิธีคิดต้นทุนแบบ FIFO หรือ Specific เท่านั้น (สินค้านี้ใช้ ${item.costingMethod})')));
        return;
      }
      // prefill VAT ตอนเพิ่มบรรทัดจาก default_vat_type ของสินค้า (ถ้ามีตั้งค่าไว้และเอกสารประเภทนี้ใช้ VAT)
      final vatType = _isVatMode ? _safeVatCode(item.defaultVatType) : null;
      final line = _CountLine(
        item: item, uomId: item.baseUomId, uomCode: item.baseUomCode,
        isIssueMode: _isIssueMode, isTransferMode: _isTransferMode, isReceiveMode: _isReceiveMode, isDeliverMode: _isDeliverMode,
        isApReturnCnMode: _isApReturnCnMode, isApDnMode: _isApDnMode, isArReturnCnMode: _isArReturnCnMode, isArDnMode: _isArDnMode,
        vatType: vatType, vatRate: vatType != null ? _rateForVatCode(vatType) : 0,
      );
      setState(() => _lines.add(line));
      _applyMainLocation(line);
      await _loadLineUoms(line, applyDefault: true);
      await _maybeResolveDirectLinePrice(line);
    });
  }

  // เพิ่มรายการตรง (ไม่ผ่าน picker PO/SO) ให้ GRN/DLN Billing — แนะนำราคาจาก im_price_list เอ็นด์พอยท์เดียวกับที่
  // PO/SO ใช้ ('11'/'12' ฝั่งซื้อใช้ผู้ขายปัจจุบัน, '31'/'32' ฝั่งขายใช้ลูกค้าปัจจุบัน) เอกสารประเภทอื่นไม่ต้อง
  // resolve ที่นี่เลย: '10'/'30' ไม่ตั้งหนี้เลยไม่มีช่องราคาให้กรอก (unitPriceCtrl ถูก lock ไว้ที่ 0), '15'/'35'
  // เพิ่มบรรทัดผ่าน _pickReturnLines ซึ่งมีต้นทุน/ราคาติดมาจากเอกสารต้นฉบับแล้ว '45' (ส่งของเพิ่มให้ลูกค้า) แนะนำ
  // ราคาขายแบบเดียวกับ '31' ส่วน '20'/'25'/'40' (เอกสารอิสระ) เพิ่มผ่าน _addLine นี้แต่ผู้ใช้กรอกราคาเอง — บรรทัดจาก _pickPoLines/_pickSoLines ก็มีราคาติดมาแล้วเช่นกัน
  Future<void> _maybeResolveDirectLinePrice(_CountLine line) async {
    final itemId = line.item.id;
    if (itemId == null) return;
    final docDate = DateFormat('yyyy-MM-dd').format(_docDate);
    if ((_isGrnBillingMode || _isGrDeferredMode) && _vendorId != null) {
      final resolved = await _poService.resolvePrice(
        itemId: itemId, vendorId: _vendorId!, qty: 1, docDate: docDate, uomId: line.uomId ?? line.item.baseUomId,
        currencyCode: _currency?.currencyCode, priceIncludesVat: _priceIncludesVat,
        vatRate: (line.vatType == null || line.vatType == 'NOVAT') ? 0 : line.vatRate,
        fallbackLastPurchase: true,
      );
      final price = double.tryParse(resolved['unit_price_fc']?.toString() ?? '') ?? 0;
      if (price > 0 && mounted) {
        setState(() {
          line.unitCostCtrl.text = _CountLine._fmtInput(price);
          line.purchasePriceAuto = price;
          line.purchasePriceNote = _purchasePriceNote(resolved);
        });
      }
    } else if (_isSalesPriceMode) {
      await _refreshListPrices([line]);
    }
  }

  // ที่มาของราคาซื้อที่ระบบเติมให้ — ตารางราคา หรือราคาซื้อล่าสุดจากผู้ขายรายนี้ (เอกสาร + วันที่)
  String? _purchasePriceNote(Map<String, dynamic> r) {
    final isEnglish = _isEnglish;
    if (r['source'] == 'LIST') return isEnglish ? 'Price list price' : 'ราคาตามตารางราคา';
    if (r['source'] != 'LAST') return null;
    final d = parseLocalDateNullable(r['ref_doc_date']?.toString());
    final date = d != null ? DateFormat('dd/MM/yyyy').format(d) : '';
    return isEnglish ? 'Last purchase price: ${r['ref_doc_no'] ?? ''} $date' : 'ราคาซื้อล่าสุด: ${r['ref_doc_no'] ?? ''} $date';
  }

  Widget? _purchasePriceIcon(_CountLine l) {
    final note = l.purchasePriceNote;
    if (note == null || l.purchasePriceAuto == null || (_parseNum(l.unitCostCtrl.text) - l.purchasePriceAuto!).abs() >= 0.00005) return null;
    final last = l.purchasePriceNote!.startsWith('ราคาซื้อล่าสุด') || l.purchasePriceNote!.startsWith('Last');
    return Tooltip(message: note, child: Icon(last ? Icons.history : Icons.list_alt, size: 14, color: Colors.grey.shade600));
  }

  // ── ราคาขายตามตารางราคา ('31'/'32'/'33'/'45') ─────────────────────────────────────────────────────
  // หาได้จากตารางราคา หรือดึงมาจากใบสั่งขาย = ล็อกช่องราคา แก้ได้เฉพาะ administrator/developer ไม่พบจึงกรอกเองได้
  // (user decision 2026-11-12 — backend assertSalesPrices ตรวจซ้ำตอนบันทึก) ดึงราคาใหม่เมื่อจำนวน/ลูกค้า/วันที่/
  // สกุลเงิน/ราคารวม VAT/ประเภท VAT ของบรรทัดเปลี่ยน (ราคาตามขั้นจำนวน สกุลเงิน และแปลงรวม/ไม่รวม VAT ตามตาราง)
  bool get _isSalesPriceMode => _isDlnBillingMode || _isDlnDeferredMode || _isArDnMode;
  bool get _canOverridePrice => AuthService().isAdmin; // administrator หรือ developer
  bool _priceFromSource(_CountLine l) => _isSalesPriceMode && !l.isFree && (l.refSoDetailId != null || l.priceSource == 'LIST');
  bool _priceLocked(_CountLine l) => _priceFromSource(l) && !_canOverridePrice;

  // onLoad: เอกสารที่เปิดมาแก้ — ราคาที่ต่างจากตารางราคา ผู้ดูแลระบบคงไว้ (ถือว่าแก้เอง) ผู้ใช้ทั่วไปเปลี่ยนเป็นราคาตาราง
  Future<void> _refreshListPrices([Iterable<_CountLine>? only, bool onLoad = false]) async {
    if (!_isSalesPriceMode || _customerId == null || !_canEditBilling) return;
    final customerId = _customerId!;
    final docDate = DateFormat('yyyy-MM-dd').format(_docDate);
    final currencyCode = _currency?.currencyCode;
    final changed = <String>[];
    await Future.wait((only ?? List.of(_lines)).map((l) async {
      final itemId = l.item.id;
      if (itemId == null || l.refSoDetailId != null || l.isFree || l.priceOverridden) return;
      final seq = ++l.priceSeq;
      final qty = l.docQty; // จำนวนตามหน่วยของบรรทัด — backend เทียบขั้นจำนวนของตารางราคาเป็นหน่วยหลักให้เอง
      Map<String, dynamic> resolved;
      try {
        resolved = await _soService.resolvePrice(itemId: itemId, customerId: customerId, qty: qty == 0 ? 1 : qty,
            docDate: docDate, uomId: l.uomId ?? l.item.baseUomId, currencyCode: currencyCode,
            priceIncludesVat: _priceIncludesVat, vatRate: (l.vatType == null || l.vatType == 'NOVAT') ? 0 : l.vatRate);
      } catch (_) {
        return;
      }
      if (!mounted || seq != l.priceSeq || !_lines.contains(l)) return;
      final price = double.tryParse(resolved['unit_price_fc']?.toString() ?? '') ?? 0;
      if (price <= 0) {
        l.priceSource = null; // ไม่พบในตารางราคา — กรอกเองได้ (คงราคาเดิมไว้)
        return;
      }
      l.priceSource = 'LIST';
      if ((_parseNum(l.unitPriceCtrl.text) - price).abs() < 0.005) return;
      if (onLoad && _canOverridePrice) {
        l.priceOverridden = true;
        return;
      }
      if (onLoad) changed.add('${l.item.itemCode}: ${l.unitPriceCtrl.text} -> ${_CountLine._fmtInput(price)}');
      l.unitPriceCtrl.text = _CountLine._fmtInput(price);
    }));
    if (!mounted) return;
    setState(() {});
    if (changed.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 6),
        content: Text('${_isEnglish ? 'Unit prices updated to the price list' : 'ปรับราคาขาย/หน่วยตามตารางราคา'}: ${changed.join(', ')}'),
      ));
    }
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
                  autofocus: true,
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
      _refImSourceSysDocType = picked.sysDocType;
      _refImSourceStatus = picked.status;
      if (_isReturnToSupplierMode) {
        _vendorId = picked.vendorId;
        _vendorLabel = '${picked.vendorCode ?? ''} ${picked.vendorNameTh ?? ''}'.trim();
        // คืนตามสกุลเงินของใบรับสินค้าต้นฉบับ — ราคาที่ดึงมา (returnPriceFc) อยู่ในสกุลเงินนั้น
        final matched = _currencies.cast<Currency?>().firstWhere(
            (c) => c?.currencyCode == (picked.currencyCode ?? CurrencyService.baseCode), orElse: () => null);
        if (matched != null) {
          _currency = matched;
          _exchangeRate = picked.exchangeRate;
        }
      } else {
        _customerId = picked.customerId;
        _customerLabel = '${picked.customerCode ?? ''} ${picked.customerNameTh ?? ''}'.trim();
        if (picked.customerId != null) _loadCustomerSalespersons(picked.customerId!);
        // รับคืนตามสกุลเงินของใบส่งสินค้าต้นฉบับ — ราคาขายที่ดึงมาอยู่ในสกุลเงินนั้น
        final matched = _currencies.cast<Currency?>().firstWhere(
            (c) => c?.currencyCode == (picked.currencyCode ?? CurrencyService.baseCode), orElse: () => null);
        if (matched != null) {
          _currency = matched;
          _exchangeRate = picked.exchangeRate;
        }
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
        // '15'/'35' ใช้ราคา + VAT ของบรรทัดเอกสารต้นฉบับเป็นค่าเริ่มต้น (อัตรา ณ ตอนซื้อ/ขาย) ผู้ใช้แก้ได้ภายหลัง
        final origVat = l.vatType != null && l.vatType!.isNotEmpty ? l.vatType : null;
        final vatType = _isVatMode ? _safeVatCode(origVat ?? items[i].defaultVatType) : null;
        final vatRate = vatType == null
            ? 0.0
            : (origVat == vatType && l.vatRate != null ? l.vatRate! : _rateForVatCode(vatType));
        final line = _CountLine(
          item: items[i],
          locationId: l.locationId, locationCode: l.locationCode,
          // จำนวนคืนได้/ต้นทุนของบรรทัดต้นฉบับเป็นหน่วยหลัก — บรรทัดคืนใช้หน่วยหลัก
          uomId: items[i].baseUomId, uomCode: items[i].baseUomCode,
          isApReturnCnMode: _isApReturnCnMode, isApDnMode: _isApDnMode,
          isArReturnCnMode: _isArReturnCnMode, isArDnMode: _isArDnMode,
          issueQty: qty.toDouble(),
          // '15': ช่องต้นทุนในโหมดผู้ขายคือราคาในสกุลเงินของเอกสาร (ตั้งตามใบรับสินค้าแล้ว) = ยอดใบลดหนี้ AP
          unitCost: _isApReturnCnMode ? (l.returnPriceFc ?? l.unitCost) : l.unitCost,
          unitPrice: _isArReturnCnMode ? l.unitPrice : null,
          discountPercent: l.discountPercent ?? 0, // ใบลดหนี้กลับรายการส่วนลดตามบรรทัดต้นฉบับ
          lotNo: l.lotNo ?? '',
          serialNo: l.serialNo ?? '',
          refImTransactionDetailId: l.id,
          vatType: vatType, vatRate: vatRate,
        );
        _lines.add(line);
        _applyMainLocation(line);
      }
    });
  }

  // '10'/'11'/'12' — เพิ่มรายการเข้า GRN จากบรรทัดที่ยังรับได้ของ PO ที่อนุมัติแล้วของผู้ขายนี้ (multi-select ได้
  // ข้าม PO หลายใบในครั้งเดียว) มิเรอร์ _pickReturnLines แต่ไม่ต้องเลือกเอกสารต้นฉบับก่อน เพราะดึงจากผู้ขายที่เลือก
  // ไว้แล้วตรงๆ (ต่างจากคืนสินค้าที่ต้องระบุ GRN/DLN ต้นฉบับเจาะจงก่อนเสมอ)
  // ค่า NUMERIC จาก PostgreSQL ผ่าน pg driver มาเป็น String เสมอ (ไม่ใช่ num) — ต้อง parse ด้วย toString() เท่านั้น
  // ห้ามใช้ `as num?` ตรงๆ (จะ throw runtime TypeError) มิเรอร์ toDouble() ที่ใช้ทั่วทั้ง *_transaction.dart models
  double _poNum(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
  String _poCurrencyCode(Map<String, dynamic> l) => (l['currency_code'] as String?) ?? CurrencyService.baseCode;
  double _poUnitCostLc(Map<String, dynamic> l) => _poNum(l['unit_price_fc']) * (_poNum(l['exchange_rate']) == 0 ? 1 : _poNum(l['exchange_rate']));

  Future<void> _pickPoLines() async {
    final isEnglish = _isEnglish;
    if (_vendorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please select a vendor first' : 'กรุณาระบุผู้ขายก่อน')));
      return;
    }
    List<Map<String, dynamic>> lines;
    try {
      lines = await _poService.fetchReceivableLines(vendorId: _vendorId);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
      return;
    }
    final alreadyPicked = _lines.map((l) => l.refPoDetailId).whereType<int>().toSet();
    final selectable = lines.where((l) => !alreadyPicked.contains(l['detail_id'] as int)).toList();
    if (selectable.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'No receivable PO lines left for this vendor' : 'ไม่มีรายการที่รับได้เหลืออยู่สำหรับผู้ขายนี้')));
      return;
    }
    final qtyCtrls = {for (final l in selectable) l['detail_id'] as int: TextEditingController(text: _CountLine._fmtInput((l['qty_remaining'] as num).toDouble()))};
    final selected = {for (final l in selectable) l['detail_id'] as int: false};

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
            title: Text(isEnglish ? 'Select Lines from Purchase Order' : 'เลือกรายการจากใบสั่งซื้อ'),
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
                        child: Text(isEnglish ? 'Remaining: ${_fmtQty.format(remaining)}' : 'คงเหลือรับได้: ${_fmtQty.format(remaining)}', style: const TextStyle(fontSize: 12)),
                      ),
                      // ราคา/หน่วยของ PO เป็นสกุลเงินต่างประเทศได้ (unit_price_fc) — ต้นทุน/หน่วยของ GRN เก็บเป็น
                      // บาทเสมอ (im_transaction ไม่มีแนวคิดสกุลเงินต่างประเทศ) จึงต้องแปลงด้วย exchange_rate ของ PO
                      // ก่อนเติมให้ผู้ใช้เห็น มิฉะนั้นจะเข้าใจผิดว่าต้นทุนต่ำกว่าความเป็นจริงหลายสิบเท่า
                      Expanded(
                        flex: 2,
                        child: Text(
                          _poCurrencyCode(l) == CurrencyService.baseCode
                              ? '@ ${_fmtQty.format(_poNum(l['unit_price_fc']))}'
                              : '@ ${_fmtQty.format(_poNum(l['unit_price_fc']))} ${_poCurrencyCode(l)} (≈${_fmtQty.format(_poUnitCostLc(l))} ${CurrencyService.baseCode})',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
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

    final pickedLines = selectable.where((l) => selected[l['detail_id']] == true && _parseNum(qtyCtrls[l['detail_id']]!.text) > 0).toList();
    if (pickedLines.isEmpty) return;
    if (!_checkPickedCurrency(pickedLines.map(_poCurrencyCode).toSet())) return;
    final items = await Future.wait(pickedLines.map((l) => _itemService.fetchRow(l['item_id'] as int)));
    if (!mounted) return;
    final curBefore = _currency?.currencyCode;
    setState(() {
      // ใบรับสินค้าที่ยังไม่มีรายการ ใช้รูปแบบราคา (รวม VAT หรือไม่) ตามใบสั่งซื้อ — ถ้ามีรายการอยู่แล้วแปลงราคาให้ตรงกับใบนี้
      if (_lines.isEmpty) _priceIncludesVat = pickedLines.first['price_includes_vat'] == true;
      for (var i = 0; i < pickedLines.length; i++) {
        final l = pickedLines[i];
        final id = l['detail_id'] as int;
        final remaining = (l['qty_remaining'] as num).toDouble();
        final qty = _parseNum(qtyCtrls[id]!.text).clamp(0, remaining);
        // VAT / ส่วนลดตามบรรทัดใบสั่งซื้อ (ใบเก่าที่ไม่มี VAT ต่อบรรทัด = VAT ตั้งต้นของสินค้า)
        final poVat = l['vat_type'] as String?;
        final vatType = _isVatMode ? _safeVatCode(poVat ?? items[i].defaultVatType) : null;
        final vatRate = vatType == null ? 0.0 : (poVat == vatType ? _poNum(l['vat_rate']) : _rateForVatCode(vatType));
        final poIncl = l['price_includes_vat'] == true && poVat != null;
        var price = _poNum(l['unit_price_fc']);
        if (vatType != null && vatType != 'NOVAT' && poIncl != _priceIncludesVat) {
          price = poIncl ? price * 100 / (100 + vatRate) : price * (100 + vatRate) / 100;
        }
        final line = _CountLine(
          item: items[i],
          // บรรทัดใบสั่งซื้อยังเป็นหน่วยหลัก (หน่วยนับหลายหน่วย ขั้นที่ 4)
          uomId: items[i].baseUomId, uomCode: items[i].baseUomCode,
          isReceiveMode: true,
          issueQty: qty.toDouble(),
          // GRN เก็บ unitCostCtrl เป็นราคาในสกุลเงินของ header (_currency) เสมอ — ตั้ง header ให้ตรงกับ PO ต้นทางไว้
          // ข้างล่างแล้ว (สกุลเงินเดียวกันทั้งใบ) จึงเติมราคาดิบจาก PO ตรงๆ ได้เลยโดยไม่ต้องแปลงเป็นบาท
          unitCost: price,
          discountPercent: _poNum(l['discount_percent']),
          refPoDetailId: id,
          // ราคาใบสั่งซื้อหลังส่วนลด ก่อน VAT — เทียบกับ _netUnit ของบรรทัดตอน Post
          poUnitPrice: _poNum(l['net_unit_price_fc'] ?? l['unit_price_fc']),
          vatType: vatType, vatRate: vatRate,
        );
        _lines.add(line);
        _applyMainLocation(line);
      }
      _refPoId = pickedLines.first['header_id'] as int;
      _refPoDocNoLabel = pickedLines.first['doc_no'] as String?;
      _loadRefDims();
      // รับตามสกุลเงินของ PO ต้นทางเสมอ (ทุกบรรทัดที่เลือกมาจาก fetchReceivableLines ของผู้ขายเดียวกัน แต่อาจมาจาก
      // PO คนละใบ คนละสกุลเงินได้ในทางทฤษฎี — ใช้สกุลเงินของ PO ใบแรกที่เลือกเป็นสกุลเงินของทั้ง GRN นี้)
      // อัตราแลกเปลี่ยนใช้อัตราปัจจุบันของสกุลเงิน ไม่ใช่อัตราตอนสั่งซื้อ — การซื้อบันทึกด้วยอัตรา ณ วันที่เกิดรายการ (TAS 21)
      final poCurrencyCode = _poCurrencyCode(pickedLines.first);
      final matched = _currencies.cast<Currency?>().firstWhere((c) => c?.currencyCode == poCurrencyCode, orElse: () => null);
      if (matched != null) {
        _currency = matched;
        _exchangeRate = matched.baseRate > 0 ? matched.baseRate : 1;
      }
    });
    if (_currency?.currencyCode != curBefore) _loadAdvances();
  }

  // '30'/'31'/'32' — เพิ่มรายการเข้า DLN จากบรรทัดที่ยังส่งได้ของ SO ที่อนุมัติแล้วของลูกค้านี้ (multi-select ได้
  // ข้าม SO หลายใบในครั้งเดียว) มิเรอร์ _pickPoLines ทุกประการ ฝั่งขาย
  // บรรทัด PO/SO ที่เลือกต้องเป็นสกุลเงินเดียวกันทั้งหมด และตรงกับบรรทัดที่มีอยู่แล้วในเอกสาร (ราคาทุกบรรทัดอยู่ใน
  // สกุลเงินของหัวเอกสารเดียว) — ไม่ตรงให้เตือนและไม่เพิ่ม
  bool _checkPickedCurrency(Set<String> codes) {
    final isEnglish = _isEnglish;
    String? msg;
    if (codes.length > 1) {
      msg = isEnglish
          ? 'The selected lines are in different currencies (${codes.join(', ')}) — select lines of one currency per document.'
          : 'บรรทัดที่เลือกมีหลายสกุลเงิน (${codes.join(', ')}) — กรุณาเลือกบรรทัดสกุลเงินเดียวกันต่อเอกสาร';
    } else if (_lines.isNotEmpty && _currency != null && codes.isNotEmpty && codes.first != _currency!.currencyCode) {
      msg = isEnglish
          ? 'The selected lines are in ${codes.first} but this document is in ${_currency!.currencyCode} — select lines of the same currency.'
          : 'บรรทัดที่เลือกเป็นสกุลเงิน ${codes.first} แต่เอกสารนี้เป็น ${_currency!.currencyCode} — กรุณาเลือกบรรทัดสกุลเงินเดียวกัน';
    }
    if (msg == null) return true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.orange.shade800));
    return false;
  }

  String _soCurrencyCode(Map<String, dynamic> l) => (l['currency_code'] as String?) ?? CurrencyService.baseCode;
  double _soUnitPriceLc(Map<String, dynamic> l) => _poNum(l['unit_price_fc']) * (_poNum(l['exchange_rate']) == 0 ? 1 : _poNum(l['exchange_rate']));

  Future<void> _pickSoLines() async {
    final isEnglish = _isEnglish;
    if (_customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please select a customer first' : 'กรุณาระบุลูกค้าก่อน')));
      return;
    }
    List<Map<String, dynamic>> lines;
    try {
      lines = await _soService.fetchDeliverableLines(customerId: _customerId);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
      return;
    }
    final alreadyPicked = _lines.map((l) => l.refSoDetailId).whereType<int>().toSet();
    final selectable = lines.where((l) => !alreadyPicked.contains(l['detail_id'] as int)).toList();
    if (selectable.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'No deliverable SO lines left for this customer' : 'ไม่มีรายการที่ส่งได้เหลืออยู่สำหรับลูกค้านี้')));
      return;
    }
    final qtyCtrls = {for (final l in selectable) l['detail_id'] as int: TextEditingController(text: _CountLine._fmtInput((l['qty_remaining'] as num).toDouble()))};
    final selected = {for (final l in selectable) l['detail_id'] as int: false};

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
            title: Text(isEnglish ? 'Select Lines from Sale Order' : 'เลือกรายการจากใบสั่งขาย'),
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
                        child: Text(isEnglish ? 'Remaining: ${_fmtQty.format(remaining)}' : 'คงเหลือส่งได้: ${_fmtQty.format(remaining)}', style: const TextStyle(fontSize: 12)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _soCurrencyCode(l) == CurrencyService.baseCode
                              ? '@ ${_fmtQty.format(_poNum(l['unit_price_fc']))}'
                              : '@ ${_fmtQty.format(_poNum(l['unit_price_fc']))} ${_soCurrencyCode(l)} (≈${_fmtQty.format(_soUnitPriceLc(l))} ${CurrencyService.baseCode})',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
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

    final pickedLines = selectable.where((l) => selected[l['detail_id']] == true && _parseNum(qtyCtrls[l['detail_id']]!.text) > 0).toList();
    if (pickedLines.isEmpty) return;
    if (!_checkPickedCurrency(pickedLines.map(_soCurrencyCode).toSet())) return;
    final items = await Future.wait(pickedLines.map((l) => _itemService.fetchRow(l['item_id'] as int)));
    if (!mounted) return;
    final curBefore = _currency?.currencyCode;
    setState(() {
      // ใบส่งสินค้าที่ยังไม่มีรายการ ใช้รูปแบบราคา (รวม VAT หรือไม่) ตามใบสั่งขาย — ถ้ามีรายการอยู่แล้วแปลงราคาให้ตรงกับใบนี้
      if (_lines.isEmpty) _priceIncludesVat = pickedLines.first['price_includes_vat'] == true;
      for (var i = 0; i < pickedLines.length; i++) {
        final l = pickedLines[i];
        final id = l['detail_id'] as int;
        final remaining = (l['qty_remaining'] as num).toDouble();
        final qty = _parseNum(qtyCtrls[id]!.text).clamp(0, remaining);
        // VAT / ส่วนลดตามบรรทัดใบสั่งขาย (ใบเก่าที่ไม่มี VAT ต่อบรรทัด = VAT ตั้งต้นของสินค้า)
        final soVat = l['vat_type'] as String?;
        final vatType = _isVatMode ? _safeVatCode(soVat ?? items[i].defaultVatType) : null;
        final vatRate = vatType == null ? 0.0 : (soVat == vatType ? _poNum(l['vat_rate']) : _rateForVatCode(vatType));
        final soIncl = l['price_includes_vat'] == true && soVat != null;
        var price = _poNum(l['unit_price_fc']);
        if (vatType != null && vatType != 'NOVAT' && soIncl != _priceIncludesVat) {
          price = soIncl ? price * 100 / (100 + vatRate) : price * (100 + vatRate) / 100;
        }
        final line = _CountLine(
          item: items[i],
          // บรรทัดใบสั่งขายยังเป็นหน่วยหลัก (หน่วยนับหลายหน่วย ขั้นที่ 3)
          uomId: items[i].baseUomId, uomCode: items[i].baseUomCode,
          isDeliverMode: true,
          issueQty: qty.toDouble(),
          // DLN เก็บ unitPriceCtrl เป็นราคาในสกุลเงินของ header (_currency) เสมอ — ตั้ง header ให้ตรงกับ SO ต้นทางไว้
          // ข้างล่างแล้ว (สกุลเงินเดียวกันทั้งใบ) จึงเติมราคาดิบจาก SO ตรงๆ ได้เลยโดยไม่ต้องแปลงเป็นบาท
          unitPrice: price,
          discountPercent: _poNum(l['discount_percent']),
          refSoDetailId: id,
          // ราคาใบสั่งขายหลังส่วนลด ก่อน VAT — เทียบกับ _netUnit ของบรรทัดตอน Post
          soUnitPrice: _poNum(l['net_unit_price_fc'] ?? l['unit_price_fc']),
          vatType: vatType, vatRate: vatRate,
        );
        _lines.add(line);
        _applyMainLocation(line);
      }
      _refSoId = pickedLines.first['header_id'] as int;
      _refSoDocNoLabel = pickedLines.first['doc_no'] as String?;
      _loadRefDims();
      // ใบสั่งซื้อลูกค้า: ค่าเริ่มต้นจากใบสั่งขาย (ไม่ทับค่าที่ผู้ใช้กรอกไว้แล้ว)
      if (_poNoCtrl.text.trim().isEmpty && _poDate == null) {
        _poNoCtrl.text = (pickedLines.first['customer_po_no'] as String?) ?? '';
        final poDate = pickedLines.first['customer_po_date'];
        _poDate = poDate != null ? parseLocalDate(poDate) : null;
      }
      _loadSoSalespersons(_refSoId!);
      // ส่งตามสกุลเงินของ SO ต้นทางเสมอ (ทุกบรรทัดที่เลือกมาจาก fetchDeliverableLines ของลูกค้าเดียวกัน แต่อาจมาจาก
      // SO คนละใบ คนละสกุลเงินได้ในทางทฤษฎี — ใช้สกุลเงินของ SO ใบแรกที่เลือกเป็นสกุลเงินของทั้ง DLN นี้)
      // อัตราแลกเปลี่ยนใช้อัตราปัจจุบันของสกุลเงิน ไม่ใช่อัตราตอนสั่งขาย — รายได้บันทึกด้วยอัตรา ณ วันที่เกิดรายการ
      final soCurrencyCode = _soCurrencyCode(pickedLines.first);
      final matched = _currencies.cast<Currency?>().firstWhere((c) => c?.currencyCode == soCurrencyCode, orElse: () => null);
      if (matched != null) {
        _currency = matched;
        _exchangeRate = matched.baseRate > 0 ? matched.baseRate : 1;
      }
    });
    if (_currency?.currencyCode != curBefore) _loadAdvances();
  }

  // ที่มาของราคาขาย: ล็อก = ตารางราคา/ใบสั่งขาย, ปลดล็อก = ผู้ดูแลระบบแก้ได้, ดินสอ = ผู้ดูแลระบบแก้ราคาเองแล้ว
  Widget? _priceSourceIcon(_CountLine l, bool isEnglish) {
    if (!_priceFromSource(l)) return null;
    final src = l.refSoDetailId != null
        ? (isEnglish ? 'Sales order price' : 'ราคาตามใบสั่งขาย')
        : (isEnglish ? 'Price list price' : 'ราคาตามตารางราคา');
    final (IconData icon, String tip) = l.priceOverridden
        ? (Icons.edit, isEnglish ? 'Price changed by administrator' : 'ผู้ดูแลระบบแก้ราคาเอง')
        : _priceLocked(l)
            ? (Icons.lock, '$src — ${isEnglish ? 'only administrators can change it' : 'แก้ได้เฉพาะผู้ดูแลระบบ'}')
            : (Icons.lock_open, '$src — ${isEnglish ? 'editable for administrators' : 'ผู้ดูแลระบบแก้ได้'}');
    return Tooltip(message: tip, child: Icon(icon, size: 14, color: Colors.grey.shade600));
  }

  void _removeLine(_CountLine line) {
    setState(() => _lines.remove(line));
    line.dispose();
  }

  // '15' อ้างอิงใบรับสินค้าที่อาจยังไม่ได้ตั้งหนี้ AP — '10' (ตั้งหนี้แยกเองที่ AP, ระบบไม่รู้ว่าตั้งแล้วหรือยัง) และ
  // '12' ที่ยังเป็น Received (ยังไม่ได้ Post AP/GL) — เตือนผลกระทบแล้วให้ผู้ใช้เลือกหยุดหรือทำต่อ
  Future<bool> _confirmReturnSourceImpact() async {
    final isEnglish = _isEnglish;
    final src = _refImTransactionLabel ?? '';
    String? msg;
    if (_refImSourceSysDocType == '10') {
      msg = isEnglish
          ? 'Source document $src is a goods receipt without auto billing (GR/IR). When it was received, the system credited the GR/IR clearing account, not Accounts Payable.\n\n'
              'Posting this return creates an AP credit note (Dr AP). If the vendor invoice for $src has NOT been recorded in AP yet:\n'
              '• the vendor\'s AP balance will become negative (debit balance)\n'
              '• the GR/IR clearing account will keep an open balance for the returned goods\n\n'
              'Recommended: record the vendor invoice in AP first, then post this return.'
          : 'เอกสารต้นฉบับ $src เป็นใบรับสินค้าแบบไม่ตั้งหนี้อัตโนมัติ (GR/IR) — ตอนรับสินค้าระบบลง Cr บัญชีพักรับสินค้า (GR/IR) ไม่ใช่เจ้าหนี้\n\n'
              'การ Post เอกสารคืนสินค้านี้จะสร้างใบลดหนี้ AP (Dr เจ้าหนี้) หากยังไม่ได้ตั้งหนี้ใบกำกับของ $src ที่ระบบ AP:\n'
              '• ยอดเจ้าหนี้ของผู้ขายรายนี้จะติดลบ (ยอดคงเหลือด้านเดบิต)\n'
              '• บัญชีพักรับสินค้า (GR/IR) จะค้างยอดของสินค้าที่คืน\n\n'
              'แนะนำ: ตั้งหนี้ใบกำกับของผู้ขายที่ AP ให้เรียบร้อยก่อน แล้วจึง Post เอกสารคืนสินค้านี้';
    } else if (_refImSourceSysDocType == '12' && _refImSourceStatus == 'Received') {
      msg = isEnglish
          ? 'Source document $src has been received but NOT billed yet (no AP invoice / GL entry).\n\n'
              'Posting this return now creates an AP credit note against an invoice that does not exist yet:\n'
              '• the vendor\'s AP balance will become negative until $src is billed\n'
              '• when $src is billed later, it will still be billed at the full received quantity\n\n'
              'Recommended: post the billing of $src first, then post this return.'
          : 'เอกสารต้นฉบับ $src รับสินค้าแล้วแต่ยังไม่ได้ตั้งหนี้ (ยังไม่มีใบตั้งหนี้ AP / รายการบัญชี)\n\n'
              'การ Post เอกสารคืนสินค้าตอนนี้จะสร้างใบลดหนี้ AP ทั้งที่ยังไม่มีใบตั้งหนี้:\n'
              '• ยอดเจ้าหนี้ของผู้ขายรายนี้จะติดลบจนกว่าจะตั้งหนี้ $src\n'
              '• เมื่อตั้งหนี้ $src ภายหลัง จะยังตั้งหนี้เต็มจำนวนที่รับมา\n\n'
              'แนะนำ: Post ตั้งหนี้ของ $src ให้เรียบร้อยก่อน แล้วจึง Post เอกสารคืนสินค้านี้';
    }
    if (msg == null) return true;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(child: Text(isEnglish ? 'Impact of this return' : 'ผลกระทบของการคืนสินค้านี้')),
        ]),
        content: SizedBox(width: 520, child: SingleChildScrollView(child: Text(msg!))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Stop' : 'หยุด')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEnglish ? 'Continue posting' : 'ทำต่อ (Post)')),
        ],
      ),
    );
    return go == true;
  }

  // Post: ตรวจวงเงินก่อน (เอกสารฝั่งขาย) — เกินและยังไม่ได้รับอนุมัติ ให้เลือกบันทึกร่างแล้วขออนุมัติ
  // บรรทัดที่ราคารับ (หรือราคาตามใบกำกับ ตอน Post AP/GL ของ '12') ต่างจากราคาในใบสั่งซื้อ — เตือนให้ยืนยันก่อน (ไม่บล็อก)
  Future<bool> _confirmPoPriceDiffs({bool billing = false, bool sales = false}) async {
    final isEnglish = _isEnglish;
    final fmt = NumberFormat('#,##0.####');
    final diffs = <String>[];
    final src = sales ? 'SO' : 'PO';
    for (final l in _lines) {
      final ref = sales ? l.soUnitPrice : l.poUnitPrice;
      // เอกสารต้นทางที่ไม่ได้ใส่ราคา (0) ถือว่ายังไม่กำหนดราคา ไม่เตือน
      if (ref == null || ref == 0 || (sales ? l.refSoDetailId : l.refPoDetailId) == null || l.isFree) continue;
      // ราคาหลังส่วนลด ก่อน VAT เทียบกับราคาในใบสั่งซื้อ/ใบสั่งขาย
      final price = _netUnit(l, billed: billing);
      if ((price - ref).abs() < 0.0001) continue;
      final pct = (price - ref) / ref * 100;
      diffs.add('${l.item.itemCode}: $src ${fmt.format(ref)} -> ${fmt.format(price)} (${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%)');
    }
    if (diffs.isEmpty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(sales
            ? (isEnglish ? 'Price differs from the sales order' : 'ราคาต่างจากใบสั่งขาย')
            : (isEnglish ? 'Price differs from the purchase order' : 'ราคาต่างจากใบสั่งซื้อ')),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sales
                  ? (isEnglish
                      ? 'These lines are priced differently from the sales order (document currency). Post anyway?'
                      : 'รายการต่อไปนี้ราคาขายต่างจากใบสั่งขาย (สกุลเงินของเอกสาร) ต้องการ Post ต่อหรือไม่')
                  : (isEnglish
                      ? 'These lines are priced differently from the purchase order (document currency). Post anyway?'
                      : 'รายการต่อไปนี้ราคาต่างจากใบสั่งซื้อ (สกุลเงินของเอกสาร) ต้องการ Post ต่อหรือไม่')),
              const SizedBox(height: 8),
              for (final d in diffs) Text(d, style: const TextStyle(fontSize: 13)),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEnglish ? 'Post anyway' : 'Post ต่อ')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _onPost() async {
    if (_isReturnToSupplierMode && !await _confirmReturnSourceImpact()) return;
    if (['10', '11', '12'].contains(_selectedSysDocType) && !await _confirmPoPriceDiffs()) return;
    // '31' ตั้งหนี้ทันที — ราคาขายต่างจาก SO ให้ยืนยัน ('32' เตือนตอนออกใบแจ้งหนี้, '30' ไม่มีราคาขาย)
    if (_isDlnBillingMode && !await _confirmPoPriceDiffs(sales: true)) return;
    if (!await _confirmLinkedAdvances()) return;
    if (!_checkVendorCnDnNo()) return;
    if (_isCashPurchaseMode && _cashPaidLc > 0.005 && !_payApproval.covers(_cashPaidLc)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_payApproval.isPending
          ? (_isEnglish ? 'This cash purchase is waiting for payment approval' : 'เอกสารซื้อเงินสดนี้อยู่ระหว่างรออนุมัติจ่าย')
          : (_isEnglish
              ? 'Save the draft and request payment approval before posting'
              : 'กรุณาบันทึกร่างและขออนุมัติจ่ายก่อน Post'))));
      return;
    }
    // ขายเงินสดรับเงินครบตอน Post — ไม่ตรวจวงเงินเครดิต
    if (_isArCustomerMode && _customerId != null && !_isCashSaleMode) {
      final go = await checkCreditBeforePost(
        context,
        service: _creditService,
        customerId: _customerId!,
        docId: _id,
        amount: _creditAmount,
        credit: _credit,
        saveDraft: () async {
          await _save('Draft', notify: false);
          return _id;
        },
        onRequested: widget.onSaveSuccess,
      );
      if (!go) return;
    }
    await _save('Post');
  }

  // ยอดหักมัดจำ: ไม่เกินยอดคงเหลือของแต่ละใบ และรวมไม่เกินยอดใบตั้งหนี้/ใบแจ้งหนี้ (รวม VAT)
  bool _checkAdvances() {
    if (!_showAdvances || _advRows.isEmpty) return true;
    final isEnglish = _isEnglish;
    void warn(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    for (final r in _advRows) {
      final amt = _parseNum(r.ctrl.text);
      if (amt < 0 || amt > r.balanceFc + 0.005) {
        warn('${r.docNo}: ${isEnglish ? 'Deduction exceeds the deposit balance' : 'ยอดหักเกินยอดคงเหลือของใบมัดจำ'} (${_fmtMoney.format(r.balanceFc)})');
        return false;
      }
    }
    if (_advTotalFc > _billTotalFc + 0.005) {
      warn(isEnglish ? 'Deposit deduction exceeds the bill total' : 'ยอดหักเงินมัดจำเกินยอดรวมของใบตั้งหนี้/ใบแจ้งหนี้');
      return false;
    }
    return true;
  }

  Future<void> _save(String action, {bool notify = true}) async {
    final isEnglish = _isEnglish;
    void warn(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

    if (_docId == null) { warn(isEnglish ? 'Please select a document type' : 'กรุณาเลือกประเภทเอกสาร'); return; }
    if (_warehouseId == null) { warn(isEnglish ? 'Please select a warehouse' : 'กรุณาเลือกคลังสินค้า'); return; }
    if (_isTransferMode && _toWarehouseId == null) {
      warn(isEnglish ? 'Please select a destination warehouse' : 'กรุณาเลือกคลังปลายทาง');
      return;
    }
    // ซื้อเงินสดไม่เลือกผู้ขายได้ — backend ใช้ผู้ขายเงินสดตามที่ตั้งค่าไว้
    if (_isApVendorMode && _vendorId == null && !_isCashPurchaseMode) {
      warn(isEnglish ? 'Please select a vendor' : 'กรุณาเลือกผู้ขาย');
      return;
    }
    if (_isGrnBillingMode && _vendorRefRequired && _refNoCtrl.text.trim().isEmpty) {
      warn(_isCashPurchaseMode
          ? (isEnglish ? 'Please enter the vendor tax invoice number' : 'กรุณาระบุเลขที่ใบกำกับภาษีของผู้ขาย')
          : (isEnglish ? 'Please enter the vendor invoice number' : 'กรุณาระบุเลขที่ใบกำกับสินค้าผู้ขาย'));
      return;
    }
    // ขายเงินสดไม่เลือกลูกค้าได้ — backend ใช้ลูกค้าเงินสดตามที่ตั้งค่าไว้
    if (_isArCustomerMode && _customerId == null && !_isCashSaleMode) {
      warn(isEnglish ? 'Please select a customer' : 'กรุณาเลือกลูกค้า');
      return;
    }
    if (action == 'Post' && _glDimMissing.isNotEmpty) {
      warn('${isEnglish ? 'Branch/dimensions incomplete' : 'สาขา/มิติไม่ครบ'}: ${_glDimMissing.join(', ')}');
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
        if (l.isDeltaMode && !l.isIncreaseMode && !l.isNonStock && l.counted < 0) {
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
        // ของแถม (l.isFree) ยกเว้นการบังคับต้นทุนต่อหน่วย — ปล่อยเป็น 0 ได้ตามที่ออกแบบไว้ (ดูหมายเหตุที่ isFree)
        if (!l.isFree && l.variance > 0 && (l.item.costingMethod != 'STANDARD' || _isPoReceiveMode) &&
            _parseNum(l.unitCostCtrl.text) <= 0) {
          warn('${l.item.itemCode}: ${isEnglish ? 'Unit cost is required' : 'กรุณาระบุต้นทุนต่อหน่วย'}');
          return;
        }
        // '15'/'20'/'25': ราคาบนใบลดหนี้/เพิ่มหนี้ AP — ไม่มีราคา = เอกสารยอด 0 ทั้งที่สต็อกเคลื่อนไหวจริง
        if (!l.isFree && (l.isApReturnCnMode || l.isApDnMode) && _parseNum(l.unitCostCtrl.text) <= 0) {
          warn('${l.item.itemCode}: ${isEnglish ? 'Unit price for the AP credit/debit note is required' : 'กรุณาระบุราคาต่อหน่วยสำหรับใบลดหนี้/เพิ่มหนี้ AP'}');
          return;
        }
        // '40'/'45': ราคาขายบนใบลดหนี้/เพิ่มหนี้ AR (เอกสารอิสระ) — '35' ไม่บังคับ เพราะราคามาจากใบส่งสินค้าต้นฉบับ
        if (!l.isFree && (_selectedSysDocType == '40' || _isArDnMode) && _parseNum(l.unitPriceCtrl.text) <= 0) {
          warn('${l.item.itemCode}: ${isEnglish ? 'Unit price for the AR credit/debit note is required' : 'กรุณาระบุราคาขายต่อหน่วยสำหรับใบลดหนี้/เพิ่มหนี้ AR'}');
          return;
        }
        if (_isVatMode && (l.vatType == null || l.vatType!.isEmpty)) {
          warn('${l.item.itemCode}: ${isEnglish ? 'VAT type is required' : 'กรุณาระบุประเภทภาษี VAT'}');
          return;
        }
        if (_salesDiscountMode && !parseStepDiscount(l.discPctCtrl.text).valid) {
          warn('${l.item.itemCode}: ${isEnglish ? 'Discount must be percentages joined by +, at most $maxDiscountSteps steps (e.g. 10+5+2)' : 'ส่วนลดต้องเป็น % คั่นด้วย + ไม่เกิน $maxDiscountSteps ขั้น เช่น 10+5+2'}');
          return;
        }
        final pct = _parseNum(l.discPctCtrl.text);
        if (_showDiscount && !_salesDiscountMode && (pct < 0 || pct > 100)) {
          warn('${l.item.itemCode}: ${isEnglish ? 'Discount must be 0-100%' : 'ส่วนลดต้องอยู่ระหว่าง 0-100%'}');
          return;
        }
      }
      final shortage = _stockShortage(isEnglish);
      if (shortage != null) { warn(shortage); return; }
    }
    // ส่วนลดติดลบ/ราคาสุทธิสูงเกิน — ตรวจทั้งร่างและโพสต์ (backend ก็ไม่ให้บันทึก)
    if (_salesDiscountMode) {
      for (final l in _lines) {
        if (_lineDiscNegative(l)) {
          warn('${l.item.itemCode}: ${isEnglish ? 'Discount amount cannot be negative — change the unit price instead' : 'ส่วนลด (เงิน) ติดลบไม่ได้ — ถ้าต้องการขายสูงกว่าราคา ให้แก้ราคาขาย/หน่วย'}');
          return;
        }
        if (_netTooHigh(l)) {
          warn('${l.item.itemCode}: ${isEnglish ? 'Net price/unit is higher than the price after discount % — change the unit price instead' : 'ราคาสุทธิ/หน่วยสูงกว่าราคาหลังหักส่วนลด % — ถ้าต้องการขายสูงกว่าราคา ให้แก้ราคาขาย/หน่วย'}');
          return;
        }
      }
    }
    if (_salesDiscountMode && !_checkSalesDiscountTotals(warn)) return;
    if (!_checkAdvances()) return;
    if (_isCashMode) {
      final err = _cash.validate(post: action == 'Post', dueFc: _cashDueFc, isEnglish: isEnglish, fmt: _fmtMoney, purchase: _isCashPurchaseMode);
      if (err != null) { warn(err); return; }
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
        vendorInvoiceDate: _isGrnBillingMode ? _invoiceDate : (_isApCnDnDoc ? _vendorInvoiceDate : null),
        refImTransactionId: _isReturnSourceDocMode ? _refImTransactionId : null,
        refPoId: _isReceiveMode ? _refPoId : null,
        refSoId: _isDeliverMode ? _refSoId : null,
        customerPoNo: _isDeliverMode && _poNoCtrl.text.trim().isNotEmpty ? _poNoCtrl.text.trim() : null,
        customerPoDate: _isDeliverMode ? _poDate : null,
        currencyId: (_isApVendorMode || _isArCustomerMode) ? _currency?.id : null,
        currencyCode: (_isApVendorMode || _isArCustomerMode) ? (_currency?.currencyCode ?? CurrencyService.baseCode) : null,
        exchangeRate: (_isApVendorMode || _isArCustomerMode) ? _exchangeRate : 1,
        priceIncludesVat: _inclVat,
        billDiscountPercent: _salesDiscountMode ? _billDiscPct : 0,
        cashDiscountAmount: _salesDiscountMode ? _cashDisc : 0,
        sendCreditTerm: _showCreditTerm,
        creditTermMonths: _showCreditTerm ? _creditMonths : null,
        creditTermDays: _showCreditTerm ? _creditDays : null,
        dueDate: _showCreditTerm ? _dueDate : null,
        billToName: _isCashMode ? _cash.billToName : null,
        billToAddress: _isCashMode ? _cash.billToAddress : null,
        billToTaxId: _isCashMode ? _cash.billToTaxId : null,
        billToBranch: _isCashMode ? _cash.billToBranch : null,
        cashReceived: _isCashSaleMode ? _cash.cashReceived : 0,
        taxInvoiceKind: _isCashPurchaseMode ? _cash.taxInvoiceKind : null,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        dim1Id: _dimSelections[1], dim2Id: _dimSelections[2], dim3Id: _dimSelections[3],
        dim4Id: _dimSelections[4], dim5Id: _dimSelections[5],
        branchId: _branchId,
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
            // จำนวนตามหน่วยของบรรทัด — backend แปลงเป็นหน่วยหลัก (counted_qty) และราคาต่อหน่วยหลักเอง
            uomQty: l.isDeltaMode ? _parseNum(l.issueQtyCtrl.text) : null,
            systemQty: l.systemQty,
            countedQty: l.counted,
            // _isApVendorMode: unitCostCtrl คือราคาที่กรอกในสกุลเงินของ header (_currency) เสมอ ส่งเป็น unitCostFc
            // ให้ backend คูณ exchange_rate เองตอนบันทึก (ดู insertAndPostAdjustment/updateTransaction) — โหมดอื่น
            // ไม่มีสกุลเงินต่างประเทศ ส่ง unitCost ตรงๆ เหมือนเดิมทุกประการ
            unitCost: _isApVendorMode ? null : (l.unitCostCtrl.text.trim().isEmpty ? null : _parseNum(l.unitCostCtrl.text)),
            unitCostFc: _isApVendorMode && l.unitCostCtrl.text.trim().isNotEmpty ? _parseNum(l.unitCostCtrl.text) : null,
            unitPrice: l.unitPriceCtrl.text.trim().isEmpty ? null : _parseNum(l.unitPriceCtrl.text),
            discountPercent: _showDiscount && !_salesDiscountMode ? _parseNum(l.discPctCtrl.text) : null,
            discountText: _salesDiscountMode ? l.discPctCtrl.text.trim() : null,
            lineDiscountAmount: _salesDiscountMode ? _lineDiscOf(l) : 0,
            netUnitPrice: _netEntered(l) ? _parseNum(l.netPriceCtrl.text) : null,
            isFree: l.isFree,
            vatType: _isVatMode ? l.vatType : null,
            vatRate: _isVatMode ? l.vatRate : null,
            refImTransactionDetailId: l.refImTransactionDetailId,
            refPoDetailId: l.refPoDetailId,
            refSoDetailId: l.refSoDetailId,
            glAccountId: _isIssueMode ? l.glAccountId : null,
            dim1Id: _isIssueMode ? l.dims[1] : null, dim2Id: _isIssueMode ? l.dims[2] : null,
            dim3Id: _isIssueMode ? l.dims[3] : null, dim4Id: _isIssueMode ? l.dims[4] : null,
            dim5Id: _isIssueMode ? l.dims[5] : null,
            description: l.remarkCtrl.text.trim().isEmpty ? null : l.remarkCtrl.text.trim(),
          )).toList();

      final payments = _isCashMode ? _cash.paymentsForSave() : null;
      final whts = _isCashMode ? _cash.whtsForSave(_exchangeRate) : null;
      if (_id == null) {
        final result = await _service.createTransaction(header: header, details: details, action: action,
            salespersons: _isArCustomerMode ? _salespersons : null, advances: _showAdvances ? _advancesForSave : null,
            payments: payments, whts: whts);
        _id = result.header.id;
      } else {
        if (_status == 'Draft') {
          await _service.updateTransaction(id: _id!, header: header, details: details,
              salespersons: _isArCustomerMode ? _salespersons : null, advances: _showAdvances ? _advancesForSave : null,
              payments: payments, whts: whts);
        }
        if (action == 'Post') {
          await _service.postTransaction(_id!);
        }
      }
      if (mounted && notify) {
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
        priceIncludesVat: _priceIncludesVat, vendorInvoiceDate: _invoiceDate,
      );
      if (!_checkAdvances()) return;
      final details = _lines.map((l) => ImTransactionDetail(
            id: l.id,
            itemId: l.item.id!,
            billedUnitCostFc: l.billedUnitCostCtrl.text.trim().isEmpty ? null : _parseNum(l.billedUnitCostCtrl.text),
            discountPercent: _parseNum(l.discPctCtrl.text),
          )).toList();
      await _service.updateTransaction(id: _id!, header: header, details: details, advances: _advancesForSave);
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
    if (!_checkAdvances()) return;
    if (!await _confirmPoPriceDiffs(billing: true)) return;
    if (!await _confirmLinkedAdvances()) return;
    setState(() => _isSaving = true);
    try {
      final details = _lines.map((l) => ImTransactionDetail(
            id: l.id,
            itemId: l.item.id!,
            billedUnitCostFc: l.billedUnitCostCtrl.text.trim().isEmpty ? null : _parseNum(l.billedUnitCostCtrl.text),
            discountPercent: _parseNum(l.discPctCtrl.text),
            vatType: _isVatMode ? l.vatType : null,
            vatRate: _isVatMode ? l.vatRate : null,
          )).toList();
      await _service.postBilling(id: _id!, refNo: refNo, details: details, advances: _advancesForSave,
          vendorInvoiceDate: _invoiceDate, priceIncludesVat: _priceIncludesVat);
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
        customerPoNo: _poNoCtrl.text.trim().isEmpty ? null : _poNoCtrl.text.trim(), customerPoDate: _poDate,
        billDiscountPercent: _billDiscPct, cashDiscountAmount: _cashDisc,
        sendCreditTerm: _showCreditTerm, creditTermMonths: _creditMonths, creditTermDays: _creditDays, dueDate: _dueDate,
      );
      if (!_checkSalesDiscountTotals(warn)) return;
      if (!_checkAdvances()) return;
      final details = _lines.map((l) => ImTransactionDetail(
            id: l.id,
            itemId: l.item.id!,
            unitPrice: l.unitPriceCtrl.text.trim().isEmpty ? null : _parseNum(l.unitPriceCtrl.text),
            discountText: l.discPctCtrl.text.trim(),
            lineDiscountAmount: _lineDiscOf(l),
            netUnitPrice: _netEntered(l) ? _parseNum(l.netPriceCtrl.text) : null,
          )).toList();
      await _service.updateTransaction(id: _id!, header: header, details: details, salespersons: _salespersons,
          advances: _advancesForSave);
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
    if (!_checkSalesDiscountTotals(warn)) return;
    if (!_checkAdvances()) return;
    if (!await _confirmPoPriceDiffs(sales: true)) return;
    if (!await _confirmLinkedAdvances()) return;
    setState(() => _isSaving = true);
    try {
      final details = _lines.map((l) => ImTransactionDetail(
            id: l.id,
            itemId: l.item.id!,
            unitPrice: l.unitPriceCtrl.text.trim().isEmpty ? null : _parseNum(l.unitPriceCtrl.text),
            discountText: l.discPctCtrl.text.trim(),
            lineDiscountAmount: _lineDiscOf(l),
            netUnitPrice: _netEntered(l) ? _parseNum(l.netPriceCtrl.text) : null,
            vatType: _isVatMode ? l.vatType : null,
            vatRate: _isVatMode ? l.vatRate : null,
          )).toList();
      await _service.postBillingDln(id: _id!, refNo: _refNoCtrl.text.trim(), details: details, salespersons: _salespersons,
          customerPoNo: _poNoCtrl.text.trim(), customerPoDate: _poDate, exchangeRate: _isForeignCurrency ? _exchangeRate : null,
          advances: _advancesForSave, billDiscountPercent: _billDiscPct, cashDiscountAmount: _cashDisc,
          sendCreditTerm: _showCreditTerm, creditTermMonths: _creditMonths, creditTermDays: _creditDays, dueDate: _dueDate);
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

  // ยกเลิก: ใช้เมื่อถอยไม่ได้ (เช่น งวดเดิมปิดแล้ว) — ย้อนสต็อก + ลงรายการบัญชีกลับวันที่ยกเลิก
  // ใบตั้งหนี้ AP/AR ที่สร้างให้ถูกยกเลิกด้วย (รายการกลับวันที่ยกเลิกเช่นกัน)
  Future<void> _void() async {
    if (_id == null) return;
    final isEnglish = _isEnglish;
    final reason = await showDocReasonDialog(context,
        isEnglish: isEnglish,
        title: isEnglish ? 'Void Document' : 'ยกเลิกเอกสาร',
        message: isEnglish
            ? 'Stock movements will be reversed and a reversing journal entry dated today will be posted (including any linked AP/AR invoice). The original stays in its period.'
            : 'ระบบจะย้อนสต็อก และลงรายการบัญชีกลับในวันนี้ (รวมใบตั้งหนี้ AP/AR ที่สร้างจากเอกสารนี้) เอกสารเดิมยังอยู่ในงวดเดิม',
        confirmLabel: isEnglish ? 'Void' : 'ยกเลิกเอกสาร');
    if (reason == null) return;
    setState(() => _isSaving = true);
    try {
      await _service.voidTransaction(_id!, reason);
      if (mounted) widget.onSaveSuccess();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish ? 'Void failed: $e' : 'Void ล้มเหลว: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ถอย: งวดยังเปิดและไม่มีเอกสารอื่นอ้างอิง — ลบรายการบัญชีและใบตั้งหนี้ AP/AR ที่สร้างให้ (เก็บเลขที่ไว้ใช้ซ้ำ)
  // '12'/'32' ที่ตั้งหนี้แล้ว ถอยเฉพาะใบตั้งหนี้กลับไปรอตั้งหนี้ก่อน (ดู reverseToDraft ใน imTransactionController.js)
  Future<void> _reverseToDraft() async {
    if (_id == null) return;
    final isEnglish = _isEnglish;
    final billOnly = _reverseTo == 'Received' || _reverseTo == 'Delivered';
    final reason = await showDocReasonDialog(context,
        isEnglish: isEnglish,
        title: billOnly
            ? (isEnglish ? 'Reverse Billing' : 'ถอยการตั้งหนี้')
            : (isEnglish ? 'Reverse to Draft' : 'ถอยเป็นร่าง'),
        message: billOnly
            ? (isEnglish
                ? 'The linked AP/AR invoice and its journal entry will be removed; the document returns to $_reverseTo. The invoice number is kept for re-posting.'
                : 'ระบบจะลบใบตั้งหนี้ AP/AR และรายการบัญชีของใบนั้น เอกสารกลับไปสถานะรอตั้งหนี้ เลขที่ใบตั้งหนี้เดิมจะใช้ซ้ำตอนโพสต์ใหม่')
            : (isEnglish
                ? 'Stock movements will be reversed and the journal entry (plus any linked AP/AR invoice) removed. The document number and journal numbers are kept for re-posting.'
                : 'ระบบจะย้อนสต็อก และลบรายการบัญชี (รวมใบตั้งหนี้ AP/AR ที่สร้างจากเอกสารนี้) เลขที่เอกสารและเลขที่รายการบัญชีเดิมจะใช้ซ้ำตอนโพสต์ใหม่'),
        confirmLabel: isEnglish ? 'Reverse' : 'ถอย',
        confirmColor: Colors.orange.shade800);
    if (reason == null) return;
    setState(() => _isSaving = true);
    try {
      await _service.reverseToDraft(_id!, reason);
      if (mounted) widget.onSaveSuccess();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish ? 'Reverse to Draft failed: $e' : 'ถอยกลับเป็นฉบับร่างล้มเหลว: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ลบ: เฉพาะร่าง — เก็บไว้ด้วยสถานะ Deleted เพื่อตรวจสอบ แต่นำกลับมาใช้ไม่ได้
  Future<void> _delete() async {
    if (_id == null) return;
    final isEnglish = _isEnglish;
    final reason = await showDocReasonDialog(context,
        isEnglish: isEnglish,
        title: isEnglish ? 'Delete Document' : 'ลบเอกสาร',
        message: isEnglish
            ? 'The document will be kept for audit with status Deleted and cannot be used again.'
            : 'ระบบจะเก็บเอกสารไว้ตรวจสอบด้วยสถานะ Deleted และนำกลับมาใช้ไม่ได้อีก',
        confirmLabel: isEnglish ? 'Delete' : 'ลบ');
    if (reason == null) return;
    setState(() => _isSaving = true);
    try {
      await _service.deleteTransaction(_id!, reason);
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

    // การ์ดข้อมูลเอกสารล็อคอยู่ด้านบน (ไม่เลื่อนตามเนื้อหา) — สูงตามสภาพย่อ/ขยาย
    // จอเตี้ย: จำกัดไม่เกิน 60% ของพื้นที่ แล้วเลื่อนภายในการ์ดแทน
    return LayoutBuilder(builder: (context, box) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: box.maxHeight.isFinite ? box.maxHeight * 0.6 : double.infinity),
            child: SingleChildScrollView(child: _buildHeaderCard(isEnglish)),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailCard(isEnglish),
                const SizedBox(height: 12),
                _buildTotalsCard(isEnglish),
                if (_isCashMode) ...[
                  const SizedBox(height: 12),
                  ImCashSalePanel(
                    controller: _cash,
                    readOnly: _isReadOnly,
                    isEnglish: isEnglish,
                    dueFc: _cashDueFc,
                    whtBaseFc: _lines.fold(0.0, (t, l) => t + _amt(l).net),
                    currencyCode: _currency?.currencyCode ?? CurrencyService.baseCode,
                    whtTypes: _whtTypes,
                    customerLabel: _isCashPurchaseMode
                        ? (_vendorId != null ? _vendorLabel : null)
                        : (_customerId != null ? _customerLabel : null),
                    purchase: _isCashPurchaseMode,
                    onTaxInvoiceKindChanged: () => setState(() {}),
                    onChanged: () { if (mounted) setState(() {}); },
                  ),
                ],
                if (_isCashPurchaseMode && (_status == 'Draft' || _payApproval.status != null)) ...[
                  const SizedBox(height: 8),
                  ImPaymentApprovalPanel(
                    service: _payService,
                    docId: _id,
                    docNo: _docNo,
                    paidLc: _cashPaidLc,
                    approval: _payApproval,
                    isDraft: _status == 'Draft' && !widget.viewOnly,
                    isEnglish: isEnglish,
                    // ขออนุมัติตามยอดที่บันทึกไว้ — บันทึกร่างก่อนเสมอ
                    beforeRequest: () async {
                      await _save('Draft', notify: false);
                      return _id != null;
                    },
                    onChanged: () async {
                      if (_id == null) return;
                      await _loadExisting(_id!);
                      if (mounted) setState(() {});
                      widget.onSaveSuccess();
                    },
                  ),
                ],
                const SizedBox(height: 12),
                _buildGlCard(isEnglish),
                if (_reverseHistory.isNotEmpty || _status == 'Deleted') ...[
                  const SizedBox(height: 12),
                  _buildHistory(isEnglish),
                ],
              ],
            ),
          ),
        ),
        _buildActionBar(isEnglish),
      ],
    ));
  }

  // ── การ์ดมาตรฐาน: หัวการ์ด (ชื่อ · ชิป · สรุปด้านขวา · ปุ่ม · ย่อ/ขยาย) — แบบเดียวกับการ์ดข้อมูลเอกสาร ──
  // collapseKey: จำการย่อ/ขยายต่อเครื่อง (SharedPreferences im_card_<key>_collapsed)
  // glPreview: การ์ดตัวอย่างรายการบัญชี — ชิปเดบิต/เครดิตที่หัวการ์ด และสรุปบัญชีตอนย่อ (จากยอดที่ _glLine สะสมไว้)
  final Map<String, bool> _cardCollapsed = {};
  static const _cardCollapseDefault = {'gl': true, 'ar': true, 'hist': true};
  bool _isCardCollapsed(String key) => _cardCollapsed[key] ?? _cardCollapseDefault[key] ?? false;

  void _loadCardPrefs(SharedPreferences p) {
    for (final k in _cardCollapseDefault.keys) {
      final v = p.getBool('im_card_${k}_collapsed');
      if (v != null) _cardCollapsed[k] = v;
    }
  }

  void _toggleCard(String key) {
    final v = !_isCardCollapsed(key);
    setState(() => _cardCollapsed[key] = v);
    SharedPreferences.getInstance().then((p) => p.setBool('im_card_${key}_collapsed', v)).catchError((_) => false);
  }

  Widget _collapseButton(bool collapsed, VoidCallback onPressed, bool isEnglish) => OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 10), foregroundColor: Colors.blueGrey.shade800),
        icon: Icon(collapsed ? Icons.expand_more : Icons.expand_less, size: 18),
        label: Text(collapsed ? (isEnglish ? 'Expand' : 'ขยาย') : (isEnglish ? 'Collapse' : 'ย่อ'), style: const TextStyle(fontSize: 12)),
        onPressed: onPressed,
      );

  Widget _chip(String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg), overflow: TextOverflow.ellipsis),
      );

  Widget _card({
    required String title,
    required List<Widget> children,
    Widget? trailing,
    List<Widget> chips = const [],
    List<Widget> actions = const [],
    String? collapseKey,
    Widget? summary,
    bool glPreview = false,
  }) {
    final isEnglish = _isEnglish;
    if (_glSectionMode) return _glSection(_glSectionTitle ?? title, children);
    final collapsed = collapseKey != null && _isCardCollapsed(collapseKey);
    if (glPreview) {
      trailing ??= _glBalanceChip(isEnglish);
      summary ??= _glSummary(isEnglish);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ซ้าย: ชื่อ + ชิป / ขวา: สรุป + ปุ่ม — จอแคบ ฝั่งขวาขึ้นบรรทัดใหม่แทนการล้นจอ
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 6,
              children: [
                Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ...chips,
                ]),
                Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  if (trailing != null) trailing,
                  ...actions,
                  if (collapseKey != null) _collapseButton(collapsed, () => _toggleCard(collapseKey), isEnglish),
                ]),
              ],
            ),
          ),
          if (!collapsed) ...[const SizedBox(height: 8), ...(glPreview ? _glTable(children) : children)]
          else if (summary != null) ...[const SizedBox(height: 8), summary],
        ]),
      ),
    );
  }

  // ยอดเดบิต/เครดิตของการ์ดตัวอย่างบัญชีที่กำลังสร้าง — _glLine สะสม, reset ก่อนสร้างการ์ดแต่ละใบ
  double _glSumDr = 0, _glSumCr = 0;
  final List<(String?, String?, double, double)> _glSumLines = [];
  void _glSumReset() {
    _glSumDr = 0;
    _glSumCr = 0;
    _glSumLines.clear();
  }

  Widget? _glBalanceChip(bool isEnglish) {
    if (_glSumDr.abs() < 0.005 && _glSumCr.abs() < 0.005) return null;
    final ok = (_glSumDr - _glSumCr).abs() < 0.005;
    return ok
        ? _chip('Dr = Cr ${_fmtMoney.format(_glSumDr)} ✓', const Color(0xFF1E6B3A), const Color(0xFFE6F4EA))
        : _chip('Dr ${_fmtMoney.format(_glSumDr)} ≠ Cr ${_fmtMoney.format(_glSumCr)}', const Color(0xFF8A4B00), const Color(0xFFFFF0D9));
  }

  Widget? _glSummary(bool isEnglish) {
    final rows = _glSumLines.where((e) => e.$3.abs() >= 0.005 || e.$4.abs() >= 0.005).toList();
    if (rows.isEmpty) return null;
    Widget item((String?, String?, double, double) e) {
      final dr = e.$3.abs() >= 0.005;
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: dr ? _gDoc : _gFin, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 6),
        Text(dr ? 'Dr ' : 'Cr ', style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700)),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text('${e.$1 ?? ''} ${e.$2 ?? ''}  ${_fmtMoney.format(dr ? e.$3 : e.$4)}'.trim(),
              style: _numStyle, overflow: TextOverflow.ellipsis),
        ),
      ]);
    }

    const max = 4;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFF6F8FA), borderRadius: BorderRadius.circular(4)),
      child: Wrap(spacing: 22, runSpacing: 6, children: [
        for (final e in rows.take(max)) item(e),
        if (rows.length > max)
          Text(isEnglish ? '+${rows.length - max} more' : 'อีก ${rows.length - max} บรรทัด',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700)),
      ]),
    );
  }

  String _currencyLabel(Currency c) => _isEnglish && c.currencyNameEng.isNotEmpty ? c.currencyNameEng : c.currencyNameThai;

  Widget _fkField({required String label, required String? displayText, required bool hasValue, VoidCallback? onSearch,
      bool editable = true, bool auto = false, Widget? trailing}) {
    return InputDecorator(
      decoration: _hDec(label, editable: editable, auto: auto),
      child: Row(children: [
        Expanded(
          child: hasValue
              ? Text(displayText ?? '', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)
              : Text(_isEnglish ? '— Not specified —' : '— ไม่ระบุ —', style: TextStyle(color: Colors.grey.shade600)),
        ),
        if (onSearch != null)
          IconButton(icon: const Icon(Icons.search, color: Colors.teal, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onSearch),
        if (trailing != null) ...[const SizedBox(width: 4), trailing],
      ]),
    );
  }

  // ── การ์ดข้อมูลเอกสาร (user request 2026-11-15): 4 กลุ่มสีตามลำดับป้อน ① เอกสาร ② คู่ค้า/อ้างอิง ③ เงื่อนไขการเงิน
  // ④ เพิ่มเติม; สีฟิลด์ ขาว = กรอกเอง, ฟ้าอ่อน = ระบบเติมให้แก้ได้, เทา = อ่านอย่างเดียว; ย่อเป็นแถบสรุปได้
  // (ค่าเริ่มต้น: Posted/Void ย่อ, อื่นๆ ขยาย — จำค่าที่ผู้ใช้เลือกแยกตามกลุ่มสถานะ)
  static const _hAuto = Color(0xFFE3EEFA);
  static const _hRo = Color(0xFFEEF0F2);
  static const _gDoc = Color(0xFF1E5AA8);
  static const _gParty = Color(0xFF1F7A4D);
  static const _gFin = Color(0xFFB45309);
  static const _gMore = Color(0xFF5B6B7C);

  InputDecoration _hDec(String label, {bool auto = false, bool editable = true, Widget? suffixIcon, String? counterText}) {
    final req = label.endsWith(' *');
    final text = req ? label.substring(0, label.length - 2) : label;
    return InputDecoration(
      label: req
          ? Text.rich(TextSpan(text: text, children: const [TextSpan(text: ' *', style: TextStyle(color: Color(0xFFC62828)))]))
          : Text(text),
      border: const OutlineInputBorder(),
      isDense: true,
      filled: !editable || auto,
      fillColor: !editable ? _hRo : _hAuto,
      suffixIcon: suffixIcon,
      counterText: counterText,
    );
  }

  bool get _hdrPostedGroup => _status == 'Posted' || _status == 'Void';
  bool get _isHeaderCollapsed =>
      (_hdrCollapsedId == _id && _hdrCollapsed != null) ? _hdrCollapsed! : (_hdrPostedGroup ? _hdrPrefPosted : _hdrPrefDraft);

  Future<void> _loadHeaderPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _hdrPrefPosted = p.getBool('im_hdr_collapsed_posted') ?? true;
        _hdrPrefDraft = p.getBool('im_hdr_collapsed_draft') ?? false;
        _loadCardPrefs(p);
      });
    } catch (_) {}
  }

  void _toggleHeader() {
    final v = !_isHeaderCollapsed;
    final posted = _hdrPostedGroup;
    setState(() {
      _hdrCollapsed = v;
      _hdrCollapsedId = _id;
      if (posted) {
        _hdrPrefPosted = v;
      } else {
        _hdrPrefDraft = v;
      }
    });
    SharedPreferences.getInstance()
        .then((p) => p.setBool(posted ? 'im_hdr_collapsed_posted' : 'im_hdr_collapsed_draft', v))
        .catchError((_) => false);
  }

  String _salespersonNames(bool isEnglish) => _salespersons
      .map((s) => isEnglish && (s.salespersonNameEng ?? '').isNotEmpty ? s.salespersonNameEng! : s.salespersonNameThai)
      .join(', ');

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
              child: SalespersonSplitEditor(
                items: list,
                isEnglish: isEnglish,
                onChanged: (l) => setD(() => list = l),
              ),
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

  // แถวฟิลด์ในกลุ่ม — flex ตามลำดับ (ไม่ระบุ = 1)
  Widget _hRow(List<Widget> children, [List<int>? flex]) {
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) out.add(const SizedBox(width: 8));
      out.add(Expanded(flex: flex != null && i < flex.length ? flex[i] : 1, child: children[i]));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: out);
  }

  Widget _hGroupLabel(int no, String title, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
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

  // กลุ่มฟิลด์: แถบสีด้านบน + ชื่อกลุ่ม; inline = ชื่อกลุ่มอยู่ซ้ายของแถว (กลุ่มแถวเดียว/เต็มความกว้าง)
  Widget _hGroup(int no, String title, Color color, List<Widget> rows, {bool inline = false}) {
    final body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < rows.length; i++) ...[if (i > 0) const SizedBox(height: 8), rows[i]],
    ]);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFBFCFD),
          border: Border.all(color: const Color(0xFFDDE3EA)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(height: 3, color: color),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: inline
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 108, child: Padding(padding: const EdgeInsets.only(top: 12), child: _hGroupLabel(no, title, color))),
                    Expanded(child: body),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _hGroupLabel(no, title, color),
                    const SizedBox(height: 8),
                    body,
                  ]),
          ),
        ]),
      ),
    );
  }

  Widget _datePickField({required String label, required String text, required VoidCallback? onTap, bool auto = false, Widget? suffixIcon}) =>
      InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: _hDec(label, auto: auto, editable: onTap != null, suffixIcon: suffixIcon),
          child: Text(text),
        ),
      );

  Widget _buildHeaderCard(bool isEnglish) {
    final canEditDocType = !_isReadOnly && _id == null;
    final collapsed = _isHeaderCollapsed;

    // ── ฟิลด์ ──
    final docTypeW = canEditDocType && _docTypes.length > 1
        ? DropdownButtonFormField<int>(
            key: ValueKey('docType$_docTypeFieldSeq'),
            value: _docId,
            isExpanded: true,
            decoration: _hDec(isEnglish ? 'Document Type *' : 'ประเภทเอกสาร *'),
            items: _docTypes
                .map((d) => DropdownMenuItem(
                    value: d.id,
                    child: Text('${d.docCode} ${isEnglish && d.docNameEng.isNotEmpty ? d.docNameEng : d.docNameThai}', overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: _changeDocType,
          )
        : _fkField(
            label: isEnglish ? 'Document Type' : 'ประเภทเอกสาร',
            hasValue: _docCode != null,
            displayText: '${_docCode ?? ''} ${isEnglish && (_docNameEng ?? '').isNotEmpty ? _docNameEng : (_docNameThai ?? '')}',
            editable: false,
          );
    final dateW = _datePickField(
      label: isEnglish ? 'Doc Date *' : 'วันที่เอกสาร *',
      text: _dateFmt.format(_docDate),
      onTap: _isReadOnly ? null : _pickDate,
    );
    final whW = _fkField(
      label: _isTransferMode ? (isEnglish ? 'From Warehouse *' : 'คลังต้นทาง *') : (isEnglish ? 'Warehouse *' : 'คลังสินค้า *'),
      hasValue: _warehouseId != null,
      displayText: _warehouseLabel,
      editable: !_isReadOnly,
      onSearch: _isReadOnly ? null : () => ImWarehouseListWidget.search(context, onSelected: _selectWarehouse),
    );
    final toWhW = !_isTransferMode
        ? null
        : _fkField(
            label: isEnglish ? 'To Warehouse *' : 'คลังปลายทาง *',
            hasValue: _toWarehouseId != null,
            displayText: _toWarehouseLabel,
            editable: !_isReadOnly,
            onSearch: _isReadOnly ? null : () => ImWarehouseListWidget.search(context, onSelected: _selectToWarehouse),
          );
    final refNoW = TextField(
      controller: _refNoCtrl,
      readOnly: !_canEditBilling,
      decoration: _hDec(
        _isCashPurchaseMode
            ? '${isEnglish ? 'Vendor Tax Invoice / Receipt No.' : 'เลขที่ใบกำกับภาษี/ใบเสร็จผู้ขาย'}${_vendorRefRequired ? ' *' : ''}'
            : (_isGrnBillingMode || (_isGrDeferredMode && _status == 'Received'))
                ? (isEnglish ? 'Vendor Invoice No. *' : 'เลขที่ใบกำกับสินค้าผู้ขาย *')
                : _isApCnDnDoc
                    ? '${_isApDnMode ? (isEnglish ? 'Vendor Debit Note No.' : 'เลขที่ใบเพิ่มหนี้ผู้ขาย') : (isEnglish ? 'Vendor Credit Note No.' : 'เลขที่ใบลดหนี้ผู้ขาย')}${_vendorCnDnNoRequired ? ' *' : ''}'
                    : _isDeliverMode
                        ? (isEnglish ? 'Customer Ref. No.' : 'เลขที่อ้างอิงลูกค้า')
                        : (isEnglish ? 'Ref No.' : 'เลขที่อ้างอิง'),
        editable: _canEditBilling,
      ),
    );
    final invDateW = !_showInvoiceDate
        ? null
        : _datePickField(
            label: _isApCnDnDoc
                ? (_isApDnMode
                    ? (isEnglish ? 'Vendor Debit Note Date' : 'วันที่ใบเพิ่มหนี้ผู้ขาย')
                    : (isEnglish ? 'Vendor Credit Note Date' : 'วันที่ใบลดหนี้ผู้ขาย'))
                : (isEnglish ? 'Vendor Invoice Date *' : 'วันที่ใบกำกับ *'),
            text: _dateFmt.format(_invoiceDate),
            onTap: _canEditBilling ? _pickInvoiceDate : null,
          );
    final partyW = _isApVendorMode
        ? _fkField(
            label: _isCashPurchaseMode
                ? (isEnglish ? 'Vendor (blank = cash vendor)' : 'ผู้ขาย (ว่าง = ผู้ขายเงินสด)')
                : (isEnglish ? 'Vendor *' : 'ผู้ขาย *'),
            hasValue: _vendorId != null,
            displayText: _vendorLabel,
            editable: !_isReadOnly,
            onSearch: _isReadOnly ? null : () => ApVendorListWidget.search(context, onSelected: _selectVendor),
          )
        : _isArCustomerMode
            ? _fkField(
                label: _isCashSaleMode
                    ? (isEnglish ? 'Customer (blank = cash customer)' : 'ลูกค้า (ว่าง = ลูกค้าเงินสด)')
                    : (isEnglish ? 'Customer *' : 'ลูกค้า *'),
                hasValue: _customerId != null,
                displayText: _customerLabel,
                editable: !_isReadOnly,
                onSearch: _isReadOnly ? null : () => ArCustomerListWidget.search(context, onSelected: _selectCustomer),
              )
            : null;
    final srcDocW = !_isReturnSourceDocMode
        ? null
        : _fkField(
            label: isEnglish ? 'Source Document *' : 'เอกสารต้นฉบับ *',
            hasValue: _refImTransactionId != null,
            displayText: _refImTransactionLabel,
            editable: !_isReadOnly,
            onSearch: _isReadOnly ? null : _pickReturnSourceDoc,
          );
    Widget orderRef(String label, bool hasValue, String text, bool canAdd, String tip, VoidCallback onAdd) => _fkField(
          label: label,
          hasValue: hasValue,
          displayText: text,
          editable: false,
          trailing: canAdd
              ? IconButton(
                  icon: const Icon(Icons.playlist_add, size: 20, color: Colors.teal),
                  tooltip: tip,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onAdd,
                )
              : null,
        );
    final poRefW = !_isPoReceiveMode
        ? null
        : orderRef(isEnglish ? 'PO Reference' : 'อ้างอิงใบสั่งซื้อ', _refPoId != null, _refPoDocNoLabel ?? '',
            !_isReadOnly && _vendorId != null, isEnglish ? 'Add lines from PO' : 'เพิ่มรายการจากใบสั่งซื้อ', _pickPoLines);
    final soRefW = !_isDeliverMode
        ? null
        : orderRef(isEnglish ? 'SO Reference' : 'อ้างอิงใบสั่งขาย', _refSoId != null, _refSoDocNoLabel ?? '',
            !_isReadOnly && _customerId != null, isEnglish ? 'Add lines from SO' : 'เพิ่มรายการจากใบสั่งขาย', _pickSoLines);
    final custPoNoW = !_isDeliverMode
        ? null
        : TextField(
            controller: _poNoCtrl,
            readOnly: !_canEditBilling,
            maxLength: 50,
            decoration: _hDec(isEnglish ? 'Customer PO No.' : 'เลขที่ PO ลูกค้า', editable: _canEditBilling, counterText: ''),
          );
    final custPoDateW = !_isDeliverMode
        ? null
        : _datePickField(
            label: isEnglish ? 'Customer PO Date' : 'วันที่ PO ลูกค้า',
            text: _poDate != null ? _dateFmt.format(_poDate!) : '-',
            onTap: !_canEditBilling
                ? null
                : () async {
                    final picked = await showDatePicker(context: context, initialDate: _poDate ?? _docDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (picked != null) setState(() => _poDate = picked);
                  },
            suffixIcon: (_poDate == null || !_canEditBilling)
                ? null
                : IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _poDate = null)),
          );
    final hasCurrency = _isApVendorMode || _isArCustomerMode;
    final rateEditable = !_isReadOnly || (_isDlnDeferredMode && _status == 'Delivered' && _canEditBilling && _isForeignCurrency);

    // ── ② ③ มีหรือไม่ ──
    final partyRow1 = <Widget>[if (partyW != null) partyW, if (srcDocW != null) srcDocW, if (poRefW != null) poRefW, if (soRefW != null) soRefW];
    final partyMode = partyRow1.isNotEmpty;
    final finMode = _showCreditTerm || hasCurrency;

    // ── แถบหัวการ์ด ──
    final titleRow = Row(children: [
      Text(isEnglish ? 'Document Header' : 'ข้อมูลเอกสาร', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      if (_docNo.isNotEmpty && _docNo != 'AUTO') ...[
        const SizedBox(width: 10),
        Text(_docNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F5C5C))),
      ],
      const SizedBox(width: 10),
      // ป้ายสถานะชิดซ้าย / วงเงินชิดขวา (spaceBetween) — ปุ่มย่ออยู่ขอบขวาสุดเหมือนการ์ดอื่น
      // (เดิม Flexible+Expanded แบ่งพื้นที่ว่างคนละครึ่ง ส่วนที่ป้ายสถานะไม่ใช้เหลือค้างหลังปุ่ม → ปุ่มอยู่กลางแถว)
      Expanded(
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(child: _statusBadges(isEnglish)),
          const SizedBox(width: 8),
          Flexible(
          // วงเงินเครดิตของลูกค้า: อยู่ในวงเงิน = แถบสั้นบรรทัดเดียว, เกินวงเงิน/มีคำขอ = แผงขอ/อนุมัติเต็ม
          child: _isArCustomerMode && _customerId != null && (_status == 'Draft' || _credit.status != null)
              ? CreditLimitPanel(
                  compact: true,
                  service: _creditService,
                  customerId: _customerId,
                  docId: _id,
                  docNo: _docNo,
                  amount: _creditAmount,
                  credit: _credit,
                  isDraft: _status == 'Draft' && !widget.viewOnly,
                  onChanged: () async {
                    if (_id == null) return;
                    await _loadExisting(_id!);
                    if (mounted) setState(() {});
                  },
                )
              : const SizedBox.shrink(),
          ),
        ]),
      ),
      const SizedBox(width: 8),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 10), foregroundColor: Colors.blueGrey.shade800),
        icon: Icon(collapsed ? Icons.expand_more : Icons.expand_less, size: 18),
        label: Text(collapsed ? (isEnglish ? 'Expand' : 'ขยาย') : (isEnglish ? 'Collapse' : 'ย่อ'), style: const TextStyle(fontSize: 12)),
        onPressed: _toggleHeader,
      ),
    ]);

    Widget body;
    if (collapsed) {
      body = _headerSummary(isEnglish);
    } else {
      // ① เอกสาร
      final g1 = partyMode
          ? _hGroup(1, isEnglish ? 'Document' : 'เอกสาร', _gDoc, [
              docTypeW,
              _hRow([dateW, whW, if (toWhW != null) toWhW]),
            ])
          : _hGroup(1, isEnglish ? 'Document' : 'เอกสาร', _gDoc, [
              _hRow([docTypeW, dateW, whW, if (toWhW != null) toWhW, refNoW, if (invDateW != null) invDateW], [3, 2, 3, if (toWhW != null) 3, 3, if (invDateW != null) 2]),
            ], inline: true);
      // ② คู่ค้า / อ้างอิง
      final g2 = !partyMode
          ? null
          : _hGroup(2, _isApVendorMode ? (isEnglish ? 'Vendor / Reference' : 'ผู้ขาย / อ้างอิง') : (isEnglish ? 'Customer / Reference' : 'ลูกค้า / อ้างอิง'), _gParty, [
              _hRow(partyRow1, partyW != null && partyRow1.length > 1 ? [2, for (var i = 1; i < partyRow1.length; i++) 1] : null),
              _hRow([if (custPoNoW != null) custPoNoW, if (custPoDateW != null) custPoDateW, refNoW, if (invDateW != null) invDateW]),
            ]);
      // ③ เงื่อนไขการเงิน
      final g3 = !finMode
          ? null
          : _hGroup(3, isEnglish ? 'Terms / Currency' : 'เงื่อนไขการเงิน', _gFin, [
              if (_showCreditTerm)
                _hRow([
                  TextField(
                    controller: _creditMonthsCtrl,
                    readOnly: !_canEditBilling,
                    keyboardType: TextInputType.number,
                    decoration: _hDec(isEnglish ? 'Credit (months)' : 'เครดิต (เดือน)', auto: true, editable: _canEditBilling),
                    onChanged: (_) => setState(_recalcDueDate),
                  ),
                  TextField(
                    controller: _creditDaysCtrl,
                    readOnly: !_canEditBilling,
                    keyboardType: TextInputType.number,
                    decoration: _hDec(isEnglish ? 'Credit (days)' : 'เครดิต (วัน)', auto: true, editable: _canEditBilling),
                    onChanged: (_) => setState(_recalcDueDate),
                  ),
                  _datePickField(
                    label: isEnglish ? 'Due Date' : 'วันที่ครบกำหนด',
                    text: _dueDate != null ? _dateFmt.format(_dueDate!) : '-',
                    auto: true,
                    onTap: !_canEditBilling
                        ? null
                        : () async {
                            final picked = await showDatePicker(context: context, initialDate: _dueDate ?? _docDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                            if (picked != null) setState(() => _dueDate = picked);
                          },
                    suffixIcon: _canEditBilling ? const Icon(Icons.calendar_today, size: 16) : null,
                  ),
                ], [2, 2, 3]),
              if (hasCurrency)
                _hRow([
                  DropdownButtonFormField<Currency>(
                    value: _currency,
                    isExpanded: true,
                    decoration: _hDec(isEnglish ? 'Currency' : 'สกุลเงิน', auto: true, editable: !_isReadOnly),
                    items: _currencies
                        .map((c) => DropdownMenuItem(value: c, child: Text('${c.currencyCode} - ${_currencyLabel(c)}', overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: _isReadOnly
                        ? null
                        : (v) {
                            final changed = v?.currencyCode != _currency?.currencyCode;
                            setState(() {
                              _currency = v;
                              _exchangeRate = v?.baseRate ?? 1;
                            });
                            if (changed) _loadAdvances(); // ใบมัดจำที่หักได้ต้องสกุลเงินเดียวกับเอกสาร
                            if (changed) _refreshListPrices(); // ตารางราคาสกุลเงินเดียวกับเอกสาร
                          },
                  ),
                  TextFormField(
                    key: ValueKey('im_rate_${widget.resetKey}_${_id}_${_currency?.currencyCode}'),
                    initialValue: _exchangeRate.toStringAsFixed(6),
                    // '32' สถานะ Delivered: สกุลเงินคงเดิม แก้ได้แค่อัตรา ณ วันออกใบแจ้งหนี้
                    enabled: rateEditable,
                    decoration: _hDec(isEnglish ? 'Exchange Rate' : 'อัตราแลกเปลี่ยน', auto: true, editable: rateEditable),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => setState(() => _exchangeRate = double.tryParse(v) ?? 1),
                  ),
                ], [3, 2]),
            ]);
      // ④ เพิ่มเติม: คำอธิบาย + พนักงานขาย (แก้ใน dialog) + มิติ
      final descW = TextField(
        controller: _descCtrl,
        readOnly: _isReadOnly,
        decoration: _hDec(isEnglish ? 'Description' : 'คำอธิบาย', editable: !_isReadOnly),
      );
      final salesW = !_isArCustomerMode
          ? null
          : InkWell(
              onTap: _canEditBilling ? () => _editSalespersons(isEnglish) : null,
              child: InputDecorator(
                decoration: _hDec(isEnglish ? 'Salespersons' : 'พนักงานขาย',
                    auto: true, editable: _canEditBilling, suffixIcon: _canEditBilling ? const Icon(Icons.edit, size: 16, color: Colors.teal) : null),
                child: Text(_salespersons.isEmpty ? (isEnglish ? '— Not specified —' : '— ไม่ระบุ —') : _salespersonNames(isEnglish),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _salespersons.isEmpty ? Colors.grey.shade600 : null)),
              ),
            );
      final branch = findBranch(_branches, _branchId);
      final branchW = InkWell(
        onTap: _isReadOnly
            ? null
            : () async {
                final r = await showUserBranchPicker(context, branches: _branches, selectedId: _branchId, isEnglish: isEnglish);
                if (r != null && mounted) setState(() => _branchId = r.$2?.id);
              },
        child: InputDecorator(
          decoration: _hDec(isEnglish ? 'Branch' : 'สาขา',
              editable: !_isReadOnly, suffixIcon: _isReadOnly ? null : const Icon(Icons.search, size: 18)),
          child: Text(
            _branchId == null
                ? (isEnglish ? '— Not specified —' : '— ไม่ระบุ —')
                : (branch != null ? branchLabel(branch, isEnglish) : '#$_branchId'),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _branchId == null ? Colors.grey.shade600 : null),
          ),
        ),
      );
      final dimWs = <Widget>[
        branchW,
        for (final t in _dimTypes)
          GlDimensionPickerField(
            dimType: t,
            values: _dimValues[t.typeCode] ?? const [],
            selected: () {
              final id = _dimSelections[t.slotNo];
              for (final v in _dimValues[t.typeCode] ?? const <GlDimensionValue>[]) {
                if (v.id == id) return v;
              }
              return null;
            }(),
            readOnly: _isReadOnly || _refDims != null,
            onSelected: (v) => setState(() => _dimSelections[t.slotNo] = v?.id),
          ),
      ];
      final moreFirst = <Widget>[descW, if (salesW != null) salesW];
      final moreFlex = <int>[if (salesW != null) 5 else 6, if (salesW != null) 4];
      final g4 = _hGroup(4, isEnglish ? 'More' : 'เพิ่มเติม', _gMore, [
        if (dimWs.length <= 2)
          _hRow([...moreFirst, ...dimWs], [...moreFlex, for (final _ in dimWs) 3])
        else ...[
          _hRow(moreFirst, moreFlex),
          _hRow(dimWs),
        ],
        if (_refDims != null)
          Text(isEnglish ? 'Dimensions follow the referenced order' : 'มิติตามเอกสารต้นทางที่อ้างอิง (แก้ไขไม่ได้)',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600, fontStyle: FontStyle.italic)),
        if (_glDimMissingSlots.isNotEmpty)
          Text(
              '${isEnglish ? 'Required by the posting accounts:' : 'บัญชีที่ลงรายการบังคับระบุ:'} '
              '${[
                if (_glDimMissingSlots.contains(0)) isEnglish ? 'Branch' : 'สาขา',
                ..._dimTypes.where((t) => _glDimMissingSlots.contains(t.slotNo)).map((t) => _dimTypeName(t, isEnglish)),
              ].join(', ')}',
              style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
      ], inline: true);

      final top = <Widget>[g1, if (g2 != null) g2, if (g3 != null) g3];
      final topFlex = <int>[30, if (g2 != null) (g3 != null ? 46 : 70), if (g3 != null) (g2 != null ? 34 : 70)];
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LayoutBuilder(builder: (ctx, c) {
          if (top.length == 1) return top.first;
          if (c.maxWidth < 1000) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 0; i < top.length; i++) ...[if (i > 0) const SizedBox(height: 10), top[i]],
            ]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < top.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(flex: topFlex[i], child: top[i]),
              ],
            ]);
        }),
        const SizedBox(height: 10),
        g4,
      ]);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          titleRow,
          const SizedBox(height: 10),
          body,
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
    final party = _isApVendorMode ? _vendorLabel : _isArCustomerMode ? _customerLabel : null;
    final refNo = _refNoCtrl.text.trim();
    final terms = <String>[
      if ((_creditMonths ?? 0) > 0) isEnglish ? '$_creditMonths mo' : '$_creditMonths เดือน',
      if ((_creditDays ?? 0) > 0) isEnglish ? '$_creditDays d' : '$_creditDays วัน',
    ].join(' ');
    final desc = _descCtrl.text.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFF6F8FA), borderRadius: BorderRadius.circular(4)),
      child: Wrap(spacing: 22, runSpacing: 6, children: [
        item(_gDoc, isEnglish ? 'Date' : 'วันที่', _dateFmt.format(_docDate)),
        if (_warehouseId != null) item(_gDoc, _isTransferMode ? (isEnglish ? 'From' : 'จากคลัง') : (isEnglish ? 'Warehouse' : 'คลัง'), _warehouseLabel ?? ''),
        if (_isTransferMode && _toWarehouseId != null) item(_gDoc, isEnglish ? 'To' : 'ไปคลัง', _toWarehouseLabel ?? ''),
        if (party != null && party.isNotEmpty) item(_gParty, _isApVendorMode ? (isEnglish ? 'Vendor' : 'ผู้ขาย') : (isEnglish ? 'Customer' : 'ลูกค้า'), party),
        if (_isReturnSourceDocMode && _refImTransactionId != null) item(_gParty, isEnglish ? 'Source' : 'ต้นฉบับ', _refImTransactionLabel ?? ''),
        if (_isPoReceiveMode && (_refPoDocNoLabel ?? '').isNotEmpty) item(_gParty, 'PO', _refPoDocNoLabel!),
        if (_isDeliverMode && (_refSoDocNoLabel ?? '').isNotEmpty) item(_gParty, 'SO', _refSoDocNoLabel!),
        if (refNo.isNotEmpty) item(_gParty, isEnglish ? 'Ref' : 'อ้างอิง', refNo),
        if (_showCreditTerm && (terms.isNotEmpty || _dueDate != null))
          item(_gFin, isEnglish ? 'Credit' : 'เครดิต',
              [if (terms.isNotEmpty) terms, if (_dueDate != null) '${isEnglish ? 'due' : 'ครบ'} ${_dateFmt.format(_dueDate!)}'].join(' · ')),
        if ((_isApVendorMode || _isArCustomerMode) && _currency != null)
          item(_gFin, isEnglish ? 'Currency' : 'สกุลเงิน',
              _isForeignCurrency ? '${_currency!.currencyCode} @ ${_exchangeRate.toStringAsFixed(4)}' : _currency!.currencyCode),
        if (_isArCustomerMode && _salespersons.isNotEmpty) item(_gMore, isEnglish ? 'Salespersons' : 'พนักงานขาย', _salespersonNames(isEnglish)),
        if (desc.isNotEmpty) item(_gMore, isEnglish ? 'Description' : 'คำอธิบาย', desc),
      ]),
    );
  }

  // ป้ายสถานะ + ใบตั้งหนี้/ใบแจ้งหนี้ที่สร้างแล้ว — แสดงต่อท้ายหัวข้อ "ข้อมูลเอกสาร"
  Widget _statusBadges(bool isEnglish) {
    Widget chip(String text, Color color, {double fontSize = 14, double bg = 0.12}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(color: color.withOpacity(bg), borderRadius: BorderRadius.circular(12)),
          child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: fontSize)),
        );
    return Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
      chip(_status, _statusColor(_status), fontSize: 13, bg: 0.15),
      if (_linkedApTransactionId != null)
        chip(isEnglish ? 'AP bill created (#$_linkedApTransactionId)' : 'สร้างใบตั้งหนี้ AP แล้ว (#$_linkedApTransactionId)', Colors.blue, fontSize: 12),
      if (_linkedArTransactionId != null)
        chip(isEnglish ? 'AR invoice created (#$_linkedArTransactionId)' : 'สร้างใบแจ้งหนี้ AR แล้ว (#$_linkedArTransactionId)', Colors.blue, fontSize: 12),
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

  // ── ② รายการสินค้า: ตาราง 1 บรรทัดต่อรายการ + ปุ่มขยายรายละเอียด ④ ทีละรายการ ──
  // คอลัมน์ขึ้นกับประเภทเอกสาร (ทั้งเอกสาร) — บรรทัดที่ไม่มีค่าในคอลัมน์นั้นเว้นว่าง ให้หัวตารางตรงกันทุกบรรทัด
  final Set<_CountLine> _expandedLines = {};
  final _lineHScroll = ScrollController(); // ตารางกว้างกว่าจอ: เลื่อนซ้าย-ขวาด้วยแถบเลื่อนที่เห็นตลอด

  bool _canEditUnitCost(_CountLine line) {
    final isApCreditPrice = line.isApReturnCnMode || line.isApDnMode;
    final isPurchasePrice = _isPoReceiveMode && line.item.costingMethod == 'STANDARD';
    return isApCreditPrice || isPurchasePrice || (line.variance > 0 && line.item.costingMethod != 'STANDARD');
  }

  bool _lineShortage(_CountLine l) =>
      !_isReadOnly && l.isDeltaMode && !l.isIncreaseMode && !l.isNonStock && l.counted < -0.00005;

  List<String> _lineErrors(_CountLine l, bool isEnglish) => [
        if (_lineShortage(l))
          isEnglish
              ? 'Not enough stock (on hand ${_fmtQty.format(l.systemQty)}, need ${_fmtQty.format(l.systemQty - l.counted)})'
              : 'ยอดคงเหลือไม่พอ (คงเหลือ ${_fmtQty.format(l.systemQty)} ต้องการ ${_fmtQty.format(l.systemQty - l.counted)})',
        if (_salesDiscountMode && !parseStepDiscount(l.discPctCtrl.text).valid)
          isEnglish ? 'Disc. % is invalid (e.g. 10+5+2)' : 'ส่วนลด % ไม่ถูกต้อง (เช่น 10+5+2)',
        if (_lineDiscNegative(l)) isEnglish ? 'Disc. amount cannot be negative' : 'ส่วนลด (เงิน) ติดลบไม่ได้',
        if (_netTooHigh(l))
          isEnglish ? 'Net price is above the price after disc. %' : 'ราคาสุทธิ/หน่วยสูงกว่าราคาหลังหักส่วนลด %',
      ];

  void _onPriceInclVatChanged(bool? v) => setState(() {
        final incl = v ?? false;
        if (incl != _priceIncludesVat) {
          for (final l in _lines.where((l) => l.refSoDetailId != null && l.vatType != null && l.vatType != 'NOVAT' && l.vatRate > 0)) {
            final p = _parseNum(l.unitPriceCtrl.text);
            if (p != 0) l.unitPriceCtrl.text = _CountLine._fmtInput(incl ? p * (100 + l.vatRate) / 100 : p * 100 / (100 + l.vatRate));
          }
        }
        _priceIncludesVat = incl;
        _refreshListPrices(); // ราคาจากตารางราคา: แปลงรวม/ไม่รวม VAT ใหม่ (backend)
      });

  Widget _buildDetailCard(bool isEnglish) {
    final shortage = _lines.where(_lineShortage).length;
    final allExpanded = _lines.isNotEmpty && _expandedLines.length >= _lines.length;
    final addBtn = _isReadOnly
        ? null
        : OutlinedButton.icon(
            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, foregroundColor: const Color(0xFF0F5C5C)),
            onPressed: _isReturnSourceDocMode ? _pickReturnLines : _addLine,
            icon: const Icon(Icons.add, size: 18),
            label: Text(_isReturnSourceDocMode
                ? (isEnglish ? 'Add Return Lines' : 'เพิ่มรายการคืนสินค้า')
                : (isEnglish ? 'Add Item' : 'เพิ่มสินค้า')),
          );
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
      chips: [
        _chip(isEnglish ? '${_lines.length} line(s)' : '${_lines.length} รายการ', const Color(0xFF33404D), _hRo),
        if (shortage > 0)
          _chip(isEnglish ? 'Not enough stock: $shortage' : 'ยอดคงเหลือไม่พอ $shortage รายการ', const Color(0xFF9B1C14), const Color(0xFFFDE8E6)),
      ],
      actions: [
        if (_isVatMode)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Checkbox(
              value: _priceIncludesVat,
              visualDensity: VisualDensity.compact,
              onChanged: _canEditPriceInclVat ? _onPriceInclVatChanged : null,
            ),
            Text(isEnglish ? 'Prices include VAT' : 'ราคารวม VAT', style: const TextStyle(fontSize: 12)),
          ]),
        if (_lines.isNotEmpty)
          OutlinedButton(
            style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 10), foregroundColor: Colors.blueGrey.shade800),
            onPressed: () => setState(() {
              if (allExpanded) {
                _expandedLines.clear();
              } else {
                _expandedLines.addAll(_lines);
              }
            }),
            child: Text(allExpanded ? (isEnglish ? 'Collapse all' : 'ย่อทุกรายการ') : (isEnglish ? 'Expand all' : 'ขยายทุกรายการ'),
                style: const TextStyle(fontSize: 12)),
          ),
        if (addBtn != null) addBtn,
      ],
      children: [
        if (_lines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(isEnglish ? 'No lines yet' : 'ยังไม่มีรายการ', style: TextStyle(color: Colors.grey.shade600)),
          )
        else
          _lineTable(isEnglish),
        if (addBtn != null && _lines.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: addBtn),
      ],
    );
  }

  List<_LCol> _lineCols(bool isEnglish) {
    final s = _lines.first;
    final anyStock = _lines.any((l) => !l.isNonStock);
    final anyLot = _lines.any((l) => l.item.isLotTracked && !l.isNonStock);
    final anySerial = _lines.any((l) => (l.item.isSerialTracked || l.item.costingMethod == 'SPECIFIC') && !l.isNonStock);
    final showCost = !_isArCustomerMode || _lines.any(_canEditUnitCost);
    final cur = _currency?.currencyCode;
    final qtyLabel = s.isTransferMode
        ? (isEnglish ? 'Transfer Qty' : 'จำนวนที่โอน')
        : s.isReceiveMode
            ? (isEnglish ? 'Receive Qty' : 'จำนวนที่รับ')
            : s.isIssueMode
                ? (isEnglish ? 'Issue Qty' : 'จำนวนที่เบิก')
                : s.isDeliverMode
                    ? (isEnglish ? 'Delivery Qty' : 'จำนวนที่ส่ง')
                    : (s.isApReturnCnMode || s.isArDnMode || s.isApDnMode || s.isArReturnCnMode)
                        ? (isEnglish ? 'Qty' : 'จำนวน')
                        : (isEnglish ? 'Counted Qty' : 'ยอดนับได้');
    final afterLabel = s.isTransferMode
        ? (isEnglish ? 'Balance After' : 'คงเหลือหลังโอน')
        : s.isReceiveMode
            ? (isEnglish ? 'Balance After' : 'คงเหลือหลังรับ')
            : s.isIssueMode
                ? (isEnglish ? 'Balance After' : 'คงเหลือหลังเบิก')
                : s.isDeliverMode
                    ? (isEnglish ? 'Balance After' : 'คงเหลือหลังส่ง')
                    : s.isDeltaMode
                        ? (isEnglish ? 'Balance After' : 'คงเหลือหลังทำรายการ')
                        : (isEnglish ? 'Variance' : 'ผลต่าง');
    final costLabel = (_isApReturnCnMode || _isApDnMode)
        ? (isEnglish ? 'Unit Price' : 'ราคา/หน่วย')
        : _isPoReceiveMode
            ? (isEnglish ? 'Purchase Price' : 'ราคาซื้อ/หน่วย')
            : (isEnglish ? 'Unit Cost' : 'ต้นทุน/หน่วย');
    return [
      const _LCol('no', '#', 28, 1),
      _LCol('item', isEnglish ? 'Item' : 'สินค้า', 0, 1),
      if (anyStock) _LCol('loc', isEnglish ? 'Location' : 'ตำแหน่งจัดเก็บ', 100, 1),
      if (_isTransferMode) _LCol('toLoc', isEnglish ? 'To Location' : 'ตำแหน่งปลายทาง', 100, 1),
      if (anyLot) _LCol('lot', isEnglish ? 'Lot No.' : 'ล็อต', 96, 1),
      if (anySerial) const _LCol('serial', 'Serial No.', 110, 1),
      if (anyStock) _LCol('sys', isEnglish ? 'System Qty' : 'ยอดระบบ', 72, 2, right: true),
      _LCol('qty', qtyLabel, 80, 2, right: true, required: true),
      if (_lines.any((l) => l.isDeltaMode)) _LCol('uom', isEnglish ? 'Unit' : 'หน่วย', 76, 2),
      if (anyStock) _LCol('after', afterLabel, 80, 2, right: true),
      if ((_isReceiveMode && !_isConsignmentReceiveMode) || _isDeliverMode) _LCol('free', isEnglish ? 'Free' : 'ของแถม', 46, 2),
      if (showCost)
        _LCol('cost', costLabel + (_isApVendorMode && cur != null ? ' ($cur)' : ''), 100, 3, right: true, required: _lines.any(_canEditUnitCost)),
      if (_isGrDeferredMode && (_status == 'Received' || _status == 'Posted'))
        _LCol('billed', (isEnglish ? 'Billed Cost' : 'ต้นทุนตามใบกำกับ') + (_currency != null && !_currency!.baseCurrencyFlag ? ' ($cur)' : ''), 120, 3,
            right: true),
      if (_isDlnBillingMode || _isDlnDeferredMode || _isArReturnCnMode || _isArDnMode)
        _LCol('price', (isEnglish ? 'Unit Price' : 'ราคาขาย/หน่วย') + (_isForeignCurrency ? ' ($cur)' : ''), 100, 3, right: true),
      if (_isVatMode) const _LCol('vat', 'VAT', 100, 3, required: true),
      if (_showDiscount) _LCol('disc', isEnglish ? 'Disc. %' : 'ส่วนลด %', _salesDiscountMode ? 78 : 68, 3),
      if (_salesDiscountMode)
        _LCol('net', (isEnglish ? 'Net price/unit' : 'ราคาสุทธิ/หน่วย') + (_inclVat ? (isEnglish ? ' incl. VAT' : ' รวม VAT') : ''), 104, 3, right: true),
      if (_salesDiscountMode || _showDiscount)
        _LCol('amount', _salesDiscountMode ? (isEnglish ? 'Amount' : 'จำนวนเงิน') : (isEnglish ? 'Before VAT' : 'ยอดก่อน VAT'), 104, 3, right: true),
      if (_isIssueMode) _LCol('acct', isEnglish ? 'Expense Account' : 'บัญชีค่าใช้จ่าย', 200, 4),
      if (_isIssueMode && _dimTypes.isNotEmpty) _LCol('dims', isEnglish ? 'Dimensions' : 'มิติ', 150, 4),
      const _LCol('act', '', 62, 0),
    ];
  }

  static const double _lGap = 6;

  Widget _lineTable(bool isEnglish) {
    final cols = _lineCols(isEnglish);
    final sd = _salesDiscountMode ? _salesDiscounts() : null;
    final fixed = cols.fold<double>(0, (t, c) => t + c.width) + _lGap * (cols.length - 1);
    return LayoutBuilder(builder: (context, cons) {
      final itemW = cons.maxWidth - fixed > 180 ? cons.maxWidth - fixed : 180.0;
      final tableW = fixed + itemW;
      double w(_LCol c) => c.width == 0 ? itemW : c.width;
      Widget cells(List<Widget> ws) => Row(children: [
            for (var i = 0; i < cols.length; i++) ...[
              if (i > 0) const SizedBox(width: _lGap),
              SizedBox(width: w(cols[i]), child: ws[i]),
            ],
          ]);
      // แถบสีกลุ่มเหนือหัวคอลัมน์ — สีเดียวกับกลุ่มของการ์ดข้อมูลเอกสาร
      final groupRow = <Widget>[];
      var i = 0;
      while (i < cols.length) {
        var j = i;
        var span = w(cols[i]);
        while (j + 1 < cols.length && cols[j + 1].group == cols[i].group) {
          j++;
          span += _lGap + w(cols[j]);
        }
        if (i > 0) groupRow.add(const SizedBox(width: _lGap));
        final g = cols[i].group;
        groupRow.add(SizedBox(
          width: span,
          child: g == 0
              ? null
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(height: 3, decoration: BoxDecoration(color: _lineGroupColor(g), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 3),
                  _hGroupLabel(g, _lineGroupTitle(g, isEnglish), _lineGroupColor(g)),
                ]),
        ));
        i = j + 1;
      }
      const hdStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4A5562));
      final table = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: groupRow),
        Container(
          padding: const EdgeInsets.only(top: 6, bottom: 6),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFDDE3EA)))),
          child: cells([
            for (final c in cols)
              Tooltip(
                message: c.label,
                child: Text.rich(
                  TextSpan(text: c.label, children: [
                    if (c.required) const TextSpan(text: ' *', style: TextStyle(color: Color(0xFFC62828))),
                  ]),
                  style: hdStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: c.right ? TextAlign.right : TextAlign.left,
                ),
              ),
          ]),
        ),
        for (var n = 0; n < _lines.length; n++) _lineRow(_lines[n], n + 1, cols, cells, sd, isEnglish),
      ]);
      if (tableW <= cons.maxWidth + 0.5) return table;
      return Scrollbar(
        controller: _lineHScroll,
        thumbVisibility: true,
        trackVisibility: true,
        child: SingleChildScrollView(
          controller: _lineHScroll,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 14),
          child: SizedBox(width: tableW, child: table),
        ),
      );
    });
  }

  Color _lineGroupColor(int g) => g == 1 ? _gDoc : g == 2 ? _gParty : g == 3 ? _gFin : _gMore;

  String _lineGroupTitle(int g, bool isEnglish) {
    switch (g) {
      case 1:
        return isEnglish ? 'Item / Location' : 'สินค้า / ที่เก็บ';
      case 2:
        return isEnglish ? 'Quantity' : 'จำนวน';
      case 3:
        return (_showDiscount || _isDlnBillingMode || _isDlnDeferredMode || _isArReturnCnMode || _isArDnMode)
            ? (isEnglish ? 'Price / Discount' : 'ราคา / ส่วนลด')
            : (isEnglish ? 'Cost' : 'ต้นทุน');
      default:
        return isEnglish ? 'Account' : 'บัญชี';
    }
  }

  Widget _lineRow(_CountLine line, int lineNo, List<_LCol> cols, Widget Function(List<Widget>) cells,
      Map<_CountLine, SalesLineDiscount>? sd, bool isEnglish) {
    final errs = _lineErrors(line, isEnglish);
    final expanded = _expandedLines.contains(line);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: errs.isNotEmpty ? const Color(0xFFFFF8F7) : null,
        border: const Border(bottom: BorderSide(color: Color(0xFFEEF1F4))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        cells([for (final c in cols) _lineCell(c.key, line, lineNo, sd, isEnglish)]),
        if (errs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 4),
            child: Text(errs.join(' · '), style: const TextStyle(fontSize: 12, color: Color(0xFF9B1C14))),
          ),
        if (expanded) Padding(padding: const EdgeInsets.only(left: 34, top: 6), child: _lineMore(line, sd, isEnglish)),
      ]),
    );
  }

  static const _numStyle = TextStyle(fontSize: 13, fontFeatures: [FontFeature.tabularFigures()]);
  static const _errRed = Color(0xFFC62828);

  Color? _inFill(bool ro, {bool auto = false}) => ro ? _hRo : (auto ? _hAuto : null);

  InputDecoration _cDec({Color? fill, bool err = false, String? hint, Widget? suffix}) => InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
        border: const OutlineInputBorder(),
        enabledBorder: err ? const OutlineInputBorder(borderSide: BorderSide(color: _errRed, width: 1.4)) : null,
        filled: fill != null,
        fillColor: fill,
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        suffixIcon: suffix,
        suffixIconConstraints: const BoxConstraints(minWidth: 22, minHeight: 18),
      );

  // ช่องแสดงค่า (อ่านอย่างเดียว / คำนวณ) ขนาดเท่าช่องกรอก
  Widget _cBox(String text, {Color? fill, bool right = true, bool bold = false, Color? color, bool err = false, String? tip}) {
    final borderColor = err
        ? _errRed
        : fill == _hRo
            ? const Color(0xFFC3C9D0)
            : fill == _hAuto
                ? const Color(0xFF8FB0D6)
                : Colors.grey.shade500;
    final box = Container(
      height: 36,
      alignment: right ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: err ? const Color(0xFFFDECEA) : (fill ?? Colors.white),
        border: Border.all(color: borderColor, width: err ? 1.4 : 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _numStyle.copyWith(
              fontWeight: bold || err ? FontWeight.bold : FontWeight.normal,
              color: err ? const Color(0xFF9B1C14) : (color ?? (fill == _hRo ? const Color(0xFF4A5562) : Colors.black87)))),
    );
    return tip == null ? box : Tooltip(message: tip, child: box);
  }

  // ── หน่วยนับหลายหน่วย ──────────────────────────────────────────────────────────────────────────────────────
  // งานของประเภทเอกสาร — หน่วยที่สินค้าอนุญาตให้ใช้ (null = เบิก/โอน ใช้ได้ทุกหน่วยที่เปิดใช้งาน)
  String? get _uomPurpose {
    const purchase = ['10', '11', '12', '13', '14', '15', '20', '25'];
    const sales = ['30', '31', '32', '33', '35', '40', '45'];
    final t = _selectedSysDocType;
    if (purchase.contains(t)) return 'PURCHASE';
    if (sales.contains(t)) return 'SALES';
    if (t == '90' || t == '95') return 'PRODUCTION';
    return null;
  }

  Future<void> _loadLineUoms(_CountLine l, {bool applyDefault = false}) async {
    final id = l.item.id;
    if (id == null || !l.isDeltaMode) return;
    try {
      final u = await _itemService.fetchItemUoms(id, purpose: _uomPurpose);
      if (!mounted || !_lines.contains(l)) return;
      l.uoms = u;
      final def = u.byId(u.defaultUomId);
      if (applyDefault && !l.uomLocked && def != null && def.uomId != l.uomId) {
        _setLineUom(l, def, scalePrices: false);
      } else {
        // หน่วยที่บันทึกไว้แต่ไม่อยู่ในรายการแล้ว (ปิดใช้งาน/ไม่อนุญาต) — คงอัตราเดิมไว้ backend แจ้งเตือนตอนบันทึก
        final cur = u.byId(l.uomId);
        if (cur != null && l.uomCode == null) l.uomCode = cur.uomCode;
        setState(() {});
      }
    } catch (_) {}
  }

  // เปลี่ยนหน่วยของบรรทัด — ราคาที่กรอกไว้คูณตามอัตราใหม่ (ราคาต่อหน่วยหลักคงเดิม) แล้วดึงราคาตามตารางราคาใหม่
  void _setLineUom(_CountLine l, ImItemUomOption opt, {bool scalePrices = true}) {
    final ratio = l.factor == 0 ? 1.0 : opt.factor / l.factor;
    setState(() {
      if (scalePrices && ratio != 1) {
        for (final c in [l.unitCostCtrl, l.billedUnitCostCtrl, l.unitPriceCtrl, l.netPriceCtrl]) {
          if (c.text.trim().isEmpty) continue;
          c.text = _CountLine._fmtInput((_parseNum(c.text) * ratio * 1e6).roundToDouble() / 1e6);
        }
      }
      l.uomId = opt.uomId;
      l.uomCode = opt.uomCode;
      l.uomNameTh = opt.uomNameTh;
      l.uomNameEn = opt.uomNameEn;
      l.factor = opt.factor;
    });
    if (!scalePrices) return; // ตั้งหน่วยเริ่มต้นตอนเพิ่มรายการ — ผู้เรียกดึงราคาต่อเอง
    if (_isSalesPriceMode) {
      _refreshListPrices([l]);
    } else if (l.purchasePriceAuto != null) {
      _maybeResolveDirectLinePrice(l); // ราคาที่ระบบเติม (ตารางราคา/ราคาซื้อล่าสุด) — ดึงใหม่ตามหน่วยใหม่
    }
  }

  // ชื่อหน่วยไทย/อังกฤษ (ไม่มีชื่อ = แสดงรหัส)
  String _nameOr(String? th, String? en, String? code) {
    final n = _isEnglish && (en ?? '').isNotEmpty ? en! : (th ?? '');
    return n.isNotEmpty ? n : (code ?? '');
  }

  String _baseUomName(_CountLine line) =>
      _nameOr(line.item.baseUomNameTh, line.item.baseUomNameEn, line.item.baseUomCode);

  String _lineUomName(_CountLine line) {
    final o = line.uoms?.byId(line.uomId);
    if (o != null) return o.displayName(_isEnglish);
    if (line.uomId == null || line.uomId == line.item.baseUomId) return _baseUomName(line);
    return _nameOr(line.uomNameTh, line.uomNameEn, line.uomCode);
  }

  Widget _uomCell(_CountLine line, Widget empty) {
    if (!line.isDeltaMode) return empty;
    final base = _baseUomName(line);
    final cur = _lineUomName(line);
    final tip = line.factor != 1 ? '1 $cur = ${_fmtQty.format(line.factor)} $base' : null;
    final opts = line.uoms?.units ?? const <ImItemUomOption>[];
    final canPick = !_isReadOnly && !line.uomLocked && opts.length > 1;
    if (!canPick) {
      return _cBox(cur, fill: _hRo, right: false, tip: tip);
    }
    final box = Container(
      height: 36,
      padding: const EdgeInsets.only(left: 7, right: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade500),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          isDense: true,
          value: opts.any((u) => u.uomId == line.uomId) ? line.uomId : null,
          hint: Text(cur, style: const TextStyle(fontSize: 13)),
          iconSize: 18,
          // style ต้องต่อจากธีม — TextStyle เปล่าไม่มี fontFamily ทำให้ไม่ใช้ฟอนต์ที่ตั้งไว้ในข้อมูลบริษัท
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13, color: Colors.black87),
          // ช่องที่เลือกแล้วแสดงชื่อหน่วยอย่างเดียว รายการในเมนูแสดงอัตราแปลงต่อหน่วยหลักด้วย
          selectedItemBuilder: (_) => [
            for (final u in opts)
              Align(alignment: Alignment.centerLeft, child: Text(u.displayName(_isEnglish), overflow: TextOverflow.ellipsis)),
          ],
          items: [
            for (final u in opts)
              DropdownMenuItem(
                value: u.uomId,
                child: Text(u.isBase ? u.displayName(_isEnglish) : '${u.displayName(_isEnglish)} (= ${_fmtQty.format(u.factor)} $base)', overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) {
            final o = line.uoms?.byId(v);
            if (o != null && o.uomId != line.uomId) _setLineUom(line, o);
          },
        ),
      ),
    );
    return tip == null ? box : Tooltip(message: tip, child: box);
  }

  Widget _cPick(String? text, VoidCallback? onTap) => InkWell(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.only(left: 7, right: 4),
          decoration: BoxDecoration(
            color: onTap == null ? _hRo : Colors.white,
            border: Border.all(color: onTap == null ? const Color(0xFFC3C9D0) : Colors.grey.shade500),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(children: [
            Expanded(
              child: Text((text ?? '').isEmpty ? '—' : text!,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: (text ?? '').isEmpty ? Colors.grey.shade500 : Colors.black87)),
            ),
            if (onTap != null) const Icon(Icons.search, size: 16, color: Color(0xFF0F6E6E)),
          ]),
        ),
      );

  Widget _cField(TextEditingController c,
      {bool ro = false,
      bool auto = false,
      bool err = false,
      bool numeric = true,
      bool bold = false,
      String? hint,
      Widget? suffix,
      ValueChanged<String>? onChanged}) =>
      TextField(
        controller: c,
        readOnly: ro,
        textAlign: numeric ? TextAlign.right : TextAlign.left,
        keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : null,
        style: _numStyle.copyWith(fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: ro ? const Color(0xFF4A5562) : Colors.black87),
        decoration: _cDec(fill: _inFill(ro, auto: auto), err: err, hint: hint, suffix: suffix),
        onChanged: onChanged,
      );

  Widget _lineCell(String key, _CountLine line, int lineNo, Map<_CountLine, SalesLineDiscount>? sd, bool isEnglish) {
    const empty = SizedBox.shrink();
    switch (key) {
      case 'no':
        return Text('$lineNo.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade700));
      case 'item':
        final name = isEnglish && (line.item.itemNameEn ?? '').isNotEmpty ? line.item.itemNameEn! : line.item.itemNameTh;
        Widget tag(String t, Color fg, Color bg) => Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
              child: Text(t, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: fg)),
            );
        return Tooltip(
          message: '${line.item.itemCode} — $name',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Flexible(child: Text(line.item.itemCode, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
              if (line.isNonStock) tag(isEnglish ? 'Service' : 'บริการ', Colors.indigo.shade700, Colors.indigo.shade50),
              if (line.isFree) tag(isEnglish ? 'Free' : 'ของแถม', const Color(0xFF1E6B3A), const Color(0xFFE6F4EA)),
            ]),
            Text(line.isNonStock ? name : '$name · ${line.item.costingMethod}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade700)),
          ]),
        );
      case 'loc':
        if (line.isNonStock) {
          return Text(isEnglish ? 'Non-stock' : 'ไม่นับสต็อก', style: TextStyle(fontSize: 12, color: Colors.grey.shade500));
        }
        return _cPick(
          line.locationCode,
          _isReadOnly || _warehouseId == null
              ? null
              : () => ImLocationTreeWidget.search(context, warehouseId: _warehouseId!, onSelected: (ImLocation loc) {
                    setState(() {
                      line.locationId = loc.id;
                      line.locationCode = loc.locationCode;
                    });
                    _refreshSystemQty(line);
                  }),
        );
      case 'toLoc':
        if (!line.isTransferMode || line.isNonStock) return empty;
        return _cPick(
          line.toLocationCode,
          _isReadOnly || _toWarehouseId == null
              ? null
              : () => ImLocationTreeWidget.search(context, warehouseId: _toWarehouseId!, onSelected: (ImLocation loc) {
                    setState(() {
                      line.toLocationId = loc.id;
                      line.toLocationCode = loc.locationCode;
                    });
                  }),
        );
      case 'lot':
        if (!line.item.isLotTracked || line.isNonStock) return empty;
        return _cField(line.lotNoCtrl, ro: _isReadOnly, numeric: false, onChanged: (_) => _refreshSystemQty(line));
      case 'serial':
        if (!(line.item.isSerialTracked || line.item.costingMethod == 'SPECIFIC') || line.isNonStock) return empty;
        return _cField(line.serialNoCtrl, ro: _isReadOnly, numeric: false, onChanged: (_) => _refreshSystemQty(line));
      case 'sys':
        if (line.isNonStock) return empty;
        if (line.loadingSystemQty) {
          return const Align(
              alignment: Alignment.centerRight, child: SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2)));
        }
        return _cBox(_fmtQty.format(line.systemQty), fill: _hRo);
      case 'qty':
        return _cField(
          line.isDeltaMode ? line.issueQtyCtrl : line.countedQtyCtrl,
          ro: _isReadOnly,
          err: _lineShortage(line),
          onChanged: (_) {
            setState(() {});
            if (_isSalesPriceMode) _refreshListPrices([line]); // ราคาตามขั้นจำนวน
          },
        );
      case 'uom':
        return _uomCell(line, empty);
      case 'after':
        if (line.isNonStock) return empty;
        final variance = line.variance;
        final varianceColor = variance > 0 ? Colors.green.shade700 : (variance < 0 ? Colors.red.shade700 : Colors.black87);
        return _cBox(_fmtQty.format(line.isDeltaMode ? line.counted : variance),
            fill: _hRo, bold: true, color: line.isDeltaMode ? Colors.black87 : varianceColor, err: _lineShortage(line),
            // ยอดระบบ/คงเหลือเป็นหน่วยหลักเสมอ
            tip: line.factor != 1 ? '${_baseUomName(line)} (${_isEnglish ? 'base unit' : 'หน่วยหลัก'})' : null);
      case 'free':
        if (!((line.isReceiveMode && !_isConsignmentReceiveMode) || line.isDeliverMode)) return empty;
        return Center(
          child: Checkbox(
            value: line.isFree,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: _isReadOnly
                ? null
                : (v) => setState(() {
                      line.isFree = v ?? false;
                      if (line.isFree && line.isDeliverMode) line.unitPriceCtrl.clear();
                      if (!line.isFree && _isSalesPriceMode) _refreshListPrices([line]);
                    }),
          ),
        );
      case 'cost':
        final canEdit = _canEditUnitCost(line);
        if (!(canEdit || !_isArCustomerMode)) return empty;
        if (canEdit) {
          return _cField(line.unitCostCtrl, ro: _isReadOnly, suffix: _purchasePriceIcon(line), onChanged: (_) => setState(() {}));
        }
        return _cBox(
          line.item.costingMethod == 'STANDARD' ? _fmtMoney.format(line.item.standardCost) : (isEnglish ? '(at Post)' : '(ตอน Post)'),
          fill: _hRo,
          tip: line.item.costingMethod == 'STANDARD'
              ? (isEnglish ? 'Standard cost' : 'ต้นทุนมาตรฐาน')
              : (isEnglish ? 'Calculated at Post' : 'คำนวณตอน Post'),
        );
      case 'billed':
        return Tooltip(
          message: isEnglish ? 'Blank = same as Unit Cost' : 'เว้นว่าง = เท่ากับต้นทุน/หน่วย',
          child: _cField(line.billedUnitCostCtrl, ro: !_canEditBilling, hint: isEnglish ? '= cost' : '= ต้นทุน', onChanged: (_) => setState(() {})),
        );
      case 'price':
        final ro = !_canEditBilling || line.isFree || _priceLocked(line);
        return _cField(
          line.unitPriceCtrl,
          ro: ro,
          auto: _priceFromSource(line),
          suffix: _priceSourceIcon(line, isEnglish),
          onChanged: (_) => setState(() {
            if (_priceFromSource(line)) line.priceOverridden = true; // ผู้ดูแลระบบแก้ราคาเอง
          }),
        );
      case 'vat':
        return DropdownButtonFormField<String>(
          value: line.vatType != null && _vatRates.any((v) => v.vatCode == line.vatType) ? line.vatType : null,
          isExpanded: true,
          isDense: true,
          decoration: _cDec(fill: _isReadOnly ? _hRo : null, err: line.vatType == null && !_isReadOnly),
          items: _vatRates
              .map((v) => DropdownMenuItem(value: v.vatCode, child: Text(_vatLabel(v.vatCode), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: _isReadOnly
              ? null
              : (v) {
                  setState(() {
                    line.vatType = v;
                    line.vatRate = v != null ? _rateForVatCode(v) : 0;
                  });
                  _refreshListPrices([line]); // ราคาตามตารางที่ต้องแปลง VAT ขึ้นกับอัตราของบรรทัด
                },
        );
      case 'disc':
        if (_salesDiscountMode) {
          return _cField(line.discPctCtrl,
              ro: !_canEditBilling || line.isFree,
              numeric: false,
              hint: isEnglish ? 'e.g. 10+5' : 'ตย.10+5',
              err: !parseStepDiscount(line.discPctCtrl.text).valid,
              onChanged: (_) => setState(() {}));
        }
        return _cField(line.discPctCtrl, ro: !_canEditBilling || line.isFree, onChanged: (_) => setState(() {}));
      case 'net':
        final ro = !_canEditBilling || line.isFree;
        return Tooltip(
          message: isEnglish
              ? 'Type the agreed net price per unit (before bill discount); the discount amount is calculated back from it and kept when qty or price changes'
              : 'กรอกราคาสุทธิ/หน่วย (ก่อนท้ายบิล) ที่ตกลงกับลูกค้า ระบบคำนวณส่วนลด (เงิน) ให้ และคงราคาสุทธินี้เมื่อจำนวนหรือราคาเปลี่ยน',
          child: _cField(
            line.netPriceCtrl,
            ro: ro,
            auto: !_netEntered(line),
            bold: _netEntered(line),
            err: _netTooHigh(line),
            hint: _fmt4.format(_netBeforeBill(line, sd?[line])),
            onChanged: (v) => setState(() {
              // จำส่วนลด (เงิน) ล่าสุดไว้ในช่องเดิม — ล้างราคาสุทธิทีหลังจะได้ส่วนลดนี้ต่อ
              if (v.trim().isNotEmpty && !_netTooHigh(line)) line.lineDiscAmtCtrl.text = _CountLine._fmtInput(_lineDiscOf(line));
            }),
          ),
        );
      case 'amount':
        final v = _salesDiscountMode ? _salesLineAmount(line, sd?[line]) : _amt(line, billed: _isGrDeferredMode).net;
        return Text(_fmtMoney.format(v), textAlign: TextAlign.right, style: _numStyle.copyWith(fontWeight: FontWeight.bold));
      case 'acct':
        return Align(
          alignment: Alignment.centerLeft,
          child: GlLineAccountCell(
            accounts: _accounts,
            accountId: line.glAccountId,
            readOnly: _isReadOnly,
            width: 196,
            placeholder: isEnglish ? 'From item / category / setup' : 'ตามสินค้า / หมวด / ตั้งค่า',
            onChanged: (a) => setState(() => line.glAccountId = a.id),
            onClear: () => setState(() => line.glAccountId = null),
          ),
        );
      case 'dims':
        return Align(
          alignment: Alignment.centerLeft,
          child: GlLineDimsCell(
            dimTypes: _dimTypes,
            dimValues: _dimValues,
            lineDims: line.dims,
            headerDims: _dimSelections,
            account: findAccount(_accounts, line.glAccountId),
            readOnly: _isReadOnly,
            width: 146,
            onChanged: (d) => setState(() => line.dims = d),
          ),
        );
      case 'act':
        final expanded = _expandedLines.contains(line);
        final hasMore = line.remarkCtrl.text.trim().isNotEmpty;
        return Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: expanded ? (isEnglish ? 'Hide details' : 'ย่อรายละเอียด') : (isEnglish ? 'Show details' : 'ขยายรายละเอียด'),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            icon: Icon(expanded ? Icons.expand_less : Icons.expand_more,
                size: 20, color: hasMore ? const Color(0xFF0F6E6E) : Colors.blueGrey.shade600),
            onPressed: () => setState(() => expanded ? _expandedLines.remove(line) : _expandedLines.add(line)),
          ),
          if (!_isReadOnly)
            IconButton(
              tooltip: isEnglish ? 'Delete line' : 'ลบรายการ',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
              onPressed: () {
                _expandedLines.remove(line);
                _removeLine(line);
              },
            ),
        ]);
    }
    return empty;
  }

  // ④ รายละเอียดเพิ่มเติมของรายการ (กดขยายทีละรายการ)
  Widget _lineMore(_CountLine line, Map<_CountLine, SalesLineDiscount>? sd, bool isEnglish) {
    Widget ro(String label, String value, {double width = 150, String? tip}) {
      final w = SizedBox(
        width: width,
        child: InputDecorator(
          decoration: _hDec(label, editable: false),
          child: Text(value, textAlign: TextAlign.right, style: _numStyle),
        ),
      );
      return tip == null ? w : Tooltip(message: tip, child: w);
    }

    return _hGroup(4, isEnglish ? 'More' : 'เพิ่มเติม', _gMore, [
      Wrap(spacing: 8, runSpacing: 8, children: [
        SizedBox(
          width: 380,
          child: TextField(
            controller: line.remarkCtrl,
            readOnly: _isReadOnly,
            maxLength: 500,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: isEnglish ? 'Line remark' : 'หมายเหตุรายการ',
              helperText: line.isNonStock ? (isEnglish ? 'Printed instead of the item name' : 'พิมพ์แทนชื่อสินค้าในใบกำกับ') : null,
              counterText: '',
              border: const OutlineInputBorder(),
              isDense: true,
              filled: _isReadOnly,
              fillColor: _hRo,
            ),
          ),
        ),
        if (sd != null) ...[
          ro(isEnglish ? 'Bill disc. share' : 'ส่วนลดท้ายบิล (ปันส่วน)', _fmtMoney.format(sd[line]?.bill ?? 0),
              tip: isEnglish ? 'Share of the bill discount % and bill cash discount' : 'ส่วนลดท้ายบิล % และส่วนลดเงินสดท้ายบิล ที่ปันส่วนมาที่รายการนี้'),
          ro(isEnglish ? 'Disc. amt' : 'ส่วนลด (เงิน)', _fmtMoney.format(_lineDiscOf(line)),
              tip: isEnglish
                  ? 'Calculated from the net price/unit entered (read-only)'
                  : 'คำนวณจากราคาสุทธิ/หน่วยที่กรอก (แก้ไขไม่ได้)'),
          ro(isEnglish ? 'Net discount' : 'ส่วนลดสุทธิ', _fmtMoney.format(sd[line]?.total ?? 0),
              tip: isEnglish ? 'Line discount + share of bill discounts' : 'ส่วนลดของรายการ + ส่วนลดท้ายบิลที่ปันส่วนมา'),
          ro((isEnglish ? 'Net unit price' : 'ราคา/หน่วยสุทธิ') + (_inclVat ? (isEnglish ? ' (incl. VAT)' : ' (รวม VAT)') : ''),
              _fmt4.format(_salesNetUnit(line, sd[line])),
              width: 170,
              tip: isEnglish ? 'Unit price after all discounts (line + bill)' : 'ราคาขายต่อหน่วยหลังหักส่วนลดทั้งหมด (ของรายการ + ท้ายบิล)'),
          if (_showDiscount) ro(isEnglish ? 'Amount before VAT' : 'ยอดก่อน VAT', _fmtMoney.format(_amt(line).net)),
        ],
      ]),
    ]);
  }

  // หักเงินมัดจำในใบตั้งหนี้ AP / ใบแจ้งหนี้ AR ที่สร้างอัตโนมัติ — อยู่ในการ์ดสรุปยอด แก้ได้ระหว่างร่าง และตอน '12'/'32' รอตั้งหนี้
  Widget _advanceGroup(bool isEnglish) {
    final editable = _canEditBilling;
    return _hGroup(
      3,
      _isApVendorMode
          ? (isEnglish ? 'Deduct deposits on the AP bill' : 'หักเงินมัดจำในใบตั้งหนี้')
          : (isEnglish ? 'Deduct deposits on the invoice' : 'หักเงินมัดจำในใบแจ้งหนี้'),
      _gFin,
      [
        for (final r in _advRowsSorted)
          Row(children: [
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: '${r.docNo}${r.docDate != null ? '  ${_dateFmt.format(r.docDate!)}' : ''}'),
                  if (r.refOrderDocNo != null)
                    TextSpan(
                      text: '  (${_isApVendorMode ? 'PO' : 'SO'} ${r.refOrderDocNo})',
                      style: TextStyle(
                          color: _isLinkedAdvance(r) ? Colors.indigo[700] : Colors.grey[600],
                          fontWeight: _isLinkedAdvance(r) ? FontWeight.bold : FontWeight.normal),
                    ),
                ]),
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 150,
              child: Text('${isEnglish ? 'Balance' : 'คงเหลือ'} ${_fmtMoney.format(r.balanceFc)}',
                  textAlign: TextAlign.right, style: _numStyle),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 130,
              child: _cField(r.ctrl, ro: !editable, hint: isEnglish ? 'Deduct' : 'ยอดหัก', onChanged: (_) => setState(() {})),
            ),
            SizedBox(
              width: 34,
              child: editable
                  ? IconButton(
                      tooltip: isEnglish ? 'Deduct up to the balance' : 'หักเต็มยอดที่หักได้',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.playlist_add_check, size: 18),
                      onPressed: () => setState(() {
                        final others = _advTotalFc - _parseNum(r.ctrl.text);
                        final room = _billTotalFc - others;
                        final amt = room < r.balanceFc ? room : r.balanceFc;
                        r.ctrl.text = amt > 0 ? amt.toStringAsFixed(2) : '';
                      }),
                    )
                  : null,
            ),
          ]),
        Text(
          isEnglish
              ? 'The deducted deposit clears the deposit account and reverses its VAT on the bill (tax invoice net of deposit). Leave blank to deduct at receipt/payment instead.'
              : 'ยอดที่หักจะล้างบัญชีเงินมัดจำและกลับรายการภาษีของมัดจำในใบนั้น (ใบกำกับภาษีหักมัดจำ) — เว้นว่างถ้าจะหักตอนรับ/จ่ายชำระแทน',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildHistory(bool isEnglish) {
    final collapsed = _isCardCollapsed('hist') && _status != 'Deleted' && _reverseHistory.length > 1;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DocReverseHistoryPanel(
        history: collapsed ? _reverseHistory.take(1).toList() : _reverseHistory,
        isDeleted: _status == 'Deleted',
        isEnglish: isEnglish,
        margin: EdgeInsets.zero,
      ),
      if (_reverseHistory.length > 1 && _status != 'Deleted')
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            icon: Icon(collapsed ? Icons.expand_more : Icons.expand_less, size: 18),
            label: Text(
                collapsed
                    ? (isEnglish ? 'Show all (${_reverseHistory.length})' : 'ดูทั้งหมด (${_reverseHistory.length})')
                    : (isEnglish ? 'Show latest only' : 'แสดงเฉพาะล่าสุด'),
                style: const TextStyle(fontSize: 12)),
            onPressed: () => _toggleCard('hist'),
          ),
        ),
    ]);
  }

  // หักเงินมัดจำในตัวอย่างรายการบัญชี — ส่วนก่อน VAT ล้างบัญชีเงินมัดจำ ส่วน VAT กลับรายการภาษีของมัดจำ (ที่อัตราของใบมัดจำ)
  // ฝั่งซื้อ (ap) ลง Cr / ฝั่งขายลง Dr — คืนรายการ + ยอดที่ลดเจ้าหนี้/ลูกหนี้ (บาท ที่อัตราของเอกสาร) มิเรอร์ buildInvAdvanceGl
  // ส่วนลดรับฝั่งซื้อ (บวก = Cr, ลบ = Dr กลับรายการบนใบลดหนี้) — บัญชีส่วนลดของประเภทเอกสาร AP ปลายทาง
  // (backend imPurchaseDiscountLine ต้องตั้งไว้เมื่อมีส่วนลด) หน้าจอนี้ไม่รู้รหัสบัญชีจึงแสดงชื่อแทน
  List<Widget> _purchaseDiscountLine(double amount, bool isEnglish) {
    if (amount.abs() < 0.005) return const [];
    final d = _glAccts?.apDiscount;
    return [
      _glLine(
          d?.code ?? (_glAccts == null ? null : '!'),
          d != null
              ? '${d.name(isEnglish)} (${isEnglish ? 'discount received' : 'ส่วนลดรับ'})'
              : (_glAccts == null
                  ? (isEnglish ? 'Discount received' : 'ส่วนลดรับ')
                  : (isEnglish ? 'Discount account not configured (AP document type)' : 'ยังไม่ตั้งบัญชีส่วนลดรับ (ประเภทเอกสาร AP)')),
          amount < 0 ? -amount : 0, amount > 0 ? amount : 0),
    ];
  }

  // ── ฝั่งซื้อ (เอกสาร AP อัตโนมัติ) ── บัญชีเจ้าหนี้/ภาษีซื้อตามที่ backend จะใช้ตอน Post (resolveApAccountId ฯลฯ)
  bool get _apLinkedPreview => _isGrnBillingMode || _isGrDeferredMode || _isApReturnCnMode || _isApDnMode;

  _Acct _apAcct(bool isEnglish) {
    final a = _glAccts?.apAccount;
    if (a != null) return (code: a.code, name: a.name(isEnglish));
    if (_glAccts == null) return (code: null, name: isEnglish ? 'Accounts Payable' : 'เจ้าหนี้การค้า');
    return (
      code: '!',
      name: isEnglish
          ? 'AP account not configured (vendor / vendor group / AP document type)'
          : 'ยังไม่ตั้งบัญชีเจ้าหนี้ (ผู้ขาย / กลุ่มผู้ขาย / ประเภทเอกสาร AP)',
    );
  }

  _Acct _apVatAcct(bool isEnglish) {
    final a = _glAccts?.apVat;
    if (a != null) return (code: a.code, name: a.name(isEnglish));
    if (_glAccts == null) return (code: _docSetup?.vatInputAccountCode, name: _docSetup?.vatInputAccountName ?? (isEnglish ? 'VAT Input' : 'ภาษีซื้อ'));
    return (code: '!', name: isEnglish ? 'VAT input account not configured' : 'ยังไม่ตั้งบัญชีภาษีซื้อ');
  }

  // ใบจ่ายชำระ AP ของซื้อเงินสด — Dr เจ้าหนี้ / Cr เงินสด-ธนาคารตามวิธีจ่าย + ภาษีหัก ณ ที่จ่ายค้างจ่าย
  // (มิเรอร์ postApPaymentForCashPurchase) — ยอดคงค้าง 0 (มัดจำครอบคลุมทั้งหมด) = ไม่มีใบจ่าย
  Widget? _buildCashPaymentSection(bool isEnglish) {
    _glSumReset();
    final rate = _exchangeRate;
    final dueLc = _cashDueFc * rate;
    if (dueLc <= 0.005) return null;
    final whtLc = _cash.whtTotal * rate;
    final cashLc = dueLc - whtLc;
    final accts = _glAccts?.paymentPayments ?? const <ImGlAcct?>[];
    final ap = _apAcct(isEnglish);
    final lines = <Widget>[_glLine(ap.code, ap.name, dueLc, 0)];
    final paid = <int>[for (var i = 0; i < _cash.payments.length; i++) if (_cash.payments[i].amount > 0) i];
    double rest = cashLc;
    for (var k = 0; k < paid.length; k++) {
      final i = paid[k];
      final p = _cash.payments[i];
      final lc = k == paid.length - 1 ? rest : p.amount * rate; // บรรทัดสุดท้ายรับเศษปัด (เหมือน backend)
      rest -= lc;
      final a = i < accts.length ? accts[i] : null;
      final label = p.paymentMethodName ?? p.paymentMethodCode ?? p.paymentMethodType;
      lines.add(_glLine(
          a?.code ?? (_glAccts == null ? null : '!'),
          a != null
              ? '${a.name(isEnglish)} ($label)'
              : (_glAccts == null ? label : (isEnglish ? 'Payment account not configured ($label)' : 'ยังไม่ตั้งบัญชีจ่ายเงิน ($label)')),
          0,
          lc));
    }
    if (paid.isEmpty) {
      lines.add(_glLine(null, isEnglish ? 'Cash / bank (no payment method yet)' : 'เงินสด/ธนาคาร (ยังไม่ระบุวิธีจ่าย)', 0, cashLc));
    }
    if (whtLc.abs() >= 0.005) {
      final w = _glAccts?.paymentWht;
      lines.add(_glLine(w?.code ?? '!',
          w?.name(isEnglish) ?? (isEnglish ? 'Withholding tax payable account not configured' : 'ยังไม่ตั้งบัญชีภาษีหัก ณ ที่จ่ายค้างจ่าย'), 0, whtLc));
    }
    return _glSection(isEnglish ? 'AP Payment' : 'ใบจ่ายชำระเจ้าหนี้', lines);
  }

  // การ์ดตัวอย่างรายการบัญชีของเอกสารที่สร้างเอกสาร AP อัตโนมัติ — ① ใบตั้งหนี้/ใบลด-เพิ่มหนี้ AP ② ใบจ่ายชำระ (ซื้อเงินสด)
  Widget _buildCombinedApCard(bool isEnglish) {
    _glSectionMode = true;
    double dr = 0, cr = 0;
    final all = <(String?, String?, double, double)>[];
    final sections = <Widget>[];
    var n = 0;
    void take(Widget? w) {
      if (w == null) return;
      dr += _glSumDr;
      cr += _glSumCr;
      all.addAll(_glSumLines);
      if (sections.isNotEmpty) sections.add(const SizedBox(height: 14));
      sections.add(w);
      n++;
    }

    final docLabel = _isApReturnCnMode
        ? (isEnglish ? 'AP Credit Note' : 'ใบลดหนี้เจ้าหนี้')
        : _isApDnMode
            ? (isEnglish ? 'AP Debit Note' : 'ใบเพิ่มหนี้เจ้าหนี้')
            : (isEnglish ? 'AP Invoice' : 'ใบตั้งหนี้เจ้าหนี้');
    try {
      _glSectionTitle = _isGrDeferredMode && _status != 'Posted'
          ? '$docLabel (${isEnglish ? 'created at Post AP/GL' : 'สร้างตอน Post AP/GL'})'
          : docLabel;
      take(_buildGlCardInner(isEnglish));
      _glSectionTitle = null;
      if (_isCashPurchaseMode) take(_buildCashPaymentSection(isEnglish));
    } finally {
      _glSectionMode = false;
      _glSectionTitle = null;
    }
    _glSumReset();
    _glSumDr = dr;
    _glSumCr = cr;
    _glSumLines.addAll(all);
    return _card(
      collapseKey: 'gl',
      glPreview: true,
      title: _status == 'Posted' ? (isEnglish ? 'GL Entries' : 'รายการบัญชี') : (isEnglish ? 'GL Preview' : 'ตัวอย่างรายการบัญชี'),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            isEnglish
                ? (n > 1
                    ? 'Posting creates $n separate journal entries in AP, shown as sections below. Accounts follow the current settings of the IM/AP document types, items and vendor.'
                    : 'This document posts no GL entry of its own — the entry below belongs to the AP document created automatically. Accounts follow the current settings of the IM/AP document types, items and vendor.')
                : (n > 1
                    ? 'เมื่อ Post ระบบลงบัญชีในโมดูล AP แยกเป็น $n รายการตามส่วนด้านล่าง — บัญชีมาจากการตั้งค่าปัจจุบันของประเภทเอกสาร IM/AP สินค้า และผู้ขาย'
                    : 'เอกสารนี้ไม่ลงบัญชีของตัวเอง — รายการด้านล่างเป็นของเอกสาร AP ที่สร้างอัตโนมัติ บัญชีมาจากการตั้งค่าปัจจุบันของประเภทเอกสาร IM/AP สินค้า และผู้ขาย'),
            style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700),
          ),
        ),
        ...sections,
      ],
    );
  }

  (List<Widget>, double) _advancePreview(bool isEnglish, {required bool ap}) {
    final lines = <Widget>[];
    double reduce = 0;
    if (!_showAdvances) return (lines, reduce);
    for (final r in _advRows) {
      final fc = _parseNum(r.ctrl.text);
      if (fc <= 0) continue;
      final leg = fc * r.rate;
      final vat = leg * r.vatRatio;
      final pend = leg * r.pendingVatRatio;
      final net = leg - vat - pend;
      reduce += fc * _exchangeRate;
      lines.add(_glLine(null, '${isEnglish ? 'Deposit deducted' : 'หักเงินมัดจำ'} ${r.docNo}', ap ? 0 : net, ap ? net : 0));
      if (vat.abs() >= 0.005) {
        lines.add(_glLine(ap ? _docSetup?.vatInputAccountCode : _docSetup?.vatOutputAccountCode,
            '${isEnglish ? 'VAT of deposit' : (ap ? 'ภาษีซื้อของมัดจำ' : 'ภาษีขายของมัดจำ')} ${r.docNo}', ap ? 0 : vat, ap ? vat : 0));
      }
      if (pend.abs() >= 0.005) {
        // บัญชี VAT รอตัดที่ตั้งไว้ในประเภทเอกสารรับ/จ่ายมัดจำ — ฝั่งซื้อ Cr ภาษีซื้อรอตัด / ฝั่งขาย Dr ภาษีขายรอตัด
        lines.add(_glLine(null, '${isEnglish ? 'Deferred VAT of deposit' : 'ล้าง VAT รอตัดของมัดจำ'} ${r.docNo}', ap ? 0 : pend, ap ? pend : 0));
      }
      final fx = fc * _exchangeRate - leg;
      if (fx.abs() >= 0.005) {
        final dr = ap ? (fx < 0 ? -fx : 0.0) : (fx > 0 ? fx : 0.0);
        final cr = ap ? (fx > 0 ? fx : 0.0) : (fx < 0 ? -fx : 0.0);
        lines.add(_glLine(null, isEnglish ? 'FX difference on deposit' : 'ผลต่างอัตราแลกเปลี่ยนมัดจำ', dr, cr));
      }
    }
    return (lines, reduce);
  }

  // ── บัญชีต่อสินค้าจาก backend (resolver เดียวกับตอน Post: สต็อก คลัง → สินค้า → หมวดสินค้า → ประเภทเอกสาร,
  // ต้นทุน/รายได้ สินค้า → หมวดสินค้า → ประเภทเอกสาร) — โหลดใหม่เมื่อประเภทเอกสาร คลัง หรือรายการสินค้าเปลี่ยน
  ImGlAccounts? _glAccts;
  String _glAcctsKey = '';
  // โหมดของบรรทัด (สินค้า → หมวดสินค้า → คลัง → ค่าเริ่มต้น) — ระหว่างรอโหลดถือเป็น Perpetual
  bool _linePeriodic(_CountLine l) => _glAccts?.items[l.item.id]?.isPeriodic ?? false;
  bool _lineToPeriodic(_CountLine l) => _glAccts?.items[l.item.id]?.isToPeriodic ?? false;

  void _ensureGlAccounts() {
    final code = _docCode;
    if (code == null) return;
    final ids = _lines.map((l) => l.item.id).whereType<int>().toSet().toList()..sort();
    final customerId = _arLinkedPreview ? _customerId : null;
    final vendorId = _apLinkedPreview ? _vendorId : null;
    final pays = _isCashMode
        ? [for (final p in _cash.payments) {'payment_method_type': p.paymentMethodType, 'gl_account_id': p.glAccountId, 'cm_bank_account_id': p.cmBankAccountId}]
        : <Map<String, dynamic>>[];
    final paySig = pays.map((p) => '${p['payment_method_type']}:${p['gl_account_id']}:${p['cm_bank_account_id']}').join(';');
    final key = '$code|$_warehouseId|$_toWarehouseId|${ids.join(',')}|$customerId|$vendorId|$paySig';
    if (key == _glAcctsKey) return;
    _glAcctsKey = key;
    _glAccts = null; // ไม่ใช้บัญชีของชุดเดิมระหว่างรอโหลด (เรียกจาก build จึงไม่ต้อง setState)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ImGlAccounts? r;
      try {
        r = await _service.fetchGlAccounts(docCode: code, warehouseId: _warehouseId, toWarehouseId: _toWarehouseId, itemIds: ids,
            customerId: customerId, vendorId: vendorId, payments: pays);
      } catch (_) {}
      if (!mounted || key != _glAcctsKey) return;
      setState(() => _glAccts = r);
    });
  }

  // บัญชีของบรรทัด — ค่าจาก backend ถ้าโหลดแล้ว ระหว่างรอโหลดใช้ค่าตั้งต้นของประเภทเอกสาร
  _Acct _lineAcct(_CountLine l, ImGlAcct? Function(ImItemGlAccts a) pick, String? setupCode, String? setupName, bool isEnglish) {
    final a = _glAccts?.items[l.item.id];
    if (a == null) return (code: setupCode, name: setupName);
    final acc = pick(a);
    if (acc == null) return (code: '!', name: isEnglish ? 'Not configured' : 'ยังไม่ตั้งค่า');
    return (code: acc.code, name: acc.name(isEnglish));
  }

  // บัญชีฝั่งสินค้าของบรรทัด — บรรทัด Periodic ใช้บัญชีซื้อสินค้าแทนบัญชีสต็อก (resolveStockSideAccount ฝั่ง backend)
  _Acct _receiveInvAcct(_CountLine l, bool isEnglish, {bool destination = false}) {
    final periodic = destination ? _lineToPeriodic(l) : _linePeriodic(l);
    if (periodic) {
      final p = destination ? _glAccts!.items[l.item.id]!.toPurchases : _glAccts!.items[l.item.id]!.purchases;
      return p == null
          ? (code: '!', name: isEnglish ? 'Purchases account not configured' : 'ยังไม่ตั้งค่าบัญชีซื้อสินค้า')
          : (code: p.code, name: p.name(isEnglish));
    }
    return _lineAcct(l, (a) => destination ? a.toInventory : a.inventory, _docSetup?.inventoryAccountCode, _docSetup?.inventoryAccountName, isEnglish);
  }

  // หมายเหตุใต้ตัวอย่าง: ฝั่งสินค้าของบรรทัด Perpetual/Periodic ใช้บัญชีต่างกัน
  Widget _modeSideNote(bool isEnglish) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          isEnglish
              ? 'Perpetual lines use the inventory account (warehouse → item → item category → document type) at stock value; Periodic lines use the purchases account at the document price.'
              : 'บรรทัด Perpetual ลงบัญชีสินค้าคงคลัง (คลัง → สินค้า → หมวดสินค้า → ประเภทเอกสาร) ตามมูลค่าสต็อก ส่วนบรรทัด Periodic ลงบัญชีซื้อสินค้าตามราคาในเอกสาร',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
        ),
      );

  Widget _skippedPeriodicNote(int count, bool isEnglish) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          isEnglish
              ? '$count Periodic line(s) post no GL at Post — their cost is calculated at period closing.'
              : 'บรรทัด Periodic $count รายการไม่ลงบัญชีตอน Post — ต้นทุนคำนวณตอนปิดงวด',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
        ),
      );

  // รวมยอดตามบัญชี (บวก = Dr, ลบ = Cr) แล้วแสดงทีละบัญชี
  List<Widget> _groupedGlLines(List<(_Acct, double)> entries, {String suffix = ''}) {
    final sums = <String, double>{};
    final accts = <String, _Acct>{};
    for (final (acct, amt) in entries) {
      final k = '${acct.code}|${acct.name}';
      sums[k] = (sums[k] ?? 0) + amt;
      accts[k] = acct;
    }
    return [
      for (final e in sums.entries)
        if (e.value.abs() >= 0.005)
          _glLine(accts[e.key]!.code, '${accts[e.key]!.name ?? ''}$suffix', e.value > 0 ? e.value : 0, e.value < 0 ? -e.value : 0),
    ];
  }

  Widget _periodicNoGlCard(bool isEnglish) => _card(collapseKey: 'gl', glPreview: true, title: isEnglish ? 'GL Preview' : 'ตัวอย่างรายการบัญชี', children: [
        Text(
          isEnglish
              ? 'All lines are Periodic — this document posts no GL entry at Post; inventory and cost of sales are calculated at period closing.'
              : 'ทุกบรรทัดเป็น Periodic — เอกสารนี้ไม่ลงบัญชีตอน Post สินค้าคงคลังและต้นทุนขายคำนวณรวมตอนปิดงวด',
          style: TextStyle(color: Colors.grey.shade700, fontStyle: FontStyle.italic),
        ),
      ]);

  // เอกสารที่สร้าง AR/AP อัตโนมัติ ต้องตั้งประเภทเอกสาร AR/AP ในหน้าตั้งค่าบัญชี IM ก่อน Post (resolveTargetDoc ฝั่ง backend)
  Widget _buildGlCard(bool isEnglish) {
    _glDimMissing.clear();
    _glDimMissingSlotsBuild.clear();
    final card0 = _arLinkedPreview
        ? _buildCombinedGlCard(isEnglish)
        : _apLinkedPreview
            ? _buildCombinedApCard(isEnglish)
            : _buildGlCardInner(isEnglish);
    // การ์ดข้อมูลเอกสารสร้างก่อนการ์ดนี้ — ช่องมิติที่ขาดเปลี่ยนเมื่อไหร่ สร้างหน้าจอใหม่อีกรอบ
    if (_glDimMissingSlotsBuild.length != _glDimMissingSlots.length || !_glDimMissingSlots.containsAll(_glDimMissingSlotsBuild)) {
      _glDimMissingSlots = {..._glDimMissingSlotsBuild};
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() {}); });
    }
    final card = _glDimMissing.isEmpty
        ? card0
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFFDECEA), borderRadius: BorderRadius.circular(4)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: Colors.red.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${isEnglish ? 'Branch/dimensions required before Post (set them in the document card):' : 'ต้องระบุสาขา/มิติก่อน Post (เลือกที่การ์ดข้อมูลเอกสาร):'} ${_glDimMissing.join(', ')}',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade800),
                  ),
                ),
              ]),
            ),
            card0,
          ]);
    final s = _docSetup;
    if (s == null || !s.targetAuto || s.targetDocId != null || _status == 'Posted') return card;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          isEnglish
              ? 'The ${s.targetModule} document type created by this document is not set — set it in IM GL Account Setup before posting.'
              : 'ยังไม่ได้ตั้งประเภทเอกสาร ${s.targetModule} ที่เอกสารนี้สร้างอัตโนมัติ — ตั้งค่าที่หน้าตั้งค่าบัญชี IM ก่อน Post',
          style: TextStyle(color: Colors.red.shade700, fontSize: 12),
        ),
      ),
      card,
    ]);
  }

  Widget _buildGlCardInner(bool isEnglish) {
    _ensureGlAccounts();
    _glSumReset();
    // '32' ที่ Delivered แล้ว: ต้นทุนขาย (COGS) Post ไปแล้วตอน Post IM (gl_entry_id ตั้งค่าจริง) จึงแสดง entry จริง
    // เหมือนสถานะ Posted ทั่วไป ต่างจาก '12' ที่ยังไม่มี GL ใดๆ เลยตอน Received
    if ((_status == 'Posted' || (_isDlnDeferredMode && _status == 'Delivered')) && _postedGlDetails != null) {
      return _card(collapseKey: 'gl', glPreview: true, title: isEnglish ? 'GL Entries (Posted)' : 'รายการบัญชี (Posted จริง)', children: [
        ..._postedGlDetails!.map((d) => _glLine(d.accountCode, isEnglish && d.accountNameEng.isNotEmpty ? d.accountNameEng : d.accountName, d.debitLc, d.creditLc)),
      ]);
    }

    // '12' ไม่มี im_gl_account_setup ของตัวเองเลย (Stage 1 ไม่มี GL, Stage 2 ใช้บัญชีของ AP) จึงต้องดักก่อนเช็ค
    // _docSetup ด้านล่าง — และ gl_entry_id ของ im_transaction เองก็เป็น null เสมอแม้ Posted แล้ว (entry อยู่ที่
    // ap_transaction ที่สร้างให้ เหมือน '11') จึงแสดงตัวอย่างที่คำนวณจากค่าปัจจุบันแทนของจริงจาก server เสมอ
    if (_isGrDeferredMode) {
      final isDraft = _status == 'Draft';
      // ช่องต้นทุน/ต้นทุนตามใบกำกับเป็นสกุลเงินของเอกสาร — แปลงเป็นบาทด้วยอัตราแลกเปลี่ยนของเอกสาร; จำนวนที่รับ
      // คือ variance (counted คือยอดคงเหลือหลังรับ ไม่ใช่จำนวนที่รับ) — สินค้าคงคลังลงตามมูลค่าสต็อกตอนรับ
      // ส่วนต่างกับราคาใบกำกับลงบัญชีผลต่างต้นทุน (มิเรอร์ postApBillFromGrn; Periodic ลงบัญชีซื้อเต็มจำนวน)
      double billedValue = 0, stockValue = 0, vatValue = 0, discValue = 0;
      final invEntries = <(_Acct, double)>[];
      for (final l in _lines) {
        final qty = l.variance;
        // ยอดก่อนส่วนลด ก่อน VAT (ราคารวม VAT แยก VAT ออกแล้ว) — ส่วนลดรับแยกบัญชีบนใบตั้งหนี้ AP
        final received = _amt(l).gross * _exchangeRate;
        final billedAmt = _amt(l, billed: true);
        final billed = billedAmt.gross * _exchangeRate;
        billedValue += billed;
        discValue += billedAmt.discount * _exchangeRate;
        // Periodic: Dr บัญชีซื้อตามใบกำกับเต็มจำนวน ไม่มีผลต่าง (เหมือน backend)
        final lineStock = _linePeriodic(l) ? billed : (l.item.costingMethod == 'STANDARD' ? qty * l.item.standardCost : received);
        stockValue += lineStock;
        invEntries.add((_receiveInvAcct(l, isEnglish), lineStock));
        vatValue += billedAmt.vat * _exchangeRate;
      }
      final (advLines, advReduce) = _advancePreview(isEnglish, ap: true);
      final priceVariance = billedValue - stockValue;
      final hasVariance = priceVariance.abs() >= 0.005;
      final isPostedYet = _status == 'Posted';
      return _card(collapseKey: 'gl', glPreview: true, 
        title: isPostedYet
            ? (isEnglish ? 'GL Preview (Posted reference)' : 'ตัวอย่างรายการบัญชี (อ้างอิงยอดที่ Posted แล้ว)')
            : (isEnglish ? 'GL Preview (not posted yet)' : 'ตัวอย่างรายการบัญชี (ยังไม่ได้ Post)'),
        children: [
          ..._groupedGlLines(invEntries),
          if (hasVariance)
            _glLine(_docSetup?.varianceAccountCode,
                isEnglish ? 'Cost variance (billed price vs received cost)' : 'ผลต่างต้นทุน (ราคาใบกำกับ - ต้นทุนตอนรับ)',
                priceVariance > 0 ? priceVariance : 0, priceVariance < 0 ? -priceVariance : 0),
          if (vatValue > 0) _glLine(_apVatAcct(isEnglish).code, _apVatAcct(isEnglish).name, vatValue, 0),
          ..._purchaseDiscountLine(discValue, isEnglish),
          _glLine(_apAcct(isEnglish).code, _apAcct(isEnglish).name, 0, billedValue - discValue + vatValue - advReduce),
          ...advLines,
          _modeSideNote(isEnglish),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              isDraft
                  ? (isEnglish
                      ? 'No GL posts at "Post IM" — this AP invoice entry is posted later via "Post AP/GL" when the vendor invoice arrives (amounts here use the current prices).'
                      : 'ตอน "Post IM" ยังไม่ลงบัญชี — รายการตั้งหนี้นี้จะลงบัญชีเมื่อกด "Post AP/GL" ภายหลังที่ได้รับใบกำกับ (ยอดนี้คำนวณจากราคาปัจจุบัน)')
                  : isPostedYet
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
      return _card(collapseKey: 'gl', glPreview: true, title: isEnglish ? 'GL Preview' : 'ตัวอย่างรายการบัญชี', children: [
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
      // แต่ละฝั่งใช้บัญชีตามโหมดของคลังนั้น (Periodic = บัญชีซื้อ) — ทั้งสองฝั่ง Periodic ไม่ลงบัญชี
      final dstEntries = <(_Acct, double)>[];
      final srcEntries = <(_Acct, double)>[];
      int skipped = 0, active = 0;
      for (final l in _lines) {
        final qty = l.baseDelta;
        if (qty <= 0) continue;
        if (_linePeriodic(l) && _lineToPeriodic(l)) {
          skipped++;
          continue;
        }
        active++;
        final cost = l.item.costingMethod == 'STANDARD' ? l.item.standardCost : null;
        if (cost == null) continue;
        dstEntries.add((_receiveInvAcct(l, isEnglish, destination: true), qty * cost));
        srcEntries.add((_receiveInvAcct(l, isEnglish), -qty * cost));
      }
      if (skipped > 0 && active == 0) return _periodicNoGlCard(isEnglish);
      return _card(collapseKey: 'gl', glPreview: true, title: isEnglish ? 'GL Preview (Draft)' : 'ตัวอย่างรายการบัญชี (Draft)', children: [
        ..._groupedGlLines(dstEntries, suffix: isEnglish ? ' (destination)' : ' (คลังปลายทาง)'),
        ..._groupedGlLines(srcEntries, suffix: isEnglish ? ' (source)' : ' (คลังต้นทาง)'),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            isEnglish
                ? 'Each side uses the account of its warehouse\'s mode: inventory (warehouse → item → item category → document type) for Perpetual, purchases for Periodic. When both sides use the same account the lines cancel out and no GL entry is posted.'
                : 'แต่ละฝั่งใช้บัญชีตามโหมดของคลังนั้น: Perpetual ใช้บัญชีสต็อก (คลัง → สินค้า → หมวดสินค้า → ประเภทเอกสาร) Periodic ใช้บัญชีซื้อสินค้า — ถ้าทั้งสองฝั่งใช้บัญชีเดียวกัน รายการจะหักล้างกันและไม่มีการลงบัญชี',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
          ),
        ),
        if (skipped > 0) _skippedPeriodicNote(skipped, isEnglish),
      ]);
    }

    if (_isReceiveMode) {
      if (_isGrnBillingMode) {
        // '11' GRN Billing — ไม่ Post บัญชีที่นี่เลย สร้าง ap_transaction อัตโนมัติแล้วโพสต์ที่นั่นแทน — ใบตั้งหนี้ใช้ราคาซื้อ
        // ที่กรอก (สกุลเงินเอกสาร × อัตรา) สินค้าคงคลังใช้มูลค่าสต็อก (STANDARD = ต้นทุนมาตรฐาน) ส่วนต่างลงบัญชีผลต่าง
        // ยอดหลังส่วนลด ก่อน VAT (ราคารวม VAT แยก VAT ออกแล้ว) — มิเรอร์ backend imLineAmounts
        // สินค้าคงคลัง/ซื้อลงยอดก่อนส่วนลด ส่วนลดรับแยกบัญชีส่วนลดของประเภทเอกสาร AP (เหมือนใบตั้งหนี้ AP)
        double billValue = 0, vatValue = 0, discValue = 0;
        final invEntries = <(_Acct, double)>[];
        for (final l in _lines) {
          final qty = _parseNum(l.issueQtyCtrl.text);
          if (qty <= 0) continue;
          final a = _amt(l);
          final gross = a.gross * _exchangeRate;
          billValue += gross;
          discValue += a.discount * _exchangeRate;
          vatValue += a.vat * _exchangeRate;
          // Periodic: Dr บัญชีซื้อตามราคาซื้อ ไม่มีผลต่าง (เหมือน backend)
          invEntries.add((_receiveInvAcct(l, isEnglish),
              !_linePeriodic(l) && l.item.costingMethod == 'STANDARD' ? qty * l.item.standardCost : gross));
        }
        final (advLines, advReduce) = _advancePreview(isEnglish, ap: true);
        final stockValue = invEntries.fold<double>(0, (s, e) => s + e.$2);
        final priceVariance = billValue - stockValue;
        return _card(collapseKey: 'gl', glPreview: true, title: isEnglish ? 'GL Preview (Draft)' : 'ตัวอย่างรายการบัญชี (Draft)', children: [
          ..._groupedGlLines(invEntries),
          if (priceVariance.abs() >= 0.005)
            _glLine(_docSetup!.varianceAccountCode,
                isEnglish ? 'Cost variance (purchase price vs standard cost)' : 'ผลต่างต้นทุน (ราคาซื้อ - ต้นทุนมาตรฐาน)',
                priceVariance > 0 ? priceVariance : 0, priceVariance < 0 ? -priceVariance : 0),
          if (vatValue > 0) _glLine(_apVatAcct(isEnglish).code, _apVatAcct(isEnglish).name, vatValue, 0),
          ..._purchaseDiscountLine(discValue, isEnglish),
          _glLine(_apAcct(isEnglish).code, _apAcct(isEnglish).name, 0, billValue - discValue + vatValue - advReduce),
          ...advLines,
          _modeSideNote(isEnglish),
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
      // GR/IR ตั้งตามราคาซื้อที่กรอก (สกุลเงินเอกสาร × อัตรา) ให้ล้างกับใบตั้งหนี้ AP ได้พอดี คลังใช้มูลค่าสต็อก
      // (STANDARD = ต้นทุนมาตรฐาน) ส่วนต่างลงบัญชีผลต่างต้นทุน — มิเรอร์ postGlEntry ฝั่ง backend
      double grirValue = 0, grirStockValue = 0;
      final invEntries = <(_Acct, double)>[];
      for (final l in _lines) {
        final qty = l.baseDelta;
        if (qty <= 0 || l.isFree) continue;
        final value = _amt(l).gross * _exchangeRate; // ก่อนส่วนลด — ส่วนลดรับลงตอนตั้งหนี้ AP (Dr GR/IR / Cr ส่วนลดรับ)
        grirValue += value;
        // Periodic: Dr บัญชีซื้อตามราคาซื้อ ไม่มีผลต่าง (เหมือน backend)
        final lineStock = !_linePeriodic(l) && l.item.costingMethod == 'STANDARD' ? qty * l.item.standardCost : value;
        grirStockValue += lineStock;
        invEntries.add((_receiveInvAcct(l, isEnglish), lineStock));
      }
      final grirVariance = grirValue - grirStockValue;
      return _card(collapseKey: 'gl', glPreview: true, title: isEnglish ? 'GL Preview (Draft)' : 'ตัวอย่างรายการบัญชี (Draft)', children: [
        ..._groupedGlLines(invEntries),
        if (grirVariance.abs() >= 0.005)
          _glLine(_docSetup!.varianceAccountCode,
              isEnglish ? 'Cost variance (purchase price vs standard cost)' : 'ผลต่างต้นทุน (ราคาซื้อ - ต้นทุนมาตรฐาน)',
              grirVariance > 0 ? grirVariance : 0, grirVariance < 0 ? -grirVariance : 0),
        // '13' รับฝากขาย: Cr เจ้าหนี้ฝากขาย / '10': Cr พักรอใบกำกับ (GR/IR) — เหมือน resolveCounterAccount ฝั่ง backend
        _isConsignmentReceiveMode
            ? _glLine(_docSetup!.consignmentPayableAccountCode, _docSetup!.consignmentPayableAccountName, 0, grirValue)
            : _glLine(_docSetup!.grirAccountCode, _docSetup!.grirAccountName, 0, grirValue),
        _modeSideNote(isEnglish),
      ]);
    }

    if (_isApReturnCnMode || _isApDnMode) {
      // '15'/'20'/'25' — มิเรอร์ '11' ทุกประการ (ไม่ Post บัญชีที่นี่เลย สร้าง ap_transaction อัตโนมัติแล้ว Post ที่นั่น
      // แทน) ต่างกันแค่ Dr/Cr กลับด้านสำหรับ CN ('15'/'20') เทียบกับ DN ('25') และยอดฝั่งลดสต็อก ('15'/'20') ยังไม่ทราบ
      // ต้นทุนที่แน่นอนจนกว่าจะ Post (ตัดจาก stock layer จริง) จึงแสดงเป็น undetermined เหมือน AJS/ISS ทั่วไป
      // ยอดใบลดหนี้/เพิ่มหนี้ = ราคาที่กรอก (สกุลเงินเอกสาร × อัตราแลกเปลี่ยน) ทราบแน่นอนตั้งแต่ Draft — ฝั่งสินค้าคงคลัง
      // ตัดตามต้นทุนสต็อกจริงตอน Post ส่วนต่างจากราคานี้ลงบัญชีผลต่างต้นทุน (ดู postApCreditDebitNoteFromIm)
      double value = 0, vatValue = 0, undetermined = 0, discSigned = 0;
      final invEntries = <(_Acct, double)>[];
      for (final l in _lines) {
        final v = l.variance;
        if (v == 0) continue;
        if (l.unitCostCtrl.text.trim().isEmpty) {
          undetermined += v.abs();
        } else {
          final a = _amt(l); // ก่อนส่วนลด ก่อน VAT — ส่วนลดแยกบัญชีส่วนลดรับ (ใบลดหนี้กลับรายการ = Dr)
          final signed = (v > 0 ? 1 : -1) * a.gross * _exchangeRate;
          discSigned += (v > 0 ? 1 : -1) * a.discount * _exchangeRate;
          value += signed;
          invEntries.add((_receiveInvAcct(l, isEnglish), signed));
          vatValue += a.vat * _exchangeRate;
        }
      }
      final noteLabel = _isApReturnCnMode
          ? (isEnglish ? 'AP Credit Note' : 'ใบลดหนี้ AP')
          : (isEnglish ? 'AP Debit Note' : 'ใบเพิ่มหนี้ AP');
      final grandValue = value - discSigned + (value >= 0 ? vatValue : -vatValue);
      return _card(collapseKey: 'gl', glPreview: true, title: isEnglish ? 'GL Preview (Draft)' : 'ตัวอย่างรายการบัญชี (Draft)', children: [
        ..._groupedGlLines(invEntries),
        _modeSideNote(isEnglish),
        if (vatValue > 0)
          _glLine(_apVatAcct(isEnglish).code, _apVatAcct(isEnglish).name, value > 0 ? vatValue : 0, value < 0 ? vatValue : 0),
        ..._purchaseDiscountLine(discSigned, isEnglish),
        _glLine(_apAcct(isEnglish).code, _apAcct(isEnglish).name,
            grandValue < 0 ? -grandValue : 0, grandValue > 0 ? grandValue : 0),
        if (undetermined > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              isEnglish
                  ? 'Some lines have no unit price yet — not included above.'
                  : 'บางรายการยังไม่ได้ระบุราคาต่อหน่วย — ยังไม่รวมในตัวเลขข้างต้น',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            isEnglish
                ? 'The inventory side is valued at the actual stock cost at Post time; any difference from the price above goes to the cost variance account.'
                : 'ฝั่งสินค้าคงคลังจะคิดตามต้นทุนสต็อกจริงตอน Post — ส่วนต่างจากราคาข้างต้นลงบัญชีผลต่างต้นทุน',
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

    // บรรทัด Periodic ของ ปรับยอด/เบิก/ส่ง/รับคืนจากลูกค้า ไม่ลงบัญชีตอน Post (lineNeedsImGl ฝั่ง backend) — '90'/'95'
    // ลงทุกบรรทัด โดยบรรทัด Periodic ใช้บัญชีซื้อแทนบัญชีสต็อก
    final alwaysPost = ['90', '95'].contains(_selectedSysDocType);
    final skippedPeriodic = alwaysPost ? 0 : _lines.where((l) => l.variance != 0 && _linePeriodic(l)).length;
    if (skippedPeriodic > 0 && !_lines.any((l) => l.variance != 0 && !_linePeriodic(l))) return _periodicNoGlCard(isEnglish);

    // บัญชีคู่บัญชี (counterpart ของคลัง) ต้องตรงกับที่ postGlEntry ใช้จริง — ISS/DLN/RTC/CNC/DNC ใช้ต้นทุนของแต่ละสินค้า
    // (สินค้า → หมวดสินค้า → ประเภทเอกสาร), MOI/MOR ใช้ WIP, AJS ใช้ผลต่าง — ตัดสินจาก sys_doc_type ไม่ใช่ doc_code
    final isCogsCounter = _isIssueMode || _isDeliverMode || _isArReturnCnMode || _isArDnMode;
    final isWipCounter = ['90', '95'].contains(_selectedSysDocType);
    double undetermined = 0;
    final invEntries = <(_Acct, double)>[];
    final counterEntries = <(_Acct, double)>[];
    for (final l in _lines) {
      final v = l.variance;
      if (v == 0) continue;
      if (!alwaysPost && _linePeriodic(l)) continue;
      // ต้นทุนมาตรฐานเป็นต่อหน่วยหลัก × จำนวนหน่วยหลัก, ต้นทุนที่กรอกเป็นต่อหน่วยของบรรทัด × จำนวนตามหน่วยของบรรทัด
      final isStd = l.item.costingMethod == 'STANDARD';
      final cost = isStd ? l.item.standardCost : (v > 0 ? _parseNum(l.unitCostCtrl.text) : null);
      if (cost == null) {
        undetermined += v.abs();
        continue;
      }
      invEntries.add((_receiveInvAcct(l, isEnglish), isStd ? v * cost : v.sign * l.docQty * cost));
      final lineAcc = _isIssueMode ? findAccount(_accounts, l.glAccountId) : null;
      final _Acct counter = lineAcc != null
          ? (code: lineAcc.accountCode, name: isEnglish && lineAcc.accountNameEng.isNotEmpty ? lineAcc.accountNameEng : lineAcc.accountNameThai)
          : isCogsCounter
          ? _lineAcct(l, (a) => a.cogs, _docSetup!.cogsAccountCode, _docSetup!.cogsAccountName, isEnglish)
          : isWipCounter
              ? (code: _docSetup!.wipAccountCode, name: _docSetup!.wipAccountName)
              : (code: _docSetup!.varianceAccountCode, name: _docSetup!.varianceAccountName);
      counterEntries.add((counter, -v * cost));
    }
    return _card(collapseKey: 'gl', glPreview: true, title: isEnglish ? 'GL Preview (Draft)' : 'ตัวอย่างรายการบัญชี (Draft)', children: [
      ..._groupedGlLines(invEntries),
      ..._groupedGlLines(counterEntries),
      if (skippedPeriodic > 0) _skippedPeriodicNote(skippedPeriodic, isEnglish),
      if (alwaysPost && _lines.any((l) => l.variance != 0 && _linePeriodic(l))) _modeSideNote(isEnglish),
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
    _ensureGlAccounts();
    _glSumReset();
    final isCredit = _isArReturnCnMode; // '35'/'40' — ลด AR (กลับทิศทางจาก DN/ใบแจ้งหนี้ปกติ)
    // ราคาขายอยู่ในสกุลเงินของเอกสาร — แปลงเป็นบาทด้วยอัตราแลกเปลี่ยน ภาษีขายคิดจากฐานเงินบาท (มิเรอร์ backend)
    // รายได้แยกตามบัญชีของแต่ละสินค้า: สินค้า → หมวดสินค้า → ประเภทเอกสาร AR (resolveRevenueAccount)
    double subtotal = 0, vat = 0;
    final revEntries = <(_Acct, double)>[];
    for (final l in _lines) {
      final a = _amt(l); // หลังส่วนลด ก่อน VAT (ราคารวม VAT แยก VAT ออกแล้ว)
      final lineSubtotal = a.net * _exchangeRate;
      subtotal += lineSubtotal;
      revEntries.add((_lineAcct(l, (a) => a.revenue, null, isEnglish ? 'Revenue' : 'รายได้', isEnglish), isCredit ? lineSubtotal : -lineSubtotal));
      vat += a.vat * _exchangeRate;
    }
    final (advLines, advReduce) = _advancePreview(isEnglish, ap: false);
    final total = subtotal + vat - advReduce;
    final vatAcctCode = _docSetup?.vatOutputAccountCode;
    final vatAcctName = isEnglish ? (_docSetup?.vatOutputAccountName ?? 'VAT Output') : (_docSetup?.vatOutputAccountName ?? 'ภาษีขาย');
    final arAcct = _arAcct(isEnglish);
    final docLabel = isCredit
        ? (isEnglish ? 'AR Credit Note' : 'ใบลดหนี้ลูกหนี้')
        : _isArDnMode
            ? (isEnglish ? 'AR Debit Note' : 'ใบเพิ่มหนี้ลูกหนี้')
            : (isEnglish ? 'AR Invoice' : 'ใบแจ้งหนี้ลูกหนี้');

    if (_status == 'Posted' && _linkedArTransactionId != null) {
      return _card(collapseKey: 'ar', glPreview: true, title: '$docLabel (${isEnglish ? 'Posted reference' : 'อ้างอิงยอดที่ Posted แล้ว'})', children: [
        _glLine(arAcct.code, arAcct.name, isCredit ? 0 : total, isCredit ? total : 0),
        ..._groupedGlLines(revEntries),
        _glLine(vatAcctCode, vatAcctName, isCredit ? vat : 0, isCredit ? 0 : vat),
        ...advLines,
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
    return _card(collapseKey: 'ar', glPreview: true, 
      title: isDeferredPending
          ? '$docLabel (${isEnglish ? 'not posted yet' : 'ยังไม่ได้ Post'})'
          : '$docLabel (Draft)',
      children: [
        _glLine(arAcct.code, arAcct.name, isCredit ? 0 : total, isCredit ? total : 0),
        ..._groupedGlLines(revEntries),
        _glLine(vatAcctCode, vatAcctName, isCredit ? vat : 0, isCredit ? 0 : vat),
        ...advLines,
        if (_lines.any((l) => _parseNum(l.discPctCtrl.text) > 0))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              isEnglish
                  ? 'Revenue is shown net of discount — if the AR document type has a discount account, revenue posts before discount and the discount posts to that account.'
                  : 'รายได้แสดงยอดหลังส่วนลด — ถ้าประเภทเอกสาร AR ปลายทางตั้งบัญชีส่วนลดไว้ รายได้จะลงยอดก่อนส่วนลดและลงส่วนลดที่บัญชีนั้น',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
            ),
          ),
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

  // ── การ์ดตัวอย่างรายการบัญชีรวม (เอกสารขายที่สร้างเอกสาร AR อัตโนมัติ) ──
  // ① ต้นทุนขาย (entry ของ IM เอง) ② ใบแจ้งหนี้/ใบลด-เพิ่มหนี้ AR ③ ใบเสร็จรับชำระ AR (ขายเงินสด) — แต่ละ entry
  // ลงบัญชีแยกกัน จึงแสดงเป็นส่วนย่อยพร้อมตรวจ Dr = Cr ของตัวเอง ยอดของการ์ดคือผลรวมทุก entry
  bool get _arLinkedPreview => _isDlnBillingMode || _isDlnDeferredMode || _isArReturnCnMode || _isArDnMode;
  bool _glSectionMode = false;
  String? _glSectionTitle; // ชื่อส่วนแทนชื่อการ์ดเดิม (ส่วนต้นทุนขาย)

  Widget _glSection(String title, List<Widget> children) {
    final hasRows = _glSumLines.any((e) => e.$3.abs() >= 0.005 || e.$4.abs() >= 0.005);
    final chip = hasRows ? _glBalanceChip(_isEnglish) : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.only(bottom: 4),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFDDE3EA)))),
        child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF33404D))),
          if (chip != null) chip,
        ]),
      ),
      ..._glTable(children),
    ]);
  }

  _Acct _arAcct(bool isEnglish) {
    final a = _glAccts?.arAccount;
    if (a != null) return (code: a.code, name: a.name(isEnglish));
    if (_glAccts == null) return (code: null, name: isEnglish ? 'Accounts Receivable' : 'ลูกหนี้การค้า');
    return (
      code: '!',
      name: isEnglish
          ? 'AR account not configured (customer / customer group / AR document type)'
          : 'ยังไม่ตั้งบัญชีลูกหนี้ (ลูกค้า / กลุ่มลูกค้า / ประเภทเอกสาร AR)',
    );
  }

  // ③ ใบเสร็จรับชำระ AR ของขายเงินสด — Dr เงินสด/ธนาคารตามวิธีรับเงิน + ภาษีถูกหัก ณ ที่จ่าย / Cr ลูกหนี้
  // (มิเรอร์ postArReceiptForCashSale) — ยอดคงค้าง 0 (มัดจำครอบคลุมทั้งหมด) = ไม่มีใบเสร็จ
  Widget? _buildCashReceiptSection(bool isEnglish) {
    _glSumReset();
    final rate = _exchangeRate;
    final dueLc = _cashDueFc * rate;
    if (dueLc <= 0.005) return null;
    final whtLc = _cash.whtTotal * rate;
    final cashLc = dueLc - whtLc;
    final accts = _glAccts?.receiptPayments ?? const <ImGlAcct?>[];
    final lines = <Widget>[];
    final paid = <int>[for (var i = 0; i < _cash.payments.length; i++) if (_cash.payments[i].amount > 0) i];
    double rest = cashLc;
    for (var k = 0; k < paid.length; k++) {
      final i = paid[k];
      final p = _cash.payments[i];
      final lc = k == paid.length - 1 ? rest : p.amount * rate; // บรรทัดสุดท้ายรับเศษปัด (เหมือน backend)
      rest -= lc;
      final a = i < accts.length ? accts[i] : null;
      final label = p.paymentMethodName ?? p.paymentMethodCode ?? p.paymentMethodType;
      lines.add(_glLine(
          a?.code ?? (_glAccts == null ? null : '!'),
          a != null
              ? '${a.name(isEnglish)} ($label)'
              : (_glAccts == null ? label : (isEnglish ? 'Receipt account not configured ($label)' : 'ยังไม่ตั้งบัญชีรับเงิน ($label)')),
          lc,
          0));
    }
    if (paid.isEmpty) {
      lines.add(_glLine(null, isEnglish ? 'Cash / bank (no payment method yet)' : 'เงินสด/ธนาคาร (ยังไม่ระบุวิธีรับชำระ)', cashLc, 0));
    }
    if (whtLc.abs() >= 0.005) {
      final w = _glAccts?.receiptWht;
      lines.add(_glLine(w?.code ?? '!',
          w?.name(isEnglish) ?? (isEnglish ? 'Withholding tax account not configured' : 'ยังไม่ตั้งบัญชีภาษีถูกหัก ณ ที่จ่าย'), whtLc, 0));
    }
    final ar = _arAcct(isEnglish);
    lines.add(_glLine(ar.code, ar.name, 0, dueLc));
    return _glSection(isEnglish ? 'AR Receipt' : 'ใบเสร็จรับชำระลูกหนี้', lines);
  }

  Widget _buildCombinedGlCard(bool isEnglish) {
    _glSectionMode = true;
    double dr = 0, cr = 0;
    final all = <(String?, String?, double, double)>[];
    final sections = <Widget>[];
    void take(Widget? w) {
      if (w == null) return;
      dr += _glSumDr;
      cr += _glSumCr;
      all.addAll(_glSumLines);
      if (sections.isNotEmpty) sections.add(const SizedBox(height: 14));
      sections.add(w);
    }

    try {
      _glSectionTitle = isEnglish ? 'Cost of sales (IM)' : 'ต้นทุนขาย (IM)';
      take(_buildGlCardInner(isEnglish));
      _glSectionTitle = null;
      take(_buildArPreviewCard(isEnglish));
      if (_isCashSaleMode) take(_buildCashReceiptSection(isEnglish));
    } finally {
      _glSectionMode = false;
      _glSectionTitle = null;
    }
    _glSumReset();
    _glSumDr = dr;
    _glSumCr = cr;
    _glSumLines.addAll(all);
    final n = _isCashSaleMode ? 3 : 2;
    return _card(
      collapseKey: 'gl',
      glPreview: true,
      title: _status == 'Posted' ? (isEnglish ? 'GL Entries' : 'รายการบัญชี') : (isEnglish ? 'GL Preview' : 'ตัวอย่างรายการบัญชี'),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            isEnglish
                ? 'Posting creates $n separate journal entries, shown as sections below. Accounts follow the current settings of the IM/AR document types, items and customer.'
                : 'เมื่อ Post ระบบลงบัญชีแยกเป็น $n รายการตามส่วนด้านล่าง — บัญชีมาจากการตั้งค่าปัจจุบันของประเภทเอกสาร IM/AR สินค้า และลูกค้า',
            style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700),
          ),
        ),
        ...sections,
      ],
    );
  }

  // ── มิติในตัวอย่างรายการบัญชี: ทุกบรรทัดใช้มิติหัวเอกสาร (ตาม backend utils/glDims.js) จึงแสดงมิติที่เลือกไว้ทุกบรรทัด ──
  // บัญชีที่บังคับมิติ (gl_account_dim_rule) แต่หัวเอกสารยังไม่เลือก = แสดง "ต้องระบุ" สีแดง + เตือนที่การ์ด + ช่องมิติในการ์ดข้อมูลเอกสาร และห้าม Post
  // เบิกใช้ ('issue') มีมิติรายบรรทัดและตรวจที่ช่องมิติของบรรทัดอยู่แล้ว จึงไม่แสดง/ไม่ตรวจซ้ำที่นี่
  final Set<String> _glDimMissing = {};
  final Set<int> _glDimMissingSlotsBuild = {};
  Set<int> _glDimMissingSlots = {};
  bool get _glDimCheck =>
      !_isIssueMode && _postedGlDetails == null && _status != 'Posted' && _status != 'Void' && _status != 'Deleted';

  String _dimTypeName(GlDimensionType t, bool isEnglish) =>
      isEnglish && (t.nameEng ?? '').isNotEmpty ? t.nameEng! : t.nameThai;

  // ช่อง "มิติ/ชื่อ": 1 บรรทัดต่อมิติ = รหัส ชื่อค่า (ชี้เมาส์ = ประเภทมิติ)
  Widget? _glLineDims(String? code) {
    final isEnglish = _isEnglish;
    Account? acc;
    if (code != null) {
      for (final a in _accounts) {
        if (a.accountCode == code) { acc = a; break; }
      }
    }
    final items = <Widget>[];
    // บัญชีบังคับสาขา (gl_account.branch_required) แต่เอกสารยังไม่มีสาขา — ทุกประเภทเอกสาร (backend ตรวจตอน Post)
    // แสดง/ตรวจเฉพาะเอกสารที่ยังไม่ Post (เอกสารเก่าที่ Post ก่อนตั้งบังคับไม่ต้องขึ้นสีแดง)
    if ((acc?.branchRequired ?? false) && _branchId == null &&
        (_glDimCheck || (_isIssueMode && _postedGlDetails == null && _status == 'Draft'))) {
      _glDimMissing.add(isEnglish ? 'Account $code requires a branch' : 'บัญชี $code ต้องระบุสาขา');
      _glDimMissingSlotsBuild.add(0);
      items.add(Text(isEnglish ? 'Branch: required' : 'สาขา: ต้องระบุ',
          style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.bold)));
    }
    if (_isIssueMode || _dimTypes.isEmpty) return items.isEmpty ? null : Column(crossAxisAlignment: CrossAxisAlignment.start, children: items);
    final req = requiredDimSlots(acc, _dimTypes);
    for (final t in _dimTypes) {
      final id = _dimSelections[t.slotNo];
      if (id != null) {
        GlDimensionValue? v;
        for (final x in _dimValues[t.typeCode] ?? const <GlDimensionValue>[]) {
          if (x.id == id) { v = x; break; }
        }
        final vName = v == null ? '#$id' : '${v.valueCode} ${isEnglish && (v.valueNameEng ?? '').isNotEmpty ? v.valueNameEng! : v.valueNameThai}';
        items.add(Tooltip(
          message: _dimTypeName(t, isEnglish),
          child: Text(vName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
        ));
      } else if (req.contains(t.slotNo)) {
        if (_glDimCheck) {
          _glDimMissing.add(isEnglish ? 'Account $code requires ${_dimTypeName(t, true)}' : 'บัญชี $code ต้องระบุ${t.nameThai}');
          _glDimMissingSlotsBuild.add(t.slotNo);
        }
        items.add(Text(isEnglish ? '${_dimTypeName(t, true)}: required' : '${t.nameThai}: ต้องระบุ',
            style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.bold)));
      }
    }
    if (items.isEmpty) return null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: items);
  }

  // ── ตารางตัวอย่างรายการบัญชี: รหัสบัญชี | ชื่อบัญชี | มิติ/ชื่อ | เดบิต | เครดิต + แถวรวม (ตามแบบ Gl.dc) ──
  static const _glColCode = 76.0;
  static const _glHeadStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4A5562));

  Widget _glCells(Widget code, Widget name, Widget? dims, Widget dr, Widget cr) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: _glColCode, child: code),
          const SizedBox(width: 8),
          Expanded(flex: 4, child: name),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: dims ?? const SizedBox.shrink()),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: dr),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: cr),
        ],
      );

  // แทรกหัวคอลัมน์ก่อนบรรทัดแรก และแถวรวมหลังบรรทัดสุดท้าย (ยอดรวม = ที่ _glLine สะสมของการ์ด/ส่วนนี้)
  List<Widget> _glTable(List<Widget> children) {
    final first = children.indexWhere((w) => w is _GlLineRow);
    if (first < 0) return children;
    final last = children.lastIndexWhere((w) => w is _GlLineRow);
    final isEnglish = _isEnglish;
    final head = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: const BoxDecoration(color: Color(0xFFF4F6F8), border: Border(bottom: BorderSide(color: Color(0xFFDDE3EA)))),
      child: _glCells(
        Text(isEnglish ? 'Account' : 'รหัสบัญชี', style: _glHeadStyle),
        Text(isEnglish ? 'Account name' : 'ชื่อบัญชี', style: _glHeadStyle),
        Text(isEnglish ? 'Dimension / name' : 'มิติ/ชื่อ', style: _glHeadStyle),
        Text(isEnglish ? 'Debit' : 'เดบิต', style: _glHeadStyle, textAlign: TextAlign.right),
        Text(isEnglish ? 'Credit' : 'เครดิต', style: _glHeadStyle, textAlign: TextAlign.right),
      ),
    );
    const bold = TextStyle(fontSize: 13, fontWeight: FontWeight.w700);
    final total = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: _glCells(
        const SizedBox.shrink(),
        Text(isEnglish ? 'Total' : 'รวม', style: bold),
        null,
        Text(_fmtMoney.format(_glSumDr), style: bold, textAlign: TextAlign.right),
        Text(_fmtMoney.format(_glSumCr), style: bold, textAlign: TextAlign.right),
      ),
    );
    return [...children.sublist(0, first), head, ...children.sublist(first, last + 1), total, ...children.sublist(last + 1)];
  }

  Widget _glLine(String? code, String? name, double debit, double credit) {
    _glSumDr += debit;
    _glSumCr += credit;
    _glSumLines.add((code, name, debit, credit));
    final dims = (debit.abs() >= 0.005 || credit.abs() >= 0.005) ? _glLineDims(code) : null;
    const st = TextStyle(fontSize: 13);
    return _GlLineRow(Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEF1F4)))),
      child: _glCells(
        Text(code ?? '-', style: st),
        Text(name ?? '', style: st),
        dims,
        Text(debit != 0 ? _fmtMoney.format(debit) : '', textAlign: TextAlign.right, style: st),
        Text(credit != 0 ? _fmtMoney.format(credit) : '', textAlign: TextAlign.right, style: st),
      ),
    ));
  }

  // ── ③ สรุปยอด: ส่วนลดท้ายบิล + หักเงินมัดจำ (ซ้าย) | ยอดไล่ลงจนถึงยอดสุทธิ (ขวา) — อยู่ต่อจากรายการ ──
  Widget _buildTotalsCard(bool isEnglish) {
    final totalQty = _lines.fold<double>(0, (s, l) => s + l.variance);
    final qtyText = _isTransferMode
        ? '${isEnglish ? 'Total transferred qty' : 'จำนวนที่โอนรวม'} ${_fmtQty.format(-totalQty)}'
        : _isReceiveMode
            ? '${isEnglish ? 'Total received qty' : 'จำนวนที่รับรวม'} ${_fmtQty.format(totalQty)}'
            : _isIssueMode
                ? '${isEnglish ? 'Total issued qty' : 'จำนวนที่เบิกรวม'} ${_fmtQty.format(-totalQty)}'
                : _isDeliverMode
                    ? '${isEnglish ? 'Total delivered qty' : 'จำนวนที่ส่งรวม'} ${_fmtQty.format(-totalQty)}'
                    : (_isApReturnCnMode || _isApDnMode || _isArReturnCnMode || _isArDnMode)
                        ? '${isEnglish ? 'Total qty' : 'จำนวนรวม'} ${_fmtQty.format(totalQty.abs())}'
                        : '${isEnglish ? 'Total variance qty' : 'จำนวนผลต่างรวม'} ${_fmtQty.format(totalQty)}';
    final qtyLine = Text('$qtyText · ${isEnglish ? '${_lines.length} line(s)' : '${_lines.length} รายการ'}',
        style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700));

    final left = <Widget>[
      if (_salesDiscountMode) _hGroup(3, isEnglish ? 'Bill discount' : 'ส่วนลดท้ายบิล', _gFin, [_billDiscountInputs(isEnglish)]),
      if (_showAdvances && _advRows.isNotEmpty) _advanceGroup(isEnglish),
    ];
    final t = _showDiscount ? _amountSums() : null;
    final cur = _currency?.currencyCode ?? '';
    final finalLabel = t == null
        ? null
        : t.adv > 0
            ? (_isApVendorMode
                ? (isEnglish ? 'Payable after deposits' : 'ยอดเจ้าหนี้หลังหักมัดจำ')
                : (isEnglish ? 'Receivable after deposits' : 'ยอดลูกหนี้หลังหักมัดจำ'))
            : (isEnglish ? 'Total' : 'ยอดรวม');
    final finalAmt = t == null ? 0.0 : t.total - t.adv;

    Widget? ladder;
    if (t != null) {
      Widget row(String label, double v, {bool line = false}) => Container(
            padding: EdgeInsets.only(top: line ? 6 : 3, bottom: 3),
            margin: EdgeInsets.only(top: line ? 2 : 0),
            decoration: line ? const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFDDE3EA)))) : null,
            child: Row(children: [
              Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF33404D)))),
              Text(_fmtMoney.format(v), style: _numStyle.copyWith(fontWeight: FontWeight.w600)),
            ]),
          );
      ladder = _hGroup(4, isEnglish ? 'Amounts ($cur)' : 'ยอดเงิน ($cur)', _gMore, [
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          row(isEnglish ? 'Amount before discount' : 'ยอดก่อนส่วนลด', t.gross),
          if (t.disc.abs() >= 0.005) row(isEnglish ? 'Discount' : 'ส่วนลด', -t.disc),
          row(isEnglish ? 'Amount before VAT' : 'ยอดก่อน VAT', t.net, line: true),
          if (_isVatMode) row('VAT', t.vat),
          if (t.adv > 0) ...[
            row(isEnglish ? 'Total' : 'ยอดรวม', t.total, line: true),
            row(isEnglish ? 'Less deposits' : 'หัก เงินมัดจำ', -t.adv),
          ],
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF1B232C), width: 2))),
            child: Row(children: [
              Expanded(child: Text(finalLabel!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
              Text('${_fmtMoney.format(finalAmt)} $cur',
                  style: _numStyle.copyWith(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF0F5C5C))),
            ]),
          ),
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerRight, child: qtyLine),
        ]),
      ]);
    }

    Widget body;
    if (left.isEmpty && ladder == null) {
      body = qtyLine;
    } else {
      final leftCol = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < left.length; i++) ...[if (i > 0) const SizedBox(height: 10), left[i]],
      ]);
      body = LayoutBuilder(builder: (context, cons) {
        if (left.isEmpty) {
          return Align(alignment: Alignment.centerRight, child: SizedBox(width: cons.maxWidth >= 900 ? cons.maxWidth * 0.42 : cons.maxWidth, child: ladder));
        }
        if (ladder == null) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [leftCol, const SizedBox(height: 8), qtyLine]);
        if (cons.maxWidth >= 900) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 5, child: leftCol),
            const SizedBox(width: 12),
            Expanded(flex: 4, child: ladder),
          ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [leftCol, const SizedBox(height: 10), ladder]);
      });
    }

    return _card(
      title: isEnglish ? 'Totals' : 'สรุปยอด',
      trailing: t == null ? null : _chip('$finalLabel ${_fmtMoney.format(finalAmt)}', const Color(0xFF1E4F8F), _hAuto),
      children: [SizedBox(width: double.infinity, child: body)],
    );
  }

  ({double gross, double disc, double net, double vat, double total, double adv}) _amountSums() {
    double gross = 0, disc = 0, net = 0, vat = 0, total = 0;
    for (final l in _lines) {
      final a = _amt(l, billed: _isGrDeferredMode);
      gross += a.gross;
      disc += a.discount;
      net += a.net;
      vat += a.vat;
      total += a.total;
    }
    return (gross: gross, disc: disc, net: net, vat: vat, total: total, adv: _showAdvances ? _advTotalFc : 0.0);
  }

  // ส่วนลดท้ายบิล — % ของยอดหลังส่วนลดรายการ แล้วตามด้วยส่วนลดเงินสด ปันส่วนเข้าแต่ละรายการตามสัดส่วนยอด
  Widget _billDiscountInputs(bool isEnglish) => Padding(
        padding: EdgeInsets.zero,
        child: Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 150,
            child: TextField(
              controller: _billDiscPctCtrl,
              readOnly: !_canEditBilling,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              decoration: _hDec(isEnglish ? 'Bill discount %' : 'ส่วนลดท้ายบิล %', editable: _canEditBilling),
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(
            width: 170,
            child: TextField(
              controller: _cashDiscCtrl,
              readOnly: !_canEditBilling,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              decoration: _hDec(isEnglish ? 'Cash discount' : 'ส่วนลดเงินสดท้ายบิล', editable: _canEditBilling),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Text(
            isEnglish ? 'Allocated to lines by amount' : 'ปันส่วนเข้าแต่ละรายการตามสัดส่วนยอด',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ]),
      );

  // ส่วนลดเกินยอด: รายการ (ขั้นบันได + เงิน) เกินยอดของรายการ / ท้ายบิล % เกิน 100 / เงินสดเกินยอดคงเหลือ
  bool _checkSalesDiscountTotals(void Function(String) warn) {
    final isEnglish = _isEnglish;
    if (_billDiscPct < 0 || _billDiscPct > 100) {
      warn(isEnglish ? 'Bill discount must be 0-100%' : 'ส่วนลดท้ายบิลต้องอยู่ระหว่าง 0-100%');
      return false;
    }
    double remaining = 0;
    for (final l in _lines) {
      if (l.isFree) continue;
      final entered = l.docQty * _parseNum(l.unitPriceCtrl.text);
      final own = entered * (1 - parseStepDiscount(l.discPctCtrl.text).factor) + _lineDiscOf(l);
      if (own > entered + 0.005) {
        warn('${l.item.itemCode}: ${isEnglish ? 'line discount exceeds the line amount' : 'ส่วนลดของรายการมากกว่ายอดของรายการ'}');
        return false;
      }
      remaining += entered - own;
    }
    remaining -= remaining * _billDiscPct / 100;
    if (_cashDisc < 0 || _cashDisc > remaining + 0.005) {
      warn(isEnglish ? 'Cash discount exceeds the remaining amount' : 'ส่วนลดเงินสดท้ายบิลมากกว่ายอดหลังส่วนลด');
      return false;
    }
    return true;
  }

  // ปุ่มที่ทำไม่ได้: ล็อกไว้ และชี้เมาส์แล้วเห็นเหตุผล
  Widget _lockable(ImDocBlock? block, Widget Function(VoidCallback? onPressed) build, VoidCallback action) =>
      block == null
          ? build(_isSaving ? null : action)
          : Tooltip(message: block.text(_isEnglish), child: build(null));

  Widget _buildActionBar(bool isEnglish) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade300))),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        TextButton(onPressed: _isSaving ? null : widget.onCancel, child: Text(isEnglish ? 'Close' : 'ปิด')),
        const SizedBox(width: 8),
        if (_status == 'Draft' && !widget.viewOnly) ...[
          if (_id != null && widget.canDelete)
            _lockable(_deleteBlock, (onPressed) => TextButton(
              onPressed: onPressed,
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(isEnglish ? 'Delete' : 'ลบ'),
            ), _delete),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _isSaving ? null : () => _save('Draft'),
            child: Text(isEnglish ? 'Save Draft' : 'บันทึกร่าง'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _isSaving ? null : _onPost,
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
        if ((_status == 'Posted' || _status == 'Received' || _status == 'Delivered') && !widget.viewOnly) ...[
          _lockable(_reverseBlock, (onPressed) => OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.orange[800]),
            child: Text(_reverseTo == 'Received' || _reverseTo == 'Delivered'
                ? (isEnglish ? 'Reverse Billing' : 'ถอยการตั้งหนี้')
                : (isEnglish ? 'Reverse to Draft' : 'ถอยเป็นร่าง')),
          ), _reverseToDraft),
          const SizedBox(width: 8),
        ],
        if ((_status == 'Posted' || _status == 'Received' || _status == 'Delivered') && !widget.viewOnly)
          _lockable(_voidBlock, (onPressed) => ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
            child: Text(isEnglish ? 'Void' : 'ยกเลิก'),
          ), _void),
        if (_isSaving) ...[
          const SizedBox(width: 12),
          const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ]),
    );
  }
}

// คอลัมน์ของตารางรายการ — width 0 = ยืดตามพื้นที่ (ชื่อสินค้า), group 1-4 = สีกลุ่ม (0 = ไม่มี)
class _LCol {
  final String key;
  final String label;
  final double width;
  final int group;
  final bool right;
  final bool required;
  const _LCol(this.key, this.label, this.width, this.group, {this.right = false, this.required = false});
}

// บรรทัดของตารางตัวอย่างรายการบัญชี — _glTable ใช้หาตำแหน่งแทรกหัวคอลัมน์/แถวรวม
class _GlLineRow extends StatelessWidget {
  const _GlLineRow(this.child);
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}
