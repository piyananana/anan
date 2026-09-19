// lib/po/models/po_replenishment.dart — ใบแนะนำสั่งซื้อเพื่อเติมสต็อก (อ่านอย่างเดียว)
class ReplenishmentSuggestion {
  final int itemId;
  final String itemCode;
  final String itemNameTh;
  final String? itemNameEn;
  final int? uomId;
  final String? uomCode;
  final double onHand;
  final double incoming;
  final double avgDailySales;
  final double projectedDemand;
  final double reorderPoint;
  final double maxStockQty;
  double suggestedQty; // ผู้ใช้แก้ไขได้ก่อนสร้างเอกสาร
  int? vendorId; // ผู้ใช้แก้ไข/เลือกใหม่ได้ก่อนสร้างเอกสาร (โดยเฉพาะตอนสร้าง PO ที่บังคับต้องมีผู้ขาย)
  String? vendorCode;
  String? vendorNameTh;
  final double? lastPrice;
  final DateTime? lastPurchaseDate;

  ReplenishmentSuggestion({
    required this.itemId,
    required this.itemCode,
    required this.itemNameTh,
    this.itemNameEn,
    this.uomId,
    this.uomCode,
    required this.onHand,
    required this.incoming,
    required this.avgDailySales,
    required this.projectedDemand,
    required this.reorderPoint,
    required this.maxStockQty,
    required this.suggestedQty,
    this.vendorId,
    this.vendorCode,
    this.vendorNameTh,
    this.lastPrice,
    this.lastPurchaseDate,
  });

  factory ReplenishmentSuggestion.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    double? toDoubleN(dynamic v) => v == null ? null : double.tryParse(v.toString());
    return ReplenishmentSuggestion(
      itemId: json['item_id'] ?? 0,
      itemCode: json['item_code'] ?? '',
      itemNameTh: json['item_name_th'] ?? '',
      itemNameEn: json['item_name_en'],
      uomId: json['uom_id'],
      uomCode: json['uom_code'],
      onHand: toDouble(json['on_hand']),
      incoming: toDouble(json['incoming']),
      avgDailySales: toDouble(json['avg_daily_sales']),
      projectedDemand: toDouble(json['projected_demand']),
      reorderPoint: toDouble(json['reorder_point']),
      maxStockQty: toDouble(json['max_stock_qty']),
      suggestedQty: toDouble(json['suggested_qty']),
      vendorId: json['vendor_id'],
      vendorCode: json['vendor_code'],
      vendorNameTh: json['vendor_name_th'],
      lastPrice: toDoubleN(json['last_price']),
      lastPurchaseDate: json['last_purchase_date'] != null ? DateTime.tryParse(json['last_purchase_date'].toString()) : null,
    );
  }
}
