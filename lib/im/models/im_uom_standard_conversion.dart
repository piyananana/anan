// lib/im/models/im_uom_standard_conversion.dart
// อัตราแปลงมาตรฐานระหว่างหน่วยนับ ที่ไม่ขึ้นกับสินค้า: 1 [from] = conversionFactor [to]

class ImUomStandardConversion {
  final int id;
  final int fromUomId;
  final int toUomId;
  final double conversionFactor;
  final String fromUomCode;
  final String fromUomNameTh;
  final String? fromUomNameEn;
  final String toUomCode;
  final String toUomNameTh;
  final String? toUomNameEn;

  const ImUomStandardConversion({
    required this.id,
    required this.fromUomId,
    required this.toUomId,
    required this.conversionFactor,
    this.fromUomCode = '',
    this.fromUomNameTh = '',
    this.fromUomNameEn,
    this.toUomCode = '',
    this.toUomNameTh = '',
    this.toUomNameEn,
  });

  factory ImUomStandardConversion.fromJson(Map<String, dynamic> j) => ImUomStandardConversion(
        id: j['id'] as int,
        fromUomId: j['from_uom_id'] as int,
        toUomId: j['to_uom_id'] as int,
        conversionFactor: double.tryParse('${j['conversion_factor']}') ?? 0,
        fromUomCode: j['from_uom_code'] ?? '',
        fromUomNameTh: j['from_uom_name_th'] ?? '',
        fromUomNameEn: j['from_uom_name_en'],
        toUomCode: j['to_uom_code'] ?? '',
        toUomNameTh: j['to_uom_name_th'] ?? '',
        toUomNameEn: j['to_uom_name_en'],
      );

  Map<String, dynamic> toJson() => {
        'from_uom_id': fromUomId,
        'to_uom_id': toUomId,
        'conversion_factor': conversionFactor,
      };

  String fromName(bool isEnglish) => isEnglish && (fromUomNameEn ?? '').isNotEmpty ? fromUomNameEn! : fromUomNameTh;
  String toName(bool isEnglish) => isEnglish && (toUomNameEn ?? '').isNotEmpty ? toUomNameEn! : toUomNameTh;
}
