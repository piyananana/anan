import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/services/sa_module_document_service.dart';
import '../models/cm_transaction_gl_setup.dart';
import '../services/cm_transaction_gl_setup_service.dart';

class CmTransactionGlSetupScreen extends StatefulWidget {
  const CmTransactionGlSetupScreen({super.key});

  @override
  State<CmTransactionGlSetupScreen> createState() => _CmTransactionGlSetupScreenState();
}

class _CmTransactionGlSetupScreenState extends State<CmTransactionGlSetupScreen>
    with AutomaticKeepAliveClientMixin {
  final CmTransactionGlSetupService _svc     = CmTransactionGlSetupService();
  final ModuleDocumentService       _docSvc  = ModuleDocumentService();
  final AccountService              _acctSvc = AccountService();

  List<CmTransactionGlSetup> _rows     = [];
  List<Account>              _accounts = [];
  List<ModuleDocument>       _glDocs   = [];

  bool   _isEnglish           = false;
  bool   _isLoading           = true;
  String _selectedDocCode     = '';
  bool   _isDraggingDivider   = false;
  bool   _isLeftPanelExpanded = true;
  double _leftPanelWidth      = 320.0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final isEnglish = _isEnglish;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _svc.fetchRows(),
        _acctSvc.fetchRows(),
        _docSvc.fetchRows(),
      ]);
      setState(() {
        _rows     = results[0] as List<CmTransactionGlSetup>;
        _accounts = (results[1] as List<Account>)
            .where((a) => a.isActive && a.isNormalAccount).toList()
          ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
        _glDocs   = (results[2] as List<ModuleDocument>)
            .where((d) => d.isDocType && d.sysModule == '01' && d.isActive).toList()
          ..sort((a, b) => a.docCode.compareTo(b.docCode));
        _isLoading = false;
        if (_rows.isNotEmpty && _selectedDocCode.isEmpty) {
          _selectedDocCode = _rows.first.docCode;
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEnglish ? 'Failed to load data: $e' : 'โหลดข้อมูลล้มเหลว: $e')));
      }
    }
  }

  CmTransactionGlSetup? get _selected =>
      _rows.where((r) => r.docCode == _selectedDocCode).firstOrNull;

  String _acctLabel(Account a) =>
      _isEnglish && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai;

  String _docLabel(ModuleDocument d) =>
      _isEnglish && d.docNameEng.isNotEmpty ? d.docNameEng : d.docNameThai;

  Future<Account?> _pickAccount({String? title}) async {
    final isEnglish = _isEnglish;
    final dialogTitle = title ?? (isEnglish ? 'Select GL Account' : 'เลือกบัญชี GL');
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
                    a.accountNameThai.toLowerCase().contains(lq) ||
                    a.accountNameEng.toLowerCase().contains(lq)).toList();
          });
        }

        return AlertDialog(
          title: Text(dialogTitle),
          content: SizedBox(
            width: 520, height: 420,
            child: Column(children: [
              TextField(
                controller: searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: isEnglish ? 'Search account code / name' : 'ค้นหา รหัส / ชื่อบัญชี',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
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
                      title: Text('${a.accountCode}  ${_acctLabel(a)}',
                          style: const TextStyle(fontSize: 13)),
                      onTap: () { picked = a; Navigator.of(ctx).pop(); },
                    );
                  },
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ],
        );
      }),
    );
    searchCtrl.dispose();
    return picked;
  }

  Future<ModuleDocument?> _pickGlDoc() async {
    final isEnglish = _isEnglish;
    final searchCtrl = TextEditingController();
    List<ModuleDocument> filtered = List.from(_glDocs);
    ModuleDocument? picked;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        return AlertDialog(
          title: Text(isEnglish ? 'Select GL Document Type' : 'เลือกประเภทเอกสาร GL'),
          content: SizedBox(
            width: 480, height: 380,
            child: Column(children: [
              TextField(
                controller: searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: isEnglish ? 'Search' : 'ค้นหา',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  isDense: true,
                ),
                onChanged: (q) {
                  setDlg(() {
                    final lq = q.toLowerCase();
                    filtered = q.isEmpty
                        ? List.from(_glDocs)
                        : _glDocs.where((d) =>
                            d.docCode.toLowerCase().contains(lq) ||
                            d.docNameThai.toLowerCase().contains(lq) ||
                            d.docNameEng.toLowerCase().contains(lq)).toList();
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
                      title: Text('${d.docCode}  ${_docLabel(d)}',
                          style: const TextStyle(fontSize: 13)),
                      onTap: () { picked = d; Navigator.of(ctx).pop(); },
                    );
                  },
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ],
        );
      }),
    );
    searchCtrl.dispose();
    return picked;
  }

  Future<void> _onSave(String docCode, CmTransactionGlSetup updated) async {
    final isEnglish = _isEnglish;
    try {
      final saved = await _svc.upsertRow(docCode, updated);
      setState(() {
        final idx = _rows.indexWhere((r) => r.docCode == saved.docCode);
        if (idx >= 0) _rows[idx] = saved; else _rows.add(saved);
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEnglish ? 'Saved successfully' : 'บันทึกสำเร็จ')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEnglish ? 'Save failed: $e' : 'บันทึกล้มเหลว: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: isEnglish ? 'Reload' : 'โหลดใหม่',
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
                Container(
                  width: 36,
                  color: Colors.blue[700],
                  child: IconButton(
                    icon: Icon(
                      _isLeftPanelExpanded ? Icons.filter_list_off : Icons.filter_list,
                      color: Colors.white, size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () =>
                        setState(() => _isLeftPanelExpanded = !_isLeftPanelExpanded),
                    tooltip: _isLeftPanelExpanded
                        ? (isEnglish ? 'Collapse list' : 'ย่อรายการ')
                        : (isEnglish ? 'Expand list' : 'ขยายรายการ'),
                  ),
                ),
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
                Expanded(
                  child: _selected == null
                      ? Center(child: Text(isEnglish ? 'Select a CM document type on the left' : 'เลือกประเภทเอกสาร CM ด้านซ้าย'))
                      : _CmGlSetupForm(
                          key: ValueKey(_selected!.docCode),
                          setup: _selected!,
                          accounts: _accounts,
                          glDocs: _glDocs,
                          onPickAccount: _pickAccount,
                          onPickGlDoc: _pickGlDoc,
                          onSave: (updated) => _onSave(_selected!.docCode, updated),
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
        final docName = _isEnglish && (row.docNameEng ?? '').isNotEmpty
            ? row.docNameEng!
            : (row.docNameThai ?? '—');
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: isSelected ? Colors.blue.shade50 : null,
          shape: isSelected
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.blue.shade400, width: 1.5),
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
                color: isSelected ? Colors.blue[800] : null,
              ),
            ),
            subtitle: Text(
              docName,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              overflow: TextOverflow.ellipsis,
            ),
            trailing: isSelected
                ? Icon(Icons.chevron_right, size: 18, color: Colors.blue[700])
                : null,
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Form widget
// ═══════════════════════════════════════════════════════════════════════════════
class _CmGlSetupForm extends StatefulWidget {
  final CmTransactionGlSetup setup;
  final List<Account> accounts;
  final List<ModuleDocument> glDocs;
  final Future<Account?> Function({String? title}) onPickAccount;
  final Future<ModuleDocument?> Function() onPickGlDoc;
  final Future<void> Function(CmTransactionGlSetup) onSave;

  const _CmGlSetupForm({
    super.key,
    required this.setup,
    required this.accounts,
    required this.glDocs,
    required this.onPickAccount,
    required this.onPickGlDoc,
    required this.onSave,
  });

  @override
  State<_CmGlSetupForm> createState() => _CmGlSetupFormState();
}

class _CmGlSetupFormState extends State<_CmGlSetupForm> {
  int? _revenueAccountId;          String? _revenueAccountCode;          String? _revenueAccountName;
  int? _expenseAccountId;          String? _expenseAccountCode;          String? _expenseAccountName;
  int? _pettyCashPayableAccountId; String? _pettyCashPayableAccountCode; String? _pettyCashPayableAccountName;
  int? _fxGainAccountId;           String? _fxGainAccountCode;           String? _fxGainAccountName;
  int? _fxLossAccountId;           String? _fxLossAccountCode;           String? _fxLossAccountName;
  int? _glDocId;                   String? _glDocCode;                   String? _glDocName;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadFromSetup(widget.setup);
  }

  void _loadFromSetup(CmTransactionGlSetup s) {
    _revenueAccountId = s.revenueAccountId; _revenueAccountCode = s.revenueAccountCode; _revenueAccountName = s.revenueAccountName;
    _expenseAccountId = s.expenseAccountId; _expenseAccountCode = s.expenseAccountCode; _expenseAccountName = s.expenseAccountName;
    _pettyCashPayableAccountId = s.pettyCashPayableAccountId;
    _pettyCashPayableAccountCode = s.pettyCashPayableAccountCode;
    _pettyCashPayableAccountName = s.pettyCashPayableAccountName;
    _fxGainAccountId = s.fxGainAccountId; _fxGainAccountCode = s.fxGainAccountCode; _fxGainAccountName = s.fxGainAccountName;
    _fxLossAccountId = s.fxLossAccountId; _fxLossAccountCode = s.fxLossAccountCode; _fxLossAccountName = s.fxLossAccountName;
    _glDocId = s.glDocId; _glDocCode = s.glDocCode; _glDocName = s.glDocName;
  }

  // CM doc types: 10=Receipt, 20=Payment, 30=Replenishment, 40=Voucher, 50=Transfer, 70=Charge, 90=Interest
  String get _sdt => widget.setup.sysDocType ?? '';
  bool get _showRevenue         => _sdt == '10';
  bool get _showExpense         => ['20', '70', '90'].contains(_sdt);
  bool get _showPettyCashPayable => ['30', '40'].contains(_sdt);
  bool get _showFx              => false; // สำรองไว้สำหรับอนาคต (แปลงสกุลเงินต่างประเทศ)
  bool get _isTransfer          => _sdt == '50';

  String _acctName(int? id, String? storedName) {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    if (id != null) {
      final match = widget.accounts.where((a) => a.id == id);
      if (match.isNotEmpty) {
        final a = match.first;
        return isEnglish && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai;
      }
    }
    return storedName ?? '';
  }

  Future<void> _pick(String title, void Function(Account) onPicked) async {
    final a = await widget.onPickAccount(title: title);
    if (a != null) setState(() => onPicked(a));
  }

  Widget _accountField({
    required String label,
    required int? accountId,
    required String? accountCode,
    required String? accountName,
    required void Function(Account) onPick,
    required VoidCallback onClear,
  }) {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    final displayName = _acctName(accountId, accountName);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _pick(label, onPick),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
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
            accountId != null ? '$accountCode  $displayName' : (isEnglish ? '— Not specified —' : '— ไม่ระบุ —'),
            style: TextStyle(fontSize: 13, color: accountId != null ? null : Colors.grey.shade500),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    try {
      final updated = CmTransactionGlSetup(
        docCode:     widget.setup.docCode,
        sysDocType:  widget.setup.sysDocType,
        docNameThai: widget.setup.docNameThai,
        docNameEng:  widget.setup.docNameEng,
        docIsActive: widget.setup.docIsActive,
        revenueAccountId: _revenueAccountId, revenueAccountCode: _revenueAccountCode, revenueAccountName: _revenueAccountName,
        expenseAccountId: _expenseAccountId, expenseAccountCode: _expenseAccountCode, expenseAccountName: _expenseAccountName,
        pettyCashPayableAccountId: _pettyCashPayableAccountId,
        pettyCashPayableAccountCode: _pettyCashPayableAccountCode,
        pettyCashPayableAccountName: _pettyCashPayableAccountName,
        fxGainAccountId: _fxGainAccountId, fxGainAccountCode: _fxGainAccountCode, fxGainAccountName: _fxGainAccountName,
        fxLossAccountId: _fxLossAccountId, fxLossAccountCode: _fxLossAccountCode, fxLossAccountName: _fxLossAccountName,
        glDocId: _glDocId, glDocCode: _glDocCode, glDocName: _glDocName,
      );
      await widget.onSave(updated);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
    final isEnglish = l.isEnglish;
    final s = widget.setup;
    String? glDocName;
    if (_glDocId != null) {
      final matchedDoc = widget.glDocs.cast<ModuleDocument?>().firstWhere((d) => d?.id == _glDocId, orElse: () => null);
      glDocName = isEnglish && (matchedDoc?.docNameEng.isNotEmpty ?? false) ? matchedDoc!.docNameEng : _glDocName;
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.docCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text(isEnglish && (s.docNameEng ?? '').isNotEmpty ? s.docNameEng! : (s.docNameThai ?? ''),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ]),
          ),
          if (s.isConfigured)
            Chip(
              label: Text(isEnglish ? 'Configured' : 'มีการตั้งค่า', style: const TextStyle(fontSize: 11)),
              backgroundColor: Colors.green.shade100,
              side: const BorderSide(color: Colors.transparent),
              visualDensity: VisualDensity.compact,
            ),
        ]),
        const SizedBox(height: 16),

        if (_isTransfer)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
                isEnglish
                    ? 'Inter-bank transfer posts using the GL account already set on each bank account (CM > Bank Account) — no extra setup needed here besides the GL document type below.'
                    : 'โอนเงินระหว่างบัญชีใช้บัญชี GL ที่ตั้งไว้ในแต่ละบัญชีธนาคาร (CM > บัญชีธนาคาร) อยู่แล้ว — ไม่ต้องตั้งค่าเพิ่มเติมนอกจากประเภทเอกสาร GL ด้านล่าง',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),

        // ── ประเภทเอกสาร GL ────────────────────────────────────────────────
        _SectionHeader(title: isEnglish ? 'GL Document Type (for Posting)' : 'ประเภทเอกสาร GL (สำหรับ Post)'),
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
              labelText: isEnglish ? 'GL Document Type' : 'ประเภทเอกสาร GL',
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
                const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.description_outlined, size: 18)),
              ]),
            ),
            child: Text(
              _glDocId != null ? '$_glDocCode  ${glDocName ?? _glDocName}' : (isEnglish ? '— Not specified —' : '— ไม่ระบุ —'),
              style: TextStyle(fontSize: 13, color: _glDocId != null ? null : Colors.grey.shade500),
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (_showRevenue || _showExpense || _showPettyCashPayable) ...[
          _SectionHeader(title: isEnglish ? 'Account Codes' : 'รหัสบัญชี'),

          if (_showRevenue)
            _accountField(
              label: isEnglish ? 'Revenue (other side of the receipt)' : 'บัญชีรายได้ (ฝั่งตรงข้ามของรายรับ)',
              accountId: _revenueAccountId, accountCode: _revenueAccountCode, accountName: _revenueAccountName,
              onPick: (a) { _revenueAccountId = a.id; _revenueAccountCode = a.accountCode; _revenueAccountName = a.accountNameThai; },
              onClear: () => setState(() { _revenueAccountId = null; _revenueAccountCode = null; _revenueAccountName = null; }),
            ),

          if (_showExpense)
            _accountField(
              label: _sdt == '90'
                  ? (isEnglish ? 'Interest income / expense (default)' : 'ดอกเบี้ยรับ / ดอกเบี้ยจ่าย (default)')
                  : (isEnglish ? 'Expense (other side)' : 'บัญชีค่าใช้จ่าย (ฝั่งตรงข้าม)'),
              accountId: _expenseAccountId, accountCode: _expenseAccountCode, accountName: _expenseAccountName,
              onPick: (a) { _expenseAccountId = a.id; _expenseAccountCode = a.accountCode; _expenseAccountName = a.accountNameThai; },
              onClear: () => setState(() { _expenseAccountId = null; _expenseAccountCode = null; _expenseAccountName = null; }),
            ),

          if (_showPettyCashPayable)
            _accountField(
              label: isEnglish ? 'Petty Cash Payable (clearing account)' : 'บัญชีพักเบิกเงินสดย่อย (บัญชีล้างยอด)',
              accountId: _pettyCashPayableAccountId, accountCode: _pettyCashPayableAccountCode, accountName: _pettyCashPayableAccountName,
              onPick: (a) { _pettyCashPayableAccountId = a.id; _pettyCashPayableAccountCode = a.accountCode; _pettyCashPayableAccountName = a.accountNameThai; },
              onClear: () => setState(() { _pettyCashPayableAccountId = null; _pettyCashPayableAccountCode = null; _pettyCashPayableAccountName = null; }),
            ),
        ],

        if (_showFx) ...[
          _accountField(
            label: isEnglish ? 'FX Gain' : 'กำไรจากอัตราแลกเปลี่ยน (FX Gain)',
            accountId: _fxGainAccountId, accountCode: _fxGainAccountCode, accountName: _fxGainAccountName,
            onPick: (a) { _fxGainAccountId = a.id; _fxGainAccountCode = a.accountCode; _fxGainAccountName = a.accountNameThai; },
            onClear: () => setState(() { _fxGainAccountId = null; _fxGainAccountCode = null; _fxGainAccountName = null; }),
          ),
          _accountField(
            label: isEnglish ? 'FX Loss' : 'ขาดทุนจากอัตราแลกเปลี่ยน (FX Loss)',
            accountId: _fxLossAccountId, accountCode: _fxLossAccountCode, accountName: _fxLossAccountName,
            onPick: (a) { _fxLossAccountId = a.id; _fxLossAccountCode = a.accountCode; _fxLossAccountName = a.accountNameThai; },
            onClear: () => setState(() { _fxLossAccountId = null; _fxLossAccountCode = null; _fxLossAccountName = null; }),
          ),
        ],

        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: (_isSaving || !(MenuScope.of(context)?.canEdit ?? true)) ? null : _submit,
              icon: _isSaving
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(_isSaving ? (isEnglish ? 'Saving...' : 'กำลังบันทึก...') : (isEnglish ? 'Save' : 'บันทึก')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
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

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey.shade700)),
    );
  }
}
