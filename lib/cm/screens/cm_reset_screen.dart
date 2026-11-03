// lib/cm/screens/cm_reset_screen.dart
import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../sa/widgets/sa_master_reset_view.dart';

// ล้างข้อมูลหลัก/การตั้งค่าของ CM — ธุรกรรม (รวมยอดยกมาธนาคาร) ล้างที่หน้าจอ "ล้างธุรกรรมทุกโมดูล" (SaSystemResetScreen)
class CmResetScreen extends StatelessWidget {
  const CmResetScreen({super.key});

  static String _rows(Map<String, dynamic>? c, String key, bool en) =>
      '$key (${c?[key] ?? '-'} ${en ? 'rows' : 'รายการ'})';

  @override
  Widget build(BuildContext context) {
    return MasterResetView(
      countsUrl: '${AppConfig.apiCm}/cm_reset_master/counts',
      resetUrl: '${AppConfig.apiCm}/cm_reset_master',
      descriptionTh: 'ฟังก์ชันนี้จะลบข้อมูลหลักของ CM (บัญชีธนาคาร, สมุดเช็ค, รูปแบบพิมพ์เช็ค, ช่องทางชำระเงิน, '
          'รูปแบบไฟล์ธนาคาร) และ/หรือการตั้งค่าบัญชีตามที่เลือกไว้ด้านล่างอย่างถาวร',
      descriptionEn: 'Permanently deletes CM master data (bank accounts, checkbooks, check print layouts, '
          'payment methods, bank file formats) and/or the account setup selected below.',
      options: [
        MasterResetOption(
          bodyKey: 'resetBankAccounts',
          icon: Icons.account_balance,
          color: Colors.red[700]!,
          titleTh: 'บัญชีธนาคาร / เงินสด',
          titleEn: 'Bank / cash accounts',
          subtitle: (c, en) => _rows(c, 'cm_bank_account', en),
          details: const [
            ('ลบบัญชีธนาคาร/เงินสด/เงินสดย่อยทั้งหมด รวมสมุดเช็คและรูปแบบพิมพ์เช็คของบัญชี',
             'Deletes all bank/cash/petty cash accounts incl. their checkbooks and check print layouts'),
            ('ถ้าช่องทางชำระเงินยังผูกบัญชีธนาคารอยู่ ต้องเลือก "ช่องทางชำระเงิน" ด้วย',
             'If payment methods are still linked to a bank account, select "Payment methods" too'),
          ],
        ),
        MasterResetOption(
          bodyKey: 'resetCheckbooks',
          icon: Icons.menu_book,
          color: Colors.orange[800]!,
          titleTh: 'สมุดเช็ค',
          titleEn: 'Checkbooks',
          subtitle: (c, en) => _rows(c, 'cm_checkbook', en),
        ),
        MasterResetOption(
          bodyKey: 'resetCheckPrintConfig',
          icon: Icons.print,
          color: Colors.brown[600]!,
          titleTh: 'รูปแบบพิมพ์เช็ค',
          titleEn: 'Check print layouts',
          subtitle: (c, en) => _rows(c, 'cm_check_print_config', en),
        ),
        MasterResetOption(
          bodyKey: 'resetPaymentMethods',
          icon: Icons.payments,
          color: Colors.blue[700]!,
          titleTh: 'ช่องทางชำระเงิน',
          titleEn: 'Payment methods',
          subtitle: (c, en) => _rows(c, 'cm_payment_method', en),
          details: const [
            ('ลบช่องทางรับ/จ่ายชำระทั้งหมด (ใช้ในใบรับ/จ่ายชำระ AR/AP และเอกสาร CM)',
             'Deletes all payment methods (used by AR/AP receipts/payments and CM documents)'),
          ],
        ),
        MasterResetOption(
          bodyKey: 'resetBankFileFormats',
          icon: Icons.description,
          color: Colors.indigo[700]!,
          titleTh: 'รูปแบบไฟล์ธนาคาร',
          titleEn: 'Bank file formats',
          subtitle: (c, en) => _rows(c, 'cm_bank_file_format', en),
        ),
        MasterResetOption(
          bodyKey: 'resetGlAccountSetup',
          icon: Icons.account_tree,
          color: Colors.teal[700]!,
          titleTh: 'ตั้งค่าบัญชีตามประเภทเอกสาร CM',
          titleEn: 'GL setup by CM document type',
          subtitle: (c, en) => _rows(c, 'cm_transaction_gl_setup', en),
          details: const [
            ('ลบการตั้งค่าบัญชีรายได้/ค่าใช้จ่าย/VAT/WHT/FX ตามประเภทเอกสาร CM ทั้งหมด',
             'Deletes all revenue/expense/VAT/WHT/FX account setup by CM document type'),
          ],
        ),
      ],
    );
  }
}
