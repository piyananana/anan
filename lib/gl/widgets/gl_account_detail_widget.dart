// widgets/user_detail_form.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../cd/models/cd_currency.dart';
import '../../cd/services/cd_currency_service.dart';
import '../models/gl_account.dart';
import '../models/gl_dimension.dart';
import '../services/gl_dimension_service.dart';

class AccountDetailWidget extends StatefulWidget {
  final AccountMode mode;
  final Account? selected;
  final Function(Account) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;

  const AccountDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
  });

  @override
  State<AccountDetailWidget> createState() => AccountDetailWidgetState();
}

class AccountDetailWidgetState extends State<AccountDetailWidget> {
  Account? _selected;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _accountCodeController;
  late TextEditingController _accountNameThaiController;
  late TextEditingController _accountNameEngController;
  late String _accountType;
  late String _normalBalance;
  late bool _isNormalAccount;
  late bool _isControlAccount;
  late String _currencyCode;
  late bool _branchRequired;
  late bool _isActive;

  List<GlDimensionType> _dimTypes = [];
  Map<String, bool> _dimRules = {};

  bool _isSaving = false;
  bool _isEnglish = false;

  // final List<String> _accountTypes = [
  //   'ASSET',
  //   'LIABILITY',
  //   'EQUITY',
  //   'REVENUE',
  //   'EXPENSE',
  // ];

  final List<String> _normalBalances = [
    'DR',
    'CR',
  ];

  List<Currency> _currencyLists = [];
  // List<String> _moduleLinkCodes = []; // ควรโหลดจาก sa_module_link
  bool _isLoading = false;
  String _error = '';

  String _baseCurrencyCode() {
    // หาสกุลเงินที่มี baseCurrencyFlag เป็น true หรือคืนค่า 'THB' เป็นค่าเริ่มต้น
    return _currencyLists
        .firstWhere((c) => c.baseCurrencyFlag,
            orElse: () => Currency(
                id: 0,
                currencyCode: 'THB',
                currencyNameThai: 'ไม่พบสกุลเงินหลัก',
                currencyNameEng: '',
                baseRate: 1.0,
                baseCurrencyFlag: true,
                numOfDecimal: 2,
                isActive: true))
        .currencyCode;
  }

  void _initDimRules(Account? account) {
    _dimRules = {for (final r in account?.dimRules ?? []) r.typeCode: r.isRequired};
  }

  Future<void> _loadDimTypes() async {
    final types = await GlDimensionService().fetchActiveTypes();
    if (mounted) setState(() => _dimTypes = types);
  }

