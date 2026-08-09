// lib/cm/screens/cm_check_print_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../cm/models/cm_bank_account.dart';
import '../../utils/thai_amount_words.dart';
import '../../utils/date_utils.dart';

const _kTheme = Color(0xFF1565C0);
final _fmt      = NumberFormat('#,##0.00', 'en_US');
final _dateFmt  = DateFormat('dd/MM/yyyy');

double _mmToPt(double mm) => mm * 72 / 25.4;

class CmCheckPrintScreen extends StatefulWidget {
  const CmCheckPrintScreen({super.key});
  @override
  State<CmCheckPrintScreen> createState() => _State();
}

class _State extends State<CmCheckPrintScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isEnglish = false;
  bool _leftExpanded = true;
  double _leftWidth  = 420.0;
  bool _isDragging   = false;

  // Left panel
  List<CmBankAccount> _accounts = [];
  CmBankAccount? _selectedAccount;
  bool _loadingAccounts = false;
  String _acctSearch = '';

  // Right panel state
  List<Map<String, dynamic>> _configs  = [];
  Map<String, dynamic>?      _selConfig;
  bool _loadingConfigs = false;

  DateTime _dateFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _dateTo   = DateTime.now();
  String  _statusFilter = 'All';

  List<Map<String, dynamic>> _checks = [];
  bool _loadingChecks = false;
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _loadingAccounts = true);
    try {
      final headers = await AuthService().getAuthHeader();
      final resp = await http.get(Uri.parse('${AppConfig.apiCm}/cm_bank_account/active'), headers: headers);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final all = (json.decode(resp.body) as List)
            .map((j) => CmBankAccount.fromJson(j as Map<String, dynamic>))
            .where((a) => a.cmType == 'BANK')
            .toList();
        setState(() { _accounts = all; _loadingAccounts = false; });
        if (all.isNotEmpty) {
          _selectedAccount = all.first;
          await _loadConfigs(all.first.id!);
        }
      } else {
        throw Exception(json.decode(resp.body)['error'] ?? resp.body);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingAccounts = false);
      _showError(e.toString());
    }
  }

  Future<void> _loadConfigs(int bankAccountId) async {
    setState(() { _loadingConfigs = true; _configs = []; _selConfig = null; });
    try {
      final headers = await AuthService().getAuthHeader();
      final uri = Uri.parse('${AppConfig.apiCm}/cm_check_print/config/$bankAccountId');
      final resp = await http.get(uri, headers: headers);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(json.decode(resp.body) as List);
        setState(() {
          _configs     = list;
          _selConfig   = list.isNotEmpty ? list.first : null;
          _loadingConfigs = false;
        });
      } else {
        throw Exception(json.decode(resp.body)['error'] ?? resp.body);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingConfigs = false);
      _showError(e.toString());
    }
  }

  Future<void> _loadChecks() async {
    if (_selectedAccount == null) return;
    setState(() { _loadingChecks = true; _checks = []; _selected.clear(); });
    try {
      final headers = await AuthService().getAuthHeader();
      final uri = Uri.parse('${AppConfig.apiCm}/cm_check_print/checks').replace(queryParameters: {
        'bank_account_id': _selectedAccount!.id!.toString(),
        'date_from': formatLocalDate(_dateFrom),
        'date_to':   formatLocalDate(_dateTo),
        if (_statusFilter != 'All') 'status': _statusFilter,
      });
      final resp = await http.get(uri, headers: headers);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        setState(() {
          _checks = List<Map<String, dynamic>>.from(json.decode(resp.body) as List);
          _loadingChecks = false;
        });
      } else {
        throw Exception(json.decode(resp.body)['error'] ?? resp.body);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingChecks = false);
      _showError(e.toString());
    }
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
          if (_selected.isNotEmpty && _selConfig != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, foregroundColor: _kTheme, padding: const EdgeInsets.symmetric(horizontal: 12)),
                onPressed: _printSelected,
                icon: const Icon(Icons.print, size: 16),
                label: Text(isEnglish ? 'Print ${_selected.length} checks' : 'พิมพ์ ${_selected.length} ฉบับ', style: const TextStyle(fontSize: 12)),
              ),
            ),
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

  List<CmBankAccount> get _filteredAccounts {
    if (_acctSearch.isEmpty) return _accounts;
    final q = _acctSearch.toLowerCase();
    return _accounts.where((a) {
      final name = _isEnglish && (a.accountNameEn ?? '').isNotEmpty ? a.accountNameEn! : a.accountNameTh;
      return a.accountCode.toLowerCase().contains(q) ||
          name.toLowerCase().contains(q) ||
          (a.bankShortName ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Widget _buildLeftPanel() {
    final isEnglish = _isEnglish;
    return Container(
      color: Colors.blueGrey.shade100,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(height: 36, color: Colors.blueGrey.shade200,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(isEnglish ? 'Bank Accounts' : 'บัญชีธนาคาร', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            decoration: InputDecoration(
              hintText: isEnglish ? 'Search accounts...' : 'ค้นหาบัญชี...',
              prefixIcon: const Icon(Icons.search),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _acctSearch = v),
          ),
        ),
        Expanded(child: _loadingAccounts
            ? const Center(child: CircularProgressIndicator())
            : _filteredAccounts.isEmpty
                ? Center(child: Text(isEnglish ? 'No accounts found' : 'ไม่พบบัญชี', style: const TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _filteredAccounts.length,
                    itemBuilder: (_, i) {
                      final a = _filteredAccounts[i];
                      final sel = _selectedAccount?.id == a.id;
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
                          onTap: () async {
                            setState(() { _selectedAccount = a; _checks = []; _selected.clear(); });
                            await _loadConfigs(a.id!);
                          },
                        ),
                      );
                    },
                  )),
      ]),
    );
  }

  Widget _buildRightPanel() {
    final isEnglish = _isEnglish;
    if (_selectedAccount == null) {
      return Center(child: Text(isEnglish ? 'Select a bank account' : 'เลือกบัญชีธนาคาร', style: const TextStyle(color: Colors.grey)));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _buildFilterBar(),
      const Divider(height: 1),
      Expanded(child: _loadingChecks
          ? const Center(child: CircularProgressIndicator())
          : _checks.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text(isEnglish ? 'Press "Load Checks" to show items' : 'กด "โหลดเช็ค" เพื่อแสดงรายการ', style: TextStyle(color: Colors.grey.shade400)),
                ]))
              : _buildCheckTable()),
    ]);
  }

  Widget _buildFilterBar() {
    final isEnglish = _isEnglish;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: Colors.grey.shade50,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            flex: 2,
            child: _loadingConfigs
                ? const SizedBox(height: 56, child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))))
                : _configs.isNotEmpty
                    ? DropdownButtonFormField<Map<String, dynamic>>(
                        value: _selConfig,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: isEnglish ? 'Config' : 'แบบพิมพ์เช็ค', border: const OutlineInputBorder()),
                        items: _configs.map((c) => DropdownMenuItem(
                          value: c,
                          child: Text('${c['config_name']}${c['is_default'] == true ? ' ★' : ''}', overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (v) => setState(() => _selConfig = v),
                      )
                    : Container(
                        height: 56, alignment: Alignment.centerLeft,
                        child: Text(isEnglish ? 'No check print config found' : 'ไม่พบ config พิมพ์เช็ค',
                            style: TextStyle(color: Colors.orange.shade700)),
                      ),
          ),
          const SizedBox(width: 8),
          Expanded(flex: 1, child: _datePicker(isEnglish ? 'From' : 'จาก', _dateFrom, (d) => setState(() => _dateFrom = d))),
          const SizedBox(width: 8),
          Expanded(flex: 1, child: _datePicker(isEnglish ? 'To' : 'ถึง', _dateTo, (d) => setState(() => _dateTo = d))),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: DropdownButtonFormField<String>(
              value: _statusFilter,
              isExpanded: true,
              decoration: InputDecoration(labelText: isEnglish ? 'Status' : 'สถานะ', border: const OutlineInputBorder()),
              items: [
                DropdownMenuItem(value: 'All',     child: Text(isEnglish ? 'All' : 'ทั้งหมด')),
                const DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                const DropdownMenuItem(value: 'Cleared', child: Text('Cleared')),
                const DropdownMenuItem(value: 'Bounced', child: Text('Bounced')),
                const DropdownMenuItem(value: 'Voided',  child: Text('Voided')),
              ],
              onChanged: (v) => setState(() => _statusFilter = v ?? 'All'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _loadChecks,
              icon: const Icon(Icons.search, size: 18),
              label: Text(isEnglish ? 'Load Checks' : 'โหลดเช็ค'),
            ),
          ),
        ]),
        if (_checks.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(children: [
            TextButton.icon(
              icon: Icon(_selected.length == _checks.length ? Icons.check_box : Icons.check_box_outline_blank, size: 16),
              label: Text(_selected.length == _checks.length ? (isEnglish ? 'Deselect All' : 'ยกเลิกทั้งหมด') : (isEnglish ? 'Select All' : 'เลือกทั้งหมด'),
                  style: const TextStyle(fontSize: 13)),
              onPressed: () => setState(() {
                if (_selected.length == _checks.length) {
                  _selected.clear();
                } else {
                  _selected.clear();
                  for (final c in _checks) { _selected.add(c['id'] as int); }
                }
              }),
            ),
          ]),
        ],
      ]),
    );
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

  Widget _buildCheckTable() {
    final isEnglish = _isEnglish;
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 36, dataRowMinHeight: 34, dataRowMaxHeight: 40,
          columnSpacing: 16,
          headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
          headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          columns: [
            const DataColumn(label: Text('')),
            DataColumn(label: Text(isEnglish ? 'Payment Date' : 'วันที่จ่าย')),
            DataColumn(label: Text(isEnglish ? 'Check No.' : 'เลขที่เช็ค')),
            DataColumn(label: Text(isEnglish ? 'Check Date' : 'วันที่เช็ค')),
            DataColumn(label: Text(isEnglish ? 'Payee' : 'ผู้รับเงิน')),
            DataColumn(label: Text(isEnglish ? 'Amount' : 'จำนวนเงิน'), numeric: true),
            DataColumn(label: Text(isEnglish ? 'Status' : 'สถานะ')),
          ],
          rows: _checks.map((c) {
            final id = c['id'] as int;
            final isSel = _selected.contains(id);
            final status = c['status'] as String? ?? '';
            Color statusColor;
            switch (status) {
              case 'Cleared': statusColor = Colors.green.shade700;
              case 'Bounced': statusColor = Colors.red.shade700;
              case 'Voided':  statusColor = Colors.red.shade600;
              default:        statusColor = Colors.blue.shade700;
            }
            return DataRow(
              selected: isSel,
              color: WidgetStateProperty.resolveWith((_) =>
                  isSel ? _kTheme.withOpacity(0.08) : null),
              onSelectChanged: (_) => setState(() {
                if (isSel) { _selected.remove(id); } else { _selected.add(id); }
              }),
              cells: [
                DataCell(Checkbox(
                  value: isSel,
                  onChanged: (_) => setState(() { if (isSel) { _selected.remove(id); } else { _selected.add(id); } }),
                  visualDensity: VisualDensity.compact,
                )),
                DataCell(Text(
                  c['payment_date'] != null
                      ? _dateFmt.format(parseLocalDate(c['payment_date']))
                      : '—',
                  style: const TextStyle(fontSize: 12),
                )),
                DataCell(Text(c['check_no'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataCell(Text(
                  c['check_date'] != null
                      ? _dateFmt.format(parseLocalDate(c['check_date']))
                      : '—',
                  style: const TextStyle(fontSize: 12),
                )),
                DataCell(SizedBox(width: 160, child: Text(
                    c['payee_name_th'] ?? '',
                    style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
                DataCell(Text(_fmt.format(double.tryParse(c['amount_lc']?.toString() ?? '0') ?? 0),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _printSelected() async {
    if (!(MenuScope.of(context)?.canPrint ?? true)) return;
    if (_selConfig == null || _selected.isEmpty) return;
    final toprint = _checks.where((c) => _selected.contains(c['id'] as int)).toList();
    try {
      final pdfBytes = await _buildPdf(toprint, _selConfig!);
      if (!mounted) return;
      await Printing.layoutPdf(onLayout: (_) => pdfBytes, name: 'checks');
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    }
  }

  Future<Uint8List> _buildPdf(List<Map<String, dynamic>> checks, Map<String, dynamic> cfg) async {
    final fontData     = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final font     = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontBoldData);

    final pw.ThemeData theme = pw.ThemeData.withFont(base: font, bold: fontBold);

    final double paperW = _mmToPt(double.tryParse(cfg['paper_width_mm']?.toString()  ?? '210') ?? 210);
    final double paperH = _mmToPt(double.tryParse(cfg['paper_height_mm']?.toString() ?? '99')  ?? 99);
    final pageFormat = PdfPageFormat(paperW, paperH, marginAll: 0);

    final double dateX     = _mmToPt(double.tryParse(cfg['date_x']?.toString()       ?? '150') ?? 150);
    final double dateY     = _mmToPt(double.tryParse(cfg['date_y']?.toString()       ?? '18')  ?? 18);
    final double payeeX    = _mmToPt(double.tryParse(cfg['payee_x']?.toString()      ?? '35')  ?? 35);
    final double payeeY    = _mmToPt(double.tryParse(cfg['payee_y']?.toString()      ?? '38')  ?? 38);
    final double amtNumX   = _mmToPt(double.tryParse(cfg['amount_num_x']?.toString() ?? '155') ?? 155);
    final double amtNumY   = _mmToPt(double.tryParse(cfg['amount_num_y']?.toString() ?? '38')  ?? 38);
    final double amtTxtX   = _mmToPt(double.tryParse(cfg['amount_text_x']?.toString()?? '20')  ?? 20);
    final double amtTxtY   = _mmToPt(double.tryParse(cfg['amount_text_y']?.toString()?? '55')  ?? 55);
    final String dateFmtStr = cfg['date_format'] as String? ?? 'dd/MM/yyyy';

    final doc = pw.Document(theme: theme);

    for (final c in checks) {
      final payee  = c['payee_name_th'] as String? ?? '';
      final amount = double.tryParse(c['amount_lc']?.toString() ?? '0') ?? 0;
      final amtTxt = thaiAmountToWords(amount);
      String dateStr = '';
      try {
        final checkDate = c['check_date'] != null
            ? parseLocalDate(c['check_date'])
            : (c['payment_date'] != null ? parseLocalDate(c['payment_date']) : DateTime.now());
        dateStr = DateFormat(dateFmtStr).format(checkDate);
      } catch (_) {
        dateStr = c['check_date']?.toString() ?? '';
      }

      doc.addPage(pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => pw.Stack(children: [
          // Date
          pw.Positioned(
            left: dateX, top: dateY,
            child: pw.Text(dateStr, style: pw.TextStyle(font: fontBold, fontSize: 11)),
          ),
          // Payee
          pw.Positioned(
            left: payeeX, top: payeeY,
            child: pw.Text(payee, style: pw.TextStyle(font: fontBold, fontSize: 12)),
          ),
          // Amount numeric
          pw.Positioned(
            left: amtNumX, top: amtNumY,
            child: pw.Text(_fmt.format(amount), style: pw.TextStyle(font: fontBold, fontSize: 12)),
          ),
          // Amount in words
          pw.Positioned(
            left: amtTxtX, top: amtTxtY,
            child: pw.Text(amtTxt, style: pw.TextStyle(font: font, fontSize: 11)),
          ),
        ]),
      ));
    }

    return doc.save();
  }
}
