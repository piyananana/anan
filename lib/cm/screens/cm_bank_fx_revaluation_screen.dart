// lib/cm/screens/cm_bank_fx_revaluation_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../gl/models/account.dart';
import '../../gl/services/account_service.dart';
import '../../sa/models/module_document.dart';
import '../../sa/services/module_document_service.dart';
import '../models/cm_bank_fx_revaluation.dart';
import '../services/cm_bank_fx_revaluation_service.dart';
import '../services/cm_period_service.dart';

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

  final _svc    = CmBankFxRevaluationService();
  final _acctSvc = AccountService();
  final _docSvc  = ModuleDocumentService();

  bool _leftExpanded = true;
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
  // Currency rates: list of (code, rateCtrl)
  final List<_RateEntry> _rateEntries = [];
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
    for (final e in _rateEntries) { e.codeCtrl.dispose(); e.rateCtrl.dispose(); }
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

  // ── Form helpers ───────────────────────────────────────────────────────────
  void _startCreate() {
    _loadMeta();
    final now = DateTime.now();
    // Default to last day of current month
    final lastDay = DateTime(now.year, now.month + 1, 0);
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
      _rateEntries.clear();
      _previewLines.clear();
      _previewed   = false;
    });
    _addRateRow();
  }

  void _startEdit(CmBankFxRevaluation r) {
    _loadMeta();
    // Rebuild rate entries from existing lines
    final rates = <String, String>{};
    for (final l in r.lines) {
      rates[l.currencyCode] = l.newRate.toString();
    }
    for (final e in _rateEntries) { e.codeCtrl.dispose(); e.rateCtrl.dispose(); }
    _rateEntries.clear();
    rates.forEach((code, rate) {
      _rateEntries.add(_RateEntry(code: code, rate: rate));
    });
    if (_rateEntries.isEmpty) _rateEntries.add(_RateEntry());

    setState(() {
      _isEditing   = true;
      _isCreating  = false;
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
  }

  void _cancelForm() {
    setState(() { _isCreating = false; _isEditing = false; _previewLines.clear(); _previewed = false; });
  }

  void _addRateRow() {
    setState(() => _rateEntries.add(_RateEntry()));
  }

  void _removeRateRow(int index) {
    final e = _rateEntries[index];
    e.codeCtrl.dispose();
    e.rateCtrl.dispose();
    setState(() => _rateEntries.removeAt(index));
  }

  Map<String, double> get _ratesMap {
    final m = <String, double>{};
    for (final e in _rateEntries) {
      final code = e.codeCtrl.text.trim().toUpperCase();
      final rate = double.tryParse(e.rateCtrl.text) ?? 0;
      if (code.isNotEmpty && rate > 0) {
        m[code] = rate;
      }
    }
    return m;
  }

  Future<void> _preview() async {
    if (_formDate == null) { _showError('กรุณาระบุวันที่'); return; }
    final rates = _ratesMap;
    if (rates.isEmpty) { _showError('กรุณาระบุ Exchange Rate อย่างน้อย 1 สกุลเงิน'); return; }
    setState(() { _saving = true; _previewed = false; });
    try {
      final lines = await _svc.previewLines(
        revaluationDate: DateFormat('yyyy-MM-dd').format(_formDate!),
        rates: rates,
      );
      if (!mounted) return;
      setState(() { _previewLines = lines; _previewed = true; _saving = false; });
      if (lines.isEmpty) _showError('ไม่พบบัญชีธนาคาร FC ที่มียอดคงเหลือสำหรับ Currency ที่ระบุ');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(e.toString());
    }
  }

  Future<void> _save({bool post = false}) async {
    if (_formDate == null) { _showError('กรุณาระบุวันที่'); return; }
    if (post && (_formGainAcctId == null || _formLossAcctId == null)) {
      _showError('กรุณาระบุบัญชี FX Gain และ FX Loss ก่อน Post GL');
      return;
    }
    if (!_previewed || _previewLines.isEmpty) {
      _showError('กรุณาคำนวณก่อนบันทึก');
      return;
    }
    setState(() => _saving = true);
    try {
      final body = {
        'revaluation_date':   DateFormat('yyyy-MM-dd').format(_formDate!),
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
          _showSuccess('Post GL สำเร็จ (${updatedResult.glDocNo ?? ''})');
        }
      } else {
        final full = await _svc.fetchRow(result.id);
        if (mounted) {
          setState(() { _saving = false; _isCreating = false; _isEditing = false; _selected = full; });
          await _loadHistory();
          _showSuccess('บันทึก Draft สำเร็จ');
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(e.toString());
    }
  }

  Future<void> _postExisting() async {
    if (_selected == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยัน Post GL'),
        content: const Text('ต้องการบันทึก GL Entry สำหรับ FX Revaluation นี้ใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
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
      _showSuccess('Post GL สำเร็จ (${updated.glDocNo ?? ''})');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(e.toString());
    }
  }

  Future<void> _voidSelected() async {
    if (_selected == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันการยกเลิก'),
        content: const Text('ต้องการยกเลิก FX Revaluation นี้ใช่หรือไม่?\nระบบจะสร้าง GL Entry ย้อนกลับโดยอัตโนมัติ'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยันยกเลิก'),
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
      _showSuccess('ยกเลิก FX Revaluation สำเร็จ');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(e.toString());
    }
  }

  Future<void> _deleteSelected() async {
    if (_selected == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: const Text('ต้องการลบรายการนี้ใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.deleteRow(_selected!.id);
      setState(() => _selected = null);
      await _loadHistory();
      _showSuccess('ลบสำเร็จ');
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kTheme,
        foregroundColor: Colors.white,
        title: const Text('Bank FX Revaluation'),
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
            // Left panel — history list
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _leftExpanded ? 260 : 0,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  maxWidth: 260,
                  child: _buildHistoryPanel(),
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

  Widget _buildHistoryPanel() {
    return Container(
      color: Colors.blueGrey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 36,
            color: Colors.blueGrey.shade200,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: const Text('ประวัติ FX Revaluation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kTheme,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: _startCreate,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('สร้างรายการใหม่', style: TextStyle(fontSize: 12)),
            ),
          ),
          Expanded(
            child: _loadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _history.isEmpty
                    ? const Center(child: Text('ยังไม่มีรายการ', style: TextStyle(color: Colors.grey, fontSize: 12)))
                    : ListView.builder(
                        itemCount: _history.length,
                        itemBuilder: (_, i) => _buildHistoryCard(_history[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(CmBankFxRevaluation r) {
    final selected = r.id == _selected?.id;
    Color statusColor;
    switch (r.status) {
      case 'Posted': statusColor = Colors.green.shade700; break;
      case 'Voided': statusColor = Colors.red.shade700;   break;
      default:       statusColor = Colors.orange.shade700;
    }
    final gainLoss = r.totalGainLoss;
    final gainLossColor = gainLoss >= 0 ? Colors.green.shade700 : Colors.red.shade700;
    return InkWell(
      onTap: () {
        setState(() { _selected = r; _isCreating = false; _isEditing = false; });
        if (r.lines.isEmpty) {
          _svc.fetchRow(r.id).then((full) {
            if (mounted) setState(() => _selected = full);
          }).catchError((Object e) { _showError(e.toString()); return null; });
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: selected ? _kTheme.withOpacity(0.1) : null,
          border: Border(
            left: BorderSide(width: 3, color: selected ? _kTheme : Colors.transparent),
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _dateFmt.format(r.revaluationDate),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                  child: Text(cmFxRevalStatusOptions[r.status] ?? r.status, style: TextStyle(fontSize: 10, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: Text(gainLoss == 0 ? '' : (gainLoss > 0 ? 'Gain: ' : 'Loss: '),
                      style: TextStyle(fontSize: 11, color: gainLossColor)),
                ),
                Text(
                  gainLoss != 0 ? _fmt.format(gainLoss.abs()) : '—',
                  style: TextStyle(fontSize: 11, color: gainLossColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (r.glDocNo != null)
              Text(r.glDocNo!, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildRightPanel() {
    if (_isCreating || _isEditing) return _buildFormPanel();
    if (_selected != null) return _buildDetailPanel(_selected!);
    return const Center(child: Text('เลือกรายการจากประวัติ หรือสร้างรายการใหม่', style: TextStyle(color: Colors.grey)));
  }

  // ── Form panel ─────────────────────────────────────────────────────────────
  Widget _buildFormPanel() {
    final isEdit = _isEditing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title bar
        Container(
          color: Colors.grey.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(isEdit ? 'แก้ไข FX Revaluation' : 'สร้าง FX Revaluation',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(onPressed: _cancelForm, child: const Text('ยกเลิก')),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Section 1: Header ───────────────────────────────────────
                const Text('ข้อมูลทั่วไป', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(
                      width: 180,
                      child: InkWell(
                        onTap: () async {
                          final p = await showDatePicker(
                            context: context,
                            initialDate: _formDate ?? DateTime.now(),
                            firstDate: DateTime(2000), lastDate: DateTime(2100),
                          );
                          if (p != null) setState(() { _formDate = p; _previewed = false; });
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'วันที่ *', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                          child: Text(_formDate != null ? _dateFmt.format(_formDate!) : '—'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<int?>(
                        value: _formGlDocId,
                        isDense: true,
                        decoration: const InputDecoration(labelText: 'GL Doc Type', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('— ไม่ระบุ —', style: TextStyle(fontSize: 12))),
                          ..._glDocTypes.map((d) => DropdownMenuItem<int?>(
                            value: d.id,
                            child: Text('${d.docCode} ${d.docNameThai}', style: const TextStyle(fontSize: 12)),
                          )),
                        ],
                        onChanged: (v) => setState(() => _formGlDocId = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _formDescCtrl,
                        decoration: const InputDecoration(labelText: 'คำอธิบาย', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _accountPickerField(
                      label: 'บัญชี FX Gain *',
                      display: _formGainAcctDisplay,
                      onPick: () async {
                        final a = await _pickAccount();
                        if (a != null) setState(() {
                          _formGainAcctId = a.id;
                          _formGainAcctDisplay = '${a.accountCode} ${a.accountNameThai}';
                        });
                      },
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _accountPickerField(
                      label: 'บัญชี FX Loss *',
                      display: _formLossAcctDisplay,
                      onPick: () async {
                        final a = await _pickAccount();
                        if (a != null) setState(() {
                          _formLossAcctId = a.id;
                          _formLossAcctDisplay = '${a.accountCode} ${a.accountNameThai}';
                        });
                      },
                    )),
                  ],
                ),
                const SizedBox(height: 20),
                // ── Section 2: Currency rates ─────────────────────────────
                Row(
                  children: [
                    const Text('Exchange Rates', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: _addRateRow,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('เพิ่มสกุลเงิน', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._rateEntries.asMap().entries.map((entry) {
                  final i = entry.key;
                  final e = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: e.codeCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Currency', border: OutlineInputBorder(), isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              hintText: 'USD',
                            ),
                            onChanged: (_) => setState(() => _previewed = false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 160,
                          child: TextField(
                            controller: e.rateCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Rate (THB per 1 unit)', border: OutlineInputBorder(), isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() => _previewed = false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          onPressed: _rateEntries.length > 1 ? () => _removeRateRow(i) : null,
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),
                // ── Calculate button ──────────────────────────────────────
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(160, 36),
                  ),
                  onPressed: _saving ? null : _preview,
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.calculate, size: 18),
                  label: const Text('คำนวณ (Preview)'),
                ),
                const SizedBox(height: 16),
                // ── Preview lines ──────────────────────────────────────────
                if (_previewed) ...[
                  const Divider(),
                  Text('ผลการคำนวณ (${_previewLines.length} บัญชี)',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_previewLines.isEmpty)
                    const Text('ไม่พบบัญชีที่ต้องปรับปรุง', style: TextStyle(color: Colors.grey))
                  else
                    _buildPreviewTable(_previewLines),
                  const SizedBox(height: 16),
                  // ── Action buttons ──────────────────────────────────────
                  if (_previewLines.isNotEmpty)
                    Row(
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(minimumSize: const Size(120, 36)),
                          onPressed: _saving ? null : () => _save(post: false),
                          child: const Text('บันทึก Draft'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kTheme,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(160, 36),
                          ),
                          onPressed: _saving ? null : () => _save(post: true),
                          icon: _saving
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('Post GL'),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _accountPickerField({required String label, required String display, required VoidCallback onPick}) {
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
          display.isEmpty ? '— เลือกบัญชี —' : display,
          style: TextStyle(fontSize: 12, color: display.isEmpty ? Colors.grey : Colors.black87),
        ),
      ),
    );
  }

  Widget _buildPreviewTable(List<CmFxPreviewLine> lines) {
    final totalGainLoss = lines.fold(0.0, (s, l) => s + l.fxGainLoss);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 34,
            dataRowMinHeight: 30,
            dataRowMaxHeight: 36,
            columnSpacing: 14,
            headingTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
            columns: const [
              DataColumn(label: Text('บัญชีธนาคาร')),
              DataColumn(label: Text('Currency')),
              DataColumn(label: Text('FC Balance'),    numeric: true),
              DataColumn(label: Text('LC ตามบัญชี'), numeric: true),
              DataColumn(label: Text('Rate ใหม่'),     numeric: true),
              DataColumn(label: Text('LC ใหม่'),       numeric: true),
              DataColumn(label: Text('FX +/-'),         numeric: true),
            ],
            rows: lines.map((l) {
              final isGain = l.fxGainLoss >= 0;
              return DataRow(cells: [
                DataCell(Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${l.bankAccountCode ?? ''}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('รวม FX Gain/Loss: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            Text(
              '${totalGainLoss >= 0 ? '+' : ''}${_fmt.format(totalGainLoss)}',
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold,
                color: totalGainLoss >= 0 ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Detail panel ───────────────────────────────────────────────────────────
  Widget _buildDetailPanel(CmBankFxRevaluation r) {
    Color statusColor;
    switch (r.status) {
      case 'Posted': statusColor = Colors.green.shade700; break;
      case 'Voided': statusColor = Colors.red.shade700;   break;
      default:       statusColor = Colors.orange.shade700;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header bar
        Container(
          color: Colors.grey.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Status chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(cmFxRevalStatusOptions[r.status] ?? r.status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Text(_dateFmt.format(r.revaluationDate), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              if (r.glDocNo != null) ...[
                const SizedBox(width: 12),
                Text('GL: ${r.glDocNo}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ],
              const Spacer(),
              _buildDetailActions(r),
            ],
          ),
        ),
        // Info row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.blue.shade50,
          child: Wrap(
            spacing: 24,
            children: [
              _infoItem('คำอธิบาย', r.description ?? '—'),
              if (r.fxGainAccountCode != null)
                _infoItem('FX Gain', '${r.fxGainAccountCode} ${r.fxGainAccountName ?? ''}'),
              if (r.fxLossAccountCode != null)
                _infoItem('FX Loss', '${r.fxLossAccountCode} ${r.fxLossAccountName ?? ''}'),
              _infoItem('รวม Gain/Loss', _fmt.format(r.totalGainLoss),
                  valueColor: r.totalGainLoss >= 0 ? Colors.green.shade700 : Colors.red.shade700),
            ],
          ),
        ),
        const Divider(height: 1),
        // Lines table
        Expanded(
          child: r.lines.isEmpty
              ? const Center(child: Text('ไม่มีรายการ', style: TextStyle(color: Colors.grey)))
              : SingleChildScrollView(
                  child: _buildSavedLinesTable(r.lines),
                ),
        ),
      ],
    );
  }

  Widget _infoItem(String label, String value, {Color? valueColor}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('$label: ', style: const TextStyle(fontSize: 11, color: Colors.grey)),
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: valueColor)),
    ],
  );

  Widget _buildDetailActions(CmBankFxRevaluation r) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (r.isDraft) ...[
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 10)),
            onPressed: () => _startEdit(r),
            child: const Text('แก้ไข', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 6),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white,
                minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 10)),
            onPressed: _saving ? null : _postExisting,
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('Post GL', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 6),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 10)),
            onPressed: _deleteSelected,
            child: const Text('ลบ', style: TextStyle(fontSize: 12)),
          ),
        ],
        if (r.isPosted) ...[
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 10)),
            onPressed: _saving ? null : _voidSelected,
            child: const Text('ยกเลิก', style: TextStyle(fontSize: 12)),
          ),
        ],
      ],
    );
  }

  Widget _buildSavedLinesTable(List<CmBankFxRevaluationLine> lines) {
    final total = lines.fold(0.0, (s, l) => s + l.fxGainLoss);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DataTable(
            headingRowHeight: 34,
            dataRowMinHeight: 30,
            dataRowMaxHeight: 36,
            columnSpacing: 14,
            headingTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
            columns: const [
              DataColumn(label: Text('บัญชีธนาคาร')),
              DataColumn(label: Text('Currency')),
              DataColumn(label: Text('GL Account')),
              DataColumn(label: Text('FC Balance'),    numeric: true),
              DataColumn(label: Text('LC ตามบัญชี'), numeric: true),
              DataColumn(label: Text('Rate ใหม่'),     numeric: true),
              DataColumn(label: Text('LC ใหม่'),       numeric: true),
              DataColumn(label: Text('FX +/-'),         numeric: true),
            ],
            rows: lines.map((l) {
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
                DataCell(Text(l.glAccountCode ?? '', style: const TextStyle(fontSize: 11))),
                DataCell(Text(_fmtFc.format(l.balanceFc),    style: const TextStyle(fontSize: 11))),
                DataCell(Text(_fmt.format(l.balanceLcBook),  style: const TextStyle(fontSize: 11))),
                DataCell(Text(_fmtRate.format(l.newRate),    style: const TextStyle(fontSize: 11))),
                DataCell(Text(_fmt.format(l.balanceLcNew),   style: const TextStyle(fontSize: 11))),
                DataCell(Text(
                  '${isGain && l.fxGainLoss != 0 ? '+' : ''}${_fmt.format(l.fxGainLoss)}',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold,
                    color: l.fxGainLoss == 0 ? Colors.grey : (isGain ? Colors.green.shade700 : Colors.red.shade700),
                  ),
                )),
              ]);
            }).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('รวม FX Gain/Loss: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Text(
                '${total >= 0 ? '+' : ''}${_fmt.format(total)}',
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold,
                  color: total >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Currency rate entry ──────────────────────────────────────────────────────
class _RateEntry {
  final TextEditingController codeCtrl;
  final TextEditingController rateCtrl;
  _RateEntry({String code = '', String rate = ''})
      : codeCtrl = TextEditingController(text: code),
        rateCtrl = TextEditingController(text: rate);
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
    final filtered = _q.isEmpty
        ? widget.accounts
        : widget.accounts.where((a) =>
            a.accountCode.toLowerCase().contains(_q.toLowerCase()) ||
            a.accountNameThai.toLowerCase().contains(_q.toLowerCase())).toList();
    return AlertDialog(
      title: const Text('เลือกผังบัญชี'),
      content: SizedBox(
        width: 480,
        height: 400,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(hintText: 'ค้นหา...', prefixIcon: Icon(Icons.search), isDense: true, border: OutlineInputBorder()),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final a = filtered[i];
                  return ListTile(
                    dense: true,
                    title: Text('${a.accountCode}  ${a.accountNameThai}', style: const TextStyle(fontSize: 12)),
                    onTap: () => Navigator.pop(context, a),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
      ],
    );
  }
}
