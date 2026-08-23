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

double _parseNum(String s) => double.tryParse(s.trim()) ?? 0;

// ── Mutable UI state for one count line — kept separate from ImTransactionDetail
// so controllers/loading flags don't leak into the plain data model. ───────────
// isIssueMode (sys_doc_type='60', ISS — เบิกสินค้า) / isTransferMode (sys_doc_type='70', TRF — โอนสินค้า):
// ผู้ใช้กรอก "จำนวนที่เบิก/โอน" (delta) โดยตรง แทนที่จะกรอก "ยอดนับได้" (absolute target) แบบ AJS — counted
// ยังคงเป็น absolute target เสมอ เพื่อให้ backend (im_transaction_detail.counted_qty / applyStockMovement) ใช้
// สูตรเดียวกันได้โดยไม่ต้องแก้ engine: counted = systemQty - จำนวนที่เบิก/โอน — ทั้งสองโหมดใช้กลไกเดียวกันทุก
// ประการ ต่างกันแค่ label ที่แสดง (ดู _isIssueMode / _isTransferMode ใน state)
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
  final TextEditingController countedQtyCtrl;
  final TextEditingController issueQtyCtrl;
  final TextEditingController unitCostCtrl;
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
    double countedQty = 0,
    double issueQty = 0,
    double? unitCost,
    String lotNo = '',
    String serialNo = '',
  })  : countedQtyCtrl = TextEditingController(text: countedQty == 0 ? '' : _fmtInput(countedQty)),
        issueQtyCtrl = TextEditingController(text: issueQty == 0 ? '' : _fmtInput(issueQty)),
        unitCostCtrl = TextEditingController(text: unitCost != null && unitCost != 0 ? _fmtInput(unitCost) : ''),
        lotNoCtrl = TextEditingController(text: lotNo),
        serialNoCtrl = TextEditingController(text: serialNo);

  bool get isDeltaMode => isIssueMode || isTransferMode;
  double get counted => isDeltaMode ? (systemQty - _parseNum(issueQtyCtrl.text)) : _parseNum(countedQtyCtrl.text);
  double get variance => counted - systemQty;

  static String _fmtInput(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  void dispose() {
    countedQtyCtrl.dispose();
    issueQtyCtrl.dispose();
    unitCostCtrl.dispose();
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
      ]);
      _docTypes = (results[0] as List<ModuleDocument>).where((d) => d.isDocType).toList();
      _openPeriods = results[1] as List<PostingPeriod>;
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
    _refNoCtrl.text = h.refNo ?? '';
    _descCtrl.text = h.description ?? '';
    _status = h.status;
    _glEntryId = h.glEntryId;

    final items = await Future.wait(tx.details.map((d) => _itemService.fetchRow(d.itemId)));
    final lines = <_CountLine>[];
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
        countedQty: d.countedQty,
        issueQty: (_isIssueMode || _isTransferMode) ? (d.systemQty - d.countedQty) : 0,
        unitCost: d.unitCost,
        lotNo: d.lotNo ?? '',
        serialNo: d.serialNo ?? '',
      ));
    }
    _lines = lines;

    if (_docCode != null) {
      _docSetup = await _service.fetchSetupByDocCode(_docCode!).catchError((_) => null);
    }
    if (_status == 'Posted' && _glEntryId != null) {
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

  void _addLine() {
    final isEnglish = _isEnglish;
    if (_warehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish ? 'Please select a warehouse first' : 'กรุณาเลือกคลังสินค้าก่อน')));
      return;
    }
    ImItemListWidget.search(context, itemTypeFilter: 'STOCK', onSelected: (ImItem item) {
      final line = _CountLine(item: item, uomId: item.baseUomId, uomCode: item.baseUomCode, isIssueMode: _isIssueMode, isTransferMode: _isTransferMode);
      setState(() => _lines.add(line));
      _refreshSystemQty(line);
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
    if (_lines.isEmpty) {
      warn(_isTransferMode
          ? (isEnglish ? 'Please add at least one transfer line' : 'กรุณาเพิ่มรายการโอนสินค้าอย่างน้อย 1 รายการ')
          : _isIssueMode
              ? (isEnglish ? 'Please add at least one issue line' : 'กรุณาเพิ่มรายการเบิกสินค้าอย่างน้อย 1 รายการ')
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
          warn('${l.item.itemCode}: ${l.isTransferMode ? (isEnglish ? 'Transfer qty is required' : 'กรุณาระบุจำนวนที่โอน') : (isEnglish ? 'Issue qty is required' : 'กรุณาระบุจำนวนที่เบิก')}');
          return;
        }
        if (l.isDeltaMode && l.counted < 0) {
          warn('${l.item.itemCode}: ${l.isTransferMode ? (isEnglish ? 'Transfer qty exceeds current balance' : 'จำนวนที่โอนเกินยอดคงเหลือ') : (isEnglish ? 'Issue qty exceeds current balance' : 'จำนวนที่เบิกเกินยอดคงเหลือ')}');
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
        refNo: _refNoCtrl.text.trim().isEmpty ? null : _refNoCtrl.text.trim(),
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
            readOnly: _isReadOnly,
            decoration: InputDecoration(labelText: isEnglish ? 'Ref No.' : 'เลขที่อ้างอิง', border: const OutlineInputBorder(), isDense: true),
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
      ]),
      const SizedBox(height: 6),
      TextField(
        controller: _descCtrl,
        readOnly: _isReadOnly,
        decoration: InputDecoration(labelText: isEnglish ? 'Description' : 'คำอธิบาย', border: const OutlineInputBorder(), isDense: true),
      ),
      const SizedBox(height: 6),
      Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: _statusColor(_status).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
          child: Text(_status, style: TextStyle(color: _statusColor(_status), fontWeight: FontWeight.w600)),
        ),
      ),
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
          : _isIssueMode
              ? (isEnglish ? 'Issue Lines' : 'รายการเบิกสินค้า')
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
              onPressed: _addLine,
              icon: const Icon(Icons.add),
              label: Text(isEnglish ? 'Add Item' : 'เพิ่มสินค้า'),
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
                        : line.isIssueMode
                            ? (isEnglish ? 'Issue Qty *' : 'จำนวนที่เบิก *')
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
                        : line.isIssueMode
                            ? (isEnglish ? 'Balance After' : 'คงเหลือหลังเบิก')
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
          ]),
        ]),
      ),
    );
  }

  Widget _buildGlCard(bool isEnglish) {
    if (_status == 'Posted' && _postedGlDetails != null) {
      return _card(title: isEnglish ? 'GL Entries (Posted)' : 'รายการบัญชี (Posted จริง)', children: [
        ..._postedGlDetails!.map((d) => _glLine(d.accountCode, isEnglish && d.accountNameEng.isNotEmpty ? d.accountNameEng : d.accountName, d.debitLc, d.creditLc)),
      ]);
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

    // บัญชีคู่บัญชี (counterpart ของคลัง) ต้องตรงกับที่ postGlEntry ใช้จริง — ISS ใช้ cogs, ที่เหลือใช้ variance (AJS)
    // ดู pattern_sys_doc_type_vs_doc_code: ตัดสินจาก sys_doc_type ไม่ใช่ doc_code
    final counterCode = _isIssueMode ? _docSetup!.cogsAccountCode : _docSetup!.varianceAccountCode;
    final counterName = _isIssueMode ? _docSetup!.cogsAccountName : _docSetup!.varianceAccountName;
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
          : _isIssueMode
              ? '${isEnglish ? 'Total issued qty' : 'จำนวนที่เบิกรวม'}: ${_fmtQty.format(-totalQty)}'
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
            child: Text(isEnglish ? 'Post' : 'Post'),
          ),
        ],
        if (_status == 'Posted' && !widget.viewOnly)
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
