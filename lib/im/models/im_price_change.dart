// lib/im/models/im_price_change.dart
// ธุรกรรมเปลี่ยนแปลงราคา — พักรายการปรับราคาจำนวนมากไว้ตรวจสอบก่อนมีผลจริง
// สถานะ: Draft (แก้ไขได้) -> Pending (ส่งขออนุมัติ) -> Approved (เขียนผลจริง) / กลับ Draft (ไม่อนุมัติ) / Void

const List<String> imPriceChangeTypes = ['REVISE', 'PROMOTION'];
String imPriceChangeTypeLabel(String type, bool isEnglish) {
  if (type == 'PROMOTION') return isEnglish ? 'Promotion (temporary)' : 'โปรโมชั่น (ชั่วคราว)';
  return isEnglish ? 'Revise (permanent)' : 'ปรับถาวร';
}

const List<String> imPriceChangeAdjustmentModes = ['PERCENT', 'AMOUNT', 'SET_PRICE'];
String imPriceChangeAdjustmentModeLabel(String mode, bool isEnglish) {
  switch (mode) {
    case 'AMOUNT':    return isEnglish ? 'Amount' : 'จำนวนเงิน';
    case 'SET_PRICE': return isEnglish ? 'Set price' : 'ตั้งราคาใหม่';
    default:          return isEnglish ? 'Percent' : 'เปอร์เซ็นต์';
  }
}

const List<String> imPriceChangeDirections = ['INCREASE', 'DECREASE'];
String imPriceChangeDirectionLabel(String dir, bool isEnglish) {
  if (dir == 'DECREASE') return isEnglish ? 'Decrease' : 'ปรับลง';
  return isEnglish ? 'Increase' : 'ปรับขึ้น';
}

const List<String> imPriceChangeStatuses = ['Draft', 'Pending', 'Approved', 'Void'];
String imPriceChangeStatusLabel(String status, bool isEnglish) {
  switch (status) {
    case 'Pending':  return isEnglish ? 'Pending Approval' : 'รออนุมัติ';
    case 'Approved': return isEnglish ? 'Approved' : 'อนุมัติแล้ว';
    case 'Void':      return isEnglish ? 'Void' : 'ยกเลิก';
    default:          return isEnglish ? 'Draft' : 'ร่าง';
  }
}

class ImPriceChangeDetail {
  final int? id;
  final int? headerId;
  final int itemId;
  final String? itemCode;
  final String? itemNameTh;
  final String? itemNameEn;
  final int? categoryId;
  final String? categoryCode;
  final String? categoryNameTh;
  final String? categoryNameEn;
  final int? uomId;
  final String? uomCode;
  final String? uomNameTh;
  final String? uomNameEn;
  final double minQty;
  // แถวราคาปัจจุบัน (STANDARD) ที่บรรทัดนี้จะปิด/อ้างอิง — null = สินค้ายังไม่มีราคาในลิสต์นี้เลย (รายการใหม่)
  final int? sourceDetailId;
  final double? oldUnitPriceFc;
  final double newUnitPriceFc;
  final bool isSelected;

  const ImPriceChangeDetail({
    this.id,
    this.headerId,
    required this.itemId,
    this.itemCode,
    this.itemNameTh,
    this.itemNameEn,
    this.categoryId,
    this.categoryCode,
    this.categoryNameTh,
    this.categoryNameEn,
    this.uomId,
    this.uomCode,
    this.uomNameTh,
    this.uomNameEn,
    this.minQty = 0,
    this.sourceDetailId,
    this.oldUnitPriceFc,
    this.newUnitPriceFc = 0,
    this.isSelected = true,
  });

  bool get isNewItem => sourceDetailId == null;

  double get percentChange {
    final old = oldUnitPriceFc;
    if (old == null || old == 0) return 0;
    return (newUnitPriceFc - old) / old * 100;
  }

