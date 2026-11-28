// lib/cm/screens/cm_bank_file_format_screen.dart — สร้างรูปแบบไฟล์โอนเงินผ่านธนาคาร แบบ B ของ IM (user 2026-11-28)
//   ซ้าย: การ์ดรูปแบบ (ธนาคาร ชนิดไฟล์ จำนวนคอลัมน์) + ตัวกรอง / ขวา: โหมดดู → แก้ไข / สำเนา / ลบ ที่แถบหัว
//   ส่วน: ข้อมูลรูปแบบ / คอลัมน์ (ตำแหน่งตัวอักษร, กดแถวเพื่อแก้) / ตัวอย่างไฟล์ (backend สร้างด้วยตัวเดียวกับไฟล์จริง)
//   หน้าสร้างไฟล์โอนจ่ายอ่านค่าที่บันทึกที่นี่จริง (utils/cmBankFile.js) — เดิมอ่านชื่อคอลัมน์คนละชุดจึงได้คอลัมน์ว่าง
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../im/widgets/im_master_kit.dart';
import '../../cd/models/cd_bank.dart';
import '../../cd/services/cd_bank_service.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../models/cm_bank_file_format.dart';
import '../services/cm_bank_file_format_service.dart';

// ── ฟิลด์ที่ใช้ได้ (ตรงกับ utils/cmBankFile.js ฝั่ง backend) ────────────────────────────
class _FieldDef {
  final String code;
  final String label;
  final String labelEng;
  final String type; // 'text' | 'date' | 'decimal' | 'integer' | 'constant'
  final String noteTh;
  final String noteEn;
  const _FieldDef(this.code, this.label, this.labelEng, this.type, [this.noteTh = '', this.noteEn = '']);
  String labelFor(bool e) => e ? labelEng : label;
  String noteFor(bool e) => e ? noteEn : noteTh;
}

const _fields = [
  _FieldDef('payment_date', 'วันที่ชำระ', 'Payment date', 'date'),
  _FieldDef('amount', 'จำนวนเงิน', 'Amount', 'decimal', 'สกุลเงินของรายการจ่าย', 'in the payment currency'),
  _FieldDef('currency', 'สกุลเงิน', 'Currency', 'text'),
  _FieldDef('vendor_code', 'รหัสเจ้าหนี้', 'Vendor code', 'text'),
  _FieldDef('vendor_name', 'ชื่อเจ้าหนี้', 'Vendor name', 'text'),
  _FieldDef('vendor_tax_id', 'เลขประจำตัวผู้เสียภาษี', 'Vendor tax ID', 'text'),
  _FieldDef('bank_code', 'รหัสธนาคาร (ผู้รับ)', 'Payee bank code', 'text', 'จับคู่ชื่อธนาคารของผู้ขายกับข้อมูลธนาคาร', 'matched from the vendor bank name'),
  _FieldDef('bank_branch_code', 'สาขาธนาคาร (ผู้รับ)', 'Payee bank branch', 'text', 'ชื่อสาขาที่ผู้ขายกรอก (ยังไม่มีรหัสสาขา)', 'branch name as entered (no branch code yet)'),
  _FieldDef('account_number', 'เลขที่บัญชี (ผู้รับ)', 'Payee account no.', 'text', 'ตัด - และช่องว่างออก', 'dashes and spaces removed'),
  _FieldDef('account_name', 'ชื่อบัญชี (ผู้รับ)', 'Payee account name', 'text'),
  _FieldDef('reference', 'อ้างอิง', 'Reference', 'text', 'หมายเหตุรายการจ่าย หรือเลขที่เอกสาร', 'payment remark or document no.'),
  _FieldDef('doc_number', 'เลขที่เอกสาร', 'Document no.', 'text'),
  _FieldDef('sequence', 'ลำดับที่', 'Sequence', 'integer'),
  _FieldDef('company_code', 'เลขผู้เสียภาษีบริษัท', 'Company tax ID', 'text', 'ถ้าธนาคารให้รหัสบริษัทเอง ใช้ "ค่าคงที่"', 'use "Constant" for a bank-assigned company ID'),
  _FieldDef('branch_code', 'รหัสสาขา (บัญชีที่จ่าย)', 'Branch code (paying account)', 'text'),
  _FieldDef('bank_own_account_no', 'เลขที่บัญชีที่จ่าย', 'Paying account no.', 'text'),
  _FieldDef('constant', 'ค่าคงที่', 'Constant', 'constant'),
];

_FieldDef _fieldOf(String code) => _fields.firstWhere((f) => f.code == code, orElse: () => _FieldDef(code, code, code, 'text'));

