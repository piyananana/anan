// lib/mo/models/mo_header.dart — ใบสั่งผลิต (Manufacturing Order, sys_module='61') มิเรอร์ po_transaction.dart
import '../../utils/date_utils.dart';

const Map<String, String> moHeaderStatusLabelsTh = {
  'Draft': 'ร่าง',
  'Released': 'ปล่อยแล้ว',
  'InProgress': 'กำลังผลิต',
  'Completed': 'ผลิตครบแล้ว',
  'Closed': 'ปิดแล้ว',
  'Cancelled': 'ยกเลิก',
};

const Map<String, String> moHeaderStatusLabelsEn = {
  'Draft': 'Draft',
  'Released': 'Released',
  'InProgress': 'In Progress',
  'Completed': 'Completed',
  'Closed': 'Closed',
  'Cancelled': 'Cancelled',
};

String moHeaderStatusLabel(String s, bool isEnglish) =>
    (isEnglish ? moHeaderStatusLabelsEn[s] : moHeaderStatusLabelsTh[s]) ?? s;

class MoComponentDetail {
  final int? id;
  final int? headerId;
  final int lineNo;
  final int componentItemId;
  final String? itemCode;
  final String? itemName;
  final double plannedQty;
  final double issuedQty; // คำนวณฝั่ง server จากธุรกรรม '90' ที่ Posted แล้ว (ยังไม่มีธุรกรรมจริงในเฟสนี้ จึงเป็น 0 เสมอ)
  final int? uomId;
  final String? uomCode;
  final String? uomNameTh;
  final String? uomNameEn;
  final int? locationId;
  final String? locationCode;

  double get qtyRemaining => plannedQty - issuedQty;

  const MoComponentDetail({
    this.id,
    this.headerId,
    required this.lineNo,
    required this.componentItemId,
    this.itemCode,
    this.itemName,
    this.plannedQty = 0,
    this.issuedQty = 0,
    this.uomId,
    this.uomCode,
    this.uomNameTh,
    this.uomNameEn,
    this.locationId,
    this.locationCode,
  });

  factory MoComponentDetail.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return MoComponentDetail(
      id: json['id'],
      headerId: json['header_id'],
      lineNo: json['line_no'] ?? 0,
      componentItemId: json['component_item_id'] ?? 0,
      itemCode: json['item_code'] ?? json['component_item_code'],
      itemName: json['item_name'] ?? json['component_item_name_th'],
      plannedQty: toDouble(json['planned_qty']),
      issuedQty: toDouble(json['issued_qty']),
      uomId: json['uom_id'],
      uomCode: json['uom_code'],
      uomNameTh: json['uom_name_th'],
      uomNameEn: json['uom_name_en'],
      locationId: json['location_id'],
      locationCode: json['location_code'],
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'line_no': lineNo,
        'component_item_id': componentItemId,
        if (itemCode != null) 'item_code': itemCode,
        if (itemName != null) 'item_name': itemName,
        'planned_qty': plannedQty,
        if (uomId != null) 'uom_id': uomId,
        if (locationId != null) 'location_id': locationId,
      };
}

class MoOutputDetail {
  final int? id;
  final int? headerId;
  final int lineNo;
  final int outputItemId;
  final String? itemCode;
  final String? itemName;
  final double plannedQty;
  final double receivedQty; // คำนวณฝั่ง server จากธุรกรรม '95' ที่ Posted แล้ว (ยังไม่มีธุรกรรมจริงในเฟสนี้ จึงเป็น 0 เสมอ)
  final int? uomId;
  final String? uomCode;
  final String? uomNameTh;
  final String? uomNameEn;
  final bool isPrimaryOutput;

  double get qtyRemaining => plannedQty - receivedQty;

  const MoOutputDetail({
    this.id,
    this.headerId,
    required this.lineNo,
    required this.outputItemId,
    this.itemCode,
    this.itemName,
    this.plannedQty = 0,
    this.receivedQty = 0,
    this.uomId,
    this.uomCode,
    this.uomNameTh,
    this.uomNameEn,
    this.isPrimaryOutput = false,
  });

