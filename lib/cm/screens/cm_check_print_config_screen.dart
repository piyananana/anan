// lib/cm/screens/cm_check_print_config_screen.dart — สร้างแบบพิมพ์เช็ค แบบ B ของ IM (user 2026-11-28)
//   เมนู "สร้างแบบพิมพ์เช็ค" (CmCheckPrintConfigScreen) — ย้ายมาจากแท็บ "ตำแหน่งพิมพ์" ของหน้าสมุดเช็ค
//   ซ้าย: แบบพิมพ์ทุกบัญชี (ตัวกรองบัญชี / บัญชีเช็คที่ยังไม่มีแบบ) / ขวา: ภาพตัวอย่างตามสเกลกระดาษ + ตั้งค่า (โหมดดู → แก้ไข)
//   พิมพ์ทดสอบใช้ตัวสร้าง PDF เดียวกับหน้าพิมพ์เช็คจ่าย (utils/cm_check_pdf.dart)
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../../im/widgets/im_master_kit.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../../utils/dot_matrix_pdf.dart';
import '../../utils/thai_amount_words.dart';
import '../../utils/date_utils.dart';
import '../models/cm_bank_account.dart';
import '../models/cm_checkbook.dart';
import '../services/cm_bank_account_service.dart';
import '../services/cm_checkbook_service.dart';
import '../utils/cm_check_pdf.dart';

class CmCheckPrintConfigScreen extends StatefulWidget {
  const CmCheckPrintConfigScreen({super.key});

  @override
  State<CmCheckPrintConfigScreen> createState() => _CmCheckPrintConfigScreenState();
}

class _CmCheckPrintConfigScreenState extends State<CmCheckPrintConfigScreen> with AutomaticKeepAliveClientMixin {
  final GlobalKey<_ConfigListState> _listKey = GlobalKey();
  final GlobalKey<_ConfigDetailState> _detailKey = GlobalKey();
  Mode _mode = Mode.none;
  CmCheckPrintConfig? _selected;
  CmCheckPrintConfig? _template; // เพิ่มใหม่จากสำเนา หรือจากบัญชีที่ยังไม่มีแบบ
  int _requestSeq = 0;
  bool _isEnglish = false;
  final _svc = CmCheckbookService();

  @override
  bool get wantKeepAlive => true;

  Future<bool> _confirmLeave() async {
    final d = _detailKey.currentState;
    if (d != null && d.isDirty) return confirmDiscardChanges(context, _isEnglish);
    return true;
  }

  Future<void> _onAdd({CmCheckPrintConfig? template}) async {
    if (!await _confirmLeave()) return;
    setState(() {
      _mode = Mode.add;
      _selected = null;
      _template = template;
      _requestSeq++;
    });
  }

  void _onCopy() {
    final s = _selected;
    if (s == null) return;
    setState(() {
      _mode = Mode.add;
      _template = s;
      _selected = null;
      _requestSeq++;
    });
  }

  void _onEdit() => setState(() {
        _mode = Mode.edit;
        _requestSeq++;
      });

  Future<void> _onView(CmCheckPrintConfig c) async {
    if (_mode == Mode.view && _selected?.id == c.id) return;
    if (!await _confirmLeave()) return;
    _show(c);
  }

  void _show(CmCheckPrintConfig c) => setState(() {
        _mode = Mode.view;
        _selected = c;
        _template = null;
        _requestSeq++;
      });

  void _close() => setState(() {
        _mode = Mode.none;
        _selected = null;
        _template = null;
        _requestSeq++;
      });

  Future<void> _onCancel() async {
    if (!await _confirmLeave()) return;
    if (_mode == Mode.edit && _selected != null) {
      _show(_selected!);
    } else {
      _close();
    }
  }

