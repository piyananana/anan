import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/anan_module.dart';
import '../../cd/models/zipcode.dart';
import '../../cd/models/business_type.dart';
import '../../cd/services/business_type_service.dart';
import '../../cd/widgets/zipcode_list_widget.dart';
import '../models/ar_customer.dart';
import '../models/ar_customer_group.dart';
import 'ar_customer_group_list_widget.dart';

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
    BuildContext context, ArCustomerAddress? existing, bool readOnly) async {
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

  Widget buildField(String label, TextEditingController ctrl) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          readOnly: readOnly,
          controller: ctrl,
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder()),
        ),
      );

  return showDialog<ArCustomerAddress>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateDialog) => AlertDialog(
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
                            value: 'billing',
                            child: Text('ที่อยู่ใบแจ้งหนี้')),
                        DropdownMenuItem(
                            value: 'shipping', child: Text('ที่อยู่จัดส่ง')),
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
                buildField('บ้านเลขที่ / ห้อง', noCtrl),
                buildField('อาคาร / หมู่บ้าน', buildingCtrl),
                buildField('ซอย', alleyCtrl),
                buildField('ถนน', roadCtrl),
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
                          buildField('แขวง / ตำบล', subDistCtrl),
                          buildField('อำเภอ / เขต', distCtrl),
                          buildField('จังหวัด', provCtrl),
                          buildField('รหัสไปรษณีย์', zipCtrl),
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
      ),
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
    BuildContext context, ArCustomerBankAccount? existing, bool readOnly) async {
  final bankCtrl = TextEditingController(text: existing?.bankName ?? '');
  final branchCtrl = TextEditingController(text: existing?.branchName ?? '');
  final accNumCtrl =
      TextEditingController(text: existing?.accountNumber ?? '');
  final accNameCtrl =
      TextEditingController(text: existing?.accountName ?? '');
  final accTypeNotifier =
      ValueNotifier<String>(existing?.accountType ?? 'current');
  final isDefaultNotifier = ValueNotifier<bool>(existing?.isDefault ?? false);

  return showDialog<ArCustomerBankAccount>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(readOnly
          ? 'ดูบัญชีธนาคาร'
          : existing == null
              ? 'เพิ่มบัญชีธนาคาร'
              : 'แก้ไขบัญชีธนาคาร'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                readOnly: readOnly,
                controller: bankCtrl,
                decoration: const InputDecoration(
                    labelText: 'ชื่อธนาคาร', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                readOnly: readOnly,
                controller: branchCtrl,
                decoration: const InputDecoration(
                    labelText: 'สาขา', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                readOnly: readOnly,
                controller: accNumCtrl,
                decoration: const InputDecoration(
                    labelText: 'เลขที่บัญชี', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                readOnly: readOnly,
                controller: accNameCtrl,
                decoration: const InputDecoration(
                    labelText: 'ชื่อบัญชี', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder<String>(
                valueListenable: accTypeNotifier,
                builder: (_, v, __) => DropdownButtonFormField<String>(
                  value: v,
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
                          if (val != null) accTypeNotifier.value = val;
                        },
                ),
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder<bool>(
                valueListenable: isDefaultNotifier,
                builder: (_, v, __) => SwitchListTile(
                  title: const Text('บัญชีหลัก'),
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
              Navigator.of(ctx).pop(ArCustomerBankAccount(
                id: existing?.id,
                customerId: existing?.customerId,
                bankName: bankCtrl.text.isEmpty ? null : bankCtrl.text,
                branchName:
                    branchCtrl.text.isEmpty ? null : branchCtrl.text,
                accountNumber:
                    accNumCtrl.text.isEmpty ? null : accNumCtrl.text,
                accountName:
                    accNameCtrl.text.isEmpty ? null : accNameCtrl.text,
                accountType: accTypeNotifier.value,
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
  late TextEditingController _creditDaysCtrl;
  late TextEditingController _creditLimitCtrl;
  late TextEditingController _discountPercentCtrl;
  late TextEditingController _currencyCtrl;
  late TextEditingController _remarkCtrl;

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

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initFromSelected(widget.selected);
    _loadBusinessTypes();
  }

  Future<void> _loadBusinessTypes() async {
    try {
      final list = await Provider.of<BusinessTypeService>(context, listen: false)
          .fetchActiveRows();
      if (mounted) setState(() => _businessTypes = list);
    } catch (_) {}
  }

  void _initFromSelected(ArCustomer? c) {
    _codeCtrl        = TextEditingController(text: c?.customerCode ?? '');
    _nameThCtrl      = TextEditingController(text: c?.customerNameTh ?? '');
    _nameEnCtrl      = TextEditingController(text: c?.customerNameEn ?? '');
    _taxIdCtrl       = TextEditingController(text: c?.taxId ?? '');
    _creditDaysCtrl  = TextEditingController(text: (c?.creditDays ?? 30).toString());
    _creditLimitCtrl = TextEditingController(text: (c?.creditLimit ?? 0).toStringAsFixed(2));
    _discountPercentCtrl = TextEditingController(text: (c?.discountPercent ?? 0).toStringAsFixed(2));
    _currencyCtrl    = TextEditingController(text: c?.currencyCode ?? 'THB');
    _remarkCtrl      = TextEditingController(text: c?.remark ?? '');
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
      _codeCtrl, _nameThCtrl, _nameEnCtrl, _taxIdCtrl,
      _creditDaysCtrl, _creditLimitCtrl, _discountPercentCtrl,
      _currencyCtrl, _remarkCtrl,
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
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                      '${bt.businessTypeCode}  ${bt.businessTypeNameThai}'),
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final customer = ArCustomer(
        id: widget.selected?.id,
        customerCode: _codeCtrl.text.trim(),
        customerNameTh: _nameThCtrl.text.trim(),
        customerNameEn:
            _nameEnCtrl.text.trim().isEmpty ? null : _nameEnCtrl.text.trim(),
        taxId: _taxIdCtrl.text.trim().isEmpty ? null : _taxIdCtrl.text.trim(),
        businessTypeId: _businessTypeId,
        customerGroupId: _customerGroupId,
        creditDays: int.tryParse(_creditDaysCtrl.text) ?? 30,
        creditLimit: double.tryParse(_creditLimitCtrl.text) ?? 0,
        discountPercent: double.tryParse(_discountPercentCtrl.text) ?? 0,
        currencyCode: _currencyCtrl.text.trim().isEmpty
            ? 'THB'
            : _currencyCtrl.text.trim().toUpperCase(),
        isActive: _isActive,
        remark: _remarkCtrl.text.trim().isEmpty ? null : _remarkCtrl.text.trim(),
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

  // ---- Section: ข้อมูลทั่วไป ----
  Widget _buildGeneralSection(bool readOnly) {
    return _Section(
      title: 'ข้อมูลทั่วไป',
      children: [
        _buildField('รหัสลูกหนี้ *', _codeCtrl,
            readOnly: readOnly || widget.mode == Mode.edit, required: true),
        _buildField('ชื่อลูกหนี้ (ไทย) *', _nameThCtrl,
            readOnly: readOnly, required: true),
        _buildField('ชื่อลูกหนี้ (อังกฤษ)', _nameEnCtrl, readOnly: readOnly),
        _buildField('เลขประจำตัวผู้เสียภาษี', _taxIdCtrl, readOnly: readOnly),

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
                      : Text(
                          '$_businessTypeCode — $_businessTypeNameThai',
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
                      : Text(
                          '$_customerGroupCode — $_customerGroupName',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
                if (!readOnly) ...[
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.blue),
                    tooltip: 'ค้นหากลุ่มลูกค้า',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => ArCustomerGroupListWidget.search(
                      context,
                      onSelected: _onGroupSelected,
                    ),
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
              child: _buildField('สกุลเงิน', _currencyCtrl,
                  readOnly: readOnly),
            ),
          ],
        ),
        SwitchListTile(
          title: const Text('ใช้งาน'),
          value: _isActive,
          onChanged: readOnly ? null : (v) => setState(() => _isActive = v),
        ),
        _buildField('หมายเหตุ', _remarkCtrl, readOnly: readOnly),
      ],
    );
  }

  // ---- Section: ที่อยู่ ----
  Widget _buildAddressSection(bool readOnly) {
    return _Section(
      title: 'ที่อยู่ (${_addresses.length})',
      trailing: readOnly
          ? null
          : IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              tooltip: 'เพิ่มที่อยู่',
              onPressed: () async {
                final result = await showAddressDialog(context, null, false);
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
                    final result =
                        await showAddressDialog(context, addr, readOnly);
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

  // ---- Section: บัญชีธนาคาร ----
  Widget _buildBankSection(bool readOnly) {
    return _Section(
      title: 'บัญชีธนาคาร (${_bankAccounts.length})',
      trailing: readOnly
          ? null
          : IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              tooltip: 'เพิ่มบัญชีธนาคาร',
              onPressed: () async {
                final result = await showBankDialog(context, null, false);
                if (result != null)
                  setState(() => _bankAccounts.add(result));
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
                  _buildAddressSection(readOnly),
                  _buildContactSection(readOnly),
                  _buildBankSection(readOnly),
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
