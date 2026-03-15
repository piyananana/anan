// models/company.dart
import '../../../utils/date_utils.dart';

class Company {
  final int? id;
  String thaiName;
  String? englishName;
  String? addressNo;
  String? addressBuildingVillage;
  String? addressAlley;
  String? addressRoad;
  String? addressSubDistrict;
  String? addressDistrict;
  String? addressProvince;
  String? addressCountry;
  String? addressZipCode;
  String? taxIdNumber;
  String? logoUrl; // URL ของรูปโลโก้
  DateTime? startDate;
  DateTime? maintenanceContractDate;
  String? serialNumber;
  String? phoneNumber;
  String? faxNumber;
  String? email;
  String? website;
  String? primaryContactPerson;
  bool isActive;

  Company({
    this.id,
    required this.thaiName,
    this.englishName,
    this.addressNo,
    this.addressBuildingVillage,
    this.addressAlley,
    this.addressRoad,
    this.addressSubDistrict,
    this.addressDistrict,
    this.addressProvince,
    this.addressCountry,
    this.addressZipCode,
    this.taxIdNumber,
    this.logoUrl,
    this.startDate,
    this.maintenanceContractDate,
    this.serialNumber,
    this.phoneNumber,
    this.faxNumber,
    this.email,
    this.website,
    this.primaryContactPerson,
    this.isActive = true, // Default to true
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'] as int?,
      thaiName: json['thai_name'] as String,
      englishName: json['english_name'] as String?,
      addressNo: json['address_no'] as String?,
      addressBuildingVillage: json['address_building_village'] as String?,
      addressAlley: json['address_alley'] as String?,
      addressRoad: json['address_road'] as String?,
      addressSubDistrict: json['address_sub_district'] as String?,
      addressDistrict: json['address_district'] as String?,
      addressProvince: json['address_province'] as String?,
      addressCountry: json['address_country'] as String?,
      addressZipCode: json['address_zip_code'] as String?,
      taxIdNumber: json['tax_id_number'] as String?,
      logoUrl: json['logo_url'] as String?,
      startDate: json['start_date'] != null ? parseLocalDate(json['start_date']) : null,
      maintenanceContractDate: json['maintenance_contract_date'] != null ? parseLocalDate(json['maintenance_contract_date']) : null,
      serialNumber: json['serial_number'] as String?,
      phoneNumber: json['phone_number'] as String?,
      faxNumber: json['fax_number'] as String?,
      email: json['email'] as String?,
      website: json['website'] as String?,
      primaryContactPerson: json['primary_contact_person'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  // สำหรับส่งข้อมูลไป Backend (POST/PUT)
  Map<String, String> toFormJson() { // ใช้ String เพื่อให้เข้ากับ Multipart request
    return {
      'thai_name': thaiName,
      'english_name': englishName ?? '',
      'address_no': addressNo ?? '',
      'address_building_village': addressBuildingVillage ?? '',
      'address_alley': addressAlley ?? '',
      'address_road': addressRoad ?? '',
      'address_sub_district': addressSubDistrict ?? '',
      'address_district': addressDistrict ?? '',
      'address_province': addressProvince ?? '',
      'address_country': addressCountry ?? '',
      'address_zip_code': addressZipCode ?? '',
      'tax_id_number': taxIdNumber ?? '',
      'start_date': startDate != null ? formatLocalDate(startDate!) : '',
      'maintenance_contract_date': maintenanceContractDate != null ? formatLocalDate(maintenanceContractDate!) : '',
      'serial_number': serialNumber ?? '',
      'phone_number': phoneNumber ?? '',
      'fax_number': faxNumber ?? '',
      'email': email ?? '',
      'website': website ?? '',
      'primary_contact_person': primaryContactPerson ?? '',
      'is_active': isActive.toString(), // แปลง bool เป็น String
    };
  }
}