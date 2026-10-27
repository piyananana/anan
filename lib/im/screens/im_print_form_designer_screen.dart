// lib/im/screens/im_print_form_designer_screen.dart — หน้าจอออกแบบแบบฟอร์มพิมพ์ (ใช้ร่วมทุกแบบฟอร์ม)
// ซ้าย: รายการฟอร์ม / ขวา: ผืนผ้าใบ (หน่วย มม. ลากวาง/ย่อขยาย) + แผงคุณสมบัติ 3 แท็บ (ชิ้นงาน / ฟอร์ม / สำเนา)
// ผืนผ้าใบแสดงรูปพื้นหลังของสำเนาที่เลือก — ตำแหน่งข้อมูลใช้ร่วมกันทุกสำเนา (ซ่อนบางชิ้นงานในบางสำเนาได้ เฉพาะ LASER)
import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';

import '../../widgets/zoomable_pdf_preview.dart';
import '../models/im_print_form.dart';
import '../../sa/services/sa_language_provider.dart';
import '../services/im_print_form_service.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../utils/im_print_form_pdf.dart';
import '../utils/im_print_form_templates.dart';

// ขนาดกระดาษสำเร็จรูป (มม. แนวตั้ง)
const Map<String, List<double>> _paperPresets = {
  'A4': [210, 297],
  'A5': [148, 210],
  'LETTER': [215.9, 279.4],
  'CONT_9x11': [228.6, 279.4],
  'CONT_9x5.5': [228.6, 139.7],
};
const Map<String, List<String>> _paperLabels = {
  'A4': ['A4 (210 x 297 มม.)', 'A4 (210 x 297 mm)'],
  'A5': ['A5 (148 x 210 มม.)', 'A5 (148 x 210 mm)'],
  'LETTER': ['Letter (8.5 x 11 นิ้ว)', 'Letter (8.5 x 11 in)'],
  'CONT_9x11': ['กระดาษต่อเนื่อง 9 x 11 นิ้ว', 'Continuous 9 x 11 in'],
  'CONT_9x5.5': ['กระดาษต่อเนื่อง 9 x 5.5 นิ้ว', 'Continuous 9 x 5.5 in'],
  'CUSTOM': ['กำหนดเอง', 'Custom'],
};

class ImPrintFormDesignerScreen extends StatefulWidget {
  const ImPrintFormDesignerScreen({super.key});

  @override
  State<ImPrintFormDesignerScreen> createState() => _ImPrintFormDesignerScreenState();
}

class _ImPrintFormDesignerScreenState extends State<ImPrintFormDesignerScreen> {
  final _svc = ImPrintFormService();
  static final Color _appBarColor = Colors.blueGrey[700]!;
  static final Color _headerColor = Colors.blueGrey[300]!;

  bool _isEnglish = false;
  bool _isLeftExpanded = true;
  double _leftWidth = 300;
  bool _isDraggingDivider = false;

  bool _loading = true;
  bool _saving = false;
  List<PrintDataSource> _sources = [];
  List<PrintForm> _forms = [];
  String? _filterSource;

  PrintForm? _form; // ฟอร์มที่กำลังแก้ (สำเนาของข้อมูล — บันทึกแล้วจึงส่งไป backend)
  bool _dirty = false;
  String? _selectedId; // ชิ้นงานที่เลือก
  int _viewCopy = 1; // สำเนาที่แสดงพื้นหลังบนผืนผ้าใบ
  double _scale = 3; // px ต่อ มม.
  bool _showGrid = true;
  double _bgOpacity = 0.6;
  int _propsRev = 0; // เปลี่ยนเมื่อค่าถูกแก้จากผืนผ้าใบ → ช่องกรอกในแผงคุณสมบัติสร้างใหม่
  int _idSeq = 0;
  final _canvasFocus = FocusNode();
  final Map<String, Uint8List?> _imageCache = {};

