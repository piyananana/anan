// lib/cm/screens/cm_transaction_gl_setup_screen.dart
// ประเภทเอกสาร CM เชื่อมต่อ GL — หน้าตาแบบเดียวกับ IM (sa_gl_setup_kit.dart, user 2026-11-26)
// ช่องบัญชีต่อ sys_doc_type ตรงกับที่ cmTransactionController.postGlEntry ใช้จริง (pattern_gl_setup_fields_match_posting)
// CM doc types: 10=รายรับ 20=รายจ่าย 30=เติมเงินสดย่อย 40=เบิกเงินสดย่อย 50=โอนระหว่างบัญชี 70=ค่าธรรมเนียม 90=ดอกเบี้ย
// (15/25 สะท้อนรายการ AR/AP — ลงบัญชีที่ AR/AP แล้ว backend ไม่ส่งมาที่หน้านี้)
import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../sa/widgets/sa_gl_setup_kit.dart';

const _lineHeadTh = 'บัญชีในบรรทัด / หัวเอกสาร (ใช้ก่อนบัญชีนี้)';
const _lineHeadEn = 'The line / document header account (checked first)';
const _lvLineTh = 'บรรทัด · หัวเอกสาร';
const _lvLineEn = 'Line · document header';

final cmGlSetupSpec = GlSetupSpec(
  module: 'CM',
  guideModule: 'CM',
  baseUrl: '${AppConfig.apiCm}/cm_transaction_gl_setup',
  placeholderTh: 'เลือกประเภทเอกสาร CM ด้านซ้าย',
  placeholderEn: 'Select a CM document type on the left',
  noGl: (s) => ['15', '25'].contains(s),
  groupOf: (s) => switch (s) {
    '10' || '20' => 'IO',
    '30' || '40' => 'PETTY',
    _ => 'BANK',
  },
  groups: const [
    ('IO', 'รายรับ / รายจ่าย', 'Receipts / payments'),
    ('PETTY', 'เงินสดย่อย', 'Petty cash'),
    ('BANK', 'ธนาคาร', 'Bank'),
  ],
  banner: (s, e) => switch (s) {
    '50' => e
        ? 'An inter-bank transfer posts to the GL accounts set on each bank account (CM > Bank Account) — only the GL document type is needed here.'
        : 'โอนเงินระหว่างบัญชีใช้บัญชี GL ที่ตั้งไว้ในแต่ละบัญชีธนาคาร (CM > บัญชีธนาคาร) — ตั้งเฉพาะประเภทเอกสาร GL ที่หน้านี้',
    '10' || '20' || '70' || '90' => e
        ? 'The bank / cash side uses the GL account of the bank account or payment method on the document.'
        : 'ฝั่งเงินสด / ธนาคารใช้บัญชี GL ของบัญชีธนาคารหรือวิธีชำระในเอกสาร',
    _ => null,
  },
  accounts: [
    GlAcct('revenue_account_id', 'บัญชีรายได้', 'Revenue',
        show: (s) => ['10', '90'].contains(s),
        labelOf: (s, e) => s == '90' ? (e ? 'Interest income' : 'ดอกเบี้ยรับ') : null,
        fbTh: _lineHeadTh,
        fbEn: _lineHeadEn,
        levelsTh: _lvLineTh,
        levelsEn: _lvLineEn),
    GlAcct('expense_account_id', 'บัญชีค่าใช้จ่าย', 'Expense',
        show: (s) => ['20', '70', '90'].contains(s),
        labelOf: (s, e) => s == '90' ? (e ? 'Interest expense' : 'ดอกเบี้ยจ่าย') : null,
        fbTh: _lineHeadTh,
        fbEn: _lineHeadEn,
        levelsTh: _lvLineTh,
        levelsEn: _lvLineEn),
    GlAcct('petty_cash_payable_account_id', 'เงินสดย่อย', 'Petty cash',
        show: (s) => ['30', '40'].contains(s),
        fbTh: 'บัญชี GL ของกองเงินสดย่อย (ใช้ก่อนบัญชีนี้)',
        fbEn: 'The petty cash fund\'s GL account (checked first)',
        levelsTh: 'กองเงินสดย่อย',
        levelsEn: 'Petty cash fund'),
    GlAcct('vat_input_account_id', 'ภาษีซื้อ', 'Input VAT',
        show: (s) => ['20', '40', '70'].contains(s), optTh: 'ต้องตั้งเมื่อเอกสารมี VAT', optEn: 'Needed when documents carry VAT'),
    GlAcct('vat_output_account_id', 'ภาษีขาย', 'Output VAT',
        show: (s) => s == '10', optTh: 'ต้องตั้งเมื่อเอกสารมี VAT', optEn: 'Needed when documents carry VAT'),
    GlAcct('wht_payable_account_id', 'ภาษีหัก ณ ที่จ่ายค้างจ่าย', 'Withholding tax payable',
        show: (s) => s == '20', optTh: 'ต้องตั้งเมื่อหักภาษี ณ ที่จ่าย', optEn: 'Needed only when tax is withheld'),
    GlAcct('wht_prepaid_account_id', 'ภาษีถูกหัก ณ ที่จ่าย', 'Withholding tax deducted',
        show: (s) => ['10', '90'].contains(s), optTh: 'ต้องตั้งเมื่อถูกหักภาษี ณ ที่จ่าย', optEn: 'Needed only when the payer withholds tax'),
  ],
  journal: (s) => switch (s) {
    '10' => const [
        GlJSection([
          GlJ.text('Dr', 'บัญชีธนาคาร / วิธีชำระ', 'Bank account / payment method'),
          GlJ('Dr', 'wht_prepaid_account_id', 'ถ้าถูกหักภาษี', 'if tax is withheld'),
          GlJ('  Cr', 'revenue_account_id', 'ต่อบรรทัด', 'per line'),
          GlJ('  Cr', 'vat_output_account_id', 'ถ้ามี VAT', 'if VAT applies'),
        ]),
      ],
    '20' => const [
        GlJSection([
          GlJ('Dr', 'expense_account_id', 'ต่อบรรทัด', 'per line'),
          GlJ('Dr', 'vat_input_account_id', 'ถ้ามี VAT', 'if VAT applies'),
          GlJ('  Cr', 'wht_payable_account_id', 'ถ้าหักภาษี ณ ที่จ่าย', 'if tax is withheld'),
          GlJ.text('  Cr', 'บัญชีธนาคาร / วิธีชำระ', 'Bank account / payment method'),
        ]),
      ],
    '30' => const [
        GlJSection([
          GlJ('Dr', 'petty_cash_payable_account_id'),
          GlJ.text('  Cr', 'บัญชีธนาคาร / วิธีชำระ', 'Bank account / payment method'),
        ]),
      ],
    '40' => const [
        GlJSection([
          GlJ.text('Dr', 'บัญชีค่าใช้จ่ายในแต่ละบรรทัด', 'The expense account on each line'),
          GlJ('Dr', 'vat_input_account_id', 'ถ้ามี VAT', 'if VAT applies'),
          GlJ('  Cr', 'petty_cash_payable_account_id'),
        ]),
      ],
    '50' => const [
        GlJSection([
          GlJ.text('Dr', 'บัญชี GL ของบัญชีธนาคารปลายทาง', 'GL account of the receiving bank account'),
          GlJ.text('  Cr', 'บัญชี GL ของบัญชีธนาคารต้นทาง', 'GL account of the sending bank account'),
        ]),
      ],
    '70' => const [
        GlJSection([
          GlJ('Dr', 'expense_account_id'),
          GlJ('Dr', 'vat_input_account_id', 'ถ้ามี VAT', 'if VAT applies'),
          GlJ.text('  Cr', 'บัญชี GL ของบัญชีธนาคาร', 'GL account of the bank account'),
        ]),
      ],
    '90' => const [
        GlJSection([
          GlJ.text('Dr', 'บัญชี GL ของบัญชีธนาคาร', 'GL account of the bank account'),
          GlJ('Dr', 'wht_prepaid_account_id', 'ถ้าถูกหักภาษี', 'if tax is withheld'),
          GlJ('  Cr', 'revenue_account_id'),
        ], th: 'ดอกเบี้ยรับ', en: 'Interest income'),
        GlJSection([
          GlJ('Dr', 'expense_account_id'),
          GlJ.text('  Cr', 'บัญชี GL ของบัญชีธนาคาร', 'GL account of the bank account'),
        ], th: 'ดอกเบี้ยจ่าย', en: 'Interest expense'),
      ],
    _ => const <GlJSection>[],
  },
);

class CmTransactionGlSetupScreen extends StatelessWidget {
  const CmTransactionGlSetupScreen({super.key});

  @override
  Widget build(BuildContext context) => GlSetupScreen(spec: cmGlSetupSpec);
}