  Future<void> _onSubmit(CmCheckPrintConfig cfg) async {
    final e = _isEnglish;
    final saved = _mode == Mode.add ? await _svc.addPrintConfig(cfg) : await _svc.updatePrintConfig(cfg);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ? 'Saved successfully' : 'บันทึกสำเร็จ')));
    final rows = await _listKey.currentState?.refresh();
    final fresh = rows?.where((r) => r.id == saved.id).firstOrNull ?? saved;
    if (mounted) _show(fresh);
  }

  Future<void> _onDelete() async {
    final c = _selected;
    if (c?.id == null) return;
    final e = _isEnglish;
    final l = AppL10n(e);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.confirmDelete),
        content: Text(e ? 'Delete print layout "${c!.configName}"?' : 'ลบแบบพิมพ์ "${c!.configName}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.delete, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.deletePrintConfig(c!.id!);
      _listKey.currentState?.refresh();
      _close();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ? 'Deleted successfully' : 'ลบสำเร็จ')));
    } catch (ex) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ? 'Delete failed: $ex' : 'ลบล้มเหลว: $ex'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final perm = MenuScope.of(context);
    final canCreate = perm?.canCreate ?? true;
    final canEdit = perm?.canEdit ?? true;
    final canDelete = perm?.canDelete ?? true;
    final canPrint = perm?.canPrint ?? true;
    final view = _mode == Mode.view;
    return ImMasterShell(
      isEnglish: isEnglish,
      initialListWidth: 320,
      barActions: [
        if (canCreate) ImKit.barButton(context, isEnglish ? 'Add layout' : 'เพิ่มแบบพิมพ์', Icons.add, () => _onAdd(), primary: true),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: isEnglish ? 'Refresh' : 'รีเฟรชรายการ',
          onPressed: () async {
            if (!await _confirmLeave()) return;
            final rows = await _listKey.currentState?.refresh();
            final cur = _selected;
            if (cur != null && _mode != Mode.add) {
              final fresh = rows?.where((r) => r.id == cur.id).firstOrNull;
              fresh == null ? _close() : _show(fresh);
            } else {
              _close();
            }
          },
        ),
      ],
      list: _ConfigList(
        key: _listKey,
        selectedId: _mode == Mode.view || _mode == Mode.edit ? _selected?.id : null,
        onTap: _onView,
        onAddFor: canCreate ? (a) => _onAdd(template: CmCheckPrintConfig(bankAccountId: a.id!, configName: '', isDefault: true)) : null,
      ),
      detail: _ConfigDetail(
        key: _detailKey,
        mode: _mode,
        selected: _mode == Mode.add ? null : _selected,
        template: _mode == Mode.add ? _template : null,
        requestSeq: _requestSeq,
        onSubmit: _onSubmit,
        onCancel: view ? _close : _onCancel,
        onEdit: view && canEdit ? _onEdit : null,
        onDelete: view && canDelete ? _onDelete : null,
        onCopy: view && canCreate ? _onCopy : null,
        canPrint: canPrint,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// รายการแบบพิมพ์ (แผงซ้าย)
// ---------------------------------------------------------------------------
class _ConfigList extends StatefulWidget {
  final int? selectedId;
  final ValueChanged<CmCheckPrintConfig> onTap;
  final ValueChanged<CmBankAccount>? onAddFor;
  const _ConfigList({super.key, required this.selectedId, required this.onTap, this.onAddFor});

  @override
  State<_ConfigList> createState() => _ConfigListState();
}

class _ConfigListState extends State<_ConfigList> {
  final _search = TextEditingController();
  List<CmCheckPrintConfig> _rows = [];
  List<CmBankAccount> _accounts = [];
  int? _bankId;
  bool _missing = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<CmCheckPrintConfig>?> refresh() async {
    setState(() => _loading = true);
    List<CmCheckPrintConfig>? out;
    try {
      final rows = await CmCheckbookService().fetchPrintConfigs();
      out = rows;
      if (mounted) setState(() => _rows = rows);
    } catch (ex) {
      if (mounted) {
        final en = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(en ? 'Failed to load data: $ex' : 'ไม่สามารถโหลดข้อมูลได้: $ex')));
      }
    }
    try {
      final a = await CmBankAccountService().fetchRows();
      if (mounted) setState(() => _accounts = a.where((x) => x.cmType == 'BANK').toList()..sort((x, y) => x.accountCode.compareTo(y.accountCode)));
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final e = context.watch<LanguageProvider>().isEnglish;
    final q = _search.text.trim().toLowerCase();
    final acc = {for (final a in _accounts) a.id: a};
    final base = _rows
        .where((c) => q.isEmpty || c.configName.toLowerCase().contains(q) || (c.bankAccountCode ?? '').toLowerCase().contains(q))
        .toList();
    final shown = base.where((c) => _bankId == null || c.bankAccountId == _bankId).toList()
      ..sort((a, b) {
        final x = (a.bankAccountCode ?? '').compareTo(b.bankAccountCode ?? '');
        if (x != 0) return x;
        if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
        return a.configName.compareTo(b.configName);
      });
    final withCfg = {for (final c in _rows) c.bankAccountId};
    final missing = _accounts.where((a) => a.isCheckAccount && a.isActive && !withCfg.contains(a.id)).toList();
    final usedAccounts = _accounts.where((a) => withCfg.contains(a.id)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ImMasterListHeader(
        searchCtrl: _search,
        hint: e ? 'Search layout / bank account' : 'ค้นหา ชื่อแบบ / บัญชีธนาคาร',
        onSearch: (_) => setState(() {}),
        countText: _loading ? (e ? 'Loading...' : 'กำลังโหลด...') : (e ? '${shown.length} layout(s)' : 'แบบพิมพ์ ${shown.length} แบบ'),
        filters: [
          ImMasterFilterChip(
              label: e ? 'All' : 'ทั้งหมด',
              on: _bankId == null && !_missing,
              onTap: () => setState(() {
                    _bankId = null;
                    _missing = false;
                  })),
          ImMasterPopupFilter(
            label: e ? 'Account' : 'บัญชี',
            value: _bankId?.toString(),
            valueLabel: _bankId == null ? null : acc[_bankId]?.accountCode,
            options: [for (final a in usedAccounts) ('${a.id}', '${a.accountCode} ${a.name(e)}')],
            allLabel: e ? 'All accounts' : 'ทุกบัญชี',
            onChanged: (v) => setState(() {
              _bankId = v == null ? null : int.tryParse(v);
              _missing = false;
            }),
          ),
          ImMasterFilterChip(
              label: '${e ? 'Cheque accounts without a layout' : 'บัญชีเช็คที่ยังไม่มีแบบ'} ${missing.length}',
              on: _missing,
              onTap: () => setState(() => _missing = !_missing)),
        ],
      ),
      Expanded(
        child: _loading && _rows.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _missing
                ? (missing.isEmpty
                    ? Center(child: Text(e ? 'Every cheque account has a layout' : 'บัญชีเช็คทุกบัญชีมีแบบพิมพ์แล้ว', style: const TextStyle(color: ImKit.ink2)))
                    : ListView(padding: const EdgeInsets.only(top: 2, bottom: 12), children: [
                        for (final a in missing)
                          ImMasterListCard(
                            code: a.accountCode,
                            chips: [ImKit.chip(e ? 'No layout' : 'ยังไม่มีแบบ', ImKit.goldSoft, ImKit.amber)],
                            name: a.name(e),
                            meta: TextSpan(text: widget.onAddFor == null ? '' : (e ? 'Tap to add a layout for this account' : 'กดเพื่อเพิ่มแบบพิมพ์ของบัญชีนี้')),
                            selected: false,
                            onTap: () => widget.onAddFor?.call(a),
                          ),
                      ]))
                : shown.isEmpty
                    ? Center(child: Text(e ? 'No print layouts yet' : 'ยังไม่มีแบบพิมพ์เช็ค', style: const TextStyle(color: ImKit.ink2)))
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 2, bottom: 12),
                        itemCount: shown.length,
                        itemBuilder: (_, i) {
                          final c = shown[i];
                          final f = NumberFormat('#,##0.##');
                          return ImMasterListCard(
                            code: c.bankAccountCode ?? '',
                            chips: [if (c.isDefault) ImKit.chip(e ? 'Default' : 'แบบหลัก', ImKit.okSoft, ImKit.ok)],
                            name: c.configName,
                            meta: TextSpan(
                                text: '${f.format(c.paperWidthMm)} × ${f.format(c.paperHeightMm)} ${e ? 'mm' : 'มม.'} · '
                                    '${c.hasStub ? (e ? 'stub ${f.format(c.stubWidthMm ?? 0)} mm' : 'ต้นขั้ว ${f.format(c.stubWidthMm ?? 0)} มม.') : (e ? 'no stub' : 'ไม่มีต้นขั้ว')}'),
                            selected: widget.selectedId != null && widget.selectedId == c.id,
                            onTap: () => widget.onTap(c),
                          );
                        },
                      ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// รายละเอียดแบบพิมพ์ (แผงขวา)
// ---------------------------------------------------------------------------
class _ConfigDetail extends StatefulWidget {
  final Mode mode;
  final CmCheckPrintConfig? selected;
  final CmCheckPrintConfig? template;
  final int requestSeq;
  final Future<void> Function(CmCheckPrintConfig) onSubmit;
  final VoidCallback onCancel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onCopy;
  final bool canPrint;
  const _ConfigDetail({
    super.key,
    required this.mode,
    this.selected,
    this.template,
    required this.requestSeq,
    required this.onSubmit,
    required this.onCancel,
    this.onEdit,
    this.onDelete,
    this.onCopy,
    required this.canPrint,
  });

  @override
  State<_ConfigDetail> createState() => _ConfigDetailState();
}

class _ConfigDetailState extends State<_ConfigDetail> with ImMasterKit {
  bool _isEnglish = false;

  @override
  bool get kitEnglish => _isEnglish;
  @override
  bool get kitReadOnly => widget.mode == Mode.view;

  final _nameCtrl = TextEditingController();
  final _wCtrl = TextEditingController();
  final _hCtrl = TextEditingController();
  final _stubCtrl = TextEditingController();
  final _dateXCtrl = TextEditingController();
  final _dateYCtrl = TextEditingController();
  final _payeeXCtrl = TextEditingController();
  final _payeeYCtrl = TextEditingController();
  final _numXCtrl = TextEditingController();
  final _numYCtrl = TextEditingController();
  final _txtXCtrl = TextEditingController();
  final _txtYCtrl = TextEditingController();
  String _dateFormat = 'dd/MM/yyyy';
  bool _hasStub = false;
  bool _isDefault = false;
  int? _bankId;
  List<CmBankAccount> _accounts = [];
  bool _saving = false;
  String _snapshot = '';

  static const _dateFormats = ['dd/MM/yyyy', 'dd-MM-yyyy', 'dd.MM.yyyy', 'ddMMyyyy', 'd MMM yyyy', 'yyyy-MM-dd'];
  static final _n2 = NumberFormat('0.##');

  bool get isDirty => !kitReadOnly && widget.mode != Mode.none && _fingerprint() != _snapshot;

  List<TextEditingController> get _ctrls =>
      [_nameCtrl, _wCtrl, _hCtrl, _stubCtrl, _dateXCtrl, _dateYCtrl, _payeeXCtrl, _payeeYCtrl, _numXCtrl, _numYCtrl, _txtXCtrl, _txtYCtrl];

  @override
  void initState() {
    super.initState();
    _applyCurrent();
    _loadAccounts();
  }

  @override
  void didUpdateWidget(covariant _ConfigDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.requestSeq != oldWidget.requestSeq || widget.selected != oldWidget.selected || widget.mode != oldWidget.mode) {
      _applyCurrent();
      kScrollTop();
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      final a = await CmBankAccountService().fetchRows();
      if (mounted) {
        setState(() => _accounts = a.where((x) => x.cmType == 'BANK' && (x.isActive || x.id == _bankId)).toList()
          ..sort((x, y) => x.accountCode.compareTo(y.accountCode)));
      }
    } catch (_) {}
  }

  void _applyCurrent() {
    final copy = widget.mode == Mode.add && widget.template != null && widget.template!.id != null;
    final d = widget.mode == Mode.add ? widget.template : widget.selected;
    String v(double? x, double def) => _n2.format(x ?? def);
    _nameCtrl.text = copy ? '${d!.configName} (${_isEnglish ? 'copy' : 'สำเนา'})' : (d?.configName ?? '');
    _wCtrl.text = v(d?.paperWidthMm, 210);
    _hCtrl.text = v(d?.paperHeightMm, 99);
    _stubCtrl.text = v(d?.stubWidthMm, 50);
    _dateXCtrl.text = v(d?.dateX, 150);
    _dateYCtrl.text = v(d?.dateY, 18);
    _payeeXCtrl.text = v(d?.payeeX, 35);
    _payeeYCtrl.text = v(d?.payeeY, 38);
    _numXCtrl.text = v(d?.amountNumX, 155);
    _numYCtrl.text = v(d?.amountNumY, 38);
    _txtXCtrl.text = v(d?.amountTextX, 20);
    _txtYCtrl.text = v(d?.amountTextY, 55);
    _dateFormat = d?.dateFormat ?? 'dd/MM/yyyy';
    _hasStub = d?.hasStub ?? false;
    _isDefault = copy ? false : (d?.isDefault ?? false);
    _bankId = d?.bankAccountId;
    _snapshot = widget.mode == Mode.add ? '' : _fingerprint();
  }

  double _num(TextEditingController c, double def) => double.tryParse(c.text.trim()) ?? def;

  CmCheckPrintConfig _build() => CmCheckPrintConfig(
        id: widget.mode == Mode.add ? null : widget.selected?.id,
        bankAccountId: _bankId ?? 0,
        configName: _nameCtrl.text.trim(),
        paperWidthMm: _num(_wCtrl, 210),
        paperHeightMm: _num(_hCtrl, 99),
        dateX: _num(_dateXCtrl, 150),
        dateY: _num(_dateYCtrl, 18),
        dateFormat: _dateFormat,
        payeeX: _num(_payeeXCtrl, 35),
        payeeY: _num(_payeeYCtrl, 38),
        amountNumX: _num(_numXCtrl, 155),
        amountNumY: _num(_numYCtrl, 38),
        amountTextX: _num(_txtXCtrl, 20),
        amountTextY: _num(_txtYCtrl, 55),
        hasStub: _hasStub,
        stubWidthMm: _num(_stubCtrl, 50),
        isDefault: _isDefault,
      );

  String _fingerprint() {
    try {
      return jsonEncode(_build().toJson());
    } catch (_) {
      return '';
    }
  }

  Future<void> _submit() async {
    final e = _isEnglish;
    String? err;
    final w = _num(_wCtrl, 0), h = _num(_hCtrl, 0);
    if (_bankId == null) {
      err = e ? 'Please choose the bank account' : 'โปรดเลือกบัญชีธนาคาร';
    } else if (_nameCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter the layout name' : 'โปรดระบุชื่อแบบพิมพ์';
    } else if (w <= 0 || h <= 0) {
      err = e ? 'Paper width and height must be greater than 0' : 'ความกว้างและความสูงของกระดาษต้องมากกว่า 0';
    }
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSubmit(_build());
    } catch (ex) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ? 'An error occurred: $ex' : 'เกิดข้อผิดพลาด: $ex'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ข้อมูลตัวอย่างของภาพตัวอย่างและพิมพ์ทดสอบ
  static const _samplePayee = 'บริษัท ตัวอย่างการค้า จำกัด';
  static const _sampleAmount = 96400.0;

  Future<void> _testPrint() async {
    final e = _isEnglish;
    try {
      final cfg = _build().toJson();
      final bytes = await buildCheckPdf([
        {'payee_name_th': _samplePayee, 'amount_lc': _sampleAmount, 'check_date': formatLocalDate(DateTime.now())},
      ], cfg);
      if (!mounted) return;
      await printPdfWithTarget(context, 'cm_check_print', bytes, isEnglish: e, name: 'check_test', defaultPaper: 'DOC');
    } catch (ex) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${e ? 'Print failed' : 'พิมพ์ไม่สำเร็จ'}: $ex'), backgroundColor: Colors.red));
    }
  }

  Widget _preview() {
    final e = _isEnglish;
    final w = _num(_wCtrl, 210).clamp(20, 600).toDouble();
    final h = _num(_hCtrl, 99).clamp(20, 400).toDouble();
    String date;
    try {
      date = DateFormat(_dateFormat).format(DateTime.now());
    } catch (_) {
      date = DateFormat('dd/MM/yyyy').format(DateTime.now());
    }
    final items = [
      _PItem(_num(_dateXCtrl, 150), _num(_dateYCtrl, 18), date, 11, true),
      _PItem(_num(_payeeXCtrl, 35), _num(_payeeYCtrl, 38), _samplePayee, 12, true),
      _PItem(_num(_numXCtrl, 155), _num(_numYCtrl, 38), NumberFormat('#,##0.00', 'en_US').format(_sampleAmount), 12, true),
      _PItem(_num(_txtXCtrl, 20), _num(_txtYCtrl, 55), thaiAmountToWords(_sampleAmount), 11, false),
    ];
    return kCard(
      title: e ? 'Cheque preview' : 'ภาพตัวอย่างเช็ค',
      count: e ? 'To paper scale · sample data · red dot = X, Y in mm from the top-left' : 'ตามสเกลกระดาษ · ข้อมูลตัวอย่าง · จุดแดง = ตำแหน่ง X, Y (มม. จากมุมซ้ายบน)',
      trailing: widget.canPrint ? kGhost(e ? 'Test print' : 'พิมพ์ทดสอบ', Icons.print_outlined, _testPrint) : null,
      child: LayoutBuilder(builder: (c, cons) {
        final maxW = cons.maxWidth.clamp(200, 760).toDouble();
        final scale = maxW / w;
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: w * scale,
            height: h * scale,
            decoration: BoxDecoration(
              color: const Color(0xFFFBFAF4),
              border: Border.all(color: ImKit.line),
              borderRadius: BorderRadius.circular(4),
            ),
            child: CustomPaint(painter: _ChequePainter(items: items, scale: scale, stubMm: _hasStub ? _num(_stubCtrl, 50) : null)),
          ),
        );
      }),
    );
  }

  List<DropdownMenuItem<String>> _formatItems() {
    final list = {..._dateFormats, _dateFormat};
    return [
      for (final f in list)
        DropdownMenuItem(
          value: f,
          child: Text(() {
            try {
              return '$f  (${DateFormat(f).format(DateTime.now())})';
            } catch (_) {
              return f;
            }
          }(), overflow: TextOverflow.ellipsis),
        ),
    ];
  }

  Widget _xy(String label, TextEditingController x, TextEditingController y) => kRow([
        kTxt('$label X', x, numeric: true),
        kTxt('$label Y', y, numeric: true),
      ]);

  Widget _settingsCard() {
    final e = _isEnglish;
    final ro = kitReadOnly;
    final bankItems = [
      for (final a in _accounts) DropdownMenuItem(value: a.id, child: Text('${a.accountCode} ${a.name(e)}', overflow: TextOverflow.ellipsis)),
      if (_bankId != null && !_accounts.any((a) => a.id == _bankId))
        DropdownMenuItem(value: _bankId, child: Text(widget.selected?.bankAccountCode ?? '$_bankId')),
    ];
    return kCard(
      title: e ? 'Layout settings' : 'ตั้งค่าแบบพิมพ์',
      trailing: kLegend(withAuto: false),
      child: kGroups([
        kGroup(1, e ? 'Layout and paper' : 'แบบพิมพ์และกระดาษ', ImKit.gDoc, [
          kDd<int>(e ? 'Bank account *' : 'บัญชีธนาคาร *', _bankId, bankItems, ro ? null : (v) => setState(() => _bankId = v), auto: false),
          kTxt(e ? 'Layout name *' : 'ชื่อแบบพิมพ์ *', _nameCtrl),
          kRow([
            kTxt(e ? 'Width (mm)' : 'กว้าง (มม.)', _wCtrl, numeric: true),
            kTxt(e ? 'Height (mm)' : 'สูง (มม.)', _hCtrl, numeric: true),
          ]),
          kRow([
            kChecks([kCk(e ? 'Has stub' : 'มีต้นขั้ว', _hasStub, ro ? null : (v) => setState(() => _hasStub = v))]),
            kTxt(e ? 'Stub width (mm)' : 'กว้างต้นขั้ว (มม.)', _stubCtrl, numeric: true, editable: !ro && _hasStub),
          ]),
          kChecks([kCk(e ? 'Default layout of this account' : 'เป็นแบบหลักของบัญชีนี้', _isDefault, ro ? null : (v) => setState(() => _isDefault = v))]),
          kNote(e
              ? 'Only one default per account — saving a default clears the others. The stub width is not used when printing yet.'
              : 'หนึ่งบัญชีมีแบบหลักได้แบบเดียว บันทึกเป็นแบบหลักแล้วแบบอื่นของบัญชีนี้จะไม่เป็นแบบหลัก · ค่าต้นขั้วยังไม่ถูกใช้ตอนพิมพ์'),
        ]),
        kGroup(2, e ? 'Positions (X, Y mm)' : 'ตำแหน่ง (X, Y มม.)', ImKit.gFin, [
          _xy(e ? 'Date' : 'วันที่', _dateXCtrl, _dateYCtrl),
          kDd<String>(e ? 'Date format' : 'รูปแบบวันที่', _dateFormat, _formatItems(), ro ? null : (v) => setState(() => _dateFormat = v ?? 'dd/MM/yyyy'), auto: false),
          _xy(e ? 'Payee' : 'ชื่อผู้รับเงิน', _payeeXCtrl, _payeeYCtrl),
          _xy(e ? 'Amount (figures)' : 'จำนวนเงิน (ตัวเลข)', _numXCtrl, _numYCtrl),
          _xy(e ? 'Amount (words)' : 'จำนวนเงิน (ตัวอักษร)', _txtXCtrl, _txtYCtrl),
          kNote(e ? 'The year prints in the Christian era (e.g. 2026)' : 'ปีพิมพ์เป็น ค.ศ. (เช่น 2026)'),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final e = isEnglish;
    if (widget.mode == Mode.none) {
      return kPlaceholder(Icons.print_outlined, e ? 'Select a layout on the left, or press "Add layout"' : 'เลือกแบบพิมพ์จากรายการด้านซ้าย หรือกด "เพิ่มแบบพิมพ์"');
    }
    final ro = kitReadOnly;
    final isAdd = widget.mode == Mode.add;
    final acc = _accounts.where((a) => a.id == _bankId).firstOrNull;
    return kPage(
      header: kHeaderBar(
        title: isAdd ? (e ? 'New print layout' : 'แบบพิมพ์เช็คใหม่') : _nameCtrl.text.trim(),
        badges: [
          if (_isDefault) ImKit.chip(e ? 'Default' : 'แบบหลัก', ImKit.okSoft, ImKit.ok),
          if (acc != null) Text('${acc.accountCode} ${acc.name(e)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          if (!ro) kEditingBadge(),
        ],
        busy: _saving,
        acts: kStdActs(
          saving: _saving,
          onEdit: widget.onEdit,
          onDelete: widget.onDelete,
          onClose: widget.onCancel,
          onCancel: widget.onCancel,
          onSave: _submit,
          extra: [if (widget.onCopy != null) DocBarAction(e ? 'Copy as new' : 'สำเนาเป็นแบบใหม่', widget.onCopy, fg: kInk)],
        ),
      ),
      sections: [
        (0, e ? 'Preview' : 'ภาพตัวอย่าง', _preview()),
        (1, e ? 'Settings' : 'ตั้งค่า', _settingsCard()),
      ],
    );
  }
}

class _PItem {
  final double x, y, pt;
  final String text;
  final bool bold;
  const _PItem(this.x, this.y, this.text, this.pt, this.bold);
}

// ภาพเช็คตามสเกล: 1 มม. = scale px; ขนาดอักษร pt → มม. (1pt = 0.3528 มม.)
class _ChequePainter extends CustomPainter {
  final List<_PItem> items;
  final double scale;
  final double? stubMm;
  _ChequePainter({required this.items, required this.scale, this.stubMm});

  @override
  void paint(Canvas canvas, Size size) {
    if (stubMm != null && stubMm! > 0) {
      final x = stubMm! * scale;
      final p = Paint()
        ..color = const Color(0xFFC9D1CC)
        ..strokeWidth = 1;
      for (double y = 0; y < size.height; y += 6) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 3), p);
      }
    }
    for (final it in items) {
      final o = Offset(it.x * scale, it.y * scale);
      final tp = TextPainter(
        text: TextSpan(
          text: it.text,
          style: TextStyle(
            fontFamily: 'THSarabun',
            fontSize: it.pt * 0.3528 * scale * 1.0,
            fontWeight: it.bold ? FontWeight.bold : FontWeight.normal,
            color: const Color(0xFF1E4F8F),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, o);
      canvas.drawCircle(o, 3, Paint()..color = const Color(0xFFC0392B));
    }
  }

  @override
  bool shouldRepaint(covariant _ChequePainter old) => true;
}