const _dateFormats = ['YYYYMMDD', 'DDMMYYYY', 'MMDDYYYY', 'DD/MM/YYYY', 'YYYY-MM-DD', 'YYYYMM'];

class CmBankFileFormatScreen extends StatefulWidget {
  const CmBankFileFormatScreen({super.key});

  @override
  State<CmBankFileFormatScreen> createState() => _CmBankFileFormatScreenState();
}

class _CmBankFileFormatScreenState extends State<CmBankFileFormatScreen> with AutomaticKeepAliveClientMixin {
  final GlobalKey<_FormatListState> _listKey = GlobalKey();
  final GlobalKey<_FormatDetailState> _detailKey = GlobalKey();
  Mode _mode = Mode.none;
  CmBankFileFormat? _selected;
  CmBankFileFormat? _copyFrom;
  bool _fullLoaded = false;
  int _requestSeq = 0;
  bool _isEnglish = false;
  final _svc = CmBankFileFormatService();

  @override
  bool get wantKeepAlive => true;

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
    final s = _selected;
    if (s == null) return;
    setState(() {
      _mode = Mode.add;
      _copyFrom = s;
      _selected = null;
      _requestSeq++;
    });
  }

  void _onEdit() => setState(() {
        _mode = Mode.edit;
        _requestSeq++;
      });

  Future<void> _onView(CmBankFileFormat f) async {
    if (_mode == Mode.view && _selected?.id == f.id) return;
    if (!await _confirmLeave()) return;
    _show(f);
  }

  void _show(CmBankFileFormat f) {
    setState(() {
      _mode = Mode.view;
      _selected = f;
      _copyFrom = null;
      _fullLoaded = false;
      _requestSeq++;
    });
    _fetchFull(f);
  }

  Future<void> _fetchFull(CmBankFileFormat f) async {
    if (f.id == null) return;
    try {
      final full = await _svc.fetchRow(f.id!);
      if (!mounted || _selected?.id != f.id || _mode != Mode.view) return;
      setState(() {
        _selected = full;
        _fullLoaded = true;
      });
    } catch (_) {}
  }

  void _close() => setState(() {
        _mode = Mode.none;
        _selected = null;
        _copyFrom = null;
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

  Future<void> _onSubmit(CmBankFileFormat f) async {
    final e = _isEnglish;
    final saved = _mode == Mode.add ? await _svc.addRow(f) : await _svc.updateRow(f);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ? 'Saved successfully' : 'บันทึกสำเร็จ')));
    _listKey.currentState?.refresh();
    if (mounted) _show(saved);
  }

  Future<void> _onDelete() async {
    final f = _selected;
    if (f?.id == null) return;
    final e = _isEnglish;
    final l = AppL10n(e);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.confirmDelete),
        content: Text(e ? 'Delete file format "${f!.formatCode} ${f.formatName}"?' : 'ลบรูปแบบไฟล์ "${f!.formatCode} ${f.formatName}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.delete, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.deleteRow(f!.id!);
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
    final view = _mode == Mode.view;
    return ImMasterShell(
      isEnglish: isEnglish,
      initialListWidth: 320,
      barActions: [
        if (canCreate) ImKit.barButton(context, isEnglish ? 'Add format' : 'เพิ่มรูปแบบ', Icons.add, _onAdd, primary: true),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: isEnglish ? 'Refresh' : 'รีเฟรชรายการ',
          onPressed: () async {
            if (!await _confirmLeave()) return;
            _listKey.currentState?.refresh();
            if (_selected != null && _mode != Mode.add) {
              _show(_selected!);
            } else {
              _close();
            }
          },
        ),
      ],
      list: _FormatList(key: _listKey, selectedId: _mode == Mode.view || _mode == Mode.edit ? _selected?.id : null, onTap: _onView),
      detail: _FormatDetail(
        key: _detailKey,
        mode: _mode,
        selected: _mode == Mode.add ? null : _selected,
        copyFrom: _mode == Mode.add ? _copyFrom : null,
        requestSeq: _requestSeq,
        onSubmit: _onSubmit,
        onCancel: view ? _close : _onCancel,
        onEdit: view && canEdit ? (_fullLoaded ? _onEdit : null) : null,
        onDelete: view && canDelete ? _onDelete : null,
        onCopy: view && canCreate ? (_fullLoaded ? _onCopy : null) : null,
      ),
    );
  }
}

bool _isFixed(CmBankFileFormat f) => f.delimiter.isEmpty;
int _lineLength(List<CmBankFileFormatColumn> cols) => cols.fold(0, (s, c) => s + c.length);