  String t(String th, String en) => _isEnglish ? en : th;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _canvasFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final sources = await _svc.fetchSources();
      final forms = await _svc.fetchForms();
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _forms = forms;
      });
    } catch (e) {
      _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : Colors.green));
  }

  PrintDataSource? get _source {
    final f = _form;
    if (f == null) return null;
    for (final s in _sources) {
      if (s.key == f.dataSource) return s;
    }
    return null;
  }

  PrintElement? get _selected {
    final f = _form;
    if (f == null || _selectedId == null) return null;
    for (final e in f.elements) {
      if (e.id == _selectedId) return e;
    }
    return null;
  }

  String _newId() => 'e${DateTime.now().microsecondsSinceEpoch}${_idSeq++}';

  void _changed([VoidCallback? fn, bool bumpProps = false]) {
    setState(() {
      fn?.call();
      _dirty = true;
      if (bumpProps) _propsRev++;
    });
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('ยกเลิกการแก้ไข', 'Discard changes')),
        content: Text(t('แบบฟอร์มมีการแก้ไขที่ยังไม่บันทึก ต้องการยกเลิกการแก้ไขหรือไม่', 'This form has unsaved changes. Discard them?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('กลับไปแก้ไข', 'Keep editing'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('ยกเลิกการแก้ไข', 'Discard'), style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _openForm(PrintForm f) async {
    if (!await _confirmDiscard()) return;
    try {
      final full = await _svc.fetchForm(f.id!);
      if (!mounted) return;
      setState(() {
        _form = full;
        _dirty = false;
        _selectedId = null;
        _viewCopy = 1;
        _propsRev++;
      });
    } catch (e) {
      _snack('$e', error: true);
    }
  }

  Future<void> _newForm() async {
    if (!await _confirmDiscard()) return;
    if (_sources.isEmpty) return;
    final src = _sources.firstWhere((s) => s.key == _filterSource, orElse: () => _sources.first);
    final f = PrintForm(
      dataSource: src.key,
      nameTh: src.nameTh,
      nameEn: src.nameEn,
      copies: [
        PrintFormCopy(nameTh: 'ต้นฉบับ', nameEn: 'Original'),
        PrintFormCopy(nameTh: 'สำเนา', nameEn: 'Copy'),
      ],
      elements: src.key == 'SALES_INVOICE' ? starterSalesInvoiceLayout(_newId) : [],
    );
    setState(() {
      _form = f;
      _dirty = true;
      _selectedId = null;
      _viewCopy = 1;
      _propsRev++;
    });
  }

  Future<void> _cancel() async {
    final f = _form;
    if (f == null) return;
    if (!await _confirmDiscard()) return;
    setState(() => _dirty = false);
    if (f.id == null) {
      setState(() => _form = null);
    } else {
      await _openForm(f);
    }
  }

  Future<void> _save() async {
    final f = _form;
    if (f == null) return;
    if (f.code.trim().isEmpty || f.nameTh.trim().isEmpty) {
      _snack(t('กรุณาระบุรหัสและชื่อแบบฟอร์ม (แท็บ "ฟอร์ม")', 'Please enter the form code and name ("Form" tab)'), error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await _svc.saveForm(f);
      final forms = await _svc.fetchForms();
      if (!mounted) return;
      setState(() {
        _form = saved;
        _forms = forms;
        _dirty = false;
        _propsRev++;
      });
      _snack(t('บันทึกแบบฟอร์มแล้ว', 'Form saved'));
    } catch (e) {
      _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _duplicate(PrintForm f) async {
    final codeCtrl = TextEditingController(text: '${f.code}-COPY');
    final nameCtrl = TextEditingController(text: f.nameTh);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('คัดลอกแบบฟอร์ม', 'Duplicate form')),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: codeCtrl, decoration: InputDecoration(labelText: t('รหัสแบบฟอร์มใหม่', 'New form code'))),
            TextField(controller: nameCtrl, decoration: InputDecoration(labelText: t('ชื่อแบบฟอร์มใหม่', 'New form name'))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('ยกเลิก', 'Cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('คัดลอก', 'Duplicate'))),
        ],
      ),
    );
    if (ok != true) return;
    if (!await _confirmDiscard()) return;
    try {
      final copy = await _svc.duplicateForm(f.id!, codeCtrl.text.trim(), nameCtrl.text.trim());
      final forms = await _svc.fetchForms();
      if (!mounted) return;
      setState(() {
        _forms = forms;
        _form = copy;
        _dirty = false;
        _selectedId = null;
        _propsRev++;
      });
      _snack(t('คัดลอกแบบฟอร์มแล้ว', 'Form duplicated'));
    } catch (e) {
      _snack('$e', error: true);
    }
  }

  Future<void> _delete(PrintForm f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('ลบแบบฟอร์ม', 'Delete form')),
        content: Text(t('ต้องการลบแบบฟอร์ม "${f.nameTh}" หรือไม่ (ประวัติการพิมพ์ยังเก็บไว้)',
            'Delete form "${f.name(true)}"? (Print history is kept)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('ยกเลิก', 'Cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('ลบ', 'Delete'), style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.deleteForm(f.id!);
      final forms = await _svc.fetchForms();
      if (!mounted) return;
      setState(() {
        _forms = forms;
        if (_form?.id == f.id) {
          _form = null;
          _dirty = false;
        }
      });
      _snack(t('ลบแบบฟอร์มแล้ว', 'Form deleted'));
    } catch (e) {
      _snack('$e', error: true);
    }
  }

  // ── รูปภาพ ────────────────────────────────────────────────────────────────
  // ย่อรูปตอนอัปโหลด: กว้างไม่เกิน maxWidth px แล้วเข้ารหัส JPEG (PNG เล็กๆ เก็บตามเดิมเพื่อรักษาพื้นโปร่งใส)
  Future<String?> _pickImage({int maxWidth = 2000, bool keepSmallPng = false}) async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final file = res?.files.single;
    final bytes = file?.bytes;
    if (bytes == null) return null;
    final ext = (file!.extension ?? '').toLowerCase();
    if (keepSmallPng && ext == 'png' && bytes.length < 300 * 1024) {
      return 'data:image/png;base64,${base64Encode(bytes)}';
    }
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      _snack(t('อ่านไฟล์รูปไม่ได้', 'Cannot read the image file'), error: true);
      return null;
    }
    final resized = decoded.width > maxWidth ? img.copyResize(decoded, width: maxWidth) : decoded;
    final jpg = img.encodeJpg(resized, quality: 80);
    return 'data:image/jpeg;base64,${base64Encode(jpg)}';
  }

  Uint8List? _imageBytes(String? dataUrl) {
    if (dataUrl == null || dataUrl.isEmpty) return null;
    final key = '${dataUrl.length}:${dataUrl.hashCode}';
    return _imageCache.putIfAbsent(key, () => decodeDataUrl(dataUrl));
  }

  // ── เพิ่มชิ้นงาน ──────────────────────────────────────────────────────────
  Future<void> _addElement(String type) async {
    final f = _form;
    final src = _source;
    if (f == null || src == null) return;
    PrintElement e;
    switch (type) {
      case 'field':
        final key = await _pickField(src.headerFields.where((x) => x.type != 'image').toList());
        if (key == null) return;
        e = PrintElement(id: _newId(), type: 'field', field: key, w: 50, h: 6);
        break;
      case 'text':
        e = PrintElement(id: _newId(), type: 'text', text: t('ข้อความ', 'Text'), w: 40, h: 6);
        break;
      case 'line':
        e = PrintElement(id: _newId(), type: 'line', w: 50, h: 0);
        break;
      case 'rect':
        e = PrintElement(id: _newId(), type: 'rect', w: 60, h: 25);
        break;
      case 'image':
        e = PrintElement(id: _newId(), type: 'image', field: 'company_logo', w: 25, h: 20);
        break;
      default:
        final cols = [
          PrintColumn(field: 'line_no', title: t('ลำดับ', 'No.'), w: 12, align: 'C'),
          PrintColumn(field: 'item_desc', title: t('รายการ', 'Description'), w: 90),
          PrintColumn(field: 'qty', title: t('จำนวน', 'Qty'), w: 25, align: 'R'),
          PrintColumn(field: 'amount', title: t('จำนวนเงิน', 'Amount'), w: 30, align: 'R'),
        ].where((c) => src.field(c.field, line: true) != null).toList();
        e = PrintElement(id: _newId(), type: 'table', w: cols.fold<double>(0, (a, c) => a + c.w), h: 80, fontSize: 14, border: 'box', columns: cols);
    }
    _changed(() {
      f.elements.add(e);
      _selectedId = e.id;
    }, true);
    _canvasFocus.requestFocus();
  }

  bool _matches(PrintField f, String q) =>
      f.label(false).toLowerCase().contains(q) || f.label(true).toLowerCase().contains(q) || f.key.contains(q);

  Future<String?> _pickField(List<PrintField> fields, {String? current}) async {
    final groups = <String, List<PrintField>>{};
    for (final f in fields) {
      groups.putIfAbsent(f.group, () => []).add(f);
    }
    String query = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final q = query.toLowerCase();
          return AlertDialog(
            title: Text(t('เลือกฟิลด์', 'Select field')),
            content: SizedBox(
              width: 420,
              height: 480,
              child: Column(children: [
                TextField(
                  autofocus: true,
                  decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: t('ค้นหา', 'Search')),
                  onChanged: (v) => setD(() => query = v),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(children: [
                    for (final g in groups.entries) ...[
                      if (g.value.any((f) => q.isEmpty || _matches(f, q)))
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 2),
                          child: Text(printFieldGroupLabels[g.key]?[_isEnglish ? 1 : 0] ?? g.key,
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey[700])),
                        ),
                      for (final f in g.value.where((f) => q.isEmpty || _matches(f, q)))
                        ListTile(
                          dense: true,
                          selected: f.key == current,
                          title: Text(_source?.displayLabel(f, _isEnglish) ?? f.label(_isEnglish)),
                          trailing: _source?.pairOf(f) == null
                              ? null
                              : Text(f.key.endsWith('_en') ? 'EN' : t('ไทย', 'TH'),
                                  style: TextStyle(fontSize: 11, color: Colors.blueGrey[600], fontWeight: FontWeight.bold)),
                          subtitle: Text('${f.key} · ${f.label(!_isEnglish)}', style: const TextStyle(fontSize: 11)),
                          onTap: () => Navigator.pop(ctx, f.key),
                        ),
                    ],
                  ]),
                ),
              ]),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('ยกเลิก', 'Cancel')))],
          );
        },
      ),
    );
  }

  void _deleteSelected() {
    final f = _form;
    final sel = _selected;
    if (f == null || sel == null) return;
    _changed(() {
      f.elements.remove(sel);
      _selectedId = null;
    }, true);
  }

  void _duplicateSelected() {
    final f = _form;
    final sel = _selected;
    if (f == null || sel == null) return;
    final c = sel.copy(newId: _newId())
      ..x = sel.x + 3
      ..y = sel.y + 3;
    _changed(() {
      f.elements.add(c);
      _selectedId = c.id;
    }, true);
  }

  void _moveLayer(int dir) {
    final f = _form;
    final sel = _selected;
    if (f == null || sel == null) return;
    final i = f.elements.indexOf(sel);
    final j = (i + dir).clamp(0, f.elements.length - 1);
    if (i == j) return;
    _changed(() {
      f.elements.removeAt(i);
      f.elements.insert(j, sel);
    });
  }

  KeyEventResult _onCanvasKey(FocusNode node, KeyEvent ev) {
    if (ev is! KeyDownEvent && ev is! KeyRepeatEvent) return KeyEventResult.ignored;
    final sel = _selected;
    if (sel == null) return KeyEventResult.ignored;
    final step = HardwareKeyboard.instance.isShiftPressed ? 5.0 : 0.5;
    double dx = 0, dy = 0;
    if (ev.logicalKey == LogicalKeyboardKey.arrowLeft) dx = -step;
    if (ev.logicalKey == LogicalKeyboardKey.arrowRight) dx = step;
    if (ev.logicalKey == LogicalKeyboardKey.arrowUp) dy = -step;
    if (ev.logicalKey == LogicalKeyboardKey.arrowDown) dy = step;
    if (ev.logicalKey == LogicalKeyboardKey.delete) {
      _deleteSelected();
      return KeyEventResult.handled;
    }
    if (dx == 0 && dy == 0) return KeyEventResult.ignored;
    _changed(() {
      sel.x = _r(sel.x + dx);
      sel.y = _r(sel.y + dy);
    }, true);
    return KeyEventResult.handled;
  }

  double _r(double v) => (v * 10).roundToDouble() / 10;

  // ── ดูตัวอย่าง PDF ────────────────────────────────────────────────────────
  Future<void> _preview() async {
    final f = _form;
    final src = _source;
    if (f == null || src == null) return;
    // เลือกเอกสารจริง (ว่าง = ข้อมูลตัวอย่าง)
    String? docKey;
    try {
      final docs = await _svc.fetchDocs(src.key);
      if (!mounted) return;
      final pick = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t('ดูตัวอย่างด้วยเอกสาร', 'Preview with document')),
          content: SizedBox(
            width: 480,
            height: 420,
            child: ListView(children: [
              ListTile(
                leading: const Icon(Icons.science_outlined),
                title: Text(t('ข้อมูลตัวอย่าง (แสดงชื่อฟิลด์)', 'Sample data (field names)')),
                onTap: () => Navigator.pop(ctx, ''),
              ),
              const Divider(),
              for (final d in docs.reversed.take(200))
                ListTile(
                  dense: true,
                  title: Text('${d.docNo}  ${formatPrintDate(d.docDate, 'dmy_be')}'),
                  subtitle: Text(d.customerName),
                  trailing: Text(formatPrintNumber(d.totalAmount, 'money', '')),
                  onTap: () => Navigator.pop(ctx, d.key),
                ),
            ]),
          ),
        ),
      );
      if (pick == null) return;
      docKey = pick.isEmpty ? null : pick;
    } catch (e) {
      _snack('$e', error: true);
      return;
    }
    PrintData data;
    try {
      data = docKey == null
          ? PrintData(company: const {}, docs: [samplePrintDoc(src, _isEnglish, lineCount: 25)])
          : await _svc.fetchPrintData(src.key, [docKey], formId: f.id);
    } catch (e) {
      _snack('$e', error: true);
      return;
    }
    if (!mounted) return;
    final form = f.clone();
    final sample = docKey == null;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 900,
          height: MediaQuery.of(ctx).size.height * 0.9,
          child: Column(children: [
            Container(
              color: _headerColor,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(children: [
                Expanded(
                  child: Text(
                    form.isPreprinted
                        ? t('ตัวอย่าง (แสดงพื้นหลังเพื่อตรวจตำแหน่ง — พิมพ์จริงไม่พิมพ์พื้นหลัง)', 'Preview (background shown for alignment only)')
                        : t('ตัวอย่าง', 'Preview'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
              ]),
            ),
            Expanded(
              child: ZoomablePdfPreview(
                documentVersion: DateTime.now().millisecondsSinceEpoch,
                initialPageFormat: PdfPageFormat(form.paperWidth * PdfPageFormat.mm, form.paperHeight * PdfPageFormat.mm),
                build: (_) => PrintFormPdf.build(form: form, source: src, data: data, printedBy: '', showBackground: true),
                // พิมพ์จากหน้าจอนี้ได้เฉพาะข้อมูลตัวอย่าง (พิมพ์เอกสารจริงต้องผ่านหน้าจอพิมพ์เพื่อบันทึกประวัติ)
                allowPrinting: sample,
                allowSharing: false,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    _isEnglish = context.watch<LanguageProvider>().isEnglish;
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: _appBarColor,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, constraints) {
              final maxLeftWidth = (constraints.maxWidth - 36 - 5 - 600).clamp(200.0, double.infinity);
              return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  width: 36,
                  color: _appBarColor,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: IconButton(
                      icon: Icon(_isLeftExpanded ? Icons.filter_list_off : Icons.filter_list, color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      onPressed: () => setState(() => _isLeftExpanded = !_isLeftExpanded),
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: _isDraggingDivider ? Duration.zero : const Duration(milliseconds: 200),
                  width: _isLeftExpanded ? _leftWidth : 0.0,
                  child: ClipRect(
                    child: OverflowBox(
                      maxWidth: _leftWidth,
                      minWidth: _leftWidth,
                      alignment: Alignment.topLeft,
                      child: ColoredBox(color: Colors.blueGrey.shade100, child: _buildFormList()),
                    ),
                  ),
                ),
                if (_isLeftExpanded)
                  MouseRegion(
                    cursor: SystemMouseCursors.resizeColumn,
                    child: GestureDetector(
                      onHorizontalDragStart: (_) => setState(() => _isDraggingDivider = true),
                      onHorizontalDragUpdate: (d) => setState(() => _leftWidth = (_leftWidth + d.delta.dx).clamp(200.0, maxLeftWidth)),
                      onHorizontalDragEnd: (_) => setState(() => _isDraggingDivider = false),
                      child: Container(width: 5, color: Colors.grey[400]),
                    ),
                  ),
                Expanded(child: _form == null ? _buildEmpty() : _buildEditor()),
              ]);
            }),
    );
  }

  Widget _buildEmpty() => Center(
        child: Text(t('เลือกแบบฟอร์มทางซ้าย หรือกด + เพื่อสร้างแบบฟอร์มใหม่', 'Select a form on the left, or press + to create one'),
            style: TextStyle(color: Colors.grey[600])),
      );

  Widget _buildFormList() {
    final forms = _forms.where((f) => _filterSource == null || f.dataSource == _filterSource).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Row(children: [
          Expanded(
            child: DropdownButtonFormField<String?>(
              value: _filterSource,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: t('แหล่งข้อมูล', 'Data source'),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: null, child: Text(t('ทั้งหมด', 'All'))),
                for (final s in _sources) DropdownMenuItem(value: s.key, child: Text(s.name(_isEnglish), overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _filterSource = v),
            ),
          ),
          IconButton(
            tooltip: t('สร้างแบบฟอร์มใหม่', 'New form'),
            icon: const Icon(Icons.add_circle, color: Colors.green),
            onPressed: _newForm,
          ),
        ]),
      ),
      Expanded(
        child: forms.isEmpty
            ? Center(child: Text(t('ยังไม่มีแบบฟอร์ม', 'No forms yet'), style: TextStyle(color: Colors.grey[700])))
            : ListView.builder(
                itemCount: forms.length,
                itemBuilder: (ctx, i) {
                  final f = forms[i];
                  final selected = _form?.id == f.id && f.id != null;
                  final src = _sources.where((s) => s.key == f.dataSource).map((s) => s.name(_isEnglish)).firstOrNull ?? f.dataSource;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    color: selected ? Colors.blueGrey[50] : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: BorderSide(color: selected ? Colors.blueGrey : Colors.transparent, width: 1.5),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Icon(f.isPreprinted ? Icons.receipt_long_outlined : Icons.print_outlined,
                          color: f.isActive ? Colors.blueGrey[700] : Colors.grey),
                      title: Row(children: [
                        Expanded(
                          child: Text('${f.code}  ${f.name(_isEnglish)}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, decoration: f.isActive ? null : TextDecoration.lineThrough)),
                        ),
                        if (f.isDefault) Icon(Icons.star, size: 16, color: Colors.amber[700]),
                      ]),
                      subtitle: Text(
                        '$src · ${f.isPreprinted ? t('Pre-printed', 'Pre-printed') : t('เลเซอร์', 'Laser')} · ${f.copyCount} ${t('สำเนา', 'copies')}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      onTap: () => _openForm(f),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) => v == 'dup' ? _duplicate(f) : _delete(f),
                        itemBuilder: (_) => [
                          PopupMenuItem(value: 'dup', child: Text(t('คัดลอก', 'Duplicate'))),
                          PopupMenuItem(value: 'del', child: Text(t('ลบ', 'Delete'), style: const TextStyle(color: Colors.red))),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  Widget _buildEditor() {
    final f = _form!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        color: _headerColor,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(children: [
          Expanded(
            child: Text(
              f.id == null ? t('แบบฟอร์มใหม่', 'New form') : '${f.code}  ${f.name(_isEnglish)}${_dirty ? ' *' : ''}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton.icon(
            onPressed: _preview,
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
            label: Text(t('ดูตัวอย่าง', 'Preview'), style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 4),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: Text(t('บันทึก', 'Save')),
          ),
          const SizedBox(width: 4),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
            onPressed: _cancel,
            child: Text(t('ยกเลิก', 'Cancel')),
          ),
        ]),
      ),
      Expanded(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: Column(children: [_buildToolbar(), Expanded(child: _buildCanvas())])),
          Container(width: 1, color: Colors.grey[400]),
          SizedBox(width: 360, child: _buildSidePanel()),
        ]),
      ),
    ]);
  }

  Widget _buildToolbar() {
    final f = _form!;
    final sel = _selected;
    Widget tool(IconData icon, String tip, VoidCallback? onTap) =>
        IconButton(icon: Icon(icon, size: 20), tooltip: tip, onPressed: onTap, visualDensity: VisualDensity.compact);
    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          Text(t('เพิ่ม:', 'Add:'), style: const TextStyle(fontSize: 12)),
          tool(Icons.data_object, t('ฟิลด์ข้อมูล', 'Data field'), () => _addElement('field')),
          tool(Icons.text_fields, t('ข้อความ', 'Text'), () => _addElement('text')),
          tool(Icons.horizontal_rule, t('เส้น', 'Line'), () => _addElement('line')),
          tool(Icons.crop_square, t('กรอบ', 'Box'), () => _addElement('rect')),
          tool(Icons.image_outlined, t('รูป/โลโก้', 'Image/logo'), () => _addElement('image')),
          tool(Icons.table_rows_outlined, t('ตารางรายการ', 'Line table'), () => _addElement('table')),
          const VerticalDivider(width: 12),
          tool(Icons.copy_all_outlined, t('ทำซ้ำชิ้นงาน', 'Duplicate element'), sel == null ? null : _duplicateSelected),
          tool(Icons.flip_to_front, t('เลื่อนขึ้นด้านหน้า', 'Bring forward'), sel == null ? null : () => _moveLayer(1)),
          tool(Icons.flip_to_back, t('เลื่อนไปด้านหลัง', 'Send backward'), sel == null ? null : () => _moveLayer(-1)),
          tool(Icons.delete_outline, t('ลบชิ้นงาน (Delete)', 'Delete element (Delete)'), sel == null ? null : _deleteSelected),
          const VerticalDivider(width: 12),
          tool(Icons.zoom_out, t('ย่อ', 'Zoom out'), _scale <= 1.5 ? null : () => setState(() => _scale -= 0.5)),
          Text('${(_scale / 3 * 100).round()}%', style: const TextStyle(fontSize: 12)),
          tool(Icons.zoom_in, t('ขยาย', 'Zoom in'), _scale >= 8 ? null : () => setState(() => _scale += 0.5)),
          tool(_showGrid ? Icons.grid_on : Icons.grid_off, t('เส้นตาราง', 'Grid'), () => setState(() => _showGrid = !_showGrid)),
          const VerticalDivider(width: 12),
          Text(t('พื้นหลัง:', 'Background:'), style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          DropdownButton<int>(
            value: _viewCopy.clamp(1, math.max(1, f.copies.length)),
            isDense: true,
            underline: const SizedBox(),
            items: [
              for (var i = 0; i < f.copies.length; i++)
                DropdownMenuItem(value: i + 1, child: Text('${i + 1}. ${f.copies[i].name(_isEnglish)}', style: const TextStyle(fontSize: 12))),
            ],
            onChanged: (v) => setState(() => _viewCopy = v ?? 1),
          ),
          SizedBox(
            width: 110,
            child: Slider(value: _bgOpacity, min: 0.1, max: 1, onChanged: (v) => setState(() => _bgOpacity = v)),
          ),
        ]),
      ),
    );
  }

  // ── ผืนผ้าใบ ──────────────────────────────────────────────────────────────
  Widget _buildCanvas() {
    final f = _form!;
    final s = _scale;
    final pw = f.paperWidth * s;
    final ph = f.paperHeight * s;
    final copy = (_viewCopy >= 1 && _viewCopy <= f.copies.length) ? f.copies[_viewCopy - 1] : null;
    final bg = _imageBytes(copy?.bgImage);
    return Focus(
      focusNode: _canvasFocus,
      onKeyEvent: _onCanvasKey,
      child: Container(
        color: Colors.grey[500],
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: GestureDetector(
                  onTap: () {
                    _canvasFocus.requestFocus();
                    setState(() => _selectedId = null);
                  },
                  child: Container(
                    width: pw,
                    height: ph,
                    decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black38)]),
                    child: Stack(clipBehavior: Clip.hardEdge, children: [
                      if (bg != null && copy != null)
                        Positioned(
                          left: copy.bgOffsetX * s,
                          top: copy.bgOffsetY * s,
                          width: pw * copy.bgScale,
                          height: ph * copy.bgScale,
                          child: Opacity(
                            opacity: _bgOpacity,
                            child: Transform.rotate(
                              angle: copy.bgRotate * math.pi / 180,
                              child: Image.memory(bg, fit: BoxFit.fill, gaplessPlayback: true),
                            ),
                          ),
                        ),
                      if (_showGrid) Positioned.fill(child: CustomPaint(painter: _GridPainter(s))),
                      for (final e in f.elements) _buildCanvasElement(e),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _fieldLabel(String? key, {bool line = false}) {
    final f = _source?.field(key, line: line);
    return f == null ? (key ?? '') : _source!.displayLabel(f, _isEnglish);
  }

  // เพิ่มชิ้นงานฟิลด์คู่ภาษา (ไทย <-> อังกฤษ) วางใต้ชิ้นงานเดิม — ผู้ใช้ลากไปวางตำแหน่งที่ต้องการเอง
  void _addPairElement(PrintElement e, String pairKey) {
    final c = e.copy(newId: _newId())
      ..field = pairKey
      ..y = e.y + math.max(e.h, 2);
    _changed(() {
      _form!.elements.add(c);
      _selectedId = c.id;
    }, true);
    _canvasFocus.requestFocus();
  }

  TextStyle _canvasText(double pt, bool bold, {Color? color}) => TextStyle(
        fontFamily: 'THSarabun',
        fontSize: math.max(pt * 0.3528 * _scale, 4),
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        height: 1.0,
        color: color ?? Colors.black,
      );

  TextAlign _ta(String a) => a == 'R' ? TextAlign.right : (a == 'C' ? TextAlign.center : TextAlign.left);

  Widget _buildCanvasElement(PrintElement e) {
    final s = _scale;
    final sel = e.id == _selectedId;
    final f = _form!;
    final hiddenOnView = !f.isPreprinted && !e.visibleOnCopy(_viewCopy);
    Widget body;
    switch (e.type) {
      case 'field':
        final label = '[${_fieldLabel(e.field)}]';
        body = Text('${e.prefix}$label${e.suffix}',
            textAlign: _ta(e.align),
            maxLines: e.maxLines <= 0 ? null : e.maxLines,
            overflow: TextOverflow.clip,
            style: _canvasText(e.fontSize, e.bold, color: Colors.blue[900]));
        break;
      case 'text':
        body = Text(e.text,
            textAlign: _ta(e.align),
            maxLines: e.maxLines <= 0 ? null : e.maxLines,
            overflow: TextOverflow.clip,
            style: _canvasText(e.fontSize, e.bold));
        break;
      case 'line':
        body = CustomPaint(painter: _LinePainter(e.w <= 0, e.h <= 0, math.max(e.strokeWidth * 0.3528 * s, 1)));
        break;
      case 'rect':
        body = Container(
          decoration: BoxDecoration(
            color: e.fillColor.isEmpty ? null : _hexColor(e.fillColor).withOpacity(e.fillOpacity.clamp(0.0, 1.0)),
            // ไม่มีเส้นขอบ: แสดงเส้นประจางๆ ในหน้าจอออกแบบให้ยังเห็นขอบเขต (ไม่พิมพ์)
            border: e.strokeWidth > 0
                ? Border.all(width: math.max(e.strokeWidth * 0.3528 * s, 1))
                : Border.all(color: Colors.blueGrey.withOpacity(0.35), width: 0.5),
          ),
        );
        break;
      case 'image':
        final bytes = e.field == null ? _imageBytes(e.imageData) : null;
        body = bytes != null
            ? Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true)
            : Container(
                color: Colors.blueGrey.withOpacity(0.12),
                alignment: Alignment.center,
                child: Text(e.field == 'company_logo' ? t('โลโก้', 'Logo') : t('รูป', 'Image'), style: _canvasText(12, false)),
              );
        break;
      default:
        body = _canvasTable(e);
    }
    final w = math.max(e.w * s, e.type == 'line' ? 2.0 : 4.0);
    final h = math.max(e.h * s, e.type == 'line' ? 2.0 : 4.0);
    return Positioned(
      left: e.x * s - (e.type == 'line' && e.w <= 0 ? 1 : 0),
      top: e.y * s - (e.type == 'line' && e.h <= 0 ? 1 : 0),
      width: w + 8,
      height: h + 8,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          left: 0,
          top: 0,
          width: w,
          height: h,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) {
              _canvasFocus.requestFocus();
              if (_selectedId != e.id) setState(() => _selectedId = e.id);
            },
            onPanStart: (_) {
              _canvasFocus.requestFocus();
              setState(() => _selectedId = e.id);
            },
            onPanUpdate: (d) => _changed(() {
              e.x = math.max(0, e.x + d.delta.dx / s);
              e.y = math.max(0, e.y + d.delta.dy / s);
            }),
            onPanEnd: (_) => _changed(() {
              e.x = _r(e.x);
              e.y = _r(e.y);
            }, true),
            child: Opacity(
              opacity: hiddenOnView ? 0.25 : 1,
              child: Container(
                decoration: BoxDecoration(
                  border: sel
                      ? Border.all(color: Colors.orange, width: 1.5)
                      : (e.type == 'field' || e.type == 'text' || e.type == 'image'
                          ? Border.all(color: Colors.blue.withOpacity(0.25), width: 0.5)
                          : null),
                ),
                child: ClipRect(child: Align(alignment: _alignOf(e), child: body)),
              ),
            ),
          ),
        ),
        if (sel)
          Positioned(
            left: w - 5,
            top: h - 5,
            width: 10,
            height: 10,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeDownRight,
              child: GestureDetector(
                onPanUpdate: (d) => _changed(() {
                  final minW = e.type == 'line' ? 0.0 : 2.0;
                  e.w = math.max(minW, e.w + d.delta.dx / s);
                  e.h = math.max(e.type == 'line' ? 0.0 : 2.0, e.h + d.delta.dy / s);
                }),
                onPanEnd: (_) => _changed(() {
                  e.w = _r(e.w);
                  e.h = _r(e.h);
                }, true),
                child: Container(decoration: BoxDecoration(color: Colors.orange, border: Border.all(color: Colors.white))),
              ),
            ),
          ),
      ]),
    );
  }

  Alignment _alignOf(PrintElement e) {
    if (e.type != 'field' && e.type != 'text') return Alignment.topLeft;
    return e.align == 'R' ? Alignment.topRight : (e.align == 'C' ? Alignment.topCenter : Alignment.topLeft);
  }

  Widget _canvasTable(PrintElement e) {
    final s = _scale;
    final rows = e.rowsPerPage;
    final style = _canvasText(e.fontSize, e.bold, color: Colors.blue[900]);
    final headStyle = _canvasText(e.fontSize, true);
    Widget cell(String text, PrintColumn c, double h, TextStyle st) => Container(
          width: c.w * s,
          height: h,
          padding: EdgeInsets.symmetric(horizontal: s),
          alignment: c.align == 'R' ? Alignment.centerRight : (c.align == 'C' ? Alignment.center : Alignment.centerLeft),
          child: Text(text, maxLines: 1, overflow: TextOverflow.clip, softWrap: false, style: st),
        );
    return Stack(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (e.showHeader) Row(children: [for (final c in e.columns) cell(c.title, c, e.headerHeight * s, headStyle)]),
        Row(children: [for (final c in e.columns) cell('[${_fieldLabel(c.field, line: true)}]', c, e.rowHeight * s, style)]),
      ]),
      Positioned.fill(child: CustomPaint(painter: _TablePainter(e, s, rows))),
    ]);
  }

  // ── แผงด้านขวา ────────────────────────────────────────────────────────────
  Widget _buildSidePanel() {
    return DefaultTabController(
      length: 3,
      child: Column(children: [
        Material(
          color: Colors.blueGrey[50],
          child: TabBar(
            labelColor: Colors.blueGrey[800],
            indicatorColor: Colors.blueGrey[700],
            tabs: [
              Tab(text: t('ชิ้นงาน', 'Element')),
              Tab(text: t('ฟอร์ม', 'Form')),
              Tab(text: t('สำเนา', 'Copies')),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(children: [
            _buildElementTab(),
            _buildFormTab(),
            _buildCopiesTab(),
          ]),
        ),
      ]),
    );
  }

  InputDecoration _dec(String label, {String? suffix, String? helper}) => InputDecoration(
        labelText: label,
        suffixText: suffix,
        helperText: helper,
        helperMaxLines: 3,
        isDense: true,
        border: const OutlineInputBorder(),
      );

  String _fmtNum(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');

  Widget _num(String keyName, String label, double value, ValueChanged<double> onChanged, {String suffix = 'มม.', double? min}) {
    return TextFormField(
      key: ValueKey('${_selectedId ?? 'form'}-$keyName-$_propsRev'),
      initialValue: _fmtNum(value),
      decoration: _dec(label, suffix: _isEnglish && suffix == 'มม.' ? 'mm' : suffix),
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      onChanged: (v) {
        final n = double.tryParse(v.trim());
        if (n == null) return;
        if (min != null && n < min) return;
        _changed(() => onChanged(n));
      },
    );
  }

  Widget _txt(String keyName, String label, String value, ValueChanged<String> onChanged, {int maxLines = 1, String? helper}) {
    return TextFormField(
      key: ValueKey('${_selectedId ?? 'form'}-$keyName-$_propsRev'),
      initialValue: value,
      maxLines: maxLines,
      decoration: _dec(label, helper: helper),
      onChanged: (v) => _changed(() => onChanged(v)),
    );
  }

  Widget _gap([double h = 10]) => SizedBox(height: h, width: h);

  Widget _row(List<Widget> children) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (var i = 0; i < children.length; i++) ...[if (i > 0) _gap(8), Expanded(child: children[i])]],
      );

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
      );

  // แท็บชิ้นงาน
  Widget _buildElementTab() {
    final f = _form!;
    final e = _selected;
    return ListView(padding: const EdgeInsets.all(12), children: [
      if (e == null)
        Text(
          t('คลิกชิ้นงานบนผืนผ้าใบหรือในรายการด้านล่างเพื่อแก้คุณสมบัติ\nลากเพื่อย้าย, ลากมุมขวาล่างเพื่อปรับขนาด, ปุ่มลูกศรขยับทีละ 0.5 มม. (Shift = 5 มม.)',
              'Click an element on the canvas or in the list below to edit it.\nDrag to move, drag the bottom-right corner to resize, arrow keys nudge 0.5 mm (Shift = 5 mm).'),
          style: TextStyle(color: Colors.grey[700], fontSize: 13),
        )
      else
        ..._elementProps(f, e),
      _section(t('รายการชิ้นงาน (${f.elements.length})', 'Elements (${f.elements.length})')),
      for (final x in f.elements.reversed)
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          selected: x.id == _selectedId,
          selectedTileColor: Colors.orange.withOpacity(0.12),
          leading: Icon(_typeIcon(x.type), size: 18),
          title: Text(_elementTitle(x), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          subtitle: Text('X ${_fmtNum(x.x)}  Y ${_fmtNum(x.y)}', style: const TextStyle(fontSize: 11)),
          onTap: () => setState(() {
            _selectedId = x.id;
            _propsRev++;
          }),
        ),
    ]);
  }

  IconData _typeIcon(String type) => switch (type) {
        'field' => Icons.data_object,
        'text' => Icons.text_fields,
        'line' => Icons.horizontal_rule,
        'rect' => Icons.crop_square,
        'image' => Icons.image_outlined,
        _ => Icons.table_rows_outlined,
      };

  String _elementTitle(PrintElement e) => switch (e.type) {
        'field' => _fieldLabel(e.field),
        'text' => e.text.replaceAll('\n', ' '),
        'line' => t('เส้น', 'Line'),
        'rect' => t('กรอบ', 'Box'),
        'image' => e.field == 'company_logo' ? t('โลโก้บริษัท', 'Company logo') : t('รูป', 'Image'),
        _ => t('ตารางรายการ (${e.columns.length} คอลัมน์)', 'Line table (${e.columns.length} columns)'),
      };

  List<Widget> _elementProps(PrintForm f, PrintElement e) {
    final src = _source!;
    final isText = e.type == 'field' || e.type == 'text';
    final fieldType = e.type == 'field' ? (src.field(e.field)?.type ?? 'text') : 'text';
    return [
      Row(children: [
        Icon(_typeIcon(e.type), size: 20, color: Colors.blueGrey[700]),
        _gap(6),
        Expanded(child: Text(_elementTitle(e), style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
      ]),
      _gap(),
      _row([
        _num('x', 'X', e.x, (v) => e.x = v, min: 0),
        _num('y', 'Y', e.y, (v) => e.y = v, min: 0),
      ]),
      _gap(),
      _row([
        _num('w', t('กว้าง', 'Width'), e.w, (v) => e.w = v, min: 0),
        _num('h', t('สูง', 'Height'), e.h, (v) => e.h = v, min: 0),
      ]),
      if (e.type == 'field') ...[
        _gap(),
        InkWell(
          onTap: () async {
            final k = await _pickField(src.headerFields.where((x) => x.type != 'image').toList(), current: e.field);
            if (k != null) _changed(() => e.field = k, true);
          },
          child: InputDecorator(
            decoration: _dec(t('ฟิลด์', 'Field')),
            child: Row(children: [Expanded(child: Text(_fieldLabel(e.field))), const Icon(Icons.arrow_drop_down)]),
          ),
        ),
        if (src.field(e.field) != null && src.pairOf(src.field(e.field)!) != null)
          Builder(builder: (_) {
            final pair = src.pairOf(src.field(e.field)!)!;
            final label = src.displayLabel(pair, _isEnglish);
            return Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.translate, size: 16),
                label: Text(t('เพิ่มชิ้นงาน [$label]', 'Add element [$label]')),
                onPressed: () => _addPairElement(e, pair.key),
              ),
            );
          }),
        _gap(),

        _row([
          _txt('prefix', t('ข้อความนำหน้า', 'Prefix'), e.prefix, (v) => e.prefix = v),
          _txt('suffix', t('ข้อความต่อท้าย', 'Suffix'), e.suffix, (v) => e.suffix = v),
        ]),
        if (fieldType == 'date' || fieldType == 'money' || fieldType == 'qty' || fieldType == 'number') ...[
          _gap(),
          _fmtDropdown(fieldType, e.fmt, (v) => e.fmt = v),
          if (fieldType != 'date')
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(t('ไม่พิมพ์เมื่อเป็นศูนย์', 'Blank when zero')),
              value: e.blankZero,
              onChanged: (v) => _changed(() => e.blankZero = v == true),
            ),
        ],
      ],
      if (e.type == 'text') ...[
        _gap(),
        _txt('text', t('ข้อความ', 'Text'), e.text, (v) => e.text = v,
            maxLines: 3, helper: t('แทรกค่าฟิลด์ด้วย {ชื่อฟิลด์} เช่น {doc_no}', 'Insert a field value with {key}, e.g. {doc_no}')),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: Text(t('แทรกฟิลด์', 'Insert field')),
            onPressed: () async {
              final k = await _pickField(src.headerFields.where((x) => x.type != 'image').toList());
              if (k != null) _changed(() => e.text = '${e.text}{$k}', true);
            },
          ),
        ),
      ],
      if (isText) ...[
        ..._glyphWarning([e.text, e.prefix, e.suffix].join()),
        _gap(),
        _row([
          _num('fs', t('ขนาดตัวอักษร', 'Font size'), e.fontSize, (v) => e.fontSize = v, suffix: 'pt', min: 4),
          _num('ml', t('จำนวนบรรทัด (0 = ไม่จำกัด)', 'Max lines (0 = auto)'), e.maxLines.toDouble(), (v) => e.maxLines = v.round(),
              suffix: '', min: 0),
        ]),
        _gap(6),
        Row(children: [
          FilterChip(
            label: Text(t('ตัวหนา', 'Bold')),
            selected: e.bold,
            onSelected: (v) => _changed(() => e.bold = v),
          ),
          const Spacer(),
          _alignToggle(e.align, (v) => e.align = v),
        ]),
      ],
      if (e.type == 'line' || e.type == 'rect') ...[
        _gap(),
        _num('sw', e.type == 'rect' ? t('ความหนาเส้นขอบ (0 = ไม่มีเส้น)', 'Border width (0 = none)') : t('ความหนาเส้น', 'Stroke width'),
            e.strokeWidth, (v) => e.strokeWidth = v, suffix: 'pt', min: e.type == 'rect' ? 0 : 0.1),
        if (e.type == 'rect') ..._fillProps(e),
        if (e.type == 'line')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(t('เส้นนอน: สูง = 0, เส้นตั้ง: กว้าง = 0', 'Horizontal: height = 0, vertical: width = 0'),
                style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ),
      ],
      if (e.type == 'image') ...[
        _gap(),
        RadioListTile<bool>(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(t('โลโก้บริษัท (จากข้อมูลบริษัท)', 'Company logo (from company profile)')),
          value: true,
          groupValue: e.field == 'company_logo',
          onChanged: (_) => _changed(() => e.field = 'company_logo'),
        ),
        RadioListTile<bool>(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(t('รูปที่อัปโหลด (เช่น ลายเซ็น ตราประทับ)', 'Uploaded image (e.g. signature, stamp)')),
          value: false,
          groupValue: e.field == 'company_logo',
          onChanged: (_) => _changed(() => e.field = null),
        ),
        if (e.field == null)
          OutlinedButton.icon(
            icon: const Icon(Icons.upload_file),
            label: Text(e.imageData == null ? t('อัปโหลดรูป', 'Upload image') : t('เปลี่ยนรูป', 'Change image')),
            onPressed: () async {
              final d = await _pickImage(maxWidth: 800, keepSmallPng: true);
              if (d != null) _changed(() => e.imageData = d);
            },
          ),
      ],
      if (e.type == 'table') ..._tableProps(src, e),
      _gap(),
      DropdownButtonFormField<String>(
        value: e.pages,
        decoration: _dec(t('พิมพ์ที่หน้า', 'Print on pages')),
        items: [
          DropdownMenuItem(value: 'all', child: Text(t('ทุกหน้า', 'Every page'))),
          DropdownMenuItem(value: 'first', child: Text(t('เฉพาะหน้าแรก', 'First page only'))),
          DropdownMenuItem(value: 'last', child: Text(t('เฉพาะหน้าสุดท้าย (เช่น ยอดรวม)', 'Last page only (e.g. totals)'))),
        ],
        onChanged: (v) => _changed(() => e.pages = v ?? 'all'),
      ),
      if (!f.isPreprinted && f.copies.length > 1) ...[
        _section(t('แสดงในสำเนา', 'Show on copies')),
        Wrap(spacing: 6, runSpacing: 4, children: [
          for (var i = 1; i <= f.copies.length; i++)
            FilterChip(
              label: Text('$i. ${f.copies[i - 1].name(_isEnglish)}'),
              selected: e.visibleOnCopy(i),
              onSelected: (v) => _changed(() {
                final all = [for (var j = 1; j <= f.copies.length; j++) j];
                final cur = e.copies.isEmpty ? all : [...e.copies];
                v ? cur.add(i) : cur.remove(i);
                final set = cur.toSet().toList()..sort();
                e.copies = set.length == all.length ? [] : set;
              }),
            ),
        ]),
        if (e.copies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(t('ซ่อนในสำเนาที่ไม่ได้เลือก (เห็นจางบนผืนผ้าใบ)', 'Hidden on unselected copies (shown faded on the canvas)'),
                style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ),
      ],
    ];
  }

  List<Widget> _glyphWarning(String text) {
    final bad = unsupportedGlyphs(text);
    if (bad.isEmpty) return [];
    return [
      _gap(6),
      Container(
        padding: const EdgeInsets.all(8),
        color: Colors.orange[50],
        child: Text(
          t('ฟอนต์ THSarabun ไม่มีอักขระ ${bad.join(' ')} — จะพิมพ์ออกมาเป็นกล่อง กรุณาใช้ตัวอักษรไทย/อังกฤษ/ตัวเลขหรือ - * > แทน',
              'THSarabun has no glyph for ${bad.join(' ')} — it prints as a box. Use Thai/English letters, digits or - * > instead.'),
          style: TextStyle(fontSize: 12, color: Colors.orange[900]),
        ),
      ),
    ];
  }

  Color _hexColor(String hex) => Color(0xFF000000 | (int.tryParse(hex, radix: 16) ?? 0));

  // กรอบ: เลือกสีพื้น + ความโปร่งใส
  List<Widget> _fillProps(PrintElement e) {
    Widget swatch(String hex, String label) {
      final selected = e.fillColor == hex;
      return Tooltip(
        message: label,
        child: InkWell(
          onTap: () => _changed(() => e.fillColor = hex, true),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: hex.isEmpty ? Colors.white : _hexColor(hex),
              border: Border.all(color: selected ? Colors.orange : Colors.grey, width: selected ? 3 : 1),
            ),
            child: hex.isEmpty ? const Icon(Icons.block, size: 16, color: Colors.grey) : null,
          ),
        ),
      );
    }

    return [
      _gap(),
      Text(t('สีพื้น', 'Fill color'), style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      _gap(4),
      Wrap(spacing: 6, runSpacing: 6, children: [
        swatch('', t('ไม่เติมสี', 'No fill')),
        for (final c in printFillColors.entries) swatch(c.key, c.value[_isEnglish ? 1 : 0]),
      ]),
      if (e.fillColor.isNotEmpty) ...[
        _gap(6),
        Row(children: [
          Text(t('ความโปร่งใส', 'Transparency'), style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          Expanded(
            child: Slider(
              value: (1 - e.fillOpacity).clamp(0.0, 0.95),
              max: 0.95,
              divisions: 19,
              label: '${((1 - e.fillOpacity) * 100).round()}%',
              onChanged: (v) => _changed(() => e.fillOpacity = 1 - v),
              onChangeEnd: (v) => _changed(() => e.fillOpacity = double.parse((1 - v).toStringAsFixed(2)), true),
            ),
          ),
          SizedBox(width: 40, child: Text('${((1 - e.fillOpacity) * 100).round()}%', textAlign: TextAlign.right)),
        ]),
      ],
    ];
  }

  Widget _fmtDropdown(String type, String value, ValueChanged<String> onChanged) {
    final opts = type == 'date' ? printDateFormats : printNumberFormats;
    return DropdownButtonFormField<String>(
      value: opts.containsKey(value) ? value : '',
      isExpanded: true,
      decoration: _dec(t('รูปแบบ', 'Format')),
      items: [for (final o in opts.entries) DropdownMenuItem(value: o.key, child: Text(o.value[_isEnglish ? 1 : 0]))],
      onChanged: (v) => _changed(() => onChanged(v ?? '')),
    );
  }

  Widget _alignToggle(String value, ValueChanged<String> onChanged) => SegmentedButton<String>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: const [
          ButtonSegment(value: 'L', icon: Icon(Icons.format_align_left, size: 18)),
          ButtonSegment(value: 'C', icon: Icon(Icons.format_align_center, size: 18)),
          ButtonSegment(value: 'R', icon: Icon(Icons.format_align_right, size: 18)),
        ],
        selected: {value},
        onSelectionChanged: (v) => _changed(() => onChanged(v.first)),
      );

  List<Widget> _tableProps(PrintDataSource src, PrintElement e) {
    final total = e.columns.fold<double>(0, (a, c) => a + c.w);
    return [
      _gap(),
      _row([
        _num('fs', t('ขนาดตัวอักษร', 'Font size'), e.fontSize, (v) => e.fontSize = v, suffix: 'pt', min: 4),
        _num('sw', t('ความหนาเส้น', 'Stroke'), e.strokeWidth, (v) => e.strokeWidth = v, suffix: 'pt', min: 0.1),
      ]),
      _gap(),
      _row([
        _num('rh', t('ความสูงแถว', 'Row height'), e.rowHeight, (v) => e.rowHeight = v, min: 1),
        _num('hh', t('ความสูงหัวตาราง', 'Header height'), e.headerHeight, (v) => e.headerHeight = v, min: 1),
      ]),
      _gap(6),
      Row(children: [
        FilterChip(label: Text(t('แสดงหัวตาราง', 'Show header')), selected: e.showHeader, onSelected: (v) => _changed(() => e.showHeader = v)),
        _gap(6),
        FilterChip(label: Text(t('ตัวหนา', 'Bold')), selected: e.bold, onSelected: (v) => _changed(() => e.bold = v)),
      ]),
      _gap(),
      DropdownButtonFormField<String>(
        value: e.border,
        decoration: _dec(t('เส้นตาราง', 'Borders')),
        items: [
          DropdownMenuItem(value: 'box', child: Text(t('กรอบนอก + เส้นแบ่งคอลัมน์', 'Outer box + column lines'))),
          DropdownMenuItem(value: 'grid', child: Text(t('ตารางเต็ม (ทุกแถว)', 'Full grid'))),
          DropdownMenuItem(value: 'rows', child: Text(t('เส้นแบ่งแถว', 'Row lines'))),
          DropdownMenuItem(value: 'none', child: Text(t('ไม่มีเส้น (ฟอร์มสำเร็จรูป)', 'None (pre-printed form)'))),
        ],
        onChanged: (v) => _changed(() => e.border = v ?? 'box'),
      ),
      _gap(6),
      Text(
        t('${e.rowsPerPage} รายการต่อหน้า — เกินนี้ขึ้นหน้าใหม่', '${e.rowsPerPage} lines per page — more lines continue on a new page'),
        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
      ),
      _section(t('คอลัมน์ (รวม ${_fmtNum(total)} มม.)', 'Columns (total ${_fmtNum(total)} mm)')),
      for (var i = 0; i < e.columns.length; i++) _columnCard(src, e, i),
      Row(children: [
        TextButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: Text(t('เพิ่มคอลัมน์', 'Add column')),
          onPressed: () async {
            final k = await _pickField(src.lineFields);
            if (k == null) return;
            _changed(() => e.columns.add(PrintColumn(field: k, title: _fieldLabel(k, line: true), w: 20)), true);
          },
        ),
        const Spacer(),
        if (total > 0 && (total - e.w).abs() > 0.05)
          TextButton(
            onPressed: () => _changed(() {
              final k = e.w / total;
              for (final c in e.columns) {
                c.w = _r(c.w * k);
              }
            }, true),
            child: Text(t('ปรับให้พอดีความกว้าง', 'Fit to width')),
          ),
      ]),
    ];
  }

  Widget _columnCard(PrintDataSource src, PrintElement e, int i) {
    final c = e.columns[i];
    final type = src.field(c.field, line: true)?.type ?? 'text';
    final key = 'col$i';
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 4, 8),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final k = await _pickField(src.lineFields, current: c.field);
                  if (k != null) _changed(() => c.field = k, true);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text('${i + 1}. ${_fieldLabel(c.field, line: true)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            if (src.field(c.field, line: true) != null && src.pairOf(src.field(c.field, line: true)!) != null)
              IconButton(
                icon: const Icon(Icons.translate, size: 16),
                visualDensity: VisualDensity.compact,
                tooltip: t('เพิ่มคอลัมน์ [${_fieldLabel(src.pairOf(src.field(c.field, line: true)!)!.key, line: true)}]',
                    'Add column [${_fieldLabel(src.pairOf(src.field(c.field, line: true)!)!.key, line: true)}]'),
                onPressed: () => _changed(
                    () => e.columns.insert(i + 1, c.copy()..field = src.pairOf(src.field(c.field, line: true)!)!.key), true),
              ),
            IconButton(
              icon: const Icon(Icons.arrow_upward, size: 16),
              visualDensity: VisualDensity.compact,
              onPressed: i == 0 ? null : () => _changed(() => e.columns.insert(i - 1, e.columns.removeAt(i)), true),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_downward, size: 16),
              visualDensity: VisualDensity.compact,
              onPressed: i == e.columns.length - 1 ? null : () => _changed(() => e.columns.insert(i + 1, e.columns.removeAt(i)), true),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: Colors.red),
              visualDensity: VisualDensity.compact,
              onPressed: () => _changed(() => e.columns.removeAt(i), true),
            ),
          ]),
          _row([
            _txt('$key-title', t('หัวคอลัมน์', 'Title'), c.title, (v) => c.title = v),
            _num('$key-w', t('กว้าง', 'Width'), c.w, (v) => c.w = v, min: 1),
          ]),
          _gap(6),
          Row(children: [
            _alignToggle(c.align, (v) => c.align = v),
            _gap(8),
            if (type == 'money' || type == 'qty' || type == 'number')
              Expanded(child: _fmtDropdown(type, c.fmt, (v) => c.fmt = v)),
          ]),
          if (type == 'money' || type == 'qty' || type == 'number')
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(t('ไม่พิมพ์เมื่อเป็นศูนย์', 'Blank when zero')),
              value: c.blankZero,
              onChanged: (v) => _changed(() => c.blankZero = v == true),
            ),
        ]),
      ),
    );
  }

  // แท็บฟอร์ม
  Widget _buildFormTab() {
    final f = _form!;
    final landscape = f.paperWidth > f.paperHeight;
    return ListView(padding: const EdgeInsets.all(12), children: [
      _txt('code', t('รหัสแบบฟอร์ม *', 'Form code *'), f.code, (v) => f.code = v.trim()),
      _gap(),
      _txt('nameTh', t('ชื่อแบบฟอร์ม (ไทย) *', 'Form name (Thai) *'), f.nameTh, (v) => f.nameTh = v),
      _gap(),
      _txt('nameEn', t('ชื่อแบบฟอร์ม (อังกฤษ)', 'Form name (English)'), f.nameEn, (v) => f.nameEn = v),
      _gap(),
      DropdownButtonFormField<String>(
        value: _sources.any((s) => s.key == f.dataSource) ? f.dataSource : null,
        isExpanded: true,
        decoration: _dec(t('แหล่งข้อมูล', 'Data source')),
        items: [for (final s in _sources) DropdownMenuItem(value: s.key, child: Text(s.name(_isEnglish)))],
        onChanged: (v) => _changed(() => f.dataSource = v ?? f.dataSource),
      ),
      _section(t('รูปแบบการพิมพ์', 'Print mode')),
      RadioListTile<String>(
        dense: true,
        contentPadding: EdgeInsets.zero,
        value: 'LASER',
        groupValue: f.printMode,
        title: Text(t('เลเซอร์: พิมพ์ฟอร์ม + ข้อมูล', 'Laser: print form + data')),
        subtitle: Text(t('1 เอกสาร = จำนวนแผ่นเท่าจำนวนสำเนา แต่ละสำเนาใช้รูปพื้นหลังของตัวเอง',
            '1 document = one sheet per copy, each copy with its own background')),
        onChanged: (v) => _changed(() => f.printMode = v!),
      ),
      RadioListTile<String>(
        dense: true,
        contentPadding: EdgeInsets.zero,
        value: 'PREPRINTED',
        groupValue: f.printMode,
        title: Text(t('Pre-printed (dot-matrix): พิมพ์ข้อมูลอย่างเดียว', 'Pre-printed (dot-matrix): data only')),
        subtitle: Text(t('พิมพ์ชุดเดียวลงกระดาษก๊อปปี้ — รูปพื้นหลังใช้จัดตำแหน่งเท่านั้น ไม่พิมพ์ออก',
            'Prints once on multi-part paper — the background is only an alignment guide')),
        onChanged: (v) => _changed(() => f.printMode = v!),
      ),
      _section(t('กระดาษ', 'Paper')),
      DropdownButtonFormField<String>(
        value: _paperLabels.containsKey(f.paperSize) ? f.paperSize : 'CUSTOM',
        isExpanded: true,
        decoration: _dec(t('ขนาดกระดาษ', 'Paper size')),
        items: [for (final p in _paperLabels.entries) DropdownMenuItem(value: p.key, child: Text(p.value[_isEnglish ? 1 : 0]))],
        onChanged: (v) => _changed(() {
          f.paperSize = v ?? 'CUSTOM';
          final p = _paperPresets[f.paperSize];
          if (p != null) {
            f.paperWidth = landscape ? p[1] : p[0];
            f.paperHeight = landscape ? p[0] : p[1];
          }
        }, true),
      ),
      _gap(6),
      Row(children: [
        Text(t('แนว:', 'Orientation:')),
        _gap(8),
        ChoiceChip(
          label: Text(t('ตั้ง', 'Portrait')),
          selected: !landscape,
          onSelected: (_) {
            if (landscape) _swapOrientation();
          },
        ),
        _gap(6),
        ChoiceChip(
          label: Text(t('นอน', 'Landscape')),
          selected: landscape,
          onSelected: (_) {
            if (!landscape) _swapOrientation();
          },
        ),
      ]),
      _gap(),
      _row([
        _num('pw', t('กว้าง', 'Width'), f.paperWidth, (v) {
          f.paperWidth = v;
          f.paperSize = 'CUSTOM';
        }, min: 20),
        _num('ph', t('สูง', 'Height'), f.paperHeight, (v) {
          f.paperHeight = v;
          f.paperSize = 'CUSTOM';
        }, min: 20),
      ]),
      _section(t('ค่าชดเชยตำแหน่งทั้งหน้า', 'Whole-page offset')),
      Text(
        t('ใช้เมื่อพิมพ์ออกมาเหลื่อมจากฟอร์มจริงทั้งแผ่น (เช่น เครื่อง dot-matrix ป้อนกระดาษเหลื่อม) — ค่าบวก = เลื่อนไปทางขวา/ลง',
            'Use when the whole printout is shifted from the real form (e.g. dot-matrix feed) — positive = right/down'),
        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
      ),
      _gap(6),
      _row([
        _num('ox', 'X', f.offsetX, (v) => f.offsetX = v),
        _num('oy', 'Y', f.offsetY, (v) => f.offsetY = v),
      ]),
      _gap(),
      SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(t('ฟอร์มเริ่มต้นของแหล่งข้อมูลนี้', 'Default form for this data source')),
        value: f.isDefault,
        onChanged: (v) => _changed(() => f.isDefault = v),
      ),
      SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(t('ใช้งาน', 'Active')),
        value: f.isActive,
        onChanged: (v) => _changed(() => f.isActive = v),
      ),
      _gap(6),
      _txt('remark', t('หมายเหตุ', 'Remark'), f.remark, (v) => f.remark = v, maxLines: 2),
    ]);
  }

  void _swapOrientation() {
    final f = _form!;
    _changed(() {
      final w = f.paperWidth;
      f.paperWidth = f.paperHeight;
      f.paperHeight = w;
    }, true);
  }

  // แท็บสำเนา
  Widget _buildCopiesTab() {
    final f = _form!;
    return ListView(padding: const EdgeInsets.all(12), children: [
      Container(
        padding: const EdgeInsets.all(8),
        color: Colors.blueGrey[50],
        child: Text(
          f.isPreprinted
              ? t('Pre-printed: พิมพ์ 1 ชุดต่อเอกสาร (กระดาษก๊อปปี้ทำสำเนาเอง) ใส่รูปถ่าย/สแกนฟอร์มไว้ที่สำเนาที่ 1 เพื่อใช้จัดตำแหน่ง — ไม่พิมพ์รูปออก',
                  'Pre-printed: one print per document (carbon copies). Put a scan of the form on copy 1 as an alignment guide — it is never printed.')
              : t('เลเซอร์: 1 เอกสารพิมพ์ ${f.copies.length} แผ่นตามลำดับด้านล่าง แต่ละแผ่นใช้รูปพื้นหลังของสำเนานั้น ปรับรูปให้เส้นในรูปตรงกับตาราง มม. ก่อนวางชิ้นงาน (แนะนำรูปสแกนเต็มหน้า)',
                  'Laser: each document prints ${f.copies.length} sheets in the order below, each with its own background. Align the image with the mm grid before placing elements (a full-page scan is recommended).'),
          style: const TextStyle(fontSize: 12),
        ),
      ),
      _gap(),
      for (var i = 0; i < f.copies.length; i++) _copyCard(f, i),
      if (f.copies.length < 10)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text(t('เพิ่มสำเนา', 'Add copy')),
            onPressed: () => _changed(() => f.copies.add(PrintFormCopy(nameTh: 'สำเนา', nameEn: 'Copy')), true),
          ),
        ),
    ]);
  }

  Widget _copyCard(PrintForm f, int i) {
    final c = f.copies[i];
    final bytes = _imageBytes(c.bgImage);
    final key = 'copy$i';
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: _viewCopy == i + 1 ? Colors.orange : Colors.transparent, width: 1.5),
      ),
      child: InkWell(
        onTap: () => setState(() => _viewCopy = i + 1),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Text('${t('สำเนาที่', 'Copy')} ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.arrow_upward, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: i == 0 ? null : () => _moveCopy(i, -1),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: i == f.copies.length - 1 ? null : () => _moveCopy(i, 1),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: Colors.red),
                visualDensity: VisualDensity.compact,
                onPressed: f.copies.length <= 1 ? null : () => _removeCopy(i),
              ),
            ]),
            _row([
              _txt('$key-th', t('ชื่อ (ไทย) *', 'Name (Thai) *'), c.nameTh, (v) => c.nameTh = v),
              _txt('$key-en', t('ชื่อ (อังกฤษ)', 'Name (English)'), c.nameEn, (v) => c.nameEn = v),
            ]),
            _gap(8),
            Row(children: [
              Container(
                width: 60,
                height: 80,
                decoration: BoxDecoration(border: Border.all(color: Colors.grey), color: Colors.grey[100]),
                child: bytes == null ? const Icon(Icons.image_not_supported_outlined, color: Colors.grey) : Image.memory(bytes, fit: BoxFit.fill),
              ),
              _gap(8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: Text(bytes == null ? t('อัปโหลดรูปพื้นหลัง', 'Upload background') : t('เปลี่ยนรูป', 'Change image')),
                    onPressed: () async {
                      final d = await _pickImage();
                      if (d != null) {
                        _changed(() {
                          c.bgImage = d;
                          _viewCopy = i + 1;
                        });
                      }
                    },
                  ),
                  if (bytes != null)
                    TextButton(
                      onPressed: () => _changed(() => c.bgImage = null),
                      child: Text(t('ลบรูป', 'Remove image'), style: const TextStyle(color: Colors.red)),
                    ),
                ]),
              ),
            ]),
            if (bytes != null) ...[
              _gap(8),
              _row([
                _num('$key-ox', t('ขยับ X', 'Shift X'), c.bgOffsetX, (v) => c.bgOffsetX = v),
                _num('$key-oy', t('ขยับ Y', 'Shift Y'), c.bgOffsetY, (v) => c.bgOffsetY = v),
              ]),
              _gap(8),
              _row([
                _num('$key-sc', t('สเกล', 'Scale'), c.bgScale, (v) => c.bgScale = v, suffix: 'x', min: 0.1),
                _num('$key-rt', t('หมุน', 'Rotate'), c.bgRotate, (v) => c.bgRotate = v, suffix: t('องศา', 'deg')),
              ]),
              if (i > 0 && f.copies[0].bgImage != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _changed(() {
                      final a = f.copies[0];
                      c
                        ..bgOffsetX = a.bgOffsetX
                        ..bgOffsetY = a.bgOffsetY
                        ..bgScale = a.bgScale
                        ..bgRotate = a.bgRotate;
                    }, true),
                    child: Text(t('ใช้ค่าปรับรูปเดียวกับสำเนาที่ 1', 'Use the same adjustment as copy 1')),
                  ),
                ),
            ],
          ]),
        ),
      ),
    );
  }

  void _moveCopy(int i, int dir) {
    final f = _form!;
    // ชิ้นงานที่ระบุเลขสำเนาไว้ต้องสลับเลขตาม
    final a = i + 1, b = i + dir + 1;
    _changed(() {
      f.copies.insert(i + dir, f.copies.removeAt(i));
      for (final e in f.elements) {
        e.copies = e.copies.map((n) => n == a ? b : (n == b ? a : n)).toList()..sort();
      }
      _viewCopy = b;
    }, true);
  }

  void _removeCopy(int i) {
    final f = _form!;
    final n = i + 1;
    _changed(() {
      f.copies.removeAt(i);
      for (final e in f.elements) {
        if (e.copies.isEmpty) continue;
        e.copies = e.copies.where((x) => x != n).map((x) => x > n ? x - 1 : x).toList();
        // เหลือทุกสำเนา (หรือไม่เหลือเลย) = แสดงทุกสำเนา
        if (e.copies.length >= f.copies.length || e.copies.isEmpty) e.copies = [];
      }
      _viewCopy = 1;
    }, true);
  }
}

