// lib/cm/screens/cm_bank_account_screen.dart — บัญชีธนาคาร/เงินสดย่อย แบบ B ของ IM (user 2026-11-28, เหมือนหน้าผู้ขาย AP)
//   ซ้าย: การ์ดบัญชี (ธนาคาร ประเภท สกุลเงิน ยอดคงเหลือ) + ตัวกรอง / ขวา: เปิดเป็นโหมดดู → แก้ไข / สำเนา / ลบ ที่แถบหัว
//   ปุ่มย่อ/ขยายรายการอยู่หน้าชื่อบนแถบหัวแผงขวา (ImListToggle ผ่าน ImMasterShell)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../im/widgets/im_master_kit.dart';
import '../../cd/services/cd_currency_service.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../models/cm_bank_account.dart';
import '../models/cm_master_summary.dart';
import '../services/cm_bank_account_service.dart';
import '../widgets/cm_bank_account_detail_widget.dart';

class CmBankAccountScreen extends StatefulWidget {
  final VoidCallback? onFieldsChanged;
  const CmBankAccountScreen({super.key, this.onFieldsChanged});

  @override
  State<CmBankAccountScreen> createState() => _CmBankAccountScreenState();
}

class _CmBankAccountScreenState extends State<CmBankAccountScreen> with AutomaticKeepAliveClientMixin {
  final GlobalKey<_BankListState> _listKey = GlobalKey();
  final GlobalKey<CmBankAccountDetailWidgetState> _detailKey = GlobalKey();

  Mode _mode = Mode.none;
  CmBankAccount? _selected;
  CmBankAccount? _copyFrom;
  int _requestSeq = 0;
  bool _isEnglish = false;

  @override
  bool get wantKeepAlive => true;

  final _svc = CmBankAccountService();

  Future<bool> _confirmLeave() async {
    final d = _detailKey.currentState;
    if (d != null && d.isDirty) return confirmDiscardChanges(context, _isEnglish);
    return true;
  }

  Future<void> _onAdd() async {
    if (!await _confirmLeave()) return;
    setState(() {
      _mode = Mode.add;
      _selected = null;
      _copyFrom = null;
      _requestSeq++;
    });
  }

  void _onCopy() {
    final src = _selected;
    if (src == null) return;
    setState(() {
      _mode = Mode.add;
      _selected = null;
      _copyFrom = src;
      _requestSeq++;
    });
  }

  void _onEdit() {
    if (_selected == null) return;
    setState(() {
      _mode = Mode.edit;
      _copyFrom = null;
      _requestSeq++;
    });
  }

  Future<void> _onView(CmBankAccount row) async {
    if (_mode == Mode.view && _selected?.id == row.id) return;
    if (!await _confirmLeave()) return;
    _show(row);
  }

  void _show(CmBankAccount row) => setState(() {
        _mode = Mode.view;
        _selected = row;
        _copyFrom = null;
        _requestSeq++;
      });

