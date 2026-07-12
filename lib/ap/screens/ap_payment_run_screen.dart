// lib/ap/screens/ap_payment_run_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:provider/provider.dart';
import '../models/ap_payment_run.dart';
import '../services/ap_payment_run_service.dart';
import '../../cm/models/cm_bank_file_format.dart';
import '../../cm/services/cm_bank_file_format_service.dart';
import '../../sa/services/auth_service.dart';
import '../../sa/services/company_service.dart';
import '../../sa/services/language_provider.dart';
import '../../sa/utils/app_l10n.dart';
import '../../sa/utils/menu_scope.dart';
import '../../utils/file_download.dart';

// ── Column widths ────────────────────────────────────────────────────────────
const double _wVendor   = 130.0;
const double _wVendorNm = 180.0;
const double _wBank     = 120.0;
const double _wAccNo    = 130.0;
const double _wInvNo    = 130.0;
const double _wDate     =  90.0;
const double _wAmt      = 110.0;
const double _wAct      =  40.0;

final _fmt = NumberFormat('#,##0.00');
final _dateFmt = DateFormat('dd/MM/yyyy');
String _fmtDate(DateTime? d) => d == null ? '' : _dateFmt.format(d);

// ── Status helpers ────────────────────────────────────────────────────────────
Color _statusColor(String s) {
  switch (s) {
    case 'Draft':     return Colors.grey;
    case 'Submitted': return Colors.orange[700]!;
    case 'Approved':  return Colors.green[700]!;
    case 'Rejected':  return Colors.red[700]!;
    case 'Completed': return Colors.blue[700]!;
    case 'Void':      return Colors.grey[600]!;
    default:          return Colors.grey;
  }
}

Widget _statusChip(String s) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: _statusColor(s).withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _statusColor(s).withOpacity(0.6))),
      child: Text(apPaymentRunStatusLabels[s] ?? s,
          style: TextStyle(
              color: _statusColor(s),
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );

// ── Editable line row (mutable) ───────────────────────────────────────────────
class _LineRow {
  final ApPaymentRunLine source;
  final TextEditingController amtCtrl;

  _LineRow(this.source)
      : amtCtrl = TextEditingController(
            text: source.paymentAmountLc.toStringAsFixed(2));

  ApPaymentRunLine toLine() => source.copyWith(
      paymentAmountLc: double.tryParse(amtCtrl.text.replaceAll(',', '')) ??
          source.paymentAmountLc);

  void dispose() => amtCtrl.dispose();
}

// ── Screen ────────────────────────────────────────────────────────────────────
class ApPaymentRunScreen extends StatefulWidget {
  const ApPaymentRunScreen({super.key});

  @override
  State<ApPaymentRunScreen> createState() => _ApPaymentRunScreenState();
}

class _ApPaymentRunScreenState extends State<ApPaymentRunScreen>
    with AutomaticKeepAliveClientMixin {
  final _svc    = ApPaymentRunService();
  final _fmtSvc = CmBankFileFormatService();

  List<ApPaymentRun> _runs = [];
  bool _listLoading = true;
  String _statusFilter = 'All';

  ApPaymentRun? _selected;
  bool _isAdding = false;
  bool _isLeftExpanded = true;
  double _leftWidth = 320;
  bool _isDraggingDivider = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  Future<void> _loadList() async {
    setState(() => _listLoading = true);
    try {
      final rows = await _svc.fetchRows(
          status: _statusFilter == 'All' ? null : _statusFilter);
      if (mounted) setState(() { _runs = rows; _listLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _listLoading = false);
    }
  }

  void _onAdd() => setState(() { _selected = null; _isAdding = true; });

  void _onSelect(ApPaymentRun run) async {
    setState(() { _isAdding = false; _selected = run; });
    try {
      final full = await _svc.fetchRow(run.id!);
      if (mounted) setState(() => _selected = full);
    } catch (_) {}
  }

  void _onSaved(ApPaymentRun saved) {
    setState(() { _selected = saved; _isAdding = false; });
    _loadList();
  }

  void _onCancel() => setState(() { _selected = null; _isAdding = false; });

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'รีเฟรช', onPressed: _loadList),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final double maxLeftWidth =
            (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── Collapse strip ───────────────────────────────────────────────
        Container(
          width: 36,
          color: Colors.blue[700],
          child: IconButton(
            icon: Icon(
              _isLeftExpanded ? Icons.filter_list_off : Icons.filter_list,
              color: Colors.white,
              size: 20,
            ),
            padding: EdgeInsets.zero,
            onPressed: () => setState(() => _isLeftExpanded = !_isLeftExpanded),
            tooltip: _isLeftExpanded ? 'ย่อรายการ' : 'ขยายรายการ',
          ),
        ),
        // ── Left panel (animated) ────────────────────────────────────────
        AnimatedContainer(
          duration: _isDraggingDivider
              ? Duration.zero
              : const Duration(milliseconds: 200),
          width: _isLeftExpanded ? _leftWidth : 0.0,
          child: ClipRect(
            child: OverflowBox(
              maxWidth: _leftWidth,
              minWidth: _leftWidth,
              alignment: Alignment.topLeft,
              child: ColoredBox(
                color: Colors.blueGrey.shade100,
                child: Column(children: [
                  // header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(children: [
                      Expanded(
                        child: Text('Payment Runs (${_runs.length})',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800])),
                      ),
                      IconButton(
                          icon: const Icon(Icons.add),
                          iconSize: 20,
                          color: Colors.blue[700],
                          tooltip: 'สร้างใหม่',
                          onPressed: _onAdd),
                    ]),
                  ),
                  _StatusFilterBar(
                    selected: _statusFilter,
                    onChanged: (s) {
                      setState(() => _statusFilter = s);
                      _loadList();
                    },
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _listLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _runs.isEmpty
                            ? Center(
                                child: Text('ไม่พบข้อมูล',
                                    style: TextStyle(color: Colors.grey[500])))
                            : ListView.builder(
                                itemCount: _runs.length,
                                itemBuilder: (ctx, i) {
                                  final r = _runs[i];
                                  final sel = _selected?.id == r.id;
                                  return ListTile(
                                    selected: sel,
                                    selectedTileColor: Colors.blueGrey.shade200,
                                    dense: true,
                                    title: Text(r.runNumber ?? '(ใหม่)',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                    subtitle: Text(
                                        '${_fmtDate(r.runDate)}  ${_fmt.format(r.totalAmountLc)}',
                                        style: const TextStyle(fontSize: 12)),
                                    trailing: _statusChip(r.status),
                                    onTap: () => _onSelect(r),
                                  );
                                }),
                  ),
                ]),
              ),
            ),
          ),
        ),
        // ── Resizable divider ────────────────────────────────────────────
        if (_isLeftExpanded)
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              onHorizontalDragStart: (_) =>
                  setState(() => _isDraggingDivider = true),
              onHorizontalDragUpdate: (details) => setState(() {
                _leftWidth =
                    (_leftWidth + details.delta.dx).clamp(200.0, maxLeftWidth);
              }),
              onHorizontalDragEnd: (_) =>
                  setState(() => _isDraggingDivider = false),
              child: Container(width: 5, color: Colors.grey[400]),
            ),
          ),
        // ── Right panel ──────────────────────────────────────────────────
        Expanded(
          child: (_selected == null && !_isAdding)
              ? Center(
                  child: Text('เลือก Payment Run หรือกด + เพื่อสร้างใหม่',
                      style: TextStyle(color: Colors.grey[500])))
              : _DetailPanel(
                  key: ValueKey(_selected?.id ?? 'new_$_isAdding'),
                  run: _selected,
                  svc: _svc,
                  fmtSvc: _fmtSvc,
                  onSaved: _onSaved,
                  onCancel: _onCancel,
                  onRefresh: _loadList,
                ),
        ),
        ]);
      }),
    );
  }
}

