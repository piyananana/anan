import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../sa/utils/sa_menu_scope.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/cm_bank_account.dart';
import '../models/cm_checkbook.dart';
import '../models/cm_payment.dart';
import '../models/cm_receipt.dart';
import '../services/cm_bank_account_service.dart';
import '../services/cm_checkbook_service.dart';
import '../services/cm_payment_service.dart';
import '../services/cm_period_service.dart';
import '../../utils/date_utils.dart';

class CmPaymentScreen extends StatefulWidget {
  const CmPaymentScreen({super.key});

  @override
  State<CmPaymentScreen> createState() => _CmPaymentScreenState();
}

class _CmPaymentScreenState extends State<CmPaymentScreen>
    with AutomaticKeepAliveClientMixin {

  static const _kColor = Color(0xFF1565C0);

  final CmBankAccountService _acctSvc    = CmBankAccountService();
  final CmCheckbookService   _cbSvc      = CmCheckbookService();
  final CmPaymentService     _svc        = CmPaymentService();
  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _amtFmt  = NumberFormat('#,##0.00');

  // Left panel
  List<CmBankAccount> _bankAccounts = [];
  CmBankAccount?      _selectedBank;
  bool _isLeftExpanded = true;
  double _leftWidth    = 280.0;
  bool _isDragging     = false;

  // Filter
  String  _statusFilter = 'All';
  String? _dateFrom;
  String? _dateTo;

  // List
  List<CmPayment> _payments = [];
  bool _loading = false;

  // Selected / Creating
  CmPayment? _selected;
  bool _showCreateForm = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadBankAccounts();
  }

  Future<void> _loadBankAccounts() async {
    try {
      final list = await _acctSvc.fetchRows();
      setState(() => _bankAccounts = list..sort((a, b) => a.accountCode.compareTo(b.accountCode)));
    } catch (e) { _showErr(e.toString()); }
  }

  void _selectBank(CmBankAccount b) {
    setState(() { _selectedBank = b; _payments = []; _selected = null; _showCreateForm = false; });
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    if (_selectedBank == null) return;
    setState(() => _loading = true);
    try {
      final list = await _svc.fetchPayments(
        bankAccountId: _selectedBank!.id,
        status:    _statusFilter == 'All' ? null : _statusFilter,
        dateFrom:  _dateFrom,
        dateTo:    _dateTo,
      );
      setState(() { _payments = list; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      _showErr(e.toString());
    }
  }

  void _showErr(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showOk(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: _kColor));
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _clear(CmPayment p) async {
    final result = await _showClearDialog();
    if (result == null) return;
    try {
      await _svc.clearPayment(p.id!, clearingDate: result['date'], clearingNote: result['note']);
      _showOk('เคลียร์สำเร็จ');
      await _loadPayments();
      setState(() => _selected = null);
    } catch (e) { _showErr(e.toString()); }
  }

  Future<void> _void(CmPayment p) async {
    if (!(MenuScope.of(context)?.canDelete ?? true)) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยัน Void'),
        content: Text('ยืนยันการ Void รายการจ่ายเงิน ${p.apDocNo ?? p.id} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Void', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
    if (!ok) return;
    try {
      await _svc.voidPayment(p.id!);
      _showOk('Void สำเร็จ');
      await _loadPayments();
      setState(() => _selected = null);
    } catch (e) { _showErr(e.toString()); }
  }

  Future<Map<String, String>?> _showClearDialog() async {
    final noteCtrl = TextEditingController();
    DateTime clearDate = DateTime.now();
    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('เคลียร์รายการจ่ายเงิน'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            InkWell(
              onTap: () async {
                final d = await showDatePicker(context: ctx, initialDate: clearDate,
                    firstDate: DateTime(2000), lastDate: DateTime(2100));
                if (d != null) setDlg(() => clearDate = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'วันที่เคลียร์', border: OutlineInputBorder(), isDense: true),
                child: Text(_dateFmt.format(clearDate)),
              ),
            ),
            const SizedBox(height: 8),
            TextField(controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'หมายเหตุ', border: OutlineInputBorder(), isDense: true)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _kColor),
              onPressed: () => Navigator.pop(ctx, {
                'date': formatLocalDate(clearDate),
                'note': noteCtrl.text.trim(),
              }),
              child: const Text('ยืนยัน'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Check Print PDF ───────────────────────────────────────────────────────

  Future<void> _printCheck(CmPayment p) async {
    // Fetch print config for this bank account
    List<CmCheckPrintConfig> configs = [];
    try {
      configs = await _cbSvc.fetchPrintConfigs(bankAccountId: p.bankAccountId);
    } catch (_) {}

    CmCheckPrintConfig? cfg = configs.firstWhere((c) => c.isDefault, orElse: () => configs.isEmpty
        ? const CmCheckPrintConfig(bankAccountId: 0, configName: 'Default')
        : configs.first);

    final pdf = pw.Document();
    final amtText = _thaiAmountText(p.amountLc);
    final amtNum  = _amtFmt.format(p.amountLc);
    final checkDateStr = p.checkDate != null ? _dateFmt.format(p.checkDate!) : _dateFmt.format(p.paymentDate);
    final payeeName = p.payeeNameTh ?? '';

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat(cfg.paperWidthMm * PdfPageFormat.mm, cfg.paperHeightMm * PdfPageFormat.mm),
      margin: pw.EdgeInsets.zero,
      build: (pw.Context ctx) {
        return pw.Stack(children: [
          // Date
          pw.Positioned(
            left: (cfg.dateX ?? 150) * PdfPageFormat.mm,
            top: (cfg.dateY ?? 18) * PdfPageFormat.mm,
            child: pw.Text(checkDateStr, style: const pw.TextStyle(fontSize: 11)),
          ),
          // Payee
          pw.Positioned(
            left: (cfg.payeeX ?? 35) * PdfPageFormat.mm,
            top: (cfg.payeeY ?? 38) * PdfPageFormat.mm,
            child: pw.Text(payeeName, style: const pw.TextStyle(fontSize: 11)),
          ),
          // Amount numeric
          pw.Positioned(
            left: (cfg.amountNumX ?? 155) * PdfPageFormat.mm,
            top: (cfg.amountNumY ?? 38) * PdfPageFormat.mm,
            child: pw.Text(amtNum, style: const pw.TextStyle(fontSize: 11)),
          ),
          // Amount text
          pw.Positioned(
            left: (cfg.amountTextX ?? 20) * PdfPageFormat.mm,
            top: (cfg.amountTextY ?? 55) * PdfPageFormat.mm,
            child: pw.Text(amtText, style: const pw.TextStyle(fontSize: 11)),
          ),
        ]);
      },
    ));

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  String _thaiAmountText(double amount) {
    // Basic baht/satang text
    final baht   = amount.truncate();
    final satang = ((amount - baht) * 100).round();
    return 'จำนวนเงิน ${NumberFormat('#,##0').format(baht)} บาท'
        '${satang > 0 ? ' ${satang.toString().padLeft(2, '0')} สตางค์' : 'ถ้วน'}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: _kColor,
        foregroundColor: Colors.white,
        actions: [
          if (_selectedBank != null)
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPayments, tooltip: 'โหลดใหม่'),
        ],
      ),
      body: LayoutBuilder(builder: (ctx, constraints) {
        final maxLeft = (constraints.maxWidth - 36 - 5 - 380).clamp(100.0, double.infinity);
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            width: 36, color: _kColor,
            child: IconButton(
              icon: Icon(_isLeftExpanded ? Icons.filter_list_off : Icons.filter_list, color: Colors.white, size: 20),
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _isLeftExpanded = !_isLeftExpanded),
            ),
          ),
          AnimatedContainer(
            duration: _isDragging ? Duration.zero : const Duration(milliseconds: 200),
            width: _isLeftExpanded ? _leftWidth : 0,
            child: ClipRect(
              child: OverflowBox(
                maxWidth: _leftWidth, minWidth: _leftWidth,
                alignment: Alignment.topLeft,
                child: ColoredBox(color: Colors.blueGrey.shade100, child: _buildBankList()),
              ),
            ),
          ),
          if (_isLeftExpanded)
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
          Expanded(child: _selectedBank == null
              ? const Center(child: Text('เลือกบัญชีธนาคารทางซ้าย', style: TextStyle(color: Colors.grey)))
              : _buildMainPanel()),
        ]);
      }),
    );
  }

  Widget _buildBankList() => Column(children: [
    Container(
      padding: const EdgeInsets.all(8), color: Colors.blueGrey.shade200,
      child: const Row(children: [
        Icon(Icons.account_balance, size: 16, color: Colors.black54), SizedBox(width: 6),
        Text('บัญชีธนาคาร', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
    ),
    Expanded(
      child: _bankAccounts.isEmpty
          ? const Center(child: Text('ไม่พบบัญชี', style: TextStyle(color: Colors.grey, fontSize: 12)))
          : ListView.builder(
              itemCount: _bankAccounts.length,
              itemBuilder: (_, i) {
                final b = _bankAccounts[i];
                final sel = _selectedBank?.id == b.id;
                return ListTile(
                  dense: true, selected: sel,
                  selectedTileColor: const Color(0xFFE3F2FD),
                  leading: CircleAvatar(radius: 14,
                    backgroundColor: sel ? _kColor : Colors.blueGrey.shade300,
                    child: Text(b.accountCode.substring(0, 1),
                        style: const TextStyle(color: Colors.white, fontSize: 11))),
                  title: Text(b.accountCode,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: sel ? _kColor : null)),
                  subtitle: Text(b.accountNameTh, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                  onTap: () => _selectBank(b),
                );
              },
            ),
    ),
  ]);

  Widget _buildMainPanel() => Column(children: [
    _buildFilterBar(),
    const Divider(height: 1),
    Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _buildList()),
      if (_showCreateForm || _selected != null) ...[
        const VerticalDivider(width: 1),
        SizedBox(width: 400,
          child: _showCreateForm
              ? _CreatePaymentForm(
                  bankAccount: _selectedBank!,
                  checkbookSvc: _cbSvc,
                  kColor: _kColor,
                  onSave: (p) async {
                    try {
                      await _svc.createPayment(p);
                      _showOk('บันทึกสำเร็จ');
                      setState(() => _showCreateForm = false);
                      await _loadPayments();
                    } catch (e) { _showErr(e.toString()); }
                  },
                  onCancel: () => setState(() => _showCreateForm = false),
                )
              : _buildDetail(_selected!),
        ),
      ],
    ])),
  ]);

  Widget _buildFilterBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    color: Colors.grey.shade50,
    child: Row(children: [
      SizedBox(width: 140,
        child: DropdownButtonFormField<String>(
          value: _statusFilter,
          decoration: const InputDecoration(labelText: 'สถานะ', border: OutlineInputBorder(), isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
          items: [
            const DropdownMenuItem(value: 'All', child: Text('ทั้งหมด')),
            ...cmPaymentStatusOptions.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
          ],
          onChanged: (v) => setState(() { _statusFilter = v!; _loadPayments(); }),
        ),
      ),
      const SizedBox(width: 8),
      _dateField('จากวันที่', _dateFrom, (d) => setState(() { _dateFrom = d; _loadPayments(); })),
      const SizedBox(width: 8),
      _dateField('ถึงวันที่', _dateTo, (d) => setState(() { _dateTo = d; _loadPayments(); })),
      const Spacer(),
      Text('${_payments.length} รายการ', style: const TextStyle(color: Colors.grey, fontSize: 12)),
      const SizedBox(width: 12),
      if (MenuScope.of(context)?.canCreate ?? true)
        FilledButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('สร้างรายการจ่าย'),
          style: FilledButton.styleFrom(backgroundColor: _kColor),
          onPressed: () => setState(() { _showCreateForm = true; _selected = null; }),
        ),
    ]),
  );

  Widget _dateField(String label, String? value, void Function(String?) onChanged) =>
    InkWell(
      onTap: () async {
        final d = await showDatePicker(context: context,
            initialDate: value != null ? parseLocalDate(value) : DateTime.now(),
            firstDate: DateTime(2000), lastDate: DateTime(2100));
        onChanged(d != null ? formatLocalDate(d) : null);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label, border: const OutlineInputBorder(), isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          suffixIcon: value != null
              ? IconButton(icon: const Icon(Icons.clear, size: 16),
                  onPressed: () => onChanged(null), padding: EdgeInsets.zero)
              : null,
        ),
        child: Text(value != null ? _dateFmt.format(parseLocalDate(value)) : '—',
            style: const TextStyle(fontSize: 13)),
      ),
    );

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_payments.isEmpty) return const Center(child: Text('ไม่มีรายการ', style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      itemCount: _payments.length,
      itemBuilder: (_, i) {
        final p = _payments[i];
        final sel = _selected?.id == p.id;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          color: sel ? const Color(0xFFE3F2FD) : null,
          shape: sel ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: _kColor, width: 1.5)) : null,
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              backgroundColor: _statusColor(p.status).withOpacity(0.15),
              child: Icon(p.isCheck ? Icons.description : Icons.swap_horiz,
                  color: _statusColor(p.status), size: 18)),
            title: Row(children: [
              Expanded(child: Text(p.apDocNo ?? (p.isFromAp ? 'AP' : 'Manual'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              _statusChip(p.status),
            ]),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_dateFmt.format(p.paymentDate)}  |  ${p.payeeCode ?? ''}  ${p.payeeNameTh ?? ''}',
                  style: const TextStyle(fontSize: 11)),
              Row(children: [
                Text(cmPaymentMethodTypeLabels[p.paymentMethodType] ?? p.paymentMethodType,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                if (p.checkNo != null)
                  Text('  เช็ค ${p.checkNo}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const Spacer(),
                Text(_amtFmt.format(p.amountLc),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kColor)),
              ]),
            ]),
            onTap: () => setState(() { _selected = sel ? null : p; _showCreateForm = false; }),
          ),
        );
      },
    );
  }

  Widget _buildDetail(CmPayment p) => Column(children: [
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: _kColor.withOpacity(0.08),
      child: Row(children: [
        const Text('รายละเอียด', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const Spacer(),
        IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _selected = null)),
      ]),
    ),
    const Divider(height: 1),
    Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (p.isFromAp) _detailRow('เอกสาร AP', p.apDocNo ?? '—'),
          _detailRow('วันที่', _dateFmt.format(p.paymentDate)),
          _detailRow('ผู้รับเงิน', '${p.payeeCode ?? ''}  ${p.payeeNameTh ?? ''}'),
          _detailRow('บัญชีธนาคาร', '${p.bankAccountCode ?? ''}  ${p.bankAccountName ?? ''}'),
          _detailRow('วิธีจ่าย', cmPaymentMethodTypeLabels[p.paymentMethodType] ?? p.paymentMethodType),
          if (p.isCheck) ...[
            _detailRow('สมุดเช็ค', p.checkbookCode ?? '—'),
            _detailRow('เลขที่เช็ค', p.checkNo ?? '—'),
            _detailRow('วันที่เช็ค', p.checkDate != null ? _dateFmt.format(p.checkDate!) : '—'),
          ],
          _detailRow('จำนวนเงิน (THB)', _amtFmt.format(p.amountLc)),
          if (p.isFcy) _detailRow('จำนวนเงิน (FC)', '${_amtFmt.format(p.amountFc)} ${p.currencyCode}'),
          if (p.remark != null && p.remark!.isNotEmpty) _detailRow('หมายเหตุ', p.remark!),
          const Divider(),
          _detailRow('สถานะ', cmPaymentStatusOptions[p.status] ?? p.status),
          if (p.clearingDate != null) _detailRow('วันที่เคลียร์', _dateFmt.format(p.clearingDate!)),
          if (p.clearingNote != null && p.clearingNote!.isNotEmpty) _detailRow('หมายเหตุ', p.clearingNote!),
          const SizedBox(height: 20),
          // Check print button
          if (p.isCheck)
            FilledButton.icon(
              icon: const Icon(Icons.print, size: 16),
              label: const Text('พิมพ์เช็ค'),
              style: FilledButton.styleFrom(backgroundColor: Colors.indigo, minimumSize: const Size.fromHeight(36)),
              onPressed: () => _printCheck(p),
            ),
          if (p.isCheck) const SizedBox(height: 8),
          if (p.isPending) ...[
            FilledButton.icon(
              icon: const Icon(Icons.check_circle, size: 16),
              label: const Text('เคลียร์รายการ'),
              style: FilledButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size.fromHeight(36)),
              onPressed: () => _clear(p),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.block, size: 16, color: Colors.red),
              label: const Text('Void', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red),
                  minimumSize: const Size.fromHeight(36)),
              onPressed: () => _void(p),
            ),
          ],
        ]),
      ),
    ),
  ]);

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
    ]),
  );

  Color _statusColor(String s) =>
      s == 'Cleared' ? Colors.green : s == 'Voided' ? Colors.grey : _kColor;

  Widget _statusChip(String s) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: _statusColor(s).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
    child: Text(cmPaymentStatusOptions[s] ?? s,
        style: TextStyle(fontSize: 10, color: _statusColor(s), fontWeight: FontWeight.bold)),
  );
}

