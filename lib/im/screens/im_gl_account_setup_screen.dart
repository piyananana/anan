import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../../sa/widgets/sa_sys_doc_type_guide.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/services/sa_module_document_service.dart';
import '../../ar/models/ar_customer.dart';
import '../../ar/widgets/ar_customer_list_widget.dart';
import '../../ap/models/ap_vendor.dart';
import '../../ap/widgets/ap_vendor_list_widget.dart';
import '../models/im_accounting_setting.dart';
import '../models/im_gl_account_setup.dart';
import '../services/im_gl_account_setup_service.dart';
import '../services/im_accounting_setting_service.dart';
import '../widgets/im_master_kit.dart';
import '../../sa/utils/sa_menu_theme.dart';

// ประเภทเอกสาร IM เชื่อมต่อบัญชีแยกประเภท — หน้าตาแบบ B ของ IM (user 2026-11-26):
// ซ้ายการ์ดจัดกลุ่ม ซื้อ/ขาย/ภายใน/ผลิต + ป้าย ครบ/ขาด N/ไม่ลงบัญชี + ตัวกรองยังไม่ครบ
// ขวา: แถบหัว (ดู → แก้ไข), ตัวเลขสรุป, การเชื่อมเอกสาร, ตารางรหัสบัญชีพร้อม "ถ้าเว้นว่าง ใช้", ตัวอย่างการลงบัญชี Dr/Cr,
// สำเนาการตั้งค่าจากประเภทเอกสารอื่นใต้ประเภทระบบเดียวกัน

// ── บัญชีที่แต่ละ sys_doc_type ใช้จริง (imTransactionController: postGlEntry/resolveCounterAccount และ
// postApBillFromGrn/postApCreditDebitNoteFromIm/postArBillFromDln/postArCreditDebitNoteFromIm) ──
// '11'/'12'/'14'/'15'/'20'/'25' ลงบัญชีผ่านเอกสาร AP เท่านั้น (ใช้ประเภทเอกสาร GL ของ AP) — ใช้บัญชีสินค้า/ผลต่าง/VAT ซื้อของหน้านี้
class ImGlSdt {
  static const apLinked = ['11', '12', '14', '15', '20', '25'];
  static const arLinked = ['31', '32', '33', '35', '40', '45'];
  static bool noGl(String s) => s == '85'; // เปลี่ยนแปลงราคา ไม่ลงบัญชี
  static bool showGlDoc(String s) => !noGl(s) && !apLinked.contains(s); // postGlEntry ของ IM เอง
  static bool showInv(String s) => !noGl(s);
  static bool showCogs(String s) => ['30', '60', ...arLinked].contains(s);
  static bool showVariance(String s) => ['10', '80', '95', ...apLinked].contains(s); // 10: ราคาซื้อ-ต้นทุนมาตรฐาน, 80: ผลต่างนับ, 95: มาตรฐาน/จริง
  static bool showWip(String s) => ['90', '95'].contains(s);
  static bool showGrir(String s) => s == '10';
  static bool showConsign(String s) => s == '13';
  static bool showVatIn(String s) => apLinked.contains(s);
  static bool showVatOut(String s) => arLinked.contains(s);

  /// กลุ่มงานของการ์ดซ้าย
  static String group(String s) {
    final n = int.tryParse(s) ?? 0;
    if (n >= 90) return 'MFG';
    if (n < 30) return 'BUY';
    if (n < 60) return 'SELL';
    return 'INT';
  }

  /// ช่องที่ยังไม่ตั้ง — นับเฉพาะช่องที่ไม่มีค่าอื่นมาแทน (บัญชีสต็อก/ต้นทุนขายมีค่าเริ่มต้นบริษัท, VAT มีของ AP/AR)
  static List<String> missing({
    required String sdt,
    required bool e,
    required String targetModule,
    required bool targetAuto,
    required bool needsReceipt,
    int? targetDocId,
    int? receiptDocId,
    int? glDocId,
    int? inv,
    int? cogs,
    int? variance,
    int? wip,
    int? grir,
    int? consign,
    int? companyInv,
    int? companyCogs,
  }) {
    if (noGl(sdt)) return const [];
    return [
      if (targetAuto && targetDocId == null) e ? '$targetModule document type' : 'ประเภทเอกสาร $targetModule',
      if (needsReceipt && receiptDocId == null)
        targetModule == 'AP' ? (e ? 'AP payment document type' : 'ประเภทเอกสารจ่ายชำระ AP') : (e ? 'AR receipt document type' : 'ประเภทเอกสารรับชำระ AR'),
      if (showGlDoc(sdt) && glDocId == null) e ? 'GL document type' : 'ประเภทเอกสาร GL',
      if (showInv(sdt) && inv == null && companyInv == null) e ? 'Inventory account' : 'บัญชีสินค้าคงคลัง',
      if (showCogs(sdt) && cogs == null && companyCogs == null) e ? 'COGS account' : 'บัญชีต้นทุนขาย',
      if (showVariance(sdt) && variance == null) e ? 'Variance account' : 'บัญชีผลต่างต้นทุน',
      if (showWip(sdt) && wip == null) e ? 'WIP account' : 'บัญชีงานระหว่างผลิต',
      if (showGrir(sdt) && grir == null) e ? 'GR/IR clearing account' : 'บัญชีพักรอใบกำกับ GR/IR',
      if (showConsign(sdt) && consign == null) e ? 'Consignment payable account' : 'บัญชีเจ้าหนี้ฝากขาย',
    ];
  }

  static List<String> missingOfRow(ImGlAccountSetup r, bool e, int? companyInv, int? companyCogs) => missing(
        sdt: r.sysDocType ?? '',
        e: e,
        targetModule: r.targetModule,
        targetAuto: r.targetAuto,
        needsReceipt: r.receiptDocCode != null,
        targetDocId: r.targetDocId,
        receiptDocId: r.receiptTargetDocId,
        glDocId: r.glDocId,
        inv: r.inventoryAccountId,
        cogs: r.cogsAccountId,
        variance: r.varianceAccountId,
        wip: r.wipAccountId,
        grir: r.grirAccountId,
        consign: r.consignmentPayableAccountId,
        companyInv: companyInv,
        companyCogs: companyCogs,
      );
}

class ImGlAccountSetupScreen extends StatefulWidget {
  const ImGlAccountSetupScreen({super.key});

  @override
  State<ImGlAccountSetupScreen> createState() => _ImGlAccountSetupScreenState();
}

class _ImGlAccountSetupScreenState extends State<ImGlAccountSetupScreen> with AutomaticKeepAliveClientMixin {
  final ImGlAccountSetupService _svc = ImGlAccountSetupService();
  final ModuleDocumentService _docSvc = ModuleDocumentService();
  final AccountService _acctSvc = AccountService();
  final ImAccountingSettingService _settingSvc = ImAccountingSettingService();
  final GlobalKey<_ImGlSetupFormState> _formKey = GlobalKey();
  final TextEditingController _searchCtrl = TextEditingController();

  List<ImGlAccountSetup> _rows = [];
  List<Account> _accounts = [];
  List<ModuleDocument> _glDocs = [];
  List<ModuleDocument> _allDocs = [];
  int? _companyInvId, _companyCogsId;

