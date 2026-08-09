// lib/cm/screens/cm_bank_file_export_screen.dart
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_language_provider.dart';
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

  bool _isEnglish = false;
  bool _leftExpanded = true;
  double _leftWidth  = 420.0;
  bool _isDragging   = false;

  // Accounts
  List<CmBankAccount> _bankAccounts  = [];
  CmBankAccount?      _selAccount;
  List<CmBankFileFormat> _formats    = [];
  CmBankFileFormat?      _selFormat;
  String _acctSearch = '';

  List<CmBankAccount> get _filteredAccounts {
    if (_acctSearch.isEmpty) return _bankAccounts;
    final q = _acctSearch.toLowerCase();
    return _bankAccounts.where((a) {
      final name = _isEnglish && (a.accountNameEn ?? '').isNotEmpty ? a.accountNameEn! : a.accountNameTh;
      return a.accountCode.toLowerCase().contains(q) ||
          name.toLowerCase().contains(q) ||
          (a.bankShortName ?? '').toLowerCase().contains(q);
    }).toList();
  }

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
    if (_selAccount == null) {
      _showError(_isEnglish ? 'Please select a bank account' : 'กรุณาเลือกบัญชีธนาคาร');
      return;
    }
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
    final isEnglish = _isEnglish;
    if (_selFormat == null) {
      _showError(isEnglish ? 'Please select a file format' : 'กรุณาเลือก Format ไฟล์');
      return;
    }
    if (_selected.isEmpty) {
      _showError(isEnglish ? 'Please select at least 1 payment' : 'กรุณาเลือกรายการจ่ายเงินอย่างน้อย 1 รายการ');
      return;
    }
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
              content: Text(isEnglish
                  ? 'Generated file $filename successfully ($rowCount items)'
                  : 'สร้างไฟล์ $filename สำเร็จ ($rowCount รายการ)'),
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
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kTheme,
        foregroundColor: Colors.white,
        title: const MenuTitle(),
        toolbarHeight: 40,
        actions: [
          if (_selected.isNotEmpty)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: _generating ? null : _generateFile,
              icon: _generating
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download, size: 16),
              label: Text(isEnglish ? 'Generate File (${_selected.length})' : 'สร้างไฟล์ (${_selected.length})', style: const TextStyle(fontSize: 13)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(builder: (_, constraints) {
        final maxLeft = (constraints.maxWidth - 36 - 5 - 320).clamp(100.0, double.infinity);
        return Row(
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
              duration: _isDragging ? Duration.zero : const Duration(milliseconds: 200),
              width: _leftExpanded ? _leftWidth : 0,
              child: ClipRect(child: OverflowBox(
                alignment: Alignment.centerLeft, maxWidth: _leftWidth, minWidth: _leftWidth,
                child: _buildLeftPanel(),
              )),
            ),
            if (_leftExpanded)
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  onHorizontalDragStart: (_) => setState(() => _isDragging = true),
                  onHorizontalDragUpdate: (d) => setState(() {
                    _leftWidth = (_leftWidth + d.delta.dx).clamp(200.0, maxLeft);
                  }),
                  onHorizontalDragEnd: (_) => setState(() => _isDragging = false),
                  child: Container(width: 5, color: Colors.grey[400]),
                ),
              ),
            Expanded(child: _buildRightPanel()),
          ],
        );
      }),
    );
  }

  Widget _buildLeftPanel() {
    final isEnglish = _isEnglish;
    final list = _filteredAccounts;
    return Container(
      color: Colors.blueGrey.shade100,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(height: 36, color: Colors.blueGrey.shade200,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            child: Text(isEnglish ? 'Bank Accounts' : 'บัญชีธนาคาร', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            decoration: InputDecoration(
              hintText: isEnglish ? 'Search account...' : 'ค้นหาบัญชี...',
              prefixIcon: const Icon(Icons.search),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _acctSearch = v),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(child: Text(isEnglish ? 'No accounts' : 'ไม่มีบัญชี', style: TextStyle(color: Colors.grey.shade400)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final a = list[i];
                    final sel = a.id == _selAccount?.id;
                    final name = isEnglish && (a.accountNameEn ?? '').isNotEmpty ? a.accountNameEn! : a.accountNameTh;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        selected: sel,
                        selectedTileColor: _kTheme.withOpacity(0.12),
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo.shade100,
                          child: const Icon(Icons.savings, size: 18),
                        ),
                        title: Text(a.accountCode,
                            style: TextStyle(fontWeight: FontWeight.bold, color: a.isActive ? null : Colors.grey)),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name,
                              style: TextStyle(fontSize: 13, color: a.isActive ? Colors.black87 : Colors.grey),
                              overflow: TextOverflow.ellipsis),
                          Text(
                            [
                              cmCmTypeLabel(a.cmType, isEnglish),
                              if (a.bankDisplay.isNotEmpty) a.bankDisplay,
                              if ((a.accountNumber ?? '').isNotEmpty) a.accountNumber!,
                              if (!a.isPettyCash) cmAccountTypeLabel(a.accountType, isEnglish),
                              if (a.isFcy) a.currencyCode,
                              if (a.isCheckAccount) (isEnglish ? 'Check' : 'เช็ค'),
                            ].join(' · '),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ]),
                        trailing: !a.isActive
                            ? Chip(
                                label: Text(isEnglish ? 'Inactive' : 'หยุดใช้', style: const TextStyle(fontSize: 11)),
                                backgroundColor: const Color(0xFFEEEEEE),
                              )
                            : null,
                        onTap: () => setState(() {
                          _selAccount = a;
                          _payments = [];
                          _selected.clear();
                        }),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _buildRightPanel() {
    final isEnglish = _isEnglish;
    return Column(children: [
      // Toolbar
      Container(
        padding: const EdgeInsets.all(10),
        color: Colors.grey.shade50,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // Format
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<CmBankFileFormat?>(
              value: _selFormat,
              isExpanded: true,
              decoration: InputDecoration(
                  labelText: isEnglish ? 'File Format' : 'Format ไฟล์',
                  border: const OutlineInputBorder()),
              hint: Text(isEnglish ? '— Select format —' : '— เลือก format —'),
              items: _formats.map((f) => DropdownMenuItem<CmBankFileFormat?>(
                value: f,
                child: Text('${f.formatCode} ${f.formatName}', overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (v) => setState(() => _selFormat = v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(flex: 1, child: _datePicker(isEnglish ? 'Date From' : 'วันที่จาก', _dateFrom, (d) => setState(() => _dateFrom = d))),
          const SizedBox(width: 8),
          Expanded(flex: 1, child: _datePicker(isEnglish ? 'To Date' : 'ถึงวันที่', _dateTo,   (d) => setState(() => _dateTo   = d))),
          const SizedBox(width: 8),
          // Status
          Expanded(
            flex: 1,
            child: DropdownButtonFormField<String>(
              value: _statusFilter,
              isExpanded: true,
              decoration: InputDecoration(
                  labelText: isEnglish ? 'Status' : 'สถานะ',
                  border: const OutlineInputBorder()),
              items: [
                DropdownMenuItem(value: 'All',      child: Text(isEnglish ? 'All' : 'ทั้งหมด')),
                const DropdownMenuItem(value: 'Posted',   child: Text('Posted')),
                const DropdownMenuItem(value: 'Cleared',  child: Text('Cleared')),
              ],
              onChanged: (v) => setState(() => _statusFilter = v ?? 'All'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(flex: 1, child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: _loadPayments,
            icon: const Icon(Icons.search, size: 18),
            label: Text(isEnglish ? 'Load' : 'โหลด'),
          )),
        ]),
      ),
      const Divider(height: 1),
      Expanded(child: _buildPaymentTable()),
    ]);
  }

  Widget _buildPaymentTable() {
    final isEnglish = _isEnglish;
    if (_loadingPayments) return const Center(child: CircularProgressIndicator());
    if (_payments.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.file_download_off, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 8),
        Text(isEnglish ? 'Press Load to show payments' : 'กดโหลดเพื่อแสดงรายการจ่ายเงิน', style: TextStyle(color: Colors.grey.shade400)),
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
            Text(isEnglish
                ? 'Selected ${_selected.length} items, total ${_fmt.format(totalSel)} THB'
                : 'เลือก ${_selected.length} รายการ รวม ${_fmt.format(totalSel)} บาท',
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
                DataColumn(label: Text(isEnglish ? 'Doc No.' : 'เลขที่เอกสาร')),
                DataColumn(label: Text(isEnglish ? 'Date' : 'วันที่')),
                DataColumn(label: Text(isEnglish ? 'Payee' : 'ผู้รับเงิน')),
                DataColumn(label: Text(isEnglish ? 'Payment Method' : 'วิธีจ่าย')),
                DataColumn(label: Text(isEnglish ? 'Check/Ref No.' : 'เช็ค/เลขที่')),
                DataColumn(label: Text(isEnglish ? 'Currency' : 'สกุลเงิน')),
                DataColumn(label: Text(isEnglish ? 'Amount' : 'จำนวนเงิน'), numeric: true),
                DataColumn(label: Text(isEnglish ? 'Status' : 'สถานะ')),
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
      case 'Voided':  return Colors.red.shade50;
      default:        return Colors.orange.shade50;
    }
  }

  Color _statusFg(String s) {
    switch (s) {
      case 'Posted':  return Colors.blue.shade700;
      case 'Cleared': return Colors.green.shade700;
      case 'Voided':  return Colors.red.shade700;
      default:        return Colors.orange.shade700;
    }
  }

  Widget _datePicker(String label, DateTime value, void Function(DateTime) onPick) {
    return InkWell(
      onTap: () async {
        final p = await showDatePicker(context: context, initialDate: value,
            firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (p != null) onPick(p);
      },
      child: InputDecorator(
        decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.calendar_today, size: 18)),
        child: Text(_dateFmt.format(value)),
      ),
    );
  }
}
