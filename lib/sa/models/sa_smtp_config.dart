// lib/sa/models/sa_smtp_config.dart

class SaSmtpConfig {
  final int? id;
  final String host;
  final int port;
  final String? username;
  final String? fromEmail;
  final String? fromName;
  final bool useTls;
  final bool isActive;

  SaSmtpConfig({
    this.id,
    required this.host,
    this.port = 587,
    this.username,
    this.fromEmail,
    this.fromName,
    this.useTls = true,
    this.isActive = true,
  });

  factory SaSmtpConfig.fromJson(Map<String, dynamic> json) => SaSmtpConfig(
        id: json['id'],
        host: json['host'] ?? '',
        port: json['port'] ?? 587,
        username: json['username'],
        fromEmail: json['from_email'],
        fromName: json['from_name'],
        useTls: json['use_tls'] ?? true,
        isActive: json['is_active'] ?? true,
      );

  Map<String, dynamic> toJson({String? newPassword}) => {
        'host': host,
        'port': port,
        'username': username,
        if (newPassword != null && newPassword.isNotEmpty) 'password': newPassword,
        'from_email': fromEmail,
        'from_name': fromName,
        'use_tls': useTls,
        'is_active': isActive,
      };
}
