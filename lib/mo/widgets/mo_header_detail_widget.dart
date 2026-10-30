// lib/mo/widgets/mo_header_detail_widget.dart — แก้ไขรายละเอียดใบสั่งผลิต (header + components + outputs +
// operations) มิเรอร์โครงสร้าง po_transaction_detail_widget.dart แต่ไม่มีผู้ขาย/ราคา/สกุลเงินเลย (MO ไม่แตะ GL/
// สต็อกเอง — ดู moHeaderController.js) Draft เท่านั้นที่แก้ไขได้, Release/Cancel เป็น action แยกกดทีละปุ่ม
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
import '../../im/models/im_uom.dart';
import '../../im/models/im_warehouse.dart';
import '../../im/widgets/im_item_list_widget.dart';
import '../../im/widgets/im_uom_list_widget.dart';
import '../../im/widgets/im_warehouse_list_widget.dart';
import '../models/mo_header.dart';
import '../models/mo_bom.dart';
import '../models/mo_work_center.dart';
import '../services/mo_header_service.dart';
import '../../gl/widgets/gl_journal_preview.dart';
import '../services/mo_bom_service.dart';
import '../widgets/mo_bom_list_widget.dart';
import '../widgets/mo_work_center_list_widget.dart';

// ---------------------------------------------------------------------------
// Add/Edit component dialog
// ---------------------------------------------------------------------------
Future<MoComponentDetail?> _showComponentDialog(BuildContext context, MoComponentDetail? existing) async {
  final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
  int? itemId = existing?.componentItemId;
  String? itemCode = existing?.itemCode;
  String? itemName = existing?.itemName;
  int? uomId = existing?.uomId;
  String? uomCode = existing?.uomCode;
  String? uomName = isEnglish && (existing?.uomNameEn ?? '').isNotEmpty ? existing?.uomNameEn : existing?.uomNameTh;
  final qtyCtrl = TextEditingController(text: existing != null ? '${existing.plannedQty}' : '1');

  return showDialog<MoComponentDetail>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
      Widget buildFkField({required String label, required String? displayText, required bool hasValue, required VoidCallback onSearch}) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InputDecorator(
              decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              child: Row(children: [
                Expanded(
                  child: hasValue
                      ? Text(displayText ?? '', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)
                      : Text(isEnglish ? '— Not specified —' : '— ไม่ระบุ —', style: TextStyle(color: Colors.grey.shade600)),
                ),
                IconButton(icon: const Icon(Icons.search, color: Colors.teal), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onSearch),
              ]),
            ),
          );

      return AlertDialog(
        title: Text(existing == null ? (isEnglish ? 'Add Component' : 'เพิ่มส่วนประกอบ') : (isEnglish ? 'Edit Component' : 'แก้ไขส่วนประกอบ')),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            buildFkField(
              label: isEnglish ? 'Component Item *' : 'สินค้าส่วนประกอบ *',
              hasValue: itemId != null,
              displayText: '$itemCode — $itemName',
              onSearch: () => ImItemListWidget.search(ctx, onSelected: (ImItem i) {
                setDlg(() {
                  itemId = i.id; itemCode = i.itemCode;
                  itemName = isEnglish && (i.itemNameEn ?? '').isNotEmpty ? i.itemNameEn : i.itemNameTh;
                  if (uomId == null && i.baseUomId != null) {
                    uomId = i.baseUomId; uomCode = i.baseUomCode;
                    uomName = isEnglish && (i.baseUomNameEn ?? '').isNotEmpty ? i.baseUomNameEn : i.baseUomNameTh;
                  }
                });
              }),
            ),
            Row(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                    decoration: InputDecoration(labelText: isEnglish ? 'Planned Qty *' : 'จำนวนที่ต้องใช้ *', border: const OutlineInputBorder()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: buildFkField(
                  label: isEnglish ? 'UOM' : 'หน่วยนับ',
                  hasValue: uomId != null,
                  displayText: '$uomCode — $uomName',
                  onSearch: () => ImUomListWidget.search(ctx, onSelected: (ImUom u) {
                    setDlg(() {
                      uomId = u.id; uomCode = u.uomCode;
                      uomName = isEnglish && (u.uomNameEn ?? '').isNotEmpty ? u.uomNameEn : u.uomNameTh;
                    });
                  }),
                ),
              ),
            ]),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(
            onPressed: () {
              if (itemId == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please select a component item' : 'กรุณาเลือกสินค้าส่วนประกอบ')));
                return;
              }
              Navigator.of(ctx).pop(MoComponentDetail(
                id: existing?.id,
                headerId: existing?.headerId,
                lineNo: existing?.lineNo ?? 1,
                componentItemId: itemId!,
                itemCode: itemCode,
                itemName: itemName,
                plannedQty: double.tryParse(qtyCtrl.text) ?? 0,
                issuedQty: existing?.issuedQty ?? 0,
                uomId: uomId,
                uomCode: uomCode,
                uomNameTh: uomName,
              ));
            },
            child: Text(isEnglish ? 'OK' : 'ตกลง'),
          ),
        ],
      );
    }),
  );
}

