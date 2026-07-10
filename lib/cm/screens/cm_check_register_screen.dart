// lib/cm/screens/cm_check_register_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../sa/utils/menu_scope.dart';
import '../models/cm_bank_account.dart';
import '../services/cm_bank_account_service.dart';
import '../services/cm_report_service.dart';

const _kTheme = Color(0xFF1565C0);
final _fmt     = NumberFormat('#,##0.00', 'en_US');
final _dateFmt = DateFormat('dd/MM/yyyy');

class CmCheckRegisterScreen extends StatefulWidget {
  const CmCheckRegisterScreen({super.key});
  @override
  State<CmCheckRegisterScreen> createState() => _State();
}

class _State extends State<CmCheckRegisterScreen>
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
  String _checkType = 'All'; // All / RECEIVED / ISSUED
  String _status    = 'All'; // All / Pending / Cleared / Bounced / Voided

  bool _loading = false;
  List<Map<String, dynamic>> _checks = [];
  double _totalIssued   = 0;
  double _totalReceived = 0;
  String? _reportDateFrom;
  String? _reportDateTo;

  static const _checkTypes   = ['All', 'RECEIVED', 'ISSUED'];
  static const _checkLabels  = {'All': 'ทุกประเภท', 'RECEIVED': 'รับเช็ค', 'ISSUED': 'จ่ายเช็ค'};
  static const _statusOptions = ['All', 'Pending', 'Cleared', 'Bounced', 'Voided'];
  static const _statusLabels  = {
    'All': 'ทุกสถานะ', 'Pending': 'รอเรียกเก็บ',
    'Cleared': 'ผ่านเรียบร้อย', 'Bounced': 'เช็คคืน', 'Voided': 'ยกเลิก',
  };

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
    setState(() { _loading = true; _checks = []; });
    try {
      final df = DateFormat('yyyy-MM-dd').format(_dateFrom!);
      final dt = DateFormat('yyyy-MM-dd').format(_dateTo!);
      final data = await _rptSvc.getCheckRegister(
        bankAccountId: _selectedAccount?.id,
        dateFrom: df, dateTo: dt,
        checkType: _checkType == 'All' ? null : _checkType,
        status:    _status    == 'All' ? null : _status,
      );
      if (!mounted) return;
      setState(() {
        _checks       = List<Map<String, dynamic>>.from(data['checks'] as List);
        _totalIssued  = _parseD(data['total_issued']);
        _totalReceived= _parseD(data['total_received']);
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
            // Left panel — bank account (optional, can show all)
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
          // All accounts option
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
          child: Wrap(
            spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _datePicker('ตั้งแต่', _dateFrom, (d) => setState(() => _dateFrom = d)),
              _datePicker('ถึง', _dateTo, (d) => setState(() => _dateTo = d)),
              _dropdownFilter('ประเภทเช็ค', _checkType, _checkTypes, _checkLabels,
                  (v) => setState(() => _checkType = v!)),
              _dropdownFilter('สถานะ', _status, _statusOptions, _statusLabels,
                  (v) => setState(() => _status = v!)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white,
                    minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 12)),
                onPressed: _loading ? null : _loadReport,
                icon: _loading
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.list_alt, size: 16),
                label: const Text('แสดงรายงาน', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Report header
        if (_reportDateFrom != null) _buildReportHeader(),
        // Table
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _reportDateFrom == null
                  ? const Center(child: Text('กด "แสดงรายงาน" เพื่อดูข้อมูล', style: TextStyle(color: Colors.grey)))
                  : _checks.isEmpty
                      ? const Center(child: Text('ไม่มีเช็คในช่วงเวลานี้', style: TextStyle(color: Colors.grey)))
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ทะเบียนเช็ค', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
            DataColumn(label: Text('ประเภท')),
            DataColumn(label: Text('วันที่')),
            DataColumn(label: Text('เลขเช็ค')),
            DataColumn(label: Text('วันที่เช็ค')),
            DataColumn(label: Text('บัญชีธนาคาร')),
            DataColumn(label: Text('คู่ค้า')),
            DataColumn(label: Text('จำนวนเงิน'), numeric: true),
            DataColumn(label: Text('เลขที่เอกสาร')),
            DataColumn(label: Text('สถานะ')),
          ],
          rows: _checks.map((c) {
            final isReceived = c['check_type'] == 'RECEIVED';
            final amount = _parseD(c['amount_lc']);
            final status = c['status']?.toString() ?? '';
            return DataRow(cells: [
              // Type chip
              DataCell(Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isReceived ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isReceived ? Colors.green.shade200 : Colors.orange.shade200),
                ),
                child: Text(
                  isReceived ? 'รับเช็ค' : 'จ่ายเช็ค',
                  style: TextStyle(fontSize: 11, color: isReceived ? Colors.green.shade800 : Colors.orange.shade800),
                ),
              )),
              // Record date
              DataCell(Text(
                c['record_date'] != null ? _dateFmt.format(DateTime.parse(c['record_date'].toString())) : '',
                style: cellStyle,
              )),
              DataCell(Text(c['check_no'] ?? '', style: cellStyle.copyWith(fontWeight: FontWeight.w600))),
              // Check date
              DataCell(Text(
                c['check_date'] != null ? _dateFmt.format(DateTime.parse(c['check_date'].toString())) : '—',
                style: cellStyle,
              )),
              DataCell(Text(c['bank_account_code'] ?? '', style: cellStyle)),
              DataCell(SizedBox(
                width: 180,
                child: Text(c['party_name'] ?? '', style: cellStyle, overflow: TextOverflow.ellipsis),
              )),
              DataCell(Text(_fmt.format(amount),
                  style: cellStyle.copyWith(fontWeight: FontWeight.w600,
                      color: isReceived ? Colors.green.shade700 : Colors.red.shade700))),
              DataCell(Text(c['doc_no'] ?? '', style: cellStyle)),
              // Status chip
              DataCell(_buildStatusChip(status)),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg, fg;
    String label;
    switch (status) {
      case 'Cleared':
        bg = Colors.green.shade100; fg = Colors.green.shade800; label = 'ผ่านแล้ว';
      case 'Bounced':
        bg = Colors.red.shade100;   fg = Colors.red.shade800;   label = 'เช็คคืน';
      case 'Voided':
        bg = Colors.grey.shade200;  fg = Colors.grey.shade700;  label = 'ยกเลิก';
      default:
        bg = Colors.blue.shade50;   fg = Colors.blue.shade800;  label = 'รอเรียกเก็บ';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 11, color: fg)),
    );
  }

  Widget _buildSummaryFooter() {
    final issuedCount   = _checks.where((c) => c['check_type'] == 'ISSUED').length;
    final receivedCount = _checks.where((c) => c['check_type'] == 'RECEIVED').length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blueGrey.shade50,
      child: Row(
        children: [
          Text('รับเช็ค: $receivedCount รายการ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 16),
          Text('จ่ายเช็ค: $issuedCount รายการ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const Spacer(),
          _summaryItem('รวมรับเช็ค', _totalReceived, Colors.green.shade700),
          const SizedBox(width: 24),
          _summaryItem('รวมจ่ายเช็ค', _totalIssued, Colors.red.shade700, bold: true),
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

  Widget _dropdownFilter(String label, String value, List<String> options,
      Map<String, String> labels, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              items: options.map((o) => DropdownMenuItem(value: o, child: Text(labels[o] ?? o))).toList(),
              onChanged: onChanged,
            ),
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