// ── Status filter bar ─────────────────────────────────────────────────────────
class _StatusFilterBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _StatusFilterBar({required this.selected, required this.onChanged});

  static const _statuses = ['All', 'Draft', 'Submitted', 'Approved', 'Completed', 'Void'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: _statuses.map((s) {
          final active = s == selected;
          return ChoiceChip(
            label: Text(s == 'All' ? 'ทั้งหมด' : (apPaymentRunStatusLabels[s] ?? s),
                style: TextStyle(fontSize: 11, color: active ? Colors.white : null)),
            selected: active,
            selectedColor: Colors.blue[600],
            onSelected: (_) => onChanged(s),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        }).toList(),
      ),
    );
  }
}

// ── Detail panel ──────────────────────────────────────────────────────────────
class _DetailPanel extends StatefulWidget {
  final ApPaymentRun? run;
  final ApPaymentRunService svc;
  final CmBankFileFormatService fmtSvc;
  final ValueChanged<ApPaymentRun> onSaved;
  final VoidCallback onCancel;
  final VoidCallback onRefresh;

  const _DetailPanel({
    super.key,
    required this.run,
    required this.svc,
    required this.fmtSvc,
    required this.onSaved,
    required this.onCancel,
    required this.onRefresh,
  });

  @override
  State<_DetailPanel> createState() => _DetailPanelState();
}

class _DetailPanelState extends State<_DetailPanel> {
  final _descCtrl = TextEditingController();
  DateTime _runDate = DateTime.now();
  int? _bankFmtId;
  List<CmBankFileFormat> _fmtOptions = [];

  late List<_LineRow> _lineRows;
  bool _saving = false;
  bool _readOnly = false;
  final _companySvc = CompanyService();

  @override
  void initState() {
    super.initState();
    _init();
    _loadFormats();
  }

  void _init() {
    final r = widget.run;
    _readOnly = r != null && !['Draft'].contains(r.status);
    _runDate = r?.runDate ?? DateTime.now();
    _descCtrl.text = r?.description ?? '';
    _bankFmtId = r?.bankFileFormatId;
    _lineRows = (r?.lines ?? []).map(_LineRow.new).toList();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    for (final row in _lineRows) { row.dispose(); }
    super.dispose();
  }

  Future<void> _loadFormats() async {
    try {
      final fmts = await widget.fmtSvc.fetchRows();
      if (mounted) setState(() => _fmtOptions = fmts.where((f) => f.isActive).toList());
    } catch (_) {}
  }

  double get _totalPayment =>
      _lineRows.fold(0, (s, r) =>
          s + (double.tryParse(r.amtCtrl.text.replaceAll(',', '')) ?? r.source.paymentAmountLc));

  bool get _isDraft => widget.run == null || widget.run!.status == 'Draft';