// ---------------------------------------------------------------------------
// Add/Edit output dialog
// ---------------------------------------------------------------------------
Future<MoOutputDetail?> _showOutputDialog(BuildContext context, MoOutputDetail? existing) async {
  final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
  int? itemId = existing?.outputItemId;
  String? itemCode = existing?.itemCode;
  String? itemName = existing?.itemName;
  int? uomId = existing?.uomId;
  String? uomCode = existing?.uomCode;
  String? uomName = isEnglish && (existing?.uomNameEn ?? '').isNotEmpty ? existing?.uomNameEn : existing?.uomNameTh;
  final qtyCtrl = TextEditingController(text: existing != null ? '${existing.plannedQty}' : '1');

  return showDialog<MoOutputDetail>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
      Widget buildFkField({required String label, required String? displayText, required bool hasValue, required VoidCallback onSearch}) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InputDecorator(
              decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              child: Row(children: [
                Expanded(
                  child: hasValue
                      ? Text(displayText ?? '', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)
                      : Text(isEnglish ? '— Not specified —' : '— ไม่ระบุ —', style: TextStyle(color: Colors.grey.shade600)),
                ),
                IconButton(icon: const Icon(Icons.search, color: Colors.teal), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onSearch),
              ]),
            ),
          );

      return AlertDialog(
        title: Text(existing == null ? (isEnglish ? 'Add Output' : 'เพิ่มผลผลิต') : (isEnglish ? 'Edit Output' : 'แก้ไขผลผลิต')),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            buildFkField(
              label: isEnglish ? 'Output Item *' : 'สินค้าผลผลิต *',
              hasValue: itemId != null,
              displayText: '$itemCode — $itemName',
              onSearch: () => ImItemListWidget.search(ctx, itemTypeFilter: 'STOCK', onSelected: (ImItem i) {
                setDlg(() {
                  itemId = i.id; itemCode = i.itemCode;
                  itemName = isEnglish && (i.itemNameEn ?? '').isNotEmpty ? i.itemNameEn : i.itemNameTh;
                  if (uomId == null && i.baseUomId != null) {
                    uomId = i.baseUomId; uomCode = i.baseUomCode;
                    uomName = isEnglish && (i.baseUomNameEn ?? '').isNotEmpty ? i.baseUomNameEn : i.baseUomNameTh;
                  }
                });
              }),
            ),
            Row(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                    decoration: InputDecoration(labelText: isEnglish ? 'Planned Qty *' : 'จำนวนที่จะผลิตได้ *', border: const OutlineInputBorder()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: buildFkField(
                  label: isEnglish ? 'UOM' : 'หน่วยนับ',
                  hasValue: uomId != null,
                  displayText: '$uomCode — $uomName',
                  onSearch: () => ImUomListWidget.search(ctx, onSelected: (ImUom u) {
                    setDlg(() {
                      uomId = u.id; uomCode = u.uomCode;
                      uomName = isEnglish && (u.uomNameEn ?? '').isNotEmpty ? u.uomNameEn : u.uomNameTh;
                    });
                  }),
                ),
              ),
            ]),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(
            onPressed: () {
              if (itemId == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please select an output item' : 'กรุณาเลือกสินค้าผลผลิต')));
                return;
              }
              Navigator.of(ctx).pop(MoOutputDetail(
                id: existing?.id,
                headerId: existing?.headerId,
                lineNo: existing?.lineNo ?? 1,
                outputItemId: itemId!,
                itemCode: itemCode,
                itemName: itemName,
                plannedQty: double.tryParse(qtyCtrl.text) ?? 0,
                receivedQty: existing?.receivedQty ?? 0,
                uomId: uomId,
                uomCode: uomCode,
                uomNameTh: uomName,
                isPrimaryOutput: existing?.isPrimaryOutput ?? false,
              ));
            },
            child: Text(isEnglish ? 'OK' : 'ตกลง'),
          ),
        ],
      );
    }),
  );
}