  bool _isEnglish = false;
  bool _isLoading = true;
  String _selectedDocCode = '';
  String _search = '';
  String _filter = ''; // '' ทั้งหมด / MISSING / BUY / SELL / INT / MFG

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final isEnglish = _isEnglish;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _svc.fetchRows(),
        _acctSvc.fetchRows(),
        _docSvc.fetchRows(),
        _settingSvc.fetchSetting().catchError((_) => null),
      ]);
      setState(() {
        _rows = results[0] as List<ImGlAccountSetup>;
        _accounts = (results[1] as List<Account>).where((a) => a.isActive && a.isNormalAccount).toList()
          ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
        _allDocs = results[2] as List<ModuleDocument>;
        _glDocs = _allDocs.where((d) => d.isDocType && d.sysModule == '01' && d.isActive).toList()..sort((a, b) => a.docCode.compareTo(b.docCode));
        final setting = results[3] as ImAccountingSetting?;
        _companyInvId = setting?.inventoryAccountId;
        _companyCogsId = setting?.cogsAccountId;
        _isLoading = false;
        if (_rows.isNotEmpty && (_selectedDocCode.isEmpty || !_rows.any((r) => r.docCode == _selectedDocCode))) {
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

  String _docLabel(ImGlAccountSetup row, bool isEnglish) => isEnglish && (row.docNameEng ?? '').isNotEmpty ? row.docNameEng! : (row.docNameThai ?? row.docCode);

  Future<bool> _confirmLeave() async {
    final f = _formKey.currentState;
    if (f != null && f.isDirty) return confirmDiscardChanges(context, _isEnglish);
    return true;
  }

  Future<void> _select(String docCode) async {
    if (docCode == _selectedDocCode) return;
    if (!await _confirmLeave()) return;
    setState(() => _selectedDocCode = docCode);
  }

  Future<bool> _onSave(ImGlAccountSetup updated) async {
    final isEnglish = _isEnglish;
    try {
      final saved = await _svc.upsertRow(updated.docCode, updated);
      setState(() {
        final idx = _rows.indexWhere((r) => r.docCode == saved.docCode);
        if (idx >= 0) _rows[idx] = saved;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Saved successfully' : 'บันทึกสำเร็จ')));
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Save failed: $e' : 'บันทึกล้มเหลว: $e'), backgroundColor: Colors.red));
      }
      return false;
    }
  }

  String _groupLabel(String g, bool e) => switch (g) {
        'BUY' => e ? 'Purchasing / receiving' : 'ซื้อ / รับสินค้า',
        'SELL' => e ? 'Sales / delivery' : 'ขาย / ส่งสินค้า',
        'MFG' => e ? 'Manufacturing' : 'ผลิต',
        _ => e ? 'Internal' : 'ภายใน',
      };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final sel = _selected;

    Widget detail;
    if (_isLoading && _rows.isEmpty) {
      detail = const ColoredBox(color: ImKit.pageBg, child: Center(child: CircularProgressIndicator()));
    } else if (sel == null) {
      detail = Builder(
          builder: (ctx) => ImListToggle.placeholder(
              ctx, Icons.account_tree_outlined, isEnglish ? 'Select an IM document type on the left' : 'เลือกประเภทเอกสาร IM ด้านซ้าย'));
    } else {
      detail = _ImGlSetupForm(
        key: _formKey,
        setup: sel,
        accounts: _accounts,
        glDocs: _glDocs,
        // ประเภทเอกสาร AR/AP ปลายทางที่เลือกได้ — ตรงโมดูลและ sys_doc_type ที่ประเภทเอกสาร IM นี้สร้าง
        targetDocs: sel.targetAuto
            ? (_allDocs
                .where((d) => d.isDocType && d.isActive && d.sysModule == (sel.targetModule == 'AP' ? '21' : '11') && d.sysDocType == sel.targetDocCode)
                .toList()
              ..sort((a, b) => a.docCode.compareTo(b.docCode)))
            : const [],
        // ขายเงินสด/ซื้อเงินสด: ประเภทเอกสารรับชำระ AR / จ่ายชำระ AP ที่เลือกได้
        receiptDocs: sel.receiptDocCode != null
            ? (_allDocs
                .where((d) => d.isDocType && d.isActive && d.sysModule == (sel.targetModule == 'AP' ? '21' : '11') && d.sysDocType == sel.receiptDocCode)
                .toList()
              ..sort((a, b) => a.docCode.compareTo(b.docCode)))
            : const [],
        siblings: _rows.where((r) => r.sysDocType == sel.sysDocType && r.docCode != sel.docCode).toList(),
        companyInvId: _companyInvId,
        companyCogsId: _companyCogsId,
        onSave: _onSave,
      );
    }

    return ImMasterShell(
      isEnglish: isEnglish,
      initialListWidth: 320,
      barActions: [
        SysDocTypeGuideButton(
          module: 'IM',
          isEnglish: isEnglish,
          docCodesBySdt: SysDocTypeGuideButton.groupDocCodes(_rows, (r) => r.sysDocType, (r) => r.docCode),
          currentSdt: sel?.sysDocType,
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          tooltip: isEnglish ? 'Reload' : 'โหลดใหม่',
          onPressed: () async {
            if (!await _confirmLeave()) return;
            _loadAll();
          },
        ),
      ],
      list: _buildList(isEnglish),
      detail: detail,
    );
  }

  Widget _buildList(bool e) {
    final q = _search.trim().toLowerCase();
    final missingOf = {for (final r in _rows) r.docCode: ImGlSdt.missingOfRow(r, e, _companyInvId, _companyCogsId)};
    bool match(ImGlAccountSetup r) {
      final sdt = r.sysDocType ?? '';
      if (_filter == 'MISSING' && (missingOf[r.docCode]?.isEmpty ?? true)) return false;
      if (['BUY', 'SELL', 'INT', 'MFG'].contains(_filter) && ImGlSdt.group(sdt) != _filter) return false;
      if (q.isEmpty) return true;
      return r.docCode.toLowerCase().contains(q) ||
          (r.docNameThai ?? '').toLowerCase().contains(q) ||
          (r.docNameEng ?? '').toLowerCase().contains(q) ||
          sdt.contains(q);
    }

    final shown = _rows.where(match).toList();
    final missingCount = _rows.where((r) => missingOf[r.docCode]!.isNotEmpty).length;
    final groups = <String, List<ImGlAccountSetup>>{};
    for (final g in ['BUY', 'SELL', 'INT', 'MFG']) {
      final list = shown.where((r) => ImGlSdt.group(r.sysDocType ?? '') == g).toList();
      if (list.isNotEmpty) groups[g] = list;
    }

    Widget card(ImGlAccountSetup r) {
      final sdt = r.sysDocType ?? '';
      final miss = missingOf[r.docCode]!;
      final status = ImGlSdt.noGl(sdt)
          ? ImKit.chip(e ? 'No GL' : 'ไม่ลงบัญชี', ImKit.ro, ImKit.gMore)
          : miss.isEmpty
              ? ImKit.chip(e ? 'Complete' : 'ครบ', ImKit.okSoft, ImKit.ok)
              : ImKit.chip(e ? '${miss.length} missing' : 'ขาด ${miss.length}', ImKit.redSoft, ImKit.red);
      final String meta;
      if (ImGlSdt.noGl(sdt)) {
        meta = e ? 'Nothing to set up' : 'ไม่ต้องตั้งค่า';
      } else if (r.targetAuto) {
        final t = r.targetDocCodeSel;
        meta = e ? 'Creates ${r.targetModule} automatically · ${t ?? 'type not chosen'}' : 'สร้าง ${r.targetModule} อัตโนมัติ · ${t ?? 'ยังไม่เลือกประเภท'}';
      } else if (ImGlSdt.showGlDoc(sdt)) {
        meta = 'GL: ${r.glDocCode ?? (e ? 'not set' : 'ยังไม่ตั้ง')}${r.targetModule == 'NONE' ? (e ? ' · internal only' : ' · ภายในเท่านั้น') : ''}';
      } else {
        meta = e ? 'Posted through the ${r.targetModule} document' : 'ลงบัญชีผ่านเอกสาร ${r.targetModule}';
      }
      return Tooltip(
        message: miss.isEmpty ? '' : miss.join(', '),
        child: ImMasterListCard(
          code: r.docCode,
          chips: [if (sdt.isNotEmpty) ImKit.chip(sdt, ImKit.blueSoft, ImKit.blue), status],
          name: _docLabel(r, e),
          meta: TextSpan(text: meta),
          selected: r.docCode == _selectedDocCode,
          active: r.docIsActive ?? true,
          onTap: () => _select(r.docCode),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ImMasterListHeader(
        searchCtrl: _searchCtrl,
        hint: e ? 'Search code / name' : 'ค้นหา รหัส / ชื่อประเภทเอกสาร',
        onSearch: (v) => setState(() => _search = v),
        filters: [
          ImMasterFilterChip(label: e ? 'All ${_rows.length}' : 'ทั้งหมด ${_rows.length}', on: _filter == '', onTap: () => setState(() => _filter = '')),
          ImMasterFilterChip(
              label: e ? 'Incomplete $missingCount' : 'ยังไม่ครบ $missingCount',
              on: _filter == 'MISSING',
              fg: missingCount > 0 ? ImKit.red : null,
              onTap: () => setState(() => _filter = _filter == 'MISSING' ? '' : 'MISSING')),
          for (final g in ['BUY', 'SELL', 'INT', 'MFG'])
            ImMasterFilterChip(
                label: switch (g) {
                  'BUY' => e ? 'Buy' : 'ซื้อ',
                  'SELL' => e ? 'Sell' : 'ขาย',
                  'MFG' => e ? 'Manufacturing' : 'ผลิต',
                  _ => e ? 'Internal' : 'ภายใน',
                },
                on: _filter == g,
                onTap: () => setState(() => _filter = _filter == g ? '' : g)),
        ],
        countText: e ? 'Showing ${shown.length} of ${_rows.length}' : 'แสดง ${shown.length} จาก ${_rows.length} รายการ',
      ),
      Expanded(
        child: _isLoading && _rows.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.only(bottom: 12), children: [
                for (final g in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                    child: Row(children: [
                      Expanded(child: Text(_groupLabel(g.key, e), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ImKit.ink2))),
                      Text('${g.value.length}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ImKit.ink2)),
                    ]),
                  ),
                  for (final r in g.value) card(r),
                ],
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(e ? 'No document types match' : 'ไม่พบประเภทเอกสารที่ตรงเงื่อนไข',
                        textAlign: TextAlign.center, style: const TextStyle(color: ImKit.ink2)),
                  ),
              ]),
      ),
    ]);
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
  final List<ModuleDocument> receiptDocs;

  /// คืน true เมื่อบันทึกสำเร็จ (แล้วกลับเป็นโหมดดู)
  final Future<bool> Function(ImGlAccountSetup) onSave;

  /// ประเภทเอกสาร IM อื่นใต้ sys_doc_type เดียวกัน — ใช้กับปุ่ม "สำเนาจากประเภทอื่น"
  final List<ImGlAccountSetup> siblings;

  /// บัญชีสต็อก/ต้นทุนขายค่าเริ่มต้นของบริษัท (im_accounting_setting) — ช่องว่างที่มีค่านี้ไม่นับว่ายังไม่ตั้ง
  final int? companyInvId;
  final int? companyCogsId;

  const _ImGlSetupForm({
    super.key,
    required this.setup,
    required this.accounts,
    required this.glDocs,
    required this.targetDocs,
    required this.receiptDocs,
    required this.onSave,
    this.siblings = const [],
    this.companyInvId,
    this.companyCogsId,
  });

  @override
  State<_ImGlSetupForm> createState() => _ImGlSetupFormState();
}

class _ImGlSetupFormState extends State<_ImGlSetupForm> with ImMasterKit {
  bool _isEnglish = false;
  bool _editing = false;
  String _snapshot = '';
  Map<String, dynamic>? _summary;
  int _summarySeq = 0;
  // ข้อความแทนบัญชีที่ยังไม่ตั้ง (ไม่มีค่าอื่นมาแทน) ในตัวอย่างการลงบัญชี — แสดงบรรทัดนั้นเป็นสีแดง
  final Set<String> _jMissing = {};

  @override
  bool get kitEnglish => _isEnglish;
  @override
  bool get kitReadOnly => !_editing;

  int? _inventoryAccountId;
  String? _inventoryAccountCode;
  String? _inventoryAccountName;
  int? _cogsAccountId;
  String? _cogsAccountCode;
  String? _cogsAccountName;
  int? _varianceAccountId;
  String? _varianceAccountCode;
  String? _varianceAccountName;
  int? _wipAccountId;
  String? _wipAccountCode;
  String? _wipAccountName;
  int? _grirAccountId;
  String? _grirAccountCode;
  String? _grirAccountName;
  int? _vatOutputAccountId;
  String? _vatOutputAccountCode;
  String? _vatOutputAccountName;
  int? _vatInputAccountId;
  String? _vatInputAccountCode;
  String? _vatInputAccountName;
  int? _consignmentPayableAccountId;
  String? _consignmentPayableAccountCode;
  String? _consignmentPayableAccountName;
  int? _glDocId;
  String? _glDocCode;
  String? _glDocName;
  int? _targetDocId;
  String? _targetDocCode;
  String? _targetDocName;
  int? _receiptDocId;
  String? _receiptDocCode;
  String? _receiptDocName;
  int? _defaultCustomerId;
  String? _defaultCustomerCode;
  String? _defaultCustomerName;
  int? _defaultVendorId;
  String? _defaultVendorCode;
  String? _defaultVendorName;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadFromSetup(widget.setup);
    _snapshot = _fp();
    _loadSummary();
  }

  @override
  void didUpdateWidget(covariant _ImGlSetupForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.setup.docCode != oldWidget.setup.docCode) {
      _loadFromSetup(widget.setup);
      _editing = false;
      _snapshot = _fp();
      _summary = null;
      kScrollTop();
      _loadSummary();
    }
  }

  void _loadFromSetup(ImGlAccountSetup s) {
    _inventoryAccountId = s.inventoryAccountId;
    _inventoryAccountCode = s.inventoryAccountCode;
    _inventoryAccountName = s.inventoryAccountName;
    _cogsAccountId = s.cogsAccountId;
    _cogsAccountCode = s.cogsAccountCode;
    _cogsAccountName = s.cogsAccountName;
    _varianceAccountId = s.varianceAccountId;
    _varianceAccountCode = s.varianceAccountCode;
    _varianceAccountName = s.varianceAccountName;
    _wipAccountId = s.wipAccountId;
    _wipAccountCode = s.wipAccountCode;
    _wipAccountName = s.wipAccountName;
    _grirAccountId = s.grirAccountId;
    _grirAccountCode = s.grirAccountCode;
    _grirAccountName = s.grirAccountName;
    _vatOutputAccountId = s.vatOutputAccountId;
    _vatOutputAccountCode = s.vatOutputAccountCode;
    _vatOutputAccountName = s.vatOutputAccountName;
    _vatInputAccountId = s.vatInputAccountId;
    _vatInputAccountCode = s.vatInputAccountCode;
    _vatInputAccountName = s.vatInputAccountName;
    _consignmentPayableAccountId = s.consignmentPayableAccountId;
    _consignmentPayableAccountCode = s.consignmentPayableAccountCode;
    _consignmentPayableAccountName = s.consignmentPayableAccountName;
    _glDocId = s.glDocId;
    _glDocCode = s.glDocCode;
    _glDocName = s.glDocName;
    _targetDocId = s.targetDocId;
    _targetDocCode = s.targetDocCodeSel;
    _targetDocName = s.targetDocNameTh;
    _receiptDocId = s.receiptTargetDocId;
    _receiptDocCode = s.receiptTargetDocCode;
    _receiptDocName = s.receiptTargetDocNameTh;
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    _defaultCustomerId = s.defaultCustomerId;
    _defaultCustomerCode = s.defaultCustomerCode;
    _defaultCustomerName = s.defaultCustomerName(isEnglish);
    _defaultVendorId = s.defaultVendorId;
    _defaultVendorCode = s.defaultVendorCode;
    _defaultVendorName = s.defaultVendorName(isEnglish);
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
                : widget.accounts
                    .where((a) =>
                        a.accountCode.toLowerCase().contains(lq) || a.accountNameThai.toLowerCase().contains(lq) || a.accountNameEng.toLowerCase().contains(lq))
                    .toList();
          });
        }

        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 520,
            height: 420,
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
                      onTap: () {
                        picked = a;
                        Navigator.of(ctx).pop();
                      },
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

  Future<void> _pickGlDoc() async {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    final picked = await _pickDoc(widget.glDocs, isEnglish ? 'Select GL Document Type' : 'เลือกประเภทเอกสาร GL');
    if (picked != null) {
      setState(() {
        _glDocId = picked.id;
        _glDocCode = picked.docCode;
        _glDocName = picked.docNameThai;
      });
    }
  }

  Future<void> _pickTargetDoc() async {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    final m = widget.setup.targetModule;
    final picked = await _pickDoc(widget.targetDocs, isEnglish ? 'Select $m Document Type' : 'เลือกประเภทเอกสาร $m');
    if (picked != null) {
      setState(() {
        _targetDocId = picked.id;
        _targetDocCode = picked.docCode;
        _targetDocName = picked.docNameThai;
      });
      _loadSummary(); // บัญชี VAT ที่ใช้แทน (ของ AP/AR ปลายทาง) เปลี่ยนตามประเภทเอกสารที่เลือก
    }
  }

  Future<void> _pickReceiptDoc() async {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    final ap = widget.setup.targetModule == 'AP';
    final picked = await _pickDoc(
        widget.receiptDocs,
        ap
            ? (isEnglish ? 'Select AP Payment Document Type' : 'เลือกประเภทเอกสารจ่ายชำระ AP')
            : (isEnglish ? 'Select AR Receipt Document Type' : 'เลือกประเภทเอกสารรับชำระ AR'));
    if (picked != null) {
      setState(() {
        _receiptDocId = picked.id;
        _receiptDocCode = picked.docCode;
        _receiptDocName = picked.docNameThai;
      });
    }
  }

  void _pickDefaultCustomer() {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    ArCustomerListWidget.search(context, onSelected: (ArCustomer c) {
      setState(() {
        _defaultCustomerId = c.id;
        _defaultCustomerCode = c.customerCode;
        _defaultCustomerName = isEnglish && (c.customerNameEn ?? '').isNotEmpty ? c.customerNameEn : c.customerNameTh;
      });
    });
  }

  void _pickDefaultVendor() {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    ApVendorListWidget.search(context, onSelected: (ApVendor v) {
      setState(() {
        _defaultVendorId = v.id;
        _defaultVendorCode = v.vendorCode;
        _defaultVendorName = isEnglish && (v.vendorNameEn ?? '').isNotEmpty ? v.vendorNameEn : v.vendorNameTh;
      });
    });
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
            width: 480,
            height: 380,
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
                      : docs
                          .where((d) =>
                              d.docCode.toLowerCase().contains(lq) || d.docNameThai.toLowerCase().contains(lq) || d.docNameEng.toLowerCase().contains(lq))
                          .toList();
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
                      onTap: () {
                        picked = d;
                        Navigator.of(ctx).pop();
                      },
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
      // ช่องที่ซ่อนอยู่ (ประเภทเอกสารนี้ไม่ใช้) บันทึกเป็นค่าว่างเสมอ — ไม่งั้นค่าเก่าค้างในฐานข้อมูลโดยผู้ใช้มองไม่เห็น
      // และทำให้ลบบัญชีนั้นออกจากผังบัญชีไม่ได้ (เช่น 511900 ค้างในช่องผลต่างของ DLN/RTC)
      T? shown<T>(bool show, T? v) => show ? v : null;
      final updated = ImGlAccountSetup(
        docCode: widget.setup.docCode,
        targetModule: widget.setup.targetModule,
        targetDocCode: widget.setup.targetDocCode,
        glDocId: shown(_showGlDoc, _glDocId),
        glDocCode: shown(_showGlDoc, _glDocCode),
        glDocName: shown(_showGlDoc, _glDocName),
        targetAuto: widget.setup.targetAuto,
        targetDocId: _targetDocId,
        targetDocCodeSel: _targetDocCode,
        targetDocNameTh: _targetDocName,
        receiptDocCode: widget.setup.receiptDocCode,
        receiptTargetDocId: _receiptDocId,
        receiptTargetDocCode: _receiptDocCode,
        receiptTargetDocNameTh: _receiptDocName,
        defaultCustomerId: _defaultCustomerId,
        defaultCustomerCode: _defaultCustomerCode,
        defaultCustomerNameTh: _defaultCustomerName,
        defaultVendorId: _defaultVendorId,
        defaultVendorCode: _defaultVendorCode,
        defaultVendorNameTh: _defaultVendorName,
        inventoryAccountId: shown(_showInv, _inventoryAccountId),
        inventoryAccountCode: shown(_showInv, _inventoryAccountCode),
        inventoryAccountName: shown(_showInv, _inventoryAccountName),
        cogsAccountId: shown(_showCogs, _cogsAccountId),
        cogsAccountCode: shown(_showCogs, _cogsAccountCode),
        cogsAccountName: shown(_showCogs, _cogsAccountName),
        varianceAccountId: shown(_showVariance, _varianceAccountId),
        varianceAccountCode: shown(_showVariance, _varianceAccountCode),
        varianceAccountName: shown(_showVariance, _varianceAccountName),
        wipAccountId: shown(_showWip, _wipAccountId),
        wipAccountCode: shown(_showWip, _wipAccountCode),
        wipAccountName: shown(_showWip, _wipAccountName),
        grirAccountId: shown(_showGrir, _grirAccountId),
        grirAccountCode: shown(_showGrir, _grirAccountCode),
        grirAccountName: shown(_showGrir, _grirAccountName),
        vatOutputAccountId: shown(_showVatOut, _vatOutputAccountId),
        vatOutputAccountCode: shown(_showVatOut, _vatOutputAccountCode),
        vatOutputAccountName: shown(_showVatOut, _vatOutputAccountName),
        vatInputAccountId: shown(_showVatIn, _vatInputAccountId),
        vatInputAccountCode: shown(_showVatIn, _vatInputAccountCode),
        vatInputAccountName: shown(_showVatIn, _vatInputAccountName),
        consignmentPayableAccountId: shown(_showConsign, _consignmentPayableAccountId),
        consignmentPayableAccountCode: shown(_showConsign, _consignmentPayableAccountCode),
        consignmentPayableAccountName: shown(_showConsign, _consignmentPayableAccountName),
      );
      final ok = await widget.onSave(updated);
      if (ok && mounted) {
        setState(() {
          _editing = false;
          _snapshot = _fp();
        });
        _loadSummary();
      }
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
    if (s.receiptDocCode != null && s.targetModule == 'AP') {
      return isEnglish
          ? 'Creates an AP invoice (system type ${s.targetDocCode}) and an AP payment (system type ${s.receiptDocCode}) that settles it when posted — choose both document types below. The document must be approved before posting (payment limit).'
          : 'เมื่อ Post จะสร้างใบตั้งหนี้ AP (ประเภทระบบ ${s.targetDocCode}) และใบจ่ายชำระ AP (ประเภทระบบ ${s.receiptDocCode}) ตัดใบตั้งหนี้นั้นอัตโนมัติ — เลือกประเภทเอกสารทั้งสองด้านล่าง เอกสารต้องได้รับอนุมัติก่อน Post (ตามวงเงินจ่าย)';
    }
    if (s.receiptDocCode != null) {
      return isEnglish
          ? 'Creates an AR invoice (system type ${s.targetDocCode}) and an AR receipt (system type ${s.receiptDocCode}) that settles it when posted — choose both document types below'
          : 'เมื่อ Post จะสร้างใบแจ้งหนี้ AR (ประเภทระบบ ${s.targetDocCode}) และใบเสร็จรับชำระ AR (ประเภทระบบ ${s.receiptDocCode}) ตัดใบแจ้งหนี้นั้นอัตโนมัติ — เลือกประเภทเอกสารทั้งสองด้านล่าง';
    }
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
  // ตัวตัดสินอยู่ที่ ImGlSdt (ใช้ร่วมกับการ์ดซ้ายที่นับช่องที่ยังไม่ตั้ง)
  bool get _noGl => ImGlSdt.noGl(_sdt);
  bool get _showGlDoc => ImGlSdt.showGlDoc(_sdt);
  bool get _showInv => ImGlSdt.showInv(_sdt);
  bool get _showCogs => ImGlSdt.showCogs(_sdt);
  bool get _showVariance => ImGlSdt.showVariance(_sdt);
  bool get _showWip => ImGlSdt.showWip(_sdt);
  bool get _showGrir => ImGlSdt.showGrir(_sdt);
  bool get _showConsign => ImGlSdt.showConsign(_sdt);
  bool get _showVatIn => ImGlSdt.showVatIn(_sdt);
  bool get _showVatOut => ImGlSdt.showVatOut(_sdt);

  // ว่าง → ข้อความแทน และจำไว้ใน _jMissing ให้ตารางตัวอย่างแสดงบรรทัดนั้นเป็นสีแดง
  String _acctLabel(int? id, String? code, String? name, bool isEnglish, String placeholder) {
    if (id != null) return '$code  ${_acctName(id, name)}';
    _jMissing.add(placeholder);
    return placeholder;
  }

  // ว่างแต่มีค่าอื่นมาแทน (ค่าเริ่มต้นบริษัท / VAT ของ AP-AR ปลายทาง) → แสดงบัญชีที่จะใช้จริง ไม่ใช่สีแดง
  String _acctOrFallback(int? id, String? code, String? name, bool isEnglish, String placeholder, Map<String, dynamic>? fb, String fbNote) =>
      id == null && fb != null ? '${_fbAcct(fb)} ($fbNote)' : _acctLabel(id, code, name, isEnglish, placeholder);

  List<_JournalSection> _journalSections(bool isEnglish) {
    _jMissing.clear();
    final companyNote = isEnglish ? 'company default' : 'ค่าเริ่มต้นบริษัท';
    final inv = _acctOrFallback(_inventoryAccountId, _inventoryAccountCode, _inventoryAccountName, isEnglish,
        isEnglish ? '(Inventory — not set)' : '(บัญชีสินค้าคงคลัง — ยังไม่ตั้งค่า)', _fb('inventory'), companyNote);
    final cogs = _acctOrFallback(_cogsAccountId, _cogsAccountCode, _cogsAccountName, isEnglish,
        isEnglish ? '(COGS — not set)' : '(บัญชีต้นทุนขาย — ยังไม่ตั้งค่า)', _fb('cogs'), companyNote);
    final wip = _acctLabel(_wipAccountId, _wipAccountCode, _wipAccountName, isEnglish, isEnglish ? '(WIP — not set)' : '(บัญชีงานระหว่างผลิต — ยังไม่ตั้งค่า)');
    final variance = _acctLabel(
        _varianceAccountId, _varianceAccountCode, _varianceAccountName, isEnglish, isEnglish ? '(Variance — not set)' : '(บัญชีผลต่างต้นทุน — ยังไม่ตั้งค่า)');
    final grir = _acctLabel(
        _grirAccountId, _grirAccountCode, _grirAccountName, isEnglish, isEnglish ? '(GR/IR clearing — not set)' : '(บัญชีพักรอใบกำกับ GR/IR — ยังไม่ตั้งค่า)');
    final vatIn = _acctOrFallback(
        _vatInputAccountId,
        _vatInputAccountCode,
        _vatInputAccountName,
        isEnglish,
        isEnglish ? '(VAT Input — not set here or in the AP setup)' : '(บัญชี VAT ซื้อ — ยังไม่ตั้งทั้งที่นี่และที่การตั้งค่า AP)',
        (_summary?['fallback']?['target_vat'] as Map<String, dynamic>?)?['account'] as Map<String, dynamic>?,
        isEnglish ? 'AP setup' : 'ของการตั้งค่า AP');
    final consignPayable = _acctLabel(_consignmentPayableAccountId, _consignmentPayableAccountCode, _consignmentPayableAccountName, isEnglish,
        isEnglish ? '(Consignment Payable — not set)' : '(บัญชีเจ้าหนี้ฝากขาย — ยังไม่ตั้งค่า)');
    final ap = isEnglish ? '(AP — posted in AP module)' : '(เจ้าหนี้ — บันทึกในโมดูล AP)';
    final purchases =
        isEnglish ? 'Purchases (warehouse → item → category → company default)' : 'บัญชีซื้อสินค้า (คลัง → สินค้า → หมวดสินค้า → ค่าเริ่มต้นของบริษัท)';

    switch (_sdt) {
      case '90': // MOI — เบิกวัตถุดิบเข้าผลิต
        return [
          _JournalSection(
              lines: [_JournalLine('Dr', wip), _JournalLine('  Cr', isEnglish ? '$inv (Periodic lines: $purchases)' : '$inv (บรรทัด Periodic: $purchases)')]),
          _JournalSection(
            title: isEnglish ? 'Referencing a manufacturing order' : 'อ้างอิงใบสั่งผลิต',
            lines: [
              _JournalLine(
                  '',
                  isEnglish
                      ? 'WIP comes from the manufacturing order document type (MO GL Account Setup)'
                      : 'บัญชี WIP ใช้ของประเภทเอกสารใบสั่งผลิต (หน้าตั้งค่าบัญชีใบสั่งผลิต)')
            ],
          ),
        ];
      case '95': // MOR — รับสินค้าเข้าคลังจากการผลิต
        return [
          _JournalSection(lines: [
            _JournalLine('Dr', isEnglish ? '$inv (Periodic lines: $purchases)' : '$inv (บรรทัด Periodic: $purchases)'),
            _JournalLine(
                'Dr/Cr', isEnglish ? '$variance (standard - actual cost, STANDARD orders)' : '$variance (ต้นทุนมาตรฐาน - ต้นทุนจริง ใบสั่งผลิตแบบ STANDARD)'),
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
            lines: [
              _JournalLine(
                  '', isEnglish ? 'WIP and variance come from the manufacturing order document type' : 'บัญชี WIP และผลต่างใช้ของประเภทเอกสารใบสั่งผลิต')
            ],
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
            lines: [
              _JournalLine(
                  'Dr/Cr',
                  isEnglish
                      ? '$purchases instead of the inventory account; no entry when both sides are Periodic'
                      : '$purchases แทนบัญชีสต็อก — ถ้าทั้งสองฝั่งเป็น Periodic ไม่ลงบัญชี')
            ],
          ),
        ];
      case '10': // GRN — รับสินค้า (ไม่มีเลขที่อ้างอิง) — AP ตั้งหนี้เองภายหลัง (Dr GR/IR / Cr AP แยกต่างหาก)
        return [
          _JournalSection(
            title: isEnglish ? 'Perpetual lines' : 'บรรทัด Perpetual',
            lines: [
              _JournalLine('Dr', inv),
              _JournalLine(
                  'Dr/Cr', isEnglish ? '$variance (purchase price - standard cost, STANDARD items)' : '$variance (ราคาซื้อ - ต้นทุนมาตรฐาน สินค้า STANDARD)'),
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
      case '14': // ซื้อเงินสด — เหมือน '11' + ใบจ่ายชำระ AP ตัดใบตั้งหนี้ทันที
        return [
          _JournalSection(lines: [
            _JournalLine('Dr', isEnglish ? '$inv / $purchases (auto, on the AP bill)' : '$inv / $purchases (อัตโนมัติ บนใบตั้งหนี้ AP)'),
            _JournalLine(
                'Dr/Cr',
                isEnglish
                    ? '$variance (purchase price - standard cost, STANDARD items, Perpetual only)'
                    : '$variance (ราคาซื้อ - ต้นทุนมาตรฐาน สินค้า STANDARD เฉพาะ Perpetual)'),
            _JournalLine(
                'Dr',
                isEnglish
                    ? '$vatIn (full tax invoice only — abbreviated/none: VAT goes into the item cost)'
                    : '$vatIn (เฉพาะใบกำกับภาษีเต็มรูป — อย่างย่อ/ไม่มี: VAT รวมเข้าต้นทุนสินค้า)'),
            _JournalLine('  Cr', ap),
          ]),
          _JournalSection(
            title: isEnglish ? 'AP payment (auto)' : 'ใบจ่ายชำระ AP (อัตโนมัติ)',
            lines: [
              _JournalLine('Dr', ap),
              _JournalLine(
                  '  Cr',
                  isEnglish
                      ? 'Cash/Bank per payment method + WHT payable + deposit deducted'
                      : 'เงินสด/ธนาคารตามวิธีจ่าย + ภาษีหัก ณ ที่จ่ายค้างจ่าย + มัดจำที่หัก'),
            ],
          ),
        ];
      case '11': // GRN Billing — รับสินค้า+ตั้งหนี้อัตโนมัติ — ไม่ Post ที่นี่ สร้าง ap_transaction แล้วโพสต์ที่นั่นแทน
        return [
          _JournalSection(lines: [
            _JournalLine('Dr', isEnglish ? '$inv / $purchases (auto, on the AP bill)' : '$inv / $purchases (อัตโนมัติ บนใบตั้งหนี้ AP)'),
            _JournalLine(
                'Dr/Cr',
                isEnglish
                    ? '$variance (purchase price - standard cost, STANDARD items, Perpetual only)'
                    : '$variance (ราคาซื้อ - ต้นทุนมาตรฐาน สินค้า STANDARD เฉพาะ Perpetual)'),
            _JournalLine('Dr', isEnglish ? '$vatIn (if VAT selected on a line)' : '$vatIn (ถ้าบรรทัดใดเลือก VAT)'),
            _JournalLine('  Cr', ap),
          ]),
        ];
      case '12': // GR รอตั้งหนี้ — Stage 1 (Post IM) ไม่ Post บัญชีเลย, Stage 2 (Post AP/GL) สินค้าคงคลังตามต้นทุนตอนรับ + ผลต่าง
        return [
          _JournalSection(lines: [
            _JournalLine('Dr',
                isEnglish ? '$inv (at received cost) / $purchases (auto, on the AP bill)' : '$inv (ตามต้นทุนตอนรับ) / $purchases (อัตโนมัติ บนใบตั้งหนี้ AP)'),
            _JournalLine(
                'Dr/Cr', isEnglish ? '$variance (billed price - received cost, Perpetual only)' : '$variance (ราคาใบกำกับ - ต้นทุนตอนรับ เฉพาะ Perpetual)'),
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
      case '33': // ขายเงินสด — ต้นทุนขายที่นี่ ใบแจ้งหนี้ + ใบเสร็จ AR แยกต่างหาก (ดู note ด้านล่าง)
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
    final isLive = ['80', '60', '70', '10', '11', '12', '13', '14', '30', '31', '32', '33', '15', '20', '25', '35', '40', '45'].contains(_sdt);

    return kCard(
      title: isEnglish ? 'Journal entry preview' : 'ตัวอย่างการลงบัญชี',
      count:
          isEnglish ? 'Uses the accounts selected now, even before saving · red = not set' : 'ตามบัญชีที่เลือกตอนนี้ ยังไม่บันทึกก็เห็น · สีแดง = ยังไม่ตั้ง',
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _journalTable(sections, isEnglish),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              if (_sdt == '33') ...[
                const SizedBox(height: 6),
                Text(
                  isEnglish
                      ? '* Three separate entries post: the COGS entry above (this module) plus the linked AR Invoice (Dr AR / Cr Revenue + Output VAT) and the linked AR Receipt (Dr Cash/Bank per payment method + WHT + deposit deducted / Cr AR), both created automatically and not shown here.'
                      : '* มีการ Post 3 entry แยกกัน: entry ต้นทุนขายข้างบน (โมดูลนี้) กับใบแจ้งหนี้ AR (Dr ลูกหนี้ / Cr รายได้ + ภาษีขาย) และใบเสร็จรับชำระ AR (Dr เงินสด/ธนาคารตามวิธีรับเงิน + ภาษีถูกหัก ณ ที่จ่าย + มัดจำที่หัก / Cr ลูกหนี้) ที่สร้างอัตโนมัติ (ไม่ได้แสดงที่นี่)',
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
        ),
      ]),
    );
  }

  String? _receiptDocDisplayName(bool isEnglish) {
    final m = widget.receiptDocs.cast<ModuleDocument?>().firstWhere((d) => d?.id == _receiptDocId, orElse: () => null);
    if (m == null) return _receiptDocName;
    return isEnglish && m.docNameEng.isNotEmpty ? m.docNameEng : m.docNameThai;
  }

  String? _targetDocDisplayName(bool isEnglish) {
    final m = widget.targetDocs.cast<ModuleDocument?>().firstWhere((d) => d?.id == _targetDocId, orElse: () => null);
    if (m == null) return _targetDocName;
    return isEnglish && m.docNameEng.isNotEmpty ? m.docNameEng : m.docNameThai;
  }

  // ── โหมดดู/แก้ไข ──
  String _fp() => [
        _inventoryAccountId,
        _cogsAccountId,
        _varianceAccountId,
        _wipAccountId,
        _grirAccountId,
        _vatOutputAccountId,
        _vatInputAccountId,
        _consignmentPayableAccountId,
        _glDocId,
        _targetDocId,
        _receiptDocId,
        _defaultCustomerId,
        _defaultVendorId,
      ].join('|');

  bool get isDirty => _editing && _fp() != _snapshot;

  Future<void> _loadSummary() async {
    final seq = ++_summarySeq;
    try {
      final s = await ImGlAccountSetupService().fetchSummary(widget.setup.docCode, targetDocId: _targetDocId);
      if (mounted && seq == _summarySeq) setState(() => _summary = s);
    } catch (_) {
      if (mounted && seq == _summarySeq) setState(() => _summary = null);
    }
  }

  Map<String, dynamic>? _fb(String key) => (_summary?['fallback'] as Map<String, dynamic>?)?[key] as Map<String, dynamic>?;

  String _fbAcct(Map<String, dynamic>? a) {
    if (a == null) return '';
    final en = '${a['account_name_eng'] ?? ''}';
    return '${a['account_code']}  ${_isEnglish && en.isNotEmpty ? en : (a['account_name_thai'] ?? '')}';
  }

  void _cancelEdit() => setState(() {
        _loadFromSetup(widget.setup);
        _editing = false;
        _loadSummary();
      });

  void _copyFrom(ImGlAccountSetup src) {
    final e = _isEnglish;
    setState(() {
      final keepTarget = (_targetDocId, _targetDocCode, _targetDocName, _receiptDocId, _receiptDocCode, _receiptDocName);
      _loadFromSetup(src);
      // ประเภทเอกสารปลายทางของต้นทาง ใช้ได้เพราะอยู่ใต้ประเภทระบบเดียวกัน — ถ้าต้นทางว่างให้คงของเดิม
      if (_targetDocId == null) {
        _targetDocId = keepTarget.$1;
        _targetDocCode = keepTarget.$2;
        _targetDocName = keepTarget.$3;
      }
      if (_receiptDocId == null) {
        _receiptDocId = keepTarget.$4;
        _receiptDocCode = keepTarget.$5;
        _receiptDocName = keepTarget.$6;
      }
    });
    _loadSummary();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e ? 'Copied the setup of ${src.docCode} — check it, then save' : 'คัดลอกการตั้งค่าจาก ${src.docCode} แล้ว ตรวจสอบแล้วกดบันทึก')));
  }

  // ── ส่วนต่างๆ ──
  List<String> _currentMissing(bool e) => ImGlSdt.missing(
        sdt: _sdt,
        e: e,
        targetModule: widget.setup.targetModule,
        targetAuto: widget.setup.targetAuto,
        needsReceipt: widget.setup.receiptDocCode != null,
        targetDocId: _targetDocId,
        receiptDocId: _receiptDocId,
        glDocId: _glDocId,
        inv: _inventoryAccountId,
        cogs: _cogsAccountId,
        variance: _varianceAccountId,
        wip: _wipAccountId,
        grir: _grirAccountId,
        consign: _consignmentPayableAccountId,
        companyInv: widget.companyInvId,
        companyCogs: widget.companyCogsId,
      );

  List<ImKpi> _kpis(bool e) {
    final missing = _currentMissing(e);
    final usage = _summary?['usage'] as Map<String, dynamic>?;
    final by = (usage?['by_status'] as Map<String, dynamic>?) ?? const {};
    final last = usage?['last_doc'] as Map<String, dynamic>?;
    final lastDate = last == null ? null : DateTime.tryParse('${last['doc_date']}');
    String fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final statusText = by.entries.map((x) => '${x.key} ${x.value}').join(' · ');
    final sib = widget.siblings;
    return [
      ImKpi(e ? 'Fields not set' : 'ช่องที่ยังไม่ตั้ง', '${missing.length}', missing.isEmpty ? (e ? 'Ready to post' : 'พร้อมใช้งาน') : missing.join(', '),
          warn: missing.isNotEmpty),
      ImKpi(e ? 'Documents of this type' : 'เอกสารที่ใช้ประเภทนี้', usage == null ? '—' : '${usage['total'] ?? 0}',
          statusText.isEmpty ? (e ? 'None yet' : 'ยังไม่มี') : statusText),
      ImKpi(e ? 'Last used' : 'ใช้ล่าสุด', lastDate == null ? '—' : fmt(lastDate),
          last == null ? (e ? 'Never used' : 'ยังไม่เคยใช้') : '${last['doc_no'] ?? ''}'),
      ImKpi(e ? 'Other types under system type $_sdt' : 'ประเภทอื่นใต้ประเภทระบบ $_sdt', '${sib.length}',
          sib.isEmpty ? (e ? 'None' : 'ไม่มี') : '${sib.map((s) => s.docCode).join(', ')} · ${e ? 'can copy setup' : 'สำเนาการตั้งค่าได้'}'),
    ];
  }

  Widget _banner(String text, {IconData icon = Icons.info_outline}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: ImKit.blueSoft, border: Border.all(color: const Color(0xFFC7D9F0)), borderRadius: BorderRadius.circular(8)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: ImKit.blue),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, color: ImKit.blue))),
        ]),
      );

  Widget _buildLinkCard(bool e) {
    final s = widget.setup;
    final m = s.targetModule;
    String? glDocName;
    if (_glDocId != null) {
      final matchedDoc = widget.glDocs.cast<ModuleDocument?>().firstWhere((d) => d?.id == _glDocId, orElse: () => null);
      glDocName = e && (matchedDoc?.docNameEng.isNotEmpty ?? false) ? matchedDoc!.docNameEng : _glDocName;
    }
    final groups = <Widget>[];
    var no = 1;
    if (s.targetAuto || s.receiptDocCode != null) {
      groups.add(kGroup(no++, e ? '$m documents created automatically' : 'เอกสาร $m ที่สร้างอัตโนมัติ', ImKit.gDoc, [
        if (s.targetAuto)
          kFk(
            label: e ? '$m ${_targetKind(true)} document type *' : 'ประเภทเอกสาร${_targetKind(false)} $m *',
            text: '$_targetDocCode  ${_targetDocDisplayName(e) ?? ''}',
            hasValue: _targetDocId != null,
            onSearch: _pickTargetDoc,
            onClear: () {
              setState(() {
                _targetDocId = null;
                _targetDocCode = null;
                _targetDocName = null;
              });
              _loadSummary();
            },
          ),
        if (s.receiptDocCode != null)
          kFk(
            label:
                m == 'AP' ? (e ? 'AP payment document type *' : 'ประเภทเอกสารจ่ายชำระ AP *') : (e ? 'AR receipt document type *' : 'ประเภทเอกสารรับชำระ AR *'),
            text: '$_receiptDocCode  ${_receiptDocDisplayName(e) ?? ''}',
            hasValue: _receiptDocId != null,
            onSearch: _pickReceiptDoc,
            onClear: () => setState(() {
              _receiptDocId = null;
              _receiptDocCode = null;
              _receiptDocName = null;
            }),
          ),
      ]));
    }
    if (s.receiptDocCode != null) {
      final ap = m == 'AP';
      groups.add(kGroup(no++, ap ? (e ? 'Default cash vendor' : 'ผู้ขายเงินสดตั้งต้น') : (e ? 'Default cash customer' : 'ลูกค้าเงินสดตั้งต้น'), ImKit.gParty, [
        ap
            ? kFk(
                label: e ? 'Vendor filled in on new documents' : 'ผู้ขายที่ใส่ให้อัตโนมัติในเอกสารใหม่',
                text: '$_defaultVendorCode  ${_defaultVendorName ?? ''}',
                hasValue: _defaultVendorId != null,
                onSearch: _pickDefaultVendor,
                onClear: () => setState(() {
                  _defaultVendorId = null;
                  _defaultVendorCode = null;
                  _defaultVendorName = null;
                }),
              )
            : kFk(
                label: e ? 'Customer filled in on new documents' : 'ลูกค้าที่ใส่ให้อัตโนมัติในเอกสารใหม่',
                text: '$_defaultCustomerCode  ${_defaultCustomerName ?? ''}',
                hasValue: _defaultCustomerId != null,
                onSearch: _pickDefaultCustomer,
                onClear: () => setState(() {
                  _defaultCustomerId = null;
                  _defaultCustomerCode = null;
                  _defaultCustomerName = null;
                }),
              ),
        kNote(e ? 'Optional' : 'ไม่บังคับ'),
      ]));
    }
    if (!_noGl) {
      groups.add(kGroup(no++, e ? 'GL document type' : 'ประเภทเอกสาร GL', ImKit.gMore, [
        if (_showGlDoc)
          kFk(
            label: e ? 'GL document type (for posting) *' : 'ประเภทเอกสาร GL (สำหรับ Post) *',
            text: '$_glDocCode  ${glDocName ?? _glDocName ?? ''}',
            hasValue: _glDocId != null,
            onSearch: _pickGlDoc,
            onClear: () => setState(() {
              _glDocId = null;
              _glDocCode = null;
              _glDocName = null;
            }),
          )
        else
          InputDecorator(
            decoration: kDec(e ? 'GL document type' : 'ประเภทเอกสาร GL', editable: false),
            child: Text(e ? 'Uses the AP account setup' : 'ใช้ของการตั้งค่าบัญชี AP', style: const TextStyle(fontSize: ImKit.font)),
          ),
      ]));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _banner(_targetLabel(e)),
      if (_noGl || ImGlSdt.apLinked.contains(_sdt)) ...[
        const SizedBox(height: 8),
        _banner(_noGl
            ? (e ? 'This document type does not post to the GL — no accounts to set up.' : 'เอกสารประเภทนี้ไม่ลงบัญชี GL — ไม่ต้องตั้งค่ารหัสบัญชี')
            : (e
                ? 'Posted through the linked AP document — the GL document type comes from the AP account setup; only the accounts below are used from here.'
                : 'ลงบัญชีผ่านเอกสาร AP ที่สร้างอัตโนมัติ — ประเภทเอกสาร GL ใช้ของการตั้งค่าบัญชี AP ใช้เฉพาะรหัสบัญชีด้านล่างจากหน้านี้')),
      ],
      if (groups.isNotEmpty) ...[
        const SizedBox(height: 12),
        kCard(title: e ? 'Document links' : 'การเชื่อมเอกสาร', trailing: kLegend(withAuto: false), child: kGroups(groups)),
      ],
    ]);
  }

  Widget _acctCell({required int? id, required String? code, required String? name, required String title, required void Function(Account?) set}) {
    final e = _isEnglish;
    final has = id != null;
    final text = has ? '$code  ${_acctName(id, name)}' : (e ? '— Not specified —' : '— ไม่ระบุ —');
    final style = TextStyle(fontSize: 12.5, color: has ? null : ImKit.ink3);
    if (!_editing) return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    return InkWell(
      onTap: () async {
        final a = await _pickAccount(title);
        if (a != null) setState(() => set(a));
      },
      borderRadius: BorderRadius.circular(5),
      child: Container(
        height: 32,
        padding: const EdgeInsets.only(left: 8, right: 4),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFC9D1CC)), borderRadius: BorderRadius.circular(5)),
        child: Row(children: [
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
          if (has)
            IconButton(
              icon: const Icon(Icons.clear, size: 15, color: Colors.red),
              tooltip: e ? 'Clear' : 'ล้าง',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              onPressed: () => setState(() => set(null)),
            ),
          const Icon(Icons.search, size: 16, color: Colors.teal),
        ]),
      ),
    );
  }

  Widget _buildAccountsCard(bool e) {
    final m = widget.setup.targetModule;
    final none = e ? 'None — set it here' : 'ไม่มี — ต้องตั้งที่นี่';
    final tv = _summary?['fallback']?['target_vat'] as Map<String, dynamic>?;
    String vatFallback(String module) {
      final a = tv?['account'] as Map<String, dynamic>?;
      if (_targetDocId == null) {
        return e ? '$module account setup (choose the $module document type first)' : 'ของการตั้งค่าบัญชี $module (เลือกประเภทเอกสารปลายทางก่อน)';
      }
      if (a == null) {
        return e
            ? '$module setup of ${tv?['doc_code'] ?? ''} has none — set it here'
            : 'การตั้งค่า $module ของ ${tv?['doc_code'] ?? ''} ไม่มี — ต้องตั้งที่นี่';
      }
      return '${_fbAcct(a)} · ${e ? '$module setup' : 'ของ $module'}';
    }

    String company(String key, String otherwise) {
      final a = _fb(key);
      return a == null ? otherwise : '${_fbAcct(a)} · ${e ? 'company default' : 'ค่าเริ่มต้นบริษัท'}';
    }

    final rows = <(String, Widget, String, String, bool)>[]; // (บัญชี, ช่อง, ถ้าเว้นว่างใช้, ชั้นอื่น, ใช้ค่าแทน)
    void add(bool show, String label, int? id, String? code, String? name, void Function(Account?) set, String fallback, String levels) {
      if (!show) return;
      rows.add((label, _acctCell(id: id, code: code, name: name, title: label, set: set), fallback, levels, id == null));
    }

    final whItemCat = e ? 'Warehouse · item · category' : 'คลัง · สินค้า · หมวด';
    final itemCat = e ? 'Item · category' : 'สินค้า · หมวด';
    add(_showInv, e ? 'Inventory' : 'สินค้าคงคลัง', _inventoryAccountId, _inventoryAccountCode, _inventoryAccountName, (a) {
      _inventoryAccountId = a?.id;
      _inventoryAccountCode = a?.accountCode;
      _inventoryAccountName = a?.accountNameThai;
    }, company('inventory', e ? 'None — set it here or on the warehouse / item / category' : 'ไม่มี — ตั้งที่นี่หรือที่คลัง/สินค้า/หมวด'), whItemCat);
    add(_showCogs, e ? 'COGS' : 'ต้นทุนขาย', _cogsAccountId, _cogsAccountCode, _cogsAccountName, (a) {
      _cogsAccountId = a?.id;
      _cogsAccountCode = a?.accountCode;
      _cogsAccountName = a?.accountNameThai;
    }, company('cogs', e ? 'None — set it here or on the item / category' : 'ไม่มี — ตั้งที่นี่หรือที่สินค้า/หมวด'), itemCat);
    add(_showVariance, e ? 'Cost variance' : 'ผลต่างต้นทุน', _varianceAccountId, _varianceAccountCode, _varianceAccountName, (a) {
      _varianceAccountId = a?.id;
      _varianceAccountCode = a?.accountCode;
      _varianceAccountName = a?.accountNameThai;
    }, none, '—');
    add(_showWip, e ? 'Work in process (WIP)' : 'งานระหว่างผลิต (WIP)', _wipAccountId, _wipAccountCode, _wipAccountName, (a) {
      _wipAccountId = a?.id;
      _wipAccountCode = a?.accountCode;
      _wipAccountName = a?.accountNameThai;
    }, none, e ? 'Manufacturing order type' : 'ประเภทใบสั่งผลิต');
    add(_showGrir, e ? 'GR/IR clearing' : 'พักรอใบกำกับ GR/IR', _grirAccountId, _grirAccountCode, _grirAccountName, (a) {
      _grirAccountId = a?.id;
      _grirAccountCode = a?.accountCode;
      _grirAccountName = a?.accountNameThai;
    }, none, '—');
    add(_showConsign, e ? 'Consignment payable' : 'เจ้าหนี้ฝากขาย', _consignmentPayableAccountId, _consignmentPayableAccountCode,
        _consignmentPayableAccountName, (a) {
      _consignmentPayableAccountId = a?.id;
      _consignmentPayableAccountCode = a?.accountCode;
      _consignmentPayableAccountName = a?.accountNameThai;
    }, none, '—');
    add(_showVatIn, e ? 'Input VAT' : 'VAT ซื้อ', _vatInputAccountId, _vatInputAccountCode, _vatInputAccountName, (a) {
      _vatInputAccountId = a?.id;
      _vatInputAccountCode = a?.accountCode;
      _vatInputAccountName = a?.accountNameThai;
    }, vatFallback(m == 'NONE' ? 'AP' : m), '—');
    add(_showVatOut, e ? 'Output VAT' : 'VAT ขาย', _vatOutputAccountId, _vatOutputAccountCode, _vatOutputAccountName, (a) {
      _vatOutputAccountId = a?.id;
      _vatOutputAccountCode = a?.accountCode;
      _vatOutputAccountName = a?.accountNameThai;
    }, vatFallback(m == 'NONE' ? 'AR' : m), '—');

    final sib = widget.siblings;
    // แสดงปุ่มเสมอ (ตามแบบ) — โหมดดู: เลือกแล้วเข้าโหมดแก้ไขให้อัตโนมัติ; ไม่มีประเภทอื่น: ปุ่มเทาพร้อมคำอธิบาย
    final canEdit = MenuScope.of(context)?.canEdit ?? true;
    final copyLabel = e ? 'Copy from another type' : 'สำเนาจากประเภทอื่น';
    final Widget? copyBtn = !canEdit
        ? null
        : sib.isEmpty
            ? Tooltip(
                message: e ? 'No other IM doc types under system type $_sdt' : 'ไม่มีประเภทเอกสาร IM อื่นใต้ประเภทระบบ $_sdt',
                child: kGhost(copyLabel, Icons.content_copy, null),
              )
            : PopupMenuButton<ImGlAccountSetup>(
                tooltip: copyLabel,
                onSelected: (src) {
                  if (!_editing) {
                    setState(() {
                      _editing = true;
                      _snapshot = _fp();
                    });
                  }
                  _copyFrom(src);
                },
                itemBuilder: (_) => [
                  for (final s in sib)
                    PopupMenuItem(
                      value: s,
                      child: Text('${s.docCode}  ${e && (s.docNameEng ?? '').isNotEmpty ? s.docNameEng : (s.docNameThai ?? '')}'),
                    ),
                ],
                child: IgnorePointer(child: kGhost(copyLabel, Icons.content_copy, () {})),
              );

    return kCard(
      title: e ? 'Account codes' : 'รหัสบัญชี',
      count: e ? 'Only the accounts system type $_sdt posts to' : 'แสดงเฉพาะบัญชีที่ประเภทระบบ $_sdt ใช้ลงบัญชี',
      trailing: copyBtn,
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        kTable(
          [
            KCol(e ? 'Account' : 'บัญชี', 3),
            KCol(e ? 'Account of this type' : 'รหัสบัญชีของประเภทนี้', 6),
            KCol(e ? 'If blank, uses' : 'ถ้าเว้นว่าง ใช้', 6),
            KCol(e ? 'Can also be set at' : 'ตั้งที่ชั้นอื่นได้', 3)
          ],
          [
            for (final r in rows)
              [
                kCell(r.$1, bold: true),
                r.$2,
                kCell(r.$3, color: r.$5 && (r.$3 == none || r.$3.contains(e ? 'None' : 'ไม่มี')) ? ImKit.red : ImKit.ink2),
                kCell(r.$4, color: ImKit.ink2),
              ],
          ],
          minWidth: 820,
          rowMinHeight: 44,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: kNote(e ? 'Accounts this type does not use are hidden and cleared on save.' : 'บัญชีที่ประเภทนี้ไม่ใช้จะไม่แสดง และล้างเป็นค่าว่างตอนบันทึก'),
        ),
      ]),
    );
  }

  Widget _journalTable(List<_JournalSection> sections, bool e) {
    final rows = <Widget>[];
    Widget line(_JournalLine l) {
      final dc = l.drCr.trim();
      final missing = _jMissing.any((p) => l.name.contains(p));
      final indent = l.drCr.startsWith('  ');
      return Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEF1F4)))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 56,
            child: Text(dc,
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.bold, color: dc == 'Dr' || dc == 'Dr/Cr' ? ImKit.blue : (dc.isEmpty ? ImKit.ink3 : ImKit.gParty))),
          ),
          if (indent) const SizedBox(width: 24),
          Expanded(child: Text(l.name, style: TextStyle(fontSize: 12.5, color: missing ? ImKit.red : null, fontWeight: missing ? FontWeight.w600 : null))),
        ]),
      );
    }

    for (final s in sections) {
      if (s.title != null) {
        rows.add(Container(
          color: const Color(0xFFF6F8FA),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text(s.title!, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: ImKit.ink2)),
        ));
      }
      rows.addAll(s.lines.map(line));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }

  @override
  Widget build(BuildContext context) {
    final e = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = e;
    final s = widget.setup;
    final canEdit = MenuScope.of(context)?.canEdit ?? true;
    final missing = _currentMissing(e);
    final acts = _editing
        ? [
            DocBarAction(e ? 'Cancel' : 'ยกเลิก', _isSaving ? null : _cancelEdit, fg: ScreenTheme.of(context).ink),
            DocBarAction(_isSaving ? (e ? 'Saving...' : 'กำลังบันทึก...') : (e ? 'Save' : 'บันทึก'), _isSaving ? null : _submit,
                fg: const Color(0xFF0B3A2A), bg: ImKit.gold, primary: true),
          ]
        : [
            if (canEdit && !_noGl)
              DocBarAction(
                  e ? 'Edit' : 'แก้ไข',
                  () => setState(() {
                        _editing = true;
                        _snapshot = _fp();
                      }),
                  fg: Colors.white,
                  bg: ScreenTheme.of(context).ink,
                  primary: true),
          ];
    final title = e && (s.docNameEng ?? '').isNotEmpty ? s.docNameEng! : (s.docNameThai ?? s.docCode);
    final journal = _buildJournalPreview(e);
    return kPage(
      header: kHeaderBar(
        code: s.docCode,
        title: title,
        badges: [
          if (_sdt.isNotEmpty) ImKit.chip(e ? 'System type $_sdt' : 'ประเภทระบบ $_sdt', Colors.white24, Colors.white),
          if (s.targetAuto) ImKit.chip(e ? 'Creates ${s.targetModule}' : 'สร้าง ${s.targetModule}', Colors.white24, Colors.white),
          if (_editing) kEditingBadge(),
          if (_noGl)
            ImKit.chip(e ? 'No GL' : 'ไม่ลงบัญชี', ImKit.ro, ImKit.gMore)
          else if (missing.isEmpty)
            ImKit.chip(e ? 'Complete' : 'ครบ', ImKit.okSoft, ImKit.ok)
          else
            Tooltip(message: missing.join(', '), child: ImKit.chip(e ? '${missing.length} missing' : 'ขาด ${missing.length}', ImKit.redSoft, ImKit.red)),
          if (s.docIsActive == false) ImKit.chip(e ? 'Inactive' : 'หยุดใช้', ImKit.redSoft, ImKit.red),
        ],
        acts: acts,
        busy: _isSaving,
      ),
      top: _noGl ? null : kKpis(_kpis(e)),
      sections: [
        (0, e ? 'Document links' : 'การเชื่อมเอกสาร', _buildLinkCard(e)),
        if (!_noGl) (1, e ? 'Account codes' : 'รหัสบัญชี', _buildAccountsCard(e)),
        if (!_noGl && journal is! SizedBox) (2, e ? 'Journal preview' : 'ตัวอย่างการลงบัญชี', journal),
      ],
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
