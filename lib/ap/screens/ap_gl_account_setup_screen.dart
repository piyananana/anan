// lib/ap/screens/ap_gl_account_setup_screen.dart
// ประเภทเอกสาร AP เชื่อมต่อ GL — หน้าตาแบบเดียวกับ IM (sa_gl_setup_kit.dart, user 2026-11-26)
// ช่องบัญชีต่อ sys_doc_type ตรงกับที่ apTransactionController.postGlEntry ใช้จริง (pattern_gl_setup_fields_match_posting)
import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../sa/widgets/sa_gl_setup_kit.dart';

bool _exp(String s) => ['10', '30', '50'].contains(s); // ตั้งหนี้/ลดหนี้/เพิ่มหนี้ (ลดหนี้กลับทิศ)
bool _cash(String s) => ['60', '65', '80'].contains(s); // จ่ายมัดจำ / รับคืนมัดจำ / จ่ายชำระ
bool _payMethod(String s) => ['60', '80'].contains(s); // รับคืนมัดจำใช้บัญชี Cash/Bank บัญชีเดียว

const _payLvTh = 'วิธีชำระ · บัญชีธนาคาร (CM)';
const _payLvEn = 'Payment method · bank account (CM)';

GlAcct _pay(String key, String th, String en) => GlAcct(key, th, en,
    show: _payMethod, fbTh: 'บัญชีเงินสด / ธนาคารด้านบน', fbEn: 'The Cash / Bank account above', levelsTh: _payLvTh, levelsEn: _payLvEn);

