// lib/cm/screens/cm_reset_screen.dart
import 'package:flutter/material.dart';
import '../../sa/utils/menu_scope.dart';
import '../services/cm_reset_service.dart';

const _kTheme = Color(0xFF1565C0);

class CmResetScreen extends StatefulWidget {
  const CmResetScreen({super.key});
  @override
  State<CmResetScreen> createState() => _State();
}

class _State extends State<CmResetScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _svc         = CmResetService();
  final _confirmCtrl = TextEditingController();
  bool _resetting    = false;
  bool _done         = false;
  List<Map<String, dynamic>> _result = [];

  static const _tablesToDelete = [
    'cm_inter_bank_transfer',
    'cm_bank_fx_revaluation_line',
    'cm_bank_fx_revaluation',
    'cm_bank_statement_line',
    'cm_bank_statement',
    'cm_petty_cash_voucher',
    'cm_petty_cash_replenishment',
    'cm_receipt',
    'cm_payment',
  ];

  @override
  void dispose() {
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    if (_confirmCtrl.text != 'RESET CM') {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('พิมพ์ "RESET CM" เพื่อยืนยัน'), backgroundColor: Colors.red.shade700));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
          const SizedBox(width: 8),
          const Text('ยืนยัน Reset CM'),
        ]),
        content: const Text(
            'การดำเนินการนี้จะ**ลบข้อมูลธุรกรรม CM ทั้งหมด**อย่างถาวร\n\n'
            'รวมถึง: ใบรับเงิน, ใบจ่ายเงิน, เงินสดย่อย, Bank Statement, '
            'FX Revaluation และ Inter-bank Transfer\n\n'
            'ข้อมูลที่ลบแล้ว**ไม่สามารถกู้คืนได้** — ดำเนินการต่อใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน Reset'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() { _resetting = true; _done = false; });
    try {
      final result = await _svc.resetData('RESET CM');
      if (!mounted) return;
      setState(() {
        _result    = result;
        _done      = true;
        _resetting = false;
        _confirmCtrl.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reset CM เสร็จสิ้น'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      setState(() => _resetting = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red.shade700));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kTheme,
        foregroundColor: Colors.white,
        title: const MenuTitle(),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        toolbarHeight: 40,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 22),
                    const SizedBox(width: 8),
                    Text('คำเตือน: การดำเนินการนี้ไม่สามารถยกเลิกได้',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                  ]),
                  const SizedBox(height: 12),
                  const Text('รายการที่จะถูกลบทั้งหมด:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ..._tablesToDelete.map((t) => Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 2),
                    child: Row(children: [
                      const Icon(Icons.remove, size: 14, color: Colors.red),
                      const SizedBox(width: 6),
                      Text(t, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
                    ]),
                  )),
                  const SizedBox(height: 12),
                  const Text('ข้อมูล Master (บัญชีธนาคาร, วิธีการชำระเงิน, สมุดเช็ค ฯลฯ) จะ**ไม่ถูกลบ**',
                      style: TextStyle(fontSize: 13, color: Colors.green)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Confirmation input
            const Text('พิมพ์ "RESET CM" เพื่อยืนยัน:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              width: 240,
              child: TextField(
                controller: _confirmCtrl,
                style: const TextStyle(fontSize: 14, fontFamily: 'monospace', letterSpacing: 1),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.all(10),
                  border: const OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.red.shade400, width: 2)),
                  hintText: 'RESET CM',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _confirmCtrl.text == 'RESET CM' ? Colors.red : Colors.grey.shade400,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 40),
              ),
              onPressed: (_resetting || _confirmCtrl.text != 'RESET CM') ? null : _reset,
              icon: _resetting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.delete_forever, size: 18),
              label: const Text('Reset ข้อมูล CM ทั้งหมด', style: TextStyle(fontSize: 13)),
            ),

            // Result
            if (_done && _result.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              const Text('ผลการ Reset:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._result.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Icon(Icons.check_circle_outline, size: 16, color: Colors.green.shade600),
                  const SizedBox(width: 8),
                  Text('${r['table']}', style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
                  const SizedBox(width: 8),
                  Text('ลบ ${r['deleted']} แถว',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ]),
              )),
            ],
          ],
        ),
      ),
    );
  }
}