  Future<void> _fetchCurrencyLists() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final dataService = Provider.of<CurrencyService>(context, listen: false);
      final fetched = await dataService.fetchActiveRows();
      setState(() {
        _currencyLists = fetched;
        _isLoading = false;
        // ถ้าเป็น record ใหม่ ให้ set ค่า default เป็นสกุลเงินหลัก
        if (_selected == null) _currencyCode = _baseCurrencyCode();
      });
    } catch (e) {
      final isEnglish = _isEnglish;
      setState(() {
        _error = isEnglish
            ? 'Unable to load data: ${e.toString()}'
            : 'ไม่สามารถโหลดข้อมูลได้: ${e.toString()}';
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_error)),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchCurrencyLists();
    _loadDimTypes();

    _selected = widget.selected;
    _accountCodeController =
        TextEditingController(text: _selected?.accountCode ?? '');
    _accountType = _selected?.accountType ?? 'ASSET';
    _normalBalance = _selected?.normalBalance ?? 'DR';
    _currencyCode = _selected?.currencyCode ?? _baseCurrencyCode();
    _isActive = _selected?.isActive ?? true;
    if (widget.mode == AccountMode.addChild) {
      _accountNameThaiController.clear();
      _accountNameEngController.clear();
      _isNormalAccount = true;
      _isControlAccount = false;
      _branchRequired = false;
      _initDimRules(null);
    } else {
      _accountNameThaiController =
          TextEditingController(text: _selected?.accountNameThai ?? '');
      _accountNameEngController =
          TextEditingController(text: _selected?.accountNameEng ?? '');
      _isNormalAccount = _selected?.isNormalAccount ?? true;
      _isControlAccount = _selected?.isControlAccount ?? false;
      _branchRequired = _selected?.branchRequired ?? false;
      _initDimRules(_selected);
    }
  }

  @override
  void didUpdateWidget(covariant AccountDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // if (oldWidget.selected != null) {
    if (widget.selected != oldWidget.selected) {
      _selected = widget.selected;

      _accountCodeController =
          TextEditingController(text: _selected?.accountCode ?? '');
      _accountType = _selected?.accountType ?? 'ASSET';
      _normalBalance = _selected?.normalBalance ?? 'DR';
      _currencyCode = _selected?.currencyCode ?? _baseCurrencyCode();
      _isActive = _selected?.isActive ?? true;

      if (widget.mode == AccountMode.addChild) {
        _accountNameThaiController.clear();
        _accountNameEngController.clear();
        _isNormalAccount = true;
        _isControlAccount = false;
        _branchRequired = false;
        _initDimRules(null);
      } else {
        _accountNameThaiController =
            TextEditingController(text: _selected?.accountNameThai ?? '');
        _accountNameEngController =
            TextEditingController(text: _selected?.accountNameEng ?? '');
        _isNormalAccount = _selected?.isNormalAccount ?? false;
        _isControlAccount = _selected?.isControlAccount ?? false;
        _branchRequired = _selected?.branchRequired ?? false;
        _initDimRules(_selected);
      }
    } else if (widget.mode == AccountMode.addRoot &&
        oldWidget.mode != AccountMode.addRoot) {
      _selected = null;
      _accountCodeController.clear();
      _accountNameThaiController.clear();
      _accountNameEngController.clear();
      _accountType = 'ASSET';
      _normalBalance = 'DR';
      _isNormalAccount = false;
      _isControlAccount = false;
      _currencyCode = _baseCurrencyCode();
      _branchRequired = false;
      _isActive = true;
      _initDimRules(null);
    } else if (widget.mode == AccountMode.addChild &&
        oldWidget.mode != AccountMode.addChild) {
      _selected = widget.selected;
      _accountCodeController =
          TextEditingController(text: _selected?.accountCode ?? '');
      _accountNameThaiController.clear();
      _accountNameEngController.clear();
      _accountType = _selected?.accountType ?? 'ASSET';
      _normalBalance = _selected?.normalBalance ?? 'DR';
      _isNormalAccount = true;
      _isControlAccount = false;
      _currencyCode = _baseCurrencyCode();
      _branchRequired = false;
      _isActive = true;
      _initDimRules(null);
    }
  }

  @override
  void dispose() {
    _accountCodeController.dispose();
    _accountNameThaiController.dispose();
    _accountNameEngController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    final isEnglish = _isEnglish;
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });
      try {
        final newDetail = Account(
          id: widget.mode == AccountMode.edit ? widget.selected!.id : 0,
          parentId: widget.mode == AccountMode.addRoot
              ? null
              : widget.mode == AccountMode.addChild
                  ? widget.selected!.id
                  : widget.selected!.parentId,
          accountCode: _accountCodeController.text,
          accountNameThai: _accountNameThaiController.text,
          accountNameEng: _accountNameEngController.text,
          accountType: _accountType,
          normalBalance: _normalBalance,
          isNormalAccount: _isNormalAccount,
          isControlAccount: _isControlAccount,
          currencyCode: _currencyCode,
          branchRequired: _branchRequired,
          isActive: _isActive,
          dimRules: _dimRules.entries
              .where((e) => e.value)
              .map((e) => GlAccountDimRule(typeCode: e.key, isRequired: true))
              .toList(),
        );
        await widget.onSubmit(newDetail);
        // if (mounted) {
        //   ScaffoldMessenger.of(context).showSnackBar(
        //     SnackBar(
        //       content: Text(widget.mode == AccountMode.edit
        //           ? 'บันทึกข้อมูลเรียบร้อย: ${_accountCodeController.text} ${_accountNameThaiController.text}'
        //           : 'เพิ่มข้อมูลเรียบร้อย: ${_accountCodeController.text} ${_accountNameThaiController.text}'),
        //       backgroundColor: Colors.green,
        //     ),
        //   );
        // }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEnglish ? 'An error occurred: $e' : 'เกิดข้อผิดพลาด: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final l = AppL10n(isEnglish);
    if (widget.isPlaceholder) {
      return Center(
        child: Text(isEnglish
            ? 'Select a chart of accounts item to edit or delete, or press the + button to add a new account code'
            : 'เลือกรายการผังบัญชีเพื่อแก้ไข หรือ ลบ หรือ กดปุ่ม + เพื่อเพิ่มรหัสบัญชีใหม่'),
      );
    }

    final bool readOnly = widget.mode == AccountMode.view;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.mode == AccountMode.view
                  ? (isEnglish ? 'View Data' : 'ดูข้อมูล')
                  : widget.mode == AccountMode.edit
                      ? (isEnglish ? 'Edit Data' : 'แก้ไขข้อมูล')
                      : widget.mode == AccountMode.addChild
                          ? '${isEnglish ? 'Add sub-account' : 'เพิ่มข้อมูลย่อย'}: ${_selected?.accountCode} ${isEnglish && (_selected?.accountNameEng.isNotEmpty ?? false) ? _selected?.accountNameEng : _selected?.accountNameThai}'
                          : (isEnglish ? 'Add Main Category' : 'เพิ่มข้อมูลหมวดหลัก'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            TextFormField(
              readOnly: widget.mode != AccountMode.addRoot && widget.mode != AccountMode.addChild,
              controller: _accountCodeController,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: isEnglish ? 'Account Code' : 'รหัสบัญชี',
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return isEnglish ? 'Please enter the account code' : 'กรุณาป้อนรหัสบัญชี';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    readOnly: readOnly,
                    controller: _accountNameThaiController,
                    decoration: InputDecoration(
                      labelText: isEnglish ? 'Account Name (Thai)' : 'ชื่อบัญชี (ภาษาไทย)',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return isEnglish
                            ? 'Please enter the account name (Thai)'
                            : 'กรุณาป้อนชื่อบัญชี (ภาษาไทย)';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    readOnly: readOnly,
                    controller: _accountNameEngController,
                    decoration: InputDecoration(
                      labelText: isEnglish ? 'Account Name (English)' : 'ชื่อบัญชี (ภาษาอังกฤษ)',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return isEnglish
                            ? 'Please enter the account name (English)'
                            : 'กรุณาป้อนชื่อบัญชี (ภาษาอังกฤษ)';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _accountType,
                      decoration: InputDecoration(
                        labelText: isEnglish
                            ? 'Account Type (Asset, Liability, Equity, Revenue, Expense)'
                            : 'หมวดบัญชี (สินทรัพย์, หนี้สิน, ส่วนของเจ้าของ, รายได้, ค่าใช้จ่าย)',
                        border: const OutlineInputBorder(),
                      ),
                      items: accountTypeOptions.entries.map((e) {
                        return DropdownMenuItem<String>(
                          value: e.key,
                          child: Text('${e.key} - ${accountTypeLabel(e.key, isEnglish)}'),
                        );
                      }).toList(),
                      onChanged: readOnly ? null : (value) {
                        if (value != null) {
                          setState(() {
                            _accountType = value;
                            if (value == 'ASSET' || value == 'EXPENSE') {
                              _normalBalance = 'DR';
                            } else {
                              _normalBalance = 'CR';
                            }
                          });
                        }
                      },
                    ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _normalBalance,
                    decoration: InputDecoration(
                      labelText: isEnglish ? 'Normal Balance (Debit/Credit)' : 'ดุลบัญชีปกติ (เดบิต/เครดิต)',
                      border: const OutlineInputBorder(),
                    ),
                    items: _normalBalances.map((val) {
                      return DropdownMenuItem(
                        value: val,
                        child: Text(val),
                      );
                    }).toList(),
                    onChanged: readOnly ? null : (value) {
                      if (value != null) {
                        setState(() {
                          _normalBalance = value;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _currencyCode,
                    decoration: InputDecoration(
                      labelText: isEnglish ? 'Base Currency' : 'สกุลเงินหลัก',
                      border: const OutlineInputBorder(),
                    ),
                    items: _currencyLists.map((val) {
                      final currencyName = isEnglish && val.currencyNameEng.isNotEmpty
                          ? val.currencyNameEng
                          : val.currencyNameThai;
                      return DropdownMenuItem(
                        value: val.currencyCode,
                        child: Text('${val.currencyCode} - $currencyName'),
                      );
                    }).toList(),
                    onChanged: readOnly ? null : (value) {
                      if (value != null) {
                        setState(() {
                          _currencyCode = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(isEnglish
                      ? 'Status: ${_isActive ? 'Active' : 'Inactive'}'
                      : 'สถานะ: ${_isActive ? 'ใช้งาน' : 'หยุดใช้'}'),
                ),
                Switch(
                  value: _isActive,
                  onChanged: readOnly ? null : (bool value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(isEnglish
                      ? 'Posting: ${_isNormalAccount ? 'Normal account (can post)' : 'Header/summary account'}'
                      : 'การลงรายการบัญชี: ${_isNormalAccount ? 'บัญชีปกติ (ลงรายการได้)' : 'เป็นหัวบัญชี/สะสมยอด'}'),
                ),
                Switch(
                  value: _isNormalAccount,
                  onChanged: readOnly ? null : (bool value) {
                    setState(() {
                      _isNormalAccount = value;
                    });
                  },
                ),
              ],
            ),
            _isNormalAccount
                ? Column(children: [
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(isEnglish
                              ? 'Control Account: ${_isControlAccount ? 'Postable only from other modules' : 'Can be posted in GL module'}'
                              : 'Control Account: ${_isControlAccount ? 'บันทึกได้เฉพาะจากโมดูลอื่น' : 'บันทึกในโมดูล GL ได้'}'),
                        ),
                        Switch(
                          value: _isControlAccount,
                          onChanged: readOnly ? null : (bool value) {
                            setState(() {
                              _isControlAccount = value;
                            });
                          },
                        ),
                      ],
                    ),
                    ..._dimTypes.expand((t) {
                      final enabled = _dimRules[t.typeCode] ?? false;
                      final dimName = isEnglish && (t.nameEng?.isNotEmpty ?? false)
                          ? t.nameEng!
                          : t.nameThai;
                      return [
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(
                            child: Text(isEnglish
                                ? '$dimName: ${enabled ? 'Required when posting' : 'Not required when posting'}'
                                : '$dimName: ${enabled ? 'ต้องระบุเมื่อทำรายการ' : 'ไม่ต้องระบุเมื่อทำรายการ'}'),
                          ),
                          Switch(
                            value: enabled,
                            onChanged: readOnly
                                ? null
                                : (v) => setState(() => _dimRules[t.typeCode] = v),
                          ),
                        ]),
                      ];
                    }),
                  ])
                : const SizedBox.shrink(),
            const SizedBox(height: 32),
            // --- Buttons ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                widget.mode == AccountMode.view
                    ? Container() // ไม่แสดงปุ่มใดๆ หากเป็นโหมดดูอย่างเดียว
                    : Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _submitForm,
                          icon: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save),
                          label: Text(_isSaving
                              ? (isEnglish ? 'Saving...' : 'กำลังบันทึก...')
                              : widget.mode == AccountMode.edit
                                  ? l.save
                                  : l.add),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.cancel),
                    label: Text(l.cancel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