  factory ImPriceChangeDetail.fromJson(Map<String, dynamic> json) => ImPriceChangeDetail(
        id: json['id'],
        headerId: json['header_id'],
        itemId: json['item_id'] as int,
        itemCode: json['item_code'],
        itemNameTh: json['item_name_th'],
        itemNameEn: json['item_name_en'],
        categoryId: json['category_id'],
        categoryCode: json['category_code'],
        categoryNameTh: json['category_name_th'],
        categoryNameEn: json['category_name_en'],
        uomId: json['uom_id'],
        uomCode: json['uom_code'],
        uomNameTh: json['uom_name_th'],
        uomNameEn: json['uom_name_en'],
        minQty: double.tryParse(json['min_qty']?.toString() ?? '') ?? 0,
        sourceDetailId: json['source_detail_id'],
        oldUnitPriceFc: json['old_unit_price_fc'] != null ? double.tryParse(json['old_unit_price_fc'].toString()) : null,
        newUnitPriceFc: double.tryParse(json['new_unit_price_fc']?.toString() ?? '') ?? 0,
        isSelected: json['is_selected'] ?? true,
      );

  // แถวจาก GET /im_price_change/preview_lines — ยังไม่มี new_unit_price_fc ให้ตั้งต้นเท่าราคาเดิมไว้ก่อน
  // (คำนวณใหม่ตามส่วนปรับจริงเมื่อผู้ใช้กด "คำนวณราคาใหม่")
  factory ImPriceChangeDetail.fromPreviewJson(Map<String, dynamic> json) => ImPriceChangeDetail(
        itemId: json['item_id'] as int,
        itemCode: json['item_code'],
        itemNameTh: json['item_name_th'],
        itemNameEn: json['item_name_en'],
        categoryId: json['category_id'],
        categoryCode: json['category_code'],
        categoryNameTh: json['category_name_th'],
        categoryNameEn: json['category_name_en'],
        uomId: json['uom_id'],
        uomCode: json['uom_code'],
        uomNameTh: json['uom_name_th'],
        uomNameEn: json['uom_name_en'],
        minQty: double.tryParse(json['min_qty']?.toString() ?? '') ?? 0,
        sourceDetailId: json['source_detail_id'],
        oldUnitPriceFc: json['old_unit_price_fc'] != null ? double.tryParse(json['old_unit_price_fc'].toString()) : null,
        newUnitPriceFc: double.tryParse(json['old_unit_price_fc']?.toString() ?? '') ?? 0,
        isSelected: json['source_detail_id'] != null,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'item_id': itemId,
        'uom_id': uomId,
        'min_qty': minQty,
        'source_detail_id': sourceDetailId,
        'old_unit_price_fc': oldUnitPriceFc,
        'new_unit_price_fc': newUnitPriceFc,
        'is_selected': isSelected,
      };

  ImPriceChangeDetail copyWith({double? newUnitPriceFc, bool? isSelected}) => ImPriceChangeDetail(
        id: id, headerId: headerId, itemId: itemId, itemCode: itemCode, itemNameTh: itemNameTh, itemNameEn: itemNameEn,
        categoryId: categoryId, categoryCode: categoryCode, categoryNameTh: categoryNameTh, categoryNameEn: categoryNameEn,
        uomId: uomId, uomCode: uomCode, uomNameTh: uomNameTh, uomNameEn: uomNameEn, minQty: minQty,
        sourceDetailId: sourceDetailId, oldUnitPriceFc: oldUnitPriceFc,
        newUnitPriceFc: newUnitPriceFc ?? this.newUnitPriceFc, isSelected: isSelected ?? this.isSelected,
      );
}

