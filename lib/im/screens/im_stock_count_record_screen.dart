// lib/im/screens/im_stock_count_record_screen.dart — ขั้นตอนที่ 4: บันทึกรายการตรวจนับ
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/im_item.dart';
import '../models/im_stock_count.dart';
import '../services/im_item_service.dart';
import '../models/im_location.dart';
import '../services/im_stock_count_service.dart';
import '../widgets/im_stock_count_picker_field.dart';
import '../widgets/im_location_tree_widget.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';

double _parseNum(String s) => double.tryParse(s.trim()) ?? 0;
String _fmtNum(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : double.parse(v.toStringAsFixed(6)).toString();

class _RecordLine {
  final ImStockCountDetail detail;
  final TextEditingController countedQtyCtrl;
  // นับหลายหน่วย — ว่าง = กรอกยอดหน่วยหลักตรง ๆ, มีค่า = ยอดตรวจนับคำนวณจากผลรวม (ช่องยอดอ่านอย่างเดียว)
  List<ImStockCountUomCount> uomCounts;

  _RecordLine(this.detail)
      : countedQtyCtrl = TextEditingController(text: detail.countedQty != null ? _fmtNum(detail.countedQty!) : ''),
        uomCounts = List.of(detail.uomCounts);

  void dispose() => countedQtyCtrl.dispose();
}

class ImStockCountRecordScreen extends StatefulWidget {
  const ImStockCountRecordScreen({super.key});

  @override
  State<ImStockCountRecordScreen> createState() => _ImStockCountRecordScreenState();
}

class _ImStockCountRecordScreenState extends State<ImStockCountRecordScreen> {
  final ImStockCountService _service = ImStockCountService();
  final _dateFmt = DateFormat('dd/MM/yyyy');

  bool _isFilterExpanded = true;
  double _filterWidth = 340;
  bool _isDraggingDivider = false;
  bool _isEnglish = false;
  bool _isProcessing = false;
  bool _isSaving = false;

  ImStockCountHeader? _selectedCount;
  ImLocation? _selectedLocation;
  List<_RecordLine> _lines = [];
  bool _hasResult = false;

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _clearLines() {
    for (final l in _lines) {
      l.dispose();
    }
    _lines = [];
  }

  Future<void> _process() async {
    final isEnglish = _isEnglish;
    if (_selectedCount == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please select a count sheet' : 'กรุณาเลือกใบตรวจนับ')));
      return;
    }
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please select a location' : 'กรุณาเลือกตำแหน่งจัดเก็บ')));
      return;
    }
    setState(() => _isProcessing = true);
    try {
      final result = await _service.fetchLinesForRecording(id: _selectedCount!.id, locationId: _selectedLocation!.id);
      _clearLines();
      _lines = result.map((d) => _RecordLine(d)).toList();
      if (mounted) setState(() => _hasResult = true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _save() async {
    if (_selectedCount == null || _lines.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final payload = _lines
          .where((l) => l.uomCounts.isNotEmpty || l.countedQtyCtrl.text.trim().isNotEmpty)
          .map((l) => l.uomCounts.isNotEmpty
              ? {'id': l.detail.id, 'uom_counts': l.uomCounts.map((u) => u.toJson()).toList()}
              : {'id': l.detail.id, 'counted_qty': _parseNum(l.countedQtyCtrl.text)})
          .toList();
      await _service.updateCounts(id: _selectedCount!.id, lines: payload);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEnglish ? 'Saved' : 'บันทึกสำเร็จ')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEnglish ? 'Save failed: $e' : 'บันทึกล้มเหลว: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _exportExcel() async {
    if (_selectedCount == null || _selectedLocation == null) return;
    setState(() => _isSaving = true);
    try {
      await _service.exportExcel(id: _selectedCount!.id, locationId: _selectedLocation!.id);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEnglish ? 'Export failed: $e' : 'Export ล้มเหลว: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _importExcel() async {
    if (_selectedCount == null) return;
    final isEnglish = _isEnglish;
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx'], withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    setState(() => _isSaving = true);
    try {
      final validated = await _service.importValidate(id: _selectedCount!.id, fileBytes: file.bytes!, fileName: file.name);
      final errorRows = validated['errorRows'] ?? 0;
      final validRows = validated['validRows'] ?? 0;
      final rows = List<Map<String, dynamic>>.from(validated['rows'] ?? []);
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isEnglish ? 'Import Result' : 'ผลการตรวจสอบไฟล์'),
          content: Text(isEnglish ? 'Valid rows: $validRows, Error rows: $errorRows.\nImport valid rows now?' : 'แถวที่ถูกต้อง: $validRows แถว, แถวผิดพลาด: $errorRows แถว\nต้องการนำเข้าแถวที่ถูกต้องเลยหรือไม่?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEnglish ? 'Import' : 'นำเข้า')),
          ],
        ),
      );
      if (proceed != true || rows.isEmpty) return;
      await _service.importConfirm(id: _selectedCount!.id, rows: rows);
      await _process();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Imported $validRows rows' : 'นำเข้าสำเร็จ $validRows รายการ')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Import failed: $e' : 'นำเข้าล้มเหลว: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _fkField({required String label, required String? displayText, required bool hasValue, VoidCallback? onSearch}) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true, filled: true, fillColor: Colors.white),
      child: Row(children: [
        Expanded(
          child: Text(hasValue ? (displayText ?? '') : (_isEnglish ? '— Not specified —' : '— ไม่ระบุ —'),
              style: hasValue ? const TextStyle(fontWeight: FontWeight.bold) : TextStyle(color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
        ),
        if (onSearch != null) IconButton(icon: const Icon(Icons.search, color: Colors.teal, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onSearch),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;

    return Scaffold(
      appBar: AppBar(title: const MenuTitle(), backgroundColor: Colors.teal[800], foregroundColor: Colors.white),
      body: LayoutBuilder(builder: (context, constraints) {
        final maxFilterWidth = (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            width: 36,
            color: Colors.teal[800],
            child: IconButton(
              icon: Icon(_isFilterExpanded ? Icons.filter_list_off : Icons.filter_list, color: Colors.white, size: 20),
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
              tooltip: _isFilterExpanded ? (isEnglish ? 'Collapse filter' : 'ย่อเงื่อนไข') : (isEnglish ? 'Expand filter' : 'ขยายเงื่อนไข'),
            ),
          ),
          AnimatedContainer(
            duration: _isDraggingDivider ? Duration.zero : const Duration(milliseconds: 200),
            width: _isFilterExpanded ? _filterWidth : 0.0,
            child: ClipRect(
              child: OverflowBox(
                maxWidth: _filterWidth,
                minWidth: _filterWidth,
                alignment: Alignment.topLeft,
                child: ColoredBox(
                  color: Colors.blueGrey.shade100,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _fkField(
                        label: isEnglish ? 'Count Sheet *' : 'ใบตรวจนับ *',
                        hasValue: _selectedCount != null,
                        displayText: _selectedCount != null ? '${_selectedCount!.countNo} — ${_dateFmt.format(_selectedCount!.countDate)}' : null,
                        onSearch: () => ImStockCountPickerField.search(context, onSelected: (h) => setState(() {
                          _selectedCount = h;
                          _selectedLocation = null;
                          _hasResult = false;
                          _clearLines();
                        })),
                      ),
                      const SizedBox(height: 12),
                      _fkField(
                        label: isEnglish ? 'Warehouse' : 'คลังสินค้า',
                        hasValue: _selectedCount != null,
                        displayText: _selectedCount != null ? '${_selectedCount!.warehouseCode ?? ''} ${_selectedCount!.warehouseNameTh ?? ''}' : null,
                      ),
                      const SizedBox(height: 12),
                      _fkField(
                        label: isEnglish ? 'Location *' : 'ตำแหน่งจัดเก็บ *',
                        hasValue: _selectedLocation != null,
                        displayText: _selectedLocation != null ? '${_selectedLocation!.locationCode} ${_selectedLocation!.displayName(_isEnglish)}' : null,
                        onSearch: _selectedCount == null
                            ? null
                            : () => ImLocationTreeWidget.search(context, warehouseId: _selectedCount!.warehouseId, onSelected: (loc) => setState(() => _selectedLocation = loc)),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _process,
                          icon: _isProcessing
                              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.search, size: 18),
                          label: Text(isEnglish ? 'Process' : 'ประมวลผลเลือกข้อมูล'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          if (_isFilterExpanded)
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                onHorizontalDragStart: (_) => setState(() => _isDraggingDivider = true),
                onHorizontalDragUpdate: (details) => setState(() => _filterWidth = (_filterWidth + details.delta.dx).clamp(240.0, maxFilterWidth)),
                onHorizontalDragEnd: (_) => setState(() => _isDraggingDivider = false),
                child: Container(width: 5, color: Colors.grey[400]),
              ),
            ),
          Expanded(
            child: !_hasResult
                ? Center(child: Text(isEnglish ? 'Select filters and click Process' : 'กรุณาเลือกเงื่อนไขและกดประมวลผลเลือกข้อมูล', style: const TextStyle(color: Colors.grey)))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Wrap(spacing: 8, children: [
                        OutlinedButton.icon(onPressed: _isSaving ? null : _exportExcel, icon: const Icon(Icons.file_download, size: 16), label: Text(isEnglish ? 'Export Template' : 'Export เทมเพลต')),
                        OutlinedButton.icon(onPressed: _isSaving ? null : _importExcel, icon: const Icon(Icons.file_upload, size: 16), label: Text(isEnglish ? 'Import' : 'Import')),
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save, size: 16),
                          label: Text(isEnglish ? 'Save' : 'บันทึก'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
                        ),
                      ]),
                    ),
                    const Divider(height: 1),
                    _buildHeaderRow(isEnglish),
                    Expanded(
                      child: _lines.isEmpty
                          ? Center(child: Text(isEnglish ? 'No items under this location' : 'ไม่พบรายการสินค้าภายใต้ตำแหน่งนี้'))
                          : ListView.separated(
                              itemCount: _lines.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) => _buildDataRow(_lines[i]),
                            ),
                    ),
                  ]),
          ),
        ]);
      }),
    );
  }

  Widget _buildHeaderRow(bool isEnglish) {
    const style = TextStyle(fontWeight: FontWeight.bold, fontSize: 12);
    return Container(
      color: Colors.blue[50],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        Expanded(flex: 2, child: Text(isEnglish ? 'Warehouse' : 'คลังสินค้า', style: style)),
        Expanded(flex: 2, child: Text(isEnglish ? 'Bin' : 'ตำแหน่ง', style: style)),
        Expanded(flex: 4, child: Text(isEnglish ? 'Item Code / Name' : 'รหัส/ชื่อสินค้า', style: style)),
        Expanded(flex: 1, child: Text(isEnglish ? 'UOM' : 'หน่วยนับ', style: style)),
        Expanded(flex: 2, child: Text(isEnglish ? 'Counted Qty' : 'ยอดตรวจนับ', style: style)),
      ]),
    );
  }

  Widget _buildDataRow(_RecordLine line) {
    final d = line.detail;
    final uomName = _isEnglish && (d.uomNameEn ?? '').isNotEmpty ? d.uomNameEn : (d.uomNameTh ?? d.uomCode ?? '');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(children: [
        Expanded(flex: 2, child: Text(d.warehouseCode ?? '', style: const TextStyle(fontSize: 13))),
        Expanded(flex: 2, child: Text(d.locationCode ?? '', style: const TextStyle(fontSize: 13))),
        Expanded(flex: 4, child: Text('${d.itemCode ?? ''} — ${d.itemName ?? ''}', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
        Expanded(flex: 1, child: Text(uomName ?? '', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
        Expanded(
          flex: 2,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: line.countedQtyCtrl,
                  readOnly: line.uomCounts.isNotEmpty,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    isDense: true, border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    filled: line.uomCounts.isNotEmpty, fillColor: Colors.grey.shade100,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.calculate_outlined, size: 20, color: line.uomCounts.isNotEmpty ? Colors.teal : Colors.grey.shade600),
                tooltip: _isEnglish ? 'Count in several units' : 'นับหลายหน่วย',
                padding: const EdgeInsets.only(left: 4),
                constraints: const BoxConstraints(),
                onPressed: () => _editUomCounts(line),
              ),
            ]),
            if (line.uomCounts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  line.uomCounts.map((u) => '${_fmtNum(u.qty)} ${u.displayName(_isEnglish)}').join(' + '),
                  style: TextStyle(fontSize: 11, color: Colors.teal.shade800),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  // นับหลายหน่วย: กรอกจำนวนแยกตามหน่วยที่ใช้ตรวจนับได้ของสินค้า แล้วรวมเป็นยอดหน่วยหลัก (backend คำนวณซ้ำตอนบันทึก)
  Future<void> _editUomCounts(_RecordLine line) async {
    final isEnglish = _isEnglish;
    final messenger = ScaffoldMessenger.of(context);
    ImItemUoms u;
    try {
      u = await ImItemService().fetchItemUoms(line.detail.itemId, purpose: 'COUNT');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!mounted) return;
    final units = [...u.units]..sort((a, b) => b.factor.compareTo(a.factor));
    final base = units.where((o) => o.isBase).firstOrNull;
    final baseDp = base?.decimalPlaces ?? 6;
    final ctrls = {
      for (final o in units)
        o.uomId: TextEditingController(
          text: line.uomCounts.where((c) => c.uomId == o.uomId).map((c) => _fmtNum(c.qty)).firstOrNull ??
              (line.uomCounts.isEmpty && o.isBase ? line.countedQtyCtrl.text.trim() : ''),
        ),
    };
    double total() {
      var t = 0.0;
      for (final o in units) {
        t += _parseNum(ctrls[o.uomId]!.text) * o.factor;
      }
      return double.parse(t.toStringAsFixed(baseDp.clamp(0, 6)));
    }
    final result = await showDialog<List<ImStockCountUomCount>>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) => AlertDialog(
        title: Text('${isEnglish ? 'Count in several units' : 'นับหลายหน่วย'} — ${line.detail.itemCode ?? ''}'),
        content: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final o in units)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: ctrls[o.uomId],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setDlg(() {}),
                  decoration: InputDecoration(
                    labelText: o.isBase
                        ? '${o.displayName(isEnglish)} (${o.uomCode})'
                        : '${o.displayName(isEnglish)} (${o.uomCode}) = ${_fmtNum(o.factor)} ${base?.displayName(isEnglish) ?? ''}',
                    border: const OutlineInputBorder(), isDense: true,
                  ),
                ),
              ),
            const Divider(),
            Align(
              alignment: Alignment.centerRight,
              child: Text('${isEnglish ? 'Total' : 'รวม'}: ${_fmtNum(total())} ${base?.displayName(isEnglish) ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, [
              for (final o in units)
                if (_parseNum(ctrls[o.uomId]!.text) > 0)
                  ImStockCountUomCount(uomId: o.uomId, uomCode: o.uomCode, uomNameTh: o.uomNameTh, uomNameEn: o.uomNameEn,
                      qty: _parseNum(ctrls[o.uomId]!.text), factor: o.factor),
            ]),
            child: Text(isEnglish ? 'OK' : 'ตกลง'),
          ),
        ],
      )),
    );
    for (final c in ctrls.values) {
      c.dispose();
    }
    if (result == null || !mounted) return;
    setState(() {
      // หน่วยหลักหน่วยเดียว = กรอกยอดตรง ๆ ไม่ต้องเก็บแยกหน่วย
      if (result.length == 1 && result.first.uomId == base?.uomId) {
        line.uomCounts = [];
        line.countedQtyCtrl.text = _fmtNum(result.first.qty);
      } else {
        line.uomCounts = result;
        var t = 0.0;
        for (final c in result) {
          t += c.qty * c.factor;
        }
        line.countedQtyCtrl.text = result.isEmpty ? '' : _fmtNum(double.parse(t.toStringAsFixed(baseDp.clamp(0, 6))));
      }
    });
  }
}
