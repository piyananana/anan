// lib/im/models/im_price_list.dart

const List<String> imPriceListTypes = ['SALES', 'PURCHASE'];

String imPriceListTypeLabel(String type, bool isEnglish) {
  if (type == 'SALES') return isEnglish ? 'Sales' : 'ราคาขาย';
  if (type == 'PURCHASE') return isEnglish ? 'Purchase' : 'ราคาซื้อ';
  return type;
}

// ป้ายกำกับบรรทัดราคา — ไม่กระทบการ resolve ราคา (ยังเลือกด้วย effective_from/to เหมือนเดิม) ใช้แค่แยกแยะ
// ราคาปกติ/ราคาโปรโมชั่นชั่วคราวในมุมมอง UI/รายงาน
const List<String> imPriceTypes = ['STANDARD', 'PROMOTION'];

String imPriceTypeLabel(String type, bool isEnglish) {
  if (type == 'PROMOTION') return isEnglish ? 'Promotion' : 'โปรโมชั่น';
  return isEnglish ? 'Standard' : 'ปกติ';
}

class ImPriceListDetail {
  final int? id;
  final int? priceListId;
  final int itemId;
  final String? itemCode;
  final String? itemNameTh;
  final String? itemNameEn;
  final int? uomId;
  final String? uomCode;
  final String? uomNameTh;
  final String? uomNameEn;
  final double minQty;
  final double unitPriceFc;
  // ราคาปกติ/ราคาโปรโมชั่น — ค่าเริ่มต้น 'STANDARD' ดู imPriceTypes ด้านบน
  final String priceType;
  final DateTime? effectiveFrom;
  final DateTime? effectiveTo;
  // audit trail ระดับบรรทัด — เห็นได้เฉพาะบรรทัดที่มาจาก backend แล้ว (id != null) บรรทัดที่เพิ่งเพิ่มในฟอร์ม
  // ยังไม่มีค่าพวกนี้จนกว่าจะบันทึกแล้วโหลดกลับมา
  final DateTime? updatedAt;
  final String? updatedBy;

  const ImPriceListDetail({
    this.id,
    this.priceListId,
    required this.itemId,
    this.itemCode,
    this.itemNameTh,
    this.itemNameEn,
    this.uomId,
    this.uomCode,
    this.uomNameTh,
    this.uomNameEn,
    this.minQty = 0,
    this.unitPriceFc = 0,
    this.priceType = 'STANDARD',
    this.effectiveFrom,
    this.effectiveTo,
    this.updatedAt,
    this.updatedBy,
  });

  factory ImPriceListDetail.fromJson(Map<String, dynamic> json) => ImPriceListDetail(
        id: json['id'],
        priceListId: json['price_list_id'],
        itemId: json['item_id'] as int,
        itemCode: json['item_code'],
        itemNameTh: json['item_name_th'],
        itemNameEn: json['item_name_en'],
        uomId: json['uom_id'],
        uomCode: json['uom_code'],
        uomNameTh: json['uom_name_th'],
        uomNameEn: json['uom_name_en'],
        minQty: double.tryParse(json['min_qty']?.toString() ?? '') ?? 0,
        unitPriceFc: double.tryParse(json['unit_price_fc']?.toString() ?? '') ?? 0,
        priceType: json['price_type'] ?? 'STANDARD',
        effectiveFrom: json['effective_from'] != null ? DateTime.tryParse(json['effective_from']) : null,
        effectiveTo: json['effective_to'] != null ? DateTime.tryParse(json['effective_to']) : null,
        updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
        updatedBy: json['updated_by'],
      );

  // ต้องส่ง 'id' กลับไปด้วย (ถ้ามี) เพื่อให้ updateRow ฝั่ง backend จับคู่บรรทัดเดิมได้ถูก (diff-based update) —
  // ถ้าไม่ส่ง id ทุกบรรทัดจะถูกมองว่าเป็นบรรทัดใหม่เสมอ ทำให้ audit trail (updated_by/updated_at ต่อบรรทัด) ใช้
  // งานไม่ได้จริง
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'item_id': itemId,
        'uom_id': uomId,
        'min_qty': minQty,
        'unit_price_fc': unitPriceFc,
        'price_type': priceType,
        'effective_from': effectiveFrom?.toIso8601String().substring(0, 10),
        'effective_to': effectiveTo?.toIso8601String().substring(0, 10),
      };
}

/// Row shape returned by GET /im_price_list_detail/by_item/:itemId
/// — a price line joined with its owning list's header, for display on the Item screen.
class ImItemPriceRow {
  final int detailId;
  final String priceListCode;
  final String priceListName;
  final String listType;
  // ลิสต์นี้เป็นลิสต์ default ของ list_type นี้หรือไม่ (im_price_list.is_default) — ใช้แสดงคอลัมน์
  // "เป็นราคาเริ่มต้น" ในรายงาน ไม่เกี่ยวกับ priceType (STANDARD/PROMOTION) ของบรรทัดราคา
  final bool isDefault;
  final int? priceGroupId;
  final String? priceGroupCode;
  final String? priceGroupNameTh;
  final String? priceGroupNameEn;
  final String? currencyCode;
  final String? uomCode;
  final String? uomNameTh;
  final String? uomNameEn;
  final double minQty;
  final double unitPriceFc;
  final DateTime? effectiveFrom;
  final DateTime? effectiveTo;

