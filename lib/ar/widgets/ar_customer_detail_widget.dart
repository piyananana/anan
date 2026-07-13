import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../cd/models/cd_zipcode.dart';
import '../../cd/models/cd_business_type.dart';
import '../../cd/services/cd_business_type_service.dart';
import '../../cd/widgets/cd_zipcode_list_widget.dart';
import '../models/ar_customer.dart';
import '../../cd/models/cd_currency.dart';
import '../../cd/services/cd_currency_service.dart';
import '../models/ar_customer_group.dart';
import '../services/ar_customer_group_service.dart';
import '../services/ar_customer_running_service.dart';
import '../../cd/models/cd_bank.dart';
import '../../cd/models/cd_bank_branch.dart';
import '../../cd/services/cd_bank_branch_service.dart';
import '../../cd/widgets/cd_bank_list_widget.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../../cd/models/cd_sales_territory.dart';
import '../../cd/services/cd_sales_territory_service.dart';
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
                      isExpanded: true,
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (!readOnly)
                      IconButton(
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
// Billing Condition Dialog
// ---------------------------------------------------------------------------
Future<ArCustomerBillingCondition?> showBillingConditionDialog(
    BuildContext context, ArCustomerBillingCondition? existing, bool readOnly) {
  const dayNames = ['อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์'];
  const weekOptions = <int, String>{1: 'แรก', 2: 'ที่ 2', 3: 'ที่ 3', 4: 'ที่ 4', -1: 'สุดท้าย'};

  var billWithDelivery = existing?.billWithDelivery ?? false;
  var dueFromBillingDate = existing?.dueFromBillingDate ?? false;
  var dayOfMonth = List<int>.from(existing?.billingDayOfMonth ?? []);
  var dayOfWeek = List<int>.from(existing?.billingDayOfWeek ?? []);
  var weekOfMonth = List<int>.from(existing?.billingWeekOfMonth ?? []);
  final timeFromCtrl = TextEditingController(text: existing?.billingTimeFrom ?? '');
  final timeToCtrl = TextEditingController(text: existing?.billingTimeTo ?? '');
  final remarkCtrl = TextEditingController(text: existing?.remark ?? '');

  return showDialog<ArCustomerBillingCondition>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
      Widget chipGroup(String label, List<int> values, List<int> selected,
          String Function(int) labelFn) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
            ),
            child: Wrap(
              spacing: 4,
              runSpacing: 2,
              children: values.map((v) {
                final sel = selected.contains(v);
                return FilterChip(
                  label: Text(labelFn(v), style: const TextStyle(fontSize: 12)),
                  selected: sel,
                  onSelected: readOnly
                      ? null
                      : (on) => setDlg(() {
                            if (on) {
                              selected.add(v);
                            } else {
                              selected.remove(v);
                            }
                          }),
                  selectedColor: Colors.indigo.shade100,
                  checkmarkColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ),
        );
      }

      return AlertDialog(
        title: Text(readOnly
            ? 'ดูเงื่อนไขวางบิล'
            : existing == null
                ? 'เพิ่มเงื่อนไขวางบิล'
                : 'แก้ไขเงื่อนไขวางบิล'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('วางบิลพร้อมวันส่งของ (ไม่ต้องรอวันวางบิล)'),
                  value: billWithDelivery,
                  onChanged: readOnly ? null : (v) => setDlg(() => billWithDelivery = v ?? false),
                ),
                const Divider(),
                // วันที่ในเดือน
                chipGroup(
                  'วันที่ในเดือน (31 = สิ้นเดือน)',
                  [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31],
                  dayOfMonth,
                  (d) => d == 31 ? 'สิ้นเดือน' : '$d',
                ),
                // วันในสัปดาห์
                chipGroup(
                  'วันในสัปดาห์',
                  List.generate(7, (i) => i),
                  dayOfWeek,
                  (d) => dayNames[d],
                ),
                // สัปดาห์ที่
                chipGroup(
                  'สัปดาห์ที่',
                  [1, 2, 3, 4, -1],
                  weekOfMonth,
                  (w) => weekOptions[w] ?? '$w',
                ),
                // เวลา
                Row(children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10, right: 5),
                      child: TextField(
                        controller: timeFromCtrl,
                        readOnly: readOnly,
                        decoration: const InputDecoration(
                          labelText: 'เวลาตั้งแต่',
                          border: OutlineInputBorder(),
                          hintText: '09:00',
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10, left: 5),
                      child: TextField(
                        controller: timeToCtrl,
                        readOnly: readOnly,
                        decoration: const InputDecoration(
                          labelText: 'ถึงเวลา',
                          border: OutlineInputBorder(),
                          hintText: '17:00',
                        ),
                      ),
                    ),
                  ),
                ]),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('คำนวณวันครบกำหนดชำระจากวันวางบิล (แทนวันส่งของ)'),
                  value: dueFromBillingDate,
                  onChanged: readOnly ? null : (v) => setDlg(() => dueFromBillingDate = v ?? false),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextField(
                    controller: remarkCtrl,
                    readOnly: readOnly,
                    decoration: const InputDecoration(
                      labelText: 'หมายเหตุ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ยกเลิก'),
          ),
          if (!readOnly)
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(ArCustomerBillingCondition(
                id: existing?.id,
                customerId: existing?.customerId,
                sortOrder: existing?.sortOrder ?? 1,
                billWithDelivery: billWithDelivery,
                billingDayOfMonth: List.from(dayOfMonth),
                billingDayOfWeek: List.from(dayOfWeek),
                billingWeekOfMonth: List.from(weekOfMonth),
                billingTimeFrom: timeFromCtrl.text.trim().isEmpty ? null : timeFromCtrl.text.trim(),
                billingTimeTo: timeToCtrl.text.trim().isEmpty ? null : timeToCtrl.text.trim(),
                dueFromBillingDate: dueFromBillingDate,
                remark: remarkCtrl.text.trim().isEmpty ? null : remarkCtrl.text.trim(),
              )),
              child: const Text('บันทึก'),
            ),
        ],
      );
    }),
  );
}

