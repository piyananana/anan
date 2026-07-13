// lib/ar/screens/ar_gl_account_setup_screen.dart
import 'package:flutter/material.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/services/sa_module_document_service.dart';
import '../models/ar_gl_account_setup.dart';
import '../services/ar_gl_account_setup_service.dart';

class ArGlAccountSetupScreen extends StatefulWidget {
  const ArGlAccountSetupScreen({super.key});

  @override
  State<ArGlAccountSetupScreen> createState() => _ArGlAccountSetupScreenState();
}

class _ArGlAccountSetupScreenState extends State<ArGlAccountSetupScreen>
    with AutomaticKeepAliveClientMixin {
  final ArGlAccountSetupService _svc      = ArGlAccountSetupService();
  final ModuleDocumentService   _docSvc   = ModuleDocumentService();
  final AccountService          _acctSvc  = AccountService();

  List<ArGlAccountSetup> _rows    = [];
  List<Account>          _accounts = [];
  List<ModuleDocument>   _glDocs  = [];   // GL doc types สำหรับ picker

  bool   _isLoading          = true;
  String _selectedDocCode    = '';
  bool   _isDraggingDivider  = false;
  bool   _isLeftPanelExpanded = true;
  double _leftPanelWidth     = 320.0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _svc.fetchRows(),
        _acctSvc.fetchRows(),
        _docSvc.fetchRows(),
      ]);
      setState(() {
        _rows     = results[0] as List<ArGlAccountSetup>;
        _accounts = (results[1] as List<Account>)
            .where((a) => a.isActive && a.isNormalAccount).toList()
          ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
        _glDocs   = (results[2] as List<ModuleDocument>)
            .where((d) => d.isDocType && d.sysModule == '01' && d.isActive).toList()
          ..sort((a, b) => a.docCode.compareTo(b.docCode));
        _isLoading = false;
        // เลือก row แรกอัตโนมัติ
        if (_rows.isNotEmpty && _selectedDocCode.isEmpty) {
          _selectedDocCode = _rows.first.docCode;
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดข้อมูลล้มเหลว: $e')));
    }
  }

  ArGlAccountSetup? get _selected =>
      _rows.where((r) => r.docCode == _selectedDocCode).firstOrNull;

  // ── Account picker dialog ─────────────────────────────────────────────────
  Future<Account?> _pickAccount({String title = 'เลือกบัญชี GL'}) async {
    final searchCtrl = TextEditingController();
    List<Account> filtered = List.from(_accounts);
    Account? picked;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        void doFilter(String q) {
          setDlg(() {
            final lq = q.toLowerCase();
            filtered = q.isEmpty
                ? List.from(_accounts)
                : _accounts.where((a) =>
                    a.accountCode.toLowerCase().contains(lq) ||
                    a.accountNameThai.toLowerCase().contains(lq)).toList();
          });
        }

        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 520, height: 420,
            child: Column(children: [
              TextField(
                controller: searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'ค้นหา รหัส / ชื่อบัญชี',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  isDense: true,
                ),
                onChanged: doFilter,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final a = filtered[i];
                    return ListTile(
                      dense: true,
                      title: Text('${a.accountCode}  ${a.accountNameThai}',
                          style: const TextStyle(fontSize: 13)),
                      onTap: () { picked = a; Navigator.of(ctx).pop(); },
                    );
                  },
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('ยกเลิก')),
          ],
        );
      }),
    );
    searchCtrl.dispose();
    return picked;
  }

  // ── GL Doc picker ─────────────────────────────────────────────────────────
  Future<ModuleDocument?> _pickGlDoc() async {
    final searchCtrl = TextEditingController();
    List<ModuleDocument> filtered = List.from(_glDocs);
    ModuleDocument? picked;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        return AlertDialog(
          title: const Text('เลือกประเภทเอกสาร GL'),
          content: SizedBox(
            width: 480, height: 380,
            child: Column(children: [
              TextField(
                controller: searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'ค้นหา',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  isDense: true,
                ),
                onChanged: (q) {
                  setDlg(() {
                    final lq = q.toLowerCase();
                    filtered = q.isEmpty
                        ? List.from(_glDocs)
                        : _glDocs.where((d) =>
                            d.docCode.toLowerCase().contains(lq) ||
                            d.docNameThai.toLowerCase().contains(lq)).toList();
                  });
                },
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final d = filtered[i];
                    return ListTile(
                      dense: true,
                      title: Text('${d.docCode}  ${d.docNameThai}',
                          style: const TextStyle(fontSize: 13)),
                      onTap: () { picked = d; Navigator.of(ctx).pop(); },
                    );
                  },
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('ยกเลิก')),
          ],
        );
      }),
    );
    searchCtrl.dispose();
    return picked;
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  Future<void> _onSave(ArGlAccountSetup updated) async {
    try {
      final saved = await _svc.upsertRow(updated);
      // อัปเดต row ใน list
      setState(() {
        final idx = _rows.indexWhere((r) => r.docCode == saved.docCode);
        if (idx >= 0) _rows[idx] = saved; else _rows.add(saved);
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกสำเร็จ')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('บันทึกล้มเหลว: $e')));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'โหลดใหม่',
            onPressed: _loadAll,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (ctx, constraints) {
              final maxLeft =
                  (constraints.maxWidth - 36 - 5 - 400).clamp(100.0, double.infinity);
              return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Collapse toggle
                Container(
                  width: 36,
                  color: Colors.teal[700],
                  child: IconButton(
                    icon: Icon(
                      _isLeftPanelExpanded ? Icons.filter_list_off : Icons.filter_list,
                      color: Colors.white, size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () =>
                        setState(() => _isLeftPanelExpanded = !_isLeftPanelExpanded),
                    tooltip: _isLeftPanelExpanded ? 'ย่อรายการ' : 'ขยายรายการ',
                  ),
                ),
                // Left: doc_code list
                AnimatedContainer(
                  duration: _isDraggingDivider
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  width: _isLeftPanelExpanded ? _leftPanelWidth : 0,
                  child: ClipRect(
                    child: OverflowBox(
                      maxWidth: _leftPanelWidth, minWidth: _leftPanelWidth,
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
                            (_leftPanelWidth + d.delta.dx).clamp(200.0, maxLeft);
                      }),
                      onHorizontalDragEnd: (_) =>
                          setState(() => _isDraggingDivider = false),
                      child: Container(width: 5, color: Colors.grey[400]),
                    ),
                  ),
                // Right: setup form
                Expanded(
                  child: _selected == null
                      ? const Center(child: Text('เลือกประเภทเอกสาร AR ด้านซ้าย'))
                      : _ArGlSetupForm(
                          key: ValueKey(_selected!.docCode),
                          setup: _selected!,
                          accounts: _accounts,
                          glDocs: _glDocs,
                          onPickAccount: _pickAccount,
                          onPickGlDoc: _pickGlDoc,
                          onSave: _onSave,
                        ),
                ),
              ]);
            }),
    );
  }

  Widget _buildLeftPanel() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: _rows.length,
      itemBuilder: (ctx, i) {
        final row = _rows[i];
        final isSelected = row.docCode == _selectedDocCode;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: isSelected ? Colors.teal.shade50 : null,
          shape: isSelected
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.teal.shade400, width: 1.5),
                )
              : null,
          child: ListTile(
            dense: true,
            onTap: () => setState(() => _selectedDocCode = row.docCode),
            leading: Icon(
              row.isConfigured ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: row.isConfigured ? Colors.green : Colors.grey,
            ),
            title: Text(
              row.docCode,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? Colors.teal[800] : null,
              ),
            ),
            subtitle: Text(
              row.docNameThai ?? '—',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              overflow: TextOverflow.ellipsis,
            ),
            trailing: isSelected
                ? Icon(Icons.chevron_right, size: 18, color: Colors.teal[700])
                : null,
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Form widget (Stateful, แยกออกมาเพื่อให้ key ทำงานได้เมื่อ doc_code เปลี่ยน)
// ═══════════════════════════════════════════════════════════════════════════
class _ArGlSetupForm extends StatefulWidget {
  final ArGlAccountSetup setup;
  final List<Account> accounts;
  final List<ModuleDocument> glDocs;
  final Future<Account?> Function({String title}) onPickAccount;
  final Future<ModuleDocument?> Function() onPickGlDoc;
  final Future<void> Function(ArGlAccountSetup) onSave;