// ---------------------------------------------------------------------------
// Add/Edit operation dialog
// ---------------------------------------------------------------------------
Future<MoOperationDetail?> _showOperationDialog(BuildContext context, MoOperationDetail? existing) async {
  final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
  int? workCenterId = existing?.workCenterId;
  String? workCenterCode = existing?.workCenterCode;
  String? workCenterName = isEnglish && (existing?.workCenterNameEn ?? '').isNotEmpty ? existing?.workCenterNameEn : existing?.workCenterNameTh;
  final nameCtrl = TextEditingController(text: existing?.operationName ?? '');
  final laborCtrl = TextEditingController(text: existing != null ? '${existing.plannedLaborHours}' : '0');
  final machineCtrl = TextEditingController(text: existing != null ? '${existing.plannedMachineHours}' : '0');

  return showDialog<MoOperationDetail>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
      Widget buildFkField({required String label, required String? displayText, required bool hasValue, required VoidCallback onSearch}) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InputDecorator(
              decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              child: Row(children: [
                Expanded(
                  child: hasValue
                      ? Text(displayText ?? '', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)
                      : Text(isEnglish ? '— Not specified —' : '— ไม่ระบุ —', style: TextStyle(color: Colors.grey.shade600)),
                ),
                IconButton(icon: const Icon(Icons.search, color: Colors.teal), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onSearch),
              ]),
            ),
          );

      return AlertDialog(
        title: Text(existing == null ? (isEnglish ? 'Add Operation' : 'เพิ่มขั้นตอนการผลิต') : (isEnglish ? 'Edit Operation' : 'แก้ไขขั้นตอนการผลิต')),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            buildFkField(
              label: isEnglish ? 'Work Center *' : 'ศูนย์งาน *',
              hasValue: workCenterId != null,
              displayText: '$workCenterCode — $workCenterName',
              onSearch: () => MoWorkCenterListWidget.search(ctx, onSelected: (MoWorkCenter w) {
                setDlg(() {
                  workCenterId = w.id; workCenterCode = w.workCenterCode;
                  workCenterName = isEnglish && (w.workCenterNameEn ?? '').isNotEmpty ? w.workCenterNameEn : w.workCenterNameTh;
                });
              }),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: isEnglish ? 'Operation Name' : 'ชื่อขั้นตอน', border: const OutlineInputBorder()),
              ),
            ),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: laborCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  decoration: InputDecoration(labelText: isEnglish ? 'Labor Hrs' : 'ชม. แรงงาน', border: const OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: machineCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  decoration: InputDecoration(labelText: isEnglish ? 'Machine Hrs' : 'ชม. เครื่องจักร', border: const OutlineInputBorder()),
                ),
              ),
            ]),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(
            onPressed: () {
              if (workCenterId == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please select a work center' : 'กรุณาเลือกศูนย์งาน')));
                return;
              }
              Navigator.of(ctx).pop(MoOperationDetail(
                id: existing?.id,
                headerId: existing?.headerId,
                lineNo: existing?.lineNo ?? 1,
                workCenterId: workCenterId!,
                workCenterCode: workCenterCode,
                workCenterNameTh: workCenterName,
                operationName: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
                plannedLaborHours: double.tryParse(laborCtrl.text) ?? 0,
                plannedMachineHours: double.tryParse(machineCtrl.text) ?? 0,
              ));
            },
            child: Text(isEnglish ? 'OK' : 'ตกลง'),
          ),
        ],
      );
    }),
  );
}

String _uomDisplayName(String? code, String? nameTh, String? nameEn, bool isEnglish) {
  if (isEnglish && (nameEn ?? '').isNotEmpty) return nameEn!;
  if ((nameTh ?? '').isNotEmpty) return nameTh!;
  return code ?? '';
}

class MoHeaderDetailWidget extends StatefulWidget {
  final int? transactionId;
  final bool viewOnly;
  final int resetKey;
  final VoidCallback onSaveSuccess;
  final VoidCallback onCancel;
  final bool canDelete;

  const MoHeaderDetailWidget({
    super.key,
    required this.transactionId,
    this.viewOnly = false,
    this.resetKey = 0,
    required this.onSaveSuccess,
    required this.onCancel,
    this.canDelete = true,
  });

  @override
  State<MoHeaderDetailWidget> createState() => _MoHeaderDetailWidgetState();
}

class _MoHeaderDetailWidgetState extends State<MoHeaderDetailWidget> {
  final _service = MoHeaderService();
  final _bomService = MoBomService();
  final _fmtQty = NumberFormat('#,##0.####');
  final _dateFmt = DateFormat('dd/MM/yyyy');
  bool _isEnglish = false;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isLoadingBom = false;

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

  int? _bomHeaderId; String? _bomVersion; String? _bomParentItemCode; String? _bomParentItemName;
  ImWarehouse? _warehouse;
  late TextEditingController _orderQtyCtrl;
  int? _uomId; String? _uomCode; String? _uomName;
  String _issueMethod = 'EXPLICIT';
  String _costingMethod = 'ACTUAL';
  String _costingMode = 'OVERHEAD_PERCENT';
  late TextEditingController _overheadPercentCtrl;
  final _descCtrl = TextEditingController();

  static const _moSysDocType = '10';
  List<ModuleDocument> _allowedDocTypes = [];
  ModuleDocument? _docType;

