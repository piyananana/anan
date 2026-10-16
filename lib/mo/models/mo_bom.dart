// lib/mo/models/mo_bom.dart — ย้ายมาจาก lib/im/models/im_bom.dart (BOM ย้ายจาก IM ไปอยู่ใต้โมดูล MO/สั่งผลิต
// เพราะเป็น "สูตรการผลิต" ซึ่งเป็นแนวคิดของงานผลิตโดยตรง ไม่ใช่ของคลังสินค้า)
import '../../utils/date_utils.dart';

const List<String> moIssueMethods = ['BACKFLUSH', 'EXPLICIT'];
String moIssueMethodLabel(String v, bool isEnglish) {
  if (v == 'BACKFLUSH') return isEnglish ? 'Backflush (auto from BOM at receipt)' : 'อัตโนมัติตามสูตร (Backflush)';
  return isEnglish ? 'Explicit (issue separately)' : 'เบิกแยกจากรับเข้าผลิต (Explicit)';
}

const List<String> moCostingMethods = ['ACTUAL', 'STANDARD'];
String moCostingMethodLabel(String v, bool isEnglish) {
  if (v == 'STANDARD') return isEnglish ? 'Standard Cost' : 'ต้นทุนมาตรฐาน (Standard)';
  return isEnglish ? 'Actual Cost' : 'ต้นทุนจริง (Actual)';
}

const List<String> moCostingModes = ['OVERHEAD_PERCENT', 'ROUTING'];
String moCostingModeLabel(String v, bool isEnglish) {
  if (v == 'ROUTING') return isEnglish ? 'Routing (Work Center hours)' : 'ตามขั้นตอนผลิต (Routing/ศูนย์งาน)';
  return isEnglish ? 'Overhead %' : 'เปอร์เซ็นต์ Overhead';
}

class MoBomDetail {
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
  // ปักหมุดว่า component นี้ (ถ้าผลิตเองมี BOM ของตัวเอง) ใช้ mo_bom_header เวอร์ชันไหนตอน explode เป็น MO ย่อย —
  // null = ยังไม่ปักหมุด (ใช้ลิสต์ active ของสินค้านั้นตอน explode จริง) หรือเป็นสินค้าซื้อ/สต็อกปกติ (leaf)
  final int? componentBomHeaderId;
  final String? componentBomVersion;
  // id ของ mo_bom_header ที่ active อยู่ของ component_item_id นี้ (ถ้ามี) — ใช้บอกฝั่ง UI ว่าสินค้านี้ "ผลิตเองได้"
  // แม้บรรทัดนี้ยังไม่ได้ปักหมุด component_bom_header_id ไว้ก็ตาม (ดูปุ่ม "สร้างใบสั่งผลิตย่อย")
  final int? componentActiveBomId;

  const MoBomDetail({
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
    this.componentBomHeaderId,
    this.componentBomVersion,
    this.componentActiveBomId,
  });

  // true = สินค้าส่วนประกอบตัวนี้ผลิตเองได้ (มี BOM ของตัวเองที่ active) — ใช้โชว์ตัวเลือก "สร้างใบสั่งผลิตย่อย"
  bool get hasOwnBom => componentActiveBomId != null;

  factory MoBomDetail.fromJson(Map<String, dynamic> json) => MoBomDetail(
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
        componentBomHeaderId: json['component_bom_header_id'],
        componentBomVersion: json['component_bom_version'],
        componentActiveBomId: json['component_active_bom_id'],
      );

  Map<String, dynamic> toJson() => {
        'component_item_id': componentItemId,
        'quantity_per': quantityPer,
        'uom_id': uomId,
        'scrap_percent': scrapPercent,
        'component_bom_header_id': componentBomHeaderId,
      };
}

// ผลิตภัณฑ์ร่วม (co-products) — ผลผลิตเพิ่มเติมนอกจาก parentItemId/bomQty/outputUomId ของ MoBomHeader ที่เป็น
// ผลผลิตหลักอยู่แล้ว (ไม่ย้ายมาคลาสนี้ เพื่อไม่กระทบ BOM เดิมที่มีผลผลิตเดียว)
class MoBomOutputDetail {
  final int? id;
  final int? bomHeaderId;
  final int lineNo;
  final int outputItemId;
  final String? outputItemCode;
  final String? outputItemNameTh;
  final String? outputItemNameEn;
  final double outputQtyPer;
  final int? uomId;
  final String? uomCode;
  final String? uomNameTh;
  final String? uomNameEn;

  const MoBomOutputDetail({
    this.id,
    this.bomHeaderId,
    this.lineNo = 1,
    required this.outputItemId,
    this.outputItemCode,
    this.outputItemNameTh,
    this.outputItemNameEn,
    this.outputQtyPer = 0,
    this.uomId,
    this.uomCode,
    this.uomNameTh,
    this.uomNameEn,
  });

