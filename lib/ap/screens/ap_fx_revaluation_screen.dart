import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../models/ap_year_end.dart';
import '../services/ap_year_end_service.dart';
import '../../utils/date_utils.dart';
import '../../sa/models/sa_document_reverse_log.dart';
import '../../sa/widgets/sa_document_reverse_widgets.dart';
import '../../cd/services/cd_currency_service.dart';
import '../../gl/widgets/gl_journal_preview.dart';

// ถอยเป็นร่าง (งวดเปิด + แบบ realized ใบตั้งหนี้ยังไม่เปลี่ยน) → โพสต์ใหม่ด้วยเลขที่รายการบัญชีเดิม หรือลบ
// ยกเลิกใช้เมื่อถอยไม่ได้ (ลงรายการกลับวันนี้) ทุกการกระทำต้องมีเหตุผล — ปุ่มที่ทำไม่ได้ล็อกพร้อมเหตุผล

class ApFxRevaluationScreen extends StatefulWidget {
  const ApFxRevaluationScreen({super.key});

  @override
  State<ApFxRevaluationScreen> createState() => _ApFxRevaluationScreenState();
}

class _ApFxRevaluationScreenState extends State<ApFxRevaluationScreen>
    with AutomaticKeepAliveClientMixin {
  final ApYearEndService _svc     = ApYearEndService();
  final _fmt     = NumberFormat('#,##0.00', 'en_US');
  final _rateFmt = NumberFormat('#,##0.000000', 'en_US');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  static const _kIndigo = Color(0xFF3949AB);

  bool _isEnglish = false;

  List<ApFxRevaluationHeader> _rows = [];
  bool _isLoading = true;

  ApFxRevaluationHeader?      _selectedRow;
  List<ApFxRevaluationDetail> _details = [];
  DocActions _actions = const DocActions();
  bool _isDetailLoading = false;
  bool _showDeleted = false;
  bool _isActing = false;

  // Panel state
  bool   _isLeftPanelExpanded = true;
  bool   _isDraggingDivider   = false;
  double _leftPanelWidth      = 280.0;

  // Form state
  bool      _isCreating   = false;
  DateTime  _revalDate    = DateTime(DateTime.now().year, 12, 31);
  DateTime? _reversalDate = DateTime(DateTime.now().year + 1, 1, 1);
  String    _method       = 'reversing';
  int       _periodYear   = DateTime.now().year;
  final _noteCtrl = TextEditingController();

  // Outstanding currencies
  List<Map<String, dynamic>> _outstandingCurrencies = [];
  bool _isFetchingCurrencies = false;
  final Map<int, TextEditingController> _rateCtrl = {};

  // Preview state
  List<Map<String, dynamic>> _previewDetails = [];
  double _previewTotal = 0;
  bool   _isPreviewing = false;
  List<GlJournalLine> _previewJournal = [];
  String? _previewJournalError;

  // รายการบัญชีของรายการที่เลือก (ร่าง = ที่จะเกิดเมื่อโพสต์, โพสต์แล้ว = รายการจริง)
  List<GlJournalLine> _journal = [];
  bool    _journalPosted = false;
  String? _journalError;
  final ScrollController _previewVertCtrl  = ScrollController();
  final ScrollController _previewHorizCtrl = ScrollController();

  // Detail table scroll controllers
  final ScrollController _detailVertCtrl  = ScrollController();
  final ScrollController _detailHorizCtrl = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    for (final c in _rateCtrl.values) c.dispose();
    _noteCtrl.dispose();
    _previewVertCtrl.dispose();
    _previewHorizCtrl.dispose();
    _detailVertCtrl.dispose();
    _detailHorizCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      _rows = await _svc.fetchRevaluations(showDeleted: _showDeleted);
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadOutstandingCurrencies() async {
    setState(() { _isFetchingCurrencies = true; _outstandingCurrencies = []; _previewDetails = []; });
    try {
      final list = await _svc.fetchOutstandingCurrencies(
          formatLocalDate(_revalDate));
      final newIds = list.map((c) => c['currency_id'] as int).toSet();
      _rateCtrl.removeWhere((id, ctrl) {
        if (!newIds.contains(id)) { ctrl.dispose(); return true; }
        return false;
      });
      for (final c in list) {
        _rateCtrl[c['currency_id'] as int] ??= TextEditingController();
      }
      setState(() { _outstandingCurrencies = list; _isFetchingCurrencies = false; });
    } catch (e) {
      setState(() => _isFetchingCurrencies = false);
      if (mounted) _showError(e.toString());
    }
  }

  Future<void> _selectRow(ApFxRevaluationHeader row) async {
    setState(() { _selectedRow = row; _isDetailLoading = true; _isCreating = false; });
    try {
      final data = await _svc.fetchRevaluationDetail(row.id);
      final dtlList = (data['details'] as List)
          .map((e) => ApFxRevaluationDetail.fromJson(e as Map<String, dynamic>)).toList();
      final header = ApFxRevaluationHeader.fromJson(data['header'] as Map<String, dynamic>);
      setState(() {
        _selectedRow = header;
        _details = dtlList;
        _actions = DocActions.fromJson(data);
        _journal = GlJournalLine.listFromJson(data['journal']);
        _journalPosted = data['journal_posted'] == true;
        _journalError = data['journal_error']?.toString();
        _isDetailLoading = false;
      });
    } catch (e) {
      setState(() => _isDetailLoading = false);
      if (mounted) _showError(e.toString());
    }
  }

  Map<String, double> _buildRates() {
    final m = <String, double>{};
    for (final c in _outstandingCurrencies) {
      final id = c['currency_id'] as int;
      final v = double.tryParse(_rateCtrl[id]?.text.replaceAll(',', '') ?? '');
      if (v != null && v > 0) m[id.toString()] = v;
    }
    return m;
  }

  Future<void> _preview() async {
    final isEnglish = _isEnglish;
    final rates = _buildRates();
    if (rates.isEmpty) { _showError(isEnglish ? 'Please enter the year-end exchange rate for at least 1 currency' : 'กรุณาใส่อัตราแลกเปลี่ยน ณ สิ้นปีอย่างน้อย 1 สกุล'); return; }
    setState(() => _isPreviewing = true);
    try {
      final data = await _svc.previewReval(
        revalDate: formatLocalDate(_revalDate),
        yearEndRates: rates,
        method: _method,
      );
      setState(() {
        _previewDetails = List<Map<String, dynamic>>.from(data['details'] ?? []);
        _previewTotal   = double.tryParse(data['total_fx_gain_loss'].toString()) ?? 0;
        _previewJournal = GlJournalLine.listFromJson(data['journal']);
        _previewJournalError = data['journal_error']?.toString();
      });
    } catch (e) { _showError(e.toString()); }
    finally { setState(() => _isPreviewing = false); }
  }

  Future<void> _save() async {
    final isEnglish = _isEnglish;
    final rates = _buildRates();
    if (rates.isEmpty) { _showError(isEnglish ? 'Please enter the year-end exchange rate for at least 1 currency' : 'กรุณาใส่อัตราแลกเปลี่ยน ณ สิ้นปีอย่างน้อย 1 สกุล'); return; }
    setState(() => _isPreviewing = true);
    try {
      final id = await _svc.createReval(
        revalDate:    formatLocalDate(_revalDate),
        periodYear:   _periodYear,
        method:       _method,
        reversalDate: _method == 'reversing' && _reversalDate != null
            ? formatLocalDate(_reversalDate!) : null,
        note:         _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        yearEndRates: rates,
      );
      await _loadAll();
      final newRow = _rows.firstWhere((r) => r.id == id);
      await _selectRow(newRow);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEnglish ? 'Draft saved successfully' : 'บันทึก Draft สำเร็จ'), backgroundColor: _kIndigo));
    } catch (e) { _showError(e.toString()); }
    finally { setState(() => _isPreviewing = false); }
  }

  Future<void> _deleteDraft(int id) async {
    final isEnglish = _isEnglish;
    if (!(MenuScope.of(context)?.canDelete ?? true)) return;
    final reason = await showDocReasonDialog(
      context,
      isEnglish: isEnglish,
      title: isEnglish ? 'Delete Draft' : 'ลบร่าง',
      message: isEnglish
          ? 'Delete this draft? It will be kept as Deleted for audit and cannot be used again.'
          : 'ลบร่างรายการนี้? ระบบเก็บไว้ด้วยสถานะ "ลบแล้ว" เพื่อตรวจสอบ และนำกลับมาใช้ไม่ได้',
      confirmLabel: isEnglish ? 'Delete' : 'ลบ',
    );
    if (reason == null) return;
    try {
      await _svc.deleteReval(id, reason);
      setState(() { _selectedRow = null; _isCreating = false; _details = []; _actions = const DocActions(); });
      await _loadAll();
    } catch (e) { _showError(e.toString()); }
  }

  Future<void> _reverse(int id) async {
    final isEnglish = _isEnglish;
    if (!(MenuScope.of(context)?.canEdit ?? true)) return;
    final reason = await showDocReasonDialog(
      context,
      isEnglish: isEnglish,
      title: isEnglish ? 'Reverse to Draft' : 'ถอยเป็นร่าง',
      message: isEnglish
          ? 'Reverse this revaluation to draft? Its GL entries will be removed (and invoice balances restored for the realized method). Post again to reuse the same GL number.'
          : 'ถอยรายการปรับมูลค่านี้เป็นร่าง? รายการบัญชี (และรายการกลับ) จะถูกลบ แบบ realized จะคืนยอดคงค้างของใบตั้งหนี้ โพสต์ใหม่ได้ด้วยเลขที่รายการบัญชีเดิม',
      confirmLabel: isEnglish ? 'Reverse' : 'ถอยเป็นร่าง',
      confirmColor: Colors.orange.shade800,
    );
    if (reason == null) return;
    await _act(id, () => _svc.reverseReval(id, reason));
  }

  // ทำรายการแล้วโหลดรายการและรายละเอียดใหม่
  Future<void> _act(int id, Future<void> Function() action) async {
    setState(() => _isActing = true);
    try {
      await action();
      await _loadAll();
      final row = _rows.where((r) => r.id == id).firstOrNull;
      if (row != null) await _selectRow(row);
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  // ปุ่มที่ทำไม่ได้: ล็อกและแสดงเหตุผลเมื่อชี้เมาส์
  Widget _lockable(DocBlock? block, Widget Function(VoidCallback? onPressed) builder, VoidCallback action) {
    final button = builder(block == null && !_isActing ? action : null);
    return block == null ? button : Tooltip(message: block.text(_isEnglish), child: button);
  }

  String _statusLabel(String s) {
    const th = {'Draft': 'ร่าง', 'Posted': 'โพสต์แล้ว', 'Void': 'ยกเลิก', 'Deleted': 'ลบแล้ว'};
    return _isEnglish ? s : (th[s] ?? s);
  }

  Future<void> _post(int id) async {
    final isEnglish = _isEnglish;
    if (!(MenuScope.of(context)?.canEdit ?? true)) return;
    final ok = await _confirm(isEnglish ? 'Post this entry and create a GL entry?' : 'Post รายการนี้และสร้าง GL entry?');
    if (!ok) return;
    try {
      await _svc.postReval(id);
      await _loadAll();
      final row = _rows.firstWhere((r) => r.id == id);
      await _selectRow(row);
    } catch (e) { _showError(e.toString()); }
  }

  Future<void> _void(int id) async {
    final isEnglish = _isEnglish;
    if (!(MenuScope.of(context)?.canDelete ?? true)) return;
    final reason = await showDocReasonDialog(
      context,
      isEnglish: isEnglish,
      title: isEnglish ? 'Void Revaluation' : 'ยกเลิกรายการปรับมูลค่า',
      message: isEnglish
          ? 'Void this revaluation? Reversing GL entries will be posted today (use this when it cannot be reversed to draft).'
          : 'ยกเลิกรายการนี้? ระบบจะลงรายการบัญชีกลับในวันนี้ (ใช้เมื่อถอยเป็นร่างไม่ได้ เช่น งวดปิดแล้ว)',
      confirmLabel: isEnglish ? 'Void' : 'ยืนยันยกเลิก',
    );
    if (reason == null) return;
    await _act(id, () => _svc.voidReval(id, reason));
  }

  Future<bool> _confirm(String msg) async {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEnglish ? 'Confirm' : 'ยืนยัน'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _kIndigo),
            child: Text(isEnglish ? 'Confirm' : 'ยืนยัน'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showError(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  Color _statusColor(String s) =>
      s == 'Posted' ? _kIndigo : (s == 'Void' || s == 'Deleted') ? Colors.red : Colors.orange;

  // ── Left panel ────────────────────────────────────────────────────────────

  Widget _buildLeftPanel() {
    final isEnglish = _isEnglish;
    return Column(children: [
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      color: const Color(0xFFE8EAF6),
      width: double.infinity,
      child: Row(children: [
        Expanded(
          child: FilledButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: Text(isEnglish ? 'New' : 'สร้างใหม่'),
            style: FilledButton.styleFrom(backgroundColor: _kIndigo),
            onPressed: () {
              setState(() { _isCreating = true; _selectedRow = null; });
              _loadOutstandingCurrencies();
            },
          ),
        ),
        IconButton(
          tooltip: _showDeleted
              ? (isEnglish ? 'Show active entries' : 'แสดงรายการปกติ')
              : (isEnglish ? 'Show deleted entries' : 'แสดงรายการที่ลบแล้ว'),
          icon: Icon(_showDeleted ? Icons.delete : Icons.delete_outline, color: _showDeleted ? Colors.red : Colors.grey[700]),
          onPressed: () {
            setState(() { _showDeleted = !_showDeleted; _selectedRow = null; _details = []; });
            _loadAll();
          },
        ),
      ]),
    ),
    Expanded(
      child: _rows.isEmpty
          ? Center(child: Text(isEnglish ? 'No entries' : 'ไม่มีรายการ', style: const TextStyle(color: Colors.grey)))
          : ListView.builder(
              itemCount: _rows.length,
              itemBuilder: (ctx, i) {
                final r = _rows[i];
                final selected = _selectedRow?.id == r.id;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: selected ? const Color(0xFFE8EAF6) : null,
                  shape: selected
                      ? RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: const Color(0xFF3949AB).withOpacity(0.6), width: 1.5))
                      : null,
                  child: ListTile(
                    dense: true,
                    onTap: () => _selectRow(r),
                    title: Text(_dateFmt.format(r.revalDate),
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13,
                            color: selected ? const Color(0xFF1A237E) : null)),
                    subtitle: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _statusColor(r.status).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(_statusLabel(r.status),
                            style: TextStyle(fontSize: 11, color: _statusColor(r.status))),
                      ),
                      const SizedBox(width: 6),
                      Text(r.method == 'reversing' ? 'Reversing' : 'Realized',
                          style: const TextStyle(fontSize: 11)),
                    ]),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                        (r.totalFxGainLoss >= 0 ? '+' : '') + _fmt.format(r.totalFxGainLoss),
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold,
                          color: r.totalFxGainLoss >= 0 ? _kIndigo : Colors.red,
                        ),
                      ),
                      if (r.status == 'Draft') ...[
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => _deleteDraft(r.id),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.delete_outline, size: 16, color: Colors.red[400]),
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

  // ── Create form ───────────────────────────────────────────────────────────

  Widget _buildCreateForm() {
    final isEnglish = _isEnglish;
    return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── Card 1: ข้อมูลทั่วไป ─────────────────────────────────────────────
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isEnglish ? 'Create AP FX Revaluation Entry' : 'สร้างรายการปรับมูลค่าเจ้าหนี้จากอัตราแลกเปลี่ยน',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _kIndigo)),
            const Divider(height: 20),
            Wrap(spacing: 32, runSpacing: 12, children: [
              _labelField(isEnglish ? 'Fiscal Year' : 'ปีบัญชี', SizedBox(
                width: 100,
                child: DropdownButtonFormField<int>(
                  value: _periodYear,
                  decoration: const InputDecoration(
                      isDense: true, border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                  items: List.generate(5, (i) => DateTime.now().year - i).map((y) =>
                      DropdownMenuItem(value: y,
                          child: Text(y.toString(),
                              style: const TextStyle(fontSize: 14)))).toList(),
                  onChanged: (v) => setState(() => _periodYear = v ?? _periodYear),
                ),
              )),
              _labelField(isEnglish ? 'Revaluation Date' : 'วันที่ปรับมูลค่า', InkWell(
                onTap: () async {
                  final d = await showDatePicker(context: context,
                      initialDate: _revalDate,
                      firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (d != null) {
                    setState(() => _revalDate = d);
                    _loadOutstandingCurrencies();
                  }
                },
                child: Container(
                  width: 150,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(4)),
                  child: Text(_dateFmt.format(_revalDate),
                      style: const TextStyle(fontSize: 14)),
                ),
              )),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 32, runSpacing: 12, children: [
              _labelField(isEnglish ? 'Method' : 'วิธีปรับมูลค่า', Row(mainAxisSize: MainAxisSize.min, children: [
                Radio<String>(value: 'realized', groupValue: _method,
                    onChanged: (v) => setState(() { _method = v!; _previewDetails = []; _previewJournal = []; }),
                    activeColor: _kIndigo, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                const Text('Realized', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 12),
                Radio<String>(value: 'reversing', groupValue: _method,
                    onChanged: (v) => setState(() { _method = v!; _previewDetails = []; _previewJournal = []; }),
                    activeColor: _kIndigo, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                const Text('Reversing', style: TextStyle(fontSize: 14)),
              ])),
              if (_method == 'reversing')
                _labelField(isEnglish ? 'Reversal Date' : 'วันกลับรายการ', InkWell(
                  onTap: () async {
                    final d = await showDatePicker(context: context,
                        initialDate: _reversalDate ?? DateTime(DateTime.now().year + 1, 1, 1),
                        firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (d != null) setState(() => _reversalDate = d);
                  },
                  child: Container(
                    width: 150,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(
                        _reversalDate != null ? _dateFmt.format(_reversalDate!) : '-',
                        style: const TextStyle(fontSize: 14)),
                  ),
                )),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 12),

      // ── Card 2: อัตราแลกเปลี่ยน ──────────────────────────────────────────
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(isEnglish ? 'Exchange rate as of  ' : 'อัตราแลกเปลี่ยน ณ วันที่  ',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(_dateFmt.format(_revalDate),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _kIndigo)),
              if (_isFetchingCurrencies) ...[
                const SizedBox(width: 12),
                const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _kIndigo)),
              ],
            ]),
            const SizedBox(height: 4),
            Text(isEnglish
                    ? 'Shows only currencies with outstanding purchase orders/invoices as of this date'
                    : 'แสดงเฉพาะสกุลเงินที่มีใบสั่งซื้อ/ใบแจ้งหนี้ค้างชำระ ณ วันที่ดังกล่าว',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const Divider(height: 20),
            if (_isFetchingCurrencies)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator(color: _kIndigo)),
              )
            else if (_outstandingCurrencies.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 18),
                  const SizedBox(width: 8),
                  Text(isEnglish
                          ? 'No outstanding foreign currency invoices found as of this date'
                          : 'ไม่พบใบแจ้งหนี้สกุลเงินต่างประเทศค้างชำระ ณ วันที่นี้',
                      style: TextStyle(fontSize: 14, color: Colors.orange[700])),
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
      const SizedBox(height: 12),

      // ── Card 3: หมายเหตุ ──────────────────────────────────────────────────
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isEnglish ? 'Note' : 'หมายเหตุ',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            TextFormField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  hintText: isEnglish ? 'Enter a note (optional)' : 'ระบุหมายเหตุ (ถ้ามี)'),
              style: const TextStyle(fontSize: 14),
              maxLines: 2,
            ),
          ]),
        ),
      ),
      const SizedBox(height: 16),

      // ── ปุ่มดำเนินการ ──────────────────────────────────────────────────────
      Row(children: [
        OutlinedButton.icon(
          icon: _isPreviewing
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.preview, size: 16),
          label: Text(isEnglish ? 'Calculate Preview' : 'คำนวณ Preview'),
          onPressed: (_isPreviewing || _isFetchingCurrencies || _outstandingCurrencies.isEmpty)
              ? null : _preview,
        ),
        const SizedBox(width: 12),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _kIndigo),
          onPressed: (_isPreviewing || _isFetchingCurrencies || _outstandingCurrencies.isEmpty)
              ? null : _save,
          child: Text(isEnglish ? 'Save Draft' : 'บันทึก Draft'),
        ),
      ]),

      if (_previewDetails.isNotEmpty) ...[
        const SizedBox(height: 16),
        SizedBox(height: 360, child: _buildPreviewTable()),
        const SizedBox(height: 12),
        GlJournalPreview(
          lines: _previewJournal, isEnglish: isEnglish, error: _previewJournalError,
          note: _journalNote(_method, _reversalDate),
        ),
      ],
    ]),
  );
  }

  Widget _currencyRateField(Map<String, dynamic> c) => SizedBox(
    width: 220,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      RichText(text: TextSpan(children: [
        TextSpan(text: c['currency_code']?.toString() ?? '',
            style: const TextStyle(fontWeight: FontWeight.bold,
                fontSize: 14, color: Colors.black87)),
        TextSpan(text: '  ${(_isEnglish && (c['currency_name_en']?.toString() ?? '').isNotEmpty) ? c['currency_name_en'] : (c['currency_name_th'] ?? '')}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ])),
      const SizedBox(height: 4),
      TextFormField(
        controller: _rateCtrl[c['currency_id'] as int],
        decoration: InputDecoration(
          isDense: true,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          suffixText: CurrencyService.baseCode,
          hintText: '0.000000',
        ),
        style: const TextStyle(fontSize: 14),
        textAlign: TextAlign.right,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    ]),
  );

  Widget _labelField(String label, Widget child) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(label, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 8),
      child,
    ],
  );

  // ── Preview table ─────────────────────────────────────────────────────────

  Widget _buildPreviewTable() {
    final isEnglish = _isEnglish;
    final table = DataTable(
      headingRowColor: WidgetStateProperty.all(const Color(0xFFE8EAF6)),
      columnSpacing: 16,
      dataRowMinHeight: 36,
      dataRowMaxHeight: 48,
      columns: [
        DataColumn(label: Text(isEnglish ? 'Vendor Code' : 'รหัสผู้จำหน่าย')),
        DataColumn(label: Text(isEnglish ? 'Vendor Name' : 'ชื่อผู้จำหน่าย')),
        DataColumn(label: Text(isEnglish ? 'Invoice' : 'ใบแจ้งหนี้')),
        DataColumn(label: Text(isEnglish ? 'Currency' : 'สกุลเงิน')),
        DataColumn(label: Text(isEnglish ? 'Balance FC' : 'ยอดค้าง FC'),   numeric: true),
        DataColumn(label: Text(isEnglish ? 'Original Rate' : 'Rate เดิม'),     numeric: true),
        DataColumn(label: Text(isEnglish ? 'Amount Before ${CurrencyService.baseCode}' : 'ยอดก่อน ${CurrencyService.baseCode}'),  numeric: true),
        DataColumn(label: Text(isEnglish ? 'New Rate' : 'Rate ใหม่'),     numeric: true),
        DataColumn(label: Text(isEnglish ? 'Amount After ${CurrencyService.baseCode}' : 'ยอดหลัง ${CurrencyService.baseCode}'),  numeric: true),
        const DataColumn(label: Text('FX G/L'),        numeric: true),
      ],
      rows: [
        ..._previewDetails.map((d) {
          final gl = double.tryParse(d['fx_gain_loss'].toString()) ?? 0;
          return DataRow(cells: [
            DataCell(Text(d['vendor_code']?.toString() ?? '',
                style: const TextStyle(fontSize: 12))),
            DataCell(SizedBox(
              width: 160,
              child: Text(
                  isEnglish && (d['vendor_name_en']?.toString() ?? '').isNotEmpty
                      ? d['vendor_name_en'].toString()
                      : d['vendor_name_th']?.toString() ?? '',
                  style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
            )),
            DataCell(Text(d['doc_no']?.toString() ?? '',
                style: const TextStyle(fontSize: 12))),
            DataCell(Text(d['currency_code']?.toString() ?? '',
                style: const TextStyle(fontSize: 12))),
            DataCell(Text(_fmt.format(d['balance_amount_fc']),
                style: const TextStyle(fontSize: 12))),
            DataCell(Text(_rateFmt.format(d['original_rate']),
                style: const TextStyle(fontSize: 12))),
            DataCell(Text(_fmt.format(d['balance_amount_lc']),
                style: const TextStyle(fontSize: 12))),
            DataCell(Text(_rateFmt.format(d['year_end_rate']),
                style: const TextStyle(fontSize: 12))),
            DataCell(Text(_fmt.format(d['revalued_amount_lc']),
                style: const TextStyle(fontSize: 12))),
            DataCell(Text(
              (gl >= 0 ? '+' : '') + _fmt.format(gl),
              style: TextStyle(fontSize: 12,
                  color: gl >= 0 ? _kIndigo : Colors.red,
                  fontWeight: FontWeight.bold),
            )),
          ]);
        }),
        DataRow(
          color: WidgetStateProperty.all(const Color(0xFFE8EAF6)),
          cells: [
            DataCell(Text(isEnglish ? 'Total' : 'รวม', style: const TextStyle(fontWeight: FontWeight.bold))),
            const DataCell(SizedBox()), const DataCell(SizedBox()),
            const DataCell(SizedBox()), const DataCell(SizedBox()),
            const DataCell(SizedBox()), const DataCell(SizedBox()),
            const DataCell(SizedBox()), const DataCell(SizedBox()),
            DataCell(Text(
              (_previewTotal >= 0 ? '+' : '') + _fmt.format(_previewTotal),
              style: TextStyle(fontWeight: FontWeight.bold,
                  color: _previewTotal >= 0 ? _kIndigo : Colors.red),
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
            Text(isEnglish ? 'Calculation Result' : 'ผลการคำนวณ',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(width: 12),
            Text(isEnglish ? '${_previewDetails.length} items' : '${_previewDetails.length} รายการ',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: RawScrollbar(
            controller: _previewVertCtrl,
            thumbVisibility: true,
            trackVisibility: true,
            thickness: 8,
            radius: const Radius.circular(4),
            notificationPredicate: (n) => n.depth == 0,
            child: SingleChildScrollView(
              controller: _previewVertCtrl,
              child: RawScrollbar(
                controller: _previewHorizCtrl,
                thumbVisibility: true,
                trackVisibility: true,
                thickness: 8,
                radius: const Radius.circular(4),
                notificationPredicate: (n) => n.depth == 0,
                child: SingleChildScrollView(
                  controller: _previewHorizCtrl,
                  scrollDirection: Axis.horizontal,
                  child: table,
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Detail view ───────────────────────────────────────────────────────────

  Widget _buildDetail(ApFxRevaluationHeader row) {
    final isEnglish = _isEnglish;
    return Column(children: [
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.grey[50],
      child: Row(children: [
        _infoChip(isEnglish ? 'Date' : 'วันที่', _dateFmt.format(row.revalDate)),
        const SizedBox(width: 24),
        _infoChip(isEnglish ? 'Fiscal Year' : 'ปีบัญชี', row.periodYear.toString()),
        const SizedBox(width: 24),
        _infoChip(isEnglish ? 'Method' : 'วิธี', row.method == 'reversing' ? 'Reversing' : 'Realized'),
        const SizedBox(width: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _statusColor(row.status).withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(_statusLabel(row.status),
              style: TextStyle(color: _statusColor(row.status),
                  fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        const Spacer(),
        if (row.status == 'Draft') ...[
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kIndigo),
            onPressed: _isActing ? null : () => _post(row.id),
            child: const Text('Post'),
          ),
          const SizedBox(width: 8),
          _lockable(_actions.deleteBlock, (onPressed) => OutlinedButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: Text(isEnglish ? 'Delete' : 'ลบ'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
              ), () => _deleteDraft(row.id)),
        ],
        if (row.status == 'Posted') ...[
          _lockable(_actions.reverseBlock, (onPressed) => OutlinedButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.undo, size: 16),
                label: Text(isEnglish ? 'Reverse to Draft' : 'ถอยเป็นร่าง'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.orange[800]),
              ), () => _reverse(row.id)),
          const SizedBox(width: 8),
          _lockable(_actions.voidBlock, (onPressed) => OutlinedButton(
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red)),
                child: Text(isEnglish ? 'Void' : 'ยกเลิก'),
              ), () => _void(row.id)),
        ],
      ]),
    ),
    if (row.status == 'Void' && (row.voidReason ?? '').isNotEmpty)
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: Colors.red.shade50,
        child: Text('${isEnglish ? 'Void reason' : 'เหตุผลการยกเลิก'}: ${row.voidReason}',
            style: TextStyle(fontSize: 13, color: Colors.red.shade800)),
      ),
    DocReverseHistoryPanel(
      history: _actions.history,
      isDeleted: row.status == 'Deleted',
      isEnglish: isEnglish,
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
    ),
    if (row.glDocNo != null)
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: const Color(0xFFE8EAF6),
        child: Row(children: [
          Text('GL Entry: ${row.glDocNo}',
              style: const TextStyle(fontSize: 13, color: _kIndigo)),
          if (row.reversalDocNo != null) ...[
            const SizedBox(width: 16),
            Text('Reversing: ${row.reversalDocNo}',
                style: const TextStyle(fontSize: 13, color: _kIndigo)),
          ],
        ]),
      ),
    Expanded(
      child: _isDetailLoading
          ? const Center(child: CircularProgressIndicator(color: _kIndigo))
          : RawScrollbar(
              controller: _detailVertCtrl,
              thumbVisibility: true,
              trackVisibility: true,
              thickness: 8,
              radius: const Radius.circular(4),
              notificationPredicate: (n) => n.depth == 0,
              child: SingleChildScrollView(
                controller: _detailVertCtrl,
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                RawScrollbar(
                  controller: _detailHorizCtrl,
                  thumbVisibility: true,
                  trackVisibility: true,
                  thickness: 8,
                  radius: const Radius.circular(4),
                  notificationPredicate: (n) => n.depth == 0,
                  child: SingleChildScrollView(
                    controller: _detailHorizCtrl,
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFE8EAF6)),
                      columnSpacing: 16,
                      columns: [
                        DataColumn(label: Text(isEnglish ? 'Vendor Code' : 'รหัสผู้จำหน่าย')),
                        DataColumn(label: Text(isEnglish ? 'Vendor Name' : 'ชื่อผู้จำหน่าย')),
                        DataColumn(label: Text(isEnglish ? 'Invoice' : 'ใบแจ้งหนี้')),
                        DataColumn(label: Text(isEnglish ? 'Currency' : 'สกุลเงิน')),
                        DataColumn(label: Text(isEnglish ? 'Balance FC' : 'ยอดค้าง FC'),    numeric: true),
                        DataColumn(label: Text(isEnglish ? 'Original Rate' : 'Rate เดิม'),      numeric: true),
                        DataColumn(label: Text(isEnglish ? 'Amount Before ${CurrencyService.baseCode}' : 'ยอดก่อน ${CurrencyService.baseCode}'),   numeric: true),
                        DataColumn(label: Text(isEnglish ? 'New Rate' : 'Rate ใหม่'),      numeric: true),
                        DataColumn(label: Text(isEnglish ? 'Amount After ${CurrencyService.baseCode}' : 'ยอดหลัง ${CurrencyService.baseCode}'),   numeric: true),
                        const DataColumn(label: Text('FX G/L'),         numeric: true),
                      ],
                      rows: [
                        ..._details.map((d) {
                          final gl = d.fxGainLoss;
                          return DataRow(cells: [
                            DataCell(Text(d.vendorCode ?? '',
                                style: const TextStyle(fontSize: 12))),
                            DataCell(SizedBox(
                              width: 160,
                              child: Text(
                                  isEnglish && (d.vendorNameEn ?? '').isNotEmpty
                                      ? d.vendorNameEn!
                                      : d.vendorNameTh ?? '',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis),
                            )),
                            DataCell(Text(d.invoiceDocNo ?? '',
                                style: const TextStyle(fontSize: 12))),
                            DataCell(Text(d.currencyCode,
                                style: const TextStyle(fontSize: 12))),
                            DataCell(Text(_fmt.format(d.balanceAmountFc),
                                style: const TextStyle(fontSize: 12))),
                            DataCell(Text(_rateFmt.format(d.originalRate),
                                style: const TextStyle(fontSize: 12))),
                            DataCell(Text(_fmt.format(d.balanceAmountLc),
                                style: const TextStyle(fontSize: 12))),
                            DataCell(Text(_rateFmt.format(d.yearEndRate),
                                style: const TextStyle(fontSize: 12))),
                            DataCell(Text(_fmt.format(d.revaluedAmountLc),
                                style: const TextStyle(fontSize: 12))),
                            DataCell(Text(
                              (gl >= 0 ? '+' : '') + _fmt.format(gl),
                              style: TextStyle(fontSize: 12,
                                  color: gl >= 0 ? _kIndigo : Colors.red,
                                  fontWeight: FontWeight.bold),
                            )),
                          ]);
                        }),
                        DataRow(
                          color: WidgetStateProperty.all(const Color(0xFFE8EAF6)),
                          cells: [
                            DataCell(Text(isEnglish ? 'Total' : 'รวม',
                                style: const TextStyle(fontWeight: FontWeight.bold))),
                            const DataCell(SizedBox()), const DataCell(SizedBox()),
                            const DataCell(SizedBox()), const DataCell(SizedBox()),
                            const DataCell(SizedBox()), const DataCell(SizedBox()),
                            const DataCell(SizedBox()), const DataCell(SizedBox()),
                            DataCell(Text(
                              (row.totalFxGainLoss >= 0 ? '+' : '') +
                                  _fmt.format(row.totalFxGainLoss),
                              style: TextStyle(fontWeight: FontWeight.bold,
                                  color: row.totalFxGainLoss >= 0
                                      ? _kIndigo : Colors.red),
                            )),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GlJournalPreview(
                  lines: _journal, isEnglish: isEnglish, posted: _journalPosted, error: _journalError,
                  note: _journalNote(row.method, row.reversalDate),
                ),
                ]),
              ),
            ),
    ),
  ]);
  }

  // วิธี reversing ลงรายการกลับอัตโนมัติ ณ วันที่กลับรายการ / realized ปรับยอดคงค้างของเอกสารเป็นอัตราใหม่
  String _journalNote(String method, DateTime? reversalDate) {
    final isEnglish = _isEnglish;
    if (method == 'reversing') {
      final d = reversalDate != null ? _dateFmt.format(reversalDate) : '-';
      return isEnglish
          ? '* Unrealized FX accounts — the entry is automatically reversed (debit/credit swapped) on $d'
          : '* ใช้บัญชีกำไร/ขาดทุนที่ยังไม่เกิดขึ้น — ระบบลงรายการกลับ (สลับเดบิต/เครดิต) อัตโนมัติในวันที่ $d';
    }
    return isEnglish
        ? '* Realized FX accounts — outstanding balances are restated at the new rate (no reversing entry)'
        : '* ใช้บัญชีกำไร/ขาดทุนจากอัตราแลกเปลี่ยน — ยอดคงค้างของเอกสารปรับเป็นอัตราใหม่ (ไม่มีรายการกลับ)';
  }

  Widget _infoChip(String label, String value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ]);

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: _kIndigo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _kIndigo))
          : LayoutBuilder(builder: (ctx, constraints) {
              final maxLeft =
                  (constraints.maxWidth - 36 - 5 - 400).clamp(100.0, double.infinity);
              return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Collapse/expand toggle
                Container(
                  width: 36,
                  color: _kIndigo,
                  child: IconButton(
                    icon: Icon(
                      _isLeftPanelExpanded
                          ? Icons.filter_list_off
                          : Icons.filter_list,
                      color: Colors.white, size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () => setState(
                        () => _isLeftPanelExpanded = !_isLeftPanelExpanded),
                    tooltip: _isLeftPanelExpanded
                        ? (isEnglish ? 'Collapse list' : 'ย่อรายการ')
                        : (isEnglish ? 'Expand list' : 'ขยายรายการ'),
                  ),
                ),
                // Left panel (animated width)
                AnimatedContainer(
                  duration: _isDraggingDivider
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  width: _isLeftPanelExpanded ? _leftPanelWidth : 0,
                  child: ClipRect(
                    child: OverflowBox(
                      maxWidth: _leftPanelWidth,
                      minWidth: _leftPanelWidth,
                      alignment: Alignment.topLeft,
                      child: _buildLeftPanel(),
                    ),
                  ),
                ),
                // Drag divider
                if (_isLeftPanelExpanded)
                  MouseRegion(
                    cursor: SystemMouseCursors.resizeColumn,
                    child: GestureDetector(
                      onHorizontalDragStart: (_) =>
                          setState(() => _isDraggingDivider = true),
                      onHorizontalDragUpdate: (d) => setState(() {
                        _leftPanelWidth =
                            (_leftPanelWidth + d.delta.dx).clamp(180.0, maxLeft);
                      }),
                      onHorizontalDragEnd: (_) =>
                          setState(() => _isDraggingDivider = false),
                      child: Container(width: 5, color: Colors.grey[400]),
                    ),
                  ),
                // Right panel
                Expanded(
                  child: _isCreating
                      ? _buildCreateForm()
                      : _selectedRow != null
                          ? _buildDetail(_selectedRow!)
                          : Center(
                              child: Text(
                                  isEnglish
                                      ? 'Select an entry on the left, or click "+ New"'
                                      : 'เลือกรายการทางซ้าย หรือกด "+ สร้างใหม่"',
                                  style: const TextStyle(color: Colors.grey))),
                ),
              ]);
            }),
    );
  }
}
