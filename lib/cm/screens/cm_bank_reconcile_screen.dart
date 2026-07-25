// lib/cm/screens/cm_bank_reconcile_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../models/cm_bank_account.dart';
import '../models/cm_bank_statement.dart';
import '../services/cm_bank_account_service.dart';
import '../services/cm_bank_statement_service.dart';
import '../../utils/date_utils.dart';

const _kTheme = Color(0xFF1565C0);
final _fmt = NumberFormat('#,##0.00', 'en_US');
final _dateFmt = DateFormat('dd/MM/yyyy');

class CmBankReconcileScreen extends StatefulWidget {
  const CmBankReconcileScreen({super.key});
  @override
  State<CmBankReconcileScreen> createState() => _CmBankReconcileScreenState();
}

class _CmBankReconcileScreenState extends State<CmBankReconcileScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _accSvc  = CmBankAccountService();
  final _svc     = CmBankStatementService();

  bool _leftExpanded = true;
  List<CmBankAccount> _accounts = [];
  CmBankAccount? _selectedAccount;

  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _unreconciledOnly = true;

  List<CmBankStatementLine> _stmtLines = [];
  List<CmReconcileRecord>   _cmRecords = [];
  bool _loading = false;

  // Selection
  CmBankStatementLine? _selLine;
  CmReconcileRecord?   _selRecord;

  // Summary data
  Map<String, dynamic>? _summary;

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

  Future<void> _loadItems() async {
    if (_selectedAccount?.id == null || _dateFrom == null || _dateTo == null) return;
    setState(() { _loading = true; _selLine = null; _selRecord = null; });
    try {
      final data = await _svc.fetchReconcileItems(
        bankAccountId: _selectedAccount!.id!,
        dateFrom: formatLocalDate(_dateFrom!),
        dateTo:   formatLocalDate(_dateTo!),
        unreconciledOnly: _unreconciledOnly,
      );
      final summary = await _svc.getReconcileSummary(
        bankAccountId: _selectedAccount!.id!,
        dateFrom: formatLocalDate(_dateFrom!),
        dateTo:   formatLocalDate(_dateTo!),
      );
      if (!mounted) return;
      final lines = (data['statement_lines'] as List)
          .map((e) => CmBankStatementLine.fromJson(e as Map<String, dynamic>))
          .toList();
      final records = (data['cm_records'] as List)
          .map((e) => CmReconcileRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _stmtLines = lines;
        _cmRecords = records;
        _summary   = summary;
        _loading   = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(e.toString());
    }
  }

  Future<void> _reconcilePair() async {
    if (_selLine == null || _selRecord == null) return;
    try {
      await _svc.reconcilePair(
        statementLineId: _selLine!.id,
        cmRecordType:    _selRecord!.recordType,
        cmRecordId:      _selRecord!.id,
        reconcileDate:   formatLocalDate(DateTime.now()),
      );
      _showSuccess('จับคู่สำเร็จ');
      await _loadItems();
    } catch (e) { _showError(e.toString()); }
  }

  Future<void> _unreconcileLine(CmBankStatementLine line) async {
    try {
      await _svc.unreconcileStatementLine(line.id);
      _showSuccess('ยกเลิกการจับคู่สำเร็จ');
      await _loadItems();
    } catch (e) { _showError(e.toString()); }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green.shade700));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
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
                padding: EdgeInsets.zero,
                iconSize: 20,
                color: Colors.white,
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
            // Right panel
            Expanded(child: _buildRightPanel()),
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
            height: 36,
            color: Colors.blueGrey.shade200,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: const Text('บัญชีธนาคาร', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _accounts.length,
              itemBuilder: (_, i) {
                final acc = _accounts[i];
                final selected = acc.id == _selectedAccount?.id;
                return ListTile(
                  dense: true,
                  selected: selected,
                  selectedTileColor: _kTheme.withOpacity(0.15),
                  title: Text(acc.accountCode, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${acc.bankShortName ?? ''} ${acc.accountNumber ?? ''}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedAccount = acc;
                      _stmtLines = [];
                      _cmRecords = [];
                      _summary   = null;
                      _selLine   = null;
                      _selRecord = null;
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPanel() {
    if (_selectedAccount == null) {
      return const Center(child: Text('เลือกบัญชีธนาคาร', style: TextStyle(color: Colors.grey)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFilterBar(),
        const Divider(height: 1),
        if (_summary != null) _buildSummaryBar(),
        // Reconcile action bar
        if (_stmtLines.isNotEmpty || _cmRecords.isNotEmpty)
          _buildActionBar(),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : (_stmtLines.isEmpty && _cmRecords.isEmpty)
                  ? const Center(child: Text('ไม่มีข้อมูล กด "โหลดข้อมูล" เพื่อดูรายการ', style: TextStyle(color: Colors.grey)))
                  : _buildReconcileView(),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          _datePicker('ตั้งแต่', _dateFrom, (d) => setState(() => _dateFrom = d)),
          const SizedBox(width: 12),
          _datePicker('ถึง', _dateTo, (d) => setState(() => _dateTo = d)),
          const SizedBox(width: 16),
          Row(children: [
            Checkbox(
              value: _unreconciledOnly,
              onChanged: (v) => setState(() => _unreconciledOnly = v ?? true),
              visualDensity: VisualDensity.compact,
            ),
            const Text('เฉพาะที่ยังไม่จับคู่', style: TextStyle(fontSize: 12)),
          ]),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kTheme,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: _loadItems,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('โหลดข้อมูล', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _datePicker(String label, DateTime? value, void Function(DateTime) onPick) {
    return InkWell(
      onTap: () async {
        final p = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
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

  Widget _buildSummaryBar() {
    final s = _summary!;
    final stmtDep  = double.tryParse(s['statement']?['total_deposit']?.toString()    ?? '0') ?? 0;
    final stmtWd   = double.tryParse(s['statement']?['total_withdrawal']?.toString() ?? '0') ?? 0;
    final recAmt   = double.tryParse(s['receipts']?['total']?.toString()             ?? '0') ?? 0;
    final payAmt   = double.tryParse(s['payments']?['total']?.toString()             ?? '0') ?? 0;
    final stmtRec  = int.tryParse(s['statement']?['reconciled_count']?.toString()   ?? '0') ?? 0;
    final stmtUnr  = int.tryParse(s['statement']?['unreconciled_count']?.toString() ?? '0') ?? 0;
    final cmRec    = (int.tryParse(s['receipts']?['reconciled_count']?.toString()   ?? '0') ?? 0)
                   + (int.tryParse(s['payments']?['reconciled_count']?.toString()   ?? '0') ?? 0);
    final cmUnr    = (int.tryParse(s['receipts']?['unreconciled_count']?.toString() ?? '0') ?? 0)
                   + (int.tryParse(s['payments']?['unreconciled_count']?.toString() ?? '0') ?? 0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.blue.shade50,
      child: Row(
        children: [
          _summaryItem('รับเข้าตาม Statement', _fmt.format(stmtDep), Colors.green.shade700),
          const SizedBox(width: 24),
          _summaryItem('จ่ายออกตาม Statement', _fmt.format(stmtWd), Colors.red.shade700),
          const SizedBox(width: 24),
          _summaryItem('ยอดรับตามระบบ CM', _fmt.format(recAmt), Colors.green.shade600),
          const SizedBox(width: 24),
          _summaryItem('ยอดจ่ายตามระบบ CM', _fmt.format(payAmt), Colors.red.shade600),
          const Spacer(),
          _summaryItem('Statement (จับคู่/ยังไม่จับ)', '$stmtRec / $stmtUnr', Colors.blue.shade700),
          const SizedBox(width: 16),
          _summaryItem('CM Record (จับคู่/ยังไม่จับ)', '$cmRec / $cmUnr', Colors.blue.shade700),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    ],
  );

  Widget _buildActionBar() {
    final canMatch = _selLine != null && _selRecord != null
        && !_selLine!.isReconciled && !_selRecord!.isReconciled;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.amber.shade50,
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 14, color: Colors.orange),
          const SizedBox(width: 6),
          Text(
            _selLine == null && _selRecord == null
                ? 'เลือก Statement Line และ CM Record เพื่อจับคู่'
                : _selLine == null
                    ? 'เลือก Statement Line'
                    : _selRecord == null
                        ? 'เลือก CM Record'
                        : canMatch
                            ? 'พร้อมจับคู่: ${_dateFmt.format(_selLine!.lineDate)} ↔ ${_selRecord!.docNo ?? ''}'
                            : 'รายการที่เลือกถูกจับคู่แล้ว',
            style: const TextStyle(fontSize: 12),
          ),
          const Spacer(),
          if (_selLine != null && _selLine!.isReconciled)
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red,
                  minimumSize: const Size(0, 28), padding: const EdgeInsets.symmetric(horizontal: 10)),
              onPressed: () => _unreconcileLine(_selLine!),
              child: const Text('ยกเลิกจับคู่ Statement Line', style: TextStyle(fontSize: 12)),
            ),
          if (canMatch) ...[
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white,
                  minimumSize: const Size(0, 28), padding: const EdgeInsets.symmetric(horizontal: 12)),
              onPressed: _reconcilePair,
              icon: const Icon(Icons.link, size: 16),
              label: const Text('จับคู่', style: TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReconcileView() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Statement lines
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 36,
                color: Colors.blueGrey.shade200,
                alignment: Alignment.center,
                child: Text('Bank Statement Lines (${_stmtLines.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              Expanded(
                child: _stmtLines.isEmpty
                    ? const Center(child: Text('ไม่มีรายการ Statement', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: _stmtLines.length,
                        itemBuilder: (_, i) => _buildStmtLineCard(_stmtLines[i]),
                      ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        // CM Records
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 36,
                color: Colors.blueGrey.shade200,
                alignment: Alignment.center,
                child: Text('CM Records (${_cmRecords.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              Expanded(
                child: _cmRecords.isEmpty
                    ? const Center(child: Text('ไม่มี CM Record', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: _cmRecords.length,
                        itemBuilder: (_, i) => _buildCmRecordCard(_cmRecords[i]),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStmtLineCard(CmBankStatementLine line) {
    final selected  = _selLine?.id == line.id;
    final isReconciled = line.isReconciled;
    return InkWell(
      onTap: () => setState(() => _selLine = selected ? null : line),
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? _kTheme.withOpacity(0.12)
              : isReconciled
                  ? Colors.green.shade50
                  : null,
          border: Border(
            left: BorderSide(width: 4, color: selected ? _kTheme : isReconciled ? Colors.green.shade400 : Colors.transparent),
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            isReconciled
                ? const Icon(Icons.check_circle, color: Colors.green, size: 16)
                : const Icon(Icons.radio_button_unchecked, color: Colors.grey, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(_dateFmt.format(line.lineDate), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    if (line.reference != null) ...[
                      const SizedBox(width: 8),
                      Text(line.reference!, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ]),
                  if (line.description != null)
                    Text(line.description!, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (line.depositAmount > 0)
                  Text('+${_fmt.format(line.depositAmount)}',
                      style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                if (line.withdrawalAmount > 0)
                  Text('-${_fmt.format(line.withdrawalAmount)}',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                Text(_fmt.format(line.balance), style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCmRecordCard(CmReconcileRecord rec) {
    final selected = _selRecord?.id == rec.id && _selRecord?.recordType == rec.recordType;
    final isReceipt = rec.recordType == 'RECEIPT';
    final isReconciled = rec.isReconciled;
    final amtStr = isReceipt ? '+${_fmt.format(rec.amount)}' : '-${_fmt.format(rec.amount.abs())}';
    final amtColor = isReceipt ? Colors.green.shade700 : Colors.red.shade700;
    return InkWell(
      onTap: () => setState(() => _selRecord = selected ? null : rec),
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? _kTheme.withOpacity(0.12)
              : isReconciled
                  ? Colors.green.shade50
                  : null,
          border: Border(
            left: BorderSide(width: 4, color: selected ? _kTheme : isReconciled ? Colors.green.shade400 : Colors.transparent),
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            isReconciled
                ? const Icon(Icons.check_circle, color: Colors.green, size: 16)
                : const Icon(Icons.radio_button_unchecked, color: Colors.grey, size: 16),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (isReceipt ? Colors.green.shade100 : Colors.red.shade100),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(isReceipt ? 'รับ' : 'จ่าย',
                  style: TextStyle(fontSize: 10, color: isReceipt ? Colors.green.shade800 : Colors.red.shade800)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(_dateFmt.format(rec.recordDate), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    if (rec.docNo != null) ...[
                      const SizedBox(width: 8),
                      Text(rec.docNo!, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                    ],
                  ]),
                  if (rec.description != null)
                    Text(rec.description!, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text(amtStr, style: TextStyle(fontSize: 12, color: amtColor, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
