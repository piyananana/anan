import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/services/sa_module_document_service.dart';
import '../models/im_accounting_setting.dart';
import '../services/im_accounting_setting_service.dart';
import '../widgets/im_master_kit.dart';
import '../../sa/utils/sa_menu_theme.dart';

// หน้าตั้งค่าโหมดบัญชีสินค้าเริ่มต้นของบริษัท (PERPETUAL/PERIODIC) — สินค้า/หมวดสินค้า/คลัง override ได้
// (ลำดับ สินค้า → หมวดสินค้า → คลัง → ค่าเริ่มต้นนี้, ดู project_im_mixed_accounting_mode) — ดู pattern_im_periodic_accounting_mode:
// PERPETUAL = ธุรกรรม IM ทุกรายการ Post GL ทันที (ของเดิม), PERIODIC = ไม่ Post GL ต่อธุรกรรมเลย รอปิดงวด
// ครั้งเดียว (ดูหน้าจอ ImPeriodClosingScreen) — subledger (im_stock_balance/im_stock_layer) อัปเดตแบบเดียวกัน
// ทุกโหมดเสมอ ไม่ผูกกับการตั้งค่านี้
// หน้าตาแบบ B ของ IM (user 2026-11-26): แถบหัว + ตัวเลขสรุป + กลุ่มสี + ลำดับที่ใช้ + รายการที่ตั้งโหมดแยก, เปิดมาในโหมดดู
class ImAccountingSettingScreen extends StatefulWidget {
  const ImAccountingSettingScreen({super.key});

  @override
  State<ImAccountingSettingScreen> createState() => _ImAccountingSettingScreenState();
}

/// บัญชีที่เลือก (เก็บทั้งชื่อไทย/อังกฤษ ให้สลับภาษาได้ทันที)
class _Acc {
  final int id;
  final String code;
  final String th;
  final String en;
  const _Acc(this.id, this.code, this.th, this.en);
  String label(bool e) => '$code  ${e && en.isNotEmpty ? en : th}';
  static _Acc? of(int? id, String? code, String? th, String? en) =>
      id == null ? null : _Acc(id, code ?? '', th ?? '', en ?? '');
  static _Acc fromAccount(Account a) => _Acc(a.id, a.accountCode, a.accountNameThai, a.accountNameEng);
}

class _Override {
  final String level; // WAREHOUSE / CATEGORY / ITEM
  final String code, nameTh, nameEn, mode;
  final String? purCode, purTh, purEn;
  _Override(Map<String, dynamic> j)
      : level = j['level'] ?? '',
        code = j['code'] ?? '',
        nameTh = j['name_th'] ?? '',
        nameEn = j['name_en'] ?? '',
        mode = j['mode'] ?? '',
        purCode = j['purchases_account_code'],
        purTh = j['purchases_account_name'],
        purEn = j['purchases_account_name_eng'];
  String name(bool e) => e && nameEn.isNotEmpty ? nameEn : nameTh;
}

class _ImAccountingSettingScreenState extends State<ImAccountingSettingScreen> with ImMasterKit {
  final ImAccountingSettingService _svc = ImAccountingSettingService();
  final AccountService _acctSvc = AccountService();
  final ModuleDocumentService _docSvc = ModuleDocumentService();

  bool _isEnglish = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _editing = false;

  List<Account> _accounts = [];
  List<ModuleDocument> _glDocs = [];
  ImAccountingSetting? _setting;
  Map<String, dynamic>? _summary;

