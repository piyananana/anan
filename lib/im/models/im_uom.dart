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

  const ImUom({
    required this.id,
    required this.uomCode,
    required this.uomNameTh,
    this.uomNameEn,
    this.isActive = true,
    this.uomDimension = 'COUNT',
    this.decimalPlaces = 0,
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