// ---------------------------------------------------------------------------
// Payment Condition Dialog
// ---------------------------------------------------------------------------
Future<ArCustomerPaymentCondition?> showPaymentConditionDialog(
    BuildContext context, ArCustomerPaymentCondition? existing, bool readOnly) {
  const dayNames = ['อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์'];
  const weekOptions = <int, String>{1: 'แรก', 2: 'ที่ 2', 3: 'ที่ 3', 4: 'ที่ 4', -1: 'สุดท้าย'};

  var dayOfMonth = List<int>.from(existing?.paymentDayOfMonth ?? []);
  var dayOfWeek = List<int>.from(existing?.paymentDayOfWeek ?? []);
  var weekOfMonth = List<int>.from(existing?.paymentWeekOfMonth ?? []);
  final timeFromCtrl = TextEditingController(text: existing?.paymentTimeFrom ?? '');
  final timeToCtrl = TextEditingController(text: existing?.paymentTimeTo ?? '');
  final withinMonthsCtrl = TextEditingController(
      text: (existing?.withinMonthsFromBilling ?? 0).toString());
  final additionalDaysCtrl =
      TextEditingController(text: (existing?.additionalDays ?? 0).toString());
  final remarkCtrl = TextEditingController(text: existing?.remark ?? '');

  return showDialog<ArCustomerPaymentCondition>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
      Widget chipGroup(String label, List<int> values, List<int> selected,
          String Function(int) labelFn) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
            ),
            child: Wrap(
              spacing: 4,
              runSpacing: 2,
              children: values.map((v) {
                final sel = selected.contains(v);
                return FilterChip(
                  label: Text(labelFn(v), style: const TextStyle(fontSize: 12)),
                  selected: sel,
                  onSelected: readOnly
                      ? null
                      : (on) => setDlg(() {
                            if (on) {
                              selected.add(v);
                            } else {
                              selected.remove(v);
                            }
                          }),
                  selectedColor: Colors.teal.shade100,
                  checkmarkColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ),
        );
      }

      return AlertDialog(
        title: Text(readOnly
            ? 'ดูเงื่อนไขรับชำระ'
            : existing == null
                ? 'เพิ่มเงื่อนไขรับชำระ'
                : 'แก้ไขเงื่อนไขรับชำระ'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // วันที่ในเดือน
                chipGroup(
                  'วันที่ในเดือน (31 = สิ้นเดือน)',
                  [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31],
                  dayOfMonth,
                  (d) => d == 31 ? 'สิ้นเดือน' : '$d',
                ),
                // วันในสัปดาห์
                chipGroup(
                  'วันในสัปดาห์',
                  List.generate(7, (i) => i),
                  dayOfWeek,
                  (d) => dayNames[d],
                ),
                // สัปดาห์ที่
                chipGroup(
                  'สัปดาห์ที่',
                  [1, 2, 3, 4, -1],
                  weekOfMonth,
                  (w) => weekOptions[w] ?? '$w',
                ),
                // เวลา
                Row(children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10, right: 5),
                      child: TextField(
                        controller: timeFromCtrl,
                        readOnly: readOnly,
                        decoration: const InputDecoration(
                          labelText: 'เวลาตั้งแต่',
                          border: OutlineInputBorder(),
                          hintText: '09:00',
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10, left: 5),
                      child: TextField(
                        controller: timeToCtrl,
                        readOnly: readOnly,
                        decoration: const InputDecoration(
                          labelText: 'ถึงเวลา',
                          border: OutlineInputBorder(),
                          hintText: '17:00',
                        ),
                      ),
                    ),
                  ),
                ]),
                const Divider(),
                // เงื่อนไขพิเศษ
                Row(children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10, right: 5),
                      child: TextField(
                        controller: withinMonthsCtrl,
                        readOnly: readOnly,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'ชำระภายในกี่เดือนจากวางบิล',
                          border: OutlineInputBorder(),
                          hintText: '0 = ไม่จำกัด',
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10, left: 5),
                      child: TextField(
                        controller: additionalDaysCtrl,
                        readOnly: readOnly,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'บวกเพิ่ม (วัน)',
                          border: OutlineInputBorder(),
                          hintText: '0',
                        ),
                      ),
                    ),
                  ),
                ]),
                TextField(
                  controller: remarkCtrl,
                  readOnly: readOnly,
                  decoration: const InputDecoration(
                    labelText: 'หมายเหตุ',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ยกเลิก'),
          ),
          if (!readOnly)
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(ArCustomerPaymentCondition(
                id: existing?.id,
                customerId: existing?.customerId,
                sortOrder: existing?.sortOrder ?? 1,
                paymentDayOfMonth: List.from(dayOfMonth),
                paymentDayOfWeek: List.from(dayOfWeek),
                paymentWeekOfMonth: List.from(weekOfMonth),
                paymentTimeFrom: timeFromCtrl.text.trim().isEmpty ? null : timeFromCtrl.text.trim(),
                paymentTimeTo: timeToCtrl.text.trim().isEmpty ? null : timeToCtrl.text.trim(),
                withinMonthsFromBilling: int.tryParse(withinMonthsCtrl.text) ?? 0,
                additionalDays: int.tryParse(additionalDaysCtrl.text) ?? 0,
                remark: remarkCtrl.text.trim().isEmpty ? null : remarkCtrl.text.trim(),
              )),
              child: const Text('บันทึก'),
            ),
        ],
      );
    }),
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
                isExpanded: true,
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
  late TextEditingController _creditTermMonthsCtrl;
  late TextEditingController _creditTermDaysCtrl;
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
  bool _autoNumberingEnabled = false; // จากตาราง ar_customer_running (global)
  bool? _customerGroupIsAutoNumber; // null = ยังไม่รู้ / ไม่ได้เลือกกลุ่ม
  bool _autoCodeOverridden = false; // true = ผู้ใช้กดแก้ไขเอง

  // effective auto-numbering:
  //   1) เลือกกลุ่ม + กลุ่มตั้งค่าอัตโนมัติ → true (ใช้ running ของกลุ่ม)
  //   2) ไม่เลือกกลุ่ม หรือ กลุ่มไม่ตั้งค่าอัตโนมัติ → ตรวจสอบ global ar_customer_running
  //   3) global ตั้งค่าอัตโนมัติ → true, มิฉะนั้น → false (ให้ผู้ใช้ใส่เอง)
  bool get _effectiveAutoNumbering {
    if (_customerGroupId != null && (_customerGroupIsAutoNumber == true)) return true;
    return _autoNumberingEnabled;
  }

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

  // เงื่อนไขการวางบิล / ชำระเงิน
  bool _requiresBilling = false;
  List<ArCustomerBillingCondition> _billingConditions = [];
  List<ArCustomerPaymentCondition> _paymentConditions = [];

  // ตัวอย่างการคำนวณวันที่
  DateTime _previewInvoiceDate = DateTime.now();
  final _previewDateFmt = DateFormat('dd/MM/yyyy');

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
    // สำหรับ record ใหม่ ให้ default สกุลเงินหลักจาก cd_currency
    if (widget.selected == null) _loadDefaultCurrency();
  }

  Future<void> _loadDefaultCurrency() async {
    final code = await Provider.of<CurrencyService>(context, listen: false)
        .getBaseCurrencyCode();
    if (mounted) setState(() => _selectedCurrencyCode = code);
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
      if (mounted) {
        setState(() {
          _customerGroups = list;
          // ถ้ามีกลุ่มเลือกอยู่แล้ว → resolve _customerGroupIsAutoNumber
          if (_customerGroupId != null) {
            final g = list.cast<ArCustomerGroup?>().firstWhere(
                (g) => g?.id == _customerGroupId,
                orElse: () => null);
            _customerGroupIsAutoNumber = g?.isAutoNumber;
          }
        });
      }
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
          // resolve name from full list (not just filtered) in case the stored account
          // doesn't have isControlAccount=true or isActive=true
          if (_arAccountId != null && _arAccountCode == null) {
            final match = list.where((a) => a.id == _arAccountId).firstOrNull;
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
    _creditTermMonthsCtrl = TextEditingController(text: (c?.creditTermMonths ?? 0).toString());
    _creditTermDaysCtrl   = TextEditingController(text: (c?.creditTermDays ?? 30).toString());
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
    _customerGroupIsAutoNumber = null; // will be resolved after _loadCustomerGroups
    _isActive        = c?.isActive ?? true;
    _addresses       = List.from(c?.addresses ?? []);
    _contacts        = List.from(c?.contacts ?? []);
    _bankAccounts    = List.from(c?.bankAccounts ?? []);
    _arAccountId       = c?.arAccountId;
    _arAccountCode     = c?.arAccountCode;
    _arAccountNameThai = c?.arAccountNameThai;
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
    _requiresBilling    = c?.requiresBilling ?? false;
    _billingConditions  = List.from(c?.billingConditions ?? []);
    _paymentConditions  = List.from(c?.paymentConditions ?? []);
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
      _creditTermMonthsCtrl, _creditTermDaysCtrl,
      _creditLimitCtrl, _discountPercentCtrl,
      _remarkCtrl,
    ]) {
      c.dispose();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  // เลือกกลุ่มลูกค้า → auto-fill เงื่อนไขเครดิต + เงื่อนไขการวางบิล/ชำระ + อัปเดต auto-number mode
  Future<void> _onGroupSelected(ArCustomerGroup group) async {
    // apply basic fields immediately
    setState(() {
      _customerGroupId           = group.id;
      _customerGroupCode         = group.groupCode;
      _customerGroupName         = group.groupNameThai;
      _customerGroupIsAutoNumber = group.isAutoNumber;
      _autoCodeOverridden        = false;
      _codeCtrl.clear();
      _creditTermMonthsCtrl.text = group.creditTermMonths.toString();
      _creditTermDaysCtrl.text   = group.creditTermDays.toString();
      _creditLimitCtrl.text        = group.creditLimit.toStringAsFixed(2);
      _discountPercentCtrl.text    = group.discountPercent.toStringAsFixed(2);
    });
    // fetch full group (with billing/payment conditions) then apply
    if (group.id == null) return;
    try {
      final full = await Provider.of<ArCustomerGroupService>(context, listen: false)
          .fetchRow(group.id!);
      if (!mounted) return;
      setState(() {
        _requiresBilling = full.requiresBilling;
        _billingConditions = full.billingConditions
            .map((bc) => bc.copyWith(id: null, customerId: null))
            .toList();
        _paymentConditions = full.paymentConditions
            .map((pc) => pc.copyWith(id: null, customerId: null))
            .toList();
      });
    } catch (_) {
      // conditions remain empty if fetch fails — non-critical
    }
  }

  void _clearGroup() {
    setState(() {
      _customerGroupId           = null;
      _customerGroupCode         = null;
      _customerGroupName         = null;
      _customerGroupIsAutoNumber = null;
      _autoCodeOverridden        = false; // reset เมื่อเคลียร์กลุ่ม
      _codeCtrl.clear();
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
        customerCode: (_effectiveAutoNumbering && !_autoCodeOverridden)
            ? ''
            : _codeCtrl.text.trim(),
        customerNameTh: _nameThCtrl.text.trim(),
        customerNameEn:
            _nameEnCtrl.text.trim().isEmpty ? null : _nameEnCtrl.text.trim(),
        taxId: _taxIdCtrl.text.trim().isEmpty ? null : _taxIdCtrl.text.trim(),
        oldCustomerCode: _oldCustomerCodeCtrl.text.trim().isEmpty ? null : _oldCustomerCodeCtrl.text.trim(),
        businessTypeId: _businessTypeId,
        customerGroupId: _customerGroupId,
        creditTermMonths: int.tryParse(_creditTermMonthsCtrl.text) ?? 0,
        creditTermDays: int.tryParse(_creditTermDaysCtrl.text) ?? 30,
        creditLimit: double.tryParse(_creditLimitCtrl.text) ?? 0,
        discountPercent: double.tryParse(_discountPercentCtrl.text) ?? 0,
        currencyCode: _selectedCurrencyCode ?? 'THB',
        isActive: _isActive,
        remark: _remarkCtrl.text.trim().isEmpty ? null : _remarkCtrl.text.trim(),
        requiresBilling: _requiresBilling,
        billingConditions: List.from(_billingConditions),
        paymentConditions: List.from(_paymentConditions),
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

    // โหมด add + effective auto-numbering เปิด + ยังไม่ได้กด "แก้ไขเอง"
    if (isAdd && _effectiveAutoNumbering && !_autoCodeOverridden) {
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

    // โหมด add + effective auto-numbering เปิด + ผู้ใช้กด "แก้ไขเอง"
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

    // โหมด edit / view / effective auto-numbering ปิด → ปกติ
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
              child: _buildField('ระยะเครดิต (เดือน)', _creditTermMonthsCtrl,
                  readOnly: readOnly, keyboard: TextInputType.number),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildField('ระยะเครดิต (วัน)', _creditTermDaysCtrl,
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
          const addrTypeLabel = {
            'billing':      'ที่อยู่ใบแจ้งหนี้',
            'shipping':     'ที่อยู่จัดส่ง',
            'billing note': 'ที่อยู่วางบิล',
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
                    style: const TextStyle(
                        fontSize: 11, color: Colors.blueGrey)),
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

  // ─── Date Preview Helpers ──────────────────────────────────────────────────

  static const _thWeekdaysFull = [
    'อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์'
  ];

  // หาวันที่ weekday ลำดับที่ weekOfMonth ของเดือน (weekOfMonth=-1 = สุดท้าย)
  DateTime? _nthWeekdayOfMonth(int year, int month, int weekday, int weekOfMonth) {
    if (weekOfMonth == -1) {
      final last = DateTime(year, month + 1, 0).day;
      for (int d = last; d >= 1; d--) {
        if (DateTime(year, month, d).weekday % 7 == weekday) {
          return DateTime(year, month, d);
        }
      }
    } else {
      int count = 0;
      for (int d = 1; d <= 31; d++) {
        final date = DateTime(year, month, d);
        if (date.month != month) break;
        if (date.weekday % 7 == weekday) {
          count++;
          if (count == weekOfMonth) return date;
        }
      }
    }
    return null;
  }

  // คำนวณวันวางบิลที่เหมาะสมที่สุดจากเงื่อนไขลำดับแรก
  DateTime? _previewCalcBillingDate(DateTime invoiceDate) {
    if (_billingConditions.isEmpty) return null;
    final cond = _billingConditions.reduce(
        (a, b) => a.sortOrder <= b.sortOrder ? a : b);

    if (cond.billWithDelivery) return invoiceDate;

    if (cond.billingDayOfMonth.isNotEmpty) {
      final days = [...cond.billingDayOfMonth]..sort();
      for (final day in days) {
        final lastDay = DateTime(invoiceDate.year, invoiceDate.month + 1, 0).day;
        final candidate = day == 31
            ? DateTime(invoiceDate.year, invoiceDate.month + 1, 0)
            : DateTime(invoiceDate.year, invoiceDate.month, day.clamp(1, lastDay));
        if (!candidate.isBefore(invoiceDate)) return candidate;
      }
      final d = days.first;
      return d == 31
          ? DateTime(invoiceDate.year, invoiceDate.month + 2, 0)
          : DateTime(invoiceDate.year, invoiceDate.month + 1, d.clamp(1, 28));
    }

    if (cond.billingDayOfWeek.isNotEmpty) {
      if (cond.billingWeekOfMonth.isNotEmpty) {
        for (int m = 0; m <= 2; m++) {
          final totalMonth = invoiceDate.month + m;
          final y = invoiceDate.year + (totalMonth - 1) ~/ 12;
          final mo = ((totalMonth - 1) % 12) + 1;
          for (final wd in cond.billingDayOfWeek) {
            for (final wom in cond.billingWeekOfMonth) {
              final d = _nthWeekdayOfMonth(y, mo, wd, wom);
              if (d != null && !d.isBefore(invoiceDate)) return d;
            }
          }
        }
      } else {
        for (int offset = 0; offset <= 13; offset++) {
          final c = invoiceDate.add(Duration(days: offset));
          if (cond.billingDayOfWeek.contains(c.weekday % 7)) return c;
        }
      }
    }
    return null;
  }

  // คำนวณวันครบกำหนดจากระยะเครดิต
  DateTime _previewCalcDueDate(DateTime invoiceDate, DateTime? billingDate) {
    final months = int.tryParse(_creditTermMonthsCtrl.text) ?? 0;
    final days   = int.tryParse(_creditTermDaysCtrl.text) ?? 0;
    final useFromBilling = billingDate != null &&
        _billingConditions.any((c) => c.dueFromBillingDate);
    var base = useFromBilling ? billingDate! : invoiceDate;
    if (months > 0) base = DateTime(base.year, base.month + months, base.day);
    if (days > 0)   base = base.add(Duration(days: days));
    return base;
  }

  // สร้างรายการวันชำระที่เป็นไปได้ภายใน maxMonths เดือนจาก startDate
  List<DateTime> _generatePaymentCandidates(
      DateTime startDate, ArCustomerPaymentCondition cond, int maxMonths) {
    final result = <DateTime>[];
    for (int m = 0; m <= maxMonths; m++) {
      final totalMonth = startDate.month + m;
      final y  = startDate.year + (totalMonth - 1) ~/ 12;
      final mo = ((totalMonth - 1) % 12) + 1;

      if (cond.paymentDayOfMonth.isNotEmpty) {
        for (final day in cond.paymentDayOfMonth) {
          final lastDay = DateTime(y, mo + 1, 0).day;
          final d = day == 31
              ? DateTime(y, mo + 1, 0)
              : DateTime(y, mo, day.clamp(1, lastDay));
          if (!d.isBefore(startDate)) {
            result.add(d.add(Duration(days: cond.additionalDays)));
          }
        }
      } else if (cond.paymentDayOfWeek.isNotEmpty) {
        if (cond.paymentWeekOfMonth.isNotEmpty) {
          for (final wd in cond.paymentDayOfWeek) {
            for (final wom in cond.paymentWeekOfMonth) {
              final d = _nthWeekdayOfMonth(y, mo, wd, wom);
              if (d != null && !d.isBefore(startDate)) {
                result.add(d.add(Duration(days: cond.additionalDays)));
              }
            }
          }
        } else {
          for (int day = 1; day <= 31; day++) {
            final d = DateTime(y, mo, day);
            if (d.month != mo) break;
            if (!d.isBefore(startDate) &&
                cond.paymentDayOfWeek.contains(d.weekday % 7)) {
              result.add(d.add(Duration(days: cond.additionalDays)));
            }
          }
        }
      }
    }
    return result;
  }

  // วันรับชำระที่ใกล้วันครบกำหนดที่สุด (ก่อนหรือตรงกับ dueDate ก่อน)
  DateTime _previewCalcPaymentDate(DateTime billingDate, DateTime dueDate) {
    if (_paymentConditions.isEmpty) return dueDate;
    final cond = _paymentConditions.reduce(
        (a, b) => a.sortOrder <= b.sortOrder ? a : b);

    final maxM = cond.withinMonthsFromBilling > 0
        ? cond.withinMonthsFromBilling + 1
        : 6;
    var candidates = _generatePaymentCandidates(billingDate, cond, maxM);

    if (cond.withinMonthsFromBilling > 0) {
      final limit = DateTime(billingDate.year,
          billingDate.month + cond.withinMonthsFromBilling, billingDate.day);
      candidates = candidates.where((d) => !d.isAfter(limit)).toList();
    }
    if (candidates.isEmpty) return dueDate;

    // วันรับชำระ ≥ dueDate ที่ใกล้ที่สุด
    final onOrAfter = candidates.where((d) => !d.isBefore(dueDate)).toList();
    if (onOrAfter.isNotEmpty) {
      onOrAfter.sort();
      return onOrAfter.first;
    }
    // ถ้าไม่มีเลย (ถูก withinMonthsFromBilling จำกัด) ให้ใช้วันสุดท้ายที่มี
    candidates.sort((a, b) => b.compareTo(a));
    return candidates.first;
  }

  static const _thMonths = [
    'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
  ];

  // แปลง list วันที่ → ช่วง เช่น [1,2,3,7,8] → "1-3, 7-8"
  String _formatDayRanges(List<int> days) {
    if (days.isEmpty) return '';
    final sorted = [...days]..sort();
    final ranges = <String>[];
    int start = sorted[0], end = sorted[0];
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i] == end + 1) {
        end = sorted[i];
      } else {
        ranges.add(start == end ? '$start' : '$start-$end');
        start = end = sorted[i];
      }
    }
    ranges.add(start == end ? '$start' : '$start-$end');
    return 'วันที่ ${ranges.join(', ')}';
  }

  // คำนวณกลุ่มวันที่ invoice ทุกวันในเดือนเดียวกัน
  // คืน list เรียงตามวันที่ billing แล้วตามวันที่ payment
  List<Map<String, dynamic>> _calcInvoiceDateGroups() {
    final year    = _previewInvoiceDate.year;
    final month   = _previewInvoiceDate.month;
    final lastDay = DateTime(year, month + 1, 0).day;

    final Map<String, Map<String, dynamic>> groups = {};

    for (int d = 1; d <= lastDay; d++) {
      final invoice         = DateTime(year, month, d);
      final billing         = _previewCalcBillingDate(invoice);
      final effectiveBilling = billing ?? invoice;
      final due             = _previewCalcDueDate(invoice, billing);
      final payment         = _previewCalcPaymentDate(effectiveBilling, due);

      // key = billingDate_paymentDate (จัดกลุ่มวันที่ให้ payment เดียวกัน)
      String fmt(DateTime dt) =>
          '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';
      final key = '${fmt(effectiveBilling)}_${fmt(payment)}';

      if (!groups.containsKey(key)) {
        groups[key] = {
          'days':    <int>[],
          'billing': effectiveBilling,
          'minDue':  due,
          'maxDue':  due,
          'payment': payment,
        };
      }
      (groups[key]!['days'] as List<int>).add(d);
      if (due.isBefore(groups[key]!['minDue'] as DateTime)) {
        groups[key]!['minDue'] = due;
      }
      if (due.isAfter(groups[key]!['maxDue'] as DateTime)) {
        groups[key]!['maxDue'] = due;
      }
    }

    final result = groups.values.toList();
    for (final g in result) {
      final minDue  = g['minDue']  as DateTime;
      final maxDue  = g['maxDue']  as DateTime;
      final payment = g['payment'] as DateTime;
      // minDelay = ห่างน้อยที่สุด (invoice วันสุดท้ายของกลุ่ม → due ล่าช้าที่สุด → gap น้อยที่สุด)
      g['minDelay'] = payment.difference(maxDue).inDays;
      g['maxDelay'] = payment.difference(minDue).inDays;
    }

    result.sort((a, b) {
      final bc = (a['billing'] as DateTime).compareTo(b['billing'] as DateTime);
      return bc != 0 ? bc : (a['payment'] as DateTime).compareTo(b['payment'] as DateTime);
    });
    return result;
  }

  // ─── Section Widget ────────────────────────────────────────────────────────

  Widget _buildDatePreviewSection() {
    final invoice    = _previewInvoiceDate;
    final billing    = _previewCalcBillingDate(invoice);
    final due        = _previewCalcDueDate(invoice, billing);
    final payment    = _previewCalcPaymentDate(billing ?? invoice, due);

    final months = int.tryParse(_creditTermMonthsCtrl.text) ?? 0;
    final days   = int.tryParse(_creditTermDaysCtrl.text) ?? 0;

    final useFromBilling = billing != null &&
        _billingConditions.any((c) => c.dueFromBillingDate);

    // ── คำอธิบายสั้น ──
    String billingDetail;
    if (_billingConditions.isEmpty) {
      billingDetail = 'ไม่มีเงื่อนไขวางบิล — ใช้วันที่ invoice';
    } else {
      final c = _billingConditions.reduce(
          (a, b) => a.sortOrder <= b.sortOrder ? a : b);
      billingDetail = _billingConditionSummary(c);
    }

    String dueDetail;
    if (months == 0 && days == 0) {
      dueDetail = 'ชำระทันที (ระยะเครดิต 0)';
    } else {
      final parts = <String>[];
      if (months > 0) parts.add('$months เดือน');
      if (days > 0)   parts.add('$days วัน');
      final base = useFromBilling ? 'วันวางบิล' : 'วันที่ invoice';
      dueDetail = 'นับจาก$base + ${parts.join(' ')}';
    }

    String paymentDetail;
    if (_paymentConditions.isEmpty) {
      paymentDetail = 'ไม่มีเงื่อนไขรับชำระ — ตามวันครบกำหนด';
    } else {
      final c = _paymentConditions.reduce(
          (a, b) => a.sortOrder <= b.sortOrder ? a : b);
      paymentDetail = _paymentConditionSummary(c);
    }

    // ── helper row ──
    Widget resultRow(IconData icon, Color color, String label,
        DateTime date, String detail) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                SizedBox(
                  width: 130,
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _previewDateFmt.format(date),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: color),
                  ),
                ),
              ]),
              const SizedBox(height: 2),
              Text(detail,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ]),
          ),
        ]),
      );
    }

    return _Section(
      title: 'ตัวอย่างการคำนวณวันที่',
      initiallyExpanded: false,
      children: [
        // Input: วันที่ Invoice
        Row(children: [
          const Text('วันที่ Invoice', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _previewInvoiceDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() => _previewInvoiceDate = picked);
              }
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.teal),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  _previewDateFmt.format(_previewInvoiceDate),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.calendar_today,
                    size: 14, color: Colors.teal),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        const Divider(height: 1),
        const SizedBox(height: 4),
        resultRow(
          Icons.receipt_long,
          Colors.blue[700]!,
          'วันวางบิล',
          billing ?? invoice,
          billingDetail,
        ),
        resultRow(
          Icons.event_available,
          Colors.green[700]!,
          'วันครบกำหนด',
          due,
          dueDetail,
        ),
        resultRow(
          Icons.payments_outlined,
          Colors.orange[700]!,
          'วันรับชำระ',
          payment,
          paymentDetail,
        ),
        // ── ช่วงวันที่ invoice ที่เหมาะสมในเดือนนี้ ──────────────────────
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 8),
        Builder(builder: (_) {
          final groups = _calcInvoiceDateGroups();
          if (groups.isEmpty) return const SizedBox.shrink();

          final minDelay = groups
              .map((g) => g['minDelay'] as int)
              .reduce((a, b) => a < b ? a : b);

          final monthLabel =
              '${_thMonths[invoice.month - 1]} ${invoice.year + 543}';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ช่วงวันที่ invoice ในเดือน $monthLabel',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey),
              ),
              const SizedBox(height: 6),
              ...groups.map((g) {
                final days     = g['days']     as List<int>;
                final billing  = g['billing']  as DateTime;
                final pmt      = g['payment']  as DateTime;
                final minD     = g['minDelay'] as int;
                final maxD     = g['maxDelay'] as int;
                final isBest   = minD == minDelay;

                final delayText = minD == maxD
                    ? 'ห่างครบกำหนด $minD วัน'
                    : 'ห่างครบกำหนด $minD–$maxD วัน';

                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isBest
                        ? Colors.green[50]
                        : Colors.grey[50],
                    border: Border.all(
                        color: isBest
                            ? Colors.green[300]!
                            : Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(children: [
                    if (isBest) ...[
                      Icon(Icons.star_rounded,
                          color: Colors.green[600], size: 14),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      _formatDayRanges(days),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: isBest
                              ? FontWeight.bold
                              : FontWeight.normal),
                    ),
                    Text(
                      '  →  วางบิล ${_previewDateFmt.format(billing)}'
                      '  →  รับชำระ ${_previewDateFmt.format(pmt)}',
                      style: TextStyle(
                          fontSize: 12,
                          color: isBest
                              ? Colors.green[800]
                              : Colors.grey[700]),
                    ),
                    const Spacer(),
                    Text(
                      delayText,
                      style: TextStyle(
                          fontSize: 11,
                          color: isBest
                              ? Colors.green[700]
                              : Colors.grey[600],
                          fontWeight: isBest
                              ? FontWeight.w600
                              : FontWeight.normal),
                    ),
                  ]),
                );
              }),
            ],
          );
        }),
      ],
    );
  }

  // ---- Section: เงื่อนไขการวางบิล ----
  Widget _buildBillingConditionsSection(bool readOnly) {
    return _Section(
      title: 'เงื่อนไขการวางบิล (${_billingConditions.length})',
      initiallyExpanded: false,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // toggle: ต้องวางบิลหรือไม่
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ต้องวางบิล',
                  style: TextStyle(
                      fontSize: 12,
                      color: _requiresBilling
                          ? Colors.indigo.shade700
                          : Colors.grey)),
              Switch(
                value: _requiresBilling,
                onChanged: readOnly
                    ? null
                    : (v) => setState(() => _requiresBilling = v),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          if (!readOnly)
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              tooltip: 'เพิ่มเงื่อนไขวางบิล',
              onPressed: () async {
                final result =
                    await showBillingConditionDialog(context, null, false);
                if (result != null) {
                  setState(() => _billingConditions.add(result.copyWith(
                      sortOrder: _billingConditions.length + 1)));
                }
              },
            ),
        ],
      ),
      children: [
        if (!_requiresBilling)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'ไม่ต้องวางบิล: วันครบกำหนดชำระนับจากวันส่งของ',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        if (_billingConditions.isEmpty)
          const Text('ยังไม่มีเงื่อนไขการวางบิล',
              style: TextStyle(color: Colors.grey)),
        ..._billingConditions.asMap().entries.map((entry) {
          final i = entry.key;
          final b = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.indigo.shade100,
                  child: Text('${i + 1}',
                      style: const TextStyle(fontSize: 11, color: Colors.indigo)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_billingConditionSummary(b),
                        style: const TextStyle(fontSize: 13)),
                  ),
                ),
                IconButton(
                  icon: Icon(readOnly ? Icons.visibility : Icons.edit,
                      size: 18,
                      color: readOnly ? Colors.green : Colors.blue),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () async {
                    final result = await showBillingConditionDialog(
                        context, b, readOnly);
                    if (result != null) {
                      setState(() => _billingConditions[i] = result);
                    }
                  },
                ),
                if (!readOnly)
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => setState(() {
                      _billingConditions.removeAt(i);
                      for (var j = 0; j < _billingConditions.length; j++) {
                        _billingConditions[j] =
                            _billingConditions[j].copyWith(sortOrder: j + 1);
                      }
                    }),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _billingConditionSummary(ArCustomerBillingCondition b) {
    const dayNames = ['อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์'];
    const weekNames = {1: 'แรก', 2: 'ที่2', 3: 'ที่3', 4: 'ที่4', -1: 'สุดท้าย'};
    final parts = <String>[];
    if (b.billWithDelivery) parts.add('วางบิลพร้อมส่งของ');
    if (b.billingDayOfMonth.isNotEmpty) {
      final days = b.billingDayOfMonth
          .map((d) => d == 31 ? 'สิ้นเดือน' : 'วันที่ $d')
          .join(', ');
      parts.add(days);
    }
    if (b.billingDayOfWeek.isNotEmpty) {
      parts.add('วัน${b.billingDayOfWeek.map((d) => dayNames[d]).join('-')}');
    }
    if (b.billingWeekOfMonth.isNotEmpty) {
      parts.add(
          'สัปดาห์${b.billingWeekOfMonth.map((w) => weekNames[w] ?? '$w').join('/')}');
    }
    if (b.billingTimeFrom != null || b.billingTimeTo != null) {
      parts.add('${b.billingTimeFrom ?? ''}–${b.billingTimeTo ?? ''}');
    }
    if (b.dueFromBillingDate) parts.add('due นับจากวางบิล');
    return parts.isEmpty ? '(ไม่ระบุเงื่อนไข)' : parts.join('  ·  ');
  }

  // ---- Section: เงื่อนไขการรับชำระเงิน ----
  Widget _buildPaymentConditionsSection(bool readOnly) {
    return _Section(
      title: 'เงื่อนไขการรับชำระเงิน (${_paymentConditions.length})',
      initiallyExpanded: false,
      trailing: readOnly
          ? null
          : IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              tooltip: 'เพิ่มเงื่อนไขรับชำระ',
              onPressed: () async {
                final result =
                    await showPaymentConditionDialog(context, null, false);
                if (result != null) {
                  setState(() => _paymentConditions.add(result.copyWith(
                      sortOrder: _paymentConditions.length + 1)));
                }
              },
            ),
      children: [
        if (_paymentConditions.isEmpty)
          const Text(
              'ยังไม่มีเงื่อนไขรับชำระ — วันชำระเงินจะเท่ากับวันครบกำหนด',
              style: TextStyle(color: Colors.grey)),
        ..._paymentConditions.asMap().entries.map((entry) {
          final i = entry.key;
          final p = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.teal.shade100,
                  child: Text('${i + 1}',
                      style: const TextStyle(fontSize: 11, color: Colors.teal)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_paymentConditionSummary(p),
                        style: const TextStyle(fontSize: 13)),
                  ),
                ),
                IconButton(
                  icon: Icon(readOnly ? Icons.visibility : Icons.edit,
                      size: 18,
                      color: readOnly ? Colors.green : Colors.blue),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () async {
                    final result = await showPaymentConditionDialog(
                        context, p, readOnly);
                    if (result != null) {
                      setState(() => _paymentConditions[i] = result);
                    }
                  },
                ),
                if (!readOnly)
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => setState(() {
                      _paymentConditions.removeAt(i);
                      for (var j = 0; j < _paymentConditions.length; j++) {
                        _paymentConditions[j] =
                            _paymentConditions[j].copyWith(sortOrder: j + 1);
                      }
                    }),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _paymentConditionSummary(ArCustomerPaymentCondition p) {
    const dayNames = ['อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์'];
    const weekNames = {1: 'แรก', 2: 'ที่2', 3: 'ที่3', 4: 'ที่4', -1: 'สุดท้าย'};
    final parts = <String>[];
    if (p.paymentDayOfMonth.isNotEmpty) {
      final days = p.paymentDayOfMonth
          .map((d) => d == 31 ? 'สิ้นเดือน' : 'วันที่ $d')
          .join(', ');
      parts.add(days);
    }
    if (p.paymentDayOfWeek.isNotEmpty) {
      parts.add('วัน${p.paymentDayOfWeek.map((d) => dayNames[d]).join('-')}');
    }
    if (p.paymentWeekOfMonth.isNotEmpty) {
      parts.add(
          'สัปดาห์${p.paymentWeekOfMonth.map((w) => weekNames[w] ?? '$w').join('/')}');
    }
    if (p.withinMonthsFromBilling > 0) {
      parts.add('ภายใน ${p.withinMonthsFromBilling} เดือนจากวางบิล');
    }
    if (p.additionalDays != 0) parts.add('+${p.additionalDays} วัน');
    if (p.paymentTimeFrom != null || p.paymentTimeTo != null) {
      parts.add('${p.paymentTimeFrom ?? ''}–${p.paymentTimeTo ?? ''}');
    }
    return parts.isEmpty ? '(ไม่ระบุเงื่อนไข)' : parts.join('  ·  ');
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
              'หากไม่ระบุ ระบบจะค้นหาบัญชีลูกหนี้จาก กลุ่มลูกค้า และ ประเภทเอกสาร ตามลำดับ พบที่ใดก่อนจะใช้บัญชีนั้นลงรายการบัญชี',
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
                  _buildBillingConditionsSection(readOnly),
                  _buildPaymentConditionsSection(readOnly),
                  _buildDatePreviewSection(),
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
