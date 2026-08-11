// lib/im/models/im_bom.dart

class ImBomDetail {
  final int? id;
  final int? bomHeaderId;
  final int lineNo;
  final int componentItemId;
  final String? componentItemCode;
  final String? componentItemNameTh;
  final String? componentItemNameEn;
  final double quantityPer;
  final int? uomId;
  final String? uomCode;
  final String? uomNameTh;
  final String? uomNameEn;
  final double scrapPercent;

  const ImBomDetail({
    this.id,
    this.bomHeaderId,
    this.lineNo = 1,
    required this.componentItemId,
    this.componentItemCode,
    this.componentItemNameTh,
    this.componentItemNameEn,
    this.quantityPer = 0,
    this.uomId,
    this.uomCode,
    this.uomNameTh,
    this.uomNameEn,
    this.scrapPercent = 0,
  });

  factory ImBomDetail.fromJson(Map<String, dynamic> json) => ImBomDetail(
        id: json['id'],
        bomHeaderId: json['bom_header_id'],
        lineNo: json['line_no'] ?? 1,
        componentItemId: json['component_item_id'] as int,
        componentItemCode: json['component_item_code'],
        componentItemNameTh: json['component_item_name_th'],
        componentItemNameEn: json['component_item_name_en'],
        quantityPer: double.tryParse(json['quantity_per']?.toString() ?? '') ?? 0,
        uomId: json['uom_id'],
        uomCode: json['uom_code'],
        uomNameTh: json['uom_name_th'],
        uomNameEn: json['uom_name_en'],
        scrapPercent: double.tryParse(json['scrap_percent']?.toString() ?? '') ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'component_item_id': componentItemId,
        'quantity_per': quantityPer,
        'uom_id': uomId,
        'scrap_percent': scrapPercent,
      };
}

class ImBomHeader {
  final int? id;
  final int parentItemId;
  final String? parentItemCode;
  final String? parentItemNameTh;
  final String? parentItemNameEn;
  final String bomVersion;
  final double bomQty;
  final int? outputUomId;
  final String? outputUomCode;
  final String? outputUomNameTh;
  final String? outputUomNameEn;
  final bool isActive;
  final DateTime? effectiveDate;
  final int componentCount;
  final List<ImBomDetail> details;

  const ImBomHeader({
    this.id,
    required this.parentItemId,
    this.parentItemCode,
    this.parentItemNameTh,
    this.parentItemNameEn,
    this.bomVersion = '1',
    this.bomQty = 1,
    this.outputUomId,
    this.outputUomCode,
    this.outputUomNameTh,
    this.outputUomNameEn,
    this.isActive = true,
    this.effectiveDate,
    this.componentCount = 0,
    this.details = const [],
  });

  factory ImBomHeader.fromJson(Map<String, dynamic> json) => ImBomHeader(
        id: json['id'],
        parentItemId: json['parent_item_id'] as int,
        parentItemCode: json['parent_item_code'],
        parentItemNameTh: json['parent_item_name_th'],
        parentItemNameEn: json['parent_item_name_en'],
        bomVersion: json['bom_version'] ?? '1',
        bomQty: double.tryParse(json['bom_qty']?.toString() ?? '') ?? 1,
        outputUomId: json['output_uom_id'],
        outputUomCode: json['output_uom_code'],
        outputUomNameTh: json['output_uom_name_th'],
        outputUomNameEn: json['output_uom_name_en'],
        isActive: json['is_active'] ?? true,
        effectiveDate: json['effective_date'] != null ? DateTime.tryParse(json['effective_date']) : null,
        componentCount: int.tryParse(json['component_count']?.toString() ?? '') ?? 0,
        details: (json['details'] as List<dynamic>? ?? []).map((e) => ImBomDetail.fromJson(e)).toList(),
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'parent_item_id': parentItemId,
        'bom_version': bomVersion,
        'bom_qty': bomQty,
        'output_uom_id': outputUomId,
        'is_active': isActive,
        'effective_date': effectiveDate?.toIso8601String().substring(0, 10),
        'details': details.map((e) => e.toJson()).toList(),
      };
}
