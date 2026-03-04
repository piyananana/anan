// widgets/confirm_logout_dialog.dart
import 'package:flutter/material.dart';

class ConfirmLogoutDialog extends StatelessWidget {
  const ConfirmLogoutDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ยืนยันการออกจากระบบ'),
      content: const Text('คุณแน่ใจหรือไม่ว่าต้องการออกจากระบบ?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false), // ไม่ยืนยัน
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true), // ยืนยัน
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('ออกจากระบบ', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}