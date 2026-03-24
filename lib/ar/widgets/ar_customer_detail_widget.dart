import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/anan_module.dart';
import '../../cd/models/zipcode.dart';
import '../../cd/models/business_type.dart';
import '../../cd/services/business_type_service.dart';
import '../../cd/widgets/zipcode_list_widget.dart';
import '../models/ar_customer.dart';
import '../../cd/models/currency.dart';
import '../../cd/services/currency_service.dart';
import '../models/ar_customer_group.dart';
import '../services/ar_customer_group_service.dart';
import '../services/ar_customer_running_service.dart';
import '../../cd/models/bank.dart';
import '../../cd/models/bank_branch.dart';
import '../../cd/services/bank_branch_service.dart';
import '../../cd/widgets/bank_list_widget.dart';
import '../../gl/models/account.dart';
import '../../gl/services/account_service.dart';
import '../../cd/models/sales_territory.dart';
import '../../cd/services/sales_territory_service.dart';
import '../widgets/ar_collector_list_widget.dart';

// ---------------------------------------------------------------------------
// Collapsible section widget
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
Future<ArCustomerAddress?> showAddressDialog(
    BuildContext context, ArCustomerAddress? existing, bool readOnly,
    {ArCustomerAddress? primaryAddress}) async {
  final addrTypeCtrl =
      ValueNotifier<String>(existing?.addressType ?? 'billing');
  final noCtrl = TextEditingController(text: existing?.addressNo ?? '');
  final buildingCtrl =
      TextEditingController(text: existing?.addressBuildingVillage ?? '');
  final alleyCtrl =
      TextEditingController(text: existing?.addressAlley ?? '');
  final roadCtrl = TextEditingController(text: existing?.addressRoad ?? '');
  final subDistCtrl =
      TextEditingController(text: existing?.addressSubDistrict ?? '');
  final distCtrl =
      TextEditingController(text: existing?.addressDistrict ?? '');
  final provCtrl =
      TextEditingController(text: existing?.addressProvince ?? '');
  final countryCtrl =
      TextEditingController(text: existing?.addressCountry ?? 'Thailand');
  final zipCtrl =
      TextEditingController(text: existing?.addressZipCode ?? '');
  final isDefaultNotifier = ValueNotifier<bool>(existing?.isDefault ?? false);
  bool useSameAddress = false;

  // แสดง checkbox เฉพาะเมื่อ: ไม่ใช่ readOnly, มีที่อยู่หลัก, และที่อยู่นี้ไม่ใช่ที่อยู่หลัก
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

  return showDialog<ArCustomerAddress>(
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
                // Checkbox: ใช้ที่อยู่เดียวกับที่อยู่หลัก
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

                // ประเภทที่อยู่
                ValueListenableBuilder<String>(
                  valueListenable: addrTypeCtrl,
                  builder: (_, v, __) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DropdownButtonFormField<String>(
                      value: v,
                      decoration: const InputDecoration(
                          labelText: 'ประเภทที่อยู่',
                          border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(
                            value: 'billing', child: Text('ที่อยู่ใบแจ้งหนี้')),
                        DropdownMenuItem(
                            value: 'shipping', child: Text('ที่อยู่จัดส่ง')),
                        DropdownMenuItem(
                            value: 'billing note', child: Text('ที่อยู่วางบิล')),
                        DropdownMenuItem(
                            value: 'payment', child: Text('ที่อยู่ชำระเงิน')),
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
                // แขวง/ตำบล + อำเภอ/เขต พร้อมปุ่มค้นหา zipcode
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!readOnly)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: IconButton(
                          icon: const Icon(Icons.search, color: Colors.blue),
                          tooltip:
                              'ค้นหา ตำบล/แขวง, อำเภอ/เขต, จังหวัด, รหัสไปรษณีย์',
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
                Navigator.of(ctx).pop(ArCustomerAddress(
                  id: existing?.id,
                  customerId: existing?.customerId,
                  addressType: addrTypeCtrl.value,
                  addressNo: noCtrl.text.isEmpty ? null : noCtrl.text,
                  addressBuildingVillage:
                      buildingCtrl.text.isEmpty ? null : buildingCtrl.text,
                  addressAlley:
                      alleyCtrl.text.isEmpty ? null : alleyCtrl.text,
                  addressRoad: roadCtrl.text.isEmpty ? null : roadCtrl.text,
                  addressSubDistrict:
                      subDistCtrl.text.isEmpty ? null : subDistCtrl.text,
                  addressDistrict:
                      distCtrl.text.isEmpty ? null : distCtrl.text,
                  addressProvince:
                      provCtrl.text.isEmpty ? null : provCtrl.text,
                  addressCountry: countryCtrl.text.isEmpty
                      ? 'Thailand'
                      : countryCtrl.text,
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
Future<ArCustomerContact?> showContactDialog(
    BuildContext context, ArCustomerContact? existing, bool readOnly) async {
  final nameCtrl = TextEditingController(text: existing?.contactName ?? '');
  final posCtrl = TextEditingController(text: existing?.position ?? '');
  final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
  final mobileCtrl = TextEditingController(text: existing?.mobile ?? '');
  final emailCtrl = TextEditingController(text: existing?.email ?? '');
  final isDefaultNotifier = ValueNotifier<bool>(existing?.isDefault ?? false);

  return showDialog<ArCustomerContact>(
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
                    labelText: 'ชื่อผู้ติดต่อ *',
                    border: OutlineInputBorder()),
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
                          labelText: 'โทรศัพท์',
                          border: OutlineInputBorder()),
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
              Navigator.of(ctx).pop(ArCustomerContact(
                id: existing?.id,
                customerId: existing?.customerId,
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
Future<ArCustomerBankAccount?> showBankDialog(
    BuildContext context, ArCustomerBankAccount? existing, bool readOnly) {
  return showDialog<ArCustomerBankAccount>(
    context: context,
    builder: (ctx) => _BankAccountDialog(existing: existing, readOnly: readOnly),
  );
}

class _BankAccountDialog extends StatefulWidget {
  final ArCustomerBankAccount? existing;
  final bool readOnly;
  const _BankAccountDialog({this.existing, required this.readOnly});

  @override
  State<_BankAccountDialog> createState() => _BankAccountDialogState();
}

class _BankAccountDialogState extends State<_BankAccountDialog> {
  // Bank picker state
  Bank? _selectedBank;
  String _bankDisplay = '';

  // Branch text + suggestions
  late final TextEditingController _branchCtrl;
  List<BankBranch> _allBranches = [];
  List<BankBranch> _branchSuggestions = [];

  // Other fields
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
      final service = Provider.of<BankBranchService>(context, listen: false);
      final list = await service.fetchRows();
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
        // Sort: selected bank's branches appear first
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
      _branchCtrl.selection =
          TextSelection.collapsed(offset: branch.branchName.length);
      _branchSuggestions = [];
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final branchName = _branchCtrl.text.trim();

      // Auto-create branch in cd_bank_branch if bank is selected, branch is
      // entered, and that branch doesn't yet exist for this bank
      if (_selectedBank?.id != null && branchName.isNotEmpty) {
        final alreadyExists = _allBranches.any((b) =>
            b.bankId == _selectedBank!.id &&
            b.branchName.toLowerCase() == branchName.toLowerCase());
        if (!alreadyExists) {
          try {
            final svc =
                Provider.of<BankBranchService>(context, listen: false);
            await svc.addRow(BankBranch(
              bankId: _selectedBank!.id!,
              branchName: branchName,
              isActive: true,
            ));
          } catch (_) {
            // Silent — don't block saving the bank account
          }
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(ArCustomerBankAccount(
        id: widget.existing?.id,
        customerId: widget.existing?.customerId,
        bankName: _bankDisplay.isEmpty ? null : _bankDisplay,
        branchName: branchName.isEmpty ? null : branchName,
        accountNumber:
            _accNumCtrl.text.trim().isEmpty ? null : _accNumCtrl.text.trim(),
        accountName:
            _accNameCtrl.text.trim().isEmpty ? null : _accNameCtrl.text.trim(),
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
              // ── Bank picker ──────────────────────────────────────────────
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
                    fontWeight: _bankDisplay.isNotEmpty
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _bankDisplay.isNotEmpty ? null : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Branch text field + inline suggestions ───────────────────
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
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 4)
                    ],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _branchSuggestions.length,
                    itemBuilder: (_, i) {
                      final b = _branchSuggestions[i];
                      final isOwnBank = _selectedBank != null &&
                          b.bankId == _selectedBank!.id;
                      return ListTile(
                        dense: true,
                        title: Text(
                          b.branchName,
                          style: TextStyle(
                            fontWeight: isOwnBank
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          b.bankDisplay,
                          style: TextStyle(
                            fontSize: 11,
                            color: isOwnBank
                                ? Colors.blue.shade700
                                : Colors.grey,
                          ),
                        ),
                        onTap: () => _selectSuggestion(b),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 10),

              // ── Account fields ───────────────────────────────────────────
              TextField(
                readOnly: readOnly,
                controller: _accNumCtrl,
                decoration: const InputDecoration(
                    labelText: 'เลขที่บัญชี',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                readOnly: readOnly,
                controller: _accNameCtrl,
                decoration: const InputDecoration(
                    labelText: 'ชื่อบัญชี',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _accType,
                decoration: const InputDecoration(
                    labelText: 'ประเภทบัญชี',
                    border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(
                      value: 'current', child: Text('กระแสรายวัน')),
                  DropdownMenuItem(
                      value: 'savings', child: Text('ออมทรัพย์')),
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
                onChanged: readOnly
                    ? null
                    : (val) => setState(() => _isDefault = val),
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
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
class ArCustomerDetailWidget extends StatefulWidget {
  final Mode mode;
  final ArCustomer? selected;
  final Function(ArCustomer) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;

  const ArCustomerDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
  });

  @override
  State<ArCustomerDetailWidget> createState() => ArCustomerDetailWidgetState();
}

class ArCustomerDetailWidgetState extends State<ArCustomerDetailWidget> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _codeCtrl;
  late TextEditingController _nameThCtrl;
  late TextEditingController _nameEnCtrl;
  late TextEditingController _taxIdCtrl;
  late TextEditingController _oldCustomerCodeCtrl;
  late TextEditingController _creditDaysCtrl;
  late TextEditingController _creditLimitCtrl;
  late TextEditingController _discountPercentCtrl;
  late TextEditingController _remarkCtrl;

  // สกุลเงิน
  String? _selectedCurrencyCode;
  String? _selectedCurrencyNameThai;
  List<Currency> _currencies = [];

  // กลุ่มลูกค้า list สำหรับ dialog
  List<ArCustomerGroup> _customerGroups = [];

  // บัญชีลูกหนี้ (FK → gl_account, is_control_account=true)
  int? _arAccountId;
  String? _arAccountCode;
  String? _arAccountNameThai;
  List<Account> _controlAccounts = [];

  // รหัสอัตโนมัติ
  bool _autoNumberingEnabled = false;
  bool _autoCodeOverridden = false; // true = ผู้ใช้กดแก้ไขเอง

  // ประเภทธุรกิจ (FK → cd_business_type)
  int? _businessTypeId;
  String? _businessTypeCode;
  String? _businessTypeNameThai;
  List<BusinessType> _businessTypes = [];

  // กลุ่มลูกค้า (FK → ar_customer_group)
  int? _customerGroupId;
  String? _customerGroupCode;
  String? _customerGroupName;

  late bool _isActive;

  List<ArCustomerAddress> _addresses = [];
  List<ArCustomerContact> _contacts = [];
  List<ArCustomerBankAccount> _bankAccounts = [];

  // เงื่อนไขการวางบิล
  int? _billingDayOfWeek;
  List<int> _billingWeekOfMonth = [];
  late TextEditingController _billingDateFromCtrl;
  late TextEditingController _billingDateToCtrl;
  late TextEditingController _billingTimeFromCtrl;
  late TextEditingController _billingTimeToCtrl;
  bool _billingExcludeHolidays = true;
  late TextEditingController _billingRemarkCtrl;

  // เขตการขาย
  int? _salesTerritoryId;
  String? _salesTerritoryCode;
  String? _salesTerritoryNameThai;
  // พนักงานขาย
  int? _salespersonId;
  String? _salespersonCode;
  String? _salespersonNameThai;
  // cache รายชื่อพนักงานขายในเขตที่เลือก
  List<TerritoryMember> _territoryMembers = [];
  bool _loadingMembers = false;
  // ผู้วางบิล
  int? _billingCollectorId;
  String? _billingCollectorCode;
  String? _billingCollectorNameThai;
  // ผู้รับชำระ
  int? _collectionCollectorId;
  String? _collectionCollectorCode;
  String? _collectionCollectorNameThai;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initFromSelected(widget.selected);
    _loadBusinessTypes();
    _loadCustomerGroups();
    _loadCurrencies();
    _loadAutoNumberingConfig();
    _loadControlAccounts();
    if (widget.selected?.salesTerritoryId != null) {
      _loadTerritoryMembers(widget.selected!.salesTerritoryId!);
    }
  }

  Future<void> _loadBusinessTypes() async {
    try {
      final list = await Provider.of<BusinessTypeService>(context, listen: false)
          .fetchActiveRows();
      if (mounted) setState(() => _businessTypes = list);
    } catch (_) {}
  }

  Future<void> _loadCustomerGroups() async {
    try {
      final list = await Provider.of<ArCustomerGroupService>(context, listen: false)
          .fetchRows();
      if (mounted) setState(() => _customerGroups = list);
    } catch (_) {}
  }

  Future<void> _loadAutoNumberingConfig() async {
    if (widget.mode != Mode.add) return; // เฉพาะโหมด add เท่านั้น
    try {
      final svc = Provider.of<ArCustomerRunningService>(context, listen: false);
      final config = await svc.fetchConfig();
      if (mounted) {
        setState(() => _autoNumberingEnabled = config.isAutoNumbering);
      }
    } catch (_) {}
  }

  Future<void> _loadCurrencies() async {
    try {
      final list = await Provider.of<CurrencyService>(context, listen: false)
          .fetchActiveRows();
      if (mounted) {
        setState(() {
          _currencies = list;
          if (_selectedCurrencyCode != null) {
            final match = _currencies.cast<Currency?>().firstWhere(
                  (c) => c?.currencyCode == _selectedCurrencyCode,
                  orElse: () => null,
                );
            _selectedCurrencyNameThai = match?.currencyNameThai;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadControlAccounts() async {
    try {
      final list = await AccountService().fetchRows();
      if (mounted) {
        setState(() {
          _controlAccounts = list.where((a) => a.isControlAccount && a.isActive).toList();
          // resolve name from loaded list if arAccountId is already set
          if (_arAccountId != null) {
            final match = _controlAccounts.where((a) => a.id == _arAccountId).firstOrNull;
            if (match != null) {
              _arAccountCode     = match.accountCode;
              _arAccountNameThai = match.accountNameThai;
            }
          }
        });
      }
    } catch (_) {}
  }

  void _initFromSelected(ArCustomer? c) {
    _codeCtrl        = TextEditingController(text: c?.customerCode ?? '');
    _nameThCtrl      = TextEditingController(text: c?.customerNameTh ?? '');
    _nameEnCtrl      = TextEditingController(text: c?.customerNameEn ?? '');
    _taxIdCtrl           = TextEditingController(text: c?.taxId ?? '');
    _oldCustomerCodeCtrl = TextEditingController(text: c?.oldCustomerCode ?? '');
    _creditDaysCtrl  = TextEditingController(text: (c?.creditDays ?? 30).toString());
    _creditLimitCtrl = TextEditingController(text: (c?.creditLimit ?? 0).toStringAsFixed(2));
    _discountPercentCtrl = TextEditingController(text: (c?.discountPercent ?? 0).toStringAsFixed(2));
    _remarkCtrl      = TextEditingController(text: c?.remark ?? '');
    _selectedCurrencyCode = c?.currencyCode ?? 'THB';
    _selectedCurrencyNameThai = null;
    _businessTypeId        = c?.businessTypeId;
    _businessTypeCode      = c?.businessTypeCode;
    _businessTypeNameThai  = c?.businessTypeNameThai;
    _customerGroupId   = c?.customerGroupId;
    _customerGroupCode = c?.customerGroupCode;
    _customerGroupName = c?.customerGroupName;
    _isActive        = c?.isActive ?? true;
    _addresses       = List.from(c?.addresses ?? []);
    _contacts        = List.from(c?.contacts ?? []);
    _bankAccounts    = List.from(c?.bankAccounts ?? []);
    _arAccountId       = c?.arAccountId;
    _arAccountCode     = null;
    _arAccountNameThai = null;
    _salesTerritoryId       = c?.salesTerritoryId;
    _salesTerritoryCode     = c?.salesTerritoryCode;
    _salesTerritoryNameThai = c?.salesTerritoryNameThai;
    _salespersonId       = c?.salespersonId;
    _salespersonCode     = c?.salespersonCode;
    _salespersonNameThai = c?.salespersonNameThai;
    _territoryMembers = [];
    _loadingMembers   = false;
    _billingCollectorId        = c?.billingCollectorId;
    _billingCollectorCode      = c?.billingCollectorCode;
    _billingCollectorNameThai  = c?.billingCollectorNameThai;
    _collectionCollectorId        = c?.collectionCollectorId;
    _collectionCollectorCode      = c?.collectionCollectorCode;
    _collectionCollectorNameThai  = c?.collectionCollectorNameThai;
    // billing
    _billingDayOfWeek       = c?.billingDayOfWeek;
    _billingWeekOfMonth     = List.from(c?.billingWeekOfMonth ?? []);
    _billingDateFromCtrl    = TextEditingController(text: c?.billingDateFrom?.toString() ?? '');
    _billingDateToCtrl      = TextEditingController(text: c?.billingDateTo?.toString() ?? '');
    _billingTimeFromCtrl    = TextEditingController(text: c?.billingTimeFrom ?? '');
    _billingTimeToCtrl      = TextEditingController(text: c?.billingTimeTo ?? '');
    _billingExcludeHolidays = c?.billingExcludeHolidays ?? true;
    _billingRemarkCtrl      = TextEditingController(text: c?.billingRemark ?? '');
  }

  @override
  void didUpdateWidget(covariant ArCustomerDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      _disposeControllers();
      _initFromSelected(widget.selected);
      setState(() {});
    } else if (widget.mode == Mode.add && oldWidget.mode != Mode.add) {
      _disposeControllers();
      _initFromSelected(null);
      setState(() {});
    }
  }

  void _disposeControllers() {
    for (final c in [
      _codeCtrl, _nameThCtrl, _nameEnCtrl, _taxIdCtrl, _oldCustomerCodeCtrl,
      _creditDaysCtrl, _creditLimitCtrl, _discountPercentCtrl,
      _remarkCtrl,
      _billingDateFromCtrl, _billingDateToCtrl,
      _billingTimeFromCtrl, _billingTimeToCtrl,
      _billingRemarkCtrl,
    ]) {
      c.dispose();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  // เลือกกลุ่มลูกค้า → auto-fill เงื่อนไขเครดิต
  void _onGroupSelected(ArCustomerGroup group) {
    setState(() {
      _customerGroupId   = group.id;
      _customerGroupCode = group.groupCode;
      _customerGroupName = group.groupNameThai;
      _creditDaysCtrl.text         = group.creditDays.toString();
      _creditLimitCtrl.text        = group.creditLimit.toStringAsFixed(2);
      _discountPercentCtrl.text    = group.discountPercent.toStringAsFixed(2);
    });
  }

  void _clearGroup() {
    setState(() {
      _customerGroupId   = null;
      _customerGroupCode = null;
      _customerGroupName = null;
    });
  }

  Future<void> _pickBusinessType() async {
    // ใช้ list ที่โหลดไว้แล้ว; ถ้ายังว่างให้โหลดใหม่
    if (_businessTypes.isEmpty) await _loadBusinessTypes();
    if (!mounted) return;

    final TextEditingController searchCtrl = TextEditingController();
    List<BusinessType> filtered = List.from(_businessTypes);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlgState) {
        void doFilter(String q) {
          setDlgState(() {
            if (q.isEmpty) {
              filtered = List.from(_businessTypes);
            } else {
              final lq = q.toLowerCase();
              filtered = _businessTypes
                  .where((bt) =>
                      bt.businessTypeCode.toLowerCase().contains(lq) ||
                      bt.businessTypeNameThai.toLowerCase().contains(lq))
                  .toList();
            }
          });
        }

        return AlertDialog(
          title: const Text('เลือกประเภทธุรกิจ'),
          content: SizedBox(
            width: 480,
            height: 380,
            child: Column(
              children: [
                TextField(
                  controller: searchCtrl,
                  autofocus: true,
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
                                  selectedTileColor: Colors.indigo.shade50,
                                  leading: isSelected
                                      ? const Icon(Icons.check_circle,
                                          color: Colors.indigo, size: 18)
                                      : const SizedBox(width: 18),
                                  title: Row(
                                    children: [
                                      SizedBox(
                                        width: 90,
                                        child: Text(
                                          bt.businessTypeCode,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.indigo),
                                        ),
                                      ),
                                      Expanded(
                                          child: Text(bt.businessTypeNameThai)),
                                    ],
                                  ),
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
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ปิด'),
            ),
          ],
        );
      }),
    );
    searchCtrl.dispose();
  }

  void _clearBusinessType() {
    setState(() {
      _businessTypeId       = null;
      _businessTypeCode     = null;
      _businessTypeNameThai = null;
    });
  }

  Future<void> _pickCustomerGroup() async {
    if (_customerGroups.isEmpty) await _loadCustomerGroups();
    if (!mounted) return;
    final searchCtrl = TextEditingController();
    List<ArCustomerGroup> filtered = List.from(_customerGroups);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlgState) {
        void doFilter(String q) {
          setDlgState(() {
            if (q.isEmpty) {
              filtered = List.from(_customerGroups);
            } else {
              final lq = q.toLowerCase();
              filtered = _customerGroups
                  .where((g) =>
                      g.groupCode.toLowerCase().contains(lq) ||
                      g.groupNameThai.toLowerCase().contains(lq))
                  .toList();
            }
          });
        }

        return AlertDialog(
          title: const Text('เลือกกลุ่มลูกค้า'),
          content: SizedBox(
            width: 480,
            height: 380,
            child: Column(
              children: [
                TextField(
                  controller: searchCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'ค้นหา รหัส / ชื่อกลุ่มลูกค้า',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onChanged: doFilter,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _customerGroups.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : filtered.isEmpty
                          ? const Center(child: Text('ไม่พบข้อมูล'))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final g = filtered[i];
                                final isSelected = _customerGroupId == g.id;
                                return ListTile(
                                  dense: true,
                                  selected: isSelected,
                                  selectedTileColor: Colors.indigo.shade50,
                                  leading: isSelected
                                      ? const Icon(Icons.check_circle,
                                          color: Colors.indigo, size: 18)
                                      : const SizedBox(width: 18),
                                  title: Row(
                                    children: [
                                      SizedBox(
                                        width: 90,
                                        child: Text(
                                          g.groupCode,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.indigo),
                                        ),
                                      ),
                                      Expanded(child: Text(g.groupNameThai)),
                                    ],
                                  ),
                                  onTap: () {
                                    _onGroupSelected(g);
                                    Navigator.of(ctx).pop();
                                  },
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ปิด'),
            ),
          ],
        );
      }),
    );
    searchCtrl.dispose();
  }

  Future<void> _pickCurrency() async {
    if (_currencies.isEmpty) await _loadCurrencies();
    if (!mounted) return;
    final searchCtrl = TextEditingController();
    List<Currency> filtered = List.from(_currencies);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlgState) {
        void doFilter(String q) {
          setDlgState(() {
            if (q.isEmpty) {
              filtered = List.from(_currencies);
            } else {
              final lq = q.toLowerCase();
              filtered = _currencies
                  .where((c) =>
                      c.currencyCode.toLowerCase().contains(lq) ||
                      c.currencyNameThai.toLowerCase().contains(lq))
                  .toList();
            }
          });
        }

        return AlertDialog(
          title: const Text('เลือกสกุลเงิน'),
          content: SizedBox(
            width: 480,
            height: 380,
            child: Column(
              children: [
                TextField(
                  controller: searchCtrl,
                  autofocus: true,
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
                                final isSelected =
                                    _selectedCurrencyCode == c.currencyCode;
                                return ListTile(
                                  dense: true,
                                  selected: isSelected,
                                  selectedTileColor: Colors.indigo.shade50,
                                  leading: isSelected
                                      ? const Icon(Icons.check_circle,
                                          color: Colors.indigo, size: 18)
                                      : const SizedBox(width: 18),
                                  title: Row(
                                    children: [
                                      SizedBox(
                                        width: 60,
                                        child: Text(
                                          c.currencyCode,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.indigo),
                                        ),
                                      ),
                                      Expanded(child: Text(c.currencyNameThai)),
                                    ],
                                  ),
                                  onTap: () {
                                    setState(() {
                                      _selectedCurrencyCode = c.currencyCode;
                                      _selectedCurrencyNameThai =
                                          c.currencyNameThai;
                                    });
                                    Navigator.of(ctx).pop();
                                  },
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ปิด'),
            ),
          ],
        );
      }),
    );
    searchCtrl.dispose();
  }

  void _clearCurrency() {
    setState(() {
      _selectedCurrencyCode = null;
      _selectedCurrencyNameThai = null;
    });
  }

  Future<void> _pickArAccount() async {
    if (_controlAccounts.isEmpty) await _loadControlAccounts();
    if (!mounted) return;
    final searchCtrl = TextEditingController();
    List<Account> filtered = List.from(_controlAccounts);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlgState) {
        void doFilter(String q) {
          setDlgState(() {
            if (q.isEmpty) {
              filtered = List.from(_controlAccounts);
            } else {
              final lq = q.toUpperCase();
              filtered = _controlAccounts
                  .where((a) =>
                      a.accountCode.toUpperCase().contains(lq) ||
                      a.accountNameThai.toUpperCase().contains(lq))
                  .toList();
            }
          });
        }

        return AlertDialog(
          title: const Text('เลือกบัญชีลูกหนี้'),
          content: SizedBox(
            width: 520,
            height: 400,
            child: Column(
              children: [
                TextField(
                  controller: searchCtrl,
                  autofocus: true,
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
                                final isSelected = _arAccountId == a.id;
                                return ListTile(
                                  dense: true,
                                  selected: isSelected,
                                  selectedTileColor: Colors.indigo.shade50,
                                  leading: isSelected
                                      ? const Icon(Icons.check_circle,
                                          color: Colors.indigo, size: 18)
                                      : const SizedBox(width: 18),
                                  title: Row(
                                    children: [
                                      SizedBox(
                                        width: 110,
                                        child: Text(
                                          a.accountCode,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.indigo),
                                        ),
                                      ),
                                      Expanded(child: Text(a.accountNameThai)),
                                    ],
                                  ),
                                  onTap: () {
                                    setState(() {
                                      _arAccountId       = a.id;
                                      _arAccountCode     = a.accountCode;
                                      _arAccountNameThai = a.accountNameThai;
                                    });
                                    Navigator.of(ctx).pop();
                                  },
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ปิด'),
            ),
          ],
        );
      }),
    );
    searchCtrl.dispose();
  }

  void _clearArAccount() {
    setState(() {
      _arAccountId       = null;
      _arAccountCode     = null;
      _arAccountNameThai = null;
    });
  }

  // ─── เขตการขาย ────────────────────────────────────────────────────────────
  Future<void> _loadTerritoryMembers(int territoryId) async {
    setState(() {
      _territoryMembers = [];
      _loadingMembers   = true;
    });
    try {
      final rows = await Provider.of<SalesTerritoryService>(context, listen: false)
          .fetchMembers(territoryId);
      if (mounted) setState(() { _territoryMembers = rows; _loadingMembers = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  Future<void> _pickSalesTerritory() async {
    final territories = await Provider.of<SalesTerritoryService>(
            context, listen: false)
        .fetchRows();
    if (!mounted) return;
    final searchCtrl = TextEditingController();
    List<SalesTerritory> filtered = List.from(territories);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        void doFilter(String q) {
          setDlg(() {
            if (q.isEmpty) {
              filtered = List.from(territories);
            } else {
              final up = q.toUpperCase();
              filtered = territories
                  .where((t) =>
                      t.territoryCode.toUpperCase().contains(up) ||
                      t.territoryNameThai.toUpperCase().contains(up))
                  .toList();
            }
          });
        }

        return AlertDialog(
          title: const Text('เลือกเขตการขาย',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 500,
            height: 520,
            child: Column(
              children: [
                TextField(
                  controller: searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'ค้นหา (รหัส / ชื่อเขต)',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: doFilter,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('ไม่พบข้อมูล'))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final t = filtered[i];
                            return ListTile(
                              leading: Icon(Icons.map_outlined,
                                  color: t.isActive
                                      ? Colors.teal[600]
                                      : Colors.grey,
                                  size: 20),
                              title: Text(
                                  '${t.territoryCode} — ${t.territoryNameThai}'),
                              subtitle: t.parentNameThai != null
                                  ? Text('ขึ้นกับ: ${t.parentNameThai}',
                                      style: const TextStyle(fontSize: 12))
                                  : null,
                              enabled: t.isActive,
                              onTap: () {
                                setState(() {
                                  _salesTerritoryId       = t.id;
                                  _salesTerritoryCode     = t.territoryCode;
                                  _salesTerritoryNameThai = t.territoryNameThai;
                                  // เคลียร์พนักงานขายเมื่อเปลี่ยนเขต
                                  _salespersonId       = null;
                                  _salespersonCode     = null;
                                  _salespersonNameThai = null;
                                });
                                Navigator.of(ctx).pop();
                                if (_salesTerritoryId != null) {
                                  _loadTerritoryMembers(_salesTerritoryId!);
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('ปิด')),
          ],
        );
      }),
    );
    searchCtrl.dispose();
  }

  void _clearSalesTerritory() {
    setState(() {
      _salesTerritoryId       = null;
      _salesTerritoryCode     = null;
      _salesTerritoryNameThai = null;
      _salespersonId       = null;
      _salespersonCode     = null;
      _salespersonNameThai = null;
      _territoryMembers    = [];
    });
  }

  // ─── พนักงานขาย ───────────────────────────────────────────────────────────
  Future<void> _pickSalesperson() async {
    if (_salesTerritoryId == null) return;
    if (_territoryMembers.isEmpty && !_loadingMembers) {
      await _loadTerritoryMembers(_salesTerritoryId!);
    }
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('เลือกพนักงานขาย',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 500,
          height: 400,
          child: _loadingMembers
              ? const Center(child: CircularProgressIndicator())
              : _territoryMembers.isEmpty
                  ? const Center(
                      child: Text('ไม่มีพนักงานขายในเขตนี้',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _territoryMembers.length,
                      itemBuilder: (_, i) {
                        final m = _territoryMembers[i];
                        return ListTile(
                          leading: Icon(
                            m.isPrimary ? Icons.star : Icons.star_border,
                            color: m.isPrimary ? Colors.amber : Colors.grey,
                            size: 20,
                          ),
                          title: Text(
                              '${m.salespersonCode} — ${m.salespersonNameThai}'),
                          subtitle: Text(
                            m.isPrimary ? 'พนักงานขายหลัก' : 'พนักงานขายรอง',
                            style: TextStyle(
                              fontSize: 12,
                              color: m.isPrimary
                                  ? Colors.amber[700]
                                  : Colors.grey,
                            ),
                          ),
                          enabled: m.isActive,
                          onTap: () {
                            setState(() {
                              _salespersonId       = m.id;
                              _salespersonCode     = m.salespersonCode;
                              _salespersonNameThai = m.salespersonNameThai;
                            });
                            Navigator.of(ctx).pop();
                          },
                        );
                      },
                    ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ปิด')),
        ],
      ),
    );
  }

  void _clearSalesperson() {
    setState(() {
      _salespersonId       = null;
      _salespersonCode     = null;
      _salespersonNameThai = null;
    });
  }

  // ─── ผู้วางบิล ─────────────────────────────────────────────────────────────
  Future<void> _pickBillingCollector() async {
    await ArCollectorListWidget.search(context, onSelected: (c) {
      if (mounted) {
        setState(() {
          _billingCollectorId       = c.id;
          _billingCollectorCode     = c.collectorCode;
          _billingCollectorNameThai = c.collectorNameThai;
        });
      }
    });
  }

  void _clearBillingCollector() {
    setState(() {
      _billingCollectorId       = null;
      _billingCollectorCode     = null;
      _billingCollectorNameThai = null;
    });
  }

  // ─── ผู้รับชำระ ─────────────────────────────────────────────────────────────
  Future<void> _pickCollectionCollector() async {
    await ArCollectorListWidget.search(context, onSelected: (c) {
      if (mounted) {
        setState(() {
          _collectionCollectorId       = c.id;
          _collectionCollectorCode     = c.collectorCode;
          _collectionCollectorNameThai = c.collectorNameThai;
        });
      }
    });
  }

  void _clearCollectionCollector() {
    setState(() {
      _collectionCollectorId       = null;
      _collectionCollectorCode     = null;
      _collectionCollectorNameThai = null;
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final customer = ArCustomer(
        id: widget.selected?.id,
        // ถ้า auto-numbering เปิดและไม่ได้แก้ไขเอง → ส่งค่าว่าง ให้ backend generate
        customerCode: (_autoNumberingEnabled && !_autoCodeOverridden)
            ? ''
            : _codeCtrl.text.trim(),
        customerNameTh: _nameThCtrl.text.trim(),
        customerNameEn:
            _nameEnCtrl.text.trim().isEmpty ? null : _nameEnCtrl.text.trim(),
        taxId: _taxIdCtrl.text.trim().isEmpty ? null : _taxIdCtrl.text.trim(),
        oldCustomerCode: _oldCustomerCodeCtrl.text.trim().isEmpty ? null : _oldCustomerCodeCtrl.text.trim(),
        businessTypeId: _businessTypeId,
        customerGroupId: _customerGroupId,
        creditDays: int.tryParse(_creditDaysCtrl.text) ?? 30,
        creditLimit: double.tryParse(_creditLimitCtrl.text) ?? 0,
        discountPercent: double.tryParse(_discountPercentCtrl.text) ?? 0,
        currencyCode: _selectedCurrencyCode ?? 'THB',
        isActive: _isActive,
        remark: _remarkCtrl.text.trim().isEmpty ? null : _remarkCtrl.text.trim(),
        billingDayOfWeek: _billingDayOfWeek,
        billingWeekOfMonth: _billingWeekOfMonth.isEmpty ? null : List.from(_billingWeekOfMonth),
        billingDateFrom: int.tryParse(_billingDateFromCtrl.text),
        billingDateTo: int.tryParse(_billingDateToCtrl.text),
        billingTimeFrom: _billingTimeFromCtrl.text.trim().isEmpty ? null : _billingTimeFromCtrl.text.trim(),
        billingTimeTo: _billingTimeToCtrl.text.trim().isEmpty ? null : _billingTimeToCtrl.text.trim(),
        billingExcludeHolidays: _billingExcludeHolidays,
        billingRemark: _billingRemarkCtrl.text.trim().isEmpty ? null : _billingRemarkCtrl.text.trim(),
        arAccountId: _arAccountId,
        salesTerritoryId: _salesTerritoryId,
        salespersonId: _salespersonId,
        billingCollectorId: _billingCollectorId,
        collectionCollectorId: _collectionCollectorId,
        addresses:    _addresses,
        contacts:     _contacts,
        bankAccounts: _bankAccounts,
      );
      await widget.onSubmit(customer);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl, {
    bool readOnly = false,
    bool required = false,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        readOnly: readOnly,
        controller: ctrl,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (v) =>
                (v == null || v.trim().isEmpty) ? 'กรุณาป้อน $label' : null
            : null,
      ),
    );
  }

  // ---- Code Field: รหัสลูกหนี้ (รองรับทั้งแบบ auto และ manual) ----
  Widget _buildCodeField(bool readOnly) {
    final isAdd = widget.mode == Mode.add;
    final isLocked = readOnly || widget.mode == Mode.edit;

    // โหมด add + auto-numbering เปิด + ยังไม่ได้กด "แก้ไขเอง"
    if (isAdd && _autoNumberingEnabled && !_autoCodeOverridden) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'รหัสลูกหนี้',
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

    // โหมด add + auto-numbering เปิด + ผู้ใช้กด "แก้ไขเอง"
    if (isAdd && _autoNumberingEnabled && _autoCodeOverridden) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'รหัสลูกหนี้ *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'กรุณาป้อน รหัสลูกหนี้' : null,
                textCapitalization: TextCapitalization.characters,
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

    // โหมด edit / view / auto-numbering ปิด → ปกติ
    return _buildField('รหัสลูกหนี้ *', _codeCtrl,
        readOnly: isLocked, required: !isLocked);
  }

  // ---- Section: ข้อมูลทั่วไป ----
  Widget _buildGeneralSection(bool readOnly) {
    return _Section(
      title: 'ข้อมูลทั่วไป',
      children: [
        Row(
          children: [
            Expanded(
              child: _buildCodeField(readOnly),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildField('เลขประจำตัวผู้เสียภาษี', _taxIdCtrl,
                  readOnly: readOnly),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildField('รหัสลูกหนี้เก่า', _oldCustomerCodeCtrl,
                  readOnly: readOnly),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _buildField('ชื่อลูกหนี้ (ไทย) *', _nameThCtrl,
                  readOnly: readOnly, required: true),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildField('ชื่อลูกหนี้ (อังกฤษ)', _nameEnCtrl,
                  readOnly: readOnly),
            ),
          ],
        ),
        // ---- ประเภทธุรกิจ (search dialog) ----
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'ประเภทธุรกิจ',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _businessTypeId == null
                      ? const Text('— ไม่ระบุ —',
                          style: TextStyle(color: Colors.grey))
                      : Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '$_businessTypeCode — $_businessTypeNameThai',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                ),
                if (!readOnly) ...[
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.blue),
                    tooltip: 'ค้นหาประเภทธุรกิจ',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _pickBusinessType,
                  ),
                  if (_businessTypeId != null)
                    IconButton(
                      icon: const Icon(Icons.clear,
                          color: Colors.red, size: 18),
                      tooltip: 'ล้างประเภทธุรกิจ',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _clearBusinessType,
                    ),
                ],
              ],
            ),
          ),
        ),

        // ---- กลุ่มลูกค้า (search popup + auto-fill) ----
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'กลุ่มลูกค้า',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _customerGroupId == null
                      ? const Text('— ไม่ระบุ —',
                          style: TextStyle(color: Colors.grey))
                      : Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '$_customerGroupCode — $_customerGroupName',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                ),
                if (!readOnly) ...[
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.blue),
                    tooltip: 'ค้นหากลุ่มลูกค้า',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _pickCustomerGroup,
                  ),
                  if (_customerGroupId != null)
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.red, size: 18),
                      tooltip: 'ล้างกลุ่มลูกค้า',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _clearGroup,
                    ),
                ],
              ],
            ),
          ),
        ),

        // ---- เงื่อนไขเครดิต ----
        Row(
          children: [
            Expanded(
              child: _buildField('เครดิต (วัน)', _creditDaysCtrl,
                  readOnly: readOnly, keyboard: TextInputType.number),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildField('วงเงินเครดิต', _creditLimitCtrl,
                  readOnly: readOnly,
                  keyboard: const TextInputType.numberWithOptions(decimal: true)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildField('ส่วนลด (%)', _discountPercentCtrl,
                  readOnly: readOnly,
                  keyboard: const TextInputType.numberWithOptions(decimal: true)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'สกุลเงิน',
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _selectedCurrencyCode == null
                          ? const Text('— ไม่ระบุ —',
                              style: TextStyle(color: Colors.grey))
                          : Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    color: Colors.green, size: 16),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _selectedCurrencyNameThai != null
                                        ? '$_selectedCurrencyCode — $_selectedCurrencyNameThai'
                                        : _selectedCurrencyCode!,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    if (!readOnly) ...[
                      IconButton(
                        icon: const Icon(Icons.search, color: Colors.blue),
                        tooltip: 'ค้นหาสกุลเงิน',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: _pickCurrency,
                      ),
                      if (_selectedCurrencyCode != null)
                        IconButton(
                          icon: const Icon(Icons.clear,
                              color: Colors.red, size: 18),
                          tooltip: 'ล้างสกุลเงิน',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: _clearCurrency,
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          ],
        ),
        _buildField('หมายเหตุ', _remarkCtrl, readOnly: readOnly),
        SwitchListTile(
          title: Text('สถานะ: ${_isActive ? 'ใช้งาน' : 'หยุดใช้'}'),
          value: _isActive,
          onChanged: readOnly ? null : (v) => setState(() => _isActive = v),
        ),
      ],
    );
  }

  // ---- Section: ที่อยู่ ----
  Widget _buildAddressSection(bool readOnly) {
    return _Section(
      title: 'ที่อยู่ (${_addresses.length})',
      initiallyExpanded: false,
      trailing: readOnly
          ? null
          : IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              tooltip: 'เพิ่มที่อยู่',
              onPressed: () async {
                final primary = _addresses.cast<ArCustomerAddress?>()
                    .firstWhere((a) => a!.isDefault, orElse: () => null);
                final result = await showAddressDialog(context, null, false,
                    primaryAddress: primary);
                if (result != null) setState(() => _addresses.add(result));
              },
            ),
      children: [
        if (_addresses.isEmpty)
          const Text('ยังไม่มีที่อยู่',
              style: TextStyle(color: Colors.grey)),
        ..._addresses.asMap().entries.map((entry) {
          final i = entry.key;
          final addr = entry.value;
          final label = [
            addr.addressNo,
            addr.addressBuildingVillage,
            addr.addressAlley != null ? 'ซ.${addr.addressAlley}' : null,
            addr.addressRoad != null ? 'ถ.${addr.addressRoad}' : null,
          ].where((s) => s != null && s.isNotEmpty).join(' ').trim();
          final displayLabel = label.isNotEmpty
              ? label
              : [addr.addressSubDistrict, addr.addressProvince]
                    .where((s) => s != null && s.isNotEmpty)
                    .join(', ')
                    .trim().isEmpty
                  ? 'ที่อยู่ ${i + 1}'
                  : [addr.addressSubDistrict, addr.addressProvince]
                      .where((s) => s != null && s.isNotEmpty)
                      .join(', ');
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.location_on_outlined, size: 18),
            title: Text(displayLabel),
            subtitle: Text([
              addr.addressType,
              if (addr.addressSubDistrict != null) addr.addressSubDistrict!,
              if (addr.addressProvince != null) addr.addressProvince!,
              if (addr.addressZipCode != null) addr.addressZipCode!,
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
                    final primary = _addresses.cast<ArCustomerAddress?>()
                        .firstWhere((a) => a!.isDefault, orElse: () => null);
                    final result = await showAddressDialog(
                        context, addr, readOnly,
                        primaryAddress: primary);
                    if (result != null) {
                      setState(() => _addresses[i] = result);
                    }
                  },
                ),
                if (!readOnly)
                  IconButton(
                    icon:
                        const Icon(Icons.delete, size: 18, color: Colors.red),
                    onPressed: () =>
                        setState(() => _addresses.removeAt(i)),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ---- Section: ผู้ติดต่อ ----
  Widget _buildContactSection(bool readOnly) {
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
          const Text('ยังไม่มีผู้ติดต่อ',
              style: TextStyle(color: Colors.grey)),
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
                    final result =
                        await showContactDialog(context, c, readOnly);
                    if (result != null) {
                      setState(() => _contacts[i] = result);
                    }
                  },
                ),
                if (!readOnly)
                  IconButton(
                    icon:
                        const Icon(Icons.delete, size: 18, color: Colors.red),
                    onPressed: () =>
                        setState(() => _contacts.removeAt(i)),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ---- Section: เงื่อนไขการวางบิล ----
  Widget _buildBillingSection(bool readOnly) {
    const dayNames = ['อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์'];
    const weekOptions = <int, String>{1: 'แรก', 2: 'ที่ 2', 3: 'ที่ 3', 4: 'ที่ 4', -1: 'สุดท้าย'};

    return _Section(
      title: 'เงื่อนไขการวางบิล',
      initiallyExpanded: false,
      children: [
        // วันในสัปดาห์ + สัปดาห์ที่
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // วันในสัปดาห์
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'วันในสัปดาห์',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _billingDayOfWeek,
                      isDense: true,
                      hint: const Text('— ไม่ระบุ —', style: TextStyle(color: Colors.grey)),
                      onChanged: readOnly
                          ? null
                          : (v) => setState(() => _billingDayOfWeek = v),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('— ไม่ระบุ —')),
                        ...List.generate(7, (i) => DropdownMenuItem(
                          value: i,
                          child: Text(dayNames[i]),
                        )),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // สัปดาห์ที่
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'สัปดาห์ที่ (เลือกได้หลายค่า)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: weekOptions.entries.map((entry) {
                      final selected = _billingWeekOfMonth.contains(entry.key);
                      return FilterChip(
                        label: Text(entry.value, style: const TextStyle(fontSize: 12)),
                        selected: selected,
                        onSelected: readOnly
                            ? null
                            : (v) => setState(() {
                                  if (v) {
                                    _billingWeekOfMonth = [..._billingWeekOfMonth, entry.key];
                                  } else {
                                    _billingWeekOfMonth = _billingWeekOfMonth
                                        .where((w) => w != entry.key)
                                        .toList();
                                  }
                                }),
                        selectedColor: Colors.indigo.shade100,
                        checkmarkColor: Colors.indigo,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
        // วันที่ตั้งแต่ / ถึง / เวลาตั้งแต่ / ถึง
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextFormField(
                  controller: _billingDateFromCtrl,
                  readOnly: readOnly,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'วันที่ตั้งแต่',
                    border: OutlineInputBorder(),
                    hintText: '1–31',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextFormField(
                  controller: _billingDateToCtrl,
                  readOnly: readOnly,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ถึงวันที่',
                    border: OutlineInputBorder(),
                    hintText: '1–31',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextFormField(
                  controller: _billingTimeFromCtrl,
                  readOnly: readOnly,
                  decoration: const InputDecoration(
                    labelText: 'เวลาตั้งแต่',
                    border: OutlineInputBorder(),
                    hintText: '09:00',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextFormField(
                  controller: _billingTimeToCtrl,
                  readOnly: readOnly,
                  decoration: const InputDecoration(
                    labelText: 'ถึงเวลา',
                    border: OutlineInputBorder(),
                    hintText: '12:00',
                  ),
                ),
              ),
            ),
          ],
        ),
        // ยกเว้นวันหยุด
        SwitchListTile(
          title: const Text('ยกเว้นวันเสาร์-อาทิตย์ และวันหยุดนักขัตฤกษ์'),
          value: _billingExcludeHolidays,
          onChanged: readOnly ? null : (v) => setState(() => _billingExcludeHolidays = v),
          contentPadding: EdgeInsets.zero,
        ),
        // หมายเหตุ
        _buildField('หมายเหตุการวางบิล', _billingRemarkCtrl, readOnly: readOnly),
      ],
    );
  }

  // ---- Section: บัญชีธนาคาร ----
  Widget _buildBankSection(bool readOnly) {
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
                if (result != null) {
                  setState(() => _bankAccounts.add(result));
                }
              },
            ),
      children: [
        if (_bankAccounts.isEmpty)
          const Text('ยังไม่มีบัญชีธนาคาร',
              style: TextStyle(color: Colors.grey)),
        ..._bankAccounts.asMap().entries.map((entry) {
          final i = entry.key;
          final b = entry.value;
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_balance_outlined, size: 18),
            title: Text([b.bankName, b.accountNumber]
                .where((s) => s != null && s.isNotEmpty)
                .join('  ')),
            subtitle: Text(b.accountName ?? ''),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                      readOnly ? Icons.visibility : Icons.edit,
                      size: 18,
                      color: readOnly ? Colors.green : Colors.blue),
                  onPressed: () async {
                    final result =
                        await showBankDialog(context, b, readOnly);
                    if (result != null) {
                      setState(() => _bankAccounts[i] = result);
                    }
                  },
                ),
                if (!readOnly)
                  IconButton(
                    icon:
                        const Icon(Icons.delete, size: 18, color: Colors.red),
                    onPressed: () =>
                        setState(() => _bankAccounts.removeAt(i)),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ---- Section: เขตการขาย & พนักงานขาย ----
  Widget _buildSalesTerritorySection(bool readOnly) {
    return _Section(
      title: 'เขตการขายและพนักงานขาย',
      initiallyExpanded: false,
      children: [
        // ── เขตการขาย ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'เขตการขาย',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _salesTerritoryId == null
                      ? const Text('— ไม่ระบุ —',
                          style: TextStyle(color: Colors.grey))
                      : Row(children: [
                          const Icon(Icons.map_outlined,
                              color: Colors.teal, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${_salesTerritoryCode ?? ''} — ${_salesTerritoryNameThai ?? ''}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ]),
                ),
                if (!readOnly) ...[
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.blue),
                    tooltip: 'ค้นหาเขตการขาย',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _pickSalesTerritory,
                  ),
                  if (_salesTerritoryId != null)
                    IconButton(
                      icon: const Icon(Icons.clear,
                          color: Colors.red, size: 18),
                      tooltip: 'ล้างเขตการขาย',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _clearSalesTerritory,
                    ),
                ],
              ],
            ),
          ),
        ),

        // ── พนักงานขาย ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'พนักงานขาย',
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              helperText: _salesTerritoryId == null && !readOnly
                  ? 'กรุณาเลือกเขตการขายก่อน'
                  : null,
              helperStyle:
                  const TextStyle(fontSize: 11, color: Colors.orange),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _loadingMembers
                      ? const Row(children: [
                          SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('กำลังโหลด...',
                              style: TextStyle(color: Colors.grey)),
                        ])
                      : _salespersonId == null
                          ? const Text('— ไม่ระบุ —',
                              style: TextStyle(color: Colors.grey))
                          : Row(children: [
                              const Icon(Icons.person_outline,
                                  color: Colors.blue, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${_salespersonCode ?? ''} — ${_salespersonNameThai ?? ''}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ]),
                ),
                if (!readOnly) ...[
                  IconButton(
                    icon: Icon(Icons.search,
                        color: _salesTerritoryId != null
                            ? Colors.blue
                            : Colors.grey),
                    tooltip: _salesTerritoryId != null
                        ? 'ค้นหาพนักงานขาย'
                        : 'เลือกเขตการขายก่อน',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed:
                        _salesTerritoryId != null ? _pickSalesperson : null,
                  ),
                  if (_salespersonId != null)
                    IconButton(
                      icon: const Icon(Icons.clear,
                          color: Colors.red, size: 18),
                      tooltip: 'ล้างพนักงานขาย',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _clearSalesperson,
                    ),
                ],
              ],
            ),
          ),
        ),

        // ── ผู้วางบิล ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'ผู้วางบิล',
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _billingCollectorId == null
                      ? const Text('— ไม่ระบุ —',
                          style: TextStyle(color: Colors.grey))
                      : Row(children: [
                          const Icon(Icons.receipt_long_outlined,
                              color: Colors.indigo, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${_billingCollectorCode ?? ''} — ${_billingCollectorNameThai ?? ''}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ]),
                ),
                if (!readOnly) ...[
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.blue),
                    tooltip: 'ค้นหาผู้วางบิล',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _pickBillingCollector,
                  ),
                  if (_billingCollectorId != null)
                    IconButton(
                      icon: const Icon(Icons.clear,
                          color: Colors.red, size: 18),
                      tooltip: 'ล้างผู้วางบิล',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _clearBillingCollector,
                    ),
                ],
              ],
            ),
          ),
        ),

        // ── ผู้รับชำระ ─────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'ผู้รับชำระ',
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _collectionCollectorId == null
                      ? const Text('— ไม่ระบุ —',
                          style: TextStyle(color: Colors.grey))
                      : Row(children: [
                          const Icon(Icons.payments_outlined,
                              color: Colors.green, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${_collectionCollectorCode ?? ''} — ${_collectionCollectorNameThai ?? ''}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ]),
                ),
                if (!readOnly) ...[
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.blue),
                    tooltip: 'ค้นหาผู้รับชำระ',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _pickCollectionCollector,
                  ),
                  if (_collectionCollectorId != null)
                    IconButton(
                      icon: const Icon(Icons.clear,
                          color: Colors.red, size: 18),
                      tooltip: 'ล้างผู้รับชำระ',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _clearCollectionCollector,
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---- Section: บัญชีลูกหนี้ GL ----
  Widget _buildArAccountSection(bool readOnly) {
    return _Section(
      title: 'รหัสบัญชีลูกหนี้',
      initiallyExpanded: false,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'รหัสบัญชีลูกหนี้ (GL)',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _arAccountId == null
                      ? const Text('— ไม่ระบุ —',
                          style: TextStyle(color: Colors.grey))
                      : Row(
                          children: [
                            const Icon(Icons.account_balance,
                                color: Colors.green, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${_arAccountCode ?? ''} — ${_arAccountNameThai ?? ''}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                ),
                if (!readOnly) ...[
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.blue),
                    tooltip: 'ค้นหาบัญชีลูกหนี้',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _pickArAccount,
                  ),
                  if (_arAccountId != null)
                    IconButton(
                      icon: const Icon(Icons.clear,
                          color: Colors.red, size: 18),
                      tooltip: 'ล้างบัญชีลูกหนี้',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _clearArAccount,
                    ),
                ],
              ],
            ),
          ),
        ),
        if (_arAccountId == null)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'หากไม่ระบุ ระบบจะใช้บัญชีลูกหนี้จากกลุ่มลูกค้าเป็นค่าเริ่มต้น',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPlaceholder) {
      return const Center(
        child: Text(
            'เลือกลูกหนี้เพื่อแก้ไข หรือ ลบ หรือ กดปุ่ม + เพื่อเพิ่มลูกหนี้ใหม่'),
      );
    }

    final bool readOnly = widget.mode == Mode.view;
    final String title = readOnly
        ? 'ดูข้อมูลลูกหนี้'
        : widget.mode == Mode.edit
            ? 'แก้ไขลูกหนี้'
            : 'เพิ่มลูกหนี้ใหม่';

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header bar
          Container(
            color: Colors.blueGrey[700],
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.person, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  title,
                  // style: Theme.of(context).textTheme.headlineSmall,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      // fontWeight: FontWeight.bold
                  ),
                ),
              ],
            ),
          ),
          // Scrollable sections
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGeneralSection(readOnly),
                  _buildSalesTerritorySection(readOnly),
                  _buildBillingSection(readOnly),
                  _buildAddressSection(readOnly),
                  _buildContactSection(readOnly),
                  _buildBankSection(readOnly),
                  _buildArAccountSection(readOnly),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!readOnly)
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _submitForm,
                    icon: _isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save),
                    label: Text(_isSaving
                        ? 'กำลังบันทึก...'
                        : widget.mode == Mode.edit
                            ? 'บันทึก'
                            : 'เพิ่ม'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                  ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.cancel),
                  label: const Text('ยกเลิก'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
