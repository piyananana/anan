// lib/cm/screens/cm_cash_position_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../sa/utils/menu_scope.dart';
import '../models/cm_bank_account.dart';
import '../services/cm_bank_account_service.dart';
import '../services/cm_report_service.dart';

const _kTheme = Color(0xFF1565C0);
final _fmt     = NumberFormat('#,##0.00', 'en_US');
final _dateFmt = DateFormat('dd/MM/yyyy');

class CmCashPositionScreen extends StatefulWidget {
  const CmCashPositionScreen({super.key});
  @override
  State<CmCashPositionScreen> createState() => _CmCashPositionScreenState();
}

class _CmCashPositionScreenState extends State<CmCashPositionScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _accSvc = CmBankAccountService();
  final _rptSvc = CmReportService();

  bool _leftExpanded = true;
  List<CmBankAccount> _accounts = [];
  CmBankAccount? _selectedAccount; // null = all accounts

  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _loading = false;

  List<Map<String, dynamic>> _rows = [];
  String? _reportDateFrom;
  String? _reportDateTo;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateFrom = DateTime(now.year, now.month, 1);
    _dateTo   = DateTime(now.year, now.month + 1, 0);
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final all = await _accSvc.fetchRows();
      if (!mounted) return;
      setState(() => _accounts = all.where((a) => a.cmType == 'BANK' && a.isActive).toList());
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _loadReport() async {
    if (_dateFrom == null || _dateTo == null) { _showError('กรุณาระบุช่วงวันที่'); return; }
    setState(() { _loading = true; _rows = []; });
    try {
      final df = DateFormat('yyyy-MM-dd').format(_dateFrom!);
      final dt = DateFormat('yyyy-MM-dd').format(_dateTo!);
      final data = await _rptSvc.getCashPosition(
        bankAccountId: _selectedAccount?.id,
        dateFrom: df, dateTo: dt,
      );
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(data['rows'] as List);
        _reportDateFrom = df;
        _reportDateTo   = dt;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700));
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
            // Toggle strip
            Container(
              width: 36,
              color: _kTheme,
              child: IconButton(
                padding: EdgeInsets.zero, iconSize: 20, color: Colors.white,
                icon: Icon(_leftExpanded ? Icons.filter_list_off : Icons.filter_list),
                onPressed: () => setState(() => _leftExpanded = !_leftExpanded),
              ),
            ),
            // Left panel
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _leftExpanded ? 220 : 0,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  maxWidth: 220,
                  child: _buildAccountPanel(),
                ),
              ),
            ),
            if (_leftExpanded) const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: _buildReportPanel()),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountPanel() {
    return Container(
      color: Colors.blueGrey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 36, color: Colors.blueGrey.shade200,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: const Text('บัญชีธนาคาร', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          // "All accounts" option
          ListTile(
            dense: true,
            selected: _selectedAccount == null,
            selectedTileColor: _kTheme.withOpacity(0.15),
            title: const Text('— ทุกบัญชี —', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            onTap: () => setState(() => _selectedAccount = null),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _accounts.length,
              itemBuilder: (_, i) {
                final acc = _accounts[i];
                final selected = acc.id == _selectedAccount?.id;
                return ListTile(
                  dense: true, selected: selected,
                  selectedTileColor: _kTheme.withOpacity(0.15),
                  title: Text(acc.accountCode, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  subtitle: Text('${acc.bankShortName ?? ''} ${acc.accountNumber ?? ''}',
                      style: const TextStyle(fontSize: 11)),
                  onTap: () => setState(() => _selectedAccount = acc),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              _datePicker('ตั้งแต่', _dateFrom, (d) => setState(() => _dateFrom = d)),
              const SizedBox(width: 12),
              _datePicker('ถึง', _dateTo, (d) => setState(() => _dateTo = d)),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white,
                    minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 12)),
                onPressed: _loading ? null : _loadReport,
                icon: _loading
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.assessment, size: 16),
                label: const Text('แสดงรายงาน', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Report title
        if (_reportDateFrom != null)
          _buildReportHeader(),
        // Table
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _rows.isEmpty && _reportDateFrom != null
                  ? const Center(child: Text('ไม่มีข้อมูล', style: TextStyle(color: Colors.grey)))
                  : _reportDateFrom == null
                      ? const Center(child: Text('กด "แสดงรายงาน" เพื่อดูข้อมูล', style: TextStyle(color: Colors.grey)))
                      : _buildTable(),
        ),
      ],
    );
  }

  Widget _buildReportHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _kTheme.withOpacity(0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('รายงาน Cash Position', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          Text(
            '${_dateFmt.format(DateFormat('yyyy-MM-dd').parse(_reportDateFrom!))} – '
            '${_dateFmt.format(DateFormat('yyyy-MM-dd').parse(_reportDateTo!))}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    double totOpen = 0, totReceipt = 0, totPayment = 0, totClose = 0;
    for (final r in _rows) {
      totOpen    += _parseD(r['opening_balance']);
      totReceipt += _parseD(r['period_receipts']);
      totPayment += _parseD(r['period_payments']);
      totClose   += _parseD(r['closing_balance']);
    }

    const headerStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87);
    const cellStyle   = TextStyle(fontSize: 12);

    return SingleChildScrollView(
      child: DataTable(
        headingRowHeight: 38,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 40,
        columnSpacing: 16,
        headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
        headingTextStyle: headerStyle,
        columns: const [
          DataColumn(label: Text('บัญชีธนาคาร')),
          DataColumn(label: Text('ธนาคาร')),
          DataColumn(label: Text('สกุลเงิน')),
          DataColumn(label: Text('ยอดเปิด'),      numeric: true),
          DataColumn(label: Text('รับเข้า'),       numeric: true),
          DataColumn(label: Text('จ่ายออก'),       numeric: true),
          DataColumn(label: Text('ยอดปิด'),        numeric: true),
        ],
        rows: [
          ..._rows.map((r) {
            final closing = _parseD(r['closing_balance']);
            return DataRow(cells: [
              DataCell(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(r['bank_account_code'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text(r['bank_account_name'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              )),
              DataCell(Text(r['bank_short_name'] ?? '', style: cellStyle)),
              DataCell(Text(r['currency_code'] ?? 'THB', style: cellStyle)),
              DataCell(Text(_fmt.format(_parseD(r['opening_balance'])), style: cellStyle)),
              DataCell(Text(_fmt.format(_parseD(r['period_receipts'])),
                  style: cellStyle.copyWith(color: Colors.green.shade700))),
              DataCell(Text(_fmt.format(_parseD(r['period_payments'])),
                  style: cellStyle.copyWith(color: Colors.red.shade700))),
              DataCell(Text(_fmt.format(closing),
                  style: cellStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: closing >= 0 ? Colors.black87 : Colors.red.shade700,
                  ))),
            ]);
          }),
          // Totals row
          DataRow(
            color: WidgetStateProperty.all(Colors.blueGrey.shade50),
            cells: [
              const DataCell(Text('รวมทั้งสิ้น', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              const DataCell(Text('')),
              const DataCell(Text('')),
              DataCell(Text(_fmt.format(totOpen),    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataCell(Text(_fmt.format(totReceipt), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green.shade700))),
              DataCell(Text(_fmt.format(totPayment), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red.shade700))),
              DataCell(Text(_fmt.format(totClose),   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: totClose >= 0 ? Colors.black87 : Colors.red.shade700))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _datePicker(String label, DateTime? value, void Function(DateTime) onPick) {
    return InkWell(
      onTap: () async {
        final p = await showDatePicker(
          context: context, initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000), lastDate: DateTime(2100),
        );
        if (p != null) onPick(p);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
        child: Row(
          children: [
            Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            Text(value != null ? _dateFmt.format(value) : '—', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }
}
