class ArCustomerAddress {
  final int? id;
  final int? customerId;
  final String addressType;
  final String? addressNo;
  final String? addressBuildingVillage;
  final String? addressAlley;
  final String? addressRoad;
  final String? addressSubDistrict;
  final String? addressDistrict;
  final String? addressProvince;
  final String? addressCountry;
  final String? addressZipCode;
  final bool isDefault;

  ArCustomerAddress({
    this.id,
    this.customerId,
    this.addressType = 'billing',
    this.addressNo,
    this.addressBuildingVillage,
    this.addressAlley,
    this.addressRoad,
    this.addressSubDistrict,
    this.addressDistrict,
    this.addressProvince,
    this.addressCountry = 'Thailand',
    this.addressZipCode,
    this.isDefault = false,
  });

  factory ArCustomerAddress.fromJson(Map<String, dynamic> json) =>
      ArCustomerAddress(
        id: json['id'],
        customerId: json['customer_id'],
        addressType: json['address_type'] ?? 'billing',
        addressNo: json['address_no'],
        addressBuildingVillage: json['address_building_village'],
        addressAlley: json['address_alley'],
        addressRoad: json['address_road'],
        addressSubDistrict: json['address_sub_district'],
        addressDistrict: json['address_district'],
        addressProvince: json['address_province'],
        addressCountry: json['address_country'],
        addressZipCode: json['address_zip_code'],
        isDefault: json['is_default'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (customerId != null) 'customer_id': customerId,
        'address_type': addressType,
        'address_no': addressNo,
        'address_building_village': addressBuildingVillage,
        'address_alley': addressAlley,
        'address_road': addressRoad,
        'address_sub_district': addressSubDistrict,
        'address_district': addressDistrict,
        'address_province': addressProvince,
        'address_country': addressCountry,
        'address_zip_code': addressZipCode,
        'is_default': isDefault,
      };

  ArCustomerAddress copyWith({
    int? id,
    int? customerId,
    String? addressType,
    String? addressNo,
    String? addressBuildingVillage,
    String? addressAlley,
    String? addressRoad,
    String? addressSubDistrict,
    String? addressDistrict,
    String? addressProvince,
    String? addressCountry,
    String? addressZipCode,
    bool? isDefault,
  }) =>
      ArCustomerAddress(
        id: id ?? this.id,
        customerId: customerId ?? this.customerId,
        addressType: addressType ?? this.addressType,
        addressNo: addressNo ?? this.addressNo,
        addressBuildingVillage:
            addressBuildingVillage ?? this.addressBuildingVillage,
        addressAlley: addressAlley ?? this.addressAlley,
        addressRoad: addressRoad ?? this.addressRoad,
        addressSubDistrict: addressSubDistrict ?? this.addressSubDistrict,
        addressDistrict: addressDistrict ?? this.addressDistrict,
        addressProvince: addressProvince ?? this.addressProvince,
        addressCountry: addressCountry ?? this.addressCountry,
        addressZipCode: addressZipCode ?? this.addressZipCode,
        isDefault: isDefault ?? this.isDefault,
      );
}

class ArCustomerContact {
  final int? id;
  final int? customerId;
  final String contactName;
  final String? position;
  final String? phone;
  final String? mobile;
  final String? email;
  final bool isDefault;

  ArCustomerContact({
    this.id,
    this.customerId,
    this.contactName = '',
    this.position,
    this.phone,
    this.mobile,
    this.email,
    this.isDefault = false,
  });

  factory ArCustomerContact.fromJson(Map<String, dynamic> json) =>
      ArCustomerContact(
        id: json['id'],
        customerId: json['customer_id'],
        contactName: json['contact_name'] ?? '',
        position: json['position'],
        phone: json['phone'],
        mobile: json['mobile'],
        email: json['email'],
        isDefault: json['is_default'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (customerId != null) 'customer_id': customerId,
        'contact_name': contactName,
        'position': position,
        'phone': phone,
        'mobile': mobile,
        'email': email,
        'is_default': isDefault,
      };

  ArCustomerContact copyWith({
    int? id,
    int? customerId,
    String? contactName,
    String? position,
    String? phone,
    String? mobile,
    String? email,
    bool? isDefault,
  }) =>
      ArCustomerContact(
        id: id ?? this.id,
        customerId: customerId ?? this.customerId,
        contactName: contactName ?? this.contactName,
        position: position ?? this.position,
        phone: phone ?? this.phone,
        mobile: mobile ?? this.mobile,
        email: email ?? this.email,
        isDefault: isDefault ?? this.isDefault,
      );
}

class ArCustomerBankAccount {
  final int? id;
  final int? customerId;
  final String? bankName;
  final String? branchName;
  final String? accountNumber;
  final String? accountName;
  final String accountType;
  final bool isDefault;

