import 'package:anan/cd/models/branch.dart';
import 'package:anan/cd/models/business_unit.dart';
import 'package:anan/cd/models/project.dart';
import 'package:anan/cd/models/currency.dart';
import 'package:anan/cd/services/branch_service.dart';
import 'package:anan/cd/services/business_unit_service.dart';
import 'package:anan/cd/services/project_service.dart';
import 'package:anan/cd/services/currency_service.dart';
import 'package:anan/gl/services/account_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/account.dart';
import '../models/gl_entry.dart';
import '../models/period.dart';
import '../services/gl_entry_service.dart';
import '../services/period_service.dart';
import '../../sa/models/module_document.dart';

class GlEntryDetailWidget extends StatefulWidget {
  final int? entryId;
  final bool viewOnly;
  final VoidCallback onSaveSuccess;
  final VoidCallback onCancel;

  const GlEntryDetailWidget({
    super.key,
    this.entryId,
    this.viewOnly = false,
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
  final BusinessUnitService _buService = BusinessUnitService();
  final ProjectService _projectService = ProjectService();
  final BranchService _branchService = BranchService();
  final CurrencyService _currencyService = CurrencyService();
  final PeriodService _periodService = PeriodService();
  bool _isLoading = false;

  // งวดบัญชีที่ gl_status = OPEN
  List<PostingPeriod> _openPeriods = [];

  // Data
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

  // Master Data
  List<Account> _accounts = [];
  List<BusinessUnit> _businessUnits = [];
  List<Project> _projects = [];
  List<Branch> _branches = [];
  List<Currency> _currencies = [];
  String _baseCurrency = 'THB';

  // UI State
  ModuleDocument? _selectedDocType;
  Currency? _selectedCurrency;
  bool _isReadOnly = false;

  // Detail row controllers
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
        _buService.fetchRows(),
        _projectService.fetchRows(),
        _branchService.fetchRows(),
        _currencyService.fetchActiveRows(),
        _service.fetchRows(),
        _periodService.fetchOpenGlPeriods(),
      ]);
      _allowedDocTypes = results[0] as List<ModuleDocument>;
      _accounts = results[1] as List<Account>;
      _businessUnits = results[2] as List<BusinessUnit>;
      _projects = results[3] as List<Project>;
      _branches = results[4] as List<Branch>;
      _currencies = results[5] as List<Currency>;
      _allDocTypes = results[6] as List<ModuleDocument>;
      _openPeriods = results[7] as List<PostingPeriod>;
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
        widget.viewOnly != oldWidget.viewOnly) {
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
            final match = _accounts.firstWhere((a) => a.id == detail.accountId,
                orElse: () => Account(
                    id: 0,
                    accountCode: '',
                    accountNameThai: '',
                    accountNameEng: '',
                    isActive: true,
                    accountType: '',
                    accountSubType: '',
                    normalBalance: '',
                    isNormalAccount: false,
                    isReconcilable: false,
                    currencyCode: '',
                    moduleLinkCode: '',
                    costCenterRequired: false,
                    projectRequired: false,
                    branchRequired: false));
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

        // Initialize controllers for loaded details
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
                id: 1,
                currencyCode: 'THB',
                currencyNameThai: '',
                currencyNameEng: '',
                baseRate: 1,
                baseCurrencyFlag: true,
                numOfDecimal: 2,
                isActive: true));

    _header = GlEntryHeader(
      docId: 0,
      docDate: DateTime.now(),
      postingDate: DateTime.now(),
      status: 'Draft',
      currencyId: baseCurrency.id ?? 1,
      exchangeRate: baseCurrency.baseRate,
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
    double drFc = 0, crFc = 0;
    double drLc = 0, crLc = 0;
    for (var d in _details) {
      d.debitLc =
          double.parse((d.debitFc * _header.exchangeRate).toStringAsFixed(2));
      d.creditLc =
          double.parse((d.creditFc * _header.exchangeRate).toStringAsFixed(2));
      drFc += d.debitFc;
      crFc += d.creditFc;
      drLc += d.debitLc;
      crLc += d.creditLc;
    }
    setState(() {
      _header.totalDebitFc = drFc;
      _header.totalCreditFc = crFc;
      _header.totalDebitLc = drLc;
      _header.totalCreditLc = crLc;
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
            'ต้องการสร้างรายการถอย (Reverse) สำหรับเอกสารนี้ใช่หรือไม่?\nระบบจะสร้างรายการใหม่ที่มียอดตรงข้ามกัน'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ยืนยันถอย',
                style: TextStyle(color: Colors.white)),
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
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      if (isDocDate) {
        // ตรวจสอบว่าวันที่เอกสารอยู่ในงวดบัญชีที่ OPEN
        final pickedDay = DateTime(picked.year, picked.month, picked.day);
        final inOpenPeriod = _openPeriods.any((p) =>
            !pickedDay.isBefore(p.periodStartDate) &&
            !pickedDay.isAfter(p.periodEndDate));
        if (!inOpenPeriod) {
          messenger.showSnackBar(const SnackBar(
            content: Text(
                'วันที่เอกสารต้องอยู่ในงวดบัญชีที่เปิด (GL Status = OPEN)'),
            backgroundColor: Colors.red,
          ));
          return;
        }
      }
      setState(() {
        if (isDocDate) {
          _header.docDate = picked;
        } else {
          _header.postingDate = picked;
        }
      });
    }
  }

  String _getBaseCurrency() {
    final item = _currencies.firstWhere((e) => e.baseCurrencyFlag == true,
        orElse: () => Currency(
            id: 0,
            isActive: true,
            currencyCode: 'THB',
            currencyNameThai: '',
            currencyNameEng: '',
            baseRate: 1,
            baseCurrencyFlag: true,
            numOfDecimal: 2));
    return item.currencyCode;
  }

  Widget _buildUnderlineText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, left: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  Widget _buildDetailItem(int index) {
    final detail = _details[index];
    final currencyFormat = NumberFormat("#,##0.00", "en_US");
    final accountInfo = _accounts.firstWhere((a) => a.id == detail.accountId,
        orElse: () => Account(
            id: 0,
            accountCode: '',
            accountNameThai: '',
            accountNameEng: '',
            accountType: '',
            accountSubType: '',
            normalBalance: '',
            isNormalAccount: false,
            isReconcilable: false,
            currencyCode: '',
            moduleLinkCode: '',
            costCenterRequired: false,
            projectRequired: false,
            branchRequired: false,
            isActive: true));

    return Card(
      key: ObjectKey(detail),
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.grey[400],
                  radius: 20,
                  child: Text('${index + 1}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                // 1. Account
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Autocomplete<Account>(
                        optionsBuilder: (textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<Account>.empty();
                          }
                          final q = textEditingValue.text.toLowerCase();
                          return _accounts.where((account) =>
                              !account.isControlAccount &&
                              (account.accountCode.toLowerCase().contains(q) ||
                               account.accountNameEng.toLowerCase().contains(q) ||
                               account.accountNameThai.toLowerCase().contains(q)));
                        },
                        displayStringForOption: (Account option) =>
                            '${option.accountCode} - ${option.accountNameThai}(${option.accountNameEng})',
                        initialValue:
                            TextEditingValue(text: detail.accountCode),
                        onSelected: (selection) {
                          if (selection.isControlAccount) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'บัญชีนี้เป็น Control Account ไม่สามารถลงรายการในโมดูล GL ได้'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          setState(() {
                            detail.accountId = selection.id;
                            detail.accountCode = selection.accountCode;
                            detail.accountName = selection.accountNameThai;
                          });
                        },
                        fieldViewBuilder:
                            (context, controller, focusNode, onFieldSubmitted) {
                          if (controller.text != detail.accountCode) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted &&
                                  controller.text != detail.accountCode) {
                                controller.text = detail.accountCode;
                              }
                            });
                          }
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                                labelStyle: TextStyle(color: Colors.grey[400]),
                                labelText: 'รหัสบัญชี',
                                isDense: true),
                            readOnly: _isReadOnly,
                          );
                        },
                      ),
                      _buildUnderlineText(detail.accountName.isEmpty
                          ? '-'
                          : detail.accountName),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 2. Business Unit
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Autocomplete<BusinessUnit>(
                        optionsBuilder: (textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<BusinessUnit>.empty();
                          }
                          return _businessUnits.where((businessUnit) =>
                              businessUnit.buCode.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase()) ||
                              businessUnit.buNameEng.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase()) ||
                              businessUnit.buNameThai.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase()));
                        },
                        displayStringForOption: (BusinessUnit option) =>
                            '${option.buCode} - ${option.buNameThai}(${option.buNameEng})',
                        initialValue: TextEditingValue(
                            text: detail.businessUnitCode ?? ''),
                        onSelected: (selection) {
                          setState(() {
                            detail.businessUnitId = selection.id;
                            detail.businessUnitCode = selection.buCode;
                            detail.businessUnitName = selection.buNameThai;
                          });
                        },
                        fieldViewBuilder:
                            (context, controller, focusNode, onFieldSubmitted) {
                          if (controller.text != detail.businessUnitCode) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted &&
                                  controller.text != detail.businessUnitCode) {
                                controller.text = detail.businessUnitCode ?? '';
                              }
                            });
                          }
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                                labelStyle: TextStyle(color: Colors.grey[400]),
                                labelText: 'รหัสหน่วยงาน',
                                isDense: true),
                            enabled:
                                accountInfo.costCenterRequired ? true : false,
                            readOnly: _isReadOnly,
                          );
                        },
                      ),
                      _buildUnderlineText(
                          (detail.businessUnitName?.isEmpty ?? true)
                              ? '-'
                              : detail.businessUnitName ?? '-'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 3. Branch
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Autocomplete<Branch>(
                        optionsBuilder: (textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<Branch>.empty();
                          }
                          return _branches.where((branch) =>
                              branch.branchCode.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase()) ||
                              branch.branchNameEng.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase()) ||
                              branch.branchNameThai.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase()));
                        },
                        displayStringForOption: (Branch option) =>
                            '${option.branchCode} - ${option.branchNameThai}(${option.branchNameEng})',
                        initialValue:
                            TextEditingValue(text: detail.branchCode ?? ''),
                        onSelected: (selection) {
                          setState(() {
                            detail.branchId = selection.id;
                            detail.branchCode = selection.branchCode;
                            detail.branchName = selection.branchNameThai;
                          });
                        },
                        fieldViewBuilder:
                            (context, controller, focusNode, onFieldSubmitted) {
                          if (controller.text != detail.branchCode) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted &&
                                  controller.text != detail.branchCode) {
                                controller.text = detail.branchCode ?? '';
                              }
                            });
                          }
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                                labelStyle: TextStyle(color: Colors.grey[400]),
                                labelText: 'รหัสสาขา',
                                isDense: true),
                            enabled: accountInfo.branchRequired ? true : false,
                            readOnly: _isReadOnly,
                          );
                        },
                      ),
                      _buildUnderlineText((detail.branchName?.isEmpty ?? true)
                          ? '-'
                          : detail.branchName ?? '-'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 4. Project
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Autocomplete<Project>(
                        optionsBuilder: (textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<Project>.empty();
                          }
                          return _projects.where((project) =>
                              project.projectCode.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase()) ||
                              project.projectNameEng.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase()) ||
                              project.projectNameThai.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase()));
                        },
                        displayStringForOption: (Project option) =>
                            '${option.projectCode} - ${option.projectNameThai}(${option.projectNameEng})',
                        initialValue:
                            TextEditingValue(text: detail.projectCode ?? ''),
                        onSelected: (selection) {
                          setState(() {
                            detail.projectId = selection.id;
                            detail.projectCode = selection.projectCode;
                            detail.projectName = selection.projectNameThai;
                          });
                        },
                        fieldViewBuilder:
                            (context, controller, focusNode, onFieldSubmitted) {
                          if (controller.text != detail.projectCode) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted &&
                                  controller.text != detail.projectCode) {
                                controller.text = detail.projectCode ?? '';
                              }
                            });
                          }
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                                labelStyle: TextStyle(color: Colors.grey[400]),
                                labelText: 'รหัสโครงการ',
                                isDense: true),
                            enabled: accountInfo.projectRequired ? true : false,
                            readOnly: _isReadOnly,
                          );
                        },
                      ),
                      _buildUnderlineText((detail.projectName?.isEmpty ?? true)
                          ? '-'
                          : detail.projectName ?? '-'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 5. Debit (FC)
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _debitCtrls[index],
                        decoration: InputDecoration(
                            labelStyle: TextStyle(color: Colors.grey[400]),
                            labelText:
                                'เดบิต (${_selectedCurrency?.currencyCode ?? _baseCurrency})',
                            isDense: true),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textAlign: TextAlign.right,
                        readOnly: _isReadOnly,
                        onChanged: (val) {
                          detail.debitFc = double.tryParse(val) ?? 0;
                          if (detail.debitFc != 0 && detail.creditFc != 0) {
                            detail.creditFc = 0;
                            _creditCtrls[index].clear();
                          }
                          _calculateTotals();
                        },
                      ),
                      if (_baseCurrency != _selectedCurrency?.currencyCode)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, right: 4),
                          child: Text(
                            detail.debitFc == 0
                                ? ''
                                : '${currencyFormat.format(detail.debitFc * _header.exchangeRate)} $_baseCurrency',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]),
                            textAlign: TextAlign.right,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 6. Credit (FC)
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _creditCtrls[index],
                        decoration: InputDecoration(
                            labelStyle: TextStyle(color: Colors.grey[400]),
                            labelText:
                                'เครดิต (${_selectedCurrency?.currencyCode ?? _baseCurrency})',
                            isDense: true),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textAlign: TextAlign.right,
                        readOnly: _isReadOnly,
                        onChanged: (val) {
                          detail.creditFc = double.tryParse(val) ?? 0;
                          if (detail.creditFc != 0 && detail.debitFc != 0) {
                            detail.debitFc = 0;
                            _debitCtrls[index].clear();
                          }
                          _calculateTotals();
                        },
                      ),
                      if (_baseCurrency != _selectedCurrency?.currencyCode)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, right: 4),
                          child: Text(
                            detail.creditFc == 0
                                ? ''
                                : '${currencyFormat.format(detail.creditFc * _header.exchangeRate)} $_baseCurrency',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]),
                            textAlign: TextAlign.right,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 7. Description
                Expanded(
                  flex: 5,
                  child: TextFormField(
                    controller: _descCtrls[index],
                    decoration: InputDecoration(
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      labelText: 'รายละเอียด (Description)',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                    readOnly: _isReadOnly,
                    onChanged: (val) {
                      detail.description = val;
                    },
                  ),
                ),

                // Delete button
                if (!_isReadOnly)
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () {
                      _debitCtrls[index].dispose();
                      _creditCtrls[index].dispose();
                      _descCtrls[index].dispose();
                      _debitCtrls.removeAt(index);
                      _creditCtrls.removeAt(index);
                      _descCtrls.removeAt(index);
                      _details.removeAt(index);
                      _calculateTotals();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Form(
      key: _formKey,
      child: Column(
        children: [
          // --- Header Form ---
          Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  // Row 1: DocType, DocNo, DocDate, RefDocType, RefDocNo, RefDocDate
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: DropdownButtonFormField<ModuleDocument>(
                          value: _selectedDocType,
                          items: _allowedDocTypes
                              .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text('${e.docCode} ${e.docNameThai}')))
                              .toList(),
                          decoration: const InputDecoration(
                            labelText: 'ประเภทเอกสาร',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: _isReadOnly
                              ? null
                              : (val) {
                                  setState(() {
                                    _selectedDocType = val;
                                    _header.docId = val!.id;
                                    _header.isAutoNumbering =
                                        val.isAutoNumbering;
                                    if (val.isAutoNumbering) {
                                      _header.docNo = 'AUTO';
                                    } else {
                                      _header.docNo = '';
                                    }
                                  });
                                },
                          validator: (v) => v == null ? 'กรุณาเลือก' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          key: ValueKey('docNo_${_header.docNo}'),
                          initialValue: _header.docNo,
                          decoration: const InputDecoration(
                            labelText: 'เลขที่เอกสาร',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          readOnly: _isReadOnly ||
                              (_selectedDocType?.isAutoNumbering ?? false),
                          onSaved: (v) => _header.docNo = v ?? '',
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'ระบุเลขที่' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: () => _selectDate(context, true),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'วันที่เอกสาร',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            child: Text(DateFormat('dd/MM/yyyy')
                                .format(_header.docDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: DropdownButtonFormField<ModuleDocument>(
                          value: _selectedRefDocType,
                          items: _allDocTypes
                              .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text('${e.docCode} ${e.docNameThai}',
                                      overflow: TextOverflow.ellipsis)))
                              .toList(),
                          decoration: const InputDecoration(
                            labelText: 'ประเภทเอกสารอ้างอิง',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: _isReadOnly
                              ? null
                              : (val) {
                                  setState(() {
                                    _selectedRefDocType = val;
                                    _header.refDocId = val?.id;
                                  });
                                },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          initialValue: _header.refDocNo,
                          decoration: const InputDecoration(
                            labelText: 'เลขที่เอกสารอ้างอิง',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
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
                              initialDate:
                                  _header.refDocDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() => _header.refDocDate = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'วันที่เอกสารอ้างอิง',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            child: Text(
                              _header.refDocDate == null
                                  ? '-'
                                  : DateFormat('dd/MM/yyyy')
                                      .format(_header.refDocDate!),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Row 2: Description, Currency, Exchange Rate
                  Row(
                    children: [
                      Expanded(
                        flex: 13,
                        child: TextFormField(
                          key: ValueKey('desc_${_header.id}'),
                          initialValue: _header.description,
                          decoration: const InputDecoration(
                            labelText: 'คำอธิบายรายการ',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          readOnly: _isReadOnly,
                          onSaved: (v) => _header.description = v ?? '',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<Currency>(
                          value: _selectedCurrency,
                          isExpanded: true,
                          items: _currencies
                              .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      c.currencyNameThai.isNotEmpty
                                          ? '${c.currencyCode}  ${c.currencyNameThai}'
                                          : c.currencyCode,
                                    ),
                                  ))
                              .toList(),
                          selectedItemBuilder: (_) => _currencies
                              .map((c) => Text(c.currencyCode,
                                  overflow: TextOverflow.ellipsis))
                              .toList(),
                          decoration: const InputDecoration(
                            labelText: 'สกุลเงิน',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: _isReadOnly ? null : _onCurrencyChanged,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          key: ValueKey(
                              'rate_${_header.currencyId}_${_header.exchangeRate}'),
                          initialValue: _header.exchangeRate.toString(),
                          decoration: const InputDecoration(
                            labelText: 'อัตราแลกเปลี่ยน',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          readOnly: _isReadOnly ||
                              (_selectedCurrency?.baseCurrencyFlag ?? true),
                          onChanged: _onExchangeRateChanged,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // --- Detail Table ---
          Expanded(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: _details.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (ctx, index) {
                  return _buildDetailItem(index);
                },
              ),
            ),
          ),

          // --- Add Row Button ---
          if (!_isReadOnly)
            Container(
              width: double.infinity,
              color: Colors.grey[200],
              child: IconButton(
                icon: const Icon(Icons.add, color: Colors.blue),
                onPressed: _addDetailRow,
              ),
            ),

          // --- Footer: Totals & Actions ---
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.deepOrange[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Expanded(
                  flex: 9,
                  child: Text(
                      _header.totalDebitFc == _header.totalCreditFc
                          ? 'ยอดรวม   '
                          : 'ยอดรวมไม่ดุล   ',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          color: _header.totalDebitFc == _header.totalCreditFc
                              ? Colors.black
                              : Colors.red,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                          NumberFormat("#,##0.00", "en_US")
                              .format(_header.totalDebitFc),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              color:
                                  _header.totalDebitFc == _header.totalCreditFc
                                      ? Colors.black
                                      : Colors.red,
                              fontWeight: FontWeight.bold)),
                      if (_baseCurrency != _selectedCurrency?.currencyCode)
                        const Divider(),
                      if (_baseCurrency != _selectedCurrency?.currencyCode)
                        Padding(
                          padding: const EdgeInsets.only(top: 0, right: 1),
                          child: Text(
                            _header.totalDebitLc == 0
                                ? ''
                                : '${NumberFormat("#,##0.00", "en_US").format(_header.totalDebitLc)} $_baseCurrency',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]),
                            textAlign: TextAlign.right,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                          NumberFormat("#,##0.00", "en_US")
                              .format(_header.totalCreditFc),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              color:
                                  _header.totalDebitFc == _header.totalCreditFc
                                      ? Colors.black
                                      : Colors.red,
                              fontWeight: FontWeight.bold)),
                      if (_baseCurrency != _selectedCurrency?.currencyCode)
                        const Divider(),
                      if (_baseCurrency != _selectedCurrency?.currencyCode)
                        Padding(
                          padding: const EdgeInsets.only(top: 0, right: 1),
                          child: Text(
                            _header.totalCreditLc == 0
                                ? ''
                                : '${NumberFormat("#,##0.00", "en_US").format(_header.totalCreditLc)} $_baseCurrency',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]),
                            textAlign: TextAlign.right,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (widget.viewOnly)
                  Expanded(
                      flex: 5,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                              onPressed: widget.onCancel,
                              child: const Text('ยกเลิก')),
                          if (_header.status == 'Posted') ...[
                            const SizedBox(width: 8),
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
                        ],
                      ))
                else if (_header.status == 'Draft')
                  Expanded(
                      flex: 5,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                              onPressed: widget.onCancel,
                              child: const Text('ยกเลิก')),
                          const SizedBox(width: 8),
                          OutlinedButton(
                              onPressed: () => _save('Draft'),
                              child: const Text('ดราฟท์')),
                          const SizedBox(width: 8),
                          ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepOrange[900]),
                              onPressed: () => _save('Post'),
                              child: const Text('โพสต์',
                                  style: TextStyle(color: Colors.white))),
                        ],
                      ))
                else
                  Expanded(
                      flex: 5,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                              onPressed: widget.onCancel,
                              child: const Text('ยกเลิก')),
                        ],
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
