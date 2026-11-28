// lib/mo/models/mo_master_summary.dart — ข้อมูลสรุปของหน้าจอข้อมูลหลัก MO แบบ B (user 2026-11-29)
double _d(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
double? _dN(dynamic v) => v == null ? null : _d(v);
int _i(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);

String _nm(String? th, String? en, bool e) => e && (en ?? '').isNotEmpty ? en! : (th ?? '');

// ─── ศูนย์ปฏิบัติงาน ──────────────────────────────────────────────────────────
class MoWorkCenterUsage {
  final int id;
  final int bomCount;
  final int operationCount;
  final int openMoCount;
  const MoWorkCenterUsage({required this.id, required this.bomCount, required this.operationCount, required this.openMoCount});
  factory MoWorkCenterUsage.fromJson(Map<String, dynamic> j) =>
      MoWorkCenterUsage(id: _i(j['id']), bomCount: _i(j['bom_count']), operationCount: _i(j['operation_count']), openMoCount: _i(j['open_mo_count']));
}

class MoWcBomUse {
  final int bomHeaderId;
  final String? bomVersion;
  final bool isActive;
  final String? costingMode;
  final String? itemCode;
  final String? itemNameTh;
  final String? itemNameEn;
  final double bomQty;
  final String? uomCode;
  final String? operationName;
  final double laborHours;
  final double machineHours;
  final double setupHours;
  final double cost;
  const MoWcBomUse({
    required this.bomHeaderId,
    this.bomVersion,
    required this.isActive,
    this.costingMode,
    this.itemCode,
    this.itemNameTh,
    this.itemNameEn,
    required this.bomQty,
    this.uomCode,
    this.operationName,
    required this.laborHours,
    required this.machineHours,
    required this.setupHours,
    required this.cost,
  });
  factory MoWcBomUse.fromJson(Map<String, dynamic> j) => MoWcBomUse(
        bomHeaderId: _i(j['bom_header_id']),
        bomVersion: j['bom_version']?.toString(),
        isActive: j['is_active'] == true,
        costingMode: j['costing_mode'],
        itemCode: j['item_code'],
        itemNameTh: j['item_name_th'],
        itemNameEn: j['item_name_en'],
        bomQty: _d(j['bom_qty']),
        uomCode: j['uom_code'],
        operationName: j['operation_name'],
        laborHours: _d(j['labor_hours']),
        machineHours: _d(j['machine_hours']),
        setupHours: _d(j['setup_hours']),
        cost: _d(j['cost']),
      );
  String itemName(bool e) => _nm(itemNameTh, itemNameEn, e);
}

class MoWcOpenMo {
  final int id;
  final String? docNo;
  final String status;
  final String? itemCode;
  final String? itemNameTh;
  final String? itemNameEn;
  final double plannedLabor;
  final double actualLabor;
  final double plannedMachine;
  final double actualMachine;
  const MoWcOpenMo({
    required this.id,
    this.docNo,
    required this.status,
    this.itemCode,
    this.itemNameTh,
    this.itemNameEn,
    required this.plannedLabor,
    required this.actualLabor,
    required this.plannedMachine,
    required this.actualMachine,
  });
  factory MoWcOpenMo.fromJson(Map<String, dynamic> j) => MoWcOpenMo(
        id: _i(j['id']),
        docNo: j['doc_no'],
        status: j['status'] ?? '',
        itemCode: j['item_code'],
        itemNameTh: j['item_name_th'],
        itemNameEn: j['item_name_en'],
        plannedLabor: _d(j['planned_labor']),
        actualLabor: _d(j['actual_labor']),
        plannedMachine: _d(j['planned_machine']),
        actualMachine: _d(j['actual_machine']),
      );
  String itemName(bool e) => _nm(itemNameTh, itemNameEn, e);
}

class MoWorkCenterSummary {
  final double rateTotal;
  final List<MoWcBomUse> boms;
  final int bomCount;
  final int activeBomCount;
  final int operationCount;
  final List<MoWcOpenMo> openMos;
  final int openMoCount;
  final double openPlannedHours;
  final double openActualHours;
  final double yearPlannedHours;
  final double yearActualHours;
  final double? yearEfficiencyPct;
  const MoWorkCenterSummary({
    required this.rateTotal,
    required this.boms,
    required this.bomCount,
    required this.activeBomCount,
    required this.operationCount,
    required this.openMos,
    required this.openMoCount,
    required this.openPlannedHours,
    required this.openActualHours,
    required this.yearPlannedHours,
    required this.yearActualHours,
    this.yearEfficiencyPct,
  });
  factory MoWorkCenterSummary.fromJson(Map<String, dynamic> j) => MoWorkCenterSummary(
        rateTotal: _d(j['rate_total']),
        boms: [for (final b in (j['boms'] as List? ?? const [])) MoWcBomUse.fromJson(Map<String, dynamic>.from(b))],
        bomCount: _i(j['bom_count']),
        activeBomCount: _i(j['active_bom_count']),
        operationCount: _i(j['operation_count']),
        openMos: [for (final m in (j['open_mos'] as List? ?? const [])) MoWcOpenMo.fromJson(Map<String, dynamic>.from(m))],
        openMoCount: _i(j['open_mo_count']),
        openPlannedHours: _d(j['open_planned_hours']),
        openActualHours: _d(j['open_actual_hours']),
        yearPlannedHours: _d(j['year_planned_hours']),
        yearActualHours: _d(j['year_actual_hours']),
        yearEfficiencyPct: _dN(j['year_efficiency_pct']),
      );
}

// ─── สูตรการผลิต ────────────────────────────────────────────────────────────────
/// การ์ดแผงซ้าย: ต้นทุนต่อหน่วยตามสูตร (ไล่ลึก) + ต้นทุนมาตรฐานของสินค้า
class MoBomCost {
  final int id;
  final double? unitCost;
  final String? error;
  final double? standardCost;
  final bool hasSub;
  final int usedInCount;
  const MoBomCost({required this.id, this.unitCost, this.error, this.standardCost, required this.hasSub, required this.usedInCount});
  factory MoBomCost.fromJson(Map<String, dynamic> j) => MoBomCost(
        id: _i(j['id']),
        unitCost: _dN(j['unit_cost']),
        error: j['error'],
        standardCost: _dN(j['standard_cost']),
        hasSub: j['has_sub'] == true,
        usedInCount: _i(j['used_in_count']),
      );
}

class MoBomLineCost {
  final double unitCost;
  final double lineTotal;
  final bool isSubAssembly;
  const MoBomLineCost({required this.unitCost, required this.lineTotal, required this.isSubAssembly});
  factory MoBomLineCost.fromJson(Map<String, dynamic> j) =>
      MoBomLineCost(unitCost: _d(j['unit_cost']), lineTotal: _d(j['line_total']), isSubAssembly: j['is_sub_assembly'] == true);
}

class MoBomOpCost {
  final int lineNo;
  final double cost;
  final bool zeroRate;
  const MoBomOpCost({required this.lineNo, required this.cost, required this.zeroRate});
  factory MoBomOpCost.fromJson(Map<String, dynamic> j) => MoBomOpCost(lineNo: _i(j['line_no']), cost: _d(j['cost']), zeroRate: j['zero_rate'] == true);
}

class MoBomVersionInfo {
  final int id;
  final String? version;
  final bool isActive;
  final int componentCount;
  final double? unitCost;
  const MoBomVersionInfo({required this.id, this.version, required this.isActive, required this.componentCount, this.unitCost});
  factory MoBomVersionInfo.fromJson(Map<String, dynamic> j) => MoBomVersionInfo(
        id: _i(j['id']),
        version: j['bom_version']?.toString(),
        isActive: j['is_active'] == true,
        componentCount: _i(j['component_count']),
        unitCost: _dN(j['unit_cost']),
      );
}

class MoBomParentUse {
  final int id;
  final String? version;
  final bool isActive;
  final String? itemCode;
  final String? itemNameTh;
  final String? itemNameEn;
  final double quantityPer;
  final bool pinnedHere;
  const MoBomParentUse(
      {required this.id, this.version, required this.isActive, this.itemCode, this.itemNameTh, this.itemNameEn, required this.quantityPer, required this.pinnedHere});
  factory MoBomParentUse.fromJson(Map<String, dynamic> j) => MoBomParentUse(
        id: _i(j['id']),
        version: j['bom_version']?.toString(),
        isActive: j['is_active'] == true,
        itemCode: j['item_code'],
        itemNameTh: j['item_name_th'],
        itemNameEn: j['item_name_en'],
        quantityPer: _d(j['quantity_per']),
        pinnedHere: j['pinned_here'] == true,
      );
  String itemName(bool e) => _nm(itemNameTh, itemNameEn, e);
}

class MoBomOpenMo {
  final int id;
  final String? docNo;
  final String status;
  final double orderQty;
  const MoBomOpenMo({required this.id, this.docNo, required this.status, required this.orderQty});
  factory MoBomOpenMo.fromJson(Map<String, dynamic> j) =>
      MoBomOpenMo(id: _i(j['id']), docNo: j['doc_no'], status: j['status'] ?? '', orderQty: _d(j['order_qty']));
}

class MoBomSummary {
  final String? costError;
  final double? materialCost;
  final double? conversionCost;
  final double? totalCost;
  final double? unitCost;
  final List<MoBomLineCost> breakdown;
  final List<MoBomOpCost> operations;
  final double? standardCost;
  final List<MoBomVersionInfo> otherVersions;
  final List<MoBomParentUse> parents;
  final int moTotal;
  final int moOpenCount;
  final List<MoBomOpenMo> openMos;
  const MoBomSummary({
    this.costError,
    this.materialCost,
    this.conversionCost,
    this.totalCost,
    this.unitCost,
    required this.breakdown,
    required this.operations,
    this.standardCost,
    required this.otherVersions,
    required this.parents,
    required this.moTotal,
    required this.moOpenCount,
    required this.openMos,
  });
  factory MoBomSummary.fromJson(Map<String, dynamic> j) => MoBomSummary(
        costError: j['cost_error'],
        materialCost: _dN(j['material_cost']),
        conversionCost: _dN(j['conversion_cost']),
        totalCost: _dN(j['total_cost']),
        unitCost: _dN(j['unit_cost']),
        breakdown: [for (final b in (j['breakdown'] as List? ?? const [])) MoBomLineCost.fromJson(Map<String, dynamic>.from(b))],
        operations: [for (final o in (j['operations'] as List? ?? const [])) MoBomOpCost.fromJson(Map<String, dynamic>.from(o))],
        standardCost: _dN(j['standard_cost']),
        otherVersions: [for (final v in (j['other_versions'] as List? ?? const [])) MoBomVersionInfo.fromJson(Map<String, dynamic>.from(v))],
        parents: [for (final p in (j['parents'] as List? ?? const [])) MoBomParentUse.fromJson(Map<String, dynamic>.from(p))],
        moTotal: _i(j['mo_total']),
        moOpenCount: _i(j['mo_open_count']),
        openMos: [for (final m in (j['open_mos'] as List? ?? const [])) MoBomOpenMo.fromJson(Map<String, dynamic>.from(m))],
      );
}