  const _ArGlSetupForm({
    super.key,
    required this.setup,
    required this.accounts,
    required this.glDocs,
    required this.onPickAccount,
    required this.onPickGlDoc,
    required this.onSave,
  });

  @override
  State<_ArGlSetupForm> createState() => _ArGlSetupFormState();
}

class _ArGlSetupFormState extends State<_ArGlSetupForm> {
  // ── ค่าปัจจุบันในฟอร์ม ─────────────────────────────────────────────────
  int?    _arAccountId;        String? _arAccountCode;        String? _arAccountName;
  int?    _revenueAccountId;   String? _revenueAccountCode;   String? _revenueAccountName;
  int?    _vatOutputAccountId; String? _vatOutputAccountCode; String? _vatOutputAccountName;
  int?    _discountAccountId;  String? _discountAccountCode;  String? _discountAccountName;
  int?    _advanceAccountId;   String? _advanceAccountCode;   String? _advanceAccountName;
  int?    _cashAccountId;      String? _cashAccountCode;      String? _cashAccountName;
  int?    _checkAccountId;           String? _checkAccountCode;           String? _checkAccountName;
  int?    _transferAccountId;        String? _transferAccountCode;        String? _transferAccountName;
  int?    _creditCardAccountId;      String? _creditCardAccountCode;      String? _creditCardAccountName;
  int?    _debitCardAccountId;       String? _debitCardAccountCode;       String? _debitCardAccountName;
  int?    _qrCodeAccountId;          String? _qrCodeAccountCode;          String? _qrCodeAccountName;
  int?    _mobileBankingAccountId;   String? _mobileBankingAccountCode;   String? _mobileBankingAccountName;
  int?    _billOfExchangeAccountId;  String? _billOfExchangeAccountCode;  String? _billOfExchangeAccountName;
  int?    _whtAccountId;       String? _whtAccountCode;       String? _whtAccountName;
  int?    _fxGainAccountId;            String? _fxGainAccountCode;            String? _fxGainAccountName;
  int?    _fxLossAccountId;            String? _fxLossAccountCode;            String? _fxLossAccountName;
  int?    _vatPendingOutputAccountId;  String? _vatPendingOutputAccountCode;  String? _vatPendingOutputAccountName;
  int?    _glDocId;                    String? _glDocCode;                    String? _glDocName;
  bool    _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadFromSetup(widget.setup);
  }

  void _loadFromSetup(ArGlAccountSetup s) {
    _arAccountId        = s.arAccountId;        _arAccountCode        = s.arAccountCode;        _arAccountName        = s.arAccountName;
    _revenueAccountId   = s.revenueAccountId;   _revenueAccountCode   = s.revenueAccountCode;   _revenueAccountName   = s.revenueAccountName;
    _vatOutputAccountId = s.vatOutputAccountId; _vatOutputAccountCode = s.vatOutputAccountCode; _vatOutputAccountName = s.vatOutputAccountName;
    _discountAccountId  = s.discountAccountId;  _discountAccountCode  = s.discountAccountCode;  _discountAccountName  = s.discountAccountName;
    _advanceAccountId   = s.advanceAccountId;   _advanceAccountCode   = s.advanceAccountCode;   _advanceAccountName   = s.advanceAccountName;
    _cashAccountId      = s.cashAccountId;      _cashAccountCode      = s.cashAccountCode;      _cashAccountName      = s.cashAccountName;
    _checkAccountId          = s.checkAccountId;          _checkAccountCode          = s.checkAccountCode;          _checkAccountName          = s.checkAccountName;
    _transferAccountId       = s.transferAccountId;       _transferAccountCode       = s.transferAccountCode;       _transferAccountName       = s.transferAccountName;
    _creditCardAccountId     = s.creditCardAccountId;     _creditCardAccountCode     = s.creditCardAccountCode;     _creditCardAccountName     = s.creditCardAccountName;
    _debitCardAccountId      = s.debitCardAccountId;      _debitCardAccountCode      = s.debitCardAccountCode;      _debitCardAccountName      = s.debitCardAccountName;
    _qrCodeAccountId         = s.qrCodeAccountId;         _qrCodeAccountCode         = s.qrCodeAccountCode;         _qrCodeAccountName         = s.qrCodeAccountName;
    _mobileBankingAccountId  = s.mobileBankingAccountId;  _mobileBankingAccountCode  = s.mobileBankingAccountCode;  _mobileBankingAccountName  = s.mobileBankingAccountName;
    _billOfExchangeAccountId = s.billOfExchangeAccountId; _billOfExchangeAccountCode = s.billOfExchangeAccountCode; _billOfExchangeAccountName = s.billOfExchangeAccountName;
    _whtAccountId       = s.whtAccountId;       _whtAccountCode       = s.whtAccountCode;       _whtAccountName       = s.whtAccountName;
    _fxGainAccountId              = s.fxGainAccountId;              _fxGainAccountCode              = s.fxGainAccountCode;              _fxGainAccountName              = s.fxGainAccountName;
    _fxLossAccountId              = s.fxLossAccountId;              _fxLossAccountCode              = s.fxLossAccountCode;              _fxLossAccountName              = s.fxLossAccountName;
    _vatPendingOutputAccountId    = s.vatPendingOutputAccountId;    _vatPendingOutputAccountCode    = s.vatPendingOutputAccountCode;    _vatPendingOutputAccountName    = s.vatPendingOutputAccountName;
    _glDocId                      = s.glDocId;                      _glDocCode                      = s.glDocCode;                      _glDocName                      = s.glDocName;
  }

  // helper: ตรวจว่า field ควรแสดงตาม sys_doc_type
  String get _sdt => widget.setup.sysDocType ?? '';
  bool get _showAr       => !['60','65'].contains(_sdt);                      // ทุก doc type ยกเว้น Advance/Refund
  bool get _showRevenue  => ['10','30','35','50','55'].contains(_sdt);        // Invoice, DN, DN+Bill, CN, CN+Bill
  bool get _showVat      => _sdt != '';                                       // ทุก doc type
  bool get _showDiscount => ['10','30','35'].contains(_sdt);                  // Invoice, DN, DN+Bill
  bool get _showAdvance  => ['60','65','80'].contains(_sdt);                  // Advance, Refund, Receipt
  bool get _showCash     => ['60','65','80'].contains(_sdt);                  // Advance, Refund, Receipt
  bool get _showWht      => _sdt == '80';                                     // Receipt เท่านั้น
  bool get _showFx       => _sdt == '80';                                     // Receipt เท่านั้น

  // ── Account picker helper ─────────────────────────────────────────────────
  Future<void> _pick(String title, void Function(Account) onPicked) async {
    final a = await widget.onPickAccount(title: title);
    if (a != null) setState(() => onPicked(a));
  }

  void _clearAccount(void Function() clear) => setState(clear);

  // ── Build account field ───────────────────────────────────────────────────
  Widget _accountField({
    required String label,
    required int? accountId,
    required String? accountCode,
    required String? accountName,
    required void Function(Account) onPick,
    required VoidCallback onClear,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _pick(label, onPick),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: required ? '$label *' : label,
            border: const OutlineInputBorder(),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
              if (accountId != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onClear,
                ),
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.account_tree_outlined, size: 18),
              ),
            ]),
          ),
          child: Text(
            accountId != null ? '$accountCode  $accountName' : '— ไม่ระบุ —',
            style: TextStyle(
              fontSize: 13,
              color: accountId != null ? null : Colors.grey.shade500,
            ),
          ),
        ),
      ),
    );
  }

  // ── Journal preview ───────────────────────────────────────────────────────
  Widget _buildJournalPreview() {
    final lines = <_JournalLine>[];
    switch (_sdt) {
      case '10':
      case '30':
      case '35':
        if (_arAccountId != null)       lines.add(_JournalLine('Dr', _arAccountCode!, _arAccountName!));
        if (_revenueAccountId != null)  lines.add(_JournalLine('  Cr', _revenueAccountCode!, '$_revenueAccountName (ต่อ line)'));
        if (_vatOutputAccountId != null)lines.add(_JournalLine('  Cr', _vatOutputAccountCode!, _vatOutputAccountName!));
        if (_discountAccountId != null) lines.add(_JournalLine('Dr', _discountAccountCode!, '$_discountAccountName (ถ้ามีส่วนลด)'));
        break;
      case '50':
      case '55':
        if (_revenueAccountId != null)  lines.add(_JournalLine('Dr', _revenueAccountCode!, _revenueAccountName!));
        if (_vatOutputAccountId != null)lines.add(_JournalLine('Dr', _vatOutputAccountCode!, _vatOutputAccountName!));
        if (_arAccountId != null)       lines.add(_JournalLine('  Cr', _arAccountCode!, _arAccountName!));
        break;
      case '60':
        if (_cashAccountId != null)     lines.add(_JournalLine('Dr', _cashAccountCode!, _cashAccountName!));
        if (_advanceAccountId != null)  lines.add(_JournalLine('  Cr', _advanceAccountCode!, _advanceAccountName!));
        if (_vatOutputAccountId != null)lines.add(_JournalLine('  Cr', _vatOutputAccountCode!, '$_vatOutputAccountName (ถ้ามี VAT)'));
        break;
      case '65':
        if (_advanceAccountId != null)  lines.add(_JournalLine('Dr', _advanceAccountCode!, _advanceAccountName!));
        if (_cashAccountId != null)     lines.add(_JournalLine('  Cr', _cashAccountCode!, _cashAccountName!));
        break;
      case '80':
        if (_cashAccountId != null)              lines.add(_JournalLine('Dr', _cashAccountCode!, _cashAccountName!));
        if (_whtAccountId != null)               lines.add(_JournalLine('Dr', _whtAccountCode!, '$_whtAccountName (WHT)'));
        if (_advanceAccountId != null)           lines.add(_JournalLine('Dr', _advanceAccountCode!, '$_advanceAccountName (ตัดมัดจำ)'));
        if (_fxLossAccountId != null)            lines.add(_JournalLine('Dr', _fxLossAccountCode!, '$_fxLossAccountName (ขาดทุน FX)'));
        if (_vatPendingOutputAccountId != null)  lines.add(_JournalLine('Dr', _vatPendingOutputAccountCode!, '$_vatPendingOutputAccountName (รับรู้ VAT รอตัด)'));
        if (_arAccountId != null)                lines.add(_JournalLine('  Cr', _arAccountCode!, _arAccountName!));
        if (_vatOutputAccountId != null)         lines.add(_JournalLine('  Cr', _vatOutputAccountCode!, '$_vatOutputAccountName (VAT รอตัด ที่รับรู้)'));
        if (_fxGainAccountId != null)            lines.add(_JournalLine('  Cr', _fxGainAccountCode!, '$_fxGainAccountName (กำไร FX)'));
        break;
    }
    if (lines.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ตัวอย่าง Journal Entry',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.blueGrey.shade700)),
          const SizedBox(height: 6),
          ...lines.map((l) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(children: [
              SizedBox(
                width: 36,
                child: Text(l.drCr,
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: l.drCr.trim() == 'Dr' ? Colors.blue.shade700 : Colors.green.shade700,
                        fontWeight: FontWeight.bold)),
              ),
              SizedBox(width: 72, child: Text(l.code, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
              Expanded(child: Text(l.name, style: const TextStyle(fontSize: 12))),
            ]),
          )),
        ],
      ),
    );
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    setState(() => _isSaving = true);
    try {
      final updated = ArGlAccountSetup(
        docCode:             widget.setup.docCode,
        sysDocType:          widget.setup.sysDocType,
        docNameThai:         widget.setup.docNameThai,
        arAccountId:         _arAccountId,        arAccountCode:        _arAccountCode,        arAccountName:        _arAccountName,
        revenueAccountId:    _revenueAccountId,   revenueAccountCode:   _revenueAccountCode,   revenueAccountName:   _revenueAccountName,
        vatOutputAccountId:  _vatOutputAccountId, vatOutputAccountCode: _vatOutputAccountCode, vatOutputAccountName: _vatOutputAccountName,
        discountAccountId:   _discountAccountId,  discountAccountCode:  _discountAccountCode,  discountAccountName:  _discountAccountName,
        advanceAccountId:    _advanceAccountId,   advanceAccountCode:   _advanceAccountCode,   advanceAccountName:   _advanceAccountName,
        cashAccountId:       _cashAccountId,      cashAccountCode:      _cashAccountCode,      cashAccountName:      _cashAccountName,
        checkAccountId:          _checkAccountId,          checkAccountCode:          _checkAccountCode,          checkAccountName:          _checkAccountName,
        transferAccountId:       _transferAccountId,       transferAccountCode:       _transferAccountCode,       transferAccountName:       _transferAccountName,
        creditCardAccountId:     _creditCardAccountId,     creditCardAccountCode:     _creditCardAccountCode,     creditCardAccountName:     _creditCardAccountName,
        debitCardAccountId:      _debitCardAccountId,      debitCardAccountCode:      _debitCardAccountCode,      debitCardAccountName:      _debitCardAccountName,
        qrCodeAccountId:         _qrCodeAccountId,         qrCodeAccountCode:         _qrCodeAccountCode,         qrCodeAccountName:         _qrCodeAccountName,
        mobileBankingAccountId:  _mobileBankingAccountId,  mobileBankingAccountCode:  _mobileBankingAccountCode,  mobileBankingAccountName:  _mobileBankingAccountName,
        billOfExchangeAccountId: _billOfExchangeAccountId, billOfExchangeAccountCode: _billOfExchangeAccountCode, billOfExchangeAccountName: _billOfExchangeAccountName,
        whtAccountId:        _whtAccountId,       whtAccountCode:       _whtAccountCode,       whtAccountName:       _whtAccountName,
        fxGainAccountId:              _fxGainAccountId,             fxGainAccountCode:             _fxGainAccountCode,            fxGainAccountName:             _fxGainAccountName,
        fxLossAccountId:              _fxLossAccountId,             fxLossAccountCode:             _fxLossAccountCode,            fxLossAccountName:             _fxLossAccountName,
        vatPendingOutputAccountId:    _vatPendingOutputAccountId,   vatPendingOutputAccountCode:   _vatPendingOutputAccountCode,  vatPendingOutputAccountName:   _vatPendingOutputAccountName,
        glDocId:                      _glDocId,                     glDocCode:                     _glDocCode,                    glDocName:                     _glDocName,
      );
      await widget.onSave(updated);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final s = widget.setup;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Title
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.docCode,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              // Text('${s.docNameThai ?? ''}  •  ${s.sysDocTypeName}',
              Text(s.docNameThai ?? '',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ]),
          ),
          if (s.isConfigured)
            Chip(
              label: const Text('มีการตั้งค่า', style: TextStyle(fontSize: 11)),
              backgroundColor: Colors.green.shade100,
              side: const BorderSide(color: Colors.transparent),
              visualDensity: VisualDensity.compact,
            ),
        ]),
        const SizedBox(height: 16),

        // ── ประเภทเอกสาร GL ──────────────────────────────────────────────
        _SectionHeader(title: 'ประเภทเอกสาร GL (สำหรับ Post)'),
        InkWell(
          onTap: () async {
            final d = await widget.onPickGlDoc();
            if (d != null) setState(() {
              _glDocId   = d.id;
              _glDocCode = d.docCode;
              _glDocName = d.docNameThai;
            });
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'ประเภทเอกสาร GL',
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                if (_glDocId != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() { _glDocId = null; _glDocCode = null; _glDocName = null; }),
                  ),
                const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.description_outlined, size: 18)),
              ]),
            ),
            child: Text(
              _glDocId != null ? '$_glDocCode  $_glDocName' : '— ไม่ระบุ —',
              style: TextStyle(fontSize: 13, color: _glDocId != null ? null : Colors.grey.shade500),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── รหัสบัญชี (แสดงตาม sys_doc_type) ────────────────────────────
        _SectionHeader(title: 'รหัสบัญชี'),

        if (_showAr)
          _accountField(
            label: 'ลูกหนี้การค้า (AR Account) *ถ้าไม่ระบุ จะใช้รหัสบัญชีจากกลุ่มลูกหนี้หรือลูกหนี้โดยตรงแทน',
            accountId: _arAccountId, accountCode: _arAccountCode, accountName: _arAccountName,
            onPick: (a) { _arAccountId = a.id; _arAccountCode = a.accountCode; _arAccountName = a.accountNameThai; },
            onClear: () => _clearAccount(() { _arAccountId = null; _arAccountCode = null; _arAccountName = null; }),
          ),

        if (_showRevenue)
          _accountField(
            label: 'รายได้ขาย (Revenue — default)',
            accountId: _revenueAccountId, accountCode: _revenueAccountCode, accountName: _revenueAccountName,
            onPick: (a) { _revenueAccountId = a.id; _revenueAccountCode = a.accountCode; _revenueAccountName = a.accountNameThai; },
            onClear: () => _clearAccount(() { _revenueAccountId = null; _revenueAccountCode = null; _revenueAccountName = null; }),
          ),

        if (_showVat) ...[
          _accountField(
            label: 'ภาษีขาย (VAT Output)',
            accountId: _vatOutputAccountId, accountCode: _vatOutputAccountCode, accountName: _vatOutputAccountName,
            onPick: (a) { _vatOutputAccountId = a.id; _vatOutputAccountCode = a.accountCode; _vatOutputAccountName = a.accountNameThai; },
            onClear: () => _clearAccount(() { _vatOutputAccountId = null; _vatOutputAccountCode = null; _vatOutputAccountName = null; }),
          ),
          _accountField(
            label: 'ภาษีขายรอตัดบัญชี (Deferred VAT Output)',
            accountId: _vatPendingOutputAccountId, accountCode: _vatPendingOutputAccountCode, accountName: _vatPendingOutputAccountName,
            onPick: (a) { _vatPendingOutputAccountId = a.id; _vatPendingOutputAccountCode = a.accountCode; _vatPendingOutputAccountName = a.accountNameThai; },
            onClear: () => _clearAccount(() { _vatPendingOutputAccountId = null; _vatPendingOutputAccountCode = null; _vatPendingOutputAccountName = null; }),
          ),
        ],

        if (_showDiscount)
          _accountField(
            label: 'ส่วนลดจ่าย (Discount)',
            accountId: _discountAccountId, accountCode: _discountAccountCode, accountName: _discountAccountName,
            onPick: (a) { _discountAccountId = a.id; _discountAccountCode = a.accountCode; _discountAccountName = a.accountNameThai; },
            onClear: () => _clearAccount(() { _discountAccountId = null; _discountAccountCode = null; _discountAccountName = null; }),
          ),

        if (_showAdvance)
          _accountField(
            label: 'เงินมัดจำรับ (Advance)',
            accountId: _advanceAccountId, accountCode: _advanceAccountCode, accountName: _advanceAccountName,
            onPick: (a) { _advanceAccountId = a.id; _advanceAccountCode = a.accountCode; _advanceAccountName = a.accountNameThai; },
            onClear: () => _clearAccount(() { _advanceAccountId = null; _advanceAccountCode = null; _advanceAccountName = null; }),
          ),

        if (_showCash)
          _accountField(
            label: 'เงินสด / ธนาคาร (Cash/Bank — default)',
            accountId: _cashAccountId, accountCode: _cashAccountCode, accountName: _cashAccountName,
            onPick: (a) { _cashAccountId = a.id; _cashAccountCode = a.accountCode; _cashAccountName = a.accountNameThai; },
            onClear: () => _clearAccount(() { _cashAccountId = null; _cashAccountCode = null; _cashAccountName = null; }),
          ),

        if (_showCash) ...[
          _SectionHeader(title: 'บัญชีรับชำระตามวิธีชำระ (ถ้าไม่ระบุ จะใช้บัญชีจากโมดูล CM หรือบัญชี Cash/Bank ด้านบน)'),
          _accountField(label: 'เช็ค (CHECK)', accountId: _checkAccountId, accountCode: _checkAccountCode, accountName: _checkAccountName,
            onPick: (a) { _checkAccountId = a.id; _checkAccountCode = a.accountCode; _checkAccountName = a.accountNameThai; },
            onClear: () => _clearAccount(() { _checkAccountId = null; _checkAccountCode = null; _checkAccountName = null; })),
          _accountField(label: 'โอนเงิน (TRANSFER)', accountId: _transferAccountId, accountCode: _transferAccountCode, accountName: _transferAccountName,
            onPick: (a) { _transferAccountId = a.id; _transferAccountCode = a.accountCode; _transferAccountName = a.accountNameThai; },
            onClear: () => _clearAccount(() { _transferAccountId = null; _transferAccountCode = null; _transferAccountName = null; })),
          _accountField(label: 'บัตรเครดิต (CREDIT CARD)', accountId: _creditCardAccountId, accountCode: _creditCardAccountCode, accountName: _creditCardAccountName,
            onPick: (a) { _creditCardAccountId = a.id; _creditCardAccountCode = a.accountCode; _creditCardAccountName = a.accountNameThai; },
            onClear: () => _clearAccount(() { _creditCardAccountId = null; _creditCardAccountCode = null; _creditCardAccountName = null; })),
          _accountField(label: 'บัตรเดบิต (DEBIT CARD)', accountId: _debitCardAccountId, accountCode: _debitCardAccountCode, accountName: _debitCardAccountName,
            onPick: (a) { _debitCardAccountId = a.id; _debitCardAccountCode = a.accountCode; _debitCardAccountName = a.accountNameThai; },
            onClear: () => _clearAccount(() { _debitCardAccountId = null; _debitCardAccountCode = null; _debitCardAccountName = null; })),
          _accountField(label: 'QR Code / พร้อมเพย์ (QR_CODE)', accountId: _qrCodeAccountId, accountCode: _qrCodeAccountCode, accountName: _qrCodeAccountName,
            onPick: (a) { _qrCodeAccountId = a.id; _qrCodeAccountCode = a.accountCode; _qrCodeAccountName = a.accountNameThai; },
            onClear: () => _clearAccount(() { _qrCodeAccountId = null; _qrCodeAccountCode = null; _qrCodeAccountName = null; })),
          _accountField(label: 'Mobile Banking / Internet Banking (MOBILE_BANKING)', accountId: _mobileBankingAccountId, accountCode: _mobileBankingAccountCode, accountName: _mobileBankingAccountName,
            onPick: (a) { _mobileBankingAccountId = a.id; _mobileBankingAccountCode = a.accountCode; _mobileBankingAccountName = a.accountNameThai; },
            onClear: () => _clearAccount(() { _mobileBankingAccountId = null; _mobileBankingAccountCode = null; _mobileBankingAccountName = null; })),
          _accountField(label: 'ตั๋วแลกเงิน (BILL OF EXCHANGE)', accountId: _billOfExchangeAccountId, accountCode: _billOfExchangeAccountCode, accountName: _billOfExchangeAccountName,
            onPick: (a) { _billOfExchangeAccountId = a.id; _billOfExchangeAccountCode = a.accountCode; _billOfExchangeAccountName = a.accountNameThai; },
            onClear: () => _clearAccount(() { _billOfExchangeAccountId = null; _billOfExchangeAccountCode = null; _billOfExchangeAccountName = null; })),
        ],

        if (_showWht)
          _accountField(
            label: 'ภาษีหัก ณ ที่จ่าย (WHT — default)',
            accountId: _whtAccountId, accountCode: _whtAccountCode, accountName: _whtAccountName,
            onPick: (a) { _whtAccountId = a.id; _whtAccountCode = a.accountCode; _whtAccountName = a.accountNameThai; },
            onClear: () => _clearAccount(() { _whtAccountId = null; _whtAccountCode = null; _whtAccountName = null; }),
          ),

        if (_showFx) ...[
          _accountField(
            label: 'กำไรจากอัตราแลกเปลี่ยน (FX Gain)',
            accountId: _fxGainAccountId, accountCode: _fxGainAccountCode, accountName: _fxGainAccountName,
            onPick: (a) { _fxGainAccountId = a.id; _fxGainAccountCode = a.accountCode; _fxGainAccountName = a.accountNameThai; },
            onClear: () => _clearAccount(() { _fxGainAccountId = null; _fxGainAccountCode = null; _fxGainAccountName = null; }),
          ),
          _accountField(
            label: 'ขาดทุนจากอัตราแลกเปลี่ยน (FX Loss)',
            accountId: _fxLossAccountId, accountCode: _fxLossAccountCode, accountName: _fxLossAccountName,
            onPick: (a) { _fxLossAccountId = a.id; _fxLossAccountCode = a.accountCode; _fxLossAccountName = a.accountNameThai; },
            onClear: () => _clearAccount(() { _fxLossAccountId = null; _fxLossAccountCode = null; _fxLossAccountName = null; }),
          ),
        ],

        // ── Journal preview ───────────────────────────────────────────────
        const SizedBox(height: 4),
        _buildJournalPreview(),

        // ── Buttons ───────────────────────────────────────────────────────
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _submit,
              icon: _isSaving
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'กำลังบันทึก...' : 'บันทึก'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.blueGrey.shade700)),
    );
  }
}

class _JournalLine {
  final String drCr, code, name;
  _JournalLine(this.drCr, this.code, this.name);
}
