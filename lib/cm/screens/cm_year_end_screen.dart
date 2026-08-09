// lib/cm/screens/cm_year_end_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../utils/date_utils.dart';

const _kTheme = Color(0xFF1565C0);
final _dateFmt = DateFormat('dd/MM/yyyy');
final _fmt      = NumberFormat('#,##0.00', 'en_US');

class CmYearEndScreen extends StatefulWidget {
  const CmYearEndScreen({super.key});
  @override
  State<CmYearEndScreen> createState() => _State();
}

class _State extends State<CmYearEndScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isEnglish = false;
  bool _leftExpanded = true;
  double _leftWidth  = 280.0;
  bool _isDragging   = false;

  // Left panel state
  int _fiscalYear = DateTime.now().year;
  final _notesCtrl = TextEditingController();

  // Data
  bool _loadingReadiness = false;
  Map<String, dynamic>? _readiness;
  bool _closing = false;

  // History list
  bool _loadingHistory = false;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final headers = await AuthService().getAuthHeader();
      final resp = await http.get(Uri.parse('${AppConfig.apiCm}/cm_year_end'), headers: headers);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        setState(() {
          _history = List<Map<String, dynamic>>.from(json.decode(resp.body) as List);
          _loadingHistory = false;
        });
      } else {
        throw Exception(json.decode(resp.body)['error'] ?? resp.body);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingHistory = false);
      _showError(e.toString());
    }
  }

  Future<void> _checkReadiness() async {
    setState(() { _loadingReadiness = true; _readiness = null; });
    try {
      final headers = await AuthService().getAuthHeader();
      final uri = Uri.parse('${AppConfig.apiCm}/cm_year_end/readiness')
          .replace(queryParameters: {'fiscal_year': _fiscalYear.toString()});
      final resp = await http.get(uri, headers: headers);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        setState(() {
          _readiness = json.decode(resp.body) as Map<String, dynamic>;
          _loadingReadiness = false;
        });
      } else {
        throw Exception(json.decode(resp.body)['error'] ?? resp.body);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingReadiness = false);
      _showError(e.toString());
    }
  }

  Future<void> _closeYear() async {
    if (!(MenuScope.of(context)?.canApprove ?? true)) return;
    final isEnglish = _isEnglish;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEnglish ? 'Confirm Year-End Close' : 'ยืนยันปิดปีบัญชี'),
        content: Text(isEnglish
            ? 'Close CM fiscal year $_fiscalYear?\nThis will record a snapshot of balances as of Dec 31, $_fiscalYear'
            : 'ต้องการปิดปี CM $_fiscalYear ใช่หรือไม่?\nการดำเนินการนี้จะบันทึก snapshot ยอดเงินคงเหลือ ณ 31 ธ.ค. $_fiscalYear'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(isEnglish ? 'Close Fiscal Year' : 'ปิดปีบัญชี'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _closing = true);
    try {
      final headers = {...await AuthService().getAuthHeader(), 'Content-Type': 'application/json'};
      final resp = await http.post(
        Uri.parse('${AppConfig.apiCm}/cm_year_end/close'),
        headers: headers,
        body: json.encode({'fiscal_year': _fiscalYear, 'notes': _notesCtrl.text}),
      );
      if (!mounted) return;
      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEnglish ? 'Fiscal year $_fiscalYear closed successfully' : 'ปิดปี $_fiscalYear เรียบร้อยแล้ว'), backgroundColor: Colors.green.shade700));
        await _loadHistory();
        await _checkReadiness();
      } else {
        throw Exception(json.decode(resp.body)['error'] ?? resp.body);
      }
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  Future<void> _reopenYear(int id, int year) async {
    final isEnglish = _isEnglish;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEnglish ? 'Confirm Reopen Fiscal Year' : 'ยืนยันเปิดปีบัญชีอีกครั้ง'),
        content: Text(isEnglish ? 'Reopen CM fiscal year $year?' : 'ต้องการเปิดปี CM $year อีกครั้งใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(isEnglish ? 'Reopen' : 'เปิดอีกครั้ง'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final headers = await AuthService().getAuthHeader();
      final resp = await http.put(
          Uri.parse('${AppConfig.apiCm}/cm_year_end/$id/reopen'), headers: headers);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEnglish ? 'Fiscal year $year reopened' : 'เปิดปี $year แล้ว'), backgroundColor: Colors.green.shade700));
        await _loadHistory();
        if (_readiness?['fiscal_year'] == year) await _checkReadiness();
      } else {
        throw Exception(json.decode(resp.body)['error'] ?? resp.body);
      }
    } catch (e) {
      if (!mounted) return;
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
    final issues   = _readiness == null ? <dynamic>[] : List.from(_readiness!['issues'] as List);
    final hasErrors = _readiness?['has_errors'] == true;
    final alreadyClosed = _readiness?['already_closed'] == true;

    return Container(
      color: Colors.blueGrey.shade100,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(height: 36, color: Colors.blueGrey.shade200,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(isEnglish ? 'Year-End Close Settings' : 'ตั้งค่าปิดปี', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            InputDecorator(
              decoration: InputDecoration(
                  labelText: isEnglish ? 'Fiscal Year (AD)' : 'ปีบัญชี (ค.ศ.)',
                  border: const OutlineInputBorder()),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: () => setState(() { _fiscalYear--; _readiness = null; }),
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28),
                ),
                Expanded(child: Center(child: Text(
                  '$_fiscalYear',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ))),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: () => setState(() { _fiscalYear++; _readiness = null; }),
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                  labelText: isEnglish ? 'Note' : 'หมายเหตุ',
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade700, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: _loadingReadiness ? null : _checkReadiness,
              icon: _loadingReadiness
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.checklist),
              label: Text(isEnglish ? 'Check' : 'ตรวจสอบ'),
            ),
            const SizedBox(height: 8),
            if (_readiness != null)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (hasErrors || alreadyClosed) ? Colors.grey.shade400 : Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: (hasErrors || alreadyClosed || _closing) ? null : _closeYear,
                icon: _closing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.lock),
                label: Text(alreadyClosed ? (isEnglish ? 'Already Closed' : 'ปิดไปแล้ว') : (isEnglish ? 'Close Fiscal Year' : 'ปิดปีบัญชี')),
              ),

            if (_readiness != null) ...[
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(isEnglish ? 'Readiness Check' : 'ผลการตรวจสอบ',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const Divider(height: 20),
                    if (issues.isEmpty)
                      Row(children: [
                        Icon(Icons.check_circle, color: _kTheme, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(isEnglish ? 'Ready to close fiscal year' : 'พร้อมปิดปีบัญชี',
                            style: TextStyle(fontSize: 14, color: _kTheme, fontWeight: FontWeight.bold))),
                      ])
                    else
                      for (final issue in issues) _issueItem(issue),
                  ]),
                ),
              ),
            ],
          ]),
        )),
      ]),
    );
  }

  Widget _issueItem(dynamic issue) {
    final isEnglish = _isEnglish;
    final sev = issue['severity'] as String? ?? 'INFO';
    final count = issue['count'] ?? 0;
    Color color;
    IconData icon;
    switch (sev) {
      case 'ERROR':   color = Colors.red.shade700;    icon = Icons.cancel;
      case 'WARNING': color = Colors.orange.shade700; icon = Icons.warning_amber_rounded;
      default:        color = Colors.blue.shade700;   icon = Icons.info_outline;
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(issue['title'] ?? '', style: const TextStyle(fontSize: 13))),
        Text(isEnglish ? '$count items' : '$count รายการ',
            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
      ]),
      const Divider(height: 20),
    ]);
  }

  Widget _buildRightPanel() {
    final isEnglish = _isEnglish;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: _kTheme.withOpacity(0.07),
        child: Row(children: [
          Text(isEnglish ? 'CM Year-End Close History' : 'ประวัติการปิดปีบัญชี CM', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: _loadingHistory ? null : _loadHistory,
            tooltip: isEnglish ? 'Refresh' : 'รีเฟรช',
          ),
        ]),
      ),
      const Divider(height: 1),
      Expanded(child: _loadingHistory
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.history, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text(isEnglish ? 'No year-end closes yet' : 'ยังไม่มีการปิดปีบัญชี', style: TextStyle(color: Colors.grey.shade400)),
                ]))
              : SingleChildScrollView(
                  child: DataTable(
                    headingRowHeight: 36, dataRowMinHeight: 36, dataRowMaxHeight: 44,
                    columnSpacing: 20,
                    headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
                    headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    columns: [
                      DataColumn(label: Text(isEnglish ? 'Fiscal Year' : 'ปีบัญชี')),
                      DataColumn(label: Text(isEnglish ? 'Close Date' : 'วันที่ปิด')),
                      DataColumn(label: Text(isEnglish ? 'Status' : 'สถานะ')),
                      DataColumn(label: Text(isEnglish ? 'Closed By' : 'ปิดโดย')),
                      DataColumn(label: Text(isEnglish ? 'Note' : 'หมายเหตุ')),
                      DataColumn(label: Text(isEnglish ? 'Bank Accounts' : 'บัญชีธนาคาร')),
                      DataColumn(label: Text(isEnglish ? 'Actions' : 'จัดการ')),
                    ],
                    rows: _history.map((r) {
                      final isClosed = r['status'] == 'Closed';
                      final balances = r['bank_balances'] != null
                          ? List<Map<String, dynamic>>.from(r['bank_balances'] as List)
                          : <Map<String, dynamic>>[];
                      return DataRow(cells: [
                        DataCell(Text('${r['fiscal_year']}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                        DataCell(Text(
                          r['close_date'] != null
                              ? _dateFmt.format(parseLocalDate(r['close_date']))
                              : '—',
                          style: const TextStyle(fontSize: 12),
                        )),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isClosed ? Colors.red.shade50 : Colors.green.shade50,
                            border: Border.all(color: isClosed ? Colors.red.shade200 : Colors.green.shade200),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isClosed ? (isEnglish ? 'Closed' : 'ปิดแล้ว') : (isEnglish ? 'Open' : 'เปิด'),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                                color: isClosed ? Colors.red.shade700 : Colors.green.shade700),
                          ),
                        )),
                        DataCell(Text(r['closed_by'] ?? '—', style: const TextStyle(fontSize: 12))),
                        DataCell(SizedBox(width: 150, child: Text(r['notes'] ?? '',
                            style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
                        DataCell(
                          balances.isEmpty
                              ? const Text('—', style: TextStyle(fontSize: 12))
                              : TextButton.icon(
                                  icon: const Icon(Icons.account_balance, size: 14),
                                  label: Text(isEnglish ? '${balances.length} accounts' : '${balances.length} บัญชี', style: const TextStyle(fontSize: 11)),
                                  onPressed: () => _showBalancesDialog(r['fiscal_year'] as int, balances),
                                ),
                        ),
                        DataCell(isClosed
                            ? TextButton.icon(
                                icon: const Icon(Icons.lock_open, size: 14),
                                label: Text(isEnglish ? 'Reopen' : 'เปิดอีกครั้ง', style: const TextStyle(fontSize: 11)),
                                style: TextButton.styleFrom(foregroundColor: Colors.orange.shade700),
                                onPressed: () => _reopenYear(r['id'] as int, r['fiscal_year'] as int),
                              )
                            : const SizedBox.shrink()),
                      ]);
                    }).toList(),
                  ),
                )),
    ]);
  }

  void _showBalancesDialog(int year, List<Map<String, dynamic>> balances) {
    final isEnglish = _isEnglish;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEnglish ? 'Balances as of Dec 31, $year' : 'ยอดเงินคงเหลือ ณ 31 ธ.ค. $year'),
        content: SizedBox(
          width: 480,
          child: DataTable(
            headingRowHeight: 34, dataRowMinHeight: 32, dataRowMaxHeight: 38,
            columnSpacing: 16,
            headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
            headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            columns: [
              DataColumn(label: Text(isEnglish ? 'Code' : 'รหัส')),
              DataColumn(label: Text(isEnglish ? 'Account Name' : 'ชื่อบัญชี')),
              DataColumn(label: Text(isEnglish ? 'Currency' : 'สกุลเงิน')),
              DataColumn(label: Text(isEnglish ? 'Balance' : 'ยอดคงเหลือ'), numeric: true),
            ],
            rows: balances.map((b) {
              final bal = double.tryParse(b['balance']?.toString() ?? '0') ?? 0;
              return DataRow(cells: [
                DataCell(Text(b['bank_account_code'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                DataCell(Text(b['bank_account_name'] ?? '', style: const TextStyle(fontSize: 12))),
                DataCell(Text(b['currency_code'] ?? 'THB', style: const TextStyle(fontSize: 12))),
                DataCell(Text(_fmt.format(bal), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                    color: bal >= 0 ? Colors.black87 : Colors.red.shade700))),
              ]);
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(isEnglish ? 'Close' : 'ปิด')),
        ],
      ),
    );
  }
}
