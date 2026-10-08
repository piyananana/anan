// lib/so/widgets/so_quote_transaction_detail_widget.dart — แก้ไขรายละเอียดใบเสนอราคา (header+lines) + แผงอนุมัติ
// มิเรอร์โครงสร้าง po_pr_transaction_detail_widget.dart ทุกประการ (vendor->customer) — customer/warehouse ไม่บังคับ
// (Quote คือ "เสนอราคาอะไร" ไม่ใช่ "ขายให้ใคร/จากคลังไหน" แน่นอน) และมีขั้นตอน Submit->Approve/Reject ผ่านคิว
// อนุมัติจริง (sa_module_approver) เหมือน PR ทุกประการ — ต่างจาก PR ตรงที่มี validUntilDate ระดับหัวเอกสาร (ไม่ใช่
// per-line neededByDate ของ PR) ดู soQuoteTransactionController.js สำหรับ workflow เต็ม
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../sa/services/sa_language_provider.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/models/sa_module_document.dart';
import '../../ar/models/ar_customer.dart';
import '../../ar/widgets/ar_customer_list_widget.dart';
import '../../im/models/im_item.dart';
import '../../im/models/im_warehouse.dart';
import '../models/so_quote_transaction.dart';
import '../../im/services/im_item_service.dart';
import '../services/so_quote_transaction_service.dart';
import '../../im/widgets/im_warehouse_list_widget.dart';
import '../../cd/models/cd_currency.dart';
import '../../cd/services/cd_currency_service.dart';
import '../../sa/widgets/sa_attachment_widget.dart';

class QuoteTransactionDetailWidget extends StatefulWidget {
  final int? transactionId;
  final bool viewOnly;
  final int resetKey;
  final VoidCallback onSaveSuccess;
  final VoidCallback onCancel;
  final bool canDelete;
  // คัดลอกใบเสนอราคาเดิมเป็นฉบับร่างใหม่ — ใช้ได้เฉพาะตอน transactionId เป็น null (โหมดสร้างใหม่) เท่านั้น
  // ดู _load()/onCopyRequested สำหรับตรรกะเต็ม (มิเรอร์ po_transaction_detail_widget.dart ทุกประการ)
  final int? copyFromId;
  final ValueChanged<int>? onCopyRequested;

