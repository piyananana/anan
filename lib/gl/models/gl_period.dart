// File: gl/models/gl_period.dart
// เพิ่มฟังก์ชัน Helper นี้ไว้นอก Class หรือใน Class ก็ได้
DateTime _parseDateSecurely(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
  try {
    // กรณีที่ Backend ส่งมาเป็น ISO แบบมีเวลา เช่น 2023-12-31T17:00:00.000Z
    // ให้แปลงเป็น Local ก่อน เพื่อดึงเอา ปี-เดือน-วัน ที่ถูกต้อง
    DateTime parsed = DateTime.parse(dateStr).toLocal();
    return DateTime(parsed.year, parsed.month, parsed.day);
  } catch (e) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}
// ***** โมเดลสำหรับ Fiscal Year และ Posting Period *****
class FiscalYear {
  final int id;
  final String fyCode;
  final String? description;
  final DateTime yearStartDate;
  final DateTime yearEndDate;
  final int numOfPeriods;
  final bool isActive;
  // Fields สำหรับแสดงผลใน List
  final int totalPeriods;
  final int closedPeriods;

  FiscalYear({
    required this.id,
    required this.fyCode,
    this.description,
    required this.yearStartDate,
    required this.yearEndDate,
    required this.numOfPeriods,
    required this.isActive,
    this.totalPeriods = 0,
    this.closedPeriods = 0,
  });

  factory FiscalYear.fromJson(Map<String, dynamic> json) {
    return FiscalYear(
      id: json['id'],
      fyCode: json['fy_code'] ?? '',
      description: json['description'] as String?,
      // yearStartDate: DateTime.parse(json['year_start_date']),
      // yearEndDate: DateTime.parse(json['year_end_date']),
      yearStartDate: _parseDateSecurely(json['year_start_date']),
      yearEndDate: _parseDateSecurely(json['year_end_date']),      
      numOfPeriods: json['num_of_periods'] ?? 0,
      isActive: json['is_active'] ?? true,
      // Field ที่ดึงมาจากการ Join/Aggregate
      totalPeriods: int.tryParse(json['total_periods']?.toString() ?? '0') ?? 0,
      closedPeriods: int.tryParse(json['closed_periods']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fy_code': fyCode,
      'description': description,
      // แปลง DateTime เป็น String สำหรับส่งไป Back-end
      'year_start_date': yearStartDate.toIso8601String().split('T')[0], 
      'year_end_date': yearEndDate.toIso8601String().split('T')[0],
      'num_of_periods': numOfPeriods,
      'is_active': isActive,
    };
  }
}

// ผู้อนุมัติแต่ละคนในคิวปิดงวด GL (เรียงตาม sequenceNo)
class GlCloseApproval {
  final int approverUserId;
  final String approverUserName;
  final int sequenceNo;
  final String status; // Pending / Approved / Rejected

  GlCloseApproval({
    required this.approverUserId,
    required this.approverUserName,
    required this.sequenceNo,
    required this.status,
  });

  factory GlCloseApproval.fromJson(Map<String, dynamic> json) => GlCloseApproval(
        approverUserId: int.tryParse(json['approver_user_id'].toString()) ?? 0,
        approverUserName: json['approver_user_name'] as String? ?? '',
        sequenceNo: int.tryParse(json['sequence_no'].toString()) ?? 0,
        status: json['status'] as String? ?? 'Pending',
      );
}

class PostingPeriod {
  final int id;
  final int fiscalYearId;
  final int periodNumber;
  final String periodName;
  final DateTime periodStartDate;
  final DateTime periodEndDate;
  final String glStatus;
  final String apStatus;
  final String arStatus;
  final String imStatus;
  final String cmStatus;
  // ข้อมูลคำขอปิดงวด GL ที่ยังรออนุมัติ (Pending) — null/ว่าง หากไม่มีคำขอค้างอยู่
  final int? closeRequestId;
  final int? closeRequestedBy;
  final String? closeRequestedByName;
  final List<GlCloseApproval> closeApprovals;

  PostingPeriod({
    required this.id,
    required this.fiscalYearId,
    required this.periodNumber,
    required this.periodName,
    required this.periodStartDate,
    required this.periodEndDate,
    required this.glStatus,
    required this.apStatus,
    required this.arStatus,
    required this.imStatus,
    this.cmStatus = 'OPEN',
    this.closeRequestId,
    this.closeRequestedBy,
    this.closeRequestedByName,
    this.closeApprovals = const [],
  });

  factory PostingPeriod.fromJson(Map<String, dynamic> json) {
    return PostingPeriod(
      id: json['id'],
      fiscalYearId: json['fiscal_year_id'],
      periodNumber: json['period_number'],
      periodName: json['period_name'],
      // periodStartDate: DateTime.parse(json['period_start_date']),
      // periodEndDate: DateTime.parse(json['period_end_date']),
      periodStartDate: _parseDateSecurely(json['period_start_date']),
      periodEndDate: _parseDateSecurely(json['period_end_date']),
      glStatus: json['gl_status'] ?? 'OPEN',
      apStatus: json['ap_status'] ?? 'OPEN',
      arStatus: json['ar_status'] ?? 'OPEN',
      imStatus: json['im_status'] ?? 'OPEN',
      cmStatus: json['cm_status'] as String? ?? 'OPEN',
      closeRequestId: json['close_request_id'] == null
          ? null : int.tryParse(json['close_request_id'].toString()),
      closeRequestedBy: json['close_requested_by'] == null
          ? null : int.tryParse(json['close_requested_by'].toString()),
      closeRequestedByName: json['close_requested_by_name'] as String?,
      closeApprovals: json['close_approvals'] == null
          ? const []
          : (json['close_approvals'] as List)
              .map((e) => GlCloseApproval.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fiscal_year_id': fiscalYearId,
      'period_number': periodNumber,
      'period_name': periodName,
      'period_start_date': periodStartDate.toIso8601String().split('T')[0],
      'period_end_date': periodEndDate.toIso8601String().split('T')[0],
      // สถานะจะถูกจัดการแยกกันในการอัปเดต
      'gl_status': glStatus,
      'ap_status': apStatus,
      'ar_status': arStatus,
      'im_status': imStatus,
      'cm_status': cmStatus,
    };
  }
}