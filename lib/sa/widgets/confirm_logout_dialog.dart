// widgets/confirm_logout_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_provider.dart';

class ConfirmLogoutDialog extends StatelessWidget {
  const ConfirmLogoutDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    return AlertDialog(
      title: Text(isEnglish ? 'Confirm Logout' : 'ยืนยันการออกจากระบบ'),
      content: Text(isEnglish
          ? 'Are you sure you want to log out?'
          : 'คุณแน่ใจหรือไม่ว่าต้องการออกจากระบบ?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(isEnglish ? 'Cancel' : 'ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: Text(
            isEnglish ? 'Logout' : 'ออกจากระบบ',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
