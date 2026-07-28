import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import 'package:provider/provider.dart';
import '../models/ar_year_end.dart';
import '../services/ar_year_end_service.dart';

class ArAllowanceRunScreen extends StatefulWidget {
  const ArAllowanceRunScreen({super.key});

  @override
  State<ArAllowanceRunScreen> createState() => _ArAllowanceRunScreenState();
}

class _ArAllowanceRunScreenState extends State<ArAllowanceRunScreen>
    with AutomaticKeepAliveClientMixin {
  final ArYearEndService _svc    = ArYearEndService();
  final _fmt     = NumberFormat('#,##0.00', 'en_US');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  bool _isEnglish = false;

  List<ArAllowanceRunHeader> _rows    = [];
  bool _isLoading = true;

  ArAllowanceRunHeader?      _selectedRow;
  List<ArAllowanceRunDetail> _details = [];
  bool _isDetailLoading = false;

  // Panel state — matches ar_fx_revaluation_screen pattern
  bool   _isLeftPanelExpanded = true;
  bool   _isDraggingDivider   = false;
  double _leftPanelWidth      = 280.0;

  // Form state
  bool     _isCreating = false;
  DateTime _runDate    = DateTime(DateTime.now().year, 12, 31);
  int      _periodYear = DateTime.now().year;
  final    _noteCtrl   = TextEditingController();

  // Preview state
  List<Map<String, dynamic>> _previewDetails = [];
  double _previewTotal = 0, _previewPrior = 0, _previewAdj = 0;
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
      final rows = await _svc.fetchAllowanceRuns();
      setState(() { _rows = rows; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) _showError(e.toString());
    }
  }

  Future<void> _selectRow(ArAllowanceRunHeader row) async {
    setState(() { _selectedRow = row; _isDetailLoading = true; _isCreating = false; });
    try {
      final data = await _svc.fetchAllowanceRunDetail(row.id);
      final dtl  = (data['details'] as List)
          .map((e) => ArAllowanceRunDetail.fromJson(e as Map<String, dynamic>)).toList();
      setState(() { _details = dtl; _isDetailLoading = false; });
    } catch (e) {
      setState(() => _isDetailLoading = false);
      if (mounted) _showError(e.toString());
    }
  }

  Future<void> _preview() async {
    setState(() => _isPreviewing = true);
    try {
      final data = await _svc.previewAllowanceRun(_runDate.toIso8601String().substring(0, 10));
      setState(() {
        _previewDetails = List<Map<String, dynamic>>.from(data['details'] ?? []);
        _previewTotal   = double.tryParse(data['total_allowance'].toString())   ?? 0;
        _previewPrior   = double.tryParse(data['prior_allowance'].toString())   ?? 0;
        _previewAdj     = double.tryParse(data['adjustment_amount'].toString()) ?? 0;
      });
    } catch (e) { if (mounted) _showError(e.toString()); }
    finally { setState(() => _isPreviewing = false); }
  }

  Future<void> _save() async {
    final isEnglish = _isEnglish;
    setState(() => _isPreviewing = true);
    try {
      final id = await _svc.createAllowanceRun(
        runDate:    _runDate.toIso8601String().substring(0, 10),
        periodYear: _periodYear,
        note:       _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      await _loadAll();
      final newRow = _rows.firstWhere((r) => r.id == id);
      await _selectRow(newRow);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEnglish ? 'Draft saved successfully' : 'บันทึก Draft สำเร็จ'), backgroundColor: Colors.teal));
    } catch (e) { if (mounted) _showError(e.toString()); }
    finally { setState(() => _isPreviewing = false); }
  }

  Future<void> _deleteDraft(int id) async {
    final isEnglish = _isEnglish;
    if (!(MenuScope.of(context)?.canDelete ?? true)) return;
    final ok = await _confirm(isEnglish ? 'Delete this Draft?' : 'ลบ Draft รายการนี้?');
    if (!ok) return;
    try {
      await _svc.deleteAllowanceRun(id);
      setState(() { _selectedRow = null; _isCreating = false; _details = []; });
      await _loadAll();
    } catch (e) { if (mounted) _showError(e.toString()); }
  }

  Future<void> _post(int id) async {
    final isEnglish = _isEnglish;
    if (!(MenuScope.of(context)?.canEdit ?? true)) return;
    if (!await _confirm(isEnglish ? 'Post this entry and create a GL entry?' : 'Post รายการนี้และสร้าง GL entry?')) return;
    try {
      await _svc.postAllowanceRun(id);
      await _loadAll();
      await _selectRow(_rows.firstWhere((r) => r.id == id));
    } catch (e) { if (mounted) _showError(e.toString()); }
  }

  Future<void> _void(int id) async {
    final isEnglish = _isEnglish;
    if (!(MenuScope.of(context)?.canDelete ?? true)) return;
    if (!await _confirm(isEnglish ? 'Void this entry? The GL entry will be reversed' : 'ยกเลิกรายการนี้? GL entry จะถูก reverse')) return;
    try {
      await _svc.voidAllowanceRun(id);
      await _loadAll();
      await _selectRow(_rows.firstWhere((r) => r.id == id));
    } catch (e) { if (mounted) _showError(e.toString()); }
  }

  Future<bool> _confirm(String msg) async {
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.isEnglish ? 'Confirm' : 'ยืนยัน'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.teal),
            child: Text(l.confirm),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showError(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  Color _statusColor(String s) =>
      s == 'Posted' ? Colors.teal : s == 'Void' ? Colors.red : Colors.orange;

  String _customerNameOf(Map<String, dynamic> d) {
    final en = d['customer_name_en']?.toString();
    if (_isEnglish && en != null && en.isNotEmpty) return en;
    return d['customer_name_th']?.toString() ?? '';
  }

  // ── Left panel ────────────────────────────────────────────────────────────

  Widget _buildLeftPanel() {
    final isEnglish = _isEnglish;
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        color: Colors.teal[50],
        width: double.infinity,
        child: FilledButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: Text(isEnglish ? 'New' : 'สร้างใหม่'),
          style: FilledButton.styleFrom(backgroundColor: Colors.teal),
          onPressed: () => setState(() {
            _isCreating = true;
            _selectedRow = null;
            _previewDetails = [];
          }),
        ),
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
                    color: selected ? Colors.teal[50] : null,
                    shape: selected
                        ? RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.teal.shade400, width: 1.5))
                        : null,
                    child: ListTile(
                      dense: true,
                      onTap: () => _selectRow(r),
                      title: Text(_dateFmt.format(r.runDate),
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
                        Text(
                          '${isEnglish ? 'Adj.' : 'ปรับ'} ${r.adjustmentAmount >= 0 ? '+' : ''}${_fmt.format(r.adjustmentAmount)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ]),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(_fmt.format(r.totalAllowance),
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold,
                                color: selected ? Colors.teal[800] : null)),
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

      // ── Card 1: ข้อมูลทั่วไป ──────────────────────────────────────────────
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isEnglish ? 'Calculate Allowance for Doubtful Accounts' : 'คำนวณค่าเผื่อหนี้สงสัยจะสูญ',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.teal)),
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
                          child: Text(y.toString(), style: const TextStyle(fontSize: 14)))).toList(),
                  onChanged: (v) => setState(() => _periodYear = v ?? _periodYear),
                ),
              )),
              _labelField(isEnglish ? 'Calculation Date' : 'วันที่คำนวณ', InkWell(
                onTap: () async {
                  final d = await showDatePicker(context: context,
                      initialDate: _runDate,
                      firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (d != null) setState(() => _runDate = d);
                },
                child: Container(
                  width: 150,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(4)),
                  child: Text(_dateFmt.format(_runDate), style: const TextStyle(fontSize: 14)),
                ),
              )),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 12),

      // ── Card 2: หมายเหตุ ──────────────────────────────────────────────────
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

      // ── ปุ่มดำเนินการ ────────────────────────────────────────────────────
      Row(children: [
        OutlinedButton.icon(
          icon: _isPreviewing
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.preview, size: 16),
          label: Text(isEnglish ? 'Calculate Preview' : 'คำนวณ Preview'),
          onPressed: _isPreviewing ? null : _preview,
        ),
        const SizedBox(width: 12),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.teal),
          onPressed: _isPreviewing ? null : _save,
          child: Text(isEnglish ? 'Save Draft' : 'บันทึก Draft'),
        ),
      ]),

      // Preview results — bounded height for proper scrollbars
      if (_previewDetails.isNotEmpty) ...[
        const SizedBox(height: 16),
        _buildPreviewSummary(),
        const SizedBox(height: 12),
        SizedBox(height: 360, child: _buildPreviewTable()),
      ],
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

  Widget _buildPreviewSummary() {
    final isEnglish = _isEnglish;
    return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.teal[50],
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.teal[200]!),
    ),
    child: Column(children: [
      _sumRow(isEnglish ? 'Required Allowance' : 'ยอดที่ควรเป็น', _previewTotal),
      _sumRow(isEnglish ? 'Existing Accumulated Balance' : 'ยอดสะสมที่มีอยู่แล้ว', _previewPrior),
      const Divider(),
      _sumRow(isEnglish ? 'Additional GL Entry Amount' : 'ยอดที่ต้องบันทึกเพิ่ม (GL)', _previewAdj, bold: true,
          color: _previewAdj >= 0 ? Colors.teal : Colors.red),
    ]),
  );
  }

  Widget _buildPreviewTable() {
    final isEnglish = _isEnglish;
    final table = DataTable(
      headingRowColor: WidgetStateProperty.all(Colors.teal[50]),
      columnSpacing: 14,
      dataRowMinHeight: 36,
      dataRowMaxHeight: 48,
      columns: [
        DataColumn(label: Text(isEnglish ? 'Customer Code' : 'รหัสลูกหนี้')),
        DataColumn(label: Text(isEnglish ? 'Customer Name' : 'ชื่อลูกหนี้')),
        DataColumn(label: Text(isEnglish ? 'Invoice' : 'ใบแจ้งหนี้')),
        DataColumn(label: Text(isEnglish ? 'Reference' : 'อ้างอิง')),
        DataColumn(label: Text(isEnglish ? 'Due Date' : 'ครบกำหนด')),
        DataColumn(label: Text(isEnglish ? 'Age (days)' : 'อายุ (วัน)'),  numeric: true),
        DataColumn(label: Text(isEnglish ? 'Balance' : 'ยอดค้าง'),     numeric: true),
        DataColumn(label: Text(isEnglish ? '% Reserve' : '% สำรอง'),     numeric: true),
        DataColumn(label: Text(isEnglish ? 'Reserve Amount' : 'ยอดสำรอง'),   numeric: true),
      ],
      rows: _previewDetails.map((d) => DataRow(cells: [
        DataCell(Text(d['customer_code']?.toString() ?? '',
            style: const TextStyle(fontSize: 12))),
        DataCell(SizedBox(
          width: 160,
          child: Text(_customerNameOf(d),
              style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
        )),
        DataCell(Text(d['doc_no']?.toString() ?? '',
            style: const TextStyle(fontSize: 12))),
        DataCell(Text(d['ref_doc_no']?.toString() ?? '',
            style: const TextStyle(fontSize: 12))),
        DataCell(Text(d['due_date'] != null
            ? _dateFmt.format(DateTime.parse(d['due_date'].toString().substring(0, 10)))
            : '-', style: const TextStyle(fontSize: 12))),
        DataCell(Text(d['age_days']?.toString() ?? '0',
            style: const TextStyle(fontSize: 12))),
        DataCell(Text(_fmt.format(d['balance_amount_lc']),
            style: const TextStyle(fontSize: 12))),
        DataCell(Text('${_fmt.format(d['rate'])}%',
            style: const TextStyle(fontSize: 12))),
        DataCell(Text(_fmt.format(d['allowance_amount']),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
      ])).toList(),
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

  Widget _buildDetail(ArAllowanceRunHeader row) {
    final isEnglish = _isEnglish;
    return Column(children: [
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.grey[50],
      child: Row(children: [
        _infoChip(isEnglish ? 'Date' : 'วันที่', _dateFmt.format(row.runDate)),
        const SizedBox(width: 24),
        _infoChip(isEnglish ? 'Fiscal Year' : 'ปีบัญชี', row.periodYear.toString()),
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
    // Summary bar
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.teal[50],
      child: Row(children: [
        _summaryCell(isEnglish ? 'Required Allowance' : 'ยอดที่ควรเป็น', row.totalAllowance),
        const SizedBox(width: 32),
        _summaryCell(isEnglish ? 'Prior Accumulated Balance' : 'ยอดสะสมเดิม', row.priorAllowance),
        const SizedBox(width: 32),
        _summaryCell(isEnglish ? 'GL Entry Amount' : 'บันทึก GL', row.adjustmentAmount,
            color: row.adjustmentAmount >= 0 ? Colors.teal : Colors.red),
        if (row.glDocNo != null) ...[
          const SizedBox(width: 32),
          Text('GL: ${row.glDocNo}',
              style: const TextStyle(fontSize: 13, color: Colors.teal)),
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
                      columnSpacing: 14,
                      columns: [
                        DataColumn(label: Text(isEnglish ? 'Customer Code' : 'รหัสลูกหนี้')),
                        DataColumn(label: Text(isEnglish ? 'Customer Name' : 'ชื่อลูกหนี้')),
                        DataColumn(label: Text(isEnglish ? 'Invoice' : 'ใบแจ้งหนี้')),
                        DataColumn(label: Text(isEnglish ? 'Reference' : 'อ้างอิง')),
                        DataColumn(label: Text(isEnglish ? 'Due Date' : 'ครบกำหนด')),
                        DataColumn(label: Text(isEnglish ? 'Age (days)' : 'อายุ (วัน)'),  numeric: true),
                        DataColumn(label: Text(isEnglish ? 'Balance' : 'ยอดค้าง'),     numeric: true),
                        DataColumn(label: Text(isEnglish ? '% Reserve' : '% สำรอง'),     numeric: true),
                        DataColumn(label: Text(isEnglish ? 'Reserve Amount' : 'ยอดสำรอง'),   numeric: true),
                      ],
                      rows: [
                        ..._details.map((d) => DataRow(cells: [
                          DataCell(Text(d.customerCode ?? '',
                              style: const TextStyle(fontSize: 12))),
                          DataCell(SizedBox(
                            width: 160,
                            child: Text(
                                isEnglish && (d.customerNameEn ?? '').isNotEmpty
                                    ? d.customerNameEn!
                                    : (d.customerNameTh ?? ''),
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis),
                          )),
                          DataCell(Text(d.docNo ?? '',
                              style: const TextStyle(fontSize: 12))),
                          DataCell(Text(d.refDocNo ?? '',
                              style: const TextStyle(fontSize: 12))),
                          DataCell(Text(d.dueDate != null
                              ? _dateFmt.format(d.dueDate!) : '-',
                              style: const TextStyle(fontSize: 12))),
                          DataCell(Text(d.ageDays.toString(),
                              style: const TextStyle(fontSize: 12))),
                          DataCell(Text(_fmt.format(d.balanceAmountLc),
                              style: const TextStyle(fontSize: 12))),
                          DataCell(Text('${_fmt.format(d.rate)}%',
                              style: const TextStyle(fontSize: 12))),
                          DataCell(Text(_fmt.format(d.allowanceAmount),
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold))),
                        ])),
                        DataRow(
                          color: WidgetStateProperty.all(Colors.teal[50]),
                          cells: [
                            DataCell(Text(isEnglish ? 'Total' : 'รวม',
                                style: const TextStyle(fontWeight: FontWeight.bold))),
                            const DataCell(SizedBox()), const DataCell(SizedBox()),
                            const DataCell(SizedBox()), const DataCell(SizedBox()),
                            const DataCell(SizedBox()), const DataCell(SizedBox()),
                            const DataCell(SizedBox()),
                            DataCell(Text(_fmt.format(row.totalAllowance),
                                style: TextStyle(fontWeight: FontWeight.bold,
                                    color: Colors.teal[800]))),
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
  }

  Widget _sumRow(String label, double v, {bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Expanded(child: Text(label,
          style: TextStyle(fontSize: 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
      Text(_fmt.format(v),
          style: TextStyle(fontSize: 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color)),
    ]),
  );

  Widget _summaryCell(String label, double v, {Color? color}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        Text(_fmt.format(v),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                color: color ?? Colors.black87)),
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
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
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
