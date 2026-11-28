// lib/mo/screens/mo_gl_account_setup_screen.dart
// ประเภทเอกสารใบสั่งผลิตเชื่อมต่อ GL — หน้าตาแบบเดียวกับ IM (sa_gl_setup_kit.dart, user 2026-11-26)
// ชุดบัญชีเดียวต่อใบสั่งผลิต: MOI/MOR ที่อ้างอิงใบสั่งผลิต, บันทึกเวลา และปิดใบสั่งผลิต ใช้บัญชีเหล่านี้ทั้งหมด
// (moHeaderController: บันทึกเวลาต้องมี gl_doc_id + wip, ค่าแรง/โสหุ้ยเมื่อมียอด; ปิดใบสั่งผลิตต้องมี wip + variance + gl_doc_id)
import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../sa/widgets/sa_gl_setup_kit.dart';

bool _all(String _) => true;

final moGlSetupSpec = GlSetupSpec(
  module: 'MO',
  baseUrl: '${AppConfig.apiMo}/mo_gl_account_setup',
  placeholderTh: 'เลือกประเภทเอกสารใบสั่งผลิตด้านซ้าย',
  placeholderEn: 'Select a manufacturing order document type on the left',
  noGl: (_) => false,
  groupOf: (_) => 'MO',
  groups: const [('MO', 'ใบสั่งผลิต', 'Manufacturing orders')],
  glDocTh: 'ประเภทเอกสาร GL (บันทึกเวลาและปิดใบสั่งผลิต)',
  glDocEn: 'GL document type (time logs and order closing)',
  glDocHintTh: 'MOI/MOR ใช้ประเภทเอกสาร GL ของประเภทเอกสาร IM ของตัวเอง',
  glDocHintEn: 'MOI/MOR use the GL document type of their own IM document type',
  banner: (_, e) => e
      ? 'One account set per manufacturing order: material issues (MOI) and production receipts (MOR) that reference the order, time logs and order closing all use these accounts.'
      : 'ชุดบัญชีเดียวต่อใบสั่งผลิต: เบิกวัตถุดิบ (MOI) และรับสินค้าจากการผลิต (MOR) ที่อ้างอิงใบสั่งผลิต การบันทึกเวลา และการปิดใบสั่งผลิต ใช้บัญชีเหล่านี้ทั้งหมด',
  accounts: const [
    GlAcct('wip_account_id', 'งานระหว่างผลิต (WIP)', 'Work in process (WIP)', show: _all, requiredFor: _all),
    GlAcct('variance_account_id', 'ผลต่างต้นทุนการผลิต', 'Manufacturing cost variance', show: _all, requiredFor: _all),
    GlAcct('applied_labor_account_id', 'ค่าแรงที่ปันเข้างาน', 'Applied labor',
        show: _all, optTh: 'ต้องตั้งเมื่อบันทึกเวลามีค่าแรง', optEn: 'Needed when time logs carry labor cost'),
    GlAcct('applied_overhead_account_id', 'โสหุ้ยการผลิตที่ปันเข้างาน', 'Applied manufacturing overhead',
        show: _all,
        optTh: 'ต้องตั้งเมื่อมีโสหุ้ยจากบันทึกเวลา หรือโสหุ้ยแบบ % ตอน MOR',
        optEn: 'Needed for time-log overhead, or percentage overhead at MOR'),
  ],
  journal: (_) => const [
    GlJSection([
      GlJ('Dr', 'wip_account_id'),
      GlJ.text('  Cr', 'บัญชีสินค้าคงคลัง (ตามการตั้งค่า IM)', 'Inventory (per the IM setup)'),
    ], th: 'เบิกวัตถุดิบเข้าผลิต (MOI)', en: 'Material issue (MOI)'),
    GlJSection([
      GlJ('Dr', 'wip_account_id'),
      GlJ('  Cr', 'applied_labor_account_id', 'ชั่วโมงแรงงาน x อัตราค่าแรง', 'labor hours x labor rate'),
      GlJ('  Cr', 'applied_overhead_account_id', 'ชั่วโมงเครื่องจักร x อัตรา', 'machine hours x rate'),
    ], th: 'บันทึกเวลาปฏิบัติงาน', en: 'Time log'),
    GlJSection([
      GlJ.text('Dr', 'บัญชีสินค้าคงคลัง (ตามการตั้งค่า IM)', 'Inventory (per the IM setup)'),
      GlJ('Dr/Cr', 'variance_account_id', 'ต้นทุนมาตรฐาน - ต้นทุนจริง', 'standard - actual cost'),
      GlJ('  Cr', 'wip_account_id'),
    ], th: 'รับสินค้าจากการผลิต (MOR)', en: 'Production receipt (MOR)'),
    GlJSection([
      GlJ('Dr/Cr', 'variance_account_id', 'WIP คงเหลือ', 'WIP left over'),
      GlJ('Dr/Cr', 'wip_account_id'),
    ], th: 'ปิดใบสั่งผลิต', en: 'Order closing'),
  ],
);

class MoGlAccountSetupScreen extends StatelessWidget {
  const MoGlAccountSetupScreen({super.key});

  @override
  Widget build(BuildContext context) => GlSetupScreen(spec: moGlSetupSpec);
}
