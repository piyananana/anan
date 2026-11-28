// lib/mo/widgets/mo_work_center_detail_widget.dart — ศูนย์ปฏิบัติงาน แบบ B ของ IM (user 2026-11-29)
//   แถบหัว + ตัวเลขสรุป (อัตรารวม, สูตรที่ใช้, ใบสั่งผลิตที่ยังไม่ปิด, ประสิทธิภาพปีนี้) + ลิงก์ข้ามส่วน
//   ส่วน: ข้อมูลศูนย์งาน (3 กลุ่มสี) / สูตรที่ใช้ศูนย์งานนี้ (ต้นทุนแปรรูปต่อรอบตามอัตราปัจจุบัน) / ใบสั่งผลิตที่ยังไม่ปิด
//   สำเนาเป็นศูนย์งานใหม่: ไม่คัดลอกรหัส
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../im/widgets/im_master_kit.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../models/mo_header.dart';
import '../models/mo_master_summary.dart';
import '../models/mo_work_center.dart';
import '../services/mo_work_center_service.dart';

class MoWorkCenterDetailWidget extends StatefulWidget {
  final Mode mode;
  final MoWorkCenter? selected;
  final MoWorkCenter? copyFrom;
  final Future<void> Function(MoWorkCenter) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;
  // เพิ่มขึ้นทุกครั้งที่หน้าจอหลักเปลี่ยน mode — บังคับเคลียร์ฟอร์มแม้ mode/selected ซ้ำเดิม
  final int requestSeq;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onCopy;

  const MoWorkCenterDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    this.copyFrom,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
    this.requestSeq = 0,
    this.onEdit,
    this.onDelete,
    this.onCopy,
  });

  @override
  State<MoWorkCenterDetailWidget> createState() => MoWorkCenterDetailWidgetState();
}

class MoWorkCenterDetailWidgetState extends State<MoWorkCenterDetailWidget> with ImMasterKit {
  bool _isEnglish = false;

  @override
  bool get kitEnglish => _isEnglish;
  @override
  bool get kitReadOnly => widget.mode == Mode.view;

  final _codeCtrl = TextEditingController();
  final _nameTh = TextEditingController();
  final _nameEn = TextEditingController();
  final _laborCtrl = TextEditingController();
  final _machineCtrl = TextEditingController();
  final _overheadCtrl = TextEditingController();
  bool _isActive = true;

  bool _isSaving = false;
  String _snapshot = '';

  MoWorkCenterSummary? _summary;
  bool _summaryLoading = false;
  int? _summaryFor;

  static final _money = NumberFormat('#,##0.00');
  static final _hrs = NumberFormat('#,##0.##');

  bool get isDirty => !kitReadOnly && !widget.isPlaceholder && _fingerprint() != _snapshot;
  bool get _isCopy => widget.mode == Mode.add && widget.copyFrom != null;

  @override
  void initState() {
    super.initState();
    _applyCurrent();
    _loadSummary();
  }