  factory MoOutputDetail.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return MoOutputDetail(
      id: json['id'],
      headerId: json['header_id'],
      lineNo: json['line_no'] ?? 0,
      outputItemId: json['output_item_id'] ?? 0,
      itemCode: json['item_code'] ?? json['output_item_code'],
      itemName: json['item_name'] ?? json['output_item_name_th'],
      plannedQty: toDouble(json['planned_qty']),
      receivedQty: toDouble(json['received_qty']),
      uomId: json['uom_id'],
      uomCode: json['uom_code'],
      uomNameTh: json['uom_name_th'],
      uomNameEn: json['uom_name_en'],
      isPrimaryOutput: json['is_primary_output'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'line_no': lineNo,
        'output_item_id': outputItemId,
        if (itemCode != null) 'item_code': itemCode,
        if (itemName != null) 'item_name': itemName,
        'planned_qty': plannedQty,
        if (uomId != null) 'uom_id': uomId,
        'is_primary_output': isPrimaryOutput,
      };
}

class MoOperationDetail {
  final int? id;
  final int? headerId;
  final int lineNo;
  final int workCenterId;
  final String? workCenterCode;
  final String? workCenterNameTh;
  final String? workCenterNameEn;
  final String? operationName;
  final double plannedLaborHours;
  final double plannedMachineHours;
  final double actualLaborHours; // บันทึกผ่านหน้าจอ "บันทึกเวลาปฏิบัติงาน" (ยังไม่ทำในเฟสนี้ จึงเป็น 0 เสมอ)
  final double actualMachineHours;
  final String status; // Pending/InProgress/Done

  const MoOperationDetail({
    this.id,
    this.headerId,
    required this.lineNo,
    required this.workCenterId,
    this.workCenterCode,
    this.workCenterNameTh,
    this.workCenterNameEn,
    this.operationName,
    this.plannedLaborHours = 0,
    this.plannedMachineHours = 0,
    this.actualLaborHours = 0,
    this.actualMachineHours = 0,
    this.status = 'Pending',
  });

  factory MoOperationDetail.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return MoOperationDetail(
      id: json['id'],
      headerId: json['header_id'],
      lineNo: json['line_no'] ?? 0,
      workCenterId: json['work_center_id'] ?? 0,
      workCenterCode: json['work_center_code'],
      workCenterNameTh: json['work_center_name_th'],
      workCenterNameEn: json['work_center_name_en'],
      operationName: json['operation_name'],
      plannedLaborHours: toDouble(json['planned_labor_hours']),
      plannedMachineHours: toDouble(json['planned_machine_hours']),
      actualLaborHours: toDouble(json['actual_labor_hours']),
      actualMachineHours: toDouble(json['actual_machine_hours']),
      status: json['status'] ?? 'Pending',
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'line_no': lineNo,
        'work_center_id': workCenterId,
        if (operationName != null) 'operation_name': operationName,
        'planned_labor_hours': plannedLaborHours,
        'planned_machine_hours': plannedMachineHours,
      };
}

class MoMaterialAvailabilityLine {
  final int id;
  final int componentItemId;
  final String? itemCode;
  final String? itemName;
  final double plannedQty;
  final double issuedQty;
  final double remainingQty;
  final double availableQty;
  final double shortageQty;
  final bool isShort;
  final String? uomCode;
  final String? uomNameTh;
  final String? uomNameEn;

  const MoMaterialAvailabilityLine({
    required this.id,
    required this.componentItemId,
    this.itemCode,
    this.itemName,
    this.plannedQty = 0,
    this.issuedQty = 0,
    this.remainingQty = 0,
    this.availableQty = 0,
    this.shortageQty = 0,
    this.isShort = false,
    this.uomCode,
    this.uomNameTh,
    this.uomNameEn,
  });

  factory MoMaterialAvailabilityLine.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return MoMaterialAvailabilityLine(
      id: json['id'] ?? 0,
      componentItemId: json['component_item_id'] ?? 0,
      itemCode: json['item_code'],
      itemName: json['item_name'],
      plannedQty: toDouble(json['planned_qty']),
      issuedQty: toDouble(json['issued_qty']),
      remainingQty: toDouble(json['remaining_qty']),
      availableQty: toDouble(json['available_qty']),
      shortageQty: toDouble(json['shortage_qty']),
      isShort: json['is_short'] ?? false,
      uomCode: json['uom_code'],
      uomNameTh: json['uom_name_th'],
      uomNameEn: json['uom_name_en'],
    );
  }
}