final apGlSetupSpec = GlSetupSpec(
  module: 'AP',
  guideModule: 'AP',
  baseUrl: '${AppConfig.apiAp}/ap_gl_account_setup',
  placeholderTh: 'เลือกประเภทเอกสาร AP ด้านซ้าย',
  placeholderEn: 'Select an AP document type on the left',
  // 70 แจ้งชำระไม่ลงบัญชี, 35/55 ยังไม่รองรับการลงบัญชี
  noGl: (s) => ['70', '35', '55'].contains(s),
  groupOf: (s) => _cash(s) ? 'CASH' : 'BILL',
  groups: const [('BILL', 'ตั้งหนี้ / ลดหนี้ / เพิ่มหนี้', 'Invoices / notes'), ('CASH', 'มัดจำ / จ่ายชำระ', 'Deposits / payments')],
  banner: (s, e) => _payMethod(s)
      ? (e
          ? 'Payment account per payment line: payment method GL account → bank account GL account (CM) → the per-method account below → Cash / Bank.'
          : 'บัญชีจ่ายเงินแต่ละบรรทัด: บัญชี GL ของวิธีชำระ → บัญชี GL ของบัญชีธนาคาร (CM) → บัญชีตามวิธีชำระด้านล่าง → เงินสด / ธนาคาร')
      : null,
  accounts: [
    GlAcct('ap_account_id', 'เจ้าหนี้การค้า', 'Accounts payable',
        show: (s) => _exp(s) || s == '80',
        fbTh: 'บัญชีของผู้ขาย / กลุ่มผู้ขาย (ใช้ก่อนบัญชีนี้เสมอ)',
        fbEn: 'The vendor / vendor group account (always checked before this one)',
        levelsTh: 'ผู้ขาย · กลุ่มผู้ขาย',
        levelsEn: 'Vendor · vendor group'),
    GlAcct('expense_account_id', 'ค่าใช้จ่าย / สินค้า', 'Expense / goods',
        show: _exp,
        fbTh: 'บัญชีที่เลือกในแต่ละบรรทัดเอกสาร (ค่านี้เป็นค่าเริ่มต้นของบรรทัด)',
        fbEn: 'The account chosen on each document line (this is the line default)',
        levelsTh: 'บรรทัดเอกสาร',
        levelsEn: 'Document line'),
    GlAcct('vat_input_account_id', 'ภาษีซื้อ', 'Input VAT',
        show: (s) => _exp(s) || _cash(s), optTh: 'ต้องตั้งเมื่อเอกสารมี VAT', optEn: 'Needed when documents carry VAT'),
    GlAcct('vat_pending_input_account_id', 'ภาษีซื้อรอตัดบัญชี', 'Deferred input VAT',
        show: (s) => _exp(s) || ['60', '80'].contains(s),
        optTh: 'ต้องตั้งเมื่อมีรายการ VAT รอตัด (ค่าบริการ / มัดจำ)',
        optEn: 'Needed only for deferred-VAT lines (services / deposits)'),
    GlAcct('discount_account_id', 'ส่วนลดรับ', 'Discount received',
        show: _exp, fbTh: 'ลงค่าใช้จ่ายสุทธิหลังหักส่วนลด', fbEn: 'Expense is posted net of discount'),
    GlAcct('advance_account_id', 'เงินมัดจำจ่าย', 'Advance paid',
        show: _cash,
        requiredFor: (s) => ['60', '65'].contains(s),
        optTh: 'ใช้บัญชีที่ใบมัดจำลงไว้ — ต้องตั้งเมื่อใบมัดจำไม่ได้เก็บบัญชีไว้',
        optEn: 'Uses the account the deposit was posted to — needed only when the deposit has none'),
    GlAcct('cash_account_id', 'เงินสด / ธนาคาร', 'Cash / bank',
        show: _cash,
        requiredFor: (s) => s == '65',
        fbTh: 'บัญชี GL ของวิธีชำระ / บัญชีธนาคาร (ใช้ก่อนบัญชีนี้)',
        fbEn: 'Payment method / bank account GL account (checked first)',
        levelsTh: _payLvTh,
        levelsEn: _payLvEn),
    _pay('check_account_id', 'เช็ค', 'Cheque'),
    _pay('transfer_account_id', 'โอนเงิน', 'Transfer'),
    GlAcct('wht_payable_account_id', 'ภาษีหัก ณ ที่จ่ายค้างจ่าย', 'Withholding tax payable',
        show: (s) => s == '80', optTh: 'ต้องตั้งเมื่อหักภาษี ณ ที่จ่าย', optEn: 'Needed only when tax is withheld'),
    GlAcct('fx_gain_account_id', 'กำไรจากอัตราแลกเปลี่ยน', 'FX gain',
        show: (s) => ['10', '80'].contains(s), optTh: 'ต้องตั้งเมื่ออัตราแลกเปลี่ยนต่างกัน', optEn: 'Needed only when exchange rates differ'),
    GlAcct('fx_loss_account_id', 'ขาดทุนจากอัตราแลกเปลี่ยน', 'FX loss',
        show: (s) => ['10', '80'].contains(s), optTh: 'ต้องตั้งเมื่ออัตราแลกเปลี่ยนต่างกัน', optEn: 'Needed only when exchange rates differ'),
  ],
  journal: (s) => switch (s) {
    '10' || '50' => [
        const GlJSection([
          GlJ('Dr', 'expense_account_id', 'ต่อบรรทัด', 'per line'),
          GlJ('Dr', 'vat_input_account_id'),
          GlJ('Dr', 'vat_pending_input_account_id', 'บรรทัด VAT รอตัด', 'deferred-VAT lines'),
          GlJ('  Cr', 'discount_account_id', 'ถ้ามีส่วนลด', 'if a discount applies'),
          GlJ('  Cr', 'ap_account_id'),
        ]),
        if (s == '10')
          const GlJSection([
            GlJ('Dr', 'fx_loss_account_id', 'ขาดทุน', 'loss'),
            GlJ('  Cr', 'fx_gain_account_id', 'กำไร', 'gain'),
          ], th: 'หักมัดจำที่อัตราแลกเปลี่ยนต่างกัน', en: 'Deposit deducted at a different exchange rate'),
      ],
    '30' => const [
        GlJSection([
          GlJ('Dr', 'ap_account_id'),
          GlJ('Dr', 'discount_account_id', 'ถ้ามีส่วนลด', 'if a discount applies'),
          GlJ('  Cr', 'expense_account_id', 'ต่อบรรทัด', 'per line'),
          GlJ('  Cr', 'vat_input_account_id'),
          GlJ('  Cr', 'vat_pending_input_account_id', 'บรรทัด VAT รอตัด', 'deferred-VAT lines'),
        ]),
      ],
    '60' => const [
        GlJSection([
          GlJ('Dr', 'advance_account_id'),
          GlJ('Dr', 'vat_input_account_id', 'ถ้ามี VAT', 'if VAT applies'),
          GlJ('  Cr', 'cash_account_id', 'หรือบัญชีตามวิธีชำระ', 'or the per-method account'),
        ]),
      ],
    '65' => const [
        GlJSection([
          GlJ('Dr', 'cash_account_id'),
          GlJ('  Cr', 'advance_account_id'),
          GlJ('  Cr', 'vat_input_account_id', 'กลับรายการ VAT มัดจำ', 'reverse the deposit VAT'),
        ]),
      ],
    '80' => const [
        GlJSection([
          GlJ('Dr', 'ap_account_id', 'บัญชีที่ใบตั้งหนี้ลงไว้', 'the account each invoice was posted to'),
          GlJ('Dr', 'fx_loss_account_id', 'ขาดทุน FX', 'FX loss'),
          GlJ('  Cr', 'cash_account_id', 'หรือบัญชีตามวิธีชำระ', 'or the per-method account'),
          GlJ('  Cr', 'advance_account_id', 'ตัดมัดจำ', 'deposit applied'),
          GlJ('  Cr', 'wht_payable_account_id', 'ถ้าหักภาษี ณ ที่จ่าย', 'if tax is withheld'),
          GlJ('  Cr', 'fx_gain_account_id', 'กำไร FX', 'FX gain'),
        ]),
        GlJSection([
          GlJ('Dr', 'vat_input_account_id'),
          GlJ('  Cr', 'vat_pending_input_account_id'),
        ], th: 'รับรู้ภาษีซื้อรอตัด (รายการ VAT รอตัด)', en: 'Recognise deferred input VAT (deferred-VAT lines)'),
      ],
    _ => const <GlJSection>[],
  },
);

class ApGlAccountSetupScreen extends StatelessWidget {
  const ApGlAccountSetupScreen({super.key});

  @override
  Widget build(BuildContext context) => GlSetupScreen(spec: apGlSetupSpec);
}
