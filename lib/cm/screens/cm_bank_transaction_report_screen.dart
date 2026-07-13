// lib/cm/screens/cm_bank_transaction_report_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../models/cm_bank_account.dart';
import '../services/cm_bank_account_service.dart';
import '../services/cm_report_service.dart';

const _kTheme = Color(0xFF1565C0);
final _fmt     = NumberFormat('#,##0.00', 'en_US');
final _dateFmt = DateFormat('dd/MM/yyyy');

class CmBankTransactionReportScreen extends StatefulWidget {
  const CmBankTransactionReportScreen({super.key});
  @override
  State<CmBankTransactionReportScreen> createState() => _State();
}

class _State extends State<CmBankTransactionReportScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _accSvc = CmBankAccountService();
  final _rptSvc = CmReportService();

  bool _leftExpanded = true;
  List<CmBankAccount> _accounts = [];
  CmBankAccount? _selectedAccount;

  DateTime? _dateFrom;
  DateTime? _dateTo;
  String _recordType = 'All'; // All / RECEIPT / PAYMENT
  bool _loading = false;

  // Report data
  List<Map<String, dynamic>> _txs = [];
  double _openingBalance  = 0;
  double _totalCredit     = 0;
  double _totalDebit      = 0;
  double _closingBalance  = 0;
  String? _reportDateFrom;
  String? _reportDateTo;

  static const _recordTypes = ['All', 'RECEIPT', 'PAYMENT'];
  static const _recordTypeLabels = {'All': 'ทุกประเภท', 'RECEIPT': 'รับเงิน', 'PAYMENT': 'จ่ายเงิน'};

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
      setState(() {
        _accounts = all.where((a) => a.cmType == 'BANK' && a.isActive).toList();
        if (_accounts.isNotEmpty) _selectedAccount ??= _accounts.first;
      });
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _loadReport() async {
    if (_selectedAccount == null) { _showError('กรุณาเลือกบัญชีธนาคาร'); return; }
    if (_dateFrom == null || _dateTo == null) { _showError('กรุณาระบุช่วงวันที่'); return; }
    setState(() { _loading = true; _txs = []; });
    try {
      final df = DateFormat('yyyy-MM-dd').format(_dateFrom!);
      final dt = DateFormat('yyyy-MM-dd').format(_dateTo!);
      final data = await _rptSvc.getBankTransactions(
        bankAccountId: _selectedAccount!.id!,
        dateFrom: df, dateTo: dt,
        recordType: _recordType == 'All' ? null : _recordType,
      );
      if (!mounted) return;
      setState(() {
        _txs            = List<Map<String, dynamic>>.from(data['transactions'] as List);
        _openingBalance = _parseD(data['opening_balance']);
        _totalCredit    = _parseD(data['total_credit']);
        _totalDebit     = _parseD(data['total_debit']);
        _closingBalance = _parseD(data['closing_balance']);
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
            // Left panel — bank account selector (required)
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
          Expanded(
            child: _accounts.isEmpty
                ? const Center(child: Text('ไม่มีบัญชี', style: TextStyle(fontSize: 12, color: Colors.grey)))
                : ListView.builder(
                    itemCount: _accounts.length,
                    itemBuilder: (_, i) {
                      final acc = _accounts[i];
                      final selected = acc.id == _selectedAccount?.id;
                      return ListTile(
                        dense: true, selected: selected,
                        selectedTileColor: _kTheme.withOpacity(0.15),
                        title: Text(acc.accountCode, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${acc.bankShortName ?? ''} ${acc.accountNumber ?? ''}\n${acc.currencyCode}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        isThreeLine: true,
                        onTap: () => setState(() {
                          _selectedAccount = acc;
                          _txs = [];
                          _reportDateFrom = null;
                        }),
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
          child: Wrap(
            spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _datePicker('ตั้งแต่', _dateFrom, (d) => setState(() => _dateFrom = d)),
              _datePicker('ถึง', _dateTo, (d) => setState(() => _dateTo = d)),
              // Record type dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _recordType,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    items: _recordTypes.map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(_recordTypeLabels[t] ?? t),
                    )).toList(),
                    onChanged: (v) => setState(() => _recordType = v!),
                  ),
                ),
              ),
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
        // Header info
        if (_reportDateFrom != null) _buildReportHeader(),
        // Table
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _reportDateFrom == null
                  ? const Center(child: Text('เลือกบัญชีและกด "แสดงรายงาน"', style: TextStyle(color: Colors.grey)))
                  : _txs.isEmpty
                      ? const Center(child: Text('ไม่มีรายการในช่วงเวลานี้', style: TextStyle(color: Colors.grey)))
                      : _buildTable(),
        ),
        // Summary footer
        if (_reportDateFrom != null && !_loading) _buildSummaryFooter(),
      ],
    );
  }

  Widget _buildReportHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: _kTheme.withOpacity(0.08),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'รายงานธุรกรรมธนาคาร: ${_selectedAccount?.accountCode ?? ''} '
                  '(${_selectedAccount?.bankShortName ?? ''})',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_dateFmt.format(DateFormat('yyyy-MM-dd').parse(_reportDateFrom!))} – '
                  '${_dateFmt.format(DateFormat('yyyy-MM-dd').parse(_reportDateTo!))}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          // Opening balance
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('ยอดยกมา', style: TextStyle(fontSize: 11, color: Colors.grey)),
              Text(_fmt.format(_openingBalance),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                      color: _openingBalance >= 0 ? Colors.black87 : Colors.red.shade700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    const headerStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.bold);
    const cellStyle   = TextStyle(fontSize: 12);

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 38,
          dataRowMinHeight: 30,
          dataRowMaxHeight: 38,
          columnSpacing: 16,
          headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
          headingTextStyle: headerStyle,
          columns: const [
            DataColumn(label: Text('วันที่')),
            DataColumn(label: Text('เลขที่เอกสาร')),
            DataColumn(label: Text('ประเภท')),
            DataColumn(label: Text('คำอธิบาย')),
            DataColumn(label: Text('เลขเช็ค')),
            DataColumn(label: Text('จ่าย'),    numeric: true),
            DataColumn(label: Text('รับ'),     numeric: true),
            DataColumn(label: Text('ยอดคงเหลือ'), numeric: true),
          ],
          rows: _txs.map((tx) {
            final isReceipt = tx['record_type'] == 'RECEIPT';
            final balance   = _parseD(tx['running_balance']);
            return DataRow(cells: [
              DataCell(Text(
                tx['record_date'] != null
                    ? _dateFmt.format(DateTime.parse(tx['record_date'].toString()))
                    : '',
                style: cellStyle,
              )),
              DataCell(Text(tx['doc_no'] ?? '', style: cellStyle)),
              DataCell(Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isReceipt ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isReceipt ? Colors.green.shade200 : Colors.orange.shade200),
                ),
                child: Text(
                  isReceipt ? 'รับเงิน' : 'จ่ายเงิน',
                  style: TextStyle(fontSize: 11, color: isReceipt ? Colors.green.shade800 : Colors.orange.shade800),
                ),
              )),
              DataCell(SizedBox(
                width: 200,
                child: Text(tx['description'] ?? '', style: cellStyle, overflow: TextOverflow.ellipsis),
              )),
              DataCell(Text(tx['check_no'] ?? '', style: cellStyle)),
              DataCell(Text(
                _parseD(tx['debit_amount']) > 0 ? _fmt.format(_parseD(tx['debit_amount'])) : '',
                style: cellStyle.copyWith(color: Colors.red.shade700),
              )),
              DataCell(Text(
                _parseD(tx['credit_amount']) > 0 ? _fmt.format(_parseD(tx['credit_amount'])) : '',
                style: cellStyle.copyWith(color: Colors.green.shade700),
              )),
              DataCell(Text(
                _fmt.format(balance),
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold,
                  color: balance >= 0 ? Colors.black87 : Colors.red.shade700,
                ),
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSummaryFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blueGrey.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _summaryItem('รวมจ่าย', _totalDebit,   Colors.red.shade700),
          const SizedBox(width: 24),
          _summaryItem('รวมรับ',  _totalCredit, Colors.green.shade700),
          const SizedBox(width: 24),
          _summaryItem('ยอดปิด', _closingBalance,
              _closingBalance >= 0 ? Colors.black87 : Colors.red.shade700,
              bold: true),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, double value, Color color, {bool bold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(_fmt.format(value),
            style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: color)),
      ],
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
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            Text(value != null ? _dateFmt.format(value) : '—',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }
}
