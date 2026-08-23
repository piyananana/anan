import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/utils/sa_menu_scope.dart';
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
        _glDocs = (results[2] as List<ModuleDocument>).where((d) => d.isDocType && d.sysModule == '01' && d.isActive).toList()
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
  final Future<void> Function(ImGlAccountSetup) onSave;

  const _ImGlSetupForm({
    super.key,
    required this.setup,
    required this.accounts,
    required this.glDocs,
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
  int? _glDocId;            String? _glDocCode;            String? _glDocName;
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
    _glDocId            = s.glDocId;            _glDocCode            = s.glDocCode;            _glDocName            = s.glDocName;
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
    final searchCtrl = TextEditingController();
    List<ModuleDocument> filtered = List.from(widget.glDocs);
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
                onChanged: (q) => setDlg(() {
                  final lq = q.toLowerCase();
                  filtered = q.isEmpty
                      ? List.from(widget.glDocs)
                      : widget.glDocs.where((d) => d.docCode.toLowerCase().contains(lq) || d.docNameThai.toLowerCase().contains(lq) || d.docNameEng.toLowerCase().contains(lq)).toList();
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
    if (picked != null) {
      setState(() { _glDocId = picked!.id; _glDocCode = picked!.docCode; _glDocName = picked!.docNameThai; });
    }
  }

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    try {
      final updated = ImGlAccountSetup(
        docCode: widget.setup.docCode,
        targetModule: widget.setup.targetModule,
        targetDocCode: widget.setup.targetDocCode,
        glDocId: _glDocId, glDocCode: _glDocCode, glDocName: _glDocName,
        inventoryAccountId: _inventoryAccountId, inventoryAccountCode: _inventoryAccountCode, inventoryAccountName: _inventoryAccountName,
        cogsAccountId: _cogsAccountId, cogsAccountCode: _cogsAccountCode, cogsAccountName: _cogsAccountName,
        varianceAccountId: _varianceAccountId, varianceAccountCode: _varianceAccountCode, varianceAccountName: _varianceAccountName,
        wipAccountId: _wipAccountId, wipAccountCode: _wipAccountCode, wipAccountName: _wipAccountName,
      );
      await widget.onSave(updated);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _targetLabel(bool isEnglish) {
    final s = widget.setup;
    if (s.targetModule == 'NONE') return isEnglish ? 'Internal only — no AR/AP document is created' : 'ภายในเท่านั้น — ไม่สร้างเอกสาร AR/AP';
    final moduleLabel = s.targetModule == 'AP' ? 'AP' : 'AR';
    return isEnglish
        ? 'Creates $moduleLabel document type "${s.targetDocCode}" when posted'
        : 'เมื่อ Post จะสร้างเอกสาร $moduleLabel ประเภท "${s.targetDocCode}"';
  }

  // ── Journal preview ───────────────────────────────────────────────────────
  // Dr/Cr ต้องขึ้นกับ sys_doc_type (มาตรฐานคงที่ตาม imSysDocType ใน sa_anan_module.dart) เสมอ ไม่ใช่ doc_code
  // เพราะแต่ละ sys_doc_type อาจมีได้หลาย doc_code (เช่น GRN1/GRN2 ใต้ sys_doc_type='10') ซึ่งแต่ละตัวมีรหัสบัญชี
  // ของตัวเอง แต่ยึดพฤติกรรม Dr/Cr เดียวกัน — รูปแบบเดียวกับ ar_gl_account_setup_screen.dart's `_sdt`
  // AJS (sys_doc_type='80') ตรงกับ logic ที่ใช้งานจริงใน imTransactionController.js:postGlEntry
  // (ส่วนเกิน = Dr คลัง/Cr ผลต่าง, ส่วนขาด = กลับด้าน) ส่วน sys_doc_type อื่นยังไม่มีการ Post จริงในระบบ
  String get _sdt => widget.setup.sysDocType ?? '';

  String _acctLabel(int? id, String? code, String? name, bool isEnglish, String placeholder) =>
      id != null ? '$code  ${_acctName(id, name)}' : placeholder;

  List<_JournalSection> _journalSections(bool isEnglish) {
    final inv = _acctLabel(_inventoryAccountId, _inventoryAccountCode, _inventoryAccountName, isEnglish,
        isEnglish ? '(Inventory — not set)' : '(บัญชีสินค้าคงคลัง — ยังไม่ตั้งค่า)');
    final cogs = _acctLabel(_cogsAccountId, _cogsAccountCode, _cogsAccountName, isEnglish,
        isEnglish ? '(COGS — not set)' : '(บัญชีต้นทุนขาย — ยังไม่ตั้งค่า)');
    final variance = _acctLabel(_varianceAccountId, _varianceAccountCode, _varianceAccountName, isEnglish,
        isEnglish ? '(Variance — not set)' : '(บัญชีผลต่างต้นทุน — ยังไม่ตั้งค่า)');
    final ap = isEnglish ? '(AP — posted in AP module)' : '(เจ้าหนี้ — บันทึกในโมดูล AP)';

    switch (_sdt) {
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
        ];
      case '10': // GRN — รับสินค้า
      case '25': // DNS — เพิ่มหนี้เจ้าหนี้
        return [
          _JournalSection(lines: [_JournalLine('Dr', inv), _JournalLine('  Cr', ap)]),
        ];
      case '15': // RTS — คืนสินค้า
      case '20': // CNS — ลดหนี้เจ้าหนี้
        return [
          _JournalSection(lines: [_JournalLine('Dr', ap), _JournalLine('  Cr', inv)]),
        ];
      case '30': // DLN — ส่งสินค้า (ขาย)
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
    final isLive = ['80', '60', '70'].contains(_sdt);

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
        ],
      ),
    );
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

        _SectionHeader(title: isEnglish ? 'Account Codes' : 'รหัสบัญชี'),
        _accountField(
          label: isEnglish ? 'Inventory Account' : 'บัญชีสินค้าคงคลัง',
          accountId: _inventoryAccountId, accountCode: _inventoryAccountCode, accountName: _inventoryAccountName,
          onPick: (a) { _inventoryAccountId = a.id; _inventoryAccountCode = a.accountCode; _inventoryAccountName = a.accountNameThai; },
          onClear: () => setState(() { _inventoryAccountId = null; _inventoryAccountCode = null; _inventoryAccountName = null; }),
        ),
        _accountField(
          label: isEnglish ? 'COGS Account' : 'บัญชีต้นทุนขาย',
          accountId: _cogsAccountId, accountCode: _cogsAccountCode, accountName: _cogsAccountName,
          onPick: (a) { _cogsAccountId = a.id; _cogsAccountCode = a.accountCode; _cogsAccountName = a.accountNameThai; },
          onClear: () => setState(() { _cogsAccountId = null; _cogsAccountCode = null; _cogsAccountName = null; }),
        ),
        _accountField(
          label: isEnglish ? 'Variance Account' : 'บัญชีผลต่างต้นทุน',
          accountId: _varianceAccountId, accountCode: _varianceAccountCode, accountName: _varianceAccountName,
          onPick: (a) { _varianceAccountId = a.id; _varianceAccountCode = a.accountCode; _varianceAccountName = a.accountNameThai; },
          onClear: () => setState(() { _varianceAccountId = null; _varianceAccountCode = null; _varianceAccountName = null; }),
        ),
        _accountField(
          label: isEnglish ? 'WIP Account' : 'บัญชีงานระหว่างผลิต (WIP)',
          accountId: _wipAccountId, accountCode: _wipAccountCode, accountName: _wipAccountName,
          onPick: (a) { _wipAccountId = a.id; _wipAccountCode = a.accountCode; _wipAccountName = a.accountNameThai; },
          onClear: () => setState(() { _wipAccountId = null; _wipAccountCode = null; _wipAccountName = null; }),
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