  factory MoBomOutputDetail.fromJson(Map<String, dynamic> json) => MoBomOutputDetail(
        id: json['id'],
        bomHeaderId: json['bom_header_id'],
        lineNo: json['line_no'] ?? 1,
        outputItemId: json['output_item_id'] as int,
        outputItemCode: json['output_item_code'],
        outputItemNameTh: json['output_item_name_th'],
        outputItemNameEn: json['output_item_name_en'],
        outputQtyPer: double.tryParse(json['output_qty_per']?.toString() ?? '') ?? 0,
        uomId: json['uom_id'],
        uomCode: json['uom_code'],
        uomNameTh: json['uom_name_th'],
        uomNameEn: json['uom_name_en'],
      );

  Map<String, dynamic> toJson() => {
        'output_item_id': outputItemId,
        'output_qty_per': outputQtyPer,
        'uom_id': uomId,
      };
}

// ขั้นตอนการผลิต (Routing) — ใช้จริงเมื่อ costingMode='ROUTING' เท่านั้น
class MoBomOperationDetail {
  final int? id;
  final int? bomHeaderId;
  final int lineNo;
  final int workCenterId;
  final String? workCenterCode;
  final String? workCenterNameTh;
  final String? workCenterNameEn;
  final String? operationName;
  final double standardLaborHours;
  final double standardMachineHours;
  final double setupHours;

  const MoBomOperationDetail({
    this.id,
    this.bomHeaderId,
    this.lineNo = 1,
    required this.workCenterId,
    this.workCenterCode,
    this.workCenterNameTh,
    this.workCenterNameEn,
    this.operationName,
    this.standardLaborHours = 0,
    this.standardMachineHours = 0,
    this.setupHours = 0,
  });

  factory MoBomOperationDetail.fromJson(Map<String, dynamic> json) => MoBomOperationDetail(
        id: json['id'],
        bomHeaderId: json['bom_header_id'],
        lineNo: json['line_no'] ?? 1,
        workCenterId: json['work_center_id'] as int,
        workCenterCode: json['work_center_code'],
        workCenterNameTh: json['work_center_name_th'],
        workCenterNameEn: json['work_center_name_en'],
        operationName: json['operation_name'],
        standardLaborHours: double.tryParse(json['standard_labor_hours']?.toString() ?? '') ?? 0,
        standardMachineHours: double.tryParse(json['standard_machine_hours']?.toString() ?? '') ?? 0,
        setupHours: double.tryParse(json['setup_hours']?.toString() ?? '') ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'work_center_id': workCenterId,
        'operation_name': operationName,
        'standard_labor_hours': standardLaborHours,
        'standard_machine_hours': standardMachineHours,
        'setup_hours': setupHours,
      };
}

class MoBomHeader {
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
  final int outputCount;
  final int operationCount;
  final String issueMethod;
  final String costingMethod;
  final String costingMode;
  final double overheadPercent;
  final List<MoBomDetail> details;
  final List<MoBomOutputDetail> outputs;
  final List<MoBomOperationDetail> operations;

  const MoBomHeader({
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
    this.outputCount = 0,
    this.operationCount = 0,
    this.issueMethod = 'EXPLICIT',
    this.costingMethod = 'ACTUAL',
    this.costingMode = 'OVERHEAD_PERCENT',
    this.overheadPercent = 0,
    this.details = const [],
    this.outputs = const [],
    this.operations = const [],
  });

  factory MoBomHeader.fromJson(Map<String, dynamic> json) => MoBomHeader(
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
        effectiveDate: parseLocalDateNullable(json['effective_date']),
        componentCount: int.tryParse(json['component_count']?.toString() ?? '') ?? 0,
        outputCount: int.tryParse(json['output_count']?.toString() ?? '') ?? 0,
        operationCount: int.tryParse(json['operation_count']?.toString() ?? '') ?? 0,
        issueMethod: json['issue_method'] ?? 'EXPLICIT',
        costingMethod: json['costing_method'] ?? 'ACTUAL',
        costingMode: json['costing_mode'] ?? 'OVERHEAD_PERCENT',
        overheadPercent: double.tryParse(json['overhead_percent']?.toString() ?? '') ?? 0,
        details: (json['details'] as List<dynamic>? ?? []).map((e) => MoBomDetail.fromJson(e)).toList(),
        outputs: (json['outputs'] as List<dynamic>? ?? []).map((e) => MoBomOutputDetail.fromJson(e)).toList(),
        operations: (json['operations'] as List<dynamic>? ?? []).map((e) => MoBomOperationDetail.fromJson(e)).toList(),
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'parent_item_id': parentItemId,
        'bom_version': bomVersion,
        'bom_qty': bomQty,
        'output_uom_id': outputUomId,
        'is_active': isActive,
        'effective_date': effectiveDate?.toIso8601String().substring(0, 10),
        'issue_method': issueMethod,
        'costing_method': costingMethod,
        'costing_mode': costingMode,
        'overhead_percent': overheadPercent,
        'details': details.map((e) => e.toJson()).toList(),
        'outputs': outputs.map((e) => e.toJson()).toList(),
        'operations': operations.map((e) => e.toJson()).toList(),
      };
}

