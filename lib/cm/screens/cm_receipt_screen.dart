import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/widgets/sa_document_reverse_widgets.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../models/cm_bank_account.dart';
import '../models/cm_receipt.dart';
import '../services/cm_bank_account_service.dart';
import '../services/cm_period_service.dart';
import '../services/cm_receipt_service.dart';
import '../../utils/date_utils.dart';
import '../../cd/services/cd_currency_service.dart';

class CmReceiptScreen extends StatefulWidget {
  const CmReceiptScreen({super.key});

  @override
  State<CmReceiptScreen> createState() => _CmReceiptScreenState();
}

class _CmReceiptScreenState extends State<CmReceiptScreen>
    with AutomaticKeepAliveClientMixin {

  static const _kColor = Color(0xFF1565C0);

  bool _isEnglish = false;

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

  Future<void> _select(CmReceipt r) async {
    setState(() => _selected = r);
    try {
      final full = await _svc.fetchReceipt(r.id!);
      if (mounted && _selected?.id == r.id) setState(() => _selected = full);
    } catch (e) { _showErr(e.toString()); }
  }

  // หลังทำรายการ: โหลดรายการใหม่และแสดงผลล่าสุดในกรอบรายละเอียด
  Future<void> _afterAction(CmReceipt updated) async {
    await _loadReceipts();
    if (mounted) setState(() => _selected = updated);
  }

  String? _blockMessage(String? code, String? ref) {
    if (code == null) return null;
    final isEnglish = _isEnglish;
    final suffix = (ref == null || ref.isEmpty) ? '' : ' ($ref)';
    switch (code) {
      case 'NOT_CLEARED':   return isEnglish ? 'Only cleared items can be un-cleared' : 'ยกเลิกการเคลียร์ได้เฉพาะรายการที่เคลียร์แล้ว';
      case 'NOT_PENDING':   return isEnglish ? 'Only pending items allowed' : 'ทำได้เฉพาะรายการที่รอเคลียร์';
      case 'NOT_CHECK':     return isEnglish ? 'Only check receipts can bounce' : 'บันทึกเช็คคืนได้เฉพาะรายการรับเป็นเช็ค';
      case 'RECONCILED':    return isEnglish
          ? 'Reconciled with a bank statement — unreconcile first'
          : 'รายการนี้กระทบยอดกับ Bank Statement แล้ว กรุณายกเลิกการกระทบยอดก่อน';
      case 'PERIOD_CLOSED': return isEnglish ? 'The CM period of the clearing date is closed' : 'งวด CM ของวันที่เคลียร์ปิดแล้ว';
      case 'SOURCE_DOC':    return isEnglish
          ? 'Created by an AR receipt — void the source document instead$suffix'
          : 'รายการนี้มาจากใบเสร็จ AR กรุณายกเลิกที่เอกสารต้นทาง$suffix';
      default:              return code;
    }
  }

  // ปุ่มที่ล็อกเมื่อทำรายการไม่ได้ — ชี้เมาส์เห็นเหตุผล
  Widget _lockable(String? blockMsg, Widget Function(VoidCallback? onPressed) build, VoidCallback action) =>
      blockMsg == null ? build(action) : Tooltip(message: blockMsg, child: build(null));

  // ── Status Actions ────────────────────────────────────────────────────────

  Future<void> _clear(CmReceipt r) async {
    final isEnglish = _isEnglish;
    final result = await _showClearDialog(r);
    if (result == null) return;
    final dt = parseLocalDate(result['date']);
    if (!await CmPeriodService.canPost(context, dt)) return;
    try {
      final updated = await _svc.clearReceipt(r.id!, clearingDate: result['date'], clearingNote: result['note']);
      _showOk(isEnglish ? 'Cleared successfully' : 'เคลียร์สำเร็จ');
      await _afterAction(updated);
    } catch (e) { _showErr(e.toString()); }
  }

  Future<void> _unclear(CmReceipt r) async {
    final isEnglish = _isEnglish;
    final reason = await showDocReasonDialog(context,
        isEnglish: isEnglish,
        title: isEnglish ? 'Undo Clearing' : 'ยกเลิกการเคลียร์',
        message: isEnglish
            ? 'The item goes back to Pending. No accounting entries change.'
            : 'รายการจะกลับเป็นรอเคลียร์ ไม่กระทบรายการบัญชี',
        confirmLabel: isEnglish ? 'Undo Clearing' : 'ยกเลิกการเคลียร์',
        confirmColor: Colors.orange);
    if (reason == null) return;
    try {
      final updated = await _svc.unclearReceipt(r.id!, reason);
      _showOk(isEnglish ? 'Clearing undone' : 'ยกเลิกการเคลียร์แล้ว');
      await _afterAction(updated);
    } catch (e) { _showErr(e.toString()); }
  }

  Future<void> _bounce(CmReceipt r) async {
    final isEnglish = _isEnglish;
    final doc = r.arDocNo ?? '-';
    final reason = await showDocReasonDialog(context,
        isEnglish: isEnglish,
        title: isEnglish ? 'Record Bounced Check' : 'บันทึกเช็คคืน',
        message: isEnglish
            ? 'AR receipt $doc will be voided with a reversing entry dated today, and its invoices become '
              'outstanding again. Other payments on the same receipt are voided too — issue a new receipt '
              'for the amount actually received.'
            : 'ใบเสร็จ AR $doc จะถูกยกเลิก (ลงรายการกลับวันนี้) ใบแจ้งหนี้จะกลับมามียอดค้าง '
              'รายการรับอื่นในใบเสร็จเดียวกันจะถูกยกเลิกด้วย ต้องออกใบเสร็จใหม่สำหรับส่วนที่ได้รับจริง',
        confirmLabel: isEnglish ? 'Record Bounce' : 'บันทึกเช็คคืน',
        confirmColor: Colors.orange);
    if (reason == null) return;
    try {
      final updated = await _svc.bounceReceipt(r.id!, reason);
      _showOk(isEnglish ? 'Bounced check recorded' : 'บันทึกเช็คคืนสำเร็จ');
      await _afterAction(updated);
    } catch (e) { _showErr(e.toString()); }
  }

  Future<void> _void(CmReceipt r) async {
    final isEnglish = _isEnglish;
    if (!(MenuScope.of(context)?.canDelete ?? true)) return;
    final reason = await showDocReasonDialog(context,
        isEnglish: isEnglish,
        title: isEnglish ? 'Void Receipt Item' : 'ยกเลิกรายการรับเงิน',
        message: isEnglish ? 'Void item ${r.arDocNo ?? r.id}?' : 'ยกเลิกรายการ ${r.arDocNo ?? r.id} ?',
        confirmLabel: 'Void');
    if (reason == null) return;
    try {
      final updated = await _svc.voidReceipt(r.id!, reason);
      _showOk(isEnglish ? 'Voided successfully' : 'Void สำเร็จ');
      await _afterAction(updated);
    } catch (e) { _showErr(e.toString()); }
  }

  Future<Map<String, String>?> _showClearDialog(CmReceipt r) async {
    final isEnglish = _isEnglish;
    final noteCtrl = TextEditingController();
    DateTime clearDate = DateTime.now();
    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(isEnglish ? 'Clear Receipt' : 'เคลียร์รายการรับเงิน'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            InkWell(
              onTap: () async {
                final d = await showDatePicker(context: ctx, initialDate: clearDate,
                    firstDate: DateTime(2000), lastDate: DateTime(2100));
                if (d != null) setDlg(() => clearDate = d);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                    labelText: isEnglish ? 'Clearing Date' : 'วันที่เคลียร์',
                    border: const OutlineInputBorder(), isDense: true),
                child: Text(_dateFmt.format(clearDate)),
              ),
            ),
            const SizedBox(height: 8),
            TextField(controller: noteCtrl,
                decoration: InputDecoration(
                    labelText: isEnglish ? 'Note' : 'หมายเหตุ',
                    border: const OutlineInputBorder(), isDense: true)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _kColor),
              onPressed: () => Navigator.pop(ctx, {
                'date': formatLocalDate(clearDate),
                'note': noteCtrl.text.trim(),
              }),
              child: Text(isEnglish ? 'Confirm' : 'ยืนยัน'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: _kColor,
        foregroundColor: Colors.white,
        actions: [
          if (_selectedBank != null)
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadReceipts,
                tooltip: isEnglish ? 'Reload' : 'โหลดใหม่'),
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
              ? Center(child: Text(
                  isEnglish ? 'Select a bank account on the left' : 'เลือกบัญชีธนาคารทางซ้าย',
                  style: const TextStyle(color: Colors.grey)))
              : _buildMainPanel()),
        ]);
      }),
    );
  }

  Widget _buildBankList() {
    final isEnglish = _isEnglish;
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(8), color: Colors.blueGrey.shade200,
        child: Row(children: [
          const Icon(Icons.savings, size: 16, color: Colors.black54), const SizedBox(width: 6),
          Text(isEnglish ? 'Bank Accounts' : 'บัญชีธนาคาร',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ]),
      ),
      Expanded(
        child: _bankAccounts.isEmpty
            ? Center(child: Text(isEnglish ? 'No accounts found' : 'ไม่พบบัญชี',
                style: const TextStyle(color: Colors.grey, fontSize: 12)))
            : ListView.builder(
                itemCount: _bankAccounts.length,
                itemBuilder: (_, i) {
                  final b = _bankAccounts[i];
                  final sel = _selectedBank?.id == b.id;
                  final name = isEnglish && (b.accountNameEn ?? '').isNotEmpty
                      ? b.accountNameEn! : b.accountNameTh;
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
                    subtitle: Text(name, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                    onTap: () => _selectBank(b),
                  );
                },
              ),
      ),
    ]);
  }

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

  Widget _buildFilterBar() {
    final isEnglish = _isEnglish;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.grey.shade50,
      child: Row(children: [
        // Status
        SizedBox(width: 140,
          child: DropdownButtonFormField<String>(
            value: _statusFilter,
            decoration: InputDecoration(
                labelText: isEnglish ? 'Status' : 'สถานะ', border: const OutlineInputBorder(), isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
            items: [
              DropdownMenuItem(value: 'All', child: Text(isEnglish ? 'All' : 'ทั้งหมด')),
              ...cmReceiptStatusOptions.keys.map((k) => DropdownMenuItem(
                  value: k, child: Text(cmReceiptStatusLabel(k, isEnglish)))),
            ],
            onChanged: (v) => setState(() { _statusFilter = v!; _loadReceipts(); }),
          ),
        ),
        const SizedBox(width: 8),
        // Type
        SizedBox(width: 150,
          child: DropdownButtonFormField<String?>(
            value: _typeFilter,
            decoration: InputDecoration(
                labelText: isEnglish ? 'Type' : 'ประเภท', border: const OutlineInputBorder(), isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
            items: [
              DropdownMenuItem(value: null, child: Text(isEnglish ? 'All' : 'ทั้งหมด')),
              ...['CASH','CHECK','TRANSFER','QR_CODE','MOBILE_BANKING','CREDIT_CARD','DEBIT_CARD','BILL_OF_EXCHANGE']
                  .map((t) => DropdownMenuItem(value: t,
                      child: Text(cmPaymentMethodTypeLabel(t, isEnglish), style: const TextStyle(fontSize: 13)))),
            ],
            onChanged: (v) => setState(() { _typeFilter = v; _loadReceipts(); }),
          ),
        ),
        const SizedBox(width: 8),
        // Date from
        _dateField(isEnglish ? 'From Date' : 'จากวันที่', _dateFrom, (d) => setState(() { _dateFrom = d; _loadReceipts(); })),
        const SizedBox(width: 8),
        _dateField(isEnglish ? 'To Date' : 'ถึงวันที่', _dateTo, (d) => setState(() { _dateTo = d; _loadReceipts(); })),
        const Spacer(),
        Text(isEnglish ? '${_receipts.length} items' : '${_receipts.length} รายการ',
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ]),
    );
  }

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
    final isEnglish = _isEnglish;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_receipts.isEmpty) return Center(child: Text(isEnglish ? 'No items' : 'ไม่มีรายการ',
        style: const TextStyle(color: Colors.grey)));
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
                Text(cmPaymentMethodTypeLabel(r.paymentMethodType, isEnglish),
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                if (r.checkNo != null)
                  Text('  ${isEnglish ? 'Check' : 'เช็ค'} ${r.checkNo}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const Spacer(),
                Text(_amtFmt.format(r.amountLc),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kColor)),
              ]),
            ]),
            onTap: () => sel ? setState(() => _selected = null) : _select(r),
          ),
        );
      },
    );
  }

  Widget _buildDetail(CmReceipt r) {
    final isEnglish = _isEnglish;
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: _kColor.withOpacity(0.08),
        child: Row(children: [
          Text(isEnglish ? 'Details' : 'รายละเอียด', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _selected = null)),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _detailRow(isEnglish ? 'AR Document' : 'เอกสาร AR', r.arDocNo ?? '—'),
            _detailRow(isEnglish ? 'Date' : 'วันที่', _dateFmt.format(r.receiptDate)),
            _detailRow(isEnglish ? 'Customer' : 'ลูกค้า', '${r.customerCode ?? ''} ${r.customerNameTh ?? ''}'),
            _detailRow(isEnglish ? 'Bank Account' : 'บัญชีธนาคาร', '${r.bankAccountCode ?? ''} ${r.bankAccountName ?? ''}'),
            _detailRow(isEnglish ? 'Bank' : 'ธนาคาร', r.bankName ?? '—'),
            _detailRow(isEnglish ? 'Payment Method' : 'วิธีชำระ',
                '${cmPaymentMethodTypeLabel(r.paymentMethodType, isEnglish)}'
                '  (${r.paymentMethodCode ?? '—'})'),
            if (r.isCheck) ...[
              _detailRow(isEnglish ? 'Check No.' : 'เลขที่เช็ค', r.checkNo ?? '—'),
              _detailRow(isEnglish ? 'Check Date' : 'วันที่เช็ค', r.checkDate != null ? _dateFmt.format(r.checkDate!) : '—'),
              _detailRow(isEnglish ? 'Drawer Bank' : 'ธนาคารผู้สั่งจ่าย', r.drawerBank ?? '—'),
            ],
            _detailRow(isEnglish ? 'Amount (${CurrencyService.baseCode})' : 'จำนวนเงิน (${CurrencyService.baseCode})', _amtFmt.format(r.amountLc)),
            if (r.isFcy) _detailRow(isEnglish ? 'Amount (FC)' : 'จำนวนเงิน (FC)', '${_amtFmt.format(r.amountFc)} ${r.currencyCode}'),
            const Divider(),
            _detailRow(isEnglish ? 'Status' : 'สถานะ', cmReceiptStatusLabel(r.status, isEnglish)),
            if (r.clearingDate != null)
              _detailRow(isEnglish ? 'Clearing Date' : 'วันที่เคลียร์', _dateFmt.format(r.clearingDate!)),
            if (r.clearingNote != null && r.clearingNote!.isNotEmpty)
              _detailRow(isEnglish ? 'Note' : 'หมายเหตุ', r.clearingNote!),
            const SizedBox(height: 20),
            // Action buttons
            if (r.isPending) ...[
              FilledButton.icon(
                icon: const Icon(Icons.check_circle, size: 16),
                label: Text(isEnglish ? 'Clear Item' : 'เคลียร์รายการ'),
                style: FilledButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size.fromHeight(36)),
                onPressed: () => _clear(r),
              ),
              const SizedBox(height: 8),
              if (r.isCheck) ...[
                _lockable(r.bounceBlockMessage, (onPressed) => FilledButton.icon(
                  icon: const Icon(Icons.cancel, size: 16),
                  label: Text(isEnglish ? 'Bounced Check' : 'เช็คคืน (Bounced)'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.orange, minimumSize: const Size.fromHeight(36)),
                  onPressed: onPressed,
                ), () => _bounce(r)),
                const SizedBox(height: 8),
              ],
              _lockable(_blockMessage(r.voidBlock, r.voidBlockRef), (onPressed) => OutlinedButton.icon(
                icon: Icon(Icons.block, size: 16, color: onPressed == null ? Colors.grey : Colors.red),
                label: Text('Void', style: TextStyle(color: onPressed == null ? Colors.grey : Colors.red)),
                style: OutlinedButton.styleFrom(
                    side: BorderSide(color: onPressed == null ? Colors.grey.shade400 : Colors.red),
                    minimumSize: const Size.fromHeight(36)),
                onPressed: onPressed,
              ), () => _void(r)),
            ],
            if (r.isCleared)
              _lockable(_blockMessage(r.unclearBlock, null), (onPressed) => OutlinedButton.icon(
                icon: const Icon(Icons.undo, size: 16),
                label: Text(isEnglish ? 'Undo Clearing' : 'ยกเลิกการเคลียร์'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.orange.shade800,
                    minimumSize: const Size.fromHeight(36)),
                onPressed: onPressed,
              ), () => _unclear(r)),
            const SizedBox(height: 12),
            DocReverseHistoryPanel(
              history: r.reverseHistory,
              isDeleted: false,
              isEnglish: isEnglish,
              margin: EdgeInsets.zero,
              title: isEnglish ? 'Status change history' : 'ประวัติการเปลี่ยนสถานะ',
            ),
          ]),
        ),
      ),
    ]);
  }

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
      case 'Voided':  return Colors.red;
      default:        return _kColor;
    }
  }

  Widget _statusChip(String s) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: _statusColor(s).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
    child: Text(cmReceiptStatusLabel(s, _isEnglish),
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
