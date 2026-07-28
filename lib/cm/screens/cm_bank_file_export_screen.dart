// lib/cm/screens/cm_bank_file_export_screen.dart
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../models/cm_bank_account.dart';
import '../models/cm_bank_file_format.dart';
import '../../utils/date_utils.dart';

const _kTheme = Color(0xFF1565C0);
final _fmt     = NumberFormat('#,##0.00', 'en_US');
final _dateFmt = DateFormat('dd/MM/yyyy');

class CmBankFileExportScreen extends StatefulWidget {
  const CmBankFileExportScreen({super.key});
  @override
  State<CmBankFileExportScreen> createState() => _State();
}

class _State extends State<CmBankFileExportScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _leftExpanded = true;

  // Accounts
  List<CmBankAccount> _bankAccounts  = [];
  CmBankAccount?      _selAccount;
  List<CmBankFileFormat> _formats    = [];
  CmBankFileFormat?      _selFormat;

  // Filter
  DateTime _dateFrom = DateTime.now().copyWith(day: 1);
  DateTime _dateTo   = DateTime.now();
  String   _statusFilter = 'All';

  // Data
  List<Map<String, dynamic>> _payments = [];
  bool _loadingPayments = false;
  final Set<int> _selected = {};

  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final headers = await AuthService().getAuthHeader();
      final acctResp = await http.get(Uri.parse('${AppConfig.apiCm}/cm_bank_account/active'), headers: headers);
      final fmtResp  = await http.get(Uri.parse('${AppConfig.apiCm}/cm_bank_file_format'), headers: headers);
      if (!mounted) return;
      if (acctResp.statusCode == 200) {
        final all = (json.decode(acctResp.body) as List)
            .map((j) => CmBankAccount.fromJson(j as Map<String, dynamic>))
            .toList();
        setState(() {
          _bankAccounts = all.where((a) => a.cmType == 'BANK').toList();
          if (_bankAccounts.isNotEmpty) _selAccount = _bankAccounts.first;
        });
      }
      if (fmtResp.statusCode == 200) {
        final fmts = (json.decode(fmtResp.body) as List)
            .map((j) => CmBankFileFormat.fromJson(j as Map<String, dynamic>))
            .toList();
        setState(() {
          _formats = fmts.where((f) => f.isActive).toList();
          if (_formats.isNotEmpty) _selFormat = _formats.first;
        });
      }
    } catch (e) { _showError(e.toString()); }
  }

  Future<void> _loadPayments() async {
    if (_selAccount == null) { _showError('กรุณาเลือกบัญชีธนาคาร'); return; }
    setState(() { _loadingPayments = true; _payments = []; _selected.clear(); });
    try {
      final headers = await AuthService().getAuthHeader();
      final params = {
        'bank_account_id': _selAccount!.id!.toString(),
        'date_from': formatLocalDate(_dateFrom),
        'date_to':   formatLocalDate(_dateTo),
        if (_statusFilter != 'All') 'status': _statusFilter,
      };
      final resp = await http.get(
          Uri.parse('${AppConfig.apiCm}/cm_bank_file_export/payments').replace(queryParameters: params),
          headers: headers);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        setState(() {
          _payments = List<Map<String, dynamic>>.from(json.decode(resp.body) as List);
          _loadingPayments = false;
        });
      } else {
        throw Exception(json.decode(resp.body)['error'] ?? resp.body);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingPayments = false);
      _showError(e.toString());
    }
  }

  Future<void> _generateFile() async {
    if (!(MenuScope.of(context)?.canExport ?? true)) return;
    if (_selFormat == null) { _showError('กรุณาเลือก Format ไฟล์'); return; }
    if (_selected.isEmpty) { _showError('กรุณาเลือกรายการจ่ายเงินอย่างน้อย 1 รายการ'); return; }
    setState(() => _generating = true);
    try {
      final headers = {...await AuthService().getAuthHeader(), 'Content-Type': 'application/json'};
      final resp = await http.post(
          Uri.parse('${AppConfig.apiCm}/cm_bank_file_export/generate'),
          headers: headers,
          body: json.encode({
            'format_id':   _selFormat!.id,
            'payment_ids': _selected.toList(),
          }));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final result = json.decode(resp.body) as Map<String, dynamic>;
        final content  = result['content'] as String;
        final filename = result['filename'] as String;
        final rowCount = result['row_count'] ?? 0;

        // Download via dart:html Blob
        final bytes  = utf8.encode(content);
        final blob   = html.Blob([bytes], 'text/plain');
        final url    = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', filename)
          ..click();
        html.Url.revokeObjectUrl(url);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('สร้างไฟล์ $filename สำเร็จ ($rowCount รายการ)'),
              backgroundColor: Colors.green.shade700));
        }
      } else {
        throw Exception(json.decode(resp.body)['error'] ?? resp.body);
      }
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _toggleAll(bool? val) {
    setState(() {
      if (val == true) {
        for (final p in _payments) { _selected.add(p['id'] as int); }
      } else {
        _selected.clear();
      }
    });
  }

  void _toggleOne(int id, bool? val) {
    setState(() {
      if (val == true) { _selected.add(id); } else { _selected.remove(id); }
    });
  }

  void _showError(String msg) {
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
        title: const MenuTitle(),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        toolbarHeight: 40,
        actions: [
          if (_selected.isNotEmpty)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: _generating ? null : _generateFile,
              icon: _generating
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download, size: 16),
              label: Text('สร้างไฟล์ (${_selected.length})', style: const TextStyle(fontSize: 13)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 36, color: _kTheme,
            child: IconButton(
              padding: EdgeInsets.zero, iconSize: 20, color: Colors.white,
              icon: Icon(_leftExpanded ? Icons.chevron_left : Icons.chevron_right),
              onPressed: () => setState(() => _leftExpanded = !_leftExpanded),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _leftExpanded ? 280 : 0,
            child: ClipRect(child: OverflowBox(
              alignment: Alignment.centerLeft, maxWidth: 280,
              child: _buildLeftPanel(),
            )),
          ),
          if (_leftExpanded) const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: _buildRightPanel()),
        ],
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Container(
      color: Colors.blueGrey.shade100,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(height: 36, color: Colors.blueGrey.shade200,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            child: const Text('บัญชีธนาคาร', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        Expanded(
          child: _bankAccounts.isEmpty
              ? Center(child: Text('ไม่มีบัญชี', style: TextStyle(color: Colors.grey.shade400)))
              : ListView.builder(
                  itemCount: _bankAccounts.length,
                  itemBuilder: (_, i) {
                    final a = _bankAccounts[i];
                    final sel = a.id == _selAccount?.id;
                    return InkWell(
                      onTap: () => setState(() {
                        _selAccount = a;
                        _payments = [];
                        _selected.clear();
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        color: sel ? _kTheme.withOpacity(0.10) : null,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(a.accountCode,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                                  color: sel ? _kTheme : Colors.black87)),
                          Text(a.accountNameTh, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          Text('${a.bankShortName ?? ''} | ${a.currencyCode}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _buildRightPanel() {
    return Column(children: [
      // Toolbar
      Container(
        padding: const EdgeInsets.all(10),
        color: Colors.grey.shade50,
        child: Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.end, children: [
          // Format
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Format ไฟล์', style: TextStyle(fontSize: 11, color: Colors.black54)),
            const SizedBox(height: 2),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<CmBankFileFormat?>(
                value: _selFormat,
                isDense: true,
                decoration: InputDecoration(isDense: true, filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4))),
                style: const TextStyle(fontSize: 12, color: Colors.black87),
                hint: const Text('— เลือก format —'),
                items: _formats.map((f) => DropdownMenuItem<CmBankFileFormat?>(
                  value: f,
                  child: Text('${f.formatCode} ${f.formatName}', style: const TextStyle(fontSize: 12)),
                )).toList(),
                onChanged: (v) => setState(() => _selFormat = v),
              ),
            ),
          ]),
          // Date from
          _datePicker('วันที่จาก', _dateFrom, (d) => setState(() => _dateFrom = d)),
          _datePicker('ถึงวันที่', _dateTo,   (d) => setState(() => _dateTo   = d)),
          // Status
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('สถานะ', style: TextStyle(fontSize: 11, color: Colors.black54)),
            const SizedBox(height: 2),
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                value: _statusFilter,
                isDense: true,
                decoration: InputDecoration(isDense: true, filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4))),
                style: const TextStyle(fontSize: 12, color: Colors.black87),
                items: const [
                  DropdownMenuItem(value: 'All',      child: Text('ทั้งหมด')),
                  DropdownMenuItem(value: 'Posted',   child: Text('Posted')),
                  DropdownMenuItem(value: 'Cleared',  child: Text('Cleared')),
                ],
                onChanged: (v) => setState(() => _statusFilter = v ?? 'All'),
              ),
            ),
          ]),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white,
                minimumSize: const Size(100, 34)),
            onPressed: _loadPayments,
            icon: const Icon(Icons.search, size: 16),
            label: const Text('โหลด', style: TextStyle(fontSize: 13)),
          ),
        ]),
      ),
      const Divider(height: 1),
      Expanded(child: _buildPaymentTable()),
    ]);
  }

  Widget _buildPaymentTable() {
    if (_loadingPayments) return const Center(child: CircularProgressIndicator());
    if (_payments.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.file_download_off, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 8),
        Text('กดโหลดเพื่อแสดงรายการจ่ายเงิน', style: TextStyle(color: Colors.grey.shade400)),
      ]));
    }

    final allSel = _payments.isNotEmpty && _selected.length == _payments.length;
    final totalSel = _selected.fold<double>(0, (s, id) {
      final p = _payments.where((x) => x['id'] == id).toList();
      return s + (p.isNotEmpty ? (double.tryParse(p.first['amount_lc']?.toString() ?? '0') ?? 0) : 0);
    });

    return Column(children: [
      if (_selected.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: _kTheme.withOpacity(0.08),
          child: Row(children: [
            Text('เลือก ${_selected.length} รายการ รวม ${_fmt.format(totalSel)} บาท',
                style: TextStyle(fontSize: 13, color: _kTheme, fontWeight: FontWeight.w600)),
          ]),
        ),
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 34, dataRowMinHeight: 30, dataRowMaxHeight: 36,
              columnSpacing: 12,
              headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
              headingTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              columns: [
                DataColumn(label: Checkbox(
                  value: allSel, tristate: true,
                  onChanged: _toggleAll,
                )),
                const DataColumn(label: Text('เลขที่เอกสาร')),
                const DataColumn(label: Text('วันที่')),
                const DataColumn(label: Text('ผู้รับเงิน')),
                const DataColumn(label: Text('วิธีจ่าย')),
                const DataColumn(label: Text('เช็ค/เลขที่')),
                const DataColumn(label: Text('สกุลเงิน')),
                const DataColumn(label: Text('จำนวนเงิน'), numeric: true),
                const DataColumn(label: Text('สถานะ')),
              ],
              rows: _payments.map((p) {
                final id   = p['id'] as int;
                final isSel = _selected.contains(id);
                final dt = parseLocalDateNullable(p['payment_date']);
                return DataRow(
                  selected: isSel,
                  onSelectChanged: (v) => _toggleOne(id, v),
                  cells: [
                    DataCell(Checkbox(value: isSel, onChanged: (v) => _toggleOne(id, v))),
                    DataCell(Text(p['ap_doc_no'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                    DataCell(Text(dt != null ? _dateFmt.format(dt) : '', style: const TextStyle(fontSize: 12))),
                    DataCell(SizedBox(width: 130, child: Text(p['payee_name_th'] ?? '',
                        style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
                    DataCell(Text(p['payment_method'] ?? '', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(p['check_no'] ?? '', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(p['currency_code'] ?? 'THB', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(_fmt.format(double.tryParse(p['amount_lc']?.toString() ?? '0') ?? 0),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _statusBg(p['status'] ?? ''),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(p['status'] ?? '',
                          style: TextStyle(fontSize: 11, color: _statusFg(p['status'] ?? ''))),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    ]);
  }

  Color _statusBg(String s) {
    switch (s) {
      case 'Posted':  return Colors.blue.shade50;
      case 'Cleared': return Colors.green.shade50;
      case 'Voided':  return Colors.grey.shade100;
      default:        return Colors.orange.shade50;
    }
  }

  Color _statusFg(String s) {
    switch (s) {
      case 'Posted':  return Colors.blue.shade700;
      case 'Cleared': return Colors.green.shade700;
      case 'Voided':  return Colors.grey.shade600;
      default:        return Colors.orange.shade700;
    }
  }

  Widget _datePicker(String label, DateTime value, void Function(DateTime) onPick) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      const SizedBox(height: 2),
      InkWell(
        onTap: () async {
          final p = await showDatePicker(context: context, initialDate: value,
              firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (p != null) onPick(p);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white, border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(_dateFmt.format(value), style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            Icon(Icons.calendar_today, size: 13, color: Colors.grey.shade500),
          ]),
        ),
      ),
    ]);
  }
}
