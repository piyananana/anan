// lib/gl/screens/gl_period_screen.dart
// หน้าจอปีบัญชีและงวดบัญชี แบบ IM design B (user 2026-11-28):
//   ซ้าย = การ์ดปีบัญชี + แถบความคืบหน้างวดที่ปิด GL แล้ว (ค้นหา, กรอง ยังเปิดอยู่ / ปิดครบแล้ว)
//   ขวา = PeriodDetailWidget (ข้อมูลปีเปิดมาเป็นโหมดดู แก้ไขผ่านแถบหัว; สถานะงวดเปลี่ยนได้ทันทีตามสิทธิ์)
//   AppBar: "สร้างปีบัญชีถัดไป" (คลิกเดียว จากปีล่าสุด โครงงวดเดิม) + เพิ่มปีบัญชีเอง
// initialFiscalYearId (จากกระดิ่งรออนุมัติปิดงวด) → เปิดปีนั้นทันที (ปุ่มอนุมัติอยู่ที่ป้ายสถานะ GL)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../im/widgets/im_master_kit.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/utils/sa_menu_theme.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../models/gl_period.dart';
import '../services/gl_period_service.dart';
import '../widgets/gl_period_detail_widget.dart';

class PeriodScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;
  final VoidCallback? onExit;
  final int? initialFiscalYearId;

  const PeriodScreen({super.key, required this.onFieldsChanged, this.onExit, this.initialFiscalYearId});

  @override
  State<PeriodScreen> createState() => _PeriodScreenState();
}

class _PeriodScreenState extends State<PeriodScreen> with AutomaticKeepAliveClientMixin {
  final GlobalKey<PeriodDetailWidgetState> _detailKey = GlobalKey();
  final _svc = PeriodService();
  final _searchCtrl = TextEditingController();

  List<FiscalYear> _years = [];
  bool _loading = false;
  String _query = '';
  String? _filter; // open | closed

  Mode _mode = Mode.none;
  FiscalYear? _selected;
  List<PostingPeriod> _periods = [];
  int _requestSeq = 0;
  bool _busy = false;

  static final _df = DateFormat('dd/MM/yyyy');

  @override
  bool get wantKeepAlive => true;

  bool get _isEnglish => Provider.of<LanguageProvider>(context, listen: false).isEnglish;

