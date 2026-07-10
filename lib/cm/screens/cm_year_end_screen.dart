// lib/cm/screens/cm_year_end_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../config/app_config.dart';
import '../../sa/services/auth_service.dart';
import '../../sa/utils/menu_scope.dart';

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

  bool _leftExpanded = true;

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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันปิดปีบัญชี'),
        content: Text('ต้องการปิดปี CM $_fiscalYear ใช่หรือไม่?\nการดำเนินการนี้จะบันทึก snapshot ยอดเงินคงเหลือ ณ 31 ธ.ค. $_fiscalYear'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ปิดปีบัญชี'),
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
            SnackBar(content: Text('ปิดปี $_fiscalYear เรียบร้อยแล้ว'), backgroundColor: Colors.green.shade700));
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันเปิดปีบัญชีอีกครั้ง'),
        content: Text('ต้องการเปิดปี CM $year อีกครั้งใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('เปิดอีกครั้ง'),
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
            SnackBar(content: Text('เปิดปี $year แล้ว'), backgroundColor: Colors.green.shade700));
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kTheme,
        foregroundColor: Colors.white,
        title: const MenuTitle(),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        toolbarHeight: 40,
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
    final issues   = _readiness == null ? <dynamic>[] : List.from(_readiness!['issues'] as List);
    final hasErrors = _readiness?['has_errors'] == true;
    final alreadyClosed = _readiness?['already_closed'] == true;

    return Container(
      color: Colors.blueGrey.shade100,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(height: 36, color: Colors.blueGrey.shade200,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: const Text('ตั้งค่าปิดปี', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('ปีบัญชี (ค.ศ.):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                onPressed: () => setState(() { _fiscalYear--; _readiness = null; }),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28),
              ),
              Expanded(child: Center(child: Text(
                '$_fiscalYear',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ))),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                onPressed: () => setState(() { _fiscalYear++; _readiness = null; }),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28),
              ),
            ]),
            const SizedBox(height: 12),
            const Text('หมายเหตุ:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                filled: true, fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade700, foregroundColor: Colors.white),
              onPressed: _loadingReadiness ? null : _checkReadiness,
              icon: _loadingReadiness
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.checklist, size: 16),
              label: const Text('ตรวจสอบ', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(height: 8),
            if (_readiness != null) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (hasErrors || alreadyClosed) ? Colors.grey.shade400 : Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: (hasErrors || alreadyClosed || _closing) ? null : _closeYear,
                icon: _closing
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.lock, size: 16),
                label: Text(alreadyClosed ? 'ปิดไปแล้ว' : 'ปิดปีบัญชี', style: const TextStyle(fontSize: 12)),
              ),
            ],

            if (_readiness != null && issues.isEmpty && !alreadyClosed)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade300),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('พร้อมปิดปีบัญชี', style: TextStyle(fontSize: 12, color: Colors.green))),
                ]),
              ),

            if (_readiness != null && issues.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...issues.map((issue) {
                final sev = issue['severity'] as String? ?? 'INFO';
                Color col;
                IconData icon;
                switch (sev) {
                  case 'ERROR':   col = Colors.red.shade700;    icon = Icons.error_outline;
                  case 'WARNING': col = Colors.orange.shade700; icon = Icons.warning_amber_rounded;
                  default:        col = Colors.blue.shade700;   icon = Icons.info_outline;
                }
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: col.withOpacity(0.08),
                    border: Border.all(color: col.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(children: [
                    Icon(icon, size: 15, color: col),
                    const SizedBox(width: 6),
                    Expanded(child: Text(issue['title'] ?? '', style: TextStyle(fontSize: 11, color: col))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: col.withOpacity(0.15), borderRadius: BorderRadius.circular(3)),
                      child: Text('${issue['count']}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: col)),
                    ),
                  ]),
                );
              }),
            ],
          ]),
        )),
      ]),
    );
  }

  Widget _buildRightPanel() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: _kTheme.withOpacity(0.07),
        child: Row(children: [
          const Text('ประวัติการปิดปีบัญชี CM', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: _loadingHistory ? null : _loadHistory,
            tooltip: 'รีเฟรช',
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
                  Text('ยังไม่มีการปิดปีบัญชี', style: TextStyle(color: Colors.grey.shade400)),
                ]))
              : SingleChildScrollView(
                  child: DataTable(
                    headingRowHeight: 36, dataRowMinHeight: 36, dataRowMaxHeight: 44,
                    columnSpacing: 20,
                    headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
                    headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    columns: const [
                      DataColumn(label: Text('ปีบัญชี')),
                      DataColumn(label: Text('วันที่ปิด')),
                      DataColumn(label: Text('สถานะ')),
                      DataColumn(label: Text('ปิดโดย')),
                      DataColumn(label: Text('หมายเหตุ')),
                      DataColumn(label: Text('บัญชีธนาคาร')),
                      DataColumn(label: Text('จัดการ')),
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
                              ? _dateFmt.format(DateTime.parse(r['close_date'].toString()))
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
                            isClosed ? 'ปิดแล้ว' : 'เปิด',
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
                                  label: Text('${balances.length} บัญชี', style: const TextStyle(fontSize: 11)),
                                  onPressed: () => _showBalancesDialog(r['fiscal_year'] as int, balances),
                                ),
                        ),
                        DataCell(isClosed
                            ? TextButton.icon(
                                icon: const Icon(Icons.lock_open, size: 14),
                                label: const Text('เปิดอีกครั้ง', style: TextStyle(fontSize: 11)),
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
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('ยอดเงินคงเหลือ ณ 31 ธ.ค. $year'),
        content: SizedBox(
          width: 480,
          child: DataTable(
            headingRowHeight: 34, dataRowMinHeight: 32, dataRowMaxHeight: 38,
            columnSpacing: 16,
            headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
            headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            columns: const [
              DataColumn(label: Text('รหัส')),
              DataColumn(label: Text('ชื่อบัญชี')),
              DataColumn(label: Text('สกุลเงิน')),
              DataColumn(label: Text('ยอดคงเหลือ'), numeric: true),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ปิด')),
        ],
      ),
    );
  }
}
