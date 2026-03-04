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
// import 'package:flutter/rendering.dart';
// import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart'; // Add intl package
import '../models/account.dart';
import '../models/gl_entry.dart';
import '../services/gl_entry_service.dart';
import '../../sa/models/module_document.dart'; // Import ModuleDocument

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
  final CurrencyService _currencyService = CurrencyService(); // Add Service
  bool _isLoading = false;

  // Data
  GlEntryHeader _header = GlEntryHeader(
    docId: 0,
    docDate: DateTime.now(),
    postingDate: DateTime.now(),
    currencyId: 1, // Default THB
    exchangeRate: 1.0,
  );
  List<GlEntryDetail> _details = [];
  List<ModuleDocument> _allowedDocTypes = [];

  List<ModuleDocument> _allDocTypes =
      []; // โหลดเอกสารทั้งหมดมาเลือกเป็น Reference
  ModuleDocument? _selectedRefDocType;

  // Master Data สำหรับเลือก
  List<Account> _accounts = []; // โหลดจากผังบัญชี
  List<BusinessUnit> _businessUnits = []; // ตัวอย่างข้อมูล
  List<Project> _projects = [];
  List<Branch> _branches = [];
  List<Currency> _currencies = []; // Add Currencies List
  String _baseCurrency = 'THB'; // Add Base Currency Code

  // UI State
  ModuleDocument? _selectedDocType;
  Currency? _selectedCurrency; // Add Selected Currency
  bool _isReadOnly = false; // True if Posted/Deleted

  @override
  void initState() {
    super.initState();
    // _loadData();
    _initMasterData();
  }

