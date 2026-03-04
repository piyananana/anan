// Models
class Branch {
  final int? id;
  final String branchCode;
  final String branchNameThai;
  final String branchNameEng;
  final bool isActive;
  final String? addressNo;
  final String? addressBuildingVillage;
  final String? addressSoi;
  final String? addressRoad;
  final String? addressSubDistrict;
  final String? addressDistrict;
  final String? addressProvince;
  final String? addressCountry;
  final String? addressZipCode;
  final String? phoneNumber;
  final String? faxNumber;
  final String? primaryContactPerson;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  Branch({
    this.id,
    required this.branchCode,
    required this.branchNameThai,
    required this.branchNameEng,
    required this.isActive,
    this.addressNo,
    this.addressBuildingVillage,
    this.addressSoi,
    this.addressRoad,
    this.addressSubDistrict,
    this.addressDistrict,
    this.addressProvince,
    this.addressCountry,
    this.addressZipCode,
    this.phoneNumber,
    this.faxNumber,
    this.primaryContactPerson,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['id'],
      branchCode: json['branch_code'],
      branchNameThai: json['branch_name_thai'],
      branchNameEng: json['branch_name_eng'],
      isActive: json['is_active'] ?? false,
      addressNo: json['address_no'],
      addressBuildingVillage: json['address_building_village'],
      addressSoi: json['address_soi'],
      addressRoad: json['address_road'],
      addressSubDistrict: json['address_sub_district'],
      addressDistrict: json['address_district'],
      addressProvince: json['address_province'],
      addressCountry: json['address_country'],
      addressZipCode: json['address_zip_code'],
      phoneNumber: json['phone_number'],
      faxNumber: json['fax_number'],
      primaryContactPerson: json['primary_contact_person'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      createdBy: json['created_by'] ?? '',
      updatedBy: json['updated_by'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'branch_code': branchCode,
      'branch_name_thai': branchNameThai,
      'branch_name_eng': branchNameEng,
      'is_active': isActive,
      'address_no': addressNo,
      'address_building_village': addressBuildingVillage,
      'address_soi': addressSoi,
      'address_road': addressRoad,
      'address_sub_district': addressSubDistrict,
      'address_district': addressDistrict,
      'address_province': addressProvince,
      'address_country': addressCountry,
      'address_zip_code': addressZipCode,
      'phone_number': phoneNumber,
      'fax_number': faxNumber,
      'primary_contact_person': primaryContactPerson,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
    };
  }
}
