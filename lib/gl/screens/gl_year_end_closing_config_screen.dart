// lib/gl/screens/gl_year_end_closing_config_screen.dart
// หน้าจอตั้งค่าปิดบัญชีสิ้นปี แบบ IM design B (user 2026-11-28) — หน้าตั้งค่าไม่มีรายการซ้าย:
//   เปิดมาเป็นโหมดดู กด "แก้ไข" ที่แถบหัว; ตัวเลขสรุป (ปีล่าสุดที่ปิด, ปีถัดไปที่ต้องปิด, กำไรปีนี้, กำไรสะสม);
//   กลุ่มบัญชี (ตรวจให้อัตโนมัติ: ส่วนของเจ้าของ, ลงรายการได้, ไม่ใช่ Control, สองบัญชีไม่ซ้ำ) + กลุ่มประเภทเอกสาร;
//   การ์ดขั้นตอนปิดบัญชี (ค่าไหนใช้ในขั้นใด + ความคืบหน้าของปีถัดไป) + ประวัติการปิดบัญชี
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../im/widgets/im_master_kit.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/services/sa_module_document_service.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/utils/sa_menu_theme.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../models/gl_account.dart';
import '../models/gl_year_end_closing.dart';
import '../services/gl_account_service.dart';
import '../services/gl_year_end_closing_service.dart';

class YearEndClosingConfigScreen extends StatefulWidget {
  const YearEndClosingConfigScreen({super.key});

  @override
  State<YearEndClosingConfigScreen> createState() => _YearEndClosingConfigScreenState();
}

class _YearEndClosingConfigScreenState extends State<YearEndClosingConfigScreen> with ImMasterKit {
  final _service = YearEndClosingService();
  final _accountService = AccountService();
  final _docService = ModuleDocumentService();

  List<Account> _accounts = [];
  List<ModuleDocument> _docTypes = [];
  ClosingConfig? _config;
  ClosingConfigSummary? _summary;

  Account? _incomeSummary;
  Account? _retained;
  ModuleDocument? _closingDoc;
  ModuleDocument? _carryDoc;

  bool _loading = false;
  bool _saving = false;
  bool _editing = false;
  bool _isEnglish = false;

  static final _amt = NumberFormat('#,##0.00');