String _delimLabel(String d, bool e) => switch (d) {
      '' => e ? 'Fixed width' : 'ความกว้างคงที่',
      ',' => 'CSV',
      '|' => e ? 'Pipe |' : 'คั่นด้วย |',
      r'\t' || '\t' => e ? 'Tab' : 'คั่นด้วยแท็บ',
      ';' => e ? 'Semicolon ;' : 'คั่นด้วย ;',
      _ => e ? 'Delimiter $d' : 'คั่นด้วย $d',
    };

// ---------------------------------------------------------------------------
// รายการรูปแบบ (แผงซ้าย)
// ---------------------------------------------------------------------------
class _FormatList extends StatefulWidget {
  final int? selectedId;
  final ValueChanged<CmBankFileFormat> onTap;
  const _FormatList({super.key, required this.selectedId, required this.onTap});

  @override
  State<_FormatList> createState() => _FormatListState();
}

enum _FFlag { delimited, fixed, inactive }

class _FormatListState extends State<_FormatList> {
  final _search = TextEditingController();
  List<CmBankFileFormat> _rows = [];
  _FFlag? _flag;
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
    try {
      final rows = await CmBankFileFormatService().fetchRows();
      if (mounted) setState(() => _rows = rows);
    } catch (ex) {
      if (mounted) {
        final en = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(en ? 'Failed to load data: $ex' : 'ไม่สามารถโหลดข้อมูลได้: $ex')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  bool _ok(CmBankFileFormat f, _FFlag? flag) => switch (flag) {
        null => true,
        _FFlag.delimited => !_isFixed(f),
        _FFlag.fixed => _isFixed(f),
        _FFlag.inactive => !f.isActive,
      };

  @override
  Widget build(BuildContext context) {
    final e = context.watch<LanguageProvider>().isEnglish;
    final q = _search.text.trim().toLowerCase();
    final base = _rows
        .where((f) =>
            q.isEmpty || f.formatCode.toLowerCase().contains(q) || f.formatName.toLowerCase().contains(q) || (f.bankCode ?? '').toLowerCase().contains(q))
        .toList();
    final shown = base.where((f) => _ok(f, _flag)).toList()..sort((a, b) => a.formatCode.compareTo(b.formatCode));
    int n(_FFlag f) => base.where((x) => _ok(x, f)).length;
    void flag(_FFlag f) => setState(() => _flag = _flag == f ? null : f);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ImMasterListHeader(
        searchCtrl: _search,
        hint: e ? 'Search code / name / bank' : 'ค้นหา รหัส / ชื่อ / ธนาคาร',
        onSearch: (_) => setState(() {}),
        countText: _loading ? (e ? 'Loading...' : 'กำลังโหลด...') : (e ? '${shown.length} format(s)' : 'รูปแบบ ${shown.length} แบบ'),
        filters: [
          ImMasterFilterChip(label: e ? 'All' : 'ทั้งหมด', on: _flag == null, onTap: () => setState(() => _flag = null)),
          ImMasterFilterChip(label: '${e ? 'Delimited' : 'ตัวคั่น'} ${n(_FFlag.delimited)}', on: _flag == _FFlag.delimited, onTap: () => flag(_FFlag.delimited)),
          ImMasterFilterChip(label: '${e ? 'Fixed width' : 'ความกว้างคงที่'} ${n(_FFlag.fixed)}', on: _flag == _FFlag.fixed, onTap: () => flag(_FFlag.fixed)),
          ImMasterFilterChip(label: '${e ? 'Inactive' : 'หยุดใช้'} ${n(_FFlag.inactive)}', on: _flag == _FFlag.inactive, onTap: () => flag(_FFlag.inactive)),
        ],
      ),
      Expanded(
        child: _loading && _rows.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : shown.isEmpty
                ? Center(child: Text(e ? 'No file formats found' : 'ไม่พบรูปแบบไฟล์', style: const TextStyle(color: ImKit.ink2)))
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 2, bottom: 12),
                    itemCount: shown.length,
                    itemBuilder: (_, i) {
                      final f = shown[i];
                      final fixed = _isFixed(f);
                      return ImMasterListCard(
                        code: f.formatCode,
                        chips: [
                          if ((f.bankCode ?? '').isNotEmpty) ImKit.chip(f.bankCode!, ImKit.blueSoft, ImKit.blue),
                          ImKit.chip(_delimLabel(f.delimiter, e), ImKit.ro, ImKit.ink2),
                          if (!f.isActive) ImKit.chip(e ? 'Inactive' : 'หยุดใช้', ImKit.ro, ImKit.ink2),
                        ],
                        name: f.formatName,
                        meta: TextSpan(text: [
                          '.${f.fileExtension}',
                          e ? '${f.columns.length} column(s)' : '${f.columns.length} คอลัมน์',
                          if (fixed && f.columns.isNotEmpty) (e ? '${_lineLength(f.columns)} chars/line' : '${_lineLength(f.columns)} ตัวอักษร/บรรทัด'),
                          if (!fixed && f.hasHeader) (e ? 'with header' : 'มีหัวคอลัมน์'),
                        ].join(' · ')),
                        selected: widget.selectedId != null && widget.selectedId == f.id,
                        active: f.isActive,
                        onTap: () => widget.onTap(f),
                      );
                    },
                  ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// รายละเอียดรูปแบบ (แผงขวา)
// ---------------------------------------------------------------------------
class _FormatDetail extends StatefulWidget {
  final Mode mode;
  final CmBankFileFormat? selected;
  final CmBankFileFormat? copyFrom;
  final int requestSeq;
  final Future<void> Function(CmBankFileFormat) onSubmit;
  final VoidCallback onCancel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onCopy;
  const _FormatDetail({
    super.key,
    required this.mode,
    this.selected,
    this.copyFrom,
    required this.requestSeq,
    required this.onSubmit,
    required this.onCancel,
    this.onEdit,
    this.onDelete,
    this.onCopy,
  });

  @override
  State<_FormatDetail> createState() => _FormatDetailState();
}

class _FormatDetailState extends State<_FormatDetail> with ImMasterKit {
  bool _isEnglish = false;

  @override
  bool get kitEnglish => _isEnglish;
  @override
  bool get kitReadOnly => widget.mode == Mode.view;

  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  String? _bankCode;
  String _ext = 'txt';
  String _delimiter = '';
  bool _hasHeader = false;
  bool _hasFooter = false;
  bool _isActive = true;
  List<CmBankFileFormatColumn> _cols = [];
  List<Bank> _banks = [];
  bool _saving = false;
  String _snapshot = '';

  List<String> _preview = [];
  int? _noBank;
  bool _previewLoading = false;
  Timer? _debounce;
  String _previewFor = '';

  bool get isDirty => !kitReadOnly && widget.mode != Mode.none && _fingerprint() != _snapshot;
  bool get _isCopy => widget.mode == Mode.add && widget.copyFrom != null;

  @override
  void initState() {
    super.initState();
    _applyCurrent();
    _loadBanks();
  }

  @override
  void didUpdateWidget(covariant _FormatDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.requestSeq != oldWidget.requestSeq || widget.selected != oldWidget.selected || widget.mode != oldWidget.mode) {
      final onlyFull = widget.requestSeq == oldWidget.requestSeq && widget.mode == oldWidget.mode && widget.selected?.id == oldWidget.selected?.id;
      _applyCurrent();
      if (!onlyFull) kScrollTop();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBanks() async {
    try {
      final b = await BankService().fetchRows();
      if (mounted) setState(() => _banks = b.where((x) => x.isActive).toList()..sort((a, c) => a.bankCode.compareTo(c.bankCode)));
    } catch (_) {}
  }

  CmBankFileFormatColumn _cloneCol(CmBankFileFormatColumn c) => CmBankFileFormatColumn.fromJson(c.toJson());

  void _applyCurrent() {
    final d = widget.mode == Mode.add ? widget.copyFrom : widget.selected;
    _codeCtrl.text = _isCopy ? '' : (d?.formatCode ?? '');
    _nameCtrl.text = d?.formatName ?? '';
    _bankCode = d?.bankCode;
    _ext = d?.fileExtension ?? 'txt';
    _delimiter = d?.delimiter ?? '';
    _hasHeader = d?.hasHeader ?? false;
    _hasFooter = d?.hasFooter ?? false;
    _isActive = _isCopy ? true : (d?.isActive ?? true);
    _cols = [for (final c in d?.columns ?? const <CmBankFileFormatColumn>[]) _cloneCol(c)];
    _snapshot = widget.mode == Mode.add ? '' : _fingerprint();
    _schedulePreview(now: true);
  }

  CmBankFileFormat _build() => CmBankFileFormat(
        id: widget.mode == Mode.add ? null : widget.selected?.id,
        formatCode: _codeCtrl.text.trim().toUpperCase(),
        formatName: _nameCtrl.text.trim(),
        bankCode: (_bankCode ?? '').isEmpty ? null : _bankCode,
        fileExtension: _ext.trim().isEmpty ? 'txt' : _ext.trim(),
        delimiter: _delimiter,
        hasHeader: _hasHeader,
        hasFooter: _hasFooter,
        isActive: _isActive,
        columns: _cols,
      );

  String _fingerprint() {
    try {
      return jsonEncode(_build().toJson());
    } catch (_) {
      return '';
    }
  }

  void _changed(VoidCallback fn) {
    setState(fn);
    _schedulePreview();
  }

  // ตัวอย่างไฟล์จาก backend (สร้างด้วยตัวเดียวกับไฟล์จริง) — หน่วง 400ms หลังแก้
  void _schedulePreview({bool now = false}) {
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: now ? 0 : 400), () async {
      if (!mounted || widget.mode == Mode.none) return;
      final key = _fingerprint();
      if (key == _previewFor && _preview.isNotEmpty) return;
      _previewFor = key;
      setState(() => _previewLoading = true);
      try {
        final r = await CmBankFileFormatService().preview(_build());
        if (mounted && _previewFor == key) {
          setState(() {
            _preview = r.lines;
            _noBank = r.vendorsWithoutBank;
          });
        }
      } catch (_) {
        if (mounted && _previewFor == key) setState(() => _preview = []);
      }
      if (mounted) setState(() => _previewLoading = false);
    });
  }

  Future<void> _submit() async {
    final e = _isEnglish;
    String? err;
    if (_codeCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter the format code' : 'โปรดระบุรหัสรูปแบบ';
    } else if (_nameCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter the format name' : 'โปรดระบุชื่อรูปแบบ';
    } else if (_cols.isEmpty) {
      err = e ? 'Please add at least one column' : 'โปรดเพิ่มคอลัมน์อย่างน้อย 1 คอลัมน์';
    } else if (_delimiter.isEmpty && _cols.any((c) => c.length <= 0)) {
      err = e ? 'Every column needs a length in a fixed-width file' : 'ไฟล์ความกว้างคงที่ ทุกคอลัมน์ต้องระบุความยาว';
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

  // ─── คอลัมน์ ──────────────────────────────────────────────────────────────────
  Future<void> _addColumn() async {
    final e = _isEnglish;
    final def = await showDialog<_FieldDef>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(e ? 'Add column' : 'เพิ่มคอลัมน์'),
        children: [
          for (final f in _fields)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(f),
              child: Text(f.noteFor(e).isEmpty ? f.labelFor(e) : '${f.labelFor(e)}  ·  ${f.noteFor(e)}'),
            ),
        ],
      ),
    );
    if (def == null) return;
    final num = def.type == 'decimal' || def.type == 'integer';
    final col = CmBankFileFormatColumn(
      fieldCode: def.code,
      columnLabel: def.label,
      length: def.type == 'date' ? 8 : (def.type == 'decimal' ? 15 : (def.type == 'constant' ? 1 : 20)),
      align: num ? 'R' : 'L',
      padChar: num ? '0' : ' ',
    );
    final ok = await _editColumn(col, isNew: true);
    if (ok == true) _changed(() => _cols.add(col));
  }

  // แก้คอลัมน์ในหน้าต่าง: คืน true = บันทึก, 'delete' = ลบ, 'up'/'down' = เลื่อน
  Future<Object?> _editColumn(CmBankFileFormatColumn c, {bool isNew = false, int? index}) async {
    final e = _isEnglish;
    final def = _fieldOf(c.fieldCode);
    final label = TextEditingController(text: c.columnLabel);
    final length = TextEditingController(text: '${c.length}');
    final pad = TextEditingController(text: c.padChar == ' ' ? '' : c.padChar);
    final constant = TextEditingController(text: c.constantValue ?? '');
    String align = c.align;
    String dateFmt = _dateFormats.contains(c.dateFormat) ? c.dateFormat : 'YYYYMMDD';
    int dp = c.decimalPlaces;
    InputDecoration dec(String l, {String? hint}) => InputDecoration(labelText: l, hintText: hint, isDense: true, border: const OutlineInputBorder());
    final r = await showDialog<Object>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        return AlertDialog(
          title: Text('${isNew ? (e ? 'New column' : 'คอลัมน์ใหม่') : (e ? 'Column' : 'คอลัมน์')}: ${def.labelFor(e)}'),
          content: SizedBox(
            width: 440,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (def.noteFor(e).isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(def.noteFor(e), style: const TextStyle(fontSize: 12, color: ImKit.blue))),
              TextField(controller: label, decoration: dec(e ? 'Header label' : 'ชื่อหัวคอลัมน์')),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: length, keyboardType: TextInputType.number, decoration: dec(e ? 'Length' : 'ความยาว'))),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: align,
                    isDense: true,
                    decoration: dec(e ? 'Align' : 'ชิด'),
                    items: [
                      DropdownMenuItem(value: 'L', child: Text(e ? 'Left' : 'ซ้าย')),
                      DropdownMenuItem(value: 'R', child: Text(e ? 'Right' : 'ขวา')),
                    ],
                    onChanged: (v) => setDlg(() => align = v ?? 'L'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: pad, maxLength: 1, decoration: dec(e ? 'Pad char' : 'ตัวเติม', hint: e ? 'blank = space' : 'ว่าง = ช่องว่าง').copyWith(counterText: ''))),
              ]),
              if (def.type == 'date') ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: dateFmt,
                  isDense: true,
                  decoration: dec(e ? 'Date format' : 'รูปแบบวันที่'),
                  items: [for (final f in _dateFormats) DropdownMenuItem(value: f, child: Text(f))],
                  onChanged: (v) => setDlg(() => dateFmt = v ?? 'YYYYMMDD'),
                ),
              ],
              if (def.type == 'decimal') ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: dp,
                  isDense: true,
                  decoration: dec(e ? 'Decimal places' : 'ทศนิยม'),
                  items: [for (final d in [0, 1, 2, 3, 4]) DropdownMenuItem(value: d, child: Text(e ? '$d places' : '$d ตำแหน่ง'))],
                  onChanged: (v) => setDlg(() => dp = v ?? 2),
                ),
              ],
              if (def.type == 'constant') ...[
                const SizedBox(height: 10),
                TextField(controller: constant, decoration: dec(e ? 'Constant value' : 'ค่าคงที่')),
              ],
              const SizedBox(height: 8),
              Text(
                  e
                      ? 'Fixed-width files cut / pad each value to the length; amounts have no decimal point (186400.00 → 18640000). Delimited files ignore the length.'
                      : 'ไฟล์ความกว้างคงที่ ตัด/เติมค่าให้ครบความยาว จำนวนเงินไม่มีจุดทศนิยม (186400.00 → 18640000) · ไฟล์มีตัวคั่นไม่ใช้ความยาว',
                  style: const TextStyle(fontSize: 11.5, color: ImKit.ink3)),
            ]),
          ),
          actions: [
            if (!isNew) ...[
              IconButton(tooltip: e ? 'Move up' : 'เลื่อนขึ้น', icon: const Icon(Icons.arrow_upward), onPressed: index == 0 ? null : () => Navigator.of(ctx).pop('up')),
              IconButton(
                  tooltip: e ? 'Move down' : 'เลื่อนลง',
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: index == _cols.length - 1 ? null : () => Navigator.of(ctx).pop('down')),
              TextButton(onPressed: () => Navigator.of(ctx).pop('delete'), child: Text(e ? 'Delete' : 'ลบ', style: const TextStyle(color: Colors.red))),
            ],
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(e ? 'Cancel' : 'ยกเลิก')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(e ? 'OK' : 'ตกลง')),
          ],
        );
      }),
    );
    if (r == true) {
      c.columnLabel = label.text.trim();
      c.length = int.tryParse(length.text.trim()) ?? c.length;
      c.align = align;
      c.padChar = pad.text.isEmpty ? ' ' : pad.text;
      c.dateFormat = dateFmt;
      c.decimalPlaces = dp;
      c.constantValue = constant.text.isEmpty ? null : constant.text;
    }
    for (final t in [label, length, pad, constant]) {
      t.dispose();
    }
    return r;
  }

  Future<void> _onTapColumn(int i) async {
    if (kitReadOnly) return;
    final r = await _editColumn(_cols[i], index: i);
    if (r == true) {
      _changed(() {});
    } else if (r == 'delete') {
      _changed(() => _cols.removeAt(i));
    } else if (r == 'up' && i > 0) {
      _changed(() => _cols.insert(i - 1, _cols.removeAt(i)));
    } else if (r == 'down' && i < _cols.length - 1) {
      _changed(() => _cols.insert(i + 1, _cols.removeAt(i)));
    }
  }

  // ─── การ์ด ───────────────────────────────────────────────────────────────────
  Widget _mainCard() {
    final e = _isEnglish;
    final ro = kitReadOnly;
    final bankItems = [
      DropdownMenuItem<String>(value: '', child: Text(e ? '— Not specified —' : '— ไม่ระบุ —')),
      for (final b in _banks) DropdownMenuItem(value: b.bankCode, child: Text('${b.bankCode} ${e && b.bankNameEng.isNotEmpty ? b.bankNameEng : b.bankNameThai}', overflow: TextOverflow.ellipsis)),
      if ((_bankCode ?? '').isNotEmpty && !_banks.any((b) => b.bankCode == _bankCode)) DropdownMenuItem(value: _bankCode!, child: Text(_bankCode!)),
    ];
    final delims = {'': _delimLabel('', e), ',': _delimLabel(',', e), '|': _delimLabel('|', e), r'\t': _delimLabel(r'\t', e), ';': _delimLabel(';', e)};
    if (!delims.containsKey(_delimiter)) delims[_delimiter] = _delimLabel(_delimiter, e);
    final exts = {'txt', 'csv', 'dat', _ext};
    return kCard(
      title: e ? 'Format details' : 'ข้อมูลรูปแบบ',
      trailing: kLegend(withAuto: false),
      child: kGroups([
        kGroup(1, e ? 'Main' : 'ข้อมูลหลัก', ImKit.gDoc, [
          kRow([
            kTxt(e ? 'Code *' : 'รหัส *', _codeCtrl, editable: widget.mode == Mode.add, cap: TextCapitalization.characters),
            kDd<String>(e ? 'Bank' : 'ธนาคาร', _bankCode ?? '', bankItems, ro ? null : (v) => setState(() => _bankCode = v), auto: false),
          ]),
          kTxt(e ? 'Format name *' : 'ชื่อรูปแบบ *', _nameCtrl),
        ]),
        kGroup(2, e ? 'File layout' : 'โครงสร้างไฟล์', ImKit.gFin, [
          kRow([
            kDd<String>(e ? 'File extension' : 'นามสกุลไฟล์', _ext, [for (final x in exts) DropdownMenuItem(value: x, child: Text(x))],
                ro ? null : (v) => _changed(() => _ext = v ?? 'txt'), auto: false),
            kDd<String>(e ? 'Delimiter' : 'ตัวคั่น', _delimiter, [for (final d in delims.entries) DropdownMenuItem(value: d.key, child: Text(d.value))],
                ro ? null : (v) => _changed(() => _delimiter = v ?? ''), auto: false),
          ]),
          kChecks([
            kCk(e ? 'Header line' : 'มีบรรทัดหัว', _hasHeader, ro ? null : (v) => _changed(() => _hasHeader = v)),
            kCk(e ? 'Total line at the end' : 'มีบรรทัดสรุปท้าย', _hasFooter, ro ? null : (v) => _changed(() => _hasFooter = v)),
            kCk(e ? 'Active' : 'ใช้งาน', _isActive, ro ? null : (v) => setState(() => _isActive = v)),
          ]),
          kNote(e
              ? 'Header = column labels · total line = TOTAL, count, total amount'
              : 'บรรทัดหัว = ชื่อหัวคอลัมน์ · บรรทัดสรุป = TOTAL จำนวนรายการ ยอดรวม'),
        ]),
      ]),
    );
  }

  Widget _columnsCard() {
    final e = _isEnglish;
    final ro = kitReadOnly;
    final fixed = _delimiter.isEmpty;
    var pos = 1;
    final rows = <List<Widget>>[];
    for (var i = 0; i < _cols.length; i++) {
      final c = _cols[i];
      final def = _fieldOf(c.fieldCode);
      final from = pos;
      final to = pos + c.length - 1;
      pos += c.length;
      rows.add([
        kCell('${i + 1}', mono: true),
        kCell(def.type == 'constant' ? '${def.labelFor(e)} "${c.constantValue ?? ''}"' : def.labelFor(e)),
        kCell(c.columnLabel),
        kCell(fixed ? '${c.length}' : '', mono: true),
        kCell(c.align == 'R' ? (e ? 'Right' : 'ขวา') : (e ? 'Left' : 'ซ้าย')),
        kCell(c.padChar == ' ' ? (e ? 'space' : 'ช่องว่าง') : c.padChar, mono: true),
        kCell(switch (def.type) {
          'date' => c.dateFormat,
          'decimal' => e ? '${c.decimalPlaces} dp${fixed ? ', no point' : ''}' : '${c.decimalPlaces} ทศนิยม${fixed ? ' ไม่มีจุด' : ''}',
          _ => '',
        }),
        kCell(fixed ? '$from–$to' : '', mono: true),
      ]);
    }
    return kCard(
      title: e ? 'Columns (${_cols.length})' : 'คอลัมน์ (${_cols.length})',
      count: ro ? (e ? 'In file order' : 'เรียงตามลำดับในไฟล์') : (e ? 'Tap a row to edit, move or delete' : 'กดที่แถวเพื่อแก้ไข เลื่อน หรือลบ'),
      trailing: ro ? null : kGhost(e ? 'Column' : 'คอลัมน์', Icons.add, _addColumn),
      padding: EdgeInsets.zero,
      child: kTable(
        [
          KCol('#', 1),
          KCol(e ? 'Data' : 'ข้อมูล', 6),
          KCol(e ? 'Header label' : 'ชื่อหัวคอลัมน์', 5),
          KCol(e ? 'Length' : 'ความยาว', 2, num: true),
          KCol(e ? 'Align' : 'ชิด', 2),
          KCol(e ? 'Pad' : 'เติม', 2),
          KCol(e ? 'Format' : 'รูปแบบ', 4),
          KCol(e ? 'Position' : 'ตำแหน่ง', 3, num: true),
        ],
        rows,
        onTap: ro ? null : [for (var i = 0; i < _cols.length; i++) () => _onTapColumn(i)],
        minWidth: 820,
        empty: ro ? (e ? 'No columns' : 'ยังไม่มีคอลัมน์') : (e ? 'No columns yet — press "+ Column"' : 'ยังไม่มีคอลัมน์ — กด "+ คอลัมน์"'),
      ),
    );
  }

  Widget _previewCard() {
    final e = _isEnglish;
    return kCard(
      title: e ? 'Sample file' : 'ตัวอย่างไฟล์',
      count: e ? '2 sample payments · built by the same code as the real file' : 'ข้อมูลตัวอย่าง 2 รายการ · สร้างด้วยโค้ดเดียวกับไฟล์จริง',
      trailing: _previewLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFFF4F6F5), borderRadius: BorderRadius.circular(6)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              _preview.isEmpty ? (e ? '(no output — add columns)' : '(ยังไม่มีข้อมูล — เพิ่มคอลัมน์)') : _preview.join('\n'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 6),
        kNote(e
            ? 'Fixed-width lengths count characters; Thai vowels and tone marks each count as one'
            : 'ความยาวแบบความกว้างคงที่นับเป็นตัวอักษร สระและวรรณยุกต์ไทยนับเป็น 1 ตัวต่อเครื่องหมาย'),
      ]),
    );
  }

  Widget _kpis() {
    final e = _isEnglish;
    final fixed = _delimiter.isEmpty;
    return kKpis([
      ImKpi(e ? 'Columns' : 'คอลัมน์', '${_cols.length}', fixed ? (e ? '${_lineLength(_cols)} chars/line' : '${_lineLength(_cols)} ตัวอักษร/บรรทัด') : _delimLabel(_delimiter, e)),
      ImKpi(e ? 'File' : 'ไฟล์', '.$_ext', [if (_hasHeader) (e ? 'header' : 'มีบรรทัดหัว'), if (_hasFooter) (e ? 'total line' : 'มีบรรทัดสรุป')].join(' · ')),
      ImKpi(e ? 'Vendors without bank account' : 'ผู้ขายไม่มีบัญชีรับโอน', _noBank == null ? '—' : '$_noBank',
          e ? 'payee account no. will be blank' : 'จะได้เลขบัญชีผู้รับว่างในไฟล์',
          warn: (_noBank ?? 0) > 0, onTap: () => ImKit.openMenu(context, 'ApVendorScreen', 'ข้อมูลผู้ขาย', 'Vendors', e)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final e = isEnglish;
    if (widget.mode == Mode.none) {
      return kPlaceholder(Icons.description_outlined, e ? 'Select a format on the left, or press "Add format"' : 'เลือกรูปแบบจากรายการด้านซ้าย หรือกด "เพิ่มรูปแบบ"');
    }
    final ro = kitReadOnly;
    final isAdd = widget.mode == Mode.add;
    return kPage(
      header: kHeaderBar(
        code: isAdd ? null : widget.selected?.formatCode,
        title: isAdd
            ? (_isCopy
                ? (e ? 'New format (copy of ${widget.copyFrom!.formatCode})' : 'รูปแบบใหม่ (สำเนาจาก ${widget.copyFrom!.formatCode})')
                : (e ? 'New file format' : 'รูปแบบไฟล์ใหม่'))
            : _nameCtrl.text.trim(),
        badges: [
          if (!isAdd) ImKit.activeChip(_isActive, e),
          ImKit.chip(_delimLabel(_delimiter, e), ImKit.blueSoft, ImKit.blue),
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
          extra: [if (widget.onCopy != null) DocBarAction(e ? 'Copy as new' : 'สำเนาเป็นรูปแบบใหม่', widget.onCopy, fg: kInk)],
        ),
      ),
      top: _kpis(),
      sections: [
        (0, e ? 'Main' : 'ข้อมูลหลัก', _mainCard()),
        (1, e ? 'Columns' : 'คอลัมน์', _columnsCard()),
        (2, e ? 'Sample file' : 'ตัวอย่างไฟล์', _previewCard()),
      ],
    );
  }
}
