import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../sa/widgets/sa_master_reset_view.dart';

// ล้างข้อมูลหลัก/การตั้งค่าของ AR — ธุรกรรมล้างที่หน้าจอ "ล้างธุรกรรมทุกโมดูล" (SaSystemResetScreen)
class ArResetScreen extends StatelessWidget {
  const ArResetScreen({super.key});

  static String _rows(Map<String, dynamic>? c, String key, bool en) =>
      '$key (${c?[key] ?? '-'} ${en ? 'rows' : 'รายการ'})';

  @override
  Widget build(BuildContext context) {
    return MasterResetView(
      countsUrl: '${AppConfig.apiAr}/ar_reset_master/counts',
      resetUrl: '${AppConfig.apiAr}/ar_reset_master',
      descriptionTh: 'ฟังก์ชันนี้จะลบข้อมูลหลักของ AR (ลูกค้า, กลุ่มลูกค้า, ผู้วางบิล/รับชำระ) '
          'และ/หรือคืนค่าการตั้งค่าตามที่เลือกไว้ด้านล่างอย่างถาวร',
      descriptionEn: 'Permanently deletes AR master data (customers, customer groups, billing/collection staff) '
          'and/or resets the settings selected below.',
      options: [
        MasterResetOption(
          bodyKey: 'resetCustomerRunning',
          icon: Icons.tag,
          color: Colors.indigo[700]!,
          titleTh: 'ตั้งค่ารหัสลูกค้าอัตโนมัติ',
          titleEn: 'Customer code auto-numbering',
          subtitle: (c, en) {
            final r = c?['ar_customer_running'];
            final on = r?['is_auto_numbering'] == true;
            return en
                ? 'ar_customer_running — enabled: ${on ? 'yes' : 'no'}, next number: ${r?['next_running_number'] ?? '-'}'
                : 'ar_customer_running — เปิดใช้งาน: ${on ? 'ใช่' : 'ไม่ใช่'}, เลขที่ถัดไป: ${r?['next_running_number'] ?? '-'}';
          },
          details: const [
            ('คืนค่าเป็นค่าเริ่มต้น: ปิดใช้งาน, รูปแบบ CUST-0001, เลขที่ถัดไป = 1',
             'Back to defaults: disabled, format CUST-0001, next number = 1'),
          ],
        ),
        MasterResetOption(
          bodyKey: 'resetCustomers',
          icon: Icons.people,
          color: Colors.red[700]!,
          titleTh: 'ลูกค้า',
          titleEn: 'Customers',
          subtitle: (c, en) => _rows(c, 'ar_customer', en),
          details: const [
            ('ลบลูกค้าทั้งหมด รวมที่อยู่/ผู้ติดต่อ/บัญชีธนาคาร/เงื่อนไขวางบิล-รับชำระ/พนักงานขาย',
             'Deletes all customers incl. addresses, contacts, bank accounts, billing/payment conditions and salespersons'),
          ],
        ),
        MasterResetOption(
          bodyKey: 'resetCustomerGroups',
          icon: Icons.groups,
          color: Colors.blue[700]!,
          titleTh: 'กลุ่มลูกค้า',
          titleEn: 'Customer groups',
          subtitle: (c, en) => _rows(c, 'ar_customer_group', en),
          details: const [
            ('ลบกลุ่มลูกค้าทั้งหมด รวมเงื่อนไขวางบิล/รับชำระของกลุ่ม',
             'Deletes all customer groups incl. group billing/payment conditions'),
            ('ถ้าลูกค้ายังอ้างอิงกลุ่มอยู่ ต้องเลือก "ลูกค้า" ด้วย',
             'If customers still reference a group, select "Customers" too'),
          ],
        ),
        MasterResetOption(
          bodyKey: 'resetCollectors',
          icon: Icons.badge,
          color: Colors.brown[600]!,
          titleTh: 'ผู้วางบิล/รับชำระ',
          titleEn: 'Billing/collection staff',
          subtitle: (c, en) => _rows(c, 'ar_collector', en),
          details: const [
            ('ถ้าลูกค้ายังอ้างอิงผู้วางบิล/รับชำระอยู่ ต้องเลือก "ลูกค้า" ด้วย',
             'If customers still reference this staff, select "Customers" too'),
          ],
        ),
        MasterResetOption(
          bodyKey: 'resetGlAccountSetup',
          icon: Icons.account_balance,
          color: Colors.teal[700]!,
          titleTh: 'ตั้งค่าเชื่อมต่อ GL',
          titleEn: 'GL account setup',
          subtitle: (c, en) => _rows(c, 'ar_gl_account_setup', en),
          details: const [
            ('ลบการตั้งค่าบัญชีเชื่อมต่อ GL ตามประเภทเอกสาร/วิธีรับชำระเงินทั้งหมด',
             'Deletes all GL account mappings by document type / payment method'),
          ],
        ),
        MasterResetOption(
          bodyKey: 'resetYearEndSetup',
          icon: Icons.event_note,
          color: Colors.deepPurple[600]!,
          titleTh: 'ตั้งค่าปิดสิ้นปี',
          titleEn: 'Year-end setup',
          subtitle: (c, en) {
            final set = c?['ar_year_end_setup_configured'] == true;
            return en
                ? 'FX/allowance accounts: ${set ? 'configured' : 'not configured'}  |  allowance rules (${c?['ar_allowance_rule'] ?? '-'})'
                : 'บัญชี FX/Allowance: ${set ? 'ตั้งค่าแล้ว' : 'ยังไม่ตั้งค่า'}  |  กฎ % สำรอง (${c?['ar_allowance_rule'] ?? '-'})';
          },
          details: const [
            ('คืนค่าบัญชี FX Gain/Loss และ Allowance เป็นค่าว่าง', 'Clears the FX gain/loss and allowance accounts'),
            ('คืนค่ากฎ % สำรองหนี้สูญเป็นค่าเริ่มต้น 4 ช่วงอายุหนี้', 'Resets allowance rules to the default 4 aging bands'),
          ],
        ),
      ],
    );
  }
}