  @override
  bool get kitEnglish => _isEnglish;
  @override
  bool get kitReadOnly => !_editing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final accounts = await _accountService.fetchRowsControlAccount();
      final docs = await _docService.fetchRows();
      final gl = docs.where((d) => d.isDocType && d.isActive && d.sysModule == '01').toList()..sort((a, b) => a.docCode.compareTo(b.docCode));
      ClosingConfig? cfg;
      try {
        cfg = await _service.fetchConfig();
      } catch (_) {}
      ClosingConfigSummary? sum;
      try {
        sum = await _service.fetchConfigSummary();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _docTypes = gl;
        _config = cfg;
        _summary = sum;
        _editing = false;
        _reset();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text((_isEnglish ? 'Error loading data: ' : 'เกิดข้อผิดพลาดในการโหลดข้อมูล: ') + e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _reset() {
    final c = _config;
    _incomeSummary = c == null ? null : _accounts.where((a) => a.id == c.incomeSummaryAccountId).firstOrNull;
    _retained = c == null ? null : _accounts.where((a) => a.id == c.retainedEarningsAccountId).firstOrNull;
    _closingDoc = c?.closingDocId == null ? null : _docTypes.where((d) => d.id == c!.closingDocId).firstOrNull;
    _carryDoc = c?.carryForwardDocId == null ? null : _docTypes.where((d) => d.id == c!.carryForwardDocId).firstOrNull;
  }

  String _fp() => docFingerprint([_incomeSummary?.id, _retained?.id, _closingDoc?.id, _carryDoc?.id]);
  String _snapshot = '';

  bool get _dirty => _editing && _fp() != _snapshot;

  /// ข้อผิดพลาดของบัญชี (null = ผ่าน)
  String? _accountProblem(Account? a, Account? other) {
    final e = _isEnglish;
    if (a == null) return e ? 'Not set' : 'ยังไม่ได้เลือก';
    final p = <String>[
      if (a.accountType != 'EQUITY') e ? 'must be an equity account' : 'ต้องเป็นบัญชีส่วนของเจ้าของ',
      if (!a.isNormalAccount) e ? 'must be postable' : 'ต้องเป็นบัญชีที่ลงรายการได้',
      if (a.isControlAccount) e ? 'must not be a control account' : 'ต้องไม่ใช่ Control account',
      if (!a.isActive) e ? 'is inactive' : 'บัญชีหยุดใช้',
      if (other != null && other.id == a.id) e ? 'must differ from the other account' : 'ต้องไม่ซ้ำกับอีกบัญชี',
    ];
    return p.isEmpty ? null : p.join(' · ');
  }

  List<String> get _missing {
    final e = _isEnglish;
    return [
      if (_accountProblem(_incomeSummary, _retained) != null) e ? 'Income summary account' : 'บัญชีสรุปกำไรขาดทุน',
      if (_accountProblem(_retained, _incomeSummary) != null) e ? 'Retained earnings account' : 'บัญชีกำไรสะสม',
      if (_closingDoc == null) e ? 'Closing document type' : 'เอกสารปิดบัญชี',
      if (_carryDoc == null) e ? 'Carry-forward document type' : 'เอกสารยกยอด',
    ];
  }

  Future<void> _save() async {
    final e = _isEnglish;
    final miss = _missing;
    if (miss.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e ? 'Please fix: ${miss.join(', ')}' : 'กรุณาแก้ไข: ${miss.join(', ')}'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.saveConfig(ClosingConfig(
        id: _config?.id,
        incomeSummaryAccountId: _incomeSummary!.id,
        retainedEarningsAccountId: _retained!.id,
        // คงประเภทบัญชีรายได้/ค่าใช้จ่ายเดิมไว้ (หน้าจอเดิมเขียนทับเป็นค่าตั้งต้นทุกครั้ง)
        revenueAccountTypes: _config?.revenueAccountTypes ?? const ['REVENUE'],
        expenseAccountTypes: _config?.expenseAccountTypes ?? const ['EXPENSE'],
        closingDocId: _closingDoc!.id,
        carryForwardDocId: _carryDoc!.id,
      ));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ? 'Settings saved' : 'บันทึกการตั้งค่าเรียบร้อยแล้ว')));
      await _load();
    } catch (ex) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text((e ? 'Error saving: ' : 'เกิดข้อผิดพลาดในการบันทึก: ') + ex.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _acct(Account a) => '${a.accountCode}  ${_isEnglish && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai}';
  String _doc(ModuleDocument d) => '${d.docCode}  ${_isEnglish && d.docNameEng.isNotEmpty ? d.docNameEng : d.docNameThai}';

  /// dialog ค้นหา (บัญชีลงรายการได้ / ประเภทเอกสาร GL ที่ใช้งาน)
  Future<T?> _pick<T>(String title, List<T> items, String Function(T) label, {List<T> Function(List<T>)? sort}) async {
    final ctrl = TextEditingController();
    var shown = items;
    final r = await showDialog<T>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 520,
            height: 420,
            child: Column(children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: InputDecoration(
                    hintText: _isEnglish ? 'Search code / name' : 'ค้นหา รหัส / ชื่อ', prefixIcon: const Icon(Icons.search), border: const OutlineInputBorder(), isDense: true),
                onChanged: (q) => setD(() => shown = items.where((x) => label(x).toUpperCase().contains(q.trim().toUpperCase())).toList()),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: shown.isEmpty
                    ? Center(child: Text(_isEnglish ? 'No results' : 'ไม่พบข้อมูล'))
                    : ListView.builder(
                        itemCount: shown.length,
                        itemBuilder: (_, i) => ListTile(dense: true, title: Text(label(shown[i])), onTap: () => Navigator.of(ctx).pop(shown[i])),
                      ),
              ),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(_isEnglish ? 'Close' : 'ปิด'))],
        ),
      ),
    );
    ctrl.dispose();
    return r;
  }

  Widget _check(String? problem) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(children: [
          Icon(problem == null ? Icons.check_circle : Icons.error_outline, size: 14, color: problem == null ? ImKit.ok : ImKit.red),
          const SizedBox(width: 4),
          Expanded(
            child: Text(problem ?? (_isEnglish ? 'Equity · postable' : 'ส่วนของเจ้าของ · ลงรายการได้'),
                style: TextStyle(fontSize: 11.5, color: problem == null ? ImKit.ok : ImKit.red)),
          ),
        ]),
      );

  Widget _settingsCard() {
    final e = _isEnglish;
    final equity = _accounts.where((a) => a.accountType == 'EQUITY').toList()..sort((a, b) => a.accountCode.compareTo(b.accountCode));
    final others = _accounts.where((a) => a.accountType != 'EQUITY').toList()..sort((a, b) => a.accountCode.compareTo(b.accountCode));
    final pickList = [...equity, ...others];
    return kCard(
      title: e ? 'Settings' : 'การตั้งค่า',
      count: e ? 'Used to create the closing entries automatically' : 'ระบบใช้ค่าเหล่านี้สร้างรายการโอนปิดบัญชีอัตโนมัติ',
      trailing: _editing ? kLegend(withAuto: false) : null,
      child: kGroups([
        kGroup(1, e ? 'Closing Accounts' : 'บัญชีที่ใช้ปิดบัญชี', ImKit.gFin, [
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            kFk(
              label: e ? 'Income Summary account *' : 'บัญชีสรุปกำไรขาดทุน (Income Summary) *',
              text: _incomeSummary == null ? null : _acct(_incomeSummary!),
              hasValue: _incomeSummary != null,
              onSearch: () async {
                final a = await _pick<Account>(e ? 'Select Income Summary account' : 'เลือกบัญชีสรุปกำไรขาดทุน', pickList, _acct);
                if (a != null) setState(() => _incomeSummary = a);
              },
            ),
            _check(_accountProblem(_incomeSummary, _retained)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            kFk(
              label: e ? 'Retained Earnings account *' : 'บัญชีกำไรสะสม (Retained Earnings) *',
              text: _retained == null ? null : _acct(_retained!),
              hasValue: _retained != null,
              onSearch: () async {
                final a = await _pick<Account>(e ? 'Select Retained Earnings account' : 'เลือกบัญชีกำไรสะสม', pickList, _acct);
                if (a != null) setState(() => _retained = a);
              },
            ),
            _check(_accountProblem(_retained, _incomeSummary)),
          ]),
          kNote(e
              ? 'Checked automatically: equity, postable, not a control account, and the two accounts must differ.'
              : 'ตรวจให้อัตโนมัติ: ต้องเป็นบัญชีส่วนของเจ้าของ ลงรายการได้ ไม่ใช่ Control และสองบัญชีต้องไม่ซ้ำกัน'),
        ]),
        kGroup(2, e ? 'Auto-generated Document Types' : 'ประเภทเอกสารที่สร้างอัตโนมัติ', ImKit.gDoc, [
          kFk(
            label: e ? 'Revenue/expense closing document (steps 3 and 4) *' : 'เอกสารปิดบัญชีรายได้/ค่าใช้จ่าย (ขั้นตอน 3 และ 4) *',
            text: _closingDoc == null ? null : _doc(_closingDoc!),
            hasValue: _closingDoc != null,
            onSearch: () async {
              final d = await _pick<ModuleDocument>(e ? 'Select closing document type' : 'เลือกเอกสารปิดบัญชี', _docTypes, _doc);
              if (d != null) setState(() => _closingDoc = d);
            },
          ),
          kFk(
            label: e ? 'Balance sheet carry-forward document (step 5) *' : 'เอกสารยกยอดงบดุล (ขั้นตอน 5) *',
            text: _carryDoc == null ? null : _doc(_carryDoc!),
            hasValue: _carryDoc != null,
            onSearch: () async {
              final d = await _pick<ModuleDocument>(e ? 'Select carry-forward document type' : 'เลือกเอกสารยกยอด', _docTypes, _doc);
              if (d != null) setState(() => _carryDoc = d);
            },
          ),
          kNote(e ? 'Only active GL document types can be selected.' : 'เลือกได้เฉพาะประเภทเอกสาร GL ที่ใช้งานอยู่'),
        ]),
      ]),
    );
  }

  Widget _stepsCard() {
    final e = _isEnglish;
    final s = _summary;
    final steps = s?.nextSteps ?? const <int, bool>{};
    final isAcc = _incomeSummary?.accountCode ?? '-';
    final re = _retained?.accountCode ?? '-';
    final cd = _closingDoc?.docCode ?? '-';
    final cf = _carryDoc?.docCode ?? '-';
    final items = <(String, String, String)>[
      (e ? 'Check periods' : 'ตรวจงวด', e ? 'All periods of the year closed in AR/AP/IM/CM' : 'ทุกงวดของปีต้องปิดโมดูลย่อยแล้ว',
          s == null ? '' : (e ? 'GL closed ${s.nextClosedPeriods}/${s.nextTotalPeriods}' : 'ปิด GL แล้ว ${s.nextClosedPeriods}/${s.nextTotalPeriods} งวด')),
      (e ? 'Adjusting entries' : 'รายการปรับปรุง', e ? 'Post adjusting templates, no drafts left' : 'บันทึกรายการปรับปรุง ไม่มี Draft ค้าง',
          s == null ? '' : (e ? 'Draft entries ${s.nextDraftEntries}' : 'Draft ค้าง ${s.nextDraftEntries}')),
      (e ? 'Close revenue/expense' : 'โอนรายได้/ค่าใช้จ่าย', e ? 'Close revenue and expense accounts into income summary' : 'ปิดบัญชีรายได้-ค่าใช้จ่ายเข้าบัญชีสรุปกำไรขาดทุน', '$cd → $isAcc'),
      (e ? 'Transfer net income' : 'โอนกำไรสุทธิ', e ? 'Income summary into retained earnings' : 'บัญชีสรุปกำไรขาดทุนเข้ากำไรสะสม', '$cd  $isAcc → $re'),
      (e ? 'Carry forward' : 'ยกยอดงบดุล', e ? 'Assets/liabilities/equity to next year' : 'สินทรัพย์/หนี้สิน/ทุน ไปปีถัดไป', e ? '$cf → next year' : '$cf → ปีถัดไป'),
      (e ? 'Lock periods' : 'ล็อกงวด', e ? 'Close GL of every period of the year' : 'ปิด GL ทุกงวดของปี', ''),
    ];
    Widget box(int i) {
      final done = steps[i + 1] == true;
      return Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: done ? ImKit.okSoft : Colors.white,
          border: Border.all(color: done ? const Color(0xFFB9DCC4) : ImKit.line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 20, height: 20, alignment: Alignment.center,
              decoration: BoxDecoration(color: done ? ImKit.ok : kInk, borderRadius: BorderRadius.circular(10)),
              child: done ? const Icon(Icons.check, size: 13, color: Colors.white) : Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 6),
            Expanded(child: Text(items[i].$1, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 4),
          Text(items[i].$2, style: const TextStyle(fontSize: 11.5, color: ImKit.ink2)),
          if (items[i].$3.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(items[i].$3, style: TextStyle(fontSize: 11.5, color: kInk, fontWeight: FontWeight.w600)),
          ],
        ]),
      );
    }

    return kCard(
      title: e ? 'Closing Steps' : 'ขั้นตอนปิดบัญชี',
      count: s?.nextFyCode == null
          ? (e ? 'Read-only' : 'อ่านอย่างเดียว')
          : (e ? 'Read-only · progress of fiscal year ${s!.nextFyCode}' : 'อ่านอย่างเดียว · ความคืบหน้าของปีบัญชี ${s!.nextFyCode}'),
      trailing: kGhost(e ? 'Open Year-End Closing' : 'ไปหน้าปิดบัญชีสิ้นปี', Icons.open_in_new,
          () => ImKit.openMenu(context, 'YearEndClosingScreen', 'ปิดบัญชีสิ้นปี', 'Year-End Closing', e)),
      child: LayoutBuilder(builder: (c, cons) {
        final cols = cons.maxWidth >= 900 ? 6 : (cons.maxWidth >= 520 ? 3 : 1);
        final w = (cons.maxWidth - 8 * (cols - 1)) / cols;
        return Wrap(spacing: 8, runSpacing: 8, children: [for (var i = 0; i < items.length; i++) SizedBox(width: w, child: box(i))]);
      }),
    );
  }

  Widget _historyCard() {
    final e = _isEnglish;
    final h = _summary?.history ?? const <ClosingHistoryRow>[];
    String net(double v) => v < 0 ? '(${_amt.format(-v)})' : _amt.format(v);
    return kCard(
      title: e ? 'Closing History' : 'ประวัติการปิดบัญชี',
      count: e ? 'Read-only' : 'อ่านอย่างเดียว',
      padding: EdgeInsets.zero,
      child: kTable([
        KCol(e ? 'Fiscal year' : 'ปีบัญชี', 2),
        KCol(e ? 'Status' : 'สถานะ', 3),
        KCol(e ? 'Last updated' : 'อัปเดตล่าสุด', 3),
        KCol(e ? 'Closing doc' : 'เอกสารปิด', 3),
        KCol(e ? 'Carry-forward doc' : 'เอกสารยกยอด', 3),
        KCol(e ? 'Net income (loss)' : 'กำไร(ขาดทุน)สุทธิ', 3, num: true),
      ], [
        for (final r in h)
          [
            kCell(r.fyCode, bold: true),
            r.status == 'COMPLETED'
                ? ImKit.chip(e ? 'Completed' : 'ปิดเสร็จแล้ว', ImKit.okSoft, ImKit.ok)
                : ImKit.chip(e ? 'In progress' : 'กำลังดำเนินการ', ImKit.goldSoft, ImKit.amber),
            kCell(r.updatedAt == null ? '' : DateFormat('dd/MM/yyyy HH:mm').format(r.updatedAt!), color: ImKit.ink2),
            kCell(r.closingDocNo ?? ''),
            kCell(r.carryDocNo ?? ''),
            kCell(r.closingDocNo == null ? '' : net(r.netIncome), mono: true, color: r.netIncome < 0 ? ImKit.red : null),
          ],
      ], minWidth: 760, empty: e ? 'No year has been closed yet' : 'ยังไม่เคยปิดบัญชีสิ้นปี'),
    );
  }

  List<ImKpi> _kpis() {
    final e = _isEnglish;
    final s = _summary;
    if (s == null) return const [];
    final last = s.lastClosed;
    return [
      ImKpi(e ? 'Last closed year' : 'ปีล่าสุดที่ปิดบัญชี', last?.fyCode ?? '-',
          last?.updatedAt == null ? (e ? 'Not closed yet' : 'ยังไม่เคยปิด') : (e ? 'closed ${DateFormat('dd/MM/yyyy').format(last!.updatedAt!)}' : 'ปิดเมื่อ ${DateFormat('dd/MM/yyyy').format(last!.updatedAt!)}')),
      ImKpi(e ? 'Next year to close' : 'ปีถัดไปที่ต้องปิด', s.nextFyCode ?? '-',
          s.nextFyCode == null ? '-' : (e ? 'GL closed ${s.nextClosedPeriods}/${s.nextTotalPeriods} periods' : 'ปิด GL แล้ว ${s.nextClosedPeriods}/${s.nextTotalPeriods} งวด')),
      ImKpi(e ? 'Net income (loss) this year' : 'กำไร(ขาดทุน) ปีนี้ถึงวันนี้', _amt.format(s.netIncomeYtd),
          e ? 'revenue − expenses · FY ${s.currentFyCode ?? '-'}' : 'รายได้ − ค่าใช้จ่าย · ปี ${s.currentFyCode ?? '-'}', warn: s.netIncomeYtd < 0),
      ImKpi(e ? 'Retained earnings' : 'กำไรสะสม', _amt.format(s.retainedEarnings),
          _retained == null ? '-' : (e ? 'account ${_retained!.accountCode} this year' : 'ยอดบัญชี ${_retained!.accountCode} ปีนี้')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    _isEnglish = context.watch<LanguageProvider>().isEnglish;
    final e = _isEnglish;
    final canEdit = MenuScope.of(context)?.canEdit ?? true;
    final miss = _missing;
    final acts = _editing
        ? [
            DocBarAction(e ? 'Cancel' : 'ยกเลิก', _saving
                ? null
                : () async {
                    if (_dirty && !await confirmDiscardChanges(context, e)) return;
                    setState(() {
                      _editing = false;
                      _reset();
                    });
                  }, fg: kInk),
            DocBarAction(_saving ? (e ? 'Saving...' : 'กำลังบันทึก...') : (e ? 'Save' : 'บันทึก'), _saving ? null : _save,
                fg: const Color(0xFF0B3A2A), bg: ImKit.gold, primary: true),
          ]
        : [
            DocBarAction(e ? 'Open Year-End Closing' : 'ไปหน้าปิดบัญชีสิ้นปี',
                () => ImKit.openMenu(context, 'YearEndClosingScreen', 'ปิดบัญชีสิ้นปี', 'Year-End Closing', e), fg: kInk),
            if (canEdit)
              DocBarAction(e ? 'Edit' : 'แก้ไข', () => setState(() {
                    _editing = true;
                    _snapshot = _fp();
                  }), fg: Colors.white, bg: kInk, primary: true),
          ];
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: ScreenTheme.of(context).bar,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: e ? 'Refresh' : 'รีเฟรช',
            onPressed: _saving
                ? null
                : () async {
                    if (_dirty && !await confirmDiscardChanges(context, e)) return;
                    _load();
                  },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading && _accounts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : kPage(
              header: kHeaderBar(
                title: e ? 'Year-End Closing Settings' : 'การตั้งค่าปิดบัญชีสิ้นปี',
                badges: [
                  if (_editing) kEditingBadge(),
                  miss.isEmpty
                      ? ImKit.chip(e ? 'Complete' : 'ครบถ้วน', ImKit.okSoft, ImKit.ok)
                      : Tooltip(message: miss.join(', '), child: ImKit.chip(e ? '${miss.length} to fix' : 'ต้องแก้ ${miss.length}', ImKit.redSoft, ImKit.red)),
                ],
                acts: acts,
                busy: _saving,
              ),
              top: kKpis(_kpis(), loading: _loading),
              sections: [
                (0, e ? 'Settings' : 'การตั้งค่า', _settingsCard()),
                (1, e ? 'Closing steps' : 'ขั้นตอนปิดบัญชี', _stepsCard()),
                (2, e ? 'History' : 'ประวัติการปิดบัญชี', _historyCard()),
              ],
            ),
    );
  }
}
