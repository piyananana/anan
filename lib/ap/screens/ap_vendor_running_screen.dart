import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../models/ap_vendor_running.dart';
import '../services/ap_vendor_running_service.dart';
import '../../im/widgets/im_master_kit.dart';
import '../../sa/utils/sa_menu_theme.dart';

// การตั้งค่ารหัสผู้ขายอัตโนมัติ (ส่วนกลาง) — กลุ่มผู้ขายที่ตั้ง is_auto_number ออกรหัสตามรูปแบบของกลุ่มแทน
// หน้าตาแบบ B เหมือนหน้ารหัสสินค้าอัตโนมัติของ IM (user 2026-11-28): ตัวอย่างรหัสแยกสีตามส่วน + 3 รหัสถัดไป
// + เตือนเลขรันชนรหัสที่มีอยู่ (ระบบข้ามรหัสที่มีผู้ขายใช้แล้วตอนออกรหัส) + รหัสล่าสุดที่ออก + ตารางกลุ่มที่ออกรหัสเอง
class ApVendorRunningScreen extends StatefulWidget {
  const ApVendorRunningScreen({super.key});

  @override
  State<ApVendorRunningScreen> createState() => _ApVendorRunningScreenState();
}

class _ApVendorRunningScreenState extends State<ApVendorRunningScreen> with ImMasterKit {
  final _service = ApVendorRunningService();

  bool _isEnglish = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _editing = false;

  ApVendorRunning? _config;
  Map<String, dynamic>? _summary;
  Timer? _debounce;
  int _summarySeq = 0;

  final _prefixCtrl = TextEditingController();
  final _separatorCtrl = TextEditingController();
  final _nextNumberCtrl = TextEditingController();
  bool _isAutoNumbering = false;
  String _formatSuffixDate = '';
  int _runningLength = 4;

  static const _cPrefix = ImKit.gDoc, _cDate = ImKit.gParty, _cSep = ImKit.gMore, _cNum = ImKit.gFin;

  @override
  bool get kitEnglish => _isEnglish;
  @override
  bool get kitReadOnly => !_editing;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _prefixCtrl.dispose();
    _separatorCtrl.dispose();
    _nextNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final e = _isEnglish;
    setState(() => _isLoading = true);
    try {
      final config = await _service.fetchConfig();
      _config = config;
      _apply(config);
      _editing = false;
      await _loadSummary();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ? 'Error: $err' : 'เกิดข้อผิดพลาด: $err'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _apply(ApVendorRunning config) {
    _isAutoNumbering = config.isAutoNumbering;
    _prefixCtrl.text = config.formatPrefix;
    _separatorCtrl.text = config.formatSeparator;
    _formatSuffixDate = config.formatSuffixDate;
    _runningLength = config.runningLength;
    _nextNumberCtrl.text = config.nextRunningNumber.toString();
  }

  int get _nextNumber => int.tryParse(_nextNumberCtrl.text.trim()) ?? 1;

  // โหลดข้อมูลประกอบตามรูปแบบที่กำลังแก้ — คำขอเก่าที่ตอบช้ากว่าไม่ทับผลล่าสุด
  Future<void> _loadSummary() async {
    final seq = ++_summarySeq;
    try {
      final s = await _service.fetchSummary(
        prefix: _prefixCtrl.text.trim().toUpperCase(),
        separator: _separatorCtrl.text,
        suffixDate: _formatSuffixDate,
        length: _runningLength,
        next: _nextNumber < 1 ? 1 : _nextNumber,
      );
      if (mounted && seq == _summarySeq) setState(() => _summary = s);
    } catch (_) {
      if (mounted && seq == _summarySeq) setState(() => _summary = null);
    }
  }

  void _formatChanged() {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _loadSummary);
  }

  // ── ส่วนของรหัส (ตรงกับ formatVendorCode ฝั่ง backend: ปี ค.ศ. ตามวันที่วันนี้) ──
  String _datePart(String fmt, DateTime now) {
    final y = now.year.toString(), m = now.month.toString().padLeft(2, '0'), d = now.day.toString().padLeft(2, '0');
    return switch (fmt) {
      'YY' => y.substring(2),
      'YYYY' => y,
      'YYMM' => y.substring(2) + m,
      'YYYYMM' => y + m,
      'YYMMDD' => y.substring(2) + m + d,
      _ => '',
    };
  }