class MoMaterialAvailability {
  final int moId;
  final String docNo;
  final int warehouseId;
  final bool hasShortage;
  final List<MoMaterialAvailabilityLine> lines;

  const MoMaterialAvailability({
    required this.moId,
    required this.docNo,
    required this.warehouseId,
    this.hasShortage = false,
    this.lines = const [],
  });

  factory MoMaterialAvailability.fromJson(Map<String, dynamic> json) {
    return MoMaterialAvailability(
      moId: json['mo_id'] ?? 0,
      docNo: json['doc_no'] ?? '',
      warehouseId: json['warehouse_id'] ?? 0,
      hasShortage: json['has_shortage'] ?? false,
      lines: (json['lines'] as List<dynamic>? ?? [])
          .map((e) => MoMaterialAvailabilityLine.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MoExplosionCandidate {
  final int componentDetailId;
  final int componentItemId;
  final String? itemCode;
  final String? itemName;
  final double plannedQty;
  final double issuedQty;
  final double remainingQty;
  final int? candidateBomHeaderId;
  final String? candidateBomVersion;
  final bool canExplode;
  final String? uomCode;
  final String? uomNameTh;
  final String? uomNameEn;

  const MoExplosionCandidate({
    required this.componentDetailId,
    required this.componentItemId,
    this.itemCode,
    this.itemName,
    this.plannedQty = 0,
    this.issuedQty = 0,
    this.remainingQty = 0,
    this.candidateBomHeaderId,
    this.candidateBomVersion,
    this.canExplode = false,
    this.uomCode,
    this.uomNameTh,
    this.uomNameEn,
  });

  factory MoExplosionCandidate.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return MoExplosionCandidate(
      componentDetailId: json['component_detail_id'] ?? 0,
      componentItemId: json['component_item_id'] ?? 0,
      itemCode: json['item_code'],
      itemName: json['item_name'],
      plannedQty: toDouble(json['planned_qty']),
      issuedQty: toDouble(json['issued_qty']),
      remainingQty: toDouble(json['remaining_qty']),
      candidateBomHeaderId: json['candidate_bom_header_id'],
      candidateBomVersion: json['candidate_bom_version'],
      canExplode: json['can_explode'] ?? false,
      uomNameTh: json['uom_name_th'],
      uomNameEn: json['uom_name_en'],
      uomCode: json['uom_code'],
    );
  }
}

class MoStatusReportRow {
  final int id;
  final String docNo;
  final DateTime docDate;
  final DateTime? dueDate;
  final String status;
  final int warehouseId;
  final String? warehouseCode;
  final String? warehouseNameTh;
  final String? warehouseNameEn;
  final double orderQty;
  final String? uomCode;
  final String? uomNameTh;
  final String? uomNameEn;
  final String? bomParentItemCode;
  final String? bomParentItemNameTh;
  final String? bomParentItemNameEn;
  final double componentPlannedQty;
  final double componentIssuedQty;
  final double outputPlannedQty;
  final double outputReceivedQty;
  final double percentComplete;
  final double wipBalanceLc;

  const MoStatusReportRow({
    required this.id,
    required this.docNo,
    required this.docDate,
    this.dueDate,
    this.status = 'Draft',
    required this.warehouseId,
    this.warehouseCode,
    this.warehouseNameTh,
    this.warehouseNameEn,
    this.orderQty = 0,
    this.uomCode,
    this.uomNameTh,
    this.uomNameEn,
    this.bomParentItemCode,
    this.bomParentItemNameTh,
    this.bomParentItemNameEn,
    this.componentPlannedQty = 0,
    this.componentIssuedQty = 0,
    this.outputPlannedQty = 0,
    this.outputReceivedQty = 0,
    this.percentComplete = 0,
    this.wipBalanceLc = 0,
  });

  factory MoStatusReportRow.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return MoStatusReportRow(
      id: json['id'] ?? 0,
      docNo: json['doc_no'] ?? '',
      docDate: parseLocalDate(json['doc_date']),
      dueDate: json['due_date'] != null ? parseLocalDate(json['due_date']) : null,
      status: json['status'] ?? 'Draft',
      warehouseId: json['warehouse_id'] ?? 0,
      warehouseCode: json['warehouse_code'],
      warehouseNameTh: json['warehouse_name_th'],
      warehouseNameEn: json['warehouse_name_en'],
      orderQty: toDouble(json['order_qty']),
      uomCode: json['uom_code'],
      uomNameTh: json['uom_name_th'],
      uomNameEn: json['uom_name_en'],
      bomParentItemCode: json['bom_parent_item_code'],
      bomParentItemNameTh: json['bom_parent_item_name_th'],
      bomParentItemNameEn: json['bom_parent_item_name_en'],
      componentPlannedQty: toDouble(json['component_planned_qty']),
      componentIssuedQty: toDouble(json['component_issued_qty']),
      outputPlannedQty: toDouble(json['output_planned_qty']),
      outputReceivedQty: toDouble(json['output_received_qty']),
      percentComplete: toDouble(json['percent_complete']),
      wipBalanceLc: toDouble(json['wip_balance_lc']),
    );
  }
}

class MoCostVarianceReportRow {
  final int id;
  final String docNo;
  final DateTime docDate;
  final String status;
  final String costingMethod;
  final String costingMode;
  final String? warehouseCode;
  final String? warehouseNameTh;
  final String? warehouseNameEn;
  final String? uomCode;
  final String? uomNameTh;
  final String? uomNameEn;
  final String? bomParentItemCode;
  final String? bomParentItemNameTh;
  final String? bomParentItemNameEn;
  final double materialCost;
  final double laborCost;
  final double machineCost;
  final double overheadCost;
  final double totalCost;
  final double outputReceivedQty;
  final double avgUnitCost;
  final double variancePosted;
  final double wipBalanceLc;

  const MoCostVarianceReportRow({
    required this.id,
    required this.docNo,
    required this.docDate,
    this.status = 'Draft',
    this.costingMethod = 'ACTUAL',
    this.costingMode = 'OVERHEAD_PERCENT',
    this.warehouseCode,
    this.warehouseNameTh,
    this.warehouseNameEn,
    this.uomCode,
    this.uomNameTh,
    this.uomNameEn,
    this.bomParentItemCode,
    this.bomParentItemNameTh,
    this.bomParentItemNameEn,
    this.materialCost = 0,
    this.laborCost = 0,
    this.machineCost = 0,
    this.overheadCost = 0,
    this.totalCost = 0,
    this.outputReceivedQty = 0,
    this.avgUnitCost = 0,
    this.variancePosted = 0,
    this.wipBalanceLc = 0,
  });

  factory MoCostVarianceReportRow.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return MoCostVarianceReportRow(
      id: json['id'] ?? 0,
      docNo: json['doc_no'] ?? '',
      docDate: parseLocalDate(json['doc_date']),
      status: json['status'] ?? 'Draft',
      costingMethod: json['costing_method'] ?? 'ACTUAL',
      costingMode: json['costing_mode'] ?? 'OVERHEAD_PERCENT',
      warehouseCode: json['warehouse_code'],
      warehouseNameTh: json['warehouse_name_th'],
      warehouseNameEn: json['warehouse_name_en'],
      uomCode: json['uom_code'],
      uomNameTh: json['uom_name_th'],
      uomNameEn: json['uom_name_en'],
      bomParentItemCode: json['bom_parent_item_code'],
      bomParentItemNameTh: json['bom_parent_item_name_th'],
      bomParentItemNameEn: json['bom_parent_item_name_en'],
      materialCost: toDouble(json['material_cost']),
      laborCost: toDouble(json['labor_cost']),
      machineCost: toDouble(json['machine_cost']),
      overheadCost: toDouble(json['overhead_cost']),
      totalCost: toDouble(json['total_cost']),
      outputReceivedQty: toDouble(json['output_received_qty']),
      avgUnitCost: toDouble(json['avg_unit_cost']),
      variancePosted: toDouble(json['variance_posted']),
      wipBalanceLc: toDouble(json['wip_balance_lc']),
    );
  }
}

class MoWipValuationLine {
  final int id;
  final String docNo;
  final DateTime docDate;
  final String status;
  final double wipBalanceLc;
  final String? warehouseCode;
  final String? warehouseNameTh;
  final String? warehouseNameEn;
  final String? bomParentItemCode;
  final String? bomParentItemNameTh;
  final String? bomParentItemNameEn;

