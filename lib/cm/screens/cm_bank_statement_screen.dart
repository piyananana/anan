// lib/cm/screens/cm_bank_statement_screen.dart
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import 'package:intl/intl.dart';
import '../models/cm_bank_account.dart';
import '../models/cm_bank_statement.dart';
import '../services/cm_bank_account_service.dart';
import '../services/cm_bank_statement_service.dart';
import '../../utils/date_utils.dart';

const _kTheme = Color(0xFF1565C0);
final _fmt = NumberFormat('#,##0.00', 'en_US');
final _dateFmt = DateFormat('dd/MM/yyyy');

class CmBankStatementScreen extends StatefulWidget {
  const CmBankStatementScreen({super.key});
  @override
  State<CmBankStatementScreen> createState() => _CmBankStatementScreenState();
}

class _CmBankStatementScreenState extends State<CmBankStatementScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _accSvc  = CmBankAccountService();
  final _stmtSvc = CmBankStatementService();

  bool _isEnglish = false;

  bool _leftExpanded = true;
  double _leftWidth  = 420.0;
  bool _isDragging   = false;
  List<CmBankAccount> _accounts = [];
  CmBankAccount? _selectedAccount;
  String _acctSearch = '';

  List<CmBankAccount> get _filteredAccounts {
    if (_acctSearch.isEmpty) return _accounts;
    final q = _acctSearch.toLowerCase();
    return _accounts.where((a) =>
        a.accountCode.toLowerCase().contains(q) ||
        (a.bankShortName ?? '').toLowerCase().contains(q) ||
        (a.accountNumber ?? '').toLowerCase().contains(q)).toList();
  }

  List<CmBankStatement> _statements = [];
  CmBankStatement? _selectedStatement;
  bool _loadingStmts = false;

  List<CmBankStatementLine> _lines = [];
  bool _loadingLines = false;

  // filters
  String _statusFilter = 'All';
  DateTime? _filterFrom;
  DateTime? _filterTo;
  String _stmtSearch = '';

  List<CmBankStatement> get _filteredStatements {
    if (_stmtSearch.isEmpty) return _statements;
    final q = _stmtSearch.toLowerCase();
    return _statements.where((s) =>
        (s.fileName ?? '').toLowerCase().contains(q) ||
        _dateFmt.format(s.statementDateFrom).contains(q) ||
        _dateFmt.format(s.statementDateTo).contains(q)).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final all = await _accSvc.fetchRows();
      if (!mounted) return;
      setState(() {
        _accounts = all.where((a) => a.cmType == 'BANK' && a.isActive).toList();
      });
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _loadStatements() async {
    if (_selectedAccount?.id == null) return;
    setState(() { _loadingStmts = true; });
    try {
      final list = await _stmtSvc.fetchStatements(
        bankAccountId: _selectedAccount!.id,
        status:   _statusFilter == 'All' ? null : _statusFilter,
        dateFrom: _filterFrom != null ? formatLocalDate(_filterFrom!) : null,
        dateTo:   _filterTo   != null ? formatLocalDate(_filterTo!)   : null,
      );
      if (!mounted) return;
      setState(() { _statements = list; _loadingStmts = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadingStmts = false; });
      _showError(e.toString());
    }
  }

  Future<void> _loadLines() async {
    if (_selectedStatement == null) return;
    setState(() { _loadingLines = true; });
    try {
      final list = await _stmtSvc.fetchLines(_selectedStatement!.id);
      if (!mounted) return;
      setState(() { _lines = list; _loadingLines = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadingLines = false; });
      _showError(e.toString());
    }
  }

  void _selectAccount(CmBankAccount acc) {
    setState(() {
      _selectedAccount   = acc;
      _selectedStatement = null;
      _lines             = [];
      _statements        = [];
    });
    _loadStatements();
  }

  void _selectStatement(CmBankStatement s) {
    setState(() { _selectedStatement = s; _lines = []; });
    _loadLines();
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

  // ── Create / Edit statement header ─────────────────────────────────────────
  Future<void> _openStatementForm({CmBankStatement? existing}) async {
    final perm = MenuScope.of(context);
    if (!(existing == null ? (perm?.canCreate ?? true) : (perm?.canEdit ?? true))) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _StatementFormDialog(
        accountId: _selectedAccount!.id!,
        existing: existing,
        service: _stmtSvc,
      ),
    );
    if (result == true) {
      await _loadStatements();
      if (existing != null) {
        // Refresh selected statement
        final updated = _statements.where((s) => s.id == existing.id).firstOrNull;
        if (updated != null) setState(() => _selectedStatement = updated);
      }
    }
  }

  Future<void> _confirmStatement() async {
    if (!(MenuScope.of(context)?.canEdit ?? true)) return;
    if (_selectedStatement == null) return;
    try {
      final updated = await _stmtSvc.confirmStatement(_selectedStatement!.id);
      setState(() { _selectedStatement = updated; });
      await _loadStatements();
      _showSuccess(_isEnglish ? 'Statement confirmed successfully' : 'ยืนยัน Statement สำเร็จ');
    } catch (e) { _showError(e.toString()); }
  }

  Future<void> _voidStatement() async {
    if (!(MenuScope.of(context)?.canDelete ?? true)) return;
    final l = AppL10n(Provider.of<LanguageProvider>(context, listen: false).isEnglish);
    final isEnglish = _isEnglish;
    if (_selectedStatement == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEnglish ? 'Confirm Void' : 'ยืนยันการยกเลิก'),
        content: Text(isEnglish ? 'Void this Bank Statement?' : 'ต้องการยกเลิก Bank Statement นี้ใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: Text(l.confirm)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final updated = await _stmtSvc.voidStatement(_selectedStatement!.id);
      setState(() { _selectedStatement = updated; });
      await _loadStatements();
      _showSuccess(isEnglish ? 'Statement voided successfully' : 'ยกเลิก Statement สำเร็จ');
    } catch (e) { _showError(e.toString()); }
  }

  Future<void> _deleteStatement() async {
    if (!(MenuScope.of(context)?.canDelete ?? true)) return;
    final l = AppL10n(Provider.of<LanguageProvider>(context, listen: false).isEnglish);
    final isEnglish = _isEnglish;
    if (_selectedStatement == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEnglish ? 'Confirm Delete' : 'ยืนยันการลบ'),
        content: Text(isEnglish
            ? 'Delete this Bank Statement and all its lines?'
            : 'ต้องการลบ Bank Statement และรายการทั้งหมดใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: Text(l.delete)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _stmtSvc.deleteStatement(_selectedStatement!.id);
      setState(() { _selectedStatement = null; _lines = []; });
      await _loadStatements();
      _showSuccess(isEnglish ? 'Deleted successfully' : 'ลบสำเร็จ');
    } catch (e) { _showError(e.toString()); }
  }

  // ── Line operations ────────────────────────────────────────────────────────
  Future<void> _openLineForm({CmBankStatementLine? existing}) async {
    if (_selectedStatement == null) return;
    final perm = MenuScope.of(context);
    if (!(existing == null ? (perm?.canCreate ?? true) : (perm?.canEdit ?? true))) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _LineFormDialog(
        statementId: _selectedStatement!.id,
        existing: existing,
        service: _stmtSvc,
      ),
    );
    if (result == true) await _loadLines();
  }

  Future<void> _deleteLine(CmBankStatementLine line) async {
    if (!(MenuScope.of(context)?.canDelete ?? true)) return;
    try {
      await _stmtSvc.deleteLine(line.id);
      await _loadLines();
    } catch (e) { _showError(e.toString()); }
  }

  Future<void> _importCsv() async {
    if (_selectedStatement == null) return;
    if (!(MenuScope.of(context)?.canCreate ?? true)) return;
    final result = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CsvImportDialog(),
    );
    if (result == null || result.isEmpty) return;
    try {
      final resp = await _stmtSvc.bulkInsertLines(
        _selectedStatement!.id,
        result,
      );
      await _loadLines();
      // Refresh statement to get updated closing_balance
      final stmts = await _stmtSvc.fetchStatements(bankAccountId: _selectedAccount!.id);
      final updated = stmts.where((s) => s.id == _selectedStatement!.id).firstOrNull;
      if (mounted && updated != null) {
        setState(() {
          _statements = stmts;
          _selectedStatement = updated;
        });
      }
      _showSuccess('${resp['message']}');
    } catch (e) { _showError(e.toString()); }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
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
      body: LayoutBuilder(
        builder: (_, constraints) {
          final maxLeft = (constraints.maxWidth - 36 - 5 - 320).clamp(100.0, double.infinity);
          return Row(
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
              // Left panel — account list
              AnimatedContainer(
                duration: _isDragging ? Duration.zero : const Duration(milliseconds: 200),
                width: _leftExpanded ? _leftWidth : 0,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    maxWidth: _leftWidth,
                    minWidth: _leftWidth,
                    child: _buildAccountPanel(),
                  ),
                ),
              ),
              // Divider
              if (_leftExpanded)
                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    onHorizontalDragStart: (_) => setState(() => _isDragging = true),
                    onHorizontalDragUpdate: (d) => setState(() {
                      _leftWidth = (_leftWidth + d.delta.dx).clamp(180.0, maxLeft);
                    }),
                    onHorizontalDragEnd: (_) => setState(() => _isDragging = false),
                    child: Container(width: 5, color: Colors.grey[400]),
                  ),
                ),
              // Right panel
              Expanded(child: _buildRightPanel()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAccountPanel() {
    final isEnglish = _isEnglish;
    final list = _filteredAccounts;
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
            child: Text(isEnglish ? 'Bank Accounts' : 'บัญชีธนาคาร',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: InputDecoration(
                hintText: isEnglish ? 'Search account...' : 'ค้นหาบัญชี...',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _acctSearch = v),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(child: Text(isEnglish ? 'No accounts' : 'ไม่มีบัญชี', style: TextStyle(color: Colors.grey.shade400)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final acc = list[i];
                      final selected = acc.id == _selectedAccount?.id;
                      final name = isEnglish && (acc.accountNameEn ?? '').isNotEmpty ? acc.accountNameEn! : acc.accountNameTh;
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          selected: selected,
                          selectedTileColor: _kTheme.withOpacity(0.12),
                          leading: CircleAvatar(
                            backgroundColor: Colors.indigo.shade100,
                            child: const Icon(Icons.savings, size: 18),
                          ),
                          title: Text(acc.accountCode,
                              style: TextStyle(fontWeight: FontWeight.bold, color: acc.isActive ? null : Colors.grey)),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(name,
                                style: TextStyle(fontSize: 13, color: acc.isActive ? Colors.black87 : Colors.grey),
                                overflow: TextOverflow.ellipsis),
                            Text(
                              [
                                cmCmTypeLabel(acc.cmType, isEnglish),
                                if (acc.bankDisplay.isNotEmpty) acc.bankDisplay,
                                if ((acc.accountNumber ?? '').isNotEmpty) acc.accountNumber!,
                                if (!acc.isPettyCash) cmAccountTypeLabel(acc.accountType, isEnglish),
                                if (acc.isFcy) acc.currencyCode,
                                if (acc.isCheckAccount) (isEnglish ? 'Check' : 'เช็ค'),
                              ].join(' · '),
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ]),
                          trailing: !acc.isActive
                              ? Chip(
                                  label: Text(isEnglish ? 'Inactive' : 'หยุดใช้', style: const TextStyle(fontSize: 11)),
                                  backgroundColor: const Color(0xFFEEEEEE),
                                )
                              : null,
                          onTap: () => _selectAccount(acc),
                        ),
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
      return Center(child: Text(_isEnglish ? 'Select a bank account' : 'เลือกบัญชีธนาคาร',
          style: const TextStyle(color: Colors.grey)));
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Statement list sub-panel (280px)
        SizedBox(
          width: 280,
          child: _buildStatementListPanel(),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        // Statement detail
        Expanded(child: _buildStatementDetailPanel()),
      ],
    );
  }

  Widget _buildStatementListPanel() {
    final isEnglish = _isEnglish;
    return Container(
      color: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter bar
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey.shade200,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: isEnglish ? 'Search statement...' : 'ค้นหา statement...',
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _stmtSearch = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _statusFilter,
                  isExpanded: true,
                  decoration: InputDecoration(
                      labelText: isEnglish ? 'Status' : 'สถานะ',
                      border: const OutlineInputBorder()),
                  items: ['All', ...cmStmtStatusOptions.keys]
                      .map((s) => DropdownMenuItem(value: s,
                          child: Text(s == 'All' ? (isEnglish ? 'All' : 'ทั้งหมด') : cmStmtStatusLabel(s, isEnglish))))
                      .toList(),
                  onChanged: (v) { setState(() => _statusFilter = v!); _loadStatements(); },
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 0),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => _openStatementForm(),
                  icon: const Icon(Icons.add),
                  label: Text(isEnglish ? 'Create Statement' : 'สร้าง Statement'),
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: _loadingStmts
                ? const Center(child: CircularProgressIndicator())
                : _filteredStatements.isEmpty
                    ? Center(child: Text(isEnglish ? 'No data' : 'ไม่มีข้อมูล', style: const TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        itemCount: _filteredStatements.length,
                        itemBuilder: (_, i) => _buildStatementCard(_filteredStatements[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatementCard(CmBankStatement s) {
    final selected = s.id == _selectedStatement?.id;
    Color statusColor;
    switch (s.status) {
      case 'Confirmed': statusColor = Colors.green.shade700; break;
      case 'Voided':    statusColor = Colors.red.shade700;   break;
      default:          statusColor = Colors.orange.shade700;
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        selected: selected,
        selectedTileColor: _kTheme.withOpacity(0.12),
        title: Text(
          '${_dateFmt.format(s.statementDateFrom)} – ${_dateFmt.format(s.statementDateTo)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_isEnglish ? 'Closing Balance' : 'ยอดปิด'}: ${_fmt.format(s.closingBalance)}', style: const TextStyle(fontSize: 13)),
            if (s.fileName != null)
              Text(s.fileName!, style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: Chip(
          label: Text(cmStmtStatusLabel(s.status, _isEnglish), style: TextStyle(fontSize: 11, color: statusColor)),
          backgroundColor: statusColor.withOpacity(0.12),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        onTap: () => _selectStatement(s),
      ),
    );
  }

  Widget _buildStatementDetailPanel() {
    final isEnglish = _isEnglish;
    if (_selectedStatement == null) {
      return Center(child: Text(isEnglish ? 'Select a Statement' : 'เลือก Statement',
          style: const TextStyle(color: Colors.grey)));
    }
    final s = _selectedStatement!;
    final canEdit   = s.isDraft;
    final canAddLine = s.isDraft || s.isConfirmed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header info bar
        Container(
          color: Colors.grey.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 24,
                  children: [
                    _infoChip(isEnglish ? 'Date Range' : 'ช่วงวันที่', '${_dateFmt.format(s.statementDateFrom)} – ${_dateFmt.format(s.statementDateTo)}'),
                    _infoChip(isEnglish ? 'Opening Balance' : 'ยอดเปิด', _fmt.format(s.openingBalance)),
                    _infoChip(isEnglish ? 'Closing Balance' : 'ยอดปิด', _fmt.format(s.closingBalance)),
                    _infoChip(isEnglish ? 'Currency' : 'สกุลเงิน', s.currencyCode),
                    if (s.notes != null) _infoChip(isEnglish ? 'Note' : 'หมายเหตุ', s.notes!),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildHeaderActions(s, canEdit),
            ],
          ),
        ),
        const Divider(height: 1),
        // Lines toolbar
        if (canAddLine)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white,
                      minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 10)),
                  onPressed: () => _openLineForm(),
                  icon: const Icon(Icons.add, size: 14),
                  label: Text(isEnglish ? 'Add Item' : 'เพิ่มรายการ', style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white,
                      minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 10)),
                  onPressed: _importCsv,
                  icon: const Icon(Icons.upload_file, size: 14),
                  label: const Text('Import CSV', style: TextStyle(fontSize: 12)),
                ),
                const Spacer(),
                Text(isEnglish ? '${_lines.length} items' : '${_lines.length} รายการ', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        // Lines table
        Expanded(
          child: _loadingLines
              ? const Center(child: CircularProgressIndicator())
              : _lines.isEmpty
                  ? Center(child: Text(isEnglish ? 'No items yet' : 'ยังไม่มีรายการ', style: const TextStyle(color: Colors.grey)))
                  : _buildLinesTable(s),
        ),
      ],
    );
  }

  Widget _infoChip(String label, String value) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('$label: ', style: const TextStyle(fontSize: 11, color: Colors.grey)),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ],
  );

  Widget _buildHeaderActions(CmBankStatement s, bool canEdit) {
    final isEnglish = _isEnglish;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canEdit) ...[
          OutlinedButton(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 10)),
            onPressed: () => _openStatementForm(existing: s),
            child: Text(isEnglish ? 'Edit' : 'แก้ไข', style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white,
                minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 10)),
            onPressed: _confirmStatement,
            child: Text(isEnglish ? 'Confirm' : 'ยืนยัน', style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 6),
        ],
        if (!s.isVoided) ...[
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red,
                minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 10)),
            onPressed: canEdit ? _deleteStatement : _voidStatement,
            child: Text(canEdit ? (isEnglish ? 'Delete' : 'ลบ') : (isEnglish ? 'Void' : 'ยกเลิก'), style: const TextStyle(fontSize: 12)),
          ),
        ],
      ],
    );
  }

  Widget _buildLinesTable(CmBankStatement stmt) {
    final isEnglish = _isEnglish;
    final canEdit = stmt.isDraft;
    return SingleChildScrollView(
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 38,
        columnSpacing: 12,
        headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
        columns: [
          DataColumn(label: Text(isEnglish ? 'Date' : 'วันที่')),
          DataColumn(label: Text(isEnglish ? 'Description' : 'รายการ')),
          DataColumn(label: Text(isEnglish ? 'Withdrawal' : 'ถอน'), numeric: true),
          DataColumn(label: Text(isEnglish ? 'Deposit' : 'ฝาก'), numeric: true),
          DataColumn(label: Text(isEnglish ? 'Balance' : 'คงเหลือ'), numeric: true),
          DataColumn(label: Text(isEnglish ? 'Reference' : 'เลขอ้างอิง')),
          DataColumn(label: Text(isEnglish ? 'Status' : 'สถานะ')),
          if (canEdit) const DataColumn(label: Text('')),
        ],
        rows: _lines.map((line) {
          return DataRow(cells: [
            DataCell(Text(_dateFmt.format(line.lineDate), style: const TextStyle(fontSize: 12))),
            DataCell(SizedBox(
              width: 200,
              child: Text(line.description ?? '', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
            )),
            DataCell(Text(line.withdrawalAmount > 0 ? _fmt.format(line.withdrawalAmount) : '', style: const TextStyle(fontSize: 12))),
            DataCell(Text(line.depositAmount > 0 ? _fmt.format(line.depositAmount) : '', style: const TextStyle(fontSize: 12))),
            DataCell(Text(_fmt.format(line.balance), style: const TextStyle(fontSize: 12))),
            DataCell(Text(line.reference ?? '', style: const TextStyle(fontSize: 12))),
            DataCell(line.isReconciled
                ? const Icon(Icons.check_circle, color: Colors.green, size: 16)
                : const Icon(Icons.radio_button_unchecked, color: Colors.grey, size: 16)),
            if (canEdit)
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 14),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => _openLineForm(existing: line),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => _deleteLine(line),
                  ),
                ],
              )),
          ]);
        }).toList(),
      ),
    );
  }
}