  ArCustomerBankAccount({
    this.id,
    this.customerId,
    this.bankName,
    this.branchName,
    this.accountNumber,
    this.accountName,
    this.accountType = 'current',
    this.isDefault = false,
  });

  factory ArCustomerBankAccount.fromJson(Map<String, dynamic> json) =>
      ArCustomerBankAccount(
        id: json['id'],
        customerId: json['customer_id'],
        bankName: json['bank_name'],
        branchName: json['branch_name'],
        accountNumber: json['account_number'],
        accountName: json['account_name'],
        accountType: json['account_type'] ?? 'current',
        isDefault: json['is_default'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (customerId != null) 'customer_id': customerId,
        'bank_name': bankName,
        'branch_name': branchName,
        'account_number': accountNumber,
        'account_name': accountName,
        'account_type': accountType,
        'is_default': isDefault,
      };

  ArCustomerBankAccount copyWith({
    int? id,
    int? customerId,
    String? bankName,
    String? branchName,
    String? accountNumber,
    String? accountName,
    String? accountType,
    bool? isDefault,
  }) =>
      ArCustomerBankAccount(
        id: id ?? this.id,
        customerId: customerId ?? this.customerId,
        bankName: bankName ?? this.bankName,
        branchName: branchName ?? this.branchName,
        accountNumber: accountNumber ?? this.accountNumber,
        accountName: accountName ?? this.accountName,
        accountType: accountType ?? this.accountType,
        isDefault: isDefault ?? this.isDefault,
      );
}

// ---------------------------------------------------------------------------
// ArCustomerBillingCondition — เงื่อนไขการวางบิล (1 ลูกค้า : N เงื่อนไข)
// ---------------------------------------------------------------------------
class ArCustomerBillingCondition {
  final int? id;
  final int? customerId;
  final int sortOrder;
  final bool billWithDelivery;
  // วันที่ในเดือน: [1–30, 31=สิ้นเดือน], [] = ไม่ระบุ
  final List<int> billingDayOfMonth;
  // วันในสัปดาห์: [0=อา, 1=จ, 2=อ, 3=พ, 4=พฤ, 5=ศ, 6=ส], [] = ไม่ระบุ
  final List<int> billingDayOfWeek;
  // สัปดาห์ที่: [1,2,3,4,-1=สุดท้าย], [] = ทุกสัปดาห์
  final List<int> billingWeekOfMonth;
  final String? billingTimeFrom; // 'HH:mm'
  final String? billingTimeTo;   // 'HH:mm'
  // ถ้า true: คำนวณ due_date ใหม่นับจากวันวางบิลแทนวันส่งของ
  final bool dueFromBillingDate;
  final String? remark;

  ArCustomerBillingCondition({
    this.id,
    this.customerId,
    this.sortOrder = 1,
    this.billWithDelivery = false,
    this.billingDayOfMonth = const [],
    this.billingDayOfWeek = const [],
    this.billingWeekOfMonth = const [],
    this.billingTimeFrom,
    this.billingTimeTo,
    this.dueFromBillingDate = false,
    this.remark,
  });

  factory ArCustomerBillingCondition.fromJson(Map<String, dynamic> json) =>
      ArCustomerBillingCondition(
        id: json['id'],
        customerId: json['customer_id'],
        sortOrder: json['sort_order'] ?? 1,
        billWithDelivery: json['bill_with_delivery'] ?? false,
        billingDayOfMonth: _toIntList(json['billing_day_of_month']),
        billingDayOfWeek: _toIntList(json['billing_day_of_week']),
        billingWeekOfMonth: _toIntList(json['billing_week_of_month']),
        billingTimeFrom: json['billing_time_from'],
        billingTimeTo: json['billing_time_to'],
        dueFromBillingDate: json['due_from_billing_date'] ?? false,
        remark: json['remark'],
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (customerId != null) 'customer_id': customerId,
        'sort_order': sortOrder,
        'bill_with_delivery': billWithDelivery,
        'billing_day_of_month': billingDayOfMonth,
        'billing_day_of_week': billingDayOfWeek,
        'billing_week_of_month': billingWeekOfMonth,
        'billing_time_from': billingTimeFrom,
        'billing_time_to': billingTimeTo,
        'due_from_billing_date': dueFromBillingDate,
        'remark': remark,
      };

