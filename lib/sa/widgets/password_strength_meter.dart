// lib/widgets/password_strength_meter.dart
import 'package:flutter/material.dart';
import '../models/password_policy.dart';

class PasswordStrengthMeter extends StatelessWidget {
  final String password;
  final PasswordPolicy? policy;
  final bool isEnglish;

  const PasswordStrengthMeter({
    super.key,
    required this.password,
    this.policy,
    this.isEnglish = false,
  });

  double _calculateStrength(String pwd) {
    if (pwd.isEmpty) return 0.0;
    double score = 0.0;
    double weightTotal = 0.0;
    policy!.minLength > 0 ? weightTotal += 1.0 : weightTotal = weightTotal;
    policy?.requireUppercase == true ? weightTotal += 1.0 : weightTotal = weightTotal;
    policy?.requireLowercase == true ? weightTotal += 1.0 : weightTotal = weightTotal;
    policy?.requireDigits == true ? weightTotal += 1.0 : weightTotal = weightTotal;
    policy?.requireSpecialChars == true ? weightTotal += 1.0 : weightTotal = weightTotal;

    final wLen   = 1.0 / weightTotal;
    final wUpper = policy?.requireUppercase    == true ? 1.0 / weightTotal : 0.0;
    final wLower = policy?.requireLowercase    == true ? 1.0 / weightTotal : 0.0;
    final wDigit = policy?.requireDigits       == true ? 1.0 / weightTotal : 0.0;
    final wSpec  = policy?.requireSpecialChars == true ? 1.0 / weightTotal : 0.0;

    score += (pwd.length / (policy?.minLength ?? 8)).clamp(0.0, 1.0) * wLen;
    if (policy?.requireUppercase    == true && RegExp(r'[A-Z]').hasMatch(pwd)) score += wUpper;
    if (policy?.requireLowercase    == true && RegExp(r'[a-z]').hasMatch(pwd)) score += wLower;
    if (policy?.requireDigits       == true && RegExp(r'[0-9]').hasMatch(pwd)) score += wDigit;
    if (policy?.requireSpecialChars == true && RegExp(r'[^A-Za-z0-9]').hasMatch(pwd)) score += wSpec;
    return score.clamp(0.0, 1.0);
  }

  Color _getColor(double s) {
    if (s < 0.25) return Colors.red;
    if (s < 0.5)  return Colors.orange;
    if (s < 0.75) return Colors.yellow;
    return Colors.green;
  }

  String _getText(double s) {
    if (s < 0.25) return isEnglish ? 'Very Weak'  : 'อ่อนมาก';
    if (s < 0.5)  return isEnglish ? 'Weak'       : 'อ่อน';
    if (s < 0.75) return isEnglish ? 'Medium'     : 'ปานกลาง';
    return              isEnglish  ? 'Strong'      : 'แข็งแรง';
  }

  @override
  Widget build(BuildContext context) {
    final strength = _calculateStrength(password);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: strength,
          backgroundColor: Colors.grey[300],
          color: _getColor(strength),
          minHeight: 8,
        ),
        const SizedBox(height: 4),
        Text(
          '${isEnglish ? "Strength" : "ความแข็งแรง"}: ${_getText(strength)}',
          style: TextStyle(fontSize: 12, color: _getColor(strength)),
        ),
      ],
    );
  }
}
