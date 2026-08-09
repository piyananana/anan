// lib/cm/screens/cm_bank_fx_revaluation_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/services/sa_module_document_service.dart';
import '../models/cm_bank_fx_revaluation.dart';
import '../services/cm_bank_fx_revaluation_service.dart';
import '../services/cm_period_service.dart';
import '../../utils/date_utils.dart';

const _kTheme = Color(0xFF1565C0);
final _fmt     = NumberFormat('#,##0.00',   'en_US');
final _fmtFc   = NumberFormat('#,##0.0000', 'en_US');
final _fmtRate = NumberFormat('#,##0.0000', 'en_US');
final _dateFmt = DateFormat('dd/MM/yyyy');

class CmBankFxRevaluationScreen extends StatefulWidget {
  const CmBankFxRevaluationScreen({super.key});
  @override
  State<CmBankFxRevaluationScreen> createState() => _CmBankFxRevaluationScreenState();
}

class _CmBankFxRevaluationScreenState extends State<CmBankFxRevaluationScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _svc     = CmBankFxRevaluationService();
  final _acctSvc = AccountService();
  final _docSvc  = ModuleDocumentService();

  bool _isEnglish = false;

  // Panel state — matches ar_fx_revaluation_screen pattern
  bool   _isLeftPanelExpanded = true;
  bool   _isDraggingDivider   = false;
  double _leftPanelWidth      = 280.0;

  List<CmBankFxRevaluation> _history = [];
  CmBankFxRevaluation? _selected;
  bool _loadingHistory = false;

  // GL meta
  List<ModuleDocument> _glDocTypes = [];
  List<Account> _glAccounts = [];
  bool _metaLoaded = false;

  // Panel mode
  bool _isCreating = false;
  bool _isEditing  = false;

  // Form state
  DateTime? _formDate;
  final _formDescCtrl = TextEditingController();
  int? _formGlDocId;
  int? _formGainAcctId;
  String _formGainAcctDisplay = '';
  int? _formLossAcctId;
  String _formLossAcctDisplay = '';

  // Outstanding currencies (auto-fetched by revaluation date) + rate entry
  List<Map<String, dynamic>> _outstandingCurrencies = [];
  bool _isFetchingCurrencies = false;
  final Map<String, TextEditingController> _rateCtrl = {};

  // Preview lines
  List<CmFxPreviewLine> _previewLines = [];
  bool _previewed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadMeta();
  }

  @override
  void dispose() {
    _formDescCtrl.dispose();
    for (final c in _rateCtrl.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final list = await _svc.fetchRows();
      if (!mounted) return;
      setState(() { _history = list; _loadingHistory = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingHistory = false);
      _showError(e.toString());
    }
  }

  Future<void> _loadMeta() async {
    if (_metaLoaded) return;
    try {
      final results = await Future.wait([_docSvc.fetchRows(), _acctSvc.fetchRows()]);
      if (!mounted) return;
      final docs  = results[0] as List<ModuleDocument>;
      final accts = results[1] as List<Account>;
      setState(() {
        _glDocTypes = docs.where((d) => d.isDocType && d.sysModule == '01' && d.isActive).toList();
        _glAccounts = accts.where((a) => a.isNormalAccount && a.isActive).toList();
        _metaLoaded = true;
      });
    } catch (_) {}
  }

  Future<void> _loadOutstandingCurrencies({Map<String, String>? seedRates}) async {
    if (_formDate == null) return;
    setState(() { _isFetchingCurrencies = true; _outstandingCurrencies = []; _previewLines = []; _previewed = false; });
    try {
      final list = await _svc.fetchOutstandingCurrencies(formatLocalDate(_formDate!));
      // dispose controllers for currencies no longer in list
      final newCodes = list.map((c) => c['currency_code'] as String).toSet();
      _rateCtrl.removeWhere((code, ctrl) {
        if (!newCodes.contains(code)) { ctrl.dispose(); return true; }
        return false;
      });
      for (final c in list) {
        final code = c['currency_code'] as String;
        _rateCtrl[code] ??= TextEditingController(text: seedRates?[code] ?? '');
      }
      if (!mounted) return;
      setState(() { _outstandingCurrencies = list; _isFetchingCurrencies = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isFetchingCurrencies = false);
      _showError(e.toString());
    }
  }

  // ── Form helpers ───────────────────────────────────────────────────────────
  void _startCreate() {
    _loadMeta();
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0); // last day of current month
    for (final c in _rateCtrl.values) { c.dispose(); }
    _rateCtrl.clear();
    setState(() {
      _isCreating  = true;
      _isEditing   = false;
      _selected    = null;
      _formDate    = lastDay;
      _formDescCtrl.text = 'FX Revaluation ${DateFormat('yyyy-MM').format(lastDay)}';
      _formGlDocId = _glDocTypes.isNotEmpty ? _glDocTypes.first.id : null;
      _formGainAcctId    = null;
      _formGainAcctDisplay = '';
      _formLossAcctId    = null;
      _formLossAcctDisplay = '';
      _outstandingCurrencies = [];
      _previewLines.clear();
      _previewed   = false;
    });
    _loadOutstandingCurrencies();
  }

  void _startEdit(CmBankFxRevaluation r) {
    _loadMeta();
    final seedRates = <String, String>{
      for (final l in r.lines) l.currencyCode: l.newRate.toString(),
    };
    for (final c in _rateCtrl.values) { c.dispose(); }
    _rateCtrl.clear();

    setState(() {
      _isEditing   = true;
      _isCreating  = false;
      _selected    = r;
      _formDate    = r.revaluationDate;
      _formDescCtrl.text = r.description ?? '';
      _formGlDocId = r.glDocId;
      _formGainAcctId    = r.fxGainAccountId;
      _formGainAcctDisplay = r.fxGainAccountId != null
          ? '${r.fxGainAccountCode ?? ''} ${r.fxGainAccountName ?? ''}'.trim()
          : '';
      _formLossAcctId    = r.fxLossAccountId;
      _formLossAcctDisplay = r.fxLossAccountId != null
          ? '${r.fxLossAccountCode ?? ''} ${r.fxLossAccountName ?? ''}'.trim()
          : '';
      _previewLines = r.lines.map((l) => CmFxPreviewLine(
        bankAccountId: l.bankAccountId, bankAccountCode: l.bankAccountCode,
        bankAccountName: l.bankAccountName, bankShortName: l.bankShortName,
        glAccountId: l.glAccountId, glAccountCode: l.glAccountCode,
        currencyCode: l.currencyCode, balanceFc: l.balanceFc,
        balanceLcBook: l.balanceLcBook, newRate: l.newRate,
        balanceLcNew: l.balanceLcNew, fxGainLoss: l.fxGainLoss,
      )).toList();
      _previewed = true;
    });
    _loadOutstandingCurrencies(seedRates: seedRates);
  }

  void _cancelForm() {
    setState(() { _isCreating = false; _isEditing = false; _previewLines.clear(); _previewed = false; });
  }

  Map<String, double> get _ratesMap {
    final m = <String, double>{};
    for (final c in _outstandingCurrencies) {
      final code = c['currency_code'] as String;
      final rate = double.tryParse(_rateCtrl[code]?.text.replaceAll(',', '') ?? '') ?? 0;
      if (rate > 0) m[code] = rate;
    }
    return m;
  }

  Future<void> _preview() async {
    final isEnglish = _isEnglish;
    if (_formDate == null) { _showError(isEnglish ? 'Please specify a date' : 'กรุณาระบุวันที่'); return; }
    final rates = _ratesMap;
    if (rates.isEmpty) { _showError(isEnglish ? 'Please specify an exchange rate for at least 1 currency' : 'กรุณาระบุ Exchange Rate อย่างน้อย 1 สกุลเงิน'); return; }
    setState(() { _saving = true; _previewed = false; });
    try {
      final lines = await _svc.previewLines(
        revaluationDate: formatLocalDate(_formDate!),
        rates: rates,
      );
      if (!mounted) return;
      setState(() { _previewLines = lines; _previewed = true; _saving = false; });
      if (lines.isEmpty) _showError(isEnglish ? 'No FC bank accounts found with a balance for the specified currencies' : 'ไม่พบบัญชีธนาคาร FC ที่มียอดคงเหลือสำหรับ Currency ที่ระบุ');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(e.toString());
    }
  }

  Future<void> _save({bool post = false}) async {
    final perm = MenuScope.of(context);
    if (!(post ? (perm?.canEdit ?? true) : (perm?.canCreate ?? true))) return;
    final isEnglish = _isEnglish;
    if (_formDate == null) { _showError(isEnglish ? 'Please specify a date' : 'กรุณาระบุวันที่'); return; }
    if (post && (_formGainAcctId == null || _formLossAcctId == null)) {
      _showError(isEnglish ? 'Please specify FX Gain and FX Loss accounts before posting to GL' : 'กรุณาระบุบัญชี FX Gain และ FX Loss ก่อน Post GL');
      return;
    }
    if (!_previewed || _previewLines.isEmpty) {
      _showError(isEnglish ? 'Please calculate before saving' : 'กรุณาคำนวณก่อนบันทึก');
      return;
    }
    setState(() => _saving = true);
    try {
      final body = {
        'revaluation_date':   formatLocalDate(_formDate!),
        'description':        _formDescCtrl.text.isEmpty ? null : _formDescCtrl.text,
        'gl_doc_id':          _formGlDocId,
        'fx_gain_account_id': _formGainAcctId,
        'fx_loss_account_id': _formLossAcctId,
        'rates':              _ratesMap,
      };

      CmBankFxRevaluation result;
      if (_isEditing && _selected != null) {
        result = await _svc.updateRow(_selected!.id, body);
      } else {
        result = await _svc.createRow(body);
      }

      if (post) {
        final posted = await _svc.postRow(result.id);
        final updatedResult = await _svc.fetchRow(posted['id'] ?? result.id);
        if (mounted) {
          setState(() { _saving = false; _isCreating = false; _isEditing = false; _selected = updatedResult; });
          await _loadHistory();
          _showSuccess(isEnglish ? 'Posted to GL successfully (${updatedResult.glDocNo ?? ''})' : 'Post GL สำเร็จ (${updatedResult.glDocNo ?? ''})');
        }
      } else {
        final full = await _svc.fetchRow(result.id);
        if (mounted) {
          setState(() { _saving = false; _isCreating = false; _isEditing = false; _selected = full; });
          await _loadHistory();
          _showSuccess(isEnglish ? 'Draft saved successfully' : 'บันทึก Draft สำเร็จ');
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(e.toString());
    }
  }

  Future<void> _postExisting() async {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    final l = AppL10n(isEnglish);
    if (_selected == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEnglish ? 'Confirm Post GL' : 'ยืนยัน Post GL'),
        content: Text(isEnglish ? 'Post the GL Entry for this FX Revaluation?' : 'ต้องการบันทึก GL Entry สำหรับ FX Revaluation นี้ใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Post GL'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!await CmPeriodService.canPost(context, _selected!.revaluationDate)) return;
    setState(() => _saving = true);
    try {
      final result = await _svc.postRow(_selected!.id);
      final updated = await _svc.fetchRow(result['id'] ?? _selected!.id);
      if (!mounted) return;
      setState(() { _selected = updated; _saving = false; });
      await _loadHistory();
      _showSuccess(isEnglish ? 'Posted to GL successfully (${updated.glDocNo ?? ''})' : 'Post GL สำเร็จ (${updated.glDocNo ?? ''})');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(e.toString());
    }
  }

  Future<void> _voidSelected() async {
    if (!(MenuScope.of(context)?.canDelete ?? true)) return;
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    final l = AppL10n(isEnglish);
    if (_selected == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEnglish ? 'Confirm Void' : 'ยืนยันการยกเลิก'),
        content: Text(isEnglish
            ? 'Void this FX Revaluation?\nA reversing GL Entry will be created automatically.'
            : 'ต้องการยกเลิก FX Revaluation นี้ใช่หรือไม่?\nระบบจะสร้าง GL Entry ย้อนกลับโดยอัตโนมัติ'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(isEnglish ? 'Confirm Void' : 'ยืนยันยกเลิก'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      final updated = await _svc.voidRow(_selected!.id);
      if (!mounted) return;
      setState(() { _selected = updated; _saving = false; });
      await _loadHistory();
      _showSuccess(isEnglish ? 'FX Revaluation voided successfully' : 'ยกเลิก FX Revaluation สำเร็จ');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(e.toString());
    }
  }

  Future<void> _deleteSelected(CmBankFxRevaluation r) async {
    if (!(MenuScope.of(context)?.canDelete ?? true)) return;
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    final l = AppL10n(isEnglish);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEnglish ? 'Confirm Delete' : 'ยืนยันการลบ'),
        content: Text(isEnglish ? 'Delete this item?' : 'ต้องการลบรายการนี้ใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.deleteRow(r.id);
      if (_selected?.id == r.id) setState(() => _selected = null);
      await _loadHistory();
      _showSuccess(isEnglish ? 'Deleted successfully' : 'ลบสำเร็จ');
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

  Color _statusColor(String s) =>
      s == 'Posted' ? Colors.green.shade700 : s == 'Voided' ? Colors.red.shade700 : Colors.orange.shade700;

  // ── Account picker ─────────────────────────────────────────────────────────
  Future<Account?> _pickAccount() async {
    if (!_metaLoaded) await _loadMeta();
    if (!mounted) return null;
    return showDialog<Account>(
      context: context,
      builder: (_) => _AccountPickerDialog(accounts: _glAccounts),
    );
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
          final maxLeft = (constraints.maxWidth - 36 - 5 - 400).clamp(100.0, double.infinity);
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
                  icon: Icon(_isLeftPanelExpanded ? Icons.filter_list_off : Icons.filter_list),
                  onPressed: () => setState(() => _isLeftPanelExpanded = !_isLeftPanelExpanded),
                  tooltip: _isLeftPanelExpanded
                      ? (isEnglish ? 'Collapse list' : 'ย่อรายการ')
                      : (isEnglish ? 'Expand list' : 'ขยายรายการ'),
                ),
              ),
              // Left panel — history list
              AnimatedContainer(
                duration: _isDraggingDivider ? Duration.zero : const Duration(milliseconds: 200),
                width: _isLeftPanelExpanded ? _leftPanelWidth : 0,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    maxWidth: _leftPanelWidth,
                    minWidth: _leftPanelWidth,
                    child: _buildLeftPanel(),
                  ),
                ),
              ),
              if (_isLeftPanelExpanded)
                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    onHorizontalDragStart: (_) => setState(() => _isDraggingDivider = true),
                    onHorizontalDragUpdate: (d) => setState(() {
                      _leftPanelWidth = (_leftPanelWidth + d.delta.dx).clamp(220.0, maxLeft);
                    }),
                    onHorizontalDragEnd: (_) => setState(() => _isDraggingDivider = false),
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

  Widget _buildLeftPanel() {
    final isEnglish = _isEnglish;
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        color: Colors.blue.shade50,
        width: double.infinity,
        child: FilledButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: Text(isEnglish ? 'Create New' : 'สร้างใหม่'),
          style: FilledButton.styleFrom(backgroundColor: _kTheme),
          onPressed: _startCreate,
        ),
      ),
      Expanded(
        child: _loadingHistory
            ? const Center(child: CircularProgressIndicator())
            : _history.isEmpty
                ? Center(child: Text(isEnglish ? 'No entries' : 'ไม่มีรายการ', style: const TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _history.length,
                    itemBuilder: (_, i) {
                      final r = _history[i];
                      final selected = r.id == _selected?.id;
                      final gainLoss = r.totalGainLoss;
                      final gainLossColor = gainLoss >= 0 ? Colors.green.shade700 : Colors.red.shade700;
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        color: selected ? _kTheme.withOpacity(0.08) : null,
                        shape: selected
                            ? RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: _kTheme, width: 1.5))
                            : null,
                        child: ListTile(
                          dense: true,
                          onTap: () {
                            setState(() { _selected = r; _isCreating = false; _isEditing = false; });
                            if (r.lines.isEmpty) {
                              _svc.fetchRow(r.id).then((full) {
                                if (mounted) setState(() => _selected = full);
                              }).catchError((Object e) { _showError(e.toString()); return null; });
                            }
                          },
                          title: Text(_dateFmt.format(r.revaluationDate),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13,
                                  color: selected ? _kTheme : null)),
                          subtitle: Container(
                            margin: const EdgeInsets.only(top: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: _statusColor(r.status).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(cmFxRevalStatusLabel(r.status, isEnglish),
                                style: TextStyle(fontSize: 11, color: _statusColor(r.status))),
                          ),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(
                              gainLoss != 0 ? '${gainLoss > 0 ? '+' : ''}${_fmt.format(gainLoss)}' : '—',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: gainLossColor),
                            ),
                            if (r.isDraft) ...[
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => _deleteSelected(r),
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade400),
                                ),
                              ),
                            ],
                          ]),
                        ),
                      );
                    },
                  ),
      ),
    ]);
  }

  Widget _buildRightPanel() {
    if (_isCreating || _isEditing) return _buildFormPanel();
    if (_selected != null) return _buildDetailPanel(_selected!);
    return Center(child: Text(_isEnglish ? 'Select an entry on the left, or click "Create New"' : 'เลือกรายการทางซ้าย หรือกด "สร้างใหม่"', style: const TextStyle(color: Colors.grey)));
  }

  // ── Form panel ─────────────────────────────────────────────────────────────
  Widget _buildFormPanel() {
    final isEnglish = _isEnglish;
    final isEdit = _isEditing;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Card 1: General Info ──────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(isEdit ? (isEnglish ? 'Edit FX Revaluation' : 'แก้ไข FX Revaluation') : (isEnglish ? 'Create FX Revaluation' : 'สร้าง FX Revaluation'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _kTheme)),
                ),
                TextButton(onPressed: _cancelForm, child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
              ]),
              const Divider(height: 20),
              Wrap(spacing: 32, runSpacing: 12, children: [
                _labelField(isEnglish ? 'Date *' : 'วันที่ *', InkWell(
                  onTap: () async {
                    final p = await showDatePicker(
                      context: context,
                      initialDate: _formDate ?? DateTime.now(),
                      firstDate: DateTime(2000), lastDate: DateTime(2100),
                    );
                    if (p != null) {
                      setState(() => _formDate = p);
                      _loadOutstandingCurrencies();
                    }
                  },
                  child: Container(
                    width: 150,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(_formDate != null ? _dateFmt.format(_formDate!) : '—',
                        style: const TextStyle(fontSize: 14)),
                  ),
                )),
                _labelField(isEnglish ? 'GL Doc Type' : 'ประเภทเอกสาร GL', SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<int?>(
                    value: _formGlDocId,
                    isDense: true,
                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                    items: [
                      DropdownMenuItem<int?>(value: null, child: Text(isEnglish ? '— Not specified —' : '— ไม่ระบุ —', style: const TextStyle(fontSize: 13))),
                      ..._glDocTypes.map((d) => DropdownMenuItem<int?>(
                        value: d.id,
                        child: Text('${d.docCode} ${d.docNameThai}', style: const TextStyle(fontSize: 13)),
                      )),
                    ],
                    onChanged: (v) => setState(() => _formGlDocId = v),
                  ),
                )),
              ]),
              const SizedBox(height: 12),
              _labelField(isEnglish ? 'Description' : 'คำอธิบาย', SizedBox(
                width: 400,
                child: TextField(
                  controller: _formDescCtrl,
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                  style: const TextStyle(fontSize: 14),
                ),
              )),
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 12, children: [
                SizedBox(width: 280, child: _accountPickerField(
                  label: isEnglish ? 'FX Gain Account *' : 'บัญชี FX Gain *',
                  display: _formGainAcctDisplay,
                  isEnglish: isEnglish,
                  onPick: () async {
                    final a = await _pickAccount();
                    if (a != null) setState(() {
                      _formGainAcctId = a.id;
                      _formGainAcctDisplay = '${a.accountCode} ${a.accountNameThai}';
                    });
                  },
                )),
                SizedBox(width: 280, child: _accountPickerField(
                  label: isEnglish ? 'FX Loss Account *' : 'บัญชี FX Loss *',
                  display: _formLossAcctDisplay,
                  isEnglish: isEnglish,
                  onPick: () async {
                    final a = await _pickAccount();
                    if (a != null) setState(() {
                      _formLossAcctId = a.id;
                      _formLossAcctDisplay = '${a.accountCode} ${a.accountNameThai}';
                    });
                  },
                )),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 12),

        // ── Card 2: Exchange Rates ────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(isEnglish ? 'Exchange rate as of  ' : 'อัตราแลกเปลี่ยน ณ วันที่  ',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(_formDate != null ? _dateFmt.format(_formDate!) : '—',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _kTheme)),
                if (_isFetchingCurrencies) ...[
                  const SizedBox(width: 12),
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _kTheme)),
                ],
              ]),
              const SizedBox(height: 4),
              Text(isEnglish ? 'Shows only currencies with an outstanding FC bank balance as of this date' : 'แสดงเฉพาะสกุลเงินที่มียอดคงเหลือบัญชีธนาคาร FC ณ วันที่ดังกล่าว',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const Divider(height: 20),
              if (_isFetchingCurrencies)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator(color: _kTheme)),
                )
              else if (_outstandingCurrencies.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(isEnglish ? 'No outstanding foreign currency bank balances found as of this date' : 'ไม่พบยอดคงเหลือบัญชีธนาคารสกุลเงินต่างประเทศ ณ วันที่นี้',
                        style: TextStyle(fontSize: 14, color: Colors.orange.shade700))),
                  ]),
                )
              else
                Wrap(
                  spacing: 20,
                  runSpacing: 16,
                  children: _outstandingCurrencies.map(_currencyRateField).toList(),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // ── Action buttons ──────────────────────────────────────────────
        Row(children: [
          OutlinedButton.icon(
            icon: _saving
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.calculate, size: 16),
            label: Text(isEnglish ? 'Calculate Preview' : 'คำนวณ Preview'),
            onPressed: (_saving || _isFetchingCurrencies || _outstandingCurrencies.isEmpty) ? null : _preview,
          ),
          const SizedBox(width: 12),
          if (_previewed && _previewLines.isNotEmpty) ...[
            OutlinedButton(
              onPressed: _saving ? null : () => _save(post: false),
              child: Text(isEnglish ? 'Save Draft' : 'บันทึก Draft'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white),
              onPressed: _saving ? null : () => _save(post: true),
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Post GL'),
            ),
          ],
        ]),

        // Preview table
        if (_previewed) ...[
          const SizedBox(height: 16),
          if (_previewLines.isEmpty)
            Text(isEnglish ? 'No accounts need adjustment' : 'ไม่พบบัญชีที่ต้องปรับปรุง', style: const TextStyle(color: Colors.grey))
          else
            SizedBox(height: 360, child: _buildPreviewTable(_previewLines, isEnglish)),
        ],
      ]),
    );
  }

  Widget _currencyRateField(Map<String, dynamic> c) {
    final isEnglish = _isEnglish;
    final code = c['currency_code']?.toString() ?? '';
    final name = (isEnglish && (c['currency_name_en']?.toString() ?? '').isNotEmpty)
        ? c['currency_name_en'] : (c['currency_name_th'] ?? '');
    return SizedBox(
      width: 220,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        RichText(text: TextSpan(children: [
          TextSpan(text: code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
          TextSpan(text: '  $name', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ])),
        const SizedBox(height: 4),
        TextFormField(
          controller: _rateCtrl[code],
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            suffixText: 'THB',
            hintText: '0.0000',
          ),
          style: const TextStyle(fontSize: 14),
          textAlign: TextAlign.right,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ]),
    );
  }

  Widget _labelField(String label, Widget child) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(label, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 8),
      child,
    ],
  );

  Widget _accountPickerField({required String label, required String display, required VoidCallback onPick, required bool isEnglish}) {
    return InkWell(
      onTap: onPick,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          suffixIcon: const Icon(Icons.search, size: 18),
        ),
        child: Text(
          display.isEmpty ? (isEnglish ? '— Select an account —' : '— เลือกบัญชี —') : display,
          style: TextStyle(fontSize: 13, color: display.isEmpty ? Colors.grey : Colors.black87),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildPreviewTable(List<CmFxPreviewLine> lines, bool isEnglish) {
    final totalGainLoss = lines.fold(0.0, (s, l) => s + l.fxGainLoss);
    final table = DataTable(
      headingRowColor: WidgetStateProperty.all(_kTheme.withOpacity(0.06)),
      columnSpacing: 14,
      dataRowMinHeight: 30,
      dataRowMaxHeight: 36,
      headingTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
      columns: [
        DataColumn(label: Text(isEnglish ? 'Bank Account' : 'บัญชีธนาคาร')),
        const DataColumn(label: Text('Currency')),
        const DataColumn(label: Text('FC Balance'),    numeric: true),
        DataColumn(label: Text(isEnglish ? 'LC per Book' : 'LC ตามบัญชี'), numeric: true),
        DataColumn(label: Text(isEnglish ? 'New Rate' : 'Rate ใหม่'),     numeric: true),
        DataColumn(label: Text(isEnglish ? 'New LC' : 'LC ใหม่'),       numeric: true),
        const DataColumn(label: Text('FX +/-'),         numeric: true),
      ],
      rows: [
        ...lines.map((l) {
          final isGain = l.fxGainLoss >= 0;
          return DataRow(cells: [
            DataCell(Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.bankAccountCode ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                if (l.bankShortName != null)
                  Text(l.bankShortName!, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            )),
            DataCell(Text(l.currencyCode, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
            DataCell(Text(_fmtFc.format(l.balanceFc), style: const TextStyle(fontSize: 11))),
            DataCell(Text(_fmt.format(l.balanceLcBook), style: const TextStyle(fontSize: 11))),
            DataCell(Text(_fmtRate.format(l.newRate), style: const TextStyle(fontSize: 11))),
            DataCell(Text(_fmt.format(l.balanceLcNew), style: const TextStyle(fontSize: 11))),
            DataCell(Text(
              '${isGain && l.fxGainLoss != 0 ? '+' : ''}${_fmt.format(l.fxGainLoss)}',
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold,
                color: l.fxGainLoss == 0 ? Colors.grey : (isGain ? Colors.green.shade700 : Colors.red.shade700),
              ),
            )),
          ]);
        }),
        DataRow(
          color: WidgetStateProperty.all(_kTheme.withOpacity(0.06)),
          cells: [
            DataCell(Text(isEnglish ? 'Total' : 'รวม', style: const TextStyle(fontWeight: FontWeight.bold))),
            const DataCell(SizedBox()), const DataCell(SizedBox()), const DataCell(SizedBox()), const DataCell(SizedBox()),
            DataCell(Text(
              '${totalGainLoss >= 0 ? '+' : ''}${_fmt.format(totalGainLoss)}',
              style: TextStyle(fontWeight: FontWeight.bold, color: totalGainLoss >= 0 ? Colors.green.shade700 : Colors.red.shade700),
            )),
          ],
        ),
      ],
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(children: [
            Text(isEnglish ? 'Calculation Result' : 'ผลการคำนวณ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(width: 12),
            Text(isEnglish ? '${lines.length} items' : '${lines.length} รายการ', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: table,
            ),
          ),
        ),
      ]),
    );
  }

  // ── Detail panel ───────────────────────────────────────────────────────────
  Widget _buildDetailPanel(CmBankFxRevaluation r) {
    final isEnglish = _isEnglish;
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.grey.shade50,
        child: Row(children: [
          _infoChip(isEnglish ? 'Date' : 'วันที่', _dateFmt.format(r.revaluationDate)),
          const SizedBox(width: 24),
          if (r.fxGainAccountCode != null) ...[
            _infoChip('FX Gain', '${r.fxGainAccountCode} ${r.fxGainAccountName ?? ''}'),
            const SizedBox(width: 24),
          ],
          if (r.fxLossAccountCode != null) ...[
            _infoChip('FX Loss', '${r.fxLossAccountCode} ${r.fxLossAccountName ?? ''}'),
            const SizedBox(width: 24),
          ],
          _infoChip(isEnglish ? 'Total Gain/Loss' : 'รวม Gain/Loss', _fmt.format(r.totalGainLoss),
              valueColor: r.totalGainLoss >= 0 ? Colors.green.shade700 : Colors.red.shade700),
          const SizedBox(width: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _statusColor(r.status).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
            child: Text(cmFxRevalStatusLabel(r.status, isEnglish),
                style: TextStyle(color: _statusColor(r.status), fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          const Spacer(),
          _buildDetailActions(r),
        ]),
      ),
      if (r.glDocNo != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: _kTheme.withOpacity(0.06),
          child: Text('GL Entry: ${r.glDocNo}', style: const TextStyle(fontSize: 13, color: _kTheme)),
        ),
      const Divider(height: 1),
      Expanded(
        child: r.lines.isEmpty
            ? Center(child: Text(isEnglish ? 'No items' : 'ไม่มีรายการ', style: const TextStyle(color: Colors.grey)))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _buildSavedLinesTable(r.lines, isEnglish),
                ),
              ),
      ),
    ]);
  }

  Widget _infoChip(String label, String value, {Color? valueColor}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: valueColor)),
      ]);

  Widget _buildDetailActions(CmBankFxRevaluation r) {
    final isEnglish = _isEnglish;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (r.isDraft) ...[
          OutlinedButton(
            onPressed: () => _startEdit(r),
            child: Text(isEnglish ? 'Edit' : 'แก้ไข'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white),
            onPressed: _saving ? null : _postExisting,
            child: const Text('Post GL'),
          ),
        ],
        if (r.isPosted)
          OutlinedButton(
            onPressed: _saving ? null : _voidSelected,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
            child: Text(isEnglish ? 'Void' : 'ยกเลิก'),
          ),
      ],
    );
  }

  Widget _buildSavedLinesTable(List<CmBankFxRevaluationLine> lines, bool isEnglish) {
    final total = lines.fold(0.0, (s, l) => s + l.fxGainLoss);
    return DataTable(
      headingRowColor: WidgetStateProperty.all(_kTheme.withOpacity(0.06)),
      columnSpacing: 16,
      columns: [
        DataColumn(label: Text(isEnglish ? 'Bank Account' : 'บัญชีธนาคาร')),
        const DataColumn(label: Text('Currency')),
        const DataColumn(label: Text('GL Account')),
        const DataColumn(label: Text('FC Balance'),    numeric: true),
        DataColumn(label: Text(isEnglish ? 'LC per Book' : 'LC ตามบัญชี'), numeric: true),
        DataColumn(label: Text(isEnglish ? 'New Rate' : 'Rate ใหม่'),     numeric: true),
        DataColumn(label: Text(isEnglish ? 'New LC' : 'LC ใหม่'),       numeric: true),
        const DataColumn(label: Text('FX +/-'),         numeric: true),
      ],
      rows: [
        ...lines.map((l) {
          final isGain = l.fxGainLoss >= 0;
          return DataRow(cells: [
            DataCell(Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.bankAccountCode ?? '', style: const TextStyle(fontSize: 12)),
                if (l.bankShortName != null)
                  Text(l.bankShortName!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            )),
            DataCell(Text(l.currencyCode, style: const TextStyle(fontSize: 12))),
            DataCell(Text(l.glAccountCode ?? '', style: const TextStyle(fontSize: 12))),
            DataCell(Text(_fmtFc.format(l.balanceFc), style: const TextStyle(fontSize: 12))),
            DataCell(Text(_fmt.format(l.balanceLcBook), style: const TextStyle(fontSize: 12))),
            DataCell(Text(_fmtRate.format(l.newRate), style: const TextStyle(fontSize: 12))),
            DataCell(Text(_fmt.format(l.balanceLcNew), style: const TextStyle(fontSize: 12))),
            DataCell(Text(
              '${isGain && l.fxGainLoss != 0 ? '+' : ''}${_fmt.format(l.fxGainLoss)}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                  color: l.fxGainLoss == 0 ? Colors.grey : (isGain ? Colors.green.shade700 : Colors.red.shade700)),
            )),
          ]);
        }),
        DataRow(
          color: WidgetStateProperty.all(_kTheme.withOpacity(0.06)),
          cells: [
            DataCell(Text(isEnglish ? 'Total' : 'รวม', style: const TextStyle(fontWeight: FontWeight.bold))),
            const DataCell(SizedBox()), const DataCell(SizedBox()), const DataCell(SizedBox()), const DataCell(SizedBox()), const DataCell(SizedBox()),
            DataCell(Text(
              '${total >= 0 ? '+' : ''}${_fmt.format(total)}',
              style: TextStyle(fontWeight: FontWeight.bold, color: total >= 0 ? Colors.green.shade700 : Colors.red.shade700),
            )),
          ],
        ),
      ],
    );
  }
}

