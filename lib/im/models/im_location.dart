// lib/im/models/im_location.dart

const List<String> imLocationTypes = ['GROUP', 'BIN'];

String imLocationTypeLabel(String type, bool isEnglish) {
  if (type == 'GROUP') return isEnglish ? 'Group (zone/aisle)' : 'กลุ่ม (โซน/แถว)';
  return isEnglish ? 'Bin (storage slot)' : 'ช่องเก็บ';
}

class ImLocation {
  final int id;
  final int warehouseId;
  final String? warehouseCode;
  final String? warehouseNameTh;
  final String? warehouseNameEn;
  final int? parentId;
  final int level;
  final String locationCode;
  final String? locationName; // ชื่อภาษาไทย (คอลัมน์ location_name เดิม)
  final String? locationNameEn;
  final String locationType; // 'GROUP' / 'BIN'
  final int? categoryId;
  final String? categoryCode;
  final String? categoryNameTh;
  final String? categoryNameEn;
  final bool isActive;
  final int? sortOrder; // ลำดับการเดินตรวจนับสต็อก — ไม่ระบุ = เรียงตาม locationCode แทน
  final bool isDefault; // ตำแหน่งจัดเก็บหลักของคลัง (1 ตำแหน่งต่อคลัง เฉพาะ BIN)
  // จาก GET im_location?with_usage=1 เท่านั้น (หน้าจอตำแหน่งจัดเก็บ)
  final int itemCount; // สินค้าที่มียอดในช่องนี้
  final int defaultCount; // สินค้าที่ตั้งช่องนี้เป็นตำแหน่งเริ่มต้น

  const ImLocation({
    required this.id,
    required this.warehouseId,
    this.warehouseCode,
    this.warehouseNameTh,
    this.warehouseNameEn,
    this.parentId,
    this.level = 1,
    required this.locationCode,
    this.locationName,
    this.locationNameEn,
    this.locationType = 'BIN',
    this.categoryId,
    this.categoryCode,
    this.categoryNameTh,
    this.categoryNameEn,
    this.isActive = true,
    this.sortOrder,
    this.isDefault = false,
    this.itemCount = 0,
    this.defaultCount = 0,
  });

  factory ImLocation.fromJson(Map<String, dynamic> json) => ImLocation(
        id: json['id'] as int,
        warehouseId: json['warehouse_id'] as int,
        warehouseCode: json['warehouse_code'],
        warehouseNameTh: json['warehouse_name_th'],
        warehouseNameEn: json['warehouse_name_en'],
        parentId: json['parent_id'],
        level: json['level'] ?? 1,
        locationCode: json['location_code'] ?? '',
        locationName: json['location_name'],
        locationNameEn: json['location_name_en'],
        locationType: json['location_type'] ?? 'BIN',
        categoryId: json['category_id'],
        categoryCode: json['category_code'],
        categoryNameTh: json['category_name_th'],
        categoryNameEn: json['category_name_en'],
        isActive: json['is_active'] ?? true,
        sortOrder: json['sort_order'],
        isDefault: json['is_default'] ?? false,
        itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
        defaultCount: (json['default_count'] as num?)?.toInt() ?? 0,
      );

  // ชื่อตามภาษาที่เลือก — ไม่มีชื่ออังกฤษใช้ชื่อไทย
  String displayName(bool isEnglish) =>
      (isEnglish && (locationNameEn ?? '').isNotEmpty ? locationNameEn : locationName) ?? '';

  Map<String, dynamic> toJson() => {
        if (id != 0) 'id': id,
        'warehouse_id': warehouseId,
        'parent_id': parentId,
        'location_code': locationCode,
        'location_name': locationName,
        'location_name_en': locationNameEn,
        'location_type': locationType,
        'category_id': categoryId,
        'is_active': isActive,
        'sort_order': sortOrder,
        'is_default': isDefault,
      };
}

