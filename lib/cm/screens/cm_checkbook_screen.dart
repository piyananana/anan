// lib/cm/screens/cm_checkbook_screen.dart — สมุดเช็ค แบบ B ของ IM (user 2026-11-28)
//   ซ้าย: เฉพาะบัญชีที่ใช้ออก/รับเช็ค (เล่มที่ใช้งาน เช็คคงเหลือ) + ตัวกรองใกล้หมด/ไม่มีเล่ม
//   ขวา: ตัวเลขสรุป + ตารางสมุดเช็ค (แถบการใช้) + เล่มที่เลือก (โหมดดู → แก้ไข) + เช็คที่ออกจากเล่ม 10 ใบล่าสุด
//   ตำแหน่งพิมพ์เช็คย้ายไปหน้า "สร้างแบบพิมพ์เช็ค" (CmCheckPrintConfigScreen)
//   ระบบออกเลขเช็คจากเล่มตอน Post ใบจ่าย (utils/cmCheckbook.js) — backend ห้ามช่วงเลขซ้อน และห้ามแก้ช่วงเลขเมื่อมีเช็คออกแล้ว
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../im/widgets/im_master_kit.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../models/cm_bank_account.dart';
import '../models/cm_checkbook.dart';
import '../models/cm_master_summary.dart';
import '../services/cm_bank_account_service.dart';
import '../services/cm_checkbook_service.dart';

const int _kLowCheques = 10; // เช็คคงเหลือต่ำกว่านี้ = ใกล้หมด

class CmCheckbookScreen extends StatefulWidget {
  const CmCheckbookScreen({super.key});

  @override
  State<CmCheckbookScreen> createState() => _CmCheckbookScreenState();
}

class _CmCheckbookScreenState extends State<CmCheckbookScreen> with AutomaticKeepAliveClientMixin {
  final GlobalKey<_AccountListState> _listKey = GlobalKey();
  final GlobalKey<_CheckbookPanelState> _panelKey = GlobalKey();
  CmBankAccount? _selected;
  int _requestSeq = 0;
  bool _isEnglish = false;

  @override
  bool get wantKeepAlive => true;

  Future<bool> _confirmLeave() async {
    final p = _panelKey.currentState;
    if (p != null && p.isDirty) return confirmDiscardChanges(context, _isEnglish);
    return true;
  }

  Future<void> _onSelect(CmBankAccount a) async {
    if (_selected?.id == a.id) return;
    if (!await _confirmLeave()) return;
    setState(() {
      _selected = a;
      _requestSeq++;
    });
  }