// ── Create Payment Form ───────────────────────────────────────────────────────

class _CreatePaymentForm extends StatefulWidget {
  final CmBankAccount bankAccount;
  final CmCheckbookService checkbookSvc;
  final Future<void> Function(CmPayment) onSave;
  final VoidCallback onCancel;
  final Color kColor;

  const _CreatePaymentForm({
    required this.bankAccount,
    required this.checkbookSvc,
    required this.onSave,
    required this.onCancel,
    required this.kColor,
  });

  @override
  State<_CreatePaymentForm> createState() => _CreatePaymentFormState();
}

class _CreatePaymentFormState extends State<_CreatePaymentForm> {
  final _formKey     = GlobalKey<FormState>();
  final _payeeCtrl   = TextEditingController();
  final _amtCtrl     = TextEditingController(text: '0.00');
  final _remarkCtrl  = TextEditingController();

  DateTime _paymentDate = DateTime.now();
  String   _methodType  = 'TRANSFER';
  DateTime? _checkDate;
  CmCheckbook? _selectedCb;
  List<CmCheckbook> _checkbooks = [];
  bool _saving = false;

  final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _loadCheckbooks();
  }

  @override
  void dispose() {
    _payeeCtrl.dispose();
    _amtCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCheckbooks() async {
    try {
      final list = await widget.checkbookSvc.fetchCheckbooks(bankAccountId: widget.bankAccount.id);
      setState(() => _checkbooks = list.where((c) => c.status == 'Active').toList());
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!await CmPeriodService.canPost(context, _paymentDate)) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(CmPayment(
        paymentDate:       _paymentDate,
        bankAccountId:     widget.bankAccount.id,
        paymentMethodType: _methodType,
        payeeNameTh:       _payeeCtrl.text.trim(),
        amountLc:          double.tryParse(_amtCtrl.text.replaceAll(',', '')) ?? 0,
        checkDate:         _methodType == 'CHECK' ? _checkDate : null,
        checkbookId:       _methodType == 'CHECK' ? _selectedCb?.id : null,
        remark:            _remarkCtrl.text.trim().isEmpty ? null : _remarkCtrl.text.trim(),
      ));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: widget.kColor.withOpacity(0.08),
        child: Row(children: [
          const Text('สร้างรายการจ่ายเงิน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close, size: 18), onPressed: widget.onCancel),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Payment date
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: _paymentDate,
                      firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (d != null) setState(() => _paymentDate = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'วันที่จ่าย *', border: OutlineInputBorder(), isDense: true),
                  child: Text(_dateFmt.format(_paymentDate)),
                ),
              ),
              const SizedBox(height: 10),
              // Method type
              DropdownButtonFormField<String>(
                value: _methodType,
                decoration: const InputDecoration(labelText: 'วิธีจ่าย *', border: OutlineInputBorder(), isDense: true),
                items: ['TRANSFER','CHECK','CASH','BILL_OF_EXCHANGE'].map((t) =>
                    DropdownMenuItem(value: t, child: Text(cmPaymentMethodTypeLabels[t] ?? t))).toList(),
                onChanged: (v) => setState(() { _methodType = v!; _selectedCb = null; }),
              ),
              const SizedBox(height: 10),
              // Checkbook (only when CHECK)
              if (_methodType == 'CHECK') ...[
                DropdownButtonFormField<CmCheckbook?>(
                  value: _selectedCb,
                  decoration: const InputDecoration(labelText: 'สมุดเช็ค', border: OutlineInputBorder(), isDense: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('— ไม่ระบุ —')),
                    ..._checkbooks.map((c) => DropdownMenuItem(value: c,
                        child: Text('${c.checkbookCode} (ถัดไป: ${c.nextCheckNo ?? c.startCheckNo})'))),
                  ],
                  onChanged: (v) => setState(() => _selectedCb = v),
                ),
                const SizedBox(height: 10),
                // Check date
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: _checkDate ?? _paymentDate,
                        firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (d != null) setState(() => _checkDate = d);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'วันที่บนเช็ค', border: const OutlineInputBorder(), isDense: true,
                      suffixIcon: _checkDate != null
                          ? IconButton(icon: const Icon(Icons.clear, size: 16),
                              onPressed: () => setState(() => _checkDate = null), padding: EdgeInsets.zero)
                          : null,
                    ),
                    child: Text(_checkDate != null ? _dateFmt.format(_checkDate!) : '(ใช้วันที่จ่าย)'),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              // Payee
              TextFormField(
                controller: _payeeCtrl,
                decoration: const InputDecoration(labelText: 'ชื่อผู้รับเงิน *', border: OutlineInputBorder(), isDense: true),
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'กรุณาระบุ' : null,
              ),
              const SizedBox(height: 10),
              // Amount
              TextFormField(
                controller: _amtCtrl,
                decoration: const InputDecoration(labelText: 'จำนวนเงิน (THB) *', border: OutlineInputBorder(), isDense: true),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                validator: (v) {
                  final d = double.tryParse(v?.replaceAll(',', '') ?? '');
                  if (d == null || d <= 0) return 'กรุณาระบุจำนวนเงิน > 0';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              // Remark
              TextFormField(
                controller: _remarkCtrl,
                decoration: const InputDecoration(labelText: 'หมายเหตุ', border: OutlineInputBorder(), isDense: true),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(children: [
                TextButton(onPressed: widget.onCancel, child: const Text('ยกเลิก')),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: widget.kColor),
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('บันทึก'),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    ]);
  }
}