// ─── Statement form dialog ──────────────────────────────────────────────────
class _StatementFormDialog extends StatefulWidget {
  final int accountId;
  final CmBankStatement? existing;
  final CmBankStatementService service;
  const _StatementFormDialog({required this.accountId, this.existing, required this.service});
  @override
  State<_StatementFormDialog> createState() => _StatementFormDialogState();
}

class _StatementFormDialogState extends State<_StatementFormDialog> {
  final _openCtrl   = TextEditingController();
  final _closeCtrl  = TextEditingController();
  final _notesCtrl  = TextEditingController();
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _dateFrom = e.statementDateFrom;
      _dateTo   = e.statementDateTo;
      _openCtrl.text  = e.openingBalance.toString();
      _closeCtrl.text = e.closingBalance.toString();
      _notesCtrl.text = e.notes ?? '';
    } else {
      final now = DateTime.now();
      _dateFrom = DateTime(now.year, now.month, 1);
      _dateTo   = DateTime(now.year, now.month + 1, 0);
    }
  }

  @override
  void dispose() {
    _openCtrl.dispose(); _closeCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isFrom) async {
    final initial = (isFrom ? _dateFrom : _dateTo) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() { if (isFrom) { _dateFrom = picked; } else { _dateTo = picked; } });
  }

  Future<void> _save() async {
    if (_dateFrom == null || _dateTo == null) {
      final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish ? 'Please specify the date range' : 'กรุณาระบุช่วงวันที่')));
      return;
    }
    setState(() => _saving = true);
    try {
      final body = {
        'bank_account_id':      widget.accountId,
        'statement_date_from':  formatLocalDate(_dateFrom!),
        'statement_date_to':    formatLocalDate(_dateTo!),
        'opening_balance':      double.tryParse(_openCtrl.text) ?? 0,
        'closing_balance':      double.tryParse(_closeCtrl.text) ?? 0,
        'notes':                _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
      };
      if (widget.existing != null) {
        await widget.service.updateStatement(widget.existing!.id, body);
      } else {
        await widget.service.createStatement(body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red.shade700));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final l = AppL10n(isEnglish);
    return AlertDialog(
      title: Text(widget.existing != null
          ? (isEnglish ? 'Edit Statement' : 'แก้ไข Statement')
          : (isEnglish ? 'Create Bank Statement' : 'สร้าง Bank Statement')),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: InkWell(
                  onTap: () => _pickDate(true),
                  child: InputDecorator(
                    decoration: InputDecoration(
                        labelText: isEnglish ? 'Start Date' : 'วันที่เริ่ม', border: const OutlineInputBorder(), isDense: true),
                    child: Text(_dateFrom != null ? _dateFmt.format(_dateFrom!) : '—'),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(child: InkWell(
                  onTap: () => _pickDate(false),
                  child: InputDecorator(
                    decoration: InputDecoration(
                        labelText: isEnglish ? 'End Date' : 'วันที่สิ้นสุด', border: const OutlineInputBorder(), isDense: true),
                    child: Text(_dateTo != null ? _dateFmt.format(_dateTo!) : '—'),
                  ),
                )),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(
                  controller: _openCtrl,
                  decoration: InputDecoration(
                      labelText: isEnglish ? 'Opening Balance' : 'ยอดเปิด', border: const OutlineInputBorder(), isDense: true),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                )),
                const SizedBox(width: 12),
                Expanded(child: TextField(
                  controller: _closeCtrl,
                  decoration: InputDecoration(
                      labelText: isEnglish ? 'Closing Balance' : 'ยอดปิด', border: const OutlineInputBorder(), isDense: true),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                )),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              decoration: InputDecoration(
                  labelText: isEnglish ? 'Note' : 'หมายเหตุ', border: const OutlineInputBorder(), isDense: true),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white),
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(l.save),
        ),
      ],
    );
  }
}

