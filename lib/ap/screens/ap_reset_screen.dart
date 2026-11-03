import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../sa/widgets/sa_master_reset_view.dart';

// ล้างข้อมูลหลัก/การตั้งค่าของ AP — ธุรกรรมล้างที่หน้าจอ "ล้างธุรกรรมทุกโมดูล" (SaSystemResetScreen)
class ApResetScreen extends StatelessWidget {
  const ApResetScreen({super.key});

  static String _rows(Map<String, dynamic>? c, String key, bool en) =>
      '$key (${c?[key] ?? '-'} ${en ? 'rows' : 'รายการ'})';

  @override
  Widget build(BuildContext context) {
    return MasterResetView(
      countsUrl: '${AppConfig.apiAp}/ap_reset_master/counts',
      resetUrl: '${AppConfig.apiAp}/ap_reset_master',
      descriptionTh: 'ฟังก์ชันนี้จะลบข้อมูลหลักของ AP (เจ้าหนี้, กลุ่มเจ้าหนี้) '
          'และ/หรือคืนค่าการตั้งค่าตามที่เลือกไว้ด้านล่างอย่างถาวร',
      descriptionEn: 'Permanently deletes AP master data (vendors, vendor groups) '
          'and/or resets the settings selected below.',
      options: [
        MasterResetOption(
          bodyKey: 'resetVendorRunning',
          icon: Icons.tag,
          color: Colors.indigo[700]!,
          titleTh: 'ตั้งค่ารหัสเจ้าหนี้อัตโนมัติ',
          titleEn: 'Vendor code auto-numbering',
          subtitle: (c, en) {
            final r = c?['ap_vendor_running'];
            final on = r?['is_auto_numbering'] == true;
            return en
                ? 'ap_vendor_running — enabled: ${on ? 'yes' : 'no'}, next number: ${r?['next_running_number'] ?? '-'}'
                : 'ap_vendor_running — เปิดใช้งาน: ${on ? 'ใช่' : 'ไม่ใช่'}, เลขที่ถัดไป: ${r?['next_running_number'] ?? '-'}';
          },
          details: const [
            ('คืนค่าเป็นค่าเริ่มต้น: ปิดใช้งาน, รูปแบบ VENDOR-0001, เลขที่ถัดไป = 1',
             'Back to defaults: disabled, format VENDOR-0001, next number = 1'),
          ],
        ),
        MasterResetOption(
          bodyKey: 'resetVendors',
          icon: Icons.store,
          color: Colors.red[700]!,
          titleTh: 'เจ้าหนี้',
          titleEn: 'Vendors',
          subtitle: (c, en) => _rows(c, 'ap_vendor', en),
          details: const [
            ('ลบเจ้าหนี้ทั้งหมด รวมที่อยู่/ผู้ติดต่อ/บัญชีธนาคาร',
             'Deletes all vendors incl. addresses, contacts and bank accounts'),
          ],
        ),
        MasterResetOption(
          bodyKey: 'resetVendorGroups',
          icon: Icons.groups,
          color: Colors.blue[700]!,
          titleTh: 'กลุ่มเจ้าหนี้',
          titleEn: 'Vendor groups',
          subtitle: (c, en) => _rows(c, 'ap_vendor_group', en),
          details: const [
            ('ถ้าเจ้าหนี้ยังอ้างอิงกลุ่มอยู่ ต้องเลือก "เจ้าหนี้" ด้วย',
             'If vendors still reference a group, select "Vendors" too'),
          ],
        ),
        MasterResetOption(
          bodyKey: 'resetGlAccountSetup',
          icon: Icons.account_balance,
          color: Colors.teal[700]!,
          titleTh: 'ตั้งค่าเชื่อมต่อ GL',
          titleEn: 'GL account setup',
          subtitle: (c, en) => _rows(c, 'ap_gl_account_setup', en),
          details: const [
            ('ลบการตั้งค่าบัญชีเชื่อมต่อ GL ตามประเภทเอกสาร/วิธีชำระเงินทั้งหมด',
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
            final set = c?['ap_year_end_setup_configured'] == true;
            return en
                ? 'FX accounts: ${set ? 'configured' : 'not configured'}'
                : 'บัญชี FX: ${set ? 'ตั้งค่าแล้ว' : 'ยังไม่ตั้งค่า'}';
          },
          details: const [
            ('คืนค่าบัญชี FX Gain/Loss และประเภทเอกสาร GL ของการตีราคาเป็นค่าว่าง',
             'Clears the FX gain/loss accounts and the revaluation GL document type'),
          ],
        ),
      ],
    );
  }
}
