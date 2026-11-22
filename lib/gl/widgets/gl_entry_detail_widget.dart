import 'package:anan/cd/models/cd_branch.dart';
import 'package:anan/cd/models/cd_currency.dart';
import 'package:anan/cd/services/cd_branch_service.dart';
import 'package:anan/cd/services/cd_currency_service.dart';
import 'package:anan/gl/services/gl_account_service.dart';
import 'package:anan/sa/services/sa_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/services/sa_language_provider.dart';
import '../models/gl_account.dart';
import '../models/gl_dimension.dart';
import '../models/gl_entry.dart';
import '../models/gl_period.dart';
import '../services/gl_dimension_service.dart';
import '../services/gl_entry_service.dart';
import '../services/gl_period_service.dart';
import 'gl_dimension_picker_field.dart';
import '../../sa/models/sa_module_document.dart';
import '../../sa/widgets/sa_document_reverse_widgets.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../../sa/widgets/sa_doc_list_kit.dart';

class GlEntryDetailWidget extends StatefulWidget {
  final int? entryId;
  final bool viewOnly;
  final int resetKey;
  final VoidCallback onSaveSuccess;
  final VoidCallback onCancel;
  final bool canDelete;
  /// ปุ่มของเอกสารแสดงบน AppBar ของหน้าจอแม่ (แทนแถบปุ่มเดิม)
  final DocAppBarActions? actions;

  const GlEntryDetailWidget({
    super.key,
    this.entryId,
    this.viewOnly = false,
    this.resetKey = 0,
    required this.onSaveSuccess,
    required this.onCancel,
    this.canDelete = true,
    this.actions,
  });

  @override
  State<GlEntryDetailWidget> createState() => _GlEntryDetailWidgetState();
}

class _GlEntryDetailWidgetState extends State<GlEntryDetailWidget> implements DocAppBarActionsHost {
  bool _isEnglish = false;
  final _formKey = GlobalKey<FormState>();
  final GlEntryService _service = GlEntryService();
  final AccountService _accountService = AccountService();
  final BranchService _branchService = BranchService();
  final CurrencyService _currencyService = CurrencyService();
  final PeriodService _periodService = PeriodService();
  final GlDimensionService _dimService = GlDimensionService();
  bool _isLoading = false;

  List<PostingPeriod> _openPeriods = [];

  GlEntryHeader _header = GlEntryHeader(
    docId: 0,
    docDate: DateTime.now(),
    postingDate: DateTime.now(),
    currencyId: 1,
    exchangeRate: 1.0,
  );
  List<GlEntryDetail> _details = [];
  List<ModuleDocument> _allowedDocTypes = [];
  List<ModuleDocument> _allDocTypes = [];
  ModuleDocument? _selectedRefDocType;

  List<Account> _accounts = [];
  List<Branch> _branches = [];
  List<Currency> _currencies = [];
  String _baseCurrency = CurrencyService.baseCode;

  List<GlDimensionType> _dimTypes = [];
  final Map<String, List<GlDimensionValue>> _dimValues = {};

  ModuleDocument? _selectedDocType;
  Currency? _selectedCurrency;
  bool _isReadOnly = false;
  bool _headerExpanded = true;

  List<TextEditingController> _debitCtrls = [];
  List<TextEditingController> _creditCtrls = [];
  List<TextEditingController> _descCtrls = [];

  @override
  void initState() {
    super.initState();
    widget.actions?.attach(this);
    _initMasterData();
  }

  @override
  void dispose() {
    widget.actions?.detach(this);
    _lineHScroll.dispose();
    for (final c in _debitCtrls) c.dispose();
    for (final c in _creditCtrls) c.dispose();
    for (final c in _descCtrls) c.dispose();
    super.dispose();
  }