// ── GL Account picker dialog ─────────────────────────────────────────────────
class _AccountPickerDialog extends StatefulWidget {
  final List<Account> accounts;
  const _AccountPickerDialog({required this.accounts});
  @override
  State<_AccountPickerDialog> createState() => _AccountPickerDialogState();
}

class _AccountPickerDialogState extends State<_AccountPickerDialog> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final l = AppL10n(Provider.of<LanguageProvider>(context, listen: false).isEnglish);
    final filtered = _q.isEmpty
        ? widget.accounts
        : widget.accounts.where((a) =>
            a.accountCode.toLowerCase().contains(_q.toLowerCase()) ||
            a.accountNameThai.toLowerCase().contains(_q.toLowerCase()) ||
            a.accountNameEng.toLowerCase().contains(_q.toLowerCase())).toList();
    return AlertDialog(
      title: Text(l.isEnglish ? 'Select Chart of Accounts' : 'เลือกผังบัญชี'),
      content: SizedBox(
        width: 480,
        height: 400,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(hintText: '${l.search}...', prefixIcon: const Icon(Icons.search), isDense: true, border: const OutlineInputBorder()),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final a = filtered[i];
                  final name = l.isEnglish && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai;
                  return ListTile(
                    dense: true,
                    title: Text('${a.accountCode}  $name', style: const TextStyle(fontSize: 12)),
                    onTap: () => Navigator.pop(context, a),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
      ],
    );
  }
}