  Future<void> _close() async {
    if (!await _confirmLeave()) return;
    setState(() {
      _selected = null;
      _requestSeq++;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final perm = MenuScope.of(context);
    return ImMasterShell(
      isEnglish: isEnglish,
      initialListWidth: 320,
      barActions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: isEnglish ? 'Refresh' : 'รีเฟรชรายการ',
          onPressed: () async {
            if (!await _confirmLeave()) return;
            await _listKey.currentState?.refresh();
            setState(() => _requestSeq++);
          },
        ),
      ],
      list: _AccountList(key: _listKey, selectedId: _selected?.id, onTap: _onSelect),
      detail: _CheckbookPanel(
        key: _panelKey,
        account: _selected,
        requestSeq: _requestSeq,
        canCreate: perm?.canCreate ?? true,
        canEdit: perm?.canEdit ?? true,
        canDelete: perm?.canDelete ?? true,
        onClose: _close,
        onChanged: () => _listKey.currentState?.refresh(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// รายการบัญชีที่ใช้เช็ค (แผงซ้าย)
// ---------------------------------------------------------------------------
class _AccountList extends StatefulWidget {
  final int? selectedId;
  final ValueChanged<CmBankAccount> onTap;
  const _AccountList({super.key, required this.selectedId, required this.onTap});

  @override
  State<_AccountList> createState() => _AccountListState();
}

enum _AFlag { low, noBook }

class _AccountListState extends State<_AccountList> {
  final _search = TextEditingController();
  List<CmBankAccount> _rows = [];
  Map<int, CmBankBalance> _bal = {};
  _AFlag? _flag;
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

  Future<void> refresh() async {
    setState(() => _loading = true);
    final svc = CmBankAccountService();
    try {
      final rows = await svc.fetchRows();
      if (mounted) setState(() => _rows = rows.where((a) => a.isCheckAccount && a.cmType == 'BANK').toList());
    } catch (ex) {
      if (mounted) {
        final en = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(en ? 'Failed to load data: $ex' : 'ไม่สามารถโหลดข้อมูลได้: $ex')));
      }
    }
    try {
      final b = await svc.fetchBalances();
      if (mounted) setState(() => _bal = b);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  bool _ok(CmBankAccount a, _AFlag? f) {
    final b = _bal[a.id];
    return switch (f) {
      null => true,
      _AFlag.low => b != null && b.activeBooks > 0 && (b.checksLeft ?? 99) < _kLowCheques,
      _AFlag.noBook => b == null || b.activeBooks == 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final e = context.watch<LanguageProvider>().isEnglish;
    final q = _search.text.trim().toLowerCase();
    final base = _rows
        .where((a) =>
            q.isEmpty ||
            a.accountCode.toLowerCase().contains(q) ||
            a.accountNameTh.toLowerCase().contains(q) ||
            (a.accountNameEn ?? '').toLowerCase().contains(q) ||
            (a.accountNumber ?? '').contains(q) ||
            a.bankDisplay.toLowerCase().contains(q))
        .toList();
    final shown = base.where((a) => _ok(a, _flag)).toList()..sort((a, b) => a.accountCode.compareTo(b.accountCode));
    int n(_AFlag f) => base.where((a) => _ok(a, f)).length;
    void flag(_AFlag f) => setState(() => _flag = _flag == f ? null : f);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ImMasterListHeader(
        searchCtrl: _search,
        hint: e ? 'Search bank account' : 'ค้นหา บัญชีธนาคาร',
        onSearch: (_) => setState(() {}),
        countText: _loading
            ? (e ? 'Loading...' : 'กำลังโหลด...')
            : (e ? '${shown.length} cheque account(s)' : 'บัญชีที่ใช้เช็ค ${shown.length} บัญชี'),
        filters: [
          ImMasterFilterChip(label: e ? 'All' : 'ทั้งหมด', on: _flag == null, onTap: () => setState(() => _flag = null)),
          ImMasterFilterChip(label: '${e ? 'Running low' : 'เช็คใกล้หมด'} ${n(_AFlag.low)}', on: _flag == _AFlag.low, onTap: () => flag(_AFlag.low)),
          ImMasterFilterChip(label: '${e ? 'No active book' : 'ไม่มีเล่มที่ใช้งาน'} ${n(_AFlag.noBook)}', on: _flag == _AFlag.noBook, onTap: () => flag(_AFlag.noBook)),
        ],
      ),
      Expanded(
        child: _loading && _rows.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : shown.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                        child: Text(
                            _rows.isEmpty
                                ? (e
                                    ? 'No bank account issues cheques yet — tick "Issue / receive cheques" on the bank account screen'
                                    : 'ยังไม่มีบัญชีที่ใช้เช็ค — ติ๊ก "ใช้ออก/รับเช็ค" ที่หน้าเลขที่บัญชีธนาคาร')
                                : (e ? 'No accounts found' : 'ไม่พบบัญชี'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: ImKit.ink2))))
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 2, bottom: 12),
                    itemCount: shown.length,
                    itemBuilder: (_, i) {
                      final a = shown[i];
                      final b = _bal[a.id];
                      final books = b?.activeBooks ?? 0;
                      final left = b?.checksLeft ?? 0;
                      return ImMasterListCard(
                        code: a.accountCode,
                        chips: [
                          if (a.bankDisplay.isNotEmpty) ImKit.chip(a.bankCode ?? a.bankDisplay, ImKit.blueSoft, ImKit.blue),
                          if (books == 0)
                            ImKit.chip(e ? 'No book' : 'ไม่มีเล่ม', ImKit.redSoft, ImKit.red)
                          else if (left < _kLowCheques)
                            ImKit.chip(e ? 'Low' : 'ใกล้หมด', ImKit.goldSoft, ImKit.amber),
                          if (!a.isActive) ImKit.chip(e ? 'Inactive' : 'หยุดใช้', ImKit.ro, ImKit.ink2),
                        ],
                        name: a.name(e),
                        meta: TextSpan(
                            text: books == 0
                                ? (e ? 'No active chequebook' : 'ยังไม่มีสมุดเช็คที่ใช้งาน')
                                : (e ? '$books active book(s) · $left cheque(s) left' : 'ใช้งาน $books เล่ม · คงเหลือ $left ใบ')),
                        selected: widget.selectedId != null && widget.selectedId == a.id,
                        active: a.isActive,
                        onTap: () => widget.onTap(a),
                      );
                    },
                  ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// แผงขวา: สมุดเช็คของบัญชีที่เลือก
// ---------------------------------------------------------------------------
enum _BookMode { none, view, edit, add }

class _CheckbookPanel extends StatefulWidget {
  final CmBankAccount? account;
  final int requestSeq;
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onClose;
  final VoidCallback onChanged;
  const _CheckbookPanel({
    super.key,
    required this.account,
    required this.requestSeq,
    required this.canCreate,
    required this.canEdit,
    required this.canDelete,
    required this.onClose,
    required this.onChanged,
  });

  @override
  State<_CheckbookPanel> createState() => _CheckbookPanelState();
}

class _CheckbookPanelState extends State<_CheckbookPanel> with ImMasterKit {
  bool _isEnglish = false;
  _BookMode _mode = _BookMode.none;
  int? _bookId;

  @override
  bool get kitEnglish => _isEnglish;
  @override
  bool get kitReadOnly => _mode == _BookMode.view || _mode == _BookMode.none;

  final _svc = CmCheckbookService();
  CmCheckbookAccountSummary? _summary;
  bool _loading = false;
  List<CmBookCheck> _checks = [];
  bool _checksLoading = false;
  bool _showClosed = false;
  bool _saving = false;

  final _codeCtrl = TextEditingController();
  final _startCtrl = TextEditingController();
  final _endCtrl = TextEditingController();
  final _nextCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime? _receivedDate;
  String _status = 'Active';
  String _snapshot = '';

  static final _money = NumberFormat('#,##0.00');
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  bool get isDirty => (_mode == _BookMode.edit || _mode == _BookMode.add) && _fingerprint() != _snapshot;
  CmBookInfo? get _book => _summary?.books.where((b) => b.id == _bookId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _CheckbookPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.requestSeq != oldWidget.requestSeq || widget.account?.id != oldWidget.account?.id) {
      final same = widget.account?.id == oldWidget.account?.id;
      _mode = _BookMode.none;
      if (!same) {
        _bookId = null;
        _summary = null;
        _checks = [];
      }
      _load(keepBook: same);
      kScrollTop();
    }
  }

  @override
  void dispose() {
    for (final c in [_codeCtrl, _startCtrl, _endCtrl, _nextCtrl, _noteCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load({bool keepBook = false}) async {
    final id = widget.account?.id;
    if (id == null) return;
    setState(() => _loading = true);
    try {
      final s = await _svc.fetchAccountSummary(id);
      if (!mounted || widget.account?.id != id) return;
      setState(() => _summary = s);
      // เลือกเล่มเดิม หรือเล่มที่ใช้งานเล่มแรก
      final keep = keepBook && s.books.any((b) => b.id == _bookId);
      final first = s.books.where((b) => b.status == 'Active').firstOrNull ?? s.books.firstOrNull;
      _selectBook(keep ? _bookId : first?.id);
    } catch (ex) {
      if (mounted) setState(() => _summary = null);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _selectBook(int? id) {
    setState(() {
      _bookId = id;
      _mode = id == null ? _BookMode.none : _BookMode.view;
    });
    _applyBook(_book);
    _loadChecks();
  }

  Future<void> _loadChecks() async {
    final id = _bookId;
    if (id == null) {
      setState(() => _checks = []);
      return;
    }
    setState(() => _checksLoading = true);
    try {
      final c = await _svc.fetchBookChecks(id);
      if (mounted && _bookId == id) setState(() => _checks = c);
    } catch (_) {
      if (mounted && _bookId == id) setState(() => _checks = []);
    }
    if (mounted) setState(() => _checksLoading = false);
  }

  void _applyBook(CmBookInfo? b) {
    _codeCtrl.text = b?.code ?? '';
    _startCtrl.text = b?.startNo ?? '';
    _endCtrl.text = b?.endNo ?? '';
    _nextCtrl.text = b?.nextNo ?? '';
    _noteCtrl.text = b?.note ?? '';
    _receivedDate = b?.receivedDate;
    _status = b?.status ?? 'Active';
    _snapshot = _fingerprint();
  }

  CmCheckbook _build() => CmCheckbook(
        id: _mode == _BookMode.add ? null : _bookId,
        bankAccountId: widget.account?.id ?? 0,
        checkbookCode: _codeCtrl.text.trim(),
        startCheckNo: _startCtrl.text.trim(),
        endCheckNo: _endCtrl.text.trim(),
        nextCheckNo: _nextCtrl.text.trim().isEmpty ? null : _nextCtrl.text.trim(),
        receivedDate: _receivedDate,
        status: _status,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );

  String _fingerprint() {
    try {
      return jsonEncode(_build().toJson());
    } catch (_) {
      return '';
    }
  }

  Future<bool> _confirmLeave() async {
    if (isDirty) return confirmDiscardChanges(context, _isEnglish);
    return true;
  }

  Future<void> _onTapBook(CmBookInfo b) async {
    if (_bookId == b.id && _mode == _BookMode.view) return;
    if (!await _confirmLeave()) return;
    _selectBook(b.id);
  }

  Future<void> _onAdd() async {
    if (!await _confirmLeave()) return;
    setState(() {
      _mode = _BookMode.add;
      _bookId = null;
      _checks = [];
    });
    _applyBook(null);
    _receivedDate = DateTime.now();
    _snapshot = _fingerprint();
    kScrollTop();
  }

  void _onEdit() => setState(() => _mode = _BookMode.edit);

  Future<void> _onCancel() async {
    if (!await _confirmLeave()) return;
    if (_mode == _BookMode.add) {
      final first = _summary?.books.where((b) => b.status == 'Active').firstOrNull ?? _summary?.books.firstOrNull;
      _selectBook(first?.id);
    } else {
      setState(() => _mode = _BookMode.view);
      _applyBook(_book);
    }
  }

  Future<void> _onSave() async {
    final e = _isEnglish;
    String? err;
    final st = _startCtrl.text.trim();
    final en = _endCtrl.text.trim();
    if (_codeCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter the book code' : 'โปรดระบุรหัสเล่ม';
    } else if (st.isEmpty || en.isEmpty) {
      err = e ? 'Please enter the first and last cheque numbers' : 'โปรดระบุเลขที่เริ่มและเลขที่สุดท้าย';
    } else if (RegExp(r'^\d+$').hasMatch(st) && RegExp(r'^\d+$').hasMatch(en) && BigInt.parse(st) > BigInt.parse(en)) {
      err = e ? 'The first number must not be greater than the last' : 'เลขที่เริ่มต้องไม่มากกว่าเลขที่สุดท้าย';
    }
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
      return;
    }
    setState(() => _saving = true);
    try {
      final row = _build();
      final saved = _mode == _BookMode.add ? await _svc.addCheckbook(row) : await _svc.updateCheckbook(row);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ? 'Saved successfully' : 'บันทึกสำเร็จ')));
      _bookId = saved.id;
      _mode = _BookMode.view;
      widget.onChanged();
      await _load(keepBook: true);
    } catch (ex) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${e ? 'Save failed' : 'บันทึกไม่สำเร็จ'}: ${ex.toString().replaceFirst('Exception: ', '')}'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onDelete() async {
    final b = _book;
    if (b == null) return;
    final e = _isEnglish;
    final l = AppL10n(e);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.confirmDelete),
        content: Text(e ? 'Delete chequebook "${b.code}" (${b.startNo}–${b.endNo})?' : 'ลบสมุดเช็ค "${b.code}" (${b.startNo}–${b.endNo}) ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.delete, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.deleteCheckbook(b.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ? 'Deleted successfully' : 'ลบสำเร็จ')));
      _bookId = null;
      widget.onChanged();
      await _load();
    } catch (ex) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${e ? 'Delete failed' : 'ลบไม่สำเร็จ'}: ${ex.toString().replaceFirst('Exception: ', '')}'), backgroundColor: Colors.red));
      }
    }
  }

  // ─── ส่วนแสดงผล ─────────────────────────────────────────────────────────────
  Widget _statusChip(String st, bool e) => switch (st) {
        'Active' => ImKit.chip(e ? 'Active' : 'ใช้งาน', ImKit.okSoft, ImKit.ok),
        'Used' => ImKit.chip(e ? 'Used up' : 'ใช้หมดแล้ว', ImKit.ro, ImKit.ink2),
        'Cancelled' => ImKit.chip(e ? 'Cancelled' : 'ยกเลิก', ImKit.redSoft, ImKit.red),
        _ => ImKit.chip(st, ImKit.ro, ImKit.ink2),
      };

  Widget _usage(CmBookInfo b) {
    final size = b.size ?? 0;
    final used = b.used ?? 0;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 60,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: size == 0 ? 0 : (used / size).clamp(0, 1).toDouble(),
            minHeight: 6,
            backgroundColor: const Color(0xFFE6EBE8),
            color: kInk,
          ),
        ),
      ),
      const SizedBox(width: 6),
      Text(size == 0 ? '' : '$used/$size', style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()])),
    ]);
  }

  Widget _booksCard() {
    final e = _isEnglish;
    final all = _summary?.books ?? const <CmBookInfo>[];
    final closed = all.where((b) => b.status != 'Active').length;
    final books = _showClosed ? all : all.where((b) => b.status == 'Active' || b.id == _bookId).toList();
    return kCard(
      title: e ? 'Chequebooks (${all.length})' : 'สมุดเช็ค (${all.length})',
      count: e ? 'Tap a row to view the book' : 'กดที่แถวเพื่อดู/แก้ไขเล่ม',
      trailing: closed == 0
          ? null
          : kGhost(
              _showClosed
                  ? (e ? 'Hide used / cancelled' : 'ซ่อนเล่มที่ใช้หมด/ยกเลิก')
                  : (e ? 'Show used / cancelled ($closed)' : 'แสดงเล่มที่ใช้หมด/ยกเลิก ($closed)'),
              _showClosed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              () => setState(() => _showClosed = !_showClosed)),
      padding: EdgeInsets.zero,
      child: kTable(
        [
          KCol(e ? 'Book' : 'เล่ม', 4),
          KCol(e ? 'Numbers' : 'เลขที่', 5),
          KCol(e ? 'Next' : 'ถัดไป', 3),
          KCol(e ? 'Usage' : 'การใช้', 4),
          KCol(e ? 'Left' : 'คงเหลือ', 2, num: true),
          KCol(e ? 'Received' : 'วันที่รับ', 3),
          KCol(e ? 'Status' : 'สถานะ', 3),
        ],
        [
          for (final b in books)
            [
              kCell(b.code, mono: true, bold: b.id == _bookId),
              kCell('${b.startNo}–${b.endNo}', mono: true),
              kCell(b.status == 'Active' ? (b.nextNo ?? '') : '', mono: true),
              _usage(b),
              kCell(b.remaining == null ? '' : '${b.remaining}',
                  mono: true, color: b.status == 'Active' && (b.remaining ?? 99) < _kLowCheques ? ImKit.amber : null),
              kCell(b.receivedDate == null ? '' : _dateFmt.format(b.receivedDate!), mono: true),
              _statusChip(b.status, e),
            ],
        ],
        onTap: [for (final b in books) () => _onTapBook(b)],
        rowColors: [for (final b in books) b.id == _bookId ? const Color(0xFFFFFCF2) : null],
        minWidth: 760,
        empty: e ? 'No chequebooks yet — press "Add chequebook"' : 'ยังไม่มีสมุดเช็ค — กด "เพิ่มสมุดเช็ค"',
      ),
    );
  }

  Widget _bookCard() {
    final e = _isEnglish;
    final ro = kitReadOnly;
    final b = _book;
    final isAdd = _mode == _BookMode.add;
    final locked = !isAdd && (b?.issuedCount ?? 0) > 0;
    final lockedByNext = !isAdd && b != null && (b.nextNo ?? b.startNo) != b.startNo;
    final rangeLocked = locked || lockedByNext;
    return kCard(
      title: isAdd ? (e ? 'New chequebook' : 'สมุดเช็คเล่มใหม่') : (e ? 'Book ${b?.code ?? ''}' : 'เล่ม ${b?.code ?? ''}'),
      count: isAdd
          ? null
          : ro
              ? (e ? 'View mode · press Edit to change' : 'โหมดดู · กดแก้ไขเพื่อเปลี่ยน')
              : (e ? 'Editing' : 'กำลังแก้ไข'),
      trailing: ro && b != null
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              if (widget.canDelete) kGhost(e ? 'Delete' : 'ลบ', Icons.delete_outline, _onDelete),
              if (widget.canEdit) kGhost(e ? 'Edit' : 'แก้ไข', Icons.edit_outlined, _onEdit),
            ])
          : null,
      child: kGroups([
        kGroup(1, e ? 'Chequebook' : 'เล่มเช็ค', ImKit.gDoc, [
          kRow([
            kTxt(e ? 'Book code *' : 'รหัสเล่ม *', _codeCtrl),
            kDate(e ? 'Received date' : 'วันที่รับ', _receivedDate, ro ? null : (d) => setState(() => _receivedDate = d)),
          ]),
          kRow([
            kTxt(e ? 'First number *' : 'เลขที่เริ่ม *', _startCtrl, editable: !ro && !rangeLocked, digitsOnly: true),
            kTxt(e ? 'Last number *' : 'เลขที่สุดท้าย *', _endCtrl, editable: !ro && !rangeLocked, digitsOnly: true),
          ]),
          kRow([
            kTxt(e ? 'Next number' : 'เลขที่ถัดไป', _nextCtrl, auto: true, digitsOnly: true),
            kDd<String>(e ? 'Status' : 'สถานะ', _status,
                [for (final k in cmCheckbookStatusOptions.keys) DropdownMenuItem(value: k, child: Text(cmCheckbookStatusLabel(k, e)))],
                ro ? null : (v) => setState(() => _status = v ?? 'Active'), auto: false),
          ]),
          kTxt(e ? 'Note' : 'หมายเหตุ', _noteCtrl),
          kNote(
              rangeLocked
                  ? (e
                      ? 'Cheques have been issued from this book — the first and last numbers cannot change'
                      : 'มีเช็คออกจากเล่มนี้แล้ว แก้เลขที่เริ่ม/สุดท้ายไม่ได้')
                  : (e
                      ? 'Numbers must not overlap another book of the same account · empty next number = first number'
                      : 'ช่วงเลขต้องไม่ซ้อนกับเล่มอื่นของบัญชีเดียวกัน · เลขที่ถัดไปว่าง = เลขที่เริ่ม'),
              color: rangeLocked ? ImKit.amber : ImKit.ink3),
          kNote(e
              ? 'The system takes the next number when a payment with this book is posted (CM 20/30, AP 60/80) and marks the book "Used up" past the last number'
              : 'ระบบใช้เลขถัดไปตอน Post ใบจ่ายที่เลือกเล่มนี้ (CM 20/30, AP 60/80) และเปลี่ยนเป็น "ใช้หมดแล้ว" เมื่อเกินเลขสุดท้าย'),
        ]),
      ]),
    );
  }

  Widget _checkStatus(String st, bool e) => switch (st) {
        'Pending' => ImKit.chip(e ? 'Not cleared' : 'ยังไม่ขึ้นเงิน', ImKit.goldSoft, ImKit.amber),
        'Cleared' => ImKit.chip(e ? 'Cleared' : 'ขึ้นเงินแล้ว', ImKit.okSoft, ImKit.ok),
        'Voided' => ImKit.chip(e ? 'Void' : 'ยกเลิก', ImKit.redSoft, ImKit.red),
        _ => ImKit.chip(st, ImKit.ro, ImKit.ink2),
      };

  Widget _checksCard() {
    final e = _isEnglish;
    return kCard(
      title: e ? 'Latest 10 cheques from this book' : 'เช็คที่ออกจากเล่มนี้ 10 ใบล่าสุด',
      count: e ? 'Read-only' : 'อ่านอย่างเดียว',
      trailing: kGhost(e ? 'Cheque register' : 'รายงานทะเบียนเช็ค', Icons.open_in_new,
          () => ImKit.openMenu(context, 'CmCheckReportScreen', 'รายงานทะเบียนเช็ค', 'Cheque Register Report', e)),
      padding: EdgeInsets.zero,
      child: _checksLoading && _checks.isEmpty
          ? const Padding(padding: EdgeInsets.all(14), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
          : kTable(
              [
                KCol(e ? 'Cheque no.' : 'เลขเช็ค', 3),
                KCol(e ? 'Cheque date' : 'วันที่เช็ค', 3),
                KCol(e ? 'Payee' : 'สั่งจ่าย', 6),
                KCol(e ? 'Document' : 'เอกสาร', 4),
                KCol(e ? 'Amount' : 'จำนวนเงิน', 3, num: true),
                KCol(e ? 'Status' : 'สถานะ', 3),
              ],
              [
                for (final c in _checks)
                  [
                    kCell(c.checkNo ?? '', mono: true),
                    kCell(c.checkDate == null ? (c.paymentDate == null ? '' : _dateFmt.format(c.paymentDate!)) : _dateFmt.format(c.checkDate!), mono: true),
                    kCell(c.payee ?? ''),
                    kCell(c.docNo ?? '', mono: true),
                    kCell(_money.format(c.amount), mono: true),
                    _checkStatus(c.status, e),
                  ],
              ],
              minWidth: 760,
              empty: e ? 'No cheques issued from this book yet' : 'ยังไม่มีเช็คออกจากเล่มนี้',
            ),
    );
  }

  Widget _kpis() {
    final e = _isEnglish;
    final s = _summary;
    if (s == null) return kKpis(const [], loading: _loading);
    return kKpis([
      ImKpi(e ? 'Cheques left' : 'เช็คคงเหลือ', e ? '${s.checksLeft}' : '${s.checksLeft} ใบ',
          e ? '${s.activeBooks} active book(s)' : '${s.activeBooks} เล่มที่ใช้งาน', warn: s.checksLeft < _kLowCheques),
      ImKpi(e ? 'Next number' : 'เลขที่ถัดไป', s.nextCheckNo ?? '—',
          s.nextCheckbookCode == null ? (e ? 'no active book' : 'ไม่มีเล่มที่ใช้งาน') : (e ? 'book ${s.nextCheckbookCode}' : 'เล่ม ${s.nextCheckbookCode}')),
      ImKpi(e ? 'Issued this month' : 'ออกเช็คเดือนนี้', e ? '${s.monthCount}' : '${s.monthCount} ใบ',
          e ? 'total ${_money.format(s.monthAmount)}' : 'รวม ${_money.format(s.monthAmount)}'),
      ImKpi(e ? 'Not yet cleared' : 'เช็คจ่ายยังไม่ขึ้นเงิน', e ? '${s.pendingCount}' : '${s.pendingCount} ใบ',
          e ? 'total ${_money.format(s.pendingAmount)}' : 'รวม ${_money.format(s.pendingAmount)}',
          onTap: () => ImKit.openMenu(context, 'CmCheckReportScreen', 'รายงานทะเบียนเช็ค', 'Cheque Register Report', e)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final e = isEnglish;
    final a = widget.account;
    if (a == null) {
      return kPlaceholder(Icons.menu_book_outlined,
          e ? 'Select a cheque account on the left' : 'เลือกบัญชีที่ใช้เช็คจากรายการด้านซ้าย');
    }
    final editing = _mode == _BookMode.edit || _mode == _BookMode.add;
    final acts = editing
        ? [
            DocBarAction(e ? 'Cancel' : 'ยกเลิก', _saving ? null : _onCancel, fg: kInk),
            DocBarAction(_saving ? (e ? 'Saving...' : 'กำลังบันทึก...') : (e ? 'Save' : 'บันทึก'), _saving ? null : _onSave,
                fg: Colors.white, bg: kInk, primary: true),
          ]
        : [
            DocBarAction(e ? 'Close' : 'ปิด', widget.onClose, fg: kInk),
            if (widget.canCreate) DocBarAction(e ? 'Add chequebook' : 'เพิ่มสมุดเช็ค', _onAdd, fg: Colors.white, bg: kInk, primary: true),
          ];
    return kPage(
      header: kHeaderBar(
        code: a.accountCode,
        title: a.name(e),
        badges: [
          if (a.bankDisplay.isNotEmpty) ImKit.chip(a.bankName(e).isEmpty ? a.bankDisplay : a.bankName(e), ImKit.blueSoft, ImKit.blue),
          if ((a.accountNumber ?? '').isNotEmpty) Text(a.accountNumber!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          if (editing) kEditingBadge(),
        ],
        busy: _saving,
        acts: acts,
      ),
      top: _kpis(),
      sections: [
        (0, e ? 'Chequebooks' : 'สมุดเช็ค', _booksCard()),
        if (_mode != _BookMode.none) (1, e ? 'Book' : 'เล่มที่เลือก', _bookCard()),
        if (_mode != _BookMode.none && _mode != _BookMode.add) (2, e ? 'Cheques' : 'เช็คที่ออกล่าสุด', _checksCard()),
      ],
    );
  }
}
