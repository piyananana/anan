import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../models/ar_year_end.dart';
import '../services/ar_year_end_service.dart';

class ArFxRevaluationScreen extends StatefulWidget {
  const ArFxRevaluationScreen({super.key});

  @override
  State<ArFxRevaluationScreen> createState() => _ArFxRevaluationScreenState();
}

class _ArFxRevaluationScreenState extends State<ArFxRevaluationScreen>
    with AutomaticKeepAliveClientMixin {
  final ArYearEndService _svc     = ArYearEndService();
  final _fmt     = NumberFormat('#,##0.00', 'en_US');
  final _rateFmt = NumberFormat('#,##0.000000', 'en_US');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  List<ArFxRevaluationHeader> _rows = [];
  bool _isLoading = true;

  ArFxRevaluationHeader?      _selectedRow;
  List<ArFxRevaluationDetail> _details = [];
  bool _isDetailLoading = false;

  // Panel state — matches ar_gl_account_setup_screen pattern
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

  // Outstanding currencies (loaded on demand by reval_date)
  List<Map<String, dynamic>> _outstandingCurrencies = [];
  bool _isFetchingCurrencies = false;
  final Map<int, TextEditingController> _rateCtrl = {};

  // Preview state
  List<Map<String, dynamic>> _previewDetails = [];
  double _previewTotal = 0;
  bool   _isPreviewing = false;
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
      _rows = await _svc.fetchRevaluations();
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
          _revalDate.toIso8601String().substring(0, 10));
      // dispose controllers for currencies no longer in list
      final newIds = list.map((c) => c['currency_id'] as int).toSet();
      _rateCtrl.removeWhere((id, ctrl) {
        if (!newIds.contains(id)) { ctrl.dispose(); return true; }
        return false;
      });
      // create controllers for new currencies (keep existing values)
      for (final c in list) {
        _rateCtrl[c['currency_id'] as int] ??= TextEditingController();
      }
      setState(() { _outstandingCurrencies = list; _isFetchingCurrencies = false; });
    } catch (e) {
      setState(() => _isFetchingCurrencies = false);
      if (mounted) _showError(e.toString());
    }
  }

  Future<void> _selectRow(ArFxRevaluationHeader row) async {
    setState(() { _selectedRow = row; _isDetailLoading = true; _isCreating = false; });
    try {
      final data = await _svc.fetchRevaluationDetail(row.id);
      final dtlList = (data['details'] as List)
          .map((e) => ArFxRevaluationDetail.fromJson(e as Map<String, dynamic>)).toList();
      setState(() { _details = dtlList; _isDetailLoading = false; });
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
    final rates = _buildRates();
    if (rates.isEmpty) { _showError('กรุณาใส่อัตราแลกเปลี่ยน ณ สิ้นปีอย่างน้อย 1 สกุล'); return; }
    setState(() => _isPreviewing = true);
    try {
      final data = await _svc.previewReval(
        revalDate: _revalDate.toIso8601String().substring(0, 10),
        yearEndRates: rates,
      );
      setState(() {
        _previewDetails = List<Map<String, dynamic>>.from(data['details'] ?? []);
        _previewTotal   = double.tryParse(data['total_fx_gain_loss'].toString()) ?? 0;
      });
    } catch (e) { _showError(e.toString()); }
    finally { setState(() => _isPreviewing = false); }
  }

  Future<void> _save() async {
    final rates = _buildRates();
    if (rates.isEmpty) { _showError('กรุณาใส่อัตราแลกเปลี่ยน ณ สิ้นปีอย่างน้อย 1 สกุล'); return; }
    setState(() => _isPreviewing = true);
    try {
      final id = await _svc.createReval(
        revalDate:    _revalDate.toIso8601String().substring(0, 10),
        periodYear:   _periodYear,
        method:       _method,
        reversalDate: _method == 'reversing'
            ? _reversalDate?.toIso8601String().substring(0, 10) : null,
        note:         _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        yearEndRates: rates,
      );
      await _loadAll();
      final newRow = _rows.firstWhere((r) => r.id == id);
      await _selectRow(newRow);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึก Draft สำเร็จ'), backgroundColor: Colors.teal));
    } catch (e) { _showError(e.toString()); }
    finally { setState(() => _isPreviewing = false); }
  }

  Future<void> _deleteDraft(int id) async {
    final ok = await _confirm('ลบ Draft รายการนี้?');
    if (!ok) return;
    try {
      await _svc.deleteReval(id);
      setState(() { _selectedRow = null; _isCreating = false; _details = []; });
      await _loadAll();
    } catch (e) { _showError(e.toString()); }
  }

  Future<void> _post(int id) async {
    final ok = await _confirm('Post รายการนี้และสร้าง GL entry?');
    if (!ok) return;
    try {
      await _svc.postReval(id);
      await _loadAll();
      final row = _rows.firstWhere((r) => r.id == id);
      await _selectRow(row);
    } catch (e) { _showError(e.toString()); }
  }

  Future<void> _void(int id) async {
    final ok = await _confirm('ยกเลิกรายการนี้? GL entry จะถูก reverse');
    if (!ok) return;
    try {
      await _svc.voidReval(id);
      await _loadAll();
      final row = _rows.firstWhere((r) => r.id == id);
      await _selectRow(row);
    } catch (e) { _showError(e.toString()); }
  }

  Future<bool> _confirm(String msg) async => await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('ยืนยัน'),
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: Colors.teal),
          child: const Text('ยืนยัน'),
        ),
      ],
    ),
  ) ?? false;

  void _showError(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  Color _statusColor(String s) =>
      s == 'Posted' ? Colors.teal : s == 'Void' ? Colors.red : Colors.orange;

  // ── Left panel ────────────────────────────────────────────────────────────

  Widget _buildLeftPanel() => Column(children: [
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      color: Colors.teal[50],
      width: double.infinity,
      child: FilledButton.icon(
        icon: const Icon(Icons.add, size: 16),
        label: const Text('สร้างใหม่'),
        style: FilledButton.styleFrom(backgroundColor: Colors.teal),
        onPressed: () {
          setState(() { _isCreating = true; _selectedRow = null; });
          _loadOutstandingCurrencies();
        },
      ),
    ),
    Expanded(
      child: _rows.isEmpty
          ? const Center(child: Text('ไม่มีรายการ', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              itemCount: _rows.length,
              itemBuilder: (ctx, i) {
                final r = _rows[i];
                final selected = _selectedRow?.id == r.id;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: selected ? Colors.teal[50] : null,
                  shape: selected
                      ? RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.teal.shade400, width: 1.5))
                      : null,
                  child: ListTile(
                    dense: true,
                    onTap: () => _selectRow(r),
                    title: Text(_dateFmt.format(r.revalDate),
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13,
                            color: selected ? Colors.teal[800] : null)),
                    subtitle: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _statusColor(r.status).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(r.status,
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
                          color: r.totalFxGainLoss >= 0 ? Colors.teal : Colors.red,
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

  // ── Create form ───────────────────────────────────────────────────────────

  Widget _buildCreateForm() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Card 1: ข้อมูลทั่วไป ────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('สร้างรายการปรับมูลค่าหนี้จากอัตราแลกเปลี่ยน',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.teal)),
                  const Divider(height: 20),
                  Wrap(spacing: 32, runSpacing: 12, children: [
                    _labelField('ปีบัญชี', SizedBox(
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
                    _labelField('วันที่ปรับมูลค่า', InkWell(
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
                    _labelField('วิธีปรับมูลค่า', Row(mainAxisSize: MainAxisSize.min, children: [
                      Radio<String>(value: 'realized', groupValue: _method,
                          onChanged: (v) => setState(() => _method = v!),
                          activeColor: Colors.teal, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      const Text('Realized', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 12),
                      Radio<String>(value: 'reversing', groupValue: _method,
                          onChanged: (v) => setState(() => _method = v!),
                          activeColor: Colors.teal, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      const Text('Reversing', style: TextStyle(fontSize: 14)),
                    ])),
                    if (_method == 'reversing')
                      _labelField('วันกลับรายการ', InkWell(
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

            // ── Card 2: อัตราแลกเปลี่ยน ──────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Text('อัตราแลกเปลี่ยน ณ วันที่  ',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(_dateFmt.format(_revalDate),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal[700])),
                    if (_isFetchingCurrencies) ...[
                      const SizedBox(width: 12),
                      const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal)),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text('แสดงเฉพาะสกุลเงินที่มีใบแจ้งหนี้ค้างชำระ ณ วันที่ดังกล่าว',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const Divider(height: 20),
                  if (_isFetchingCurrencies)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(child: CircularProgressIndicator(color: Colors.teal)),
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
                        Text('ไม่พบใบแจ้งหนี้สกุลเงินต่างประเทศค้างชำระ ณ วันที่นี้',
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

            // ── Card 3: หมายเหตุ ─────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('หมายเหตุ',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        hintText: 'ระบุหมายเหตุ (ถ้ามี)'),
                    style: const TextStyle(fontSize: 14),
                    maxLines: 2,
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // ── ปุ่มดำเนินการ ────────────────────────────────────────────
            Row(children: [
              OutlinedButton.icon(
                icon: _isPreviewing
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.preview, size: 16),
                label: const Text('คำนวณ Preview'),
                onPressed: (_isPreviewing || _isFetchingCurrencies || _outstandingCurrencies.isEmpty)
                    ? null : _preview,
              ),
              const SizedBox(width: 12),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                onPressed: (_isPreviewing || _isFetchingCurrencies || _outstandingCurrencies.isEmpty)
                    ? null : _save,
                child: const Text('บันทึก Draft'),
              ),
            ]),

      // Preview table inside SingleChildScrollView with SizedBox to bound its height
      if (_previewDetails.isNotEmpty) ...[
        const SizedBox(height: 16),
        SizedBox(height: 360, child: _buildPreviewTable()),
      ],
    ]),
  );

  Widget _currencyRateField(Map<String, dynamic> c) => SizedBox(
    width: 220,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      RichText(text: TextSpan(children: [
        TextSpan(text: c['currency_code']?.toString() ?? '',
            style: const TextStyle(fontWeight: FontWeight.bold,
                fontSize: 14, color: Colors.black87)),
        TextSpan(text: '  ${c['currency_name_th'] ?? ''}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ])),
      const SizedBox(height: 4),
      TextFormField(
        controller: _rateCtrl[c['currency_id'] as int],
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          suffixText: 'THB',
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
  // Called inside SizedBox(height:420) so it always has bounded height.

  Widget _buildPreviewTable() {
    final table = DataTable(
      headingRowColor: WidgetStateProperty.all(Colors.teal[50]),
      columnSpacing: 16,
      dataRowMinHeight: 36,
      dataRowMaxHeight: 48,
      columns: const [
        DataColumn(label: Text('รหัสลูกหนี้')),
        DataColumn(label: Text('ชื่อลูกหนี้')),
        DataColumn(label: Text('ใบแจ้งหนี้')),
        DataColumn(label: Text('อ้างอิง')),
        DataColumn(label: Text('สกุลเงิน')),
        DataColumn(label: Text('ยอดค้าง FC'),   numeric: true),
        DataColumn(label: Text('Rate เดิม'),     numeric: true),
        DataColumn(label: Text('ยอดก่อน THB'),  numeric: true),
        DataColumn(label: Text('Rate ใหม่'),     numeric: true),
        DataColumn(label: Text('ยอดหลัง THB'),  numeric: true),
        DataColumn(label: Text('FX G/L'),        numeric: true),
      ],
      rows: [
        ..._previewDetails.map((d) {
          final gl = double.tryParse(d['fx_gain_loss'].toString()) ?? 0;
          return DataRow(cells: [
            DataCell(Text(d['customer_code']?.toString() ?? '',
                style: const TextStyle(fontSize: 12))),
            DataCell(SizedBox(
              width: 160,
              child: Text(d['customer_name_th']?.toString() ?? '',
                  style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
            )),
            DataCell(Text(d['doc_no']?.toString() ?? '',
                style: const TextStyle(fontSize: 12))),
            DataCell(Text(d['ref_doc_no']?.toString() ?? '',
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
                  color: gl >= 0 ? Colors.teal : Colors.red,
                  fontWeight: FontWeight.bold),
            )),
          ]);
        }),
        DataRow(
          color: WidgetStateProperty.all(Colors.teal[50]),
          cells: [
            const DataCell(Text('รวม', style: TextStyle(fontWeight: FontWeight.bold))),
            const DataCell(SizedBox()), const DataCell(SizedBox()),
            const DataCell(SizedBox()), const DataCell(SizedBox()),
            const DataCell(SizedBox()), const DataCell(SizedBox()),
            const DataCell(SizedBox()), const DataCell(SizedBox()),
            const DataCell(SizedBox()),
            DataCell(Text(
              (_previewTotal >= 0 ? '+' : '') + _fmt.format(_previewTotal),
              style: TextStyle(fontWeight: FontWeight.bold,
                  color: _previewTotal >= 0 ? Colors.teal : Colors.red),
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
            const Text('ผลการคำนวณ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(width: 12),
            Text('${_previewDetails.length} รายการ',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ]),
        ),
        const Divider(height: 1),
        // Expanded fills the remaining bounded height given by SizedBox(height:420) parent.
        // RawScrollbar with trackVisibility keeps scrollbars always visible.
        Expanded(
          child: RawScrollbar(
            controller: _previewVertCtrl,
            thumbVisibility: true,
            trackVisibility: true,
            thickness: 8,
            radius: const Radius.circular(4),
            // depth 0 = notifications from the direct vertical SingleChildScrollView
            notificationPredicate: (n) => n.depth == 0,
            child: SingleChildScrollView(
              controller: _previewVertCtrl,
              child: RawScrollbar(
                controller: _previewHorizCtrl,
                thumbVisibility: true,
                trackVisibility: true,
                thickness: 8,
                radius: const Radius.circular(4),
                // depth 0 = notifications from the direct horizontal SingleChildScrollView
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

  Widget _buildDetail(ArFxRevaluationHeader row) => Column(children: [
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.grey[50],
      child: Row(children: [
        _infoChip('วันที่', _dateFmt.format(row.revalDate)),
        const SizedBox(width: 24),
        _infoChip('ปีบัญชี', row.periodYear.toString()),
        const SizedBox(width: 24),
        _infoChip('วิธี', row.method == 'reversing' ? 'Reversing' : 'Realized'),
        const SizedBox(width: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _statusColor(row.status).withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(row.status,
              style: TextStyle(color: _statusColor(row.status),
                  fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        const Spacer(),
        if (row.status == 'Draft') ...[
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () => _post(row.id),
            child: const Text('Post'),
          ),
          const SizedBox(width: 8),
        ],
        if (row.status == 'Posted')
          OutlinedButton(
            onPressed: () => _void(row.id),
            style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red)),
            child: const Text('Void'),
          ),
      ]),
    ),
    if (row.glDocNo != null)
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: Colors.teal[50],
        child: Row(children: [
          Text('GL Entry: ${row.glDocNo}',
              style: const TextStyle(fontSize: 13, color: Colors.teal)),
          if (row.reversalDocNo != null) ...[
            const SizedBox(width: 16),
            Text('Reversing: ${row.reversalDocNo}',
                style: TextStyle(fontSize: 13, color: Colors.teal[700])),
          ],
        ]),
      ),
    Expanded(
      child: _isDetailLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
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
                child: RawScrollbar(
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
                      headingRowColor: WidgetStateProperty.all(Colors.teal[50]),
                      columnSpacing: 16,
                      columns: const [
                        DataColumn(label: Text('รหัสลูกหนี้')),
                        DataColumn(label: Text('ชื่อลูกหนี้')),
                        DataColumn(label: Text('ใบแจ้งหนี้')),
                        DataColumn(label: Text('สกุลเงิน')),
                        DataColumn(label: Text('ยอดค้าง FC'),    numeric: true),
                        DataColumn(label: Text('Rate เดิม'),      numeric: true),
                        DataColumn(label: Text('ยอดก่อน THB'),   numeric: true),
                        DataColumn(label: Text('Rate ใหม่'),      numeric: true),
                        DataColumn(label: Text('ยอดหลัง THB'),   numeric: true),
                        DataColumn(label: Text('FX G/L'),         numeric: true),
                      ],
                      rows: [
                        ..._details.map((d) {
                          final gl = d.fxGainLoss;
                          return DataRow(cells: [
                            DataCell(Text(d.customerCode ?? '',
                                style: const TextStyle(fontSize: 12))),
                            DataCell(SizedBox(
                              width: 160,
                              child: Text(d.customerNameTh ?? '',
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
                                  color: gl >= 0 ? Colors.teal : Colors.red,
                                  fontWeight: FontWeight.bold),
                            )),
                          ]);
                        }),
                        DataRow(
                          color: WidgetStateProperty.all(Colors.teal[50]),
                          cells: [
                            const DataCell(Text('รวม',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                            const DataCell(SizedBox()), const DataCell(SizedBox()),
                            const DataCell(SizedBox()), const DataCell(SizedBox()),
                            const DataCell(SizedBox()), const DataCell(SizedBox()),
                            const DataCell(SizedBox()), const DataCell(SizedBox()),
                            DataCell(Text(
                              (row.totalFxGainLoss >= 0 ? '+' : '') +
                                  _fmt.format(row.totalFxGainLoss),
                              style: TextStyle(fontWeight: FontWeight.bold,
                                  color: row.totalFxGainLoss >= 0
                                      ? Colors.teal : Colors.red),
                            )),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    ),
  ]);

  Widget _infoChip(String label, String value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        Text(value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ]);

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : LayoutBuilder(builder: (ctx, constraints) {
              final maxLeft =
                  (constraints.maxWidth - 36 - 5 - 400).clamp(100.0, double.infinity);
              return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Collapse/expand toggle — 36px teal strip on far left
                Container(
                  width: 36,
                  color: Colors.teal,
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
                    tooltip: _isLeftPanelExpanded ? 'ย่อรายการ' : 'ขยายรายการ',
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
                          : const Center(
                              child: Text(
                                  'เลือกรายการทางซ้าย หรือกด "+ สร้างใหม่"',
                                  style: TextStyle(color: Colors.grey))),
                ),
              ]);
            }),
    );
  }
}
