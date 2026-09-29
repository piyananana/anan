// lib/so/widgets/so_transaction_detail_widget.dart — แก้ไขรายละเอียดใบสั่งขาย (header+lines)
// มิเรอร์โครงสร้าง po_transaction_detail_widget.dart ทุกประการ (vendor->customer) — SO ไม่แตะสต็อก/GL เลย —
// Draft เท่านั้นที่แก้ไขได้ (เหมือน DLN), Approve/Close/Void เป็น action แยกกดทีละปุ่ม ดู soTransactionController.js
// สำหรับ workflow เต็ม — ยังไม่มีขั้น "ใบเสนอราคา" นำหน้าเหมือน PR นำหน้า PO ในรอบนี้ (จึงไม่มี _pickQuoteLines)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/models/sa_module_document.dart';
import '../../ar/models/ar_customer.dart';
import '../../ar/widgets/ar_customer_list_widget.dart';
import '../../im/models/im_item.dart';
import '../../im/models/im_warehouse.dart';
import '../models/so_transaction.dart';
import '../../im/services/im_item_service.dart';
import '../services/so_transaction_service.dart';
import '../../im/widgets/im_warehouse_list_widget.dart';
import '../../cd/models/cd_currency.dart';
import '../../cd/services/cd_currency_service.dart';
import '../../sa/widgets/sa_attachment_widget.dart';

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
  _LineForm({this.id, this.item, this.qtyOrdered = 0, this.unitPriceFc = 0, this.qtyDelivered = 0});
  double get totalValueLc => qtyOrdered * unitPriceFc;
}

class _SoTransactionDetailWidgetState extends State<SoTransactionDetailWidget> {
  final _service = SoTransactionService();
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
  ArCustomer? _customer;
  ImWarehouse? _warehouse;
  final _descCtrl = TextEditingController();
  String _status = 'Draft';

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