// ─── Line form dialog ────────────────────────────────────────────────────────
class _LineFormDialog extends StatefulWidget {
  final int statementId;
  final CmBankStatementLine? existing;
  final CmBankStatementService service;
  const _LineFormDialog({required this.statementId, this.existing, required this.service});
  @override
  State<_LineFormDialog> createState() => _LineFormDialogState();
}

class _LineFormDialogState extends State<_LineFormDialog> {
  DateTime? _date;
  final _descCtrl   = TextEditingController();
  final _wdCtrl     = TextEditingController(text: '0');
  final _depCtrl    = TextEditingController(text: '0');
  final _balCtrl    = TextEditingController(text: '0');
  final _refCtrl    = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _date = e.lineDate;
      _descCtrl.text = e.description ?? '';
      _wdCtrl.text   = e.withdrawalAmount.toString();
      _depCtrl.text  = e.depositAmount.toString();
      _balCtrl.text  = e.balance.toString();
      _refCtrl.text  = e.reference ?? '';
    } else {
      _date = DateTime.now();
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose(); _wdCtrl.dispose(); _depCtrl.dispose();
    _balCtrl.dispose(); _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_date == null) return;
    setState(() => _saving = true);
    try {
      final body = {
        'line_date':         formatLocalDate(_date!),
        'description':       _descCtrl.text.isEmpty ? null : _descCtrl.text,
        'withdrawal_amount': double.tryParse(_wdCtrl.text)  ?? 0,
        'deposit_amount':    double.tryParse(_depCtrl.text) ?? 0,
        'balance':           double.tryParse(_balCtrl.text) ?? 0,
        'reference':         _refCtrl.text.isEmpty ? null : _refCtrl.text,
      };
      if (widget.existing != null) {
        await widget.service.updateLine(widget.existing!.id, body);
      } else {
        await widget.service.addLine(widget.statementId, body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red.shade700));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final l = AppL10n(isEnglish);
    return AlertDialog(
      title: Text(widget.existing != null
          ? (isEnglish ? 'Edit Item' : 'แก้ไขรายการ')
          : (isEnglish ? 'Add Item' : 'เพิ่มรายการ')),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () async {
                final p = await showDatePicker(context: context, initialDate: _date ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                if (p != null) setState(() => _date = p);
              },
              child: InputDecorator(
                decoration: InputDecoration(labelText: isEnglish ? 'Date' : 'วันที่', border: const OutlineInputBorder(), isDense: true),
                child: Text(_date != null ? _dateFmt.format(_date!) : '—'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(controller: _descCtrl, decoration: InputDecoration(labelText: isEnglish ? 'Description' : 'รายการ', border: const OutlineInputBorder(), isDense: true)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: _wdCtrl, decoration: InputDecoration(labelText: isEnglish ? 'Withdrawal' : 'ถอน', border: const OutlineInputBorder(), isDense: true), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _depCtrl, decoration: InputDecoration(labelText: isEnglish ? 'Deposit' : 'ฝาก', border: const OutlineInputBorder(), isDense: true), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _balCtrl, decoration: InputDecoration(labelText: isEnglish ? 'Balance' : 'คงเหลือ', border: const OutlineInputBorder(), isDense: true), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
            ]),
            const SizedBox(height: 10),
            TextField(controller: _refCtrl, decoration: InputDecoration(labelText: isEnglish ? 'Reference' : 'เลขอ้างอิง', border: const OutlineInputBorder(), isDense: true)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white),
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(l.save),
        ),
      ],
    );
  }
}