  Future<void> _initMasterData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _service.fetchRowsByModuleUserId(),
        _accountService.fetchRowsControlAccount(),
        _branchService.fetchRows(),
        _currencyService.fetchActiveRows(),
        _service.fetchRows(),
        _periodService.fetchOpenGlPeriods(),
        _dimService.fetchActiveTypes(),
      ]);
      _allowedDocTypes = results[0] as List<ModuleDocument>;
      _accounts = results[1] as List<Account>;
      _branches = results[2] as List<Branch>;
      _currencies = results[3] as List<Currency>;
      _allDocTypes = results[4] as List<ModuleDocument>;
      _openPeriods = results[5] as List<PostingPeriod>;
      _dimTypes = results[6] as List<GlDimensionType>;

      final dimValueResults = await Future.wait(
        _dimTypes.map((t) => _dimService.fetchValuesByType(t.typeCode)),
      );
      for (int i = 0; i < _dimTypes.length; i++) {
        _dimValues[_dimTypes[i].typeCode] = dimValueResults[i];
      }

      await _loadTransactionData();
    } catch (e) {
      if (mounted) {
        final isEnglish = _isEnglish;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish
                ? 'Error loading master data: $e'
                : 'เกิดข้อผิดพลาดในการโหลดข้อมูลหลัก: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void didUpdateWidget(covariant GlEntryDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.actions != oldWidget.actions) {
      oldWidget.actions?.detach(this);
      widget.actions?.attach(this);
    }
    if (widget.entryId != oldWidget.entryId ||
        widget.viewOnly != oldWidget.viewOnly ||
        widget.resetKey != oldWidget.resetKey) {
      _loadTransactionData();
    }
  }

  Future<void> _loadTransactionData() async {
    if (_allowedDocTypes.isEmpty && _accounts.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      if (widget.entryId == null) {
        _resetForm();
      } else {
        final data = await _service.fetchEntryDetail(widget.entryId!);

        List<GlEntryDetail> loadedDetails = data['details'];
        for (var detail in loadedDetails) {
          if (detail.accountCode.isEmpty && detail.accountId != 0) {
            final match = _accounts.firstWhere(
              (a) => a.id == detail.accountId,
              orElse: () => Account(
                  id: 0, accountCode: '', accountNameThai: '', accountNameEng: '',
                  isActive: true, accountType: '',
                  normalBalance: '', isNormalAccount: false,
                  currencyCode: '', branchRequired: false, dimRules: const []),
            );
            detail.accountCode = match.accountCode;
            detail.accountName = match.accountNameThai;
          }
        }

        setState(() {
          _header = data['header'];
          if (_header.refDocId != null && _allDocTypes.isNotEmpty) {
            try {
              _selectedRefDocType =
                  _allDocTypes.firstWhere((e) => e.id == _header.refDocId);
            } catch (_) {}
          }
          _details = loadedDetails;
          _isReadOnly = widget.viewOnly ||
              _header.status != 'Draft' ||
              _header.refDocId != null;

          if (_allowedDocTypes.isNotEmpty) {
            try {
              _selectedDocType =
                  _allowedDocTypes.firstWhere((e) => e.id == _header.docId);
            } catch (_) {
              _selectedDocType = null;
            }
          }
          if (_currencies.isNotEmpty) {
            _baseCurrency = _getBaseCurrency();
            try {
              _selectedCurrency =
                  _currencies.firstWhere((c) => c.id == _header.currencyId);
            } catch (_) {
              _selectedCurrency = _currencies.firstWhere(
                  (c) => c.baseCurrencyFlag,
                  orElse: () => _currencies.first);
            }
          }
        });

        for (final c in _debitCtrls) c.dispose();
        for (final c in _creditCtrls) c.dispose();
        for (final c in _descCtrls) c.dispose();
        _debitCtrls = _details
            .map((d) => TextEditingController(
                text: d.debitFc == 0 ? '' : d.debitFc.toString()))
            .toList();
        _creditCtrls = _details
            .map((d) => TextEditingController(
                text: d.creditFc == 0 ? '' : d.creditFc.toString()))
            .toList();
        _descCtrls = _details
            .map((d) => TextEditingController(text: d.description))
            .toList();
      }
    } catch (e) {
      if (mounted) {
        final isEnglish = _isEnglish;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish
                ? 'Error loading data: $e'
                : 'เกิดข้อผิดพลาดในการโหลดข้อมูล: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _markClean();
    }
  }

  void _resetForm() {
    Currency baseCurrency = _currencies.firstWhere(
        (c) => c.baseCurrencyFlag == true,
        orElse: () => _currencies.isNotEmpty
            ? _currencies.first
            : Currency(
                id: 1, currencyCode: CurrencyService.baseCode, currencyNameThai: '',
                currencyNameEng: '', baseRate: 1, baseCurrencyFlag: true,
                numOfDecimal: 2, isActive: true));

    _header = GlEntryHeader(
      docId: 0,
      docDate: DateTime.now(),
      postingDate: DateTime.now(),
      status: 'Draft',
      currencyId: baseCurrency.id ?? 1,
      exchangeRate: baseCurrency.baseRate,
      branchId:   AuthService().defaultBranch?.branchId,
      branchCode: AuthService().defaultBranch?.branchCode,
      branchName: AuthService().defaultBranch?.branchNameThai,
    );
    _details = [];
    _selectedDocType = null;
    _selectedRefDocType = null;
    _selectedCurrency = baseCurrency;
    _isReadOnly = false;

    for (final c in _debitCtrls) c.dispose();
    for (final c in _creditCtrls) c.dispose();
    for (final c in _descCtrls) c.dispose();
    _debitCtrls = [];
    _creditCtrls = [];
    _descCtrls = [];

    _addDetailRow();
  }

  void _addDetailRow() {
    setState(() {
      _details.add(GlEntryDetail(accountId: 0));
      _debitCtrls.add(TextEditingController());
      _creditCtrls.add(TextEditingController());
      _descCtrls.add(TextEditingController());
    });
  }

  void _calculateTotals() {
    double drFc = 0, crFc = 0, drLc = 0, crLc = 0;
    for (var d in _details) {
      d.debitLc  = double.parse((d.debitFc  * _header.exchangeRate).toStringAsFixed(2));
      d.creditLc = double.parse((d.creditFc * _header.exchangeRate).toStringAsFixed(2));
      drFc += d.debitFc;  crFc += d.creditFc;
      drLc += d.debitLc;  crLc += d.creditLc;
    }
    setState(() {
      _header.totalDebitFc  = drFc;  _header.totalCreditFc  = crFc;
      _header.totalDebitLc  = drLc;  _header.totalCreditLc  = crLc;
    });
  }

  void _onCurrencyChanged(Currency? val) {
    if (val == null) return;
    setState(() {
      _selectedCurrency = val;
      _header.currencyId = val.id!;
      _header.exchangeRate = val.baseCurrencyFlag ? 1.0 : val.baseRate;
    });
    _calculateTotals();
  }

  void _onExchangeRateChanged(String val) {
    _header.exchangeRate = double.tryParse(val) ?? 0.0;
    _calculateTotals();
  }

  Future<void> _save(String action) async {
    final isEnglish = _isEnglish;
    // ช่องหัวเอกสารซ่อนข้อความผิดพลาดใต้ช่อง (กรอบเท่ากันทุกช่อง) — แจ้งด้วย SnackBar แทน
    if (!_formKey.currentState!.validate()) {
      setState(() => _headerExpanded = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish
              ? 'Please fill in the required fields (red border)'
              : 'กรุณากรอกช่องที่จำเป็น (กรอบสีแดง)')));
      return;
    }
    _formKey.currentState!.save();
    _calculateTotals();

    if (action == 'Post' &&
        (_header.totalDebitFc - _header.totalCreditFc).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish
              ? 'Debit/Credit total ($_baseCurrency) does not balance'
              : 'ยอด Dr/Cr ($_baseCurrency) ไม่เท่ากัน')));
      return;
    }
    if (_details.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish
              ? 'Please add at least one entry line'
              : 'กรุณาเพิ่มรายการบัญชี')));
      return;
    }
    if (_details.any((d) => d.accountId == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish
              ? 'Please select an account for every line'
              : 'กรุณาเลือกบัญชีให้ครบทุกรายการ')));
      return;
    }
    if (_details.any((d) => d.debitFc == 0 && d.creditFc == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish
              ? 'Please enter a debit or credit amount for every line'
              : 'กรุณาระบุยอดเดบิตหรือเครดิตในทุกรายการ')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _service.saveEntry(_header, _details, action);
      _markClean();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish ? 'Saved successfully' : 'บันทึกสำเร็จ')));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onSaveSuccess();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish ? 'Save failed: $e' : 'บันทึกไม่สำเร็จ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reverse() async {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    final reason = await showDocReasonDialog(
      context,
      isEnglish: isEnglish,
      title: isEnglish ? 'Reverse to Draft' : 'ถอยรายการกลับเป็นร่าง',
      message: isEnglish
          ? 'The entry returns to Draft and is removed from account balances.\n'
            'Edit it and post again with the same document no. ${_header.docNo}'
          : 'รายการจะกลับเป็นร่างและถูกตัดออกจากยอดบัญชี\n'
            'แก้ไขแล้วโพสต์ใหม่ได้ด้วยเลขที่เดิม ${_header.docNo}',
      confirmLabel: isEnglish ? 'Reverse to Draft' : 'ถอยเป็นร่าง',
    );
    if (reason == null) return;
    try {
      await _service.reverseEntry(_header.id, reason);
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onSaveSuccess();
        });
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish ? 'Reverse failed: $msg' : 'ถอยไม่สำเร็จ: $msg')));
      }
    }
  }

  // เหตุผลที่ถอยรายการไม่ได้ (ตาม reverse_block จาก backend) — null = ถอยได้
  String? _reverseBlockMessage(bool isEnglish) {
    final block = _header.externalSourceId != null ? 'MODULE' : _header.reverseBlock;
    switch (block) {
      case null:
      case 'NOT_POSTED':
        return null;
      case 'MODULE':
        return isEnglish
            ? 'This entry was created from another module\nPlease reverse/void it from the source document'
            : 'รายการนี้สร้างจากโมดูลอื่น\nกรุณาถอย/ยกเลิกจากเอกสารต้นทาง';
      case 'CLOSING':
        return isEnglish
            ? 'Year-end closing entry\ncannot be reversed here'
            : 'รายการปิดบัญชีสิ้นปี\nไม่สามารถถอยจากหน้าจอนี้ได้';
      case 'PERIOD_CLOSED':
        return isEnglish
            ? 'The accounting period of this entry is closed'
            : 'งวดบัญชีของรายการนี้ปิดแล้ว';
      default:
        return block;
    }
  }

  Future<void> _selectDate(BuildContext context, bool isDocDate) async {
    if (_isReadOnly) return;
    final isEnglish = _isEnglish;
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: isDocDate ? _header.docDate : _header.postingDate,
      firstDate: DateTime(2000), lastDate: DateTime(2100),
    );
    if (picked != null) {
      if (isDocDate) {
        final pickedDay = DateTime(picked.year, picked.month, picked.day);
        final inOpenPeriod = _openPeriods.any((p) =>
            !pickedDay.isBefore(p.periodStartDate) &&
            !pickedDay.isAfter(p.periodEndDate));
        if (!inOpenPeriod) {
          messenger.showSnackBar(SnackBar(
            content: Text(isEnglish
                ? 'Document date must fall within an open posting period (GL Status = OPEN)'
                : 'วันที่เอกสารต้องอยู่ในงวดบัญชีที่เปิด (GL Status = OPEN)'),
            backgroundColor: Colors.red,
          ));
          return;
        }
      }
      setState(() {
        if (isDocDate) _header.docDate = picked;
        else _header.postingDate = picked;
      });
    }
  }

  String _getBaseCurrency() {
    final item = _currencies.firstWhere((e) => e.baseCurrencyFlag == true,
        orElse: () => Currency(
            id: 0, isActive: true, currencyCode: CurrencyService.baseCode, currencyNameThai: '',
            currencyNameEng: '', baseRate: 1, baseCurrencyFlag: true, numOfDecimal: 2));
    return item.currencyCode;
  }

  // ── Dimension helpers ────────────────────────────────────────────────────

  int? _getDimId(GlEntryDetail detail, int slotNo) {
    switch (slotNo) {
      case 1: return detail.dim1Id;
      case 2: return detail.dim2Id;
      case 3: return detail.dim3Id;
      case 4: return detail.dim4Id;
      case 5: return detail.dim5Id;
      default: return null;
    }
  }

  void _setDim(GlEntryDetail detail, int slotNo, GlDimensionValue? val) {
    switch (slotNo) {
      case 1: detail.dim1Id = val?.id; detail.dim1Code = val?.valueCode; detail.dim1Name = val?.valueNameThai; break;
      case 2: detail.dim2Id = val?.id; detail.dim2Code = val?.valueCode; detail.dim2Name = val?.valueNameThai; break;
      case 3: detail.dim3Id = val?.id; detail.dim3Code = val?.valueCode; detail.dim3Name = val?.valueNameThai; break;
      case 4: detail.dim4Id = val?.id; detail.dim4Code = val?.valueCode; detail.dim4Name = val?.valueNameThai; break;
      case 5: detail.dim5Id = val?.id; detail.dim5Code = val?.valueCode; detail.dim5Name = val?.valueNameThai; break;
    }
  }

  // ── รูปแบบช่อง (user design 2026-11-22 — เหมือนหน้ารายละเอียด IM) ────────────────────────────
  // หัวเอกสาร: กรอบ 40 / ตัวอักษร 13 / ป้ายลอย 12; ตาราง: กรอบ 36 / ตัวอักษร 13
  // สีช่อง: ขาว = กรอกเอง, ฟ้า = ระบบเติมให้ (แก้ได้), เทา = อ่านอย่างเดียว
  static const _gDoc = Color(0xFF1E5AA8);
  static const _gParty = Color(0xFF1F7A4D);
  static const _gFin = Color(0xFFB45309);
  static const _gMore = Color(0xFF5B6B7C);
  static const _hAuto = Color(0xFFE3EEFA);
  static const _hRo = Color(0xFFEEF0F2);
  static const _errRed = Color(0xFFC62828);
  static const _ink2 = Color(0xFF4A5562);
  static const _ink3 = Color(0xFF6B7682);
  static const double _hFieldH = 40;
  static const double _cellH = 36;
  static const _numStyle = TextStyle(fontSize: 13, fontFeatures: [FontFeature.tabularFigures()]);

  // ไม่ dense (กรอบขั้นต่ำ 48) + จำกัดความสูง → กรอบเท่ากันทุกช่อง; ข้อความผิดพลาดซ่อน (กรอบแดงแทน) ไม่ให้กรอบเตี้ยลง
  InputDecoration _hDec(String label, {bool req = false, bool auto = false, bool forcedReadOnly = false, Widget? suffixIcon}) {
    final ro = _isReadOnly || forcedReadOnly;
    return InputDecoration(
      label: req
          ? Text.rich(TextSpan(text: label, children: const [TextSpan(text: ' *', style: TextStyle(color: _errRed))]))
          : Text(label),
      border: const OutlineInputBorder(),
      isDense: false,
      constraints: const BoxConstraints.tightFor(height: _hFieldH),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      suffixIcon: suffixIcon,
      suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 24, maxHeight: 24),
      filled: ro || auto,
      fillColor: ro ? _hRo : _hAuto,
      errorStyle: const TextStyle(height: 0, fontSize: 0),
    );
  }

  InputDecoration _cDec({Color? fill, bool err = false}) => InputDecoration(
        isDense: false,
        constraints: const BoxConstraints.tightFor(height: _cellH),
        contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        border: const OutlineInputBorder(),
        enabledBorder: err ? const OutlineInputBorder(borderSide: BorderSide(color: _errRed, width: 1.4)) : null,
        filled: fill != null,
        fillColor: fill,
      );

  // ช่องแสดงค่า (อ่านอย่างเดียว / คำนวณ) ขนาดเท่าช่องกรอกในตาราง
  Widget _cBox(String text, {bool right = false, bool bold = false, String? tip, Color? color}) {
    final box = Container(
      height: _cellH,
      alignment: right ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: _hRo,
        border: Border.all(color: const Color(0xFFC3C9D0)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _numStyle.copyWith(fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color ?? _ink2)),
    );
    return tip == null ? box : Tooltip(message: tip, child: box);
  }

  Widget _chip(String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg), overflow: TextOverflow.ellipsis),
      );

  Widget _hGroupLabel(int no, String title, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9)),
          child: Text('$no', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 6),
        Flexible(child: Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
      ]);

  String _branchDisplayName() {
    for (final b in _branches) {
      if (b.id == _header.branchId && _isEnglish && b.branchNameEng.isNotEmpty) return b.branchNameEng;
    }
    return _header.branchName ?? '';
  }

  String _docLabel(ModuleDocument e) => '${e.docCode} ${_isEnglish && e.docNameEng.isNotEmpty ? e.docNameEng : e.docNameThai}';

  // งวดบัญชีที่เปิดอยู่ซึ่งวันที่เอกสารตกอยู่ (null = ไม่อยู่ในงวดที่เปิด)
  PostingPeriod? get _docPeriod {
    final d = DateTime(_header.docDate.year, _header.docDate.month, _header.docDate.day);
    for (final p in _openPeriods) {
      if (!d.isBefore(p.periodStartDate) && !d.isAfter(p.periodEndDate)) return p;
    }
    return null;
  }

  Future<void> _pickBranch() async {
    final b = await _showBranchDialog();
    if (!mounted) return;
    if (b != null) {
      setState(() {
        _header.branchId = b.id;
        _header.branchCode = b.branchCode;
        _header.branchName = b.branchNameThai;
      });
    } else if (_header.branchId != null) {
      setState(() {
        _header.branchId = null;
        _header.branchCode = null;
        _header.branchName = null;
      });
    }
  }

  // ── การ์ดข้อมูลเอกสาร: 4 กลุ่มสี (เหมือน IM) — fix ด้านบน, ย่อเป็นแถบสรุปได้ ─────────────────────
  Widget _buildHeaderCard(bool isEnglish) {
    final df = DateFormat('dd/MM/yyyy');
    final calIcon = const Icon(Icons.calendar_today, size: 16, color: Color(0xFF0F6E6E));
    final auto = _selectedDocType?.isAutoNumbering ?? false;
    final period = _docPeriod;
    final isBase = _selectedCurrency?.baseCurrencyFlag ?? true;

    final titleRow = Row(children: [
      Expanded(
        child: Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(isEnglish ? 'Document Header' : 'ข้อมูลเอกสาร', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          if (_header.docNo.isNotEmpty && _header.docNo != 'AUTO')
            Text(_header.docNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F5C5C))),
          docStatusBadge(_header.status),
          // งวดบัญชีของวันที่เอกสาร — แจ้งตั้งแต่ก่อนบันทึกว่าโพสต์ได้หรือไม่
          if (!_isReadOnly)
            period != null
                ? _chip('${isEnglish ? 'Period' : 'งวด'} ${period.periodName} · ${isEnglish ? 'open' : 'เปิด'}', const Color(0xFF1E4F8F), _hAuto)
                : _chip(isEnglish ? 'Date is not in an open period' : 'วันที่ไม่อยู่ในงวดที่เปิด', const Color(0xFFB71C1C), const Color(0xFFFDECEA)),
        ]),
      ),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 10), foregroundColor: Colors.blueGrey.shade800),
        icon: Icon(_headerExpanded ? Icons.expand_less : Icons.expand_more, size: 18),
        label: Text(_headerExpanded ? (isEnglish ? 'Collapse' : 'ย่อ') : (isEnglish ? 'Expand' : 'ขยาย'), style: const TextStyle(fontSize: 12)),
        onPressed: () => setState(() => _headerExpanded = !_headerExpanded),
      ),
    ]);

    final g1 = docFilterGroup(1, isEnglish ? 'Document' : 'เอกสาร', color: _gDoc, [
      DropdownButtonFormField<ModuleDocument>(
        isExpanded: true,
        isDense: true,
        value: _selectedDocType,
        items: _allowedDocTypes.map((e) => DropdownMenuItem(value: e, child: Text(_docLabel(e), overflow: TextOverflow.ellipsis))).toList(),
        decoration: _hDec(isEnglish ? 'Document Type' : 'ประเภทเอกสาร', req: true),
        onChanged: _isReadOnly
            ? null
            : (val) => setState(() {
                  _selectedDocType = val;
                  _header.docId = val!.id;
                  _header.isAutoNumbering = val.isAutoNumbering;
                  _header.docNo = val.isAutoNumbering ? 'AUTO' : '';
                }),
        validator: (v) => v == null ? (isEnglish ? 'Please select' : 'กรุณาเลือก') : null,
      ),
      Row(children: [
        Expanded(
          child: TextFormField(
            key: ValueKey('docNo_${_header.docNo}'),
            initialValue: auto && _header.docNo == 'AUTO' ? '' : _header.docNo,
            decoration: _hDec(isEnglish ? 'Doc No.' : 'เลขที่เอกสาร', req: !auto, auto: auto, forcedReadOnly: auto && _isReadOnly)
                .copyWith(hintText: auto ? (isEnglish ? 'Auto' : 'อัตโนมัติ') : null),
            readOnly: _isReadOnly || auto,
            onSaved: (v) => _header.docNo = auto && (v ?? '').isEmpty ? 'AUTO' : (v ?? ''),
            onChanged: (v) => _header.docNo = v,
            validator: (v) => !auto && (v == null || v.isEmpty) ? (isEnglish ? 'Please enter doc no.' : 'ระบุเลขที่') : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: InkWell(
            onTap: _isReadOnly ? null : () => _selectDate(context, true),
            child: InputDecorator(
              decoration: _hDec(isEnglish ? 'Doc Date' : 'วันที่เอกสาร', req: true, auto: true, suffixIcon: _isReadOnly ? null : calIcon),
              child: Text(df.format(_header.docDate), maxLines: 1),
            ),
          ),
        ),
      ]),
    ]);

    final g2 = docFilterGroup(2, isEnglish ? 'Reference Document' : 'เอกสารอ้างอิง', color: _gParty, [
      DropdownButtonFormField<ModuleDocument?>(
        isExpanded: true,
        isDense: true,
        value: _selectedRefDocType,
        items: [
          DropdownMenuItem<ModuleDocument?>(value: null, child: Text(isEnglish ? '— Not specified —' : '— ไม่ระบุ —')),
          ..._allDocTypes.map((e) => DropdownMenuItem<ModuleDocument?>(value: e, child: Text(_docLabel(e), overflow: TextOverflow.ellipsis))),
        ],
        decoration: _hDec(isEnglish ? 'Reference Doc Type' : 'ประเภทเอกสารอ้างอิง'),
        onChanged: _isReadOnly
            ? null
            : (val) => setState(() {
                  _selectedRefDocType = val;
                  _header.refDocId = val?.id;
                }),
      ),
      Row(children: [
        Expanded(
          child: TextFormField(
            key: ValueKey('refDocNo_${widget.resetKey}_${_header.id}'),
            initialValue: _header.refDocNo,
            decoration: _hDec(isEnglish ? 'Reference No.' : 'เลขที่อ้างอิง'),
            readOnly: _isReadOnly,
            onSaved: (v) => _header.refDocNo = v,
            onChanged: (v) => _header.refDocNo = v,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: InkWell(
            onTap: _isReadOnly
                ? null
                : () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _header.refDocDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _header.refDocDate = picked);
                  },
            child: InputDecorator(
              decoration: _hDec(isEnglish ? 'Reference Date' : 'วันที่อ้างอิง', suffixIcon: _isReadOnly ? null : calIcon),
              child: Text(_header.refDocDate == null ? '—' : df.format(_header.refDocDate!), maxLines: 1),
            ),
          ),
        ),
      ]),
    ]);

    final g3 = docFilterGroup(3, isEnglish ? 'Currency' : 'สกุลเงิน', color: _gFin, [
      DropdownButtonFormField<Currency>(
        value: _selectedCurrency,
        isExpanded: true,
        isDense: true,
        items: _currencies
            .map((c) => DropdownMenuItem(
                value: c,
                child: Text(
                    '${c.currencyCode}  ${isEnglish && c.currencyNameEng.isNotEmpty ? c.currencyNameEng : c.currencyNameThai}'.trim(),
                    overflow: TextOverflow.ellipsis)))
            .toList(),
        decoration: _hDec(isEnglish ? 'Currency' : 'สกุลเงิน', auto: true),
        onChanged: _isReadOnly ? null : _onCurrencyChanged,
      ),
      TextFormField(
        key: ValueKey('rate_${_header.currencyId}_${_header.exchangeRate}'),
        initialValue: _header.exchangeRate.toStringAsFixed(4),
        decoration: _hDec(isEnglish ? 'Exchange Rate' : 'อัตราแลกเปลี่ยน', auto: true, forcedReadOnly: isBase),
        textAlign: TextAlign.right,
        style: _numStyle,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        readOnly: _isReadOnly || isBase,
        onChanged: _onExchangeRateChanged,
      ),
    ]);

    final hasBranch = (_header.branchCode ?? '').isNotEmpty;
    final g4 = docFilterGroup(4, isEnglish ? 'More' : 'เพิ่มเติม', color: _gMore, [
      InkWell(
        onTap: _isReadOnly ? null : _pickBranch,
        child: InputDecorator(
          decoration: _hDec(isEnglish ? 'Branch' : 'สาขา', auto: true,
              suffixIcon: _isReadOnly ? null : const Icon(Icons.search, size: 18, color: Color(0xFF0F6E6E))),
          child: hasBranch
              ? Text.rich(
                  TextSpan(children: [
                    TextSpan(text: _header.branchCode, style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: '  ${_branchDisplayName()}', style: const TextStyle(color: _ink2)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)
              : Text(isEnglish ? '— Not specified —' : '— ไม่ระบุ —', style: TextStyle(color: Colors.grey.shade600), maxLines: 1),
        ),
      ),
      TextFormField(
        key: ValueKey('desc_${_header.id}'),
        initialValue: _header.description,
        decoration: _hDec(isEnglish ? 'Description' : 'คำอธิบาย'),
        readOnly: _isReadOnly,
        onSaved: (v) => _header.description = v ?? '',
        onChanged: (v) => _header.description = v,
      ),
    ]);

    // จอกว้าง: 4 กลุ่มแถวเดียว / จอกลาง: 2×2 / จอแคบ: เรียงลง
    final body = LayoutBuilder(builder: (context, c) {
      Widget row(List<(Widget, int)> items) => IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(flex: items[i].$2, child: items[i].$1),
              ],
            ]),
          );
      if (c.maxWidth >= 1150) return row([(g1, 12), (g2, 12), (g3, 8), (g4, 12)]);
      if (c.maxWidth >= 640) {
        return Column(children: [row([(g1, 1), (g2, 1)]), const SizedBox(height: 10), row([(g3, 1), (g4, 1)])]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        g1, const SizedBox(height: 10), g2, const SizedBox(height: 10), g3, const SizedBox(height: 10), g4,
      ]);
    });

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          titleRow,
          const SizedBox(height: 10),
          if (_headerExpanded) body else _headerSummary(isEnglish),
        ]),
      ),
    );
  }

  // แถบสรุปตอนย่อการ์ด — จุดสีบอกกลุ่มที่มา
  Widget _headerSummary(bool isEnglish) {
    final df = DateFormat('dd/MM/yyyy');
    Widget item(Color c, String label, String value) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 6),
          Text('$label ', style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700)),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(value, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
          ),
        ]);
    final ref = [
      if (_selectedRefDocType != null) _selectedRefDocType!.docCode,
      if ((_header.refDocNo ?? '').isNotEmpty) _header.refDocNo!,
      if (_header.refDocDate != null) df.format(_header.refDocDate!),
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFF6F8FA), borderRadius: BorderRadius.circular(4)),
      child: Wrap(spacing: 22, runSpacing: 6, children: [
        if (_selectedDocType != null) item(_gDoc, isEnglish ? 'Type' : 'ประเภท', _docLabel(_selectedDocType!)),
        item(_gDoc, isEnglish ? 'Date' : 'วันที่', df.format(_header.docDate)),
        if (ref.isNotEmpty) item(_gParty, isEnglish ? 'Reference' : 'อ้างอิง', ref),
        item(_gFin, isEnglish ? 'Currency' : 'สกุลเงิน',
            (_selectedCurrency?.baseCurrencyFlag ?? true)
                ? (_selectedCurrency?.currencyCode ?? _baseCurrency)
                : '${_selectedCurrency!.currencyCode} @ ${_header.exchangeRate.toStringAsFixed(4)}'),
        if ((_header.branchCode ?? '').isNotEmpty) item(_gMore, isEnglish ? 'Branch' : 'สาขา', '${_header.branchCode} ${_branchDisplayName()}'),
        if (_header.description.trim().isNotEmpty) item(_gMore, isEnglish ? 'Description' : 'คำอธิบาย', _header.description.trim()),
      ]),
    );
  }

  // ── การ์ดรายการเดบิต / เครดิต: ตารางแบบการ์ดรายการสินค้า (ช่อง 36) ──────────────────────────────
  bool get _balanced => (_header.totalDebitFc - _header.totalCreditFc).abs() < 0.005;

  Widget _buildDetailSection(bool isEnglish) {
    final hasAmount = _header.totalDebitFc != 0 || _header.totalCreditFc != 0;
    final fmt = NumberFormat('#,##0.00', 'en_US');
    final diff = (_header.totalDebitFc - _header.totalCreditFc).abs();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(isEnglish ? 'Debit / Credit Lines' : 'รายการเดบิต / เครดิต', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                _chip(isEnglish ? '${_details.length} lines' : '${_details.length} บรรทัด', const Color(0xFF1E4F8F), _hAuto),
                if (hasAmount)
                  _balanced
                      ? _chip(isEnglish ? 'Balanced' : 'สมดุล', const Color(0xFF1E6B3A), const Color(0xFFE6F4EA))
                      : _chip('${isEnglish ? 'Out of balance · diff' : 'ไม่สมดุล · ต่าง'} ${fmt.format(diff)}', const Color(0xFFB71C1C),
                          const Color(0xFFFDECEA)),
              ]),
            ),
            if (!_isReadOnly)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: const Color(0xFF0F6E6E),
                  side: const BorderSide(color: Color(0xFF0F6E6E)),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: Text(isEnglish ? 'Add Line' : 'เพิ่มบรรทัด', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                onPressed: _addDetailRow,
              ),
          ]),
          const SizedBox(height: 10),
          _buildDetailTable(isEnglish),
        ]),
      ),
    );
  }

  final _lineHScroll = ScrollController();

  Widget _buildDetailTable(bool isEnglish) {
    final currency = _selectedCurrency?.currencyCode ?? _baseCurrency;
    final foreign = _baseCurrency != currency;
    final fmt = NumberFormat('#,##0.00', 'en_US');
    // คอลัมน์สาขาของบรรทัด — แสดงเฉพาะเมื่อมีบรรทัดที่ระบุสาขาเอง (รายการจากงานประมวลผลที่แยกสาขา)
    final showLineBranch = _details.any((d) => d.branchId != null);
    const gap = 6.0;
    // คอลัมน์: (key, กว้าง, กลุ่ม) — กว้าง 0 = ยืดตามพื้นที่ที่เหลือ
    final cols = <(String, double, int)>[
      ('no', 30, 0),
      ('acct', 250, 1),
      if (showLineBranch) ('branch', 100, 1),
      for (final t in _dimTypes) ('dim${t.slotNo}', 130, 2),
      ('dr', 130, 3),
      ('cr', 130, 3),
      ('desc', 0, 4),
      if (!_isReadOnly) ('act', 36, 0),
    ];
    return LayoutBuilder(builder: (context, cons) {
      final fixed = cols.fold<double>(0, (s, c) => s + c.$2) + gap * (cols.length - 1);
      final flexW = cons.maxWidth - fixed > 200 ? cons.maxWidth - fixed : 200.0;
      final tableW = fixed + flexW;
      double w((String, double, int) c) => c.$2 == 0 ? flexW : c.$2;
      Widget cells(List<Widget> ws) => Row(children: [
            for (var i = 0; i < cols.length; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              SizedBox(width: w(cols[i]), child: ws[i]),
            ],
          ]);
      String groupTitle(int g) => switch (g) {
            1 => isEnglish ? 'Account / Branch' : 'บัญชี / สาขา',
            2 => isEnglish ? 'Dimensions' : 'มิติ',
            3 => '${isEnglish ? 'Amount' : 'จำนวนเงิน'} ($currency)',
            _ => isEnglish ? 'Details' : 'รายละเอียด',
          };
      Color groupColor(int g) => g == 1 ? _gDoc : g == 2 ? _gParty : g == 3 ? _gFin : _gMore;

      // แถบสีกลุ่มเหนือหัวคอลัมน์
      final groupRow = <Widget>[];
      var i = 0;
      while (i < cols.length) {
        var j = i;
        var span = w(cols[i]);
        while (j + 1 < cols.length && cols[j + 1].$3 == cols[i].$3) {
          j++;
          span += gap + w(cols[j]);
        }
        if (i > 0) groupRow.add(const SizedBox(width: gap));
        final g = cols[i].$3;
        groupRow.add(SizedBox(
          width: span,
          child: g == 0
              ? null
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(height: 3, decoration: BoxDecoration(color: groupColor(g), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 3),
                  _hGroupLabel(g, groupTitle(g), groupColor(g)),
                ]),
        ));
        i = j + 1;
      }

      const hd = TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _ink2);
      Widget head(String key) {
        if (key.startsWith('dim')) {
          final t = _dimTypes.firstWhere((t) => 'dim${t.slotNo}' == key);
          return Text(isEnglish && (t.nameEng?.isNotEmpty ?? false) ? t.nameEng! : t.nameThai, style: hd, maxLines: 1, overflow: TextOverflow.ellipsis);
        }
        return switch (key) {
          'no' => const Text('#', style: hd),
          'acct' => Text.rich(
              TextSpan(text: isEnglish ? 'Account' : 'รหัสบัญชี', children: const [TextSpan(text: ' *', style: TextStyle(color: _errRed))]),
              style: hd),
          'branch' => Text(isEnglish ? 'Branch' : 'สาขา', style: hd),
          'dr' => Text(isEnglish ? 'Debit' : 'เดบิต', style: hd, textAlign: TextAlign.right),
          'cr' => Text(isEnglish ? 'Credit' : 'เครดิต', style: hd, textAlign: TextAlign.right),
          'desc' => Text(isEnglish ? 'Description' : 'รายละเอียด', style: hd),
          _ => const SizedBox.shrink(),
        };
      }

      Widget total(double fc, double lc) => Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(fmt.format(fc), textAlign: TextAlign.right, style: _numStyle.copyWith(fontWeight: FontWeight.bold)),
              if (foreign) Text('${fmt.format(lc)} $_baseCurrency', style: const TextStyle(fontSize: 12, color: _ink3)),
            ],
          );

      final table = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: groupRow),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFDDE3EA)))),
          child: cells([for (final c in cols) head(c.$1)]),
        ),
        for (var n = 0; n < _details.length; n++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEF1F4)))),
            child: cells([for (final c in cols) _lineCell(c.$1, n, isEnglish, foreign, fmt)]),
          ),
        if (_details.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _balanced ? const Color(0xFFF6F8FA) : const Color(0xFFFDECEA),
              border: const Border(top: BorderSide(color: Color(0xFFDDE3EA))),
            ),
            child: cells([
              for (final c in cols)
                switch (c.$1) {
                  'acct' => Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(isEnglish ? 'Total ${_details.length} lines' : 'รวม ${_details.length} บรรทัด',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  'dr' => Padding(padding: const EdgeInsets.only(right: 7), child: total(_header.totalDebitFc, _header.totalDebitLc)),
                  'cr' => Padding(padding: const EdgeInsets.only(right: 7), child: total(_header.totalCreditFc, _header.totalCreditLc)),
                  _ => const SizedBox.shrink(),
                },
            ]),
          ),
      ]);
      if (tableW <= cons.maxWidth + 0.5) return table;
      return Scrollbar(
        controller: _lineHScroll,
        thumbVisibility: true,
        trackVisibility: true,
        child: SingleChildScrollView(
          controller: _lineHScroll,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 14),
          child: SizedBox(width: tableW, child: table),
        ),
      );
    });
  }

  Account? _accountOf(GlEntryDetail d) {
    for (final a in _accounts) {
      if (a.id == d.accountId) return a;
    }
    return null;
  }

  Widget _lineCell(String key, int i, bool isEnglish, bool foreign, NumberFormat fmt) {
    final detail = _details[i];
    final acc = _accountOf(detail);
    if (key.startsWith('dim')) {
      final t = _dimTypes.firstWhere((t) => 'dim${t.slotNo}' == key);
      GlAccountDimRule? rule;
      for (final r in acc?.dimRules ?? const <GlAccountDimRule>[]) {
        if (r.typeCode == t.typeCode) rule = r;
      }
      // บัญชีนี้ไม่ใช้มิตินี้
      if (rule == null) return _cBox('—');
      final values = _dimValues[t.typeCode] ?? const <GlDimensionValue>[];
      final selectedId = _getDimId(detail, t.slotNo);
      GlDimensionValue? selected;
      for (final v in values) {
        if (v.id == selectedId) selected = v;
      }
      final missing = rule.isRequired && selected == null && !_isReadOnly;
      final field = GlDimensionPickerField(
        dimType: t,
        values: values,
        selected: selected,
        readOnly: _isReadOnly,
        fontSize: 13,
        decoration: _cDec(fill: _isReadOnly ? _hRo : (missing ? const Color(0xFFFDECEA) : Colors.white), err: missing),
        onSelected: (val) => setState(() => _setDim(detail, t.slotNo, val)),
      );
      return missing ? Tooltip(message: isEnglish ? 'Required by the account' : 'บัญชีนี้บังคับระบุ', child: field) : field;
    }
    switch (key) {
      case 'no':
        return Text('${i + 1}.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade700));
      case 'acct':
        final name = acc != null && _isEnglish && acc.accountNameEng.isNotEmpty ? acc.accountNameEng : detail.accountName;
        final has = detail.accountCode.isNotEmpty;
        final box = InkWell(
          onTap: _isReadOnly
              ? null
              : () async {
                  final a = await _showAccountDialog();
                  if (a != null && mounted) {
                    setState(() {
                      detail.accountId = a.id;
                      detail.accountCode = a.accountCode;
                      detail.accountName = a.accountNameThai;
                      for (final t in _dimTypes) {
                        if (!a.dimRules.any((r) => r.typeCode == t.typeCode)) _setDim(detail, t.slotNo, null);
                      }
                    });
                  }
                },
          child: Container(
            height: _cellH,
            padding: const EdgeInsets.only(left: 7, right: 4),
            decoration: BoxDecoration(
              color: _isReadOnly ? _hRo : Colors.white,
              border: Border.all(color: _isReadOnly ? const Color(0xFFC3C9D0) : Colors.grey.shade500),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(children: [
              Expanded(
                child: has
                    ? Text.rich(
                        TextSpan(children: [
                          TextSpan(text: detail.accountCode, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal[700])),
                          TextSpan(text: '  $name', style: const TextStyle(color: _ink2)),
                        ]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13))
                    : Text(isEnglish ? '— Select account —' : '— เลือกบัญชี —',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
              ),
              if (!_isReadOnly && detail.accountId != 0)
                InkWell(
                  onTap: () => setState(() {
                    detail.accountId = 0;
                    detail.accountCode = '';
                    detail.accountName = '';
                    for (final t in _dimTypes) {
                      _setDim(detail, t.slotNo, null);
                    }
                  }),
                  child: const Padding(padding: EdgeInsets.all(2), child: Icon(Icons.clear, size: 14, color: Colors.grey)),
                ),
              if (!_isReadOnly) const Icon(Icons.search, size: 16, color: Color(0xFF0F6E6E)),
            ]),
          ),
        );
        return has ? Tooltip(message: '${detail.accountCode} — $name', child: box) : box;
      case 'branch':
        // สาขาของบรรทัด (อ่านอย่างเดียว) — ว่าง = ใช้สาขาที่หัวรายการ
        return _cBox(
          detail.branchCode ?? _header.branchCode ?? '—',
          color: detail.branchId == null ? _ink3 : null,
          tip: detail.branchId == null
              ? (isEnglish ? 'Header branch' : 'ใช้สาขาที่หัวรายการ')
              : (isEnglish && (detail.branchNameEng?.isNotEmpty ?? false) ? detail.branchNameEng! : detail.branchName ?? ''),
        );
      case 'dr':
      case 'cr':
        final isDr = key == 'dr';
        final fc = isDr ? detail.debitFc : detail.creditFc;
        final lc = isDr ? detail.debitLc : detail.creditLc;
        // อ่านอย่างเดียว + เงินตราต่างประเทศ: ยอดสกุลเงินของเอกสาร (ยอดบาทใน tooltip)
        if (_isReadOnly && foreign) {
          return _cBox(fc == 0 ? '' : fmt.format(fc), right: true, tip: lc == 0 ? null : '${fmt.format(lc)} $_baseCurrency');
        }
        return TextField(
          controller: isDr ? _debitCtrls[i] : _creditCtrls[i],
          readOnly: _isReadOnly,
          textAlign: TextAlign.right,
          style: _numStyle.copyWith(color: _isReadOnly ? _ink2 : Colors.black87),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _cDec(fill: _isReadOnly ? _hRo : null),
          onChanged: (val) {
            final v = double.tryParse(val.replaceAll(',', '')) ?? 0;
            // บรรทัดหนึ่งมีได้ฝั่งเดียว — กรอกฝั่งหนึ่งแล้วล้างอีกฝั่ง
            if (isDr) {
              detail.debitFc = v;
              if (v != 0 && detail.creditFc != 0) {
                detail.creditFc = 0;
                _creditCtrls[i].clear();
              }
            } else {
              detail.creditFc = v;
              if (v != 0 && detail.debitFc != 0) {
                detail.debitFc = 0;
                _debitCtrls[i].clear();
              }
            }
            _calculateTotals();
          },
        );
      case 'desc':
        return TextField(
          controller: _descCtrls[i],
          readOnly: _isReadOnly,
          style: TextStyle(fontSize: 13, color: _isReadOnly ? _ink2 : Colors.black87),
          decoration: _cDec(fill: _isReadOnly ? _hRo : null),
          onChanged: (val) => detail.description = val,
        );
      case 'act':
        return IconButton(
          tooltip: isEnglish ? 'Delete line' : 'ลบบรรทัด',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
          onPressed: () => setState(() {
            _debitCtrls[i].dispose();
            _creditCtrls[i].dispose();
            _descCtrls[i].dispose();
            _debitCtrls.removeAt(i);
            _creditCtrls.removeAt(i);
            _descCtrls.removeAt(i);
            _details.removeAt(i);
            _calculateTotals();
          }),
        );
    }
    return const SizedBox.shrink();
  }

  // ── การ์ดสรุปยอด: เดบิต/เครดิตรวม + ผลต่าง (สมดุล = เขียว, ไม่สมดุล = แดง บอกฝั่งที่มากกว่า) ──────────
  Widget _buildSummaryCard(bool isEnglish) {
    final fmt = NumberFormat('#,##0.00', 'en_US');
    final currency = _selectedCurrency?.currencyCode ?? _baseCurrency;
    final foreign = _baseCurrency != currency;
    final diff = _header.totalDebitFc - _header.totalCreditFc;
    final hasAmount = _header.totalDebitFc != 0 || _header.totalCreditFc != 0;
    final ok = _balanced && hasAmount;
    Widget row(String label, String value, {bool line = false}) => Container(
          padding: EdgeInsets.only(top: line ? 7 : 3, bottom: 3),
          margin: EdgeInsets.only(top: line ? 4 : 0),
          decoration: line ? const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFDDE3EA)))) : null,
          child: Row(children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF33404D)))),
            Text(value, style: _numStyle.copyWith(fontWeight: FontWeight.w600)),
          ]),
        );
    final (fg, bg) = ok
        ? (const Color(0xFF1E6B3A), const Color(0xFFE6F4EA))
        : hasAmount
            ? (const Color(0xFFB71C1C), const Color(0xFFFDECEA))
            : (_ink2, const Color(0xFFF6F8FA));
    final finalLabel = !hasAmount
        ? (isEnglish ? 'Difference' : 'ผลต่าง')
        : ok
            ? (isEnglish ? 'Difference · balanced' : 'ผลต่าง · สมดุล')
            : diff > 0
                ? (isEnglish ? 'Debit exceeds credit' : 'เดบิตมากกว่า')
                : (isEnglish ? 'Credit exceeds debit' : 'เครดิตมากกว่า');
    final figures = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      row('${isEnglish ? 'Total debit' : 'เดบิตรวม'} ($currency)', fmt.format(_header.totalDebitFc)),
      row('${isEnglish ? 'Total credit' : 'เครดิตรวม'} ($currency)', fmt.format(_header.totalCreditFc)),
      if (foreign) ...[
        row('${isEnglish ? 'Total debit' : 'เดบิตรวม'} ($_baseCurrency)', fmt.format(_header.totalDebitLc), line: true),
        row('${isEnglish ? 'Total credit' : 'เครดิตรวม'} ($_baseCurrency)', fmt.format(_header.totalCreditLc)),
      ],
      row(isEnglish ? 'Lines' : 'จำนวนบรรทัด', '${_details.length}', line: true),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Row(children: [
          Expanded(child: Text(finalLabel, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: fg))),
          Text(fmt.format(diff.abs()), style: _numStyle.copyWith(fontSize: 17, fontWeight: FontWeight.bold, color: fg)),
        ]),
      ),
    ]);
    final hint = Text(
      isEnglish
          ? 'The entry can be posted when total debit equals total credit and every line has an account and the dimensions the account requires. '
              'Foreign-currency amounts are converted at the header exchange rate.'
          : 'เอกสารจะ Post ได้เมื่อเดบิตรวมเท่ากับเครดิตรวม และทุกบรรทัดระบุบัญชีกับมิติที่บัญชีบังคับครบ '
              'ยอดในสกุลเงินต่างประเทศแปลงเป็นสกุลเงินหลักตามอัตราแลกเปลี่ยนของหัวเอกสาร',
      style: const TextStyle(fontSize: 12, color: _ink3),
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(isEnglish ? 'Summary' : 'สรุปยอด', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, c) => c.maxWidth >= 720
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: hint),
                    const SizedBox(width: 24),
                    SizedBox(width: 360, child: figures),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [figures, const SizedBox(height: 10), hint]),
          ),
        ]),
      ),
    );
  }

  // ── Picker dialogs ───────────────────────────────────────────────────────

  Future<Account?> _showAccountDialog() async {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    final l = AppL10n(isEnglish);
    final searchCtrl = TextEditingController();
    final available = _accounts.where((a) => a.isNormalAccount && !a.isControlAccount && a.isActive).toList();
    List<Account> filtered = List.from(available);
    final result = await showDialog<Account>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        void doFilter(String q) {
          final lq = q.toLowerCase();
          setS(() => filtered = q.isEmpty
              ? available
              : available.where((a) =>
                  a.accountCode.toLowerCase().contains(lq) ||
                  a.accountNameThai.toLowerCase().contains(lq) ||
                  a.accountNameEng.toLowerCase().contains(lq)).toList());
        }
        return Dialog(
          child: SizedBox(
            width: 560, height: 540,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(
                    labelText: isEnglish ? 'Search account (code / name)' : 'ค้นหาบัญชี (รหัส / ชื่อ)',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontSize: 15),
                  onChanged: doFilter,
                  autofocus: true,
                ),
              ),
              Expanded(child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final a = filtered[i];
                  final name = isEnglish && a.accountNameEng.isNotEmpty
                      ? a.accountNameEng
                      : a.accountNameThai;
                  return ListTile(
                    dense: true,
                    title: Text('${a.accountCode}  $name',
                        style: const TextStyle(fontSize: 14)),
                    onTap: () => Navigator.pop(ctx, a),
                  );
                },
              )),
              const Divider(height: 1),
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.close)),
            ]),
          ),
        );
      }),
    );
    searchCtrl.dispose();
    return result;
  }

  Future<Branch?> _showBranchDialog() async {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    final l = AppL10n(isEnglish);
    // แสดงเฉพาะสาขาที่ user มีสิทธิ์ (ถ้ากำหนดไว้) มิฉะนั้นแสดงทั้งหมด
    final allowedIds = AuthService().allowedBranches.map((b) => b.branchId).toSet();
    final source = allowedIds.isEmpty
        ? _branches
        : _branches.where((b) => b.id != null && allowedIds.contains(b.id)).toList();
    final searchCtrl = TextEditingController();
    List<Branch> filtered = List.from(source);
    final result = await showDialog<Branch>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        void doFilter(String q) {
          final lq = q.toLowerCase();
          setS(() => filtered = q.isEmpty
              ? source
              : source.where((b) =>
                  b.branchCode.toLowerCase().contains(lq) ||
                  b.branchNameThai.toLowerCase().contains(lq) ||
                  b.branchNameEng.toLowerCase().contains(lq)).toList());
        }
        return Dialog(
          child: SizedBox(
            width: 480, height: 500,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(
                    labelText: isEnglish ? 'Search branch (code / name)' : 'ค้นหาสาขา (รหัส / ชื่อ)',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontSize: 15),
                  onChanged: doFilter,
                  autofocus: true,
                ),
              ),
              Expanded(child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final b = filtered[i];
                  final name = isEnglish && b.branchNameEng.isNotEmpty
                      ? b.branchNameEng
                      : b.branchNameThai;
                  return ListTile(
                    dense: true,
                    title: Text('${b.branchCode}  $name',
                        style: const TextStyle(fontSize: 14)),
                    onTap: () => Navigator.pop(ctx, b),
                  );
                },
              )),
              const Divider(height: 1),
              Row(children: [
                const SizedBox(width: 8),
                if (_header.branchId != null)
                  TextButton.icon(
                    icon: const Icon(Icons.clear, size: 16),
                    label: Text(isEnglish ? 'Clear' : 'ล้างค่า'),
                    onPressed: () => Navigator.pop(ctx, null),
                    style: TextButton.styleFrom(foregroundColor: Colors.grey),
                  ),
                const Spacer(),
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.close)),
              ]),
            ]),
          ),
        );
      }),
    );
    searchCtrl.dispose();
    return result;
  }

  // ── ปุ่มของเอกสาร (แสดงบน AppBar ของหน้าจอ แทนแถบปุ่มเดิม) — ปุ่ม "กลับ" ตัดออก (ใช้ลูกศรย้อนกลับ) ──
  List<DocBarAction> _barActions(bool en) {
    final a = <DocBarAction>[];
    if (!_isReadOnly && _header.status == 'Draft') {
      a.add(DocBarAction.secondary(en ? 'Draft' : 'ดราฟท์', () => _save('Draft'), DocBarColors.save));
      a.add(DocBarAction.primary(en ? 'Post' : 'โพสต์', () => _save('Post'), DocBarColors.post));
    } else if (_header.status == 'Posted') {
      final msg = _reverseBlockMessage(en);
      if (msg != null) {
        a.add(DocBarAction.primary(en ? 'Reverse' : 'ถอย', null, DocBarColors.voidBg, tooltip: msg));
      } else if (widget.canDelete) {
        a.add(DocBarAction.primary(en ? 'Reverse' : 'ถอย', _reverse, DocBarColors.voidBg));
      }
    }
    return a;
  }

  @override
  Widget buildAppBarActions(BuildContext context, bool en) =>
      _isLoading ? const SizedBox.shrink() : buildDocBarActions(context, _barActions(en), isEnglish: en);

  // ── มีการแก้ไขค้าง — หัวเอกสาร/บรรทัดต่างจากตอนโหลดเสร็จ (เฉพาะร่างที่แก้ไขได้) ──
  String? _cleanFingerprint;
  String _formFingerprint() => docFingerprint([_header, _details]);

  void _markClean() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cleanFingerprint = _formFingerprint();
    });
  }

  @override
  bool get isDirty {
    if (_isLoading || _isReadOnly || widget.viewOnly || _header.status != 'Draft') return false;
    return _cleanFingerprint != null && _cleanFingerprint != _formFingerprint();
  }

  @override
  Widget build(BuildContext context) {
    widget.actions?.scheduleRefresh();
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    // การ์ดข้อมูลเอกสาร fix ด้านบน (สูงไม่เกิน 60% แล้วเลื่อนในการ์ด) — รายการ/สรุปยอดเลื่อนด้านล่าง (แบบเดียวกับ IM)
    return Form(
      key: _formKey,
      child: docListTheme(
        context,
        LayoutBuilder(
          builder: (context, box) => Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: box.maxHeight.isFinite ? box.maxHeight * 0.6 : double.infinity),
                child: SingleChildScrollView(child: _buildHeaderCard(isEnglish)),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  DocReverseHistoryPanel(
                      history: _header.reverseHistory, isDeleted: _header.status == 'Deleted', isEnglish: isEnglish, margin: EdgeInsets.zero),
                  if (_header.reverseHistory.isNotEmpty) const SizedBox(height: 12),
                  _buildDetailSection(isEnglish),
                  const SizedBox(height: 12),
                  _buildSummaryCard(isEnglish),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