  Future<void> _save() async {
    final lines = _lineRows.map((r) => r.toLine()).toList();
    final run = ApPaymentRun(
      id: widget.run?.id,
      runDate: _runDate,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      bankFileFormatId: _bankFmtId,
      lines: lines,
    );
    setState(() => _saving = true);
    try {
      final saved = widget.run?.id == null
          ? await widget.svc.createRun(run)
          : await widget.svc.updateRun(run);
      if (mounted) {
        widget.onSaved(saved);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('บันทึกสำเร็จ')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการส่งอนุมัติ'),
        content: Text('ส่งอนุมัติ ${widget.run!.runNumber}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ส่งอนุมัติ')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.svc.submitRun(widget.run!.id!);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('ส่งอนุมัติสำเร็จ')));
        widget.onRefresh();
        final updated = await widget.svc.fetchRow(widget.run!.id!);
        if (mounted) widget.onSaved(updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _void() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการยกเลิก'),
        content: Text('ยกเลิกเอกสาร ${widget.run?.runNumber ?? ''}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ไม่')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ยกเลิกเอกสาร', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.svc.voidRun(widget.run!.id!);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('ยกเลิกเอกสารสำเร็จ')));
        widget.onRefresh();
        final updated = await widget.svc.fetchRow(widget.run!.id!);
        if (mounted) widget.onSaved(updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Remittance Advice PDF ──────────────────────────────────────────────────

  Future<Uint8List> _buildRaPdf(PdfPageFormat format) async {
    final run = widget.run!;
    final company = await _companySvc.fetchCompany();
    final companyName = company?.thaiName ?? '';

    final fontData     = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final font     = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontBoldData);

    final numFmt  = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd/MM/yyyy');
    String fd(DateTime? d) => d == null ? '' : dateFmt.format(d);

    // Group lines by vendor
    final Map<int, List<ApPaymentRunLine>> byVendor = {};
    for (final line in run.lines) {
      byVendor.putIfAbsent(line.vendorId, () => []).add(line);
    }

    final doc = pw.Document();
    final theme = pw.ThemeData.withFont(base: font, bold: fontBold);

    const headerBg   = PdfColor.fromInt(0xFFD6E4F7); // light blue
    const borderColor = PdfColor.fromInt(0xFF9E9E9E);

    pw.Widget col(String t, double w,
        {pw.TextAlign align = pw.TextAlign.left,
        bool bold = false,
        pw.TextStyle? style}) =>
        pw.Container(
          width: w,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: pw.Text(t,
              textAlign: align,
              style: style ??
                  pw.TextStyle(
                      fontSize: 10,
                      fontWeight:
                          bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        );

    for (final entry in byVendor.entries) {
      final lines = entry.value;
      final first = lines.first;
      final vendorTotal =
          lines.fold<double>(0, (s, l) => s + l.paymentAmountLc);

      final bankLine = [
        first.bankName,
        first.bankBranchName,
      ].where((e) => e != null && e.isNotEmpty).join(' สาขา ');

      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.fromLTRB(20, 20, 20, 20),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── Company & title ──────────────────────────────────────
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(
                  child: pw.Text(companyName,
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Text(
                  'พิมพ์: ${dateFmt.format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text('ใบแจ้งรายการโอนเงิน / Remittance Advice',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Divider(color: borderColor, thickness: 0.5),
            pw.SizedBox(height: 4),
            // ── Run header info ──────────────────────────────────────
            pw.Row(children: [
              pw.SizedBox(
                width: 260,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(children: [
                      pw.SizedBox(
                          width: 90,
                          child: pw.Text('เลขที่ Payment Run:',
                              style: const pw.TextStyle(fontSize: 10))),
                      pw.Text(run.runNumber ?? '-',
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold)),
                    ]),
                    pw.SizedBox(height: 2),
                    pw.Row(children: [
                      pw.SizedBox(
                          width: 90,
                          child: pw.Text('วันที่โอนเงิน:',
                              style: const pw.TextStyle(fontSize: 10))),
                      pw.Text(fd(run.runDate),
                          style: const pw.TextStyle(fontSize: 10)),
                    ]),
                    if (run.description != null &&
                        run.description!.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Row(children: [
                        pw.SizedBox(
                            width: 90,
                            child: pw.Text('หมายเหตุ:',
                                style:
                                    const pw.TextStyle(fontSize: 10))),
                        pw.Expanded(
                          child: pw.Text(run.description!,
                              style: const pw.TextStyle(fontSize: 10)),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
              pw.Expanded(child: pw.SizedBox()),
              // Vendor info box
              pw.Container(
                width: 240,
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderColor, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(3)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ผู้รับเงิน / Payee',
                        style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey600)),
                    pw.SizedBox(height: 2),
                    pw.Text(
                        '${first.vendorCode}  ${first.vendorNameTh}',
                        style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('ธนาคาร: $bankLine',
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('บัญชี: ${first.accountNumber ?? '-'}',
                        style: const pw.TextStyle(fontSize: 10)),
                    if ((first.accountName ?? '').isNotEmpty)
                      pw.Text('ชื่อบัญชี: ${first.accountName}',
                          style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ]),
            pw.SizedBox(height: 10),
            // ── Lines table ──────────────────────────────────────────
            pw.Table(
              border: pw.TableBorder.all(
                  color: borderColor, width: 0.4),
              columnWidths: const {
                0: pw.FixedColumnWidth(130),
                1: pw.FixedColumnWidth(72),
                2: pw.FixedColumnWidth(72),
                3: pw.FlexColumnWidth(1),
                4: pw.FixedColumnWidth(82),
                5: pw.FixedColumnWidth(82),
              },
              children: [
                // Header
                pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: headerBg),
                  children: [
                    col('เลขที่ใบแจ้งหนี้', 130, bold: true),
                    col('วันที่ใบ', 72,
                        align: pw.TextAlign.center, bold: true),
                    col('วันครบกำหนด', 72,
                        align: pw.TextAlign.center, bold: true),
                    col('รายละเอียด', 0, bold: true),
                    col('ยอดใบแจ้งหนี้', 82,
                        align: pw.TextAlign.right, bold: true),
                    col('ยอดชำระ', 82,
                        align: pw.TextAlign.right, bold: true),
                  ],
                ),
                // Data rows
                for (final line in lines)
                  pw.TableRow(children: [
                    col(line.invoiceNo, 130),
                    col(fd(line.invoiceDate), 72,
                        align: pw.TextAlign.center),
                    col(fd(line.dueDate), 72,
                        align: pw.TextAlign.center),
                    col('', 0),
                    col(numFmt.format(line.invoiceAmountLc), 82,
                        align: pw.TextAlign.right),
                    col(numFmt.format(line.paymentAmountLc), 82,
                        align: pw.TextAlign.right),
                  ]),
                // Total row
                pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: headerBg),
                  children: [
                    col('รวมทั้งสิ้น', 130,
                        bold: true,
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold)),
                    col('', 72),
                    col('', 72),
                    col('', 0),
                    col('', 82),
                    col(numFmt.format(vendorTotal), 82,
                        align: pw.TextAlign.right,
                        bold: true,
                        style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            // ── Signature area ───────────────────────────────────────
            pw.Row(children: [
              _sigBox('ผู้จัดทำ / Prepared by'),
              pw.SizedBox(width: 20),
              _sigBox('ผู้ตรวจสอบ / Checked by'),
              pw.SizedBox(width: 20),
              _sigBox('ผู้อนุมัติ / Approved by'),
            ]),
          ],
        ),
      ));
    }

    return doc.save();
  }

  pw.Widget _sigBox(String label) => pw.Expanded(
        child: pw.Column(children: [
          pw.Container(
            height: 50,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                  bottom: pw.BorderSide(
                      color: PdfColor.fromInt(0xFF9E9E9E),
                      width: 0.5)),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Center(
            child: pw.Text(label,
                style: const pw.TextStyle(fontSize: 9)),
          ),
          pw.Center(
            child: pw.Text('วันที่: __________',
                style: const pw.TextStyle(fontSize: 9)),
          ),
        ]),
      );

  // ── Bank file generation ──────────────────────────────────────────────────

  String _fmtBankDate(DateTime d, String pattern) {
    final y = d.year.toString();
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return pattern
        .replaceAll('YYYY', y)
        .replaceAll('MM', m)
        .replaceAll('DD', dd);
  }

  String _fmtBankAmount(double v, int decimalPlaces, bool fixedWidth) {
    if (decimalPlaces <= 0) return v.truncate().toString();
    if (fixedWidth) {
      // Remove decimal point: 1234.56 with 2 dp → "123456"
      final factor = _pow10(decimalPlaces);
      return (v * factor).round().toString();
    }
    return v.toStringAsFixed(decimalPlaces);
  }

  int _pow10(int n) {
    int r = 1;
    for (int i = 0; i < n; i++) { r *= 10; }
    return r;
  }

  String _padField(String value, int length, String align, String padChar) {
    final pad = padChar.isEmpty ? ' ' : padChar[0];
    if (value.length >= length) return value.substring(0, length);
    return align == 'R'
        ? value.padLeft(length, pad)
        : value.padRight(length, pad);
  }

  String _rawFieldValue(
      CmBankFileFormatColumn col,
      ApPaymentRunLine line,
      ApPaymentRun run,
      int seqNo,
      String companyCode,
      bool fixedWidth) {
    switch (col.fieldCode) {
      case 'payment_date':
        return _fmtBankDate(run.runDate, col.dateFormat);
      case 'amount':
        return _fmtBankAmount(
            line.paymentAmountLc, col.decimalPlaces, fixedWidth);
      case 'currency':
        return line.currencyCode;
      case 'vendor_code':
        return line.vendorCode;
      case 'vendor_name':
        return line.vendorNameTh;
      case 'bank_code':
        return line.bankName ?? '';
      case 'bank_branch_code':
        return line.bankBranchName ?? '';
      case 'account_number':
        return line.accountNumber ?? '';
      case 'account_name':
        return line.accountName ?? '';
      case 'reference':
        return line.invoiceNo;
      case 'doc_number':
        return run.runNumber ?? '';
      case 'sequence':
        return seqNo.toString();
      case 'company_code':
        return companyCode;
      case 'branch_code':
        return '';
      case 'constant':
        return col.constantValue ?? '';
      default:
        return '';
    }
  }

  Future<void> _generateBankFile() async {
    final run = widget.run;
    if (run == null || _bankFmtId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('กรุณาเลือกรูปแบบไฟล์ธนาคารก่อนสร้างไฟล์')));
      return;
    }
    if (run.lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่มีรายการชำระเงิน')));
      return;
    }

    setState(() => _saving = true);
    try {
      final fmt = await widget.fmtSvc.fetchRow(_bankFmtId!);
      final company = await _companySvc.fetchCompany();
      final companyCode = company?.taxIdNumber ?? '';
      final fixedWidth = fmt.delimiter.isEmpty;

      final lines = <String>[];

      // Optional header line (column labels or blank)
      if (fmt.hasHeader) {
        if (fixedWidth) {
          lines.add(fmt.columns
              .map((c) => _padField(c.columnLabel, c.length, c.align, c.padChar))
              .join());
        } else {
          lines.add(fmt.columns.map((c) => c.columnLabel).join(fmt.delimiter));
        }
      }

      // Data rows
      for (int i = 0; i < run.lines.length; i++) {
        final line = run.lines[i];
        if (fixedWidth) {
          lines.add(fmt.columns.map((col) {
            final raw = _rawFieldValue(col, line, run, i + 1, companyCode, true);
            return _padField(raw, col.length, col.align, col.padChar);
          }).join());
        } else {
          lines.add(fmt.columns.map((col) {
            return _rawFieldValue(col, line, run, i + 1, companyCode, false);
          }).join(fmt.delimiter));
        }
      }

      // Optional footer line (total count + total amount)
      if (fmt.hasFooter) {
        final totalAmt = run.lines
            .fold<double>(0, (s, l) => s + l.paymentAmountLc);
        final footerAmtCol = fmt.columns.firstWhere(
            (c) => c.fieldCode == 'amount',
            orElse: () => CmBankFileFormatColumn(fieldCode: 'amount'));
        final amtStr = _fmtBankAmount(
            totalAmt, footerAmtCol.decimalPlaces, fixedWidth);
        final countStr = run.lines.length.toString();
        if (fixedWidth) {
          final countLen = footerAmtCol.length ~/ 2;
          final amtLen = footerAmtCol.length - countLen;
          lines.add(
              _padField(countStr, countLen, 'R', '0') +
              _padField(amtStr, amtLen, 'R', '0'));
        } else {
          lines.add('$countStr${fmt.delimiter}$amtStr');
        }
      }

      final content = lines.join('\r\n');
      final bytes = utf8.encode(content);
      final filename =
          '${run.runNumber ?? 'payment_run'}.${fmt.fileExtension}';

      if (!mounted) return;
      await downloadFile(bytes, filename);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ดาวน์โหลดไฟล์ $filename สำเร็จ')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('สร้างไฟล์ล้มเหลว: $e'),
                backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showRaPreview() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: SizedBox(
          width: 820,
          height: 700,
          child: Column(children: [
            Container(
              color: Colors.blue[700],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                const Icon(Icons.picture_as_pdf, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('ใบแจ้งรายการโอนเงิน (Remittance Advice)',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ),
                IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    onPressed: () => Navigator.of(ctx).pop()),
              ]),
            ),
            Expanded(
              child: PdfPreview(
                build: (format) => _buildRaPdf(format),
                initialPageFormat: PdfPageFormat.a4,
                canChangeOrientation: false,
                canDebug: false,
                pdfFileName:
                    'RA_${widget.run?.runNumber ?? 'draft'}.pdf',
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Post GL ───────────────────────────────────────────────────────────────

  Future<void> _postGl() async {
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    final run = widget.run;
    if (run == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการบันทึก GL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('บันทึก GL สำหรับ Payment Run: ${run.runNumber}'),
            const SizedBox(height: 8),
            Text('จำนวนรายการ: ${run.lines.length} รายการ',
                style: const TextStyle(fontSize: 13)),
            Text(
              'ยอดรวม: ${_fmt.format(run.totalAmountLc)} บาท',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              'ระบบจะสร้างรายการบัญชี GL และเปลี่ยนสถานะเป็น "สำเร็จ"\n'
              'การดำเนินการนี้ไม่สามารถย้อนกลับได้',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
            child: const Text('บันทึก GL',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final result = await widget.svc.postGl(run.id!);
      final glDocNo = result['gl_doc_no'] ?? '';
      if (mounted) {
        widget.onRefresh();
        final updated = await widget.svc.fetchRow(run.id!);
        if (mounted) {
          widget.onSaved(updated);
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Row(children: [
                Icon(Icons.check_circle, color: Colors.green[700]),
                const SizedBox(width: 8),
                const Text('บันทึก GL สำเร็จ'),
              ]),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Payment Run: ${updated.runNumber}'),
                  Text('GL Document: $glDocNo',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('สถานะ: ${apPaymentRunStatusLabels[updated.status] ?? updated.status}'),
                ],
              ),
              actions: [
                ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('ตกลง')),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('บันทึก GL ล้มเหลว: $e'),
                backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openInvoicePicker() async {
    final existingTxnIds = _lineRows.map((r) => r.source.apTransactionId).toSet();
    final added = await showDialog<List<ApPaymentRunLine>>(
      context: context,
      builder: (ctx) => _InvoicePickerDialog(
        svc: widget.svc,
        existingTxnIds: existingTxnIds,
      ),
    );
    if (added == null || added.isEmpty || !mounted) return;
    setState(() {
      for (final line in added) {
        _lineRows.add(_LineRow(line));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
    final status = widget.run?.status ?? 'Draft';
    final canVoid = widget.run != null && ['Draft', 'Submitted'].contains(status);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // ── Header bar ────────────────────────────────────────────────────
      Container(
        color: Colors.blue[300],
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Text(
            widget.run?.runNumber ?? '(ใหม่)',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(width: 12),
          if (widget.run != null) _statusChip(status),
          const Spacer(),
          if (_saving) const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          if (!_saving && _isDraft) ...[
            TextButton.icon(
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: const Text('ยกเลิก'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: widget.onCancel,
            ),
            const SizedBox(width: 4),
            ElevatedButton.icon(
              icon: const Icon(Icons.save, size: 16),
              label: const Text('บันทึก'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue[700]),
              onPressed: _save,
            ),
          ],
          if (!_saving && widget.run != null && status == 'Draft') ...[
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.send, size: 16),
              label: const Text('ส่งอนุมัติ'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[100],
                  foregroundColor: Colors.orange[800]),
              onPressed: _submit,
            ),
          ],
          if (!_saving && canVoid) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              icon: const Icon(Icons.block, size: 16),
              label: const Text('ยกเลิกเอกสาร'),
              style: TextButton.styleFrom(foregroundColor: Colors.red[200]),
              onPressed: _void,
            ),
          ],
          if (!_saving && !_isDraft && !canVoid) ...[
            if (status == 'Approved' && widget.run!.lines.isNotEmpty) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.account_balance, size: 16),
                label: const Text('บันทึก GL'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white),
                onPressed: _postGl,
              ),
              const SizedBox(width: 8),
            ],
            if (['Approved', 'Completed'].contains(status) &&
                widget.run!.lines.isNotEmpty) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf, size: 16),
                label: const Text('พิมพ์ RA'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[600],
                    foregroundColor: Colors.white),
                onPressed: _showRaPreview,
              ),
              const SizedBox(width: 8),
              if (_bankFmtId != null) ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('สร้างไฟล์ธนาคาร'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo[600],
                      foregroundColor: Colors.white),
                  onPressed: _generateBankFile,
                ),
                const SizedBox(width: 8),
              ],
            ],
            TextButton.icon(
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('กลับ'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: widget.onCancel,
            ),
          ],
        ]),
      ),
      // ── Form fields ───────────────────────────────────────────────────
      Container(
        color: Colors.blue.shade50,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: Wrap(spacing: 16, runSpacing: 8, children: [
          // Run date
          SizedBox(
            width: 180,
            child: InkWell(
              onTap: _readOnly ? null : () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _runDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2099),
                );
                if (d != null) setState(() => _runDate = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                    labelText: 'วันที่',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                child: Row(children: [
                  Expanded(child: Text(_dateFmt.format(_runDate))),
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                ]),
              ),
            ),
          ),
          // Description
          SizedBox(
            width: 280,
            child: TextField(
              controller: _descCtrl,
              readOnly: _readOnly,
              decoration: const InputDecoration(
                  labelText: 'คำอธิบาย',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            ),
          ),
          // Bank file format
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<int?>(
              value: _bankFmtId,
              decoration: const InputDecoration(
                  labelText: 'รูปแบบไฟล์ธนาคาร',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              items: [
                const DropdownMenuItem(value: null, child: Text('(ไม่ระบุ)')),
                ..._fmtOptions.map((f) => DropdownMenuItem(
                      value: f.id,
                      child: Text('${f.formatCode} - ${f.formatName}',
                          overflow: TextOverflow.ellipsis),
                    )),
              ],
              onChanged: _readOnly
                  ? null
                  : (v) => setState(() => _bankFmtId = v),
            ),
          ),
          // GL reference — shown after posting
          if (widget.run?.glDocNo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.account_balance, size: 14, color: Colors.green[700]),
                const SizedBox(width: 4),
                Text('GL: ${widget.run!.glDocNo}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                        fontSize: 13)),
              ]),
            ),
        ]),
      ),
      // ── Lines toolbar ─────────────────────────────────────────────────
      if (_isDraft)
        Container(
          color: Colors.blue.shade50,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('เลือกใบแจ้งหนี้'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white),
              onPressed: _openInvoicePicker,
            ),
            const SizedBox(width: 8),
            Text('${_lineRows.length} รายการ',
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ]),
        ),
      // ── Approvals panel (shown for non-Draft/non-Void) ───────────────
      if (widget.run != null && !['Draft', 'Void'].contains(status))
        _ApprovalPanel(
          run: widget.run!,
          svc: widget.svc,
          onActionDone: () async {
            widget.onRefresh();
            final updated = await widget.svc.fetchRow(widget.run!.id!);
            if (mounted) widget.onSaved(updated);
          },
        ),
      // ── Lines table ───────────────────────────────────────────────────
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Header + data share ONE horizontal scroll so they stay in sync
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: _wVendor + _wVendorNm + _wBank + _wAccNo + _wInvNo +
                    _wDate * 2 + _wAmt * 2 + (_isDraft ? _wAct : 0),
                child: Column(children: [
                  // Table header (moves with horizontal scroll)
                  Container(
                    color: Colors.blue[100],
                    child: _TableHeader(isDraft: _isDraft),
                  ),
                  // Data rows — vertical scroll via ListView.builder
                  Expanded(
                    child: _lineRows.isEmpty
                        ? Center(child: Text('ยังไม่มีรายการ',
                            style: TextStyle(color: Colors.grey[500])))
                        : ListView.builder(
                            itemCount: _lineRows.length,
                            itemBuilder: (ctx, i) {
                              final row = _lineRows[i];
                              return _LineWidget(
                                key: ValueKey(row.source.apTransactionId),
                                row: row,
                                isDraft: _isDraft,
                                onDelete: () => setState(() {
                                  _lineRows.removeAt(i).dispose();
                                }),
                                onAmtChanged: () => setState(() {}),
                              );
                            },
                          ),
                  ),
                ]),
              ),
            ),
          ),
          // Total row — always visible, outside of scroll area
          Container(
            color: Colors.blue[50],
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: Row(children: [
              const Spacer(),
              Text('รวมทั้งสิ้น: ',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800])),
              SizedBox(
                width: _wAmt,
                child: Text(_fmt.format(_totalPayment),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                        fontSize: 14)),
              ),
              if (_isDraft) const SizedBox(width: _wAct),
            ]),
          ),
        ]),
      ),
    ]);
  }
}