  List<MoComponentDetail> _components = [];
  List<MoOutputDetail> _outputs = [];
  List<MoOperationDetail> _operations = [];

  // Rejected แก้ไขแล้วส่งขออนุมัติใหม่ได้เหมือน Draft
  bool get _isEditable => ['Draft', 'Rejected'].contains(_status);
  bool get _isReadOnly => widget.viewOnly || !_isEditable;

  @override
  void initState() {
    super.initState();
    _orderQtyCtrl = TextEditingController(text: '1');
    _overheadPercentCtrl = TextEditingController(text: '0');
    _load();
  }

  @override
  void didUpdateWidget(covariant MoHeaderDetailWidget old) {
    super.didUpdateWidget(old);
    if (widget.transactionId != old.transactionId || widget.resetKey != old.resetKey) {
      _load();
    }
  }

  @override
  void dispose() {
    _orderQtyCtrl.dispose();
    _overheadPercentCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
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
    _bomHeaderId = null; _bomVersion = null; _bomParentItemCode = null; _bomParentItemName = null;
    _warehouse = null;
    _orderQtyCtrl.text = '1';
    _uomId = null; _uomCode = null; _uomName = null;
    _issueMethod = 'EXPLICIT';
    _costingMethod = 'ACTUAL';
    _costingMode = 'OVERHEAD_PERCENT';
    _overheadPercentCtrl.text = '0';
    _descCtrl.clear();
    _components = [];
    _outputs = [];
    _operations = [];
  }