  @override
  void initState() {
    super.initState();
    _load(selectId: widget.initialFiscalYearId);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({int? selectId}) async {
    setState(() => _loading = true);
    try {
      final rows = await _svc.fetchHeaderRows();
      rows.sort((a, b) => b.yearStartDate.compareTo(a.yearStartDate));
      if (!mounted) return;
      setState(() => _years = rows);
      final pick = selectId == null ? null : rows.where((y) => y.id == selectId).firstOrNull;
      if (pick != null) await _show(pick);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEnglish ? 'Failed to load data: $e' : 'ไม่สามารถโหลดข้อมูลได้: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchPeriods(FiscalYear fy) async {
    try {
      final periods = await _svc.fetchDetailRows(fy.id);
      if (mounted && _selected?.id == fy.id) setState(() => _periods = periods);
    } catch (e) {
      if (mounted) {
        setState(() => _periods = []);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEnglish ? 'Failed to load periods: $e' : 'ไม่สามารถโหลดงวดบัญชีได้: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _show(FiscalYear fy, {Mode mode = Mode.view}) async {
    setState(() {
      _mode = mode;
      _selected = fy;
      if (_periods.isNotEmpty && _periods.first.fiscalYearId != fy.id) _periods = [];
      _requestSeq++;
    });
    await _fetchPeriods(fy);
  }

  Future<bool> _confirmLeave() async {
    final d = _detailKey.currentState;
    if (d != null && d.isDirty) return confirmDiscardChanges(context, _isEnglish);
    return true;
  }

  Future<void> _onView(FiscalYear fy) async {
    if (_mode == Mode.view && _selected?.id == fy.id) return;
    if (await _confirmLeave()) await _show(fy);
  }

  Future<void> _onAdd() async {
    if (!await _confirmLeave()) return;
    setState(() {
      _mode = Mode.add;
      _selected = null;
      _periods = [];
      _requestSeq++;
    });
  }

  Future<void> _onCancel() async {
    if (!await _confirmLeave()) return;
    if (_mode == Mode.edit && _selected != null) {
      setState(() {
        _mode = Mode.view;
        _requestSeq++;
      });
    } else {
      setState(() {
        _mode = Mode.none;
        _selected = null;
        _periods = [];
        _requestSeq++;
      });
    }
  }

  Future<void> _onSubmit(FiscalYear row) async {
    final e = _isEnglish;
    final adding = _mode == Mode.add;
    try {
      int id = row.id;
      if (adding) {
        id = (await _svc.addHeaderRow(row)).id;
      } else {
        await _svc.updateHeaderRow(row);
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(adding ? (e ? 'Added successfully' : 'เพิ่มสำเร็จ') : (e ? 'Saved successfully' : 'บันทึกสำเร็จ'))));
      widget.onFieldsChanged();
      await _load(selectId: id);
    } catch (ex) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ex.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _onDelete() async {
    final fy = _selected;
    if (fy == null) return;
    final e = _isEnglish;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(e ? 'Confirm Delete' : 'ยืนยันการลบ'),
        content: Text(e
            ? 'Delete fiscal year "${fy.fyCode}" and all its periods?'
            : 'ลบปีบัญชี "${fy.fyCode}" และงวดบัญชีทั้งหมดของปีนี้ใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(e ? 'Cancel' : 'ยกเลิก')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(e ? 'Delete' : 'ลบ', style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.deleteHeaderRow(fy.id);
      setState(() {
        _mode = Mode.none;
        _selected = null;
        _periods = [];
        _requestSeq++;
      });
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ? 'Deleted successfully' : 'ลบสำเร็จ')));
    } catch (ex) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ex.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _createNext() async {
    final e = _isEnglish;
    if (!await _confirmLeave()) return;
    final last = _years.isEmpty ? null : (_years.toList()..sort((a, b) => b.yearEndDate.compareTo(a.yearEndDate))).first;
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(e ? 'Create Next Fiscal Year' : 'สร้างปีบัญชีถัดไป'),
        content: Text(last == null
            ? (e ? 'There is no fiscal year yet.' : 'ยังไม่มีปีบัญชี')
            : (e
                ? 'Create the year after ${last.fyCode} (from ${_df.format(last.yearEndDate.add(const Duration(days: 1)))}) with the same periods, including special periods?'
                : 'สร้างปีบัญชีต่อจาก ${last.fyCode} (เริ่ม ${_df.format(last.yearEndDate.add(const Duration(days: 1)))}) โดยใช้โครงงวดเดิมทุกงวด รวมงวดพิเศษ ใช่หรือไม่?')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(e ? 'Cancel' : 'ยกเลิก')),
          if (last != null) ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(e ? 'Create' : 'สร้าง')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final id = await _svc.createNextYear();
      widget.onFieldsChanged();
      await _load(selectId: id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ? 'Fiscal year created' : 'สร้างปีบัญชีแล้ว')));
    } catch (ex) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ex.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _isCurrent(FiscalYear y) {
    final n = DateTime.now();
    final t = DateTime(n.year, n.month, n.day);
    return !y.yearStartDate.isAfter(t) && !y.yearEndDate.isBefore(t);
  }

  bool _fullyClosed(FiscalYear y) => y.totalPeriods > 0 && y.closedPeriods >= y.totalPeriods;

