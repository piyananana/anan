// lib/im/models/im_price_group.dart — กลุ่มราคา (ค้าปลีก/ค้าส่ง/ตัวแทนจำหน่าย/VIP ฯลฯ) สำหรับผูกกับ im_price_list
// แยกจาก ar_customer_group/ap_vendor_group โดยสิ้นเชิง (กลุ่มนั้นคือนโยบายบัญชี/เครดิต ไม่เกี่ยวกับการตั้งราคา)
// มิเรอร์ im_uom.dart ทุกประการ

class ImPriceGroup {
  final int id;
  final String priceGroupCode;
  final String priceGroupNameTh;
  final String? priceGroupNameEn;
  final String? description;
  final bool isActive;

  const ImPriceGroup({
    required this.id,
    required this.priceGroupCode,
    required this.priceGroupNameTh,
    this.priceGroupNameEn,
    this.description,
    this.isActive = true,
  });

  factory ImPriceGroup.fromJson(Map<String, dynamic> json) => ImPriceGroup(
        id: json['id'] as int,
        priceGroupCode: json['price_group_code'] ?? '',
        priceGroupNameTh: json['price_group_name_th'] ?? '',
        priceGroupNameEn: json['price_group_name_en'],
        description: json['description'],
        isActive: json['is_active'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        if (id != 0) 'id': id,
        'price_group_code': priceGroupCode,
        'price_group_name_th': priceGroupNameTh,
        'price_group_name_en': priceGroupNameEn,
        'description': description,
        'is_active': isActive,
      };
}