  String _mode = 'PERPETUAL';
  _Acc? _inv, _cogs, _pur;
  ModuleDocument? _closingDoc;
  String? _closingDocCode, _closingDocTh, _closingDocEn; // จากฐานข้อมูล (ก่อนโหลดรายการเอกสาร/เมื่อเอกสารถูกปิดใช้)
  int? _closingDocId;

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
    final e = _isEnglish;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _svc.fetchSetting(),
        _acctSvc.fetchRows(),
        _docSvc.fetchRows(),
        _svc.fetchSummary().catchError((_) => <String, dynamic>{}),
      ]);
      _setting = results[0] as ImAccountingSetting?;
      _accounts = (results[1] as List<Account>).where((a) => a.isActive && a.isNormalAccount).toList()
        ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
      _glDocs = (results[2] as List<ModuleDocument>).where((d) => d.isDocType && d.sysModule == '01' && d.isActive).toList()
        ..sort((a, b) => a.docCode.compareTo(b.docCode));
      final sm = results[3] as Map<String, dynamic>;
      _summary = sm.isEmpty ? null : sm;
      _apply(_setting);
      _editing = false;
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ? 'Error: $err' : 'เกิดข้อผิดพลาด: $err'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _apply(ImAccountingSetting? s) {
    _mode = s?.inventoryAccountingMode ?? 'PERPETUAL';
    _inv = _Acc.of(s?.inventoryAccountId, s?.inventoryAccountCode, s?.inventoryAccountName, s?.inventoryAccountNameEng);
    _cogs = _Acc.of(s?.cogsAccountId, s?.cogsAccountCode, s?.cogsAccountName, s?.cogsAccountNameEng);
    _pur = _Acc.of(s?.purchasesAccountId, s?.purchasesAccountCode, s?.purchasesAccountName, s?.purchasesAccountNameEng);
    _closingDocId = s?.closingGlDocId;
    _closingDocCode = s?.closingDocCode;
    _closingDocTh = s?.closingDocNameThai;
    _closingDocEn = s?.closingDocNameEng;
    _closingDoc = _glDocs.where((d) => d.id == _closingDocId).firstOrNull;
  }

  String? get _closingLabel {
    if (_closingDocId == null) return null;
    final d = _closingDoc;
    if (d != null) return '${d.docCode}  ${_isEnglish && d.docNameEng.isNotEmpty ? d.docNameEng : d.docNameThai}';
    return '${_closingDocCode ?? ''}  ${_isEnglish && (_closingDocEn ?? '').isNotEmpty ? _closingDocEn : (_closingDocTh ?? '')}';
  }

  bool get _anyPeriodic => _mode == 'PERIODIC' || (_summary?['any_periodic'] == true);

  // ช่องที่ยังไม่ตั้ง — บัญชีซื้อนับเฉพาะเมื่อมีสต็อก Periodic
  List<String> _missing(bool e) => [
        if (_inv == null) e ? 'inventory account' : 'บัญชีสินค้าคงเหลือ',
        if (_cogs == null) e ? 'COGS account' : 'บัญชีต้นทุนขาย',
        if (_anyPeriodic && _pur == null) e ? 'purchases account' : 'บัญชีซื้อสินค้า',
        if (_anyPeriodic && _closingDocId == null) e ? 'closing GL document type' : 'ประเภทเอกสาร GL ปิดงวด',
      ];

  Future<void> _save() async {
    final e = _isEnglish;
    setState(() => _isSaving = true);
    try {
      await _svc.upsertSetting(ImAccountingSetting(
        inventoryAccountingMode: _mode,
        modeEffectivePeriodId: _setting?.modeEffectivePeriodId,
        inventoryAccountId: _inv?.id,
        cogsAccountId: _cogs?.id,
        purchasesAccountId: _pur?.id,
        closingGlDocId: _closingDocId,
      ));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ? 'Saved successfully' : 'บันทึกสำเร็จ')));
      await _load();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ? 'Save failed: $err' : 'บันทึกล้มเหลว: $err'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _cancel() => setState(() {
        _apply(_setting);
        _editing = false;
      });

  // ── ตัวเลือก ──
  Future<T?> _pickFrom<T>(String title, List<T> all, String Function(T) label, bool Function(T, String) match) async {
    final e = _isEnglish;
    final searchCtrl = TextEditingController();
    var filtered = List<T>.from(all);
    T? picked;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 500,
            height: 420,
            child: Column(children: [
              TextField(
                controller: searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                    hintText: e ? 'Search code / name' : 'ค้นหา รหัส / ชื่อ',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    isDense: true),
                onChanged: (q) => setDlg(() {
                  final lq = q.toLowerCase();
                  filtered = q.isEmpty ? List.from(all) : all.where((x) => match(x, lq)).toList();
                }),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => ListTile(
                    dense: true,
                    title: Text(label(filtered[i]), style: const TextStyle(fontSize: 13)),
                    onTap: () {
                      picked = filtered[i];
                      Navigator.of(ctx).pop();
                    },
                  ),
                ),
              ),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(e ? 'Cancel' : 'ยกเลิก'))],
        );
      }),
    );
    searchCtrl.dispose();
    return picked;
  }

  Future<void> _pickAccount(String title, void Function(_Acc) set) async {
    final e = _isEnglish;
    final a = await _pickFrom<Account>(
      title,
      _accounts,
      (a) => '${a.accountCode}  ${e && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai}',
      (a, q) => a.accountCode.toLowerCase().contains(q) || a.accountNameThai.toLowerCase().contains(q) || a.accountNameEng.toLowerCase().contains(q),
    );
    if (a != null) setState(() => set(_Acc.fromAccount(a)));
  }

  Future<void> _pickClosingDoc() async {
    final e = _isEnglish;
    final d = await _pickFrom<ModuleDocument>(
      e ? 'Select GL Document Type' : 'เลือกประเภทเอกสาร GL',
      _glDocs,
      (d) => '${d.docCode}  ${e && d.docNameEng.isNotEmpty ? d.docNameEng : d.docNameThai}',
      (d, q) => d.docCode.toLowerCase().contains(q) || d.docNameThai.toLowerCase().contains(q) || d.docNameEng.toLowerCase().contains(q),
    );
    if (d != null) {
      setState(() {
        _closingDoc = d;
        _closingDocId = d.id;
      });
    }
  }

  void _openMenu(String target, String th, String en) => ImKit.openMenu(context, target, th, en, _isEnglish);

  // ── ส่วนต่างๆ ──
  Widget _modeCard(String value, String title, String desc) {
    final on = _mode == value;
    return InkWell(
      onTap: _editing ? () => setState(() => _mode = value) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
        decoration: BoxDecoration(
          color: on ? ScreenTheme.of(context).soft : Colors.white,
          border: Border.all(color: on ? ScreenTheme.of(context).ink : ImKit.line, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(on ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 16, color: on ? ScreenTheme.of(context).ink : Colors.grey),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
          ]),
          const SizedBox(height: 3),
          Text(desc, style: const TextStyle(fontSize: 11.5, color: ImKit.ink2)),
        ]),
      ),
    );
  }

  Widget _buildMainCard(bool e) {
    final lastClosing = _summary?['last_closing'] as Map<String, dynamic>?;
    String lastClosingText = '';
    if (lastClosing != null) {
      final at = lastClosing['posted_at']?.toString();
      final d = at == null ? null : DateTime.tryParse(at)?.toLocal();
      final ds = d == null ? '' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      lastClosingText = [lastClosing['period_name'], ds, lastClosing['doc_no']].where((x) => x != null && '$x'.isNotEmpty).join(' · ');
    }
    return kCard(
      title: e ? 'Mode and default accounts' : 'โหมดและบัญชีเริ่มต้น',
      trailing: kLegend(withAuto: false),
      child: kGroups([
        kGroup(1, e ? 'Company default mode' : 'โหมดเริ่มต้นของบริษัท', ImKit.gDoc, [
          LayoutBuilder(builder: (c, cons) {
            final a = _modeCard('PERPETUAL', 'Perpetual',
                e ? 'Post to the GL on every transaction; GL stock always matches the system' : 'โพสต์บัญชีทุกธุรกรรมทันที สต็อกในบัญชีตรงกับระบบตลอด');
            final b = _modeCard('PERIODIC', 'Periodic',
                e ? 'No GL per transaction; one entry at period-end closing, purchases go to the purchases account'
                  : 'ไม่โพสต์บัญชีต่อธุรกรรม โพสต์ครั้งเดียวตอนปิดงวด ซื้อลงบัญชีซื้อสินค้า');
            if (cons.maxWidth < 420) return Column(children: [a, const SizedBox(height: 8), b]);
            return IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: a), const SizedBox(width: 8), Expanded(child: b)]),
            );
          }),
          kNote(e ? 'Quantity and cost tracking is the same in both modes.' : 'จำนวนและต้นทุนสินค้าติดตามแบบเดียวกันทั้ง 2 โหมด', color: ImKit.ink2),
        ]),
        kGroup(2, e ? 'Default accounts (both modes)' : 'บัญชีเริ่มต้น (ใช้ทั้ง 2 โหมด)', ImKit.gParty, [
          kNote(e ? 'Used when the warehouse, item, item category and document type have no account; also used by period-end closing.'
                  : 'ใช้เมื่อคลัง สินค้า หมวดสินค้า และประเภทเอกสารไม่ได้ระบุบัญชี และใช้ตอนปิดงวด', color: ImKit.ink2),
          kFk(
            label: e ? 'Inventory Account' : 'บัญชีสินค้าคงเหลือ',
            text: _inv?.label(e),
            hasValue: _inv != null,
            onSearch: () => _pickAccount(e ? 'Select Inventory Account' : 'เลือกบัญชีสินค้าคงเหลือ', (a) => _inv = a),
            onClear: () => setState(() => _inv = null),
          ),
          kFk(
            label: e ? 'COGS Account' : 'บัญชีต้นทุนขาย',
            text: _cogs?.label(e),
            hasValue: _cogs != null,
            onSearch: () => _pickAccount(e ? 'Select COGS Account' : 'เลือกบัญชีต้นทุนขาย', (a) => _cogs = a),
            onClear: () => setState(() => _cogs = null),
          ),
        ]),
        kGroup(3, e ? 'Default accounts (Periodic)' : 'บัญชีเริ่มต้น (Periodic)', ImKit.gFin, [
          kNote(e ? 'Receipts and AP documents of Periodic stock debit this account instead of inventory, unless the warehouse, item or category sets its own.'
                  : 'เอกสารรับสินค้าและเอกสาร AP ของสต็อก Periodic ลงบัญชีนี้แทนบัญชีสต็อก ถ้าคลัง สินค้า หรือหมวดสินค้าไม่ได้ระบุบัญชีซื้อของตัวเอง',
              color: ImKit.ink2),
          kFk(
            label: e ? 'Purchases Account' : 'บัญชีซื้อสินค้า',
            text: _pur?.label(e),
            hasValue: _pur != null,
            onSearch: () => _pickAccount(e ? 'Select Purchases Account' : 'เลือกบัญชีซื้อสินค้า', (a) => _pur = a),
            onClear: () => setState(() => _pur = null),
          ),
        ]),
        kGroup(4, e ? 'Period-end closing' : 'ปิดงวด', ImKit.gMore, [
          kFk(
            label: e ? 'Closing GL Document Type' : 'ประเภทเอกสาร GL สำหรับปิดงวด',
            text: _closingLabel,
            hasValue: _closingDocId != null,
            onSearch: _pickClosingDoc,
            onClear: () => setState(() {
              _closingDoc = null;
              _closingDocId = null;
            }),
          ),
          InputDecorator(
            decoration: kDec(e ? 'Last closing' : 'ปิดงวดล่าสุด', editable: false),
            child: Text(lastClosingText.isEmpty ? (e ? 'Not closed yet' : 'ยังไม่เคยปิดงวด') : lastClosingText,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: ImKit.font)),
          ),
        ]),
      ]),
    );
  }

  Widget _flowRow(String title, List<String> steps) {
    Widget step(String t, {bool me = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: me ? ImKit.goldSoft : Colors.white,
            border: Border.all(color: me ? const Color(0xFFF1D58F) : ImKit.line),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(t, style: TextStyle(fontSize: 12.5, color: me ? ImKit.amber : null, fontWeight: me ? FontWeight.w600 : null)),
        );
    final me = _isEnglish ? 'Default on this screen' : 'ค่าเริ่มต้นหน้านี้';
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 6, children: [
      SizedBox(width: 120, child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5))),
      for (final s in steps) ...[step(s), const Text('›', style: TextStyle(color: ImKit.ink3))],
      step(me, me: true),
    ]);
  }

  Widget _buildFlowCard(bool e) {
    final item = e ? 'Item' : 'สินค้า', cat = e ? 'Item category' : 'หมวดสินค้า', wh = e ? 'Warehouse' : 'คลัง';
    final doc = e ? 'IM document type' : 'ประเภทเอกสาร IM';
    return kCard(
      title: e ? 'Order the system uses to find the mode and accounts' : 'ลำดับที่ระบบใช้หาโหมดและบัญชี',
      count: e ? 'The first level that has a value is used' : 'ระบบใช้ชั้นแรกที่มีค่า',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _flowRow(e ? 'Accounting mode' : 'โหมดบัญชี', [item, cat, wh]),
        const SizedBox(height: 10),
        _flowRow(e ? 'Inventory account' : 'บัญชีสต็อก', [wh, item, cat, doc]),
        const SizedBox(height: 10),
        _flowRow(e ? 'COGS account' : 'บัญชีต้นทุนขาย', [item, cat, doc]),
        const SizedBox(height: 10),
        _flowRow(e ? 'Purchases account' : 'บัญชีซื้อสินค้า', [wh, item, cat]),
      ]),
    );
  }

  (String, Color, Color, String, String, String) _levelInfo(String level, bool e) => switch (level) {
        'WAREHOUSE' => (e ? 'Warehouse' : 'คลัง', ImKit.goldSoft, ImKit.amber, 'ImWarehouseScreen', 'คลังสินค้า', 'Warehouse'),
        'CATEGORY' => (e ? 'Category' : 'หมวด', ImKit.blueSoft, ImKit.blue, 'ImItemCategoryScreen', 'หมวดหมู่สินค้า', 'Item Category'),
        _ => (e ? 'Item' : 'สินค้า', ImKit.ro, ImKit.gMore, 'ImItemScreen', 'ข้อมูลสินค้า', 'Item'),
      };

  Widget _buildOverridesCard(bool e) {
    final list = ((_summary?['overrides'] as List?) ?? const []).map((j) => _Override(j as Map<String, dynamic>)).toList();
    final counts = _summary?['counts'] as Map<String, dynamic>? ?? const {};
    int total = 0;
    for (final c in counts.values) {
      final m = c as Map<String, dynamic>;
      total += (m['PERPETUAL'] as int? ?? 0) + (m['PERIODIC'] as int? ?? 0);
    }
    final hidden = total - list.length;
    String purText(_Override o) {
      if (o.purCode != null) return '${o.purCode}  ${e && (o.purEn ?? '').isNotEmpty ? o.purEn : (o.purTh ?? '')}';
      return o.level == 'ITEM' ? (e ? 'Uses category / default' : 'ใช้ของหมวด / ค่าเริ่มต้น') : (e ? 'Uses default' : 'ใช้ค่าเริ่มต้น');
    }

    return kCard(
      title: e ? 'Levels with their own mode' : 'รายการที่ตั้งโหมดแยก',
      count: e ? 'Read-only · $total rows · tap a row to open that screen' : 'อ่านอย่างเดียว · $total รายการ · กดแถวเพื่อเปิดหน้าจอนั้น',
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        kTable(
          [KCol(e ? 'Level' : 'ระดับ', 2), KCol(e ? 'Code / name' : 'รหัส / ชื่อ', 6), KCol(e ? 'Mode' : 'โหมด', 2),
            KCol(e ? 'Own purchases account' : 'บัญชีซื้อสินค้าของตัวเอง', 5)],
          [
            for (final o in list)
              () {
                final info = _levelInfo(o.level, e);
                return <Widget>[
                  ImKit.chip(info.$1, info.$2, info.$3),
                  kCell('${o.code}  ${o.name(e)}'),
                  o.mode == 'PERIODIC' ? ImKit.chip('Periodic', ImKit.purSoft, ImKit.pur) : ImKit.chip('Perpetual', ImKit.okSoft, ImKit.ok),
                  kCell(purText(o), color: o.purCode == null ? ImKit.ink3 : null),
                ];
              }(),
          ],
          onTap: [
            for (final o in list)
              () {
                final info = _levelInfo(o.level, e);
                _openMenu(info.$4, info.$5, info.$6);
              },
          ],
          minWidth: 640,
          empty: e
              ? 'No warehouse, category or item sets its own mode — everything uses the company default.'
              : 'ไม่มีคลัง หมวด หรือสินค้าที่ตั้งโหมดเอง ทุกสต็อกใช้ค่าเริ่มต้นของบริษัท',
        ),
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: kNote(e ? 'Showing the first ${list.length} rows; $hidden more items set their own mode.'
                           : 'แสดง ${list.length} แถวแรก · ยังมีสินค้าที่ตั้งโหมดเองอีก $hidden รายการ'),
          ),
      ]),
    );
  }

  List<ImKpi> _kpis(bool e) {
    final counts = _summary?['counts'] as Map<String, dynamic>? ?? const {};
    final overrides = ((_summary?['overrides'] as List?) ?? const []).map((j) => _Override(j as Map<String, dynamic>)).toList();
    ImKpi level(String key, String th, String en) {
      final m = counts[key] as Map<String, dynamic>? ?? const {};
      final per = m['PERIODIC'] as int? ?? 0, pp = m['PERPETUAL'] as int? ?? 0;
      final names = overrides.where((o) => o.level == key).map((o) => o.code).toList();
      final sub = per + pp == 0
          ? (e ? 'none' : 'ไม่มี')
          : (key != 'ITEM' && names.length <= 3 ? names.join(', ') : 'Periodic $per · Perpetual $pp');
      return ImKpi(e ? en : th, '${per + pp}', sub);
    }

    final open = _summary?['open_period'] as Map<String, dynamic>?;
    final last = _summary?['last_closing'] as Map<String, dynamic>?;
    final ImKpi fourth;
    if (!_anyPeriodic) {
      fourth = ImKpi(e ? 'Periodic closing' : 'ปิดงวด Periodic', e ? 'Not needed' : 'ไม่ต้องปิด', e ? 'No Periodic stock' : 'ไม่มีสต็อก Periodic');
    } else if (open != null) {
      fourth = ImKpi(e ? 'Period not yet closed' : 'งวดที่ยังไม่ปิด Periodic', '${open['period_name'] ?? ''}',
          e ? 'Tap to open stock period closing' : 'กดเพื่อไปหน้าปิดงวดสินค้า',
          warn: true, onTap: () => _openMenu('ImPeriodClosingScreen', 'ปิดงวดสินค้า', 'IM Period Closing'));
    } else {
      fourth = ImKpi(e ? 'Last period closed' : 'ปิดงวดล่าสุด', last == null ? '—' : '${last['period_name'] ?? ''}',
          last == null ? (e ? 'Not closed yet' : 'ยังไม่เคยปิดงวด') : '${last['doc_no'] ?? ''}',
          onTap: () => _openMenu('ImPeriodClosingScreen', 'ปิดงวดสินค้า', 'IM Period Closing'));
    }
    return [
      level('ITEM', 'สินค้าที่ตั้งโหมดเอง', 'Items with own mode'),
      level('CATEGORY', 'หมวดสินค้าที่ตั้งโหมดเอง', 'Categories with own mode'),
      level('WAREHOUSE', 'คลังที่ตั้งโหมดเอง', 'Warehouses with own mode'),
      fourth,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final e = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = e;
    final canEdit = MenuScope.of(context)?.canEdit ?? true;

    Widget body;
    if (_isLoading && _setting == null && _summary == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final missing = _missing(e);
      final acts = _editing
          ? [
              DocBarAction(e ? 'Cancel' : 'ยกเลิก', _isSaving ? null : _cancel, fg: ScreenTheme.of(context).ink),
              DocBarAction(_isSaving ? (e ? 'Saving...' : 'กำลังบันทึก...') : (e ? 'Save' : 'บันทึก'), _isSaving ? null : _save,
                  fg: const Color(0xFF0B3A2A), bg: ImKit.gold, primary: true),
            ]
          : [
              if (canEdit)
                DocBarAction(e ? 'Edit' : 'แก้ไข', () => setState(() => _editing = true), fg: Colors.white, bg: ScreenTheme.of(context).ink, primary: true),
            ];
      body = kPage(
        header: kHeaderBar(
          title: e ? 'Inventory accounting mode' : 'โหมดบัญชีสินค้าคงคลัง',
          badges: [
            ImKit.chip(e ? 'Default: ${_mode == 'PERIODIC' ? 'Periodic' : 'Perpetual'}' : 'ค่าเริ่มต้น: ${_mode == 'PERIODIC' ? 'Periodic' : 'Perpetual'}',
                Colors.white24, Colors.white),
            if (_editing) kEditingBadge(),
            missing.isEmpty
                ? ImKit.chip(e ? 'Complete' : 'ตั้งค่าครบ', ImKit.okSoft, ImKit.ok)
                : Tooltip(
                    message: missing.join(', '),
                    child: ImKit.chip(e ? '${missing.length} not set' : 'ยังไม่ตั้ง ${missing.length}', ImKit.redSoft, ImKit.red),
                  ),
          ],
          acts: acts,
          busy: _isSaving,
        ),
        top: kKpis(_summary == null ? const [] : _kpis(e), loading: _isLoading),
        sections: [
          (0, e ? 'Mode and default accounts' : 'โหมดและบัญชีเริ่มต้น', _buildMainCard(e)),
          (1, e ? 'Lookup order' : 'ลำดับที่ใช้', _buildFlowCard(e)),
          (2, e ? 'Levels with own mode' : 'รายการที่ตั้งโหมดแยก', _buildOverridesCard(e)),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: ScreenTheme.of(context).bar,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: e ? 'Refresh' : 'รีเฟรช',
            onPressed: _isSaving
                ? null
                : () async {
                    if (_editing && !await confirmDiscardChanges(context, e)) return;
                    _load();
                  },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: body,
    );
  }
}