  Future<void> _onDelete() async {
    final row = _selected;
    if (row?.id == null) return;
    final e = _isEnglish;
    final l = AppL10n(e);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.confirmDelete),
        content: Text(e ? 'Delete bank account "${row!.accountCode} ${row.name(e)}"?' : 'ลบบัญชี "${row!.accountCode} ${row.name(e)}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.delete, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.deleteRow(row!.id!);
      _listKey.currentState?.refresh();
      _close();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ? 'Deleted successfully' : 'ลบสำเร็จ')));
    } catch (ex) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e ? 'Delete failed: $ex' : 'ลบล้มเหลว: $ex'), backgroundColor: Colors.red));
      }
    }
  }

  // บันทึกแล้วแสดงบัญชีนั้นต่อ
  Future<void> _onSubmit(CmBankAccount row) async {
    final e = _isEnglish;
    final CmBankAccount saved = _mode == Mode.add ? await _svc.addRow(row) : await _svc.updateRow(row);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_mode == Mode.add ? (e ? 'Added ${saved.accountCode}' : 'เพิ่มบัญชี ${saved.accountCode} สำเร็จ') : (e ? 'Saved successfully' : 'บันทึกสำเร็จ'))));
    }
    widget.onFieldsChanged?.call();
    final rows = await _listKey.currentState?.refresh();
    final fresh = rows?.where((r) => r.id == saved.id).firstOrNull ?? saved;
    if (mounted) _show(fresh);
  }

  Future<void> _onCancel() async {
    if (!await _confirmLeave()) return;
    if (_mode == Mode.edit && _selected != null) {
      _show(_selected!);
    } else {
      _close();
    }
  }

  void _close() => setState(() {
        _mode = Mode.none;
        _selected = null;
        _copyFrom = null;
        _requestSeq++;
      });

  Widget _detail(bool canCreate, bool canEdit, bool canDelete) {
    if (_mode == Mode.none) {
      return CmBankAccountDetailWidget(
          key: _detailKey, mode: Mode.none, selected: null, onSubmit: (_) async {}, onCancel: _close, isPlaceholder: true, requestSeq: _requestSeq);
    }
    final view = _mode == Mode.view;
    return CmBankAccountDetailWidget(
      key: _detailKey,
      mode: _mode,
      selected: _mode == Mode.add ? null : _selected,
      copyFrom: _mode == Mode.add ? _copyFrom : null,
      onSubmit: _onSubmit,
      onCancel: view ? _close : _onCancel,
      onEdit: view && canEdit ? _onEdit : null,
      onDelete: view && canDelete ? _onDelete : null,
      onCopy: view && canCreate ? _onCopy : null,
      requestSeq: _requestSeq,
    );
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
    return ImMasterShell(
      isEnglish: isEnglish,
      initialListWidth: 340,
      barActions: [
        if (canCreate) ImKit.barButton(context, isEnglish ? 'Add account' : 'เพิ่มบัญชี', Icons.add, _onAdd, primary: true),
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
      list: _BankList(key: _listKey, selectedId: _mode == Mode.view || _mode == Mode.edit ? _selected?.id : null, onTap: _onView),
      detail: _detail(canCreate, canEdit, canDelete),
    );
  }
}

// ---------------------------------------------------------------------------
// รายการบัญชี (แผงซ้าย)
// ---------------------------------------------------------------------------
class _BankList extends StatefulWidget {
  final int? selectedId;
  final ValueChanged<CmBankAccount> onTap;
  const _BankList({super.key, required this.selectedId, required this.onTap});

  @override
  State<_BankList> createState() => _BankListState();
}

enum _BFlag { bank, petty, cheque, fcy, noGl, inactive }

class _BankListState extends State<_BankList> {
  final _search = TextEditingController();
  List<CmBankAccount> _rows = [];
  Map<int, CmBankBalance> _bal = {};
  _BFlag? _flag;
  bool _loading = false;
  static final _money = NumberFormat('#,##0.00');

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