  const MoWipValuationLine({
    required this.id,
    required this.docNo,
    required this.docDate,
    this.status = 'Draft',
    this.wipBalanceLc = 0,
    this.warehouseCode,
    this.warehouseNameTh,
    this.warehouseNameEn,
    this.bomParentItemCode,
    this.bomParentItemNameTh,
    this.bomParentItemNameEn,
  });

  factory MoWipValuationLine.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return MoWipValuationLine(
      id: json['id'] ?? 0,
      docNo: json['doc_no'] ?? '',
      docDate: parseLocalDate(json['doc_date']),
      status: json['status'] ?? 'Draft',
      wipBalanceLc: toDouble(json['wip_balance_lc']),
      warehouseCode: json['warehouse_code'],
      warehouseNameTh: json['warehouse_name_th'],
      warehouseNameEn: json['warehouse_name_en'],
      bomParentItemCode: json['bom_parent_item_code'],
      bomParentItemNameTh: json['bom_parent_item_name_th'],
      bomParentItemNameEn: json['bom_parent_item_name_en'],
    );
  }
}

class MoWipValuationReport {
  final List<MoWipValuationLine> lines;
  final double totalMoWip;
  final String? wipAccountCode;
  final String? wipAccountName;
  final double? glBalance;
  final double? difference;

