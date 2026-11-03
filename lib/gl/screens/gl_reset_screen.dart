import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../sa/widgets/sa_master_reset_view.dart';

// ล้างข้อมูลหลัก/การตั้งค่าของ GL — รายการบัญชี/ยอดสะสม/ปิดงวด/ปิดปี ล้างที่หน้าจอ "ล้างธุรกรรมทุกโมดูล" (SaSystemResetScreen)
class GlResetScreen extends StatelessWidget {
  const GlResetScreen({super.key});

  static String _rows(Map<String, dynamic>? c, String key, bool en) =>
      '$key (${c?[key] ?? '-'} ${en ? 'rows' : 'รายการ'})';

  @override
  Widget build(BuildContext context) {
    return MasterResetView(
      countsUrl: '${AppConfig.apiGl}/gl_reset_master/counts',
      resetUrl: '${AppConfig.apiGl}/gl_reset_master',
      descriptionTh: 'ฟังก์ชันนี้จะลบข้อมูลหลักของ GL (ผังบัญชี, มิติ, ปีบัญชี/งวดบัญชี, แบบงบการเงิน, ตั้งค่าปิดสิ้นปี) '
          'และ/หรือคืนค่าสถานะงวดบัญชีตามที่เลือกไว้ด้านล่างอย่างถาวร',
      descriptionEn: 'Permanently deletes GL master data (chart of accounts, dimensions, fiscal years/periods, '
          'financial report layouts, year-end closing setup) and/or resets period statuses as selected below.',
      options: [
        MasterResetOption(
          bodyKey: 'resetPeriodStatus',
          icon: Icons.lock_reset,
          color: Colors.indigo[700]!,
          titleTh: 'คืนสถานะงวดบัญชีเป็นค่าเริ่มต้น',
          titleEn: 'Reset period statuses to default',
          subtitle: (c, en) => en
              ? 'gl_posting_period — ${c?['gl_posting_period_changed'] ?? '-'} of ${c?['gl_posting_period'] ?? '-'} periods changed from default'
              : 'gl_posting_period — เปลี่ยนจากค่าเริ่มต้นแล้ว ${c?['gl_posting_period_changed'] ?? '-'} จาก ${c?['gl_posting_period'] ?? '-'} งวด',
          details: const [
            ('สถานะ GL/AP/AR/IM กลับเป็นปิด (LOCKED) และ CM เป็นเปิด เหมือนตอนสร้างงวดใหม่ — เปิดงวดที่จะใช้เองที่หน้าจองวดบัญชี',
             'GL/AP/AR/IM statuses back to LOCKED and CM to OPEN, as when a period is created — open the periods you need on the posting period screen'),
          ],
        ),
        MasterResetOption(
          bodyKey: 'resetFinancialReports',
          icon: Icons.assessment,
          color: Colors.blue[700]!,
          titleTh: 'แบบงบการเงิน',
          titleEn: 'Financial report layouts',
          subtitle: (c, en) => _rows(c, 'gl_fin_report', en),
          details: const [
            ('ลบแบบงบการเงินทั้งหมด รวมแถวและคอลัมน์ของรายงาน', 'Deletes all report layouts incl. their rows and columns'),
          ],
        ),
        MasterResetOption(
          bodyKey: 'resetClosingConfig',
          icon: Icons.event_note,
          color: Colors.deepPurple[600]!,
          titleTh: 'ตั้งค่าปิดสิ้นปี / รายการปรับปรุง',
          titleEn: 'Year-end closing setup / adjusting templates',
          subtitle: (c, en) => en
              ? 'gl_closing_config (${c?['gl_closing_config'] ?? '-'}), gl_adjusting_template (${c?['gl_adjusting_template'] ?? '-'})'
              : 'gl_closing_config (${c?['gl_closing_config'] ?? '-'}), gl_adjusting_template (${c?['gl_adjusting_template'] ?? '-'})',
        ),
        MasterResetOption(
          bodyKey: 'resetDimensions',
          icon: Icons.view_in_ar,
          color: Colors.teal[700]!,
          titleTh: 'มิติ (Dimension)',
          titleEn: 'Dimensions',
          subtitle: (c, en) => en
              ? 'types (${c?['gl_dimension_type'] ?? '-'}), values (${c?['gl_dimension_value'] ?? '-'}), combinations (${c?['gl_dim_combination'] ?? '-'})'
              : 'ประเภท (${c?['gl_dimension_type'] ?? '-'}), ค่ามิติ (${c?['gl_dimension_value'] ?? '-'}), ชุดค่าผสม (${c?['gl_dim_combination'] ?? '-'})',
          details: const [
            ('ลบประเภทมิติ ค่ามิติ ชุดค่าผสม และกฎบังคับมิติของบัญชีทั้งหมด',
             'Deletes all dimension types, values, combinations and account dimension rules'),
          ],
        ),
        MasterResetOption(
          bodyKey: 'resetFiscalYears',
          icon: Icons.calendar_month,
          color: Colors.orange[800]!,
          titleTh: 'ปีบัญชี / งวดบัญชี',
          titleEn: 'Fiscal years / posting periods',
          subtitle: (c, en) => en
              ? 'gl_fiscal_year (${c?['gl_fiscal_year'] ?? '-'}), gl_posting_period (${c?['gl_posting_period'] ?? '-'})'
              : 'gl_fiscal_year (${c?['gl_fiscal_year'] ?? '-'}), gl_posting_period (${c?['gl_posting_period'] ?? '-'})',
          details: const [
            ('ลบปีบัญชีและงวดบัญชีทั้งหมด และล้างงวดที่ตั้งค่าอ้างอิงไว้ (เช่น งวดที่เริ่มใช้โหมดบัญชีสินค้าคงคลัง)',
             'Deletes all fiscal years and periods and clears settings that reference a period (e.g. inventory accounting mode start period)'),
          ],
        ),
        MasterResetOption(
          bodyKey: 'resetChartOfAccounts',
          icon: Icons.account_tree,
          color: Colors.red[700]!,
          titleTh: 'ผังบัญชี',
          titleEn: 'Chart of accounts',
          subtitle: (c, en) => en
              ? 'gl_account (${c?['gl_account'] ?? '-'} rows) — referenced by ${c?['gl_account_refs'] ?? '-'} master/setup rows'
              : 'gl_account (${c?['gl_account'] ?? '-'} รายการ) — ถูกอ้างอิงในข้อมูลหลัก/การตั้งค่า ${c?['gl_account_refs'] ?? '-'} รายการ',
          details: const [
            ('ลบผังบัญชีทั้งหมด และล้างบัญชีที่ผูกไว้ในข้อมูลหลัก/การตั้งค่าของทุกโมดูลเป็นค่าว่าง '
                '(เช่น ลูกค้า, ผู้ขาย, สินค้า, บัญชีธนาคาร, อัตราภาษี, ตั้งค่า GL ของแต่ละโมดูล)',
             'Deletes the whole chart of accounts and clears linked accounts in every module\'s master data and setup '
                 '(e.g. customers, vendors, items, bank accounts, tax rates, module GL setups)'),
            ('ถ้ามีรายการปรับปรุง (Adjusting Template) ต้องเลือก "ตั้งค่าปิดสิ้นปี / รายการปรับปรุง" ด้วย',
             'If adjusting templates exist, select "Year-end closing setup / adjusting templates" too'),
          ],
        ),
      ],
    );
  }
}