// ─── CSV Import Dialog ───────────────────────────────────────────────────────
class _CsvImportDialog extends StatefulWidget {
  const _CsvImportDialog();
  @override
  State<_CsvImportDialog> createState() => _CsvImportDialogState();
}

class _CsvImportDialogState extends State<_CsvImportDialog> {
  String? _fileName;
  List<List<String>> _rawRows = [];
  List<List<String>> _previewRows = [];

  int _skipHeader = 1;
  int _skipFooter = 0;
  String _delimiter = ',';
  String _dateFormat = 'DD/MM/YYYY';

  // Column mapping: null = ignore
  int? _dateCol;
  int? _descCol;
  int? _wdCol;
  int? _depCol;
  int? _balCol;
  int? _refCol;
  // Single amount mode: positive = deposit, negative = withdrawal
  bool _singleAmount = false;
  int? _amtCol;

  static const _dateFormats = ['DD/MM/YYYY', 'YYYY-MM-DD', 'DD-MM-YYYY', 'DDMMYYYY', 'YYYYMMDD', 'MM/DD/YYYY'];

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    final content = utf8.decode(file.bytes!, allowMalformed: true);
    final rawLines = content.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    final delim = _detectDelimiter(rawLines.isNotEmpty ? rawLines[0] : '');
    final parsed = rawLines.map((l) => _splitLine(l, delim)).toList();
    setState(() {
      _fileName = file.name;
      _rawRows  = parsed;
      _delimiter = delim;
      _updatePreview();
    });
  }

  String _detectDelimiter(String line) {
    final counts = {',': 0, ';': 0, '\t': 0, '|': 0};
    for (final e in counts.entries) {
      counts[e.key] = e.key.allMatches(line).length;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  List<String> _splitLine(String line, String delim) {
    // Handle quoted CSV fields
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == delim && !inQuotes) {
        result.add(current.toString().trim());
        current = StringBuffer();
      } else {
        current.write(ch);
      }
    }
    result.add(current.toString().trim());
    return result;
  }

  void _updatePreview() {
    if (_rawRows.isEmpty) { _previewRows = []; return; }
    final start = _skipHeader.clamp(0, _rawRows.length);
    final end   = (_rawRows.length - _skipFooter).clamp(start, _rawRows.length);
    _previewRows = _rawRows.sublist(start, end.clamp(start, start + 5));
  }

  int get _numCols => _rawRows.isNotEmpty && _rawRows.length > _skipHeader ? _rawRows[_skipHeader].length : 0;

  DateTime? _parseDate(String s) {
    s = s.replaceAll('"', '').trim();
    try {
      switch (_dateFormat) {
        case 'DD/MM/YYYY': return DateFormat('dd/MM/yyyy').parseStrict(s);
        case 'YYYY-MM-DD': return DateFormat('yyyy-MM-dd').parseStrict(s);
        case 'DD-MM-YYYY': return DateFormat('dd-MM-yyyy').parseStrict(s);
        case 'DDMMYYYY':   return DateFormat('ddMMyyyy').parseStrict(s);
        case 'YYYYMMDD':   return DateFormat('yyyyMMdd').parseStrict(s);
        case 'MM/DD/YYYY': return DateFormat('MM/dd/yyyy').parseStrict(s);
        default:           return DateFormat('dd/MM/yyyy').parseStrict(s);
      }
    } catch (_) {
      return null;
    }
  }

  double _parseAmt(String s) {
    s = s.replaceAll('"', '').replaceAll(',', '').trim();
    return double.tryParse(s) ?? 0;
  }

  List<Map<String, dynamic>>? _buildLines() {
    if (_rawRows.isEmpty || _dateCol == null) return null;
    final start = _skipHeader.clamp(0, _rawRows.length);
    final end   = (_rawRows.length - _skipFooter).clamp(start, _rawRows.length);
    final result = <Map<String, dynamic>>[];
    for (final row in _rawRows.sublist(start, end)) {
      if (row.isEmpty) continue;
      String? cell(int? col) => col != null && col < row.length ? row[col] : null;
      final dateStr = cell(_dateCol);
      if (dateStr == null || dateStr.isEmpty) continue;
      final date = _parseDate(dateStr);
      if (date == null) continue;
      double wd = 0, dep = 0;
      if (_singleAmount && _amtCol != null) {
        final amt = _parseAmt(cell(_amtCol) ?? '');
        if (amt >= 0) { dep = amt; } else { wd = -amt; }
      } else {
        wd  = _parseAmt(cell(_wdCol) ?? '');
        dep = _parseAmt(cell(_depCol) ?? '');
      }
      result.add({
        'line_date':         DateFormat('yyyy-MM-dd').format(date),
        'description':       cell(_descCol),
        'withdrawal_amount': wd,
        'deposit_amount':    dep,
        'balance':           _parseAmt(cell(_balCol) ?? ''),
        'reference':         cell(_refCol),
      });
    }
    return result;
  }

  Widget _colDrop(String label, int? value, void Function(int?) onChanged, bool isEnglish) {
    return DropdownButtonFormField<int?>(
      value: value,
      isExpanded: true,
      isDense: true,
      decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('—', style: TextStyle(fontSize: 12))),
        ...List.generate(_numCols, (i) => DropdownMenuItem<int?>(value: i,
            child: Text('${isEnglish ? 'Column' : 'คอลัมน์'} ${i + 1}', style: const TextStyle(fontSize: 12)))),
      ],
      onChanged: (v) { setState(() { onChanged(v); _updatePreview(); }); },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final l = AppL10n(isEnglish);
    final lines = _buildLines();
    final colCount = _numCols;
    return AlertDialog(
      title: const Text('Import CSV'),
      content: SizedBox(
        width: 700,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // File picker row
            Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white),
                  onPressed: _pickFile,
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: Text(isEnglish ? 'Choose File' : 'เลือกไฟล์'),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(_fileName ?? (isEnglish ? 'No file selected' : 'ยังไม่ได้เลือกไฟล์'), style: const TextStyle(fontSize: 12))),
                if (_rawRows.isNotEmpty)
                  Text(isEnglish ? '${_rawRows.length} lines' : '${_rawRows.length} บรรทัด', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
            if (_rawRows.isNotEmpty) ...[
              const SizedBox(height: 12),
              // Settings row
              Row(children: [
                SizedBox(width: 120, child: DropdownButtonFormField<String>(
                  value: _delimiter,
                  isDense: true,
                  decoration: InputDecoration(labelText: isEnglish ? 'Delimiter' : 'ตัวคั่น', isDense: true, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                  items: const [
                    DropdownMenuItem(value: ',', child: Text('Comma ,', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: ';', child: Text('Semicolon ;', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: '\t', child: Text('Tab', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: '|', child: Text('Pipe |', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (v) { setState(() { _delimiter = v!; _rawRows = _rawRows.map((r) => _splitLine(r.join(_delimiter), _delimiter)).toList(); _updatePreview(); }); },
                )),
                const SizedBox(width: 8),
                SizedBox(width: 80, child: TextFormField(
                  initialValue: _skipHeader.toString(),
                  decoration: InputDecoration(labelText: isEnglish ? 'Skip Head' : 'ข้ามหัว', isDense: true, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                  keyboardType: TextInputType.number,
                  onChanged: (v) { setState(() { _skipHeader = int.tryParse(v) ?? 0; _updatePreview(); }); },
                )),
                const SizedBox(width: 8),
                SizedBox(width: 80, child: TextFormField(
                  initialValue: _skipFooter.toString(),
                  decoration: InputDecoration(labelText: isEnglish ? 'Skip Tail' : 'ข้ามท้าย', isDense: true, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                  keyboardType: TextInputType.number,
                  onChanged: (v) { setState(() { _skipFooter = int.tryParse(v) ?? 0; _updatePreview(); }); },
                )),
                const SizedBox(width: 8),
                SizedBox(width: 150, child: DropdownButtonFormField<String>(
                  value: _dateFormat,
                  isDense: true,
                  decoration: InputDecoration(labelText: isEnglish ? 'Date Format' : 'รูปแบบวันที่', isDense: true, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                  items: _dateFormats.map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 11)))).toList(),
                  onChanged: (v) => setState(() => _dateFormat = v!),
                )),
                const SizedBox(width: 8),
                Row(children: [
                  Checkbox(value: _singleAmount, onChanged: (v) => setState(() => _singleAmount = v ?? false), visualDensity: VisualDensity.compact),
                  Text(isEnglish ? 'Single amount column' : 'ยอดเดียว', style: const TextStyle(fontSize: 12)),
                ]),
              ]),
              const SizedBox(height: 10),
              // Column mapping
              if (colCount > 0)
                Row(children: [
                  Expanded(child: _colDrop(isEnglish ? 'Date *' : 'วันที่ *', _dateCol, (v) => _dateCol = v, isEnglish)),
                  const SizedBox(width: 6),
                  Expanded(child: _colDrop(isEnglish ? 'Description' : 'รายการ', _descCol, (v) => _descCol = v, isEnglish)),
                  const SizedBox(width: 6),
                  if (!_singleAmount) ...[
                    Expanded(child: _colDrop(isEnglish ? 'Withdrawal' : 'ถอน', _wdCol, (v) => _wdCol = v, isEnglish)),
                    const SizedBox(width: 6),
                    Expanded(child: _colDrop(isEnglish ? 'Deposit' : 'ฝาก', _depCol, (v) => _depCol = v, isEnglish)),
                  ] else ...[
                    Expanded(child: _colDrop(isEnglish ? 'Amount (+ Deposit)' : 'ยอด (+ ฝาก)', _amtCol, (v) => _amtCol = v, isEnglish)),
                    const SizedBox(width: 6),
                  ],
                  Expanded(child: _colDrop(isEnglish ? 'Balance' : 'คงเหลือ', _balCol, (v) => _balCol = v, isEnglish)),
                  const SizedBox(width: 6),
                  Expanded(child: _colDrop(isEnglish ? 'Reference' : 'อ้างอิง', _refCol, (v) => _refCol = v, isEnglish)),
                ]),
              const SizedBox(height: 10),
              // Raw preview
              Expanded(
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowHeight: 30,
                        dataRowMinHeight: 26,
                        dataRowMaxHeight: 30,
                        columnSpacing: 10,
                        headingTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        columns: List.generate(colCount, (i) => DataColumn(
                          label: Text('${isEnglish ? 'Col' : 'คอล'} ${i + 1}', style: const TextStyle(fontSize: 11)),
                        )),
                        rows: _previewRows.map((row) => DataRow(
                          cells: List.generate(colCount, (i) => DataCell(
                            Text(i < row.length ? row[i] : '', style: const TextStyle(fontSize: 11)),
                          )),
                        )).toList(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              if (lines != null)
                Text(isEnglish ? 'Ready to import ${lines.length} items' : 'พร้อม import ${lines.length} รายการ',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, null), child: Text(l.cancel)),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white),
          onPressed: (lines != null && lines.isNotEmpty) ? () => Navigator.pop(context, lines) : null,
          child: Text(isEnglish ? 'Import ${lines?.length ?? 0} items' : 'นำเข้า ${lines?.length ?? 0} รายการ'),
        ),
      ],
    );
  }
}
