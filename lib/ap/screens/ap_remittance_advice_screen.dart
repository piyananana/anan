// lib/ap/screens/ap_remittance_advice_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../utils/date_utils.dart';

final _fmt     = NumberFormat('#,##0.00', 'en_US');
final _dateFmt = DateFormat('dd/MM/yyyy');

class ApRemittanceAdviceScreen extends StatefulWidget {
  const ApRemittanceAdviceScreen({super.key});
  @override
  State<ApRemittanceAdviceScreen> createState() => _ApRemittanceAdviceScreenState();
}

class _ApRemittanceAdviceScreenState extends State<ApRemittanceAdviceScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isLeftExpanded = true;
  double _leftWidth = 280;
  bool _isDraggingDivider = false;
  bool _isEnglish = false;

  // filters
  DateTime? _fDateFrom;
  DateTime? _fDateTo;
  String    _fStatus = 'Cleared';

  List<Map<String, dynamic>> _payments = [];
  final Set<int> _selected = {};
  bool _loading     = false;
  bool _generating  = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fDateFrom = DateTime(now.year, now.month, 1);
    _fDateTo   = now;
    _loadPayments();
  }

  Future<Map<String, String>> _headers() async => AuthService().getAuthHeader();

  String _payeeName(Map<String, dynamic> p) {
    final nameTh = p['payee_name_th'] ?? '';
    final nameEn = p['payee_name_en'] ?? '';
    return _isEnglish && (nameEn as String).isNotEmpty ? nameEn : nameTh;
  }

  String _bankAccountLabel(Map<String, dynamic> p) {
    final code = p['bank_account_code'] ?? '';
    final nameTh = p['bank_account_name'] ?? '';
    final nameEn = p['bank_account_name_en'] ?? '';
    final name = _isEnglish && (nameEn as String).isNotEmpty ? nameEn : nameTh;
    return '$code $name'.trim();
  }

  Future<void> _loadPayments() async {
    setState(() => _loading = true);
    try {
      final h = await _headers();
      final params = <String, String>{'status': _fStatus};
      if (_fDateFrom != null) params['date_from'] = formatLocalDate(_fDateFrom!);
      if (_fDateTo   != null) params['date_to']   = formatLocalDate(_fDateTo!);
      final uri = Uri.parse('${AppConfig.apiCm}/cm_payment')
          .replace(queryParameters: params);
      final r = await http.get(uri, headers: h);
      if (r.statusCode == 200) {
        final d = json.decode(r.body) as List;
        setState(() {
          _payments = d.cast<Map<String, dynamic>>();
          _selected.clear();
        });
      }
    } catch (e) { _showErr('$e'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _printSingle(Map<String, dynamic> payment) async {
    final l = AppL10n(Provider.of<LanguageProvider>(context, listen: false).isEnglish);
    final id = payment['id'] as int?;
    if (id == null) return;
    setState(() => _generating = true);
    try {
      final h = await _headers();
      final r = await http.get(
          Uri.parse('${AppConfig.apiAp}/ap_remittance_advice/$id'), headers: h);
      if (r.statusCode != 200) {
        _showErr(l.isEnglish ? 'Failed to load data' : 'โหลดข้อมูลไม่สำเร็จ');
        return;
      }
      final data = json.decode(r.body) as Map<String, dynamic>;
      final pdfBytes = await _buildPdf(data);
      if (!mounted) return;
      await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
    } catch (e) { _showErr('$e'); }
    finally { if (mounted) setState(() => _generating = false); }
  }

  Future<void> _printBatch() async {
    final l = AppL10n(Provider.of<LanguageProvider>(context, listen: false).isEnglish);
    if (_selected.isEmpty) {
      _showErr(l.isEnglish ? 'Please select item(s) first' : 'กรุณาเลือกรายการก่อน');
      return;
    }
    setState(() => _generating = true);
    try {
      final h = await _headers();
      final ids = _selected.toList();
      final uri = Uri.parse('${AppConfig.apiAp}/ap_remittance_advice/batch')
          .replace(queryParameters: {'payment_ids': ids.join(',')});
      final r = await http.get(uri, headers: h);
      if (r.statusCode != 200) {
        _showErr(l.isEnglish ? 'Failed to load data' : 'โหลดข้อมูลไม่สำเร็จ');
        return;
      }
      final data = json.decode(r.body) as List;
      if (!mounted) return;

      // Build one PDF page per payment
      final doc = pw.Document();
      for (final d in data) {
        await _addPageToDoc(doc, d as Map<String, dynamic>);
      }
      final bytes = await doc.save();
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) { _showErr('$e'); }
    finally { if (mounted) setState(() => _generating = false); }
  }

  Future<Uint8List> _buildPdf(Map<String, dynamic> data) async {
    final doc = pw.Document();
    await _addPageToDoc(doc, data);
    return doc.save();
  }

  Future<void> _addPageToDoc(pw.Document doc, Map<String, dynamic> data) async {
    final isEnglish = _isEnglish;
    final font = await PdfGoogleFonts.sarabunRegular();
    final fontBold = await PdfGoogleFonts.sarabunBold();

    final company   = (data['company']  as Map<String, dynamic>?) ?? {};
    final payment   = (data['payment']  as Map<String, dynamic>?) ?? {};
    final vendor    = (data['vendor']   as Map<String, dynamic>?) ?? {};
    final invoices  = (data['invoices'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final companyName = isEnglish && (company['company_name_en'] ?? '').toString().isNotEmpty
        ? company['company_name_en']
        : (company['company_name_th'] ?? '');
    final vendorName = isEnglish && (vendor['vendor_name_en'] ?? '').toString().isNotEmpty
        ? vendor['vendor_name_en']
        : (vendor['vendor_name_th'] ?? '');
    final bankName = isEnglish && (payment['bank_name_en'] ?? '').toString().isNotEmpty
        ? payment['bank_name_en']
        : (payment['bank_name_th'] ?? '');
    final paymentMethodName = isEnglish && (payment['payment_method_name_en'] ?? '').toString().isNotEmpty
        ? payment['payment_method_name_en']
        : (payment['payment_method_name_th'] ?? payment['payment_method_type'] ?? '');

    final payDate = parseLocalDateNullable(payment['payment_date']);

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(companyName, style: pw.TextStyle(font: fontBold, fontSize: 14)),
                  if ((company['address'] ?? '').toString().isNotEmpty)
                    pw.Text(company['address'] as String, style: pw.TextStyle(font: font, fontSize: 9)),
                  if ((company['tax_id'] ?? '').toString().isNotEmpty)
                    pw.Text('${isEnglish ? 'Tax ID' : 'เลขที่ผู้เสียภาษี'}: ${company['tax_id']}',
                        style: pw.TextStyle(font: font, fontSize: 9)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('ใบแจ้งการชำระเงิน', style: pw.TextStyle(font: fontBold, fontSize: 16)),
                  pw.Text('Remittance Advice', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                  pw.Text('${isEnglish ? 'No.' : 'เลขที่'}: ${payment['ap_doc_no'] ?? payment['id'] ?? ''}',
                      style: pw.TextStyle(font: fontBold, fontSize: 10)),
                  if (payDate != null)
                    pw.Text('${isEnglish ? 'Date' : 'วันที่'}: ${_dateFmt.format(payDate)}',
                        style: pw.TextStyle(font: font, fontSize: 10)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(),
          pw.SizedBox(height: 8),

          // Vendor info
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(isEnglish ? 'To:' : 'เรียน / To:', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                  pw.Text(vendorName, style: pw.TextStyle(font: fontBold, fontSize: 11)),
                  if ((vendor['bank_account_number'] ?? '').toString().isNotEmpty)
                    pw.Text(
                        '${isEnglish ? 'Receiving account' : 'บัญชีรับเงิน'}: '
                        '${vendor['bank_name'] ?? ''} ${vendor['bank_account_number'] ?? ''} '
                        '${vendor['bank_account_name'] ?? ''}',
                        style: pw.TextStyle(font: font, fontSize: 9)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('${isEnglish ? 'Payment method' : 'วิธีการชำระ'}: $paymentMethodName',
                      style: pw.TextStyle(font: font, fontSize: 10)),
                  pw.Text(
                      '${isEnglish ? 'Paid from' : 'จ่ายจากบัญชี'}: '
                      '$bankName ${payment['bank_account_code'] ?? ''} ${payment['bank_account_number'] ?? ''}',
                      style: pw.TextStyle(font: font, fontSize: 10)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),

          // Invoice table
          if (invoices.isNotEmpty)
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(2.5),
                1: pw.FlexColumnWidth(1.5),
                2: pw.FlexColumnWidth(1.5),
                3: pw.FlexColumnWidth(2),
                4: pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    isEnglish ? 'Invoice No.' : 'เลขที่ใบแจ้งหนี้',
                    isEnglish ? 'Invoice Date' : 'วันที่ใบ',
                    isEnglish ? 'Due Date' : 'วันครบกำหนด',
                    isEnglish ? 'Invoice Amount' : 'ยอดใบแจ้งหนี้',
                    isEnglish ? 'This Payment' : 'ชำระครั้งนี้',
                  ]
                      .map((h) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                          child: pw.Text(h, style: pw.TextStyle(font: fontBold, fontSize: 9))))
                      .toList(),
                ),
                ...invoices.map((inv) {
                  final invDate = parseLocalDateNullable(inv['invoice_date']);
                  final dueDate = parseLocalDateNullable(inv['due_date']);
                  return pw.TableRow(children: [
                    inv['doc_no'] ?? '',
                    invDate != null ? _dateFmt.format(invDate) : '',
                    dueDate != null ? _dateFmt.format(dueDate) : '',
                    _fmt.format((inv['total_amount'] as num?)?.toDouble() ?? 0),
                    _fmt.format((inv['this_payment'] as num?)?.toDouble() ?? 0),
                  ].map((v) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                      child: pw.Text(v.toString(), style: pw.TextStyle(font: font, fontSize: 9)))).toList(),
                  );
                }),
              ],
            ),
          pw.SizedBox(height: 8),

          // Total
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    border: pw.Border.all(color: PdfColors.blue200)),
                child: pw.Text(
                  '${isEnglish ? 'Total payment' : 'ยอดชำระทั้งสิ้น'}: '
                  '${_fmt.format((payment['amount_lc'] as num?)?.toDouble() ?? 0)}'
                  '${isEnglish ? '' : ' บาท'}',
                  style: pw.TextStyle(font: fontBold, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    ));
  }

  void _showErr(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final l = AppL10n(isEnglish);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        title: const MenuTitle(),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: l.refresh, onPressed: _loadPayments),
          const SizedBox(width: 4),
          if (_selected.isNotEmpty)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: _generating ? null : _printBatch,
              icon: const Icon(Icons.print, size: 16),
              label: Text(
                  isEnglish ? 'Print (${_selected.length})' : 'พิมพ์ (${_selected.length})',
                  style: const TextStyle(fontSize: 13)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final double maxLeftWidth =
            (constraints.maxWidth - 36 - 5 - 300).clamp(100.0, double.infinity);
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Toggle strip
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
              tooltip: _isLeftExpanded
                  ? (isEnglish ? 'Collapse panel' : 'ย่อแผง')
                  : (isEnglish ? 'Expand panel' : 'ขยายแผง'),
            ),
          ),
          // Left panel – filters
          AnimatedContainer(
            duration: _isDraggingDivider ? Duration.zero : const Duration(milliseconds: 200),
            width: _isLeftExpanded ? _leftWidth : 0.0,
            child: ClipRect(
              child: OverflowBox(
                maxWidth: _leftWidth,
                minWidth: _leftWidth,
                alignment: Alignment.topLeft,
                child: ColoredBox(
                  color: Colors.blueGrey.shade100,
                  child: SizedBox(
                    width: _leftWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          color: Colors.blueGrey.shade200,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Column(children: [
                            _datePicker(isEnglish ? 'Start Date' : 'วันที่เริ่ม', _fDateFrom,
                                (d) { setState(() => _fDateFrom = d); _loadPayments(); }),
                            const SizedBox(height: 8),
                            _datePicker(isEnglish ? 'End Date' : 'วันที่สิ้นสุด', _fDateTo,
                                (d) { setState(() => _fDateTo = d); _loadPayments(); }),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _fStatus,
                              decoration: InputDecoration(
                                  labelText: l.status, isDense: true,
                                  filled: true, fillColor: Colors.white,
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                              items: [
                                DropdownMenuItem(value: 'Cleared', child: Text(isEnglish ? 'Cleared' : 'เคลียร์แล้ว', style: const TextStyle(fontSize: 13))),
                                DropdownMenuItem(value: 'Pending', child: Text(l.pending, style: const TextStyle(fontSize: 13))),
                                DropdownMenuItem(value: '', child: Text(l.all, style: const TextStyle(fontSize: 13))),
                              ],
                              onChanged: (v) { setState(() => _fStatus = v ?? ''); _loadPayments(); },
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 34),
                                  padding: EdgeInsets.zero),
                              onPressed: _loadPayments,
                              icon: const Icon(Icons.refresh, size: 15),
                              label: Text(l.refresh, style: const TextStyle(fontSize: 13)),
                            ),
                          ]),
                        ),
                        Expanded(
                          child: Container(
                            color: Colors.blueGrey.shade50,
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              isEnglish
                                  ? 'Selected ${_selected.length} / ${_payments.length} item(s)'
                                  : 'เลือก ${_selected.length} / ${_payments.length} รายการ',
                              style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Resizable divider
          if (_isLeftExpanded)
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                onHorizontalDragStart: (_) => setState(() => _isDraggingDivider = true),
                onHorizontalDragUpdate: (details) => setState(() {
                  _leftWidth = (_leftWidth + details.delta.dx).clamp(200.0, maxLeftWidth);
                }),
                onHorizontalDragEnd: (_) => setState(() => _isDraggingDivider = false),
                child: Container(width: 5, color: Colors.grey[400]),
              ),
            ),
          // Right panel – payment list
          Expanded(
            child: Column(children: [
              // Column headers
              Container(
                color: Colors.blueGrey.shade200,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(children: [
                  Checkbox(
                    value: _payments.isNotEmpty && _selected.length == _payments.length,
                    tristate: _selected.isNotEmpty && _selected.length < _payments.length,
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _selected.addAll(_payments.map((p) => p['id'] as int));
                      } else {
                        _selected.clear();
                      }
                    }),
                  ),
                  Expanded(flex: 2, child: Text(isEnglish ? 'Reference' : 'เลขที่อ้างอิง', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text(isEnglish ? 'Payee' : 'ผู้รับเงิน', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text(isEnglish ? 'Bank Account' : 'บัญชีธนาคาร', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  SizedBox(width: 90, child: Text(l.date, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  SizedBox(width: 110, child: Text(l.amount, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                  SizedBox(width: 80, child: Text(isEnglish ? 'Action' : 'การดำเนินการ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                ]),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _payments.isEmpty
                        ? Center(child: Text(l.noData, style: TextStyle(color: Colors.blueGrey.shade400)))
                        : ListView.builder(
                            itemCount: _payments.length,
                            itemBuilder: (_, i) {
                              final p = _payments[i];
                              final id = p['id'] as int;
                              final sel = _selected.contains(id);
                              final dt = parseLocalDateNullable(p['payment_date']);
                              return Container(
                                color: sel ? Colors.blue.withOpacity(0.07) : (i.isEven ? Colors.grey.shade50 : Colors.white),
                                child: Row(children: [
                                  Checkbox(
                                    value: sel,
                                    onChanged: (v) => setState(() {
                                      if (v == true) _selected.add(id); else _selected.remove(id);
                                    }),
                                  ),
                                  Expanded(flex: 2, child: Text(p['ap_doc_no'] ?? '#$id', style: const TextStyle(fontSize: 13))),
                                  Expanded(flex: 2, child: Text(_payeeName(p), style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                                  Expanded(flex: 2, child: Text(_bankAccountLabel(p),
                                      style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                  SizedBox(width: 90, child: Text(dt != null ? _dateFmt.format(dt) : '', style: const TextStyle(fontSize: 12))),
                                  SizedBox(width: 110, child: Text(_fmt.format((p['amount_lc'] as num?)?.toDouble() ?? 0),
                                      style: const TextStyle(fontSize: 13), textAlign: TextAlign.right)),
                                  SizedBox(
                                    width: 80,
                                    child: Center(
                                      child: IconButton(
                                        iconSize: 18,
                                        padding: EdgeInsets.zero,
                                        icon: Icon(Icons.print, color: Colors.blue[700]),
                                        tooltip: l.print_,
                                        onPressed: _generating ? null : () => _printSingle(p),
                                      ),
                                    ),
                                  ),
                                ]),
                              );
                            },
                          ),
              ),
            ]),
          ),
        ]);
      }),
    );
  }

  Widget _datePicker(String label, DateTime? value, void Function(DateTime) onPick) =>
      InkWell(
        onTap: () async {
          final d = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (d != null) onPick(d);
        },
        child: InputDecorator(
          decoration: InputDecoration(
              labelText: label, isDense: true,
              filled: true, fillColor: Colors.white,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
          child: Text(value != null ? _dateFmt.format(value) : '-',
              style: const TextStyle(fontSize: 13)),
        ),
      );
}
