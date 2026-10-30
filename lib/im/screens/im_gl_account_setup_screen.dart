import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/widgets/sa_sys_doc_type_guide.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/services/sa_module_document_service.dart';
import '../models/im_gl_account_setup.dart';
import '../services/im_gl_account_setup_service.dart';

class ImGlAccountSetupScreen extends StatefulWidget {
  const ImGlAccountSetupScreen({super.key});

  @override
  State<ImGlAccountSetupScreen> createState() => _ImGlAccountSetupScreenState();
}

class _ImGlAccountSetupScreenState extends State<ImGlAccountSetupScreen> with AutomaticKeepAliveClientMixin {
  final ImGlAccountSetupService _svc = ImGlAccountSetupService();
  final ModuleDocumentService _docSvc = ModuleDocumentService();
  final AccountService _acctSvc = AccountService();

  List<ImGlAccountSetup> _rows = [];
  List<Account> _accounts = [];
  List<ModuleDocument> _glDocs = [];
  List<ModuleDocument> _allDocs = [];

  bool _isEnglish = false;
  bool _isLoading = true;
  String _selectedDocCode = '';
  bool _isDraggingDivider = false;
  bool _isLeftPanelExpanded = true;
  double _leftPanelWidth = 320.0;

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
        _rows = results[0] as List<ImGlAccountSetup>;
        _accounts = (results[1] as List<Account>).where((a) => a.isActive && a.isNormalAccount).toList()
          ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
        _allDocs = results[2] as List<ModuleDocument>;
        _glDocs = _allDocs.where((d) => d.isDocType && d.sysModule == '01' && d.isActive).toList()
          ..sort((a, b) => a.docCode.compareTo(b.docCode));
        _isLoading = false;
        if (_rows.isNotEmpty && _selectedDocCode.isEmpty) {
          _selectedDocCode = _rows.first.docCode;
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Failed to load data: $e' : 'โหลดข้อมูลล้มเหลว: $e')));
      }
    }
  }

  ImGlAccountSetup? get _selected => _rows.where((r) => r.docCode == _selectedDocCode).firstOrNull;

  String _docLabel(ImGlAccountSetup row, bool isEnglish) =>
      isEnglish && (row.docNameEng ?? '').isNotEmpty ? row.docNameEng! : (row.docNameThai ?? row.docCode);

  Future<void> _onSave(ImGlAccountSetup updated) async {
    final isEnglish = _isEnglish;
    try {
      final saved = await _svc.upsertRow(updated.docCode, updated);
      setState(() {
        final idx = _rows.indexWhere((r) => r.docCode == saved.docCode);
        if (idx >= 0) _rows[idx] = saved;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Saved successfully' : 'บันทึกสำเร็จ')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Save failed: $e' : 'บันทึกล้มเหลว: $e')));
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
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        actions: [
          SysDocTypeGuideButton(
            module: 'IM',
            isEnglish: isEnglish,
            docCodesBySdt: SysDocTypeGuideButton.groupDocCodes(_rows, (r) => r.sysDocType, (r) => r.docCode),
            currentSdt: _selected?.sysDocType,
          ),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), tooltip: isEnglish ? 'Reload' : 'โหลดใหม่', onPressed: _loadAll),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (ctx, constraints) {
              final maxLeft = (constraints.maxWidth - 36 - 5 - 400).clamp(100.0, double.infinity);
              return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  width: 36,
                  color: Colors.teal[700],
                  child: IconButton(
                    icon: Icon(_isLeftPanelExpanded ? Icons.filter_list_off : Icons.filter_list, color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    onPressed: () => setState(() => _isLeftPanelExpanded = !_isLeftPanelExpanded),
                    tooltip: _isLeftPanelExpanded ? (isEnglish ? 'Collapse list' : 'ย่อรายการ') : (isEnglish ? 'Expand list' : 'ขยายรายการ'),
                  ),
                ),
                AnimatedContainer(
                  duration: _isDraggingDivider ? Duration.zero : const Duration(milliseconds: 200),
                  width: _isLeftPanelExpanded ? _leftPanelWidth : 0,
                  child: ClipRect(
                    child: OverflowBox(
                      maxWidth: _leftPanelWidth, minWidth: _leftPanelWidth,
                      alignment: Alignment.topLeft,
                      child: _buildLeftPanel(isEnglish),
                    ),
                  ),
                ),
                if (_isLeftPanelExpanded)
                  MouseRegion(
                    cursor: SystemMouseCursors.resizeColumn,
                    child: GestureDetector(
                      onHorizontalDragStart: (_) => setState(() => _isDraggingDivider = true),
                      onHorizontalDragUpdate: (d) => setState(() {
                        _leftPanelWidth = (_leftPanelWidth + d.delta.dx).clamp(200.0, maxLeft);
                      }),
                      onHorizontalDragEnd: (_) => setState(() => _isDraggingDivider = false),
                      child: Container(width: 5, color: Colors.grey[400]),
                    ),
                  ),
                Expanded(
                  child: _selected == null
                      ? Center(child: Text(isEnglish ? 'Select an IM document type on the left' : 'เลือกประเภทเอกสาร IM ด้านซ้าย'))
                      : _ImGlSetupForm(
                          key: ValueKey(_selected!.docCode),
                          setup: _selected!,
                          accounts: _accounts,
                          glDocs: _glDocs,
                          // ประเภทเอกสาร AR/AP ปลายทางที่เลือกได้ — ตรงโมดูลและ sys_doc_type ที่ประเภทเอกสาร IM นี้สร้าง
                          targetDocs: _selected!.targetAuto
                              ? (_allDocs.where((d) => d.isDocType && d.isActive
                                      && d.sysModule == (_selected!.targetModule == 'AP' ? '21' : '11')
                                      && d.sysDocType == _selected!.targetDocCode).toList()
                                ..sort((a, b) => a.docCode.compareTo(b.docCode)))
                              : const [],
                          onSave: _onSave,
                        ),
                ),
              ]);
            }),
    );
  }

  Widget _buildLeftPanel(bool isEnglish) {
    return ColoredBox(
      color: Colors.blueGrey.shade100,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        itemCount: _rows.length,
        itemBuilder: (ctx, i) {
          final row = _rows[i];
          final isSelected = row.docCode == _selectedDocCode;
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            color: isSelected ? Colors.teal.shade50 : null,
            shape: isSelected
                ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.teal.shade400, width: 1.5))
                : null,
            child: ListTile(
              dense: true,
              onTap: () => setState(() => _selectedDocCode = row.docCode),
              leading: Icon(row.isConfigured ? Icons.check_circle : Icons.radio_button_unchecked, size: 18, color: row.isConfigured ? Colors.green : Colors.grey),
              title: Text(row.docCode, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? Colors.teal[800] : null)),
              subtitle: Text(_docLabel(row, isEnglish), style: TextStyle(fontSize: 11, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
              trailing: isSelected ? Icon(Icons.chevron_right, size: 18, color: Colors.teal[700]) : null,
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Form widget
// ═══════════════════════════════════════════════════════════════════════════════
class _ImGlSetupForm extends StatefulWidget {
  final ImGlAccountSetup setup;
  final List<Account> accounts;
  final List<ModuleDocument> glDocs;
  final List<ModuleDocument> targetDocs;
  final Future<void> Function(ImGlAccountSetup) onSave;

  const _ImGlSetupForm({
    super.key,
    required this.setup,
    required this.accounts,
    required this.glDocs,
    required this.targetDocs,
    required this.onSave,
  });

  @override
  State<_ImGlSetupForm> createState() => _ImGlSetupFormState();
}

class _ImGlSetupFormState extends State<_ImGlSetupForm> {
  int? _inventoryAccountId; String? _inventoryAccountCode; String? _inventoryAccountName;
  int? _cogsAccountId;      String? _cogsAccountCode;      String? _cogsAccountName;
  int? _varianceAccountId;  String? _varianceAccountCode;  String? _varianceAccountName;
  int? _wipAccountId;       String? _wipAccountCode;       String? _wipAccountName;
  int? _grirAccountId;      String? _grirAccountCode;      String? _grirAccountName;
  int? _vatOutputAccountId; String? _vatOutputAccountCode; String? _vatOutputAccountName;
  int? _vatInputAccountId;  String? _vatInputAccountCode;  String? _vatInputAccountName;
  int? _consignmentPayableAccountId; String? _consignmentPayableAccountCode; String? _consignmentPayableAccountName;
  int? _glDocId;            String? _glDocCode;            String? _glDocName;
  int? _targetDocId;        String? _targetDocCode;        String? _targetDocName;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadFromSetup(widget.setup);
  }

  @override
  void didUpdateWidget(covariant _ImGlSetupForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.setup.docCode != oldWidget.setup.docCode) _loadFromSetup(widget.setup);
  }

  void _loadFromSetup(ImGlAccountSetup s) {
    _inventoryAccountId = s.inventoryAccountId; _inventoryAccountCode = s.inventoryAccountCode; _inventoryAccountName = s.inventoryAccountName;
    _cogsAccountId      = s.cogsAccountId;      _cogsAccountCode      = s.cogsAccountCode;      _cogsAccountName      = s.cogsAccountName;
    _varianceAccountId  = s.varianceAccountId;  _varianceAccountCode  = s.varianceAccountCode;  _varianceAccountName  = s.varianceAccountName;
    _wipAccountId       = s.wipAccountId;       _wipAccountCode       = s.wipAccountCode;       _wipAccountName       = s.wipAccountName;
    _grirAccountId      = s.grirAccountId;      _grirAccountCode      = s.grirAccountCode;      _grirAccountName      = s.grirAccountName;
    _vatOutputAccountId = s.vatOutputAccountId; _vatOutputAccountCode = s.vatOutputAccountCode; _vatOutputAccountName = s.vatOutputAccountName;
    _vatInputAccountId  = s.vatInputAccountId;  _vatInputAccountCode  = s.vatInputAccountCode;  _vatInputAccountName  = s.vatInputAccountName;
    _consignmentPayableAccountId = s.consignmentPayableAccountId;
    _consignmentPayableAccountCode = s.consignmentPayableAccountCode;
    _consignmentPayableAccountName = s.consignmentPayableAccountName;
    _glDocId            = s.glDocId;            _glDocCode            = s.glDocCode;            _glDocName            = s.glDocName;
    _targetDocId        = s.targetDocId;        _targetDocCode        = s.targetDocCodeSel;     _targetDocName        = s.targetDocNameTh;
  }

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

  Future<Account?> _pickAccount(String title) async {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    final searchCtrl = TextEditingController();
    List<Account> filtered = List.from(widget.accounts);
    Account? picked;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        void doFilter(String q) {
          setDlg(() {
            final lq = q.toLowerCase();
            filtered = q.isEmpty
                ? List.from(widget.accounts)
                : widget.accounts.where((a) => a.accountCode.toLowerCase().contains(lq) || a.accountNameThai.toLowerCase().contains(lq) || a.accountNameEng.toLowerCase().contains(lq)).toList();
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
                      title: Text('${a.accountCode}  ${_acctName(a.id, a.accountNameThai)}', style: const TextStyle(fontSize: 13)),
                      onTap: () { picked = a; Navigator.of(ctx).pop(); },
                    );
                  },
                ),
              ),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก'))],
        );
      }),
    );
    searchCtrl.dispose();
    return picked;
  }

  Future<void> _pick(String title, void Function(Account) onPicked) async {
    final a = await _pickAccount(title);
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
                IconButton(icon: const Icon(Icons.clear, size: 16), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onClear),
              const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.account_tree_outlined, size: 18)),
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

  Future<void> _pickGlDoc() async {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    final picked = await _pickDoc(widget.glDocs, isEnglish ? 'Select GL Document Type' : 'เลือกประเภทเอกสาร GL');
    if (picked != null) {
      setState(() { _glDocId = picked.id; _glDocCode = picked.docCode; _glDocName = picked.docNameThai; });
    }
  }

  Future<void> _pickTargetDoc() async {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    final m = widget.setup.targetModule;
    final picked = await _pickDoc(widget.targetDocs, isEnglish ? 'Select $m Document Type' : 'เลือกประเภทเอกสาร $m');
    if (picked != null) {
      setState(() { _targetDocId = picked.id; _targetDocCode = picked.docCode; _targetDocName = picked.docNameThai; });
    }
  }

  Future<ModuleDocument?> _pickDoc(List<ModuleDocument> docs, String title) async {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    final searchCtrl = TextEditingController();
    List<ModuleDocument> filtered = List.from(docs);
    ModuleDocument? picked;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        return AlertDialog(
          title: Text(title),
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
                onChanged: (q) => setDlg(() {
                  final lq = q.toLowerCase();
                  filtered = q.isEmpty
                      ? List.from(docs)
                      : docs.where((d) => d.docCode.toLowerCase().contains(lq) || d.docNameThai.toLowerCase().contains(lq) || d.docNameEng.toLowerCase().contains(lq)).toList();
                }),
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
                      title: Text('${d.docCode}  ${isEnglish && d.docNameEng.isNotEmpty ? d.docNameEng : d.docNameThai}', style: const TextStyle(fontSize: 13)),
                      onTap: () { picked = d; Navigator.of(ctx).pop(); },
                    );
                  },
                ),
              ),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก'))],
        );
      }),
    );
    searchCtrl.dispose();
    return picked;
  }

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    try {
      final updated = ImGlAccountSetup(
        docCode: widget.setup.docCode,
        targetModule: widget.setup.targetModule,
        targetDocCode: widget.setup.targetDocCode,
        glDocId: _glDocId, glDocCode: _glDocCode, glDocName: _glDocName,
        targetAuto: widget.setup.targetAuto,
        targetDocId: _targetDocId, targetDocCodeSel: _targetDocCode, targetDocNameTh: _targetDocName,
        inventoryAccountId: _inventoryAccountId, inventoryAccountCode: _inventoryAccountCode, inventoryAccountName: _inventoryAccountName,
        cogsAccountId: _cogsAccountId, cogsAccountCode: _cogsAccountCode, cogsAccountName: _cogsAccountName,
        varianceAccountId: _varianceAccountId, varianceAccountCode: _varianceAccountCode, varianceAccountName: _varianceAccountName,
        wipAccountId: _wipAccountId, wipAccountCode: _wipAccountCode, wipAccountName: _wipAccountName,
        grirAccountId: _grirAccountId, grirAccountCode: _grirAccountCode, grirAccountName: _grirAccountName,
        vatOutputAccountId: _vatOutputAccountId, vatOutputAccountCode: _vatOutputAccountCode, vatOutputAccountName: _vatOutputAccountName,
        vatInputAccountId: _vatInputAccountId, vatInputAccountCode: _vatInputAccountCode, vatInputAccountName: _vatInputAccountName,
        consignmentPayableAccountId: _consignmentPayableAccountId, consignmentPayableAccountCode: _consignmentPayableAccountCode, consignmentPayableAccountName: _consignmentPayableAccountName,
      );
      await widget.onSave(updated);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ชื่อ sys_doc_type ของเอกสารปลายทาง (AP: 10 ตั้งหนี้ 30 ลดหนี้ 50 เพิ่มหนี้ / AR: 10 ตั้งหนี้ 50 ลดหนี้ 30 เพิ่มหนี้)
  String _targetKind(bool isEnglish) {
    final s = widget.setup;
    final t = s.targetDocCode;
    final isAp = s.targetModule == 'AP';
    if (t == '10') return isEnglish ? 'billing' : 'ตั้งหนี้';
    final isCredit = isAp ? t == '30' : t == '50';
    return isCredit ? (isEnglish ? 'credit note' : 'ลดหนี้') : (isEnglish ? 'debit note' : 'เพิ่มหนี้');
  }

  String _targetLabel(bool isEnglish) {
    final s = widget.setup;
    if (s.targetModule == 'NONE') return isEnglish ? 'Internal only — no AR/AP document is created' : 'ภายในเท่านั้น — ไม่สร้างเอกสาร AR/AP';
    final moduleLabel = s.targetModule == 'AP' ? 'AP' : 'AR';
    final kind = _targetKind(isEnglish);
    if (!s.targetAuto) {
      return isEnglish
          ? 'No document is created automatically — record the $moduleLabel $kind later in the $moduleLabel module'
          : 'ไม่สร้างเอกสารอัตโนมัติ — ไปบันทึก$kind ที่โมดูล $moduleLabel ภายหลัง';
    }
    return isEnglish
        ? 'Creates an $moduleLabel $kind (system type ${s.targetDocCode}) when posted — choose its document type below'
        : 'เมื่อ Post จะสร้างเอกสาร$kind $moduleLabel (ประเภทระบบ ${s.targetDocCode}) อัตโนมัติ — เลือกประเภทเอกสารด้านล่าง';
  }

  // ── Journal preview ───────────────────────────────────────────────────────
  // Dr/Cr ต้องขึ้นกับ sys_doc_type (มาตรฐานคงที่ตาม imSysDocType ใน sa_anan_module.dart) เสมอ ไม่ใช่ doc_code
  // เพราะแต่ละ sys_doc_type อาจมีได้หลาย doc_code (เช่น GRN1/GRN2 ใต้ sys_doc_type='10') ซึ่งแต่ละตัวมีรหัสบัญชี
  // ของตัวเอง แต่ยึดพฤติกรรม Dr/Cr เดียวกัน — รูปแบบเดียวกับ ar_gl_account_setup_screen.dart's `_sdt`
  // AJS (sys_doc_type='80') ตรงกับ logic ที่ใช้งานจริงใน imTransactionController.js:postGlEntry
  // (ส่วนเกิน = Dr คลัง/Cr ผลต่าง, ส่วนขาด = กลับด้าน) ส่วน sys_doc_type อื่นยังไม่มีการ Post จริงในระบบ
  String get _sdt => widget.setup.sysDocType ?? '';

  // แสดงเฉพาะบัญชีที่ใช้จริงตาม sys_doc_type (imTransactionController: postGlEntry/resolveCounterAccount และ
  // postApBillFromGrn/postApCreditDebitNoteFromIm/postArBillFromDln/postArCreditDebitNoteFromIm)
  // '11'/'12'/'15'/'20'/'25' ลงบัญชีผ่านเอกสาร AP เท่านั้น (ใช้ประเภทเอกสาร GL ของ AP) — ใช้บัญชีสินค้า/ผลต่าง/VAT ซื้อของหน้านี้
  static const _apLinked = ['11', '12', '15', '20', '25'];
  static const _arLinked = ['31', '32', '35', '40', '45'];
  bool get _noGl         => _sdt == '85';                                        // เปลี่ยนแปลงราคา ไม่ลงบัญชี
  bool get _showGlDoc    => !_noGl && !_apLinked.contains(_sdt);                 // postGlEntry ของ IM เอง
  bool get _showInv      => !_noGl;
  bool get _showCogs     => ['30', '60', ..._arLinked].contains(_sdt);
  bool get _showVariance => ['10', '80', '95', ..._apLinked].contains(_sdt);    // 10: ราคาซื้อ-ต้นทุนมาตรฐาน, 80: ผลต่างนับ, 95: มาตรฐาน/จริง
  bool get _showWip      => ['90', '95'].contains(_sdt);
  bool get _showGrir     => _sdt == '10';
  bool get _showConsign  => _sdt == '13';
  bool get _showVatIn    => _apLinked.contains(_sdt);
  bool get _showVatOut   => _arLinked.contains(_sdt);

  String _acctLabel(int? id, String? code, String? name, bool isEnglish, String placeholder) =>
      id != null ? '$code  ${_acctName(id, name)}' : placeholder;

  List<_JournalSection> _journalSections(bool isEnglish) {
    final inv = _acctLabel(_inventoryAccountId, _inventoryAccountCode, _inventoryAccountName, isEnglish,
        isEnglish ? '(Inventory — not set)' : '(บัญชีสินค้าคงคลัง — ยังไม่ตั้งค่า)');
    final cogs = _acctLabel(_cogsAccountId, _cogsAccountCode, _cogsAccountName, isEnglish,
        isEnglish ? '(COGS — not set)' : '(บัญชีต้นทุนขาย — ยังไม่ตั้งค่า)');
    final wip = _acctLabel(_wipAccountId, _wipAccountCode, _wipAccountName, isEnglish,
        isEnglish ? '(WIP — not set)' : '(บัญชีงานระหว่างผลิต — ยังไม่ตั้งค่า)');
    final variance = _acctLabel(_varianceAccountId, _varianceAccountCode, _varianceAccountName, isEnglish,
        isEnglish ? '(Variance — not set)' : '(บัญชีผลต่างต้นทุน — ยังไม่ตั้งค่า)');
    final grir = _acctLabel(_grirAccountId, _grirAccountCode, _grirAccountName, isEnglish,
        isEnglish ? '(GR/IR clearing — not set)' : '(บัญชีพักรอใบกำกับ GR/IR — ยังไม่ตั้งค่า)');
    final vatIn = _acctLabel(_vatInputAccountId, _vatInputAccountCode, _vatInputAccountName, isEnglish,
        isEnglish ? '(VAT Input — not set, falls back to AP\'s own setup)' : '(บัญชี VAT ซื้อ — ยังไม่ตั้งค่า จะ fallback ไปที่ของ AP เอง)');
    final consignPayable = _acctLabel(_consignmentPayableAccountId, _consignmentPayableAccountCode, _consignmentPayableAccountName, isEnglish,
        isEnglish ? '(Consignment Payable — not set)' : '(บัญชีเจ้าหนี้ฝากขาย — ยังไม่ตั้งค่า)');
    final ap = isEnglish ? '(AP — posted in AP module)' : '(เจ้าหนี้ — บันทึกในโมดูล AP)';
    final purchases = isEnglish ? 'Purchases (warehouse → item → category → company default)' : 'บัญชีซื้อสินค้า (คลัง → สินค้า → หมวดสินค้า → ค่าเริ่มต้นของบริษัท)';

    switch (_sdt) {
      case '90': // MOI — เบิกวัตถุดิบเข้าผลิต
        return [
          _JournalSection(lines: [_JournalLine('Dr', wip), _JournalLine('  Cr', isEnglish ? '$inv (Periodic lines: $purchases)' : '$inv (บรรทัด Periodic: $purchases)')]),
          _JournalSection(
            title: isEnglish ? 'Referencing a manufacturing order' : 'อ้างอิงใบสั่งผลิต',
            lines: [_JournalLine('', isEnglish ? 'WIP comes from the manufacturing order document type (MO GL Account Setup)' : 'บัญชี WIP ใช้ของประเภทเอกสารใบสั่งผลิต (หน้าตั้งค่าบัญชีใบสั่งผลิต)')],
          ),
        ];
      case '95': // MOR — รับสินค้าเข้าคลังจากการผลิต
        return [
          _JournalSection(lines: [
            _JournalLine('Dr', isEnglish ? '$inv (Periodic lines: $purchases)' : '$inv (บรรทัด Periodic: $purchases)'),
            _JournalLine('Dr/Cr', isEnglish ? '$variance (standard - actual cost, STANDARD orders)' : '$variance (ต้นทุนมาตรฐาน - ต้นทุนจริง ใบสั่งผลิตแบบ STANDARD)'),
            _JournalLine('  Cr', isEnglish ? '$wip (actual cost)' : '$wip (ต้นทุนจริง)'),
          ]),
          _JournalSection(
            title: isEnglish ? 'Percentage overhead orders' : 'ใบสั่งผลิตที่คิดโสหุ้ยเป็น %',
            lines: [
              _JournalLine('Dr', wip),
              _JournalLine('  Cr', isEnglish ? 'Applied overhead (MO GL Account Setup)' : 'โสหุ้ยการผลิตที่ปันเข้างาน (หน้าตั้งค่าบัญชีใบสั่งผลิต)'),
            ],
          ),
          _JournalSection(
            title: isEnglish ? 'Referencing a manufacturing order' : 'อ้างอิงใบสั่งผลิต',
            lines: [_JournalLine('', isEnglish ? 'WIP and variance come from the manufacturing order document type' : 'บัญชี WIP และผลต่างใช้ของประเภทเอกสารใบสั่งผลิต')],
          ),
        ];
      case '80': // AJS — ปรับยอดสินค้า
        return [
          _JournalSection(
            title: isEnglish ? 'Counted qty > system qty (surplus)' : 'ยอดนับได้ > ยอดระบบ (ส่วนเกิน)',
            lines: [_JournalLine('Dr', inv), _JournalLine('  Cr', variance)],
          ),
          _JournalSection(
            title: isEnglish ? 'Counted qty < system qty (shortage)' : 'ยอดนับได้ < ยอดระบบ (ส่วนขาด)',
            lines: [_JournalLine('Dr', variance), _JournalLine('  Cr', inv)],
          ),
        ];
      case '60': // ISS — เบิกสินค้า
        return [
          _JournalSection(lines: [_JournalLine('Dr', cogs), _JournalLine('  Cr', inv)]),
        ];
      case '70': // TRF — โอนสินค้า
        return [
          _JournalSection(lines: [
            _JournalLine('Dr', isEnglish ? '$inv (destination warehouse)' : '$inv (คลังปลายทาง)'),
            _JournalLine('  Cr', isEnglish ? '$inv (source warehouse)' : '$inv (คลังต้นทาง)'),
          ]),
          // ฝั่งที่เป็น Periodic ใช้บัญชีซื้อแทนบัญชีสต็อก — ทั้งสองฝั่ง Periodic ไม่ลงบัญชี (resolveStockSideAccount)
          _JournalSection(
            title: isEnglish ? 'A Periodic side (warehouse/item mode)' : 'ฝั่งที่เป็น Periodic (ตามโหมดของคลัง/สินค้า)',
            lines: [_JournalLine('Dr/Cr', isEnglish ? '$purchases instead of the inventory account; no entry when both sides are Periodic' : '$purchases แทนบัญชีสต็อก — ถ้าทั้งสองฝั่งเป็น Periodic ไม่ลงบัญชี')],
          ),
        ];
      case '10': // GRN — รับสินค้า (ไม่มีเลขที่อ้างอิง) — AP ตั้งหนี้เองภายหลัง (Dr GR/IR / Cr AP แยกต่างหาก)
        return [
          _JournalSection(
            title: isEnglish ? 'Perpetual lines' : 'บรรทัด Perpetual',
            lines: [
              _JournalLine('Dr', inv),
              _JournalLine('Dr/Cr', isEnglish ? '$variance (purchase price - standard cost, STANDARD items)' : '$variance (ราคาซื้อ - ต้นทุนมาตรฐาน สินค้า STANDARD)'),
              _JournalLine('  Cr', isEnglish ? '$grir (at purchase price)' : '$grir (ตามราคาซื้อ)'),
            ],
          ),
          _JournalSection(
            title: isEnglish ? 'Periodic lines' : 'บรรทัด Periodic',
            lines: [_JournalLine('Dr', purchases), _JournalLine('  Cr', grir)],
          ),
        ];
      case '13': // รับฝากขาย (Consignment) — ต้นทุนจริงตั้งแต่รับ แต่ยังไม่เป็นหนี้ AP จริง พักไว้ที่บัญชีเจ้าหนี้
        // ฝากขายแทน GR/IR จนกว่าจะขายออกและ settle เป็น AP จริงภายหลัง (ดู Consignment Settlement)
        return [
          _JournalSection(
            title: isEnglish ? 'Perpetual lines' : 'บรรทัด Perpetual',
            lines: [_JournalLine('Dr', inv), _JournalLine('  Cr', consignPayable)],
          ),
          _JournalSection(
            title: isEnglish ? 'Periodic lines' : 'บรรทัด Periodic',
            lines: [_JournalLine('Dr', purchases), _JournalLine('  Cr', consignPayable)],
          ),
        ];
      case '11': // GRN Billing — รับสินค้า+ตั้งหนี้อัตโนมัติ — ไม่ Post ที่นี่ สร้าง ap_transaction แล้วโพสต์ที่นั่นแทน
        return [
          _JournalSection(lines: [
            _JournalLine('Dr', isEnglish ? '$inv / $purchases (auto, on the AP bill)' : '$inv / $purchases (อัตโนมัติ บนใบตั้งหนี้ AP)'),
            _JournalLine('Dr/Cr', isEnglish ? '$variance (purchase price - standard cost, STANDARD items, Perpetual only)' : '$variance (ราคาซื้อ - ต้นทุนมาตรฐาน สินค้า STANDARD เฉพาะ Perpetual)'),
            _JournalLine('Dr', isEnglish ? '$vatIn (if VAT selected on a line)' : '$vatIn (ถ้าบรรทัดใดเลือก VAT)'),
            _JournalLine('  Cr', ap),
          ]),
        ];
      case '12': // GR รอตั้งหนี้ — Stage 1 (Post IM) ไม่ Post บัญชีเลย, Stage 2 (Post AP/GL) สินค้าคงคลังตามต้นทุนตอนรับ + ผลต่าง
        return [
          _JournalSection(lines: [
            _JournalLine('Dr', isEnglish ? '$inv (at received cost) / $purchases (auto, on the AP bill)' : '$inv (ตามต้นทุนตอนรับ) / $purchases (อัตโนมัติ บนใบตั้งหนี้ AP)'),
            _JournalLine('Dr/Cr', isEnglish ? '$variance (billed price - received cost, Perpetual only)' : '$variance (ราคาใบกำกับ - ต้นทุนตอนรับ เฉพาะ Perpetual)'),
            _JournalLine('Dr', isEnglish ? '$vatIn (if VAT selected on a line)' : '$vatIn (ถ้าบรรทัดใดเลือก VAT)'),
            _JournalLine('  Cr', ap),
          ]),
        ];
      case '25': // DNS — เพิ่มหนี้เจ้าหนี้
        return [
          _JournalSection(lines: [
            _JournalLine('Dr', inv),
            _JournalLine('Dr', isEnglish ? '$vatIn (if VAT selected on a line)' : '$vatIn (ถ้าบรรทัดใดเลือก VAT)'),
            _JournalLine('Dr/Cr', isEnglish ? '$variance (if the price differs from stock cost)' : '$variance (ถ้าราคาต่างจากต้นทุนสต็อก)'),
            _JournalLine('  Cr', ap),
          ]),
        ];
      case '15': // RTS — คืนสินค้า
      case '20': // CNS — ลดหนี้เจ้าหนี้
        return [
          _JournalSection(lines: [
            _JournalLine('Dr', ap),
            _JournalLine('  Cr', isEnglish ? '$inv (at actual stock cost)' : '$inv (ตามต้นทุนสต็อกจริง)'),
            _JournalLine('  Cr', isEnglish ? '$vatIn (reversed, if VAT selected on a line)' : '$vatIn (กลับรายการ ถ้าบรรทัดใดเลือก VAT)'),
            _JournalLine('Dr/Cr', isEnglish ? '$variance (price on the credit note - stock cost)' : '$variance (ราคาบนใบลดหนี้ - ต้นทุนสต็อก)'),
          ]),
        ];
      case '30': // DLN — ส่งสินค้า (ขาย)
      case '31': // DLN Billing — ส่งสินค้า+ตั้งหนี้อัตโนมัติ — ต้นทุนขาย Post ที่นี่เสมอ ใบแจ้งหนี้ AR แยกต่างหาก (ดู note ด้านล่าง)
      case '32': // DLN รอตั้งหนี้ — ต้นทุนขาย Post ทันทีตอน Post IM เหมือนกัน (ไม่ขึ้นกับราคาขาย) ต่างจาก '12' ตรงนี้
      case '45': // DNC — เพิ่มหนี้ลูกหนี้
        return [
          _JournalSection(lines: [_JournalLine('Dr', cogs), _JournalLine('  Cr', inv)]),
        ];
      case '35': // RTC — รับคืนสินค้า
      case '40': // CNC — ลดหนี้ลูกหนี้
        return [
          _JournalSection(lines: [_JournalLine('Dr', inv), _JournalLine('  Cr', cogs)]),
        ];
      default:
        return [];
    }
  }

  Widget _buildJournalPreview(bool isEnglish) {
    final sections = _journalSections(isEnglish);
    if (sections.isEmpty) return const SizedBox.shrink();
    final isLive = ['80', '60', '70', '10', '11', '12', '13', '30', '31', '32', '15', '20', '25', '35', '40', '45'].contains(_sdt);

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
          Text(isEnglish ? 'Journal Entry Preview' : 'ตัวอย่าง Journal Entry',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey.shade700)),
          const SizedBox(height: 6),
          for (final section in sections) ...[
            if (section.title != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 2),
                child: Text(section.title!, style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.blueGrey.shade600)),
              ),
            ],
            ...section.lines.map((l) => Padding(
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
                    Expanded(child: Text(l.name, style: const TextStyle(fontSize: 12))),
                  ]),
                )),
          ],
          if (!isLive) ...[
            const SizedBox(height: 6),
            Text(
              isEnglish
                  ? '* Posting for this document type is not yet implemented — shown as a conceptual reference only.'
                  : '* ประเภทเอกสารนี้ยังไม่รองรับการ Post จริงในระบบ — แสดงเป็นแนวทางบัญชีเบื้องต้นเท่านั้น',
              style: TextStyle(fontSize: 11, color: Colors.orange.shade800, fontStyle: FontStyle.italic),
            ),
          ],
          if (_sdt == '70') ...[
            const SizedBox(height: 6),
            Text(
              isEnglish
                  ? '* Inventory accounts are not yet warehouse-specific — both sides resolve to the same account today, so no GL entry actually posts until per-warehouse accounts are configured (im_warehouse).'
                  : '* บัญชีสต็อกยังไม่ได้แยกตามคลัง ทั้งสองฝั่งจึงชี้ไปที่บัญชีเดียวกันในวันนี้ — จะยังไม่มีการโพสต์ GL จริงจนกว่าจะตั้งค่าบัญชีแยกตามคลัง (im_warehouse)',
              style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600, fontStyle: FontStyle.italic),
            ),
          ],
          if (_sdt == '13') ...[
            const SizedBox(height: 6),
            Text(
              isEnglish
                  ? '* No AP bill is created when this document is posted. Consigned items must use FIFO or Specific costing. AP liability is only recognized later, in aggregate, when sold units are settled with the consignor via the Consignment Settlement screen.'
                  : '* เมื่อ Post เอกสารนี้จะยังไม่มีการสร้างใบตั้งหนี้ AP — สินค้าฝากขายต้องใช้วิธีคิดต้นทุนแบบ FIFO หรือ Specific เท่านั้น และจะรับรู้เป็นหนี้ AP จริงเป็นก้อนภายหลัง เมื่อทำการ Settlement กับผู้ฝากขายตามจำนวนที่ขายออกจริง ผ่านหน้า Consignment Settlement',
              style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600, fontStyle: FontStyle.italic),
            ),
          ],
          if (_sdt == '11') ...[
            const SizedBox(height: 6),
            Text(
              isEnglish
                  ? '* This document type does not post its own GL entry — Posting it creates a linked AP Purchase Invoice automatically, and that invoice\'s own entry is the one shown above.'
                  : '* ประเภทเอกสารนี้ไม่ได้ Post บัญชีของตัวเอง — เมื่อ Post จะสร้างใบตั้งหนี้ในโมดูล AP ให้อัตโนมัติ และ entry ที่แสดงด้านบนคือ entry ของใบตั้งหนี้นั้น',
              style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600, fontStyle: FontStyle.italic),
            ),
          ],
          if (_sdt == '12') ...[
            const SizedBox(height: 6),
            Text(
              isEnglish
                  ? '* Two-stage: "Post IM" posts no GL at all (goods received, invoice not yet in hand). Only "Post AP/GL" later — when the vendor invoice arrives — creates the linked AP Purchase Invoice shown above, using the billed cost entered at that point.'
                  : '* สองขั้นตอน: "Post IM" จะยังไม่มีการ Post บัญชีใดๆ เลย (รับของแล้วแต่ยังไม่ได้ใบกำกับ) ต้องรอ "Post AP/GL" ภายหลังเมื่อได้รับใบกำกับจากผู้ขายก่อน จึงจะสร้างใบตั้งหนี้ AP ตาม entry ด้านบน โดยใช้ต้นทุนตามใบกำกับที่กรอก ณ ตอนนั้น',
              style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600, fontStyle: FontStyle.italic),
            ),
          ],
          if (['15', '20', '25'].contains(_sdt)) ...[
            const SizedBox(height: 6),
            Text(
              isEnglish
                  ? '* This document type does not post its own GL entry — Posting it creates a linked AP Credit/Debit Note automatically, and that document\'s own entry is the one shown above.'
                  : '* ประเภทเอกสารนี้ไม่ได้ Post บัญชีของตัวเอง — เมื่อ Post จะสร้างใบลดหนี้/เพิ่มหนี้ในโมดูล AP ให้อัตโนมัติ และ entry ที่แสดงด้านบนคือ entry ของใบนั้น',
              style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600, fontStyle: FontStyle.italic),
            ),
          ],
          if (_sdt == '31') ...[
            const SizedBox(height: 6),
            Text(
              isEnglish
                  ? '* Two separate entries post: the COGS entry above (this module — Periodic lines are skipped, same as plain DLN/ISS) plus a linked AR Invoice\'s own entry (created automatically, not shown here, and always posts regardless of mode since it is a real obligation to the customer, not a stock valuation).'
                  : '* มีการ Post 2 entry แยกกัน: entry ต้นทุนขายข้างบน (โมดูลนี้ — บรรทัด Periodic ไม่ลง เหมือน DLN ธรรมดา/ISS) กับ entry ของใบแจ้งหนี้ AR ที่สร้างอัตโนมัติ (ไม่ได้แสดงที่นี่ และ Post เสมอไม่ว่าโหมดใด เพราะเป็นภาระผูกพันจริงกับลูกค้า ไม่ใช่การตีมูลค่าสต็อก)',
              style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600, fontStyle: FontStyle.italic),
            ),
          ],
          if (_sdt == '32') ...[
            const SizedBox(height: 6),
            Text(
              isEnglish
                  ? '* Two-stage: "Post IM" posts the COGS entry above immediately (cost comes from the stock ledger, independent of the not-yet-issued selling price). "Post AR/GL" later creates the linked AR Invoice separately (not shown here) once the price is confirmed.'
                  : '* สองขั้นตอน: "Post IM" จะ Post entry ต้นทุนขายข้างบนทันที (ต้นทุนมาจาก stock ledger ไม่ขึ้นกับราคาขายที่ยังไม่ออกใบแจ้งหนี้) ต้องรอ "Post AR/GL" ภายหลังจึงจะสร้างใบแจ้งหนี้ AR แยกต่างหาก (ไม่ได้แสดงที่นี่) เมื่อยืนยันราคาขายแล้ว',
              style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600, fontStyle: FontStyle.italic),
            ),
          ],
          if (['35', '40', '45'].contains(_sdt)) ...[
            const SizedBox(height: 6),
            Text(
              isEnglish
                  ? '* Two separate entries post: the COGS entry above (this module) plus a linked AR Credit/Debit Note\'s own entry (created automatically, not shown here) — matching the DLN sale/invoice split.'
                  : '* มีการ Post 2 entry แยกกัน: entry ต้นทุนขายข้างบน (โมดูลนี้) กับ entry ของใบลดหนี้/เพิ่มหนี้ AR ที่สร้างอัตโนมัติ (ไม่ได้แสดงที่นี่) — มิเรอร์การแยก entry ของ DLN ตอนขาย/ตั้งหนี้',
              style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  String? _targetDocDisplayName(bool isEnglish) {
    final m = widget.targetDocs.cast<ModuleDocument?>().firstWhere((d) => d?.id == _targetDocId, orElse: () => null);
    if (m == null) return _targetDocName;
    return isEnglish && m.docNameEng.isNotEmpty ? m.docNameEng : m.docNameThai;
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
              Text(isEnglish && (s.docNameEng ?? '').isNotEmpty ? s.docNameEng! : (s.docNameThai ?? s.docCode), style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
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
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.blueGrey.shade200)),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 16, color: Colors.blueGrey),
            const SizedBox(width: 8),
            Expanded(child: Text(_targetLabel(isEnglish), style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700))),
          ]),
        ),
        const SizedBox(height: 16),

        if (_noGl || _apLinked.contains(_sdt))
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.blueGrey.shade200)),
            child: Text(
              _noGl
                  ? (isEnglish ? 'This document type does not post to the GL — no accounts to set up.' : 'เอกสารประเภทนี้ไม่ลงบัญชี GL — ไม่ต้องตั้งค่ารหัสบัญชี')
                  : (isEnglish
                      ? 'Posted through the linked AP document — the GL document type comes from the AP account setup; only the accounts below are used from here.'
                      : 'ลงบัญชีผ่านเอกสาร AP ที่สร้างอัตโนมัติ — ประเภทเอกสาร GL ใช้ของการตั้งค่าบัญชี AP ใช้เฉพาะรหัสบัญชีด้านล่างจากหน้านี้'),
              style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700),
            ),
          ),

        if (s.targetAuto) ...[
        _SectionHeader(title: isEnglish ? '${s.targetModule} Document Type (created automatically)' : 'ประเภทเอกสาร ${s.targetModule} (สร้างอัตโนมัติ)'),
        InkWell(
          onTap: _pickTargetDoc,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: isEnglish ? '${s.targetModule} ${_targetKind(true)} document type (required)' : 'ประเภทเอกสาร${_targetKind(false)} ${s.targetModule} (ต้องระบุ)',
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              errorText: _targetDocId == null ? (isEnglish ? 'Required before posting this document type' : 'ต้องตั้งก่อน Post เอกสารประเภทนี้') : null,
              suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                if (_targetDocId != null)
                  IconButton(icon: const Icon(Icons.clear, size: 16), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => setState(() { _targetDocId = null; _targetDocCode = null; _targetDocName = null; })),
                const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.description_outlined, size: 18)),
              ]),
            ),
            child: Text(
              _targetDocId != null ? '$_targetDocCode  ${_targetDocDisplayName(isEnglish) ?? ''}' : (isEnglish ? '— Not specified —' : '— ไม่ระบุ —'),
              style: TextStyle(fontSize: 13, color: _targetDocId != null ? null : Colors.grey.shade500),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ],

        if (_showGlDoc) ...[
        _SectionHeader(title: isEnglish ? 'GL Document Type (for Posting)' : 'ประเภทเอกสาร GL (สำหรับ Post)'),
        InkWell(
          onTap: _pickGlDoc,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: isEnglish ? 'GL Document Type' : 'ประเภทเอกสาร GL',
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                if (_glDocId != null)
                  IconButton(icon: const Icon(Icons.clear, size: 16), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => setState(() { _glDocId = null; _glDocCode = null; _glDocName = null; })),
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
        ],

        if (_showInv) _SectionHeader(title: isEnglish ? 'Account Codes' : 'รหัสบัญชี'),
        if (_showInv)
        _accountField(
          label: isEnglish ? 'Inventory Account' : 'บัญชีสินค้าคงคลัง',
          accountId: _inventoryAccountId, accountCode: _inventoryAccountCode, accountName: _inventoryAccountName,
          onPick: (a) { _inventoryAccountId = a.id; _inventoryAccountCode = a.accountCode; _inventoryAccountName = a.accountNameThai; },
          onClear: () => setState(() { _inventoryAccountId = null; _inventoryAccountCode = null; _inventoryAccountName = null; }),
        ),
        if (_showCogs)
        _accountField(
          label: isEnglish ? 'COGS Account' : 'บัญชีต้นทุนขาย',
          accountId: _cogsAccountId, accountCode: _cogsAccountCode, accountName: _cogsAccountName,
          onPick: (a) { _cogsAccountId = a.id; _cogsAccountCode = a.accountCode; _cogsAccountName = a.accountNameThai; },
          onClear: () => setState(() { _cogsAccountId = null; _cogsAccountCode = null; _cogsAccountName = null; }),
        ),
        if (_showVariance)
        _accountField(
          label: isEnglish ? 'Variance Account' : 'บัญชีผลต่างต้นทุน',
          accountId: _varianceAccountId, accountCode: _varianceAccountCode, accountName: _varianceAccountName,
          onPick: (a) { _varianceAccountId = a.id; _varianceAccountCode = a.accountCode; _varianceAccountName = a.accountNameThai; },
          onClear: () => setState(() { _varianceAccountId = null; _varianceAccountCode = null; _varianceAccountName = null; }),
        ),
        if (_showWip)
        _accountField(
          label: isEnglish ? 'WIP Account' : 'บัญชีงานระหว่างผลิต (WIP)',
          accountId: _wipAccountId, accountCode: _wipAccountCode, accountName: _wipAccountName,
          onPick: (a) { _wipAccountId = a.id; _wipAccountCode = a.accountCode; _wipAccountName = a.accountNameThai; },
          onClear: () => setState(() { _wipAccountId = null; _wipAccountCode = null; _wipAccountName = null; }),
        ),
        if (_showGrir)
        _accountField(
          label: isEnglish ? 'GR/IR Clearing Account (used by "10" — GRN with no reference)' : 'บัญชีพักรอใบกำกับ GR/IR (ใช้กับ "10" — รับสินค้าไม่มีเลขที่อ้างอิง)',
          accountId: _grirAccountId, accountCode: _grirAccountCode, accountName: _grirAccountName,
          onPick: (a) { _grirAccountId = a.id; _grirAccountCode = a.accountCode; _grirAccountName = a.accountNameThai; },
          onClear: () => setState(() { _grirAccountId = null; _grirAccountCode = null; _grirAccountName = null; }),
        ),
        if (_showConsign)
        _accountField(
          label: isEnglish ? 'Consignment Payable Account (used by "13" — Consignment Receipt)' : 'บัญชีเจ้าหนี้ฝากขาย (ใช้กับ "13" — รับฝากขาย)',
          accountId: _consignmentPayableAccountId, accountCode: _consignmentPayableAccountCode, accountName: _consignmentPayableAccountName,
          onPick: (a) { _consignmentPayableAccountId = a.id; _consignmentPayableAccountCode = a.accountCode; _consignmentPayableAccountName = a.accountNameThai; },
          onClear: () => setState(() { _consignmentPayableAccountId = null; _consignmentPayableAccountCode = null; _consignmentPayableAccountName = null; }),
        ),
        if (_showVatIn)
        _accountField(
          label: isEnglish
              ? 'VAT Input Account (used by "11"/"12"/"15"/"20"/"25" — overrides AP\'s own setup)'
              : 'บัญชี VAT ซื้อ (ใช้กับ "11"/"12"/"15"/"20"/"25" — override บัญชี VAT ของ AP เอง)',
          accountId: _vatInputAccountId, accountCode: _vatInputAccountCode, accountName: _vatInputAccountName,
          onPick: (a) { _vatInputAccountId = a.id; _vatInputAccountCode = a.accountCode; _vatInputAccountName = a.accountNameThai; },
          onClear: () => setState(() { _vatInputAccountId = null; _vatInputAccountCode = null; _vatInputAccountName = null; }),
        ),
        if (_showVatOut)
        _accountField(
          label: isEnglish
              ? 'VAT Output Account (used by "31"/"32"/"35"/"40"/"45" — overrides AR\'s own setup)'
              : 'บัญชี VAT ขาย (ใช้กับ "31"/"32"/"35"/"40"/"45" — override บัญชี VAT ของ AR เอง)',
          accountId: _vatOutputAccountId, accountCode: _vatOutputAccountCode, accountName: _vatOutputAccountName,
          onPick: (a) { _vatOutputAccountId = a.id; _vatOutputAccountCode = a.accountCode; _vatOutputAccountName = a.accountNameThai; },
          onClear: () => setState(() { _vatOutputAccountId = null; _vatOutputAccountCode = null; _vatOutputAccountName = null; }),
        ),

        _buildJournalPreview(isEnglish),

        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: (_isSaving || !(MenuScope.of(context)?.canEdit ?? true)) ? null : _submit,
              icon: _isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
              label: Text(_isSaving ? (isEnglish ? 'Saving...' : 'กำลังบันทึก...') : (isEnglish ? 'Save' : 'บันทึก')),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
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
      child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey.shade700)),
    );
  }
}

class _JournalSection {
  final String? title;
  final List<_JournalLine> lines;
  _JournalSection({this.title, required this.lines});
}

class _JournalLine {
  final String drCr, name;
  _JournalLine(this.drCr, this.name);
}
