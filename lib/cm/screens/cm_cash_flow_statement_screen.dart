// lib/cm/screens/cm_cash_flow_statement_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/utils/sa_menu_scope.dart';

const _kTheme = Color(0xFF1565C0);
final _fmt     = NumberFormat('#,##0.00', 'en_US');
final _dateFmt = DateFormat('dd/MM/yyyy');

class CmCashFlowStatementScreen extends StatefulWidget {
  const CmCashFlowStatementScreen({super.key});
  @override
  State<CmCashFlowStatementScreen> createState() => _State();
}

class _State extends State<CmCashFlowStatementScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _leftExpanded = true;

  DateTime _dateFrom = DateTime(DateTime.now().year, 1, 1);
  DateTime _dateTo   = DateTime.now();

  bool _loading = false;
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic>? _totals;
  bool _hasReport = false;

  double _parseD(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;

  Future<void> _loadReport() async {
    setState(() { _loading = true; _rows = []; _totals = null; _hasReport = false; });
    try {
      final headers = await AuthService().getAuthHeader();
      final uri = Uri.parse('${AppConfig.apiCm}/cm_cash_flow_statement').replace(queryParameters: {
        'date_from': DateFormat('yyyy-MM-dd').format(_dateFrom),
        'date_to':   DateFormat('yyyy-MM-dd').format(_dateTo),
      });
      final resp = await http.get(uri, headers: headers);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        setState(() {
          _rows      = List<Map<String, dynamic>>.from(data['rows'] as List);
          _totals    = data['totals'] as Map<String, dynamic>?;
          _hasReport = true;
          _loading   = false;
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
        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white),
          onPressed: _loading ? null : _loadReport,
          icon: _loading
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.waterfall_chart, size: 16),
          label: const Text('แสดงงบ', style: TextStyle(fontSize: 12)),
        ),
        if (_hasReport && _totals != null) ...[
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          _summaryItem('ยอดต้นงวด',   _parseD(_totals!['opening']),  Colors.blueGrey.shade700),
          _summaryItem('รับเงิน',      _parseD(_totals!['receipts']),  Colors.green.shade700),
          _summaryItem('จ่ายเงิน',    _parseD(_totals!['payments']),  Colors.red.shade700),
          _summaryItem('FX ปรับ',     _parseD(_totals!['fx_adj']),
              _parseD(_totals!['fx_adj']) >= 0 ? Colors.teal.shade700 : Colors.orange.shade700),
          const Divider(),
          _summaryItem('ยอดปลายงวด', _parseD(_totals!['closing']),
              _parseD(_totals!['closing']) >= 0 ? Colors.blue.shade700 : Colors.red.shade700,
              bold: true),
        ],
      ]),
    );
  }

  Widget _summaryItem(String label, double value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 11, color: Colors.black54,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
        Text(_fmt.format(value), style: TextStyle(fontSize: 12, color: color,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
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
            const Text('งบกระแสเงินสด (Cash Flow Statement)',
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
                  Icon(Icons.waterfall_chart, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('เลือกช่วงวันที่และกด "แสดงงบ"',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                ]))
              : _rows.isEmpty
                  ? const Center(child: Text('ไม่มีบัญชีธนาคาร', style: TextStyle(color: Colors.grey)))
                  : _buildTable()),
    ]);
  }

  Widget _buildTable() {
    const hStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.bold);
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 36, dataRowMinHeight: 34, dataRowMaxHeight: 42,
          columnSpacing: 14,
          headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
          headingTextStyle: hStyle,
          columns: const [
            DataColumn(label: Text('บัญชีธนาคาร')),
            DataColumn(label: Text('สกุลเงิน')),
            DataColumn(label: Text('ยอดต้นงวด'),      numeric: true),
            DataColumn(label: Text('รับเงิน'),          numeric: true),
            DataColumn(label: Text('จ่ายเงิน'),         numeric: true),
            DataColumn(label: Text('โอนเข้า'),          numeric: true),
            DataColumn(label: Text('โอนออก'),           numeric: true),
            DataColumn(label: Text('FX ปรับ'),          numeric: true),
            DataColumn(label: Text('ยอดปลายงวด'),      numeric: true),
          ],
          rows: [
            ..._rows.map((r) {
              final closing = _parseD(r['closing']);
              final fxAdj   = _parseD(r['fx_adj']);
              return DataRow(cells: [
                DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(r['bank_account_code'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('${r['bank_account_name'] ?? ''} (${r['bank_short_name'] ?? ''})',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ])),
                DataCell(Text(r['currency_code'] ?? 'THB', style: const TextStyle(fontSize: 12))),
                DataCell(Text(_fmt.format(_parseD(r['opening'])),      style: const TextStyle(fontSize: 12))),
                DataCell(Text(_fmt.format(_parseD(r['receipts'])),     style: TextStyle(fontSize: 12, color: Colors.green.shade700))),
                DataCell(Text(_fmt.format(_parseD(r['payments'])),     style: TextStyle(fontSize: 12, color: Colors.red.shade700))),
                DataCell(Text(_fmt.format(_parseD(r['transfer_in'])),  style: const TextStyle(fontSize: 12))),
                DataCell(Text(_fmt.format(_parseD(r['transfer_out'])), style: const TextStyle(fontSize: 12))),
                DataCell(Text(_fmt.format(fxAdj), style: TextStyle(fontSize: 12,
                    color: fxAdj > 0 ? Colors.teal.shade700 : fxAdj < 0 ? Colors.orange.shade700 : Colors.black87))),
                DataCell(Text(_fmt.format(closing), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                    color: closing >= 0 ? Colors.black87 : Colors.red.shade700))),
              ]);
            }),
            // Totals row
            if (_totals != null) ...[
              DataRow(
                color: WidgetStateProperty.all(Colors.blueGrey.shade50),
                cells: [
                  const DataCell(Text('รวมทั้งหมด', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  const DataCell(Text('')),
                  DataCell(Text(_fmt.format(_parseD(_totals!['opening'])),      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataCell(Text(_fmt.format(_parseD(_totals!['receipts'])),     style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700))),
                  DataCell(Text(_fmt.format(_parseD(_totals!['payments'])),     style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade700))),
                  DataCell(Text(_fmt.format(_parseD(_totals!['transfer_in'])),  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataCell(Text(_fmt.format(_parseD(_totals!['transfer_out'])), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataCell(Text(_fmt.format(_parseD(_totals!['fx_adj'])),       style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataCell(Text(_fmt.format(_parseD(_totals!['closing'])),      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                      color: _parseD(_totals!['closing']) >= 0 ? _kTheme : Colors.red.shade700))),
                ],
              ),
            ],
          ],
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
