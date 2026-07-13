// lib/cm/screens/cm_remittance_advice_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/utils/sa_menu_scope.dart';

const _kTheme  = Color(0xFF1565C0);
final _fmt     = NumberFormat('#,##0.00', 'en_US');
final _dateFmt = DateFormat('dd/MM/yyyy');

class CmRemittanceAdviceScreen extends StatefulWidget {
  const CmRemittanceAdviceScreen({super.key});
  @override
  State<CmRemittanceAdviceScreen> createState() => _CmRemittanceAdviceScreenState();
}

class _CmRemittanceAdviceScreenState extends State<CmRemittanceAdviceScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _panelOpen = true;

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

  Future<void> _loadPayments() async {
    setState(() => _loading = true);
    try {
      final h = await _headers();
      final params = <String, String>{'status': _fStatus};
      if (_fDateFrom != null) params['date_from'] = DateFormat('yyyy-MM-dd').format(_fDateFrom!);
      if (_fDateTo   != null) params['date_to']   = DateFormat('yyyy-MM-dd').format(_fDateTo!);
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
    final id = payment['id'] as int?;
    if (id == null) return;
    setState(() => _generating = true);
    try {
      final h = await _headers();
      final r = await http.get(
          Uri.parse('${AppConfig.apiCm}/cm_remittance_advice/$id'), headers: h);
      if (r.statusCode != 200) { _showErr('โหลดข้อมูลไม่สำเร็จ'); return; }
      final data = json.decode(r.body) as Map<String, dynamic>;
      final pdfBytes = await _buildPdf(data);
      if (!mounted) return;
      await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
    } catch (e) { _showErr('$e'); }
    finally { if (mounted) setState(() => _generating = false); }
  }

  Future<void> _printBatch() async {
    if (_selected.isEmpty) { _showErr('กรุณาเลือกรายการก่อน'); return; }
    setState(() => _generating = true);
    try {
      final h = await _headers();
      final ids = _selected.toList();
      final uri = Uri.parse('${AppConfig.apiCm}/cm_remittance_advice/batch')
          .replace(queryParameters: {'payment_ids': ids.join(',')});
      final r = await http.get(uri, headers: h);
      if (r.statusCode != 200) { _showErr('โหลดข้อมูลไม่สำเร็จ'); return; }
      final data = json.decode(r.body) as List;
      if (!mounted) return;

      // Build one PDF per payee
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
    final font = await PdfGoogleFonts.sarabunRegular();
    final fontBold = await PdfGoogleFonts.sarabunBold();

    final company   = (data['company']   as Map<String, dynamic>?) ?? {};
    final payment   = (data['payment']   as Map<String, dynamic>?) ?? {};
    final vendor    = (data['vendor']    as Map<String, dynamic>?) ?? {};
    final invoices  = (data['invoices']  as List?)?.cast<Map<String, dynamic>>() ?? [];
    final bankAcc   = (data['bank_account'] as Map<String, dynamic>?) ?? {};

    DateTime? payDate;
    try { payDate = DateTime.parse(payment['payment_date'].toString()); } catch (_) {}

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
                  pw.Text(company['company_name_th'] ?? '', style: pw.TextStyle(font: fontBold, fontSize: 14)),
                  if (company['address'] != null)
                    pw.Text(company['address'] as String, style: pw.TextStyle(font: font, fontSize: 9)),
                  if (company['tax_id'] != null)
                    pw.Text('เลขที่ผู้เสียภาษี: ${company['tax_id']}', style: pw.TextStyle(font: font, fontSize: 9)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('ใบแจ้งการชำระเงิน', style: pw.TextStyle(font: fontBold, fontSize: 16)),
                  pw.Text('Remittance Advice', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                  pw.Text('เลขที่: ${payment['payment_no'] ?? ''}',
                      style: pw.TextStyle(font: fontBold, fontSize: 10)),
                  if (payDate != null)
                    pw.Text('วันที่: ${_dateFmt.format(payDate)}',
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
                  pw.Text('เรียน / To:', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                  pw.Text(vendor['vendor_name_th'] ?? vendor['vendor_name'] ?? '',
                      style: pw.TextStyle(font: fontBold, fontSize: 11)),
                  if (vendor['address'] != null)
                    pw.Text(vendor['address'] as String, style: pw.TextStyle(font: font, fontSize: 9)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('วิธีการชำระ: ${payment['payment_method_type'] ?? ''}',
                      style: pw.TextStyle(font: font, fontSize: 10)),
                  pw.Text('ธนาคาร: ${bankAcc['bank_name'] ?? ''} ${bankAcc['account_no'] ?? ''}',
                      style: pw.TextStyle(font: font, fontSize: 10)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),

          // Invoice table
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(3),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.5),
              5: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: ['เลขที่ใบแจ้งหนี้', 'วันที่', 'รายการ', 'ยอดรวม', 'ชำระแล้ว', 'ชำระครั้งนี้']
                    .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                        child: pw.Text(h, style: pw.TextStyle(font: fontBold, fontSize: 9))))
                    .toList(),
              ),
              ...invoices.map((inv) {
                DateTime? invDate;
                try { invDate = DateTime.parse(inv['invoice_date'].toString()); } catch (_) {}
                return pw.TableRow(children: [
                  inv['doc_no'] ?? '',
                  invDate != null ? _dateFmt.format(invDate) : '',
                  inv['description'] ?? '',
                  _fmt.format((inv['total_amount'] as num?)?.toDouble() ?? 0),
                  _fmt.format((inv['paid_before'] as num?)?.toDouble() ?? 0),
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
                  'ยอดชำระทั้งสิ้น: ${_fmt.format((payment['amount_lc'] as num?)?.toDouble() ?? 0)} บาท',
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kTheme,
        foregroundColor: Colors.white,
        toolbarHeight: 40,
        title: const MenuTitle(),
        actions: [
          if (_selected.isNotEmpty)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: _generating ? null : _printBatch,
              icon: const Icon(Icons.print, size: 16),
              label: Text('พิมพ์ (${_selected.length})', style: const TextStyle(fontSize: 13)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toggle strip
          Container(
            width: 36,
            color: _kTheme,
            child: Column(children: [
              IconButton(
                padding: EdgeInsets.zero,
                iconSize: 20,
                color: Colors.white,
                icon: Icon(_panelOpen ? Icons.chevron_left : Icons.chevron_right),
                onPressed: () => setState(() => _panelOpen = !_panelOpen),
              ),
            ]),
          ),
          // Left panel – filters
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _panelOpen ? 260 : 0,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                maxWidth: 260,
                child: SizedBox(
                  width: 260,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        color: Colors.blueGrey.shade200,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Column(children: [
                          _datePicker('วันที่เริ่ม', _fDateFrom, (d) { setState(() => _fDateFrom = d); _loadPayments(); }),
                          const SizedBox(height: 6),
                          _datePicker('วันที่สิ้นสุด', _fDateTo, (d) { setState(() => _fDateTo = d); _loadPayments(); }),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _fStatus,
                            decoration: const InputDecoration(
                                labelText: 'สถานะ', isDense: true,
                                filled: true, fillColor: Colors.white,
                                border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                            items: const [
                              DropdownMenuItem(value: 'Cleared', child: Text('เคลียร์แล้ว', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'Pending', child: Text('รอดำเนินการ', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: '', child: Text('ทั้งหมด', style: TextStyle(fontSize: 12))),
                            ],
                            onChanged: (v) { setState(() => _fStatus = v ?? ''); _loadPayments(); },
                          ),
                          const SizedBox(height: 4),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 30),
                                padding: EdgeInsets.zero),
                            onPressed: _loadPayments,
                            icon: const Icon(Icons.refresh, size: 14),
                            label: const Text('รีเฟรช', style: TextStyle(fontSize: 12)),
                          ),
                        ]),
                      ),
                      Expanded(
                        child: Container(
                          color: Colors.blueGrey.shade50,
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            'เลือก ${_selected.length} / ${_payments.length} รายการ',
                            style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Right panel – payment list
          Expanded(
            child: Column(children: [
              // Column headers
              Container(
                color: Colors.blueGrey.shade200,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                  const Expanded(flex: 2, child: Text('เลขที่ชำระ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  const Expanded(flex: 2, child: Text('ผู้รับเงิน', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  const Expanded(flex: 2, child: Text('บัญชีธนาคาร', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 90, child: Text('วันที่', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 100, child: Text('จำนวนเงิน', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                  const SizedBox(width: 80, child: Text('การดำเนินการ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                ]),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _payments.isEmpty
                        ? Center(child: Text('ไม่พบรายการ', style: TextStyle(color: Colors.blueGrey.shade400)))
                        : ListView.builder(
                            itemCount: _payments.length,
                            itemBuilder: (_, i) {
                              final p = _payments[i];
                              final id = p['id'] as int;
                              final sel = _selected.contains(id);
                              DateTime? dt;
                              try { dt = DateTime.parse(p['payment_date'].toString()); } catch (_) {}
                              return Container(
                                color: sel ? _kTheme.withOpacity(0.07) : (i.isEven ? Colors.grey.shade50 : Colors.white),
                                child: Row(children: [
                                  Checkbox(
                                    value: sel,
                                    onChanged: (v) => setState(() {
                                      if (v == true) _selected.add(id); else _selected.remove(id);
                                    }),
                                  ),
                                  Expanded(flex: 2, child: Text(p['payment_no'] ?? '', style: const TextStyle(fontSize: 12))),
                                  Expanded(flex: 2, child: Text(p['payee_name_th'] ?? '', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                  Expanded(flex: 2, child: Text('${p['bank_account_code'] ?? ''} ${p['bank_account_name'] ?? ''}'.trim(),
                                      style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                                  SizedBox(width: 90, child: Text(dt != null ? _dateFmt.format(dt) : '', style: const TextStyle(fontSize: 11))),
                                  SizedBox(width: 100, child: Text(_fmt.format((p['amount_lc'] as num?)?.toDouble() ?? 0),
                                      style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
                                  SizedBox(
                                    width: 80,
                                    child: Center(
                                      child: IconButton(
                                        iconSize: 18,
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(Icons.print, color: _kTheme),
                                        tooltip: 'พิมพ์',
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
        ],
      ),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
          child: Text(value != null ? _dateFmt.format(value) : '-',
              style: const TextStyle(fontSize: 12)),
        ),
      );
}