class _GridPainter extends CustomPainter {
  final double scale;
  _GridPainter(this.scale);

  @override
  void paint(Canvas canvas, Size size) {
    final minor = Paint()
      ..color = Colors.blueGrey.withOpacity(0.10)
      ..strokeWidth = 0.5;
    final major = Paint()
      ..color = Colors.blueGrey.withOpacity(0.28)
      ..strokeWidth = 0.6;
    final step = scale >= 4 ? 1.0 : 5.0; // ซูมมาก = เส้นทุก 1 มม.
    for (double mm = 0; mm * scale <= size.width; mm += step) {
      final x = mm * scale;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), mm % 10 == 0 ? major : minor);
    }
    for (double mm = 0; mm * scale <= size.height; mm += step) {
      final y = mm * scale;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), mm % 10 == 0 ? major : minor);
    }
    // ตัวเลข มม. ทุก 10 มม. ตามขอบบน/ซ้าย
    final tp = TextPainter(textDirection: TextDirection.ltr);
    void label(String s, Offset o) {
      tp.text = TextSpan(text: s, style: TextStyle(fontSize: 8, color: Colors.blueGrey.withOpacity(0.7)));
      tp.layout();
      tp.paint(canvas, o);
    }

    for (var mm = 10; mm * scale <= size.width; mm += 10) {
      label('$mm', Offset(mm * scale + 1, 0));
    }
    for (var mm = 10; mm * scale <= size.height; mm += 10) {
      label('$mm', Offset(1, mm * scale + 1));
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.scale != scale;
}

