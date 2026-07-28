import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/services/sa_module_document_service.dart';
import '../models/ap_gl_account_setup.dart';
import '../services/ap_gl_account_setup_service.dart';

class ApGlAccountSetupScreen extends StatefulWidget {
  const ApGlAccountSetupScreen({super.key});

  @override
  State<ApGlAccountSetupScreen> createState() => _ApGlAccountSetupScreenState();
}

class _ApGlAccountSetupScreenState extends State<ApGlAccountSetupScreen>
    with AutomaticKeepAliveClientMixin {
  final ApGlAccountSetupService _svc     = ApGlAccountSetupService();
  final ModuleDocumentService   _docSvc  = ModuleDocumentService();
  final AccountService          _acctSvc = AccountService();

  List<ApGlAccountSetup> _rows     = [];
  List<Account>          _accounts = [];
  List<ModuleDocument>   _glDocs   = [];

  bool   _isEnglish          = false;
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
    final isEnglish = _isEnglish;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _svc.fetchRows(),
        _acctSvc.fetchRows(),
        _docSvc.fetchRows(),
      ]);
      setState(() {
        _rows     = results[0] as List<ApGlAccountSetup>;
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

  ApGlAccountSetup? get _selected =>
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

  Future<void> _onSave(ApGlAccountSetup updated) async {
    final isEnglish = _isEnglish;
    try {
      final saved = await _svc.upsertRow(updated);
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
                      ? Center(child: Text(isEnglish ? 'Select an AP document type on the left' : 'เลือกประเภทเอกสาร AP ด้านซ้าย'))
                      : _ApGlSetupForm(
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
class _ApGlSetupForm extends StatefulWidget {
  final ApGlAccountSetup setup;
  final List<Account> accounts;
  final List<ModuleDocument> glDocs;
  final Future<Account?> Function({String? title}) onPickAccount;
  final Future<ModuleDocument?> Function() onPickGlDoc;
  final Future<void> Function(ApGlAccountSetup) onSave;

  const _ApGlSetupForm({
    super.key,
    required this.setup,
    required this.accounts,
    required this.glDocs,
    required this.onPickAccount,
    required this.onPickGlDoc,
    required this.onSave,
  });

  @override
  State<_ApGlSetupForm> createState() => _ApGlSetupFormState();
}

class _ApGlSetupFormState extends State<_ApGlSetupForm> {
  int?    _apAccountId;           String? _apAccountCode;           String? _apAccountName;
  int?    _expenseAccountId;      String? _expenseAccountCode;      String? _expenseAccountName;
  int?    _vatInputAccountId;     String? _vatInputAccountCode;     String? _vatInputAccountName;
  int?    _vatPendingInputAccountId; String? _vatPendingInputAccountCode; String? _vatPendingInputAccountName;
  int?    _discountAccountId;     String? _discountAccountCode;     String? _discountAccountName;
  int?    _advanceAccountId;      String? _advanceAccountCode;      String? _advanceAccountName;
  int?    _whtPayableAccountId;   String? _whtPayableAccountCode;   String? _whtPayableAccountName;
  int?    _cashAccountId;         String? _cashAccountCode;         String? _cashAccountName;
  int?    _checkAccountId;        String? _checkAccountCode;        String? _checkAccountName;
  int?    _transferAccountId;     String? _transferAccountCode;     String? _transferAccountName;
  int?    _fxGainAccountId;       String? _fxGainAccountCode;       String? _fxGainAccountName;
  int?    _fxLossAccountId;       String? _fxLossAccountCode;       String? _fxLossAccountName;
  int?    _glDocId;               String? _glDocCode;               String? _glDocName;
  bool    _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadFromSetup(widget.setup);
  }

  void _loadFromSetup(ApGlAccountSetup s) {
    _apAccountId             = s.apAccountId;           _apAccountCode           = s.apAccountCode;           _apAccountName           = s.apAccountName;
    _expenseAccountId        = s.expenseAccountId;      _expenseAccountCode      = s.expenseAccountCode;      _expenseAccountName      = s.expenseAccountName;
    _vatInputAccountId       = s.vatInputAccountId;     _vatInputAccountCode     = s.vatInputAccountCode;     _vatInputAccountName     = s.vatInputAccountName;
    _vatPendingInputAccountId = s.vatPendingInputAccountId; _vatPendingInputAccountCode = s.vatPendingInputAccountCode; _vatPendingInputAccountName = s.vatPendingInputAccountName;
    _discountAccountId       = s.discountAccountId;     _discountAccountCode     = s.discountAccountCode;     _discountAccountName     = s.discountAccountName;
    _advanceAccountId        = s.advanceAccountId;      _advanceAccountCode      = s.advanceAccountCode;      _advanceAccountName      = s.advanceAccountName;
    _whtPayableAccountId     = s.whtPayableAccountId;   _whtPayableAccountCode   = s.whtPayableAccountCode;   _whtPayableAccountName   = s.whtPayableAccountName;
    _cashAccountId           = s.cashAccountId;         _cashAccountCode         = s.cashAccountCode;         _cashAccountName         = s.cashAccountName;
    _checkAccountId          = s.checkAccountId;        _checkAccountCode        = s.checkAccountCode;        _checkAccountName        = s.checkAccountName;
    _transferAccountId       = s.transferAccountId;     _transferAccountCode     = s.transferAccountCode;     _transferAccountName     = s.transferAccountName;
    _fxGainAccountId         = s.fxGainAccountId;       _fxGainAccountCode       = s.fxGainAccountCode;       _fxGainAccountName       = s.fxGainAccountName;
    _fxLossAccountId         = s.fxLossAccountId;       _fxLossAccountCode       = s.fxLossAccountCode;       _fxLossAccountName       = s.fxLossAccountName;
    _glDocId                 = s.glDocId;               _glDocCode               = s.glDocCode;               _glDocName               = s.glDocName;
  }

  // AP doc types: 10=PI, 30=CN, 50=DN, 60=Advance Payment, 65=Advance Refund, 70=RA, 80=Payment
  String get _sdt => widget.setup.sysDocType ?? '';
  bool get _showAp         => !['60', '65', '70'].contains(_sdt);
  bool get _showExpense    => ['10', '30', '50'].contains(_sdt);
  bool get _showVat        => ['10', '30', '50', '60', '80'].contains(_sdt);
  bool get _showVatPending => _showVat;
  bool get _showDiscount   => ['10', '50'].contains(_sdt);
  bool get _showAdvance    => ['60', '65', '80'].contains(_sdt);
  bool get _showBank       => ['60', '65', '80'].contains(_sdt);
  bool get _showWht        => _sdt == '80';
  bool get _showFx         => _sdt == '80';

  // ── Bilingual account name resolver — prefer live lookup by id over the stored name ──
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

  void _clearAccount(void Function() clear) => setState(clear);

  Widget _accountField({
    required String label,
    required int? accountId,
    required String? accountCode,
    required String? accountName,
    required void Function(Account) onPick,
    required VoidCallback onClear,
    bool required = false,
  }) {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    final displayName = _acctName(accountId, accountName);
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
            accountId != null ? '$accountCode  $displayName' : (isEnglish ? '— Not specified —' : '— ไม่ระบุ —'),
            style: TextStyle(
              fontSize: 13,
              color: accountId != null ? null : Colors.grey.shade500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJournalPreview() {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    String nm(int? id, String? stored) => _acctName(id, stored);
    final lines = <_JournalLine>[];
    switch (_sdt) {
      case '10': // PI — Purchase Invoice
        if (_expenseAccountId != null) lines.add(_JournalLine('Dr', _expenseAccountCode!, '${nm(_expenseAccountId, _expenseAccountName)} ${isEnglish ? '(per line)' : '(ต่อ line)'}'));
        if (_vatInputAccountId != null) lines.add(_JournalLine('Dr', _vatInputAccountCode!, nm(_vatInputAccountId, _vatInputAccountName)));
        if (_apAccountId != null) lines.add(_JournalLine('  Cr', _apAccountCode!, nm(_apAccountId, _apAccountName)));
        break;
      case '30': // CN from vendor
        if (_apAccountId != null) lines.add(_JournalLine('Dr', _apAccountCode!, nm(_apAccountId, _apAccountName)));
        if (_expenseAccountId != null) lines.add(_JournalLine('  Cr', _expenseAccountCode!, '${nm(_expenseAccountId, _expenseAccountName)} ${isEnglish ? '(per line)' : '(ต่อ line)'}'));
        if (_vatInputAccountId != null) lines.add(_JournalLine('  Cr', _vatInputAccountCode!, nm(_vatInputAccountId, _vatInputAccountName)));
        break;
      case '50': // DN — Debit Note
        if (_expenseAccountId != null) lines.add(_JournalLine('Dr', _expenseAccountCode!, '${nm(_expenseAccountId, _expenseAccountName)} ${isEnglish ? '(per line)' : '(ต่อ line)'}'));
        if (_vatInputAccountId != null) lines.add(_JournalLine('Dr', _vatInputAccountCode!, nm(_vatInputAccountId, _vatInputAccountName)));
        if (_apAccountId != null) lines.add(_JournalLine('  Cr', _apAccountCode!, nm(_apAccountId, _apAccountName)));
        break;
      case '60': // Advance Payment
        if (_advanceAccountId != null) lines.add(_JournalLine('Dr', _advanceAccountCode!, nm(_advanceAccountId, _advanceAccountName)));
        if (_vatInputAccountId != null) lines.add(_JournalLine('Dr', _vatInputAccountCode!, '${nm(_vatInputAccountId, _vatInputAccountName)} ${isEnglish ? '(if VAT applies)' : '(ถ้ามี VAT)'}'));
        if (_cashAccountId != null) lines.add(_JournalLine('  Cr', _cashAccountCode!, nm(_cashAccountId, _cashAccountName)));
        break;
      case '65': // Advance Refund
        if (_cashAccountId != null) lines.add(_JournalLine('Dr', _cashAccountCode!, nm(_cashAccountId, _cashAccountName)));
        if (_advanceAccountId != null) lines.add(_JournalLine('  Cr', _advanceAccountCode!, nm(_advanceAccountId, _advanceAccountName)));
        break;
      case '70': // RA — ไม่มี GL entry
        break;
      case '80': // Payment
        if (_apAccountId != null) lines.add(_JournalLine('Dr', _apAccountCode!, nm(_apAccountId, _apAccountName)));
        if (_fxLossAccountId != null) lines.add(_JournalLine('Dr', _fxLossAccountCode!, '${nm(_fxLossAccountId, _fxLossAccountName)} ${isEnglish ? '(FX loss)' : '(ขาดทุน FX)'}'));
        if (_advanceAccountId != null) lines.add(_JournalLine('Dr', _advanceAccountCode!, '${nm(_advanceAccountId, _advanceAccountName)} ${isEnglish ? '(advance applied)' : '(ตัดมัดจำ)'}'));
        if (_vatPendingInputAccountId != null) lines.add(_JournalLine('Dr', _vatPendingInputAccountCode!, '${nm(_vatPendingInputAccountId, _vatPendingInputAccountName)} ${isEnglish ? '(recognize deferred VAT)' : '(รับรู้ VAT รอตัด)'}'));
        if (_cashAccountId != null) lines.add(_JournalLine('  Cr', _cashAccountCode!, nm(_cashAccountId, _cashAccountName)));
        if (_whtPayableAccountId != null) lines.add(_JournalLine('  Cr', _whtPayableAccountCode!, '${nm(_whtPayableAccountId, _whtPayableAccountName)} ${isEnglish ? '(WHT payable)' : '(WHT ค้างจ่าย)'}'));
        if (_fxGainAccountId != null) lines.add(_JournalLine('  Cr', _fxGainAccountCode!, '${nm(_fxGainAccountId, _fxGainAccountName)} ${isEnglish ? '(FX gain)' : '(กำไร FX)'}'));
        if (_vatInputAccountId != null) lines.add(_JournalLine('  Cr', _vatInputAccountCode!, '${nm(_vatInputAccountId, _vatInputAccountName)} ${isEnglish ? '(recognize deferred VAT)' : '(รับรู้ VAT รอตัดบัญชี)'}'));
        break;
    }
    if (lines.isEmpty) {
      if (_sdt == '70') {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
              isEnglish
                  ? 'RA (Remittance Advice) does not post a GL entry — used only to match invoices with payments'
                  : 'RA (Remittance Advice) ไม่มีการบันทึก GL entry — ใช้สำหรับจับคู่ใบแจ้งหนี้กับการชำระเงินเท่านั้น',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        );
      }
      return const SizedBox.shrink();
    }

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
          Text(isEnglish ? 'Sample Journal Entry' : 'ตัวอย่าง Journal Entry',
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
                        color: l.drCr.trim() == 'Dr'
                            ? Colors.blue.shade700
                            : Colors.green.shade700,
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

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    try {
      final updated = ApGlAccountSetup(
        docCode:    widget.setup.docCode,
        sysDocType: widget.setup.sysDocType,
        docNameThai: widget.setup.docNameThai,
        docNameEng: widget.setup.docNameEng,
        docIsActive: widget.setup.docIsActive,
        apAccountId:              _apAccountId,            apAccountCode:           _apAccountCode,           apAccountName:           _apAccountName,
        expenseAccountId:         _expenseAccountId,       expenseAccountCode:      _expenseAccountCode,      expenseAccountName:      _expenseAccountName,
        vatInputAccountId:        _vatInputAccountId,      vatInputAccountCode:     _vatInputAccountCode,     vatInputAccountName:     _vatInputAccountName,
        vatPendingInputAccountId: _vatPendingInputAccountId, vatPendingInputAccountCode: _vatPendingInputAccountCode, vatPendingInputAccountName: _vatPendingInputAccountName,
        discountAccountId:        _discountAccountId,      discountAccountCode:     _discountAccountCode,     discountAccountName:     _discountAccountName,
        advanceAccountId:         _advanceAccountId,       advanceAccountCode:      _advanceAccountCode,      advanceAccountName:      _advanceAccountName,
        whtPayableAccountId:      _whtPayableAccountId,    whtPayableAccountCode:   _whtPayableAccountCode,   whtPayableAccountName:   _whtPayableAccountName,
        cashAccountId:            _cashAccountId,          cashAccountCode:         _cashAccountCode,         cashAccountName:         _cashAccountName,
        checkAccountId:           _checkAccountId,         checkAccountCode:        _checkAccountCode,        checkAccountName:        _checkAccountName,
        transferAccountId:        _transferAccountId,      transferAccountCode:     _transferAccountCode,     transferAccountName:     _transferAccountName,
        fxGainAccountId:          _fxGainAccountId,        fxGainAccountCode:       _fxGainAccountCode,       fxGainAccountName:       _fxGainAccountName,
        fxLossAccountId:          _fxLossAccountId,        fxLossAccountCode:       _fxLossAccountCode,       fxLossAccountName:       _fxLossAccountName,
        glDocId:                  _glDocId,                glDocCode:               _glDocCode,               glDocName:               _glDocName,
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
              Text(s.docCode,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.description_outlined, size: 18)),
              ]),
            ),
            child: Text(
              _glDocId != null ? '$_glDocCode  ${glDocName ?? _glDocName}' : (isEnglish ? '— Not specified —' : '— ไม่ระบุ —'),
              style: TextStyle(fontSize: 13, color: _glDocId != null ? null : Colors.grey.shade500),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── รหัสบัญชี ──────────────────────────────────────────────────────
        _SectionHeader(title: isEnglish ? 'Account Codes' : 'รหัสบัญชี'),

        if (_showAp)
          _accountField(
            label: isEnglish
                ? 'Accounts Payable (AP Account) *If not specified, the account from the vendor group or vendor will be used instead'
                : 'เจ้าหนี้การค้า (AP Account) *ถ้าไม่ระบุ จะใช้รหัสบัญชีจากกลุ่มเจ้าหนี้หรือเจ้าหนี้โดยตรงแทน',
            accountId: _apAccountId, accountCode: _apAccountCode, accountName: _apAccountName,
            onPick: (a) { _apAccountId = a.id; _apAccountCode = a.accountCode; _apAccountName = a.accountNameThai; },
            onClear: () => _clearAccount(() { _apAccountId = null; _apAccountCode = null; _apAccountName = null; }),
          ),

        if (_showExpense)
          _accountField(
            label: isEnglish ? 'Expense / Goods (Expense — default)' : 'ค่าใช้จ่าย / สินค้า (Expense — default)',
            accountId: _expenseAccountId, accountCode: _expenseAccountCode, accountName: _expenseAccountName,
            onPick: (a) { _expenseAccountId = a.id; _expenseAccountCode = a.accountCode; _expenseAccountName = a.accountNameThai; },
            onClear: () => _clearAccount(() { _expenseAccountId = null; _expenseAccountCode = null; _expenseAccountName = null; }),
          ),

        if (_showVat) ...[
          _accountField(
            label: isEnglish ? 'VAT Input' : 'ภาษีซื้อ (VAT Input)',
            accountId: _vatInputAccountId, accountCode: _vatInputAccountCode, accountName: _vatInputAccountName,
            onPick: (a) { _vatInputAccountId = a.id; _vatInputAccountCode = a.accountCode; _vatInputAccountName = a.accountNameThai; },
            onClear: () => _clearAccount(() { _vatInputAccountId = null; _vatInputAccountCode = null; _vatInputAccountName = null; }),
          ),
          if (_showVatPending)
            _accountField(
              label: isEnglish ? 'Deferred VAT Input' : 'ภาษีซื้อรอตัดบัญชี (Deferred VAT Input)',
              accountId: _vatPendingInputAccountId, accountCode: _vatPendingInputAccountCode, accountName: _vatPendingInputAccountName,
              onPick: (a) { _vatPendingInputAccountId = a.id; _vatPendingInputAccountCode = a.accountCode; _vatPendingInputAccountName = a.accountNameThai; },
              onClear: () => _clearAccount(() { _vatPendingInputAccountId = null; _vatPendingInputAccountCode = null; _vatPendingInputAccountName = null; }),
            ),
        ],

        if (_showDiscount)
          _accountField(
            label: isEnglish ? 'Discount Received' : 'ส่วนลดรับ (Discount Received)',
            accountId: _discountAccountId, accountCode: _discountAccountCode, accountName: _discountAccountName,
            onPick: (a) { _discountAccountId = a.id; _discountAccountCode = a.accountCode; _discountAccountName = a.accountNameThai; },
            onClear: () => _clearAccount(() { _discountAccountId = null; _discountAccountCode = null; _discountAccountName = null; }),
          ),

        if (_showAdvance)
          _accountField(
            label: isEnglish ? 'Advance Paid' : 'เงินมัดจำจ่าย (Advance Paid)',
            accountId: _advanceAccountId, accountCode: _advanceAccountCode, accountName: _advanceAccountName,
            onPick: (a) { _advanceAccountId = a.id; _advanceAccountCode = a.accountCode; _advanceAccountName = a.accountNameThai; },
            onClear: () => _clearAccount(() { _advanceAccountId = null; _advanceAccountCode = null; _advanceAccountName = null; }),
          ),

        if (_showBank) ...[
          _accountField(
            label: isEnglish ? 'Cash / Bank (default)' : 'เงินสด / ธนาคาร (Cash/Bank — default)',
            accountId: _cashAccountId, accountCode: _cashAccountCode, accountName: _cashAccountName,
            onPick: (a) { _cashAccountId = a.id; _cashAccountCode = a.accountCode; _cashAccountName = a.accountNameThai; },
            onClear: () => _clearAccount(() { _cashAccountId = null; _cashAccountCode = null; _cashAccountName = null; }),
          ),
          _SectionHeader(title: isEnglish
              ? 'Payment Accounts by Method (if not specified, the account from the CM module or the Cash/Bank account above will be used)'
              : 'บัญชีจ่ายตามวิธีชำระ (ถ้าไม่ระบุ จะใช้บัญชีจากโมดูล CM หรือบัญชี Cash/Bank ด้านบน)'),
          _accountField(
            label: isEnglish ? 'Check (CHECK)' : 'เช็ค (CHECK)',
            accountId: _checkAccountId, accountCode: _checkAccountCode, accountName: _checkAccountName,
            onPick: (a) { _checkAccountId = a.id; _checkAccountCode = a.accountCode; _checkAccountName = a.accountNameThai; },
            onClear: () => _clearAccount(() { _checkAccountId = null; _checkAccountCode = null; _checkAccountName = null; }),
          ),
          _accountField(
            label: isEnglish ? 'Transfer (TRANSFER)' : 'โอนเงิน (TRANSFER)',
            accountId: _transferAccountId, accountCode: _transferAccountCode, accountName: _transferAccountName,
            onPick: (a) { _transferAccountId = a.id; _transferAccountCode = a.accountCode; _transferAccountName = a.accountNameThai; },
            onClear: () => _clearAccount(() { _transferAccountId = null; _transferAccountCode = null; _transferAccountName = null; }),
          ),
        ],

        if (_showWht)
          _accountField(
            label: isEnglish ? 'Withholding Tax Payable (WHT Payable)' : 'ภาษีหัก ณ ที่จ่ายค้างจ่าย (WHT Payable)',
            accountId: _whtPayableAccountId, accountCode: _whtPayableAccountCode, accountName: _whtPayableAccountName,
            onPick: (a) { _whtPayableAccountId = a.id; _whtPayableAccountCode = a.accountCode; _whtPayableAccountName = a.accountNameThai; },
            onClear: () => _clearAccount(() { _whtPayableAccountId = null; _whtPayableAccountCode = null; _whtPayableAccountName = null; }),
          ),

        if (_showFx) ...[
          _accountField(
            label: isEnglish ? 'FX Gain' : 'กำไรจากอัตราแลกเปลี่ยน (FX Gain)',
            accountId: _fxGainAccountId, accountCode: _fxGainAccountCode, accountName: _fxGainAccountName,
            onPick: (a) { _fxGainAccountId = a.id; _fxGainAccountCode = a.accountCode; _fxGainAccountName = a.accountNameThai; },
            onClear: () => _clearAccount(() { _fxGainAccountId = null; _fxGainAccountCode = null; _fxGainAccountName = null; }),
          ),
          _accountField(
            label: isEnglish ? 'FX Loss' : 'ขาดทุนจากอัตราแลกเปลี่ยน (FX Loss)',
            accountId: _fxLossAccountId, accountCode: _fxLossAccountCode, accountName: _fxLossAccountName,
            onPick: (a) { _fxLossAccountId = a.id; _fxLossAccountCode = a.accountCode; _fxLossAccountName = a.accountNameThai; },
            onClear: () => _clearAccount(() { _fxLossAccountId = null; _fxLossAccountCode = null; _fxLossAccountName = null; }),
          ),
        ],

        const SizedBox(height: 4),
        _buildJournalPreview(),

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