  Future<List<CmBankAccount>?> refresh() async {
    setState(() => _loading = true);
    List<CmBankAccount>? out;
    final svc = CmBankAccountService();
    try {
      final rows = await svc.fetchRows();
      out = rows;
      if (mounted) setState(() => _rows = rows);
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
    return out;
  }

  bool _ok(CmBankAccount a, _BFlag? f) => switch (f) {
        null => true,
        _BFlag.bank => a.cmType == 'BANK',
        _BFlag.petty => a.cmType == 'PETTY_CASH',
        _BFlag.cheque => a.isCheckAccount,
        _BFlag.fcy => a.currencyCode != CurrencyService.baseCode,
        _BFlag.noGl => a.glAccountId == null,
        _BFlag.inactive => !a.isActive,
      };

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
            (a.accountNumber ?? '').toLowerCase().contains(q) ||
            a.bankDisplay.toLowerCase().contains(q) ||
            (a.bankCode ?? '').toLowerCase().contains(q))
        .toList();
    final shown = base.where((a) => _ok(a, _flag)).toList()..sort((a, b) => a.accountCode.compareTo(b.accountCode));
    int n(_BFlag f) => base.where((a) => _ok(a, f)).length;
    void flag(_BFlag f) => setState(() => _flag = _flag == f ? null : f);
    ImMasterFilterChip chip(_BFlag f, String th, String en) =>
        ImMasterFilterChip(label: '${e ? en : th} ${n(f)}', on: _flag == f, onTap: () => flag(f));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ImMasterListHeader(
        searchCtrl: _search,
        hint: e ? 'Search code / name / account no. / bank' : 'ค้นหา รหัส / ชื่อ / เลขที่บัญชี / ธนาคาร',
        onSearch: (_) => setState(() {}),
        countText: _loading
            ? (e ? 'Loading...' : 'กำลังโหลด...')
            : (shown.length == _rows.length
                ? (e ? '${_rows.length} accounts' : 'ทั้งหมด ${_rows.length} บัญชี')
                : (e ? '${shown.length} of ${_rows.length} accounts' : '${shown.length} จาก ${_rows.length} บัญชี')),
        filters: [
          ImMasterFilterChip(label: e ? 'All' : 'ทั้งหมด', on: _flag == null, onTap: () => setState(() => _flag = null)),
          chip(_BFlag.bank, 'ธนาคาร', 'Bank'),
          chip(_BFlag.petty, 'เงินสดย่อย', 'Petty cash'),
          chip(_BFlag.cheque, 'ใช้เช็ค', 'Cheque'),
          chip(_BFlag.fcy, 'สกุลต่างประเทศ', 'Foreign currency'),
          chip(_BFlag.noGl, 'ไม่มีบัญชี GL', 'No GL account'),
          chip(_BFlag.inactive, 'หยุดใช้', 'Inactive'),
        ],
      ),
      Expanded(
        child: _loading && _rows.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : shown.isEmpty
                ? Center(child: Text(e ? 'No accounts found' : 'ไม่พบบัญชี', style: const TextStyle(color: ImKit.ink2)))
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 2, bottom: 12),
                    itemCount: shown.length,
                    itemBuilder: (_, i) {
                      final a = shown[i];
                      final b = a.id == null ? null : _bal[a.id];
                      final petty = a.cmType == 'PETTY_CASH';
                      final fcy = a.currencyCode != CurrencyService.baseCode;
                      return ImMasterListCard(
                        code: a.accountCode,
                        chips: [
                          if (petty)
                            ImKit.chip(e ? 'Petty cash' : 'เงินสดย่อย', ImKit.goldSoft, ImKit.amber)
                          else if (a.bankDisplay.isNotEmpty)
                            ImKit.chip(a.bankCode ?? a.bankDisplay, ImKit.blueSoft, ImKit.blue),
                          if (!petty) ImKit.chip(cmAccountTypeLabel(a.accountType, e).split(' (').first, ImKit.ro, ImKit.ink2),
                          if (fcy) ImKit.chip(a.currencyCode, ImKit.ro, ImKit.ink2),
                          if (a.isCheckAccount) ImKit.chip(e ? 'Cheque' : 'เช็ค', const Color(0xFFEFE8FB), const Color(0xFF5B3B9A)),
                          if (a.glAccountId == null) ImKit.chip(e ? 'No GL' : 'ไม่มี GL', ImKit.redSoft, ImKit.red),
                          if (!a.isActive) ImKit.chip(e ? 'Inactive' : 'หยุดใช้', ImKit.ro, ImKit.ink2),
                        ],
                        name: a.name(e),
                        meta: TextSpan(children: [
                          TextSpan(text: b == null ? '' : '${e ? 'balance' : 'คงเหลือ'} ${_money.format(b.balance)}'),
                          if (b != null && b.unreconciledCount > 0)
                            TextSpan(
                                text: e ? ' · ${b.unreconciledCount} not reconciled' : ' · ไม่กระทบยอด ${b.unreconciledCount} รายการ',
                                style: const TextStyle(color: ImKit.amber)),
                          if ((b == null || b.unreconciledCount == 0) && (a.accountNumber ?? '').isNotEmpty)
                            TextSpan(text: '${b == null ? '' : ' · '}${a.accountNumber}'),
                        ]),
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
