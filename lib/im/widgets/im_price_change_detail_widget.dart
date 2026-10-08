// lib/im/widgets/im_price_change_detail_widget.dart
// ธุรกรรมเปลี่ยนแปลงราคา — จอเดียวครบ: เงื่อนไขกรอง (ย่อได้) + ตารางรีวิว (จัดกลุ่มตามหมวดหมู่ แก้ราคา inline) +
// แถบปฏิบัติการตามสถานะ (Draft/Pending/Approved/Void)
//
// ผิดจาก detail widget อื่นๆ ในโปรเจกต์ตรงที่ "บันทึก Draft" ไม่ปิดฟอร์มกลับไป placeholder เหมือน
// im_uom_screen/im_price_list_screen (widget.onSubmit + widget.onCancel) — เพราะ workflow ของธุรกรรมนี้ต้องให้
// ผู้ใช้ "บันทึก Draft แล้วทำงานต่อ" (ดึงข้อมูล/ปรับราคา/ส่งขออนุมัติ) ในจอเดียวกันหลายรอบ จึงเรียก
// ImPriceChangeService ตรงจากวิดเจ็ตนี้เอง แล้วใช้ onRefreshList แทน (รีเฟรชลิสต์ซ้ายโดยไม่ปิดฟอร์ม)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/models/sa_module_document.dart';
import '../models/im_item_category.dart';
import '../models/im_price_change.dart';
import '../services/im_item_category_service.dart';
import '../services/im_price_change_service.dart';
import 'im_price_list_list_widget.dart';

// ---------------------------------------------------------------------------
// Multi-select dialog (หมวดหมู่สินค้า) — มิเรอร์ _MultiPickerDialog ใน
// im_stock_balance_by_item_report_screen.dart (เป็น private ต่อไฟล์ตาม convention เดิมของโปรเจกต์)
// ---------------------------------------------------------------------------
class _MultiPickerDialog<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final List<int> selected;
  final int Function(T) idOf;
  final String Function(T) labelOf;
  final bool isEnglish;

  const _MultiPickerDialog({
    required this.title,
    required this.items,
    required this.selected,
    required this.idOf,
    required this.labelOf,
    required this.isEnglish,
  });

  @override
  State<_MultiPickerDialog<T>> createState() => _MultiPickerDialogState<T>();
}

