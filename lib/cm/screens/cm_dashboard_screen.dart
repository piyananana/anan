// lib/cm/screens/cm_dashboard_screen.dart
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
final _fmt     = NumberFormat('#,##0.00', 'en_US');
final _dateFmt = DateFormat('dd/MM/yyyy');

class CmDashboardScreen extends StatefulWidget {
  const CmDashboardScreen({super.key});
  @override
  State<CmDashboardScreen> createState() => _State();
}

class _State extends State<CmDashboardScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _loading = false;
  bool _isEnglish = false;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final headers = await AuthService().getAuthHeader();
      final resp = await http.get(Uri.parse('${AppConfig.apiCm}/cm_dashboard'), headers: headers);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        setState(() { _data = json.decode(resp.body) as Map<String, dynamic>; _loading = false; });
      } else {
        throw Exception(json.decode(resp.body)['error'] ?? resp.body);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red.shade700));
    }
  }

  double _parseD(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;

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
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: isEnglish ? 'Refresh' : 'รีเฟรช',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.dashboard, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: Text(isEnglish ? 'Load Data' : 'โหลดข้อมูล'),
                  ),
                ]))
              : _buildDashboard(),
    );
  }

  Widget _buildDashboard() {
    final isEnglish = _isEnglish;
    final bankBalances       = List<Map<String, dynamic>>.from(_data!['bank_balances'] as List);
    final pettyCash          = List<Map<String, dynamic>>.from(_data!['petty_cash_balances'] as List);
    final alerts             = List<Map<String, dynamic>>.from(_data!['alerts'] as List);
    final recentTx           = List<Map<String, dynamic>>.from(_data!['recent_transactions'] as List);
    final checksReceived     = _data!['pending_checks_received'] as Map<String, dynamic>;
    final checksIssued       = _data!['pending_checks_issued']   as Map<String, dynamic>;
    final totalBankBalance   = _parseD(_data!['total_bank_balance_lc']);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Summary cards ─────────────────────────────────────────────────
          Wrap(spacing: 16, runSpacing: 16, children: [
            _summaryCard(isEnglish ? 'Cash Balance (THB)' : 'ยอดเงินคงเหลือ (THB)',
                _fmt.format(totalBankBalance),
                Icons.account_balance, Colors.blue.shade700,
                subtitle: isEnglish ? '${bankBalances.length} accounts' : '${bankBalances.length} บัญชี'),
            _summaryCard(isEnglish ? 'Pending Checks — Received' : 'เช็คค้าง — รับ',
                isEnglish ? '${checksReceived['count']} checks' : '${checksReceived['count']} ฉบับ',
                Icons.receipt_long, Colors.orange.shade700,
                subtitle: '${_fmt.format(_parseD(checksReceived['amount']))} THB'),
            _summaryCard(isEnglish ? 'Pending Checks — Issued' : 'เช็คค้าง — จ่าย',
                isEnglish ? '${checksIssued['count']} checks' : '${checksIssued['count']} ฉบับ',
                Icons.payment, Colors.deepOrange.shade700,
                subtitle: '${_fmt.format(_parseD(checksIssued['amount']))} THB'),
            _summaryCard(isEnglish ? 'Alerts' : 'แจ้งเตือน',
                isEnglish ? '${alerts.length} items' : '${alerts.length} รายการ',
                alerts.isEmpty ? Icons.check_circle : Icons.warning_amber_rounded,
                alerts.isEmpty ? Colors.green.shade700 : Colors.red.shade700,
                subtitle: alerts.isEmpty
                    ? (isEnglish ? 'No issues' : 'ไม่มีปัญหา')
                    : (isEnglish ? 'Action required' : 'ต้องดำเนินการ')),
          ]),
          const SizedBox(height: 24),

          // ── Alerts ────────────────────────────────────────────────────────
          if (alerts.isNotEmpty) ...[
            _sectionTitle(isEnglish ? 'Alerts' : 'แจ้งเตือน', Icons.notifications_active),
            const SizedBox(height: 8),
            ...alerts.map(_buildAlertCard),
            const SizedBox(height: 24),
          ],

          // ── Bank balances ─────────────────────────────────────────────────
          _sectionTitle(isEnglish ? 'Bank Account Balances' : 'ยอดเงินคงเหลือในบัญชีธนาคาร', Icons.account_balance),
          const SizedBox(height: 8),
          if (bankBalances.isEmpty)
            _emptyState(isEnglish ? 'No bank accounts' : 'ไม่มีบัญชีธนาคาร')
          else
            _buildBankTable(bankBalances),
          const SizedBox(height: 24),

          // ── Petty cash ────────────────────────────────────────────────────
          if (pettyCash.isNotEmpty) ...[
            _sectionTitle(isEnglish ? 'Petty Cash' : 'เงินสดย่อย', Icons.savings),
            const SizedBox(height: 8),
            _buildPettyCashTable(pettyCash),
            const SizedBox(height: 24),
          ],

          // ── Recent transactions ───────────────────────────────────────────
          _sectionTitle(isEnglish ? 'Recent Transactions' : 'ธุรกรรมล่าสุด', Icons.history),
          const SizedBox(height: 8),
          if (recentTx.isEmpty)
            _emptyState(isEnglish ? 'No transactions' : 'ไม่มีธุรกรรม')
          else
            _buildRecentTxTable(recentTx),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color, {String? subtitle}) {
    return Container(
      width: 200, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          if (subtitle != null)
            Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ])),
      ]),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final sev = alert['severity'] as String? ?? 'INFO';
    Color color;
    IconData icon;
    switch (sev) {
      case 'ERROR':   color = Colors.red.shade700;    icon = Icons.error_outline;
      case 'WARNING': color = Colors.orange.shade700; icon = Icons.warning_amber_rounded;
      default:        color = Colors.blue.shade700;   icon = Icons.info_outline;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(alert['title'] ?? '', style: TextStyle(fontSize: 13, color: color))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
          child: Text('${alert['count']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ),
      ]),
    );
  }

  Widget _buildBankTable(List<Map<String, dynamic>> rows) {
    final isEnglish = _isEnglish;
    return Card(
      margin: EdgeInsets.zero,
      child: DataTable(
        headingRowHeight: 36, dataRowMinHeight: 34, dataRowMaxHeight: 40,
        columnSpacing: 20,
        headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
        headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        columns: [
          DataColumn(label: Text(isEnglish ? 'Account Code' : 'รหัสบัญชี')),
          DataColumn(label: Text(isEnglish ? 'Account Name' : 'ชื่อบัญชี')),
          DataColumn(label: Text(isEnglish ? 'Bank' : 'ธนาคาร')),
          DataColumn(label: Text(isEnglish ? 'Currency' : 'สกุลเงิน')),
          DataColumn(label: Text(isEnglish ? 'Balance' : 'ยอดคงเหลือ'), numeric: true),
        ],
        rows: rows.map((r) {
          final bal = _parseD(r['balance']);
          return DataRow(cells: [
            DataCell(Text(r['bank_account_code'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
            DataCell(Text(r['bank_account_name'] ?? '', style: const TextStyle(fontSize: 12))),
            DataCell(Text(r['bank_short_name'] ?? '', style: const TextStyle(fontSize: 12))),
            DataCell(Text(r['currency_code'] ?? 'THB', style: const TextStyle(fontSize: 12))),
            DataCell(Text(_fmt.format(bal), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                color: bal >= 0 ? Colors.black87 : Colors.red.shade700))),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildPettyCashTable(List<Map<String, dynamic>> rows) {
    final isEnglish = _isEnglish;
    return Card(
      margin: EdgeInsets.zero,
      child: DataTable(
        headingRowHeight: 36, dataRowMinHeight: 34, dataRowMaxHeight: 40,
        columnSpacing: 20,
        headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
        headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        columns: [
          DataColumn(label: Text(isEnglish ? 'Fund' : 'กองทุน')),
          DataColumn(label: Text(isEnglish ? 'Limit' : 'วงเงิน'), numeric: true),
          DataColumn(label: Text(isEnglish ? 'Used' : 'เบิกแล้ว'), numeric: true),
          DataColumn(label: Text(isEnglish ? 'Available' : 'คงเหลือ'),  numeric: true),
        ],
        rows: rows.map((r) {
          final avail = _parseD(r['available']);
          return DataRow(cells: [
            DataCell(Text('${r['bank_account_code']} ${r['bank_account_name']}', style: const TextStyle(fontSize: 12))),
            DataCell(Text(_fmt.format(_parseD(r['fund_amount'])),  style: const TextStyle(fontSize: 12))),
            DataCell(Text(_fmt.format(_parseD(r['used_amount'])),  style: TextStyle(fontSize: 12, color: Colors.red.shade700))),
            DataCell(Text(_fmt.format(avail), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                color: avail >= 0 ? Colors.green.shade700 : Colors.red.shade700))),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildRecentTxTable(List<Map<String, dynamic>> rows) {
    final isEnglish = _isEnglish;
    return Card(
      margin: EdgeInsets.zero,
      child: DataTable(
        headingRowHeight: 36, dataRowMinHeight: 32, dataRowMaxHeight: 38,
        columnSpacing: 16,
        headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
        headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        columns: [
          DataColumn(label: Text(isEnglish ? 'Date' : 'วันที่')),
          DataColumn(label: Text(isEnglish ? 'Doc No.' : 'เลขที่')),
          DataColumn(label: Text(isEnglish ? 'Type' : 'ประเภท')),
          DataColumn(label: Text(isEnglish ? 'Description' : 'คำอธิบาย')),
          DataColumn(label: Text(isEnglish ? 'Amount' : 'จำนวนเงิน'), numeric: true),
        ],
        rows: rows.map((r) {
          final txType = r['tx_type'] as String? ?? '';
          Color typeColor;
          String typeLabel;
          switch (txType) {
            case 'RECEIPT':  typeColor = Colors.green.shade700;  typeLabel = isEnglish ? 'Receipt' : 'รับเงิน';
            case 'PAYMENT':  typeColor = Colors.red.shade700;    typeLabel = isEnglish ? 'Payment' : 'จ่ายเงิน';
            default:         typeColor = Colors.blue.shade700;   typeLabel = isEnglish ? 'Transfer' : 'โอนเงิน';
          }
          return DataRow(cells: [
            DataCell(Text(
              r['tx_date'] != null ? _dateFmt.format(parseLocalDate(r['tx_date'])) : '',
              style: const TextStyle(fontSize: 12))),
            DataCell(Text(r['doc_no'] ?? '', style: const TextStyle(fontSize: 12))),
            DataCell(Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(typeLabel, style: TextStyle(fontSize: 11, color: typeColor, fontWeight: FontWeight.bold)),
            )),
            DataCell(SizedBox(width: 180, child: Text(r['description'] ?? '',
                style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
            DataCell(Text(_fmt.format(_parseD(r['amount_lc'])),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: typeColor))),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 18, color: _kTheme),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _emptyState(String msg) =>
      Padding(padding: const EdgeInsets.all(16),
          child: Text(msg, style: TextStyle(color: Colors.grey.shade400, fontSize: 13)));
}