  ArCustomerBillingCondition copyWith({
    int? id,
    int? customerId,
    int? sortOrder,
    bool? billWithDelivery,
    List<int>? billingDayOfMonth,
    List<int>? billingDayOfWeek,
    List<int>? billingWeekOfMonth,
    String? billingTimeFrom,
    String? billingTimeTo,
    bool? dueFromBillingDate,
    String? remark,
  }) =>
      ArCustomerBillingCondition(
        id: id ?? this.id,
        customerId: customerId ?? this.customerId,
        sortOrder: sortOrder ?? this.sortOrder,
        billWithDelivery: billWithDelivery ?? this.billWithDelivery,
        billingDayOfMonth: billingDayOfMonth ?? this.billingDayOfMonth,
        billingDayOfWeek: billingDayOfWeek ?? this.billingDayOfWeek,
        billingWeekOfMonth: billingWeekOfMonth ?? this.billingWeekOfMonth,
        billingTimeFrom: billingTimeFrom ?? this.billingTimeFrom,
        billingTimeTo: billingTimeTo ?? this.billingTimeTo,
        dueFromBillingDate: dueFromBillingDate ?? this.dueFromBillingDate,
        remark: remark ?? this.remark,
      );
}

// ---------------------------------------------------------------------------
// ArCustomerPaymentCondition — เงื่อนไขการรับชำระ (1 ลูกค้า : N เงื่อนไข)
// ---------------------------------------------------------------------------
class ArCustomerPaymentCondition {
  final int? id;
  final int? customerId;
  final int sortOrder;
  // วันที่ในเดือน: [1–30, 31=สิ้นเดือน], [] = ไม่ระบุ
  final List<int> paymentDayOfMonth;
  // วันในสัปดาห์: [0–6], [] = ไม่ระบุ
  final List<int> paymentDayOfWeek;
  // สัปดาห์ที่: [1,2,3,4,-1=สุดท้าย], [] = ทุกสัปดาห์
  final List<int> paymentWeekOfMonth;
  final String? paymentTimeFrom; // 'HH:mm'
  final String? paymentTimeTo;   // 'HH:mm'
  // ชำระภายในกี่เดือนจากเดือนที่วางบิล (0 = ไม่จำกัดเดือน)
  final int withinMonthsFromBilling;
  // จำนวนวันที่บวกเพิ่มจากวันที่คำนวณได้
  final int additionalDays;
  final String? remark;

  ArCustomerPaymentCondition({
    this.id,
    this.customerId,
    this.sortOrder = 1,
    this.paymentDayOfMonth = const [],
    this.paymentDayOfWeek = const [],
    this.paymentWeekOfMonth = const [],
    this.paymentTimeFrom,
    this.paymentTimeTo,
    this.withinMonthsFromBilling = 0,
    this.additionalDays = 0,
    this.remark,
  });

  factory ArCustomerPaymentCondition.fromJson(Map<String, dynamic> json) =>
      ArCustomerPaymentCondition(
        id: json['id'],
        customerId: json['customer_id'],
        sortOrder: json['sort_order'] ?? 1,
        paymentDayOfMonth: _toIntList(json['payment_day_of_month']),
        paymentDayOfWeek: _toIntList(json['payment_day_of_week']),
        paymentWeekOfMonth: _toIntList(json['payment_week_of_month']),
        paymentTimeFrom: json['payment_time_from'],
        paymentTimeTo: json['payment_time_to'],
        withinMonthsFromBilling: json['within_months_from_billing'] ?? 0,
        additionalDays: json['additional_days'] ?? 0,
        remark: json['remark'],
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (customerId != null) 'customer_id': customerId,
        'sort_order': sortOrder,
        'payment_day_of_month': paymentDayOfMonth,
        'payment_day_of_week': paymentDayOfWeek,
        'payment_week_of_month': paymentWeekOfMonth,
        'payment_time_from': paymentTimeFrom,
        'payment_time_to': paymentTimeTo,
        'within_months_from_billing': withinMonthsFromBilling,
        'additional_days': additionalDays,
        'remark': remark,
      };

