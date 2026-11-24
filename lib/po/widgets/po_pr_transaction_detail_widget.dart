// lib/po/widgets/po_pr_transaction_detail_widget.dart — แก้ไขรายละเอียดใบขอซื้อ (header+lines) + แผงอนุมัติ
// มิเรอร์โครงสร้าง po_transaction_detail_widget.dart แต่ vendor/warehouse ไม่บังคับ (PR คือ "ขอซื้ออะไร" ไม่ใช่
// "ซื้อจากใคร/ลงคลังไหน") และเพิ่มขั้นตอน Submit->Approve/Reject ผ่านคิวอนุมัติจริง (sa_module_approver) มิเรอร์
// แผงอนุมัติกลาง DocApprovalPanel (คิวที่ตาราง doc_approval) — ดู poPrTransactionController.js สำหรับ workflow เต็ม (ย้ายมา
// รวมกับโฟลเดอร์ po เดิมอยู่ lib/pr/)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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
import '../models/po_pr_transaction.dart';
import '../../im/services/im_item_service.dart';
import '../services/po_pr_transaction_service.dart';
import '../../im/widgets/im_warehouse_list_widget.dart';
import '../../cd/models/cd_currency.dart';
import '../../cd/services/cd_currency_service.dart';
import '../../sa/widgets/sa_attachment_widget.dart';
import '../../sa/models/sa_doc_approval.dart';
import '../../sa/widgets/sa_doc_approval_panel.dart';
import '../../gl/models/gl_dimension.dart';
import '../../gl/widgets/gl_line_account_dims.dart';
import '../../cd/models/cd_branch.dart';
import '../../cd/services/cd_branch_service.dart';
import '../../cd/widgets/cd_user_branch_picker.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../../sa/widgets/sa_doc_list_kit.dart';
import '../../gl/widgets/gl_dimension_picker_field.dart';

class PrTransactionDetailWidget extends StatefulWidget {
  final int? transactionId;
  final bool viewOnly;
  final int resetKey;
  final VoidCallback onSaveSuccess;
  final VoidCallback onCancel;
  final bool canDelete;
  /// ปุ่มของเอกสารแสดงบน AppBar ของหน้าจอแม่ (แทนแถบปุ่มเดิม)
  final DocAppBarActions? actions;
  // คัดลอกใบขอซื้อเดิมเป็นฉบับร่างใหม่ — ใช้ได้เฉพาะตอน transactionId เป็น null (โหมดสร้างใหม่) เท่านั้น
  // ดู _load()/onCopyRequested สำหรับตรรกะเต็ม (มิเรอร์ po_transaction_detail_widget.dart ทุกประการ)
  final int? copyFromId;
  final ValueChanged<int>? onCopyRequested;

