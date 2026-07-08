// lib/ap/models/ap_vendor.dart

class ApVendorAddress {
  final int? id;
  final int? vendorId;
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

  ApVendorAddress({
    this.id,
    this.vendorId,
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

  factory ApVendorAddress.fromJson(Map<String, dynamic> json) => ApVendorAddress(
        id: json['id'],
        vendorId: json['vendor_id'],
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
        if (vendorId != null) 'vendor_id': vendorId,
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

  ApVendorAddress copyWith({
    int? id, int? vendorId, String? addressType, String? addressNo,
    String? addressBuildingVillage, String? addressAlley, String? addressRoad,
    String? addressSubDistrict, String? addressDistrict, String? addressProvince,
    String? addressCountry, String? addressZipCode, bool? isDefault,
  }) => ApVendorAddress(
        id: id ?? this.id, vendorId: vendorId ?? this.vendorId,
        addressType: addressType ?? this.addressType, addressNo: addressNo ?? this.addressNo,
        addressBuildingVillage: addressBuildingVillage ?? this.addressBuildingVillage,
        addressAlley: addressAlley ?? this.addressAlley, addressRoad: addressRoad ?? this.addressRoad,
        addressSubDistrict: addressSubDistrict ?? this.addressSubDistrict,
        addressDistrict: addressDistrict ?? this.addressDistrict,
        addressProvince: addressProvince ?? this.addressProvince,
        addressCountry: addressCountry ?? this.addressCountry,
        addressZipCode: addressZipCode ?? this.addressZipCode,
        isDefault: isDefault ?? this.isDefault,
      );
}

class ApVendorContact {
  final int? id;
  final int? vendorId;
  final String contactName;
  final String? position;
  final String? phone;
  final String? mobile;
  final String? email;
  final bool isDefault;

  ApVendorContact({
    this.id, this.vendorId,
    this.contactName = '', this.position, this.phone, this.mobile, this.email,
    this.isDefault = false,
  });

  factory ApVendorContact.fromJson(Map<String, dynamic> json) => ApVendorContact(
        id: json['id'], vendorId: json['vendor_id'],
        contactName: json['contact_name'] ?? '', position: json['position'],
        phone: json['phone'], mobile: json['mobile'], email: json['email'],
        isDefault: json['is_default'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (vendorId != null) 'vendor_id': vendorId,
        'contact_name': contactName, 'position': position,
        'phone': phone, 'mobile': mobile, 'email': email, 'is_default': isDefault,
      };

  ApVendorContact copyWith({
    int? id, int? vendorId, String? contactName, String? position,
    String? phone, String? mobile, String? email, bool? isDefault,
  }) => ApVendorContact(
        id: id ?? this.id, vendorId: vendorId ?? this.vendorId,
        contactName: contactName ?? this.contactName, position: position ?? this.position,
        phone: phone ?? this.phone, mobile: mobile ?? this.mobile,
        email: email ?? this.email, isDefault: isDefault ?? this.isDefault,
      );
}

class ApVendorBankAccount {
  final int? id;
  final int? vendorId;
  final String? bankName;
  final String? branchName;
  final String? accountNumber;
  final String? accountName;
  final String accountType;
  final bool isDefault;

  ApVendorBankAccount({
    this.id, this.vendorId, this.bankName, this.branchName,
    this.accountNumber, this.accountName,
    this.accountType = 'current', this.isDefault = false,
  });

  factory ApVendorBankAccount.fromJson(Map<String, dynamic> json) => ApVendorBankAccount(
        id: json['id'], vendorId: json['vendor_id'],
        bankName: json['bank_name'], branchName: json['branch_name'],
        accountNumber: json['account_number'], accountName: json['account_name'],
        accountType: json['account_type'] ?? 'current',
        isDefault: json['is_default'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (vendorId != null) 'vendor_id': vendorId,
        'bank_name': bankName, 'branch_name': branchName,
        'account_number': accountNumber, 'account_name': accountName,
        'account_type': accountType, 'is_default': isDefault,
      };

  ApVendorBankAccount copyWith({
    int? id, int? vendorId, String? bankName, String? branchName,
    String? accountNumber, String? accountName, String? accountType, bool? isDefault,
  }) => ApVendorBankAccount(
        id: id ?? this.id, vendorId: vendorId ?? this.vendorId,
        bankName: bankName ?? this.bankName, branchName: branchName ?? this.branchName,
        accountNumber: accountNumber ?? this.accountNumber,
        accountName: accountName ?? this.accountName,
        accountType: accountType ?? this.accountType,
        isDefault: isDefault ?? this.isDefault,
      );
}

class ApVendor {
  final int? id;
  final String vendorCode;
  final String? oldVendorCode;
  final String vendorNameTh;
  final String? vendorNameEn;
  final String? taxId;
  final int? vendorGroupId;
  final String? vendorGroupCode;
  final String? vendorGroupName;
  final int? businessTypeId;
  final String? businessTypeCode;
  final String? businessTypeNameThai;
  final int creditTermMonths;
  final int creditTermDays;
  final double creditLimit;
  final String currencyCode;
  final bool isActive;
  final String? remark;
  final int? apAccountId;
  final String? apAccountCode;
  final String? apAccountNameThai;
  final String? vendorType;
  final List<ApVendorAddress> addresses;
  final List<ApVendorContact> contacts;
  final List<ApVendorBankAccount> bankAccounts;

  ApVendor({
    this.id,
    required this.vendorCode,
    this.oldVendorCode,
    required this.vendorNameTh,
    this.vendorNameEn,
    this.taxId,
    this.vendorGroupId,
    this.vendorGroupCode,
    this.vendorGroupName,
    this.businessTypeId,
    this.businessTypeCode,
    this.businessTypeNameThai,
    this.creditTermMonths = 0,
    this.creditTermDays = 30,
    this.creditLimit = 0,
    this.currencyCode = 'THB',
    this.isActive = true,
    this.remark,
    this.apAccountId,
    this.apAccountCode,
    this.apAccountNameThai,
    this.vendorType,
    this.addresses = const [],
    this.contacts = const [],
    this.bankAccounts = const [],
  });

  factory ApVendor.fromJson(Map<String, dynamic> json) => ApVendor(
        id: json['id'],
        vendorCode: json['vendor_code'] ?? '',
        oldVendorCode: json['old_vendor_code'],
        vendorNameTh: json['vendor_name_th'] ?? '',
        vendorNameEn: json['vendor_name_en'],
        taxId: json['tax_id'],
        vendorGroupId: json['vendor_group_id'],
        vendorGroupCode: json['vendor_group_code'],
        vendorGroupName: json['vendor_group_name'],
        businessTypeId: json['business_type_id'],
        businessTypeCode: json['business_type_code'],
        businessTypeNameThai: json['business_type_name_thai'],
        creditTermMonths: json['credit_term_months'] ?? 0,
        creditTermDays: json['credit_term_days'] ?? 30,
        creditLimit: double.tryParse(json['credit_limit']?.toString() ?? '') ?? 0.0,
        currencyCode: json['currency_code'] ?? 'THB',
        isActive: json['is_active'] ?? true,
        remark: json['remark'],
        apAccountId: json['ap_account_id'],
        apAccountCode: json['ap_account_code'],
        apAccountNameThai: json['ap_account_name_thai'],
        vendorType: json['vendor_type'],
        addresses: (json['addresses'] as List<dynamic>? ?? [])
            .map((e) => ApVendorAddress.fromJson(e)).toList(),
        contacts: (json['contacts'] as List<dynamic>? ?? [])
            .map((e) => ApVendorContact.fromJson(e)).toList(),
        bankAccounts: (json['bank_accounts'] as List<dynamic>? ?? [])
            .map((e) => ApVendorBankAccount.fromJson(e)).toList(),
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'vendor_code': vendorCode,
        'old_vendor_code': oldVendorCode,
        'vendor_name_th': vendorNameTh,
        'vendor_name_en': vendorNameEn,
        'tax_id': taxId,
        'vendor_group_id': vendorGroupId,
        'business_type_id': businessTypeId,
        'credit_term_months': creditTermMonths,
        'credit_term_days': creditTermDays,
        'credit_limit': creditLimit,
        'currency_code': currencyCode,
        'is_active': isActive,
        'remark': remark,
        'ap_account_id': apAccountId,
        'vendor_type': vendorType,
        'addresses': addresses.map((e) => e.toJson()).toList(),
        'contacts': contacts.map((e) => e.toJson()).toList(),
        'bank_accounts': bankAccounts.map((e) => e.toJson()).toList(),
      };

  ApVendor copyWith({
    int? id, String? vendorCode, String? oldVendorCode,
    String? vendorNameTh, String? vendorNameEn, String? taxId,
    int? vendorGroupId, String? vendorGroupCode, String? vendorGroupName,
    int? businessTypeId, String? businessTypeCode, String? businessTypeNameThai,
    int? creditTermMonths, int? creditTermDays,
    double? creditLimit,
    String? currencyCode, bool? isActive, String? remark,
    int? apAccountId, String? apAccountCode, String? apAccountNameThai,
    String? vendorType,
    List<ApVendorAddress>? addresses,
    List<ApVendorContact>? contacts,
    List<ApVendorBankAccount>? bankAccounts,
  }) => ApVendor(
        id: id ?? this.id,
        vendorCode: vendorCode ?? this.vendorCode,
        oldVendorCode: oldVendorCode ?? this.oldVendorCode,
        vendorNameTh: vendorNameTh ?? this.vendorNameTh,
        vendorNameEn: vendorNameEn ?? this.vendorNameEn,
        taxId: taxId ?? this.taxId,
        vendorGroupId: vendorGroupId ?? this.vendorGroupId,
        vendorGroupCode: vendorGroupCode ?? this.vendorGroupCode,
        vendorGroupName: vendorGroupName ?? this.vendorGroupName,
        businessTypeId: businessTypeId ?? this.businessTypeId,
        businessTypeCode: businessTypeCode ?? this.businessTypeCode,
        businessTypeNameThai: businessTypeNameThai ?? this.businessTypeNameThai,
        creditTermMonths: creditTermMonths ?? this.creditTermMonths,
        creditTermDays: creditTermDays ?? this.creditTermDays,
        creditLimit: creditLimit ?? this.creditLimit,
        currencyCode: currencyCode ?? this.currencyCode,
        isActive: isActive ?? this.isActive,
        remark: remark ?? this.remark,
        apAccountId: apAccountId ?? this.apAccountId,
        apAccountCode: apAccountCode ?? this.apAccountCode,
        apAccountNameThai: apAccountNameThai ?? this.apAccountNameThai,
        vendorType: vendorType ?? this.vendorType,
        addresses: addresses ?? this.addresses,
        contacts: contacts ?? this.contacts,
        bankAccounts: bankAccounts ?? this.bankAccounts,
      );
}