// เพิ่มฟังก์ชันนี้สำหรับโหลดข้อมูลหลักครั้งเดียว
  Future<void> _initMasterData() async {
    setState(() => _isLoading = true);
    try {
      _allowedDocTypes = await _service.fetchRowsByModuleUserId();
      _accounts = await _accountService.fetchRowsControlAccount();
      _businessUnits = await _buService.fetchRows();
      _projects = await _projectService.fetchRows();
      _branches = await _branchService.fetchRows();
      _currencies = await _currencyService.fetchActiveRows();
      _allDocTypes = await _service.fetchRows();

      // หลังจากโหลด Master Data เสร็จ ให้โหลดข้อมูลรายการต่อ
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
    if (widget.entryId != oldWidget.entryId) {
      _loadTransactionData();
    }
  }

  Future<void> _loadTransactionData() async {
    // ไม่ต้อง setState isLoading = true ที่นี่หากต้องการให้ Smooth
    // หรือถ้าอยากให้ขึ้นหมุนๆ ก็ใส่ได้ แต่อย่าโหลด Master Data ซ้ำ

    // Check ก่อนว่า Master Data พร้อมไหม ถ้าไม่พร้อมให้รอก่อน (กรณีเปิดมาแล้วกด Edit เลย)
    if (_allowedDocTypes.isEmpty && _accounts.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      if (widget.entryId == null) {
        _resetForm();
      } else {
        final data = await _service.fetchEntryDetail(widget.entryId!);

        // --- สำคัญ: ตรวจสอบว่า API ส่ง account_code กลับมาใน details หรือไม่ ---
        // ถ้า API ส่งมาแต่ ID แต่ไม่ส่ง Code มา ให้ Map ข้อมูลจาก Master Data กลับเข้าไป
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
                    isControlAccount: false,
                    isReconcilable: false,
                    currencyCode: '',
                    moduleLinkCode: '',
                    costCenterRequired: false,
                    projectRequired: false,
                    branchRequired: false));
            detail.accountCode = match.accountCode;
            detail.accountName = match.accountNameThai;
          }
          // ทำแบบเดียวกันกับ BusinessUnit, Branch, Project ถ้าจำเป็น
        }

        setState(() {
          _header = data['header'];
          // Map Reference Doc Type
          if (_header.refDocId != null && _allDocTypes.isNotEmpty) {
            try {
              _selectedRefDocType =
                  _allDocTypes.firstWhere((e) => e.id == _header.refDocId);
            } catch (_) {}
          }
          _details = loadedDetails;
          _isReadOnly = widget.viewOnly || _header.status != 'Draft';

          // Map DocType & Currency (Logic เดิม)
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
    // หา Base Currency (THB)
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
    _selectedCurrency = baseCurrency; // Set Default Currency
    _isReadOnly = false;
    _addDetailRow(); // Add 1 empty row
  }

  void _addDetailRow() {
    setState(() {
      _details.add(GlEntryDetail(accountId: 0));
    });
  }

  // คำนวณยอดรวม (ทั้ง FC และ LC)
  void _calculateTotals() {
    double drFc = 0, crFc = 0;
    double drLc = 0, crLc = 0;
    for (var d in _details) {
      // คำนวณ LC ระดับบรรทัด (FC * Rate)
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

// เมื่อเปลี่ยน Currency Dropdown
  void _onCurrencyChanged(Currency? val) {
    if (val == null) return;
    setState(() {
      _selectedCurrency = val;
      _header.currencyId = val.id!;
      // ถ้าเป็น Base Currency ให้ Rate = 1 เสมอ, ถ้าไม่ใช่ให้ใช้ Rate มาตรฐานของสกุลนั้นๆ
      if (val.baseCurrencyFlag) {
        _header.exchangeRate = 1.0;
      } else {
        _header.exchangeRate = val.baseRate;
      }
      _calculateTotals(); // Recalculate LC amounts
    });
  }

  // เมื่อเปลี่ยน Exchange Rate (Text Field)
  void _onExchangeRateChanged(String val) {
    double newRate = double.tryParse(val) ?? 0.0;
    setState(() {
      _header.exchangeRate = newRate;
      _calculateTotals();
    });
  }

  // Widget สำหรับเลือกบัญชีแบบค้นหาได้
  // Widget _buildAccountAutocomplete(int index) {
  //   return Autocomplete<Account>(
  //     optionsBuilder: (TextEditingValue textEditingValue) {
  //       if (textEditingValue.text.isEmpty) {
  //         return const Iterable<Account>.empty();
  //       }
  //       return _accounts.where((Account option) {
  //         return option.accountCode.contains(textEditingValue.text) ||
  //             option.accountNameThai
  //                 .toLowerCase()
  //                 .contains(textEditingValue.text.toLowerCase());
  //       });
  //     },
  //     displayStringForOption: (Account option) =>
  //         '${option.accountCode} - ${option.accountNameThai}',
  //     onSelected: (Account selection) {
  //       setState(() {
  //         _details[index].accountId = selection.id;
  //         _details[index].accountCode = selection.accountCode;
  //         // ตรวจสอบเงื่อนไข Required ต่างๆ จากโมเดล Account
  //         // และล้างค่าหากไม่จำเป็นต้องใช้ (หรือเก็บไว้ก็ได้)
  //       });
  //     },
  //     fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
  //       // กำหนดค่าเริ่มต้นถ้ามีข้อมูลเก่า
  //       if (controller.text.isEmpty && _details[index].accountCode.isNotEmpty) {
  //         controller.text = _details[index].accountCode;
  //       }
  //       return TextFormField(
  //         controller: controller,
  //         focusNode: focusNode,
  //         readOnly: _isReadOnly,
  //         decoration: const InputDecoration(
  //             border: OutlineInputBorder(),
  //             labelText: 'บัญชี',
  //             // hintText: 'รหัส/ชื่อบัญชี',
  //             isDense: true),
  //         validator: (v) => _details[index].accountId == 0 ? 'จำเป็น' : null,
  //       );
  //     },
  //   );
  // }

  Future<void> _save(String action) async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    // Calculate one last time to be sure
    _calculateTotals();

    // Validations (Check FC balance)
    if (action == 'Post' &&
        (_header.totalDebitFc - _header.totalCreditFc).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ยอด Dr/Cr ($_baseCurrency) ไม่เท่ากัน')));
      return;
    }
    // Optional: Check LC balance warnings (usually diff is from rounding)

    if (_details.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณาเพิ่มรายการบัญชี')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _service.saveEntry(_header, _details, action);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('บันทึกสำเร็จ')));
      widget.onSaveSuccess();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isDocDate) async {
    if (_isReadOnly) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: isDocDate ? _header.docDate : _header.postingDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
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

  // Widget Helper สำหรับ Text สีเทาใต้ Field
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
    // กำหนดรูปแบบตัวเลข
    final currencyFormat = NumberFormat("#,###,###,##0.00");
    // ค้นหา Account Info เพื่อตรวจสอบเงื่อนไข Required
    final accountInfo = _accounts.firstWhere((a) => a.id == detail.accountId,
        orElse: () => Account(
            id: 0,
            accountCode: '',
            accountNameThai: '',
            accountNameEng: '',
            accountType: '',
            accountSubType: '',
            normalBalance: '',
            isControlAccount: false,
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
          // เปลี่ยนเป็น Column เพื่อรองรับการขึ้นบรรทัดใหม่
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- บรรทัดที่ 1: Account, Dimensions, Amounts ---
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
                // 1. Account (บัญชี)
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
                          return _accounts.where((account) =>
                              account.accountCode.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase()) ||
                              account.accountNameEng.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase()) ||
                              account.accountNameThai.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase()));
                        },
                        displayStringForOption: (Account option) =>
                            '${option.accountCode} - ${option.accountNameThai}(${option.accountNameEng})',
                        initialValue:
                            TextEditingValue(text: detail.accountCode),
                        onSelected: (selection) {
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
                            // enabled: !_isReadOnly,
                            readOnly: _isReadOnly,
                          );
                        },
                      ),
                      // แสดงชื่อบัญชีใต้ Field
                      _buildUnderlineText(detail.accountName.isEmpty
                          ? '-'
                          : detail.accountName),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 2. Business Unit (หน่วยงาน)
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
                          // ถ้า Controller ว่าง แต่ใน Model มีค่า ให้ใส่ค่ากลับเข้าไป (ป้องกันค่าหายตอน Scroll)
                          if (controller.text != detail.businessUnitCode) {
                            controller.text = detail.businessUnitCode ?? '';
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
                      // แสดงชื่อหน่วยงานใต้ Field
                      _buildUnderlineText(
                          (detail.businessUnitName?.isEmpty ?? true)
                              ? '-'
                              : detail.businessUnitName ?? '-'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 3. Branch (สาขา)
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
                          // ถ้า Controller ว่าง แต่ใน Model มีค่า ให้ใส่ค่ากลับเข้าไป (ป้องกันค่าหายตอน Scroll)
                          if (controller.text != detail.branchCode) {
                            controller.text = detail.branchCode ?? '';
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
                      // แสดงชื่อสาขาใต้ Field
                      _buildUnderlineText((detail.branchName?.isEmpty ?? true)
                          ? '-'
                          : detail.branchName ?? '-'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 4. Project (โครงการ)
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
                          // ถ้า Controller ว่าง แต่ใน Model มีค่า ให้ใส่ค่ากลับเข้าไป (ป้องกันค่าหายตอน Scroll)
                          if (controller.text != detail.projectCode) {
                            controller.text = detail.projectCode ?? '';
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
                      // แสดงชื่อโครงการใต้ Field
                      _buildUnderlineText((detail.projectName?.isEmpty ?? true)
                          ? '-'
                          : detail.projectName ?? '-'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 5. Debit (FC / LC)
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        initialValue: detail.debitFc == 0
                            ? ''
                            : detail.debitFc.toString(),
                        decoration: InputDecoration(
                            labelStyle: TextStyle(color: Colors.grey[400]),
                            labelText:
                                'เดบิต (${_selectedCurrency?.currencyCode ?? _baseCurrency})',
                            isDense: true),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textAlign: TextAlign.right,
                        // enabled: !_isReadOnly,
                        readOnly: _isReadOnly,
                        onChanged: (val) {
                          setState(() {
                            detail.debitFc = double.tryParse(val) ?? 0;
                            _calculateTotals();
                          });
                        },
                      ),
                      // คำนวณ LC Real-time
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
                // 6. Credit (FC / LC)
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        initialValue: detail.creditFc == 0
                            ? ''
                            : detail.creditFc.toString(),
                        decoration: InputDecoration(
                            labelStyle: TextStyle(color: Colors.grey[400]),
                            labelText:
                                'เครดิต (${_selectedCurrency?.currencyCode ?? _baseCurrency})',
                            isDense: true),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textAlign: TextAlign.right,
                        // enabled: !_isReadOnly,
                        readOnly: _isReadOnly,
                        onChanged: (val) {
                          setState(() {
                            detail.creditFc = double.tryParse(val) ?? 0;
                            _calculateTotals();
                          });
                        },
                      ),
                      // คำนวณ LC Real-time
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
                Expanded(
                  flex: 5,
                  child: TextFormField(
                    initialValue: detail.description,
                    decoration: InputDecoration(
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      labelText: 'รายละเอียด (Description)',
                      isDense: true,
                      border:
                          const OutlineInputBorder(), // ใส่กรอบให้ดูชัดขึ้นว่าเป็นคนละส่วน
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                    // enabled: !_isReadOnly,
                    readOnly: _isReadOnly,
                    onChanged: (val) {
                      detail.description = val;
                      // ไม่ต้อง setState ใหญ่ แค่อัปเดตค่าในตัวแปร
                    },
                  ),
                ),

                // ปุ่มลบรายการ (แสดงเฉพาะตอนแก้ไข)
                if (!_isReadOnly)
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _details.removeAt(index);
                        _calculateTotals();
                      });
                    },
                  ),
              ],
            ),

            // // --- บรรทัดที่ 2: รายละเอียด (Description) ---
            // const SizedBox(height: 12), // เว้นระยะห่างบรรทัด
            // TextFormField(
            //   initialValue: detail.description,
            //   decoration: InputDecoration(
            //     labelStyle: TextStyle(color: Colors.grey[400]),
            //     labelText: 'รายละเอียด (Description)',
            //     isDense: true,
            //     border:
            //         const OutlineInputBorder(), // ใส่กรอบให้ดูชัดขึ้นว่าเป็นคนละส่วน
            //     contentPadding:
            //         const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            //   ),
            //   enabled: !_isReadOnly,
            //   onChanged: (val) {
            //     detail.description = val;
            //     // ไม่ต้อง setState ใหญ่ แค่อัปเดตค่าในตัวแปร
            //   },
            // ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ถ้าไม่ได้เลือกรายการและไม่ใช่โหมดเพิ่ม (กรณี Tab นี้ถูกเปิดแต่แรก)
    // หรือกำลังโหลด
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
                  // Row 1: DocType, DocNo, DocDate
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Doc Type
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
                      // Doc No
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
                      // Doc Date
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
                      // 2. Reference Doc No (Text)
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
                          onChanged: (v) =>
                              _header.refDocNo = v, // Update ทันที
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 3. Reference Doc Date (Date Picker)
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: () async {
                            if (_isReadOnly) return;
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _header.refDocDate ?? DateTime.now(),
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
                  // --- New Section: Reference Document Info ---
                  // Container(
                  //   padding: const EdgeInsets.all(8),
                  //   decoration: BoxDecoration(
                  //     color: Colors.grey[50],
                  //     border: Border.all(color: Colors.grey[300]!),
                  //     borderRadius: BorderRadius.circular(4),
                  //   ),
                  //   child: Column(
                  //     crossAxisAlignment: CrossAxisAlignment.start,
                  //     children: [
                  //       const Text('เอกสารอ้างอิง (Reference Document)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  //       const SizedBox(height: 8),
                  //       Row(
                  //         children: [
                  //           // 1. Reference Doc Type (Dropdown)
                  //           Expanded(
                  //             flex: 2,
                  //             child: DropdownButtonFormField<ModuleDocument>(
                  //               value: _selectedRefDocType,
                  //               items: _allDocTypes.map((e) => DropdownMenuItem(
                  //                 value: e,
                  //                 child: Text('${e.docCode} ${e.docNameThai}', overflow: TextOverflow.ellipsis)
                  //               )).toList(),
                  //               decoration: const InputDecoration(
                  //                 labelText: 'ประเภทเอกสารอ้างอิง',
                  //                 border: OutlineInputBorder(),
                  //                 isDense: true,
                  //               ),
                  //               onChanged: _isReadOnly ? null : (val) {
                  //                 setState(() {
                  //                   _selectedRefDocType = val;
                  //                   _header.refDocId = val?.id;
                  //                 });
                  //               },
                  //             ),
                  //           ),
                  //           const SizedBox(width: 8),
                  //           // 2. Reference Doc No (Text)
                  //           Expanded(
                  //             flex: 2,
                  //             child: TextFormField(
                  //               initialValue: _header.refDocNo,
                  //               decoration: const InputDecoration(
                  //                 labelText: 'เลขที่เอกสารอ้างอิง',
                  //                 border: OutlineInputBorder(),
                  //                 isDense: true,
                  //               ),
                  //               readOnly: _isReadOnly,
                  //               onSaved: (v) => _header.refDocNo = v,
                  //               onChanged: (v) => _header.refDocNo = v, // Update ทันที
                  //             ),
                  //           ),
                  //           const SizedBox(width: 8),
                  //           // 3. Reference Doc Date (Date Picker)
                  //           Expanded(
                  //             flex: 1,
                  //             child: InkWell(
                  //               onTap: () async {
                  //                   if (_isReadOnly) return;
                  //                   final picked = await showDatePicker(
                  //                     context: context,
                  //                     initialDate: _header.refDocDate ?? DateTime.now(),
                  //                     firstDate: DateTime(2000),
                  //                     lastDate: DateTime(2100),
                  //                   );
                  //                   if (picked != null) {
                  //                     setState(() => _header.refDocDate = picked);
                  //                   }
                  //               },
                  //               child: InputDecorator(
                  //                 decoration: const InputDecoration(
                  //                   labelText: 'วันที่เอกสารอ้างอิง',
                  //                   border: OutlineInputBorder(),
                  //                   isDense: true,
                  //                 ),
                  //                 child: Text(
                  //                   _header.refDocDate == null
                  //                     ? '-'
                  //                     : DateFormat('dd/MM/yyyy').format(_header.refDocDate!),
                  //                 ),
                  //               ),
                  //             ),
                  //           ),
                  //         ],
                  //       ),
                  //     ],
                  //   ),
                  // ),
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
                      // Currency Dropdown
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<Currency>(
                          value: _selectedCurrency,
                          items: _currencies
                              .map((c) => DropdownMenuItem(
                                  value: c, child: Text(c.currencyCode)))
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
                      // Exchange Rate
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
                              (_selectedCurrency?.baseCurrencyFlag ??
                                  true), // Readonly if Base Currency
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

          // --- Add Button (Footer) ---
          if (!_isReadOnly)
            Container(
              width: double.infinity,
              color: Colors.grey[200],
              child: IconButton(
                icon: const Icon(Icons.add, color: Colors.blue),
                onPressed: _addDetailRow,
              ),
            ),

          // --- Footer Totals & Actions ---
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.deepOrange[50],
            child: Row(
              // mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Column(
                //   crossAxisAlignment: CrossAxisAlignment.start,
                //   children: [
                //     Text(
                //         'รวมเดบิต : ${NumberFormat("#,###,###,##0.00").format(_header.totalDebitFc)} $_baseCurrency  |  ${NumberFormat("#,###,###,##0.00").format(_header.totalDebitLc)} ${_selectedCurrency?.currencyCode ?? ''}',
                //         style: const TextStyle(fontWeight: FontWeight.bold)),
                //     Text(
                //         'รวมเครดิต : ${NumberFormat("#,###,###,##0.00").format(_header.totalCreditFc)} $_baseCurrency  |  ${NumberFormat("#,###,###,##0.00").format(_header.totalCreditLc)} ${_selectedCurrency?.currencyCode ?? ''}',
                //         style: const TextStyle(fontWeight: FontWeight.bold)),
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
                          NumberFormat("##,###,###,##0.00")
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
                      // TextFormField(
                      //   style: const TextStyle(fontWeight: FontWeight.bold),
                      //   initialValue: _header.totalDebitFc == 0
                      //       ? ''
                      //       : NumberFormat("##,###,###,##0.00").format(_header.totalDebitFc),
                      //   decoration: InputDecoration(
                      //       labelStyle: TextStyle(color: Colors.grey[400]),
                      //       labelText: 'เดบิต ($_baseCurrency)',
                      //       isDense: true),
                      //   keyboardType: const TextInputType.numberWithOptions(
                      //       decimal: true),
                      //   textAlign: TextAlign.right,
                      //   enabled: false,
                      // ),
                      if (_baseCurrency != _selectedCurrency?.currencyCode)
                        Padding(
                          padding: const EdgeInsets.only(top: 0, right: 1),
                          child: Text(
                            _header.totalDebitLc == 0
                                ? ''
                                : '${NumberFormat("##,###,###,##0.00").format(_header.totalDebitLc)} $_baseCurrency',
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
                          NumberFormat("##,###,###,##0.00")
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
                      // TextFormField(
                      //   style: const TextStyle(fontWeight: FontWeight.bold),
                      //   initialValue: _header.totalCreditFc == 0
                      //       ? ''
                      //       : NumberFormat("##,###,###,##0.00").format(_header.totalCreditFc),
                      //   decoration: InputDecoration(
                      //       labelStyle: TextStyle(color: Colors.grey[400]),
                      //       labelText: 'เครดิต ($_baseCurrency)',
                      //       isDense: true),
                      //   keyboardType: const TextInputType.numberWithOptions(
                      //       decimal: true),
                      //   textAlign: TextAlign.right,
                      //   enabled: false,
                      // ),
                      if (_baseCurrency != _selectedCurrency?.currencyCode)
                        Padding(
                          padding: const EdgeInsets.only(top: 0, right: 1),
                          child: Text(
                            _header.totalCreditLc == 0
                                ? ''
                                : '${NumberFormat("##,###,###,##0.00").format(_header.totalCreditLc)} $_baseCurrency',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]),
                            textAlign: TextAlign.right,
                          ),
                        ),
                    ],
                  ),
                ),
                //   ],
                // ),
                const SizedBox(width: 8),
                if (widget.viewOnly)
                  Expanded(
                      flex: 5,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        // crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          OutlinedButton(
                              onPressed: widget.onCancel,
                              child: const Text('ยกเลิก')),
                          _header.status == 'Posted'
                              ? const SizedBox(width: 8)
                              : const SizedBox.shrink(),
                          // Show Reverse button if Posted
                          if (_header.status == 'Posted')
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red),
                              onPressed: () async {
                                // Call Reverse API
                                await _service.reverseEntry(_header.id);
                                widget.onSaveSuccess(); // Refresh List
                              },
                              child: const Text('ถอย',
                                  style: TextStyle(color: Colors.white)),
                            ),
                        ],
                      ))
                else if (_header.status ==
                    'Draft') // Show Save/Post buttons if Draft
                  Expanded(
                      flex: 5,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        // crossAxisAlignment: CrossAxisAlignment.end,
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
                        // crossAxisAlignment: CrossAxisAlignment.end,
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