class ImPriceChangeHeader {
  final int? id;
  // ประเภทเอกสาร (sa_module_document, sys_doc_type='85') — ใช้ระบบเดียวกับธุรกรรม IM ปกติ (GRN/DLN/AJS ฯลฯ):
  // เลือกครั้งเดียวตอนสร้าง (ล็อกถาวรหลังบันทึกครั้งแรก เพราะเลขที่ถูกออกจาก config ของ doc_id นี้ไปแล้ว)
  final int? docId;
  final String? docCode;
  final String? docNameThai;
  final String? docNameEng;
  final String? changeNo;
  final int? priceListId;
  final String? priceListCode;
  final String? priceListName;
  final String? listType;
  final String changeType;
  final String adjustmentMode;
  final String adjustmentDirection;
  final double adjustmentValue;
  // ปัดเศษราคาใหม่ที่คำนวณจาก % ให้สอดคล้องกับเงินจริง (0 = ไม่ปัดเศษ) — ใช้เฉพาะ adjustmentMode == 'PERCENT'
  final double roundingStep;
  final DateTime? effectiveFrom;
  final DateTime? effectiveTo;
  final List<int> categoryFilter;
  final String? itemCodeFrom;
  final String? itemCodeTo;
  final String status;
  final String? remark;
  final DateTime? approvedAt;
  final String? approvedBy;
  final int lineCount;
  final int selectedCount;
  final List<ImPriceChangeDetail> details;

  const ImPriceChangeHeader({
    this.id,
    this.docId,
    this.docCode,
    this.docNameThai,
    this.docNameEng,
    this.changeNo,
    this.priceListId,
    this.priceListCode,
    this.priceListName,
    this.listType,
    this.changeType = 'REVISE',
    this.adjustmentMode = 'PERCENT',
    this.adjustmentDirection = 'INCREASE',
    this.adjustmentValue = 0,
    this.roundingStep = 0,
    this.effectiveFrom,
    this.effectiveTo,
    this.categoryFilter = const [],
    this.itemCodeFrom,
    this.itemCodeTo,
    this.status = 'Draft',
    this.remark,
    this.approvedAt,
    this.approvedBy,
    this.lineCount = 0,
    this.selectedCount = 0,
    this.details = const [],
  });

  factory ImPriceChangeHeader.fromJson(Map<String, dynamic> json) => ImPriceChangeHeader(
        id: json['id'],
        docId: json['doc_id'],
        docCode: json['doc_code'],
        docNameThai: json['doc_name_thai'],
        docNameEng: json['doc_name_eng'],
        changeNo: json['change_no'],
        priceListId: json['price_list_id'],
        priceListCode: json['price_list_code'],
        priceListName: json['price_list_name'],
        listType: json['list_type'],
        changeType: json['change_type'] ?? 'REVISE',
        adjustmentMode: json['adjustment_mode'] ?? 'PERCENT',
        adjustmentDirection: json['adjustment_direction'] ?? 'INCREASE',
        adjustmentValue: double.tryParse(json['adjustment_value']?.toString() ?? '') ?? 0,
        roundingStep: double.tryParse(json['rounding_step']?.toString() ?? '') ?? 0,
        effectiveFrom: json['effective_from'] != null ? DateTime.tryParse(json['effective_from']) : null,
        effectiveTo: json['effective_to'] != null ? DateTime.tryParse(json['effective_to']) : null,
        categoryFilter: (json['category_filter'] as List<dynamic>? ?? []).map((e) => e as int).toList(),
        itemCodeFrom: json['item_code_from'],
        itemCodeTo: json['item_code_to'],
        status: json['status'] ?? 'Draft',
        remark: json['remark'],
        approvedAt: json['approved_at'] != null ? DateTime.tryParse(json['approved_at'].toString()) : null,
        approvedBy: json['approved_by'],
        lineCount: int.tryParse(json['line_count']?.toString() ?? '') ?? 0,
        selectedCount: int.tryParse(json['selected_count']?.toString() ?? '') ?? 0,
        details: (json['details'] as List<dynamic>? ?? []).map((e) => ImPriceChangeDetail.fromJson(e)).toList(),
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'doc_id': docId,
        'price_list_id': priceListId,
        'change_type': changeType,
        'adjustment_mode': adjustmentMode,
        'adjustment_direction': adjustmentDirection,
        'adjustment_value': adjustmentValue,
        'rounding_step': roundingStep,
        'effective_from': effectiveFrom?.toIso8601String().substring(0, 10),
        'effective_to': effectiveTo?.toIso8601String().substring(0, 10),
        'category_filter': categoryFilter,
        'item_code_from': itemCodeFrom,
        'item_code_to': itemCodeTo,
        'remark': remark,
        'details': details.map((e) => e.toJson()).toList(),
      };
}
