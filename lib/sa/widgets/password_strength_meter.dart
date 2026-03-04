// lib/widgets/password_strength_meter.dart
import 'package:flutter/material.dart';
import '../models/password_policy.dart'; // Ensure this path is correct

class PasswordStrengthMeter extends StatelessWidget {
  final String password;
  final PasswordPolicy? policy; // Optional: policy to evaluate against

  const PasswordStrengthMeter({
    super.key,
    required this.password,
    this.policy,
  });

  // Calculate password strength (simple example)
  double _calculateStrength(String pwd) {
    if (pwd.isEmpty) return 0.0;
    double score = 0.0;
    double weightOfLength = 0.0;
    double weightOfUppercase = 0.0;
    double weightOfLowercase = 0.0;
    double weightOfDigits = 0.0;
    double weightOfSpecialChars = 0.0;
    double weightTotal = 0.0;
    // Calculate weights based on policy
    policy!.minLength > 0 ? weightTotal += 1.0 : weightTotal = weightTotal;
    policy?.requireUppercase == true
        ? weightTotal += 1.0
        : weightTotal = weightTotal;
    policy?.requireLowercase == true
        ? weightTotal += 1.0
        : weightTotal = weightTotal;
    policy?.requireDigits == true
        ? weightTotal += 1.0
        : weightTotal = weightTotal;
    policy?.requireSpecialChars == true
        ? weightTotal += 1.0
        : weightTotal = weightTotal;
    // Calculate weights for each criterion
    weightOfLength = 1.0 / weightTotal;
    weightOfUppercase =
        policy?.requireUppercase == true ? 1.0 / weightTotal : 0.0;
    weightOfLowercase =
        policy?.requireLowercase == true ? 1.0 / weightTotal : 0.0;
    weightOfDigits = policy?.requireDigits == true ? 1.0 / weightTotal : 0.0;
    weightOfSpecialChars =
        policy?.requireSpecialChars == true ? 1.0 / weightTotal : 0.0;

    // Length score
    score += (pwd.length / (policy?.minLength ?? 8)).clamp(0.0, 1.0) *
        weightOfLength;
    // score += (pwd.length / (policy?.minLength ?? 8)).clamp(0.0, 1.0) * 0.25;
    // Character type scores
    if (policy?.requireUppercase == true && RegExp(r'[A-Z]').hasMatch(pwd)) {
      score += weightOfUppercase; // score += 0.25;
    }
    if (policy?.requireLowercase == true && RegExp(r'[a-z]').hasMatch(pwd)) {
      score += weightOfLowercase; // score += 0.25;
    }
    if (policy?.requireDigits == true && RegExp(r'[0-9]').hasMatch(pwd)) {
      score += weightOfDigits; // score += 0.25;
    }
    if (policy?.requireSpecialChars == true &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(pwd)) {
      score += weightOfSpecialChars; // score += 0.25;
    }
    // Cap the score at 1.0 (100%)
    return score.clamp(0.0, 1.0);
  }

  Color _getColor(double strength) {
    if (strength < 0.25) return Colors.red;
    if (strength < 0.5) return Colors.orange;
    if (strength < 0.75) return Colors.yellow;
    return Colors.green;
  }

  String _getText(double strength) {
    if (strength < 0.25) return 'อ่อนมาก';
    if (strength < 0.5) return 'อ่อน';
    if (strength < 0.75) return 'ปานกลาง';
    return 'แข็งแรง';
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
          'ความแข็งแรง: ${_getText(strength)}',
          style: TextStyle(fontSize: 12, color: _getColor(strength)),
        ),
      ],
    );
  }
}