class _MultiPickerDialogState<T> extends State<_MultiPickerDialog<T>> {
  late List<int> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 400, height: 480,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.teal[800],
            child: Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Expanded(
            child: ListView(
              children: widget.items.map((item) {
                final id = widget.idOf(item);
                return CheckboxListTile(
                  dense: true,
                  title: Text(widget.labelOf(item), style: const TextStyle(fontSize: 13)),
                  value: _selected.contains(id),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) { _selected.add(id); } else { _selected.remove(id); }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              TextButton(
                onPressed: () => setState(() {
                  _selected = _selected.length == widget.items.length ? [] : widget.items.map((e) => widget.idOf(e)).toList();
                }),
                child: Text(_selected.length == widget.items.length
                    ? (widget.isEnglish ? 'Deselect All' : 'ยกเลิกทั้งหมด')
                    : (widget.isEnglish ? 'Select All' : 'เลือกทั้งหมด')),
              ),
              Row(children: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.isEnglish ? 'Cancel' : 'ยกเลิก')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[800], foregroundColor: Colors.white),
                  child: Text(widget.isEnglish ? 'OK' : 'ตกลง'),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class ImPriceChangeDetailWidget extends StatefulWidget {
  final Mode mode;
  final ImPriceChangeHeader? selected;
  final VoidCallback onCancel;
  final VoidCallback onRefreshList;
  final bool isPlaceholder;
  final int requestSeq;

  const ImPriceChangeDetailWidget({
    super.key,
    required this.mode,
    required this.selected,
    required this.onCancel,
    required this.onRefreshList,
    this.isPlaceholder = false,
    this.requestSeq = 0,
  });

  @override
  State<ImPriceChangeDetailWidget> createState() => ImPriceChangeDetailWidgetState();
}

class ImPriceChangeDetailWidgetState extends State<ImPriceChangeDetailWidget> {
  bool _isEnglish = false;
  bool _isSaving = false;
  bool _isFetching = false;
  bool _isFilterExpanded = true;
  String _gridSearchQuery = '';
  final Map<int, bool> _groupExpanded = {};
  final Map<int, TextEditingController> _priceCtrls = {};

  int? _currentId;
  String? _changeNo;
  String _status = 'Draft';

  // ประเภทเอกสาร (sa_module_document, sys_doc_type='85') — ล็อกถาวรหลังบันทึกครั้งแรก (_currentId != null) เพราะ
  // เลขที่เอกสารถูกออกจาก config ของ doc_id นี้ไปแล้ว เปลี่ยนภายหลังจะทำให้เลขที่ไม่ตรงกับประเภทที่เลือกจริง
  List<ModuleDocument> _docTypes = [];
  int? _docId;
  String? _docCode;
  String? _docNameThai;
  String? _docNameEng;

  int? _priceListId;
  String? _priceListCode;
  String? _priceListName;
  String _changeType = 'REVISE';
  String _adjustmentMode = 'PERCENT';
  String _adjustmentDirection = 'INCREASE';
  // ปัดเศษราคาใหม่ที่คำนวณจาก % ให้สอดคล้องกับเงินจริง (0 = ไม่ปัดเศษ) — ใช้เฉพาะ _adjustmentMode == 'PERCENT'
  double _roundingStep = 0;
  late TextEditingController _adjustmentValueCtrl;
  DateTime? _effectiveFrom;
  DateTime? _effectiveTo;
  List<int> _selectedCategoryIds = [];
  late TextEditingController _itemCodeFromCtrl;
  late TextEditingController _itemCodeToCtrl;
  late TextEditingController _remarkCtrl;

  List<ImItemCategory> _categories = [];
  List<ImPriceChangeDetail> _details = [];

  bool get _isDraftEditable => _status == 'Draft' && widget.mode != Mode.view && widget.mode != Mode.none;
  bool get _canEditDocType => _isDraftEditable && _currentId == null;

  // ตัวเลือกปัดเศษ — 0 = ไม่ปัดเศษ ส่วนที่เหลือครอบคลุมหน่วยเงินจริงที่ใช้บ่อย (สตางค์ 0.25/0.50 ถึงหลักพัน)
  static const List<double> _roundingSteps = [0, 0.25, 0.5, 1, 5, 10, 100, 1000];
  String _roundingStepLabel(double step, bool isEnglish) {
    if (step == 0) return isEnglish ? 'No rounding' : 'ไม่ปัดเศษ';
    final text = step == step.roundToDouble() ? step.toInt().toString() : step.toString();
    return isEnglish ? 'Nearest $text' : 'ปัดเศษทีละ $text';
  }

  @override
  void initState() {
    super.initState();
    _adjustmentValueCtrl = TextEditingController();
    _itemCodeFromCtrl = TextEditingController();
    _itemCodeToCtrl = TextEditingController();
    _remarkCtrl = TextEditingController();
    if (widget.selected != null) { _populate(widget.selected!); } else { _clear(); }
    _loadCategories();
    _loadDocTypes();
  }

  @override
  void didUpdateWidget(covariant ImPriceChangeDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected || widget.mode != oldWidget.mode || widget.requestSeq != oldWidget.requestSeq) {
      if (widget.selected != null) { _populate(widget.selected!); } else { _clear(); }
    }
  }

  @override
  void dispose() {
    _adjustmentValueCtrl.dispose();
    _itemCodeFromCtrl.dispose();
    _itemCodeToCtrl.dispose();
    _remarkCtrl.dispose();
    for (final c in _priceCtrls.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final rows = await ImItemCategoryService().fetchActiveRows();
      if (mounted) setState(() => _categories = rows.where((c) => c.categoryType == 'CATEGORY').toList());
    } catch (_) {}
  }

  // ดึง "ประเภทเอกสาร" (sa_module_document) ที่ผู้ใช้คนนี้มีสิทธิ์ภายใต้ IM — กรองเฉพาะ sys_doc_type='85'
  // (เปลี่ยนแปลงราคา) เพราะ endpoint คืนทุกประเภทเอกสารของ IM มา (GRN/DLN/AJS ฯลฯ ด้วย)
  Future<void> _loadDocTypes() async {
    try {
      final rows = await ImPriceChangeService().fetchDocTypesByUser();
      final filtered = rows.where((d) => d.sysDocType == '85').toList();
      if (!mounted) return;
      setState(() {
        _docTypes = filtered;
        _autoSelectDocTypeIfSingle();
      });
    } catch (_) {}
  }

  void _autoSelectDocTypeIfSingle() {
    if (_docId == null && _docTypes.length == 1) {
      final d = _docTypes.first;
      _docId = d.id; _docCode = d.docCode; _docNameThai = d.docNameThai; _docNameEng = d.docNameEng;
    }
  }

  void _setDetails(List<ImPriceChangeDetail> rows) {
    for (final c in _priceCtrls.values) { c.dispose(); }
    _priceCtrls.clear();
    _groupExpanded.clear();
    _details = rows;
  }

  void _populate(ImPriceChangeHeader h) {
    _currentId = h.id;
    _changeNo = h.changeNo;
    _status = h.status;
    _docId = h.docId; _docCode = h.docCode; _docNameThai = h.docNameThai; _docNameEng = h.docNameEng;
    _priceListId = h.priceListId; _priceListCode = h.priceListCode; _priceListName = h.priceListName;
    _changeType = h.changeType;
    _adjustmentMode = h.adjustmentMode;
    _adjustmentDirection = h.adjustmentDirection;
    _adjustmentValueCtrl.text = h.adjustmentValue == 0 ? '' : '${h.adjustmentValue}';
    _roundingStep = h.roundingStep;
    _effectiveFrom = h.effectiveFrom;
    _effectiveTo = h.effectiveTo;
    _selectedCategoryIds = List.from(h.categoryFilter);
    _itemCodeFromCtrl.text = h.itemCodeFrom ?? '';
    _itemCodeToCtrl.text = h.itemCodeTo ?? '';
    _remarkCtrl.text = h.remark ?? '';
    _setDetails(List.from(h.details));
    _isFilterExpanded = h.details.isEmpty;
  }

  void _clear() {
    _currentId = null; _changeNo = null; _status = 'Draft';
    _docId = null; _docCode = null; _docNameThai = null; _docNameEng = null;
    _priceListId = null; _priceListCode = null; _priceListName = null;
    _changeType = 'REVISE'; _adjustmentMode = 'PERCENT'; _adjustmentDirection = 'INCREASE'; _roundingStep = 0;
    _adjustmentValueCtrl.clear();
    _effectiveFrom = DateTime.now().add(const Duration(days: 1));
    _effectiveTo = null;
    _selectedCategoryIds = [];
    _itemCodeFromCtrl.clear(); _itemCodeToCtrl.clear(); _remarkCtrl.clear();
    _setDetails([]);
    _isFilterExpanded = true;
    _autoSelectDocTypeIfSingle();
  }

  void _warn(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _confirm(String title, String content) async {
    final isEnglish = _isEnglish;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEnglish ? 'Confirm' : 'ยืนยัน')),
        ],
      ),
    );
    return result == true;
  }

  // ── ตารางราคาเป้าหมาย ────────────────────────────────────────────────────
  Future<void> _pickPriceList() async {
    await ImPriceListListWidget.search(context, onSelected: (h) {
      setState(() {
        _priceListId = h.id; _priceListCode = h.priceListCode; _priceListName = h.priceListName; 
        _setDetails([]); // ราคาที่ดึงมาก่อนหน้าอ้างลิสต์เดิม ไม่เกี่ยวกับลิสต์ใหม่ที่เพิ่งเลือก
      });
    });
  }

  // ── หมวดหมู่ (multi-select) ──────────────────────────────────────────────
  Future<void> _pickCategories() async {
    final isEnglish = _isEnglish;
    final result = await showDialog<List<int>>(
      context: context,
      builder: (_) => _MultiPickerDialog<ImItemCategory>(
        title: isEnglish ? 'Select Item Categories' : 'เลือกหมวดหมู่สินค้า',
        items: _categories,
        selected: _selectedCategoryIds,
        idOf: (c) => c.id,
        labelOf: (c) => '${c.categoryCode}  ${isEnglish && (c.categoryNameEn ?? '').isNotEmpty ? c.categoryNameEn! : c.categoryNameTh}',
        isEnglish: isEnglish,
      ),
    );
    if (result != null && mounted) setState(() => _selectedCategoryIds = result);
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _effectiveFrom : _effectiveTo) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() { if (isFrom) { _effectiveFrom = picked; } else { _effectiveTo = picked; } });
  }

  // ── ดึงข้อมูล ────────────────────────────────────────────────────────────
  Future<void> _fetchPreview() async {
    if (_priceListId == null) return;
    setState(() => _isFetching = true);
    try {
      final rows = await ImPriceChangeService().previewLines(
        priceListId: _priceListId!,
        categoryIds: _selectedCategoryIds.isEmpty ? null : _selectedCategoryIds,
        itemCodeFrom: _itemCodeFromCtrl.text.trim().isEmpty ? null : _itemCodeFromCtrl.text.trim(),
        itemCodeTo: _itemCodeToCtrl.text.trim().isEmpty ? null : _itemCodeToCtrl.text.trim(),
      );
      if (mounted) setState(() { _setDetails(rows); _isFilterExpanded = false; });
    } catch (e) {
      _warn(_isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  // ── คำนวณราคาใหม่ (เฉพาะแถวที่ติ๊กเลือกและมีราคาเดิม — รายการใหม่ต้องกรอกเอง) ─────────────────
  void _recalculate() {
    final value = double.tryParse(_adjustmentValueCtrl.text) ?? 0;
    setState(() {
      for (int i = 0; i < _details.length; i++) {
        final d = _details[i];
        if (!d.isSelected || d.oldUnitPriceFc == null) continue;
        double newPrice;
        switch (_adjustmentMode) {
          case 'AMOUNT':
            newPrice = _adjustmentDirection == 'DECREASE' ? d.oldUnitPriceFc! - value : d.oldUnitPriceFc! + value;
            break;
          case 'SET_PRICE':
            newPrice = value;
            break;
          default:
            final delta = d.oldUnitPriceFc! * (value / 100);
            newPrice = _adjustmentDirection == 'DECREASE' ? d.oldUnitPriceFc! - delta : d.oldUnitPriceFc! + delta;
            // ปัดเศษให้สอดคล้องกับเงินจริง (เช่น ปัดเป็นทีละ 5/10 บาท) — ใช้เฉพาะโหมด % เท่านั้น ตาม
            // ที่ผู้ใช้ขอ (AMOUNT/SET_PRICE ผู้ใช้กำหนดค่าตรงอยู่แล้ว ไม่ต้องปัดซ้ำ)
            if (_roundingStep > 0) newPrice = (newPrice / _roundingStep).round() * _roundingStep;
        }
        if (newPrice < 0) newPrice = 0;
        newPrice = double.parse(newPrice.toStringAsFixed(4));
        _details[i] = d.copyWith(newUnitPriceFc: newPrice);
        _priceCtrls[i]?.text = newPrice.toStringAsFixed(2);
      }
    });
  }

  List<int> _visibleIndices() {
    final q = _gridSearchQuery.trim().toUpperCase();
    if (q.isEmpty) return List.generate(_details.length, (i) => i);
    final out = <int>[];
    for (int i = 0; i < _details.length; i++) {
      final d = _details[i];
      if ((d.itemCode ?? '').toUpperCase().contains(q) ||
          (d.itemNameTh ?? '').toUpperCase().contains(q) ||
          (d.itemNameEn ?? '').toUpperCase().contains(q)) {
        out.add(i);
      }
    }
    return out;
  }

  ImPriceChangeHeader _buildHeader() => ImPriceChangeHeader(
        id: _currentId,
        docId: _docId,
        priceListId: _priceListId,
        changeType: _changeType,
        adjustmentMode: _adjustmentMode,
        adjustmentDirection: _adjustmentDirection,
        adjustmentValue: double.tryParse(_adjustmentValueCtrl.text) ?? 0,
        roundingStep: _roundingStep,
        effectiveFrom: _effectiveFrom,
        effectiveTo: _effectiveTo,
        categoryFilter: _selectedCategoryIds,
        itemCodeFrom: _itemCodeFromCtrl.text.trim().isEmpty ? null : _itemCodeFromCtrl.text.trim(),
        itemCodeTo: _itemCodeToCtrl.text.trim().isEmpty ? null : _itemCodeToCtrl.text.trim(),
        remark: _remarkCtrl.text.trim().isEmpty ? null : _remarkCtrl.text.trim(),
        details: _details,
      );

  Future<void> _saveDraft() async {
    final isEnglish = _isEnglish;
    if (_docId == null) { _warn(isEnglish ? 'Please select a document type' : 'กรุณาเลือกประเภทเอกสาร'); return; }
    if (_priceListId == null) { _warn(isEnglish ? 'Please select a target price list' : 'กรุณาเลือกตารางราคาเป้าหมาย'); return; }
    if (_effectiveFrom == null) { _warn(isEnglish ? 'Please set the effective date' : 'กรุณาระบุวันที่มีผล'); return; }
    if (_changeType == 'PROMOTION' && _effectiveTo == null) { _warn(isEnglish ? 'Promotion requires an end date' : 'โปรโมชั่นต้องระบุวันสิ้นสุด'); return; }
    if (_details.isEmpty) { _warn(isEnglish ? 'Please fetch item data first' : 'กรุณาดึงข้อมูลสินค้าก่อน'); return; }
    setState(() => _isSaving = true);
    try {
      final svc = ImPriceChangeService();
      final header = _buildHeader();
      final saved = _currentId == null ? await svc.addRow(header) : await svc.updateRow(header);
      if (mounted) {
        setState(() { _currentId = saved.id; _changeNo = saved.changeNo; _status = saved.status; });
        widget.onRefreshList();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Saved' : 'บันทึกสำเร็จ')));
      }
    } catch (e) {
      _warn(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _submitForApproval() async {
    final isEnglish = _isEnglish;
    if (_docId == null) { _warn(isEnglish ? 'Please select a document type' : 'กรุณาเลือกประเภทเอกสาร'); return; }
    if (_priceListId == null) { _warn(isEnglish ? 'Please select a target price list' : 'กรุณาเลือกตารางราคาเป้าหมาย'); return; }
    if (_details.where((d) => d.isSelected).isEmpty) {
      _warn(isEnglish ? 'Please select at least one line' : 'กรุณาเลือกรายการอย่างน้อย 1 รายการ');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final svc = ImPriceChangeService();
      final header = _buildHeader();
      final saved = _currentId == null ? await svc.addRow(header) : await svc.updateRow(header);
      final submitted = await svc.submit(saved.id!);
      if (mounted) {
        setState(() { _currentId = submitted.id; _changeNo = submitted.changeNo; _status = submitted.status; });
        widget.onRefreshList();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Submitted for approval' : 'ส่งขออนุมัติสำเร็จ')));
      }
    } catch (e) {
      _warn(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _doStatusAction(Future<ImPriceChangeHeader> Function(ImPriceChangeService, int) action) async {
    if (_currentId == null) return;
    setState(() => _isSaving = true);
    try {
      final result = await action(ImPriceChangeService(), _currentId!);
      if (mounted) {
        setState(() => _populate(result));
        widget.onRefreshList();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEnglish ? 'Done' : 'ดำเนินการสำเร็จ')));
      }
    } catch (e) {
      _warn(_isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── UI helpers ───────────────────────────────────────────────────────────
  Widget _buildFkField({required String label, required String? displayText, required bool hasValue, required VoidCallback onSearch, VoidCallback? onClear}) =>
      InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
        child: Row(children: [
          Expanded(
            child: hasValue
                ? Text(displayText ?? '', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)
                : Text(_isEnglish ? '— Not specified —' : '— ไม่ระบุ —', style: TextStyle(color: Colors.grey.shade600)),
          ),
          if (_isDraftEditable) ...[
            IconButton(icon: const Icon(Icons.search, size: 18, color: Colors.teal), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onSearch),
            if (hasValue && onClear != null)
              IconButton(icon: const Icon(Icons.clear, size: 18, color: Colors.red), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onClear),
          ],
        ]),
      );

  Widget _buildMultiField({required String label, required int count, required String allLabel, required VoidCallback onTap, required VoidCallback onClear}) {
    final hasValue = count > 0;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label, border: const OutlineInputBorder(), isDense: true,
        suffixIcon: _isDraftEditable
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                if (hasValue) InkWell(onTap: onClear, child: const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.clear, size: 16, color: Colors.grey))),
                InkWell(onTap: onTap, child: const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_drop_down, size: 20))),
              ])
            : null,
      ),
      child: InkWell(
        onTap: _isDraftEditable ? onTap : null,
        child: Text(
          hasValue ? (_isEnglish ? '$count selected' : 'เลือก $count รายการ') : allLabel,
          style: TextStyle(fontSize: 13, color: hasValue ? Colors.black87 : Colors.black38),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildDateField({required String label, required DateTime? date, required VoidCallback onPick}) {
    final text = date == null ? '' : '${date.day}/${date.month}/${date.year}';
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label, border: const OutlineInputBorder(), isDense: true,
        suffixIcon: _isDraftEditable ? IconButton(icon: const Icon(Icons.calendar_today, size: 16), onPressed: onPick) : null,
      ),
      child: InkWell(
        onTap: _isDraftEditable ? onPick : null,
        child: Text(text.isEmpty ? (_isEnglish ? '— Not specified —' : '— ไม่ระบุ —') : text, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl) => TextField(
        controller: ctrl,
        enabled: _isDraftEditable,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
      );

  // ประเภทเอกสาร (sa_module_document) — มิเรอร์ pattern ธุรกรรม IM ปกติ: DropdownButtonFormField เมื่อยังแก้ไขได้
  // และมีให้เลือกมากกว่า 1 ตัว, ไม่งั้นแสดงเป็นข้อความอ่านอย่างเดียว (ล็อกถาวรหลังบันทึกครั้งแรก)
  Widget _buildDocTypeField(bool isEnglish) {
    if (_canEditDocType && _docTypes.length > 1) {
      return DropdownButtonFormField<int>(
        value: _docId,
        isExpanded: true,
        decoration: InputDecoration(labelText: isEnglish ? 'Document Type *' : 'ประเภทเอกสาร *', border: const OutlineInputBorder(), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
        items: _docTypes.map((d) => DropdownMenuItem(
          value: d.id,
          child: Text('${d.docCode} ${isEnglish && d.docNameEng.isNotEmpty ? d.docNameEng : d.docNameThai}', overflow: TextOverflow.ellipsis),
        )).toList(),
        onChanged: (v) {
          final d = _docTypes.firstWhere((e) => e.id == v);
          setState(() { _docId = d.id; _docCode = d.docCode; _docNameThai = d.docNameThai; _docNameEng = d.docNameEng; });
        },
      );
    }
    return InputDecorator(
      decoration: InputDecoration(labelText: isEnglish ? 'Document Type' : 'ประเภทเอกสาร', border: const OutlineInputBorder(), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
      child: Text(
        _docCode != null
            ? '$_docCode  ${isEnglish && (_docNameEng ?? '').isNotEmpty ? _docNameEng : (_docNameThai ?? '')}'
            : (isEnglish ? '— Not specified —' : '— ไม่ระบุ —'),
        style: const TextStyle(fontSize: 13),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ── Zone 1: เงื่อนไข ─────────────────────────────────────────────────────
  Widget _buildFilterZone(bool isEnglish) {
    final priceListDisplay = '${_priceListCode ?? ''} — ${_priceListName ?? ''}';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(flex: 1, child: _buildDocTypeField(isEnglish)),
        const SizedBox(width: 10),
        Expanded(
          flex: 1,
          child: _buildFkField(
            label: isEnglish ? 'Target Price List *' : 'ตารางราคาเป้าหมาย *',
            hasValue: _priceListId != null,
            displayText: priceListDisplay,
            onSearch: _pickPriceList,
            onClear: () => setState(() { _priceListId = null; _priceListCode = null; _priceListName = null; _setDetails([]); }),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 1,
          child: DropdownButtonFormField<String>(
            value: _changeType,
            decoration: InputDecoration(labelText: isEnglish ? 'Change Type' : 'ประเภทการเปลี่ยน', border: const OutlineInputBorder(), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            items: imPriceChangeTypes.map((t) => DropdownMenuItem(value: t, child: Text(imPriceChangeTypeLabel(t, isEnglish)))).toList(),
            onChanged: _isDraftEditable ? (v) => setState(() => _changeType = v ?? 'REVISE') : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(flex: 1, child: _buildDateField(label: isEnglish ? 'Effective From *' : 'วันที่มีผล *', date: _effectiveFrom, onPick: () => _pickDate(isFrom: true))),
      ]),
      // วันสิ้นสุด — เฉพาะ PROMOTION เท่านั้น เหลือบรรทัดเดียวลำพังหลังย้ายวันที่มีผลขึ้นไปรวมกับแถวบน
      if (_changeType == 'PROMOTION') ...[
        const SizedBox(height: 10),
        Row(children: [
          Expanded(flex: 1, child: _buildDateField(label: isEnglish ? 'Effective To *' : 'วันสิ้นสุด *', date: _effectiveTo, onPick: () => _pickDate(isFrom: false))),
          const SizedBox(width: 10),
          const Expanded(flex: 1, child: SizedBox()),
          const SizedBox(width: 10),
          const Expanded(flex: 1, child: SizedBox()),
          const SizedBox(width: 10),
          const Expanded(flex: 1, child: SizedBox()),
        ]),
      ],
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _buildMultiField(
          label: isEnglish ? 'Category' : 'หมวดหมู่',
          count: _selectedCategoryIds.length,
          allLabel: isEnglish ? 'All categories' : 'ทุกหมวดหมู่',
          onTap: _pickCategories,
          onClear: () => setState(() => _selectedCategoryIds = []),
        )),
        const SizedBox(width: 10),
        Expanded(child: _buildTextField(isEnglish ? 'Item code from' : 'รหัสสินค้าจาก', _itemCodeFromCtrl)),
        const SizedBox(width: 10),
        Expanded(child: _buildTextField(isEnglish ? 'Item code to' : 'รหัสสินค้าถึง', _itemCodeToCtrl)),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: (_priceListId == null || _isFetching) ? null : _fetchPreview,
          icon: _isFetching ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search, size: 16),
          label: Text(isEnglish ? 'Fetch data' : 'ดึงข้อมูล'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700], foregroundColor: Colors.white),
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          flex: 1,
          child: DropdownButtonFormField<String>(
            value: _adjustmentMode,
            decoration: InputDecoration(labelText: isEnglish ? 'Adjustment' : 'รูปแบบปรับราคา', border: const OutlineInputBorder(), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            items: imPriceChangeAdjustmentModes.map((m) => DropdownMenuItem(value: m, child: Text(imPriceChangeAdjustmentModeLabel(m, isEnglish)))).toList(),
            onChanged: _isDraftEditable ? (v) => setState(() => _adjustmentMode = v ?? 'PERCENT') : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 1,
          child: _adjustmentMode == 'SET_PRICE'
              ? const SizedBox()
              : DropdownButtonFormField<String>(
                  value: _adjustmentDirection,
                  decoration: InputDecoration(labelText: isEnglish ? 'Direction' : 'ปรับขึ้น/ลง', border: const OutlineInputBorder(), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  items: imPriceChangeDirections.map((d) => DropdownMenuItem(value: d, child: Text(imPriceChangeDirectionLabel(d, isEnglish)))).toList(),
                  onChanged: _isDraftEditable ? (v) => setState(() => _adjustmentDirection = v ?? 'INCREASE') : null,
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 1,
          child: TextField(
            controller: _adjustmentValueCtrl,
            enabled: _isDraftEditable,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _adjustmentMode == 'SET_PRICE' ? (isEnglish ? 'New price' : 'ราคาใหม่') : (isEnglish ? 'Value' : 'ค่าที่ปรับ'),
              border: const OutlineInputBorder(), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // ปัดเศษ — ใช้เฉพาะโหมด % เพื่อให้ราคาที่คำนวณได้สอดคล้องกับเงินจริง (เช่น ปัดเป็นทีละ 5/10 บาท) ไม่เกี่ยวกับ
        // AMOUNT/SET_PRICE เพราะผู้ใช้กำหนดค่าตรงอยู่แล้ว — คงช่องไว้เป็น SizedBox เปล่าตอนไม่ใช่ % เพื่อให้ทั้ง 4
        // ฟีลด์ของบรรทัดนี้กว้างเท่ากันเสมอ (flex: 1 เท่ากันหมด) ไม่ขยับตามโหมดที่เลือก
        Expanded(
          flex: 1,
          child: _adjustmentMode == 'PERCENT'
              ? DropdownButtonFormField<double>(
                  value: _roundingStep,
                  decoration: InputDecoration(labelText: isEnglish ? 'Round to nearest' : 'ปัดเศษทีละ', border: const OutlineInputBorder(), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  items: _roundingSteps.map((s) => DropdownMenuItem(value: s, child: Text(_roundingStepLabel(s, isEnglish)))).toList(),
                  onChanged: _isDraftEditable ? (v) => setState(() => _roundingStep = v ?? 0) : null,
                )
              : const SizedBox(),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: _details.isEmpty ? null : _recalculate,
          icon: const Icon(Icons.calculate_outlined, size: 16),
          label: Text(isEnglish ? 'Recalculate' : 'คำนวณราคาใหม่'),
        ),
      ]),
      const SizedBox(height: 10),
      _buildTextField(isEnglish ? 'Remark' : 'หมายเหตุ', _remarkCtrl),
    ]);
  }

  // ── Zone 2: ตารางรีวิว ───────────────────────────────────────────────────
  Widget _buildGridToolbar(bool isEnglish) {
    final total = _details.length;
    final selected = _details.where((d) => d.isSelected).length;
    final newCount = _details.where((d) => d.isNewItem).length;
    final changedWithOld = _details.where((d) => !d.isNewItem && (d.oldUnitPriceFc ?? 0) != 0).toList();
    final avgPct = changedWithOld.isEmpty ? 0.0 : changedWithOld.map((d) => d.percentChange).reduce((a, b) => a + b) / changedWithOld.length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(children: [
          if (_isDraftEditable) ...[
            TextButton(
              onPressed: () => setState(() { for (int i = 0; i < _details.length; i++) { _details[i] = _details[i].copyWith(isSelected: true); } }),
              child: Text(isEnglish ? 'Select all' : 'เลือกทั้งหมด'),
            ),
            TextButton(
              onPressed: () => setState(() { for (int i = 0; i < _details.length; i++) { _details[i] = _details[i].copyWith(isSelected: false); } }),
              child: Text(isEnglish ? 'Select none' : 'ไม่เลือก'),
            ),
            TextButton(
              onPressed: () => setState(() {
                for (int i = 0; i < _details.length; i++) {
                  final d = _details[i];
                  _details[i] = d.copyWith(isSelected: d.isNewItem ? d.newUnitPriceFc > 0 : d.percentChange != 0);
                }
              }),
              child: Text(isEnglish ? 'Only changed' : 'เฉพาะที่เปลี่ยน'),
            ),
          ],
          const Spacer(),
          SizedBox(
            width: 220,
            child: TextField(
              decoration: InputDecoration(
                hintText: isEnglish ? 'Search in table' : 'ค้นหาในตาราง',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _gridSearchQuery = v),
            ),
          ),
        ]),
      ),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        color: Colors.teal.shade50,
        child: Text(
          isEnglish
              ? 'Total $total items  |  Selected $selected  |  Avg ${avgPct.toStringAsFixed(1)}%  |  New items $newCount'
              : 'ทั้งหมด $total รายการ  |  เลือก $selected  |  เฉลี่ย ${avgPct.toStringAsFixed(1)}%  |  รายการใหม่ $newCount รายการ',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    ]);
  }

  Widget _buildRow(int i, bool isEnglish) {
    final d = _details[i];
    final name = isEnglish && (d.itemNameEn ?? '').isNotEmpty ? d.itemNameEn : d.itemNameTh;
    final uomName = isEnglish && (d.uomNameEn ?? '').isNotEmpty ? d.uomNameEn : (d.uomNameTh ?? d.uomCode ?? '');
    final pct = d.percentChange;
    final ctrl = _priceCtrls.putIfAbsent(i, () => TextEditingController(text: d.newUnitPriceFc.toStringAsFixed(2)));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: d.isNewItem ? Colors.amber.shade50 : null,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(children: [
        Checkbox(
          value: d.isSelected,
          onChanged: _isDraftEditable ? (v) => setState(() => _details[i] = d.copyWith(isSelected: v ?? true)) : null,
        ),
        Expanded(
          flex: 4,
          child: Row(children: [
            Expanded(child: Text('${d.itemCode}  ${name ?? ''}', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
            if (d.isNewItem)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: Colors.amber.shade300, borderRadius: BorderRadius.circular(4)),
                child: Text(isEnglish ? 'New' : 'ใหม่', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
              ),
          ]),
        ),
        Expanded(flex: 1, child: Text(uomName ?? '', style: const TextStyle(fontSize: 12))),
        Expanded(flex: 2, child: Text(d.oldUnitPriceFc?.toStringAsFixed(2) ?? '—', style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
        const SizedBox(width: 4),
        Icon(Icons.arrow_forward, size: 12, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Expanded(
          flex: 2,
          child: _isDraftEditable
              ? TextField(
                  controller: ctrl,
                  enabled: d.isSelected,
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4), border: OutlineInputBorder()),
                  onChanged: (v) => setState(() => _details[i] = _details[i].copyWith(newUnitPriceFc: double.tryParse(v) ?? 0)),
                )
              : Text(d.newUnitPriceFc.toStringAsFixed(2), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
        ),
        SizedBox(
          width: 64,
          child: pct == 0
              ? const SizedBox()
              : Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Icon(pct > 0 ? Icons.arrow_upward : Icons.arrow_downward, size: 12, color: pct > 0 ? Colors.green : Colors.red),
                  Text('${pct.abs().toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, color: pct > 0 ? Colors.green : Colors.red)),
                ]),
        ),
      ]),
    );
  }

  Widget _buildGrid(bool isEnglish) {
    if (_details.isEmpty) {
      return Center(
        child: Text(
          isEnglish ? 'No data — set the filters above and click "Fetch data"' : 'ยังไม่มีข้อมูล — ตั้งเงื่อนไขด้านบนแล้วกด "ดึงข้อมูล"',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }
    final visible = _visibleIndices();
    final grouped = <int?, List<int>>{};
    for (final i in visible) {
      grouped.putIfAbsent(_details[i].categoryId, () => []).add(i);
    }
    final catKeys = grouped.keys.toList()
      ..sort((a, b) {
        final ca = _details[grouped[a]!.first].categoryCode ?? '';
        final cb = _details[grouped[b]!.first].categoryCode ?? '';
        return ca.compareTo(cb);
      });

    return ListView.builder(
      itemCount: catKeys.length,
      itemBuilder: (context, gi) {
        final catId = catKeys[gi];
        final indices = grouped[catId]!;
        final first = _details[indices.first];
        final catLabel = catId == null
            ? (isEnglish ? 'Uncategorized' : 'ไม่มีหมวดหมู่')
            : '${first.categoryCode}  ${isEnglish && (first.categoryNameEn ?? '').isNotEmpty ? first.categoryNameEn : first.categoryNameTh}';
        final selectedInGroup = indices.where((i) => _details[i].isSelected).length;
        final expanded = _groupExpanded[catId ?? -1] ?? true;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: () => setState(() => _groupExpanded[catId ?? -1] = !expanded),
            child: Container(
              color: Colors.blueGrey.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(children: [
                Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 18, color: Colors.blueGrey.shade700),
                const SizedBox(width: 6),
                Expanded(child: Text(catLabel, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800, fontSize: 13))),
                Text(
                  isEnglish ? '${indices.length} items, $selectedInGroup selected' : '${indices.length} รายการ, เลือก $selectedInGroup',
                  style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600),
                ),
              ]),
            ),
          ),
          if (expanded) ...indices.map((i) => _buildRow(i, isEnglish)),
        ]);
      },
    );
  }

  // ── แถบหัว + ปฏิบัติการตามสถานะ ───────────────────────────────────────────
  Widget _buildHeaderBar(bool isEnglish) {
    final canApprove = MenuScope.of(context)?.canApprove ?? false;
    final actionButtons = <Widget>[];
    if (_status == 'Draft') {
      actionButtons.addAll([
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveDraft,
          icon: _isSaving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save, size: 16),
          label: Text(isEnglish ? 'Save' : 'บันทึก'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[800], foregroundColor: Colors.white),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _isSaving ? null : _submitForApproval,
          icon: const Icon(Icons.send, size: 16),
          label: Text(isEnglish ? 'Submit' : 'ส่งขออนุมัติ'),
        ),
      ]);
    } else if (_status == 'Pending' && canApprove) {
      actionButtons.addAll([
        ElevatedButton.icon(
          onPressed: _isSaving ? null : () async {
            if (await _confirm(isEnglish ? 'Approve' : 'อนุมัติ', isEnglish ? 'Apply these price changes now?' : 'ต้องการอนุมัติและเขียนราคาจริงเลยหรือไม่?')) {
              _doStatusAction((svc, id) => svc.approve(id));
            }
          },
          icon: const Icon(Icons.check, size: 16),
          label: Text(isEnglish ? 'Approve' : 'อนุมัติ'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _isSaving ? null : () async {
            if (await _confirm(isEnglish ? 'Reject' : 'ไม่อนุมัติ', isEnglish ? 'Send this back to Draft for editing?' : 'ส่งกลับไปแก้ไขใหม่หรือไม่?')) {
              _doStatusAction((svc, id) => svc.reject(id));
            }
          },
          icon: const Icon(Icons.close, size: 16),
          label: Text(isEnglish ? 'Reject' : 'ไม่อนุมัติ'),
        ),
      ]);
    }
    if (['Draft', 'Pending'].contains(_status)) {
      actionButtons.add(const SizedBox(width: 8));
      actionButtons.add(TextButton(
        onPressed: _isSaving || _currentId == null ? null : () async {
          if (await _confirm(isEnglish ? 'Void' : 'ยกเลิก', isEnglish ? 'Cancel this transaction?' : 'ต้องการยกเลิกธุรกรรมนี้หรือไม่?')) {
            _doStatusAction((svc, id) => svc.voidChange(id));
          }
        },
        child: Text(isEnglish ? 'Void' : 'ยกเลิก', style: const TextStyle(color: Colors.red)),
      ));
    }

    return Container(
      color: Colors.teal[300],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Icon(Icons.price_change_outlined, color: Colors.teal[900], size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _changeNo ?? (isEnglish ? 'New Price Change' : 'สร้างธุรกรรมเปลี่ยนแปลงราคา'),
            style: TextStyle(color: Colors.teal[900], fontSize: 16, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(10)),
          child: Text(imPriceChangeStatusLabel(_status, isEnglish), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal[900])),
        ),
        ...actionButtons,
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(_isFilterExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.teal[900]),
          tooltip: _isFilterExpanded ? (isEnglish ? 'Collapse filters' : 'ย่อเงื่อนไข') : (isEnglish ? 'Expand filters' : 'ขยายเงื่อนไข'),
          onPressed: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
        ),
        TextButton(onPressed: widget.onCancel, child: Text(isEnglish ? 'Close' : 'ปิด', style: TextStyle(color: Colors.teal[900]))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    if (widget.isPlaceholder) {
      return Center(
        child: Text(
          isEnglish ? 'Select a price change transaction, or create a new one' : 'เลือกธุรกรรมเปลี่ยนแปลงราคา หรือสร้างใหม่',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }
    return Column(children: [
      _buildHeaderBar(isEnglish),
      if (_isFilterExpanded) Padding(padding: const EdgeInsets.all(10), child: _buildFilterZone(isEnglish)),
      const Divider(height: 1),
      _buildGridToolbar(isEnglish),
      Expanded(child: _buildGrid(isEnglish)),
    ]);
  }
}
