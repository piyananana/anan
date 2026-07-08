// lib/cm/screens/cm_petty_cash_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../gl/models/account.dart';
import '../../gl/services/account_service.dart';
import '../../sa/models/module_document.dart';
import '../../sa/services/module_document_service.dart';
import '../models/cm_bank_account.dart';
import '../models/cm_petty_cash.dart';
import '../services/cm_bank_account_service.dart';
import '../services/cm_petty_cash_service.dart';
import '../services/cm_period_service.dart';

const _kTheme = Color(0xFF1565C0);
final _fmt = DateFormat('dd/MM/yyyy');
final _fmtNum = NumberFormat('#,##0.00');

// ─────────────────────────────────────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────────────────────────────────────

class CmPettyCashScreen extends StatefulWidget {
  const CmPettyCashScreen({super.key});
  @override
  State<CmPettyCashScreen> createState() => _CmPettyCashScreenState();
}

class _CmPettyCashScreenState extends State<CmPettyCashScreen>
    with AutomaticKeepAliveClientMixin {
  final _svc = CmBankAccountService();

  List<CmBankAccount> _accounts = [];
  CmBankAccount? _selected;
  double _leftWidth = 260;
  bool _collapsed = false;
  bool _loading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _loading = true);
    try {
      final all = await _svc.fetchRows();
      setState(() => _accounts = all.where((a) => a.cmType == 'PETTY_CASH' && a.isActive).toList());
    } catch (e) {
      if (mounted) _showError('โหลดบัญชีล้มเหลว: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('เงินสดย่อย'),
        backgroundColor: _kTheme,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'โหลดใหม่',
            onPressed: _loadAccounts,
          ),
        ],
      ),
      body: LayoutBuilder(builder: (ctx, constraints) {
        final maxLeft = (constraints.maxWidth - 36 - 6 - 300).clamp(100.0, double.infinity);
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ── Toggle strip ──────────────────────────────────────────────
          Container(
            width: 36,
            color: _kTheme,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                _collapsed ? Icons.filter_list : Icons.filter_list_off,
                color: Colors.white,
                size: 20,
              ),
              tooltip: _collapsed ? 'ขยายรายการ' : 'ย่อรายการ',
              onPressed: () => setState(() => _collapsed = !_collapsed),
            ),
          ),
          // ── Left panel ────────────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _collapsed ? 0 : _leftWidth,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: _leftWidth,
                maxWidth: _leftWidth,
                child: _buildLeftPanel(),
              ),
            ),
          ),
          // ── Drag divider ──────────────────────────────────────────────
          if (!_collapsed)
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                onHorizontalDragUpdate: (d) => setState(() {
                  _leftWidth = (_leftWidth + d.delta.dx).clamp(180.0, maxLeft);
                }),
                child: Container(width: 6, color: Colors.blueGrey.shade100),
              ),
            ),
          // ── Right panel ───────────────────────────────────────────────
          Expanded(child: _buildRightPanel()),
        ]);
      }),
    );
  }

  Widget _buildLeftPanel() {
    return Container(
      color: Colors.blueGrey.shade100,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: Colors.blueGrey.shade200,
            width: double.infinity,
            child: const Text('บัญชีเงินสดย่อย',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: _accounts.length,
              itemBuilder: (_, i) {
                final a = _accounts[i];
                final sel = _selected?.id == a.id;
                return InkWell(
                  onTap: () => setState(() => _selected = a),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    color: sel ? _kTheme.withOpacity(0.15) : null,
                    child: Row(
                      children: [
                        Icon(Icons.account_balance_wallet,
                            size: 16, color: sel ? _kTheme : Colors.blueGrey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.accountCode,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: sel ? _kTheme : null)),
                              Text(a.accountNameTh,
                                  style: const TextStyle(fontSize: 11),
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
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
    if (_selected == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet, size: 64, color: Colors.blueGrey.shade300),
            const SizedBox(height: 12),
            Text('เลือกบัญชีเงินสดย่อยจากรายการซ้ายมือ',
                style: TextStyle(color: Colors.blueGrey.shade400)),
          ],
        ),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Header
          Container(
            color: Color.lerp(_kTheme, Colors.white, 0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    '${_selected!.accountCode} — ${_selected!.accountNameTh}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const TabBar(
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: [
                    Tab(text: 'ใบสำคัญจ่าย'),
                    Tab(text: 'รายการเบิกจ่าย'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _VoucherTab(account: _selected!, key: ValueKey('v${_selected!.id}')),
                _ReplenishmentTab(account: _selected!, key: ValueKey('r${_selected!.id}')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Voucher Tab
// ─────────────────────────────────────────────────────────────────────────────

class _VoucherTab extends StatefulWidget {
  final CmBankAccount account;
  const _VoucherTab({required this.account, super.key});
  @override
  State<_VoucherTab> createState() => _VoucherTabState();
}

class _VoucherTabState extends State<_VoucherTab> {
  final _svc = CmPettyCashService();
  final _acctSvc = AccountService();

  List<CmPettyCashVoucher> _vouchers = [];
  CmPettyCashVoucher? _selected;
  bool _loading = false;
  bool _isCreating = false;
  bool _isEditing = false;

  // Filters
  String _statusFilter = 'All';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  // Form state
  final _payeeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  DateTime? _formDate;
  int? _expGlId;
  String? _expGlDisplay;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _payeeCtrl.dispose();
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _svc.fetchVouchers(
        pettyCashAccountId: widget.account.id,
        status: _statusFilter == 'All' ? null : _statusFilter,
        dateFrom: _dateFrom != null
            ? DateFormat('yyyy-MM-dd').format(_dateFrom!)
            : null,
        dateTo: _dateTo != null
            ? DateFormat('yyyy-MM-dd').format(_dateTo!)
            : null,
      );
      setState(() {
        _vouchers = list;
        if (_selected != null) {
          _selected = list.where((v) => v.id == _selected!.id).firstOrNull;
        }
      });
    } catch (e) {
      if (mounted) _err('โหลดใบสำคัญล้มเหลว: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _err(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  void _ok(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));

  void _startCreate() {
    _formDate = DateTime.now();
    _payeeCtrl.clear();
    _descCtrl.clear();
    _amountCtrl.clear();
    _expGlId = null;
    _expGlDisplay = null;
    setState(() {
      _selected = null;
      _isCreating = true;
      _isEditing = false;
    });
  }

  void _startEdit(CmPettyCashVoucher v) {
    _formDate = v.voucherDate;
    _payeeCtrl.text = v.payeeName ?? '';
    _descCtrl.text = v.description ?? '';
    _amountCtrl.text = v.amount.toStringAsFixed(2);
    _expGlId = v.expenseGlAccountId;
    _expGlDisplay = v.expenseGlAccountId != null
        ? '${v.expenseGlAccountCode} ${v.expenseGlAccountName}'
        : null;
    setState(() {
      _selected = v;
      _isEditing = true;
      _isCreating = false;
    });
  }

  void _cancelForm() => setState(() {
    _isCreating = false;
    _isEditing = false;
  });

  Future<void> _save() async {
    if (_formDate == null) { _err('กรุณาระบุวันที่'); return; }
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) { _err('กรุณาระบุจำนวนเงินที่ถูกต้อง'); return; }

    final body = {
      'voucher_date':          DateFormat('yyyy-MM-dd').format(_formDate!),
      'petty_cash_account_id': widget.account.id,
      'payee_name':            _payeeCtrl.text.trim().isEmpty ? null : _payeeCtrl.text.trim(),
      'description':           _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'expense_gl_account_id': _expGlId,
      'amount':                amount,
    };

    try {
      if (_isCreating) {
        await _svc.createVoucher(body);
        _ok('สร้างใบสำคัญสำเร็จ');
      } else {
        await _svc.updateVoucher(_selected!.id, body);
        _ok('บันทึกสำเร็จ');
      }
      _cancelForm();
      await _load();
    } catch (e) {
      _err('$e');
    }
  }

  Future<void> _approve(CmPettyCashVoucher v) async {
    if (!await CmPeriodService.canPost(context, v.voucherDate)) return;
    try {
      await _svc.approveVoucher(v.id);
      _ok('อนุมัติใบสำคัญ ${v.voucherNo} สำเร็จ');
      await _load();
    } catch (e) { _err('$e'); }
  }

  Future<void> _void(CmPettyCashVoucher v) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันการยกเลิก'),
        content: Text('ยืนยันยกเลิกใบสำคัญ ${v.voucherNo}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _svc.voidVoucher(v.id);
      _ok('ยกเลิกใบสำคัญสำเร็จ');
      await _load();
    } catch (e) { _err('$e'); }
  }

  Future<void> _delete(CmPettyCashVoucher v) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ลบใบสำคัญ ${v.voucherNo}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _svc.deleteVoucher(v.id);
      setState(() { if (_selected?.id == v.id) _selected = null; });
      _ok('ลบสำเร็จ');
      await _load();
    } catch (e) { _err('$e'); }
  }

  Future<void> _pickGlAccount() async {
    List<Account> accounts;
    try {
      accounts = await _acctSvc.fetchRows();
    } catch (e) { _err('โหลดผังบัญชีล้มเหลว: $e'); return; }

    final leafAccounts = accounts.where((a) => a.isNormalAccount && a.isActive).toList();
    if (!mounted) return;

    final result = await showDialog<Account>(
      context: context,
      builder: (ctx) => _GlAccountPickerDialog(accounts: leafAccounts),
    );
    if (result != null) {
      setState(() {
        _expGlId = result.id;
        _expGlDisplay = '${result.accountCode} ${result.accountNameThai}';
      });
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _dateFrom : _dateTo) ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) { _dateFrom = picked; } else { _dateTo = picked; }
      });
      await _load();
    }
  }

  Future<void> _pickFormDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _formDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _formDate = picked);
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Approved':    return Colors.green;
      case 'Replenished': return _kTheme;
      case 'Voided':      return Colors.grey;
      default:            return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Left list ─────────────────────────────────────────────────────
        SizedBox(
          width: 300,
          child: Column(
            children: [
              _buildFilterBar(),
              if (_loading) const LinearProgressIndicator(),
              Expanded(child: _buildList()),
              Padding(
                padding: const EdgeInsets.all(8),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kTheme,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 38),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('สร้างใบสำคัญ'),
                  onPressed: _startCreate,
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        // ── Right panel ───────────────────────────────────────────────────
        Expanded(
          child: _isCreating || _isEditing
              ? _buildForm()
              : _selected != null
                  ? _buildDetail(_selected!)
                  : Center(
                      child: Text('เลือกใบสำคัญหรือกดสร้างใหม่',
                          style: TextStyle(color: Colors.blueGrey.shade400))),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _statusFilter,
            decoration: const InputDecoration(
                labelText: 'สถานะ', isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: 'All', child: Text('ทั้งหมด')),
              ...cmPcvStatusOptions.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
            ],
            onChanged: (v) {
              if (v != null) { setState(() => _statusFilter = v); _load(); }
            },
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDate(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(_dateFrom != null ? _fmt.format(_dateFrom!) : 'จากวันที่',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDate(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(_dateTo != null ? _fmt.format(_dateTo!) : 'ถึงวันที่',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  ),
                ),
              ),
              if (_dateFrom != null || _dateTo != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () {
                    setState(() { _dateFrom = null; _dateTo = null; });
                    _load();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_vouchers.isEmpty) {
      return Center(child: Text('ไม่พบใบสำคัญ', style: TextStyle(color: Colors.grey.shade500)));
    }
    return ListView.builder(
      itemCount: _vouchers.length,
      itemBuilder: (_, i) {
        final v = _vouchers[i];
        final sel = _selected?.id == v.id;
        return InkWell(
          onTap: () => setState(() {
            _selected = v;
            _isCreating = false;
            _isEditing = false;
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: sel ? _kTheme.withOpacity(0.1) : null,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.voucherNo,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('${_fmt.format(v.voucherDate)} • ${_fmtNum.format(v.amount)} บาท',
                          style: const TextStyle(fontSize: 11)),
                      if (v.payeeName != null)
                        Text(v.payeeName!, style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor(v.status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(cmPcvStatusOptions[v.status] ?? v.status,
                      style: TextStyle(fontSize: 10, color: _statusColor(v.status))),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetail(CmPettyCashVoucher v) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(v.voucherNo,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              _statusChip(v.status),
              const Spacer(),
              if (v.isDraft) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('แก้ไข'),
                  onPressed: () => _startEdit(v),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          const Divider(height: 24),
          _infoRow('วันที่', _fmt.format(v.voucherDate)),
          _infoRow('ผู้รับเงิน', v.payeeName ?? '-'),
          _infoRow('รายละเอียด', v.description ?? '-'),
          _infoRow('บัญชีค่าใช้จ่าย',
              v.expenseGlAccountId != null
                  ? '${v.expenseGlAccountCode} ${v.expenseGlAccountName}'
                  : '-'),
          _infoRow('จำนวนเงิน', '${_fmtNum.format(v.amount)} บาท',
              highlight: true),
          if (v.replenishmentId != null)
            _infoRow('เลขที่เบิกจ่าย', 'RPL #${v.replenishmentId}'),
          const SizedBox(height: 20),
          // Action buttons
          Wrap(
            spacing: 8,
            children: [
              if (v.isDraft) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('อนุมัติ'),
                  onPressed: () => _approve(v),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('ลบ'),
                  onPressed: () => _delete(v),
                ),
              ],
              if (v.isDraft || v.isApproved)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  icon: const Icon(Icons.cancel, size: 16),
                  label: const Text('ยกเลิก'),
                  onPressed: () => _void(v),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final isNew = _isCreating;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isNew ? 'สร้างใบสำคัญใหม่' : 'แก้ไขใบสำคัญ',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Divider(height: 20),
          // Date
          GestureDetector(
            onTap: _pickFormDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                  labelText: 'วันที่ *', border: OutlineInputBorder(), isDense: true),
              child: Text(_formDate != null ? _fmt.format(_formDate!) : 'เลือกวันที่',
                  style: TextStyle(
                      color: _formDate != null ? null : Colors.grey.shade500)),
            ),
          ),
          const SizedBox(height: 12),
          // Payee
          TextField(
            controller: _payeeCtrl,
            decoration: const InputDecoration(
                labelText: 'ผู้รับเงิน', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 12),
          // Description
          TextField(
            controller: _descCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
                labelText: 'รายละเอียด', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 12),
          // GL Account picker
          GestureDetector(
            onTap: _pickGlAccount,
            child: InputDecorator(
              decoration: InputDecoration(
                  labelText: 'บัญชีค่าใช้จ่าย',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_expGlId != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () => setState(() { _expGlId = null; _expGlDisplay = null; }),
                        ),
                      const Icon(Icons.search, size: 18),
                    ],
                  )),
              child: Text(_expGlDisplay ?? 'เลือกบัญชี...',
                  style: TextStyle(
                      color: _expGlDisplay != null ? null : Colors.grey.shade500,
                      fontSize: 13)),
            ),
          ),
          const SizedBox(height: 12),
          // Amount
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'จำนวนเงิน (บาท) *', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _kTheme),
                onPressed: _save,
                child: const Text('บันทึก', style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _cancelForm,
                child: const Text('ยกเลิก'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String s) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
        color: _statusColor(s).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12)),
    child: Text(cmPcvStatusOptions[s] ?? s,
        style: TextStyle(fontSize: 12, color: _statusColor(s), fontWeight: FontWeight.bold)),
  );

  Widget _infoRow(String label, String value, {bool highlight = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                  color: highlight ? _kTheme : null)),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Replenishment Tab
// ─────────────────────────────────────────────────────────────────────────────

class _ReplenishmentTab extends StatefulWidget {
  final CmBankAccount account;
  const _ReplenishmentTab({required this.account, super.key});
  @override
  State<_ReplenishmentTab> createState() => _ReplenishmentTabState();
}

class _ReplenishmentTabState extends State<_ReplenishmentTab> {
  final _svc = CmPettyCashService();
  final _bankSvc = CmBankAccountService();
  final _docSvc = ModuleDocumentService();

  List<CmPettyCashReplenishment> _replenishments = [];
  CmPettyCashReplenishment? _selected;
  bool _loading = false;
  bool _isCreating = false;

  // Filters
  String _statusFilter = 'All';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  // Lists for dropdowns
  List<CmBankAccount> _bankAccounts = [];
  List<ModuleDocument> _glDocTypes = [];

  // Detail view: pending or replenished vouchers
  List<CmPettyCashVoucher> _detailVouchers = [];
  bool _loadingVouchers = false;

  // Form state
  DateTime? _formDate;
  int? _srcBankId;
  int? _glDocId;
  final _descCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMeta();
    _load();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    try {
      final [banks, docs] = await Future.wait([
        _bankSvc.fetchRows().then((list) => list.where((a) => a.cmType == 'BANK' && a.isActive).toList()),
        _docSvc.fetchRows(),
      ]);
      setState(() {
        _bankAccounts = banks as List<CmBankAccount>;
        final all = docs as List<ModuleDocument>;
        _glDocTypes = all.where((d) => d.isDocType && d.sysModule == '01' && d.isActive).toList();
      });
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _svc.fetchReplenishments(
        pettyCashAccountId: widget.account.id,
        status: _statusFilter == 'All' ? null : _statusFilter,
        dateFrom: _dateFrom != null ? DateFormat('yyyy-MM-dd').format(_dateFrom!) : null,
        dateTo:   _dateTo != null   ? DateFormat('yyyy-MM-dd').format(_dateTo!)   : null,
      );
      setState(() {
        _replenishments = list;
        if (_selected != null) {
          final found = list.where((r) => r.id == _selected!.id).firstOrNull;
          if (found != null && found.id != _selected!.id) _loadDetailVouchers(found);
          _selected = found;
        }
      });
    } catch (e) {
      if (mounted) _err('โหลดรายการล้มเหลว: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDetailVouchers(CmPettyCashReplenishment rpl) async {
    setState(() { _detailVouchers = []; _loadingVouchers = true; });
    try {
      List<CmPettyCashVoucher> vouchers;
      if (rpl.isDraft) {
        vouchers = await _svc.fetchPendingVouchers(widget.account.id!);
      } else if (rpl.isPosted) {
        vouchers = await _svc.fetchReplenishedVouchers(rpl.id);
      } else {
        vouchers = [];
      }
      if (mounted) setState(() => _detailVouchers = vouchers);
    } catch (_) {
      if (mounted) setState(() => _detailVouchers = []);
    } finally {
      if (mounted) setState(() => _loadingVouchers = false);
    }
  }

  void _err(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  void _ok(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));

  void _selectRpl(CmPettyCashReplenishment r) {
    setState(() {
      _selected = r;
      _isCreating = false;
    });
    _loadDetailVouchers(r);
  }

  void _startCreate() {
    _formDate = DateTime.now();
    _srcBankId = null;
    _glDocId = null;
    _descCtrl.clear();
    setState(() {
      _selected = null;
      _isCreating = true;
      _detailVouchers = [];
    });
    // Pre-load pending vouchers to show what will be replenished
    _loadPendingForCreate();
  }

  Future<void> _loadPendingForCreate() async {
    setState(() => _loadingVouchers = true);
    try {
      final list = await _svc.fetchPendingVouchers(widget.account.id!);
      if (mounted) setState(() => _detailVouchers = list);
    } catch (_) {
      if (mounted) setState(() => _detailVouchers = []);
    } finally {
      if (mounted) setState(() => _loadingVouchers = false);
    }
  }

  void _cancelCreate() => setState(() {
    _isCreating = false;
    _detailVouchers = [];
  });

  Future<void> _save() async {
    if (_formDate == null) { _err('กรุณาระบุวันที่'); return; }
    if (_srcBankId == null) { _err('กรุณาเลือกบัญชีธนาคารต้นทาง'); return; }
    if (_detailVouchers.isEmpty) { _err('ไม่พบใบสำคัญ Approved ที่รอการเบิกจ่าย'); return; }

    final total = _detailVouchers.fold(0.0, (s, v) => s + v.amount);
    final body = {
      'replenishment_date':     DateFormat('yyyy-MM-dd').format(_formDate!),
      'petty_cash_account_id':  widget.account.id,
      'source_bank_account_id': _srcBankId,
      'total_amount':            total,
      'description':             _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'gl_doc_id':               _glDocId,
    };
    try {
      await _svc.createReplenishment(body);
      _ok('สร้างรายการเบิกจ่ายสำเร็จ');
      _cancelCreate();
      await _load();
    } catch (e) { _err('$e'); }
  }

  Future<void> _postGl(CmPettyCashReplenishment r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันบันทึก GL'),
        content: Text('บันทึก GL สำหรับรายการ ${r.replenishmentNo}?\n'
            'จะรวมใบสำคัญ Approved ทั้งหมดที่ยังไม่ได้เบิกจ่าย'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kTheme),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final result = await _svc.postReplenishment(r.id);
      _ok('บันทึก GL สำเร็จ (${result['gl_doc_no']}) ยอดรวม ${_fmtNum.format(result['total_amount'])} บาท');
      await _load();
    } catch (e) { _err('$e'); }
  }

  Future<void> _void(CmPettyCashReplenishment r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันการยกเลิก'),
        content: Text('ยกเลิกรายการ ${r.replenishmentNo}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _svc.voidReplenishment(r.id);
      _ok('ยกเลิกสำเร็จ');
      await _load();
    } catch (e) { _err('$e'); }
  }

  Future<void> _pickDate(bool isFrom) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _dateFrom : _dateTo) ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) { _dateFrom = picked; } else { _dateTo = picked; }
      });
      await _load();
    }
  }

  Future<void> _pickFormDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _formDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _formDate = picked);
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Posted': return Colors.green;
      case 'Voided': return Colors.grey;
      default:       return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Left list ─────────────────────────────────────────────────────
        SizedBox(
          width: 300,
          child: Column(
            children: [
              _buildFilterBar(),
              if (_loading) const LinearProgressIndicator(),
              Expanded(child: _buildList()),
              Padding(
                padding: const EdgeInsets.all(8),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kTheme,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 38),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('สร้างรายการเบิกจ่าย'),
                  onPressed: _startCreate,
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        // ── Right panel ───────────────────────────────────────────────────
        Expanded(
          child: _isCreating
              ? _buildCreateForm()
              : _selected != null
                  ? _buildDetail(_selected!)
                  : Center(
                      child: Text('เลือกรายการหรือกดสร้างใหม่',
                          style: TextStyle(color: Colors.blueGrey.shade400))),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _statusFilter,
            decoration: const InputDecoration(
                labelText: 'สถานะ', isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: 'All', child: Text('ทั้งหมด')),
              ...cmRplStatusOptions.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
            ],
            onChanged: (v) {
              if (v != null) { setState(() => _statusFilter = v); _load(); }
            },
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDate(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(_dateFrom != null ? _fmt.format(_dateFrom!) : 'จากวันที่',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDate(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(_dateTo != null ? _fmt.format(_dateTo!) : 'ถึงวันที่',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  ),
                ),
              ),
              if (_dateFrom != null || _dateTo != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () {
                    setState(() { _dateFrom = null; _dateTo = null; });
                    _load();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_replenishments.isEmpty) {
      return Center(child: Text('ไม่พบรายการ', style: TextStyle(color: Colors.grey.shade500)));
    }
    return ListView.builder(
      itemCount: _replenishments.length,
      itemBuilder: (_, i) {
        final r = _replenishments[i];
        final sel = _selected?.id == r.id;
        return InkWell(
          onTap: () => _selectRpl(r),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: sel ? _kTheme.withOpacity(0.1) : null,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.replenishmentNo,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('${_fmt.format(r.replenishmentDate)} • ${_fmtNum.format(r.totalAmount)} บาท',
                          style: const TextStyle(fontSize: 11)),
                      if (r.glDocNo != null)
                        Text('GL: ${r.glDocNo}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor(r.status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(cmRplStatusOptions[r.status] ?? r.status,
                      style: TextStyle(fontSize: 10, color: _statusColor(r.status))),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetail(CmPettyCashReplenishment r) {
    final total = _detailVouchers.fold(0.0, (s, v) => s + v.amount);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(r.replenishmentNo,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              _statusChip(r.status),
              const Spacer(),
            ],
          ),
          const Divider(height: 24),
          _infoRow('วันที่', _fmt.format(r.replenishmentDate)),
          _infoRow('บัญชีเงินสดย่อย',
              r.pettyCashAccountCode != null
                  ? '${r.pettyCashAccountCode} ${r.pettyCashAccountName}'
                  : '-'),
          _infoRow('บัญชีธนาคารต้นทาง',
              r.sourceBankAccountId != null
                  ? '${r.sourceBankAccountCode} ${r.sourceBankAccountName}'
                  : '-'),
          _infoRow('รายละเอียด', r.description ?? '-'),
          _infoRow('ยอดรวม', '${_fmtNum.format(r.totalAmount)} บาท', highlight: true),
          if (r.glDocNo != null) _infoRow('เลขที่เอกสาร GL', r.glDocNo!),
          const SizedBox(height: 16),
          // Vouchers list
          Row(
            children: [
              Text(
                r.isDraft
                    ? 'ใบสำคัญ Approved รอการเบิกจ่าย'
                    : 'ใบสำคัญที่เบิกจ่ายในรายการนี้',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              if (_loadingVouchers) ...[
                const SizedBox(width: 8),
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ],
          ),
          const SizedBox(height: 6),
          if (_detailVouchers.isEmpty && !_loadingVouchers)
            Text('ไม่พบใบสำคัญ',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12))
          else
            ...(_detailVouchers.map((v) => _voucherSummaryRow(v))),
          if (_detailVouchers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('รวม: ${_fmtNum.format(total)} บาท',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: _kTheme)),
                ],
              ),
            ),
          const SizedBox(height: 20),
          // Action buttons
          Wrap(
            spacing: 8,
            children: [
              if (r.isDraft) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: _kTheme),
                  icon: const Icon(Icons.receipt_long, size: 16),
                  label: const Text('บันทึก GL', style: TextStyle(color: Colors.white)),
                  onPressed: () => _postGl(r),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  icon: const Icon(Icons.cancel, size: 16),
                  label: const Text('ยกเลิก'),
                  onPressed: () => _void(r),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreateForm() {
    final total = _detailVouchers.fold(0.0, (s, v) => s + v.amount);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('สร้างรายการเบิกจ่ายใหม่',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Divider(height: 20),
          // Date
          GestureDetector(
            onTap: _pickFormDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                  labelText: 'วันที่ *', border: OutlineInputBorder(), isDense: true),
              child: Text(_formDate != null ? _fmt.format(_formDate!) : 'เลือกวันที่',
                  style: TextStyle(
                      color: _formDate != null ? null : Colors.grey.shade500)),
            ),
          ),
          const SizedBox(height: 12),
          // Source bank account
          DropdownButtonFormField<int>(
            value: _srcBankId,
            decoration: const InputDecoration(
                labelText: 'บัญชีธนาคารต้นทาง *', border: OutlineInputBorder(), isDense: true),
            items: _bankAccounts.map((a) => DropdownMenuItem(
              value: a.id,
              child: Text('${a.accountCode} ${a.accountNameTh}', overflow: TextOverflow.ellipsis),
            )).toList(),
            onChanged: (v) => setState(() => _srcBankId = v),
          ),
          const SizedBox(height: 12),
          // GL Doc type
          DropdownButtonFormField<int>(
            value: _glDocId,
            decoration: const InputDecoration(
                labelText: 'ประเภทเอกสาร GL', border: OutlineInputBorder(), isDense: true),
            items: [
              const DropdownMenuItem<int>(value: null, child: Text('(ไม่ระบุ)')),
              ..._glDocTypes.map((d) => DropdownMenuItem(
                value: d.id,
                child: Text('${d.docCode} ${d.docNameThai}', overflow: TextOverflow.ellipsis),
              )),
            ],
            onChanged: (v) => setState(() => _glDocId = v),
          ),
          const SizedBox(height: 12),
          // Description
          TextField(
            controller: _descCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
                labelText: 'รายละเอียด', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 16),
          // Pending vouchers
          Row(
            children: [
              const Text('ใบสำคัญที่จะรวมในการเบิกจ่าย:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              if (_loadingVouchers) ...[
                const SizedBox(width: 8),
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ],
          ),
          const SizedBox(height: 6),
          if (_detailVouchers.isEmpty && !_loadingVouchers)
            Text('ไม่พบใบสำคัญ Approved ที่รอการเบิกจ่าย',
                style: TextStyle(color: Colors.orange.shade700, fontSize: 12))
          else
            ...(_detailVouchers.map((v) => _voucherSummaryRow(v))),
          if (_detailVouchers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('ยอดรวม: ${_fmtNum.format(total)} บาท',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: _kTheme)),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _kTheme),
                onPressed: _save,
                child: const Text('บันทึก Draft', style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _cancelCreate,
                child: const Text('ยกเลิก'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _voucherSummaryRow(CmPettyCashVoucher v) => Container(
    margin: const EdgeInsets.symmetric(vertical: 2),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300)),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(v.voucherNo,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              if (v.payeeName != null)
                Text(v.payeeName!, style: const TextStyle(fontSize: 11)),
              if (v.expenseGlAccountCode != null)
                Text('${v.expenseGlAccountCode} ${v.expenseGlAccountName ?? ''}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            ],
          ),
        ),
        Text(_fmtNum.format(v.amount),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        const Text('บาท', style: TextStyle(fontSize: 11)),
      ],
    ),
  );

  Widget _statusChip(String s) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
        color: _statusColor(s).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12)),
    child: Text(cmRplStatusOptions[s] ?? s,
        style: TextStyle(fontSize: 12, color: _statusColor(s), fontWeight: FontWeight.bold)),
  );

  Widget _infoRow(String label, String value, {bool highlight = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 160,
          child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                  color: highlight ? _kTheme : null)),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// GL Account Picker Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _GlAccountPickerDialog extends StatefulWidget {
  final List<Account> accounts;
  const _GlAccountPickerDialog({required this.accounts});
  @override
  State<_GlAccountPickerDialog> createState() => _GlAccountPickerDialogState();
}

class _GlAccountPickerDialogState extends State<_GlAccountPickerDialog> {
  final _search = TextEditingController();
  List<Account> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.accounts;
    _search.addListener(_filter);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _filter() {
    final q = _search.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.accounts
          : widget.accounts
              .where((a) =>
                  a.accountCode.toLowerCase().contains(q) ||
                  a.accountNameThai.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 480,
        height: 500,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('เลือกบัญชีค่าใช้จ่าย',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'ค้นหารหัสหรือชื่อบัญชี...',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                    border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final a = _filtered[i];
                  return ListTile(
                    dense: true,
                    title: Text('${a.accountCode} — ${a.accountNameThai}',
                        style: const TextStyle(fontSize: 13)),
                    onTap: () => Navigator.pop(context, a),
                  );
                },
              ),
            ),
            const Divider(),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
