// lib/ar/widgets/ar_collector_detail_widget.dart — ผู้วางบิล/ผู้เก็บเงิน แบบ B ของ IM (user 2026-11-28)
//   แถบหัว (รหัส ชื่อ ป้ายชนิด/วันที่มีผล / ปุ่ม) + ตัวเลขสรุป + ข้อมูล 3 กลุ่มสี + ลูกค้าที่รับผิดชอบ
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../im/widgets/im_master_kit.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../cd/models/cd_branch.dart';
import '../../cd/services/cd_branch_service.dart';
import '../models/ar_collector.dart';
import '../models/ar_customer_summary.dart';
import '../services/ar_collector_service.dart';

/// ป้ายวันที่มีผลของผู้วางบิล/ผู้เก็บเงิน (ใช้ทั้งการ์ดรายการและแถบหัว)
Widget arCollectorEffectiveChip(ArCollector c, bool isEnglish) => switch (c.effectiveState()) {
      'expired' => ImKit.chip(isEnglish ? 'Expired' : 'หมดอายุ', ImKit.redSoft, ImKit.red),
      'future' => ImKit.chip(isEnglish ? 'Not started' : 'ยังไม่เริ่ม', ImKit.goldSoft, ImKit.amber),
      _ => ImKit.chip(isEnglish ? 'In effect' : 'มีผล', ImKit.okSoft, ImKit.ok),
    };

class ArCollectorDetailWidget extends StatefulWidget {
  final Mode mode;
  final ArCollector? selected;
  final Function(ArCollector) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;
  // เพิ่มขึ้นทุกครั้งที่หน้าจอหลักเปลี่ยน mode — บังคับเคลียร์ฟอร์มแม้ mode/selected ซ้ำเดิม
  final int requestSeq;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ArCollectorDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
    this.requestSeq = 0,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<ArCollectorDetailWidget> createState() => ArCollectorDetailWidgetState();
}

class ArCollectorDetailWidgetState extends State<ArCollectorDetailWidget> with ImMasterKit {
  bool _isEnglish = false;

  @override
  bool get kitEnglish => _isEnglish;
  @override
  bool get kitReadOnly => widget.mode == Mode.view;

  final _codeCtrl = TextEditingController();
  final _nameThCtrl = TextEditingController();
  final _nameEnCtrl = TextEditingController();
  final _taxIdCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String _type = 'EMPLOYEE';
  int? _branchId;
  String? _branchNameThai;
  String? _branchLabel;
  DateTime? _from;
  DateTime? _to;
  bool _isActive = true;

  bool _isSaving = false;
  String _snapshot = '';
  ArCollectorSummary? _summary;
  bool _summaryLoading = false;
  int? _summaryFor;

  static final _money = NumberFormat('#,##0.00');

  bool get isDirty => !kitReadOnly && !widget.isPlaceholder && _fingerprint() != _snapshot;

  @override
  void initState() {
    super.initState();
    _apply(widget.mode == Mode.add ? null : widget.selected);
    _loadSummary();
  }

