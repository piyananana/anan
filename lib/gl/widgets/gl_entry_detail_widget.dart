import 'package:anan/cd/models/branch.dart';
import 'package:anan/cd/models/currency.dart';
import 'package:anan/cd/services/branch_service.dart';
import 'package:anan/cd/services/currency_service.dart';
import 'package:anan/gl/services/account_service.dart';
import 'package:anan/sa/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/account.dart';
import '../models/gl_dimension.dart';
import '../models/gl_entry.dart';
import '../models/period.dart';
import '../services/gl_dimension_service.dart';
import '../services/gl_entry_service.dart';
import '../services/period_service.dart';
import 'gl_dimension_picker_field.dart';
import '../../sa/models/module_document.dart';

class GlEntryDetailWidget extends StatefulWidget {
  final int? entryId;
  final bool viewOnly;
  final int resetKey;
  final VoidCallback onSaveSuccess;
  final VoidCallback onCancel;

  const GlEntryDetailWidget({
    super.key,
    this.entryId,
    this.viewOnly = false,
    this.resetKey = 0,
    required this.onSaveSuccess,
    required this.onCancel,
  });

  @override
  State<GlEntryDetailWidget> createState() => _GlEntryDetailWidgetState();
}

class _GlEntryDetailWidgetState extends State<GlEntryDetailWidget> {
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
  String _baseCurrency = 'THB';

  List<GlDimensionType> _dimTypes = [];
  final Map<String, List<GlDimensionValue>> _dimValues = {};

  ModuleDocument? _selectedDocType;
  Currency? _selectedCurrency;
  bool _isReadOnly = false;
  bool _headerExpanded = true;
  bool _detailExpanded = true;

  List<TextEditingController> _debitCtrls = [];
  List<TextEditingController> _creditCtrls = [];
  List<TextEditingController> _descCtrls = [];

  @override
  void initState() {
    super.initState();
    _initMasterData();
  }

