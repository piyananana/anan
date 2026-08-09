// lib/cm/screens/cm_bank_opening_balance_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../cm/models/cm_bank_account.dart';
import '../../utils/date_utils.dart';

const _kTheme = Color(0xFF1565C0);
final _fmt     = NumberFormat('#,##0.00', 'en_US');
final _dateFmt = DateFormat('dd/MM/yyyy');

class CmBankOpeningBalanceScreen extends StatefulWidget {
  const CmBankOpeningBalanceScreen({super.key});
  @override
  State<CmBankOpeningBalanceScreen> createState() => _State();
}

class _State extends State<CmBankOpeningBalanceScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isEnglish = false;
  bool _leftExpanded = true;
  double _leftWidth  = 240.0;
  bool _isDragging   = false;

  List<CmBankAccount> _accounts    = [];
  CmBankAccount?      _selAccount;
  bool _loadingAccounts = false;

  // Current opening balance record for selected account
  Map<String, dynamic>? _currentOB;
  bool _saving = false;

  // Form state
  DateTime  _asOfDate = DateTime(DateTime.now().year - 1, 12, 31);
  final _balCtrl   = TextEditingController(text: '0.00');
  final _notesCtrl = TextEditingController();

  // All OB records (for reference table on right)
  List<Map<String, dynamic>> _allOBs = [];
  bool _loadingAll = false;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _loadAll();
  }

  @override
  void dispose() {
    _balCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    setState(() => _loadingAccounts = true);
    try {
      final headers = await AuthService().getAuthHeader();
      final resp = await http.get(Uri.parse('${AppConfig.apiCm}/cm_bank_account/active'), headers: headers);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final all = (json.decode(resp.body) as List)
            .map((j) => CmBankAccount.fromJson(j as Map<String, dynamic>))
            .where((a) => a.cmType == 'BANK')
            .toList();
        setState(() { _accounts = all; _loadingAccounts = false; });
        if (all.isNotEmpty) {
          _selAccount = all.first;
          _fillFormFromOBs(all.first.id!);
        }
      } else {
        throw Exception(json.decode(resp.body)['error'] ?? resp.body);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingAccounts = false);
      _showError(e.toString());
    }
  }

  Future<void> _loadAll() async {
    setState(() => _loadingAll = true);
    try {
      final headers = await AuthService().getAuthHeader();
      final resp = await http.get(Uri.parse('${AppConfig.apiCm}/cm_bank_opening_balance'), headers: headers);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        setState(() {
          _allOBs = List<Map<String, dynamic>>.from(json.decode(resp.body) as List);
          _loadingAll = false;
        });
      } else {
        throw Exception(json.decode(resp.body)['error'] ?? resp.body);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingAll = false);
    }
  }

  void _fillFormFromOBs(int bankAccountId) {
    final match = _allOBs.where((o) => o['bank_account_id'] == bankAccountId).toList();
    if (match.isNotEmpty) {
      final ob = match.first;
      setState(() {
        _currentOB = ob;
        _asOfDate = parseLocalDate(ob['as_of_date']);
        _balCtrl.text   = _fmt.format(double.tryParse(ob['opening_balance']?.toString() ?? '0') ?? 0);
        _notesCtrl.text = ob['notes'] ?? '';
      });
    } else {
      setState(() {
        _currentOB = null;
        _balCtrl.text   = '0.00';
        _notesCtrl.text = '';
      });
    }
  }

  Future<void> _save() async {
    if (!(MenuScope.of(context)?.canEdit ?? true)) return;
    if (_selAccount == null) return;
    final isEnglish = _isEnglish;
    final balance = double.tryParse(_balCtrl.text.replaceAll(',', ''));
    if (balance == null) {
      _showError(isEnglish ? 'The balance must be a number' : 'ยอดเงินต้องเป็นตัวเลข');
      return;
    }
    setState(() => _saving = true);
    try {
      final headers = {...await AuthService().getAuthHeader(), 'Content-Type': 'application/json'};
      final resp = await http.put(
        Uri.parse('${AppConfig.apiCm}/cm_bank_opening_balance'),
        headers: headers,
        body: json.encode({
          'bank_account_id': _selAccount!.id,
          'as_of_date':      formatLocalDate(_asOfDate),
          'opening_balance': balance,
          'notes':           _notesCtrl.text.trim(),
        }),
      );
      if (!mounted) return;
      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEnglish ? 'Opening balance saved' : 'บันทึกยอดยกมาแล้ว'), backgroundColor: Colors.green.shade700));
        await _loadAll();
        _fillFormFromOBs(_selAccount!.id!);
      } else {
        throw Exception(json.decode(resp.body)['error'] ?? resp.body);
      }
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (!(MenuScope.of(context)?.canDelete ?? true)) return;
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    final l = AppL10n(isEnglish);
    if (_selAccount == null || _currentOB == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEnglish ? 'Confirm Delete Opening Balance' : 'ยืนยันลบยอดยกมา'),
        content: Text(isEnglish
            ? 'Delete the opening balance for ${_selAccount!.accountCode}?'
            : 'ลบยอดยกมาของ ${_selAccount!.accountCode} ใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final headers = await AuthService().getAuthHeader();
      final resp = await http.delete(
          Uri.parse('${AppConfig.apiCm}/cm_bank_opening_balance/${_selAccount!.id}'), headers: headers);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEnglish ? 'Deleted' : 'ลบแล้ว'), backgroundColor: Colors.green.shade700));
        await _loadAll();
        _fillFormFromOBs(_selAccount!.id!);
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
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kTheme,
        foregroundColor: Colors.white,
        title: const MenuTitle(),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        toolbarHeight: 40,
      ),
      body: LayoutBuilder(builder: (_, constraints) {
        final maxLeft = (constraints.maxWidth - 36 - 5 - 320).clamp(100.0, double.infinity);
        return Row(
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
              duration: _isDragging ? Duration.zero : const Duration(milliseconds: 200),
              width: _leftExpanded ? _leftWidth : 0,
              child: ClipRect(child: OverflowBox(
                alignment: Alignment.centerLeft, maxWidth: _leftWidth, minWidth: _leftWidth,
                child: _buildLeftPanel(),
              )),
            ),
            if (_leftExpanded)
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  onHorizontalDragStart: (_) => setState(() => _isDragging = true),
                  onHorizontalDragUpdate: (d) => setState(() {
                    _leftWidth = (_leftWidth + d.delta.dx).clamp(200.0, maxLeft);
                  }),
                  onHorizontalDragEnd: (_) => setState(() => _isDragging = false),
                  child: Container(width: 5, color: Colors.grey[400]),
                ),
              ),
            Expanded(child: _buildRightPanel()),
          ],
        );
      }),
    );
  }

  Widget _buildLeftPanel() {
    final isEnglish = _isEnglish;
    return Container(
      color: Colors.blueGrey.shade100,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(height: 36, color: Colors.blueGrey.shade200,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(isEnglish ? 'Bank Accounts' : 'บัญชีธนาคาร', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        Expanded(child: _loadingAccounts
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: _accounts.length,
                itemBuilder: (_, i) {
                  final a = _accounts[i];
                  final sel = _selAccount?.id == a.id;
                  final hasOB = _allOBs.any((o) => o['bank_account_id'] == a.id);
                  final name = isEnglish && (a.accountNameEn ?? '').isNotEmpty ? a.accountNameEn! : a.accountNameTh;
                  return InkWell(
                    onTap: () {
                      setState(() => _selAccount = a);
                      _fillFormFromOBs(a.id!);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      color: sel ? _kTheme.withOpacity(0.12) : null,
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(a.accountCode, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                              color: sel ? _kTheme : Colors.black87)),
                          Text('$name (${a.bankShortName})',
                              style: const TextStyle(fontSize: 11, color: Colors.black54)),
                        ])),
                        if (hasOB)
                          Icon(Icons.check_circle, size: 14, color: Colors.green.shade600),
                      ]),
                    ),
                  );
                },
              )),
      ]),
    );
  }

  Widget _buildRightPanel() {
    final isEnglish = _isEnglish;
    final selName = _selAccount == null
        ? ''
        : (isEnglish && (_selAccount!.accountNameEn ?? '').isNotEmpty ? _selAccount!.accountNameEn! : _selAccount!.accountNameTh);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Form panel
      if (_selAccount != null)
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade50,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('${isEnglish ? 'Opening Balance' : 'ยอดยกมา'}: ${_selAccount!.accountCode} $selName',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_currentOB != null)
                TextButton.icon(
                  icon: Icon(Icons.delete_outline, size: 14, color: Colors.red.shade400),
                  label: Text(isEnglish ? 'Delete' : 'ลบ', style: TextStyle(fontSize: 12, color: Colors.red.shade400)),
                  onPressed: _delete,
                ),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 16, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.end, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isEnglish ? 'Opening Balance as of:' : 'ยอดยกมา ณ วันที่:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () async {
                    final p = await showDatePicker(context: context, initialDate: _asOfDate,
                        firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (p != null) setState(() => _asOfDate = p);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white, border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_dateFmt.format(_asOfDate), style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 8),
                      Icon(Icons.calendar_today, size: 13, color: Colors.grey.shade500),
                    ]),
                  ),
                ),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${isEnglish ? 'Amount' : 'ยอดเงิน'} (${_selAccount!.currencyCode}):', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _balCtrl,
                    textAlign: TextAlign.right,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(), filled: true, fillColor: Colors.white,
                    ),
                  ),
                ),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isEnglish ? 'Note:' : 'หมายเหตุ:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _notesCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(), filled: true, fillColor: Colors.white,
                    ),
                  ),
                ),
              ]),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save, size: 16),
                label: Text(isEnglish ? 'Save' : 'บันทึก', style: const TextStyle(fontSize: 12)),
              ),
            ]),
          ]),
        ),
      const Divider(height: 1),
      // All OB table
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Text(isEnglish ? 'All Opening Balances' : 'รายการยอดยกมาทั้งหมด', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.refresh, size: 16), onPressed: _loadAll, tooltip: isEnglish ? 'Refresh' : 'รีเฟรช'),
        ]),
      ),
      Expanded(child: _loadingAll
          ? const Center(child: CircularProgressIndicator())
          : _allOBs.isEmpty
              ? Center(child: Text(isEnglish ? 'No opening balances yet' : 'ยังไม่มียอดยกมา',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13)))
              : SingleChildScrollView(
                  child: DataTable(
                    headingRowHeight: 34, dataRowMinHeight: 32, dataRowMaxHeight: 38,
                    columnSpacing: 20,
                    headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
                    headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    columns: [
                      DataColumn(label: Text(isEnglish ? 'Account Code' : 'รหัสบัญชี')),
                      DataColumn(label: Text(isEnglish ? 'Account Name' : 'ชื่อบัญชี')),
                      DataColumn(label: Text(isEnglish ? 'Bank' : 'ธนาคาร')),
                      DataColumn(label: Text(isEnglish ? 'Opening Balance as of' : 'ยอดยกมา ณ วันที่')),
                      DataColumn(label: Text(isEnglish ? 'Amount' : 'ยอดเงิน'), numeric: true),
                      DataColumn(label: Text(isEnglish ? 'Note' : 'หมายเหตุ')),
                    ],
                    rows: _allOBs.map((o) {
                      final bal = double.tryParse(o['opening_balance']?.toString() ?? '0') ?? 0;
                      final dt = parseLocalDateNullable(o['as_of_date']);
                      return DataRow(cells: [
                        DataCell(Text(o['bank_account_code'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        DataCell(Text(o['bank_account_name'] ?? '', style: const TextStyle(fontSize: 12))),
                        DataCell(Text(o['bank_short_name'] ?? '', style: const TextStyle(fontSize: 12))),
                        DataCell(Text(dt != null ? _dateFmt.format(dt) : '', style: const TextStyle(fontSize: 12))),
                        DataCell(Text(_fmt.format(bal), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                            color: bal >= 0 ? Colors.black87 : Colors.red.shade700))),
                        DataCell(Text(o['notes'] ?? '', style: const TextStyle(fontSize: 12))),
                      ]);
                    }).toList(),
                  ),
                )),
    ]);
  }
}
