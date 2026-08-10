// lib/im/models/im_uom.dart

class ImUom {
  final int id;
  final String uomCode;
  final String uomNameTh;
  final String? uomNameEn;
  final bool isActive;

  const ImUom({
    required this.id,
    required this.uomCode,
    required this.uomNameTh,
    this.uomNameEn,
    this.isActive = true,
  });

  factory ImUom.fromJson(Map<String, dynamic> json) => ImUom(
        id: json['id'] as int,
        uomCode: json['uom_code'] ?? '',
        uomNameTh: json['uom_name_th'] ?? '',
        uomNameEn: json['uom_name_en'],
        isActive: json['is_active'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        if (id != 0) 'id': id,
        'uom_code': uomCode,
        'uom_name_th': uomNameTh,
        'uom_name_en': uomNameEn,
        'is_active': isActive,
      };
}