  @override
  void dispose() {
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading master: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void didUpdateWidget(covariant GlEntryDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
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
                  isActive: true, accountType: '', accountSubType: '',
                  normalBalance: '', isNormalAccount: false, isReconcilable: false,
                  currencyCode: '', moduleLinkCode: '', costCenterRequired: false,
                  projectRequired: false, branchRequired: false, dimRules: const []),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    Currency baseCurrency = _currencies.firstWhere(
        (c) => c.baseCurrencyFlag == true,
        orElse: () => _currencies.isNotEmpty
            ? _currencies.first
            : Currency(
                id: 1, currencyCode: 'THB', currencyNameThai: '',
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
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    _calculateTotals();

    if (action == 'Post' &&
        (_header.totalDebitFc - _header.totalCreditFc).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ยอด Dr/Cr ($_baseCurrency) ไม่เท่ากัน')));
      return;
    }
    if (_details.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณาเพิ่มรายการบัญชี')));
      return;
    }
    if (_details.any((d) => d.accountId == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาเลือกบัญชีให้ครบทุกรายการ')));
      return;
    }
    if (_details.any((d) => d.debitFc == 0 && d.creditFc == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('กรุณาระบุยอดเดบิตหรือเครดิตในทุกรายการ')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _service.saveEntry(_header, _details, action);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('บันทึกสำเร็จ')));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onSaveSuccess();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reverse() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการถอยรายการ'),
        content: const Text(
            'ต้องการสร้างรายการถอย (Reverse) ใช่หรือไม่?\nระบบจะสร้างรายการใหม่ที่มียอดตรงข้ามกัน'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ยืนยันถอย', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _service.reverseEntry(_header.id);
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onSaveSuccess();
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('ถอยไม่สำเร็จ: $e')));
        }
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isDocDate) async {
    if (_isReadOnly) return;
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
          messenger.showSnackBar(const SnackBar(
            content: Text('วันที่เอกสารต้องอยู่ในงวดบัญชีที่เปิด (GL Status = OPEN)'),
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
            id: 0, isActive: true, currencyCode: 'THB', currencyNameThai: '',
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

  // ── Decoration helper ────────────────────────────────────────────────────

  // Editable = white fill + outline border
  // Read-only = grey[100] fill + outline border (no cursor/icon → visually distinct)
  InputDecoration _fieldDeco(String label, {bool forcedReadOnly = false}) {
    final isRO = _isReadOnly || forcedReadOnly;
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
      filled: true,
      fillColor: isRO ? Colors.grey[100] : Colors.white,
    );
  }

  // ── Picker dialogs ───────────────────────────────────────────────────────

  Future<Account?> _showAccountDialog() async {
    final searchCtrl = TextEditingController();
    final available = _accounts.where((a) => !a.isControlAccount && a.isActive).toList();
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
                  a.accountNameThai.toLowerCase().contains(lq)).toList());
        }
        return Dialog(
          child: SizedBox(
            width: 560, height: 540,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: searchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ค้นหาบัญชี (รหัส / ชื่อ)',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
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
                  return ListTile(
                    dense: true,
                    title: Text('${a.accountCode}  ${a.accountNameThai}',
                        style: const TextStyle(fontSize: 14)),
                    onTap: () => Navigator.pop(ctx, a),
                  );
                },
              )),
              const Divider(height: 1),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ปิด')),
            ]),
          ),
        );
      }),
    );
    searchCtrl.dispose();
    return result;
  }

  Future<Branch?> _showBranchDialog() async {
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
                  b.branchNameThai.toLowerCase().contains(lq)).toList());
        }
        return Dialog(
          child: SizedBox(
            width: 480, height: 500,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: searchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ค้นหาสาขา (รหัส / ชื่อ)',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
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
                  return ListTile(
                    dense: true,
                    title: Text('${b.branchCode}  ${b.branchNameThai}',
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
                    label: const Text('ล้างค่า'),
                    onPressed: () => Navigator.pop(ctx, null),
                    style: TextButton.styleFrom(foregroundColor: Colors.grey),
                  ),
                const Spacer(),
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ปิด')),
              ]),
            ]),
          ),
        );
      }),
    );
    searchCtrl.dispose();
    return result;
  }

  // ── Header card (collapsible) ────────────────────────────────────────────
  Widget _buildHeaderCard() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.article_outlined, size: 18, color: Colors.teal),
            const SizedBox(width: 6),
            Text('ข้อมูลหัวเอกสาร',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            IconButton(
              icon: Icon(_headerExpanded ? Icons.expand_less : Icons.expand_more, size: 18),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _headerExpanded = !_headerExpanded),
            ),
            const Spacer(),
            if (_header.status != 'Draft')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _header.status == 'Posted' ? Colors.green[50] : Colors.red[50],
                  border: Border.all(color: _header.status == 'Posted' ? Colors.green : Colors.red),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_header.status,
                    style: TextStyle(
                        color: _header.status == 'Posted' ? Colors.green[800] : Colors.red[800],
                        fontWeight: FontWeight.bold, fontSize: 12)),
              ),
          ]),
          if (_headerExpanded) ...[
            const SizedBox(height: 8),
            // Row 1
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 4,
                child: DropdownButtonFormField<ModuleDocument>(
                  isExpanded: true,
                  value: _selectedDocType,
                  items: _allowedDocTypes.map((e) => DropdownMenuItem(
                      value: e, child: Text('${e.docCode} ${e.docNameThai}'))).toList(),
                  decoration: _fieldDeco('ประเภทเอกสาร'),
                  onChanged: _isReadOnly ? null : (val) => setState(() {
                    _selectedDocType = val;
                    _header.docId = val!.id;
                    _header.isAutoNumbering = val.isAutoNumbering;
                    _header.docNo = val.isAutoNumbering ? 'AUTO' : '';
                  }),
                  validator: (v) => v == null ? 'กรุณาเลือก' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextFormField(
                  key: ValueKey('docNo_${_header.docNo}'),
                  initialValue: _header.docNo,
                  decoration: _fieldDeco(
                      (_selectedDocType?.isAutoNumbering ?? false) ? 'เลขที่อัตโนมัติ' : 'เลขที่เอกสาร',
                      forcedReadOnly: _selectedDocType?.isAutoNumbering ?? false).copyWith(
                    hintText: (_selectedDocType?.isAutoNumbering ?? false) ? '(ระบบกำหนดให้อัตโนมัติ)' : null,
                  ),
                  readOnly: _isReadOnly || (_selectedDocType?.isAutoNumbering ?? false),
                  onSaved: (v) => _header.docNo = v ?? '',
                  validator: (v) => (v == null || v.isEmpty) ? 'ระบุเลขที่' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: () => _selectDate(context, true),
                  child: InputDecorator(
                    decoration: _fieldDeco('วันที่เอกสาร'),
                    child: Text(DateFormat('dd/MM/yyyy').format(_header.docDate)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: DropdownButtonFormField<ModuleDocument>(
                  isExpanded: true,
                  value: _selectedRefDocType,
                  items: _allDocTypes.map((e) => DropdownMenuItem(
                      value: e, child: Text('${e.docCode} ${e.docNameThai}', overflow: TextOverflow.ellipsis))).toList(),
                  decoration: _fieldDeco('ประเภทเอกสารอ้างอิง'),
                  onChanged: _isReadOnly ? null : (val) => setState(() {
                    _selectedRefDocType = val;
                    _header.refDocId = val?.id;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextFormField(
                  key: ValueKey('refDocNo_${widget.resetKey}_${_header.id}'),
                  initialValue: _header.refDocNo,
                  decoration: _fieldDeco('เลขที่เอกสารอ้างอิง'),
                  readOnly: _isReadOnly,
                  onSaved: (v) => _header.refDocNo = v,
                  onChanged: (v) => _header.refDocNo = v,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: () async {
                    if (_isReadOnly) return;
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _header.refDocDate ?? DateTime.now(),
                      firstDate: DateTime(2000), lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _header.refDocDate = picked);
                  },
                  child: InputDecorator(
                    decoration: _fieldDeco('วันที่เอกสารอ้างอิง'),
                    child: Text(_header.refDocDate == null
                        ? '-'
                        : DateFormat('dd/MM/yyyy').format(_header.refDocDate!)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            // Row 2
            Row(children: [
              Expanded(
                flex: 10,
                child: TextFormField(
                  key: ValueKey('desc_${_header.id}'),
                  initialValue: _header.description,
                  decoration: _fieldDeco('คำอธิบายรายการ'),
                  readOnly: _isReadOnly,
                  onSaved: (v) => _header.description = v ?? '',
                ),
              ),
              const SizedBox(width: 8),
              // Branch — dialog picker
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: _isReadOnly ? null : () async {
                    final b = await _showBranchDialog();
                    if (!mounted) return;
                    if (b != null) {
                      setState(() {
                        _header.branchId   = b.id;
                        _header.branchCode = b.branchCode;
                        _header.branchName = b.branchNameThai;
                      });
                    } else if (_header.branchId != null) {
                      setState(() {
                        _header.branchId   = null;
                        _header.branchCode = null;
                        _header.branchName = null;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'สาขา',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      filled: true,
                      fillColor: _isReadOnly ? Colors.grey[100] : Colors.white,
                      suffixIcon: _isReadOnly
                          ? null
                          : const Icon(Icons.search, size: 16, color: Colors.teal),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: _header.branchCode?.isNotEmpty == true
                          ? [
                              Text(_header.branchCode!,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal[700])),
                              Text(_header.branchName ?? '',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ]
                          : [
                              Text('— ไม่ระบุ —',
                                  style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                            ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<Currency>(
                  value: _selectedCurrency,
                  isExpanded: true,
                  items: _currencies.map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c.currencyNameThai.isNotEmpty
                          ? '${c.currencyCode}  ${c.currencyNameThai}'
                          : c.currencyCode))).toList(),
                  selectedItemBuilder: (_) => _currencies
                      .map((c) => Text(c.currencyCode, overflow: TextOverflow.ellipsis))
                      .toList(),
                  decoration: _fieldDeco('สกุลเงิน'),
                  onChanged: _isReadOnly ? null : _onCurrencyChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextFormField(
                  key: ValueKey('rate_${_header.currencyId}_${_header.exchangeRate}'),
                  initialValue: _header.exchangeRate.toString(),
                  decoration: _fieldDeco('อัตราแลกเปลี่ยน',
                      forcedReadOnly: _selectedCurrency?.baseCurrencyFlag ?? true),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  readOnly: _isReadOnly || (_selectedCurrency?.baseCurrencyFlag ?? true),
                  onChanged: _onExchangeRateChanged,
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  // ── Detail section ───────────────────────────────────────────────────────
  Widget _buildDetailSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => setState(() => _detailExpanded = !_detailExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              const Icon(Icons.table_rows_outlined, size: 18, color: Colors.teal),
              const SizedBox(width: 6),
              Text('รายการเดบิต/เครดิต',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              Text('(${_details.length} รายการ)',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const Spacer(),
              Icon(_detailExpanded ? Icons.expand_less : Icons.expand_more, size: 18, color: Colors.grey),
            ]),
          ),
        ),
        if (_detailExpanded) ...[
          const Divider(height: 1),
          _buildDetailTable(),
          if (!_isReadOnly)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: TextButton.icon(
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: const Text('เพิ่มบรรทัด'),
                onPressed: _addDetailRow,
              ),
            ),
        ],
      ]),
    );
  }

  Widget _buildDetailTable() {
    final currency = _selectedCurrency?.currencyCode ?? _baseCurrency;
    final fmt = NumberFormat('#,##0.00', 'en_US');
    final balanced = (_header.totalDebitFc - _header.totalCreditFc).abs() < 0.005;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.teal[50]),
            headingTextStyle: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
            dataTextStyle: const TextStyle(fontSize: 14, color: Colors.black87),
            columnSpacing: 12,
            dataRowMinHeight: 56,
            dataRowMaxHeight: 76,
            columns: [
              const DataColumn(label: Text('#')),
              const DataColumn(label: Text('รหัสบัญชี')),
              ..._dimTypes.map((t) => DataColumn(label: Text(t.nameThai))),
              DataColumn(label: Text('เดบิต ($currency)')),
              DataColumn(label: Text('เครดิต ($currency)')),
              const DataColumn(label: Text('รายละเอียด')),
              if (!_isReadOnly) const DataColumn(label: SizedBox()),
            ],
            rows: [
              ..._details.asMap().entries.map((entry) {
              final i = entry.key;
              final detail = entry.value;
              final accountInfo = _accounts.firstWhere(
                (a) => a.id == detail.accountId,
                orElse: () => Account(
                    id: 0, accountCode: '', accountNameThai: '', accountNameEng: '',
                    accountType: '', accountSubType: '', normalBalance: '',
                    isNormalAccount: false, isReconcilable: false, currencyCode: '',
                    moduleLinkCode: '', costCenterRequired: false, projectRequired: false,
                    branchRequired: false, isActive: true, dimRules: const []),
              );
              return DataRow(cells: [
                DataCell(Text('${i + 1}')),
                // Account cell — dialog picker, 2-line after select, × to clear
                DataCell(SizedBox(
                  width: 160,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _isReadOnly ? null : () async {
                            final a = await _showAccountDialog();
                            if (a != null && mounted) {
                              setState(() {
                                detail.accountId   = a.id;
                                detail.accountCode = a.accountCode;
                                detail.accountName = a.accountNameThai;
                                for (final t in _dimTypes) {
                                  if (!a.dimRules.any((r) => r.typeCode == t.typeCode)) {
                                    _setDim(detail, t.slotNo, null);
                                  }
                                }
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: detail.accountCode.isEmpty
                                ? Text('คลิกเพื่อเลือก',
                                    style: TextStyle(fontSize: 14, color: Colors.grey[500]))
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(detail.accountCode,
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal[700])),
                                      Text(detail.accountName,
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      if (!_isReadOnly && detail.accountId != 0)
                        InkWell(
                          onTap: () => setState(() {
                            detail.accountId   = 0;
                            detail.accountCode = '';
                            detail.accountName = '';
                            for (final t in _dimTypes) _setDim(detail, t.slotNo, null);
                          }),
                          borderRadius: BorderRadius.circular(10),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(Icons.clear, size: 14, color: Colors.grey),
                          ),
                        ),
                    ],
                  ),
                )),
                // Dim cells
                ..._dimTypes.map((dimType) {
                  final hasDimRule = accountInfo.id != 0 &&
                      accountInfo.dimRules.any((r) => r.typeCode == dimType.typeCode);
                  if (!hasDimRule) {
                    return const DataCell(Text('—', style: TextStyle(color: Colors.grey)));
                  }
                  final values = _dimValues[dimType.typeCode] ?? [];
                  final selectedId = _getDimId(detail, dimType.slotNo);
                  final selectedVal = values.cast<GlDimensionValue?>()
                      .firstWhere((v) => v?.id == selectedId, orElse: () => null);
                  return DataCell(SizedBox(
                    width: 130,
                    child: GlDimensionPickerField(
                      dimType: dimType,
                      values: values,
                      selected: selectedVal,
                      readOnly: _isReadOnly,
                      isDense: true,
                      onSelected: (val) => setState(() => _setDim(detail, dimType.slotNo, val)),
                    ),
                  ));
                }),
                // Debit
                DataCell(SizedBox(width: 110, child: TextFormField(
                  controller: _debitCtrls[i],
                  decoration: InputDecoration(
                    isDense: true,
                    filled: !_isReadOnly,
                    fillColor: Colors.white,
                    border: InputBorder.none,
                    enabledBorder: _isReadOnly
                        ? InputBorder.none
                        : const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.teal, width: 1)),
                    focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.teal, width: 2)),
                  ),
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.right,
                  readOnly: _isReadOnly,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) {
                    detail.debitFc = double.tryParse(val) ?? 0;
                    if (detail.debitFc != 0 && detail.creditFc != 0) {
                      detail.creditFc = 0;
                      _creditCtrls[i].clear();
                    }
                    _calculateTotals();
                  },
                ))),
                // Credit
                DataCell(SizedBox(width: 110, child: TextFormField(
                  controller: _creditCtrls[i],
                  decoration: InputDecoration(
                    isDense: true,
                    filled: !_isReadOnly,
                    fillColor: Colors.white,
                    border: InputBorder.none,
                    enabledBorder: _isReadOnly
                        ? InputBorder.none
                        : const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.teal, width: 1)),
                    focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.teal, width: 2)),
                  ),
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.right,
                  readOnly: _isReadOnly,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) {
                    detail.creditFc = double.tryParse(val) ?? 0;
                    if (detail.creditFc != 0 && detail.debitFc != 0) {
                      detail.debitFc = 0;
                      _debitCtrls[i].clear();
                    }
                    _calculateTotals();
                  },
                ))),
                // Description
                DataCell(SizedBox(width: 220, child: TextFormField(
                  controller: _descCtrls[i],
                  decoration: InputDecoration(
                    isDense: true,
                    filled: !_isReadOnly,
                    fillColor: Colors.white,
                    border: InputBorder.none,
                    enabledBorder: _isReadOnly
                        ? InputBorder.none
                        : const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey, width: 0.8)),
                    focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.teal, width: 2)),
                  ),
                  style: const TextStyle(fontSize: 14),
                  readOnly: _isReadOnly,
                  onChanged: (val) => detail.description = val,
                ))),
                // Delete
                if (!_isReadOnly)
                  DataCell(IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.red),
                    visualDensity: VisualDensity.compact,
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
                  )),
              ]);
              }),
              // ── Totals row (align กับคอลัมน์เดบิต/เครดิต) ───────────────
              if (_details.isNotEmpty)
                DataRow(
                  color: WidgetStateProperty.resolveWith((states) =>
                      balanced ? Colors.teal[50] : Colors.red[50]),
                  cells: [
                    const DataCell(SizedBox()),
                    DataCell(Text('รวม',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: balanced ? Colors.teal[700] : Colors.red))),
                    ..._dimTypes.map((_) => const DataCell(SizedBox())),
                    DataCell(SizedBox(
                      width: 110,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(fmt.format(_header.totalDebitFc),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: balanced ? Colors.teal[700] : Colors.red)),
                          if (_baseCurrency != currency)
                            Text(fmt.format(_header.totalDebitLc),
                                textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        ],
                      ),
                    )),
                    DataCell(SizedBox(
                      width: 110,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(fmt.format(_header.totalCreditFc),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: balanced ? Colors.teal[700] : Colors.red)),
                          if (_baseCurrency != currency)
                            Text(fmt.format(_header.totalCreditLc),
                                textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        ],
                      ),
                    )),
                    const DataCell(SizedBox()),
                    if (!_isReadOnly) const DataCell(SizedBox()),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Balance indicator bar (fixed, shows only when unbalanced) ──────────────
  Widget _buildTotalsRow() {
    final balanced = (_header.totalDebitFc - _header.totalCreditFc).abs() < 0.005;
    if (balanced) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.red[50],
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
        const SizedBox(width: 6),
        const Text('ยอดไม่ดุล — กรุณาตรวจสอบยอดรวมเดบิต/เครดิตในตาราง',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    );
  }

  // ── Action buttons ───────────────────────────────────────────────────────
  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(children: [
        if (!_isReadOnly && _header.status == 'Draft') ...[
          OutlinedButton(onPressed: () => _save('Draft'), child: const Text('ดราฟท์')),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange[900]),
            onPressed: () => _save('Post'),
            child: const Text('โพสต์', style: TextStyle(color: Colors.white)),
          ),
        ] else if (_header.status == 'Posted') ...[
          if (_header.externalSourceId != null)
            Tooltip(
              message: 'รายการนี้สร้างจากโมดูลอื่น\nกรุณายกเลิกจากโมดูลต้นทาง',
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[400]),
                onPressed: null,
                icon: const Icon(Icons.lock_outline, size: 14),
                label: const Text('ถอย', style: TextStyle(color: Colors.white)),
              ),
            )
          else
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: _reverse,
              child: const Text('ถอย', style: TextStyle(color: Colors.white)),
            ),
        ],
        const Spacer(),
        TextButton(onPressed: widget.onCancel, child: const Text('กลับ')),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return Form(
      key: _formKey,
      child: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildHeaderCard(),
              const SizedBox(height: 4),
              _buildDetailSection(),
            ]),
          ),
        ),
        _buildTotalsRow(),
        _buildActionButtons(),
      ]),
    );
  }
}
