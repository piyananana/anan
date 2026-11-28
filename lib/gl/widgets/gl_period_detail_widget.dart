// lib/gl/widgets/gl_period_detail_widget.dart
// รายละเอียดปีบัญชี แบบ IM design B (user 2026-11-28):
//   แถบหัว (ปี, ป้ายใช้งาน/ปีปัจจุบัน/ปิดบัญชีสิ้นปีแล้ว, ช่วงวันที่) + ตัวเลขสรุป (งวดปัจจุบัน, ปิด GL แล้ว, รออนุมัติปิด,
//   เอกสาร Draft ในงวดเปิด) + กลุ่มข้อมูลปี + ตารางงวดแบบเมทริกซ์ GL/AR/AP/IM/CM (คลิกป้ายสถานะ = เมนูเปลี่ยนสถานะ,
//   พับงวดที่ปิดครบแล้ว, คอลัมน์ Draft ค้าง) + การ์ดเอกสารค้างในงวดเปิด
// ขั้นตอนเปลี่ยนสถานะ/ขอปิด/อนุมัติ/ปฏิเสธ/ยกเลิกคำขอ และ dialog งวดพิเศษ คัดลอกจากหน้าจอเดิมทั้งหมด (ไม่เปลี่ยนพฤติกรรม)
// เปลี่ยนสถานะงวดได้เมื่อมีสิทธิ์แก้ไข (ไม่ต้องกดแก้ไขปีก่อน), อนุมัติ/ปฏิเสธ = สิทธิ์อนุมัติ + อยู่ในคิวผู้อนุมัติ
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../im/widgets/im_master_kit.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../models/gl_period.dart';
import '../../sa/models/sa_doc_approval.dart';
import '../services/gl_period_service.dart';

const _modules = ['GL', 'AR', 'AP', 'IM', 'CM'];
const _moduleScreens = {
  'GL': ('GlEntryScreen', 'บันทึกรายการบัญชี', 'Journal entries'),
  'AR': ('ArTransactionScreen', 'เอกสารลูกหนี้', 'AR documents'),
  'AP': ('ApTransactionScreen', 'เอกสารเจ้าหนี้', 'AP documents'),
  'IM': ('ImTransactionScreen', 'เอกสารสินค้า', 'Inventory documents'),
  'CM': ('CmTransactionScreen', 'เอกสารการเงิน', 'Cash documents'),
};

class PeriodDetailWidget extends StatefulWidget {
  final Mode mode; // none / add / view / edit (edit = แก้ข้อมูลปี)
  final FiscalYear? selectedHead;
  final List<PostingPeriod>? selectedDetail;
  final Function(FiscalYear) onSubmitHead;
  final VoidCallback onCancel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isPlaceholder;
  final Function() onDetailChange; // โหลดงวดใหม่หลังเพิ่ม/แก้/ลบงวด หรือเปลี่ยนสถานะ
  final bool canEdit; // สิทธิ์แก้ไข — เพิ่ม/แก้/ลบงวด และเปลี่ยนสถานะงวด
  final bool canApprove; // สิทธิ์ "อนุมัติ" — คุมปุ่มอนุมัติ/ปฏิเสธคำขอปิดงวด GL
  final int requestSeq;

  const PeriodDetailWidget({
    super.key,
    required this.mode,
    this.selectedHead,
    this.selectedDetail,
    required this.onSubmitHead,
    required this.onCancel,
    this.onEdit,
    this.onDelete,
    this.isPlaceholder = false,
    required this.onDetailChange,
    this.canEdit = true,
    this.canApprove = true,
    this.requestSeq = 0,
  });

  @override
  State<PeriodDetailWidget> createState() => PeriodDetailWidgetState();
}

class PeriodDetailWidgetState extends State<PeriodDetailWidget> with ImMasterKit {
  final _fiscalYearCodeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _numOfPeriodsController = TextEditingController();
  late DateTime _yearStartDate;
  late DateTime _yearEndDate;
  bool _isActive = true;
  List<PostingPeriod> _selectedDetail = [];
  final PeriodService _detailService = PeriodService();
  final DateFormat _dateFormat = DateFormat('dd-MM-yyyy');
  final DateFormat _d2 = DateFormat('dd/MM');

  bool _isSaving = false;
  bool _isEnglish = false;
  bool _showClosed = false;
  FiscalYearSummary? _summary;
  bool _loadingSummary = false;
  int _seq = 0;
  String _snapshot = '';

  bool get _isNew => widget.mode == Mode.add;
  bool get _readOnly => widget.mode == Mode.view || widget.mode == Mode.none;
  @override
  bool get kitEnglish => _isEnglish;
  @override
  bool get kitReadOnly => _readOnly;

  bool get isDirty => !_readOnly && !widget.isPlaceholder && _fp() != _snapshot;

  @override
  void initState() {
    super.initState();
    _apply();
  }

