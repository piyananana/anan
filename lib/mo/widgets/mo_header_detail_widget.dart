// lib/mo/widgets/mo_header_detail_widget.dart — รายละเอียดใบสั่งผลิต (header + ผลผลิต + ส่วนประกอบ + ขั้นตอนการผลิต)
// รูปแบบหน้ารายละเอียดเดียวกับ IM / PO (user design 2026-11-24): การ์ดข้อมูลเอกสาร 4 กลุ่มสี fix ด้านบน,
// ตารางแก้ไขในแถวได้เลย (ไม่มีหน้าต่างแก้ไขทีละบรรทัด), ความพร้อมวัตถุดิบ, แถบเบิก/รับแล้ว และการ์ดสรุปการผลิต
// MO ไม่แตะ GL/สต็อกเอง (ดู moHeaderController.js) — Draft/Rejected เท่านั้นที่แก้ไขได้
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/models/sa_document_reverse_log.dart';
import '../../sa/widgets/sa_document_reverse_widgets.dart';
import '../../sa/models/sa_doc_approval.dart';
import '../../sa/widgets/sa_doc_approval_panel.dart';
import '../../im/models/im_item.dart';
import '../../im/models/im_location.dart';
import '../../im/models/im_warehouse.dart';
import '../../im/widgets/im_item_list_widget.dart';
import '../../im/widgets/im_location_tree_widget.dart';
import '../../im/services/im_item_service.dart';
import '../../im/widgets/im_warehouse_list_widget.dart';
import '../models/mo_header.dart';
import '../models/mo_bom.dart';
import '../models/mo_work_center.dart';
import '../services/mo_header_service.dart';
import '../../gl/widgets/gl_journal_preview.dart';
import '../services/mo_bom_service.dart';
import '../widgets/mo_bom_list_widget.dart';
import '../widgets/mo_work_center_list_widget.dart';
import 'mo_uom_picker.dart';
import '../../gl/models/gl_dimension.dart';
import '../../gl/widgets/gl_line_account_dims.dart';
import '../../gl/widgets/gl_dimension_picker_field.dart';
import '../../cd/models/cd_branch.dart';
import '../../cd/services/cd_branch_service.dart';
import '../../cd/widgets/cd_user_branch_picker.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../../sa/widgets/sa_doc_list_kit.dart';

final _qtyEdit = NumberFormat('0.######');

String _uomDisplayName(String? code, String? nameTh, String? nameEn, bool isEnglish) {
  if (isEnglish && (nameEn ?? '').isNotEmpty) return nameEn!;
  if ((nameTh ?? '').isNotEmpty) return nameTh!;
  return code ?? '';
}

// ── บรรทัดในตาราง (แก้ไขในแถว) — แปลงกลับเป็น model ตอนบันทึก ──────────────────────────────────────
class _CompLine {
  int? id;
  int itemId;
  String? itemCode;
  String? itemName;
  double issuedQty;
  int? uomId;
  String? uomCode, uomNameTh, uomNameEn;
  int? locationId;
  String? locationCode, locationName;
  bool hasBom;
  final TextEditingController qtyCtrl;
  final TextEditingController remarkCtrl;

  _CompLine({
    this.id,
    required this.itemId,
    this.itemCode,
    this.itemName,
    this.issuedQty = 0,
    this.uomId,
    this.uomCode,
    this.uomNameTh,
    this.uomNameEn,
    this.locationId,
    this.locationCode,
    this.locationName,
    this.hasBom = false,
    double qty = 0,
    String? remark,
  })  : qtyCtrl = TextEditingController(text: _qtyEdit.format(qty)),
        remarkCtrl = TextEditingController(text: remark ?? '');

  factory _CompLine.of(MoComponentDetail c) => _CompLine(
        id: c.id,
        itemId: c.componentItemId,
        itemCode: c.itemCode,
        itemName: c.itemName,
        issuedQty: c.issuedQty,
        uomId: c.uomId,
        uomCode: c.uomCode,
        uomNameTh: c.uomNameTh,
        uomNameEn: c.uomNameEn,
        locationId: c.locationId,
        locationCode: c.locationCode,
        locationName: c.locationName,
        hasBom: c.hasBom,
        qty: c.plannedQty,
        remark: c.remark,
      );

  double get qty => double.tryParse(qtyCtrl.text) ?? 0;

  MoComponentDetail toModel(int lineNo) => MoComponentDetail(
        id: id,
        lineNo: lineNo,
        componentItemId: itemId,
        itemCode: itemCode,
        itemName: itemName,
        plannedQty: qty,
        issuedQty: issuedQty,
        uomId: uomId,
        uomCode: uomCode,
        uomNameTh: uomNameTh,
        uomNameEn: uomNameEn,
        locationId: locationId,
        locationCode: locationCode,
        remark: remarkCtrl.text.trim().isEmpty ? null : remarkCtrl.text.trim(),
      );

  void dispose() {
    qtyCtrl.dispose();
    remarkCtrl.dispose();
  }
}

class _OutLine {
  int? id;
  int itemId;
  String? itemCode;
  String? itemName;
  double receivedQty;
  int? uomId;
  String? uomCode, uomNameTh, uomNameEn;
  bool isPrimary;
  final TextEditingController qtyCtrl;
  final TextEditingController remarkCtrl;

  _OutLine({
    this.id,
    required this.itemId,
    this.itemCode,
    this.itemName,
    this.receivedQty = 0,
    this.uomId,
    this.uomCode,
    this.uomNameTh,
    this.uomNameEn,
    this.isPrimary = false,
    double qty = 0,
    String? remark,
  })  : qtyCtrl = TextEditingController(text: _qtyEdit.format(qty)),
        remarkCtrl = TextEditingController(text: remark ?? '');

  factory _OutLine.of(MoOutputDetail o) => _OutLine(
        id: o.id,
        itemId: o.outputItemId,
        itemCode: o.itemCode,
        itemName: o.itemName,
        receivedQty: o.receivedQty,
        uomId: o.uomId,
        uomCode: o.uomCode,
        uomNameTh: o.uomNameTh,
        uomNameEn: o.uomNameEn,
        isPrimary: o.isPrimaryOutput,
        qty: o.plannedQty,
        remark: o.remark,
      );

  double get qty => double.tryParse(qtyCtrl.text) ?? 0;

  MoOutputDetail toModel(int lineNo) => MoOutputDetail(
        id: id,
        lineNo: lineNo,
        outputItemId: itemId,
        itemCode: itemCode,
        itemName: itemName,
        plannedQty: qty,
        receivedQty: receivedQty,
        uomId: uomId,
        uomCode: uomCode,
        uomNameTh: uomNameTh,
        uomNameEn: uomNameEn,
        isPrimaryOutput: isPrimary,
        remark: remarkCtrl.text.trim().isEmpty ? null : remarkCtrl.text.trim(),
      );

  void dispose() {
    qtyCtrl.dispose();
    remarkCtrl.dispose();
  }
}

class _OpLine {
  int? id;
  int workCenterId;
  String? workCenterCode, workCenterNameTh, workCenterNameEn;
  double actualLaborHours;
  double actualMachineHours;
  String status;
  final TextEditingController nameCtrl;
  final TextEditingController laborCtrl;
  final TextEditingController machineCtrl;

  _OpLine({
    this.id,
    required this.workCenterId,
    this.workCenterCode,
    this.workCenterNameTh,
    this.workCenterNameEn,
    this.actualLaborHours = 0,
    this.actualMachineHours = 0,
    this.status = 'Pending',
    String? name,
    double labor = 0,
    double machine = 0,
  })  : nameCtrl = TextEditingController(text: name ?? ''),
        laborCtrl = TextEditingController(text: _qtyEdit.format(labor)),
        machineCtrl = TextEditingController(text: _qtyEdit.format(machine));

  factory _OpLine.of(MoOperationDetail op) => _OpLine(
        id: op.id,
        workCenterId: op.workCenterId,
        workCenterCode: op.workCenterCode,
        workCenterNameTh: op.workCenterNameTh,
        workCenterNameEn: op.workCenterNameEn,
        actualLaborHours: op.actualLaborHours,
        actualMachineHours: op.actualMachineHours,
        status: op.status,
        name: op.operationName,
        labor: op.plannedLaborHours,
        machine: op.plannedMachineHours,
      );

  double get labor => double.tryParse(laborCtrl.text) ?? 0;
  double get machine => double.tryParse(machineCtrl.text) ?? 0;

  MoOperationDetail toModel(int lineNo) => MoOperationDetail(
        id: id,
        lineNo: lineNo,
        workCenterId: workCenterId,
        workCenterCode: workCenterCode,
        workCenterNameTh: workCenterNameTh,
        workCenterNameEn: workCenterNameEn,
        operationName: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
        plannedLaborHours: labor,
        plannedMachineHours: machine,
        actualLaborHours: actualLaborHours,
        actualMachineHours: actualMachineHours,
        status: status,
      );

  void dispose() {
    nameCtrl.dispose();
    laborCtrl.dispose();
    machineCtrl.dispose();
  }
}

class MoHeaderDetailWidget extends StatefulWidget {
  final int? transactionId;
  final bool viewOnly;
  final int resetKey;
  final VoidCallback onSaveSuccess;
  final VoidCallback onCancel;
  final bool canDelete;
  /// ปุ่มของเอกสารแสดงบน AppBar ของหน้าจอแม่ (แทนแถบปุ่มเดิม)
  final DocAppBarActions? actions;

  const MoHeaderDetailWidget({
    super.key,
    required this.transactionId,
    this.viewOnly = false,
    this.resetKey = 0,
    required this.onSaveSuccess,
    required this.onCancel,
    this.canDelete = true,
    this.actions,
  });

  @override
  State<MoHeaderDetailWidget> createState() => _MoHeaderDetailWidgetState();
}

class _MoHeaderDetailWidgetState extends State<MoHeaderDetailWidget> implements DocAppBarActionsHost {
  final _service = MoHeaderService();
  final _bomService = MoBomService();
  final _fmt = NumberFormat('#,##0.00');
  final _fmtQty = NumberFormat('#,##0.####');
  final _dateFmt = DateFormat('dd/MM/yyyy');
  bool _isEnglish = false;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isLoadingBom = false;
  bool _headerExpanded = true;

