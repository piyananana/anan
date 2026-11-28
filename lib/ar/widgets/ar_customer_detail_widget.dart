import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../cd/models/cd_zipcode.dart';
import '../../cd/models/cd_business_type.dart';
import '../../cd/services/cd_business_type_service.dart';
import '../../cd/widgets/cd_zipcode_list_widget.dart';
import '../../cd/widgets/cd_tax_branch_field.dart';
import '../../cd/widgets/cd_salesperson_split_editor.dart';
import '../../cd/models/cd_doc_salesperson.dart';
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
import '../../im/widgets/im_price_list_list_widget.dart';
import '../../sa/services/sa_language_provider.dart';
import 'dart:convert';
import '../../im/widgets/im_master_kit.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../models/ar_customer_summary.dart';
import '../services/ar_customer_service.dart';

// ---------------------------------------------------------------------------
// Address Dialog
// ---------------------------------------------------------------------------
Future<ArCustomerAddress?> showAddressDialog(
    BuildContext context, ArCustomerAddress? existing, bool readOnly,
    {ArCustomerAddress? primaryAddress}) async {
  final isEnglish =
      Provider.of<LanguageProvider>(context, listen: false).isEnglish;
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
                // Checkbox: ใช้ที่อยู่เดียวกับที่อยู่หลัก
                if (showSameAddressCheckbox)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(isEnglish
                          ? 'Use same address as primary'
                          : 'ใช้ที่อยู่เดียวกับที่อยู่หลัก'),
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
                      decoration: InputDecoration(
                          labelText: isEnglish ? 'Address Type' : 'ประเภทที่อยู่',
                          border: const OutlineInputBorder()),
                      items: [
                        DropdownMenuItem(
                            value: 'billing',
                            child: Text(isEnglish
                                ? 'Billing Address'
                                : 'ที่อยู่ใบแจ้งหนี้')),
                        DropdownMenuItem(
                            value: 'shipping',
                            child: Text(
                                isEnglish ? 'Shipping Address' : 'ที่อยู่จัดส่ง')),
                        DropdownMenuItem(
                            value: 'billing note',
                            child: Text(isEnglish
                                ? 'Billing Note Address'
                                : 'ที่อยู่วางบิล')),
                        DropdownMenuItem(
                            value: 'payment',
                            child: Text(isEnglish
                                ? 'Payment Address'
                                : 'ที่อยู่ชำระเงิน')),
                        DropdownMenuItem(
                            value: 'other',
                            child: Text(isEnglish ? 'Other' : 'อื่นๆ')),
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
                  Expanded(
                      child: buildField(
                          isEnglish ? 'House No. / Room' : 'บ้านเลขที่ / ห้อง',
                          noCtrl)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: buildField(
                          isEnglish
                              ? 'Building / Village'
                              : 'อาคาร / หมู่บ้าน',
                          buildingCtrl)),
                ]),
                Row(children: [
                  Expanded(
                      child:
                          buildField(isEnglish ? 'Alley' : 'ซอย', alleyCtrl)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: buildField(isEnglish ? 'Road' : 'ถนน', roadCtrl)),
                ]),
                // แขวง/ตำบล + อำเภอ/เขต พร้อมปุ่มค้นหา zipcode
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (!readOnly)
                      IconButton(
                          icon: const Icon(Icons.search, color: Colors.blue),
                          tooltip: isEnglish
                              ? 'Search sub-district, district, province, zip code'
                              : 'ค้นหา ตำบล/แขวง, อำเภอ/เขต, จังหวัด, รหัสไปรษณีย์',
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
                            Expanded(
                                child: buildField(
                                    isEnglish ? 'Sub-district' : 'ตำบล / แขวง',
                                    subDistCtrl)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: buildField(
                                    isEnglish ? 'District' : 'อำเภอ / เขต',
                                    distCtrl)),
                          ]),
                          Row(children: [
                            Expanded(
                                child: buildField(
                                    isEnglish ? 'Province' : 'จังหวัด',
                                    provCtrl)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: buildField(
                                    isEnglish ? 'Zip Code' : 'รหัสไปรษณีย์',
                                    zipCtrl)),
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
                    title:
                        Text(isEnglish ? 'Primary Address' : 'ที่อยู่หลัก'),
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
Future<ArCustomerContact?> showContactDialog(
    BuildContext context, ArCustomerContact? existing, bool readOnly) async {
  final isEnglish =
      Provider.of<LanguageProvider>(context, listen: false).isEnglish;
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
                    labelText:
                        isEnglish ? 'Contact Name *' : 'ชื่อผู้ติดต่อ *',
                    border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                readOnly: readOnly,
                controller: posCtrl,
                decoration: InputDecoration(
                    labelText: isEnglish ? 'Position' : 'ตำแหน่ง',
                    border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      readOnly: readOnly,
                      controller: phoneCtrl,
                      decoration: InputDecoration(
                          labelText: isEnglish ? 'Phone' : 'โทรศัพท์',
                          border: const OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      readOnly: readOnly,
                      controller: mobileCtrl,
                      decoration: InputDecoration(
                          labelText: isEnglish ? 'Mobile' : 'มือถือ',
                          border: const OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                readOnly: readOnly,
                controller: emailCtrl,
                decoration: InputDecoration(
                    labelText: isEnglish ? 'Email' : 'อีเมล',
                    border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder<bool>(
                valueListenable: isDefaultNotifier,
                builder: (_, v, __) => SwitchListTile(
                  title: Text(
                      isEnglish ? 'Primary Contact' : 'ผู้ติดต่อหลัก'),
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
// Billing Condition Dialog
// ---------------------------------------------------------------------------
Future<ArCustomerBillingCondition?> showBillingConditionDialog(
    BuildContext context, ArCustomerBillingCondition? existing, bool readOnly) {
  final isEnglish =
      Provider.of<LanguageProvider>(context, listen: false).isEnglish;
  final dayNames = isEnglish
      ? ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
      : ['อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์'];
  final weekOptions = isEnglish
      ? <int, String>{1: '1st', 2: '2nd', 3: '3rd', 4: '4th', -1: 'Last'}
      : <int, String>{1: 'แรก', 2: 'ที่ 2', 3: 'ที่ 3', 4: 'ที่ 4', -1: 'สุดท้าย'};

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
            ? (isEnglish ? 'View Billing Condition' : 'ดูเงื่อนไขวางบิล')
            : existing == null
                ? (isEnglish ? 'Add Billing Condition' : 'เพิ่มเงื่อนไขวางบิล')
                : (isEnglish
                    ? 'Edit Billing Condition'
                    : 'แก้ไขเงื่อนไขวางบิล')),
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
                  title: Text(isEnglish
                      ? 'Bill with delivery date (no need to wait for billing date)'
                      : 'วางบิลพร้อมวันส่งของ (ไม่ต้องรอวันวางบิล)'),
                  value: billWithDelivery,
                  onChanged: readOnly ? null : (v) => setDlg(() => billWithDelivery = v ?? false),
                ),
                const Divider(),
                // วันที่ในเดือน
                chipGroup(
                  isEnglish
                      ? 'Day of month (31 = end of month)'
                      : 'วันที่ในเดือน (31 = สิ้นเดือน)',
                  [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31],
                  dayOfMonth,
                  (d) => d == 31 ? (isEnglish ? 'End of month' : 'สิ้นเดือน') : '$d',
                ),
                // วันในสัปดาห์
                chipGroup(
                  isEnglish ? 'Day of week' : 'วันในสัปดาห์',
                  List.generate(7, (i) => i),
                  dayOfWeek,
                  (d) => dayNames[d],
                ),
                // สัปดาห์ที่
                chipGroup(
                  isEnglish ? 'Week of month' : 'สัปดาห์ที่',
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
                        decoration: InputDecoration(
                          labelText: isEnglish ? 'Time From' : 'เวลาตั้งแต่',
                          border: const OutlineInputBorder(),
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
                        decoration: InputDecoration(
                          labelText: isEnglish ? 'Time To' : 'ถึงเวลา',
                          border: const OutlineInputBorder(),
                          hintText: '17:00',
                        ),
                      ),
                    ),
                  ),
                ]),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(isEnglish
                      ? 'Calculate due date from billing date (instead of delivery date)'
                      : 'คำนวณวันครบกำหนดชำระจากวันวางบิล (แทนวันส่งของ)'),
                  value: dueFromBillingDate,
                  onChanged: readOnly ? null : (v) => setDlg(() => dueFromBillingDate = v ?? false),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextField(
                    controller: remarkCtrl,
                    readOnly: readOnly,
                    decoration: InputDecoration(
                      labelText: isEnglish ? 'Remark' : 'หมายเหตุ',
                      border: const OutlineInputBorder(),
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
            child: Text(isEnglish ? 'Cancel' : 'ยกเลิก'),
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
              child: Text(isEnglish ? 'Save' : 'บันทึก'),
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
  final isEnglish =
      Provider.of<LanguageProvider>(context, listen: false).isEnglish;
  final dayNames = isEnglish
      ? ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
      : ['อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์'];
  final weekOptions = isEnglish
      ? <int, String>{1: '1st', 2: '2nd', 3: '3rd', 4: '4th', -1: 'Last'}
      : <int, String>{1: 'แรก', 2: 'ที่ 2', 3: 'ที่ 3', 4: 'ที่ 4', -1: 'สุดท้าย'};

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
            ? (isEnglish ? 'View Payment Condition' : 'ดูเงื่อนไขรับชำระ')
            : existing == null
                ? (isEnglish ? 'Add Payment Condition' : 'เพิ่มเงื่อนไขรับชำระ')
                : (isEnglish
                    ? 'Edit Payment Condition'
                    : 'แก้ไขเงื่อนไขรับชำระ')),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // วันที่ในเดือน
                chipGroup(
                  isEnglish
                      ? 'Day of month (31 = end of month)'
                      : 'วันที่ในเดือน (31 = สิ้นเดือน)',
                  [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31],
                  dayOfMonth,
                  (d) => d == 31 ? (isEnglish ? 'End of month' : 'สิ้นเดือน') : '$d',
                ),
                // วันในสัปดาห์
                chipGroup(
                  isEnglish ? 'Day of week' : 'วันในสัปดาห์',
                  List.generate(7, (i) => i),
                  dayOfWeek,
                  (d) => dayNames[d],
                ),
                // สัปดาห์ที่
                chipGroup(
                  isEnglish ? 'Week of month' : 'สัปดาห์ที่',
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
                        decoration: InputDecoration(
                          labelText: isEnglish ? 'Time From' : 'เวลาตั้งแต่',
                          border: const OutlineInputBorder(),
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
                        decoration: InputDecoration(
                          labelText: isEnglish ? 'Time To' : 'ถึงเวลา',
                          border: const OutlineInputBorder(),
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
                        decoration: InputDecoration(
                          labelText: isEnglish
                              ? 'Pay within (months) from billing'
                              : 'ชำระภายในกี่เดือนจากวางบิล',
                          border: const OutlineInputBorder(),
                          hintText: isEnglish ? '0 = unlimited' : '0 = ไม่จำกัด',
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
                        decoration: InputDecoration(
                          labelText:
                              isEnglish ? 'Additional (days)' : 'บวกเพิ่ม (วัน)',
                          border: const OutlineInputBorder(),
                          hintText: '0',
                        ),
                      ),
                    ),
                  ),
                ]),
                TextField(
                  controller: remarkCtrl,
                  readOnly: readOnly,
                  decoration: InputDecoration(
                    labelText: isEnglish ? 'Remark' : 'หมายเหตุ',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isEnglish ? 'Cancel' : 'ยกเลิก'),
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
              child: Text(isEnglish ? 'Save' : 'บันทึก'),
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
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
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
              // ── Bank picker ──────────────────────────────────────────────
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
                              tooltip: isEnglish ? 'Select Bank' : 'เลือกธนาคาร',
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
                decoration: InputDecoration(
                    labelText: isEnglish ? 'Account Number' : 'เลขที่บัญชี',
                    border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                readOnly: readOnly,
                controller: _accNameCtrl,
                decoration: InputDecoration(
                    labelText: isEnglish ? 'Account Name' : 'ชื่อบัญชี',
                    border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _accType,
                decoration: InputDecoration(
                    labelText: isEnglish ? 'Account Type' : 'ประเภทบัญชี',
                    border: const OutlineInputBorder()),
                items: [
                  DropdownMenuItem(
                      value: 'current',
                      child: Text(isEnglish ? 'Current' : 'กระแสรายวัน')),
                  DropdownMenuItem(
                      value: 'savings',
                      child: Text(isEnglish ? 'Savings' : 'ออมทรัพย์')),
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
// Main Detail Widget
// ---------------------------------------------------------------------------
class ArCustomerDetailWidget extends StatefulWidget {
  final Mode mode;
  final ArCustomer? selected;
  final Function(ArCustomer) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;
  // เพิ่มขึ้นทุกครั้งที่ผู้ใช้กดปุ่มเพิ่ม/แก้ไข/ดู/ยกเลิกจากหน้าจอหลัก — ใช้บังคับให้ didUpdateWidget เคลียร์ฟอร์ม
  // เสมอ แม้ mode/selected จะ "เหมือนเดิม" กับครั้งก่อน (เช่น กดเพิ่มลูกค้าซ้ำหลังพิมพ์ข้อมูลค้างไว้)
  final int requestSeq;
  // แบบ B (2026-11-28): สำเนาเป็นลูกค้าใหม่ + ปุ่มของแถบหัว (null = ไม่มีสิทธิ์/ยังโหลดไม่ครบ)
  final ArCustomer? copyFrom;
  final VoidCallback? onEdit;
  final VoidCallback? onCopy;
  final VoidCallback? onDelete;

  const ArCustomerDetailWidget({
    super.key,
    required this.mode,
    this.selected,
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
  State<ArCustomerDetailWidget> createState() => ArCustomerDetailWidgetState();
}

class ArCustomerDetailWidgetState extends State<ArCustomerDetailWidget> with ImMasterKit {
  final _formKey = GlobalKey<FormState>();

  @override
  bool get kitEnglish => _isEnglish;
  @override
  bool get kitReadOnly => widget.mode == Mode.view;

  // ตัวเลขสรุป/อายุหนี้/ที่มาบัญชีลูกหนี้ (เฉพาะลูกค้าที่บันทึกแล้ว)
  ArCustomerSummary? _summary;
  bool _summaryLoading = false;
  int? _summaryFor;

  // แก้ไขค้าง → หน้าจอหลักถามก่อนเปลี่ยนลูกค้า
  String _snapshot = '';
  bool get isDirty => !kitReadOnly && !widget.isPlaceholder && _fingerprint() != _snapshot;
  bool get _isCopy => widget.mode == Mode.add && widget.copyFrom != null;

  late TextEditingController _codeCtrl;
  late TextEditingController _nameThCtrl;
  late TextEditingController _nameEnCtrl;
  late TextEditingController _taxIdCtrl;
  late TextEditingController _taxBranchCtrl;
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
  // true เมื่อระเบียนนี้ถูกสร้าง (ครั้งแรก) โดยรหัสถูกออกอัตโนมัติ — ล็อกกลุ่มลูกค้าถาวร ไม่ขึ้นกับ setting ปัจจุบันของกลุ่ม
  bool _isCodeAutoGenerated = false;

  // effective auto-numbering:
  //   1) เลือกกลุ่ม + กลุ่มตั้งค่าอัตโนมัติ → true (ใช้ running ของกลุ่ม)
  //   2) ไม่เลือกกลุ่ม หรือ กลุ่มไม่ตั้งค่าอัตโนมัติ → ตรวจสอบ global ar_customer_running
  //   3) global ตั้งค่าอัตโนมัติ → true, มิฉะนั้น → false (ให้ผู้ใช้ใส่เอง)
  bool get _effectiveAutoNumbering {
    if (_customerGroupId != null && (_customerGroupIsAutoNumber == true)) return true;
    return _autoNumberingEnabled;
  }

  // แก้ไขระเบียนเดิม + รหัสถูกออกอัตโนมัติตอนสร้าง → ล็อกกลุ่มลูกค้าถาวร เปลี่ยนกลุ่มไม่ได้
  bool get _groupLocked => widget.mode == Mode.edit && _isCodeAutoGenerated;

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
  // พนักงานขาย (หลายคน + สัดส่วน %, คนหลักติดดาว)
  List<DocSalesperson> _salespersons = [];
  // cache รายชื่อพนักงานขายในเขตที่เลือก
  List<TerritoryMember> _territoryMembers = [];
  // ผู้วางบิล
  int? _billingCollectorId;
  String? _billingCollectorCode;
  String? _billingCollectorNameThai;
  // ผู้รับชำระ
  int? _collectionCollectorId;
  String? _collectionCollectorCode;
  String? _collectionCollectorNameThai;
  // รหัสตารางราคา (im_price_list) — ลูกค้ารายนี้ใช้ได้รหัสเดียวเท่านั้น เพื่อเชื่อมไปหาราคาสินค้าใน
  // im_price_list_detail แยกจาก customerGroupId (นโยบายบัญชี/เครดิต) โดยสิ้นเชิง
  int? _priceListId;
  String? _priceListCode;
  String? _priceListName;

  bool _isSaving = false;
  bool _isEnglish = false;

  @override
  void initState() {
    super.initState();
    _initFromSelected(_source);
    _loadSummary();
    _loadBusinessTypes();
    _loadCustomerGroups();
    _loadCurrencies();
    _loadAutoNumberingConfig();
    _loadControlAccounts();
    if (_salesTerritoryId != null) {
      _loadTerritoryMembers(_salesTerritoryId!);
    }
    // สำหรับ record ใหม่ ให้ default สกุลเงินหลักจาก cd_currency
    if (widget.selected == null && widget.copyFrom == null) _loadDefaultCurrency();
  }

  // ข้อมูลตั้งต้นของฟอร์ม: เพิ่มแบบสำเนา = ลูกค้าต้นฉบับ (ล้างรหัส/เลขผู้เสียภาษี/รหัสเดิม), เพิ่มใหม่ = ว่าง
  ArCustomer? get _source => widget.mode == Mode.add ? widget.copyFrom : widget.selected;

  // ค่าที่โหลดตามหลังมาเปลี่ยนฟอร์ม — ถ้ายังไม่ได้แก้อะไรให้ถือว่ายังไม่แก้
  void _keepClean(VoidCallback fn) {
    final wasClean = _fingerprint() == _snapshot;
    setState(fn);
    if (wasClean) _snapshot = _fingerprint();
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
      final s = await Provider.of<ArCustomerService>(context, listen: false).fetchSummary(id);
      if (mounted && _summaryFor == id) setState(() => _summary = s);
    } catch (_) {
      if (mounted && _summaryFor == id) setState(() => _summary = null);
    } finally {
      if (mounted && _summaryFor == id) setState(() => _summaryLoading = false);
    }
  }

  Future<void> _loadDefaultCurrency() async {
    final code = await Provider.of<CurrencyService>(context, listen: false)
        .getBaseCurrencyCode();
    if (mounted) _keepClean(() => _selectedCurrencyCode = code);
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
        _keepClean(() {
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
        _keepClean(() => _autoNumberingEnabled = config.isAutoNumbering);
      }
    } catch (_) {}
  }

  Future<void> _loadCurrencies() async {
    try {
      final list = await Provider.of<CurrencyService>(context, listen: false)
          .fetchActiveRows();
      if (mounted) {
        _keepClean(() {
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
        _keepClean(() {
          _controlAccounts = list.where((a) => a.isControlAccount && a.isNormalAccount && a.isActive).toList();
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
    // สำเนาเป็นลูกค้าใหม่: ไม่เอารหัส / เลขผู้เสียภาษี / รหัสเดิม (ต้องไม่ซ้ำต่อราย)
    final copy = widget.mode == Mode.add && c != null;
    _autoCodeOverridden = false;
    _codeCtrl        = TextEditingController(text: copy ? '' : c?.customerCode ?? '');
    _nameThCtrl      = TextEditingController(text: c?.customerNameTh ?? '');
    _nameEnCtrl      = TextEditingController(text: c?.customerNameEn ?? '');
    _taxIdCtrl           = TextEditingController(text: copy ? '' : c?.taxId ?? '');
    _taxBranchCtrl       = TextEditingController(text: c?.taxBranchCode ?? '');
    _oldCustomerCodeCtrl = TextEditingController(text: copy ? '' : c?.oldCustomerCode ?? '');
    _creditTermMonthsCtrl = TextEditingController(text: (c?.creditTermMonths ?? 0).toString());
    _creditTermDaysCtrl   = TextEditingController(text: (c?.creditTermDays ?? 30).toString());
    _creditLimitCtrl = TextEditingController(text: (c?.creditLimit ?? 0).toStringAsFixed(2));
    _discountPercentCtrl = TextEditingController(text: (c?.discountPercent ?? 0).toStringAsFixed(2));
    _remarkCtrl      = TextEditingController(text: c?.remark ?? '');
    _selectedCurrencyCode = c?.currencyCode ?? CurrencyService.baseCode;
    _selectedCurrencyNameThai = null;
    _businessTypeId        = c?.businessTypeId;
    _businessTypeCode      = c?.businessTypeCode;
    _businessTypeNameThai  = c?.businessTypeNameThai;
    _customerGroupId   = c?.customerGroupId;
    _customerGroupCode = c?.customerGroupCode;
    _customerGroupName = c?.customerGroupName;
    _customerGroupIsAutoNumber = null; // will be resolved after _loadCustomerGroups
    _isCodeAutoGenerated = copy ? false : c?.isCodeAutoGenerated ?? false;
    if (_customerGroupId != null) {
      final g = _customerGroups.where((g) => g.id == _customerGroupId).firstOrNull;
      if (g != null) _customerGroupIsAutoNumber = g.isAutoNumber;
    }
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
    _salespersons        = List.from(c?.salespersons ?? const <DocSalesperson>[]);
    _territoryMembers = [];
    _billingCollectorId        = c?.billingCollectorId;
    _billingCollectorCode      = c?.billingCollectorCode;
    _billingCollectorNameThai  = c?.billingCollectorNameThai;
    _collectionCollectorId        = c?.collectionCollectorId;
    _collectionCollectorCode      = c?.collectionCollectorCode;
    _collectionCollectorNameThai  = c?.collectionCollectorNameThai;
    _priceListId   = c?.priceListId;
    _priceListCode = c?.priceListCode;
    _priceListName = c?.priceListName;
    _requiresBilling    = c?.requiresBilling ?? false;
    _billingConditions  = List.from(c?.billingConditions ?? []);
    _paymentConditions  = List.from(c?.paymentConditions ?? []);
    _snapshot = _fingerprint();
  }

  @override
  void didUpdateWidget(covariant ArCustomerDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = widget.selected != oldWidget.selected ||
        widget.mode != oldWidget.mode ||
        widget.requestSeq != oldWidget.requestSeq ||
        widget.copyFrom != oldWidget.copyFrom;
    if (!changed) return;
    final sameRecord = widget.selected?.id != null && widget.selected?.id == oldWidget.selected?.id;
    // ข้อมูลเต็มโหลดตามมาทีหลัง (mode/seq เดิม) — ไม่ล้างตำแหน่งเลื่อน
    final onlyFullLoad = sameRecord && widget.mode == oldWidget.mode && widget.requestSeq == oldWidget.requestSeq;
    _disposeControllers();
    _initFromSelected(_source);
    if (widget.mode == Mode.add && oldWidget.mode != Mode.add) _loadAutoNumberingConfig();
    if (widget.mode == Mode.add && widget.copyFrom == null) _loadDefaultCurrency();
    if (!sameRecord) _summaryFor = null;
    _loadSummary();
    final tid = _salesTerritoryId;
    if (tid != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _salesTerritoryId == tid) _loadTerritoryMembers(tid);
      });
    }
    if (!onlyFullLoad) kScrollTop();
    setState(() {});
  }

  void _disposeControllers() {
    for (final c in [
      _codeCtrl, _nameThCtrl, _nameEnCtrl, _taxIdCtrl, _taxBranchCtrl, _oldCustomerCodeCtrl,
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

    final isEnglish = _isEnglish;
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
                      bt.businessTypeNameThai.toLowerCase().contains(lq) ||
                      bt.businessTypeNameEng.toLowerCase().contains(lq))
                  .toList();
            }
          });
        }

        return AlertDialog(
          title: Text(isEnglish ? 'Select Business Type' : 'เลือกประเภทธุรกิจ'),
          content: SizedBox(
            width: 480,
            height: 380,
            child: Column(
              children: [
                TextField(
                  controller: searchCtrl,
                  autofocus: true,
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
                                          child: Text(isEnglish && bt.businessTypeNameEng.isNotEmpty
                                              ? bt.businessTypeNameEng
                                              : bt.businessTypeNameThai)),
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
              child: Text(isEnglish ? 'Close' : 'ปิด'),
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

  String _customerGroupDisplayName(bool isEnglish) {
    if (_customerGroupId != null && isEnglish) {
      final match = _customerGroups.where((g) => g.id == _customerGroupId);
      if (match.isNotEmpty && match.first.groupNameEng.isNotEmpty) {
        return match.first.groupNameEng;
      }
    }
    return _customerGroupName ?? '';
  }

  String _arAccountDisplayName(bool isEnglish) {
    if (_arAccountId != null && isEnglish) {
      final match = _controlAccounts.where((a) => a.id == _arAccountId);
      if (match.isNotEmpty && match.first.accountNameEng.isNotEmpty) {
        return match.first.accountNameEng;
      }
    }
    return _arAccountNameThai ?? '';
  }

  Future<void> _pickCustomerGroup({bool restrictToNonAuto = false}) async {
    if (_customerGroups.isEmpty) await _loadCustomerGroups();
    if (!mounted) return;
    final isEnglish = _isEnglish;
    final searchCtrl = TextEditingController();
    final List<ArCustomerGroup> candidates = restrictToNonAuto
        ? _customerGroups.where((g) => !g.isAutoNumber).toList()
        : _customerGroups;
    List<ArCustomerGroup> filtered = List.from(candidates);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlgState) {
        void doFilter(String q) {
          setDlgState(() {
            if (q.isEmpty) {
              filtered = List.from(candidates);
            } else {
              final lq = q.toLowerCase();
              filtered = candidates
                  .where((g) =>
                      g.groupCode.toLowerCase().contains(lq) ||
                      g.groupNameThai.toLowerCase().contains(lq) ||
                      g.groupNameEng.toLowerCase().contains(lq))
                  .toList();
            }
          });
        }

        return AlertDialog(
          title: Text(isEnglish ? 'Select Customer Group' : 'เลือกกลุ่มลูกค้า'),
          content: SizedBox(
            width: 480,
            height: 380,
            child: Column(
              children: [
                TextField(
                  controller: searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: isEnglish ? 'Search code / customer group name' : 'ค้นหา รหัส / ชื่อกลุ่มลูกค้า',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onChanged: doFilter,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _customerGroups.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : filtered.isEmpty
                          ? Center(child: Text(isEnglish ? 'No data found' : 'ไม่พบข้อมูล'))
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
                                      Expanded(child: Text(isEnglish && g.groupNameEng.isNotEmpty
                                          ? g.groupNameEng
                                          : g.groupNameThai)),
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
              child: Text(isEnglish ? 'Close' : 'ปิด'),
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
    final isEnglish = _isEnglish;
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
                      c.currencyNameThai.toLowerCase().contains(lq) ||
                      c.currencyNameEng.toLowerCase().contains(lq))
                  .toList();
            }
          });
        }

        return AlertDialog(
          title: Text(isEnglish ? 'Select Currency' : 'เลือกสกุลเงิน'),
          content: SizedBox(
            width: 480,
            height: 380,
            child: Column(
              children: [
                TextField(
                  controller: searchCtrl,
                  autofocus: true,
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
                                      Expanded(child: Text(isEnglish && c.currencyNameEng.isNotEmpty
                                          ? c.currencyNameEng
                                          : c.currencyNameThai)),
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
              child: Text(isEnglish ? 'Close' : 'ปิด'),
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
    final isEnglish = _isEnglish;
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
                      a.accountNameThai.toUpperCase().contains(lq) ||
                      a.accountNameEng.toUpperCase().contains(lq))
                  .toList();
            }
          });
        }

        return AlertDialog(
          title: Text(isEnglish ? 'Select Receivable Account' : 'เลือกบัญชีลูกหนี้'),
          content: SizedBox(
            width: 520,
            height: 400,
            child: Column(
              children: [
                TextField(
                  controller: searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: isEnglish ? 'Search code / account name' : 'ค้นหา รหัส / ชื่อบัญชี',
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
                                      Expanded(child: Text(isEnglish && a.accountNameEng.isNotEmpty
                                          ? a.accountNameEng
                                          : a.accountNameThai)),
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
              child: Text(isEnglish ? 'Close' : 'ปิด'),
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
    setState(() => _territoryMembers = []);
    try {
      final rows = await Provider.of<SalesTerritoryService>(context, listen: false)
          .fetchMembers(territoryId);
      if (mounted) setState(() => _territoryMembers = rows);
    } catch (_) {}
  }

  Future<void> _pickSalesTerritory() async {
    final territories = await Provider.of<SalesTerritoryService>(
            context, listen: false)
        .fetchRows();
    if (!mounted) return;
    final isEnglish = _isEnglish;
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
                      t.territoryNameThai.toUpperCase().contains(up) ||
                      (t.territoryNameEng?.toUpperCase().contains(up) ?? false))
                  .toList();
            }
          });
        }

        return AlertDialog(
          title: Text(isEnglish ? 'Select Sales Territory' : 'เลือกเขตการขาย',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 500,
            height: 520,
            child: Column(
              children: [
                TextField(
                  autofocus: true,
                  controller: searchCtrl,
                  decoration: InputDecoration(
                    hintText: isEnglish ? 'Search (code / territory name)' : 'ค้นหา (รหัส / ชื่อเขต)',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: doFilter,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(child: Text(isEnglish ? 'No data found' : 'ไม่พบข้อมูล'))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final t = filtered[i];
                            final tName = isEnglish && (t.territoryNameEng?.isNotEmpty ?? false)
                                ? t.territoryNameEng!
                                : t.territoryNameThai;
                            return ListTile(
                              leading: Icon(Icons.map_outlined,
                                  color: t.isActive
                                      ? Colors.teal[600]
                                      : Colors.grey,
                                  size: 20),
                              title: Text('${t.territoryCode} — $tName'),
                              subtitle: t.parentNameThai != null
                                  ? Text(isEnglish ? 'Parent: ${t.parentNameThai}' : 'ขึ้นกับ: ${t.parentNameThai}',
                                      style: const TextStyle(fontSize: 12))
                                  : null,
                              enabled: t.isActive,
                              onTap: () {
                                setState(() {
                                  _salesTerritoryId       = t.id;
                                  _salesTerritoryCode     = t.territoryCode;
                                  _salesTerritoryNameThai = t.territoryNameThai;
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
                child: Text(isEnglish ? 'Close' : 'ปิด')),
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
      _territoryMembers    = [];
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

  // ─── ตารางราคา ───────────────────────────────────────────────────────────────
  Future<void> _pickPriceList() async {
    await ImPriceListListWidget.search(context, listType: 'SALES', onSelected: (h) {
      if (mounted) {
        setState(() {
          _priceListId   = h.id;
          _priceListCode = h.priceListCode;
          _priceListName = h.priceListName;
        });
      }
    });
  }

  void _clearPriceList() {
    setState(() {
      _priceListId   = null;
      _priceListCode = null;
      _priceListName = null;
    });
  }

  // ข้อมูลในฟอร์มเป็น ArCustomer (ใช้ทั้งตอนบันทึกและตรวจว่ามีแก้ไขค้าง)
  ArCustomer _buildCustomer() => ArCustomer(
        id: widget.mode == Mode.add ? null : widget.selected?.id,
        // ถ้า auto-numbering เปิดและไม่ได้แก้ไขเอง → ส่งค่าว่าง ให้ backend generate
        customerCode: (widget.mode == Mode.add && _effectiveAutoNumbering && !_autoCodeOverridden)
            ? ''
            : _codeCtrl.text.trim(),
        customerNameTh: _nameThCtrl.text.trim(),
        customerNameEn: _nameEnCtrl.text.trim().isEmpty ? null : _nameEnCtrl.text.trim(),
        taxId: _taxIdCtrl.text.trim().isEmpty ? null : _taxIdCtrl.text.trim(),
        taxBranchCode: normalizeTaxBranch(_taxBranchCtrl.text),
        oldCustomerCode: _oldCustomerCodeCtrl.text.trim().isEmpty ? null : _oldCustomerCodeCtrl.text.trim(),
        businessTypeId: _businessTypeId,
        customerGroupId: _customerGroupId,
        creditTermMonths: int.tryParse(_creditTermMonthsCtrl.text) ?? 0,
        creditTermDays: int.tryParse(_creditTermDaysCtrl.text) ?? 30,
        creditLimit: double.tryParse(_creditLimitCtrl.text) ?? 0,
        discountPercent: double.tryParse(_discountPercentCtrl.text) ?? 0,
        currencyCode: _selectedCurrencyCode ?? CurrencyService.baseCode,
        isActive: _isActive,
        remark: _remarkCtrl.text.trim().isEmpty ? null : _remarkCtrl.text.trim(),
        requiresBilling: _requiresBilling,
        billingConditions: List.from(_billingConditions),
        paymentConditions: List.from(_paymentConditions),
        arAccountId: _arAccountId,
        salesTerritoryId: _salesTerritoryId,
        salespersonId: _salespersons.where((e) => e.isPrimary).firstOrNull?.salespersonId,
        salespersons: List.from(_salespersons),
        billingCollectorId: _billingCollectorId,
        collectionCollectorId: _collectionCollectorId,
        priceListId: _priceListId,
        addresses: List.from(_addresses),
        contacts: List.from(_contacts),
        bankAccounts: List.from(_bankAccounts),
      );

  String _fingerprint() {
    try {
      return jsonEncode(_buildCustomer().toJson());
    } catch (_) {
      return '';
    }
  }

  Future<void> _submitForm() async {
    final isEnglish = _isEnglish;
    String? err;
    if (_nameThCtrl.text.trim().isEmpty) {
      err = isEnglish ? 'Please enter the customer name (TH)' : 'กรุณาป้อนชื่อลูกค้า (ไทย)';
    } else if (widget.mode == Mode.add && (!_effectiveAutoNumbering || _autoCodeOverridden) && _codeCtrl.text.trim().isEmpty) {
      err = isEnglish ? 'Please enter the customer code' : 'กรุณาป้อนรหัสลูกค้า';
    }
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await widget.onSubmit(_buildCustomer());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish ? 'An error occurred: $e' : 'เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── ตัวช่วยแสดงผล ─────────────────────────────────────────────────────────
  static final _money = NumberFormat('#,##0.00');
  String _m(double v) => _money.format(v);
  String _dt(DateTime? d) => d == null ? '' : _previewDateFmt.format(d);

  ArCustomerGroup? get _groupObj =>
      _customerGroupId == null ? null : _customerGroups.where((g) => g.id == _customerGroupId).firstOrNull;
  bool _sameInt(TextEditingController c, int v) => int.tryParse(c.text.trim()) == v;
  bool _sameNum(TextEditingController c, double v) => ((double.tryParse(c.text.trim()) ?? double.nan) - v).abs() < 0.005;

  String _groupLabel(bool e) =>
      _customerGroupId == null ? '' : '${_customerGroupCode ?? ''} ${_customerGroupDisplayName(e)}'.trim();
  String _bizTypeLabel(bool e) {
    if (_businessTypeId == null) return '';
    final bt = _businessTypes.where((b) => b.id == _businessTypeId).firstOrNull;
    final name = e && (bt?.businessTypeNameEng.isNotEmpty ?? false) ? bt!.businessTypeNameEng : (_businessTypeNameThai ?? '');
    return '${_businessTypeCode ?? ''} $name'.trim();
  }

  String _currencyLabel(bool e) {
    if (_selectedCurrencyCode == null) return '';
    final c = _currencies.where((c) => c.currencyCode == _selectedCurrencyCode).firstOrNull;
    final name = c == null ? (_selectedCurrencyNameThai ?? '') : (e && c.currencyNameEng.isNotEmpty ? c.currencyNameEng : c.currencyNameThai);
    return name.isEmpty ? _selectedCurrencyCode! : '$_selectedCurrencyCode $name';
  }

  // ─── ช่องรหัสลูกค้า (ออกอัตโนมัติ / กรอกเอง) ───────────────────────────────────
  Widget _codeField() {
    final e = _isEnglish;
    final isAdd = widget.mode == Mode.add;
    if (isAdd && _effectiveAutoNumbering && !_autoCodeOverridden) {
      return InputDecorator(
        decoration: kDec(e ? 'Customer code' : 'รหัสลูกค้า', auto: true),
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
        Expanded(child: kTxt(e ? 'Customer code *' : 'รหัสลูกค้า *', _codeCtrl, cap: TextCapitalization.characters)),
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
    return kTxt(e ? 'Customer code *' : 'รหัสลูกค้า *', _codeCtrl, editable: isAdd, cap: TextCapitalization.characters);
  }

  // ─── ส่วนที่ 1: ข้อมูลลูกค้า (4 กลุ่มสี) ────────────────────────────────────────
  Widget _mainCard() {
    final e = _isEnglish;
    final g = _groupObj;
    final termFromGroup = g != null && _sameInt(_creditTermMonthsCtrl, g.creditTermMonths) && _sameInt(_creditTermDaysCtrl, g.creditTermDays);
    final limitFromGroup = g != null && _sameNum(_creditLimitCtrl, g.creditLimit);
    final discFromGroup = g != null && _sameNum(_discountPercentCtrl, g.discountPercent);
    final branchText = taxBranchLabel(normalizeTaxBranch(_taxBranchCtrl.text), e);
    return kCard(
      title: e ? 'Customer details' : 'ข้อมูลลูกค้า',
      trailing: kLegend(),
      child: kGroups([
        kGroup(1, e ? 'Main' : 'ข้อมูลหลัก', ImKit.gDoc, [
          kRow([_codeField(), kTxt(e ? 'Old customer code' : 'รหัสเดิม', _oldCustomerCodeCtrl)]),
          kTxt(e ? 'Customer name (TH) *' : 'ชื่อลูกค้า (ไทย) *', _nameThCtrl),
          kTxt(e ? 'Customer name (EN)' : 'ชื่อลูกค้า (อังกฤษ)', _nameEnCtrl),
          kRow([
            kTxt(e ? 'Tax ID' : 'เลขผู้เสียภาษี', _taxIdCtrl, digitsOnly: true),
            kTxt(e ? 'Tax branch (5 digits)' : 'สาขา (5 หลัก)', _taxBranchCtrl, digitsOnly: true),
          ]),
          if (branchText.isNotEmpty) kNote(branchText),
          kRow([
            kFk(
              label: e ? 'Customer group' : 'กลุ่มลูกค้า',
              text: _groupLabel(e),
              hasValue: _customerGroupId != null,
              onSearch: () => _pickCustomerGroup(restrictToNonAuto: widget.mode == Mode.edit && !_isCodeAutoGenerated),
              onClear: _clearGroup,
              locked: _groupLocked,
              lockedTip: e ? 'Locked — code was auto-generated by this group' : 'ล็อก — รหัสออกอัตโนมัติจากกลุ่มนี้',
            ),
            kFk(
              label: e ? 'Business type' : 'ประเภทธุรกิจ',
              text: _bizTypeLabel(e),
              hasValue: _businessTypeId != null,
              onSearch: _pickBusinessType,
              onClear: _clearBusinessType,
            ),
          ]),
        ]),
        kGroup(2, e ? 'Credit and price' : 'เครดิตและราคา', ImKit.gFin, [
          kRow([
            kTxt(e ? 'Credit term (months)' : 'เครดิต (เดือน)', _creditTermMonthsCtrl, digitsOnly: true, numeric: true, auto: termFromGroup),
            kTxt(e ? 'Credit term (days)' : 'เครดิต (วัน)', _creditTermDaysCtrl, digitsOnly: true, numeric: true, auto: termFromGroup),
          ]),
          kRow([
            kTxt(e ? 'Credit limit' : 'วงเงินเครดิต', _creditLimitCtrl, numeric: true, auto: limitFromGroup),
            kTxt(e ? 'Discount %' : 'ส่วนลด %', _discountPercentCtrl, numeric: true, auto: discFromGroup),
          ]),
          kRow([
            kFk(
              label: e ? 'Currency' : 'สกุลเงิน',
              text: _currencyLabel(e),
              hasValue: _selectedCurrencyCode != null,
              onSearch: _pickCurrency,
              onClear: _clearCurrency,
            ),
            kFk(
              label: e ? 'Price list' : 'ตารางราคา',
              text: '${_priceListCode ?? ''} ${_priceListName ?? ''}'.trim(),
              hasValue: _priceListId != null,
              onSearch: _pickPriceList,
              onClear: _clearPriceList,
            ),
          ]),
          if (g != null && (termFromGroup || limitFromGroup || discFromGroup))
            kNote(e
                ? 'Blue = same as group ${g.groupCode} (filled from the group when it was chosen)'
                : 'ช่องสีฟ้า = ค่าเดียวกับกลุ่ม ${g.groupCode} (ตั้งต้นจากกลุ่มตอนเลือกกลุ่ม)',
                color: ImKit.blue),
        ]),
        kGroup(3, e ? 'Sales' : 'การขาย', ImKit.gParty, [
          kFk(
            label: e ? 'Sales territory' : 'เขตการขาย',
            text: '${_salesTerritoryCode ?? ''} ${_salesTerritoryNameThai ?? ''}'.trim(),
            hasValue: _salesTerritoryId != null,
            onSearch: _pickSalesTerritory,
            onClear: _clearSalesTerritory,
          ),
          SalespersonSplitEditor(
            items: _salespersons,
            isEnglish: e,
            readOnly: kitReadOnly,
            showPrimary: true,
            showShares: true,
            preferredIds: _territoryMembers.map((m) => m.id).whereType<int>().toSet(),
            onChanged: (list) => setState(() => _salespersons = list),
          ),
          kRow([
            kFk(
              label: e ? 'Biller' : 'ผู้วางบิล',
              text: '${_billingCollectorCode ?? ''} ${_billingCollectorNameThai ?? ''}'.trim(),
              hasValue: _billingCollectorId != null,
              onSearch: _pickBillingCollector,
              onClear: _clearBillingCollector,
            ),
            kFk(
              label: e ? 'Collector' : 'ผู้เก็บเงิน',
              text: '${_collectionCollectorCode ?? ''} ${_collectionCollectorNameThai ?? ''}'.trim(),
              hasValue: _collectionCollectorId != null,
              onSearch: _pickCollectionCollector,
              onClear: _clearCollectionCollector,
            ),
          ]),
        ]),
        kGroup(4, e ? 'More' : 'เพิ่มเติม', ImKit.gMore, [
          kChecks([
            kCk(e ? 'Active' : 'ใช้งาน', _isActive, kitReadOnly ? null : (v) => setState(() => _isActive = v)),
            kCk(e ? 'Requires billing before payment' : 'ต้องวางบิลก่อนรับชำระ', _requiresBilling,
                kitReadOnly ? null : (v) => setState(() => _requiresBilling = v)),
          ]),
          kTxt(e ? 'Remark' : 'หมายเหตุ', _remarkCtrl),
        ]),
      ]),
    );
  }

  // ─── ส่วนที่ 2: ที่อยู่ ผู้ติดต่อ บัญชีธนาคาร ────────────────────────────────────
  String _addrTypeLabel(String t, bool e) => (e
          ? const {'billing': 'Billing', 'shipping': 'Shipping', 'billing note': 'Billing note'}
          : const {'billing': 'ออกใบกำกับ', 'shipping': 'ส่งของ', 'billing note': 'วางบิล'})[t] ??
      t;

  String _addrText(ArCustomerAddress a) => [
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

  Widget _defaultMark(bool v) => v ? ImKit.chip(_isEnglish ? 'Default' : 'หลัก', ImKit.okSoft, ImKit.ok) : kCell('');

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
      count: '${_bankAccounts.length}',
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

  // ─── ส่วนที่ 3: วางบิลและรับชำระ ─────────────────────────────────────────────
  bool _previewOpen = false;

  Future<void> _addBilling() async {
    final r = await showBillingConditionDialog(context, null, false);
    if (r != null) setState(() => _billingConditions.add(r.copyWith(sortOrder: _billingConditions.length + 1)));
  }

  Future<void> _addPayment() async {
    final r = await showPaymentConditionDialog(context, null, false);
    if (r != null) setState(() => _paymentConditions.add(r.copyWith(sortOrder: _paymentConditions.length + 1)));
  }

  Widget _conditionsCard() {
    final e = _isEnglish;
    final ro = kitReadOnly;
    final rows = <List<Widget>>[];
    final taps = <VoidCallback?>[];
    for (var i = 0; i < _billingConditions.length; i++) {
      final b = _billingConditions[i];
      rows.add([
        ImKit.chip(e ? 'Billing' : 'วางบิล', ImKit.blueSoft, ImKit.blue),
        kCell('${i + 1}', mono: true),
        Text(_billingConditionSummary(b), style: const TextStyle(fontSize: 12.5)),
        ro
            ? const SizedBox.shrink()
            : _delBtn(() => setState(() {
                  _billingConditions.removeAt(i);
                  for (var j = 0; j < _billingConditions.length; j++) {
                    _billingConditions[j] = _billingConditions[j].copyWith(sortOrder: j + 1);
                  }
                })),
      ]);
      taps.add(() async {
        final r = await showBillingConditionDialog(context, b, ro);
        if (r != null && !ro) setState(() => _billingConditions[i] = r);
      });
    }
    for (var i = 0; i < _paymentConditions.length; i++) {
      final p = _paymentConditions[i];
      rows.add([
        ImKit.chip(e ? 'Payment' : 'รับชำระ', ImKit.okSoft, ImKit.ok),
        kCell('${i + 1}', mono: true),
        Text(_paymentConditionSummary(p), style: const TextStyle(fontSize: 12.5)),
        ro
            ? const SizedBox.shrink()
            : _delBtn(() => setState(() {
                  _paymentConditions.removeAt(i);
                  for (var j = 0; j < _paymentConditions.length; j++) {
                    _paymentConditions[j] = _paymentConditions[j].copyWith(sortOrder: j + 1);
                  }
                })),
      ]);
      taps.add(() async {
        final r = await showPaymentConditionDialog(context, p, ro);
        if (r != null && !ro) setState(() => _paymentConditions[i] = r);
      });
    }
    final g = _groupObj;
    return kCard(
      title: e ? 'Billing and payment' : 'วางบิลและรับชำระ',
      count: g != null
          ? (e ? 'Choosing a group copies its conditions here' : 'เลือกกลุ่มแล้วคัดลอกเงื่อนไขของกลุ่ม ${g.groupCode} มาให้')
          : null,
      trailing: ro
          ? null
          : Wrap(spacing: 6, children: [
              kGhost(e ? 'Billing' : 'วางบิล', Icons.add, _addBilling),
              kGhost(e ? 'Payment' : 'รับชำระ', Icons.add, _addPayment),
            ]),
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        kTable(
          [
            KCol(e ? 'Condition' : 'เงื่อนไข', 2),
            KCol(e ? 'No.' : 'ลำดับ', 1),
            KCol(e ? 'Details' : 'รายละเอียด', 10),
            const KCol('', 1),
          ],
          rows,
          onTap: taps,
          minWidth: 640,
          rowMinHeight: 40,
          empty: e ? 'No conditions — payment date follows the due date' : 'ยังไม่มีเงื่อนไข — วันรับชำระเท่ากับวันครบกำหนด',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: kNote(_requiresBilling
              ? (e ? 'Billing required: due date may be counted from the billing date (per condition)' : 'ต้องวางบิล: วันครบกำหนดนับจากวันวางบิลได้ตามเงื่อนไข')
              : (e ? 'Billing not required: due date is counted from the invoice date' : 'ไม่ต้องวางบิล: วันครบกำหนดนับจากวันที่เอกสาร')),
        ),
      ]),
    );
  }

  // ─── ส่วนที่ 4: บัญชีลูกหนี้ (ลูกค้า > กลุ่ม > ประเภทเอกสาร) ──────────────────────
  Widget _accountCard() {
    final e = _isEnglish;
    final s = _summary;
    final g = _groupObj;
    // บัญชีของกลุ่ม: จากสรุป (บันทึกแล้ว) หรือจากรายการกลุ่ม (ฟอร์มปัจจุบัน)
    final groupCode = g?.groupCode ?? s?.groupCode;
    String? groupAcc;
    if (g != null && g.glAccountId != null) {
      final acc = _controlAccounts.where((a) => a.id == g.glAccountId).firstOrNull;
      final nm = acc == null ? (g.glAccountNameThai ?? '') : (e && acc.accountNameEng.isNotEmpty ? acc.accountNameEng : acc.accountNameThai);
      groupAcc = '${g.glAccountCode ?? acc?.accountCode ?? ''} $nm'.trim();
    } else if (g == null && s?.groupAccount != null && _customerGroupId != null) {
      groupAcc = '${s!.groupAccount!.code} ${s.groupAccount!.name(e)}';
    }
    final hasCustomer = _arAccountId != null;
    final hasGroup = _customerGroupId != null && groupAcc != null;
    Widget status(bool used, bool skipped, String? usedText) => used
        ? ImKit.chip(usedText ?? (e ? 'Used' : 'ใช้บัญชีนี้'), ImKit.okSoft, ImKit.ok)
        : skipped
            ? ImKit.chip(e ? 'Not used' : 'ไม่ใช้', ImKit.ro, ImKit.ink2)
            : ImKit.chip(e ? 'Empty, skip' : 'ว่าง ข้าม', ImKit.ro, ImKit.ink3);
    final docTypes = s?.docTypeAccounts ?? const <ArDocTypeAccount>[];
    final docText = docTypes.isEmpty
        ? (e ? 'As set per AR document type (AR GL setup)' : 'ตามที่ตั้งไว้แต่ละประเภทเอกสาร (ตั้งค่าบัญชี GL ของ AR)')
        : docTypes.map((d) => '${d.docCode} ${d.account?.code ?? '—'}').join(' · ');
    return kCard(
      title: e ? 'Receivable account' : 'รหัสบัญชีลูกหนี้',
      count: e ? 'Order used: customer › group › document type' : 'ลำดับที่ใช้: ลูกค้า › กลุ่มลูกค้า › ประเภทเอกสาร',
      trailing: kGhost(e ? 'AR GL setup' : 'ตั้งค่าบัญชี GL', Icons.open_in_new,
          () => ImKit.openMenu(context, 'ArGlAccountSetupScreen', 'ตั้งค่าบัญชี GL ของ AR', 'AR GL Account Setup', e)),
      padding: EdgeInsets.zero,
      child: kTable(
        [KCol(e ? 'Level' : 'ระดับ', 3), KCol(e ? 'Account' : 'บัญชี', 8), KCol(e ? 'Status' : 'สถานะ', 3)],
        [
          [
            kCell(e ? 'This customer' : 'ลูกค้านี้', bold: true),
            SizedBox(
              width: double.infinity,
              child: kFk(
                label: '',
                text: '${_arAccountCode ?? ''} ${_arAccountDisplayName(e)}'.trim(),
                hasValue: hasCustomer,
                onSearch: _pickArAccount,
                onClear: _clearArAccount,
              ),
            ),
            status(hasCustomer, false, null),
          ],
          [
            kCell(groupCode == null ? (e ? 'Group' : 'กลุ่ม') : '${e ? 'Group' : 'กลุ่ม'} $groupCode', bold: true),
            kCell(_customerGroupId == null ? (e ? '— No group —' : '— ไม่มีกลุ่ม —') : (groupAcc ?? (e ? '— Not set —' : '— ไม่ได้ตั้ง —'))),
            status(!hasCustomer && hasGroup, hasCustomer && hasGroup, null),
          ],
          [
            kCell(e ? 'Document type' : 'ประเภทเอกสาร', bold: true),
            Text(docText, style: const TextStyle(fontSize: 12.5), maxLines: 2, overflow: TextOverflow.ellipsis),
            status(!hasCustomer && !hasGroup, hasCustomer || hasGroup, e ? 'Used' : 'ใช้ระดับนี้'),
          ],
        ],
        minWidth: 640,
        rowMinHeight: 48,
      ),
    );
  }

  // ─── ส่วนที่ 5: ยอดค้างตามอายุหนี้ + เอกสารค้างเก่าสุด (อ่านอย่างเดียว) ──────────────────
  void _openAging() => ImKit.openMenu(context, 'ArAgingReportScreen', 'รายงานอายุลูกหนี้', 'AR Aging Report', _isEnglish);

  Widget _agingCard() {
    final e = _isEnglish;
    final s = _summary;
    Widget amt(double v, {bool warn = false}) =>
        kCell(_m(v), mono: true, color: warn && v > 0.005 ? ImKit.red : null, bold: warn && v > 0.005);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      kCard(
        title: e ? 'Outstanding by age' : 'ยอดค้างตามอายุหนี้',
        count: e ? 'Read-only · as of today · invoices and debit notes' : 'อ่านอย่างเดียว · ณ วันนี้ · ใบแจ้งหนี้และใบเพิ่มหนี้',
        trailing: kGhost(e ? 'AR aging report' : 'รายงานอายุลูกหนี้', Icons.open_in_new, _openAging),
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
          title: e ? 'Oldest open documents' : 'เอกสารค้างเก่าสุด',
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
            empty: e ? 'No open documents' : 'ไม่มีเอกสารค้าง',
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
    final lim = s.creditLimit;
    final pct = lim > 0 ? (s.creditUsed / lim * 100) : 0.0;
    final remaining = lim - s.creditUsed;
    final last = s.lastSale;
    final rcpt = s.lastReceipt;
    return kKpis([
      ImKpi(
        e ? 'Outstanding' : 'ยอดค้างชำระ',
        _m(s.outstanding),
        [
          e ? '${s.openCount} doc(s) · base currency' : '${s.openCount} ใบ · สกุลหลัก',
          if (s.openCredits > 0.005) (e ? 'less credits ${_m(s.openCredits)}' : 'หักลดหนี้/มัดจำ ${_m(s.openCredits)}'),
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
        e ? 'Credit used' : 'วงเงินที่ใช้ไป',
        lim > 0 ? '${pct.toStringAsFixed(0)}%' : (e ? 'No limit' : 'ไม่กำหนดวงเงิน'),
        lim > 0
            ? (e ? 'left ${_m(remaining)} of ${_m(lim)}' : 'คงเหลือ ${_m(remaining)} จาก ${_m(lim)}')
            : (s.unbilledDelivery > 0.005 ? (e ? 'incl. unbilled delivery ${_m(s.unbilledDelivery)}' : 'รวมส่งของรอตั้งหนี้ ${_m(s.unbilledDelivery)}') : '—'),
        warn: lim > 0 && s.creditUsed > lim + 0.005,
      ),
      ImKpi(
        e ? 'Last sale / receipt' : 'ขาย/รับชำระล่าสุด',
        last == null ? '—' : _dt(last.docDate),
        [
          if (last != null) last.docNo,
          rcpt == null ? (e ? 'no receipt yet' : 'ยังไม่มีรับชำระ') : '${e ? 'receipt' : 'รับชำระ'} ${_dt(rcpt.docDate)}',
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

    if (widget.isPlaceholder) {
      return kPlaceholder(Icons.person_outline,
          e ? 'Select a customer on the left, or press "Add customer"' : 'เลือกลูกค้าจากรายการด้านซ้าย หรือกด "เพิ่มลูกค้า"');
    }

    final ro = kitReadOnly;
    final isAdd = widget.mode == Mode.add;
    final saved = !isAdd && widget.selected?.id != null;
    final name = _nameThCtrl.text.trim().isEmpty
        ? ''
        : (e && _nameEnCtrl.text.trim().isNotEmpty ? _nameEnCtrl.text.trim() : _nameThCtrl.text.trim());
    final title = isAdd
        ? (_isCopy
            ? (e ? 'New customer (copy of ${widget.copyFrom!.customerCode})' : 'ลูกค้าใหม่ (สำเนาจาก ${widget.copyFrom!.customerCode})')
            : (e ? 'New customer' : 'ลูกค้าใหม่'))
        : name;
    final branch = taxBranchLabel(normalizeTaxBranch(_taxBranchCtrl.text), e);

    final header = kHeaderBar(
      code: isAdd ? null : widget.selected?.customerCode,
      title: title,
      badges: [
        if (!isAdd) ImKit.activeChip(_isActive, e),
        if (_customerGroupCode != null) ImKit.chip(_customerGroupCode!, ImKit.blueSoft, ImKit.blue),
        if (_requiresBilling) ImKit.chip(e ? 'Billing required' : 'ต้องวางบิล', ImKit.goldSoft, ImKit.amber),
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
        onSave: _submitForm,
        extra: [
          if (widget.onCopy != null) DocBarAction(e ? 'Copy as new' : 'สำเนาเป็นลูกค้าใหม่', widget.onCopy, fg: kInk),
        ],
      ),
    );

    return Form(
      key: _formKey,
      child: kPage(
        header: header,
        top: saved ? _kpis() : null,
        sections: [
          (0, e ? 'Main' : 'ข้อมูลหลัก', _mainCard()),
          (1, e ? 'Addresses and contacts' : 'ที่อยู่และผู้ติดต่อ',
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_addressCard(), const SizedBox(height: 12), _bankCard()])),
          (2, e ? 'Billing and payment' : 'วางบิลและรับชำระ',
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_conditionsCard(), const SizedBox(height: 12), _buildDatePreviewSection()])),
          (3, e ? 'Receivable account' : 'บัญชีลูกหนี้', _accountCard()),
          if (saved) (4, e ? 'Outstanding' : 'ยอดค้าง', _agingCard()),
        ],
      ),
    );
  }

  String _paymentConditionSummary(ArCustomerPaymentCondition p) {
    final e = _isEnglish;
    final dayNames = e
        ? const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
        : const ['อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์'];
    final weekNames = e
        ? const {1: '1st', 2: '2nd', 3: '3rd', 4: '4th', -1: 'Last'}
        : const {1: 'แรก', 2: 'ที่2', 3: 'ที่3', 4: 'ที่4', -1: 'สุดท้าย'};
    final parts = <String>[];
    if (p.paymentDayOfMonth.isNotEmpty) {
      parts.add(p.paymentDayOfMonth
          .map((d) => d == 31 ? (e ? 'End of month' : 'สิ้นเดือน') : (e ? 'Day $d' : 'วันที่ $d'))
          .join(', '));
    }
    if (p.paymentDayOfWeek.isNotEmpty) {
      parts.add((e ? '' : 'วัน') + p.paymentDayOfWeek.map((d) => dayNames[d]).join('-'));
    }
    if (p.paymentWeekOfMonth.isNotEmpty) {
      parts.add((e ? 'Week ' : 'สัปดาห์') + p.paymentWeekOfMonth.map((w) => weekNames[w] ?? '$w').join('/'));
    }
    if (p.withinMonthsFromBilling > 0) {
      parts.add(e ? 'Within ${p.withinMonthsFromBilling} month(s) of billing' : 'ภายใน ${p.withinMonthsFromBilling} เดือนจากวางบิล');
    }
    if (p.additionalDays != 0) parts.add(e ? '+${p.additionalDays} day(s)' : '+${p.additionalDays} วัน');
    if (p.paymentTimeFrom != null || p.paymentTimeTo != null) {
      parts.add('${p.paymentTimeFrom ?? ''}–${p.paymentTimeTo ?? ''}');
    }
    return parts.isEmpty ? (e ? '(No condition specified)' : '(ไม่ระบุเงื่อนไข)') : parts.join('  ·  ');
  }

  // ─── Date Preview Helpers ──────────────────────────────────────────────────

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
    final useFromBilling = _billingConditions.any((c) => c.dueFromBillingDate);
    var base = useFromBilling ? (billingDate ?? invoiceDate) : invoiceDate;
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

  static const _enMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  // แปลง list วันที่ → ช่วง เช่น [1,2,3,7,8] → "1-3, 7-8"
  String _formatDayRanges(List<int> days) {
    if (days.isEmpty) return '';
    final isEnglish = _isEnglish;
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
    return isEnglish
        ? 'Day ${ranges.join(', ')}'
        : 'วันที่ ${ranges.join(', ')}';
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
    final isEnglish = _isEnglish;
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
      billingDetail = isEnglish
          ? 'No billing condition — uses invoice date'
          : 'ไม่มีเงื่อนไขวางบิล — ใช้วันที่ invoice';
    } else {
      final c = _billingConditions.reduce(
          (a, b) => a.sortOrder <= b.sortOrder ? a : b);
      billingDetail = _billingConditionSummary(c);
    }

    String dueDetail;
    if (months == 0 && days == 0) {
      dueDetail = isEnglish
          ? 'Due immediately (credit term 0)'
          : 'ชำระทันที (ระยะเครดิต 0)';
    } else {
      final parts = <String>[];
      if (months > 0) parts.add(isEnglish ? '$months month(s)' : '$months เดือน');
      if (days > 0)   parts.add(isEnglish ? '$days day(s)' : '$days วัน');
      final base = isEnglish
          ? (useFromBilling ? 'billing date' : 'invoice date')
          : (useFromBilling ? 'วันวางบิล' : 'วันที่ invoice');
      dueDetail = isEnglish
          ? 'From $base + ${parts.join(' ')}'
          : 'นับจาก$base + ${parts.join(' ')}';
    }

    String paymentDetail;
    if (_paymentConditions.isEmpty) {
      paymentDetail = isEnglish
          ? 'No payment condition — follows due date'
          : 'ไม่มีเงื่อนไขรับชำระ — ตามวันครบกำหนด';
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

    return kCard(
      title: isEnglish ? 'Date calculation preview' : 'ตัวอย่างการคำนวณวันที่',
      collapsed: !_previewOpen,
      onToggle: () => setState(() => _previewOpen = !_previewOpen),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Input: วันที่ Invoice
        Row(children: [
          Text(isEnglish ? 'Invoice Date' : 'วันที่ Invoice',
              style: const TextStyle(fontSize: 13)),
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
          isEnglish ? 'Billing Date' : 'วันวางบิล',
          billing ?? invoice,
          billingDetail,
        ),
        resultRow(
          Icons.event_available,
          Colors.green[700]!,
          isEnglish ? 'Due Date' : 'วันครบกำหนด',
          due,
          dueDetail,
        ),
        resultRow(
          Icons.payments_outlined,
          Colors.orange[700]!,
          isEnglish ? 'Payment Date' : 'วันรับชำระ',
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

          final monthLabel = isEnglish
              ? '${_enMonths[invoice.month - 1]} ${invoice.year}'
              : '${_thMonths[invoice.month - 1]} ${invoice.year + 543}';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEnglish
                    ? 'Suitable invoice date range in $monthLabel'
                    : 'ช่วงวันที่ invoice ในเดือน $monthLabel',
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

                final delayText = isEnglish
                    ? (minD == maxD
                        ? '$minD day(s) before due'
                        : '$minD–$maxD day(s) before due')
                    : (minD == maxD
                        ? 'ห่างครบกำหนด $minD วัน'
                        : 'ห่างครบกำหนด $minD–$maxD วัน');

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
                      isEnglish
                          ? '  →  bill ${_previewDateFmt.format(billing)}'
                              '  →  pay ${_previewDateFmt.format(pmt)}'
                          : '  →  วางบิล ${_previewDateFmt.format(billing)}'
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
      ]),
    );
  }

  String _billingConditionSummary(ArCustomerBillingCondition b) {
    final isEnglish = _isEnglish;
    final dayNames = isEnglish
        ? ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
        : ['อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์'];
    final weekNames = isEnglish
        ? {1: '1st', 2: '2nd', 3: '3rd', 4: '4th', -1: 'Last'}
        : {1: 'แรก', 2: 'ที่2', 3: 'ที่3', 4: 'ที่4', -1: 'สุดท้าย'};
    final parts = <String>[];
    if (b.billWithDelivery) {
      parts.add(isEnglish ? 'Bill with delivery' : 'วางบิลพร้อมส่งของ');
    }
    if (b.billingDayOfMonth.isNotEmpty) {
      final days = b.billingDayOfMonth
          .map((d) => d == 31
              ? (isEnglish ? 'End of month' : 'สิ้นเดือน')
              : (isEnglish ? 'Day $d' : 'วันที่ $d'))
          .join(', ');
      parts.add(days);
    }
    if (b.billingDayOfWeek.isNotEmpty) {
      parts.add((isEnglish ? '' : 'วัน') +
          b.billingDayOfWeek.map((d) => dayNames[d]).join('-'));
    }
    if (b.billingWeekOfMonth.isNotEmpty) {
      parts.add((isEnglish ? 'Week ' : 'สัปดาห์') +
          b.billingWeekOfMonth.map((w) => weekNames[w] ?? '$w').join('/'));
    }
    if (b.billingTimeFrom != null || b.billingTimeTo != null) {
      parts.add('${b.billingTimeFrom ?? ''}–${b.billingTimeTo ?? ''}');
    }
    if (b.dueFromBillingDate) {
      parts.add(isEnglish ? 'Due from billing date' : 'due นับจากวางบิล');
    }
    return parts.isEmpty
        ? (isEnglish ? '(No condition specified)' : '(ไม่ระบุเงื่อนไข)')
        : parts.join('  ·  ');
  }

}
