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