  Widget _list(bool e) {
    final q = _query.trim().toUpperCase();
    final open = _years.where((y) => !_fullyClosed(y)).length;
    final closed = _years.length - open;
    final shown = _years.where((y) {
      if (q.isNotEmpty && !y.fyCode.toUpperCase().contains(q) && !(y.description ?? '').toUpperCase().contains(q)) return false;
      if (_filter == 'open') return !_fullyClosed(y);
      if (_filter == 'closed') return _fullyClosed(y);
      return true;
    }).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ImMasterListHeader(
        searchCtrl: _searchCtrl,
        hint: e ? 'Search year / description' : 'ค้นหา ปี / คำอธิบาย',
        onSearch: (v) => setState(() => _query = v),
        filters: [
          ImMasterFilterChip(label: e ? 'All' : 'ทั้งหมด', on: _filter == null, onTap: () => setState(() => _filter = null)),
          ImMasterFilterChip(label: e ? 'Still open $open' : 'ยังเปิดอยู่ $open', on: _filter == 'open', onTap: () => setState(() => _filter = _filter == 'open' ? null : 'open')),
          ImMasterFilterChip(label: e ? 'Fully closed $closed' : 'ปิดครบแล้ว $closed', on: _filter == 'closed',
              onTap: () => setState(() => _filter = _filter == 'closed' ? null : 'closed')),
        ],
        countText: e ? '${_years.length} fiscal years' : 'ทั้งหมด ${_years.length} ปีบัญชี',
      ),
      Expanded(
        child: _loading && _years.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : shown.isEmpty
                ? Center(child: Text(e ? 'No fiscal year' : 'ไม่พบปีบัญชี', style: const TextStyle(color: ImKit.ink2)))
                : ListView(children: [
                    for (final y in shown)
                      () {
                        final ratio = y.totalPeriods == 0 ? 0.0 : (y.closedPeriods / y.totalPeriods).clamp(0.0, 1.0);
                        final notStarted = y.yearStartDate.isAfter(DateTime.now());
                        return Stack(children: [
                          ImMasterListCard(
                            code: y.fyCode,
                            chips: [
                              if (_isCurrent(y)) ImKit.chip(e ? 'Current' : 'ปีปัจจุบัน', ImKit.okSoft, ImKit.ok),
                              if (_fullyClosed(y)) ImKit.chip(e ? 'Fully closed' : 'ปิดครบแล้ว', ImKit.blueSoft, ImKit.blue),
                              if (notStarted) ImKit.chip(e ? 'Not started' : 'ยังไม่เริ่ม', ImKit.ro, ImKit.gMore),
                              if (!y.isActive) ImKit.activeChip(false, e),
                            ],
                            name: (y.description ?? '').isEmpty ? (e ? 'Fiscal year ${y.fyCode}' : 'ปีบัญชี ${y.fyCode}') : y.description!,
                            meta: TextSpan(
                                text: '${_df.format(y.yearStartDate)} – ${_df.format(y.yearEndDate)} · '
                                    '${e ? 'GL closed ${y.closedPeriods}/${y.totalPeriods}' : 'ปิด GL แล้ว ${y.closedPeriods}/${y.totalPeriods}'}'),
                            selected: _selected?.id == y.id && _mode != Mode.add,
                            active: y.isActive,
                            onTap: () => _onView(y),
                          ),
                          Positioned(
                            left: 20,
                            right: 20,
                            bottom: 9,
                            child: IgnorePointer(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(value: ratio, minHeight: 3, backgroundColor: const Color(0xFFE3E8EE),
                                    color: ScreenTheme.of(context).ink),
                              ),
                            ),
                          ),
                        ]);
                      }(),
                  ]),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final e = context.watch<LanguageProvider>().isEnglish;
    final perm = MenuScope.of(context);
    final canCreate = perm?.canCreate ?? true;
    final canEdit = perm?.canEdit ?? true;
    final canDelete = perm?.canDelete ?? true;
    final canApprove = perm?.canApprove ?? true;
    final view = _mode == Mode.view;
    return ImMasterShell(
      isEnglish: e,
      initialListWidth: 300,
      barActions: [
        if (canCreate) ImKit.barButton(context, e ? 'Add fiscal year' : 'เพิ่มปีบัญชี', Icons.add, _onAdd),
        if (canCreate) ImKit.barButton(context, e ? 'Create next fiscal year' : 'สร้างปีบัญชีถัดไป', Icons.event_repeat, _busy ? () {} : _createNext, primary: true),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: e ? 'Refresh' : 'รีเฟรชรายการ',
          onPressed: () async {
            if (!await _confirmLeave()) return;
            await _load(selectId: _mode == Mode.view || _mode == Mode.edit ? _selected?.id : null);
          },
        ),
      ],
      list: _list(e),
      detail: PeriodDetailWidget(
        key: _detailKey,
        mode: _mode,
        selectedHead: _selected,
        selectedDetail: _periods,
        isPlaceholder: _mode == Mode.none,
        onSubmitHead: _onSubmit,
        onCancel: view ? () => setState(() {
              _mode = Mode.none;
              _selected = null;
              _periods = [];
              _requestSeq++;
            }) : _onCancel,
        onEdit: view && canEdit
            ? () => setState(() {
                  _mode = Mode.edit;
                  _requestSeq++;
                })
            : null,
        onDelete: view && canDelete ? _onDelete : null,
        onDetailChange: () async {
          if (_selected != null) await _fetchPeriods(_selected!);

          try {
            final rows = await _svc.fetchHeaderRows();
            rows.sort((a, b) => b.yearStartDate.compareTo(a.yearStartDate));
            if (mounted) {
              setState(() {
                _years = rows;

              });
            }
          } catch (_) {}
        },
        canEdit: canEdit,
        canApprove: canApprove,
        requestSeq: _requestSeq,
      ),
    );
  }
}