  @override
  void didUpdateWidget(covariant ArCollectorDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected == oldWidget.selected && widget.mode == oldWidget.mode && widget.requestSeq == oldWidget.requestSeq) return;
    final sameRecord = widget.selected?.id != null && widget.selected?.id == oldWidget.selected?.id;
    _apply(widget.mode == Mode.add ? null : widget.selected);
    if (!sameRecord) _summaryFor = null;
    _loadSummary(force: sameRecord && widget.mode == Mode.view && widget.requestSeq != oldWidget.requestSeq);
    if (!sameRecord || widget.mode != oldWidget.mode) kScrollTop();
  }

  @override
  void dispose() {
    for (final c in [_codeCtrl, _nameThCtrl, _nameEnCtrl, _taxIdCtrl, _phoneCtrl, _emailCtrl, _addressCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _apply(ArCollector? d) {
    _codeCtrl.text = d?.collectorCode ?? '';
    _nameThCtrl.text = d?.collectorNameThai ?? '';
    _nameEnCtrl.text = d?.collectorNameEng ?? '';
    _taxIdCtrl.text = d?.taxId ?? '';
    _phoneCtrl.text = d?.phone ?? '';
    _emailCtrl.text = d?.email ?? '';
    _addressCtrl.text = d?.address ?? '';
    _type = d?.collectorType ?? 'EMPLOYEE';
    _branchId = d?.branchId;
    _branchNameThai = d?.branchNameThai;
    _branchLabel = null;
    _from = d?.effectiveDateFrom;
    _to = d?.effectiveDateTo;
    _isActive = d?.isActive ?? true;
    _snapshot = _fingerprint();
  }

  Future<void> _loadSummary({bool force = false}) async {
    final id = widget.mode == Mode.add ? null : widget.selected?.id;
    if (id == null) {
      _summary = null;
      _summaryFor = null;
      return;
    }
    if (!force && _summaryFor == id && _summary != null) return;
    _summaryFor = id;
    _summaryLoading = true;
    try {
      final s = await Provider.of<ArCollectorService>(context, listen: false).fetchSummary(id);
      if (mounted && _summaryFor == id) setState(() => _summary = s);
    } catch (_) {
      if (mounted && _summaryFor == id) setState(() => _summary = null);
    } finally {
      if (mounted && _summaryFor == id) setState(() => _summaryLoading = false);
    }
  }

  String? _t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  ArCollector _build() => ArCollector(
        id: widget.mode == Mode.add ? null : widget.selected?.id,
        collectorCode: _codeCtrl.text.trim().toUpperCase(),
        collectorNameThai: _nameThCtrl.text.trim(),
        collectorNameEng: _t(_nameEnCtrl),
        collectorType: _type,
        taxId: _t(_taxIdCtrl),
        branchId: _branchId,
        phone: _t(_phoneCtrl),
        email: _t(_emailCtrl),
        address: _t(_addressCtrl),
        effectiveDateFrom: _from,
        effectiveDateTo: _to,
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
      err = e ? 'Please enter the code' : 'กรุณาระบุรหัส';
    } else if (_nameThCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter the Thai name' : 'กรุณาระบุชื่อภาษาไทย';
    } else if (_from != null && _to != null && _to!.isBefore(_from!)) {
      err = e ? 'Effective "to" date is before the "from" date' : 'วันที่สิ้นสุดก่อนวันที่เริ่มมีผล';
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
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e ? 'An error occurred: $ex' : 'เกิดข้อผิดพลาด: $ex'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickBranch() async {
    final e = _isEnglish;
    final List<Branch> all;
    try {
      all = await Provider.of<BranchService>(context, listen: false).fetchRows();
    } catch (ex) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ? 'Failed to load branches: $ex' : 'โหลดข้อมูลสาขาล้มเหลว: $ex')));
      }
      return;
    }
    final choices = all.where((b) => b.isActive).toList()..sort((a, b) => a.branchCode.compareTo(b.branchCode));
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: Text(e ? 'Select branch' : 'เลือกสาขา', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 500,
          height: 500,
          child: choices.isEmpty
              ? Center(child: Text(e ? 'No branches found' : 'ไม่พบข้อมูลสาขา'))
              : ListView.builder(
                  itemCount: choices.length,
                  itemBuilder: (_, i) {
                    final b = choices[i];
                    final name = e && b.branchNameEng.isNotEmpty ? b.branchNameEng : b.branchNameThai;
                    return ListTile(
                      title: Text('${b.branchCode} — $name'),
                      onTap: () {
                        setState(() {
                          _branchId = b.id;
                          _branchNameThai = b.branchNameThai;
                          _branchLabel = '${b.branchCode} $name';
                        });
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(e ? 'Cancel' : 'ยกเลิก'))],
      ),
    );
  }

  Widget _mainCard() {
    final e = _isEnglish;
    final ro = kitReadOnly;
    final types = e ? arCollectorTypeOptionsEng : arCollectorTypeOptions;
    return kCard(
      title: e ? 'Biller / collector details' : 'ข้อมูลผู้วางบิล / ผู้เก็บเงิน',
      trailing: kLegend(withAuto: false),
      child: kGroups([
        kGroup(1, e ? 'Main' : 'ข้อมูลหลัก', ImKit.gDoc, [
          kRow([
            kTxt(e ? 'Code *' : 'รหัส *', _codeCtrl, editable: widget.mode == Mode.add, cap: TextCapitalization.characters),
            kDd<String>(e ? 'Type' : 'ชนิด', _type, [for (final t in types.entries) DropdownMenuItem(value: t.key, child: Text(t.value))],
                ro ? null : (v) => setState(() => _type = v ?? 'EMPLOYEE'), auto: false),
          ]),
          kTxt(e ? 'Name (TH) *' : 'ชื่อ (ไทย) *', _nameThCtrl),
          kTxt(e ? 'Name (EN)' : 'ชื่อ (อังกฤษ)', _nameEnCtrl),
        ]),
        kGroup(2, e ? 'Contact' : 'ติดต่อ', ImKit.gParty, [
          kRow([kTxt(e ? 'Phone' : 'โทรศัพท์', _phoneCtrl), kTxt(e ? 'Email' : 'อีเมล', _emailCtrl)]),
          kTxt(e ? 'Address' : 'ที่อยู่', _addressCtrl),
          if (_type != 'EMPLOYEE') kTxt(e ? 'Tax ID' : 'เลขผู้เสียภาษี', _taxIdCtrl, digitsOnly: true),
        ]),
        kGroup(3, e ? 'Effective period and branch' : 'ช่วงเวลามีผลและสาขา', ImKit.gFin, [
          kRow([
            kDate(e ? 'Effective from' : 'มีผลตั้งแต่', _from, ro ? null : (d) => setState(() => _from = d)),
            kDate(e ? 'Effective to' : 'ถึงวันที่', _to, ro ? null : (d) => setState(() => _to = d)),
          ]),
          kNote(e ? 'Leave blank = no limit' : 'เว้นว่าง = ไม่จำกัด'),
          kFk(
            label: e ? 'Branch' : 'สาขา',
            text: _branchLabel ?? _branchNameThai ?? '',
            hasValue: _branchId != null,
            onSearch: _pickBranch,
            onClear: () => setState(() {
              _branchId = null;
              _branchNameThai = null;
              _branchLabel = null;
            }),
          ),
          kChecks([kCk(e ? 'Active' : 'ใช้งาน', _isActive, ro ? null : (v) => setState(() => _isActive = v))]),
        ]),
      ]),
    );
  }

  Widget _customersCard() {
    final e = _isEnglish;
    final s = _summary;
    if (s == null) {
      return kCard(
        title: e ? 'Customers handled' : 'ลูกค้าที่รับผิดชอบ',
        child: _summaryLoading
            ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            : kNote(e ? 'Could not load customers' : 'โหลดรายชื่อลูกค้าไม่ได้'),
      );
    }
    return kCard(
      title: e ? 'Customers handled' : 'ลูกค้าที่รับผิดชอบ',
      count: e
          ? 'billing ${s.billingCount} · collecting ${s.collectionCount} — set on the customer screen'
          : 'วางบิล ${s.billingCount} ราย · เก็บเงิน ${s.collectionCount} ราย — กำหนดที่หน้าจอลูกค้า',
      trailing: kGhost(e ? 'Customers' : 'ข้อมูลลูกค้า', Icons.open_in_new,
          () => ImKit.openMenu(context, 'ArCustomerScreen', 'ข้อมูลลูกค้า', 'Customers', e)),
      padding: EdgeInsets.zero,
      child: kTable(
        [
          KCol(e ? 'Code' : 'รหัส', 3),
          KCol(e ? 'Customer' : 'ลูกค้า', 7),
          KCol(e ? 'Duty' : 'หน้าที่', 4),
          KCol(e ? 'Open docs' : 'เอกสารค้าง', 2, num: true),
          KCol(e ? 'Outstanding' : 'ยอดค้าง', 3, num: true),
          KCol(e ? 'Overdue' : 'เกินกำหนด', 3, num: true),
        ],
        [
          for (final c in s.customers)
            [
              kCell(c.code, mono: true, color: c.isActive ? null : ImKit.ink3),
              kCell(c.name(e), color: c.isActive ? null : ImKit.ink3),
              Wrap(spacing: 4, children: [
                if (c.isBiller) ImKit.chip(e ? 'Billing' : 'วางบิล', ImKit.blueSoft, ImKit.blue),
                if (c.isCollector) ImKit.chip(e ? 'Collecting' : 'เก็บเงิน', ImKit.okSoft, ImKit.ok),
              ]),
              kCell(c.openCount == 0 ? '' : '${c.openCount}', mono: true),
              kCell(c.outstanding.abs() < 0.005 ? '' : _money.format(c.outstanding), mono: true),
              kCell(c.overdue < 0.005 ? '' : _money.format(c.overdue), mono: true, color: ImKit.red),
            ],
        ],
        minWidth: 760,
        empty: e ? 'No customers assigned yet' : 'ยังไม่มีลูกค้าที่กำหนดให้คนนี้',
      ),
    );
  }

  Widget _kpis() {
    final e = _isEnglish;
    final s = _summary;
    if (s == null) return kKpis(const [], loading: _summaryLoading);
    return kKpis([
      ImKpi(e ? 'Customers collecting' : 'ลูกค้าที่เก็บเงิน', '${s.collectionCount}', e ? 'as collector' : 'เป็นผู้เก็บเงิน'),
      ImKpi(e ? 'Customers billing' : 'ลูกค้าที่วางบิล', '${s.billingCount}', e ? 'as biller' : 'เป็นผู้วางบิล'),
      ImKpi(e ? 'To collect' : 'ยอดที่ต้องตามเก็บ', _money.format(s.outstanding),
          e ? '${s.openDocs} open doc(s)' : 'เอกสารค้าง ${s.openDocs} ใบ'),
      ImKpi(e ? 'Overdue' : 'เกินกำหนด', _money.format(s.overdue),
          s.overdueCustomers == 0 ? (e ? 'none' : 'ไม่มี') : (e ? '${s.overdueCustomers} customer(s)' : '${s.overdueCustomers} ราย'),
          warn: s.overdue > 0.005,
          onTap: () => ImKit.openMenu(context, 'ArAgingReportScreen', 'รายงานอายุลูกหนี้', 'AR Aging Report', e)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final e = isEnglish;
    if (widget.isPlaceholder) {
      return kPlaceholder(Icons.badge_outlined,
          e ? 'Select a biller / collector on the left, or press "Add"' : 'เลือกผู้วางบิล/ผู้เก็บเงินจากรายการด้านซ้าย หรือกด "เพิ่ม"');
    }
    final ro = kitReadOnly;
    final isAdd = widget.mode == Mode.add;
    final saved = !isAdd && widget.selected?.id != null;
    final name = e && _nameEnCtrl.text.trim().isNotEmpty ? _nameEnCtrl.text.trim() : _nameThCtrl.text.trim();
    final cur = _build();
    return kPage(
      header: kHeaderBar(
        code: isAdd ? null : widget.selected?.collectorCode,
        title: isAdd ? (e ? 'New biller / collector' : 'ผู้วางบิล/ผู้เก็บเงินใหม่') : name,
        badges: [
          if (!isAdd) ImKit.activeChip(_isActive, e),
          ImKit.chip(arCollectorTypeLabel(_type, e), ImKit.blueSoft, ImKit.blue),
          if (_from != null || _to != null) arCollectorEffectiveChip(cur, e),
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
        ),
      ),
      top: saved ? _kpis() : null,
      sections: [
        (0, e ? 'Details' : 'ข้อมูล', _mainCard()),
        if (saved) (1, e ? 'Customers' : 'ลูกค้าที่รับผิดชอบ', _customersCard()),
      ],
    );
  }
}
