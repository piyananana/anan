import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../cd/models/cd_zipcode.dart';
import '../../cd/models/cd_currency.dart';
import '../../cd/services/cd_currency_service.dart';
import '../../cd/widgets/cd_zipcode_list_widget.dart';
import '../../cd/widgets/cd_tax_branch_field.dart';
import '../../cd/models/cd_bank.dart';
import '../../cd/models/cd_bank_branch.dart';
import '../../cd/services/cd_bank_branch_service.dart';
import '../../cd/widgets/cd_bank_list_widget.dart';
import '../../cd/models/cd_business_type.dart';
import '../../cd/services/cd_business_type_service.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../../cm/models/cm_payment_method.dart';
import '../../cm/widgets/cm_payment_method_list_widget.dart';
import '../models/ap_vendor.dart';
import '../services/ap_vendor_running_service.dart';
import '../services/ap_vendor_group_service.dart';
import '../widgets/ap_vendor_group_list_widget.dart';
import '../../im/widgets/im_price_list_list_widget.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../im/widgets/im_master_kit.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../models/ap_vendor_group.dart';
import '../models/ap_vendor_summary.dart';
import '../services/ap_vendor_service.dart';


// ---------------------------------------------------------------------------
// Address Dialog
// ---------------------------------------------------------------------------
Future<ApVendorAddress?> showAddressDialog(
    BuildContext context, ApVendorAddress? existing, bool readOnly,
    {ApVendorAddress? primaryAddress}) async {
  final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
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
              ? (isEnglish ? 'View Address' : 'ดูที่อยู่')
              : existing == null
                  ? (isEnglish ? 'Add Address' : 'เพิ่มที่อยู่')
                  : (isEnglish ? 'Edit Address' : 'แก้ไขที่อยู่')),
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
                        title: Text(isEnglish ? 'Use the same address as the primary address' : 'ใช้ที่อยู่เดียวกับที่อยู่หลัก'),
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
                        decoration: InputDecoration(
                            labelText: isEnglish ? 'Address Type' : 'ประเภทที่อยู่',
                            border: const OutlineInputBorder()),
                        items: [
                          DropdownMenuItem(value: 'billing', child: Text(isEnglish ? 'Billing Address' : 'ที่อยู่ใบแจ้งหนี้')),
                          DropdownMenuItem(value: 'shipping', child: Text(isEnglish ? 'Shipping Address' : 'ที่อยู่จัดส่ง')),
                          DropdownMenuItem(value: 'billing note', child: Text(isEnglish ? 'Billing Note Address' : 'ที่อยู่วางบิล')),
                          DropdownMenuItem(value: 'payment', child: Text(isEnglish ? 'Payment Address' : 'ที่อยู่ชำระเงิน')),
                          DropdownMenuItem(value: 'other', child: Text(isEnglish ? 'Other' : 'อื่นๆ')),
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
                    Expanded(child: buildField(isEnglish ? 'House No. / Room' : 'บ้านเลขที่ / ห้อง', noCtrl)),
                    const SizedBox(width: 8),
                    Expanded(child: buildField(isEnglish ? 'Building / Village' : 'อาคาร / หมู่บ้าน', buildingCtrl)),
                  ]),
                  Row(children: [
                    Expanded(child: buildField(isEnglish ? 'Alley' : 'ซอย', alleyCtrl)),
                    const SizedBox(width: 8),
                    Expanded(child: buildField(isEnglish ? 'Road' : 'ถนน', roadCtrl)),
                  ]),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (!readOnly)
                        IconButton(
                          icon: const Icon(Icons.search, color: Colors.blue),
                          tooltip: isEnglish ? 'Search sub-district, district, province, zip code' : 'ค้นหา ตำบล/แขวง, อำเภอ/เขต, จังหวัด, รหัสไปรษณีย์',
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
                              Expanded(child: buildField(isEnglish ? 'Sub-district' : 'ตำบล / แขวง', subDistCtrl)),
                              const SizedBox(width: 8),
                              Expanded(child: buildField(isEnglish ? 'District' : 'อำเภอ / เขต', distCtrl)),
                            ]),
                            Row(children: [
                              Expanded(child: buildField(isEnglish ? 'Province' : 'จังหวัด', provCtrl)),
                              const SizedBox(width: 8),
                              Expanded(child: buildField(isEnglish ? 'Zip Code' : 'รหัสไปรษณีย์', zipCtrl)),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                  buildField(isEnglish ? 'Country' : 'ประเทศ', countryCtrl),
                  ValueListenableBuilder<bool>(
                    valueListenable: isDefaultNotifier,
                    builder: (_, v, __) => SwitchListTile(
                      title: Text(isEnglish ? 'Primary Address' : 'ที่อยู่หลัก'),
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
                child: Text(isEnglish ? 'Save' : 'บันทึก'),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(isEnglish ? 'Close' : 'ปิด'),
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
  final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
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
          ? (isEnglish ? 'View Contact' : 'ดูผู้ติดต่อ')
          : existing == null
              ? (isEnglish ? 'Add Contact' : 'เพิ่มผู้ติดต่อ')
              : (isEnglish ? 'Edit Contact' : 'แก้ไขผู้ติดต่อ')),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                readOnly: readOnly,
                controller: nameCtrl,
                decoration: InputDecoration(
                    labelText: isEnglish ? 'Contact Name *' : 'ชื่อผู้ติดต่อ *', border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                readOnly: readOnly,
                controller: posCtrl,
                decoration: InputDecoration(
                    labelText: isEnglish ? 'Position' : 'ตำแหน่ง', border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      readOnly: readOnly,
                      controller: phoneCtrl,
                      decoration: InputDecoration(
                          labelText: isEnglish ? 'Phone' : 'โทรศัพท์', border: const OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      readOnly: readOnly,
                      controller: mobileCtrl,
                      decoration: InputDecoration(
                          labelText: isEnglish ? 'Mobile' : 'มือถือ', border: const OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                readOnly: readOnly,
                controller: emailCtrl,
                decoration: InputDecoration(
                    labelText: isEnglish ? 'Email' : 'อีเมล', border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder<bool>(
                valueListenable: isDefaultNotifier,
                builder: (_, v, __) => SwitchListTile(
                  title: Text(isEnglish ? 'Primary Contact' : 'ผู้ติดต่อหลัก'),
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
            child: Text(isEnglish ? 'Save' : 'บันทึก'),
          ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(isEnglish ? 'Close' : 'ปิด'),
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
    final isEnglish = Provider.of<LanguageProvider>(context).isEnglish;
    final readOnly = widget.readOnly;
    return AlertDialog(
      title: Text(readOnly
          ? (isEnglish ? 'View Bank Account' : 'ดูบัญชีธนาคาร')
          : widget.existing == null
              ? (isEnglish ? 'Add Bank Account' : 'เพิ่มบัญชีธนาคาร')
              : (isEnglish ? 'Edit Bank Account' : 'แก้ไขบัญชีธนาคาร')),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InputDecorator(
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Bank' : 'ธนาคาร',
                  border: const OutlineInputBorder(),
                  suffixIcon: readOnly
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_bankDisplay.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                tooltip: isEnglish ? 'Clear' : 'ล้าง',
                                onPressed: () => setState(() {
                                  _selectedBank = null;
                                  _bankDisplay = '';
                                  _branchCtrl.clear();
                                  _branchSuggestions = [];
                                }),
                              ),
                            IconButton(
                              icon: const Icon(Icons.search, size: 18),
                              tooltip: isEnglish ? 'Select bank' : 'เลือกธนาคาร',
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
                  labelText: isEnglish ? 'Branch' : 'สาขา',
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
                decoration: InputDecoration(
                    labelText: isEnglish ? 'Account Number' : 'เลขที่บัญชี', border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                readOnly: readOnly,
                controller: _accNameCtrl,
                decoration: InputDecoration(
                    labelText: isEnglish ? 'Account Name' : 'ชื่อบัญชี', border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _accType,
                decoration: InputDecoration(
                    labelText: isEnglish ? 'Account Type' : 'ประเภทบัญชี', border: const OutlineInputBorder()),
                items: [
                  DropdownMenuItem(value: 'current', child: Text(isEnglish ? 'Current' : 'กระแสรายวัน')),
                  DropdownMenuItem(value: 'savings', child: Text(isEnglish ? 'Savings' : 'ออมทรัพย์')),
                ],
                onChanged: readOnly
                    ? null
                    : (val) {
                        if (val != null) setState(() => _accType = val);
                      },
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                title: Text(isEnglish ? 'Primary Account' : 'บัญชีหลัก'),
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
                : Text(isEnglish ? 'Save' : 'บันทึก'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(isEnglish ? 'Close' : 'ปิด'),
        ),
      ],
    );
  }
}


// ---------------------------------------------------------------------------
// Main Detail Widget — แบบ B ของ IM (user 2026-11-28, เหมือนหน้าลูกค้า AR)
//   เปิดมาเป็นโหมดดู → แก้ไข / สำเนาเป็นผู้ขายใหม่ / ลบ ที่แถบหัว
//   ตัวเลขสรุป + 4 กลุ่มสี + ตารางที่อยู่/ผู้ติดต่อ/บัญชีธนาคาร (กดแถวเปิดหน้าต่างเดิม)
//   + ที่มาบัญชีเจ้าหนี้ (ผู้ขาย > กลุ่ม > ประเภทเอกสาร) + ยอดค้างจ่ายตามอายุหนี้
// ---------------------------------------------------------------------------
class ApVendorDetailWidget extends StatefulWidget {
  final Mode mode;
  final ApVendor? selected;
  final Future<void> Function(ApVendor) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;
  // เพิ่มขึ้นทุกครั้งที่ผู้ใช้กดปุ่มเพิ่ม/แก้ไข/ดู/ยกเลิกจากหน้าจอหลัก — ใช้บังคับให้ didUpdateWidget เคลียร์ฟอร์ม
  // เสมอ แม้ mode/selected จะ "เหมือนเดิม" กับครั้งก่อน (เช่น กดเพิ่มเจ้าหนี้ซ้ำหลังพิมพ์ข้อมูลค้างไว้)
  final int requestSeq;
  // สำเนาเป็นผู้ขายใหม่ + ปุ่มของแถบหัว (null = ไม่มีสิทธิ์/ยังโหลดไม่ครบ)
  final ApVendor? copyFrom;
  final VoidCallback? onEdit;
  final VoidCallback? onCopy;
  final VoidCallback? onDelete;

  const ApVendorDetailWidget({
    super.key,
    required this.mode,
    required this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
    this.requestSeq = 0,
    this.copyFrom,
    this.onEdit,
    this.onCopy,
    this.onDelete,
  });

  @override
  State<ApVendorDetailWidget> createState() => ApVendorDetailWidgetState();
}

class ApVendorDetailWidgetState extends State<ApVendorDetailWidget> with ImMasterKit {
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isEnglish = false;

  @override
  bool get kitEnglish => _isEnglish;
  @override
  bool get kitReadOnly => widget.mode == Mode.view || widget.mode == Mode.none;

  // ตัวเลขสรุป/อายุหนี้/ที่มาบัญชีเจ้าหนี้ (เฉพาะผู้ขายที่บันทึกแล้ว)
  ApVendorSummary? _summary;
  bool _summaryLoading = false;
  int? _summaryFor;

  // แก้ไขค้าง → หน้าจอหลักถามก่อนเปลี่ยนผู้ขาย
  String _snapshot = '';
  bool get isDirty => !kitReadOnly && !widget.isPlaceholder && _fingerprint() != _snapshot;
  bool get _isCopy => widget.mode == Mode.add && widget.copyFrom != null;

  late TextEditingController _codeCtrl;
  late TextEditingController _oldCodeCtrl;
  late TextEditingController _nameTHCtrl;
  late TextEditingController _nameENCtrl;
  late TextEditingController _taxIdCtrl;
  late TextEditingController _taxBranchCtrl;
  late TextEditingController _remarkCtrl;
  late TextEditingController _creditMonthsCtrl;
  late TextEditingController _creditDaysCtrl;
  late TextEditingController _creditLimitCtrl;

  bool _isActive = true;

  // สกุลเงิน
  String? _selectedCurrencyCode;
  String? _selectedCurrencyNameThai;
  List<Currency> _currencies = [];

  // รหัสอัตโนมัติ
  bool _autoNumberingEnabled = false;
  bool? _vendorGroupIsAutoNumber;
  bool _autoCodeOverridden = false;
  // true เมื่อระเบียนนี้ถูกสร้าง (ครั้งแรก) โดยรหัสถูกออกอัตโนมัติ — ล็อกกลุ่มผู้ขายถาวร ไม่ขึ้นกับ setting ปัจจุบันของกลุ่ม
  bool _isCodeAutoGenerated = false;

  bool get _effectiveAutoNumbering {
    if (_vendorGroupId != null && (_vendorGroupIsAutoNumber == true)) return true;
    return _autoNumberingEnabled;
  }

  // ฟิลด์ที่เชื่อมกับตารางอื่น
  int? _vendorGroupId;
  String? _vendorGroupCode;
  String? _vendorGroupName;
  String? _vendorGroupNameEng;
  List<ApVendorGroup> _groups = [];
  // ตารางราคา (im_price_list) — ผู้ขายรายนี้ใช้ได้รหัสเดียวเท่านั้น แยกจาก vendorGroupId โดยสิ้นเชิง
  int? _priceListId;
  String? _priceListCode;
  String? _priceListName;
  int? _businessTypeId;
  String? _businessTypeCode;
  String? _businessTypeNameThai;
  String? _businessTypeNameEng;
  String? _vendorType;
  int? _apAccountId;
  String? _apAccountCode;
  String? _apAccountNameThai;
  String? _apAccountNameEng;
  int? _paymentMethodId;
  String? _paymentMethodCode;
  String? _paymentMethodNameThai;
  String? _paymentMethodNameEng;

  List<ApVendorAddress> _addresses = [];
  List<ApVendorContact> _contacts = [];
  List<ApVendorBankAccount> _bankAccounts = [];

  List<BusinessType> _businessTypes = [];
  List<Account> _controlAccounts = [];

  // ข้อมูลตั้งต้นของฟอร์ม: เพิ่มแบบสำเนา = ผู้ขายต้นฉบับ, เพิ่มใหม่ = ว่าง
  ApVendor? get _source => widget.mode == Mode.add ? widget.copyFrom : widget.selected;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadDropdowns();
    _loadCurrencies();
    _loadGroups();
    _loadAutoNumberingConfig();
    _apply(_source);
    if (_source == null) _loadDefaultCurrency();
    _loadSummary();
  }

  // ค่าที่โหลดตามหลังมาเปลี่ยนฟอร์ม — ถ้ายังไม่ได้แก้อะไรให้ถือว่ายังไม่แก้
  void _keepClean(VoidCallback fn) {
    final wasClean = _fingerprint() == _snapshot;
    setState(fn);
    if (wasClean) _snapshot = _fingerprint();
  }

  void _initControllers() {
    _codeCtrl         = TextEditingController();
    _oldCodeCtrl      = TextEditingController();
    _nameTHCtrl       = TextEditingController();
    _nameENCtrl       = TextEditingController();
    _taxIdCtrl        = TextEditingController();
    _taxBranchCtrl    = TextEditingController();
    _remarkCtrl       = TextEditingController();
    _creditMonthsCtrl = TextEditingController(text: '0');
    _creditDaysCtrl   = TextEditingController(text: '30');
    _creditLimitCtrl  = TextEditingController(text: '0');
  }

  @override
  void didUpdateWidget(covariant ApVendorDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = widget.selected != oldWidget.selected ||
        widget.mode != oldWidget.mode ||
        widget.requestSeq != oldWidget.requestSeq ||
        widget.copyFrom != oldWidget.copyFrom;
    if (!changed) return;
    final sameRecord = widget.selected?.id != null && widget.selected?.id == oldWidget.selected?.id;
    // ข้อมูลเต็มโหลดตามมาทีหลัง (mode/seq เดิม) — ไม่ล้างตำแหน่งเลื่อน
    final onlyFullLoad = sameRecord && widget.mode == oldWidget.mode && widget.requestSeq == oldWidget.requestSeq;
    _apply(_source);
    if (_source == null) _loadDefaultCurrency();
    if (widget.mode == Mode.add && oldWidget.mode != Mode.add) _loadAutoNumberingConfig();
    if (!sameRecord) _summaryFor = null;
    _loadSummary();
    if (!onlyFullLoad) kScrollTop();
    setState(() {});
  }

  @override
  void dispose() {
    _codeCtrl.dispose(); _oldCodeCtrl.dispose(); _nameTHCtrl.dispose();
    _nameENCtrl.dispose(); _taxIdCtrl.dispose(); _taxBranchCtrl.dispose(); _remarkCtrl.dispose();
    _creditMonthsCtrl.dispose(); _creditDaysCtrl.dispose(); _creditLimitCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    final id = widget.mode == Mode.add ? null : widget.selected?.id;
    if (id == null) {
      _summary = null;
      _summaryFor = null;
      return;
    }
    if (_summaryFor == id && _summary != null) return;
    _summaryFor = id;
    _summaryLoading = true;
    try {
      final s = await ApVendorService().fetchSummary(id);
      if (mounted && _summaryFor == id) setState(() => _summary = s);
    } catch (_) {
      if (mounted && _summaryFor == id) setState(() => _summary = null);
    } finally {
      if (mounted && _summaryFor == id) setState(() => _summaryLoading = false);
    }
  }

  Future<void> _loadDropdowns() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        BusinessTypeService().fetchActiveRows(),
        AccountService().fetchRows(),
      ]);
      if (mounted) {
        _keepClean(() {
          _businessTypes   = results[0] as List<BusinessType>;
          final allAccounts = results[1] as List<Account>;
          _controlAccounts = allAccounts
              .where((a) => a.isControlAccount && a.isNormalAccount && a.isActive)
              .toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadGroups() async {
    try {
      final list = await ApVendorGroupService().fetchRows();
      if (mounted) {
        _keepClean(() {
          _groups = list;
          final g = _groupObj;
          if (g != null) {
            _vendorGroupIsAutoNumber = g.isAutoNumber;
            _vendorGroupNameEng = g.groupNameEng;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadCurrencies() async {
    try {
      final list = await CurrencyService().fetchActiveRows();
      if (mounted) {
        _keepClean(() {
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
    String code;
    try {
      code = await CurrencyService().getBaseCurrencyCode();
    } catch (_) {
      code = CurrencyService.baseCode;
    }
    if (mounted && _selectedCurrencyCode == null) _keepClean(() => _selectedCurrencyCode = code);
  }

  Future<void> _loadAutoNumberingConfig() async {
    if (widget.mode != Mode.add) return;
    try {
      final config = await ApVendorRunningService().fetchConfig();
      if (mounted) _keepClean(() => _autoNumberingEnabled = config.isAutoNumbering);
    } catch (_) {}
  }

  // เติมฟอร์มจากผู้ขาย (null = ว่าง) — สำเนาเป็นผู้ขายใหม่: ไม่เอารหัส / เลขผู้เสียภาษี / รหัสเดิม / บัญชีธนาคาร
  void _apply(ApVendor? v) {
    final copy = widget.mode == Mode.add && v != null;
    _autoCodeOverridden = false;
    _codeCtrl.text         = copy ? '' : v?.vendorCode ?? '';
    _oldCodeCtrl.text      = copy ? '' : v?.oldVendorCode ?? '';
    _nameTHCtrl.text       = v?.vendorNameTh ?? '';
    _nameENCtrl.text       = v?.vendorNameEn ?? '';
    _taxIdCtrl.text        = copy ? '' : v?.taxId ?? '';
    _taxBranchCtrl.text    = v?.taxBranchCode ?? '';
    _remarkCtrl.text       = v?.remark ?? '';
    _creditMonthsCtrl.text = '${v?.creditTermMonths ?? 0}';
    _creditDaysCtrl.text   = '${v?.creditTermDays ?? 30}';
    _creditLimitCtrl.text  = (v?.creditLimit ?? 0).toStringAsFixed(2);
    _isActive              = v?.isActive ?? true;
    _selectedCurrencyCode  = v?.currencyCode;
    _selectedCurrencyNameThai = _currencies.where((c) => c.currencyCode == v?.currencyCode).firstOrNull?.currencyNameThai;
    _vendorGroupId         = v?.vendorGroupId;
    _vendorGroupCode       = v?.vendorGroupCode;
    _vendorGroupName       = v?.vendorGroupName;
    final g = _groupObj;
    _vendorGroupNameEng    = g?.groupNameEng;
    _vendorGroupIsAutoNumber = g?.isAutoNumber;
    _priceListId          = v?.priceListId;
    _priceListCode        = v?.priceListCode;
    _priceListName        = v?.priceListName;
    _isCodeAutoGenerated   = copy ? false : v?.isCodeAutoGenerated ?? false;
    _businessTypeId        = v?.businessTypeId;
    _businessTypeCode      = v?.businessTypeCode;
    _businessTypeNameThai  = v?.businessTypeNameThai;
    _businessTypeNameEng   = null;
    _vendorType            = v?.vendorType;
    _apAccountId           = v?.apAccountId;
    _apAccountCode         = v?.apAccountCode;
    _apAccountNameThai     = v?.apAccountNameThai;
    _apAccountNameEng      = null;
    _paymentMethodId       = v?.paymentMethodId;
    _paymentMethodCode     = v?.paymentMethodCode;
    _paymentMethodNameThai = v?.paymentMethodNameThai;
    _paymentMethodNameEng  = v?.paymentMethodNameEng;
    _addresses   = [for (final a in v?.addresses ?? const <ApVendorAddress>[]) a];
    _contacts    = [for (final c in v?.contacts ?? const <ApVendorContact>[]) c];
    _bankAccounts = copy ? [] : [for (final b in v?.bankAccounts ?? const <ApVendorBankAccount>[]) b];
    _snapshot = _fingerprint();
  }

  ApVendor _buildVendor() => ApVendor(
        id: widget.mode == Mode.add ? null : widget.selected?.id,
        vendorCode: (widget.mode == Mode.add && _effectiveAutoNumbering && !_autoCodeOverridden)
            ? ''
            : _codeCtrl.text.trim().toUpperCase(),
        oldVendorCode: _oldCodeCtrl.text.trim().isEmpty ? null : _oldCodeCtrl.text.trim(),
        vendorNameTh: _nameTHCtrl.text.trim(),
        vendorNameEn: _nameENCtrl.text.trim().isEmpty ? null : _nameENCtrl.text.trim(),
        taxId: _taxIdCtrl.text.trim().isEmpty ? null : _taxIdCtrl.text.trim(),
        taxBranchCode: normalizeTaxBranch(_taxBranchCtrl.text),
        vendorGroupId: _vendorGroupId,
        vendorGroupCode: _vendorGroupCode,
        vendorGroupName: _vendorGroupName,
        priceListId: _priceListId,
        businessTypeId: _businessTypeId,
        businessTypeCode: _businessTypeCode,
        businessTypeNameThai: _businessTypeNameThai,
        vendorType: _vendorType,
        creditTermMonths: int.tryParse(_creditMonthsCtrl.text) ?? 0,
        creditTermDays: int.tryParse(_creditDaysCtrl.text) ?? 30,
        creditLimit: double.tryParse(_creditLimitCtrl.text) ?? 0,
        currencyCode: _selectedCurrencyCode ?? CurrencyService.baseCode,
        isActive: _isActive,
        remark: _remarkCtrl.text.trim().isEmpty ? null : _remarkCtrl.text.trim(),
        apAccountId: _apAccountId,
        apAccountCode: _apAccountCode,
        apAccountNameThai: _apAccountNameThai,
        paymentMethodId: _paymentMethodId,
        paymentMethodCode: _paymentMethodCode,
        paymentMethodNameThai: _paymentMethodNameThai,
        paymentMethodNameEng: _paymentMethodNameEng,
        addresses: List.from(_addresses),
        contacts: List.from(_contacts),
        bankAccounts: List.from(_bankAccounts),
      );

  String _fingerprint() {
    try {
      return jsonEncode(_buildVendor().toJson());
    } catch (_) {
      return '';
    }
  }

  Future<void> _save() async {
    final e = _isEnglish;
    String? err;
    if (_nameTHCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter the vendor name (TH)' : 'กรุณาป้อนชื่อผู้ขาย (ไทย)';
    } else if (widget.mode == Mode.add && (!_effectiveAutoNumbering || _autoCodeOverridden) && _codeCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter the vendor code' : 'กรุณาป้อนรหัสผู้ขาย';
    }
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await widget.onSubmit(_buildVendor());
    } catch (ex) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e ? 'Error: $ex' : 'เกิดข้อผิดพลาด: $ex'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Group ──────────────────────────────────────────────────────────────────
  ApVendorGroup? get _groupObj => _vendorGroupId == null ? null : _groups.where((g) => g.id == _vendorGroupId).firstOrNull;

  Future<void> _pickVendorGroup() async {
    await ApVendorGroupListWidget.search(context, onSelected: (group) {
      // แก้ไขข้อมูลเดิม + รหัสป้อนเอง (ไม่ auto) → เปลี่ยนกลุ่มได้เฉพาะกลุ่มที่ไม่ auto ด้วยกัน
      if (widget.mode == Mode.edit && !_isCodeAutoGenerated &&
          group.isAutoNumber && group.id != _vendorGroupId) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEnglish
              ? 'This vendor\'s code was entered manually — it can only be moved to another non-auto-numbering group.'
              : 'ผู้ขายรายนี้ป้อนรหัสเอง เปลี่ยนไปได้เฉพาะกลุ่มที่ไม่ได้ตั้งค่ารหัสอัตโนมัติ'),
          backgroundColor: Colors.red,
        ));
        return;
      }
      setState(() {
        _vendorGroupId           = group.id;
        _vendorGroupCode         = group.groupCode;
        _vendorGroupName         = group.groupNameThai;
        _vendorGroupNameEng      = group.groupNameEng;
        _vendorGroupIsAutoNumber = group.isAutoNumber;
        _autoCodeOverridden      = false;
        if (widget.mode == Mode.add) _codeCtrl.clear();
        _creditMonthsCtrl.text = '${group.creditTermMonths}';
        _creditDaysCtrl.text   = '${group.creditTermDays}';
        _selectedCurrencyCode  = group.currencyCode;
        _selectedCurrencyNameThai = _currencies.where((c) => c.currencyCode == group.currencyCode).firstOrNull?.currencyNameThai;
      });
    });
  }

  void _clearGroup() {
    setState(() {
      _vendorGroupId = null; _vendorGroupCode = null; _vendorGroupName = null; _vendorGroupNameEng = null;
      _vendorGroupIsAutoNumber = null; _autoCodeOverridden = false;
      if (widget.mode == Mode.add) _codeCtrl.clear();
    });
  }

  // ── ตารางราคา (im_price_list) — ผู้ขายรายนี้ใช้ได้รหัสเดียวเท่านั้น แยกจาก vendorGroupId (นโยบายบัญชี/เครดิต) โดยสิ้นเชิง ──
  Future<void> _pickPriceList() async {
    await ImPriceListListWidget.search(context, listType: 'PURCHASE', onSelected: (h) {
      setState(() {
        _priceListId   = h.id;
        _priceListCode = h.priceListCode;
        _priceListName = h.priceListName;
      });
    });
  }

  void _clearPriceList() {
    setState(() {
      _priceListId = null; _priceListCode = null; _priceListName = null;
    });
  }

  // ── Business Type ──────────────────────────────────────────────────────────
  Future<void> _pickBusinessType() async {
    final isEnglish = _isEnglish;
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
                  b.businessTypeNameThai.toLowerCase().contains(q.toLowerCase()) ||
                  b.businessTypeNameEng.toLowerCase().contains(q.toLowerCase())).toList();
        });
        String btName(BusinessType b) =>
            isEnglish && b.businessTypeNameEng.isNotEmpty ? b.businessTypeNameEng : b.businessTypeNameThai;
        return AlertDialog(
          title: Text(isEnglish ? 'Select Business Type' : 'เลือกประเภทธุรกิจ'),
          content: SizedBox(
            width: 480, height: 380,
            child: Column(children: [
              TextField(
                controller: searchCtrl, autofocus: true,
                decoration: InputDecoration(
                  hintText: isEnglish ? 'Search code / business type name' : 'ค้นหา รหัส / ชื่อประเภทธุรกิจ',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onChanged: doFilter,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _businessTypes.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? Center(child: Text(isEnglish ? 'No data found' : 'ไม่พบข้อมูล'))
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
                                  Expanded(child: Text(btName(bt))),
                                ]),
                                onTap: () {
                                  setState(() {
                                    _businessTypeId       = bt.id;
                                    _businessTypeCode     = bt.businessTypeCode;
                                    _businessTypeNameThai = bt.businessTypeNameThai;
                                    _businessTypeNameEng  = bt.businessTypeNameEng;
                                  });
                                  Navigator.of(ctx).pop();
                                },
                              );
                            },
                          ),
              ),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Close' : 'ปิด'))],
        );
      }),
    );
    searchCtrl.dispose();
  }

  // ── Currency ───────────────────────────────────────────────────────────────
  Future<void> _pickCurrency() async {
    final isEnglish = _isEnglish;
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
                  c.currencyNameThai.toLowerCase().contains(q.toLowerCase()) ||
                  c.currencyNameEng.toLowerCase().contains(q.toLowerCase())).toList();
        });
        String curName(Currency c) =>
            isEnglish && c.currencyNameEng.isNotEmpty ? c.currencyNameEng : c.currencyNameThai;
        return AlertDialog(
          title: Text(isEnglish ? 'Select Currency' : 'เลือกสกุลเงิน'),
          content: SizedBox(
            width: 480, height: 380,
            child: Column(children: [
              TextField(
                controller: searchCtrl, autofocus: true,
                decoration: InputDecoration(
                  hintText: isEnglish ? 'Search code / currency name' : 'ค้นหา รหัส / ชื่อสกุลเงิน',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onChanged: doFilter,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _currencies.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? Center(child: Text(isEnglish ? 'No data found' : 'ไม่พบข้อมูล'))
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
                                  Expanded(child: Text(curName(c))),
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
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Close' : 'ปิด'))],
        );
      }),
    );
    searchCtrl.dispose();
  }

  // ── AP Account ─────────────────────────────────────────────────────────────
  Future<void> _pickApAccount() async {
    final isEnglish = _isEnglish;
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
                  a.accountNameThai.toUpperCase().contains(q.toUpperCase()) ||
                  a.accountNameEng.toUpperCase().contains(q.toUpperCase())).toList();
        });
        String acctName(Account a) =>
            isEnglish && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai;
        return AlertDialog(
          title: Text(isEnglish ? 'Select AP Account' : 'เลือกบัญชีเจ้าหนี้'),
          content: SizedBox(
            width: 520, height: 400,
            child: Column(children: [
              TextField(
                controller: searchCtrl, autofocus: true,
                decoration: InputDecoration(
                  hintText: isEnglish ? 'Search account code / name' : 'ค้นหา รหัส / ชื่อบัญชี',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onChanged: doFilter,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _controlAccounts.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? Center(child: Text(isEnglish ? 'No data found' : 'ไม่พบข้อมูล'))
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
                                  Expanded(child: Text(acctName(a))),
                                ]),
                                onTap: () {
                                  setState(() {
                                    _apAccountId       = a.id;
                                    _apAccountCode     = a.accountCode;
                                    _apAccountNameThai = a.accountNameThai;
                                    _apAccountNameEng  = a.accountNameEng;
                                  });
                                  Navigator.of(ctx).pop();
                                },
                              );
                            },
                          ),
              ),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Close' : 'ปิด'))],
        );
      }),
    );
    searchCtrl.dispose();
  }

  Future<void> _pickPaymentMethod() async {
    final isEnglish = _isEnglish;
    final method = await showDialog<CmPaymentMethod>(
      context: context,
      builder: (ctx) => Dialog(child: SizedBox(
        width: 500, height: 400,
        child: Column(children: [
          AppBar(
            title: Text(isEnglish ? 'Select Payment Method' : 'เลือกช่องทางการชำระเงิน'),
            backgroundColor: Colors.blue[700], foregroundColor: Colors.white,
            automaticallyImplyLeading: false,
            actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))],
          ),
          Expanded(child: CmPaymentMethodListWidget(
            enableAddButton: false, enableEditButton: false, enableViewButton: false, enableDeleteButton: false,
            enableCardSelect: false,
            onAdd: () {}, onEdit: (_) {}, onView: (_) {}, onDelete: (_) {},
            onCallback: (m) => Navigator.pop(ctx, m),
          )),
        ]),
      )),
    );
    if (method != null) {
      setState(() {
        _paymentMethodId = method.id;
        _paymentMethodCode = method.methodCode;
        _paymentMethodNameThai = method.methodNameTh;
        _paymentMethodNameEng = method.methodNameEn;
      });
    }
  }

  // ─── ตัวช่วยแสดงผล ─────────────────────────────────────────────────────────
  static final _money = NumberFormat('#,##0.00');
  static final _dateFmt = DateFormat('dd/MM/yyyy');
  String _m(double v) => _money.format(v);
  String _dt(DateTime? d) => d == null ? '' : _dateFmt.format(d);
  bool _sameInt(TextEditingController c, int v) => int.tryParse(c.text.trim()) == v;

  String _groupLabel(bool e) {
    if (_vendorGroupId == null) return '';
    final name = e && (_vendorGroupNameEng ?? '').isNotEmpty ? _vendorGroupNameEng! : (_vendorGroupName ?? '');
    return '${_vendorGroupCode ?? ''} $name'.trim();
  }

  String _bizTypeLabel(bool e) {
    if (_businessTypeId == null) return '';
    final bt = _businessTypes.where((b) => b.id == _businessTypeId).firstOrNull;
    final name = e && (bt?.businessTypeNameEng.isNotEmpty ?? false)
        ? bt!.businessTypeNameEng
        : (e && (_businessTypeNameEng ?? '').isNotEmpty ? _businessTypeNameEng! : (_businessTypeNameThai ?? ''));
    return '${_businessTypeCode ?? ''} $name'.trim();
  }

  String _currencyLabel(bool e) {
    if (_selectedCurrencyCode == null) return '';
    final c = _currencies.where((c) => c.currencyCode == _selectedCurrencyCode).firstOrNull;
    final name = c == null ? (_selectedCurrencyNameThai ?? '') : (e && c.currencyNameEng.isNotEmpty ? c.currencyNameEng : c.currencyNameThai);
    return name.isEmpty ? _selectedCurrencyCode! : '$_selectedCurrencyCode $name';
  }

  String _payMethodLabel(bool e) => _paymentMethodId == null
      ? ''
      : '${_paymentMethodCode ?? ''} ${e && (_paymentMethodNameEng ?? '').isNotEmpty ? _paymentMethodNameEng : (_paymentMethodNameThai ?? '')}'.trim();

  // The persisted vendor record only stores the Thai AP account name — resolve
  // the bilingual name live against the loaded control account list when possible.
  String _resolveApAccountName(bool isEnglish) {
    if (_apAccountId != null) {
      final a = _controlAccounts.where((a) => a.id == _apAccountId).firstOrNull;
      if (a != null) return isEnglish && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai;
    }
    return isEnglish && (_apAccountNameEng ?? '').isNotEmpty ? _apAccountNameEng! : (_apAccountNameThai ?? '');
  }

  // ─── ช่องรหัสผู้ขาย (ออกอัตโนมัติ / กรอกเอง) ───────────────────────────────────
  Widget _codeField() {
    final e = _isEnglish;
    final isAdd = widget.mode == Mode.add;
    if (isAdd && _effectiveAutoNumbering && !_autoCodeOverridden) {
      return InputDecorator(
        decoration: kDec(e ? 'Vendor code' : 'รหัสผู้ขาย', auto: true),
        child: Row(children: [
          Icon(Icons.auto_awesome, color: kInk, size: 15),
          const SizedBox(width: 6),
          Expanded(
            child: Text(e ? 'Auto-generated on save' : 'ออกรหัสอัตโนมัติเมื่อบันทึก',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: ImKit.font, color: kInk, fontStyle: FontStyle.italic)),
          ),
          InkWell(
            onTap: () => setState(() => _autoCodeOverridden = true),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(e ? 'Enter manually' : 'กรอกเอง', style: const TextStyle(fontSize: 12, color: ImKit.ink2, decoration: TextDecoration.underline)),
            ),
          ),
        ]),
      );
    }
    if (isAdd && _effectiveAutoNumbering && _autoCodeOverridden) {
      return Row(children: [
        Expanded(child: kTxt(e ? 'Vendor code *' : 'รหัสผู้ขาย *', _codeCtrl, cap: TextCapitalization.characters)),
        IconButton(
          icon: Icon(Icons.auto_awesome, color: kInk, size: 18),
          tooltip: e ? 'Use auto-generated code' : 'กลับไปใช้รหัสอัตโนมัติ',
          visualDensity: VisualDensity.compact,
          onPressed: () => setState(() {
            _autoCodeOverridden = false;
            _codeCtrl.clear();
          }),
        ),
      ]);
    }
    return kTxt(e ? 'Vendor code *' : 'รหัสผู้ขาย *', _codeCtrl, editable: isAdd, cap: TextCapitalization.characters);
  }

  // ─── ส่วนที่ 1: ข้อมูลผู้ขาย (4 กลุ่มสี) ────────────────────────────────────────
  Widget _mainCard() {
    final e = _isEnglish;
    final g = _groupObj;
    final termFromGroup = g != null && _sameInt(_creditMonthsCtrl, g.creditTermMonths) && _sameInt(_creditDaysCtrl, g.creditTermDays);
    final curFromGroup = g != null && g.currencyCode.isNotEmpty && g.currencyCode == _selectedCurrencyCode;
    final branchText = taxBranchLabel(normalizeTaxBranch(_taxBranchCtrl.text), e);
    return kCard(
      title: e ? 'Vendor details' : 'ข้อมูลผู้ขาย',
      trailing: kLegend(),
      child: kGroups([
        kGroup(1, e ? 'Main' : 'ข้อมูลหลัก', ImKit.gDoc, [
          kRow([_codeField(), kTxt(e ? 'Old vendor code' : 'รหัสเดิม', _oldCodeCtrl)]),
          kTxt(e ? 'Vendor name (TH) *' : 'ชื่อผู้ขาย (ไทย) *', _nameTHCtrl),
          kTxt(e ? 'Vendor name (EN)' : 'ชื่อผู้ขาย (อังกฤษ)', _nameENCtrl),
          kRow([
            kTxt(e ? 'Tax ID' : 'เลขผู้เสียภาษี', _taxIdCtrl, digitsOnly: true),
            kTxt(e ? 'Tax branch (5 digits)' : 'สาขา (5 หลัก)', _taxBranchCtrl, digitsOnly: true),
          ]),
          if (branchText.isNotEmpty) kNote(branchText),
          kRow([
            kDd<String?>(
              e ? 'Vendor type' : 'ประเภทผู้ขาย',
              _vendorType,
              [
                DropdownMenuItem(value: null, child: Text(e ? '— Not specified —' : '— ไม่ระบุ —')),
                DropdownMenuItem(value: 'individual', child: Text(e ? 'Individual' : 'บุคคลธรรมดา')),
                DropdownMenuItem(value: 'juristic', child: Text(e ? 'Juristic person' : 'นิติบุคคล')),
              ],
              kitReadOnly ? null : (v) => setState(() => _vendorType = v),
              auto: false,
            ),
            kFk(
              label: e ? 'Business type' : 'ประเภทธุรกิจ',
              text: _bizTypeLabel(e),
              hasValue: _businessTypeId != null,
              onSearch: _pickBusinessType,
              onClear: () => setState(() {
                _businessTypeId = null; _businessTypeCode = null; _businessTypeNameThai = null; _businessTypeNameEng = null;
              }),
            ),
          ]),
        ]),
        kGroup(2, e ? 'Credit and currency' : 'เครดิตและสกุลเงิน', ImKit.gFin, [
          kFk(
            label: e ? 'Vendor group' : 'กลุ่มผู้ขาย',
            text: _groupLabel(e),
            hasValue: _vendorGroupId != null,
            onSearch: _pickVendorGroup,
            onClear: _clearGroup,
            locked: widget.mode == Mode.edit && _isCodeAutoGenerated,
            lockedTip: e ? 'Locked — code was auto-generated at creation' : 'ล็อก — รหัสถูกออกอัตโนมัติตอนสร้างข้อมูล',
          ),
          kRow([
            kTxt(e ? 'Credit term (months)' : 'เครดิต (เดือน)', _creditMonthsCtrl, digitsOnly: true, numeric: true, auto: termFromGroup),
            kTxt(e ? 'Credit term (days)' : 'เครดิต (วัน)', _creditDaysCtrl, digitsOnly: true, numeric: true, auto: termFromGroup),
          ]),
          kRow([
            kTxt(e ? 'Credit limit granted' : 'วงเงินเครดิตที่ได้รับ', _creditLimitCtrl, numeric: true),
            kFk(
              label: e ? 'Currency' : 'สกุลเงิน',
              text: _currencyLabel(e),
              hasValue: _selectedCurrencyCode != null,
              onSearch: _pickCurrency,
              onClear: () => setState(() {
                _selectedCurrencyCode = null;
                _selectedCurrencyNameThai = null;
              }),
              auto: curFromGroup,
            ),
          ]),
          if (g != null && (termFromGroup || curFromGroup))
            kNote(e
                ? 'Blue = same as group ${g.groupCode} (filled from the group when it was chosen)'
                : 'ช่องสีฟ้า = ค่าเดียวกับกลุ่ม ${g.groupCode} (ตั้งต้นจากกลุ่มตอนเลือกกลุ่ม)',
                color: ImKit.blue),
        ]),
        kGroup(3, e ? 'Purchasing and payment' : 'การซื้อและการจ่าย', ImKit.gParty, [
          kFk(
            label: e ? 'Purchase price list' : 'ตารางราคาซื้อ',
            text: '${_priceListCode ?? ''} ${_priceListName ?? ''}'.trim(),
            hasValue: _priceListId != null,
            onSearch: _pickPriceList,
            onClear: _clearPriceList,
          ),
          kFk(
            label: e ? 'Main payment method' : 'ประเภทการชำระหลัก',
            text: _payMethodLabel(e),
            hasValue: _paymentMethodId != null,
            onSearch: _pickPaymentMethod,
            onClear: () => setState(() {
              _paymentMethodId = null; _paymentMethodCode = null; _paymentMethodNameThai = null; _paymentMethodNameEng = null;
            }),
          ),
        ]),
        kGroup(4, e ? 'More' : 'เพิ่มเติม', ImKit.gMore, [
          kChecks([
            kCk(e ? 'Active' : 'ใช้งาน', _isActive, kitReadOnly ? null : (v) => setState(() => _isActive = v)),
          ]),
          kTxt(e ? 'Remark' : 'หมายเหตุ', _remarkCtrl),
        ]),
      ]),
    );
  }

  // ─── ส่วนที่ 2: ที่อยู่ ผู้ติดต่อ บัญชีธนาคาร ────────────────────────────────────
  String _addrTypeLabel(String t, bool e) => (e
          ? const {'billing': 'Billing', 'shipping': 'Shipping', 'billing note': 'Billing note', 'payment': 'Payment'}
          : const {'billing': 'ใบแจ้งหนี้', 'shipping': 'จัดส่ง', 'billing note': 'วางบิล', 'payment': 'ชำระเงิน'})[t] ??
      t;

  String _addrText(ApVendorAddress a) => [
        a.addressNo,
        a.addressBuildingVillage,
        if (a.addressAlley?.isNotEmpty ?? false) (_isEnglish ? 'Soi ${a.addressAlley}' : 'ซ.${a.addressAlley}'),
        if (a.addressRoad?.isNotEmpty ?? false) (_isEnglish ? '${a.addressRoad} Rd.' : 'ถ.${a.addressRoad}'),
        a.addressSubDistrict,
        a.addressDistrict,
        a.addressProvince,
        a.addressZipCode,
      ].where((s) => s != null && s.isNotEmpty).join(' ');

  Widget _delBtn(VoidCallback onTap) => kIconBtn(Icons.delete_outline, _isEnglish ? 'Remove' : 'ลบ', onTap, color: ImKit.red);
  Widget _defaultMark(bool v) => v ? ImKit.chip(_isEnglish ? 'Default' : 'หลัก', ImKit.okSoft, ImKit.ok) : kCell('');

  Future<void> _addAddress() async {
    final primary = _addresses.where((a) => a.isDefault).firstOrNull;
    final r = await showAddressDialog(context, null, false, primaryAddress: primary);
    if (r != null) setState(() => _addresses.add(r));
  }

  Future<void> _openAddress(int i) async {
    final primary = _addresses.where((a) => a.isDefault).firstOrNull;
    final r = await showAddressDialog(context, _addresses[i], kitReadOnly, primaryAddress: primary);
    if (r != null && !kitReadOnly) setState(() => _addresses[i] = r);
  }

  Future<void> _addContact() async {
    final r = await showContactDialog(context, null, false);
    if (r != null) setState(() => _contacts.add(r));
  }

  Future<void> _openContact(int i) async {
    final r = await showContactDialog(context, _contacts[i], kitReadOnly);
    if (r != null && !kitReadOnly) setState(() => _contacts[i] = r);
  }

  Future<void> _addBank() async {
    final r = await showBankDialog(context, null, false);
    if (r != null) setState(() => _bankAccounts.add(r));
  }

  Future<void> _openBank(int i) async {
    final r = await showBankDialog(context, _bankAccounts[i], kitReadOnly);
    if (r != null && !kitReadOnly) setState(() => _bankAccounts[i] = r);
  }

  Widget _addressCard() {
    final e = _isEnglish;
    final ro = kitReadOnly;
    final rows = <List<Widget>>[];
    final taps = <VoidCallback?>[];
    for (var i = 0; i < _addresses.length; i++) {
      final a = _addresses[i];
      rows.add([
        kCell(_addrTypeLabel(a.addressType, e), color: ImKit.ink2),
        kCell(_addrText(a)),
        kCell(''),
        _defaultMark(a.isDefault),
        ro ? const SizedBox.shrink() : _delBtn(() => setState(() => _addresses.removeAt(i))),
      ]);
      taps.add(() => _openAddress(i));
    }
    for (var i = 0; i < _contacts.length; i++) {
      final c = _contacts[i];
      rows.add([
        kCell(e ? 'Contact' : 'ผู้ติดต่อ', color: ImKit.ink2),
        kCell([c.contactName, if (c.position?.isNotEmpty ?? false) '(${c.position})'].join(' ')),
        kCell([c.phone, c.mobile, c.email].where((s) => s != null && s.isNotEmpty).join(' · ')),
        _defaultMark(c.isDefault),
        ro ? const SizedBox.shrink() : _delBtn(() => setState(() => _contacts.removeAt(i))),
      ]);
      taps.add(() => _openContact(i));
    }
    return kCard(
      title: e ? 'Addresses (${_addresses.length}) and contacts (${_contacts.length})' : 'ที่อยู่ (${_addresses.length}) และผู้ติดต่อ (${_contacts.length})',
      count: e ? 'Click a row to open' : 'กดแถวเพื่อเปิดดู/แก้ไข',
      trailing: ro
          ? null
          : Wrap(spacing: 6, children: [
              kGhost(e ? 'Address' : 'ที่อยู่', Icons.add, _addAddress),
              kGhost(e ? 'Contact' : 'ผู้ติดต่อ', Icons.add, _addContact),
            ]),
      padding: EdgeInsets.zero,
      child: kTable(
        [
          KCol(e ? 'Type' : 'ประเภท', 2),
          KCol(e ? 'Address / name' : 'ที่อยู่ / ชื่อ', 7),
          KCol(e ? 'Contact' : 'ติดต่อ', 4),
          KCol(e ? 'Default' : 'ค่าหลัก', 2),
          const KCol('', 1),
        ],
        rows,
        onTap: taps,
        minWidth: 720,
        empty: e ? 'No addresses or contacts yet' : 'ยังไม่มีที่อยู่และผู้ติดต่อ',
      ),
    );
  }

  Widget _bankCard() {
    final e = _isEnglish;
    final ro = kitReadOnly;
    return kCard(
      title: e ? 'Bank accounts' : 'บัญชีธนาคาร',
      count: e
          ? '${_bankAccounts.length} · the default account receives transfers in payment runs'
          : '${_bankAccounts.length} บัญชี · บัญชีหลักใช้เป็นบัญชีรับโอนในใบสั่งจ่าย',
      trailing: ro ? null : kGhost(e ? 'Bank account' : 'บัญชีธนาคาร', Icons.add, _addBank),
      padding: EdgeInsets.zero,
      child: kTable(
        [
          KCol(e ? 'Bank' : 'ธนาคาร', 4),
          KCol(e ? 'Branch' : 'สาขา', 3),
          KCol(e ? 'Account no.' : 'เลขที่บัญชี', 3),
          KCol(e ? 'Account name' : 'ชื่อบัญชี', 4),
          KCol(e ? 'Default' : 'ค่าหลัก', 2),
          const KCol('', 1),
        ],
        [
          for (var i = 0; i < _bankAccounts.length; i++)
            [
              kCell(_bankAccounts[i].bankName ?? ''),
              kCell(_bankAccounts[i].branchName ?? ''),
              kCell(_bankAccounts[i].accountNumber ?? '', mono: true),
              kCell(_bankAccounts[i].accountName ?? ''),
              _defaultMark(_bankAccounts[i].isDefault),
              ro ? const SizedBox.shrink() : _delBtn(() => setState(() => _bankAccounts.removeAt(i))),
            ],
        ],
        onTap: [for (var i = 0; i < _bankAccounts.length; i++) () => _openBank(i)],
        minWidth: 720,
        empty: e ? 'No bank accounts yet' : 'ยังไม่มีบัญชีธนาคาร',
      ),
    );
  }

  // ─── ส่วนที่ 3: บัญชีเจ้าหนี้ (ผู้ขาย > กลุ่ม > ประเภทเอกสาร) ──────────────────────
  Widget _accountCard() {
    final e = _isEnglish;
    final s = _summary;
    final g = _groupObj;
    final groupCode = g?.groupCode ?? s?.groupCode;
    String? groupAcc;
    if (g != null && g.apAccountId != null) {
      final acc = _controlAccounts.where((a) => a.id == g.apAccountId).firstOrNull;
      final nm = acc == null ? (g.apAccountNameThai ?? '') : (e && acc.accountNameEng.isNotEmpty ? acc.accountNameEng : acc.accountNameThai);
      groupAcc = '${g.apAccountCode ?? acc?.accountCode ?? ''} $nm'.trim();
    } else if (g == null && s?.groupAccount != null && _vendorGroupId != null) {
      groupAcc = '${s!.groupAccount!.code} ${s.groupAccount!.name(e)}';
    }
    final hasVendor = _apAccountId != null;
    final hasGroup = _vendorGroupId != null && groupAcc != null;
    Widget status(bool used, bool skipped, String? usedText) => used
        ? ImKit.chip(usedText ?? (e ? 'Used' : 'ใช้บัญชีนี้'), ImKit.okSoft, ImKit.ok)
        : skipped
            ? ImKit.chip(e ? 'Not used' : 'ไม่ใช้', ImKit.ro, ImKit.ink2)
            : ImKit.chip(e ? 'Empty, skip' : 'ว่าง ข้าม', ImKit.ro, ImKit.ink3);
    final docTypes = s?.docTypeAccounts ?? const <ApDocTypeAccount>[];
    final docText = docTypes.isEmpty
        ? (e ? 'As set per AP document type (AP GL setup)' : 'ตามที่ตั้งไว้แต่ละประเภทเอกสาร (ตั้งค่าบัญชี GL ของ AP)')
        : docTypes.map((d) => '${d.docCode} ${d.account?.code ?? '—'}').join(' · ');
    return kCard(
      title: e ? 'Payable account' : 'รหัสบัญชีเจ้าหนี้',
      count: e ? 'Order used: vendor › group › document type' : 'ลำดับที่ใช้: ผู้ขาย › กลุ่มผู้ขาย › ประเภทเอกสาร',
      trailing: kGhost(e ? 'AP GL setup' : 'ตั้งค่าบัญชี GL', Icons.open_in_new,
          () => ImKit.openMenu(context, 'ApGlAccountSetupScreen', 'ตั้งค่าบัญชี GL ของ AP', 'AP GL Account Setup', e)),
      padding: EdgeInsets.zero,
      child: kTable(
        [KCol(e ? 'Level' : 'ระดับ', 3), KCol(e ? 'Account' : 'บัญชี', 8), KCol(e ? 'Status' : 'สถานะ', 3)],
        [
          [
            kCell(e ? 'This vendor' : 'ผู้ขายนี้', bold: true),
            SizedBox(
              width: double.infinity,
              child: kFk(
                label: '',
                text: '${_apAccountCode ?? ''} ${_resolveApAccountName(e)}'.trim(),
                hasValue: hasVendor,
                onSearch: _pickApAccount,
                onClear: () => setState(() {
                  _apAccountId = null; _apAccountCode = null; _apAccountNameThai = null; _apAccountNameEng = null;
                }),
              ),
            ),
            status(hasVendor, false, null),
          ],
          [
            kCell(groupCode == null ? (e ? 'Group' : 'กลุ่ม') : '${e ? 'Group' : 'กลุ่ม'} $groupCode', bold: true),
            kCell(_vendorGroupId == null ? (e ? '— No group —' : '— ไม่มีกลุ่ม —') : (groupAcc ?? (e ? '— Not set —' : '— ไม่ได้ตั้ง —'))),
            status(!hasVendor && hasGroup, hasVendor && hasGroup, null),
          ],
          [
            kCell(e ? 'Document type' : 'ประเภทเอกสาร', bold: true),
            Text(docText, style: const TextStyle(fontSize: 12.5), maxLines: 2, overflow: TextOverflow.ellipsis),
            status(!hasVendor && !hasGroup, hasVendor || hasGroup, e ? 'Used' : 'ใช้ระดับนี้'),
          ],
        ],
        minWidth: 640,
        rowMinHeight: 48,
      ),
    );
  }

  // ─── ส่วนที่ 4: ยอดค้างจ่ายตามอายุหนี้ + เอกสารค้างเก่าสุด (อ่านอย่างเดียว) ──────────────
  void _openAging() => ImKit.openMenu(context, 'ApAgingReportScreen', 'รายงานอายุเจ้าหนี้', 'AP Aging Report', _isEnglish);

  Widget _agingCard() {
    final e = _isEnglish;
    final s = _summary;
    Widget amt(double v, {bool warn = false}) =>
        kCell(_m(v), mono: true, color: warn && v > 0.005 ? ImKit.red : null, bold: warn && v > 0.005);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      kCard(
        title: e ? 'Payables by age' : 'ยอดค้างจ่ายตามอายุหนี้',
        count: e ? 'Read-only · as of today · bills and debit notes' : 'อ่านอย่างเดียว · ณ วันนี้ · ใบตั้งหนี้และใบเพิ่มหนี้',
        trailing: kGhost(e ? 'AP aging report' : 'รายงานอายุเจ้าหนี้', Icons.open_in_new, _openAging),
        padding: EdgeInsets.zero,
        child: s == null
            ? Padding(
                padding: const EdgeInsets.all(14),
                child: _summaryLoading
                    ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                    : kNote(e ? 'Could not load outstanding balances' : 'โหลดยอดค้างไม่ได้'),
              )
            : kTable(
                [
                  KCol(e ? 'Not due' : 'ยังไม่ครบกำหนด', 3, num: true),
                  KCol(e ? '1–30 days' : '1–30 วัน', 3, num: true),
                  KCol(e ? '31–60 days' : '31–60 วัน', 3, num: true),
                  KCol(e ? '61–90 days' : '61–90 วัน', 3, num: true),
                  KCol(e ? 'Over 90 days' : 'เกิน 90 วัน', 3, num: true),
                  KCol(e ? 'Total' : 'รวม', 3, num: true),
                ],
                [
                  [
                    amt(s.notDue),
                    amt(s.d1_30, warn: true),
                    amt(s.d31_60, warn: true),
                    amt(s.d61_90, warn: true),
                    amt(s.over90, warn: true),
                    kCell(_m(s.agingTotal), mono: true, bold: true),
                  ],
                ],
                minWidth: 640,
              ),
      ),
      if (s != null) ...[
        const SizedBox(height: 12),
        kCard(
          title: e ? 'Oldest open documents' : 'เอกสารค้างจ่ายเก่าสุด',
          count: e ? '${s.oldestDocs.length} of ${s.openCount}' : '${s.oldestDocs.length} จาก ${s.openCount} ใบ',
          padding: EdgeInsets.zero,
          child: kTable(
            [
              KCol(e ? 'Document no.' : 'เลขที่เอกสาร', 4),
              KCol(e ? 'Date' : 'วันที่', 3),
              KCol(e ? 'Due date' : 'ครบกำหนด', 3),
              KCol(e ? 'Days overdue' : 'เกินกำหนด (วัน)', 2, num: true),
              KCol(e ? 'Outstanding' : 'คงค้าง', 3, num: true),
            ],
            [
              for (final d in s.oldestDocs)
                [
                  kCell(d.docNo, mono: true),
                  kCell(_dt(d.docDate), mono: true),
                  kCell(_dt(d.dueDate), mono: true, color: d.daysOverdue > 0 ? ImKit.red : null),
                  kCell(d.daysOverdue > 0 ? '${d.daysOverdue}' : '—', mono: true, color: d.daysOverdue > 0 ? ImKit.red : null),
                  kCell(_m(d.balance), mono: true),
                ],
            ],
            minWidth: 640,
            empty: e ? 'No open documents' : 'ไม่มีเอกสารค้างจ่าย',
          ),
        ),
      ],
    ]);
  }

  // ─── ตัวเลขสรุป ──────────────────────────────────────────────────────────────
  Widget _kpis() {
    final e = _isEnglish;
    final s = _summary;
    if (s == null) return kKpis(const [], loading: _summaryLoading);
    final last = s.lastBill;
    final pay = s.lastPayment;
    return kKpis([
      ImKpi(
        e ? 'Payable' : 'ยอดค้างจ่าย',
        _m(s.outstanding),
        [
          e ? '${s.openCount} doc(s) · base currency' : '${s.openCount} ใบ · สกุลหลัก',
          if (s.creditLimit > 0) (e ? 'limit ${_m(s.creditLimit)}' : 'วงเงิน ${_m(s.creditLimit)}'),
        ].join(' · '),
      ),
      ImKpi(
        e ? 'Overdue' : 'เกินกำหนด',
        _m(s.overdue),
        s.overdueCount == 0
            ? (e ? 'none' : 'ไม่มี')
            : (e ? '${s.overdueCount} doc(s) · oldest ${s.maxDaysOverdue} days' : '${s.overdueCount} ใบ · นานสุด ${s.maxDaysOverdue} วัน'),
        warn: s.overdue > 0.005,
        onTap: _openAging,
      ),
      ImKpi(
        e ? 'Deposit balance' : 'เงินมัดจำคงเหลือ',
        _m(s.deposit),
        s.depositCount == 0
            ? (e ? 'no open deposit' : 'ไม่มีมัดจำค้าง')
            : (e ? '${s.depositCount} deposit(s) paid, not yet deducted' : 'จ่ายมัดจำแล้ว ${s.depositCount} ใบ ยังไม่ได้หัก'),
      ),
      ImKpi(
        e ? 'Last bill / payment' : 'ตั้งหนี้/จ่ายชำระล่าสุด',
        last == null ? '—' : _dt(last.docDate),
        [
          if (last != null) last.docNo,
          pay == null ? (e ? 'no payment yet' : 'ยังไม่มีจ่ายชำระ') : '${e ? 'paid' : 'จ่ายชำระ'} ${_dt(pay.docDate)}',
        ].join(' · '),
      ),
    ]);
  }

  // ─── หน้า ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final e = isEnglish;

    if (widget.isPlaceholder || widget.mode == Mode.none) {
      return kPlaceholder(Icons.storefront_outlined,
          e ? 'Select a vendor on the left, or press "Add vendor"' : 'เลือกผู้ขายจากรายการด้านซ้าย หรือกด "เพิ่มผู้ขาย"');
    }
    if (_isLoading && _controlAccounts.isEmpty) return const Center(child: CircularProgressIndicator());

    final ro = kitReadOnly;
    final isAdd = widget.mode == Mode.add;
    final saved = !isAdd && widget.selected?.id != null;
    final name = _nameTHCtrl.text.trim().isEmpty
        ? ''
        : (e && _nameENCtrl.text.trim().isNotEmpty ? _nameENCtrl.text.trim() : _nameTHCtrl.text.trim());
    final title = isAdd
        ? (_isCopy
            ? (e ? 'New vendor (copy of ${widget.copyFrom!.vendorCode})' : 'ผู้ขายใหม่ (สำเนาจาก ${widget.copyFrom!.vendorCode})')
            : (e ? 'New vendor' : 'ผู้ขายใหม่'))
        : name;
    final branch = taxBranchLabel(normalizeTaxBranch(_taxBranchCtrl.text), e);
    final typeLabel = switch (_vendorType) {
      'individual' => e ? 'Individual' : 'บุคคลธรรมดา',
      'juristic' => e ? 'Juristic person' : 'นิติบุคคล',
      _ => null,
    };

    final header = kHeaderBar(
      code: isAdd ? null : widget.selected?.vendorCode,
      title: title,
      badges: [
        if (!isAdd) ImKit.activeChip(_isActive, e),
        if (_vendorGroupCode != null) ImKit.chip(_groupLabel(e), ImKit.blueSoft, ImKit.blue),
        if (typeLabel != null) ImKit.chip(typeLabel, ImKit.ro, ImKit.ink2),
        if (branch.isNotEmpty || _selectedCurrencyCode != null)
          Text([if (branch.isNotEmpty) branch, if (_selectedCurrencyCode != null) _selectedCurrencyCode!].join(' · '),
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        if (!ro) kEditingBadge(),
      ],
      busy: _isSaving,
      acts: kStdActs(
        saving: _isSaving,
        onEdit: widget.onEdit,
        onDelete: widget.onDelete,
        onClose: widget.onCancel,
        onCancel: widget.onCancel,
        onSave: _save,
        extra: [
          if (widget.onCopy != null) DocBarAction(e ? 'Copy as new' : 'สำเนาเป็นผู้ขายใหม่', widget.onCopy, fg: kInk),
        ],
      ),
    );

    return kPage(
      header: header,
      top: saved ? _kpis() : null,
      sections: [
        (0, e ? 'Main' : 'ข้อมูลหลัก', _mainCard()),
        (1, e ? 'Addresses and contacts' : 'ที่อยู่และผู้ติดต่อ', _addressCard()),
        (2, e ? 'Bank accounts' : 'บัญชีธนาคาร', _bankCard()),
        (3, e ? 'Payable account' : 'บัญชีเจ้าหนี้', _accountCard()),
        if (saved) (4, e ? 'Outstanding' : 'ยอดค้าง', _agingCard()),
      ],
    );
  }
}