  ArCustomerPaymentCondition copyWith({
    int? id,
    int? customerId,
    int? sortOrder,
    List<int>? paymentDayOfMonth,
    List<int>? paymentDayOfWeek,
    List<int>? paymentWeekOfMonth,
    String? paymentTimeFrom,
    String? paymentTimeTo,
    int? withinMonthsFromBilling,
    int? additionalDays,
    String? remark,
  }) =>
      ArCustomerPaymentCondition(
        id: id ?? this.id,
        customerId: customerId ?? this.customerId,
        sortOrder: sortOrder ?? this.sortOrder,
        paymentDayOfMonth: paymentDayOfMonth ?? this.paymentDayOfMonth,
        paymentDayOfWeek: paymentDayOfWeek ?? this.paymentDayOfWeek,
        paymentWeekOfMonth: paymentWeekOfMonth ?? this.paymentWeekOfMonth,
        paymentTimeFrom: paymentTimeFrom ?? this.paymentTimeFrom,
        paymentTimeTo: paymentTimeTo ?? this.paymentTimeTo,
        withinMonthsFromBilling:
            withinMonthsFromBilling ?? this.withinMonthsFromBilling,
        additionalDays: additionalDays ?? this.additionalDays,
        remark: remark ?? this.remark,
      );
}

List<int> _toIntList(dynamic v) {
  if (v == null) return [];
  if (v is List) return v.map((e) => (e as num).toInt()).toList();
  return [];
}

// ---------------------------------------------------------------------------
// ArCustomer
// ---------------------------------------------------------------------------
class ArCustomer {
  final int? id;
  final String customerCode;
  final String? oldCustomerCode;
  final String customerNameTh;
  final String? customerNameEn;
  final String? taxId;
  // FK → cd_business_type
  final int? businessTypeId;
  final String? businessTypeCode;
  final String? businessTypeNameThai;
  // FK → ar_customer_group
  final int? customerGroupId;
  final String? customerGroupCode;
  final String? customerGroupName;
  // เงื่อนไขเครดิต: due_date = delivery_date + creditTermMonths เดือน + creditTermDays วัน
  final int creditTermMonths;
  final int creditTermDays;
  final double creditLimit;
  final double discountPercent;
  final String currencyCode;
  final bool isActive;
  final String? remark;
  // ต้องวางบิลก่อนหรือไม่
  final bool requiresBilling;
  final int? arAccountId;        // FK -> gl_account.id
  final String? arAccountCode;
  final String? arAccountNameThai;
  // บัญชี GL ของกลุ่มลูกหนี้ (override ลำดับสูงกว่าลูกหนี้ แต่ต่ำกว่า setup)
  final int? groupArAccountId;
  final String? groupArAccountCode;
  final String? groupArAccountNameThai;
  // เขตการขาย + พนักงานขาย
  final int? salesTerritoryId;
  final String? salesTerritoryCode;
  final String? salesTerritoryNameThai;
  final int? salespersonId;
  final String? salespersonCode;
  final String? salespersonNameThai;
  // ผู้วางบิล + ผู้รับชำระ (FK -> ar_collector)
  final int? billingCollectorId;
  final String? billingCollectorCode;
  final String? billingCollectorNameThai;
  final int? collectionCollectorId;
  final String? collectionCollectorCode;
  final String? collectionCollectorNameThai;
  final List<ArCustomerAddress> addresses;
  final List<ArCustomerContact> contacts;
  final List<ArCustomerBankAccount> bankAccounts;
  final List<ArCustomerBillingCondition> billingConditions;
  final List<ArCustomerPaymentCondition> paymentConditions;

  ArCustomer({
    this.id,
    required this.customerCode,
    this.oldCustomerCode,
    required this.customerNameTh,
    this.customerNameEn,
    this.taxId,
    this.businessTypeId,
    this.businessTypeCode,
    this.businessTypeNameThai,
    this.customerGroupId,
    this.customerGroupCode,
    this.customerGroupName,
    this.creditTermMonths = 0,
    this.creditTermDays = 30,
    this.creditLimit = 0,
    this.discountPercent = 0,
    this.currencyCode = 'THB',
    this.isActive = true,
    this.remark,
    this.requiresBilling = false,
    this.arAccountId,
    this.arAccountCode,
    this.arAccountNameThai,
    this.groupArAccountId,
    this.groupArAccountCode,
    this.groupArAccountNameThai,
    this.salesTerritoryId,
    this.salesTerritoryCode,
    this.salesTerritoryNameThai,
    this.salespersonId,
    this.salespersonCode,
    this.salespersonNameThai,
    this.billingCollectorId,
    this.billingCollectorCode,
    this.billingCollectorNameThai,
    this.collectionCollectorId,
    this.collectionCollectorCode,
    this.collectionCollectorNameThai,
    this.addresses = const [],
    this.contacts = const [],
    this.bankAccounts = const [],
    this.billingConditions = const [],
    this.paymentConditions = const [],
  });