/// สินค้า 1 แถวในตำแหน่ง (ยอดแยกล็อต หรือสินค้าที่ตั้งเป็นตำแหน่งเริ่มต้นแต่ยังไม่มียอด)
class ImLocationItemRow {
  final int itemId;
  final String itemCode;
  final String itemNameTh;
  final String? itemNameEn;
  final String? uomCode;
  final String? uomNameTh;
  final String? uomNameEn;
  final String? locationCode;
  final String? lotNo;
  final double qty;
  final double value;
  final bool isDefault;
  const ImLocationItemRow({required this.itemId, required this.itemCode, required this.itemNameTh, this.itemNameEn,
      this.uomCode, this.uomNameTh, this.uomNameEn, this.locationCode, this.lotNo, this.qty = 0, this.value = 0, this.isDefault = false});

  String displayName(bool isEnglish) => isEnglish && (itemNameEn ?? '').isNotEmpty ? itemNameEn! : itemNameTh;
  String uomName(bool isEnglish) => isEnglish && (uomNameEn ?? '').isNotEmpty ? uomNameEn! : (uomNameTh ?? uomCode ?? '');

  factory ImLocationItemRow.fromJson(Map<String, dynamic> j) => ImLocationItemRow(
        itemId: j['item_id'] as int,
        itemCode: j['item_code'] ?? '',
        itemNameTh: j['item_name_th'] ?? '',
        itemNameEn: j['item_name_en'],
        uomCode: j['uom_code'],
        uomNameTh: j['uom_name_th'],
        uomNameEn: j['uom_name_en'],
        locationCode: j['location_code'],
        lotNo: j['lot_no'],
        qty: double.tryParse('${j['qty'] ?? 0}') ?? 0,
        value: double.tryParse('${j['value'] ?? 0}') ?? 0,
        isDefault: j['is_default'] == true,
      );
}

class ImLocationChildRow {
  final int id;
  final String code;
  final String? nameTh;
  final String? nameEn;
  final String type;
  final int? sortOrder;
  final bool isActive;
  final String? categoryCode;
  final int itemCount;
  final int defaultCount;
  const ImLocationChildRow({required this.id, required this.code, this.nameTh, this.nameEn, this.type = 'BIN', this.sortOrder,
      this.isActive = true, this.categoryCode, this.itemCount = 0, this.defaultCount = 0});

  String displayName(bool isEnglish) => (isEnglish && (nameEn ?? '').isNotEmpty ? nameEn : nameTh) ?? '';

  factory ImLocationChildRow.fromJson(Map<String, dynamic> j) => ImLocationChildRow(
        id: j['id'] as int,
        code: j['location_code'] ?? '',
        nameTh: j['location_name'],
        nameEn: j['location_name_en'],
        type: j['location_type'] ?? 'BIN',
        sortOrder: j['sort_order'],
        isActive: j['is_active'] ?? true,
        categoryCode: j['category_code'],
        itemCount: (j['item_count'] as num?)?.toInt() ?? 0,
        defaultCount: (j['default_count'] as num?)?.toInt() ?? 0,
      );
}

/// สรุปตำแหน่ง — GET im_location/:id/summary (กลุ่ม = รวมทุกช่องเก็บใต้กลุ่ม)
class ImLocationSummary {
  final int itemCount;
  final double stockValue;
  final int defaultCount;
  final int binCount;
  final List<ImLocationItemRow> items;
  final List<ImLocationChildRow> children;
  const ImLocationSummary({this.itemCount = 0, this.stockValue = 0, this.defaultCount = 0, this.binCount = 0,
      this.items = const [], this.children = const []});

  factory ImLocationSummary.fromJson(Map<String, dynamic> j) => ImLocationSummary(
        itemCount: (j['item_count'] as num?)?.toInt() ?? 0,
        stockValue: double.tryParse('${j['stock_value'] ?? 0}') ?? 0,
        defaultCount: (j['default_count'] as num?)?.toInt() ?? 0,
        binCount: (j['bin_count'] as num?)?.toInt() ?? 0,
        items: (j['items'] as List<dynamic>? ?? []).map((e) => ImLocationItemRow.fromJson(e)).toList(),
        children: (j['children'] as List<dynamic>? ?? []).map((e) => ImLocationChildRow.fromJson(e)).toList(),
      );
}
