// lib/po/widgets/po_transaction_detail_widget.dart — แก้ไขรายละเอียดใบสั่งซื้อ (header+lines)
// มิเรอร์โครงสร้าง im_transaction_detail_widget.dart (list+detail tab pattern) แต่เรียบง่ายกว่ามาก เพราะ PO ไม่แตะ
// สต็อก/GL เลย — Draft เท่านั้นที่แก้ไขได้ (เหมือน GRN), Approve/Close/Void เป็น action แยกกดทีละปุ่ม (เหมือน
// im_stock_count) ดู poTransactionController.js สำหรับ workflow เต็ม
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/models/sa_module_document.dart';
import '../../ap/models/ap_vendor.dart';
import '../../ap/widgets/ap_vendor_list_widget.dart';
import '../../im/models/im_item.dart';
import '../../im/models/im_warehouse.dart';
import '../models/po_transaction.dart';
import '../../im/services/im_item_service.dart';
import '../services/po_transaction_service.dart';
import '../../im/widgets/im_warehouse_list_widget.dart';
import '../../pr/services/pr_transaction_service.dart';
import '../../cd/models/cd_currency.dart';
import '../../cd/services/cd_currency_service.dart';

class PoTransactionDetailWidget extends StatefulWidget {
  final int? transactionId;
  final bool viewOnly;
  final int resetKey;
  final VoidCallback onSaveSuccess;
  final VoidCallback onCancel;
  final bool canDelete;

