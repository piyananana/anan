// lib/po/widgets/po_pr_transaction_detail_widget.dart — แก้ไขรายละเอียดใบขอซื้อ (header+lines) + แผงอนุมัติ
// มิเรอร์โครงสร้าง po_transaction_detail_widget.dart แต่ vendor/warehouse ไม่บังคับ (PR คือ "ขอซื้ออะไร" ไม่ใช่
// "ซื้อจากใคร/ลงคลังไหน") และเพิ่มขั้นตอน Submit->Approve/Reject ผ่านคิวอนุมัติจริง (sa_module_approver) มิเรอร์
// แผงอนุมัติกลาง DocApprovalPanel (คิวที่ตาราง doc_approval) — ดู poPrTransactionController.js สำหรับ workflow เต็ม (ย้ายมา
// รวมกับโฟลเดอร์ po เดิมอยู่ lib/pr/)
import 'package:flutter/material.dart';
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
  _LineForm({this.id, this.item, this.qtyRequested = 0, this.neededByDate, this.estimatedUnitCost = 0, this.qtyConverted = 0,
      this.uomId, this.uomCode, this.uomNameTh, this.uomNameEn, this.factor = 1});
  double get totalValueLc => qtyRequested * estimatedUnitCost;
}

class _PrTransactionDetailWidgetState extends State<PrTransactionDetailWidget> implements DocAppBarActionsHost {
  final _service = PrTransactionService();
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
    super.dispose();
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
    final deco = InputDecoration(labelText: isEnglish ? 'Unit' : 'หน่วย', isDense: true, border: const OutlineInputBorder());
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13);
    Widget w;
    if (_isReadOnly || opts.length <= 1 || l.qtyConverted > 0) {
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

  Widget _fkField({required String label, required bool hasValue, required String displayText, VoidCallback? onSearch, VoidCallback? onClear}) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label, border: const OutlineInputBorder(), isDense: true,
        suffixIcon: onSearch == null
            ? null
            : (hasValue && onClear != null
                ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: onClear)
                : IconButton(icon: const Icon(Icons.search, size: 18), onPressed: onSearch)),
      ),
      child: GestureDetector(
        onTap: onSearch,
        child: Text(hasValue ? displayText : (_isEnglish ? '— Not specified —' : '— ไม่ระบุ —'),
            style: TextStyle(fontSize: 13, color: hasValue ? Colors.black87 : Colors.black38)),
      ),
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
                Expanded(child: Text('${isEnglish ? "PR No." : "เลขที่ใบขอซื้อ"}: $_docNo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blueGrey.shade100, borderRadius: BorderRadius.circular(12)),
                  child: Text(prTransactionStatusLabel(_status, isEnglish), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
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
                  flex: 2,
                  child: _fkField(
                    label: isEnglish ? 'Vendor (optional)' : 'ผู้ขาย (ไม่บังคับ)',
                    hasValue: _vendor != null,
                    displayText: '${_vendor?.vendorCode ?? ''}  ${_vendor?.vendorNameTh ?? ''}',
                    onSearch: _isReadOnly ? null : () => ApVendorListWidget.search(context, onSelected: _selectVendor),
                    onClear: () => setState(() => _vendor = null),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: _fkField(
                    label: isEnglish ? 'Warehouse (optional)' : 'คลังปลายทาง (ไม่บังคับ)',
                    hasValue: _warehouse != null,
                    displayText: '${_warehouse?.warehouseCode ?? ''}  ${_warehouse?.warehouseNameTh ?? ''}',
                    onSearch: _isReadOnly ? null : () => ImWarehouseListWidget.search(context, onSelected: (w) => setState(() {
                      _warehouse = w;
                      _branchId ??= w.branchId; // ยังไม่มีสาขา → ใช้สาขาของคลัง
                    })),
                    onClear: () => setState(() => _warehouse = null),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
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
                    onChanged: _isReadOnly ? null : (v) => setState(() { _currency = v; _exchangeRate = v?.baseRate ?? 1; }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('pr_rate_${widget.resetKey}_$_id'),
                    initialValue: _exchangeRate.toStringAsFixed(6),
                    enabled: !_isReadOnly,
                    decoration: InputDecoration(labelText: isEnglish ? 'Exchange Rate' : 'อัตราแลกเปลี่ยน', border: const OutlineInputBorder(), isDense: true),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => setState(() => _exchangeRate = double.tryParse(v) ?? 1),
                  ),
                ),
              ]),
            ]),
          ),
        ),
        if (_approvals.isNotEmpty) ...[
          const SizedBox(height: 12),
          // แผงอนุมัติกลาง (รองรับทั้งตามลำดับ และคนใดคนหนึ่ง)
          DocApprovalPanel(
            docNo: _docNo,
            approvals: _approvals,
            approvalMode: _approvalMode,
            awaiting: _status == 'Submitted' && !widget.viewOnly,
            onApprove: (r) => _service.approveTransaction(_id!, remarks: r),
            onReject: (r) => _service.rejectTransaction(_id!, remarks: r),
            onDone: _load,
          ),
        ],
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(isEnglish ? 'Lines' : 'รายการขอซื้อ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                if (_currency != null && !_currency!.baseCurrencyFlag) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                    child: Text(isEnglish ? 'Est. cost in ${_currency!.currencyCode}' : 'ราคาประมาณเป็น ${_currency!.currencyCode}', style: TextStyle(fontSize: 11, color: Colors.orange[800])),
                  ),
                ],
                const Spacer(),
                if (!_isReadOnly)
                  OutlinedButton.icon(onPressed: _addLine, icon: const Icon(Icons.add, size: 16), label: Text(isEnglish ? 'Add Line' : 'เพิ่มรายการ')),
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
                        initialValue: _fmtQty.format(l.qtyRequested),
                        enabled: !_isReadOnly,
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(labelText: isEnglish ? 'Qty' : 'จำนวน', isDense: true, border: const OutlineInputBorder()),
                        onChanged: (v) => setState(() => l.qtyRequested = double.tryParse(v) ?? 0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(width: 110, child: _uomField(l, isEnglish)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      child: TextFormField(
                        // ราคาที่คูณตามหน่วยใหม่ต้องแสดงในช่อง — initialValue ไม่อัปเดตเอง จึงสร้างช่องใหม่เมื่อหน่วยเปลี่ยน
                        key: ValueKey('cost_${identityHashCode(l)}_${l.uomId}'),
                        initialValue: _fmtValue.format(l.estimatedUnitCost),
                        enabled: !_isReadOnly,
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          labelText: (isEnglish ? 'Est. Cost' : 'ราคาประมาณ') + (_currency != null ? ' (${_currency!.currencyCode})' : ''),
                          isDense: true, border: const OutlineInputBorder(),
                        ),
                        onChanged: (v) => setState(() => l.estimatedUnitCost = double.tryParse(v) ?? 0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(width: 100, child: Text(_fmtValue.format(l.totalValueLc * _exchangeRate), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    if (l.qtyConverted > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(isEnglish ? 'PO: ${_fmtQty.format(l.qtyConverted)}' : 'สั่งซื้อแล้ว: ${_fmtQty.format(l.qtyConverted)}',
                            style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
                      ),
                    AttachmentButton(moduleCode: 'pr_transaction_detail', entityId: l.id, readOnly: _isReadOnly),
                    if (!_isReadOnly)
                      IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), onPressed: () => setState(() => _lines.removeAt(i))),
                  ]),
                );
              }),
              const Divider(),
              Align(
                alignment: Alignment.centerRight,
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  if (_currency != null && !_currency!.baseCurrencyFlag)
                    Text(
                      '${isEnglish ? "Estimated Total" : "รวมมูลค่าประมาณ"}: ${_fmtValue.format(_lines.fold<double>(0, (s, l) => s + l.totalValueLc))} ${_currency!.currencyCode}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  Text(
                    '${isEnglish ? "Estimated Total" : "รวมมูลค่าประมาณ"} ($_baseCurrencyCode): ${_fmtValue.format(_lines.fold<double>(0, (s, l) => s + l.totalValueLc * _exchangeRate))}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ]),
              ),
            ]),
          ),
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
