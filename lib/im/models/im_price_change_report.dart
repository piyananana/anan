// lib/im/models/im_price_change_report.dart
// รายงานตรวจเช็คการเปลี่ยนแปลงราคา — หนึ่งแถว = หนึ่งบรรทัดสินค้าในธุรกรรมเปลี่ยนแปลงราคาหนึ่งใบ (เฉพาะที่
// is_selected=true และธุรกรรมไม่ใช่ Void) ราคาเก่า/ใหม่เป็นค่าที่ snapshot ไว้ตอนสร้างธุรกรรม

const List<String> imPriceChangeReportStatuses = ['Draft', 'Pending', 'Approved'];
String imPriceChangeReportStatusLabel(String status, bool isEnglish) {
  switch (status) {
    case 'Pending':  return isEnglish ? 'Pending Approval' : 'รออนุมัติ';
    case 'Approved': return isEnglish ? 'History (Approved)' : 'ประวัติการเปลี่ยนแปลง';
    default:          return isEnglish ? 'Draft' : 'ร่าง';
  }
}

const List<String> imPriceChangeActiveStatuses = ['ALL', 'ACTIVE', 'INACTIVE'];
String imPriceChangeActiveStatusLabel(String status, bool isEnglish) {
  switch (status) {
    case 'ACTIVE':   return isEnglish ? 'Active' : 'ใช้งาน';
    case 'INACTIVE': return isEnglish ? 'Inactive' : 'ไม่ใช้';
    default:          return isEnglish ? 'All' : 'ทั้งหมด';
  }
}

class ImPriceChangeReportRow {
  final int headerId;
  final String? changeNo;
  final String changeStatus; // Draft | Pending | Approved
  final String changeType; // REVISE | PROMOTION
  final DateTime? effectiveFrom;
  final DateTime? effectiveTo;
  final DateTime? approvedAt;
  final String? approvedBy;
  final int detailId;
  final int itemId;
  final double minQty;
  final double? oldUnitPriceFc;
  final double newUnitPriceFc;
  final int? priceListId;
  final String? priceListCode;
  final String? priceListName;
  final int? priceGroupId;
  final String? priceGroupCode;
  final String? priceGroupNameTh;
  final String? priceGroupNameEn;
  final String? itemCode;
  final String? itemNameTh;
  final String? itemNameEn;
  final int? categoryId;
  final String? categoryCode;
  final String? categoryNameTh;
  final String? categoryNameEn;
  final String? uomCode;
  final String? uomNameTh;
  final String? uomNameEn;
  // ใช้งาน/ไม่ใช้ — มีค่าเฉพาะรายการที่อนุมัติแล้ว (null = Draft/Pending ยังไม่มีแถวราคาจริงให้ตรวจสอบ)
  final String? resultStatus;

  const ImPriceChangeReportRow({
    required this.headerId,
    this.changeNo,
    required this.changeStatus,
    required this.changeType,
    this.effectiveFrom,
    this.effectiveTo,
    this.approvedAt,
    this.approvedBy,
    required this.detailId,
    required this.itemId,
    this.minQty = 0,
    this.oldUnitPriceFc,
    this.newUnitPriceFc = 0,
    this.priceListId,
    this.priceListCode,
    this.priceListName,
    this.priceGroupId,
    this.priceGroupCode,
    this.priceGroupNameTh,
    this.priceGroupNameEn,
    this.itemCode,
    this.itemNameTh,
    this.itemNameEn,
    this.categoryId,
    this.categoryCode,
    this.categoryNameTh,
    this.categoryNameEn,
    this.uomCode,
    this.uomNameTh,
    this.uomNameEn,
    this.resultStatus,
  });

  double get changeAmount => (newUnitPriceFc) - (oldUnitPriceFc ?? 0);
  double get changePercent {
    final old = oldUnitPriceFc;
    if (old == null || old == 0) return 0;
    return (newUnitPriceFc - old) / old * 100;
  }

  factory ImPriceChangeReportRow.fromJson(Map<String, dynamic> json) => ImPriceChangeReportRow(
        headerId: json['header_id'] as int,
        changeNo: json['change_no'],
        changeStatus: json['change_status'] ?? 'Draft',
        changeType: json['change_type'] ?? 'REVISE',
        effectiveFrom: json['effective_from'] != null ? DateTime.tryParse(json['effective_from']) : null,
        effectiveTo: json['effective_to'] != null ? DateTime.tryParse(json['effective_to']) : null,
        approvedAt: json['approved_at'] != null ? DateTime.tryParse(json['approved_at'].toString()) : null,
        approvedBy: json['approved_by'],
        detailId: json['detail_id'] as int,
        itemId: json['item_id'] as int,
        minQty: double.tryParse(json['min_qty']?.toString() ?? '') ?? 0,
        oldUnitPriceFc: json['old_unit_price_fc'] != null ? double.tryParse(json['old_unit_price_fc'].toString()) : null,
        newUnitPriceFc: double.tryParse(json['new_unit_price_fc']?.toString() ?? '') ?? 0,
        priceListId: json['price_list_id'],
        priceListCode: json['price_list_code'],
        priceListName: json['price_list_name'],
        priceGroupId: json['price_group_id'],
        priceGroupCode: json['price_group_code'],
        priceGroupNameTh: json['price_group_name_th'],
        priceGroupNameEn: json['price_group_name_en'],
        itemCode: json['item_code'],
        itemNameTh: json['item_name_th'],
        itemNameEn: json['item_name_en'],
        categoryId: json['category_id'],
        categoryCode: json['category_code'],
        categoryNameTh: json['category_name_th'],
        categoryNameEn: json['category_name_en'],
        uomCode: json['uom_code'],
        uomNameTh: json['uom_name_th'],
        uomNameEn: json['uom_name_en'],
        resultStatus: json['result_status'],
      );
}

/// แถวสินค้าแบบย่อ — ใช้กับ dialog ค้นหาสินค้าจาก-ถึง ของหน้ารายงานนี้โดยเฉพาะ (ขอบเขตแค่สินค้าที่เคยตั้งราคาไว้)
class ImPriceChangeReportItem {
  final int id;
  final String itemCode;
  final String itemNameTh;
  final String? itemNameEn;

  const ImPriceChangeReportItem({
    required this.id,
    required this.itemCode,
    required this.itemNameTh,
    this.itemNameEn,
  });

  factory ImPriceChangeReportItem.fromJson(Map<String, dynamic> json) => ImPriceChangeReportItem(
        id: json['id'] as int,
        itemCode: json['item_code'] ?? '',
        itemNameTh: json['item_name_th'] ?? '',
        itemNameEn: json['item_name_en'],
      );
}