  const QuoteTransactionDetailWidget({
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
  State<QuoteTransactionDetailWidget> createState() => _QuoteTransactionDetailWidgetState();
}

class _LineForm {
  int? id;
  ImItem? item;
  double qtyQuoted;
  double unitPriceFc;
  double qtyConverted;
  // ราคาล่าสุดที่ระบบ auto-fill ให้จาก im_price_list — ใช้เทียบกับ unitPriceFc ปัจจุบันตอนจำนวน/ลูกค้าเปลี่ยน เพื่อ
  // รู้ว่าผู้ใช้แก้ราคาเองไปแล้วหรือยัง (ถ้าแก้แล้วจะไม่ auto-fill ทับให้อีก) ค่าเริ่มต้นต้องเป็น 0 (ไม่ใช่ null)
  // ให้ตรงกับ unitPriceFc เริ่มต้นของบรรทัดใหม่ — มิเรอร์ so_transaction_detail_widget.dart ทุกประการ
  double lastResolvedPrice = 0;
  _LineForm({this.id, this.item, this.qtyQuoted = 0, this.unitPriceFc = 0, this.qtyConverted = 0});
  double get totalValueLc => qtyQuoted * unitPriceFc;
}

class _QuoteTransactionDetailWidgetState extends State<QuoteTransactionDetailWidget> {
  final _service = QuoteTransactionService();
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
  DateTime? _validUntilDate;
  ArCustomer? _customer;
  ImWarehouse? _warehouse;
  final _descCtrl = TextEditingController();
  String _status = 'Draft';
  List<QuoteTransactionApproval> _approvals = [];

  // รองรับเสนอราคาสินค้าต่างประเทศเป็นสกุลเงินต่างประเทศ — มิเรอร์ po_pr_transaction_detail_widget.dart ทุกประการ
  List<Currency> _currencies = [];
  Currency? _currency;
  double _exchangeRate = 1;

  // sys_module='41' มีมากกว่าหนึ่งประเภทเอกสารได้ (เช่น SOR ของ SO, SQT ของ Quote) จึงต้องกรองซ้ำด้วย sys_doc_type
  // '05' คือ Quote (ตาม soSysDocType ใน sa_anan_module.dart)
  static const _quoteSysDocType = '05';
  List<ModuleDocument> _allowedDocTypes = [];
  ModuleDocument? _docType;

  List<_LineForm> _lines = [];
  Timer? _priceResolveDebounce;

  bool get _isReadOnly => widget.viewOnly || !['Draft', 'Rejected'].contains(_status);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant QuoteTransactionDetailWidget old) {
    super.didUpdateWidget(old);
    if (widget.transactionId != old.transactionId || widget.resetKey != old.resetKey) {
      _load();
    }
  }

  @override
  void dispose() {
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
    _validUntilDate = null;
    _customer = null;
    _warehouse = null;
    _descCtrl.clear();
    _status = 'Draft';
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
        _allowedDocTypes = docTypes.where((d) => d.isDocType && d.sysDocType == _quoteSysDocType).toList();
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
        _validUntilDate = null;
        _customer = h.customerId != null ? ArCustomer(id: h.customerId, customerCode: h.customerCode ?? '', customerNameTh: h.customerNameTh ?? '') : null;
        _warehouse = h.warehouseId != null
            ? ImWarehouse(id: h.warehouseId!, warehouseCode: h.warehouseCode ?? '', warehouseNameTh: h.warehouseNameTh ?? '', warehouseNameEn: h.warehouseNameEn)
            : null;
        _descCtrl.text = h.description ?? '';
        _status = 'Draft';
        _approvals = [];
        _currency = _currencies.cast<Currency?>().firstWhere(
            (c) => c?.id == h.currencyId || c?.currencyCode == h.currencyCode, orElse: () => null);
        _exchangeRate = h.exchangeRate;
        final items = await Future.wait(h.details.map((d) => _itemService.fetchRow(d.itemId)));
        _lines = [
          for (var i = 0; i < h.details.length; i++)
            _LineForm(
              item: items[i],
              qtyQuoted: h.details[i].qtyQuoted,
              unitPriceFc: h.details[i].unitPriceFc,
            ),
        ];
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
        _validUntilDate = h.validUntilDate;
        _customer = h.customerId != null ? ArCustomer(id: h.customerId, customerCode: h.customerCode ?? '', customerNameTh: h.customerNameTh ?? '') : null;
        _warehouse = h.warehouseId != null
            ? ImWarehouse(id: h.warehouseId!, warehouseCode: h.warehouseCode ?? '', warehouseNameTh: h.warehouseNameTh ?? '', warehouseNameEn: h.warehouseNameEn)
            : null;
        _descCtrl.text = h.description ?? '';
        _status = h.status;
        _approvals = h.approvals;
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
              qtyQuoted: h.details[i].qtyQuoted,
              unitPriceFc: h.details[i].unitPriceFc,
              qtyConverted: h.details[i].qtyConverted,
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
  // ลูกค้า ซึ่งไม่เคย resolve มาก่อนเลย) — มิเรอร์ so_transaction_detail_widget.dart:_reresolveAllLinesForCustomer
  // ทุกประการ (ไม่ใช้ debounce Timer ร่วมกับ _maybeReresolvePrice เพราะเรียกวนหลายบรรทัดจะตัดกันเอง)
  Future<void> _reresolveAllLinesForCustomer() async {
    final customer = _customer;
    if (customer == null) return;
    for (final line in _lines) {
      if (line.item == null || line.unitPriceFc != line.lastResolvedPrice) continue;
      final resolved = await _service.resolvePrice(
        itemId: line.item!.id!, customerId: customer.id!, qty: line.qtyQuoted,
        docDate: DateFormat('yyyy-MM-dd').format(_docDate), uomId: line.item!.baseUomId,
      );
      if (!mounted || _customer != customer) return;
      if (resolved['unit_price_fc'] != null && line.unitPriceFc == line.lastResolvedPrice) {
        final price = double.tryParse(resolved['unit_price_fc'].toString()) ?? 0;
        setState(() { line.unitPriceFc = price; line.lastResolvedPrice = price; });
      }
    }
  }

  Future<void> _addLine() async {
    final result = await showDialog<ImItem>(context: context, builder: (_) => const _QuoteItemPickerDialog());
    if (result == null || !mounted) return;
    final line = _LineForm(item: result, qtyQuoted: 1, unitPriceFc: 0);
    setState(() => _lines.add(line));
    if (_customer != null) {
      final resolved = await _service.resolvePrice(
        itemId: result.id!, customerId: _customer!.id!, qty: 1, docDate: DateFormat('yyyy-MM-dd').format(_docDate),
        uomId: result.baseUomId,
      );
      if (resolved['unit_price_fc'] != null && mounted) {
        final price = double.tryParse(resolved['unit_price_fc'].toString()) ?? 0;
        setState(() { line.unitPriceFc = price; line.lastResolvedPrice = price; });
      }
    }
  }

  // เรียกซ้ำเมื่อจำนวนในบรรทัดเปลี่ยน เพราะ im_price_list มี tier ตาม min_qty — มิเรอร์
  // so_transaction_detail_widget.dart:_maybeReresolvePrice ทุกประการ
  void _maybeReresolvePrice(_LineForm line) {
    _priceResolveDebounce?.cancel();
    if (_customer == null || line.item == null) return;
    _priceResolveDebounce = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted || line.unitPriceFc != line.lastResolvedPrice) return;
      final resolved = await _service.resolvePrice(
        itemId: line.item!.id!, customerId: _customer!.id!, qty: line.qtyQuoted, docDate: DateFormat('yyyy-MM-dd').format(_docDate),
        uomId: line.item!.baseUomId,
      );
      if (resolved['unit_price_fc'] != null && mounted && line.unitPriceFc == line.lastResolvedPrice) {
        final price = double.tryParse(resolved['unit_price_fc'].toString()) ?? 0;
        setState(() { line.unitPriceFc = price; line.lastResolvedPrice = price; });
      }
    });
  }

  Future<void> _save() async {
    final isEnglish = _isEnglish;
    if (_docType == null) { _warn(isEnglish ? 'Please select a document type' : 'กรุณาเลือกประเภทเอกสาร'); return; }
    if (_lines.isEmpty) { _warn(isEnglish ? 'At least 1 line is required' : 'ต้องมีรายการเสนอราคาอย่างน้อย 1 รายการ'); return; }
    for (final l in _lines) {
      if (l.item == null || l.qtyQuoted <= 0) { _warn(isEnglish ? 'Please complete every line' : 'กรุณากรอกรายการให้ครบถ้วน'); return; }
    }
    setState(() => _isSaving = true);
    try {
      final header = QuoteTransactionHeader(
        id: _id ?? 0, docId: _docId ?? 0, docNo: _docNo, docDate: _docDate,
        customerId: _customer?.id, warehouseId: _warehouse?.id, validUntilDate: _validUntilDate,
        currencyId: _currency?.id, currencyCode: _currency?.currencyCode ?? 'THB', exchangeRate: _exchangeRate,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      );
      final details = _lines
          .map((l) => QuoteTransactionDetail(
                id: l.id, lineNo: 0, itemId: l.item!.id!, itemCode: l.item!.itemCode, itemName: l.item!.itemNameTh,
                qtyQuoted: l.qtyQuoted, unitPriceFc: l.unitPriceFc,
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

  Future<void> _confirmAction(String titleTh, String titleEn, String bodyTh, String bodyEn, Future<QuoteTransactionHeader> Function() action) async {
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
      _currencies.cast<Currency?>().firstWhere((c) => c?.baseCurrencyFlag == true, orElse: () => null)?.currencyCode ?? 'THB';

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
                    onChanged: (_isReadOnly || _id != null) ? null : (v) => setState(() { _docType = v; _docId = v?.id; }),
                    validator: (v) => v == null ? (isEnglish ? 'Please select' : 'กรุณาเลือก') : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('${isEnglish ? "Quote No." : "เลขที่ใบเสนอราคา"}: $_docNo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blueGrey.shade100, borderRadius: BorderRadius.circular(12)),
                  child: Text(quoteTransactionStatusLabel(_status, isEnglish), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
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
                      final picked = await showDatePicker(context: context, initialDate: _validUntilDate ?? _docDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                      if (picked != null) setState(() => _validUntilDate = picked);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(labelText: isEnglish ? 'Valid Until' : 'ใช้ได้ถึงวันที่', border: const OutlineInputBorder(), isDense: true),
                      child: Text(_validUntilDate != null ? _dateFmt.format(_validUntilDate!) : '-'),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  flex: 2,
                  child: _fkField(
                    label: isEnglish ? 'Customer (optional)' : 'ลูกค้า (ไม่บังคับ)',
                    hasValue: _customer != null,
                    displayText: '${_customer?.customerCode ?? ''}  ${_customer?.customerNameTh ?? ''}',
                    onSearch: _isReadOnly ? null : () => ArCustomerListWidget.search(context, onSelected: _selectCustomer),
                    onClear: () => setState(() => _customer = null),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: _fkField(
                    label: isEnglish ? 'Warehouse (optional)' : 'คลังต้นทาง (ไม่บังคับ)',
                    hasValue: _warehouse != null,
                    displayText: '${_warehouse?.warehouseCode ?? ''}  ${_warehouse?.warehouseNameTh ?? ''}',
                    onSearch: _isReadOnly ? null : () => ImWarehouseListWidget.search(context, onSelected: (w) => setState(() => _warehouse = w)),
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
                    key: ValueKey('quote_rate_${widget.resetKey}_$_id'),
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
          _ApprovalPanel(quoteId: _id!, docNo: _docNo, approvals: _approvals, service: _service, onActionDone: _load),
        ],
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(isEnglish ? 'Lines' : 'รายการเสนอราคา', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                if (_currency != null && !_currency!.baseCurrencyFlag) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                    child: Text(isEnglish ? 'Price in ${_currency!.currencyCode}' : 'ราคาเป็น ${_currency!.currencyCode}', style: TextStyle(fontSize: 11, color: Colors.orange[800])),
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
                        initialValue: _fmtQty.format(l.qtyQuoted),
                        enabled: !_isReadOnly,
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(labelText: isEnglish ? 'Qty' : 'จำนวน', isDense: true, border: const OutlineInputBorder()),
                        onChanged: (v) {
                          setState(() => l.qtyQuoted = double.tryParse(v) ?? 0);
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
                    SizedBox(width: 100, child: Text(_fmtValue.format(l.totalValueLc * _exchangeRate), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    if (l.qtyConverted > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(isEnglish ? 'SO: ${_fmtQty.format(l.qtyConverted)}' : 'สั่งขายแล้ว: ${_fmtQty.format(l.qtyConverted)}',
                            style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
                      ),
                    AttachmentButton(moduleCode: 'quote_transaction_detail', entityId: l.id, readOnly: _isReadOnly),
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
                      '${isEnglish ? "Quoted Total" : "รวมมูลค่าเสนอราคา"}: ${_fmtValue.format(_lines.fold<double>(0, (s, l) => s + l.totalValueLc))} ${_currency!.currencyCode}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  Text(
                    '${isEnglish ? "Quoted Total" : "รวมมูลค่าเสนอราคา"} ($_baseCurrencyCode): ${_fmtValue.format(_lines.fold<double>(0, (s, l) => s + l.totalValueLc * _exchangeRate))}',
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
          if (['Draft', 'Rejected'].contains(_status) && !widget.viewOnly)
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: const Icon(Icons.save, size: 18),
              label: Text(isEnglish ? 'Save' : 'บันทึก'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[800], foregroundColor: Colors.white),
            ),
          if (['Draft', 'Rejected'].contains(_status) && _id != null && !widget.viewOnly) ...[
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _submit,
              icon: const Icon(Icons.send, size: 18),
              label: Text(isEnglish ? 'Submit' : 'ส่งอนุมัติ'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo[600], foregroundColor: Colors.white),
            ),
          ],
          if (['Approved', 'PartiallyConverted', 'FullyConverted'].contains(_status) && canApprove && !widget.viewOnly) ...[
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : () => _confirmAction(
                  'ยืนยันปิดใบเสนอราคา', 'Close Sale Quote',
                  'ปิดใบเสนอราคานี้? ใช้เมื่อไม่มีการสั่งขายเพิ่มแล้ว (แม้ยังแปลงเป็น SO ไม่ครบ 100%)',
                  'Close this Quote? Use this when no more SO conversion is expected (even if not 100% converted).',
                  () => _service.closeTransaction(_id!)),
              icon: const Icon(Icons.lock_outline, size: 18),
              label: Text(isEnglish ? 'Close' : 'ปิดใบเสนอราคา'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
            ),
          ],
          if (['Draft', 'Rejected', 'Approved', 'PartiallyConverted'].contains(_status) && _id != null && !widget.viewOnly) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : () => _confirmAction(
                  'ยืนยันยกเลิกใบเสนอราคา', 'Void Sale Quote',
                  'ยกเลิกใบเสนอราคานี้? จะยกเลิกไม่ได้ถ้ามีใบสั่งขายอ้างอิงเข้ามาแล้ว',
                  'Void this Quote? This is blocked if any SO already references it.',
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
// Approval panel — มิเรอร์ _ApprovalPanel ใน po_pr_transaction_detail_widget.dart ทุกประการ
// ---------------------------------------------------------------------------
class _ApprovalPanel extends StatefulWidget {
  final int quoteId;
  final String docNo;
  final List<QuoteTransactionApproval> approvals;
  final QuoteTransactionService service;
  final VoidCallback onActionDone;

  const _ApprovalPanel({
    required this.quoteId,
    required this.docNo,
    required this.approvals,
    required this.service,
    required this.onActionDone,
  });

  @override
  State<_ApprovalPanel> createState() => _ApprovalPanelState();
}

class _ApprovalPanelState extends State<_ApprovalPanel> {
  bool _acting = false;

  Color _approvalColor(String s) {
    switch (s) {
      case 'Approved': return Colors.green[700]!;
      case 'Rejected': return Colors.red[700]!;
      case 'Skipped':  return Colors.grey;
      default:         return Colors.orange[700]!;
    }
  }

  String _approvalLabel(String s, bool isEnglish) {
    switch (s) {
      case 'Approved': return isEnglish ? 'Approved' : 'อนุมัติแล้ว';
      case 'Rejected': return isEnglish ? 'Rejected' : 'ปฏิเสธ';
      case 'Skipped':  return isEnglish ? 'Skipped' : 'ข้าม';
      default:         return isEnglish ? 'Pending' : 'รออนุมัติ';
    }
  }

  Future<void> _doAction(bool isApprove) async {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    if (!(MenuScope.of(context)?.canApprove ?? true)) return;
    final currentUserId = Provider.of<AuthService>(context, listen: false).currentUser?.id;
    final approvals = widget.approvals;

    final myRecord = approvals.where((a) => a.approverUserId == currentUserId && a.status == 'Pending').toList();
    if (myRecord.isEmpty) return;

    final mySeq = myRecord.first.sequenceNo;
    final blockedByPrev = approvals.any((a) => a.sequenceNo < mySeq && a.status == 'Pending');
    if (blockedByPrev) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish ? 'Still waiting for approval from a previous sequence' : 'ยังรอการอนุมัติจากลำดับก่อนหน้า')));
      return;
    }

    final remarksCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isApprove ? (isEnglish ? 'Confirm Approval' : 'ยืนยันการอนุมัติ') : (isEnglish ? 'Confirm Rejection' : 'ยืนยันการปฏิเสธ')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(isApprove ? (isEnglish ? 'Approve ${widget.docNo}?' : 'อนุมัติ ${widget.docNo}?') : (isEnglish ? 'Reject ${widget.docNo}?' : 'ปฏิเสธ ${widget.docNo}?')),
          const SizedBox(height: 12),
          TextField(
            controller: remarksCtrl,
            decoration: InputDecoration(labelText: isEnglish ? 'Remarks (optional)' : 'หมายเหตุ (ถ้ามี)', border: const OutlineInputBorder(), isDense: true),
            maxLines: 2,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: isApprove ? Colors.green[700] : Colors.red[700], foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isApprove ? (isEnglish ? 'Approve' : 'อนุมัติ') : (isEnglish ? 'Reject' : 'ปฏิเสธ'))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _acting = true);
    try {
      final remarks = remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim();
      if (isApprove) {
        await widget.service.approveTransaction(widget.quoteId, remarks: remarks);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Approved successfully' : 'อนุมัติสำเร็จ')));
      } else {
        await widget.service.rejectTransaction(widget.quoteId, remarks: remarks);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Rejected successfully' : 'ปฏิเสธสำเร็จ')));
      }
      widget.onActionDone();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final currentUserId = Provider.of<AuthService>(context, listen: false).currentUser?.id;
    final approvals = widget.approvals;

    final myPending = approvals.firstWhere(
        (a) => a.approverUserId == currentUserId && a.status == 'Pending',
        orElse: () => const QuoteTransactionApproval(id: -1, headerId: -1, approverUserId: -1, approverUserName: '', sequenceNo: 0, status: ''));
    final canAct = myPending.id != -1 && !approvals.any((a) => a.sequenceNo < myPending.sequenceNo && a.status == 'Pending');

    return Container(
      color: Colors.orange.shade50,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.approval_outlined, size: 16, color: Colors.orange[800]),
          const SizedBox(width: 6),
          Text(isEnglish ? 'Approval Steps' : 'ขั้นตอนการอนุมัติ',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange[800])),
          const Spacer(),
          if (_acting) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          if (!_acting && canAct) ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline, size: 14),
              label: Text(isEnglish ? 'Approve' : 'อนุมัติ', style: const TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600], foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              onPressed: () => _doAction(true),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.cancel_outlined, size: 14),
              label: Text(isEnglish ? 'Reject' : 'ปฏิเสธ', style: const TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600], foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              onPressed: () => _doAction(false),
            ),
          ],
        ]),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: approvals.map((a) {
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Text('${a.sequenceNo}. ${a.approverUserName}', style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: _approvalColor(a.status).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(_approvalLabel(a.status, isEnglish), style: TextStyle(fontSize: 10, color: _approvalColor(a.status), fontWeight: FontWeight.w600)),
              ),
            ]);
          }).toList(),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Item picker dialog — มิเรอร์ _PrItemPickerDialog ใน po_pr_transaction_detail_widget.dart
// ---------------------------------------------------------------------------
class _QuoteItemPickerDialog extends StatefulWidget {
  const _QuoteItemPickerDialog();

  @override
  State<_QuoteItemPickerDialog> createState() => _QuoteItemPickerDialogState();
}

class _QuoteItemPickerDialogState extends State<_QuoteItemPickerDialog> {
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