  int? _id;
  int? _docId;
  String _docNo = 'AUTO';
  DateTime _docDate = DateTime.now();
  DateTime? _dueDate;
  String _status = 'Draft';
  String? _cancelReason;
  DocActions _actions = const DocActions();
  String? _approvalMode;
  List<DocApprovalStep> _approvals = const [];
  String? _parentMoDocNo;
  double _wipBalanceLc = 0;
  MoCostSummary _cost = const MoCostSummary();

  int? _bomHeaderId; String? _bomVersion; String? _bomParentItemCode; String? _bomParentItemName;
  ImWarehouse? _warehouse;
  late TextEditingController _orderQtyCtrl;
  int? _uomId; String? _uomCode; String? _uomName;
  String _issueMethod = 'EXPLICIT';
  String _costingMethod = 'ACTUAL';
  String _costingMode = 'OVERHEAD_PERCENT';
  late TextEditingController _overheadPercentCtrl;
  final _descCtrl = TextEditingController();
  // มิติหัวเอกสาร — user-approved 2026-11-02
  List<GlDimensionType> _dimTypes = [];
  Map<String, List<GlDimensionValue>> _dimValues = {};
  Map<int, int?> _dimSelections = {};
  bool _dimsLoaded = false;
  // สาขา (user-approved 2026-11-18): ค่าเริ่มต้น สาขาของผู้ใช้ → สาขาของคลัง; รายการบัญชีของใบสั่งผลิตลงสาขานี้
  int? _branchId;
  List<Branch> _branches = [];

  static const _moSysDocType = '10';
  List<ModuleDocument> _allowedDocTypes = [];
  ModuleDocument? _docType;

  List<_CompLine> _components = [];
  List<_OutLine> _outputs = [];
  List<_OpLine> _operations = [];
  // คงเหลือในคลังต่อบรรทัดส่วนประกอบที่บันทึกแล้ว (id → จำนวนในหน่วยของบรรทัด) จาก API ตรวจวัตถุดิบพร้อมผลิต
  Map<int, double>? _available;

  // Rejected แก้ไขแล้วส่งขออนุมัติใหม่ได้เหมือน Draft
  bool get _isEditable => ['Draft', 'Rejected'].contains(_status);
  bool get _isReadOnly => widget.viewOnly || !_isEditable;
  bool get _showProgress =>
      !['Draft', 'Rejected', 'Submitted'].contains(_status) ||
      _components.any((c) => c.issuedQty > 0) ||
      _outputs.any((o) => o.receivedQty > 0);

  @override
  void initState() {
    super.initState();
    widget.actions?.attach(this);
    _orderQtyCtrl = TextEditingController(text: '1');
    _overheadPercentCtrl = TextEditingController(text: '0');
    _load();
  }

  @override
  void didUpdateWidget(covariant MoHeaderDetailWidget old) {
    super.didUpdateWidget(old);
    if (widget.actions != old.actions) {
      old.actions?.detach(this);
      widget.actions?.attach(this);
    }
    if (widget.transactionId != old.transactionId || widget.resetKey != old.resetKey) {
      _load();
    }
  }

  @override
  void dispose() {
    widget.actions?.detach(this);
    _orderQtyCtrl.dispose();
    _overheadPercentCtrl.dispose();
    _descCtrl.dispose();
    for (final l in _components) {
      l.dispose();
    }
    for (final l in _outputs) {
      l.dispose();
    }
    for (final l in _operations) {
      l.dispose();
    }
    super.dispose();
  }