  bool get _isReadOnly => widget.viewOnly || _status != 'Draft';

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
    _customer = null;
    _warehouse = null;
    _descCtrl.clear();
    _status = 'Draft';
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
        _allowedDocTypes = docTypes.where((d) => d.isDocType && d.sysDocType == _soSysDocType).toList();
      }
      if (_currencies.isEmpty) {
        _currencies = await _currencyService.fetchActiveRows();
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
        _customer = ArCustomer(id: h.customerId, customerCode: h.customerCode ?? '', customerNameTh: h.customerNameTh ?? '');
        _warehouse = ImWarehouse(id: h.warehouseId, warehouseCode: h.warehouseCode ?? '', warehouseNameTh: h.warehouseNameTh ?? '', warehouseNameEn: h.warehouseNameEn);
        _descCtrl.text = h.description ?? '';
        _status = 'Draft';
        _currency = _currencies.cast<Currency?>().firstWhere(
            (c) => c?.id == h.currencyId || c?.currencyCode == h.currencyCode, orElse: () => null);
        _exchangeRate = h.exchangeRate;
        final items = await Future.wait(h.details.map((d) => _itemService.fetchRow(d.itemId)));
        _lines = [
          for (var i = 0; i < h.details.length; i++)
            _LineForm(
              item: items[i],
              qtyOrdered: h.details[i].qtyOrdered,
              unitPriceFc: h.details[i].unitPriceFc,
            ),
        ];
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
        _customer = ArCustomer(id: h.customerId, customerCode: h.customerCode ?? '', customerNameTh: h.customerNameTh ?? '');
        _warehouse = ImWarehouse(id: h.warehouseId, warehouseCode: h.warehouseCode ?? '', warehouseNameTh: h.warehouseNameTh ?? '', warehouseNameEn: h.warehouseNameEn);
        _descCtrl.text = h.description ?? '';
        _status = h.status;
        _currency = _currencies.cast<Currency?>().firstWhere(
            (c) => c?.id == h.currencyId || c?.currencyCode == h.currencyCode, orElse: () => null);
        _exchangeRate = h.exchangeRate;
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
            ),
        ];
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectCustomer(ArCustomer c) {
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
  }

  Future<void> _addLine() async {
    final result = await showDialog<ImItem>(context: context, builder: (_) => const _ItemPickerDialog());
    if (result == null || !mounted) return;
    final line = _LineForm(item: result, qtyOrdered: 1, unitPriceFc: 0);
    setState(() => _lines.add(line));
    if (_customer != null) {
      final resolved = await _service.resolvePrice(
        itemId: result.id!, customerId: _customer!.id!, qty: 1, docDate: DateFormat('yyyy-MM-dd').format(_docDate),
      );
      if (resolved['unit_price_fc'] != null && mounted) {
        setState(() => line.unitPriceFc = double.tryParse(resolved['unit_price_fc'].toString()) ?? 0);
      }
    }
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
    setState(() => _isSaving = true);
    try {
      final header = SoTransactionHeader(
        id: _id ?? 0, docId: _docId ?? 0, docNo: _docNo, docDate: _docDate,
        customerId: _customer!.id!, warehouseId: _warehouse!.id, dueDate: _dueDate,
        currencyId: _currency?.id, currencyCode: _currency?.currencyCode ?? 'THB', exchangeRate: _exchangeRate,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      );
      final details = _lines
          .map((l) => SoTransactionDetail(
                id: l.id, lineNo: 0, itemId: l.item!.id!, itemCode: l.item!.itemCode, itemName: l.item!.itemNameTh,
                qtyOrdered: l.qtyOrdered, unitPriceFc: l.unitPriceFc,
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
                    onChanged: _isReadOnly ? null : (v) => setState(() { _currency = v; _exchangeRate = v?.baseRate ?? 1; }),
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
            ]),
          ),
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
          if (_id != null && canCreate) ...[
            OutlinedButton.icon(
              onPressed: _isSaving ? null : () => widget.onCopyRequested?.call(_id!),
              icon: const Icon(Icons.copy, size: 18),
              label: Text(isEnglish ? 'Copy as New' : 'คัดลอกเป็นใบใหม่'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.teal[800]),
            ),
            const SizedBox(width: 8),
          ],
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
                  'ยืนยันอนุมัติใบสั่งขาย', 'Approve Sale Order',
                  'อนุมัติใบสั่งขายนี้? หลังอนุมัติแล้วใบส่งสินค้า (DLN) จะสามารถอ้างอิงได้ และจะแก้ไขรายการไม่ได้อีก',
                  'Approve this SO? Once approved, DLN can reference it and lines can no longer be edited.',
                  () => _service.approveTransaction(_id!)),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: Text(isEnglish ? 'Approve' : 'อนุมัติ'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[700], foregroundColor: Colors.white),
            ),
          ],
          if (['Approved', 'PartiallyDelivered', 'FullyDelivered'].contains(_status) && canApprove && !widget.viewOnly) ...[
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : () => _confirmAction(
                  'ยืนยันปิดใบสั่งขาย', 'Close Sale Order',
                  'ปิดใบสั่งขายนี้? ใช้เมื่อไม่มีการส่งสินค้าเพิ่มแล้ว (แม้ยังส่งไม่ครบ 100%)',
                  'Close this SO? Use this when no more delivery is expected (even if not 100% delivered).',
                  () => _service.closeTransaction(_id!)),
              icon: const Icon(Icons.lock_outline, size: 18),
              label: Text(isEnglish ? 'Close' : 'ปิดใบสั่งขาย'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
            ),
          ],
          if (['Draft', 'Approved', 'PartiallyDelivered'].contains(_status) && _id != null && canApprove && !widget.viewOnly) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : () => _confirmAction(
                  'ยืนยันยกเลิกใบสั่งขาย', 'Void Sale Order',
                  'ยกเลิกใบสั่งขายนี้? จะยกเลิกไม่ได้ถ้ามีใบส่งสินค้าอ้างอิงเข้ามาแล้ว',
                  'Void this SO? This is blocked if any DLN already references it.',
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
