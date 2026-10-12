// lib/mo/models/mo_work_center.dart — ศูนย์งาน (Work Center) สำหรับ Routing ของสูตรการผลิต (mo_bom) และใบสั่ง
// ผลิต (mo_header) เก็บอัตราค่าแรง/ค่าเครื่องจักร/overhead ต่อชั่วโมง มิเรอร์ im_price_group.dart ทุกประการ

class MoWorkCenter {
  final int id;
  final String workCenterCode;
  final String workCenterNameTh;
  final String? workCenterNameEn;
  final double laborRatePerHour;
  final double machineRatePerHour;
  final double overheadRatePerHour;
  final bool isActive;

  const MoWorkCenter({
    required this.id,
    required this.workCenterCode,
    required this.workCenterNameTh,
    this.workCenterNameEn,
    this.laborRatePerHour = 0,
    this.machineRatePerHour = 0,
    this.overheadRatePerHour = 0,
    this.isActive = true,
  });

  factory MoWorkCenter.fromJson(Map<String, dynamic> json) => MoWorkCenter(
        id: json['id'] as int,
        workCenterCode: json['work_center_code'] ?? '',
        workCenterNameTh: json['work_center_name_th'] ?? '',
        workCenterNameEn: json['work_center_name_en'],
        laborRatePerHour: double.tryParse(json['labor_rate_per_hour']?.toString() ?? '') ?? 0,
        machineRatePerHour: double.tryParse(json['machine_rate_per_hour']?.toString() ?? '') ?? 0,
        overheadRatePerHour: double.tryParse(json['overhead_rate_per_hour']?.toString() ?? '') ?? 0,
        isActive: json['is_active'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        if (id != 0) 'id': id,
        'work_center_code': workCenterCode,
        'work_center_name_th': workCenterNameTh,
        'work_center_name_en': workCenterNameEn,
        'labor_rate_per_hour': laborRatePerHour,
        'machine_rate_per_hour': machineRatePerHour,
        'overhead_rate_per_hour': overheadRatePerHour,
        'is_active': isActive,
      };
}

class MoWorkCenterEfficiencyRow {
  final int id;
  final String workCenterCode;
  final String workCenterNameTh;
  final String? workCenterNameEn;
  final bool isActive;
  final int moCount;
  final int operationCount;
  final double plannedLaborHours;
  final double actualLaborHours;
  final double plannedMachineHours;
  final double actualMachineHours;
  final double actualCost;
  final double laborUtilizationPct;
  final double machineUtilizationPct;

  const MoWorkCenterEfficiencyRow({
    required this.id,
    required this.workCenterCode,
    required this.workCenterNameTh,
    this.workCenterNameEn,
    this.isActive = true,
    this.moCount = 0,
    this.operationCount = 0,
    this.plannedLaborHours = 0,
    this.actualLaborHours = 0,
    this.plannedMachineHours = 0,
    this.actualMachineHours = 0,
    this.actualCost = 0,
    this.laborUtilizationPct = 0,
    this.machineUtilizationPct = 0,
  });

  factory MoWorkCenterEfficiencyRow.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    int toInt(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;
    return MoWorkCenterEfficiencyRow(
      id: json['id'] ?? 0,
      workCenterCode: json['work_center_code'] ?? '',
      workCenterNameTh: json['work_center_name_th'] ?? '',
      workCenterNameEn: json['work_center_name_en'],
      isActive: json['is_active'] ?? true,
      moCount: toInt(json['mo_count']),
      operationCount: toInt(json['operation_count']),
      plannedLaborHours: toDouble(json['planned_labor_hours']),
      actualLaborHours: toDouble(json['actual_labor_hours']),
      plannedMachineHours: toDouble(json['planned_machine_hours']),
      actualMachineHours: toDouble(json['actual_machine_hours']),
      actualCost: toDouble(json['actual_cost']),
      laborUtilizationPct: toDouble(json['labor_utilization_pct']),
      machineUtilizationPct: toDouble(json['machine_utilization_pct']),
    );
  }
}
