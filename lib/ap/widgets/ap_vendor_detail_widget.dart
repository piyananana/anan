import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../sa/models/anan_module.dart';
import '../../cd/models/zipcode.dart';
import '../../cd/models/currency.dart';
import '../../cd/services/currency_service.dart';
import '../../cd/widgets/zipcode_list_widget.dart';
import '../../cd/models/bank.dart';
import '../../cd/models/bank_branch.dart';
import '../../cd/services/bank_branch_service.dart';
import '../../cd/widgets/bank_list_widget.dart';
import '../../cd/models/business_type.dart';
import '../../cd/services/business_type_service.dart';
import '../../gl/models/account.dart';
import '../../gl/services/account_service.dart';
import '../models/ap_vendor.dart';
import '../services/ap_vendor_running_service.dart';
import '../widgets/ap_vendor_group_list_widget.dart';

// ---------------------------------------------------------------------------
// Collapsible section
// ---------------------------------------------------------------------------
class _Section extends StatefulWidget {
  final String title;
  final bool initiallyExpanded;
  final List<Widget> children;
  final Widget? trailing;

  const _Section({
    required this.title,
    this.initiallyExpanded = true,
    required this.children,
    this.trailing,
  });

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            color: Colors.blueGrey.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.blueGrey.shade600,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey.shade800,
                    ),
                  ),
                ),
                if (widget.trailing != null) widget.trailing!,
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.children,
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Address Dialog
// ---------------------------------------------------------------------------
Future<ApVendorAddress?> showAddressDialog(
    BuildContext context, ApVendorAddress? existing, bool readOnly,
    {ApVendorAddress? primaryAddress}) async {
  final addrTypeCtrl = ValueNotifier<String>(existing?.addressType ?? 'billing');
  final noCtrl = TextEditingController(text: existing?.addressNo ?? '');
  final buildingCtrl = TextEditingController(text: existing?.addressBuildingVillage ?? '');
  final alleyCtrl = TextEditingController(text: existing?.addressAlley ?? '');
  final roadCtrl = TextEditingController(text: existing?.addressRoad ?? '');
  final subDistCtrl = TextEditingController(text: existing?.addressSubDistrict ?? '');
  final distCtrl = TextEditingController(text: existing?.addressDistrict ?? '');
  final provCtrl = TextEditingController(text: existing?.addressProvince ?? '');
  final countryCtrl = TextEditingController(text: existing?.addressCountry ?? 'Thailand');
  final zipCtrl = TextEditingController(text: existing?.addressZipCode ?? '');
  final isDefaultNotifier = ValueNotifier<bool>(existing?.isDefault ?? false);
  bool useSameAddress = false;

  final showSameAddressCheckbox =
      !readOnly && primaryAddress != null && existing?.isDefault != true;

  void applySameAddress() {
    noCtrl.text = primaryAddress?.addressNo ?? '';
    buildingCtrl.text = primaryAddress?.addressBuildingVillage ?? '';
    alleyCtrl.text = primaryAddress?.addressAlley ?? '';
    roadCtrl.text = primaryAddress?.addressRoad ?? '';
    subDistCtrl.text = primaryAddress?.addressSubDistrict ?? '';
    distCtrl.text = primaryAddress?.addressDistrict ?? '';
    provCtrl.text = primaryAddress?.addressProvince ?? '';
    countryCtrl.text = primaryAddress?.addressCountry ?? 'Thailand';
    zipCtrl.text = primaryAddress?.addressZipCode ?? '';
  }

  return showDialog<ApVendorAddress>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateDialog) {
        final fieldsReadOnly = readOnly || useSameAddress;

        Widget buildField(String label, TextEditingController ctrl) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                readOnly: fieldsReadOnly,
                controller: ctrl,
                decoration: InputDecoration(
                    labelText: label, border: const OutlineInputBorder()),
              ),
            );

        return AlertDialog(
          title: Text(readOnly
              ? 'ดูที่อยู่'
              : existing == null
                  ? 'เพิ่มที่อยู่'
                  : 'แก้ไขที่อยู่'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showSameAddressCheckbox)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('ใช้ที่อยู่เดียวกับที่อยู่หลัก'),
                        value: useSameAddress,
                        activeColor: Colors.teal,
                        onChanged: (v) {
                          setStateDialog(() {
                            useSameAddress = v ?? false;
                            if (useSameAddress) applySameAddress();
                          });
                        },
                      ),
                    ),
                  ValueListenableBuilder<String>(
                    valueListenable: addrTypeCtrl,
                    builder: (_, v, __) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: v,
                        decoration: const InputDecoration(
                            labelText: 'ประเภทที่อยู่',
                            border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'billing', child: Text('ที่อยู่ใบแจ้งหนี้')),
                          DropdownMenuItem(value: 'shipping', child: Text('ที่อยู่จัดส่ง')),
                          DropdownMenuItem(value: 'billing note', child: Text('ที่อยู่วางบิล')),
                          DropdownMenuItem(value: 'payment', child: Text('ที่อยู่ชำระเงิน')),
                          DropdownMenuItem(value: 'other', child: Text('อื่นๆ')),
                        ],
                        onChanged: readOnly
                            ? null
                            : (val) {
                                if (val != null) addrTypeCtrl.value = val;
                              },
                      ),
                    ),
                  ),
                  Row(children: [
                    Expanded(child: buildField('บ้านเลขที่ / ห้อง', noCtrl)),
                    const SizedBox(width: 8),
                    Expanded(child: buildField('อาคาร / หมู่บ้าน', buildingCtrl)),
                  ]),
                  Row(children: [
                    Expanded(child: buildField('ซอย', alleyCtrl)),
                    const SizedBox(width: 8),
                    Expanded(child: buildField('ถนน', roadCtrl)),
                  ]),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (!readOnly)
                        IconButton(
                          icon: const Icon(Icons.search, color: Colors.blue),
                          tooltip: 'ค้นหา ตำบล/แขวง, อำเภอ/เขต, จังหวัด, รหัสไปรษณีย์',
                          onPressed: () {
                            ZipcodeListWidget.search(
                              ctx,
                              onSelected: (Zipcode z) {
                                subDistCtrl.text = z.subDistrict;
                                distCtrl.text = z.district;
                                provCtrl.text = z.province;
                                zipCtrl.text = z.zipcode;
                              },
                            );
                          },
                        ),
                      Expanded(
                        child: Column(
                          children: [
                            Row(children: [
                              Expanded(child: buildField('ตำบล / แขวง', subDistCtrl)),
                              const SizedBox(width: 8),
                              Expanded(child: buildField('อำเภอ / เขต', distCtrl)),
                            ]),
                            Row(children: [
                              Expanded(child: buildField('จังหวัด', provCtrl)),
                              const SizedBox(width: 8),
                              Expanded(child: buildField('รหัสไปรษณีย์', zipCtrl)),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                  buildField('ประเทศ', countryCtrl),
                  ValueListenableBuilder<bool>(
                    valueListenable: isDefaultNotifier,
                    builder: (_, v, __) => SwitchListTile(
                      title: const Text('ที่อยู่หลัก'),
                      value: v,
                      onChanged: readOnly
                          ? null
                          : (val) => isDefaultNotifier.value = val,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (!readOnly)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop(ApVendorAddress(
                    id: existing?.id,
                    vendorId: existing?.vendorId,
                    addressType: addrTypeCtrl.value,
                    addressNo: noCtrl.text.isEmpty ? null : noCtrl.text,
                    addressBuildingVillage: buildingCtrl.text.isEmpty ? null : buildingCtrl.text,
                    addressAlley: alleyCtrl.text.isEmpty ? null : alleyCtrl.text,
                    addressRoad: roadCtrl.text.isEmpty ? null : roadCtrl.text,
                    addressSubDistrict: subDistCtrl.text.isEmpty ? null : subDistCtrl.text,
                    addressDistrict: distCtrl.text.isEmpty ? null : distCtrl.text,
                    addressProvince: provCtrl.text.isEmpty ? null : provCtrl.text,
                    addressCountry: countryCtrl.text.isEmpty ? 'Thailand' : countryCtrl.text,
                    addressZipCode: zipCtrl.text.isEmpty ? null : zipCtrl.text,
                    isDefault: isDefaultNotifier.value,
                  ));
                },
                child: const Text('บันทึก'),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ปิด'),
            ),
          ],
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// Contact Dialog
// ---------------------------------------------------------------------------
Future<ApVendorContact?> showContactDialog(
    BuildContext context, ApVendorContact? existing, bool readOnly) async {
  final nameCtrl = TextEditingController(text: existing?.contactName ?? '');
  final posCtrl = TextEditingController(text: existing?.position ?? '');
  final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
  final mobileCtrl = TextEditingController(text: existing?.mobile ?? '');
  final emailCtrl = TextEditingController(text: existing?.email ?? '');
  final isDefaultNotifier = ValueNotifier<bool>(existing?.isDefault ?? false);

  return showDialog<ApVendorContact>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(readOnly
          ? 'ดูผู้ติดต่อ'
          : existing == null
              ? 'เพิ่มผู้ติดต่อ'
              : 'แก้ไขผู้ติดต่อ'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                readOnly: readOnly,
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'ชื่อผู้ติดต่อ *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                readOnly: readOnly,
                controller: posCtrl,
                decoration: const InputDecoration(
                    labelText: 'ตำแหน่ง', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      readOnly: readOnly,
                      controller: phoneCtrl,
                      decoration: const InputDecoration(
                          labelText: 'โทรศัพท์', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      readOnly: readOnly,
                      controller: mobileCtrl,
                      decoration: const InputDecoration(
                          labelText: 'มือถือ', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                readOnly: readOnly,
                controller: emailCtrl,
                decoration: const InputDecoration(
                    labelText: 'อีเมล', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder<bool>(
                valueListenable: isDefaultNotifier,
                builder: (_, v, __) => SwitchListTile(
                  title: const Text('ผู้ติดต่อหลัก'),
                  value: v,
                  onChanged: readOnly
                      ? null
                      : (val) => isDefaultNotifier.value = val,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (!readOnly)
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(ApVendorContact(
                id: existing?.id,
                vendorId: existing?.vendorId,
                contactName: nameCtrl.text.trim(),
                position: posCtrl.text.isEmpty ? null : posCtrl.text,
                phone: phoneCtrl.text.isEmpty ? null : phoneCtrl.text,
                mobile: mobileCtrl.text.isEmpty ? null : mobileCtrl.text,
                email: emailCtrl.text.isEmpty ? null : emailCtrl.text,
                isDefault: isDefaultNotifier.value,
              ));
            },
            child: const Text('บันทึก'),
          ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('ปิด'),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Bank Account Dialog
// ---------------------------------------------------------------------------
Future<ApVendorBankAccount?> showBankDialog(
    BuildContext context, ApVendorBankAccount? existing, bool readOnly) {
  return showDialog<ApVendorBankAccount>(
    context: context,
    builder: (ctx) => _BankAccountDialog(existing: existing, readOnly: readOnly),
  );
}

class _BankAccountDialog extends StatefulWidget {
  final ApVendorBankAccount? existing;
  final bool readOnly;
  const _BankAccountDialog({this.existing, required this.readOnly});

  @override
  State<_BankAccountDialog> createState() => _BankAccountDialogState();
}

class _BankAccountDialogState extends State<_BankAccountDialog> {
  Bank? _selectedBank;
  String _bankDisplay = '';

  late final TextEditingController _branchCtrl;
  List<BankBranch> _allBranches = [];
  List<BankBranch> _branchSuggestions = [];

  late final TextEditingController _accNumCtrl;
  late final TextEditingController _accNameCtrl;
  String _accType = 'current';
  bool _isDefault = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _bankDisplay = e?.bankName ?? '';
    _branchCtrl = TextEditingController(text: e?.branchName ?? '');
    _accNumCtrl = TextEditingController(text: e?.accountNumber ?? '');
    _accNameCtrl = TextEditingController(text: e?.accountName ?? '');
    _accType = e?.accountType ?? 'current';
    _isDefault = e?.isDefault ?? false;
    _loadBranches();
  }

  @override
  void dispose() {
    _branchCtrl.dispose();
    _accNumCtrl.dispose();
    _accNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    try {
      final list = await BankBranchService().fetchRows();
      if (mounted) setState(() => _allBranches = list);
    } catch (_) {}
  }

  void _onBranchChanged(String text) {
    setState(() {
      if (text.trim().isEmpty) {
        _branchSuggestions = [];
      } else {
        final q = text.trim().toLowerCase();
        _branchSuggestions = _allBranches
            .where((b) => b.branchName.toLowerCase().contains(q))
            .toList();
        if (_selectedBank != null) {
          _branchSuggestions.sort((a, b) {
            final aOwn = a.bankId == _selectedBank!.id ? 0 : 1;
            final bOwn = b.bankId == _selectedBank!.id ? 0 : 1;
            return aOwn.compareTo(bOwn);
          });
        }
      }
    });
  }

  void _selectSuggestion(BankBranch branch) {
    setState(() {
      _branchCtrl.text = branch.branchName;
      _branchCtrl.selection = TextSelection.collapsed(offset: branch.branchName.length);
      _branchSuggestions = [];
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final branchName = _branchCtrl.text.trim();
      if (_selectedBank?.id != null && branchName.isNotEmpty) {
        final alreadyExists = _allBranches.any((b) =>
            b.bankId == _selectedBank!.id &&
            b.branchName.toLowerCase() == branchName.toLowerCase());
        if (!alreadyExists) {
          try {
            await BankBranchService().addRow(BankBranch(
              bankId: _selectedBank!.id!,
              branchName: branchName,
              isActive: true,
            ));
          } catch (_) {}
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(ApVendorBankAccount(
        id: widget.existing?.id,
        vendorId: widget.existing?.vendorId,
        bankName: _bankDisplay.isEmpty ? null : _bankDisplay,
        branchName: branchName.isEmpty ? null : branchName,
        accountNumber: _accNumCtrl.text.trim().isEmpty ? null : _accNumCtrl.text.trim(),
        accountName: _accNameCtrl.text.trim().isEmpty ? null : _accNameCtrl.text.trim(),
        accountType: _accType,
        isDefault: _isDefault,
      ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = widget.readOnly;
    return AlertDialog(
      title: Text(readOnly
          ? 'ดูบัญชีธนาคาร'
          : widget.existing == null
              ? 'เพิ่มบัญชีธนาคาร'
              : 'แก้ไขบัญชีธนาคาร'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'ธนาคาร',
                  border: const OutlineInputBorder(),
                  suffixIcon: readOnly
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_bankDisplay.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                tooltip: 'ล้าง',
                                onPressed: () => setState(() {
                                  _selectedBank = null;
                                  _bankDisplay = '';
                                  _branchCtrl.clear();
                                  _branchSuggestions = [];
                                }),
                              ),
                            IconButton(
                              icon: const Icon(Icons.search, size: 18),
                              tooltip: 'เลือกธนาคาร',
                              onPressed: () async {
                                await BankListWidget.search(context,
                                    onSelected: (bank) {
                                  if (mounted) {
                                    setState(() {
                                      _selectedBank = bank;
                                      _bankDisplay = bank.displayName;
                                      _branchCtrl.clear();
                                      _branchSuggestions = [];
                                    });
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                ),
                child: Text(
                  _bankDisplay.isEmpty ? '—' : _bankDisplay,
                  style: TextStyle(
                    fontWeight: _bankDisplay.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                    color: _bankDisplay.isNotEmpty ? null : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _branchCtrl,
                readOnly: readOnly,
                decoration: InputDecoration(
                  labelText: 'สาขา',
                  border: const OutlineInputBorder(),
                  suffixIcon: (!readOnly && _branchCtrl.text.isNotEmpty)
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() {
                            _branchCtrl.clear();
                            _branchSuggestions = [];
                          }),
                        )
                      : null,
                ),
                onChanged: _onBranchChanged,
              ),
              if (_branchSuggestions.isNotEmpty && !readOnly)
                Container(
                  constraints: const BoxConstraints(maxHeight: 160),
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _branchSuggestions.length,
                    itemBuilder: (_, i) {
                      final b = _branchSuggestions[i];
                      final isOwnBank = _selectedBank != null && b.bankId == _selectedBank!.id;
                      return ListTile(
                        dense: true,
                        title: Text(b.branchName,
                            style: TextStyle(
                                fontWeight: isOwnBank ? FontWeight.bold : FontWeight.normal)),
                        subtitle: Text(b.bankDisplay,
                            style: TextStyle(
                                fontSize: 11,
                                color: isOwnBank ? Colors.blue.shade700 : Colors.grey)),
                        onTap: () => _selectSuggestion(b),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 10),
              TextField(
                readOnly: readOnly,
                controller: _accNumCtrl,
                decoration: const InputDecoration(
                    labelText: 'เลขที่บัญชี', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                readOnly: readOnly,
                controller: _accNameCtrl,
                decoration: const InputDecoration(
                    labelText: 'ชื่อบัญชี', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _accType,
                decoration: const InputDecoration(
                    labelText: 'ประเภทบัญชี', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'current', child: Text('กระแสรายวัน')),
                  DropdownMenuItem(value: 'savings', child: Text('ออมทรัพย์')),
                ],
                onChanged: readOnly
                    ? null
                    : (val) {
                        if (val != null) setState(() => _accType = val);
                      },
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text('บัญชีหลัก'),
                value: _isDefault,
                onChanged: readOnly ? null : (val) => setState(() => _isDefault = val),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (!readOnly)
          ElevatedButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('บันทึก'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ปิด'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Main Detail Widget
// ---------------------------------------------------------------------------
class ApVendorDetailWidget extends StatefulWidget {
  final Mode mode;
  final ApVendor? selected;
  final Future<void> Function(ApVendor) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;

  const ApVendorDetailWidget({
    super.key,
    required this.mode,
    required this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
  });

  @override
  State<ApVendorDetailWidget> createState() => ApVendorDetailWidgetState();
}

class ApVendorDetailWidgetState extends State<ApVendorDetailWidget> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;

  late TextEditingController _codeCtrl;
  late TextEditingController _oldCodeCtrl;
  late TextEditingController _nameTHCtrl;
  late TextEditingController _nameENCtrl;
  late TextEditingController _taxIdCtrl;
  late TextEditingController _remarkCtrl;
  late TextEditingController _creditMonthsCtrl;
  late TextEditingController _creditDaysCtrl;

  bool _isActive = true;

  // สกุลเงิน
  String? _selectedCurrencyCode;
  String? _selectedCurrencyNameThai;
  List<Currency> _currencies = [];

  // รหัสอัตโนมัติ
  bool _autoNumberingEnabled = false;
  bool? _vendorGroupIsAutoNumber;
  bool _autoCodeOverridden = false;

  bool get _effectiveAutoNumbering {
    if (_vendorGroupId != null && (_vendorGroupIsAutoNumber == true)) return true;
    return _autoNumberingEnabled;
  }

  // ฟิลด์ที่เชื่อมกับตารางอื่น
  int? _vendorGroupId;
  String? _vendorGroupCode;
  String? _vendorGroupName;
  int? _businessTypeId;
  String? _businessTypeCode;
  String? _businessTypeNameThai;
  String? _vendorType;
  int? _apAccountId;
  String? _apAccountCode;
  String? _apAccountNameThai;

  List<ApVendorAddress> _addresses = [];
  List<ApVendorContact> _contacts = [];
  List<ApVendorBankAccount> _bankAccounts = [];

  List<BusinessType> _businessTypes = [];
  List<Account> _controlAccounts = [];

  bool get _isReadOnly => widget.mode == Mode.view || widget.mode == Mode.none;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadDropdowns();
    _loadCurrencies();
    _loadAutoNumberingConfig();
    if (widget.selected != null) _populate(widget.selected!);
    if (widget.selected == null) _loadDefaultCurrency();
  }

  void _initControllers() {
    _codeCtrl         = TextEditingController();
    _oldCodeCtrl      = TextEditingController();
    _nameTHCtrl       = TextEditingController();
    _nameENCtrl       = TextEditingController();
    _taxIdCtrl        = TextEditingController();
    _remarkCtrl       = TextEditingController();
    _creditMonthsCtrl = TextEditingController(text: '0');
    _creditDaysCtrl   = TextEditingController(text: '30');
  }

  @override
  void didUpdateWidget(covariant ApVendorDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected || widget.mode != oldWidget.mode) {
      if (widget.selected != null) {
        _populate(widget.selected!);
      } else {
        _clear();
        _loadDefaultCurrency();
      }
      if (widget.mode == Mode.add) _loadAutoNumberingConfig();
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose(); _oldCodeCtrl.dispose(); _nameTHCtrl.dispose();
    _nameENCtrl.dispose(); _taxIdCtrl.dispose(); _remarkCtrl.dispose();
    _creditMonthsCtrl.dispose(); _creditDaysCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDropdowns() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        BusinessTypeService().fetchActiveRows(),
        AccountService().fetchRows(),
      ]);
      if (mounted) {
        setState(() {
          _businessTypes   = results[0] as List<BusinessType>;
          final allAccounts = results[1] as List<Account>;
          _controlAccounts = allAccounts
              .where((a) => a.isControlAccount && a.isActive)
              .toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCurrencies() async {
    try {
      final list = await CurrencyService().fetchActiveRows();
      if (mounted) {
        setState(() {
          _currencies = list;
          if (_selectedCurrencyCode != null) {
            final match = _currencies.cast<Currency?>().firstWhere(
                (c) => c?.currencyCode == _selectedCurrencyCode,
                orElse: () => null);
            _selectedCurrencyNameThai = match?.currencyNameThai;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadDefaultCurrency() async {
    try {
      final code = await CurrencyService().getBaseCurrencyCode();
      if (mounted && _selectedCurrencyCode == null) {
        setState(() => _selectedCurrencyCode = code);
      }
    } catch (_) {
      if (mounted && _selectedCurrencyCode == null) {
        setState(() => _selectedCurrencyCode = 'THB');
      }
    }
  }

  Future<void> _loadAutoNumberingConfig() async {
    if (widget.mode != Mode.add) return;
    try {
      final config = await ApVendorRunningService().fetchConfig();
      if (mounted) setState(() => _autoNumberingEnabled = config.isAutoNumbering);
    } catch (_) {}
  }

  void _populate(ApVendor v) {
    _codeCtrl.text         = v.vendorCode;
    _oldCodeCtrl.text      = v.oldVendorCode ?? '';
    _nameTHCtrl.text       = v.vendorNameTh;
    _nameENCtrl.text       = v.vendorNameEn ?? '';
    _taxIdCtrl.text        = v.taxId ?? '';
    _remarkCtrl.text       = v.remark ?? '';
    _creditMonthsCtrl.text = '${v.creditTermMonths}';
    _creditDaysCtrl.text   = '${v.creditTermDays}';
    _isActive              = v.isActive;
    _selectedCurrencyCode  = v.currencyCode;
    _selectedCurrencyNameThai = null;
    _vendorGroupId         = v.vendorGroupId;
    _vendorGroupCode       = v.vendorGroupCode;
    _vendorGroupName       = v.vendorGroupName;
    _vendorGroupIsAutoNumber = null;
    _businessTypeId        = v.businessTypeId;
    _businessTypeCode      = v.businessTypeCode;
    _businessTypeNameThai  = v.businessTypeNameThai;
    _vendorType            = v.vendorType;
    _apAccountId           = v.apAccountId;
    _apAccountCode         = v.apAccountCode;
    _apAccountNameThai     = v.apAccountNameThai;
    _addresses   = List.from(v.addresses);
    _contacts    = List.from(v.contacts);
    _bankAccounts = List.from(v.bankAccounts);
  }

  void _clear() {
    _codeCtrl.clear(); _oldCodeCtrl.clear(); _nameTHCtrl.clear();
    _nameENCtrl.clear(); _taxIdCtrl.clear(); _remarkCtrl.clear();
    _creditMonthsCtrl.text = '0'; _creditDaysCtrl.text = '30';
    _isActive = true;
    _selectedCurrencyCode = null; _selectedCurrencyNameThai = null;
    _vendorGroupId = null; _vendorGroupCode = null; _vendorGroupName = null;
    _vendorGroupIsAutoNumber = null; _autoCodeOverridden = false;
    _businessTypeId = null; _businessTypeCode = null; _businessTypeNameThai = null;
    _vendorType = null;
    _apAccountId = null; _apAccountCode = null; _apAccountNameThai = null;
    _addresses = []; _contacts = []; _bankAccounts = [];
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final vendor = ApVendor(
        id: widget.selected?.id,
        vendorCode: (_effectiveAutoNumbering && !_autoCodeOverridden)
            ? ''
            : _codeCtrl.text.trim().toUpperCase(),
        oldVendorCode: _oldCodeCtrl.text.trim().isEmpty ? null : _oldCodeCtrl.text.trim(),
        vendorNameTh: _nameTHCtrl.text.trim(),
        vendorNameEn: _nameENCtrl.text.trim().isEmpty ? null : _nameENCtrl.text.trim(),
        taxId: _taxIdCtrl.text.trim().isEmpty ? null : _taxIdCtrl.text.trim(),
        vendorGroupId: _vendorGroupId,
        vendorGroupCode: _vendorGroupCode,
        vendorGroupName: _vendorGroupName,
        businessTypeId: _businessTypeId,
        businessTypeCode: _businessTypeCode,
        businessTypeNameThai: _businessTypeNameThai,
        vendorType: _vendorType,
        creditTermMonths: int.tryParse(_creditMonthsCtrl.text) ?? 0,
        creditTermDays: int.tryParse(_creditDaysCtrl.text) ?? 30,
        currencyCode: _selectedCurrencyCode ?? 'THB',
        isActive: _isActive,
        remark: _remarkCtrl.text.trim().isEmpty ? null : _remarkCtrl.text.trim(),
        apAccountId: _apAccountId,
        apAccountCode: _apAccountCode,
        apAccountNameThai: _apAccountNameThai,
        addresses: _addresses,
        contacts: _contacts,
        bankAccounts: _bankAccounts,
      );
      await widget.onSubmit(vendor);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Group ──────────────────────────────────────────────────────────────────
  Future<void> _pickVendorGroup() async {
    await ApVendorGroupListWidget.search(context, onSelected: (group) {
      setState(() {
        _vendorGroupId           = group.id;
        _vendorGroupCode         = group.groupCode;
        _vendorGroupName         = group.groupNameThai;
        _vendorGroupIsAutoNumber = group.isAutoNumber;
        _autoCodeOverridden      = false;
        _codeCtrl.clear();
        _creditMonthsCtrl.text = '${group.creditTermMonths}';
        _creditDaysCtrl.text   = '${group.creditTermDays}';
        _selectedCurrencyCode  = group.currencyCode;
      });
    });
  }

  void _clearGroup() {
    setState(() {
      _vendorGroupId = null; _vendorGroupCode = null; _vendorGroupName = null;
      _vendorGroupIsAutoNumber = null; _autoCodeOverridden = false;
      _codeCtrl.clear();
    });
  }

  // ── Business Type ──────────────────────────────────────────────────────────
  Future<void> _pickBusinessType() async {
    if (_businessTypes.isEmpty) await _loadDropdowns();
    if (!mounted) return;
    final searchCtrl = TextEditingController();
    List<BusinessType> filtered = List.from(_businessTypes);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        void doFilter(String q) => setDlg(() {
          filtered = q.isEmpty
              ? List.from(_businessTypes)
              : _businessTypes.where((b) =>
                  b.businessTypeCode.toLowerCase().contains(q.toLowerCase()) ||
                  b.businessTypeNameThai.toLowerCase().contains(q.toLowerCase())).toList();
        });
        return AlertDialog(
          title: const Text('เลือกประเภทธุรกิจ'),
          content: SizedBox(
            width: 480, height: 380,
            child: Column(children: [
              TextField(
                controller: searchCtrl, autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'ค้นหา รหัส / ชื่อประเภทธุรกิจ',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10),
                ),
                onChanged: doFilter,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _businessTypes.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? const Center(child: Text('ไม่พบข้อมูล'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final bt = filtered[i];
                              final isSelected = _businessTypeId == bt.id;
                              return ListTile(
                                dense: true,
                                selected: isSelected,
                                selectedTileColor: Colors.blue.shade50,
                                leading: isSelected
                                    ? const Icon(Icons.check_circle, color: Colors.blue, size: 18)
                                    : const SizedBox(width: 18),
                                title: Row(children: [
                                  SizedBox(
                                    width: 90,
                                    child: Text(bt.businessTypeCode,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, color: Colors.blue)),
                                  ),
                                  Expanded(child: Text(bt.businessTypeNameThai)),
                                ]),
                                onTap: () {
                                  setState(() {
                                    _businessTypeId       = bt.id;
                                    _businessTypeCode     = bt.businessTypeCode;
                                    _businessTypeNameThai = bt.businessTypeNameThai;
                                  });
                                  Navigator.of(ctx).pop();
                                },
                              );
                            },
                          ),
              ),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('ปิด'))],
        );
      }),
    );
    searchCtrl.dispose();
  }

  // ── Currency ───────────────────────────────────────────────────────────────
  Future<void> _pickCurrency() async {
    if (_currencies.isEmpty) await _loadCurrencies();
    if (!mounted) return;
    final searchCtrl = TextEditingController();
    List<Currency> filtered = List.from(_currencies);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        void doFilter(String q) => setDlg(() {
          filtered = q.isEmpty
              ? List.from(_currencies)
              : _currencies.where((c) =>
                  c.currencyCode.toLowerCase().contains(q.toLowerCase()) ||
                  c.currencyNameThai.toLowerCase().contains(q.toLowerCase())).toList();
        });
        return AlertDialog(
          title: const Text('เลือกสกุลเงิน'),
          content: SizedBox(
            width: 480, height: 380,
            child: Column(children: [
              TextField(
                controller: searchCtrl, autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'ค้นหา รหัส / ชื่อสกุลเงิน',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10),
                ),
                onChanged: doFilter,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _currencies.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? const Center(child: Text('ไม่พบข้อมูล'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final c = filtered[i];
                              final isSelected = _selectedCurrencyCode == c.currencyCode;
                              return ListTile(
                                dense: true,
                                selected: isSelected,
                                selectedTileColor: Colors.blue.shade50,
                                leading: isSelected
                                    ? const Icon(Icons.check_circle, color: Colors.blue, size: 18)
                                    : const SizedBox(width: 18),
                                title: Row(children: [
                                  SizedBox(
                                    width: 60,
                                    child: Text(c.currencyCode,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, color: Colors.blue)),
                                  ),
                                  Expanded(child: Text(c.currencyNameThai)),
                                ]),
                                onTap: () {
                                  setState(() {
                                    _selectedCurrencyCode     = c.currencyCode;
                                    _selectedCurrencyNameThai = c.currencyNameThai;
                                  });
                                  Navigator.of(ctx).pop();
                                },
                              );
                            },
                          ),
              ),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('ปิด'))],
        );
      }),
    );
    searchCtrl.dispose();
  }

  // ── AP Account ─────────────────────────────────────────────────────────────
  Future<void> _pickApAccount() async {
    if (_controlAccounts.isEmpty) await _loadDropdowns();
    if (!mounted) return;
    final searchCtrl = TextEditingController();
    List<Account> filtered = List.from(_controlAccounts);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        void doFilter(String q) => setDlg(() {
          filtered = q.isEmpty
              ? List.from(_controlAccounts)
              : _controlAccounts.where((a) =>
                  a.accountCode.toUpperCase().contains(q.toUpperCase()) ||
                  a.accountNameThai.toUpperCase().contains(q.toUpperCase())).toList();
        });
        return AlertDialog(
          title: const Text('เลือกบัญชีเจ้าหนี้'),
          content: SizedBox(
            width: 520, height: 400,
            child: Column(children: [
              TextField(
                controller: searchCtrl, autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'ค้นหา รหัส / ชื่อบัญชี',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10),
                ),
                onChanged: doFilter,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _controlAccounts.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? const Center(child: Text('ไม่พบข้อมูล'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final a = filtered[i];
                              final isSelected = _apAccountId == a.id;
                              return ListTile(
                                dense: true,
                                selected: isSelected,
                                selectedTileColor: Colors.blue.shade50,
                                leading: isSelected
                                    ? const Icon(Icons.check_circle, color: Colors.blue, size: 18)
                                    : const SizedBox(width: 18),
                                title: Row(children: [
                                  SizedBox(
                                    width: 110,
                                    child: Text(a.accountCode,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, color: Colors.blue)),
                                  ),
                                  Expanded(child: Text(a.accountNameThai)),
                                ]),
                                onTap: () {
                                  setState(() {
                                    _apAccountId       = a.id;
                                    _apAccountCode     = a.accountCode;
                                    _apAccountNameThai = a.accountNameThai;
                                  });
                                  Navigator.of(ctx).pop();
                                },
                              );
                            },
                          ),
              ),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('ปิด'))],
        );
      }),
    );
    searchCtrl.dispose();
  }

  // ── Field helper ───────────────────────────────────────────────────────────
  Widget _buildField(
    String label,
    TextEditingController ctrl, {
    bool required = false,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: ctrl,
          readOnly: _isReadOnly,
          keyboardType: keyboard,
          inputFormatters: formatters,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          validator: required
              ? (v) => (v == null || v.trim().isEmpty) ? 'กรุณาป้อน $label' : null
              : null,
        ),
      );

  // ── รหัสเจ้าหนี้ (รองรับ auto-numbering) ──────────────────────────────────
  Widget _buildCodeField() {
    final isAdd = widget.mode == Mode.add;
    final isLocked = _isReadOnly || widget.mode == Mode.edit;

    if (isAdd && _effectiveAutoNumbering && !_autoCodeOverridden) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'รหัสเจ้าหนี้',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.teal, size: 16),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'ออกรหัสอัตโนมัติเมื่อบันทึก',
                  style: TextStyle(color: Colors.teal, fontStyle: FontStyle.italic),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.edit, size: 14),
                label: const Text('แก้ไขเอง', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => setState(() => _autoCodeOverridden = true),
              ),
            ],
          ),
        ),
      );
    }

    if (isAdd && _effectiveAutoNumbering && _autoCodeOverridden) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'รหัสเจ้าหนี้ *',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'กรุณาป้อนรหัสเจ้าหนี้' : null,
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: 'กลับไปใช้รหัสอัตโนมัติ',
              child: IconButton(
                icon: const Icon(Icons.auto_awesome, color: Colors.teal),
                onPressed: () => setState(() {
                  _autoCodeOverridden = false;
                  _codeCtrl.clear();
                }),
              ),
            ),
          ],
        ),
      );
    }

    return _buildField('รหัสเจ้าหนี้${!isLocked ? ' *' : ''}', _codeCtrl,
        required: !isLocked);
  }

  // ── FK-field builder (InputDecorator + search/clear) ──────────────────────
  Widget _buildFkField({
    required String label,
    required String? displayText,
    required bool hasValue,
    required VoidCallback onSearch,
    VoidCallback? onClear,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: Row(
            children: [
              Expanded(
                child: hasValue
                    ? Row(children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(displayText ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ])
                    : Text('— ไม่ระบุ —',
                        style: TextStyle(color: Colors.grey.shade600)),
              ),
              if (!_isReadOnly) ...[
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.blue),
                  tooltip: 'ค้นหา$label',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onSearch,
                ),
                if (hasValue && onClear != null)
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.red, size: 18),
                    tooltip: 'ล้าง',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onClear,
                  ),
              ],
            ],
          ),
        ),
      );

  // ── Sections ───────────────────────────────────────────────────────────────

  Widget _buildBasicSection() => _Section(
        title: 'ข้อมูลพื้นฐาน',
        children: [
          Row(children: [
            Expanded(child: _buildCodeField()),
            const SizedBox(width: 10),
            Expanded(child: _buildField('เลขผู้เสียภาษี', _taxIdCtrl)),
            const SizedBox(width: 10),
            Expanded(child: _buildField('รหัสเก่า', _oldCodeCtrl)),
          ]),
          Row(children: [
            Expanded(child: _buildField('ชื่อเจ้าหนี้ (ไทย) *', _nameTHCtrl, required: true)),
            const SizedBox(width: 10),
            Expanded(child: _buildField('ชื่อเจ้าหนี้ (อังกฤษ)', _nameENCtrl)),
          ]),
          Row(children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DropdownButtonFormField<String?>(
                  value: _vendorType,
                  decoration: const InputDecoration(
                    labelText: 'ประเภทผู้ขาย',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: null,           child: Text('— ไม่ระบุ —')),
                    DropdownMenuItem(value: 'individual',   child: Text('บุคคลธรรมดา')),
                    DropdownMenuItem(value: 'juristic',     child: Text('นิติบุคคล')),
                  ],
                  onChanged: _isReadOnly ? null : (v) => setState(() => _vendorType = v),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _buildFkField(
              label: 'ประเภทธุรกิจ',
              hasValue: _businessTypeId != null,
              displayText: '$_businessTypeCode — $_businessTypeNameThai',
              onSearch: _pickBusinessType,
              onClear: () => setState(() {
                _businessTypeId = null; _businessTypeCode = null; _businessTypeNameThai = null;
              }),
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildFkField(
              label: 'กลุ่มผู้ขาย',
              hasValue: _vendorGroupId != null,
              displayText: '$_vendorGroupCode — $_vendorGroupName',
              onSearch: _pickVendorGroup,
              onClear: _clearGroup,
            )),
          ]),
          Row(children: [
            Expanded(child: _buildField('เครดิต (เดือน)', _creditMonthsCtrl,
                keyboard: TextInputType.number,
                formatters: [FilteringTextInputFormatter.digitsOnly])),
            const SizedBox(width: 10),
            Expanded(child: _buildField('เครดิต (วัน)', _creditDaysCtrl,
                keyboard: TextInputType.number,
                formatters: [FilteringTextInputFormatter.digitsOnly])),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'สกุลเงิน',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: _selectedCurrencyCode == null
                          ? Text('— ไม่ระบุ —',
                              style: TextStyle(color: Colors.grey.shade600))
                          : Row(children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 16),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _selectedCurrencyNameThai != null
                                      ? '$_selectedCurrencyCode — $_selectedCurrencyNameThai'
                                      : _selectedCurrencyCode!,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ]),
                    ),
                    if (!_isReadOnly) ...[
                      IconButton(
                        icon: const Icon(Icons.search, color: Colors.blue),
                        tooltip: 'ค้นหาสกุลเงิน',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: _pickCurrency,
                      ),
                      if (_selectedCurrencyCode != null)
                        IconButton(
                          icon: const Icon(Icons.clear, color: Colors.red, size: 18),
                          tooltip: 'ล้างสกุลเงิน',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => setState(() {
                            _selectedCurrencyCode = null;
                            _selectedCurrencyNameThai = null;
                          }),
                        ),
                    ],
                  ]),
                ),
              ),
            ),
          ]),
          _buildField('หมายเหตุ', _remarkCtrl),
          SwitchListTile(
            title: Text('สถานะ: ${_isActive ? 'ใช้งาน' : 'หยุดใช้'}'),
            value: _isActive,
            onChanged: _isReadOnly ? null : (v) => setState(() => _isActive = v),
          ),
        ],
      );

  Widget _buildAddressSection() {
    final readOnly = _isReadOnly;
    return _Section(
      title: 'ที่อยู่ (${_addresses.length})',
      initiallyExpanded: false,
      trailing: readOnly
          ? null
          : IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              tooltip: 'เพิ่มที่อยู่',
              onPressed: () async {
                final primary = _addresses.cast<ApVendorAddress?>()
                    .firstWhere((a) => a!.isDefault, orElse: () => null);
                final result = await showAddressDialog(context, null, false,
                    primaryAddress: primary);
                if (result != null) setState(() => _addresses.add(result));
              },
            ),
      children: [
        if (_addresses.isEmpty)
          const Text('ยังไม่มีที่อยู่', style: TextStyle(color: Colors.grey)),
        ..._addresses.asMap().entries.map((entry) {
          final i = entry.key;
          final addr = entry.value;
          final line1 = [
            addr.addressNo,
            addr.addressBuildingVillage,
            addr.addressAlley != null ? 'ซ.${addr.addressAlley}' : null,
            addr.addressRoad != null ? 'ถ.${addr.addressRoad}' : null,
          ].where((s) => s != null && s.isNotEmpty).join(' ').trim();
          final displayLabel = line1.isNotEmpty
              ? line1
              : [addr.addressSubDistrict, addr.addressProvince]
                      .where((s) => s != null && s.isNotEmpty)
                      .join(', ')
                      .isEmpty
                  ? 'ที่อยู่ ${i + 1}'
                  : [addr.addressSubDistrict, addr.addressProvince]
                      .where((s) => s != null && s.isNotEmpty)
                      .join(', ');
          const addrTypeLabel = {
            'billing': 'ที่อยู่ใบแจ้งหนี้',
            'shipping': 'ที่อยู่จัดส่ง',
            'billing note': 'ที่อยู่วางบิล',
            'payment': 'ที่อยู่ชำระเงิน',
          };
          final typeLabel = addrTypeLabel[addr.addressType] ?? addr.addressType;
          final subText = [
            if (addr.addressSubDistrict != null) addr.addressSubDistrict!,
            if (addr.addressDistrict != null) addr.addressDistrict!,
            if (addr.addressProvince != null) addr.addressProvince!,
            if (addr.addressZipCode != null) addr.addressZipCode!,
          ].join('  ');
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.location_on_outlined, size: 18),
            title: Text(displayLabel),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subText.isNotEmpty) Text(subText),
                Text(typeLabel,
                    style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                      readOnly ? Icons.visibility : Icons.edit,
                      size: 18,
                      color: readOnly ? Colors.green : Colors.blue),
                  onPressed: () async {
                    final primary = _addresses.cast<ApVendorAddress?>()
                        .firstWhere((a) => a!.isDefault, orElse: () => null);
                    final result = await showAddressDialog(context, addr, readOnly,
                        primaryAddress: primary);
                    if (result != null) setState(() => _addresses[i] = result);
                  },
                ),
                if (!readOnly)
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                    onPressed: () => setState(() => _addresses.removeAt(i)),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildContactSection() {
    final readOnly = _isReadOnly;
    return _Section(
      title: 'ผู้ติดต่อ (${_contacts.length})',
      initiallyExpanded: false,
      trailing: readOnly
          ? null
          : IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              tooltip: 'เพิ่มผู้ติดต่อ',
              onPressed: () async {
                final result = await showContactDialog(context, null, false);
                if (result != null) setState(() => _contacts.add(result));
              },
            ),
      children: [
        if (_contacts.isEmpty)
          const Text('ยังไม่มีผู้ติดต่อ', style: TextStyle(color: Colors.grey)),
        ..._contacts.asMap().entries.map((entry) {
          final i = entry.key;
          final c = entry.value;
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline, size: 18),
            title: Text(c.contactName),
            subtitle: Text([
              if (c.position != null) c.position!,
              if (c.phone != null) c.phone!,
              if (c.mobile != null) c.mobile!,
            ].join('  ')),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                      readOnly ? Icons.visibility : Icons.edit,
                      size: 18,
                      color: readOnly ? Colors.green : Colors.blue),
                  onPressed: () async {
                    final result = await showContactDialog(context, c, readOnly);
                    if (result != null) setState(() => _contacts[i] = result);
                  },
                ),
                if (!readOnly)
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                    onPressed: () => setState(() => _contacts.removeAt(i)),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBankSection() {
    final readOnly = _isReadOnly;
    return _Section(
      title: 'บัญชีธนาคาร (${_bankAccounts.length})',
      initiallyExpanded: false,
      trailing: readOnly
          ? null
          : IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              tooltip: 'เพิ่มบัญชีธนาคาร',
              onPressed: () async {
                final result = await showBankDialog(context, null, false);
                if (result != null) setState(() => _bankAccounts.add(result));
              },
            ),
      children: [
        if (_bankAccounts.isEmpty)
          const Text('ยังไม่มีบัญชีธนาคาร', style: TextStyle(color: Colors.grey)),
        ..._bankAccounts.asMap().entries.map((entry) {
          final i = entry.key;
          final b = entry.value;
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_balance_outlined, size: 18),
            title: Text([b.bankName, b.branchName]
                .where((s) => s != null && s.isNotEmpty)
                .join(' — ')),
            subtitle: Text([
              if (b.accountNumber != null) b.accountNumber!,
              if (b.accountName != null) b.accountName!,
            ].join('  ')),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                      readOnly ? Icons.visibility : Icons.edit,
                      size: 18,
                      color: readOnly ? Colors.green : Colors.blue),
                  onPressed: () async {
                    final result = await showBankDialog(context, b, readOnly);
                    if (result != null) setState(() => _bankAccounts[i] = result);
                  },
                ),
                if (!readOnly)
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                    onPressed: () => setState(() => _bankAccounts.removeAt(i)),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildGlAccountSection() => _Section(
        title: 'บัญชีเจ้าหนี้ (GL)',
        initiallyExpanded: false,
        children: [
          _buildFkField(
            label: 'บัญชีเจ้าหนี้',
            hasValue: _apAccountId != null,
            displayText: '$_apAccountCode — $_apAccountNameThai',
            onSearch: _pickApAccount,
            onClear: () => setState(() {
              _apAccountId = null; _apAccountCode = null; _apAccountNameThai = null;
            }),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 4),
            child: Text(
              'หากไม่ระบุ ระบบจะใช้บัญชีจาก กลุ่มผู้ขาย และ ประเภทเอกสาร ตามลำดับ',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.blueGrey.shade400,
                  fontStyle: FontStyle.italic),
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    if (widget.isPlaceholder) {
      return const Center(
          child: Text('เลือกรายการเพื่อดูข้อมูล', style: TextStyle(color: Colors.grey)));
    }
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Form(
      key: _formKey,
      child: Column(
        children: [
          Container(
            color: Colors.blue[300],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.business, color: Colors.blue[900], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.mode == Mode.add
                        ? 'เพิ่มเจ้าหนี้ใหม่'
                        : widget.mode == Mode.edit
                            ? 'แก้ไขเจ้าหนี้'
                            : 'ข้อมูลเจ้าหนี้',
                    style: TextStyle(
                        color: Colors.blue[900],
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                if (!_isReadOnly) ...[
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save, size: 16),
                    label: Text(_isSaving ? 'กำลังบันทึก...' : 'บันทึก'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        foregroundColor: Colors.white),
                  ),
                  const SizedBox(width: 8),
                ],
                TextButton(
                  onPressed: widget.onCancel,
                  child: Text('ปิด', style: TextStyle(color: Colors.blue[900])),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _buildBasicSection(),
                _buildAddressSection(),
                _buildContactSection(),
                _buildBankSection(),
                _buildGlAccountSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
