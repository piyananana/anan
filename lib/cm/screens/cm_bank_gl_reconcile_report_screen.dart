// lib/cm/screens/cm_bank_gl_reconcile_report_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../config/app_config.dart';
import '../../sa/services/auth_service.dart';
import '../../sa/utils/menu_scope.dart';

const _kTheme = Color(0xFF1565C0);
final _fmt     = NumberFormat('#,##0.00', 'en_US');
final _dateFmt = DateFormat('dd/MM/yyyy');

class CmBankGlReconcileReportScreen extends StatefulWidget {
  const CmBankGlReconcileReportScreen({super.key});
  @override
  State<CmBankGlReconcileReportScreen> createState() => _State();
}

class _State extends State<CmBankGlReconcileReportScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _leftExpanded = true;
  DateTime? _asOfDate;
  bool _loading = false;
  List<Map<String, dynamic>> _rows = [];
  String? _reportDate;
  int _totalMatched   = 0;
  int _totalUnmatched = 0;

  @override
  void initState() {
    super.initState();
    // Default: last day of current month
    final now = DateTime.now();
    _asOfDate = DateTime(now.year, now.month + 1, 0);
  }

  Future<void> _loadReport() async {
    if (_asOfDate == null) return;
    setState(() { _loading = true; _rows = []; });
    try {
      final headers = await AuthService().getAuthHeader();
      final d = DateFormat('yyyy-MM-dd').format(_asOfDate!);
      final uri = Uri.parse('${AppConfig.apiCm}/cm_bank_gl_reconcile')
          .replace(queryParameters: {'as_of_date': d});
      final resp = await http.get(uri, headers: headers);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        setState(() {
          _rows           = List<Map<String, dynamic>>.from(data['rows'] as List);
          _totalMatched   = data['total_matched'] as int? ?? 0;
          _totalUnmatched = data['total_unmatched'] as int? ?? 0;
          _reportDate     = d;
          _loading        = false;
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
      body: LayoutBuilder(
        builder: (_, __) => Row(
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
        const Text('ณ วันที่:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        _datePicker(),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white),
          onPressed: _loading ? null : _loadReport,
          icon: _loading
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.compare_arrows, size: 16),
          label: const Text('กระทบยอด', style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(height: 16),
        if (_reportDate != null) ...[
          const Divider(),
          const SizedBox(height: 8),
          _statCard('ตรงกัน',     _totalMatched,   Colors.green.shade700),
          const SizedBox(height: 8),
          _statCard('ไม่ตรงกัน', _totalUnmatched, Colors.red.shade700),
        ],
      ]),
    );
  }

  Widget _statCard(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.3)), borderRadius: BorderRadius.circular(6)),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: color))),
        Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  Widget _buildRightPanel() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_reportDate != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: _kTheme.withOpacity(0.08),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('รายงานกระทบยอด CM vs GL', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text('ณ วันที่ ${_dateFmt.format(DateFormat('yyyy-MM-dd').parse(_reportDate!))}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          ]),
        ),
      if (_reportDate != null) const Divider(height: 1),
      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reportDate == null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.compare_arrows, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('เลือกวันที่และกด "กระทบยอด"', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                ]))
              : _rows.isEmpty
                  ? const Center(child: Text('ไม่มีบัญชีที่มี GL Account กำหนดไว้', style: TextStyle(color: Colors.grey)))
                  : _buildTable()),
    ]);
  }

  Widget _buildTable() {
    const hStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.bold);
    const cStyle = TextStyle(fontSize: 12);
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 38, dataRowMinHeight: 36, dataRowMaxHeight: 44,
          columnSpacing: 16,
          headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
          headingTextStyle: hStyle,
          columns: const [
            DataColumn(label: Text('บัญชีธนาคาร')),
            DataColumn(label: Text('GL Account')),
            DataColumn(label: Text('สกุลเงิน')),
            DataColumn(label: Text('ยอด CM'),   numeric: true),
            DataColumn(label: Text('ยอด GL'),   numeric: true),
            DataColumn(label: Text('ส่วนต่าง'), numeric: true),
            DataColumn(label: Text('สถานะ')),
          ],
          rows: _rows.map((r) {
            final isMatched = r['is_matched'] == true;
            final diff = _parseD(r['difference']);
            return DataRow(
              color: WidgetStateProperty.resolveWith((_) =>
                  isMatched ? null : Colors.red.shade50),
              cells: [
                DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(r['bank_account_code'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('${r['bank_account_name'] ?? ''} (${r['bank_short_name'] ?? ''})',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ])),
                DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(r['gl_account_code'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text(r['gl_account_name'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ])),
                DataCell(Text(r['currency_code'] ?? 'THB', style: cStyle)),
                DataCell(Text(_fmt.format(_parseD(r['cm_balance'])), style: cStyle)),
                DataCell(Text(_fmt.format(_parseD(r['gl_balance'])), style: cStyle)),
                DataCell(Text(_fmt.format(diff),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                        color: diff == 0 ? Colors.black87 : Colors.red.shade700))),
                DataCell(isMatched
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
                        const SizedBox(width: 4),
                        Text('ตรงกัน', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                      ])
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.error_outline, size: 16, color: Colors.red.shade600),
                        const SizedBox(width: 4),
                        Text('ไม่ตรงกัน', style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                      ])),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _datePicker() {
    return InkWell(
      onTap: () async {
        final p = await showDatePicker(context: context, initialDate: _asOfDate ?? DateTime.now(),
            firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (p != null) setState(() => _asOfDate = p);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: Colors.white,
            border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
        child: Row(children: [
          Text(_asOfDate != null ? _dateFmt.format(_asOfDate!) : '— เลือกวันที่ —',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const Spacer(),
          Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
        ]),
      ),
    );
  }
}
