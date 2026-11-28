// lib/im/models/im_uom.dart

/// ประเภทหน่วย (im_uom.uom_dimension) — อัตราแปลงมาตรฐานใช้ได้เฉพาะหน่วยประเภทเดียวกัน
const List<String> kUomDimensions = ['COUNT', 'WEIGHT', 'LENGTH', 'VOLUME', 'AREA', 'TIME'];

String uomDimensionLabel(String dimension, bool isEnglish) {
  switch (dimension) {
    case 'WEIGHT': return isEnglish ? 'Weight' : 'น้ำหนัก';
    case 'LENGTH': return isEnglish ? 'Length' : 'ความยาว';
    case 'VOLUME': return isEnglish ? 'Volume' : 'ปริมาตร';
    case 'AREA':   return isEnglish ? 'Area' : 'พื้นที่';
    case 'TIME':   return isEnglish ? 'Time' : 'เวลา';
    default:       return isEnglish ? 'Count' : 'นับจำนวน';
  }
}

class ImUom {
  final int id;
  final String uomCode;
  final String uomNameTh;
  final String? uomNameEn;
  final bool isActive;
  final String uomDimension; // COUNT/WEIGHT/LENGTH/VOLUME/AREA/TIME
  final int decimalPlaces;   // ทศนิยมที่ยอมให้ป้อน 0-4
  // จาก GET im_uom?with_usage=1 เท่านั้น (หน้าจอหน่วยนับ)
  final int baseItemCount;
  final int altItemCount;

  const ImUom({
    required this.id,
    required this.uomCode,
    required this.uomNameTh,
    this.uomNameEn,
    this.isActive = true,
    this.uomDimension = 'COUNT',
    this.decimalPlaces = 0,
    this.baseItemCount = 0,
    this.altItemCount = 0,
  });

  String displayName(bool isEnglish) =>
      isEnglish && (uomNameEn ?? '').isNotEmpty ? uomNameEn! : uomNameTh;

  factory ImUom.fromJson(Map<String, dynamic> json) => ImUom(
        id: json['id'] as int,
        uomCode: json['uom_code'] ?? '',
        uomNameTh: json['uom_name_th'] ?? '',
        uomNameEn: json['uom_name_en'],
        isActive: json['is_active'] ?? true,
        uomDimension: (json['uom_dimension'] as String?) ?? 'COUNT',
        decimalPlaces: (json['decimal_places'] as num?)?.toInt() ?? 0,
        baseItemCount: (json['base_item_count'] as num?)?.toInt() ?? 0,
        altItemCount: (json['alt_item_count'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        if (id != 0) 'id': id,
        'uom_code': uomCode,
        'uom_name_th': uomNameTh,
        'uom_name_en': uomNameEn,
        'is_active': isActive,
        'uom_dimension': uomDimension,
        'decimal_places': decimalPlaces,
      };
}

/// สินค้าที่ใช้หน่วยนี้ 1 รายการ — role BASE (หน่วยหลัก) / ALT (หน่วยรอง: 1 หน่วยนี้ = factor × baseUomCode)
class ImUomItemUse {
  final int itemId;
  final String itemCode;
  final String itemNameTh;
  final String? itemNameEn;
  final String role;
  final double factor;
  final String? baseUomCode;
  const ImUomItemUse({required this.itemId, required this.itemCode, required this.itemNameTh, this.itemNameEn,
      required this.role, this.factor = 1, this.baseUomCode});

  String displayName(bool isEnglish) => isEnglish && (itemNameEn ?? '').isNotEmpty ? itemNameEn! : itemNameTh;

  factory ImUomItemUse.fromJson(Map<String, dynamic> j) => ImUomItemUse(
        itemId: j['item_id'] as int,
        itemCode: j['item_code'] ?? '',
        itemNameTh: j['item_name_th'] ?? '',
        itemNameEn: j['item_name_en'],
        role: j['role'] ?? 'BASE',
        factor: double.tryParse('${j['factor']}') ?? 1,
        baseUomCode: j['base_uom_code'],
      );
}

/// สรุปการใช้หน่วยนับ — GET im_uom/:id/summary
class ImUomSummary {
  final int baseCount;
  final int altCount;
  final List<String> stdConversions;
  final DateTime? lastDocDate;
  final String? lastDocNo;
  final String? lastDocCode;
  final List<ImUomItemUse> items;
  const ImUomSummary({this.baseCount = 0, this.altCount = 0, this.stdConversions = const [], this.lastDocDate,
      this.lastDocNo, this.lastDocCode, this.items = const []});

  factory ImUomSummary.fromJson(Map<String, dynamic> j) {
    final ld = j['last_doc'] as Map<String, dynamic>?;
    DateTime? d;
    final ds = ld?['doc_date']?.toString();
    if (ds != null && ds.length >= 10) {
      final p = ds.substring(0, 10).split('-');
      d = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    }
    return ImUomSummary(
      baseCount: (j['base_count'] as num?)?.toInt() ?? 0,
      altCount: (j['alt_count'] as num?)?.toInt() ?? 0,
      stdConversions: (j['std_conversions'] as List<dynamic>? ?? []).map((e) => '$e').toList(),
      lastDocDate: d,
      lastDocNo: ld?['doc_no'],
      lastDocCode: ld?['doc_code'],
      items: (j['items'] as List<dynamic>? ?? []).map((e) => ImUomItemUse.fromJson(e)).toList(),
    );
  }
}