  @override
  void didUpdateWidget(covariant PeriodDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedHead != oldWidget.selectedHead || widget.mode != oldWidget.mode || widget.requestSeq != oldWidget.requestSeq) {
      _apply();
    } else if (widget.selectedDetail != oldWidget.selectedDetail && widget.selectedHead != null) {
      // งวดโหลดใหม่ (เปลี่ยนสถานะ/เพิ่มงวด) → นับเอกสาร Draft ใหม่
      _loadSummary(widget.selectedHead!.id);
    }
  }

  @override
  void dispose() {
    _fiscalYearCodeController.dispose();
    _descriptionController.dispose();
    _numOfPeriodsController.dispose();
    super.dispose();
  }

  void _apply() {
    final h = _isNew ? null : widget.selectedHead;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _fiscalYearCodeController.text = h?.fyCode ?? '';
    _descriptionController.text = h?.description ?? '';
    _yearStartDate = h?.yearStartDate ?? DateTime(today.year, 1, 1);
    _yearEndDate = h?.yearEndDate ?? DateTime(today.year, 12, 31);
    _numOfPeriodsController.text = '${h?.numOfPeriods ?? 12}';
    _isActive = h?.isActive ?? true;
    _summary = null;
    if (h != null) _loadSummary(h.id);
    kScrollTop();
    _snapshot = _fp();
  }

  Future<void> _loadSummary(int fyId) async {
    final seq = ++_seq;
    _loadingSummary = true;
    try {
      final s = await _detailService.fetchYearSummary(fyId);
      if (mounted && seq == _seq) setState(() => _summary = s);
    } catch (_) {
    } finally {
      if (mounted && seq == _seq) setState(() => _loadingSummary = false);
    }
  }

  FiscalYear _build() => FiscalYear(
        id: widget.selectedHead?.id ?? 0,
        fyCode: _fiscalYearCodeController.text.trim(),
        description: _descriptionController.text.trim(),
        yearStartDate: _yearStartDate,
        yearEndDate: _yearEndDate,
        numOfPeriods: int.tryParse(_numOfPeriodsController.text) ?? 12,
        isActive: _isActive,
      );

  String _fp() => docFingerprint(_build().toJson());

  Future<void> _submitForm() async {
    final e = _isEnglish;
    String? err;
    if (_fiscalYearCodeController.text.trim().isEmpty) {
      err = e ? 'Please enter the fiscal year' : 'กรุณาป้อนปีบัญชี';
    } else if ((int.tryParse(_numOfPeriodsController.text) ?? 0) <= 0) {
      err = e ? 'Number of periods must be greater than 0' : 'จำนวนงวดต้องมากกว่า 0';
    } else if (_yearStartDate.isAfter(_yearEndDate)) {
      err = e ? 'Start date must not be after end date' : 'วันที่เริ่มต้นต้องไม่เกินวันที่สิ้นสุด';
    }
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await widget.onSubmitHead(_build());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── สถานะ ──
  static String _statusOf(PostingPeriod p, String m) => switch (m) {
        'GL' => p.glStatus,
        'AR' => p.arStatus,
        'AP' => p.apStatus,
        'IM' => p.imStatus,
        _ => p.cmStatus,
      };

  bool _isCurrent(PostingPeriod p) {
    final now = DateTime.now();
    final t = DateTime(now.year, now.month, now.day);
    return !p.periodStartDate.isAfter(t) && !p.periodEndDate.isBefore(t);
  }

  bool _allClosed(PostingPeriod p) => _modules.every((m) => _statusOf(p, m) == 'CLOSED');

  Widget _statusChip(String status, bool e) => switch (status) {
        'OPEN' => ImKit.chip(e ? 'Open' : 'เปิด', ImKit.okSoft, ImKit.ok),
        'LOCKED' => ImKit.chip(e ? 'Locked' : 'ล็อก', const Color(0xFFFFF3C4), ImKit.amber),
        'PENDING_CLOSE' => ImKit.chip(e ? 'Pending' : 'รออนุมัติ', ImKit.goldSoft, ImKit.amber),
        'CLOSED' => ImKit.chip(e ? 'Closed' : 'ปิด', ImKit.redSoft, ImKit.red),
        _ => ImKit.chip(status, ImKit.ro, ImKit.gMore),
      };

  /// การทำงานที่ทำได้ของป้ายสถานะ (เงื่อนไขเดียวกับไอคอนใต้ป้ายของหน้าจอเดิม)
  List<(String, IconData, Color, VoidCallback)> _statusActions(PostingPeriod period, String module, String status, bool e) {
    final out = <(String, IconData, Color, VoidCallback)>[];
    final currentUserId = AuthService().currentUser?.id;
    if (module == 'GL' && status == 'PENDING_CLOSE') {
      final myPending = period.closeApprovals.where((a) => a.approverUserId == currentUserId && a.status == 'Pending').toList();
      final canReject = widget.canApprove && myPending.isNotEmpty;
      final canAcceptNow = canReject && isMyApprovalTurn(period.closeApprovals, currentUserId, period.closeApprovalMode);
      final isRequester = period.closeRequestedBy != null && currentUserId == period.closeRequestedBy;
      if (canAcceptNow) out.add((e ? 'Approve close' : 'อนุมัติปิดงวด', Icons.check_circle_outline, Colors.green, () => _approveGlClose(period)));
      if (canReject) out.add((e ? 'Reject' : 'ปฏิเสธ', Icons.cancel_outlined, Colors.red, () => _rejectGlClose(period)));
      if (!canReject && isRequester) out.add((e ? 'Cancel request' : 'ยกเลิกคำขอ', Icons.undo, Colors.blueGrey, () => _cancelGlCloseRequest(period)));
      return out;
    }
    if (!widget.canEdit) return out;
    if (status == 'OPEN') {
      out.add((e ? 'Lock (LOCKED)' : 'ล็อก (LOCKED)', Icons.lock_outline, Colors.orange, () => _confirmSoftClose(period, module)));
      out.add(module == 'GL'
          ? (e ? 'Request close' : 'ขอปิดงวด', Icons.cancel_outlined, Colors.red, () => _confirmRequestGlClose(period))
          : (e ? 'Close period (CLOSED)' : 'ปิดงวด (CLOSED)', Icons.cancel_outlined, Colors.red, () => _confirmClose(period, module, 'OPEN')));
    } else if (status == 'LOCKED') {
      out.add((e ? 'Unlock (OPEN)' : 'ปลดล็อก (OPEN)', Icons.lock_open_outlined, Colors.green, () => _updateStatus(period, module, 'OPEN')));
      out.add(module == 'GL'
          ? (e ? 'Request close' : 'ขอปิดงวด', Icons.cancel_outlined, Colors.red, () => _confirmRequestGlClose(period))
          : (e ? 'Close period (CLOSED)' : 'ปิดงวด (CLOSED)', Icons.cancel_outlined, Colors.red, () => _confirmClose(period, module, 'LOCKED')));
    }
    return out;
  }

  Widget _statusCell(PostingPeriod p, String module, bool e) {
    final status = _statusOf(p, module);
    final acts = _statusActions(p, module, status, e);
    final pendingNames = module == 'GL' && status == 'PENDING_CLOSE'
        ? p.closeApprovals.where((a) => a.status == 'Pending').map((a) => '${a.approverUserName} (${a.sequenceNo})').join(' → ')
        : '';
    Widget chip = Row(mainAxisSize: MainAxisSize.min, children: [
      _statusChip(status, e),
      if (acts.isNotEmpty) const Icon(Icons.arrow_drop_down, size: 16, color: ImKit.ink2),
    ]);
    if (acts.isNotEmpty) {
      chip = PopupMenuButton<int>(
        tooltip: e ? 'Change status' : 'เปลี่ยนสถานะ',
        onSelected: (i) => acts[i].$4(),
        itemBuilder: (_) => [
          for (var i = 0; i < acts.length; i++)
            PopupMenuItem(
              value: i,
              child: Row(children: [Icon(acts[i].$2, size: 18, color: acts[i].$3), const SizedBox(width: 8), Text(acts[i].$1)]),
            ),
        ],
        child: chip,
      );
    }
    final w = pendingNames.isEmpty
        ? chip
        : Column(mainAxisSize: MainAxisSize.min, children: [
            chip,
            Text(pendingNames, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: ImKit.ink3)),
          ]);
    return Center(child: w);
  }

  // ── การ์ด ──
  Widget _mainCard() {
    final e = _isEnglish;
    final ed = !_readOnly;
    final datesEditable = ed && (_isNew || !(_summary?.hasPostings ?? true));
    final special = _selectedDetail.length - (widget.selectedHead?.numOfPeriods ?? _selectedDetail.length);
    return kCard(
      title: e ? 'Fiscal Year' : 'ข้อมูลปีบัญชี',
      trailing: ed ? kLegend(withAuto: false) : null,
      child: kGroups([
        kGroup(1, e ? 'Main Information' : 'ข้อมูลหลัก', ImKit.gDoc, [
          kRow([
            kTxt(e ? 'Fiscal Year (B.E. or A.D.) *' : 'ปีบัญชี (พ.ศ. หรือ ค.ศ.) *', _fiscalYearCodeController, editable: _isNew),
            Align(alignment: Alignment.centerLeft, child: kChecks([kCk(e ? 'Active' : 'ใช้งาน', _isActive, ed ? (v) => setState(() => _isActive = v) : null)])),
          ]),
          kTxt(e ? 'Description' : 'คำอธิบาย', _descriptionController),
        ]),
        kGroup(2, e ? 'Period' : 'ช่วงเวลา', ImKit.gParty, [
          kRow([
            kDate(e ? 'Start date *' : 'วันที่เริ่มต้น *', _yearStartDate, datesEditable ? (d) => setState(() => _yearStartDate = d ?? _yearStartDate) : null),
            kDate(e ? 'End date *' : 'วันที่สิ้นสุด *', _yearEndDate, datesEditable ? (d) => setState(() => _yearEndDate = d ?? _yearEndDate) : null),
          ]),
          kRow([
            kTxt(e ? 'Number of periods *' : 'จำนวนงวด *', _numOfPeriodsController, numeric: true, digitsOnly: true, editable: _isNew),
            InputDecorator(
              decoration: kDec(e ? 'Special periods' : 'งวดพิเศษ', editable: false),
              child: Text(_isNew ? '—' : '${special < 0 ? 0 : special}', style: const TextStyle(fontSize: ImKit.font)),
            ),
          ]),
          if (ed && !_isNew && !datesEditable)
            kNote(e ? 'Dates cannot be changed because the year already has journal entries.' : 'แก้วันที่ไม่ได้ เพราะมีรายการบัญชีในปีนี้แล้ว'),
          if (_isNew) kNote(e ? 'Monthly periods are created automatically when saved.' : 'ระบบสร้างงวดรายเดือนให้อัตโนมัติเมื่อบันทึก'),
        ]),
      ]),
    );
  }

  Widget _periodsCard() {
    final e = _isEnglish;
    final s = _summary;
    final all = _selectedDetail;
    // พับงวดที่ปิดครบทุกโมดูลไว้ ยกเว้นงวดปัจจุบัน/งวดหลังสุดที่ปิด
    final hidden = _showClosed ? <PostingPeriod>[] : all.where((p) => _allClosed(p) && !_isCurrent(p)).toList();
    final rows = all.where((p) => !hidden.contains(p)).toList();
    final canEditPeriod = widget.canEdit && widget.selectedHead != null;
    return kCard(
      title: e ? 'Posting Periods' : 'งวดบัญชี',
      count: e ? '${all.length} period(s) · click a status to change it' : '${all.length} งวด · คลิกป้ายสถานะเพื่อเปลี่ยนสถานะ',
      trailing: Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (all.any(_allClosed))
          ImMasterFilterChip(label: e ? 'Show fully closed' : 'แสดงงวดที่ปิดครบ', on: _showClosed, onTap: () => setState(() => _showClosed = !_showClosed)),
        if (canEditPeriod) kGhost(e ? 'Add special period' : 'เพิ่มงวดพิเศษ', Icons.add, () => _showDetailDialog()),
      ]),
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        kTable([
          KCol(e ? 'Period' : 'งวด', 5),
          KCol(e ? 'Dates' : 'ช่วงวันที่', 4),
          for (final m in _modules) KCol(m, 3),
          KCol(e ? 'Draft' : 'Draft ค้าง', 2, num: true),
          const KCol('', 3),
        ], [
          for (final p in rows)
            [
              Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(p.periodName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                if (_isCurrent(p)) ImKit.chip(e ? 'Current' : 'ปัจจุบัน', ImKit.blueSoft, ImKit.blue),
              ]),
              kCell('${_d2.format(p.periodStartDate)} – ${_d2.format(p.periodEndDate)}', color: ImKit.ink2),
              for (final m in _modules) _statusCell(p, m, e),
              () {
                final n = s?.draftOf(p.id) ?? 0;
                final by = (s?.draft[p.id] ?? const <String, int>{}).entries.map((x) => '${x.key} ${x.value}').join(' · ');
                final t = kCell(s == null ? '' : '$n', mono: true, bold: n > 0, color: n > 0 && !_allClosed(p) ? ImKit.red : null);
                return by.isEmpty ? t : Tooltip(message: by, child: t);
              }(),
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (canEditPeriod && p.glStatus != 'CLOSED') ...[
                  kIconBtn(Icons.edit, e ? 'Edit period date/name' : 'แก้ไขวันที่/ชื่องวด', () => _showDetailDialog(period: p), color: kInk),
                  kIconBtn(Icons.delete_outline, e ? 'Delete period' : 'ลบงวด', () => _deletePeriod(p.id), color: ImKit.red),
                ],
              ]),
            ],
        ], rowColors: [for (final p in rows) _isCurrent(p) ? const Color(0xFFFFFCF2) : null], minWidth: 980, rowMinHeight: 44,
            empty: e ? 'No period' : 'ยังไม่มีงวดบัญชี'),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: kNote([
            if (hidden.isNotEmpty) e ? '${hidden.length} fully closed period(s) are hidden.' : 'พับงวดที่ปิดครบทุกโมดูลไว้ ${hidden.length} งวด',
            e
                ? 'GL can be closed only after AR/AP/IM/CM of the period are closed and approved (same rules as before). Name/dates can be changed only for periods not yet closed in GL.'
                : 'ปิด GL ได้เมื่อ AR/AP/IM/CM ของงวดนั้นปิดแล้ว และผ่านการอนุมัติ (ตามกฎเดิม) · แก้ชื่อ/วันที่ได้เฉพาะงวดที่ GL ยังไม่ปิด',
          ].join('\n')),
        ),
      ]),
    );
  }

  Widget _pendingCard() {
    final e = _isEnglish;
    final s = _summary;
    final rows = s?.pending ?? const <FyPendingDoc>[];
    return kCard(
      title: e ? 'Pending Documents in Open Periods' : 'เอกสารค้างในงวดเปิด',
      count: e ? 'Read-only · draft documents dated in periods not yet closed' : 'อ่านอย่างเดียว · เอกสาร Draft ที่วันที่ตกอยู่ในงวดที่ยังไม่ปิด',
      padding: EdgeInsets.zero,
      child: s == null
          ? Padding(
              padding: const EdgeInsets.all(14),
              child: Center(child: _loadingSummary ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const SizedBox.shrink()),
            )
          : kTable([
              KCol(e ? 'Module' : 'โมดูล', 2),
              KCol(e ? 'Period' : 'งวด', 3),
              KCol(e ? 'Document type' : 'ประเภทเอกสาร', 6),
              KCol(e ? 'Count' : 'จำนวน', 2, num: true),
              const KCol('', 2),
            ], [
              for (final p in rows)
                [
                  ImKit.chip(p.module, ImKit.blueSoft, ImKit.blue),
                  kCell(p.periodName),
                  kCell([p.docCode ?? '', p.docName(e)].where((x) => x.isNotEmpty).join('  ')),
                  kCell('${p.count}', mono: true, bold: true),
                  InkWell(
                    onTap: () {
                      final t = _moduleScreens[p.module];
                      if (t != null) ImKit.openMenu(context, t.$1, t.$2, t.$3, e);
                    },
                    child: Text(e ? 'Open ›' : 'เปิด ›', style: TextStyle(fontSize: 12.5, color: kInk, decoration: TextDecoration.underline)),
                  ),
                ],
            ], minWidth: 640, empty: e ? 'No pending document' : 'ไม่มีเอกสารค้าง'),
    );
  }

  List<ImKpi> _kpis() {
    final e = _isEnglish;
    final s = _summary;
    final ps = _selectedDetail;
    final cur = ps.where(_isCurrent).firstOrNull;
    final closed = ps.where((p) => p.glStatus == 'CLOSED').toList();
    final pend = ps.where((p) => p.glStatus == 'PENDING_CLOSE').toList();
    final byMod = s?.pendingByModule ?? const <String, int>{};
    final draftTotal = byMod.values.fold(0, (a, b) => a + b);
    return [
      ImKpi(e ? 'Current period' : 'งวดปัจจุบัน', cur?.periodName ?? '-', e ? 'by today\'s date' : 'ตามวันที่วันนี้'),
      ImKpi(e ? 'GL closed' : 'ปิด GL แล้ว', '${closed.length} / ${ps.length}',
          closed.isEmpty ? (e ? 'none yet' : 'ยังไม่มี') : (e ? 'last: ${closed.last.periodName}' : 'งวดล่าสุดที่ปิด: ${closed.last.periodName}')),
      ImKpi(e ? 'Pending close approval' : 'รออนุมัติปิดงวด', '${pend.length}',
          pend.isEmpty ? '-' : '${pend.first.periodName}${pend.first.closeRequestedByName == null ? '' : (e ? ' · by ${pend.first.closeRequestedByName}' : ' · ขอโดย ${pend.first.closeRequestedByName}')}'),
      ImKpi(e ? 'Drafts in open periods' : 'เอกสาร Draft ในงวดเปิด', s == null ? '-' : '$draftTotal',
          byMod.isEmpty ? '-' : byMod.entries.map((x) => '${x.key} ${x.value}').join(' · '), warn: draftTotal > 0),
    ];
  }

  @override
  Widget build(BuildContext context) {
    _isEnglish = context.watch<LanguageProvider>().isEnglish;
    final e = _isEnglish;
    _selectedDetail = widget.selectedDetail ?? const [];
    if (widget.isPlaceholder) {
      return kPlaceholder(Icons.calendar_month_outlined, e ? 'Select a fiscal year on the left to view its periods' : 'เลือกปีบัญชีทางซ้ายเพื่อดูงวดบัญชี');
    }
    final h = widget.selectedHead;
    final saved = !_isNew && h != null;
    final now = DateTime.now();
    final isCurrentYear = saved && !h.yearStartDate.isAfter(now) && !h.yearEndDate.isBefore(DateTime(now.year, now.month, now.day));
    final yearEndDone = _summary?.yearEndStatus != null && _summary!.yearEndStatus!.toUpperCase().contains('COMPLET');
    return kPage(
      header: kHeaderBar(
        code: saved ? h.fyCode : null,
        title: saved ? ((h.description ?? '').isEmpty ? (e ? 'Fiscal year ${h.fyCode}' : 'ปีบัญชี ${h.fyCode}') : h.description!) : (e ? 'Add Fiscal Year' : 'เพิ่มปีบัญชี'),
        badges: [
          if (widget.mode == Mode.edit) kEditingBadge(),
          if (saved) ImKit.activeChip(h.isActive, e),
          if (isCurrentYear) ImKit.chip(e ? 'Current year' : 'ปีปัจจุบัน', ImKit.goldSoft, ImKit.amber),
          if (yearEndDone) ImKit.chip(e ? 'Year-end closed' : 'ปิดบัญชีสิ้นปีแล้ว', ImKit.blueSoft, ImKit.blue),
          if (saved) Text('${DateFormat('dd/MM/yyyy').format(h.yearStartDate)} – ${DateFormat('dd/MM/yyyy').format(h.yearEndDate)}',
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
        acts: kStdActs(
          saving: _isSaving,
          onEdit: widget.onEdit,
          onDelete: widget.onDelete == null || (_summary?.hasPostings ?? true) ? null : widget.onDelete,
          onClose: widget.onCancel,
          onCancel: widget.onCancel,
          onSave: _submitForm,
          extra: [
            if (saved && widget.canEdit) DocBarAction(e ? '+ Special period' : '+ งวดพิเศษ', () => _showDetailDialog(), fg: kInk),
          ],
        ),
        busy: _isSaving,
      ),
      top: saved ? kKpis(_kpis(), loading: _loadingSummary) : null,
      sections: [
        (0, e ? 'Main' : 'ข้อมูลหลัก', _mainCard()),
        if (saved) (1, e ? 'Periods' : 'งวดบัญชี', _periodsCard()),
        if (saved) (2, e ? 'Pending documents' : 'เอกสารค้างในงวด', _pendingCard()),
      ],
    );
  }

  // ───────────── ด้านล่าง: คัดลอกจากหน้าจอเดิม (dialog งวด + ขั้นตอนสถานะ/อนุมัติ) ─────────────

  Future<void> _showDetailDialog({PostingPeriod? period}) async {
    // กำหนดค่าเริ่มต้น
    String periodName = period?.periodName ?? '';
    DateTime startDate = period?.periodStartDate ?? _yearStartDate;
    DateTime endDate = period?.periodEndDate ?? _yearEndDate;
    // int periodNumber = period?.periodNumber ?? (widget.periods.isNotEmpty ? widget.periods.last.periodNumber + 1 : 1);
    int periodNumber = period?.periodNumber ??
        (_selectedDetail.isNotEmpty
            ? _selectedDetail.last.periodNumber + 10
            : 10);

    // หากเป็น Period ที่ถูกปิดแล้ว ไม่ควรอนุญาตให้แก้ไขวันที่
    final bool isClosed = period != null && period.glStatus != 'OPEN';

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return AlertDialog(
                title: Text(period == null
                    ? (l.isEnglish ? 'Add New Period' : 'เพิ่มงวดเดือนบัญชีใหม่')
                    : (l.isEnglish
                        ? 'Edit Period ${period.periodName}'
                        : 'แก้ไขงวดเดือนบัญชี ${period.periodName}')),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: periodNumber.toString(),
                            decoration: InputDecoration(
                              labelText: l.isEnglish ? 'Period Number' : 'ลำดับงวดเดือนบัญชี',
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            enabled: period == null, // ลำดับห้ามแก้ไข
                            onChanged: (v) =>
                                periodNumber = int.tryParse(v) ?? periodNumber,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextFormField(
                            initialValue: periodName,
                            decoration: InputDecoration(
                              labelText: l.isEnglish ? 'Period Name' : 'ชื่องวดเดือนบัญชี',
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (v) => periodName = v,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      // Date Pickers
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              dense: true,
                              key: Key('start_date_${period?.id ?? 'new'}'),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4.0),
                                side: BorderSide(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              title: Text(
                                  '${l.isEnglish ? 'Start Date' : 'วันที่เริ่มต้น'}: ${_dateFormat.format(startDate)}'),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: isClosed
                                  ? null
                                  : () async {
                                      final picked = await showDatePicker(
                                          context: context,
                                          initialDate: startDate,
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2100));
                                      if (picked != null) {
                                        setDialogState(() {
                                          startDate = picked;
                                        });
                                      }
                                    },
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ListTile(
                              dense: true,
                              key: Key('end_date_${period?.id ?? 'new'}'),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4.0),
                                side: BorderSide(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              title: Text(
                                  '${l.isEnglish ? 'End Date' : 'วันที่สิ้นสุด'}: ${_dateFormat.format(endDate)}'),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: isClosed
                                  ? null
                                  : () async {
                                      final picked = await showDatePicker(
                                          context: context,
                                          initialDate: endDate,
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2100));
                                      if (picked != null) {
                                        setDialogState(() {
                                          endDate = picked;
                                        });
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (isClosed)
                        Text(
                            l.isEnglish
                                ? 'Dates cannot be edited because the period is already closed'
                                : 'ไม่สามารถแก้ไขวันที่ได้ เนื่องจากงวดเดือนบัญชีถูกปิดแล้ว',
                            style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l.cancel)),
                  ElevatedButton(
                    onPressed: () async {
                      if (periodName.isEmpty || startDate.isAfter(endDate)) {
                        // widget.onMessage('ข้อมูลไม่ถูกต้อง: ชื่อห้ามว่าง และวันที่เริ่มต้นต้องไม่เกินวันที่สิ้นสุด');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l.isEnglish
                                ? 'Invalid data: name must not be empty, and start date must not be after end date'
                                : 'ข้อมูลไม่ถูกต้อง: ชื่อห้ามว่าง และวันที่เริ่มต้นต้องไม่เกินวันที่สิ้นสุด'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final newPeriod = PostingPeriod(
                        id: period?.id ?? 0,
                        fiscalYearId: widget.selectedHead!.id,
                        periodNumber: periodNumber,
                        periodName: periodName,
                        periodStartDate: startDate,
                        periodEndDate: endDate,
                        glStatus: period?.glStatus ?? 'LOCKED',
                        apStatus: period?.apStatus ?? 'LOCKED',
                        arStatus: period?.arStatus ?? 'LOCKED',
                        imStatus: period?.imStatus ?? 'LOCKED',
                        cmStatus: period?.cmStatus ?? 'LOCKED',
                      );

                      try {
                        if (period == null) {
                          await _detailService.addDetailRow(newPeriod);
                        } else {
                          await _detailService.updateDetailRow(newPeriod);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l.isEnglish
                                ? 'Period saved successfully'
                                : 'บันทึกงวดเดือนบัญชีสำเร็จ'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        widget.onDetailChange(); // แจ้งให้หน้าหลักโหลด Periods ใหม่
                        Navigator.of(context).pop();
                      } catch (e) {
                        // widget.onMessage('เกิดข้อผิดพลาดในการบันทึก: ${e.toString()}',);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l.isEnglish
                                ? 'Error saving: ${e.toString()}'
                                : 'เกิดข้อผิดพลาดในการบันทึก: ${e.toString()}'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    child: Text(period == null ? l.add : l.save),
                  ),
                ],
              );
            }
        );
      },
    );
  }

  void _deletePeriod(int periodId) async {
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    final bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l.confirmDelete),
            content: Text(
                l.isEnglish
                    ? 'Are you sure you want to delete this period? (Only periods not yet posted can be deleted)'
                    : 'คุณแน่ใจว่าต้องการลบงวดเดือนบัญชีนี้หรือไม่? (ลบได้เฉพาะรอบที่ยังไม่ลงบัญชี)'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l.cancel)),
              TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l.delete)),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      try {
        // await _detailService.deletePeriod(periodId);
        await _detailService.deleteDetailRow(periodId);
        // widget.onMessage('ลบงวดเดือนบัญชีสำเร็จ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.isEnglish ? 'Period deleted successfully' : 'ลบงวดเดือนบัญชีสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onDetailChange();
      } catch (e) {
        // widget.onMessage('ไม่สามารถลบได้: ${e.toString()}',);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.isEnglish ? 'Unable to delete: ${e.toString()}' : 'ไม่สามารถลบได้: ${e.toString()}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  // ปิดงวด (CLOSED) — 2-step: warning → credential approval
  Future<void> _confirmClose(
      PostingPeriod period, String module, String fromStatus) async {
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    int step = 1;
    final confirmCtrl = TextEditingController(); // username
    final pwCtrl = TextEditingController();      // password
    bool pwVisible = false;
    String approvalError = '';
    bool isApproving = false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) {
          if (step == 1) {
            return AlertDialog(
              title: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 26),
                const SizedBox(width: 8),
                Text(l.isEnglish ? 'Warning: Close Period' : 'คำเตือน: ปิดงวดบัญชี'),
              ]),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${l.isEnglish ? 'Period' : 'งวดเดือนบัญชี'}: ${period.periodName}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('${l.isEnglish ? 'Module' : 'โมดูล'}: $module'),
                          const SizedBox(height: 2),
                          Text('${l.isEnglish ? 'Status change' : 'การเปลี่ยนสถานะ'}: $fromStatus → CLOSED',
                              style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _warningRow(Icons.lock, l.isEnglish
                        ? 'Entries in this period can no longer be recorded/edited'
                        : 'ไม่สามารถบันทึก/แก้ไขรายการในงวดนี้ได้อีก'),
                    _warningRow(Icons.block, l.isEnglish
                        ? 'The status cannot be reverted back to OPEN or LOCKED'
                        : 'ไม่สามารถย้อนสถานะกลับเป็น OPEN หรือ LOCKED ได้'),
                    _warningRow(Icons.people_outline, l.isEnglish
                        ? 'No user will be able to post entries in this period'
                        : 'ผู้ใช้ทุกคนจะไม่สามารถลงรายการในงวดนี้ได้'),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l.isEnglish
                                ? 'Please make sure all entries are recorded and reconciled\nbefore closing this period'
                                : 'ควรตรวจสอบให้แน่ใจว่าลงรายการและกระทบยอดครบถ้วนแล้ว\nก่อนดำเนินการปิดงวดบัญชี',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(l.cancel),
                ),
                ElevatedButton.icon(
                  onPressed: () => setDs(() => step = 2),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text(l.isEnglish ? 'Continue' : 'ดำเนินการต่อ'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                ),
              ],
            );
          }

          // ── Step 2: credential approval ─────────────────────────────────
          return AlertDialog(
            title: Row(children: [
              const Icon(Icons.verified_user, color: Colors.red, size: 22),
              const SizedBox(width: 8),
              Text(l.isEnglish ? 'Period Closing Approver' : 'ผู้อนุมัติการปิดงวดบัญชี'),
            ]),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.isEnglish
                        ? 'Please have an authorized approver fill in the details to confirm\n(a user belonging to a group with permission to approve period closing)'
                        : 'โปรดให้ผู้มีสิทธิ์อนุมัติกรอกข้อมูลเพื่อยืนยัน\n(ผู้ใช้ที่อยู่ในกลุ่มที่มีสิทธิ์อนุมัติการปิดงวดบัญชี)',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: confirmCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: l.isEnglish ? 'Username' : 'ชื่อผู้ใช้',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setDs(() {}),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: pwCtrl,
                    obscureText: !pwVisible,
                    decoration: InputDecoration(
                      labelText: l.isEnglish ? 'Password' : 'รหัสผ่าน',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: Icon(pwVisible ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDs(() => pwVisible = !pwVisible),
                      ),
                    ),
                    onChanged: (_) => setDs(() {}),
                  ),
                  if (approvalError.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          approvalError,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isApproving ? null : () => Navigator.of(ctx).pop(false),
                child: Text(l.cancel),
              ),
              ElevatedButton.icon(
                onPressed: (confirmCtrl.text.trim().isNotEmpty &&
                        pwCtrl.text.isNotEmpty &&
                        !isApproving)
                    ? () async {
                        setDs(() {
                          isApproving = true;
                          approvalError = '';
                        });
                        try {
                          await _detailService.verifyCloseApprover(
                              confirmCtrl.text.trim(), pwCtrl.text);
                          if (ctx.mounted) Navigator.of(ctx).pop(true);
                        } catch (e) {
                          setDs(() {
                            approvalError = e.toString().replaceFirst('Exception: ', '');
                            isApproving = false;
                          });
                        }
                      }
                    : null,
                icon: isApproving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.lock, size: 16),
                label: Text(l.isEnglish ? 'Confirm Close Period' : 'ยืนยันปิดงวด'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ],
          );
        },
      ),
    );

    confirmCtrl.dispose();
    pwCtrl.dispose();
    if (confirmed == true) {
      _updateStatus(period, module, 'CLOSED');
    }
  }

  Widget _warningRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(icon, size: 16, color: Colors.red.shade700),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ]),
    );
  }

  Future<void> _confirmSoftClose(PostingPeriod period, String module) async {
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.isEnglish ? 'Confirm Status Change' : 'ยืนยันการเปลี่ยนสถานะ'),
        content: Text(
          l.isEnglish
              ? 'Changing status from OPEN to LOCKED is for data review purposes. '
                  'It will prevent further entries from being added to this period and module, '
                  'but the status can still be reverted back to OPEN.'
              : 'การเปลี่ยนสถานะ OPEN เป็น LOCKED เพื่อการตรวจสอบข้อมูล '
                  'จะทำให้เพิ่มเติมรายการของงวดและโมดูลนี้ไม่ได้ '
                  'แต่ยังสามารถย้อนสถานะกลับมา OPEN ได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.confirm),
          ),
        ],
      ),
    );
    if (confirm == true) {
      _updateStatus(period, module, 'LOCKED');
    }
  }

  void _updateStatus(
      PostingPeriod period, String module, String newStatus) async {
    final isEnglish = _isEnglish;
    try {
      // await _service.updatePeriodStatus(period.id, module, newStatus, _currentUserId);
      await _detailService.updateStatusDetailRow(period.id, module, newStatus);
      // widget.onMessage('อัปเดตสถานะ ${module} เป็น ${newStatus} สำเร็จ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEnglish
              ? 'Updated $module status to $newStatus successfully'
              : 'อัปเดตสถานะ $module เป็น $newStatus สำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
      widget.onDetailChange();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── GL Period Close Approval Workflow ──────────────────────────────────

  // ขอปิดงวดบัญชี GL — แทนที่ flow รหัสผ่านเดิม ด้วยการส่งคำขอไปยังผู้อนุมัติที่ตั้งค่าไว้
  Future<void> _confirmRequestGlClose(PostingPeriod period) async {
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    final isEnglish = l.isEnglish;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 26),
          const SizedBox(width: 8),
          Text(isEnglish ? 'Request to Close Period' : 'ขออนุมัติปิดงวดบัญชี'),
        ]),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${isEnglish ? 'Period' : 'งวดเดือนบัญชี'}: ${period.periodName}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      isEnglish
                          ? 'Closing a GL period is irreversible once approved'
                          : 'การปิดงวดบัญชี GL ไม่สามารถย้อนกลับได้เมื่อได้รับการอนุมัติแล้ว',
                      style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _warningRow(Icons.playlist_add_check, isEnglish
                  ? 'AP, AR, CM and IM periods must all be CLOSED first'
                  : 'งวดบัญชีของ AP, AR, CM และ IM ต้องถูกปิด (CLOSED) ให้ครบก่อน'),
              _warningRow(Icons.fact_check_outlined, isEnglish
                  ? 'There must be no Draft GL entries remaining in this period'
                  : 'ต้องไม่มีรายการบัญชี GL ที่ยังอยู่ในสถานะ Draft ค้างอยู่'),
              _warningRow(Icons.how_to_reg, isEnglish
                  ? 'This request will be sent to the configured approver for confirmation'
                  : 'คำขอนี้จะถูกส่งไปยังผู้อนุมัติที่ตั้งค่าไว้เพื่อยืนยันการปิดงวด'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.send, size: 16),
            label: Text(isEnglish ? 'Send Request' : 'ส่งคำขอ'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final menuId = MenuScope.of(context)?.id;
    if (menuId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEnglish ? 'Cannot determine current menu' : 'ไม่สามารถระบุเมนูปัจจุบันได้'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    try {
      final result = await _detailService.requestClose(period.id, menuId: menuId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message']?.toString() ??
            (isEnglish ? 'Close request sent successfully' : 'ส่งคำขอปิดงวดสำเร็จ')),
        backgroundColor: Colors.green,
      ));
      widget.onDetailChange();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _approveGlClose(PostingPeriod period) async {
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    final isEnglish = l.isEnglish;
    if (period.closeRequestId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEnglish ? 'Approve Period Close' : 'อนุมัติปิดงวดบัญชี'),
        content: Text(isEnglish
            ? 'Approve closing period "${period.periodName}"? This action cannot be undone.'
            : 'ยืนยันอนุมัติปิดงวดบัญชี "${period.periodName}" ใช่หรือไม่? การดำเนินการนี้ไม่สามารถย้อนกลับได้'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(isEnglish ? 'Approve' : 'อนุมัติ'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _detailService.approveCloseRequest(period.closeRequestId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEnglish ? 'Period closed successfully' : 'อนุมัติปิดงวดบัญชีสำเร็จ'),
        backgroundColor: Colors.green,
      ));
      widget.onDetailChange();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _rejectGlClose(PostingPeriod period) async {
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    final isEnglish = l.isEnglish;
    if (period.closeRequestId == null) return;
    final remarksCtrl = TextEditingController();
    String? errorText;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDs) => AlertDialog(
        title: Text(isEnglish ? 'Reject Close Request' : 'ปฏิเสธคำขอปิดงวด'),
        content: TextField(
          controller: remarksCtrl,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: isEnglish ? 'Reason (required)' : 'เหตุผล (จำเป็น)',
            border: const OutlineInputBorder(),
            isDense: true,
            errorText: errorText,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          ElevatedButton(
            onPressed: () {
              if (remarksCtrl.text.trim().isEmpty) {
                setDs(() => errorText = isEnglish ? 'Required' : 'กรุณาระบุ');
                return;
              }
              Navigator.of(ctx).pop(true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(isEnglish ? 'Reject' : 'ปฏิเสธ'),
          ),
        ],
      )),
    );
    final remarks = remarksCtrl.text.trim();
    remarksCtrl.dispose();
    if (confirm != true) return;
    try {
      await _detailService.rejectCloseRequest(period.closeRequestId!, remarks);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEnglish ? 'Request rejected' : 'ปฏิเสธคำขอสำเร็จ'),
        backgroundColor: Colors.green,
      ));
      widget.onDetailChange();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _cancelGlCloseRequest(PostingPeriod period) async {
    final l = AppL10n(context.read<LanguageProvider>().isEnglish);
    final isEnglish = l.isEnglish;
    if (period.closeRequestId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEnglish ? 'Cancel Close Request' : 'ยกเลิกคำขอปิดงวด'),
        content: Text(isEnglish
            ? 'Cancel the pending close request for "${period.periodName}"?'
            : 'ยกเลิกคำขอปิดงวดบัญชี "${period.periodName}" ที่รออนุมัติอยู่ใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.confirm),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _detailService.cancelCloseRequest(period.closeRequestId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEnglish ? 'Request cancelled' : 'ยกเลิกคำขอสำเร็จ'),
        backgroundColor: Colors.green,
      ));
      widget.onDetailChange();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: Colors.red,
      ));
    }
  }
}
