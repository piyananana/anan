// lib/im/models/im_price_list.dart

const List<String> imPriceListTypes = ['SALES', 'PURCHASE'];

String imPriceListTypeLabel(String type, bool isEnglish) {
  if (type == 'SALES') return isEnglish ? 'Sales' : 'ราคาขาย';
  if (type == 'PURCHASE') return isEnglish ? 'Purchase' : 'ราคาซื้อ';
  return type;
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
  final DateTime? effectiveFrom;
  final DateTime? effectiveTo;

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
    this.effectiveFrom,
    this.effectiveTo,
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
        effectiveFrom: json['effective_from'] != null ? DateTime.tryParse(json['effective_from']) : null,
        effectiveTo: json['effective_to'] != null ? DateTime.tryParse(json['effective_to']) : null,
      );

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'uom_id': uomId,
        'min_qty': minQty,
        'unit_price_fc': unitPriceFc,
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
  final String? currencyCode;
  final String? uomCode;
  final double minQty;
  final double unitPriceFc;
  final DateTime? effectiveFrom;
  final DateTime? effectiveTo;

  const ImItemPriceRow({
    required this.detailId,
    required this.priceListCode,
    required this.priceListName,
    required this.listType,
    this.currencyCode,
    this.uomCode,
    this.minQty = 0,
    this.unitPriceFc = 0,
    this.effectiveFrom,
    this.effectiveTo,
  });

  factory ImItemPriceRow.fromJson(Map<String, dynamic> json) => ImItemPriceRow(
        detailId: json['id'] as int,
        priceListCode: json['price_list_code'] ?? '',
        priceListName: json['price_list_name'] ?? '',
        listType: json['list_type'] ?? 'SALES',
        currencyCode: json['currency_code'],
        uomCode: json['uom_code'],
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
        'is_active': isActive,
        'details': details.map((e) => e.toJson()).toList(),
      };
}