  const MoWipValuationReport({
    this.lines = const [],
    this.totalMoWip = 0,
    this.wipAccountCode,
    this.wipAccountName,
    this.glBalance,
    this.difference,
  });

  factory MoWipValuationReport.fromJson(Map<String, dynamic> json) {
    double? toDoubleN(dynamic v) => v == null ? null : (double.tryParse(v.toString()) ?? 0);
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return MoWipValuationReport(
      lines: (json['lines'] as List<dynamic>? ?? []).map((e) => MoWipValuationLine.fromJson(e as Map<String, dynamic>)).toList(),
      totalMoWip: toDouble(json['total_mo_wip']),
      wipAccountCode: json['wip_account_code'],
      wipAccountName: json['wip_account_name'],
      glBalance: toDoubleN(json['gl_balance']),
      difference: toDoubleN(json['difference']),
    );
  }
}

class MoHeader {
  final int id;
  final int docId;
  final String docNo;
  final DateTime docDate;
  final int? bomHeaderId;
  final String? bomVersion;
  final int? bomParentItemId;
  final String? bomParentItemCode;
  final String? bomParentItemNameTh;
  final String? bomParentItemNameEn;
  final int warehouseId;
  final String? warehouseCode;
  final String? warehouseNameTh;
  final String? warehouseNameEn;
  final double orderQty;
  final int? uomId;
  final String? uomCode;
  final String? uomNameTh;
  final String? uomNameEn;
  final String issueMethod;
  final String costingMethod;
  final String costingMode;
  final double overheadPercent;
  final DateTime? dueDate;
  final String status;
  final double wipBalanceLc;
  final int? parentMoId;
  final String? parentMoDocNo;
  final int? parentMoDetailId;
  final String? description;
  final int? branchId;
  final String? branchCode;
  final String? branchNameThai;
  final DateTime? releasedAt;
  final String? releasedBy;
  // From join
  final String? docCode;
  final String? docNameThai;
  final String? docNameEng;
  final bool? isAutoNumbering;
  final String? createdBy;
  final String? updatedBy;
  final List<MoComponentDetail> components;
  final List<MoOutputDetail> outputs;
  final List<MoOperationDetail> operations;

  const MoHeader({
    this.id = 0,
    required this.docId,
    this.docNo = 'AUTO',
    required this.docDate,
    this.bomHeaderId,
    this.bomVersion,
    this.bomParentItemId,
    this.bomParentItemCode,
    this.bomParentItemNameTh,
    this.bomParentItemNameEn,
    required this.warehouseId,
    this.warehouseCode,
    this.warehouseNameTh,
    this.warehouseNameEn,
    this.orderQty = 0,
    this.uomId,
    this.uomCode,
    this.uomNameTh,
    this.uomNameEn,
    this.issueMethod = 'EXPLICIT',
    this.costingMethod = 'ACTUAL',
    this.costingMode = 'OVERHEAD_PERCENT',
    this.overheadPercent = 0,
    this.dueDate,
    this.status = 'Draft',
    this.wipBalanceLc = 0,
    this.parentMoId,
    this.parentMoDocNo,
    this.parentMoDetailId,
    this.description,
    this.branchId,
    this.branchCode,
    this.branchNameThai,
    this.releasedAt,
    this.releasedBy,
    this.docCode,
    this.docNameThai,
    this.docNameEng,
    this.isAutoNumbering,
    this.createdBy,
    this.updatedBy,
    this.components = const [],
    this.outputs = const [],
    this.operations = const [],
  });