  // แทนที่รายการทั้งหมด — controller เดิมทิ้งหลังเฟรมนี้ (ช่องในตารางยังผูกอยู่จนกว่าจะ build ใหม่)
  void _replaceLines(List<_CompLine> comps, List<_OutLine> outs, List<_OpLine> ops) {
    final old = [..._components, ..._outputs, ..._operations];
    _components = comps;
    _outputs = outs;
    _operations = ops;
    if (old.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final l in old) {
          (l as dynamic).dispose();
        }
      });
    }
  }

  void _resetForm() {
    _id = null;
    _docType = _allowedDocTypes.isNotEmpty ? _allowedDocTypes.first : null;
    _docId = _docType?.id;
    _docNo = 'AUTO';
    _docDate = DateTime.now();
    _dueDate = null;
    _status = 'Draft';
    _cancelReason = null;
    _actions = const DocActions();
    _approvalMode = null;
    _approvals = const [];
    _parentMoDocNo = null;
    _wipBalanceLc = 0;
    _cost = const MoCostSummary();
    _bomHeaderId = null; _bomVersion = null; _bomParentItemCode = null; _bomParentItemName = null;
    _warehouse = null;
    _orderQtyCtrl.text = '1';
    _uomId = null; _uomCode = null; _uomName = null;
    _issueMethod = 'EXPLICIT';
    _costingMethod = 'ACTUAL';
    _costingMode = 'OVERHEAD_PERCENT';
    _overheadPercentCtrl.text = '0';
    _descCtrl.clear();
    _dimSelections = {};
    _branchId = defaultDocBranchId();
    _available = null;
    _replaceLines([], [], []);
  }

  Future<void> _load() async {
    final isEnglish = _isEnglish;
    setState(() => _isLoading = true);
    try {
      if (_allowedDocTypes.isEmpty) {
        final docTypes = await _service.fetchDocTypesByUser();
        _allowedDocTypes = docTypes.where((d) => d.isDocType && d.sysDocType == _moSysDocType).toList();
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
      if (widget.transactionId == null) {
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
        _status = h.status;
        _cancelReason = h.cancelReason;
        _actions = h.actions;
        _approvalMode = h.approvalMode;
        _approvals = h.approvals;
        _parentMoDocNo = h.parentMoDocNo;
        _wipBalanceLc = h.wipBalanceLc;
        _cost = h.costSummary;
        _bomHeaderId = h.bomHeaderId; _bomVersion = h.bomVersion;
        _bomParentItemCode = h.bomParentItemCode;
        _bomParentItemName = isEnglish && (h.bomParentItemNameEn ?? '').isNotEmpty ? h.bomParentItemNameEn : h.bomParentItemNameTh;
        _warehouse = ImWarehouse(id: h.warehouseId, warehouseCode: h.warehouseCode ?? '', warehouseNameTh: h.warehouseNameTh ?? '', warehouseNameEn: h.warehouseNameEn);
        _orderQtyCtrl.text = _qtyEdit.format(h.orderQty);
        _uomId = h.uomId; _uomCode = h.uomCode;
        _uomName = isEnglish && (h.uomNameEn ?? '').isNotEmpty ? h.uomNameEn : h.uomNameTh;
        _issueMethod = h.issueMethod;
        _costingMethod = h.costingMethod;
        _costingMode = h.costingMode;
        _overheadPercentCtrl.text = _qtyEdit.format(h.overheadPercent);
        _descCtrl.text = h.description ?? '';
        _dimSelections = {1: h.dim1Id, 2: h.dim2Id, 3: h.dim3Id, 4: h.dim4Id, 5: h.dim5Id};
        _branchId = h.branchId;
        _replaceLines(
          h.components.map(_CompLine.of).toList(),
          h.outputs.map(_OutLine.of).toList(),
          h.operations.map(_OpLine.of).toList(),
        );
        _available = null;
        _loadAvailability();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _markClean();
    }
  }

  // คงเหลือในคลังปลายทางของส่วนประกอบ (API ตรวจวัตถุดิบพร้อมผลิต) — ปิด/ยกเลิก/ลบแล้วไม่ต้องตรวจ
  Future<void> _loadAvailability() async {
    final id = _id;
    if (id == null || ['Closed', 'Cancelled', 'Deleted'].contains(_status)) return;
    try {
      final a = await _service.checkMaterialAvailability(id);
      if (!mounted || _id != id) return;
      setState(() => _available = {for (final l in a.lines) l.id: l.availableQty});
    } catch (_) {}
  }

  double? _availableOf(_CompLine c) => c.id == null ? null : _available?[c.id!];

  // จำนวนที่ขาด = ยังต้องเบิก (ตามจำนวนในช่องตอนนี้) − คงเหลือในคลัง
  double? _shortOf(_CompLine c) {
    final av = _availableOf(c);
    if (av == null) return null;
    final s = c.qty - c.issuedQty - av;
    return s > 0.0001 ? s : 0;
  }

  int get _shortCount => _components.where((c) => (_shortOf(c) ?? 0) > 0).length;

  Future<void> _pickBom() async {
    await MoBomListWidget.search(context, onSelected: (MoBomHeader h) {
      setState(() {
        _bomHeaderId = h.id; _bomVersion = h.bomVersion;
        _bomParentItemCode = h.parentItemCode;
        _bomParentItemName = _isEnglish && (h.parentItemNameEn ?? '').isNotEmpty ? h.parentItemNameEn : h.parentItemNameTh;
      });
    });
    if (_bomHeaderId != null && _components.isEmpty && _outputs.isEmpty) {
      await _loadFromBom();
    }
  }

  // โหลด/สเกลส่วนประกอบ+ผลผลิต+ขั้นตอนการผลิตจากสูตรที่เลือก ตาม order_qty/bom_qty — ถ้ามีรายการอยู่แล้วต้องยืนยัน
  // ก่อนแทนที่ (กันพลาดทับรายการที่ผู้ใช้แก้ไขเองไปแล้ว) ชม. ติดตั้ง (setup_hours) ของสูตรรวมเข้ากับ
  // planned_labor_hours ตรงนี้เลย (คงที่ต่อใบสั่งผลิต ไม่ scale) เพราะ mo_operation_detail ไม่มีคอลัมน์แยกสำหรับมัน
  Future<void> _loadFromBom() async {
    if (_bomHeaderId == null) return;
    final isEnglish = _isEnglish;
    if (_components.isNotEmpty || _outputs.isNotEmpty || _operations.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isEnglish ? 'Reload from BOM?' : 'โหลดจากสูตรใหม่?'),
          content: Text(isEnglish
              ? 'This replaces all current components/outputs/operations with the BOM\'s lines, scaled to the order qty.'
              : 'การทำนี้จะแทนที่ส่วนประกอบ/ผลผลิต/ขั้นตอนการผลิตทั้งหมดที่มีอยู่ ด้วยรายการจากสูตร (ปรับตามจำนวนที่สั่งผลิต)'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEnglish ? 'Replace' : 'แทนที่')),
          ],
        ),
      );
      if (confirm != true) return;
    }
    setState(() => _isLoadingBom = true);
    try {
      final bom = await _bomService.fetchRow(_bomHeaderId!);
      // หน่วยสั่งผลิตอาจต่างจากหน่วยผลผลิตของสูตร (เช่น สั่งเป็นชิ้น สูตรเป็นลัง) — สเกลด้วยจำนวนหน่วยหลัก
      // หน่วยสั่งผลิตที่ไม่อนุญาตให้ผลิตของสินค้านี้ (หรือยังไม่เลือก) = ใช้หน่วยผลผลิตของสูตร
      final units = (await ImItemService().fetchItemUoms(bom.parentItemId, purpose: 'PRODUCTION')).units;
      ImItemUomOption? unitOf(int? id) {
        for (final u in units) {
          if (id == null ? u.isBase : u.uomId == id) return u;
        }
        return null;
      }
      final bomUnit = unitOf(bom.outputUomId);
      final orderUnit = (_uomId != null ? unitOf(_uomId) : null) ?? bomUnit;
      final outFactor = bomUnit?.factor ?? 1;
      final orderFactor = orderUnit?.factor ?? outFactor;
      var orderQty = double.tryParse(_orderQtyCtrl.text) ?? 0;
      if (orderQty <= 0) {
        orderQty = bom.bomQty * outFactor / orderFactor;
        _orderQtyCtrl.text = _qtyEdit.format(orderQty);
      }
      final scale = bom.bomQty == 0 ? 1.0 : orderQty * orderFactor / (bom.bomQty * outFactor);

      final newComponents = bom.details.map((d) => _CompLine(
            itemId: d.componentItemId,
            itemCode: d.componentItemCode,
            itemName: isEnglish && (d.componentItemNameEn ?? '').isNotEmpty ? d.componentItemNameEn : d.componentItemNameTh,
            qty: d.quantityPer * scale * (1 + d.scrapPercent / 100),
            uomId: d.uomId, uomCode: d.uomCode, uomNameTh: d.uomNameTh, uomNameEn: d.uomNameEn,
          )).toList();

      final newOutputs = <_OutLine>[
        _OutLine(
          itemId: bom.parentItemId,
          itemCode: bom.parentItemCode,
          itemName: isEnglish && (bom.parentItemNameEn ?? '').isNotEmpty ? bom.parentItemNameEn : bom.parentItemNameTh,
          qty: orderQty,
          uomId: orderUnit?.uomId ?? bom.outputUomId,
          uomCode: orderUnit?.uomCode ?? bom.outputUomCode,
          uomNameTh: orderUnit != null ? orderUnit.uomNameTh : bom.outputUomNameTh,
          uomNameEn: orderUnit != null ? orderUnit.uomNameEn : bom.outputUomNameEn,
          isPrimary: true,
        ),
        ...bom.outputs.map((o) => _OutLine(
              itemId: o.outputItemId,
              itemCode: o.outputItemCode,
              itemName: isEnglish && (o.outputItemNameEn ?? '').isNotEmpty ? o.outputItemNameEn : o.outputItemNameTh,
              qty: o.outputQtyPer * scale,
              uomId: o.uomId, uomCode: o.uomCode, uomNameTh: o.uomNameTh, uomNameEn: o.uomNameEn,
            )),
      ];

      final newOperations = bom.operations.map((op) => _OpLine(
            workCenterId: op.workCenterId,
            workCenterCode: op.workCenterCode,
            workCenterNameTh: op.workCenterNameTh,
            workCenterNameEn: op.workCenterNameEn,
            name: op.operationName,
            labor: op.standardLaborHours * scale + op.setupHours,
            machine: op.standardMachineHours * scale,
          )).toList();

      setState(() {
        _replaceLines(newComponents, newOutputs, newOperations);
        _issueMethod = bom.issueMethod;
        _costingMethod = bom.costingMethod;
        _costingMode = bom.costingMode;
        _overheadPercentCtrl.text = _qtyEdit.format(bom.overheadPercent);
        if (orderUnit != null) {
          _uomId = orderUnit.uomId;
          _uomCode = orderUnit.uomCode;
          _uomName = orderUnit.displayName(isEnglish);
        } else if (_uomId == null) {
          _uomId = bom.outputUomId;
          _uomCode = bom.outputUomCode;
          _uomName = isEnglish && (bom.outputUomNameEn ?? '').isNotEmpty ? bom.outputUomNameEn : bom.outputUomNameTh;
        }
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Failed to load BOM: $e' : 'โหลดสูตรล้มเหลว: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingBom = false);
    }
  }

  // หน่วยสั่งผลิต = หน่วยของสินค้าผลผลิตหลักที่อนุญาตให้ใช้ผลิต
  Future<void> _pickUom() async {
    final isEnglish = _isEnglish;
    final primary = _outputs.where((o) => o.isPrimary).firstOrNull ?? _outputs.firstOrNull;
    final o = await pickProductionUom(context, primary?.itemId, isEnglish);
    if (o == null || !mounted) return;
    setState(() { _uomId = o.uomId; _uomCode = o.uomCode; _uomName = o.displayName(isEnglish); });
  }

  String _itemLabel(ImItem i) => _isEnglish && (i.itemNameEn ?? '').isNotEmpty ? i.itemNameEn! : i.itemNameTh;

  // ── เพิ่ม/เปลี่ยนรายการ: เลือกสินค้า/ศูนย์งานตอนกดเพิ่ม แล้วกรอกต่อในแถว ─────────────────────────────────
  void _addComponent() => ImItemListWidget.search(context, onSelected: (ImItem i) {
        setState(() => _components.add(_CompLine(
              itemId: i.id!, itemCode: i.itemCode, itemName: _itemLabel(i), qty: 1,
              uomId: i.baseUomId, uomCode: i.baseUomCode, uomNameTh: i.baseUomNameTh, uomNameEn: i.baseUomNameEn,
            )));
      });

  void _changeComponentItem(_CompLine l) => ImItemListWidget.search(context, onSelected: (ImItem i) {
        setState(() {
          l.itemId = i.id!; l.itemCode = i.itemCode; l.itemName = _itemLabel(i); l.hasBom = false;
          // เปลี่ยนสินค้าแล้วหน่วยเดิมอาจไม่ใช่หน่วยของสินค้าใหม่ — ตั้งเป็นหน่วยหลักของสินค้าใหม่
          l.uomId = i.baseUomId; l.uomCode = i.baseUomCode; l.uomNameTh = i.baseUomNameTh; l.uomNameEn = i.baseUomNameEn;
        });
      });

  void _addOutput() => ImItemListWidget.search(context, itemTypeFilter: 'STOCK', onSelected: (ImItem i) {
        setState(() => _outputs.add(_OutLine(
              itemId: i.id!, itemCode: i.itemCode, itemName: _itemLabel(i), qty: 1,
              uomId: i.baseUomId, uomCode: i.baseUomCode, uomNameTh: i.baseUomNameTh, uomNameEn: i.baseUomNameEn,
              isPrimary: !_outputs.any((o) => o.isPrimary),
            )));
      });

  void _changeOutputItem(_OutLine l) => ImItemListWidget.search(context, itemTypeFilter: 'STOCK', onSelected: (ImItem i) {
        setState(() {
          l.itemId = i.id!; l.itemCode = i.itemCode; l.itemName = _itemLabel(i);
          l.uomId = i.baseUomId; l.uomCode = i.baseUomCode; l.uomNameTh = i.baseUomNameTh; l.uomNameEn = i.baseUomNameEn;
        });
      });

  void _addOperation() => MoWorkCenterListWidget.search(context, onSelected: (MoWorkCenter w) {
        setState(() => _operations.add(_OpLine(
              workCenterId: w.id, workCenterCode: w.workCenterCode, workCenterNameTh: w.workCenterNameTh, workCenterNameEn: w.workCenterNameEn,
            )));
      });

  void _changeWorkCenter(_OpLine l) => MoWorkCenterListWidget.search(context, onSelected: (MoWorkCenter w) {
        setState(() {
          l.workCenterId = w.id; l.workCenterCode = w.workCenterCode;
          l.workCenterNameTh = w.workCenterNameTh; l.workCenterNameEn = w.workCenterNameEn;
        });
      });

  Future<void> _pickLineUom(int itemId, void Function(ImItemUomOption) apply) async {
    final o = await pickProductionUom(context, itemId, _isEnglish);
    if (o != null && mounted) setState(() => apply(o));
  }

  void _pickLocation(_CompLine l) {
    if (_warehouse == null) {
      _warn(_isEnglish ? 'Select the warehouse first' : 'กรุณาเลือกคลังก่อน');
      return;
    }
    ImLocationTreeWidget.search(context, warehouseId: _warehouse!.id, onSelected: (ImLocation loc) {
      setState(() {
        l.locationId = loc.id;
        l.locationCode = loc.locationCode;
        l.locationName = _isEnglish && (loc.locationNameEn ?? '').isNotEmpty ? loc.locationNameEn : loc.locationName;
      });
    });
  }

  void _removeLine<T>(List<T> list, int i) => setState(() {
        final removed = list.removeAt(i);
        WidgetsBinding.instance.addPostFrameCallback((_) => (removed as dynamic).dispose());
      });

  // ข้อมูลที่บันทึก — ใช้ทั้งตอนบันทึกและตรวจการแก้ไขค้าง
  ({MoHeader header, List<MoComponentDetail> components, List<MoOutputDetail> outputs, List<MoOperationDetail> operations}) _savePayload() {
    final header = MoHeader(
      id: _id ?? 0, docId: _docId ?? 0, docNo: _docNo, docDate: _docDate,
      bomHeaderId: _bomHeaderId, warehouseId: _warehouse!.id, orderQty: double.tryParse(_orderQtyCtrl.text) ?? 0, uomId: _uomId,
      issueMethod: _issueMethod, costingMethod: _costingMethod, costingMode: _costingMode,
      overheadPercent: double.tryParse(_overheadPercentCtrl.text) ?? 0,
      dueDate: _dueDate, description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      dim1Id: _dimSelections[1], dim2Id: _dimSelections[2], dim3Id: _dimSelections[3],
      dim4Id: _dimSelections[4], dim5Id: _dimSelections[5],
      branchId: _branchId,
    );
    return (
      header: header,
      components: [for (var i = 0; i < _components.length; i++) _components[i].toModel(i + 1)],
      outputs: [for (var i = 0; i < _outputs.length; i++) _outputs[i].toModel(i + 1)],
      // ขั้นตอนการผลิตใช้เฉพาะต้นทุนแปรรูปแบบตามขั้นตอน (แบบอื่นซ่อนการ์ดไว้ — ยังเก็บรายการไว้เหมือนเดิม)
      operations: [for (var i = 0; i < _operations.length; i++) _operations[i].toModel(i + 1)],
    );
  }

  Future<void> _save() async {
    final isEnglish = _isEnglish;
    if (_docType == null) { _warn(isEnglish ? 'Please select a document type' : 'กรุณาเลือกประเภทเอกสาร'); return; }
    if (_warehouse == null) { _warn(isEnglish ? 'Please select a warehouse' : 'กรุณาระบุคลังปลายทาง'); return; }
    final orderQty = double.tryParse(_orderQtyCtrl.text) ?? 0;
    if (orderQty <= 0) { _warn(isEnglish ? 'Please enter an order qty greater than 0' : 'กรุณาระบุจำนวนที่สั่งผลิตให้มากกว่า 0'); return; }
    if (_components.isEmpty) { _warn(isEnglish ? 'At least 1 component is required' : 'ต้องมีส่วนประกอบอย่างน้อย 1 รายการ'); return; }
    if (_outputs.isEmpty) { _warn(isEnglish ? 'At least 1 output is required' : 'ต้องมีผลผลิตอย่างน้อย 1 รายการ'); return; }
    if (_components.any((c) => c.qty <= 0) || _outputs.any((o) => o.qty <= 0)) {
      _warn(isEnglish ? 'Every component and output needs a qty greater than 0' : 'ทุกบรรทัดส่วนประกอบและผลผลิตต้องมีจำนวนมากกว่า 0');
      return;
    }
    if (!_outputs.any((o) => o.isPrimary)) setState(() => _outputs.first.isPrimary = true);
    setState(() => _isSaving = true);
    try {
      final p = _savePayload();
      if (_id == null) {
        await _service.createTransaction(header: p.header, components: p.components, outputs: p.outputs, operations: p.operations);
      } else {
        await _service.updateTransaction(id: _id!, header: p.header, components: p.components, outputs: p.outputs, operations: p.operations);
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

  Future<void> _confirmAction(String titleTh, String titleEn, String bodyTh, String bodyEn, Future<MoHeader> Function() action,
      {Widget? extra}) async {
    final isEnglish = _isEnglish;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEnglish ? titleEn : titleTh),
        content: extra == null
            ? Text(isEnglish ? bodyEn : bodyTh)
            : SizedBox(
                width: 640,
                child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(isEnglish ? bodyEn : bodyTh),
                    const SizedBox(height: 12),
                    extra,
                  ]),
                ),
              ),
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

  // ปิดใบสั่งผลิต — แสดงรายการปรับ WIP ที่จะลงบัญชี (คำนวณจาก backend ด้วยฟังก์ชันเดียวกับตอนปิดจริง) ก่อนยืนยัน
  Future<void> _closeMo() async {
    final isEnglish = _isEnglish;
    Widget extra;
    try {
      final p = await _service.fetchClosePreview(_id!);
      final missing = (p[isEnglish ? 'missing_en' : 'missing'] as List? ?? const []).cast<String>();
      final lines = GlJournalLine.listFromJson(p['lines']);
      extra = GlJournalPreview(
        lines: lines,
        isEnglish: isEnglish,
        error: missing.isNotEmpty
            ? (isEnglish
                ? 'The manufacturing order document type has no ${missing.join(', ')} — set it in MO GL Account Setup before closing.'
                : 'ประเภทเอกสารใบสั่งผลิตยังไม่ได้ตั้ง ${missing.join(', ')} — ตั้งค่าที่หน้าตั้งค่าบัญชีใบสั่งผลิตก่อนปิด')
            : null,
        note: lines.isEmpty && missing.isEmpty
            ? (isEnglish ? 'WIP balance is zero — no journal entry.' : 'ยอด WIP คงเหลือเป็นศูนย์ — ไม่มีรายการบัญชี')
            : null,
      );
    } catch (e) {
      extra = Text('Error: $e', style: const TextStyle(color: Colors.red));
    }
    if (!mounted) return;
    await _confirmAction(
      'ยืนยันปิดใบสั่งผลิต', 'Close Manufacturing Order',
      'ปิดใบสั่งผลิตนี้? ยอดคงเหลือ WIP ที่เหลืออยู่ (ถ้ามี) จะถูกปรับปรุงเข้าบัญชีผลต่างต้นทุนการผลิต และจะเบิก/รับ/บันทึกเวลาเพิ่มไม่ได้อีก',
      'Close this MO? Any remaining WIP balance will be posted to the manufacturing cost variance account, and no further issue/receipt/time log will be allowed.',
      () => _service.closeTransaction(_id!),
      extra: extra,
    );
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
      title: fromClosed ? (isEnglish ? 'Reverse MO Closing' : 'ถอยการปิดใบสั่งผลิต') : (isEnglish ? 'Reverse to Draft' : 'ถอยเป็นร่าง'),
      message: fromClosed
          ? (isEnglish
              ? 'Reopen this MO (back to Completed)? The WIP adjustment entry is removed if its period is still open; otherwise a reversing entry is posted today. Issues/receipts can then be reversed again.'
              : 'ถอยการปิดใบสั่งผลิตนี้ (กลับเป็นผลิตครบแล้ว)? รายการปรับ WIP จะถูกลบถ้างวดยังเปิด ไม่เช่นนั้นระบบลงรายการกลับในวันนี้ หลังถอยแล้วถอยเอกสารเบิก/รับได้อีกครั้ง')
          : (isEnglish
              ? 'Reverse this MO to draft? Pending approvals are skipped. You can edit it and submit it again with the same number.'
              : 'ถอยใบสั่งผลิตนี้เป็นร่าง? ผู้อนุมัติที่ยังไม่ตัดสินจะถูกข้าม แก้ไขแล้วส่งขออนุมัติใหม่ได้ด้วยเลขที่เดิม'),
      confirmLabel: fromClosed ? (isEnglish ? 'Reverse Closing' : 'ถอยการปิด') : (isEnglish ? 'Reverse to Draft' : 'ถอยเป็นร่าง'),
      color: Colors.orange[800]!,
      action: (r) => _service.reverseTransaction(_id!, r),
    );
  }

  void _cancelMo() {
    final isEnglish = _isEnglish;
    _reasonAction(
      title: isEnglish ? 'Cancel Manufacturing Order' : 'ยกเลิกใบสั่งผลิต',
      message: isEnglish
          ? 'Cancel this MO? It will no longer be usable for issues/receipts.'
          : 'ยกเลิกใบสั่งผลิตนี้? จะใช้เบิก/รับไม่ได้อีก',
      confirmLabel: isEnglish ? 'Cancel MO' : 'ยกเลิกใบสั่งผลิต',
      color: Colors.red[700]!,
      action: (r) => _service.cancelTransaction(_id!, r),
    );
  }

  void _deleteMo() {
    final isEnglish = _isEnglish;
    _reasonAction(
      title: isEnglish ? 'Delete Draft' : 'ลบร่าง',
      message: isEnglish
          ? 'Delete this draft? It will be kept as Deleted for audit and cannot be used again.'
          : 'ลบร่างใบสั่งผลิตนี้? ระบบเก็บไว้ด้วยสถานะ "ลบแล้ว" เพื่อตรวจสอบ และนำกลับมาใช้ไม่ได้',
      confirmLabel: isEnglish ? 'Delete' : 'ลบ',
      color: Colors.red[700]!,
      action: (r) => _service.deleteTransaction(_id!, r),
      closeAfter: true,
    );
  }

  // ── ปุ่มของเอกสาร (แสดงบน AppBar ของหน้าจอ) — ปุ่มที่ทำไม่ได้: ล็อกและแสดงเหตุผลเมื่อชี้เมาส์ ──
  List<DocBarAction> _barActions(BuildContext context, bool en) {
    final perm = MenuScope.of(context);
    final canApprove = perm?.canApprove ?? false;
    final busy = _isSaving;
    VoidCallback? guard(DocBlock? b, VoidCallback f) => b != null || busy ? null : f;
    final canSubmit = _isEditable && _id != null && !widget.viewOnly && perm?.id != null;
    final a = <DocBarAction>[];
    if (_isEditable && _id != null && widget.canDelete && !widget.viewOnly) {
      a.add(DocBarAction.secondary(en ? 'Delete' : 'ลบ', guard(_actions.deleteBlock, _deleteMo), DocBarColors.delete, tooltip: _actions.deleteBlock?.text(en)));
    }
    if ((['Released', 'InProgress', 'Completed', 'Closed'].contains(_status) && canApprove ||
            _status == 'Submitted') && _id != null && !widget.viewOnly) {
      a.add(DocBarAction.secondary(
          _status == 'Closed' ? (en ? 'Reverse Closing' : 'ถอยการปิด') : (en ? 'Reverse to Draft' : 'ถอยเป็นร่าง'),
          guard(_actions.reverseBlock, _reverse), DocBarColors.reverse, tooltip: _actions.reverseBlock?.text(en)));
    }
    if (_isEditable && !widget.viewOnly) {
      a.add(canSubmit
          ? DocBarAction.secondary(en ? 'Save' : 'บันทึก', busy ? null : _save, DocBarColors.save)
          : DocBarAction.primary(en ? 'Save' : 'บันทึก', busy ? null : _save, DocBarColors.post));
    }
    // ส่งขออนุมัติ — อนุมัติครบแล้วจึงปล่อยใบสั่งผลิต (ไม่มีผู้อนุมัติ: ตามตัวเลือกของเมนู ให้ผ่าน/ไม่ให้ผ่าน)
    if (canSubmit) {
      a.add(DocBarAction.primary(en ? 'Submit' : 'ส่งขออนุมัติ', busy ? null : () => _confirmAction(
          'ยืนยันการส่งขออนุมัติ', 'Confirm Submit for Approval',
          'ส่งขออนุมัติใบสั่งผลิต $_docNo? ระหว่างรออนุมัติจะแก้ไขไม่ได้ อนุมัติครบแล้วจึงปล่อยให้ฝ่ายผลิตเริ่มเบิก/รับได้',
          'Submit MO $_docNo for approval? It cannot be edited while waiting. It is released to production once approved.',
          () => _service.submitTransaction(_id!, menuId: perm!.id)), DocBarColors.submit));
    }
    if (_status == 'Completed' && _id != null && canApprove && !widget.viewOnly) {
      a.add(DocBarAction.primary(en ? 'Close MO' : 'ปิดใบสั่งผลิต', busy ? null : _closeMo, DocBarColors.post));
    }
    if (['Released', 'InProgress', 'Completed'].contains(_status) && _id != null && canApprove && !widget.viewOnly) {
      a.add(DocBarAction.primary(en ? 'Cancel MO' : 'ยกเลิกใบสั่งผลิต', guard(_actions.voidBlock, _cancelMo), DocBarColors.voidBg, tooltip: _actions.voidBlock?.text(en)));
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
      return docFingerprint([p.header, p.components, p.outputs, p.operations]);
    } catch (_) {
      return 'incomplete|${docFingerprint([
            _warehouse?.id,
            _orderQtyCtrl.text,
            [for (var i = 0; i < _components.length; i++) _components[i].toModel(i + 1)],
            [for (var i = 0; i < _outputs.length; i++) _outputs[i].toModel(i + 1)],
            [for (var i = 0; i < _operations.length; i++) _operations[i].toModel(i + 1)],
          ])}';
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

  String _warehouseName(ImWarehouse w) => _isEnglish && (w.warehouseNameEn ?? '').isNotEmpty ? w.warehouseNameEn! : w.warehouseNameTh;

  // ── รูปแบบช่อง (user design 2026-11-23 — เหมือนหน้ารายละเอียด IM / PO) ──────────────────────────
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
  static const _teal = Color(0xFF0F6E6E);
  static const double _hFieldH = 40;
  static const double _cellH = 36;
  static const _numStyle = TextStyle(fontSize: 13, fontFeatures: [FontFeature.tabularFigures()]);
  static const _calIcon = Icon(Icons.calendar_today, size: 16, color: _teal);
  static const _searchIcon = Icon(Icons.search, size: 18, color: _teal);

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

  // ช่องเลือกในตาราง (หน่วย / ตำแหน่ง / ศูนย์งาน) — แก้ไขได้ = ขาว + แว่นขยาย, อ่านอย่างเดียว = เทา
  Widget _cellPick(String text, VoidCallback? onTap, {String? empty, VoidCallback? onClear}) {
    final ro = _isReadOnly || onTap == null;
    final has = text.isNotEmpty;
    return InkWell(
      onTap: ro ? null : onTap,
      child: Container(
        height: _cellH,
        padding: const EdgeInsets.only(left: 7, right: 4),
        decoration: BoxDecoration(
          color: ro ? _hRo : Colors.white,
          border: Border.all(color: const Color(0xFFC3C9D0)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(children: [
          Expanded(
            child: Text(has ? text : (empty ?? '—'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: has ? (ro ? _ink2 : Colors.black87) : Colors.grey.shade500)),
          ),
          if (!ro && has && onClear != null)
            InkWell(onTap: onClear, child: const Icon(Icons.clear, size: 14, color: Colors.grey))
          else if (!ro)
            const Icon(Icons.search, size: 16, color: _teal),
        ]),
      ),
    );
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
          foregroundColor: _teal,
          side: const BorderSide(color: _teal),
        ),
        icon: const Icon(Icons.add, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        onPressed: onPressed,
      );

  Widget _deleteButton(VoidCallback onPressed) => IconButton(
        tooltip: _isEnglish ? 'Delete line' : 'ลบรายการ',
        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
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

  Widget _hRow(List<Widget> children, {List<int>? flex}) => Row(children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(flex: flex?[i] ?? 1, child: children[i]),
        ],
      ]);

  Widget _cellField(TextEditingController c, {bool numeric = true, String? allow, ValueChanged<String>? onChanged, bool err = false}) =>
      TextFormField(
        controller: c,
        readOnly: _isReadOnly,
        textAlign: numeric ? TextAlign.right : TextAlign.left,
        keyboardType: numeric ? TextInputType.number : null,
        inputFormatters: allow == null ? null : [FilteringTextInputFormatter.allow(RegExp(allow))],
        style: _numStyle.copyWith(color: _isReadOnly ? _ink2 : Colors.black87),
        decoration: _cDec(fill: _isReadOnly ? _hRo : null, err: err),
        onChanged: onChanged,
      );

  Widget _footerLabel(String t) => Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, softWrap: false, overflow: TextOverflow.visible));

  Widget _footerNum(String t) =>
      Padding(padding: const EdgeInsets.only(right: 7), child: Text(t, style: _numStyle.copyWith(fontWeight: FontWeight.bold)));

  Widget _sumRow(String label, double v, {bool line = false, bool neg = false, Color? color, bool bold = false}) => Container(
        padding: EdgeInsets.only(top: line ? 7 : 3, bottom: 3),
        margin: EdgeInsets.only(top: line ? 4 : 0),
        decoration: line ? const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFDDE3EA)))) : null,
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 13, color: color ?? const Color(0xFF33404D), fontWeight: bold ? FontWeight.bold : null))),
          Text(_fmt.format(v),
              style: _numStyle.copyWith(fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: color ?? (neg ? _errRed : null))),
        ]),
      );

  // แถบความคืบหน้าต่อบรรทัด (เบิกแล้ว / รับแล้ว) — ครบ = เขียว
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

  // ช่องรหัส+ชื่อสินค้าในตาราง — แก้ไขได้: คลิกเพื่อเปลี่ยนสินค้า; tag = ป้ายต่อท้าย (เช่น "มีสูตร")
  Widget _itemBox(String? code, String? name, {VoidCallback? onTap, Widget? tag}) {
    final ro = _isReadOnly || onTap == null;
    return Tooltip(
      message: '${code ?? ''}  ${name ?? ''}',
      child: InkWell(
        onTap: ro ? null : onTap,
        child: Container(
          height: _cellH,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: ro ? _hRo : Colors.white,
            border: Border.all(color: const Color(0xFFC3C9D0)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(children: [
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: code ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: '  ${name ?? ''}', style: const TextStyle(color: _ink2)),
                ]),
                style: const TextStyle(fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (tag != null) ...[const SizedBox(width: 6), tag],
          ]),
        ),
      ),
    );
  }

  Widget _pickBox(String label, {required String? code, required String? name, required String emptyText, VoidCallback? onTap, VoidCallback? onClear, bool req = false, bool auto = false, bool forcedReadOnly = false}) =>
      InkWell(
        onTap: _isReadOnly || forcedReadOnly ? null : onTap,
        child: InputDecorator(
          decoration: _hDec(label, req: req, auto: auto, forcedReadOnly: forcedReadOnly,
              suffixIcon: _isReadOnly || forcedReadOnly || onTap == null ? null : _searchIcon),
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
            if (!_isReadOnly && !forcedReadOnly && code != null && onClear != null)
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

  // ผลผลิตหลัก: รับแล้ว / ตามแผน (หน่วยของบรรทัด)
  ({double done, double total})? get _primaryProgress {
    final p = _outputs.where((o) => o.isPrimary).firstOrNull ?? _outputs.firstOrNull;
    return p == null ? null : (done: p.receivedQty, total: p.qty);
  }

  // ── การ์ดข้อมูลเอกสาร: 4 กลุ่มสี (เหมือน IM / PO) — fix ด้านบน, ย่อเป็นแถบสรุปได้ ─────────────────────
  Widget _buildHeaderSection() {
    final isEnglish = _isEnglish;
    final branch = findBranch(_branches, _branchId);
    final shortCount = _shortCount;
    final prog = _primaryProgress;
    final showMadePct = prog != null && prog.total > 0 && (_showProgress || prog.done > 0);

    final titleRow = Row(children: [
      Expanded(
        child: Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(isEnglish ? 'Document Header' : 'ข้อมูลเอกสาร', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          if (_docNo.isNotEmpty && _docNo != 'AUTO')
            Text(_docNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F5C5C))),
          docStatusBadge(_status, label: moHeaderStatusLabel(_status, isEnglish)),
          if (shortCount > 0)
            _chip(isEnglish ? '$shortCount material(s) short' : 'วัตถุดิบขาด $shortCount รายการ', _errRed, const Color(0xFFFDE7E7)),
          if (showMadePct)
            _chip(
                isEnglish
                    ? 'Produced ${(prog.done / prog.total * 100).clamp(0, 999).toStringAsFixed(0)}%'
                    : 'ผลิตแล้ว ${(prog.done / prog.total * 100).clamp(0, 999).toStringAsFixed(0)}%',
                const Color(0xFF1E6B3A),
                const Color(0xFFE3F4E8)),
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
        value: _docType,
        isExpanded: true,
        isDense: true,
        decoration: _hDec(isEnglish ? 'Document Type' : 'ประเภทเอกสาร', req: true, forcedReadOnly: _id != null),
        items: _allowedDocTypes
            .map((d) => DropdownMenuItem(value: d, child: Text('${d.docCode} ${_docTypeLabel(d)}', overflow: TextOverflow.ellipsis)))
            .toList(),
        // เปลี่ยนได้เฉพาะตอนยังไม่บันทึกครั้งแรก — เลขที่เอกสาร/ชุดเลขวิ่งผูกกับประเภทเอกสารตอนสร้าง
        onChanged: (_isReadOnly || _id != null) ? null : (v) => setState(() { _docType = v; _docId = v?.id; }),
      ),
      InputDecorator(
        decoration: _hDec(isEnglish ? 'MO No.' : 'เลขที่ใบสั่งผลิต', auto: true, forcedReadOnly: _id != null),
        child: Text(_docNo == 'AUTO' ? (isEnglish ? 'Auto' : 'อัตโนมัติ') : _docNo,
            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _docNo == 'AUTO' ? Colors.grey.shade600 : null)),
      ),
      _hRow([
        _datePick(isEnglish ? 'Doc Date' : 'วันที่เอกสาร', _docDate, () async {
          final picked = await showDatePicker(context: context, initialDate: _docDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (picked != null) setState(() => _docDate = picked);
        }, req: true, auto: true),
        _datePick(isEnglish ? 'Due Date' : 'วันครบกำหนด', _dueDate, () async {
          final picked = await showDatePicker(context: context, initialDate: _dueDate ?? _docDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (picked != null) setState(() => _dueDate = picked);
        }, onClear: () => setState(() => _dueDate = null)),
      ]),
    ]);

    // ② สิ่งที่ผลิต
    final bomName = _bomParentItemName == null ? null : '$_bomParentItemName${_bomVersion != null ? '  (v$_bomVersion)' : ''}';
    final g2 = docFilterGroup(2, isEnglish ? 'What to Produce' : 'สิ่งที่ผลิต', color: _gParty, [
      Row(children: [
        Expanded(
          child: _pickBox(
            isEnglish ? 'BOM' : 'สูตรการผลิต',
            code: _bomHeaderId == null ? null : _bomParentItemCode,
            name: bomName,
            emptyText: isEnglish ? 'Optional — click to select a BOM' : 'ไม่บังคับ — คลิกเพื่อเลือกสูตร',
            onTap: _pickBom,
          ),
        ),
        if (!_isReadOnly && _bomHeaderId != null) ...[
          const SizedBox(width: 4),
          IconButton(
            icon: _isLoadingBom
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync, color: _teal, size: 20),
            tooltip: isEnglish ? 'Reload lines from BOM' : 'โหลดรายการจากสูตรใหม่',
            visualDensity: VisualDensity.compact,
            onPressed: _isLoadingBom ? null : _loadFromBom,
          ),
        ],
      ]),
      _pickBox(
        isEnglish ? 'Destination Warehouse' : 'คลังปลายทาง',
        req: true,
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
          key: ValueKey('mo_qty_${widget.resetKey}_$_id'),
          controller: _orderQtyCtrl,
          readOnly: _isReadOnly,
          textAlign: TextAlign.right,
          style: _numStyle,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
          decoration: _hDec(isEnglish ? 'Order Qty' : 'จำนวนที่สั่งผลิต', req: true),
          onChanged: (_) => setState(() {}),
        ),
        _pickBox(
          isEnglish ? 'Unit' : 'หน่วย',
          code: _uomId == null ? null : (_uomName ?? _uomCode ?? ''),
          name: null,
          auto: true,
          emptyText: '—',
          onTap: _pickUom,
        ),
      ]),
      // ใบสั่งผลิตหลัก — กรณีเป็นใบสั่งผลิตย่อยที่สร้างจากส่วนประกอบของใบอื่น (อ่านอย่างเดียว)
      if (_parentMoDocNo != null)
        InputDecorator(
          decoration: _hDec(isEnglish ? 'Parent MO' : 'ใบสั่งผลิตหลัก', forcedReadOnly: true),
          child: Text(_parentMoDocNo!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, color: _ink2)),
        ),
    ]);

    // ③ นโยบายต้นทุน — เติมค่ามาจากสูตรตอนโหลด (ถ้ามี) override เป็นรายใบนี้ได้
    final pctMode = _costingMode == 'OVERHEAD_PERCENT';
    final g3 = docFilterGroup(3, isEnglish ? 'Costing Policy' : 'นโยบายต้นทุน', color: _gFin, [
      DropdownButtonFormField<String>(
        value: _issueMethod,
        isExpanded: true,
        isDense: true,
        decoration: _hDec(isEnglish ? 'Material Issue' : 'วิธีเบิกวัตถุดิบ', auto: true),
        items: moIssueMethods.map((m) => DropdownMenuItem(value: m, child: Text(moIssueMethodLabel(m, isEnglish), overflow: TextOverflow.ellipsis))).toList(),
        onChanged: _isReadOnly ? null : (v) => setState(() => _issueMethod = v ?? 'EXPLICIT'),
      ),
      DropdownButtonFormField<String>(
        value: _costingMethod,
        isExpanded: true,
        isDense: true,
        decoration: _hDec(isEnglish ? 'Output Costing' : 'วิธีตีมูลค่าผลผลิต', auto: true),
        items: moCostingMethods.map((m) => DropdownMenuItem(value: m, child: Text(moCostingMethodLabel(m, isEnglish), overflow: TextOverflow.ellipsis))).toList(),
        onChanged: _isReadOnly ? null : (v) => setState(() => _costingMethod = v ?? 'ACTUAL'),
      ),
      _hRow([
        DropdownButtonFormField<String>(
          value: _costingMode,
          isExpanded: true,
          isDense: true,
          decoration: _hDec(isEnglish ? 'Conversion Cost' : 'ต้นทุนแปรรูป', auto: true),
          items: moCostingModes.map((m) => DropdownMenuItem(value: m, child: Text(moCostingModeLabel(m, isEnglish), overflow: TextOverflow.ellipsis))).toList(),
          onChanged: _isReadOnly ? null : (v) => setState(() => _costingMode = v ?? 'OVERHEAD_PERCENT'),
        ),
        // เปิดให้กรอกเฉพาะต้นทุนแปรรูปแบบร้อยละ
        pctMode
            ? TextFormField(
                controller: _overheadPercentCtrl,
                readOnly: _isReadOnly,
                textAlign: TextAlign.right,
                style: _numStyle,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                decoration: _hDec('Overhead %', auto: true),
                onChanged: (_) => setState(() {}),
              )
            : InputDecorator(
                decoration: _hDec('Overhead %', forcedReadOnly: true),
                child: const Text('—', textAlign: TextAlign.right, style: TextStyle(color: _ink2)),
              ),
      ], flex: const [3, 2]),
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
          if (_headerExpanded) _groupLayout([g1, g2, g3, g4], const [10, 13, 12, 11]) else _headerSummary(isEnglish),
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
    final qty = double.tryParse(_orderQtyCtrl.text) ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFF6F8FA), borderRadius: BorderRadius.circular(4)),
      child: Wrap(spacing: 22, runSpacing: 6, children: [
        if (_docType != null) item(_gDoc, isEnglish ? 'Type' : 'ประเภท', '${_docType!.docCode} ${_docTypeLabel(_docType!)}'),
        item(_gDoc, isEnglish ? 'Date' : 'วันที่', _dateFmt.format(_docDate)),
        if (_dueDate != null) item(_gDoc, isEnglish ? 'Due' : 'ครบกำหนด', _dateFmt.format(_dueDate!)),
        if (_bomHeaderId != null) item(_gParty, isEnglish ? 'BOM' : 'สูตร', '$_bomParentItemCode ${_bomParentItemName ?? ''}'),
        if (_warehouse != null) item(_gParty, isEnglish ? 'Warehouse' : 'คลัง', '${_warehouse!.warehouseCode} ${_warehouseName(_warehouse!)}'),
        item(_gParty, isEnglish ? 'Qty' : 'จำนวน', '${_fmtQty.format(qty)} ${_uomName ?? _uomCode ?? ''}'),
        if (_parentMoDocNo != null) item(_gParty, isEnglish ? 'Parent MO' : 'ใบสั่งผลิตหลัก', _parentMoDocNo!),
        item(_gFin, isEnglish ? 'Conversion' : 'ต้นทุนแปรรูป',
            '${moCostingModeLabel(_costingMode, isEnglish)}${_costingMode == 'OVERHEAD_PERCENT' ? ' ${_overheadPercentCtrl.text}%' : ''}'),
        if (_descCtrl.text.trim().isNotEmpty) item(_gMore, isEnglish ? 'Description' : 'คำอธิบาย', _descCtrl.text.trim()),
      ]),
    );
  }

  String _lineUom(String? code, String? th, String? en) => _uomDisplayName(code, th, en, _isEnglish);

  // ── ผลผลิต: ดาว = ผลผลิตหลัก (ต้นทุนส่วนใหญ่ปันเข้า) ──────────────────────────────────────────────
  Widget _buildOutputsSection() {
    final isEnglish = _isEnglish;
    final showProgress = _showProgress;
    final cols = <(String, double, int, bool)>[
      ('#', 28, 0, false),
      ('', 30, 0, false),
      (isEnglish ? 'Output Item *' : 'สินค้าผลผลิต *', 0, 1, false),
      (isEnglish ? 'Planned Qty *' : 'จำนวนที่จะผลิต *', 100, 2, true),
      (isEnglish ? 'Unit' : 'หน่วย', 110, 2, false),
      if (showProgress) (isEnglish ? 'Received' : 'รับแล้ว', 110, 3, true),
      (isEnglish ? 'Remark' : 'หมายเหตุ', 0, 4, false),
      if (!_isReadOnly) ('', 36, 0, false),
    ];
    final rows = <List<Widget>>[];
    for (var i = 0; i < _outputs.length; i++) {
      final o = _outputs[i];
      final uom = _lineUom(o.uomCode, o.uomNameTh, o.uomNameEn);
      rows.add([
        Text('${i + 1}.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade700)),
        Tooltip(
          message: o.isPrimary
              ? (isEnglish ? 'Primary output' : 'ผลผลิตหลัก')
              : (isEnglish ? 'By-product — click to make primary' : 'ผลพลอยได้ — คลิกเพื่อตั้งเป็นผลผลิตหลัก'),
          child: InkWell(
            onTap: _isReadOnly || o.isPrimary
                ? null
                : () => setState(() {
                      for (final x in _outputs) {
                        x.isPrimary = identical(x, o);
                      }
                    }),
            child: Icon(o.isPrimary ? Icons.star : Icons.star_border, size: 20, color: o.isPrimary ? Colors.amber.shade700 : Colors.grey.shade400),
          ),
        ),
        _itemBox(o.itemCode, o.itemName, onTap: () => _changeOutputItem(o)),
        _cellField(o.qtyCtrl, allow: r'[0-9.]', onChanged: (_) => setState(() {}), err: !_isReadOnly && o.qty <= 0),
        _cellPick(uom, () => _pickLineUom(o.itemId, (u) {
              o.uomId = u.uomId; o.uomCode = u.uomCode; o.uomNameTh = u.uomNameTh; o.uomNameEn = u.uomNameEn;
            })),
        if (showProgress)
          _progress(o.receivedQty, o.qty,
              isEnglish
                  ? 'Received ${_fmtQty.format(o.receivedQty)} of ${_fmtQty.format(o.qty)} $uom'
                  : 'รับแล้ว ${_fmtQty.format(o.receivedQty)} จาก ${_fmtQty.format(o.qty)} $uom'),
        _cellField(o.remarkCtrl, numeric: false),
        if (!_isReadOnly)
          _deleteButton(() {
            final wasPrimary = o.isPrimary;
            _removeLine(_outputs, i);
            if (wasPrimary && _outputs.isNotEmpty) setState(() => _outputs.first.isPrimary = true);
          }),
      ]);
    }
    return _card(
      isEnglish ? 'Outputs' : 'ผลผลิต',
      chips: [_chip(isEnglish ? '${_outputs.length} lines' : '${_outputs.length} รายการ', const Color(0xFF1E4F8F), _hAuto)],
      actions: [if (!_isReadOnly) _addButton(isEnglish ? 'Add Output' : 'เพิ่มผลผลิต', _addOutput)],
      [
        _gridTable(
          cols: cols,
          groupTitle: (g) => switch (g) {
            1 => isEnglish ? 'Item' : 'สินค้า',
            2 => isEnglish ? 'Quantity' : 'จำนวน',
            3 => isEnglish ? 'Progress' : 'ความคืบหน้า',
            _ => isEnglish ? 'Remark' : 'หมายเหตุ',
          },
          rows: rows,
          empty: Text(isEnglish ? 'No outputs — select a BOM or click Add Output' : 'ยังไม่มีผลผลิต — เลือกสูตรการผลิต หรือกดเพิ่มผลผลิต',
              style: const TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  // ── ส่วนประกอบ: ความพร้อมวัตถุดิบ (คงเหลือในคลัง / ขาด) + เบิกแล้ว ─────────────────────────────────
  Widget _buildComponentsSection() {
    final isEnglish = _isEnglish;
    final showProgress = _showProgress;
    final showAvail = _available != null;
    final cols = <(String, double, int, bool)>[
      ('#', 28, 0, false),
      (isEnglish ? 'Component *' : 'วัตถุดิบ / ส่วนประกอบ *', 0, 1, false),
      (isEnglish ? 'Planned Qty *' : 'จำนวนที่ใช้ *', 100, 2, true),
      (isEnglish ? 'Unit' : 'หน่วย', 100, 2, false),
      (isEnglish ? 'Issue Location' : 'ตำแหน่งเบิก', 130, 2, false),
      if (showAvail) (isEnglish ? 'On Hand' : 'คงเหลือในคลัง', 104, 3, true),
      if (showAvail) (isEnglish ? 'Short' : 'ขาด', 90, 3, true),
      if (showProgress) (isEnglish ? 'Issued' : 'เบิกแล้ว', 110, 3, true),
      (isEnglish ? 'Remark' : 'หมายเหตุ', 0, 4, false),
      if (!_isReadOnly) ('', 36, 0, false),
    ];
    final bomTag = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: const Color(0xFFEDE7F6), borderRadius: BorderRadius.circular(8)),
      child: Text(isEnglish ? 'BOM' : 'มีสูตร', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF5E35B1))),
    );
    final rows = <List<Widget>>[];
    for (var i = 0; i < _components.length; i++) {
      final c = _components[i];
      final uom = _lineUom(c.uomCode, c.uomNameTh, c.uomNameEn);
      final av = _availableOf(c);
      final short = _shortOf(c);
      final loc = c.locationCode == null ? '' : '${c.locationCode}${(c.locationName ?? '').isNotEmpty ? '  ${c.locationName}' : ''}';
      rows.add([
        Text('${i + 1}.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade700)),
        _itemBox(c.itemCode, c.itemName,
            onTap: () => _changeComponentItem(c),
            tag: c.hasBom
                ? Tooltip(
                    message: isEnglish
                        ? 'This item has its own BOM — a sub-MO can be created for it'
                        : 'สินค้านี้มีสูตรการผลิต — สร้างใบสั่งผลิตย่อยได้',
                    child: bomTag)
                : null),
        _cellField(c.qtyCtrl, allow: r'[0-9.]', onChanged: (_) => setState(() {}), err: !_isReadOnly && c.qty <= 0),
        _cellPick(uom, () => _pickLineUom(c.itemId, (u) {
              c.uomId = u.uomId; c.uomCode = u.uomCode; c.uomNameTh = u.uomNameTh; c.uomNameEn = u.uomNameEn;
            })),
        _cellPick(loc, () => _pickLocation(c),
            empty: isEnglish ? 'Any' : 'ไม่ระบุ',
            onClear: () => setState(() { c.locationId = null; c.locationCode = null; c.locationName = null; })),
        if (showAvail)
          av == null
              ? _cBox('—', tip: isEnglish ? 'Save to check stock' : 'บันทึกก่อนจึงตรวจคงเหลือได้')
              : _cBox(_fmtQty.format(av)),
        if (showAvail)
          short == null
              ? _cBox('—')
              : short > 0
                  ? _cBox(_fmtQty.format(short), bold: true, color: _errRed, fill: const Color(0xFFFDECEC))
                  : _cBox('—', color: const Color(0xFF1E6B3A)),
        if (showProgress)
          _progress(c.issuedQty, c.qty,
              isEnglish
                  ? 'Issued ${_fmtQty.format(c.issuedQty)} of ${_fmtQty.format(c.qty)} $uom'
                  : 'เบิกแล้ว ${_fmtQty.format(c.issuedQty)} จาก ${_fmtQty.format(c.qty)} $uom'),
        _cellField(c.remarkCtrl, numeric: false),
        if (!_isReadOnly) _deleteButton(() => _removeLine(_components, i)),
      ]);
    }
    final shortCount = _shortCount;
    final hasNew = showAvail && _components.any((c) => c.id == null);
    return _card(
      isEnglish ? 'Components' : 'ส่วนประกอบ',
      chips: [
        _chip(isEnglish ? '${_components.length} lines' : '${_components.length} รายการ', const Color(0xFF1E4F8F), _hAuto),
        if (shortCount > 0)
          _chip(isEnglish ? '$shortCount short' : 'ขาด $shortCount รายการ', _errRed, const Color(0xFFFDE7E7))
        else if (showAvail && _components.isNotEmpty && !hasNew)
          _chip(isEnglish ? 'All available' : 'วัตถุดิบพร้อม', const Color(0xFF1E6B3A), const Color(0xFFE3F4E8)),
      ],
      actions: [
        if (_available != null || _id != null && !['Closed', 'Cancelled', 'Deleted'].contains(_status))
          IconButton(
            tooltip: isEnglish ? 'Refresh stock on hand' : 'ตรวจคงเหลือในคลังใหม่',
            icon: const Icon(Icons.refresh, size: 18, color: _teal),
            visualDensity: VisualDensity.compact,
            onPressed: _loadAvailability,
          ),
        if (!_isReadOnly) _addButton(isEnglish ? 'Add Component' : 'เพิ่มส่วนประกอบ', _addComponent),
      ],
      [
        _gridTable(
          cols: cols,
          groupTitle: (g) => switch (g) {
            1 => isEnglish ? 'Item' : 'สินค้า',
            2 => isEnglish ? 'Quantity / Location' : 'จำนวน / ตำแหน่งเบิก',
            3 => isEnglish ? 'Availability / Issued' : 'ความพร้อม / เบิกแล้ว',
            _ => isEnglish ? 'Remark' : 'หมายเหตุ',
          },
          rows: rows,
          empty: Text(isEnglish ? 'No components — select a BOM or click Add Component' : 'ยังไม่มีส่วนประกอบ — เลือกสูตรการผลิต หรือกดเพิ่มส่วนประกอบ',
              style: const TextStyle(color: Colors.grey)),
        ),
        if (showAvail) ...[
          const SizedBox(height: 6),
          Text(
            isEnglish
                ? 'On hand = stock in the destination warehouse, in the line\'s unit · Short = still to issue − on hand${hasNew ? ' · new lines are checked after saving' : ''}'
                : 'คงเหลือในคลัง = ยอดในคลังปลายทาง (หน่วยของบรรทัด) · ขาด = จำนวนที่ยังต้องเบิก − คงเหลือ${hasNew ? ' · บรรทัดใหม่ตรวจได้หลังบันทึก' : ''}',
            style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
          ),
        ],
      ],
    );
  }

  // ── ขั้นตอนการผลิต — เฉพาะต้นทุนแปรรูปแบบตามขั้นตอนการผลิต ─────────────────────────────────────────
  Widget _opStatusChip(String s) {
    final isEnglish = _isEnglish;
    final (label, fg, bg) = switch (s) {
      'Done' => (isEnglish ? 'Done' : 'เสร็จแล้ว', const Color(0xFF1E6B3A), const Color(0xFFE3F4E8)),
      'InProgress' => (isEnglish ? 'In Progress' : 'กำลังทำ', const Color(0xFF1E4F8F), _hAuto),
      _ => (isEnglish ? 'Pending' : 'รอดำเนินการ', _ink2, _hRo),
    };
    return _chip(label, fg, bg);
  }

  Widget _buildOperationsSection() {
    final isEnglish = _isEnglish;
    final showProgress = _showProgress;
    final cols = <(String, double, int, bool)>[
      ('#', 28, 0, false),
      (isEnglish ? 'Work Center *' : 'ศูนย์งาน *', 0, 1, false),
      (isEnglish ? 'Operation' : 'ชื่อขั้นตอน', 0, 1, false),
      (isEnglish ? 'Labor Hrs' : 'ชม. แรงงาน', 96, 2, true),
      (isEnglish ? 'Machine Hrs' : 'ชม. เครื่องจักร', 104, 2, true),
      if (showProgress) (isEnglish ? 'Actual Labor' : 'แรงงานจริง', 100, 3, true),
      if (showProgress) (isEnglish ? 'Actual Machine' : 'เครื่องจักรจริง', 110, 3, true),
      if (showProgress) (isEnglish ? 'Status' : 'สถานะ', 104, 3, false),
      if (!_isReadOnly) ('', 36, 0, false),
    ];
    double pl = 0, pm = 0, al = 0, am = 0;
    final rows = <List<Widget>>[];
    for (var i = 0; i < _operations.length; i++) {
      final op = _operations[i];
      pl += op.labor; pm += op.machine; al += op.actualLaborHours; am += op.actualMachineHours;
      final wcName = _isEnglish && (op.workCenterNameEn ?? '').isNotEmpty ? op.workCenterNameEn : op.workCenterNameTh;
      rows.add([
        Text('${i + 1}.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade700)),
        _itemBox(op.workCenterCode, wcName, onTap: () => _changeWorkCenter(op)),
        _cellField(op.nameCtrl, numeric: false),
        _cellField(op.laborCtrl, allow: r'[0-9.]', onChanged: (_) => setState(() {})),
        _cellField(op.machineCtrl, allow: r'[0-9.]', onChanged: (_) => setState(() {})),
        if (showProgress)
          _progress(op.actualLaborHours, op.labor,
              isEnglish ? 'Actual ${_fmtQty.format(op.actualLaborHours)} of ${_fmtQty.format(op.labor)} hr' : 'จริง ${_fmtQty.format(op.actualLaborHours)} จาก ${_fmtQty.format(op.labor)} ชม.'),
        if (showProgress)
          _progress(op.actualMachineHours, op.machine,
              isEnglish ? 'Actual ${_fmtQty.format(op.actualMachineHours)} of ${_fmtQty.format(op.machine)} hr' : 'จริง ${_fmtQty.format(op.actualMachineHours)} จาก ${_fmtQty.format(op.machine)} ชม.'),
        if (showProgress) _opStatusChip(op.status),
        if (!_isReadOnly) _deleteButton(() => _removeLine(_operations, i)),
      ]);
    }
    final footer = <Widget>[
      const SizedBox.shrink(),
      _footerLabel(isEnglish ? 'Total ${_operations.length} steps' : 'รวม ${_operations.length} ขั้นตอน'),
      const SizedBox.shrink(),
      _footerNum(_fmtQty.format(pl)),
      _footerNum(_fmtQty.format(pm)),
      if (showProgress) _footerNum(_fmtQty.format(al)),
      if (showProgress) _footerNum(_fmtQty.format(am)),
      if (showProgress) const SizedBox.shrink(),
      if (!_isReadOnly) const SizedBox.shrink(),
    ];
    final done = _operations.where((o) => o.status == 'Done').length;
    return _card(
      isEnglish ? 'Routing' : 'ขั้นตอนการผลิต',
      chips: [
        _chip(isEnglish ? '${_operations.length} steps' : '${_operations.length} ขั้นตอน', const Color(0xFF1E4F8F), _hAuto),
        if (showProgress && _operations.isNotEmpty)
          _chip(isEnglish ? '$done done' : 'เสร็จ $done ขั้นตอน', const Color(0xFF1E6B3A), const Color(0xFFE3F4E8)),
      ],
      actions: [if (!_isReadOnly) _addButton(isEnglish ? 'Add Step' : 'เพิ่มขั้นตอน', _addOperation)],
      [
        _gridTable(
          cols: cols,
          groupTitle: (g) => switch (g) {
            1 => isEnglish ? 'Operation' : 'ขั้นตอน',
            2 => isEnglish ? 'Planned Hours' : 'ชั่วโมงตามแผน',
            _ => isEnglish ? 'Actual / Status' : 'ชั่วโมงจริง / สถานะ',
          },
          rows: rows,
          footer: footer,
          empty: Text(isEnglish ? 'No steps — select a BOM or click Add Step' : 'ยังไม่มีขั้นตอน — เลือกสูตรการผลิต หรือกดเพิ่มขั้นตอน',
              style: const TextStyle(color: Colors.grey)),
        ),
        if (showProgress) ...[
          const SizedBox(height: 6),
          Text(
            isEnglish
                ? 'Actual hours are logged on the Operation Time Log screen — each log posts labor/machine cost into WIP'
                : 'ชั่วโมงจริงบันทึกที่หน้าจอบันทึกเวลาปฏิบัติงาน — ทุกครั้งที่บันทึกจะปันค่าแรง/ค่าเครื่องจักรเข้า WIP',
            style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
          ),
        ],
      ],
    );
  }

  // ── สรุปการผลิต: ซ้าย = ความคืบหน้า, ขวา = ต้นทุนสะสม → โอนเข้าสินค้าสำเร็จรูป → WIP คงเหลือ ───────────────
  Widget _bar(String label, double p, String value, {Color? color}) {
    final v = p.clamp(0.0, 1.0);
    final full = v >= 0.9999;
    final c = color ?? (full ? const Color(0xFF2E9B57) : const Color(0xFF3B7DD8));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF33404D)))),
          Text(value, style: _numStyle.copyWith(fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: v, minHeight: 8, color: c, backgroundColor: const Color(0xFFE6EAEE)),
        ),
      ]),
    );
  }

  Widget _buildSummarySection() {
    final isEnglish = _isEnglish;
    final pct = NumberFormat('#,##0');
    final prog = _primaryProgress;
    final primary = _outputs.where((o) => o.isPrimary).firstOrNull ?? _outputs.firstOrNull;
    final primaryUom = primary == null ? '' : _lineUom(primary.uomCode, primary.uomNameTh, primary.uomNameEn);
    double fr(double d, double t) => t <= 0 ? 0 : (d / t).clamp(0.0, 1.0);
    final matFrac = _components.isEmpty ? 0.0 : _components.fold<double>(0, (s, c) => s + fr(c.issuedQty, c.qty)) / _components.length;
    final matDone = _components.where((c) => c.qty > 0 && c.issuedQty >= c.qty - 0.00005).length;
    final routing = _costingMode == 'ROUTING';
    final plannedHrs = _operations.fold<double>(0, (s, o) => s + o.labor + o.machine);
    final actualHrs = _operations.fold<double>(0, (s, o) => s + o.actualLaborHours + o.actualMachineHours);

    final left = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(isEnglish ? 'Progress' : 'ความคืบหน้า', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      if (prog != null)
        _bar(
          isEnglish ? 'Primary output received' : 'รับผลผลิตหลักแล้ว',
          fr(prog.done, prog.total),
          '${_fmtQty.format(prog.done)} / ${_fmtQty.format(prog.total)} $primaryUom  (${pct.format(fr(prog.done, prog.total) * 100)}%)',
        ),
      _bar(
        isEnglish ? 'Materials issued' : 'เบิกวัตถุดิบแล้ว',
        matFrac,
        isEnglish ? '$matDone of ${_components.length} lines complete  (${pct.format(matFrac * 100)}%)' : 'ครบ $matDone จาก ${_components.length} รายการ  (${pct.format(matFrac * 100)}%)',
      ),
      if (routing && _operations.isNotEmpty)
        _bar(
          isEnglish ? 'Hours used (labor + machine)' : 'ชั่วโมงที่ใช้ (แรงงาน + เครื่องจักร)',
          fr(actualHrs, plannedHrs),
          '${_fmtQty.format(actualHrs)} / ${_fmtQty.format(plannedHrs)} ${isEnglish ? 'hr' : 'ชม.'}',
          color: actualHrs > plannedHrs + 0.00005 ? const Color(0xFFD9822B) : null,
        ),
    ]);

    final c = _cost;
    final closedVariance = _status == 'Closed' ? c.wipBalance - _wipBalanceLc : 0.0;
    final ohPct = double.tryParse(_overheadPercentCtrl.text) ?? 0;
    final figures = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sumRow(isEnglish ? 'Materials issued' : 'วัตถุดิบที่เบิก', c.materialCost),
      if (routing || c.laborCost.abs() >= 0.005) _sumRow(isEnglish ? 'Labor (time logs)' : 'ค่าแรง (บันทึกเวลา)', c.laborCost),
      if (routing || c.machineOverheadCost.abs() >= 0.005)
        _sumRow(isEnglish ? 'Machine + overhead (time logs)' : 'ค่าเครื่องจักร + โสหุ้ย (บันทึกเวลา)', c.machineOverheadCost),
      if (!routing || c.percentOverheadCost.abs() >= 0.005)
        _sumRow(isEnglish ? 'Overhead ${_qtyEdit.format(ohPct)}% (applied on receipt)' : 'Overhead ${_qtyEdit.format(ohPct)}% (ปันเข้าตอนรับผลผลิต)',
            c.percentOverheadCost),
      _sumRow(isEnglish ? 'Accumulated cost' : 'ต้นทุนสะสม', c.totalCost, line: true, bold: true),
      _sumRow(isEnglish ? 'Transferred to finished goods' : 'โอนเข้าสินค้าสำเร็จรูป', -c.transferredCost, neg: c.transferredCost.abs() >= 0.005),
      if (closedVariance.abs() >= 0.005)
        _sumRow(isEnglish ? 'Closed to variance account' : 'ปิดเข้าบัญชีผลต่างต้นทุน', -closedVariance, color: const Color(0xFF8A4B00)),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFFE8F3F2), borderRadius: BorderRadius.circular(6)),
        child: Row(children: [
          Expanded(
              child: Text(isEnglish ? 'WIP Balance' : 'WIP คงเหลือ',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F5C5C)))),
          Text(_fmt.format(_wipBalanceLc), style: _numStyle.copyWith(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF0F5C5C))),
        ]),
      ),
      if (c.avgUnitCost.abs() >= 0.00005)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            Expanded(
                child: Text(isEnglish ? 'Average cost per ${_uomName ?? 'unit'}' : 'ต้นทุนเฉลี่ยต่อ${_uomName ?? 'หน่วย'}',
                    style: const TextStyle(fontSize: 13, color: _ink2))),
            Text(NumberFormat('#,##0.0000').format(c.avgUnitCost), style: _numStyle.copyWith(fontWeight: FontWeight.w600, color: _ink2)),
          ]),
        ),
    ]);

    return _card(isEnglish ? 'Production Summary' : 'สรุปการผลิต', [
      LayoutBuilder(
        builder: (context, box) => box.maxWidth >= 800
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: left),
                const SizedBox(width: 32),
                SizedBox(width: 400, child: figures),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: 10), figures]),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    widget.actions?.scheduleRefresh();
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    // การ์ดข้อมูลเอกสาร fix ด้านบน (สูงไม่เกิน 60% แล้วเลื่อนในการ์ด) — การ์ดอื่นเลื่อนด้านล่าง (แบบเดียวกับ IM / PO)
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
            if (_status == 'Cancelled' && (_cancelReason ?? '').isNotEmpty) ...[
              Text('${isEnglish ? 'Cancel reason' : 'เหตุผลการยกเลิก'}: $_cancelReason',
                  style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
            ],
            // แผงอนุมัติกลาง — อนุมัติครบ = ปล่อยใบสั่งผลิต
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
            _buildOutputsSection(),
            const SizedBox(height: 16),
            _buildComponentsSection(),
            if (_costingMode == 'ROUTING') ...[
              const SizedBox(height: 16),
              _buildOperationsSection(),
            ],
            if (_id != null && !['Draft', 'Rejected', 'Submitted', 'Deleted'].contains(_status)) ...[
              const SizedBox(height: 16),
              _buildSummarySection(),
            ],
          ]),
        ),
      ),
    ])));
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