class MoBomCostBreakdownLine {
  final int componentItemId;
  final String? componentItemCode;
  final String? componentItemNameTh;
  final String? componentItemNameEn;
  final double quantityPer;
  final double scrapPercent;
  final double unitCost;
  final double lineTotal;
  final bool isSubAssembly;

  const MoBomCostBreakdownLine({
    required this.componentItemId,
    this.componentItemCode,
    this.componentItemNameTh,
    this.componentItemNameEn,
    this.quantityPer = 0,
    this.scrapPercent = 0,
    this.unitCost = 0,
    this.lineTotal = 0,
    this.isSubAssembly = false,
  });

  factory MoBomCostBreakdownLine.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return MoBomCostBreakdownLine(
      componentItemId: json['component_item_id'] ?? 0,
      componentItemCode: json['component_item_code'],
      componentItemNameTh: json['component_item_name_th'],
      componentItemNameEn: json['component_item_name_en'],
      quantityPer: toDouble(json['quantity_per']),
      scrapPercent: toDouble(json['scrap_percent']),
      unitCost: toDouble(json['unit_cost']),
      lineTotal: toDouble(json['line_total']),
      isSubAssembly: json['is_sub_assembly'] ?? false,
    );
  }
}

class MoBomCostRollupRow {
  final int bomHeaderId;
  final String? bomVersion;
  final double bomQty;
  final int? parentItemId;
  final String? parentItemCode;
  final String? parentItemNameTh;
  final String? parentItemNameEn;
  final String costingMode;
  final double overheadPercent;
  final double materialCost;
  final double conversionCost;
  final double totalCost;
  final double unitCost;
  final List<MoBomCostBreakdownLine> breakdown;
  final String? error;

  const MoBomCostRollupRow({
    required this.bomHeaderId,
    this.bomVersion,
    this.bomQty = 0,
    this.parentItemId,
    this.parentItemCode,
    this.parentItemNameTh,
    this.parentItemNameEn,
    this.costingMode = 'OVERHEAD_PERCENT',
    this.overheadPercent = 0,
    this.materialCost = 0,
    this.conversionCost = 0,
    this.totalCost = 0,
    this.unitCost = 0,
    this.breakdown = const [],
    this.error,
  });

  factory MoBomCostRollupRow.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return MoBomCostRollupRow(
      bomHeaderId: json['bomHeaderId'] ?? 0,
      bomVersion: json['bomVersion'],
      bomQty: toDouble(json['bomQty']),
      parentItemId: json['parentItemId'],
      parentItemCode: json['parentItemCode'],
      parentItemNameTh: json['parentItemNameTh'],
      parentItemNameEn: json['parentItemNameEn'],
      costingMode: json['costingMode'] ?? 'OVERHEAD_PERCENT',
      overheadPercent: toDouble(json['overheadPercent']),
      materialCost: toDouble(json['materialCost']),
      conversionCost: toDouble(json['conversionCost']),
      totalCost: toDouble(json['totalCost']),
      unitCost: toDouble(json['unitCost']),
      breakdown: (json['breakdown'] as List<dynamic>? ?? []).map((e) => MoBomCostBreakdownLine.fromJson(e as Map<String, dynamic>)).toList(),
      error: json['error'],
    );
  }
}

class MoBomWhereUsedRow {
  final int componentItemId;
  final String? componentItemCode;
  final String? componentItemNameTh;
  final String? componentItemNameEn;
  final int bomHeaderId;
  final String? bomVersion;
  final bool isActive;
  final String? parentItemCode;
  final String? parentItemNameTh;
  final String? parentItemNameEn;
  final double quantityPer;
  final double scrapPercent;

  const MoBomWhereUsedRow({
    required this.componentItemId,
    this.componentItemCode,
    this.componentItemNameTh,
    this.componentItemNameEn,
    required this.bomHeaderId,
    this.bomVersion,
    this.isActive = true,
    this.parentItemCode,
    this.parentItemNameTh,
    this.parentItemNameEn,
    this.quantityPer = 0,
    this.scrapPercent = 0,
  });

  factory MoBomWhereUsedRow.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return MoBomWhereUsedRow(
      componentItemId: json['component_item_id'] ?? 0,
      componentItemCode: json['component_item_code'],
      componentItemNameTh: json['component_item_name_th'],
      componentItemNameEn: json['component_item_name_en'],
      bomHeaderId: json['bom_header_id'] ?? 0,
      bomVersion: json['bom_version'],
      isActive: json['is_active'] ?? true,
      parentItemCode: json['parent_item_code'],
      parentItemNameTh: json['parent_item_name_th'],
      parentItemNameEn: json['parent_item_name_en'],
      quantityPer: toDouble(json['quantity_per']),
      scrapPercent: toDouble(json['scrap_percent']),
    );
  }
}
