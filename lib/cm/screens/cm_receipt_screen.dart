import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/cm_bank_account.dart';
import '../models/cm_receipt.dart';
import '../services/cm_bank_account_service.dart';
import '../services/cm_period_service.dart';
import '../services/cm_receipt_service.dart';

class CmReceiptScreen extends StatefulWidget {
  const CmReceiptScreen({super.key});

  @override
  State<CmReceiptScreen> createState() => _CmReceiptScreenState();
}

class _CmReceiptScreenState extends State<CmReceiptScreen>
    with AutomaticKeepAliveClientMixin {

  static const _kColor = Color(0xFF1565C0);

  final CmBankAccountService _acctSvc = CmBankAccountService();
  final CmReceiptService     _svc     = CmReceiptService();
  final _dateFmt   = DateFormat('dd/MM/yyyy');
  final _amtFmt    = NumberFormat('#,##0.00');

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
  String? _typeFilter;

  // List
  List<CmReceipt> _receipts = [];
  bool _loading = false;

  // Selected for detail
  CmReceipt? _selected;

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
    setState(() { _selectedBank = b; _receipts = []; _selected = null; });
    _loadReceipts();
  }

  Future<void> _loadReceipts() async {
    if (_selectedBank == null) return;
    setState(() => _loading = true);
    try {
      final list = await _svc.fetchReceipts(
        bankAccountId:     _selectedBank!.id,
        status:            _statusFilter == 'All' ? null : _statusFilter,
        dateFrom:          _dateFrom,
        dateTo:            _dateTo,
        paymentMethodType: _typeFilter,
      );
      setState(() { _receipts = list; _loading = false; });
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

  // ── Status Actions ────────────────────────────────────────────────────────

  Future<void> _clear(CmReceipt r) async {
    final result = await _showClearDialog(r);
    if (result == null) return;
    final dt = DateTime.parse(result['date']!);
    if (!await CmPeriodService.canPost(context, dt)) return;
    try {
      await _svc.clearReceipt(r.id!, clearingDate: result['date'], clearingNote: result['note']);
      _showOk('เคลียร์สำเร็จ');
      await _loadReceipts();
      setState(() => _selected = null);
    } catch (e) { _showErr(e.toString()); }
  }

  Future<void> _bounce(CmReceipt r) async {
    final note = await _showNoteDialog('บันทึกเช็คคืน', 'หมายเหตุ / เหตุผล');
    if (note == null) return;
    try {
      await _svc.bounceReceipt(r.id!, clearingNote: note.isEmpty ? null : note);
      _showOk('บันทึกเช็คคืนสำเร็จ');
      await _loadReceipts();
      setState(() => _selected = null);
    } catch (e) { _showErr(e.toString()); }
  }

  Future<void> _void(CmReceipt r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยัน Void'),
        content: Text('ยืนยันการ Void รายการ ${r.arDocNo ?? r.id} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Void', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
    if (!ok) return;
    try {
      await _svc.voidReceipt(r.id!);
      _showOk('Void สำเร็จ');
      await _loadReceipts();
      setState(() => _selected = null);
    } catch (e) { _showErr(e.toString()); }
  }

  Future<Map<String, String>?> _showClearDialog(CmReceipt r) async {
    final noteCtrl = TextEditingController();
    DateTime clearDate = DateTime.now();
    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('เคลียร์รายการรับเงิน'),
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
                'date': clearDate.toIso8601String().substring(0, 10),
                'note': noteCtrl.text.trim(),
              }),
              child: const Text('ยืนยัน'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showNoteDialog(String title, String label) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl,
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
            maxLines: 2),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายการรับเงิน (CM Receipt)'),
        backgroundColor: _kColor,
        foregroundColor: Colors.white,
        actions: [
          if (_selectedBank != null)
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadReceipts, tooltip: 'โหลดใหม่'),
        ],
      ),
      body: LayoutBuilder(builder: (ctx, constraints) {
        final maxLeft = (constraints.maxWidth - 36 - 5 - 320).clamp(100.0, double.infinity);
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Toggle strip
          Container(
            width: 36, color: _kColor,
            child: IconButton(
              icon: Icon(_isLeftExpanded ? Icons.filter_list_off : Icons.filter_list, color: Colors.white, size: 20),
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _isLeftExpanded = !_isLeftExpanded),
            ),
          ),
          // Left panel
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
          // Right
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
        Icon(Icons.savings, size: 16, color: Colors.black54), SizedBox(width: 6),
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
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                          color: sel ? _kColor : null)),
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
      if (_selected != null) ...[
        const VerticalDivider(width: 1),
        SizedBox(width: 380, child: _buildDetail(_selected!)),
      ],
    ])),
  ]);

  Widget _buildFilterBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    color: Colors.grey.shade50,
    child: Row(children: [
      // Status
      SizedBox(width: 140,
        child: DropdownButtonFormField<String>(
          value: _statusFilter,
          decoration: const InputDecoration(labelText: 'สถานะ', border: OutlineInputBorder(), isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
          items: [
            const DropdownMenuItem(value: 'All', child: Text('ทั้งหมด')),
            ...cmReceiptStatusOptions.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
          ],
          onChanged: (v) => setState(() { _statusFilter = v!; _loadReceipts(); }),
        ),
      ),
      const SizedBox(width: 8),
      // Type
      SizedBox(width: 150,
        child: DropdownButtonFormField<String?>(
          value: _typeFilter,
          decoration: const InputDecoration(labelText: 'ประเภท', border: OutlineInputBorder(), isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
          items: [
            const DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
            ...['CASH','CHECK','TRANSFER','QR_CODE','MOBILE_BANKING','CREDIT_CARD','DEBIT_CARD','BILL_OF_EXCHANGE']
                .map((t) => DropdownMenuItem(value: t,
                    child: Text(cmPaymentMethodTypeLabels[t] ?? t, style: const TextStyle(fontSize: 13)))),
          ],
          onChanged: (v) => setState(() { _typeFilter = v; _loadReceipts(); }),
        ),
      ),
      const SizedBox(width: 8),
      // Date from
      _dateField('จากวันที่', _dateFrom, (d) => setState(() { _dateFrom = d; _loadReceipts(); })),
      const SizedBox(width: 8),
      _dateField('ถึงวันที่', _dateTo, (d) => setState(() { _dateTo = d; _loadReceipts(); })),
      const Spacer(),
      Text('${_receipts.length} รายการ', style: const TextStyle(color: Colors.grey, fontSize: 12)),
    ]),
  );

  Widget _dateField(String label, String? value, void Function(String?) onChanged) =>
    InkWell(
      onTap: () async {
        final d = await showDatePicker(context: context,
            initialDate: value != null ? DateTime.parse(value) : DateTime.now(),
            firstDate: DateTime(2000), lastDate: DateTime(2100));
        onChanged(d?.toIso8601String().substring(0, 10));
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
        child: Text(value != null ? _dateFmt.format(DateTime.parse(value)) : '—',
            style: const TextStyle(fontSize: 13)),
      ),
    );

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_receipts.isEmpty) return const Center(child: Text('ไม่มีรายการ', style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      itemCount: _receipts.length,
      itemBuilder: (_, i) {
        final r = _receipts[i];
        final sel = _selected?.id == r.id;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          color: sel ? const Color(0xFFE3F2FD) : null,
          shape: sel ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: _kColor, width: 1.5)) : null,
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              backgroundColor: _statusColor(r.status).withOpacity(0.15),
              child: Icon(_pmIcon(r.paymentMethodType), color: _statusColor(r.status), size: 18)),
            title: Row(children: [
              Expanded(child: Text(r.arDocNo ?? '—',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              _statusChip(r.status),
            ]),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_dateFmt.format(r.receiptDate)}  |  '
                  '${r.customerCode ?? ''}  ${r.customerNameTh ?? ''}',
                  style: const TextStyle(fontSize: 11)),
              Row(children: [
                Text(cmPaymentMethodTypeLabels[r.paymentMethodType] ?? r.paymentMethodType,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                if (r.checkNo != null)
                  Text('  เช็ค ${r.checkNo}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const Spacer(),
                Text(_amtFmt.format(r.amountLc),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kColor)),
              ]),
            ]),
            onTap: () => setState(() => _selected = sel ? null : r),
          ),
        );
      },
    );
  }

  Widget _buildDetail(CmReceipt r) => Column(children: [
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
          _detailRow('เอกสาร AR', r.arDocNo ?? '—'),
          _detailRow('วันที่', _dateFmt.format(r.receiptDate)),
          _detailRow('ลูกค้า', '${r.customerCode ?? ''} ${r.customerNameTh ?? ''}'),
          _detailRow('บัญชีธนาคาร', '${r.bankAccountCode ?? ''} ${r.bankAccountName ?? ''}'),
          _detailRow('ธนาคาร', r.bankName ?? '—'),
          _detailRow('วิธีชำระ', '${cmPaymentMethodTypeLabels[r.paymentMethodType] ?? r.paymentMethodType}'
              '  (${r.paymentMethodCode ?? '—'})'),
          if (r.isCheck) ...[
            _detailRow('เลขที่เช็ค', r.checkNo ?? '—'),
            _detailRow('วันที่เช็ค', r.checkDate != null ? _dateFmt.format(r.checkDate!) : '—'),
            _detailRow('ธนาคารผู้สั่งจ่าย', r.drawerBank ?? '—'),
          ],
          _detailRow('จำนวนเงิน (THB)', _amtFmt.format(r.amountLc)),
          if (r.isFcy) _detailRow('จำนวนเงิน (FC)', '${_amtFmt.format(r.amountFc)} ${r.currencyCode}'),
          const Divider(),
          _detailRow('สถานะ', cmReceiptStatusOptions[r.status] ?? r.status),
          if (r.clearingDate != null)
            _detailRow('วันที่เคลียร์', _dateFmt.format(r.clearingDate!)),
          if (r.clearingNote != null && r.clearingNote!.isNotEmpty)
            _detailRow('หมายเหตุ', r.clearingNote!),
          const SizedBox(height: 20),
          // Action buttons
          if (r.isPending) ...[
            FilledButton.icon(
              icon: const Icon(Icons.check_circle, size: 16),
              label: const Text('เคลียร์รายการ'),
              style: FilledButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size.fromHeight(36)),
              onPressed: () => _clear(r),
            ),
            const SizedBox(height: 8),
            if (r.isCheck)
              FilledButton.icon(
                icon: const Icon(Icons.cancel, size: 16),
                label: const Text('เช็คคืน (Bounced)'),
                style: FilledButton.styleFrom(backgroundColor: Colors.orange, minimumSize: const Size.fromHeight(36)),
                onPressed: () => _bounce(r),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.block, size: 16, color: Colors.red),
              label: const Text('Void', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red),
                  minimumSize: const Size.fromHeight(36)),
              onPressed: () => _void(r),
            ),
          ],
        ]),
      ),
    ),
  ]);

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
    ]),
  );

  Color _statusColor(String s) {
    switch (s) {
      case 'Cleared': return Colors.green;
      case 'Bounced': return Colors.orange;
      case 'Voided':  return Colors.grey;
      default:        return _kColor;
    }
  }

  Widget _statusChip(String s) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: _statusColor(s).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
    child: Text(cmReceiptStatusOptions[s] ?? s,
        style: TextStyle(fontSize: 10, color: _statusColor(s), fontWeight: FontWeight.bold)),
  );

  IconData _pmIcon(String type) {
    switch (type) {
      case 'CHECK':  return Icons.account_balance;
      case 'TRANSFER': return Icons.swap_horiz;
      case 'CREDIT_CARD': case 'DEBIT_CARD': return Icons.credit_card;
      case 'QR_CODE': return Icons.qr_code;
      default: return Icons.payments;
    }
  }
}
