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

class ArCustomer {
  final int? id;
  final String customerCode;
  final String customerNameTh;
  final String? customerNameEn;
  final String? taxId;
  final String businessType; // trading, manufacturing, service, mixed
  final int creditDays;
  final double creditLimit;
  final String currencyCode;
  final bool isActive;
  final String? remark;
  final List<ArCustomerAddress> addresses;
  final List<ArCustomerContact> contacts;
  final List<ArCustomerBankAccount> bankAccounts;

  ArCustomer({
    this.id,
    required this.customerCode,
    required this.customerNameTh,
    this.customerNameEn,
    this.taxId,
    this.businessType = 'trading',
    this.creditDays = 30,
    this.creditLimit = 0,
    this.currencyCode = 'THB',
    this.isActive = true,
    this.remark,
    this.addresses = const [],
    this.contacts = const [],
    this.bankAccounts = const [],
  });

  factory ArCustomer.fromJson(Map<String, dynamic> json) => ArCustomer(
        id: json['id'],
        customerCode: json['customer_code'] ?? '',
        customerNameTh: json['customer_name_th'] ?? '',
        customerNameEn: json['customer_name_en'],
        taxId: json['tax_id'],
        businessType: json['business_type'] ?? 'trading',
        creditDays: json['credit_days'] ?? 30,
        creditLimit:
            double.tryParse(json['credit_limit']?.toString() ?? '0') ?? 0,
        currencyCode: json['currency_code'] ?? 'THB',
        isActive: json['is_active'] ?? true,
        remark: json['remark'],
        addresses: (json['addresses'] as List<dynamic>? ?? [])
            .map((e) => ArCustomerAddress.fromJson(e))
            .toList(),
        contacts: (json['contacts'] as List<dynamic>? ?? [])
            .map((e) => ArCustomerContact.fromJson(e))
            .toList(),
        bankAccounts: (json['bank_accounts'] as List<dynamic>? ?? [])
            .map((e) => ArCustomerBankAccount.fromJson(e))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'customer_code': customerCode,
        'customer_name_th': customerNameTh,
        'customer_name_en': customerNameEn,
        'tax_id': taxId,
        'business_type': businessType,
        'credit_days': creditDays,
        'credit_limit': creditLimit,
        'currency_code': currencyCode,
        'is_active': isActive,
        'remark': remark,
        'addresses': addresses.map((e) => e.toJson()).toList(),
        'contacts': contacts.map((e) => e.toJson()).toList(),
        'bank_accounts': bankAccounts.map((e) => e.toJson()).toList(),
      };
}