  factory ArCustomer.fromJson(Map<String, dynamic> json) => ArCustomer(
        id: json['id'],
        customerCode: json['customer_code'] ?? '',
        oldCustomerCode: json['old_customer_code'] as String?,
        customerNameTh: json['customer_name_th'] ?? '',
        customerNameEn: json['customer_name_en'],
        taxId: json['tax_id'],
        businessTypeId: json['business_type_id'],
        businessTypeCode: json['business_type_code'],
        businessTypeNameThai: json['business_type_name_thai'],
        customerGroupId: json['customer_group_id'],
        customerGroupCode: json['customer_group_code'],
        customerGroupName: json['customer_group_name'],
        creditTermMonths: json['credit_term_months'] ?? 0,
        creditTermDays: json['credit_term_days'] ?? 30,
        creditLimit:
            double.tryParse(json['credit_limit']?.toString() ?? '0') ?? 0,
        discountPercent:
            double.tryParse(json['discount_percent']?.toString() ?? '0') ?? 0,
        currencyCode: json['currency_code'] ?? 'THB',
        isActive: json['is_active'] ?? true,
        remark: json['remark'],
        requiresBilling: json['requires_billing'] ?? false,
        arAccountId: json['ar_account_id'] as int?,
        arAccountCode: json['ar_account_code'] as String?,
        arAccountNameThai: json['ar_account_name_thai'] as String?,
        groupArAccountId: json['group_ar_account_id'] as int?,
        groupArAccountCode: json['group_ar_account_code'] as String?,
        groupArAccountNameThai: json['group_ar_account_name_thai'] as String?,
        salesTerritoryId: json['sales_territory_id'] as int?,
        salesTerritoryCode: json['sales_territory_code'] as String?,
        salesTerritoryNameThai: json['sales_territory_name_thai'] as String?,
        salespersonId: json['salesperson_id'] as int?,
        salespersonCode: json['salesperson_code'] as String?,
        salespersonNameThai: json['salesperson_name_thai'] as String?,
        billingCollectorId: json['billing_collector_id'] as int?,
        billingCollectorCode: json['billing_collector_code'] as String?,
        billingCollectorNameThai:
            json['billing_collector_name_thai'] as String?,
        collectionCollectorId: json['collection_collector_id'] as int?,
        collectionCollectorCode: json['collection_collector_code'] as String?,
        collectionCollectorNameThai:
            json['collection_collector_name_thai'] as String?,
        addresses: (json['addresses'] as List<dynamic>? ?? [])
            .map((e) => ArCustomerAddress.fromJson(e))
            .toList(),
        contacts: (json['contacts'] as List<dynamic>? ?? [])
            .map((e) => ArCustomerContact.fromJson(e))
            .toList(),
        bankAccounts: (json['bank_accounts'] as List<dynamic>? ?? [])
            .map((e) => ArCustomerBankAccount.fromJson(e))
            .toList(),
        billingConditions:
            (json['billing_conditions'] as List<dynamic>? ?? [])
                .map((e) => ArCustomerBillingCondition.fromJson(e))
                .toList(),
        paymentConditions:
            (json['payment_conditions'] as List<dynamic>? ?? [])
                .map((e) => ArCustomerPaymentCondition.fromJson(e))
                .toList(),
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'customer_code': customerCode,
        'old_customer_code': oldCustomerCode,
        'customer_name_th': customerNameTh,
        'customer_name_en': customerNameEn,
        'tax_id': taxId,
        'business_type_id': businessTypeId,
        'customer_group_id': customerGroupId,
        'credit_term_months': creditTermMonths,
        'credit_term_days': creditTermDays,
        'credit_limit': creditLimit,
        'discount_percent': discountPercent,
        'currency_code': currencyCode,
        'is_active': isActive,
        'remark': remark,
        'requires_billing': requiresBilling,
        'ar_account_id': arAccountId,
        'group_ar_account_id': groupArAccountId,
        'sales_territory_id': salesTerritoryId,
        'salesperson_id': salespersonId,
        'billing_collector_id': billingCollectorId,
        'collection_collector_id': collectionCollectorId,
        'addresses': addresses.map((e) => e.toJson()).toList(),
        'contacts': contacts.map((e) => e.toJson()).toList(),
        'bank_accounts': bankAccounts.map((e) => e.toJson()).toList(),
        'billing_conditions':
            billingConditions.map((e) => e.toJson()).toList(),
        'payment_conditions':
            paymentConditions.map((e) => e.toJson()).toList(),
      };
}
