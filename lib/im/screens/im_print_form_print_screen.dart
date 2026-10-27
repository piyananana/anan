// lib/im/screens/im_print_form_print_screen.dart — หน้าจอพิมพ์แบบฟอร์ม (ใช้ร่วมทุกแหล่งข้อมูล)
// ลงทะเบียนเป็นเมนูแยกต่อแหล่งข้อมูล (เช่น ImPrintSalesInvoiceScreen = ใบส่งสินค้า/ใบกำกับภาษี) เพื่อคุมสิทธิ์ตามเมนู
// เลือกแบบฟอร์ม + ประเภทเอกสาร (ตามสิทธิ์) + ช่วงเลขที่/วันที่ → ติ๊กเลือกเอกสาร → ดูตัวอย่าง / พิมพ์ (PDF ไฟล์เดียวรวมทุกใบ)
// ปุ่มพิมพ์บันทึกประวัติการพิมพ์ (พิมพ์ซ้ำ = "พิมพ์ซ้ำครั้งที่ x"), ดูตัวอย่างไม่นับครั้ง — พิมพ์ได้เฉพาะเอกสารที่โพสต์แล้ว
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../utils/date_utils.dart';
import '../../widgets/zoomable_pdf_preview.dart';
import '../models/im_print_form.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_language_provider.dart';
import '../services/im_print_form_service.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../utils/im_print_form_pdf.dart';

class ImPrintFormPrintScreen extends StatefulWidget {
  final String dataSource;
  const ImPrintFormPrintScreen({super.key, required this.dataSource});

  @override
  State<ImPrintFormPrintScreen> createState() => _ImPrintFormPrintScreenState();
}

class _ImPrintFormPrintScreenState extends State<ImPrintFormPrintScreen> {
  final _svc = ImPrintFormService();
  static final Color _appBarColor = Colors.blueGrey[700]!;
  static final Color _headerColor = Colors.blueGrey[300]!;

  bool _isEnglish = false;
  bool _isLeftExpanded = true;
  double _leftWidth = 320;
  bool _isDraggingDivider = false;

  bool _loading = true;
  bool _searching = false;
  bool _busy = false;
  PrintDataSource? _source;
  List<PrintForm> _forms = [];
  PrintForm? _form; // ฟอร์มเต็ม (รวมสำเนา/รูป)
  List<PrintDocType> _docTypes = [];
  final Set<int> _docTypeIds = {};
  final _docNoFrom = TextEditingController();
  final _docNoTo = TextEditingController();
  DateTime? _dateFrom;
  DateTime? _dateTo;
  final Set<int> _copyNos = {};

  List<PrintDocRow> _rows = [];
  final Set<String> _selected = {};
  bool _searched = false;