  Future<void> _load() async {
    final isEnglish = _isEnglish;
    setState(() => _isLoading = true);
    try {
      if (_allowedDocTypes.isEmpty) {
        final docTypes = await _service.fetchDocTypesByUser();
        _allowedDocTypes = docTypes.where((d) => d.isDocType && d.sysDocType == _moSysDocType).toList();
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
        _bomHeaderId = h.bomHeaderId; _bomVersion = h.bomVersion;
        _bomParentItemCode = h.bomParentItemCode;
        _bomParentItemName = isEnglish && (h.bomParentItemNameEn ?? '').isNotEmpty ? h.bomParentItemNameEn : h.bomParentItemNameTh;
        _warehouse = ImWarehouse(id: h.warehouseId, warehouseCode: h.warehouseCode ?? '', warehouseNameTh: h.warehouseNameTh ?? '', warehouseNameEn: h.warehouseNameEn);
        _orderQtyCtrl.text = '${h.orderQty}';
        _uomId = h.uomId; _uomCode = h.uomCode;
        _uomName = isEnglish && (h.uomNameEn ?? '').isNotEmpty ? h.uomNameEn : h.uomNameTh;
        _issueMethod = h.issueMethod;
        _costingMethod = h.costingMethod;
        _costingMode = h.costingMode;
        _overheadPercentCtrl.text = '${h.overheadPercent}';
        _descCtrl.text = h.description ?? '';
        _components = List.from(h.components);
        _outputs = List.from(h.outputs);
        _operations = List.from(h.operations);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
      final orderQty = double.tryParse(_orderQtyCtrl.text) ?? 0;
      final scale = (bom.bomQty == 0 ? 1 : (orderQty <= 0 ? bom.bomQty : orderQty) / bom.bomQty);
      if (orderQty <= 0) _orderQtyCtrl.text = '${bom.bomQty}';

      final newComponents = bom.details.map((d) => MoComponentDetail(
            componentItemId: d.componentItemId,
            itemCode: d.componentItemCode,
            itemName: isEnglish && (d.componentItemNameEn ?? '').isNotEmpty ? d.componentItemNameEn : d.componentItemNameTh,
            plannedQty: d.quantityPer * scale * (1 + d.scrapPercent / 100),
            uomId: d.uomId, uomCode: d.uomCode, uomNameTh: d.uomNameTh, uomNameEn: d.uomNameEn,
            lineNo: 1,
          )).toList();

      final newOutputs = <MoOutputDetail>[
        MoOutputDetail(
          outputItemId: bom.parentItemId,
          itemCode: bom.parentItemCode,
          itemName: isEnglish && (bom.parentItemNameEn ?? '').isNotEmpty ? bom.parentItemNameEn : bom.parentItemNameTh,
          plannedQty: bom.bomQty * scale,
          uomId: bom.outputUomId, uomCode: bom.outputUomCode, uomNameTh: bom.outputUomNameTh, uomNameEn: bom.outputUomNameEn,
          isPrimaryOutput: true,
          lineNo: 1,
        ),
        ...bom.outputs.map((o) => MoOutputDetail(
              outputItemId: o.outputItemId,
              itemCode: o.outputItemCode,
              itemName: isEnglish && (o.outputItemNameEn ?? '').isNotEmpty ? o.outputItemNameEn : o.outputItemNameTh,
              plannedQty: o.outputQtyPer * scale,
              uomId: o.uomId, uomCode: o.uomCode, uomNameTh: o.uomNameTh, uomNameEn: o.uomNameEn,
              isPrimaryOutput: false,
              lineNo: 1,
            )),
      ];

      final newOperations = bom.operations.map((op) => MoOperationDetail(
            workCenterId: op.workCenterId,
            workCenterCode: op.workCenterCode,
            workCenterNameTh: op.workCenterNameTh,
            workCenterNameEn: op.workCenterNameEn,
            operationName: op.operationName,
            plannedLaborHours: op.standardLaborHours * scale + op.setupHours,
            plannedMachineHours: op.standardMachineHours * scale,
            lineNo: 1,
          )).toList();

      setState(() {
        _components = newComponents;
        _outputs = newOutputs;
        _operations = newOperations;
        _issueMethod = bom.issueMethod;
        _costingMethod = bom.costingMethod;
        _costingMode = bom.costingMode;
        _overheadPercentCtrl.text = '${bom.overheadPercent}';
        if (_uomId == null) {
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

  Future<void> _pickUom() async {
    final isEnglish = _isEnglish;
    await ImUomListWidget.search(context, onSelected: (ImUom u) {
      setState(() {
        _uomId = u.id;
        _uomCode = u.uomCode;
        _uomName = isEnglish && (u.uomNameEn ?? '').isNotEmpty ? u.uomNameEn : u.uomNameTh;
      });
    });
  }

  Future<void> _addComponent() async {
    final result = await _showComponentDialog(context, null);
    if (result != null) setState(() => _components.add(result));
  }

  Future<void> _editComponent(int index) async {
    final result = await _showComponentDialog(context, _components[index]);
    if (result != null) setState(() => _components[index] = result);
  }

  void _removeComponent(int index) => setState(() => _components.removeAt(index));

  Future<void> _addOutput() async {
    final result = await _showOutputDialog(context, null);
    if (result != null) setState(() => _outputs.add(result));
  }

  Future<void> _editOutput(int index) async {
    final result = await _showOutputDialog(context, _outputs[index]);
    if (result != null) setState(() => _outputs[index] = result);
  }

  void _removeOutput(int index) => setState(() => _outputs.removeAt(index));

  Future<void> _addOperation() async {
    final result = await _showOperationDialog(context, null);
    if (result != null) setState(() => _operations.add(result));
  }

  Future<void> _editOperation(int index) async {
    final result = await _showOperationDialog(context, _operations[index]);
    if (result != null) setState(() => _operations[index] = result);
  }

  void _removeOperation(int index) => setState(() => _operations.removeAt(index));

  Future<void> _save() async {
    final isEnglish = _isEnglish;
    if (_docType == null) { _warn(isEnglish ? 'Please select a document type' : 'กรุณาเลือกประเภทเอกสาร'); return; }
    if (_warehouse == null) { _warn(isEnglish ? 'Please select a warehouse' : 'กรุณาระบุคลังปลายทาง'); return; }
    final orderQty = double.tryParse(_orderQtyCtrl.text) ?? 0;
    if (orderQty <= 0) { _warn(isEnglish ? 'Please enter an order qty greater than 0' : 'กรุณาระบุจำนวนที่สั่งผลิตให้มากกว่า 0'); return; }
    if (_components.isEmpty) { _warn(isEnglish ? 'At least 1 component is required' : 'ต้องมีส่วนประกอบอย่างน้อย 1 รายการ'); return; }
    if (_outputs.isEmpty) { _warn(isEnglish ? 'At least 1 output is required' : 'ต้องมีผลผลิตอย่างน้อย 1 รายการ'); return; }
    setState(() => _isSaving = true);
    try {
      final header = MoHeader(
        id: _id ?? 0, docId: _docId ?? 0, docNo: _docNo, docDate: _docDate,
        bomHeaderId: _bomHeaderId, warehouseId: _warehouse!.id, orderQty: orderQty, uomId: _uomId,
        issueMethod: _issueMethod, costingMethod: _costingMethod, costingMode: _costingMode,
        overheadPercent: double.tryParse(_overheadPercentCtrl.text) ?? 0,
        dueDate: _dueDate, description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      );
      if (_id == null) {
        await _service.createTransaction(header: header, components: _components, outputs: _outputs, operations: _operations);
      } else {
        await _service.updateTransaction(id: _id!, header: header, components: _components, outputs: _outputs, operations: _operations);
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

  // ปุ่มที่ทำไม่ได้: ล็อกและแสดงเหตุผลเมื่อชี้เมาส์
  Widget _lockable(DocBlock? block, Widget Function(VoidCallback? onPressed) builder, VoidCallback action) {
    final button = builder(block == null && !_isSaving ? action : null);
    return block == null ? button : Tooltip(message: block.text(_isEnglish), child: button);
  }

  void _warn(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.orange));
  }

  String _docTypeLabel(ModuleDocument d) => _isEnglish && d.docNameEng.isNotEmpty ? d.docNameEng : d.docNameThai;

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
                    onChanged: (_isReadOnly || _id != null) ? null : (v) => setState(() { _docType = v; _docId = v?.id; }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('${isEnglish ? "MO No." : "เลขที่ใบสั่งผลิต"}: $_docNo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blueGrey.shade100, borderRadius: BorderRadius.circular(12)),
                  child: Text(moHeaderStatusLabel(_status, isEnglish), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
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
                    label: isEnglish ? 'BOM (optional)' : 'สูตรการผลิต (ไม่บังคับ)',
                    hasValue: _bomHeaderId != null,
                    displayText: '$_bomParentItemCode — $_bomParentItemName (v$_bomVersion)',
                    onSearch: _isReadOnly ? null : _pickBom,
                  ),
                ),
                if (!_isReadOnly && _bomHeaderId != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _isLoadingBom ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync, color: Colors.teal),
                    tooltip: isEnglish ? 'Reload lines from BOM' : 'โหลดรายการจากสูตรใหม่',
                    onPressed: _isLoadingBom ? null : _loadFromBom,
                  ),
                ],
                const SizedBox(width: 4),
                Expanded(
                  child: _fkField(
                    label: isEnglish ? 'Warehouse *' : 'คลังปลายทาง *',
                    hasValue: _warehouse != null,
                    displayText: '${_warehouse?.warehouseCode ?? ''}  ${_warehouse?.warehouseNameTh ?? ''}',
                    onSearch: _isReadOnly ? null : () => ImWarehouseListWidget.search(context, onSelected: (w) => setState(() => _warehouse = w)),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('mo_qty_${widget.resetKey}_$_id'),
                    controller: _orderQtyCtrl,
                    enabled: !_isReadOnly,
                    decoration: InputDecoration(labelText: isEnglish ? 'Order Qty *' : 'จำนวนที่สั่งผลิต *', border: const OutlineInputBorder(), isDense: true),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _fkField(
                    label: isEnglish ? 'UOM' : 'หน่วยนับ',
                    hasValue: _uomId != null,
                    displayText: '$_uomCode — $_uomName',
                    onSearch: _isReadOnly ? null : _pickUom,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                readOnly: _isReadOnly,
                controller: _descCtrl,
                decoration: InputDecoration(labelText: isEnglish ? 'Description' : 'คำอธิบาย', border: const OutlineInputBorder(), isDense: true),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        // นโยบายต้นทุน — เติมค่ามาจากสูตรตอนโหลด (ถ้ามี) override เป็นรายใบนี้ได้ (ดูแผนออกแบบโมดูล MO — ควรจำกัด
        // สิทธิ์แก้ไข section นี้ไว้ที่กลุ่มผู้ใช้ Costing เท่านั้น)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isEnglish ? 'Costing Policy' : 'นโยบายต้นทุน', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _issueMethod,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: isEnglish ? 'Material Issue' : 'วิธีเบิกวัตถุดิบ', border: const OutlineInputBorder(), isDense: true),
                    items: moIssueMethods.map((m) => DropdownMenuItem(value: m, child: Text(moIssueMethodLabel(m, isEnglish)))).toList(),
                    onChanged: _isReadOnly ? null : (v) => setState(() => _issueMethod = v ?? 'EXPLICIT'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _costingMethod,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: isEnglish ? 'Output Costing' : 'วิธีตีมูลค่าผลผลิต', border: const OutlineInputBorder(), isDense: true),
                    items: moCostingMethods.map((m) => DropdownMenuItem(value: m, child: Text(moCostingMethodLabel(m, isEnglish)))).toList(),
                    onChanged: _isReadOnly ? null : (v) => setState(() => _costingMethod = v ?? 'ACTUAL'),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _costingMode,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: isEnglish ? 'Conversion Cost' : 'ต้นทุนแปรรูป', border: const OutlineInputBorder(), isDense: true),
                    items: moCostingModes.map((m) => DropdownMenuItem(value: m, child: Text(moCostingModeLabel(m, isEnglish)))).toList(),
                    onChanged: _isReadOnly ? null : (v) => setState(() => _costingMode = v ?? 'OVERHEAD_PERCENT'),
                  ),
                ),
                const SizedBox(width: 10),
                if (_costingMode == 'OVERHEAD_PERCENT')
                  Expanded(
                    child: TextFormField(
                      readOnly: _isReadOnly,
                      controller: _overheadPercentCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      decoration: InputDecoration(labelText: isEnglish ? 'Overhead %' : 'เปอร์เซ็นต์ Overhead', border: const OutlineInputBorder(), isDense: true),
                    ),
                  )
                else
                  const Expanded(child: SizedBox.shrink()),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        _buildComponentsCard(isEnglish),
        const SizedBox(height: 12),
        _buildOutputsCard(isEnglish),
        if (_costingMode == 'ROUTING') ...[
          const SizedBox(height: 12),
          _buildOperationsCard(isEnglish),
        ],
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(onPressed: widget.onCancel, child: Text(isEnglish ? 'Close' : 'ปิด')),
          const SizedBox(width: 8),
          if (_isEditable && !widget.viewOnly)
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: const Icon(Icons.save, size: 18),
              label: Text(isEnglish ? 'Save' : 'บันทึก'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[800], foregroundColor: Colors.white),
            ),
          // ส่งขออนุมัติ — อนุมัติครบแล้วจึงปล่อยใบสั่งผลิต (ไม่มีผู้อนุมัติ: ตามตัวเลือกของเมนู ให้ผ่าน/ไม่ให้ผ่าน)
          if (_isEditable && _id != null && !widget.viewOnly && perm?.id != null) ...[
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : () => _confirmAction(
                  'ยืนยันการส่งขออนุมัติ', 'Confirm Submit for Approval',
                  'ส่งขออนุมัติใบสั่งผลิต $_docNo? ระหว่างรออนุมัติจะแก้ไขไม่ได้ อนุมัติครบแล้วจึงปล่อยให้ฝ่ายผลิตเริ่มเบิก/รับได้',
                  'Submit MO $_docNo for approval? It cannot be edited while waiting. It is released to production once approved.',
                  () => _service.submitTransaction(_id!, menuId: perm!.id)),
              icon: const Icon(Icons.send, size: 18),
              label: Text(isEnglish ? 'Submit' : 'ส่งขออนุมัติ'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[700], foregroundColor: Colors.white),
            ),
          ],
          if (_isEditable && _id != null && widget.canDelete && !widget.viewOnly) ...[
            const SizedBox(width: 8),
            _lockable(_actions.deleteBlock, (onPressed) => OutlinedButton.icon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(isEnglish ? 'Delete' : 'ลบ'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red[700]),
                ), _deleteMo),
          ],
          if ((['Released', 'InProgress', 'Completed', 'Closed'].contains(_status) && canApprove ||
                  _status == 'Submitted') && _id != null && !widget.viewOnly) ...[
            const SizedBox(width: 8),
            _lockable(_actions.reverseBlock, (onPressed) => OutlinedButton.icon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.undo, size: 18),
                  label: Text(_status == 'Closed'
                      ? (isEnglish ? 'Reverse Closing' : 'ถอยการปิด')
                      : (isEnglish ? 'Reverse to Draft' : 'ถอยเป็นร่าง')),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.orange[800]),
                ), _reverse),
          ],
          if (['Released', 'InProgress', 'Completed'].contains(_status) && _id != null && canApprove && !widget.viewOnly) ...[
            const SizedBox(width: 8),
            _lockable(_actions.voidBlock, (onPressed) => OutlinedButton.icon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: Text(isEnglish ? 'Cancel MO' : 'ยกเลิกใบสั่งผลิต'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red[700]),
                ), _cancelMo),
          ],
          if (_status == 'Completed' && _id != null && canApprove && !widget.viewOnly) ...[
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _closeMo,
              icon: const Icon(Icons.lock_outline, size: 18),
              label: Text(isEnglish ? 'Close MO' : 'ปิดใบสั่งผลิต'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[700], foregroundColor: Colors.white),
            ),
          ],
        ]),
        if (_id != null && _approvals.isNotEmpty)
          DocApprovalPanel(
            docNo: _docNo,
            approvals: _approvals,
            approvalMode: _approvalMode,
            awaiting: _status == 'Submitted' && !widget.viewOnly,
            // อนุมัติครบ = ปล่อยใบสั่งผลิต
            onApprove: (r) => _service.approveTransaction(_id!, remarks: r),
            onReject: (r) => _service.rejectTransaction(_id!, remarks: r),
            onDone: _load,
          ),
        if (_status == 'Cancelled' && (_cancelReason ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('${isEnglish ? 'Cancel reason' : 'เหตุผลการยกเลิก'}: $_cancelReason',
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

  Widget _buildComponentsCard(bool isEnglish) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(isEnglish ? 'Components (${_components.length})' : 'ส่วนประกอบ (${_components.length})', style: const TextStyle(fontWeight: FontWeight.bold))),
            if (!_isReadOnly)
              OutlinedButton.icon(onPressed: _addComponent, icon: const Icon(Icons.add, size: 16), label: Text(isEnglish ? 'Add' : 'เพิ่ม')),
          ]),
          const Divider(),
          if (_components.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(isEnglish ? 'No components yet' : 'ยังไม่มีส่วนประกอบ', style: TextStyle(color: Colors.grey.shade600)))
          else
            ..._components.asMap().entries.map((entry) {
              final i = entry.key;
              final c = entry.value;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${c.itemCode}  ${c.itemName ?? ''}'),
                subtitle: Text(isEnglish
                    ? 'Planned: ${_fmtQty.format(c.plannedQty)} ${_uomDisplayName(c.uomCode, c.uomNameTh, c.uomNameEn, isEnglish)}${c.issuedQty > 0 ? '  ·  Issued: ${_fmtQty.format(c.issuedQty)}' : ''}'
                    : 'ที่วางแผน: ${_fmtQty.format(c.plannedQty)} ${_uomDisplayName(c.uomCode, c.uomNameTh, c.uomNameEn, isEnglish)}${c.issuedQty > 0 ? '  ·  เบิกแล้ว: ${_fmtQty.format(c.issuedQty)}' : ''}'),
                trailing: _isReadOnly
                    ? null
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _editComponent(i)),
                        IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _removeComponent(i)),
                      ]),
              );
            }),
        ]),
      ),
    );
  }

  Widget _buildOutputsCard(bool isEnglish) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(isEnglish ? 'Outputs (${_outputs.length})' : 'ผลผลิต (${_outputs.length})', style: const TextStyle(fontWeight: FontWeight.bold))),
            if (!_isReadOnly)
              OutlinedButton.icon(onPressed: _addOutput, icon: const Icon(Icons.add, size: 16), label: Text(isEnglish ? 'Add' : 'เพิ่ม')),
          ]),
          const Divider(),
          if (_outputs.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(isEnglish ? 'No outputs yet' : 'ยังไม่มีผลผลิต', style: TextStyle(color: Colors.grey.shade600)))
          else
            ..._outputs.asMap().entries.map((entry) {
              final i = entry.key;
              final o = entry.value;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: o.isPrimaryOutput ? const Icon(Icons.star, size: 18, color: Colors.amber) : null,
                title: Text('${o.itemCode}  ${o.itemName ?? ''}'),
                subtitle: Text(isEnglish
                    ? 'Planned: ${_fmtQty.format(o.plannedQty)} ${_uomDisplayName(o.uomCode, o.uomNameTh, o.uomNameEn, isEnglish)}${o.receivedQty > 0 ? '  ·  Received: ${_fmtQty.format(o.receivedQty)}' : ''}'
                    : 'ที่วางแผน: ${_fmtQty.format(o.plannedQty)} ${_uomDisplayName(o.uomCode, o.uomNameTh, o.uomNameEn, isEnglish)}${o.receivedQty > 0 ? '  ·  รับแล้ว: ${_fmtQty.format(o.receivedQty)}' : ''}'),
                trailing: _isReadOnly
                    ? null
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _editOutput(i)),
                        IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _removeOutput(i)),
                      ]),
              );
            }),
        ]),
      ),
    );
  }

  Widget _buildOperationsCard(bool isEnglish) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(isEnglish ? 'Routing (${_operations.length})' : 'ขั้นตอนการผลิต (${_operations.length})', style: const TextStyle(fontWeight: FontWeight.bold))),
            if (!_isReadOnly)
              OutlinedButton.icon(onPressed: _addOperation, icon: const Icon(Icons.add, size: 16), label: Text(isEnglish ? 'Add' : 'เพิ่ม')),
          ]),
          const Divider(),
          if (_operations.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(isEnglish ? 'No operations yet' : 'ยังไม่มีขั้นตอนการผลิต', style: TextStyle(color: Colors.grey.shade600)))
          else
            ..._operations.asMap().entries.map((entry) {
              final i = entry.key;
              final op = entry.value;
              final wcName = isEnglish && (op.workCenterNameEn ?? '').isNotEmpty ? op.workCenterNameEn : op.workCenterNameTh;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${op.workCenterCode}  $wcName${(op.operationName ?? '').isNotEmpty ? ' — ${op.operationName}' : ''}'),
                subtitle: Text(isEnglish
                    ? 'Planned labor ${op.plannedLaborHours} hr · machine ${op.plannedMachineHours} hr${op.actualLaborHours > 0 || op.actualMachineHours > 0 ? '  ·  Actual labor ${op.actualLaborHours} hr · machine ${op.actualMachineHours} hr' : ''}'
                    : 'แรงงานที่วางแผน ${op.plannedLaborHours} ชม. · เครื่องจักร ${op.plannedMachineHours} ชม.${op.actualLaborHours > 0 || op.actualMachineHours > 0 ? '  ·  แรงงานจริง ${op.actualLaborHours} ชม. · เครื่องจักร ${op.actualMachineHours} ชม.' : ''}'),
                trailing: _isReadOnly
                    ? null
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _editOperation(i)),
                        IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _removeOperation(i)),
                      ]),
              );
            }),
        ]),
      ),
    );
  }
}