  const PrTransactionDetailWidget({
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
  State<PrTransactionDetailWidget> createState() => _PrTransactionDetailWidgetState();
}

class _LineForm {
  int? id;
  ImItem? item;
  double qtyRequested;
  DateTime? neededByDate;
  double estimatedUnitCost;
  double qtyConverted;
  // หน่วยของบรรทัด — จำนวน/ราคาประมาณตามหน่วยนี้ (ไม่ระบุ = หน่วยหลัก) factor = จำนวนหน่วยหลักต่อ 1 หน่วย
  // uoms = หน่วยที่สินค้าอนุญาตให้ซื้อ (null = ยังไม่โหลด)
  int? uomId;
  String? uomCode, uomNameTh, uomNameEn;
  double factor;
  ImItemUoms? uoms;
  final TextEditingController qtyCtrl, costCtrl, remarkCtrl; // หมายเหตุต่อบรรทัด = pr_transaction_detail.description
  _LineForm({this.id, this.item, this.qtyRequested = 0, this.neededByDate, this.estimatedUnitCost = 0, this.qtyConverted = 0,
      this.uomId, this.uomCode, this.uomNameTh, this.uomNameEn, this.factor = 1, String? remark})
      : qtyCtrl = TextEditingController(text: _numText(qtyRequested)),
        costCtrl = TextEditingController(text: _numText(estimatedUnitCost)),
        remarkCtrl = TextEditingController(text: remark ?? '');
  double get totalValueLc => qtyRequested * estimatedUnitCost;
  String? get remark => remarkCtrl.text.trim().isEmpty ? null : remarkCtrl.text.trim();
  void dispose() {
    qtyCtrl.dispose();
    costCtrl.dispose();
    remarkCtrl.dispose();
  }
}

String _numText(double v) => v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

class _PrTransactionDetailWidgetState extends State<PrTransactionDetailWidget> implements DocAppBarActionsHost {
  final _service = PrTransactionService();
  final _itemService = ImItemService();
  final _currencyService = CurrencyService();
  final _fmtQty = NumberFormat('#,##0.####');
  final _fmt = NumberFormat('#,##0.00');
  bool _headerExpanded = true;
  final _dateFmt = DateFormat('dd/MM/yyyy');
  bool _isEnglish = false;
  bool _isLoading = false;
  bool _isSaving = false;

  int? _id;
  int? _docId;
  String _docNo = 'AUTO';
  DateTime _docDate = DateTime.now();
  ApVendor? _vendor;
  ImWarehouse? _warehouse;
  final _descCtrl = TextEditingController();
  String _status = 'Draft';
  String? _voidReason;
  DocActions _actions = const DocActions();
  List<DocApprovalStep> _approvals = [];
  String? _approvalMode;

  // รองรับขอซื้อสินค้าต่างประเทศเป็นสกุลเงินต่างประเทศ — มิเรอร์ po_transaction_detail_widget.dart ทุกประการ
  List<Currency> _currencies = [];
  Currency? _currency;
  double _exchangeRate = 1;

  // sys_module='51' มีมากกว่าหนึ่งประเภทเอกสารได้ (เช่น POR ของ PO, PRQ ของ PR) จึงต้องกรองซ้ำด้วย sys_doc_type
  // '05' คือ PR (ตาม poSysDocType ใน sa_anan_module.dart) แล้วให้ผู้ใช้เลือกเองเหมือนหน้าจอธุรกรรม AR/AP
  static const _prSysDocType = '05';
  List<ModuleDocument> _allowedDocTypes = [];
  ModuleDocument? _docType;

  List<_LineForm> _lines = [];

  // มิติหัวเอกสาร — user-approved 2026-11-02
  List<GlDimensionType> _dimTypes = [];
  Map<String, List<GlDimensionValue>> _dimValues = {};
  Map<int, int?> _dimSelections = {};
  // สาขา (user-approved 2026-11-18): ค่าเริ่มต้น สาขาของผู้ใช้ → สาขาของคลัง; ส่งต่อให้เอกสารที่อ้างอิง
  int? _branchId;
  List<Branch> _branches = [];
  bool _dimsLoaded = false;
  bool get _isReadOnly => widget.viewOnly || !['Draft', 'Rejected'].contains(_status);

  @override
  void initState() {
    super.initState();
    widget.actions?.attach(this);
    _load();
  }

  @override
  void didUpdateWidget(covariant PrTransactionDetailWidget old) {
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
    _descCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
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
    _vendor = null;
    _warehouse = null;
    _descCtrl.clear();
    _dimSelections = {};
    _branchId = defaultDocBranchId();
    _status = 'Draft';
    _voidReason = null;
    _actions = const DocActions();
    _approvals = [];
    _currency = _currencies.cast<Currency?>().firstWhere((c) => c?.baseCurrencyFlag == true, orElse: () => null);
    _exchangeRate = _currency?.baseRate ?? 1;
    _disposeLines();
    _lines = [];
  }

  Future<void> _load() async {
    final isEnglish = _isEnglish;
    setState(() => _isLoading = true);
    try {
      if (_allowedDocTypes.isEmpty) {
        final docTypes = await _service.fetchDocTypesByUser();
        _allowedDocTypes = docTypes.where((d) => d.isDocType && d.sysDocType == _prSysDocType).toList();
      }
      if (_currencies.isEmpty) {
        _currencies = await _currencyService.fetchActiveRows();
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
        _vendor = h.vendorId != null ? ApVendor(id: h.vendorId, vendorCode: h.vendorCode ?? '', vendorNameTh: h.vendorNameTh ?? '') : null;
        _warehouse = h.warehouseId != null
            ? ImWarehouse(id: h.warehouseId!, warehouseCode: h.warehouseCode ?? '', warehouseNameTh: h.warehouseNameTh ?? '', warehouseNameEn: h.warehouseNameEn)
            : null;
        _descCtrl.text = h.description ?? '';
        _dimSelections = {1: h.dim1Id, 2: h.dim2Id, 3: h.dim3Id, 4: h.dim4Id, 5: h.dim5Id};
        _branchId = h.branchId;
        _status = 'Draft';
        _voidReason = null;
        _actions = const DocActions();
        _approvals = [];
        _currency = _currencies.cast<Currency?>().firstWhere(
            (c) => c?.id == h.currencyId || c?.currencyCode == h.currencyCode, orElse: () => null);
        _exchangeRate = h.exchangeRate;
        final items = await Future.wait(h.details.map((d) => _itemService.fetchRow(d.itemId)));
        _disposeLines();
        _lines = [
          for (var i = 0; i < h.details.length; i++)
            _LineForm(
              item: items[i],
              qtyRequested: h.details[i].qtyRequested,
              neededByDate: h.details[i].neededByDate,
              estimatedUnitCost: h.details[i].estimatedUnitCost,
              uomId: h.details[i].uomId ?? items[i].baseUomId,
              uomCode: h.details[i].uomCode ?? items[i].baseUomCode,
              uomNameTh: h.details[i].uomId != null ? h.details[i].uomNameTh : items[i].baseUomNameTh,
              uomNameEn: h.details[i].uomId != null ? h.details[i].uomNameEn : items[i].baseUomNameEn,
              factor: h.details[i].conversionFactor,
              remark: h.details[i].description,
            ),
        ];
        for (final l in _lines) { _loadLineUoms(l); }
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
        _vendor = h.vendorId != null ? ApVendor(id: h.vendorId, vendorCode: h.vendorCode ?? '', vendorNameTh: h.vendorNameTh ?? '') : null;
        _warehouse = h.warehouseId != null
            ? ImWarehouse(id: h.warehouseId!, warehouseCode: h.warehouseCode ?? '', warehouseNameTh: h.warehouseNameTh ?? '', warehouseNameEn: h.warehouseNameEn)
            : null;
        _descCtrl.text = h.description ?? '';
        _dimSelections = {1: h.dim1Id, 2: h.dim2Id, 3: h.dim3Id, 4: h.dim4Id, 5: h.dim5Id};
        _branchId = h.branchId;
        _status = h.status;
        _voidReason = h.voidReason;
        _actions = h.actions;
        _approvals = h.approvals;
        _approvalMode = h.approvalMode;
        _currency = _currencies.cast<Currency?>().firstWhere(
            (c) => c?.id == h.currencyId || c?.currencyCode == h.currencyCode, orElse: () => null);
        _exchangeRate = h.exchangeRate;
        // ดึง ImItem เต็มจาก itemId เสมอ ไม่ใช้ค่า snapshot ที่บันทึกไว้ตอนสร้างเอกสารมาแสดงตรงๆ — มิเรอร์
        // po_transaction_detail_widget.dart ทุกประการ (ดู comment เดียวกันที่นั่น)
        final items = await Future.wait(h.details.map((d) => _itemService.fetchRow(d.itemId)));
        _disposeLines();
        _lines = [
          for (var i = 0; i < h.details.length; i++)
            _LineForm(
              id: h.details[i].id,
              item: items[i],
              qtyRequested: h.details[i].qtyRequested,
              neededByDate: h.details[i].neededByDate,
              estimatedUnitCost: h.details[i].estimatedUnitCost,
              qtyConverted: h.details[i].qtyConverted,
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

  void _selectVendor(ApVendor v) {
    setState(() {
      _vendor = v;
      // สกุลเงินหลักของผู้ขาย (ap_vendor.currency_code) — มิเรอร์ po_transaction_detail_widget.dart:_selectVendor
      if (v.currencyCode.isNotEmpty) {
        final matched = _currencies.cast<Currency?>().firstWhere((c) => c?.currencyCode == v.currencyCode, orElse: () => null);
        if (matched != null) {
          _currency = matched;
          _exchangeRate = matched.baseRate > 0 ? matched.baseRate : 1;
        }
      }
    });
  }

  Future<void> _addLine() async {
    final result = await showDialog<ImItem>(context: context, builder: (_) => const _PrItemPickerDialog());
    if (result == null || !mounted) return;
    final line = _LineForm(item: result, qtyRequested: 1, estimatedUnitCost: 0,
        uomId: result.baseUomId, uomCode: result.baseUomCode, uomNameTh: result.baseUomNameTh, uomNameEn: result.baseUomNameEn);
    setState(() => _lines.add(line));
    await _loadLineUoms(line, applyDefault: true); // หน่วยซื้อตั้งต้นของสินค้า
  }

  // หน่วยที่เลือกได้ของบรรทัด (หน่วยที่สินค้าอนุญาตให้ซื้อ) — applyDefault = ตั้งหน่วยซื้อตั้งต้นของสินค้า (บรรทัดใหม่)
  Future<void> _loadLineUoms(_LineForm l, {bool applyDefault = false}) async {
    final id = l.item?.id;
    if (id == null || _isReadOnly) return;
    try {
      final u = await _itemService.fetchItemUoms(id, purpose: 'PURCHASE');
      if (!mounted || !_lines.contains(l)) return;
      l.uoms = u;
      final def = u.byId(u.defaultUomId);
      if (applyDefault && def != null && def.uomId != l.uomId) {
        _setLineUom(l, def);
      } else {
        setState(() {});
      }
    } catch (_) {}
  }

  // เปลี่ยนหน่วยของบรรทัด — ราคาประมาณคูณตามอัตราใหม่ (ราคาต่อหน่วยหลักคงเดิม)
  void _setLineUom(_LineForm l, ImItemUomOption opt) {
    final ratio = l.factor == 0 ? 1.0 : opt.factor / l.factor;
    setState(() {
      if (ratio != 1 && l.estimatedUnitCost != 0) {
        l.estimatedUnitCost = (l.estimatedUnitCost * ratio * 1e4).roundToDouble() / 1e4;
        l.costCtrl.text = _numText(l.estimatedUnitCost);
      }
      l.uomId = opt.uomId;
      l.uomCode = opt.uomCode;
      l.uomNameTh = opt.uomNameTh;
      l.uomNameEn = opt.uomNameEn;
      l.factor = opt.factor;
    });
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
    if (_isReadOnly || opts.length <= 1 || l.qtyConverted > 0) {
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
  ({PrTransactionHeader header, List<PrTransactionDetail> details}) _savePayload() {
    final header = PrTransactionHeader(
      id: _id ?? 0, docId: _docId ?? 0, docNo: _docNo, docDate: _docDate,
      vendorId: _vendor?.id, warehouseId: _warehouse?.id,
      currencyId: _currency?.id, currencyCode: _currency?.currencyCode ?? CurrencyService.baseCode, exchangeRate: _exchangeRate,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      dim1Id: _dimSelections[1], dim2Id: _dimSelections[2], dim3Id: _dimSelections[3],
      dim4Id: _dimSelections[4], dim5Id: _dimSelections[5],
      branchId: _branchId,
    );
    final details = _lines
        .map((l) => PrTransactionDetail(
              id: l.id, lineNo: 0, itemId: l.item!.id!, itemCode: l.item!.itemCode, itemName: l.item!.itemNameTh,
              uomId: l.uomId, qtyRequested: l.qtyRequested, neededByDate: l.neededByDate, estimatedUnitCost: l.estimatedUnitCost,
              description: l.remark,
            ))
        .toList();
    return (header: header, details: details);
  }

  Future<void> _save() async {
    final isEnglish = _isEnglish;
    if (_docType == null) { _warn(isEnglish ? 'Please select a document type' : 'กรุณาเลือกประเภทเอกสาร'); return; }
    if (_lines.isEmpty) { _warn(isEnglish ? 'At least 1 line is required' : 'ต้องมีรายการขอซื้ออย่างน้อย 1 รายการ'); return; }
    for (final l in _lines) {
      if (l.item == null || l.qtyRequested <= 0) { _warn(isEnglish ? 'Please complete every line' : 'กรุณากรอกรายการให้ครบถ้วน'); return; }
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

  Future<void> _submit() async {
    final isEnglish = _isEnglish;
    final menuId = MenuScope.of(context)?.id;
    if (menuId == null) { _warn(isEnglish ? 'Cannot determine current menu' : 'ไม่สามารถระบุเมนูปัจจุบันได้'); return; }
    final confirmed = await showDialog<bool>(
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
    if (confirmed != true) return;
    setState(() => _isSaving = true);
    try {
      await _service.submitTransaction(_id!, menuId: menuId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Submitted for approval successfully' : 'ส่งอนุมัติสำเร็จ')));
        await _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmAction(String titleTh, String titleEn, String bodyTh, String bodyEn, Future<PrTransactionHeader> Function() action) async {
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
      title: fromClosed ? (isEnglish ? 'Reopen Purchase Requisition' : 'ถอยการปิดใบขอซื้อ') : (isEnglish ? 'Reverse to Draft' : 'ถอยเป็นร่าง'),
      message: fromClosed
          ? (isEnglish
              ? 'Reopen this PR? Its status will be recalculated from the purchase orders converted from it.'
              : 'ถอยการปิดใบขอซื้อนี้? สถานะจะคำนวณใหม่จากใบสั่งซื้อที่แปลงไปแล้ว')
          : (isEnglish
              ? 'Reverse this PR to draft? Pending approvals are skipped. You can edit it and submit it again with the same number.'
              : 'ถอยใบขอซื้อนี้เป็นร่าง? ผู้อนุมัติที่ยังไม่ตัดสินจะถูกข้าม แก้ไขแล้วส่งอนุมัติใหม่ได้ด้วยเลขที่เดิม'),
      confirmLabel: fromClosed ? (isEnglish ? 'Reopen' : 'ถอยการปิด') : (isEnglish ? 'Reverse to Draft' : 'ถอยเป็นร่าง'),
      color: Colors.orange[800]!,
      action: (r) => _service.reverseTransaction(_id!, r),
    );
  }

  void _voidDoc() {
    final isEnglish = _isEnglish;
    _reasonAction(
      title: isEnglish ? 'Void Purchase Requisition' : 'ยกเลิกใบขอซื้อ',
      message: isEnglish
          ? 'Void this PR? It can no longer be converted.'
          : 'ยกเลิกใบขอซื้อนี้? จะนำไปแปลงเป็นใบสั่งซื้อไม่ได้อีก',
      confirmLabel: isEnglish ? 'Void' : 'ยกเลิกใบขอซื้อ',
      color: Colors.red[700]!,
      action: (r) => _service.voidTransaction(_id!, r),
    );
  }

  void _deleteDoc() {
    final isEnglish = _isEnglish;
    _reasonAction(
      title: isEnglish ? 'Delete' : 'ลบใบขอซื้อ',
      message: isEnglish
          ? 'Delete this PR? It will be kept as Deleted for audit and cannot be used again.'
          : 'ลบใบขอซื้อนี้? ระบบเก็บไว้ด้วยสถานะ "ลบแล้ว" เพื่อตรวจสอบ และนำกลับมาใช้ไม่ได้',
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
    final editable = ['Draft', 'Rejected'].contains(_status) && !widget.viewOnly;
    final a = <DocBarAction>[];
    if (_id != null && canCreate) {
      a.add(DocBarAction.secondary(en ? 'Copy as New' : 'คัดลอกเป็นใบใหม่', busy ? null : () => widget.onCopyRequested?.call(_id!), DocBarColors.neutral));
    }
    if (editable && _id != null && widget.canDelete) {
      a.add(DocBarAction.secondary(en ? 'Delete' : 'ลบ', guard(_actions.deleteBlock, _deleteDoc), DocBarColors.delete, tooltip: _actions.deleteBlock?.text(en)));
    }
    // ถอนการส่งอนุมัติทำได้ทุกคนที่แก้ไขได้ ส่วนถอยใบที่อนุมัติ/ปิดแล้วต้องมีสิทธิ์อนุมัติ
    if (['Submitted', 'Approved', 'PartiallyConverted', 'FullyConverted', 'Closed'].contains(_status) &&
        (_status == 'Submitted' || canApprove) && _id != null && !widget.viewOnly) {
      a.add(DocBarAction.secondary(
          _status == 'Closed' ? (en ? 'Reopen' : 'ถอยการปิด') : (en ? 'Reverse to Draft' : 'ถอยเป็นร่าง'),
          guard(_actions.reverseBlock, _reverse), DocBarColors.reverse, tooltip: _actions.reverseBlock?.text(en)));
    }
    if (editable) {
      a.add(_id != null
          ? DocBarAction.secondary(en ? 'Save' : 'บันทึก', busy ? null : _save, DocBarColors.save)
          : DocBarAction.primary(en ? 'Save' : 'บันทึก', busy ? null : _save, DocBarColors.post));
    }
    if (editable && _id != null) {
      a.add(DocBarAction.primary(en ? 'Submit' : 'ส่งอนุมัติ', busy ? null : _submit, DocBarColors.submit));
    }
    if (['Approved', 'PartiallyConverted', 'FullyConverted'].contains(_status) && canApprove && !widget.viewOnly) {
      a.add(DocBarAction.primary(en ? 'Close' : 'ปิดใบขอซื้อ', busy ? null : () => _confirmAction(
          'ยืนยันปิดใบขอซื้อ', 'Close Purchase Requisition',
          'ปิดใบขอซื้อนี้? ใช้เมื่อไม่มีการสั่งซื้อเพิ่มแล้ว (แม้ยังแปลงเป็น PO ไม่ครบ 100%)',
          'Close this PR? Use this when no more PO conversion is expected (even if not 100% converted).',
          () => _service.closeTransaction(_id!)), DocBarColors.post));
    }
    if (['Approved', 'PartiallyConverted', 'FullyConverted'].contains(_status) && canApprove && _id != null && !widget.viewOnly) {
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
      return 'incomplete|${docFingerprint([_vendor?.id, _lines.length, _descCtrl.text])}';
    }
  }

  void _markClean() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cleanFingerprint = _formFingerprint();
    });
  }

  @override
  bool get isDirty {
    if (_isLoading || _isSaving || widget.viewOnly || !(['Draft', 'Rejected'].contains(_status))) return false;
    return _cleanFingerprint != null && _cleanFingerprint != _formFingerprint();
  }

  void _warn(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.orange));
  }

  String _docTypeLabel(ModuleDocument d) => _isEnglish && d.docNameEng.isNotEmpty ? d.docNameEng : d.docNameThai;

  String _currencyLabel(Currency c) => _isEnglish && c.currencyNameEng.isNotEmpty ? c.currencyNameEng : c.currencyNameThai;

  String get _baseCurrencyCode =>
      _currencies.cast<Currency?>().firstWhere((c) => c?.baseCurrencyFlag == true, orElse: () => null)?.currencyCode ?? CurrencyService.baseCode;

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

  // วันที่ในตาราง (กรอบ 36)
  Widget _cellDate(DateTime? value, ValueChanged<DateTime?> onChanged) {
    if (_isReadOnly) return _cBox(value == null ? '' : _dateFmt.format(value), right: false);
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: value ?? _docDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: _cDec(fill: value == null ? Colors.white : _hAuto),
        child: Row(children: [
          Expanded(child: Text(value == null ? '' : _dateFmt.format(value), style: _numStyle, maxLines: 1)),
          if (value != null)
            InkWell(onTap: () => onChanged(null), child: const Icon(Icons.clear, size: 14, color: Colors.grey))
          else
            const Icon(Icons.calendar_today, size: 14, color: Color(0xFF0F6E6E)),
        ]),
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
          docStatusBadge(_status, label: prTransactionStatusLabel(_status, isEnglish)),
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
      _hRow([
        InputDecorator(
          decoration: _hDec(isEnglish ? 'Doc No.' : 'เลขที่เอกสาร', auto: true, forcedReadOnly: _id != null),
          child: Text(_docNo == 'AUTO' ? (isEnglish ? 'Auto' : 'อัตโนมัติ') : _docNo,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _docNo == 'AUTO' ? Colors.grey.shade600 : null)),
        ),
        _datePick(isEnglish ? 'Doc Date' : 'วันที่เอกสาร', _docDate, () async {
          final picked = await showDatePicker(context: context, initialDate: _docDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (picked != null) setState(() => _docDate = picked);
        }, req: true, auto: true),
      ]),
    ]);

    // ② ผู้ขาย / คลังปลายทาง (ใบขอซื้อไม่บังคับ)
    final opt = isEnglish ? ' (optional)' : ' (ไม่บังคับ)';
    final g2 = docFilterGroup(2, isEnglish ? 'Vendor / Destination' : 'ผู้ขาย / คลังปลายทาง', color: _gParty, [
      _pickBox(
        (isEnglish ? 'Vendor' : 'ผู้ขาย') + opt,
        code: _vendor?.vendorCode,
        name: _vendor?.vendorNameTh,
        emptyText: isEnglish ? '— Not specified —' : '— ไม่ระบุ —',
        onTap: () => ApVendorListWidget.search(context, onSelected: _selectVendor),
        onClear: () => setState(() => _vendor = null),
      ),
      _pickBox(
        (isEnglish ? 'Destination Warehouse' : 'คลังปลายทาง') + opt,
        code: _warehouse?.warehouseCode,
        name: _warehouse == null ? null : _warehouseName(_warehouse!),
        emptyText: isEnglish ? '— Not specified —' : '— ไม่ระบุ —',
        auto: true,
        onTap: () => ImWarehouseListWidget.search(context, onSelected: (w) => setState(() {
              _warehouse = w;
              _branchId ??= w.branchId; // ยังไม่มีสาขา → ใช้สาขาของคลัง
            })),
        onClear: () => setState(() => _warehouse = null),
      ),
    ]);

    // ③ การเงิน
    final g3 = docFilterGroup(3, isEnglish ? 'Finance' : 'การเงิน', color: _gFin, [
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
          onChanged: _isReadOnly ? null : (v) => setState(() { _currency = v; _exchangeRate = v?.baseRate ?? 1; }),
        ),
        TextFormField(
          key: ValueKey('pr_rate_${widget.resetKey}_${_id}_${_currency?.currencyCode}'),
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
          if (_headerExpanded) _groupLayout([g1, g2, g3, g4], const [10, 12, 9, 12]) else _headerSummary(isEnglish),
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
        if (_vendor != null) item(_gParty, isEnglish ? 'Vendor' : 'ผู้ขาย', '${_vendor!.vendorCode} ${_vendor!.vendorNameTh}'),
        if (_warehouse != null) item(_gParty, isEnglish ? 'Warehouse' : 'คลัง', '${_warehouse!.warehouseCode} ${_warehouseName(_warehouse!)}'),
        if (_currency != null)
          item(_gFin, isEnglish ? 'Currency' : 'สกุลเงิน',
              _currency!.baseCurrencyFlag ? _currency!.currencyCode : '${_currency!.currencyCode} @ ${_exchangeRate.toStringAsFixed(4)}'),
        if (_descCtrl.text.trim().isNotEmpty) item(_gMore, isEnglish ? 'Description' : 'คำอธิบาย', _descCtrl.text.trim()),
      ]),
    );
  }

  // ── การ์ดรายการขอซื้อ: ตารางแบบการ์ดรายการสินค้าของ IM (ช่อง 36, 4 กลุ่มสี) ──────────────────
  Widget _buildLinesSection() {
    final isEnglish = _isEnglish;
    final cur = _currency?.currencyCode ?? _baseCurrencyCode;
    final valueLabel = isEnglish ? 'Value' : 'มูลค่า';
    final showOrdered = !['Draft', 'Rejected', 'Submitted'].contains(_status) || _lines.any((l) => l.qtyConverted > 0);
    final cols = <(String, double, int, bool)>[
      ('#', 28, 0, false),
      (isEnglish ? 'Item *' : 'สินค้า *', 0, 1, false),
      (isEnglish ? 'Qty' : 'จำนวน', 84, 2, true),
      (isEnglish ? 'Unit' : 'หน่วย', 100, 2, false),
      (isEnglish ? 'Unit Cost' : 'ราคา/หน่วย', 104, 3, true),
      (valueLabel, 116, 3, true),
      (isEnglish ? 'Needed By' : 'วันที่ต้องการ', 124, 4, false),
      if (showOrdered) (isEnglish ? 'Ordered' : 'สั่งซื้อแล้ว', 100, 4, true),
      (isEnglish ? 'Remark' : 'หมายเหตุ', 0, 4, false),
      ('', 36, 0, false),
      if (!_isReadOnly) ('', 36, 0, false),
    ];

    final rows = <List<Widget>>[];
    double sum = 0;
    for (var i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      sum += l.totalValueLc;
      rows.add([
        Text('${i + 1}.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade700)),
        _itemBox(l.item),
        _cellField(l.qtyCtrl, allow: r'[0-9.]', onChanged: (v) => setState(() => l.qtyRequested = double.tryParse(v) ?? 0)),
        _uomField(l, isEnglish),
        _cellField(l.costCtrl, allow: r'[0-9.]', onChanged: (v) => setState(() => l.estimatedUnitCost = double.tryParse(v) ?? 0)),
        _cBox(_fmt.format(l.totalValueLc), bold: true),
        _cellDate(l.neededByDate, (d) => setState(() => l.neededByDate = d)),
        if (showOrdered)
          _progress(l.qtyConverted, l.qtyRequested,
              isEnglish
                  ? 'Ordered ${_fmtQty.format(l.qtyConverted)} of ${_fmtQty.format(l.qtyRequested)}'
                  : 'สั่งซื้อแล้ว ${_fmtQty.format(l.qtyConverted)} จาก ${_fmtQty.format(l.qtyRequested)}'),
        _cellField(l.remarkCtrl, numeric: false),
        AttachmentButton(moduleCode: 'pr_transaction_detail', entityId: l.id, readOnly: _isReadOnly),
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
        c.$1 == valueLabel ? _footerAmount(sum) : const SizedBox.shrink(),
    ];
    footer[1] = _footerLabel(isEnglish ? 'Total ${_lines.length} lines' : 'รวม ${_lines.length} รายการ');

    return _card(
      isEnglish ? 'Requested Items' : 'รายการขอซื้อ',
      chips: [
        _chip(isEnglish ? '${_lines.length} lines' : '${_lines.length} รายการ', const Color(0xFF1E4F8F), _hAuto),
        if (_currency != null && !_currency!.baseCurrencyFlag)
          _chip(isEnglish ? 'Est. cost in $cur' : 'ราคาประมาณเป็น $cur', const Color(0xFF8A4B00), const Color(0xFFFFF0D9)),
      ],
      actions: [if (!_isReadOnly) _addButton(isEnglish ? 'Add Line' : 'เพิ่มรายการ', _addLine)],
      [
        _gridTable(
          cols: cols,
          groupTitle: (g) => switch (g) {
            1 => isEnglish ? 'Item' : 'สินค้า',
            2 => isEnglish ? 'Quantity' : 'จำนวน',
            3 => isEnglish ? 'Estimated Cost ($cur)' : 'ราคาประมาณ ($cur)',
            _ => isEnglish ? 'Needed By / Status / Remark' : 'วันที่ต้องการ / สถานะ / หมายเหตุ',
          },
          rows: rows,
          footer: footer,
          empty: Text(isEnglish ? 'No items — click Add Line' : 'ไม่มีรายการ — กดเพิ่มรายการ', style: const TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  // ── การ์ดสรุปยอด ─────────────────────────────────────────────────
  Widget _buildTotalsSection() {
    final isEnglish = _isEnglish;
    final cur = _currency?.currencyCode ?? _baseCurrencyCode;
    final total = _lines.fold<double>(0, (s, l) => s + l.totalValueLc);
    final fullyOrdered = _lines.where((l) => l.qtyRequested > 0 && l.qtyConverted >= l.qtyRequested - 1e-9).length;
    final showOrdered = !['Draft', 'Rejected', 'Submitted'].contains(_status) || _lines.any((l) => l.qtyConverted > 0);

    final figures = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(isEnglish ? 'Lines' : 'จำนวนรายการ', style: const TextStyle(fontSize: 13, color: Color(0xFF33404D)))),
          Text('${_lines.length}', style: _numStyle.copyWith(fontWeight: FontWeight.w600)),
        ]),
      ),
      if (showOrdered)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(isEnglish ? 'Fully ordered' : 'สั่งซื้อแล้วครบ', style: const TextStyle(fontSize: 13, color: Color(0xFF33404D)))),
            Text('$fullyOrdered / ${_lines.length}', style: _numStyle.copyWith(fontWeight: FontWeight.w600)),
          ]),
        ),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFFE8F3F2), borderRadius: BorderRadius.circular(6)),
        child: Row(children: [
          Expanded(
              child: Text('${isEnglish ? 'Estimated Total' : 'มูลค่าประมาณรวม'} ($cur)',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F5C5C)))),
          Text(_fmt.format(total), style: _numStyle.copyWith(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF0F5C5C))),
        ]),
      ),
      if (_currency != null && !_currency!.baseCurrencyFlag)
        _sumRow('${isEnglish ? 'Estimated Total' : 'มูลค่าประมาณรวม'} ($_baseCurrencyCode)', total * _exchangeRate),
    ]);

    final hint = Text(
      isEnglish
          ? 'Estimated values support the approval decision; actual prices are set on the purchase order. "Ordered" counts purchase orders that are not void.'
          : 'มูลค่าประมาณใช้ประกอบการอนุมัติ · ราคาจริงกำหนดในใบสั่งซื้อ · "สั่งซื้อแล้ว" นับจากใบสั่งซื้อที่ไม่ถูกยกเลิก',
      style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
    );

    return _card(isEnglish ? 'Summary' : 'สรุปยอด', [
      LayoutBuilder(
        builder: (context, c) => c.maxWidth >= 700
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: hint),
                const SizedBox(width: 24),
                SizedBox(width: 380, child: figures),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [figures, const SizedBox(height: 10), hint]),
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
            if (_approvals.isNotEmpty) ...[
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
// Item picker dialog — มิเรอร์ _ItemPickerDialog ใน po_transaction_detail_widget.dart
// ---------------------------------------------------------------------------
class _PrItemPickerDialog extends StatefulWidget {
  const _PrItemPickerDialog();

  @override
  State<_PrItemPickerDialog> createState() => _PrItemPickerDialogState();
}

class _PrItemPickerDialogState extends State<_PrItemPickerDialog> {
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