// ── Table header row ──────────────────────────────────────────────────────────
class _TableHeader extends StatelessWidget {
  final bool isDraft;
  const _TableHeader({required this.isDraft});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _hCell('รหัสเจ้าหนี้',  _wVendor),
      _hCell('ชื่อเจ้าหนี้',  _wVendorNm),
      _hCell('ธนาคาร',        _wBank),
      _hCell('เลขที่บัญชี',   _wAccNo),
      _hCell('เลขที่ใบแจ้งหนี้', _wInvNo),
      _hCell('วันที่ใบ',      _wDate),
      _hCell('วันครบกำหนด',   _wDate),
      _hCell('ยอดใบแจ้งหนี้', _wAmt, right: true),
      _hCell('ยอดชำระ',       _wAmt, right: true),
      if (isDraft) _hCell('',  _wAct),
    ]);
  }

  Widget _hCell(String label, double w, {bool right = false}) => Container(
        width: w,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        alignment: right ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800])),
      );
}

// ── Line row widget ───────────────────────────────────────────────────────────
class _LineWidget extends StatelessWidget {
  final _LineRow row;
  final bool isDraft;
  final VoidCallback onDelete;
  final VoidCallback onAmtChanged;

  const _LineWidget({
    super.key,
    required this.row,
    required this.isDraft,
    required this.onDelete,
    required this.onAmtChanged,
  });

