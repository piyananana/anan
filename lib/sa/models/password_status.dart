// lib/models/password_status.dart
class PasswordStatus {
  final bool isPasswordExpired;
  final int? daysUntilExpiration; // null ถ้าไม่หมดอายุหรือไม่ได้อยู่ในช่วงแจ้งเตือน
  final bool forceChangePassword;

  PasswordStatus({
    required this.isPasswordExpired,
    this.daysUntilExpiration,
    required this.forceChangePassword,
  });

  factory PasswordStatus.fromJson(Map<String, dynamic> json) {
    return PasswordStatus(
      isPasswordExpired: json['isPasswordExpired'] as bool,
      daysUntilExpiration: json['daysUntilExpiration'] as int?,
      forceChangePassword: json['forceChangePassword'] as bool,
    );
  }
}