  List<MapEntry<String, String>> _suffixOptions(bool e) {
    final now = DateTime.now();
    String ex(String f) => e ? ' (e.g. ${_datePart(f, now)})' : ' (เช่น ${_datePart(f, now)})';
    return [
      MapEntry('', e ? 'No date' : 'ไม่ใช้วันที่'),
      MapEntry('YY', '${e ? 'YY — 2-digit year' : 'YY — ปี 2 หลัก'}${ex('YY')}'),
      MapEntry('YYYY', '${e ? 'YYYY — 4-digit year' : 'YYYY — ปี 4 หลัก'}${ex('YYYY')}'),
      MapEntry('YYMM', '${e ? 'YYMM — year-month' : 'YYMM — ปี-เดือน'}${ex('YYMM')}'),
      MapEntry('YYYYMM', '${e ? 'YYYYMM — 4-digit year-month' : 'YYYYMM — ปี 4 หลัก-เดือน'}${ex('YYYYMM')}'),
      MapEntry('YYMMDD', '${e ? 'YYMMDD — year-month-day' : 'YYMMDD — ปี-เดือน-วัน'}${ex('YYMMDD')}'),
    ];
  }

  String _dateLabel(bool e) => switch (_formatSuffixDate) {
        'YY' => e ? 'Year (YY)' : 'ปี (YY)',
        'YYYY' => e ? 'Year (YYYY)' : 'ปี (YYYY)',
        'YYMM' => e ? 'Year-month (YYMM)' : 'ปี-เดือน (YYMM)',
        'YYYYMM' => e ? 'Year-month (YYYYMM)' : 'ปี-เดือน (YYYYMM)',
        'YYMMDD' => e ? 'Year-month-day (YYMMDD)' : 'ปี-เดือน-วัน (YYMMDD)',
        _ => '',
      };