  const ImItemPriceRow({
    required this.detailId,
    required this.priceListCode,
    required this.priceListName,
    required this.listType,
    this.isDefault = false,
    this.priceGroupId,
    this.priceGroupCode,
    this.priceGroupNameTh,
    this.priceGroupNameEn,
    this.currencyCode,
    this.uomCode,
    this.uomNameTh,
    this.uomNameEn,
    this.minQty = 0,
    this.unitPriceFc = 0,
    this.effectiveFrom,
    this.effectiveTo,
  });

  // ใช้งาน/ไม่ใช้งาน ณ วันนี้ — เทียบช่วง effective_from/to กับวันปัจจุบัน (ไม่ขึ้นกับ im_price_list.is_active
  // เพราะ endpoint by_item กรองลิสต์ที่ is_active=false ออกไปแล้วตั้งแต่ชั้น backend)
  bool get isActiveNow {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (effectiveFrom != null && effectiveFrom!.isAfter(today)) return false;
    if (effectiveTo != null && effectiveTo!.isBefore(today)) return false;
    return true;
  }

  factory ImItemPriceRow.fromJson(Map<String, dynamic> json) => ImItemPriceRow(
        detailId: json['id'] as int,
        priceListCode: json['price_list_code'] ?? '',
        priceListName: json['price_list_name'] ?? '',
        listType: json['list_type'] ?? 'SALES',
        isDefault: json['is_default'] ?? false,
        priceGroupId: json['price_group_id'],
        priceGroupCode: json['price_group_code'],
        priceGroupNameTh: json['price_group_name_th'],
        priceGroupNameEn: json['price_group_name_en'],
        currencyCode: json['currency_code'],
        uomCode: json['uom_code'],
        uomNameTh: json['uom_name_th'],
        uomNameEn: json['uom_name_en'],
        minQty: double.tryParse(json['min_qty']?.toString() ?? '') ?? 0,
        unitPriceFc: double.tryParse(json['unit_price_fc']?.toString() ?? '') ?? 0,
        effectiveFrom: json['effective_from'] != null ? DateTime.tryParse(json['effective_from']) : null,
        effectiveTo: json['effective_to'] != null ? DateTime.tryParse(json['effective_to']) : null,
      );
}

class ImPriceListHeader {
  final int? id;
  final String priceListCode;
  final String priceListName;
  final String listType;
  final int? currencyId;
  final String? currencyCode;
  final String? currencyNameTh;
  final String? currencyNameEn;
  // กลุ่มราคา (im_price_group) — **แค่ป้ายกำกับ/หมวดหมู่ ไม่ใช่ targeting** ไม่มีผลต่อการ resolve ราคาเลย ตาราง
  // ราคาหลายใบแปะป้ายเดียวกันได้ (เช่น "ค้าส่ง" หลายใบ ราคาต่างกันได้) — ฝั่งที่ลูกค้า/ผู้ขายผูกกับตารางราคาที่จะ
  // ใช้จริงคือ ar_customer.priceListId/ap_vendor.priceListId (ดูไฟล์นั้น) ไม่ใช่ที่นี่
  final int? priceGroupId;
  final String? priceGroupCode;
  final String? priceGroupNameTh;
  final String? priceGroupNameEn;
  // ลิสต์ที่ใช้เป็น fallback ของ list_type นี้เมื่อผู้ขาย/ลูกค้าไม่มีลิสต์เฉพาะราย (ar_customer.priceListId/
  // ap_vendor.priceListId เป็น null) — ตั้งได้ใบเดียวต่อ list_type (การันตีด้วย unique index ฝั่ง backend)
  final bool isDefault;
  final bool isActive;
  final int lineCount;
  final List<ImPriceListDetail> details;

  const ImPriceListHeader({
    this.id,
    required this.priceListCode,
    required this.priceListName,
    this.listType = 'SALES',
    this.currencyId,
    this.currencyCode,
    this.currencyNameTh,
    this.currencyNameEn,
    this.priceGroupId,
    this.priceGroupCode,
    this.priceGroupNameTh,
    this.priceGroupNameEn,
    this.isDefault = false,
    this.isActive = true,
    this.lineCount = 0,
    this.details = const [],
  });

  factory ImPriceListHeader.fromJson(Map<String, dynamic> json) => ImPriceListHeader(
        id: json['id'],
        priceListCode: json['price_list_code'] ?? '',
        priceListName: json['price_list_name'] ?? '',
        listType: json['list_type'] ?? 'SALES',
        currencyId: json['currency_id'],
        currencyCode: json['currency_code'],
        currencyNameTh: json['currency_name_th'],
        currencyNameEn: json['currency_name_en'],
        priceGroupId: json['price_group_id'],
        priceGroupCode: json['price_group_code'],
        priceGroupNameTh: json['price_group_name_th'],
        priceGroupNameEn: json['price_group_name_en'],
        isDefault: json['is_default'] ?? false,
        isActive: json['is_active'] ?? true,
        lineCount: int.tryParse(json['line_count']?.toString() ?? '') ?? 0,
        details: (json['details'] as List<dynamic>? ?? []).map((e) => ImPriceListDetail.fromJson(e)).toList(),
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'price_list_code': priceListCode,
        'price_list_name': priceListName,
        'list_type': listType,
        'currency_id': currencyId,
        'price_group_id': priceGroupId,
        'is_default': isDefault,
        'is_active': isActive,
        'details': details.map((e) => e.toJson()).toList(),
      };
}
