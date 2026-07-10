// lib/cm/screens/cm_fx_gain_loss_report_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../config/app_config.dart';
import '../../sa/services/auth_service.dart';
import '../../sa/utils/menu_scope.dart';
import '../../cm/models/cm_bank_account.dart';

const _kTheme = Color(0xFF1565C0);
final _fmt     = NumberFormat('#,##0.00', 'en_US');
final _dateFmt = DateFormat('dd/MM/yyyy');

class CmFxGainLossReportScreen extends StatefulWidget {
  const CmFxGainLossReportScreen({super.key});
  @override
  State<CmFxGainLossReportScreen> createState() => _State();
}

class _State extends State<CmFxGainLossReportScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _leftExpanded = true;

  // Filter
  DateTime _dateFrom = DateTime(DateTime.now().year, 1, 1);
  DateTime _dateTo   = DateTime.now();
  List<CmBankAccount> _accounts    = [];
  CmBankAccount?      _selAccount; // null = all accounts

  // Report data
  bool _loading = false;
  List<Map<String, dynamic>> _rows = [];
  double _totalGain    = 0;
  double _totalLoss    = 0;
  double _netGainLoss  = 0;
  bool _hasReport = false;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final headers = await AuthService().getAuthHeader();
      final resp = await http.get(Uri.parse('${AppConfig.apiCm}/cm_bank_account/active'), headers: headers);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final all = (json.decode(resp.body) as List)
            .map((j) => CmBankAccount.fromJson(j as Map<String, dynamic>))
            .where((a) => a.cmType == 'BANK' && a.currencyCode != 'THB')
            .toList();
        setState(() => _accounts = all);
      }
    } catch (_) {}
  }

  Future<void> _loadReport() async {
    setState(() { _loading = true; _rows = []; _hasReport = false; });
    try {
      final headers = await AuthService().getAuthHeader();
      final params = {
        'date_from': DateFormat('yyyy-MM-dd').format(_dateFrom),
        'date_to':   DateFormat('yyyy-MM-dd').format(_dateTo),
        if (_selAccount != null) 'bank_account_id': _selAccount!.id!.toString(),
      };
      final uri = Uri.parse('${AppConfig.apiCm}/cm_fx_gain_loss_report')
          .replace(queryParameters: params);
      final resp = await http.get(uri, headers: headers);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        setState(() {
          _rows       = List<Map<String, dynamic>>.from(data['rows'] as List);
          _totalGain  = double.tryParse(data['total_gain']?.toString()    ?? '0') ?? 0;
          _totalLoss  = double.tryParse(data['total_loss']?.toString()    ?? '0') ?? 0;
          _netGainLoss= double.tryParse(data['net_gain_loss']?.toString() ?? '0') ?? 0;
          _hasReport  = true;
          _loading    = false;
        });
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
              icon: Icon(_leftExpanded ? Icons.filter_list_off : Icons.filter_list),
              onPressed: () => setState(() => _leftExpanded = !_leftExpanded),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _leftExpanded ? 220 : 0,
            child: ClipRect(child: OverflowBox(
              alignment: Alignment.centerLeft, maxWidth: 220,
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
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(height: 36, color: Colors.blueGrey.shade200,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: const Text('ตัวกรอง', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        const SizedBox(height: 12),
        const Text('จากวันที่:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        _datePicker(_dateFrom, (d) => setState(() => _dateFrom = d)),
        const SizedBox(height: 8),
        const Text('ถึงวันที่:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        _datePicker(_dateTo, (d) => setState(() => _dateTo = d)),
        const SizedBox(height: 12),
        const Text('บัญชีธนาคาร:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.white,
              border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
          child: DropdownButton<CmBankAccount?>(
            value: _selAccount,
            isExpanded: true, isDense: true,
            underline: const SizedBox(),
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            hint: const Text('ทุกบัญชี (FC)', style: TextStyle(fontSize: 12)),
            items: [
              const DropdownMenuItem<CmBankAccount?>(value: null, child: Text('ทุกบัญชี (FC)')),
              ..._accounts.map((a) => DropdownMenuItem<CmBankAccount?>(
                value: a,
                child: Text('${a.accountCode} (${a.currencyCode})', style: const TextStyle(fontSize: 12)),
              )),
            ],
            onChanged: (v) => setState(() => _selAccount = v),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white),
          onPressed: _loading ? null : _loadReport,
          icon: _loading
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.bar_chart, size: 16),
          label: const Text('แสดงรายงาน', style: TextStyle(fontSize: 12)),
        ),
        if (_hasReport) ...[
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          _statCard('FX Gain', _totalGain, Colors.green.shade700),
          const SizedBox(height: 6),
          _statCard('FX Loss', _totalLoss, Colors.red.shade700),
          const SizedBox(height: 6),
          _statCard('สุทธิ', _netGainLoss,
              _netGainLoss >= 0 ? Colors.green.shade700 : Colors.red.shade700),
        ],
      ]),
    );
  }

  Widget _statCard(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.08),
          border: Border.all(color: color.withOpacity(0.3)), borderRadius: BorderRadius.circular(6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: color)),
        Text(_fmt.format(value),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  Widget _buildRightPanel() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_hasReport)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: _kTheme.withOpacity(0.07),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('รายงาน FX Gain/Loss จากการ Revaluation',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            Text('${_dateFmt.format(_dateFrom)} — ${_dateFmt.format(_dateTo)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          ]),
        ),
      if (_hasReport) const Divider(height: 1),
      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_hasReport
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.currency_exchange, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('เลือกช่วงวันที่และกด "แสดงรายงาน"',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                ]))
              : _rows.isEmpty
                  ? const Center(child: Text('ไม่มีข้อมูล FX Revaluation ในช่วงที่เลือก',
                      style: TextStyle(color: Colors.grey)))
                  : _buildTable()),
    ]);
  }

  Widget _buildTable() {
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 36, dataRowMinHeight: 34, dataRowMaxHeight: 42,
          columnSpacing: 14,
          headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
          headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          columns: const [
            DataColumn(label: Text('วันที่ Reval')),
            DataColumn(label: Text('เลขที่')),
            DataColumn(label: Text('บัญชีธนาคาร')),
            DataColumn(label: Text('สกุลเงิน')),
            DataColumn(label: Text('ยอด FC'),       numeric: true),
            DataColumn(label: Text('ยอด LC (เดิม)'), numeric: true),
            DataColumn(label: Text('อัตราใหม่'),    numeric: true),
            DataColumn(label: Text('ยอด LC (ใหม่)'), numeric: true),
            DataColumn(label: Text('FX Gain/Loss'),  numeric: true),
          ],
          rows: _rows.map((r) {
            final fxGL = _parseD(r['fx_gain_loss']);
            Color glColor;
            if (fxGL > 0) {
              glColor = Colors.green.shade700;
            } else if (fxGL < 0) {
              glColor = Colors.red.shade700;
            } else {
              glColor = Colors.black87;
            }
            DateTime? dt;
            try { dt = DateTime.parse(r['revaluation_date'].toString()); } catch (_) {}
            return DataRow(cells: [
              DataCell(Text(dt != null ? _dateFmt.format(dt) : '', style: const TextStyle(fontSize: 12))),
              DataCell(Text(r['gl_doc_no'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(r['bank_account_code'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text('${r['bank_account_name'] ?? ''} (${r['bank_short_name'] ?? ''})',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ])),
              DataCell(Text(r['currency_code'] ?? '', style: const TextStyle(fontSize: 12))),
              DataCell(Text(_fmt.format(_parseD(r['balance_fc'])),      style: const TextStyle(fontSize: 12))),
              DataCell(Text(_fmt.format(_parseD(r['balance_lc_book'])), style: const TextStyle(fontSize: 12))),
              DataCell(Text(
                NumberFormat('#,##0.000000', 'en_US').format(_parseD(r['new_rate'])),
                style: const TextStyle(fontSize: 12),
              )),
              DataCell(Text(_fmt.format(_parseD(r['balance_lc_new'])),  style: const TextStyle(fontSize: 12))),
              DataCell(Text(_fmt.format(fxGL), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: glColor))),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _datePicker(DateTime value, void Function(DateTime) onPick) {
    return InkWell(
      onTap: () async {
        final p = await showDatePicker(context: context, initialDate: value,
            firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (p != null) onPick(p);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: Colors.white,
            border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
        child: Row(children: [
          Text(_dateFmt.format(value), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const Spacer(),
          Icon(Icons.calendar_today, size: 13, color: Colors.grey.shade500),
        ]),
      ),
    );
  }
}
