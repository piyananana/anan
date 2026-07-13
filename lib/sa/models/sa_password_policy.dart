// lib/models/sa_password_policy.dart
class PasswordPolicy {
  final int minLength;
  final bool requireUppercase;
  final bool requireLowercase;
  final bool requireDigits;
  final bool requireSpecialChars;
  final int passwordHistoryCount;
  final int passwordExpiryDays;
  final int passwordNotificationDays;
  final bool forcePasswordChangeOnExpiry;
  final int sessionTimeoutMinutes;
  /// 'dialog' = แสดง dialog ให้เลือก, 'force' = kick เครื่องเก่าทันที
  final String singleSessionMode;

  PasswordPolicy({
    required this.minLength,
    required this.requireUppercase,
    required this.requireLowercase,
    required this.requireDigits,
    required this.requireSpecialChars,
    required this.passwordHistoryCount,
    required this.passwordExpiryDays,
    required this.passwordNotificationDays,
    required this.forcePasswordChangeOnExpiry,
    this.sessionTimeoutMinutes = 5,
    this.singleSessionMode = 'dialog',
  });

  factory PasswordPolicy.fromJson(Map<String, dynamic> json) {
    return PasswordPolicy(
      minLength: json['min_length'] as int,
      requireUppercase: json['require_uppercase'] as bool,
      requireLowercase: json['require_lowercase'] as bool,
      requireDigits: json['require_digits'] as bool,
      requireSpecialChars: json['require_special_chars'] as bool,
      passwordHistoryCount: json['password_history_count'] as int,
      passwordExpiryDays: json['password_expiry_days'] as int,
      passwordNotificationDays: json['password_notification_days'] as int,
      forcePasswordChangeOnExpiry: json['force_password_change_on_expiry'] as bool,
      sessionTimeoutMinutes: (json['session_timeout_minutes'] as int?) ?? 5,
      singleSessionMode: (json['single_session_mode'] as String?) ?? 'dialog',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'min_length': minLength,
      'require_uppercase': requireUppercase,
      'require_lowercase': requireLowercase,
      'require_digits': requireDigits,
      'require_special_chars': requireSpecialChars,
      'password_history_count': passwordHistoryCount,
      'password_expiry_days': passwordExpiryDays,
      'password_notification_days': passwordNotificationDays,
      'force_password_change_on_expiry': forcePasswordChangeOnExpiry,
      'session_timeout_minutes': sessionTimeoutMinutes,
      'single_session_mode': singleSessionMode,
    };
  }
}