  bool get isReadOnly => status != 'Draft';

  factory MoHeader.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    return MoHeader(
      id: json['id'] ?? 0,
      docId: json['doc_id'] ?? 0,
      docNo: json['doc_no'] ?? 'AUTO',
      docDate: parseLocalDate(json['doc_date']),
      bomHeaderId: json['bom_header_id'],
      bomVersion: json['bom_version'],
      bomParentItemId: json['bom_parent_item_id'],
      bomParentItemCode: json['bom_parent_item_code'],
      bomParentItemNameTh: json['bom_parent_item_name_th'],
      bomParentItemNameEn: json['bom_parent_item_name_en'],
      warehouseId: json['warehouse_id'] ?? 0,
      warehouseCode: json['warehouse_code'],
      warehouseNameTh: json['warehouse_name_th'],
      warehouseNameEn: json['warehouse_name_en'],
      orderQty: toDouble(json['order_qty']),
      uomId: json['uom_id'],
      uomCode: json['uom_code'],
      uomNameTh: json['uom_name_th'],
      uomNameEn: json['uom_name_en'],
      issueMethod: json['issue_method'] ?? 'EXPLICIT',
      costingMethod: json['costing_method'] ?? 'ACTUAL',
      costingMode: json['costing_mode'] ?? 'OVERHEAD_PERCENT',
      overheadPercent: toDouble(json['overhead_percent']),
      dueDate: json['due_date'] != null ? parseLocalDate(json['due_date']) : null,
      status: json['status'] ?? 'Draft',
      wipBalanceLc: toDouble(json['wip_balance_lc']),
      parentMoId: json['parent_mo_id'],
      parentMoDocNo: json['parent_mo_doc_no'],
      parentMoDetailId: json['parent_mo_detail_id'],
      description: json['description'],
      branchId: json['branch_id'],
      branchCode: json['branch_code'],
      branchNameThai: json['branch_name_thai'],
      releasedAt: json['released_at'] != null ? DateTime.tryParse(json['released_at'].toString())?.toLocal() : null,
      releasedBy: json['released_by'],
      docCode: json['doc_code'] ?? json['d_doc_code'],
      docNameThai: json['doc_name_thai'],
      docNameEng: json['doc_name_eng'],
      isAutoNumbering: json['is_auto_numbering'],
      createdBy: json['created_by'],
      updatedBy: json['updated_by'],
      components: (json['components'] as List<dynamic>? ?? []).map((e) => MoComponentDetail.fromJson(e as Map<String, dynamic>)).toList(),
      outputs: (json['outputs'] as List<dynamic>? ?? []).map((e) => MoOutputDetail.fromJson(e as Map<String, dynamic>)).toList(),
      operations: (json['operations'] as List<dynamic>? ?? []).map((e) => MoOperationDetail.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'doc_id': docId,
        'doc_no': docNo,
        'doc_date': formatLocalDate(docDate),
        if (bomHeaderId != null) 'bom_header_id': bomHeaderId,
        'warehouse_id': warehouseId,
        'order_qty': orderQty,
        if (uomId != null) 'uom_id': uomId,
        'issue_method': issueMethod,
        'costing_method': costingMethod,
        'costing_mode': costingMode,
        'overhead_percent': overheadPercent,
        if (dueDate != null) 'due_date': formatLocalDate(dueDate!),
        if (description != null) 'description': description,
        if (parentMoId != null) 'parent_mo_id': parentMoId,
        if (parentMoDetailId != null) 'parent_mo_detail_id': parentMoDetailId,
        if (branchId != null) 'branch_id': branchId,
        if (createdBy != null) 'created_by': createdBy,
        if (updatedBy != null) 'updated_by': updatedBy,
      };
}