  String t(String th, String en) => _isEnglish ? en : th;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateFrom = DateTime(now.year, now.month, 1);
    _dateTo = DateTime(now.year, now.month, now.day);
    _init();
  }

  @override
  void dispose() {
    _docNoFrom.dispose();
    _docNoTo.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : Colors.green));
  }

  Future<void> _init() async {
    try {
      final sources = await _svc.fetchSources();
      final src = sources.where((s) => s.key == widget.dataSource).firstOrNull;
      if (src == null) throw Exception('ไม่พบแหล่งข้อมูล ${widget.dataSource}');
      final forms = await _svc.fetchForms(dataSource: src.key, activeOnly: true);
      final types = await _svc.fetchDocTypes(src.key);
      if (!mounted) return;
      setState(() {
        _source = src;
        _forms = forms;
        _docTypes = types;
        _docTypeIds.addAll(types.map((d) => d.id));
      });
      final def = forms.where((f) => f.isDefault).firstOrNull ?? forms.firstOrNull;
      if (def != null) await _selectForm(def.id!);
    } catch (e) {
      _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectForm(int id) async {
    try {
      final f = await _svc.fetchForm(id);
      if (!mounted) return;
      setState(() {
        _form = f;
        _copyNos
          ..clear()
          ..addAll([for (var i = 1; i <= f.copies.length; i++) i]);
      });
    } catch (e) {
      _snack('$e', error: true);
    }
  }

  Future<void> _search() async {
    final src = _source;
    if (src == null) return;
    if (_docTypeIds.isEmpty) {
      _snack(t('กรุณาเลือกประเภทเอกสาร', 'Please select a document type'), error: true);
      return;
    }
    setState(() => _searching = true);
    try {
      final rows = await _svc.fetchDocs(
        src.key,
        docIds: _docTypeIds.toList(),
        docNoFrom: _docNoFrom.text.trim(),
        docNoTo: _docNoTo.text.trim(),
        dateFrom: _dateFrom == null ? null : formatLocalDate(_dateFrom!),
        dateTo: _dateTo == null ? null : formatLocalDate(_dateTo!),
      );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _searched = true;
        // ค่าเริ่มต้นเลือกทุกใบที่ยังไม่เคยพิมพ์
        _selected
          ..clear()
          ..addAll(rows.where((r) => r.printCount == 0).map((r) => r.key));
      });
    } catch (e) {
      _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  List<String> get _selectedKeys => _rows.where((r) => _selected.contains(r.key)).map((r) => r.key).toList();

  List<int>? get _printCopies {
    final f = _form;
    if (f == null || f.isPreprinted) return null;
    return (_copyNos.toList()..sort());
  }

  bool _canPrint() {
    final f = _form;
    if (f == null) {
      _snack(t('กรุณาเลือกแบบฟอร์ม', 'Please select a form'), error: true);
      return false;
    }
    if (_selectedKeys.isEmpty) {
      _snack(t('กรุณาเลือกเอกสาร', 'Please select documents'), error: true);
      return false;
    }
    if (!f.isPreprinted && _copyNos.isEmpty) {
      _snack(t('กรุณาเลือกสำเนาที่จะพิมพ์', 'Please select copies to print'), error: true);
      return false;
    }
    return true;
  }

  PdfPageFormat _pageFormat(PrintForm f) => PdfPageFormat(f.paperWidth * PdfPageFormat.mm, f.paperHeight * PdfPageFormat.mm);

  Future<String> _userName() async => (await AuthService().getCurrentUser())?.userName ?? '';

  Future<void> _preview() async {
    if (!_canPrint()) return;
    final f = _form!;
    setState(() => _busy = true);
    try {
      final data = await _svc.fetchPrintData(_source!.key, _selectedKeys, formId: f.id);
      final user = await _userName();
      if (!mounted) return;
      _showPdf(
        t('ดูตัวอย่าง (${data.docs.length} เอกสาร) — ยังไม่นับเป็นการพิมพ์', 'Preview (${data.docs.length} documents) — not counted as printed'),
        f,
        (_) => PrintFormPdf.build(form: f, source: _source!, data: data, printedBy: user, copyNos: _printCopies),
        allowPrinting: false,
      );
    } catch (e) {
      _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // พิมพ์ทดสอบตำแหน่ง: ข้อมูลตัวอย่าง + กรอบแดงของทุกชิ้นงาน — พิมพ์ลงกระดาษเปล่าแล้ววางทาบฟอร์มจริง
  Future<void> _testPrint() async {
    final f = _form;
    if (f == null) {
      _snack(t('กรุณาเลือกแบบฟอร์ม', 'Please select a form'), error: true);
      return;
    }
    final data = PrintData(company: const {}, docs: [samplePrintDoc(_source!, _isEnglish, lineCount: 50)]);
    _showPdf(
      t('พิมพ์ทดสอบตำแหน่ง (ข้อมูลตัวอย่าง + กรอบชิ้นงาน)', 'Alignment test (sample data + element boxes)'),
      f,
      (_) => PrintFormPdf.build(form: f, source: _source!, data: data, printedBy: '', copyNos: _printCopies?.take(1).toList(), guide: true),
      allowPrinting: true,
    );
  }

  Future<void> _print() async {
    if (!_canPrint()) return;
    final f = _form!;
    final keys = _selectedKeys;
    final reprints = _rows.where((r) => keys.contains(r.key) && r.printCount > 0).length;
    final copies = f.isPreprinted ? <int>[] : _printCopies!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('ยืนยันการพิมพ์', 'Confirm printing')),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('พิมพ์ ${keys.length} เอกสาร ด้วยแบบฟอร์ม "${f.nameTh}"', 'Print ${keys.length} documents with form "${f.name(true)}"')),
          if (!f.isPreprinted)
            Text(t('สำเนา: ${copies.map((n) => f.copies[n - 1].nameTh).join(', ')}',
                'Copies: ${copies.map((n) => f.copies[n - 1].name(true)).join(', ')}')),
          if (reprints > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(t('มี $reprints เอกสารที่เคยพิมพ์แล้ว — จะบันทึกเป็นการพิมพ์ซ้ำ', '$reprints documents were printed before — they will be logged as reprints'),
                  style: TextStyle(color: Colors.orange[800])),
            ),
          const SizedBox(height: 8),
          Text(t('ในหน้าต่างพิมพ์ให้ตั้งขนาดเป็น "ขนาดจริง / 100%" (ห้ามย่อให้พอดีหน้า)', 'In the print dialog set scale to "Actual size / 100%" (not "Fit to page")'),
              style: const TextStyle(fontSize: 12)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('ยกเลิก', 'Cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('พิมพ์', 'Print'))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final copyNames = f.isPreprinted ? null : copies.map((n) => f.copies[n - 1].nameTh).join(', ');
      final data = await _svc.fetchPrintData(_source!.key, keys, formId: f.id, log: true, copies: copyNames);
      final user = await _userName();
      final bytes = await PrintFormPdf.build(form: f, source: _source!, data: data, printedBy: user, copyNos: _printCopies);
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: '${f.code}_${DateTime.now().millisecondsSinceEpoch}', format: _pageFormat(f));
      await _search();
    } catch (e) {
      _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showPdf(String title, PrintForm f, LayoutCallback build, {required bool allowPrinting}) {
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
                Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
              ]),
            ),
            Expanded(
              child: ZoomablePdfPreview(
                documentVersion: DateTime.now().millisecondsSinceEpoch,
                initialPageFormat: _pageFormat(f),
                build: build,
                allowPrinting: allowPrinting,
                allowSharing: false,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _pickDate(bool from) async {
    final d = await showDatePicker(
      context: context,
      initialDate: (from ? _dateFrom : _dateTo) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => from ? _dateFrom = d : _dateTo = d);
  }

  @override
  Widget build(BuildContext context) {
    _isEnglish = context.watch<LanguageProvider>().isEnglish;
    return Scaffold(
      appBar: AppBar(title: const MenuTitle(), backgroundColor: _appBarColor, foregroundColor: Colors.white),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, constraints) {
              final maxLeftWidth = (constraints.maxWidth - 36 - 5 - 400).clamp(240.0, double.infinity);
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
                      child: ColoredBox(color: Colors.blueGrey.shade100, child: _buildFilters()),
                    ),
                  ),
                ),
                if (_isLeftExpanded)
                  MouseRegion(
                    cursor: SystemMouseCursors.resizeColumn,
                    child: GestureDetector(
                      onHorizontalDragStart: (_) => setState(() => _isDraggingDivider = true),
                      onHorizontalDragUpdate: (d) => setState(() => _leftWidth = (_leftWidth + d.delta.dx).clamp(240.0, maxLeftWidth)),
                      onHorizontalDragEnd: (_) => setState(() => _isDraggingDivider = false),
                      child: Container(width: 5, color: Colors.grey[400]),
                    ),
                  ),
                Expanded(child: _buildDocList()),
              ]);
            }),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: const OutlineInputBorder(),
      );

  Widget _section(String s) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Text(s, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
      );

  Widget _buildFilters() {
    final f = _form;
    return ListView(padding: const EdgeInsets.all(10), children: [
      DropdownButtonFormField<int>(
        value: _forms.any((x) => x.id == f?.id) ? f?.id : null,
        isExpanded: true,
        decoration: _dec(t('แบบฟอร์ม', 'Form')),
        items: [
          for (final x in _forms)
            DropdownMenuItem(value: x.id, child: Text('${x.name(_isEnglish)}${x.isDefault ? ' *' : ''}', overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) {
          if (v != null) _selectForm(v);
        },
      ),
      if (_forms.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(t('ยังไม่มีแบบฟอร์มที่ใช้งานของแหล่งข้อมูลนี้ — สร้างที่หน้าจอออกแบบฟอร์ม', 'No active form for this data source — create one in the form designer'),
              style: TextStyle(fontSize: 12, color: Colors.red[700])),
        ),
      if (f != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            f.isPreprinted
                ? t('Pre-printed (dot-matrix): พิมพ์ข้อมูลชุดเดียว ไม่พิมพ์พื้นหลัง', 'Pre-printed (dot-matrix): data only, one set')
                : t('เลเซอร์: พิมพ์พื้นหลัง + ข้อมูล ทีละสำเนา', 'Laser: background + data, one sheet per copy'),
            style: const TextStyle(fontSize: 12),
          ),
        ),
      if (f != null && !f.isPreprinted) ...[
        _section(t('สำเนาที่พิมพ์', 'Copies to print')),
        Wrap(spacing: 6, runSpacing: 4, children: [
          for (var i = 1; i <= f.copies.length; i++)
            FilterChip(
              label: Text(f.copies[i - 1].name(_isEnglish)),
              selected: _copyNos.contains(i),
              onSelected: (v) => setState(() => v ? _copyNos.add(i) : _copyNos.remove(i)),
            ),
        ]),
      ],
      _section(t('ประเภทเอกสาร', 'Document types')),
      if (_docTypes.isEmpty)
        Text(t('ไม่มีสิทธิ์ประเภทเอกสาร', 'No permitted document types'), style: TextStyle(fontSize: 12, color: Colors.red[700])),
      for (final d in _docTypes)
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          visualDensity: VisualDensity.compact,
          title: Text('${d.docCode} - ${d.name(_isEnglish)}'),
          value: _docTypeIds.contains(d.id),
          onChanged: (v) => setState(() => v == true ? _docTypeIds.add(d.id) : _docTypeIds.remove(d.id)),
        ),
      _section(t('ช่วงเลขที่เอกสาร', 'Document no. range')),
      Row(children: [
        Expanded(child: TextField(controller: _docNoFrom, decoration: _dec(t('จาก', 'From')))),
        const SizedBox(width: 6),
        Expanded(child: TextField(controller: _docNoTo, decoration: _dec(t('ถึง', 'To')))),
      ]),
      _section(t('ช่วงวันที่เอกสาร', 'Document date range')),
      Row(children: [
        Expanded(child: _dateBox(t('จาก', 'From'), _dateFrom, () => _pickDate(true), () => setState(() => _dateFrom = null))),
        const SizedBox(width: 6),
        Expanded(child: _dateBox(t('ถึง', 'To'), _dateTo, () => _pickDate(false), () => setState(() => _dateTo = null))),
      ]),
      const SizedBox(height: 14),
      ElevatedButton.icon(
        onPressed: _searching ? null : _search,
        icon: _searching ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search),
        label: Text(t('ค้นหาเอกสาร', 'Find documents')),
      ),
      const SizedBox(height: 6),
      Text(t('แสดงเฉพาะเอกสารที่โพสต์แล้ว', 'Only posted documents are listed'), style: TextStyle(fontSize: 12, color: Colors.grey[700])),
    ]);
  }

  Widget _dateBox(String label, DateTime? d, VoidCallback onTap, VoidCallback onClear) => InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: _dec(label).copyWith(
            suffixIcon: d == null
                ? const Icon(Icons.calendar_today, size: 16)
                : IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: onClear, visualDensity: VisualDensity.compact),
          ),
          child: Text(d == null ? '' : formatPrintDate(formatLocalDate(d), 'dmy_be')),
        ),
      );

  Widget _buildDocList() {
    final allSelected = _rows.isNotEmpty && _rows.every((r) => _selected.contains(r.key));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        color: _headerColor,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(children: [
          Expanded(
            child: Text(
              t('เลือก ${_selected.length} จาก ${_rows.length} เอกสาร', 'Selected ${_selected.length} of ${_rows.length} documents'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton.icon(
            onPressed: _busy ? null : _testPrint,
            icon: const Icon(Icons.grid_on, color: Colors.white),
            label: Text(t('พิมพ์ทดสอบตำแหน่ง', 'Alignment test'), style: const TextStyle(color: Colors.white)),
          ),
          TextButton.icon(
            onPressed: _busy ? null : _preview,
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
            label: Text(t('ดูตัวอย่าง', 'Preview'), style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 4),
          ElevatedButton.icon(
            onPressed: _busy ? null : _print,
            icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.print),
            label: Text(t('พิมพ์', 'Print')),
          ),
        ]),
      ),
      Container(
        color: Colors.amber[50],
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          Icon(Icons.info_outline, size: 18, color: Colors.amber[900]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              t('ในหน้าต่างพิมพ์ให้ตั้งขนาดเป็น "ขนาดจริง / 100%" ห้ามเลือก "ย่อให้พอดีหน้า" และตั้งขนาดกระดาษของเครื่องพิมพ์ให้ตรงกับแบบฟอร์ม',
                  'In the print dialog choose "Actual size / 100%" (not "Fit to page") and set the printer paper size to match the form'),
              style: TextStyle(fontSize: 12, color: Colors.amber[900]),
            ),
          ),
        ]),
      ),
      Container(
        color: Colors.grey[200],
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(children: [
          Checkbox(
            value: allSelected,
            onChanged: _rows.isEmpty
                ? null
                : (v) => setState(() {
                      _selected.clear();
                      if (v == true) _selected.addAll(_rows.map((r) => r.key));
                    }),
          ),
          _hdr(t('ประเภท', 'Type'), 70),
          _hdr(t('เลขที่เอกสาร', 'Document no.'), 140),
          _hdr(t('วันที่', 'Date'), 90),
          Expanded(child: _hdrText(t('ลูกค้า', 'Customer'))),
          _hdr(t('จำนวนเงิน', 'Amount'), 110, right: true),
          _hdr(t('พิมพ์แล้ว', 'Printed'), 90, right: true),
          const SizedBox(width: 8),
        ]),
      ),
      Expanded(
        child: _rows.isEmpty
            ? Center(
                child: Text(
                  _searched ? t('ไม่พบเอกสารตามเงื่อนไข', 'No documents found') : t('กำหนดเงื่อนไขทางซ้ายแล้วกดค้นหาเอกสาร', 'Set the filters on the left and press Find'),
                  style: TextStyle(color: Colors.grey[600]),
                ),
              )
            : ListView.separated(
                itemCount: _rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final r = _rows[i];
                  final sel = _selected.contains(r.key);
                  return InkWell(
                    onTap: () => setState(() => sel ? _selected.remove(r.key) : _selected.add(r.key)),
                    child: Container(
                      color: sel ? Colors.blueGrey[50] : null,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(children: [
                        Checkbox(value: sel, onChanged: (v) => setState(() => v == true ? _selected.add(r.key) : _selected.remove(r.key))),
                        _cell(r.docCode, 70),
                        _cell(r.docNo, 140),
                        _cell(formatPrintDate(r.docDate, 'dmy_be'), 90),
                        Expanded(child: Text('${r.customerCode}  ${r.customerName}', overflow: TextOverflow.ellipsis)),
                        _cell(formatPrintNumber(r.totalAmount, 'money', ''), 110, right: true),
                        SizedBox(
                          width: 90,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: r.printCount == 0
                                ? Text('-', style: TextStyle(color: Colors.grey[500]))
                                : Chip(
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: Colors.orange[100],
                                    label: Text(t('${r.printCount} ครั้ง', '${r.printCount}x'), style: const TextStyle(fontSize: 12)),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ]),
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  Widget _hdrText(String s) => Text(s, style: const TextStyle(fontWeight: FontWeight.bold));
  Widget _hdr(String s, double w, {bool right = false}) =>
      SizedBox(width: w, child: Align(alignment: right ? Alignment.centerRight : Alignment.centerLeft, child: _hdrText(s)));
  Widget _cell(String s, double w, {bool right = false}) =>
      SizedBox(width: w, child: Text(s, textAlign: right ? TextAlign.right : TextAlign.left, overflow: TextOverflow.ellipsis));
}