  @override
  void didUpdateWidget(covariant MoWorkCenterDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected == oldWidget.selected &&
        widget.mode == oldWidget.mode &&
        widget.requestSeq == oldWidget.requestSeq &&
        widget.copyFrom == oldWidget.copyFrom) {
      return;
    }
    final sameRecord = widget.selected?.id != null && widget.selected?.id == oldWidget.selected?.id;
    _applyCurrent();
    if (!sameRecord) _summaryFor = null;
    _loadSummary(force: sameRecord && widget.mode == Mode.view);
    kScrollTop();
  }

  @override
  void dispose() {
    for (final c in [_codeCtrl, _nameTh, _nameEn, _laborCtrl, _machineCtrl, _overheadCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyCurrent() {
    final copy = _isCopy;
    final d = widget.mode == Mode.add ? widget.copyFrom : widget.selected;
    String f(double? v) => v == null ? '0' : NumberFormat('0.####').format(v);
    _codeCtrl.text = copy ? '' : (d?.workCenterCode ?? '');
    _nameTh.text = d?.workCenterNameTh ?? '';
    _nameEn.text = d?.workCenterNameEn ?? '';
    _laborCtrl.text = f(d?.laborRatePerHour);
    _machineCtrl.text = f(d?.machineRatePerHour);
    _overheadCtrl.text = f(d?.overheadRatePerHour);
    _isActive = copy ? true : (d?.isActive ?? true);
    _snapshot = widget.mode == Mode.add ? '' : _fingerprint();
  }

  Future<void> _loadSummary({bool force = false}) async {
    final id = widget.mode == Mode.add ? null : widget.selected?.id;
    if (id == null || id == 0) {
      _summary = null;
      _summaryFor = null;
      return;
    }
    if (!force && _summaryFor == id && _summary != null) return;
    _summaryFor = id;
    _summaryLoading = true;
    try {
      final s = await MoWorkCenterService().fetchSummary(id);
      if (mounted && _summaryFor == id) setState(() => _summary = s);
    } catch (_) {
      if (mounted && _summaryFor == id) setState(() => _summary = null);
    }
    if (mounted && _summaryFor == id) setState(() => _summaryLoading = false);
  }

  double _n(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  MoWorkCenter _build() => MoWorkCenter(
        id: widget.mode == Mode.add ? 0 : (widget.selected?.id ?? 0),
        workCenterCode: _codeCtrl.text.trim().toUpperCase(),
        workCenterNameTh: _nameTh.text.trim(),
        workCenterNameEn: _nameEn.text.trim().isEmpty ? null : _nameEn.text.trim(),
        laborRatePerHour: _n(_laborCtrl),
        machineRatePerHour: _n(_machineCtrl),
        overheadRatePerHour: _n(_overheadCtrl),
        isActive: _isActive,
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
    if (_codeCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter the work center code' : 'โปรดระบุรหัสศูนย์งาน';
    } else if (_nameTh.text.trim().isEmpty) {
      err = e ? 'Please enter the Thai name' : 'โปรดระบุชื่อ (ไทย)';
    }
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await widget.onSubmit(_build());
    } catch (ex) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${e ? 'An error occurred' : 'เกิดข้อผิดพลาด'}: ${ex.toString().replaceFirst('Exception: ', '')}'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── การ์ด ───────────────────────────────────────────────────────────────────
  Widget _mainCard() {
    final e = _isEnglish;
    final ro = kitReadOnly;
    final total = _n(_laborCtrl) + _n(_machineCtrl) + _n(_overheadCtrl);
    return kCard(
      title: e ? 'Work center details' : 'ข้อมูลศูนย์งาน',
      trailing: kLegend(withAuto: false),
      child: kGroups([
        kGroup(1, e ? 'Main' : 'ข้อมูลหลัก', ImKit.gDoc, [
          kTxt(e ? 'Work center code *' : 'รหัสศูนย์งาน *', _codeCtrl, editable: widget.mode == Mode.add, cap: TextCapitalization.characters),
          kTxt(e ? 'Name (TH) *' : 'ชื่อ (ไทย) *', _nameTh),
          kTxt(e ? 'Name (EN)' : 'ชื่อ (อังกฤษ)', _nameEn),
        ]),
        kGroup(2, e ? 'Rates per hour' : 'อัตราต่อชั่วโมง', ImKit.gFin, [
          kRow([
            kTxt(e ? 'Labor' : 'ค่าแรง', _laborCtrl, numeric: true),
            kTxt(e ? 'Machine' : 'ค่าเครื่องจักร', _machineCtrl, numeric: true),
          ]),
          kRow([
            kTxt(e ? 'Overhead' : 'ค่าโสหุ้ย', _overheadCtrl, numeric: true),
            InputDecorator(
              decoration: kDec(e ? 'Total' : 'รวม', editable: false),
              child: Text(_money.format(total), textAlign: TextAlign.right, style: const TextStyle(fontSize: ImKit.font)),
            ),
          ]),
          kNote(e
              ? 'Routing cost = labor h × labor + machine h × (machine + overhead) + setup h × labor. Used only by BOMs / MOs costed by routing.'
              : 'ต้นทุนแปรรูป = ชม.แรงงาน × ค่าแรง + ชม.เครื่องจักร × (ค่าเครื่องจักร + ค่าโสหุ้ย) + ชม.ติดตั้ง × ค่าแรง · ใช้เฉพาะสูตร/ใบสั่งผลิตที่คิดต้นทุน "ตามขั้นตอนผลิต"'),
          if (!ro && total == 0) kNote(e ? 'All rates are 0 — routing steps here will cost nothing' : 'อัตราเป็น 0 ทั้งหมด ขั้นตอนที่ใช้ศูนย์งานนี้จะไม่มีต้นทุน', color: ImKit.amber),
        ]),
        kGroup(3, e ? 'More' : 'เพิ่มเติม', ImKit.gMore, [
          kChecks([kCk(e ? 'Active' : 'ใช้งาน', _isActive, ro ? null : (v) => setState(() => _isActive = v))]),
        ]),
      ]),
    );
  }

  Widget _loadingOr(String title) => kCard(
        title: title,
        child: _summaryLoading
            ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            : kNote(_isEnglish ? 'Could not load' : 'โหลดข้อมูลไม่ได้'),
      );

  Widget _bomsCard() {
    final e = _isEnglish;
    final s = _summary;
    final title = e ? 'BOMs using this work center' : 'สูตรที่ใช้ศูนย์งานนี้';
    if (s == null) return _loadingOr(title);
    return kCard(
      title: '$title (${s.bomCount})',
      count: e ? 'Read-only · conversion cost per batch at current rates' : 'อ่านอย่างเดียว · ต้นทุนแปรรูปต่อรอบผลิตตามอัตราปัจจุบัน',
      trailing: kGhost(e ? 'Bills of materials' : 'ไปหน้าสูตรการผลิต', Icons.open_in_new,
          () => ImKit.openMenu(context, 'MoBomScreen', 'สูตรการผลิต', 'Bill of Materials', e)),
      padding: EdgeInsets.zero,
      child: kTable(
        [
          KCol(e ? 'Item produced' : 'สินค้าที่ผลิต', 7),
          KCol(e ? 'Version' : 'เวอร์ชัน', 3),
          KCol(e ? 'Operation' : 'ขั้นตอน', 5),
          KCol(e ? 'Labor' : 'แรงงาน', 2, num: true),
          KCol(e ? 'Machine' : 'เครื่องจักร', 2, num: true),
          KCol(e ? 'Setup' : 'ติดตั้ง', 2, num: true),
          KCol(e ? 'Cost / batch' : 'ต้นทุน/รอบ', 3, num: true),
        ],
        [
          for (final b in s.boms)
            [
              kCell('${b.itemCode ?? ''} ${b.itemName(e)}'.trim(), color: b.isActive ? null : ImKit.ink3),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(b.bomVersion ?? '', style: const TextStyle(fontSize: 12.5)),
                const SizedBox(width: 4),
                b.isActive ? ImKit.chip(e ? 'Active' : 'ใช้งาน', ImKit.okSoft, ImKit.ok) : ImKit.chip(e ? 'Inactive' : 'ไม่ใช้งาน', ImKit.ro, ImKit.ink2),
              ]),
              kCell(b.operationName ?? ''),
              kCell(_hrs.format(b.laborHours), mono: true),
              kCell(_hrs.format(b.machineHours), mono: true),
              kCell(_hrs.format(b.setupHours), mono: true),
              kCell(b.costingMode == 'ROUTING' ? _money.format(b.cost) : (e ? 'not routing' : 'ไม่ได้คิดตามขั้นตอน'),
                  mono: true, color: b.costingMode == 'ROUTING' ? null : ImKit.ink3),
            ],
        ],
        minWidth: 820,
        empty: e ? 'No BOM uses this work center' : 'ยังไม่มีสูตรใช้ศูนย์งานนี้',
      ),
    );
  }

  Widget _mosCard() {
    final e = _isEnglish;
    final s = _summary;
    final title = e ? 'Open manufacturing orders' : 'ใบสั่งผลิตที่ยังไม่ปิด';
    if (s == null) return _loadingOr(title);
    return kCard(
      title: '$title (${s.openMoCount})',
      count: e ? 'Read-only · hours of this work center' : 'อ่านอย่างเดียว · ชั่วโมงของศูนย์งานนี้',
      trailing: kGhost(e ? 'Efficiency report' : 'รายงานประสิทธิภาพศูนย์การผลิต', Icons.open_in_new,
          () => ImKit.openMenu(context, 'MoWorkCenterEfficiencyReportScreen', 'รายงานประสิทธิภาพศูนย์การผลิต', 'Work Center Efficiency Report', e)),
      padding: EdgeInsets.zero,
      child: kTable(
        [
          KCol(e ? 'MO' : 'ใบสั่งผลิต', 4),
          KCol(e ? 'Item' : 'สินค้า', 7),
          KCol(e ? 'Status' : 'สถานะ', 3),
          KCol(e ? 'Planned labor h' : 'ชม.แรงงาน วางแผน', 3, num: true),
          KCol(e ? 'Actual labor h' : 'ชม.แรงงาน จริง', 3, num: true),
        ],
        [
          for (final m in s.openMos)
            [
              kCell(m.docNo ?? '', mono: true),
              kCell('${m.itemCode ?? ''} ${m.itemName(e)}'.trim()),
              ImKit.chip(moHeaderStatusLabel(m.status, e), m.status == 'InProgress' ? ImKit.blueSoft : ImKit.goldSoft, m.status == 'InProgress' ? ImKit.blue : ImKit.amber),
              kCell(_hrs.format(m.plannedLabor), mono: true),
              kCell(_hrs.format(m.actualLabor), mono: true),
            ],
        ],
        minWidth: 700,
        empty: e ? 'No open MO uses this work center' : 'ไม่มีใบสั่งผลิตที่ยังไม่ปิดใช้ศูนย์งานนี้',
      ),
    );
  }

  Widget _kpis() {
    final e = _isEnglish;
    final s = _summary;
    if (s == null) return kKpis(const [], loading: _summaryLoading);
    final eff = s.yearEfficiencyPct;
    return kKpis([
      ImKpi(e ? 'Total rate per hour' : 'อัตรารวมต่อชั่วโมง', _money.format(s.rateTotal),
          e
              ? 'labor ${_money.format(_n(_laborCtrl))} · machine ${_money.format(_n(_machineCtrl))} · overhead ${_money.format(_n(_overheadCtrl))}'
              : 'ค่าแรง ${_money.format(_n(_laborCtrl))} · เครื่องจักร ${_money.format(_n(_machineCtrl))} · โสหุ้ย ${_money.format(_n(_overheadCtrl))}',
          warn: s.rateTotal == 0),
      ImKpi(e ? 'BOMs using it' : 'สูตรที่ใช้', '${s.bomCount}',
          e ? '${s.operationCount} operation(s) · ${s.activeBomCount} active' : '${s.operationCount} ขั้นตอน · สูตรที่ใช้งาน ${s.activeBomCount}'),
      ImKpi(e ? 'Open MOs' : 'ใบสั่งผลิตที่ยังไม่ปิด', '${s.openMoCount}',
          e
              ? 'planned ${_hrs.format(s.openPlannedHours)} h · actual ${_hrs.format(s.openActualHours)} h'
              : 'วางแผน ${_hrs.format(s.openPlannedHours)} ชม. · ทำจริง ${_hrs.format(s.openActualHours)} ชม.'),
      ImKpi(e ? 'Efficiency this year' : 'ประสิทธิภาพปีนี้', eff == null ? '—' : '${NumberFormat('0.#').format(eff)}%',
          eff == null ? (e ? 'no MO hours this year' : 'ยังไม่มีชั่วโมงในใบสั่งผลิตปีนี้') : (e ? 'actual / planned labor hours' : 'ชั่วโมงแรงงานจริง / วางแผน'),
          onTap: () => ImKit.openMenu(context, 'MoWorkCenterEfficiencyReportScreen', 'รายงานประสิทธิภาพศูนย์การผลิต', 'Work Center Efficiency Report', e)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final e = isEnglish;
    if (widget.isPlaceholder) {
      return kPlaceholder(Icons.factory_outlined,
          e ? 'Select a work center on the left, or press "Add work center"' : 'เลือกศูนย์งานจากรายการด้านซ้าย หรือกด "เพิ่มศูนย์งาน"');
    }
    final ro = kitReadOnly;
    final isAdd = widget.mode == Mode.add;
    final saved = !isAdd && (widget.selected?.id ?? 0) != 0;
    final name = e && _nameEn.text.trim().isNotEmpty ? _nameEn.text.trim() : _nameTh.text.trim();
    return kPage(
      header: kHeaderBar(
        code: isAdd ? null : widget.selected?.workCenterCode,
        title: isAdd
            ? (_isCopy
                ? (e ? 'New work center (copy of ${widget.copyFrom!.workCenterCode})' : 'ศูนย์งานใหม่ (สำเนาจาก ${widget.copyFrom!.workCenterCode})')
                : (e ? 'New work center' : 'ศูนย์งานใหม่'))
            : name,
        badges: [
          if (!isAdd) ImKit.activeChip(_isActive, e),
          if (!ro) kEditingBadge(),
        ],
        busy: _isSaving,
        acts: kStdActs(
          saving: _isSaving,
          onEdit: widget.onEdit,
          onDelete: widget.onDelete,
          onClose: widget.onCancel,
          onCancel: widget.onCancel,
          onSave: _submit,
          extra: [if (widget.onCopy != null) DocBarAction(e ? 'Copy as new' : 'สำเนาเป็นศูนย์งานใหม่', widget.onCopy, fg: kInk)],
        ),
      ),
      top: saved ? _kpis() : null,
      sections: [
        (0, e ? 'Main' : 'ข้อมูลหลัก', _mainCard()),
        if (saved) (1, e ? 'BOMs' : 'สูตรที่ใช้', _bomsCard()),
        if (saved) (2, e ? 'MOs' : 'ใบสั่งผลิต', _mosCard()),
      ],
    );
  }
}
