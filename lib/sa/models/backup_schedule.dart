// lib/models/backup_schedule.dart

import 'package:flutter/material.dart';

class BackupSchedule {
  final int id;
  final String scheduleType;
  
  // สถานะการทำงานของ schedule
  bool isRunning;
  double progressPercent;
  String? message;
  DateTime? lastBackupTime;

  // Daily
  List<int>? dailyDaysOfWeek;
  TimeOfDay? dailyTime;

  // Monthly
  List<int>? monthlyMonths;
  int? monthlyDayOfMonth;
  TimeOfDay? monthlyTime;

  // Yearly
  DateTime? yearlyDate;
  TimeOfDay? yearlyTime;

  BackupSchedule({
    required this.id,
    required this.scheduleType,
    required this.isRunning,
    required this.progressPercent,
    this.message,
    this.lastBackupTime,
    this.dailyDaysOfWeek,
    this.dailyTime,
    this.monthlyMonths,
    this.monthlyDayOfMonth,
    this.monthlyTime,
    this.yearlyDate,
    this.yearlyTime,
  });

  factory BackupSchedule.fromJson(Map<String, dynamic> json) {
    return BackupSchedule(
      id: json['id'] as int,
      scheduleType: json['schedule_type'] as String,
      isRunning: json['is_running'] as bool,
      progressPercent: (double.tryParse(json['progress_percent'].toString()) ?? 0.0),
      message: json['message'] as String?,
      lastBackupTime: json['last_backup_time'] != null
          ? DateTime.parse(json['last_backup_time'])
          : null,
      dailyDaysOfWeek: json['daily_days_of_week'] != null
          ? (json['daily_days_of_week'] as String).split(',').map(int.parse).toList()
          : null,
      dailyTime: json['daily_time'] != null
          ? TimeOfDay(
              hour: int.parse(json['daily_time'].substring(0, 2)),
              minute: int.parse(json['daily_time'].substring(3, 5)),
            )
          : null,
      monthlyMonths: json['monthly_months'] != null
          ? (json['monthly_months'] as String).split(',').map(int.parse).toList()
          : null,
      monthlyDayOfMonth: json['monthly_day_of_month'] as int?,
      monthlyTime: json['monthly_time'] != null
          ? TimeOfDay(
              hour: int.parse(json['monthly_time'].substring(0, 2)),
              minute: int.parse(json['monthly_time'].substring(3, 5)),
            )
          : null,
      yearlyDate: json['yearly_date'] != null
          ? DateTime.parse(json['yearly_date'])
          : null,
      yearlyTime: json['yearly_time'] != null
          ? TimeOfDay(
              hour: int.parse(json['yearly_time'].substring(0, 2)),
              minute: int.parse(json['yearly_time'].substring(3, 5)),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schedule_type': scheduleType,
      'daily_days_of_week': dailyDaysOfWeek?.join(','),
      'daily_time': dailyTime != null ? '${dailyTime!.hour.toString().padLeft(2, '0')}:${dailyTime!.minute.toString().padLeft(2, '0')}:00' : null,
      'monthly_months': monthlyMonths?.join(','),
      'monthly_day_of_month': monthlyDayOfMonth,
      'monthly_time': monthlyTime != null ? '${monthlyTime!.hour.toString().padLeft(2, '0')}:${monthlyTime!.minute.toString().padLeft(2, '0')}:00' : null,
      'yearly_date': yearlyDate?.toIso8601String().split('T')[0],
      'yearly_time': yearlyTime != null ? '${yearlyTime!.hour.toString().padLeft(2, '0')}:${yearlyTime!.minute.toString().padLeft(2, '0')}:00' : null,
    };
  }
}

// // lib/models/backup_schedule.dart

// // import 'dart:ffi';

// import 'package:flutter/material.dart';

// class BackupSchedule {
//   final int id;
//   final String scheduleType;
//   bool isActive;

//   // Daily
//   List<int>? dailyDaysOfWeek;
//   TimeOfDay? dailyTime;

//   // Monthly
//   List<int>? monthlyMonths;
//   int? monthlyDayOfMonth;
//   TimeOfDay? monthlyTime;

//   // Yearly
//   DateTime? yearlyDate;
//   TimeOfDay? yearlyTime;

//   BackupSchedule({
//     required this.id,
//     required this.scheduleType,
//     required this.isActive,
//     this.dailyDaysOfWeek,
//     this.dailyTime,
//     this.monthlyMonths,
//     this.monthlyDayOfMonth,
//     this.monthlyTime,
//     this.yearlyDate,
//     this.yearlyTime,
//   });

//   factory BackupSchedule.fromJson(Map<String, dynamic> json) {
//     return BackupSchedule(
//       id: json['id'] as int,
//       scheduleType: json['schedule_type'] as String,
//       isActive: json['is_active'] as bool,
//       dailyDaysOfWeek: json['daily_days_of_week'] != null
//           ? (json['daily_days_of_week'] as String).split(',').map(int.parse).toList()
//           : null,
//       dailyTime: json['daily_time'] != null
//           ? TimeOfDay(
//               hour: int.parse(json['daily_time'].substring(0, 2)),
//               minute: int.parse(json['daily_time'].substring(3, 5)),
//             )
//           : null,
//       monthlyMonths: json['monthly_months'] != null
//           ? (json['monthly_months'] as String).split(',').map(int.parse).toList()
//           : null,
//       monthlyDayOfMonth: json['monthly_day_of_month'] as int?,
//       monthlyTime: json['monthly_time'] != null
//           ? TimeOfDay(
//               hour: int.parse(json['monthly_time'].substring(0, 2)),
//               minute: int.parse(json['monthly_time'].substring(3, 5)),
//             )
//           : null,
//       yearlyDate: json['yearly_date'] != null
//           ? DateTime.parse(json['yearly_date'])
//           : null,
//       yearlyTime: json['yearly_time'] != null
//           ? TimeOfDay(
//               hour: int.parse(json['yearly_time'].substring(0, 2)),
//               minute: int.parse(json['yearly_time'].substring(3, 5)),
//             )
//           : null,
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'schedule_type': scheduleType,
//       'daily_days_of_week': dailyDaysOfWeek?.join(','),
//       'daily_time': dailyTime != null ? '${dailyTime!.hour.toString().padLeft(2, '0')}:${dailyTime!.minute.toString().padLeft(2, '0')}:00' : null,
//       'monthly_months': monthlyMonths?.join(','),
//       'monthly_day_of_month': monthlyDayOfMonth,
//       'monthly_time': monthlyTime != null ? '${monthlyTime!.hour.toString().padLeft(2, '0')}:${monthlyTime!.minute.toString().padLeft(2, '0')}:00' : null,
//       'yearly_date': yearlyDate?.toIso8601String().split('T')[0],
//       'yearly_time': yearlyTime != null ? '${yearlyTime!.hour.toString().padLeft(2, '0')}:${yearlyTime!.minute.toString().padLeft(2, '0')}:00' : null,
//     };
//   }
// }

// class BackupStatus {
//   final bool isRunning;
//   final String? scheduleType;
//   final double progressPercent;
//   final String? message;
//   final DateTime? lastBackupTime;

//   BackupStatus({
//     required this.isRunning,
//     this.scheduleType,
//     required this.progressPercent,
//     this.message,
//     this.lastBackupTime,
//   });

//   factory BackupStatus.fromJson(Map<String, dynamic> json) {
//     return BackupStatus(
//       isRunning: json['is_running'] as bool,
//       scheduleType: json['schedule_type'] as String?,
//       // progressPercent: (json['progress_percent'] as num).toDouble(),
//       progressPercent: double.tryParse(json['progress_percent'].toString()) ?? 0.0,
//       message: json['message'] as String?,
//       lastBackupTime: json['last_backup_time'] != null
//           ? DateTime.parse(json['last_backup_time'])
//           : null,
//     );
//   }
// }