  Future<void> _save() async {
    final e = _isEnglish;
    final nextNum = int.tryParse(_nextNumberCtrl.text.trim());
    if (_isAutoNumbering && (nextNum == null || nextNum < 1)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e ? 'Please enter a valid next running number' : 'กรุณาระบุเลขรันถัดไปให้ถูกต้อง'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final saved = await _service.saveConfig(ApVendorRunning(
        id: _config?.id,
        isAutoNumbering: _isAutoNumbering,
        formatPrefix: _prefixCtrl.text.trim().toUpperCase(),
        formatSeparator: _separatorCtrl.text,
        formatSuffixDate: _formatSuffixDate,
        runningLength: _runningLength,
        nextRunningNumber: nextNum ?? 1,
      ));
      _config = saved;
      _apply(saved);
      _editing = false;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ? 'Saved successfully' : 'บันทึกสำเร็จ')));
      await _loadSummary();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ? 'Save failed: $err' : 'บันทึกล้มเหลว: $err'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _cancel() {
    final c = _config;
    setState(() {
      if (c != null) _apply(c);
      _editing = false;
    });
    _loadSummary();
  }

  // ── ส่วนต่างๆ ──
  Widget _seg(String text, Color c) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border(bottom: BorderSide(color: c, width: 3)),
        ),
        child: Text(text,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1, fontFeatures: [FontFeature.tabularFigures()])),
      );

  Widget _segLabel(String text, Color c) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11.5, color: ImKit.ink2)),
      ]);

  Widget _buildPreviewCard(bool e) {
    final prefix = _prefixCtrl.text.trim().toUpperCase();
    final date = _datePart(_formatSuffixDate, DateTime.now());
    final sep = _separatorCtrl.text;
    final num = (_nextNumber < 1 ? 1 : _nextNumber).toString().padLeft(_runningLength, '0');
    final nextCodes = ((_summary?['next_codes'] as List?) ?? const []).map((x) => '$x').toList();
    final collision = _summary?['collision'] as Map<String, dynamic>?;
    // next_codes = 4 รหัสที่จะออกจริง (ข้ามรหัสที่มีอยู่) — ไม่ชน: รหัสแรกคือรหัสที่แสดงอยู่แล้ว จึงแสดง 3 ตัวถัดไป
    // ชน: รหัสที่แสดงจะไม่ถูกออก จึงแสดง 3 ตัวแรกที่ว่าง
    final following = (collision == null ? nextCodes.skip(1) : nextCodes).take(3).toList();

    return kCard(
      title: e ? 'Sample generated code' : 'ตัวอย่างรหัสที่จะออก',
      count: e ? 'Updates as you edit' : 'อัปเดตทันทีขณะแก้',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
          decoration: BoxDecoration(color: ScreenTheme.of(context).soft, borderRadius: BorderRadius.circular(8)),
          child: Column(children: [
            if (!_isAutoNumbering) ...[
              Text(e ? 'Auto numbering is off — vendor codes are entered manually' : 'ปิดใช้งานอยู่ — ต้องระบุรหัสผู้ขายเอง',
                  style: const TextStyle(color: ImKit.amber, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
            ],
            Opacity(
              opacity: _isAutoNumbering ? 1 : 0.45,
              child: Wrap(alignment: WrapAlignment.center, runSpacing: 4, children: [
                if (prefix.isNotEmpty) _seg(prefix, _cPrefix),
                if (date.isNotEmpty) _seg(date, _cDate),
                if (sep.isNotEmpty) _seg(sep, _cSep),
                _seg(num, _cNum),
              ]),
            ),
            const SizedBox(height: 10),
            Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 4, children: [
              if (prefix.isNotEmpty) _segLabel(e ? 'Prefix' : 'คำนำหน้า', _cPrefix),
              if (date.isNotEmpty) _segLabel(_dateLabel(e), _cDate),
              if (sep.isNotEmpty) _segLabel(e ? 'Separator' : 'ตัวคั่น', _cSep),
              _segLabel(e ? 'Running number, $_runningLength digits' : 'เลขรัน $_runningLength หลัก', _cNum),
            ]),
            if (_isAutoNumbering && following.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 4, children: [
                Text(e ? 'Next' : 'ถัดไป', style: const TextStyle(fontSize: 12, color: ImKit.ink2)),
                for (final c in following)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: ImKit.line), borderRadius: BorderRadius.circular(5)),
                    child: Text(c, style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()])),
                  ),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget? _buildCollisionBanner(bool e) {
    final c = _summary?['collision'] as Map<String, dynamic>?;
    if (c == null || !_isAutoNumbering) return null;
    final name = e && '${c['vendor_name_en'] ?? ''}'.isNotEmpty ? c['vendor_name_en'] : (c['vendor_name_th'] ?? '');
    final free = c['next_free'] as int? ?? _nextNumber;
    final freeText = free.toString().padLeft(_runningLength, '0');
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F7),
        border: Border.all(color: const Color(0xFFF3C0BB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: ImKit.red, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            e
                ? 'Code ${c['code']} already exists (vendor "$name"). New vendors skip to the next free number $freeText.'
                : 'รหัส ${c['code']} มีอยู่แล้วในระบบ (ผู้ขาย "$name") ระบบจะข้ามไปเลขว่างถัดไป $freeText เมื่อออกรหัส',
            style: const TextStyle(fontSize: 12.5, color: ImKit.red),
          ),
        ),
        if (_editing) ...[
          const SizedBox(width: 8),
          kGhost(e ? 'Use $freeText' : 'ใช้เลข $freeText', Icons.auto_fix_high, () {
            _nextNumberCtrl.text = '$free';
            _formatChanged();
          }),
        ],
      ]),
    );
  }

  Widget _buildFormatCard(bool e) {
    final last = _summary?['last_issued'] as Map<String, dynamic>?;
    String lastText = '';
    if (last != null) {
      final d = DateTime.tryParse('${last['created_at'] ?? ''}')?.toLocal();
      final ds = d == null ? '' : ' · ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      lastText = '${last['vendor_code']}$ds';
    }
    final ro = kitReadOnly;
    return kCard(
      title: e ? 'Code format' : 'รูปแบบรหัส',
      trailing: kLegend(),
      child: kGroups([
        kGroup(1, e ? 'Usage' : 'การใช้งาน', ImKit.gDoc, [
          kChecks([
            kCk(e ? 'Use auto vendor numbering' : 'ใช้รหัสผู้ขายอัตโนมัติ', _isAutoNumbering,
                ro ? null : (v) => setState(() => _isAutoNumbering = v)),
          ]),
          kNote(
              e
                  ? 'The system assigns a code when a new vendor is saved; users can press "Enter manually" on the vendor screen. Vendor groups with their own numbering use the group format instead.'
                  : 'ระบบออกรหัสให้เมื่อบันทึกผู้ขายใหม่ ผู้ใช้กด "กรอกเอง" ในหน้าผู้ขายได้ กลุ่มผู้ขายที่ตั้งรหัสอัตโนมัติของตัวเองจะใช้รูปแบบของกลุ่มแทน',
              color: ImKit.ink2),
        ]),
        kGroup(2, e ? 'Leading part' : 'ส่วนหน้า', _cDate, [
          kRow([
            TextField(
              controller: _prefixCtrl,
              readOnly: ro,
              textCapitalization: TextCapitalization.characters,
              maxLength: 20,
              style: const TextStyle(fontSize: ImKit.font),
              decoration: kDec(e ? 'Prefix' : 'คำนำหน้า (Prefix)', editable: !ro).copyWith(counterText: ''),
              onChanged: (_) => _formatChanged(),
            ),
            kDd<String>(
              e ? 'Date part' : 'ส่วนวันที่',
              _formatSuffixDate,
              [for (final o in _suffixOptions(e)) DropdownMenuItem(value: o.key, child: Text(o.value, overflow: TextOverflow.ellipsis))],
              ro
                  ? null
                  : (v) {
                      _formatSuffixDate = v ?? '';
                      _formatChanged();
                    },
            ),
          ]),
        ]),
        kGroup(3, e ? 'Running number' : 'เลขรัน', _cNum, [
          kRow([
            TextField(
              controller: _separatorCtrl,
              readOnly: ro,
              maxLength: 5,
              style: const TextStyle(fontSize: ImKit.font),
              decoration: kDec(e ? 'Separator' : 'ตัวคั่น', editable: !ro).copyWith(counterText: ''),
              onChanged: (_) => _formatChanged(),
            ),
            kDd<int>(
              e ? 'Running number length' : 'ความยาวเลขรัน',
              _runningLength,
              [for (final n in {3, 4, 5, 6, 7, 8, _runningLength}) DropdownMenuItem(value: n, child: Text(e ? '$n digits' : '$n หลัก'))],
              ro
                  ? null
                  : (v) {
                      _runningLength = v ?? 4;
                      _formatChanged();
                    },
            ),
          ]),
          kRow([
            TextField(
              controller: _nextNumberCtrl,
              readOnly: ro,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: ImKit.font, fontFeatures: [FontFeature.tabularFigures()]),
              decoration: kDec(e ? 'Next running number *' : 'เลขรันถัดไป *', editable: !ro),
              onChanged: (_) => _formatChanged(),
            ),
            InputDecorator(
              decoration: kDec(e ? 'Last code issued' : 'รหัสล่าสุดที่ออก', editable: false),
              child: Text(lastText.isEmpty ? (e ? 'None yet' : 'ยังไม่มี') : lastText,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: ImKit.font)),
            ),
          ]),
        ]),
      ]),
    );
  }

  Widget _buildGroupsCard(bool e) {
    final groups = ((_summary?['groups'] as List?) ?? const []).cast<Map<String, dynamic>>();
    void openGroups() => ImKit.openMenu(context, 'ApVendorGroupScreen', 'กลุ่มผู้ขาย', 'Vendor Group', e);
    return kCard(
      title: e ? 'Vendor groups with their own numbering' : 'กลุ่มผู้ขายที่ออกรหัสเอง',
      count: e
          ? 'Read-only · ${groups.length} groups · vendors in these groups use the group format'
          : 'อ่านอย่างเดียว · ${groups.length} กลุ่ม · ผู้ขายในกลุ่มเหล่านี้ใช้รูปแบบของกลุ่มแทนหน้านี้',
      trailing: kGhost(e ? 'Vendor groups' : 'ไปหน้ากลุ่มผู้ขาย', Icons.open_in_new, openGroups),
      padding: EdgeInsets.zero,
      child: kTable(
        [KCol(e ? 'Group' : 'กลุ่ม', 6), KCol(e ? 'Next code' : 'รหัสถัดไป', 3), KCol(e ? 'Next number' : 'เลขรันถัดไป', 2, num: true),
          KCol(e ? 'Vendors' : 'ผู้ขายในกลุ่ม', 2, num: true)],
        [
          for (final g in groups)
            [
              kCell('${g['group_code']}  ${e && '${g['group_name_eng'] ?? ''}'.isNotEmpty ? g['group_name_eng'] : (g['group_name_thai'] ?? '')}'),
              kCell('${g['sample_code'] ?? ''}', mono: true),
              kCell('${g['running_next_number'] ?? ''}', mono: true),
              kCell('${g['vendor_count'] ?? 0}', mono: true),
            ],
        ],
        onTap: [for (final _ in groups) openGroups],
        minWidth: 560,
        empty: e ? 'No group numbers its own vendors — every vendor uses the format above.' : 'ไม่มีกลุ่มที่ออกรหัสเอง ผู้ขายทุกรายใช้รูปแบบด้านบน',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = e;
    final canEdit = MenuScope.of(context)?.canEdit ?? true;

    Widget body;
    if (_isLoading && _config == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
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
      final banner = _buildCollisionBanner(e);
      body = kPage(
        header: kHeaderBar(
          title: e ? 'Vendor auto-numbering' : 'การออกรหัสผู้ขายอัตโนมัติ',
          badges: [
            if (_editing) kEditingBadge(),
            _isAutoNumbering
                ? ImKit.chip(e ? 'Enabled' : 'เปิดใช้งาน', ImKit.okSoft, ImKit.ok)
                : ImKit.chip(e ? 'Disabled' : 'ปิดใช้งาน', ImKit.redSoft, ImKit.red),
          ],
          acts: acts,
          busy: _isSaving,
        ),
        sections: [
          (
            0,
            e ? 'Sample code' : 'ตัวอย่างรหัส',
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _buildPreviewCard(e),
              if (banner != null) ...[const SizedBox(height: 12), banner],
            ]),
          ),
          (1, e ? 'Format' : 'รูปแบบ', _buildFormatCard(e)),
          (2, e ? 'Groups with own numbering' : 'กลุ่มที่ออกรหัสเอง', _buildGroupsCard(e)),
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
                    _loadConfig();
                  },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: body,
    );
  }
}