  const PoTransactionDetailWidget({
    super.key,
    required this.transactionId,
    this.viewOnly = false,
    this.resetKey = 0,
    required this.onSaveSuccess,
    required this.onCancel,
    this.canDelete = true,
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
  _LineForm({this.id, this.item, this.qtyOrdered = 0, this.unitPriceFc = 0, this.qtyReceived = 0, this.refPrDetailId});
  double get totalValueLc => qtyOrdered * unitPriceFc;
}

class _PoTransactionDetailWidgetState extends State<PoTransactionDetailWidget> {
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
  int? _refPrId; // ใบขอซื้อ (PR) ต้นทาง ถ้าเพิ่มรายการมาจาก _pickPrLines()
  String? _refPrDocNoLabel;

  // รองรับสั่งซื้อสินค้าต่างประเทศเป็นสกุลเงินต่างประเทศ — unit_price_fc ต่อบรรทัดคือราคาในสกุลเงินนี้ (FC),
  // total_value_lc คำนวณจาก unit_price_fc * exchange_rate เสมอ มิเรอร์ ap_transaction_detail_widget.dart ทุกประการ
  List<Currency> _currencies = [];
  Currency? _currency;
  double _exchangeRate = 1;

  // sys_module='51' มีมากกว่าหนึ่งประเภทเอกสารได้ (เช่น POR ของ PO, PRQ ของ PR) จึงต้องกรองซ้ำด้วย sys_doc_type
  // '10' คือ PO (ตาม poSysDocType ใน sa_anan_module.dart) แล้วให้ผู้ใช้เลือกเองเหมือนหน้าจอธุรกรรม AR/AP — เผื่อ
  // ผู้ใช้สร้างประเภทเอกสาร PO มากกว่าหนึ่งชุดสำหรับกลุ่มรายการบัญชีที่ต่างกัน
  static const _poSysDocType = '10';
  List<ModuleDocument> _allowedDocTypes = [];
  ModuleDocument? _docType;

  List<_LineForm> _lines = [];

  bool get _isReadOnly => widget.viewOnly || _status != 'Draft';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PoTransactionDetailWidget old) {
    super.didUpdateWidget(old);
    if (widget.transactionId != old.transactionId || widget.resetKey != old.resetKey) {
      _load();
    }
  }

  @override
  void dispose() {
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
    _vendor = null;
    _warehouse = null;
    _descCtrl.clear();
    _status = 'Draft';
    _refPrId = null;
    _refPrDocNoLabel = null;
    _currency = _currencies.cast<Currency?>().firstWhere((c) => c!.baseCurrencyFlag, orElse: () => null);
    _exchangeRate = _currency?.baseRate ?? 1;
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
        _vendor = ApVendor(id: h.vendorId, vendorCode: h.vendorCode ?? '', vendorNameTh: h.vendorNameTh ?? '');
        _warehouse = ImWarehouse(id: h.warehouseId, warehouseCode: h.warehouseCode ?? '', warehouseNameTh: h.warehouseNameTh ?? '', warehouseNameEn: h.warehouseNameEn);
        _descCtrl.text = h.description ?? '';
        _status = h.status;
        _refPrId = h.refPrId;
        _refPrDocNoLabel = h.refPrDocNo;
        _currency = _currencies.cast<Currency?>().firstWhere(
            (c) => c?.id == h.currencyId || c?.currencyCode == h.currencyCode, orElse: () => null);
        _exchangeRate = h.exchangeRate;
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
            ),
        ];
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
  }

  Future<void> _addLine() async {
    final result = await showDialog<ImItem>(context: context, builder: (_) => const _ItemPickerDialog());
    if (result == null || !mounted) return;
    final line = _LineForm(item: result, qtyOrdered: 1, unitPriceFc: 0);
    setState(() => _lines.add(line));
    if (_vendor != null) {
      final resolved = await _service.resolvePrice(
        itemId: result.id!, vendorId: _vendor!.id!, qty: 1, docDate: DateFormat('yyyy-MM-dd').format(_docDate),
      );
      if (resolved['unit_price_fc'] != null && mounted) {
        setState(() => line.unitPriceFc = double.tryParse(resolved['unit_price_fc'].toString()) ?? 0);
      }
    }
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
                        child: Text(isEnglish ? 'Remaining: ${_fmtQty.format(remaining)}' : 'คงเหลือแปลงได้: ${_fmtQty.format(remaining)}', style: const TextStyle(fontSize: 12)),
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
        _lines.add(_LineForm(
          item: items[i],
          qtyOrdered: qty.toDouble(),
          unitPriceFc: _prNum(l['estimated_unit_cost']),
          refPrDetailId: id,
        ));
      }
      _refPrId = pickedLines.first['header_id'] as int;
      _refPrDocNoLabel = pickedLines.first['doc_no'] as String?;
    });
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
      final header = PoTransactionHeader(
        id: _id ?? 0, docId: _docId ?? 0, docNo: _docNo, docDate: _docDate,
        vendorId: _vendor!.id!, warehouseId: _warehouse!.id, dueDate: _dueDate,
        currencyId: _currency?.id, currencyCode: _currency?.currencyCode ?? 'THB', exchangeRate: _exchangeRate,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        refPrId: _refPrId,
      );
      final details = _lines
          .map((l) => PoTransactionDetail(
                id: l.id, lineNo: 0, itemId: l.item!.id!, itemCode: l.item!.itemCode, itemName: l.item!.itemNameTh,
                qtyOrdered: l.qtyOrdered, unitPriceFc: l.unitPriceFc, refPrDetailId: l.refPrDetailId,
              ))
          .toList();
      if (_id == null) {
        await _service.createTransaction(header: header, details: details);
      } else {
        await _service.updateTransaction(id: _id!, header: header, details: details);
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

  void _warn(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.orange));
  }

  String _docTypeLabel(ModuleDocument d) => _isEnglish && d.docNameEng.isNotEmpty ? d.docNameEng : d.docNameThai;

  String _currencyLabel(Currency c) => _isEnglish && c.currencyNameEng.isNotEmpty ? c.currencyNameEng : c.currencyNameThai;

  String get _baseCurrencyCode =>
      _currencies.cast<Currency?>().firstWhere((c) => c!.baseCurrencyFlag, orElse: () => null)?.currencyCode ?? 'THB';

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
                    onChanged: _isReadOnly ? null : (v) => setState(() { _currency = v; _exchangeRate = v?.baseRate ?? 1; }),
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
                        onChanged: (v) => setState(() => l.qtyOrdered = double.tryParse(v) ?? 0),
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
                    SizedBox(width: 100, child: Text(_fmtValue.format(l.totalValueLc * _exchangeRate), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    if (l.qtyReceived > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(isEnglish ? 'Recv: ${_fmtQty.format(l.qtyReceived)}' : 'รับแล้ว: ${_fmtQty.format(l.qtyReceived)}',
                            style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
                      ),
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
                      '${isEnglish ? "Total" : "รวม"}: ${_fmtValue.format(_lines.fold<double>(0, (s, l) => s + l.totalValueLc))} ${_currency!.currencyCode}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  Text(
                    '${isEnglish ? "Total" : "รวม"} ($_baseCurrencyCode): ${_fmtValue.format(_lines.fold<double>(0, (s, l) => s + l.totalValueLc * _exchangeRate))}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(onPressed: widget.onCancel, child: Text(isEnglish ? 'Close' : 'ปิด')),
          const SizedBox(width: 8),
          if (_status == 'Draft' && !widget.viewOnly)
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: const Icon(Icons.save, size: 18),
              label: Text(isEnglish ? 'Save' : 'บันทึก'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[800], foregroundColor: Colors.white),
            ),
          if (_status == 'Draft' && _id != null && canApprove && !widget.viewOnly) ...[
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : () => _confirmAction(
                  'ยืนยันอนุมัติใบสั่งซื้อ', 'Approve Purchase Order',
                  'อนุมัติใบสั่งซื้อนี้? หลังอนุมัติแล้วใบรับสินค้า (GRN) จะสามารถอ้างอิงได้ และจะแก้ไขรายการไม่ได้อีก',
                  'Approve this PO? Once approved, GRN can reference it and lines can no longer be edited.',
                  () => _service.approveTransaction(_id!)),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: Text(isEnglish ? 'Approve' : 'อนุมัติ'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[700], foregroundColor: Colors.white),
            ),
          ],
          if (['Approved', 'PartiallyReceived', 'FullyReceived'].contains(_status) && canApprove && !widget.viewOnly) ...[
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : () => _confirmAction(
                  'ยืนยันปิดใบสั่งซื้อ', 'Close Purchase Order',
                  'ปิดใบสั่งซื้อนี้? ใช้เมื่อไม่มีการรับสินค้าเพิ่มแล้ว (แม้ยังรับไม่ครบ 100%)',
                  'Close this PO? Use this when no more receiving is expected (even if not 100% received).',
                  () => _service.closeTransaction(_id!)),
              icon: const Icon(Icons.lock_outline, size: 18),
              label: Text(isEnglish ? 'Close' : 'ปิดใบสั่งซื้อ'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
            ),
          ],
          if (['Draft', 'Approved', 'PartiallyReceived'].contains(_status) && _id != null && canApprove && !widget.viewOnly) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : () => _confirmAction(
                  'ยืนยันยกเลิกใบสั่งซื้อ', 'Void Purchase Order',
                  'ยกเลิกใบสั่งซื้อนี้? จะยกเลิกไม่ได้ถ้ามีใบรับสินค้าอ้างอิงเข้ามาแล้ว',
                  'Void this PO? This is blocked if any GRN already references it.',
                  () => _service.voidTransaction(_id!)),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: Text(isEnglish ? 'Void' : 'ยกเลิก'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red[700]),
            ),
          ],
        ]),
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