  @override
  Widget build(BuildContext context) {
    final s = row.source;
    return Container(
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0)))),
      child: Row(children: [
        _cell(s.vendorCode,                                    _wVendor),
        _cell(s.vendorNameTh,                                  _wVendorNm),
        _cell('${s.bankName ?? ''}\n${s.bankBranchName ?? ''}',_wBank, wrap: true),
        _cell(s.accountNumber ?? '',                           _wAccNo),
        _cell(s.invoiceNo,                                     _wInvNo),
        _cell(_fmtDate(s.invoiceDate),                         _wDate),
        _cell(_fmtDate(s.dueDate),                             _wDate),
        _amtCell(_fmt.format(s.invoiceAmountLc)),
        // Editable payment amount
        isDraft
            ? Container(
                width: _wAmt,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: TextField(
                  controller: row.amtCtrl,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      border: OutlineInputBorder()),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  onChanged: (_) => onAmtChanged(),
                ),
              )
            : _amtCell(_fmt.format(s.paymentAmountLc)),
        if (isDraft)
          SizedBox(
            width: _wAct,
            child: IconButton(
                icon: const Icon(Icons.delete_outline, size: 16),
                color: Colors.red[300],
                onPressed: onDelete),
          ),
      ]),
    );
  }

  Widget _cell(String text, double w, {bool wrap = false}) => Container(
        width: w,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        alignment: Alignment.centerLeft,
        child: Text(text,
            maxLines: wrap ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12)),
      );

  Widget _amtCell(String text) => Container(
        width: _wAmt,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        alignment: Alignment.centerRight,
        child: Text(text, style: const TextStyle(fontSize: 12)),
      );
}