class _LinePainter extends CustomPainter {
  final bool vertical;
  final bool horizontal;
  final double width;
  _LinePainter(this.vertical, this.horizontal, this.width);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.black
      ..strokeWidth = width;
    if (horizontal) {
      canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), p);
    } else if (vertical) {
      canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), p);
    } else {
      canvas.drawLine(Offset.zero, Offset(size.width, size.height), p);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.vertical != vertical || old.horizontal != horizontal || old.width != width;
}

// เส้นของตารางรายการบนผืนผ้าใบ (เหมือนตอนพิมพ์)
class _TablePainter extends CustomPainter {
  final PrintElement e;
  final double scale;
  final int rows;
  _TablePainter(this.e, this.scale, this.rows);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.black
      ..strokeWidth = math.max(e.strokeWidth * 0.3528 * scale, 1)
      ..style = PaintingStyle.stroke;
    final faint = Paint()
      ..color = Colors.blueGrey.withOpacity(0.35)
      ..strokeWidth = 0.5;
    final headH = e.showHeader ? e.headerHeight * scale : 0.0;
    final rowH = e.rowHeight * scale;
    if (e.border == 'grid' || e.border == 'box') {
      canvas.drawRect(Offset.zero & size, p);
      if (e.showHeader) canvas.drawLine(Offset(0, headH), Offset(size.width, headH), p);
      var x = 0.0;
      for (var i = 0; i < e.columns.length - 1; i++) {
        x += e.columns[i].w * scale;
        if (x >= size.width) break;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
      }
    }
    for (var i = 1; i <= rows; i++) {
      final y = headH + rowH * i;
      if (y >= size.height - 0.5) break;
      // grid/rows = เส้นจริง, อื่นๆ = เส้นจางบอกตำแหน่งแถว (ไม่พิมพ์)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), e.border == 'grid' || e.border == 'rows' ? p : faint);
    }
    if (e.border == 'rows' && e.showHeader) canvas.drawLine(Offset(0, headH), Offset(size.width, headH), p);
    if (e.border == 'none' || e.border == 'rows') canvas.drawRect(Offset.zero & size, faint);
  }

  @override
  bool shouldRepaint(covariant _TablePainter old) => true;
}