// ── Invoice picker dialog ─────────────────────────────────────────────────────
class _InvoicePickerDialog extends StatefulWidget {
  final ApPaymentRunService svc;
  final Set<int> existingTxnIds;

  const _InvoicePickerDialog({
    required this.svc,
    required this.existingTxnIds,
  });

  @override
  State<_InvoicePickerDialog> createState() => _InvoicePickerDialogState();
}

class _InvoicePickerDialogState extends State<_InvoicePickerDialog> {
  final _vendorCtrl = TextEditingController();
  DateTime? _dateFrom;
  DateTime? _dateTo;

  List<ApOpenInvoice> _invoices = [];
  final Set<int> _selected = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _vendorCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final rows = await widget.svc.fetchOpenInvoices(
        vendorCode: _vendorCtrl.text.trim().isEmpty ? null : _vendorCtrl.text.trim(),
        dateFrom: _dateFrom == null ? null : DateFormat('yyyy-MM-dd').format(_dateFrom!),
        dateTo:   _dateTo   == null ? null : DateFormat('yyyy-MM-dd').format(_dateTo!),
      );
      if (mounted) {
        setState(() {
          _invoices = rows.where((r) => !widget.existingTxnIds.contains(r.txnId)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addSelected() {
    final lines = _invoices
        .where((inv) => _selected.contains(inv.txnId))
        .map((inv) => ApPaymentRunLine(
              apTransactionId: inv.txnId,
              vendorId: inv.vendorId,
              vendorCode: inv.vendorCode,
              vendorNameTh: inv.vendorNameTh,
              bankName: inv.bankName,
              bankBranchName: inv.bankBranchName,
              accountNumber: inv.accountNumber,
              accountName: inv.accountName,
              invoiceNo: inv.docNo,
              invoiceDate: inv.docDate,
              dueDate: inv.dueDate,
              invoiceAmountLc: inv.totalAmountLc,
              paymentAmountLc: inv.balanceAmountLc,
              currencyCode: inv.currencyCode,
              exchangeRate: inv.exchangeRate,
            ))
        .toList();
    Navigator.of(context).pop(lines);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
    return Dialog(
      child: SizedBox(
        width: 900,
        height: 600,
        child: Column(children: [
          // Title
          Container(
            color: Colors.blue[700],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              const Icon(Icons.receipt_long, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('เลือกใบแจ้งหนี้',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ),
              IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                  onPressed: () => Navigator.of(context).pop(null)),
            ]),
          ),
          // Filter row
          Container(
            color: Colors.blue.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _vendorCtrl,
                  decoration: const InputDecoration(
                      labelText: 'รหัสเจ้าหนี้',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              _DateBtn(
                label: 'วันที่จาก',
                date: _dateFrom,
                onPick: (d) => setState(() => _dateFrom = d),
              ),
              const SizedBox(width: 8),
              _DateBtn(
                label: 'วันที่ถึง',
                date: _dateTo,
                onPick: (d) => setState(() => _dateTo = d),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.search, size: 16),
                label: const Text('ค้นหา'),
                onPressed: _search,
              ),
              const Spacer(),
              Text('${_selected.length} รายการที่เลือก',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ]),
          ),
          // Table header
          Container(
            color: Colors.blue[100],
            child: Row(children: [
              SizedBox(width: 40, child: Checkbox(
                tristate: true,
                value: _selected.isEmpty ? false : (_selected.length == _invoices.length ? true : null),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selected.addAll(_invoices.map((i) => i.txnId));
                  } else {
                    _selected.clear();
                  }
                }),
              )),
              _ph('รหัสเจ้าหนี้', 110),
              _ph('ชื่อเจ้าหนี้', 160),
              _ph('เลขที่บัญชี', 120),
              _ph('เลขที่ใบแจ้งหนี้', 130),
              _ph('วันที่ใบ', 90),
              _ph('วันครบกำหนด', 90),
              _ph('ยอดใบแจ้งหนี้', 110, right: true),
              _ph('ยอดคงเหลือ', 110, right: true),
            ]),
          ),
          // Rows
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _invoices.isEmpty
                    ? Center(child: Text('ไม่พบใบแจ้งหนี้ที่ค้างชำระ',
                        style: TextStyle(color: Colors.grey[500])))
                    : ListView.builder(
                        itemCount: _invoices.length,
                        itemBuilder: (ctx, i) {
                          final inv = _invoices[i];
                          final sel = _selected.contains(inv.txnId);
                          return Container(
                            decoration: BoxDecoration(
                                color: sel ? Colors.blue.shade50 : null,
                                border: const Border(
                                    bottom: BorderSide(color: Color(0xFFE0E0E0)))),
                            child: InkWell(
                              onTap: () => setState(() {
                                if (sel) {
                                  _selected.remove(inv.txnId);
                                } else {
                                  _selected.add(inv.txnId);
                                }
                              }),
                              child: Row(children: [
                                SizedBox(width: 40,
                                    child: Checkbox(
                                        value: sel,
                                        onChanged: (v) => setState(() {
                                              if (v == true) {
                                                _selected.add(inv.txnId);
                                              } else {
                                                _selected.remove(inv.txnId);
                                              }
                                            }))),
                                _pd(inv.vendorCode, 110),
                                _pd(inv.vendorNameTh, 160),
                                _pd(inv.accountNumber ?? '', 120),
                                _pd(inv.docNo, 130),
                                _pd(_fmtDate(inv.docDate), 90),
                                _pd(_fmtDate(inv.dueDate), 90),
                                _pd(_fmt.format(inv.totalAmountLc), 110, right: true),
                                _pd(_fmt.format(inv.balanceAmountLc), 110,
                                    right: true,
                                    color: Colors.blue[700]),
                              ]),
                            ),
                          );
                        }),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.all(10),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('ยกเลิก')),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: Text('เพิ่ม ${_selected.length} รายการ'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white),
                onPressed: _selected.isEmpty ? null : _addSelected,
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _ph(String label, double w, {bool right = false}) => Container(
        width: w,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        alignment: right ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800])),
      );

  Widget _pd(String text, double w, {bool right = false, Color? color}) => Container(
        width: w,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        alignment: right ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: color)),
      );
}

// ── Approval panel ───────────────────────────────────────────────────────────
class _ApprovalPanel extends StatefulWidget {
  final ApPaymentRun run;
  final ApPaymentRunService svc;
  final VoidCallback onActionDone;

  const _ApprovalPanel({
    required this.run,
    required this.svc,
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
      default:         return Colors.orange[700]!;
    }
  }

  String _approvalLabel(String s) {
    switch (s) {
      case 'Approved': return 'อนุมัติแล้ว';
      case 'Rejected': return 'ปฏิเสธ';
      default:         return 'รออนุมัติ';
    }
  }

  Future<void> _doAction(bool isApprove) async {
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    final currentUserId =
        Provider.of<AuthService>(context, listen: false).currentUser?.id;
    final approvals = widget.run.approvals;

    // Check if current user has a pending record that's actionable (all prev approved)
    final myRecord = approvals
        .where((a) => a.approverUserId == currentUserId && a.status == 'Pending')
        .toList();
    if (myRecord.isEmpty) return;

    final mySeq = myRecord.first.sequenceNo;
    final blockedByPrev = approvals
        .any((a) => a.sequenceNo < mySeq && a.status == 'Pending');
    if (blockedByPrev) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('ยังรอการอนุมัติจากลำดับก่อนหน้า')));
      return;
    }

    // Show remarks dialog
    final remarksCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isApprove ? 'ยืนยันการอนุมัติ' : 'ยืนยันการปฏิเสธ'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(isApprove
              ? 'อนุมัติ ${widget.run.runNumber}?'
              : 'ปฏิเสธ ${widget.run.runNumber}?'),
          const SizedBox(height: 12),
          TextField(
            controller: remarksCtrl,
            decoration: const InputDecoration(
                labelText: 'หมายเหตุ (ถ้ามี)',
                border: OutlineInputBorder(),
                isDense: true),
            maxLines: 2,
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isApprove ? Colors.green[700] : Colors.red[700],
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isApprove ? 'อนุมัติ' : 'ปฏิเสธ')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _acting = true);
    try {
      final remarks =
          remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim();
      if (isApprove) {
        await widget.svc.approveRun(widget.run.id!, remarks: remarks);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('อนุมัติสำเร็จ')));
        }
      } else {
        await widget.svc.rejectRun(widget.run.id!, remarks: remarks);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('ปฏิเสธสำเร็จ')));
        }
      }
      widget.onActionDone();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        Provider.of<AuthService>(context, listen: false).currentUser?.id;
    final approvals = widget.run.approvals;
    if (approvals.isEmpty) return const SizedBox.shrink();

    final myPending = approvals.firstWhere(
        (a) => a.approverUserId == currentUserId && a.status == 'Pending',
        orElse: () => const ApPaymentRunApproval(
            id: -1, runId: -1, approverUserId: -1,
            approverUserName: '', sequenceNo: 0, status: ''));
    final canAct = myPending.id != -1 &&
        !approvals.any(
            (a) => a.sequenceNo < myPending.sequenceNo && a.status == 'Pending');

    return Container(
      color: Colors.orange.shade50,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.approval_outlined, size: 16, color: Colors.orange[800]),
          const SizedBox(width: 6),
          Text('ขั้นตอนการอนุมัติ',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.orange[800])),
          const Spacer(),
          if (_acting)
            const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
          if (!_acting && canAct) ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline, size: 14),
              label: const Text('อนุมัติ', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              onPressed: () => _doAction(true),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.cancel_outlined, size: 14),
              label: const Text('ปฏิเสธ', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
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
              Text('${a.sequenceNo}. ${a.approverUserName}',
                  style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                    color: _approvalColor(a.status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _approvalColor(a.status).withOpacity(0.6))),
                child: Text(_approvalLabel(a.status),
                    style: TextStyle(
                        fontSize: 10,
                        color: _approvalColor(a.status),
                        fontWeight: FontWeight.w600)),
              ),
              if (a.approvedAt != null) ...[
                const SizedBox(width: 4),
                Text(_dateFmt.format(a.approvedAt!),
                    style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              ],
              if (a.remarks != null && a.remarks!.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text('(${a.remarks!})',
                    style:
                        TextStyle(fontSize: 10, color: Colors.grey[600])),
              ],
            ]);
          }).toList(),
        ),
      ]),
    );
  }
}

// ── Small date button ─────────────────────────────────────────────────────────
class _DateBtn extends StatelessWidget {
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime?> onPick;
  const _DateBtn({required this.label, required this.date, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2099),
        );
        onPick(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            suffixIcon: date != null
                ? GestureDetector(
                    onTap: () => onPick(null),
                    child: const Icon(Icons.clear, size: 14))
                : null),
        child: SizedBox(
          width: 90,
          child: Text(date == null ? '' : DateFormat('dd/MM/yyyy').format(date!),
              style: const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}
