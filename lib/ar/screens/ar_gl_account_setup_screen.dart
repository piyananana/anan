// lib/ar/screens/ar_gl_account_setup_screen.dart
// ประเภทเอกสาร AR เชื่อมต่อ GL — หน้าตาแบบเดียวกับ IM (sa_gl_setup_kit.dart, user 2026-11-26)
// ช่องบัญชีต่อ sys_doc_type ตรงกับที่ arTransactionController.postGlEntry ใช้จริง (pattern_gl_setup_fields_match_posting)
import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../sa/widgets/sa_gl_setup_kit.dart';

bool _rev(String s) => ['10', '30', '35', '50', '55'].contains(s); // ตั้งหนี้/เพิ่มหนี้/ลดหนี้ (ลดหนี้กลับทิศ)
bool _cash(String s) => ['60', '65', '80'].contains(s); // มัดจำ / คืนมัดจำ / รับชำระ
bool _payMethod(String s) => ['60', '80'].contains(s); // คืนมัดจำใช้บัญชี Cash/Bank บัญชีเดียว

const _payFbTh = 'บัญชีเงินสด / ธนาคารด้านบน';
const _payFbEn = 'The Cash / Bank account above';
const _payLvTh = 'วิธีชำระ · บัญชีธนาคาร (CM)';
const _payLvEn = 'Payment method · bank account (CM)';

GlAcct _pay(String key, String th, String en) =>
    GlAcct(key, th, en, show: _payMethod, fbTh: _payFbTh, fbEn: _payFbEn, levelsTh: _payLvTh, levelsEn: _payLvEn);

final arGlSetupSpec = GlSetupSpec(
  module: 'AR',
  guideModule: 'AR',
  baseUrl: '${AppConfig.apiAr}/ar_gl_account_setup',
  placeholderTh: 'เลือกประเภทเอกสาร AR ด้านซ้าย',
  placeholderEn: 'Select an AR document type on the left',
  noGl: (s) => s == '70', // วางบิล ไม่ลงบัญชี
  groupOf: (s) => _cash(s) ? 'CASH' : 'BILL',
  groups: const [('BILL', 'ตั้งหนี้ / เพิ่มหนี้ / ลดหนี้', 'Invoices / notes'), ('CASH', 'มัดจำ / รับชำระ', 'Deposits / receipts')],
  banner: (s, e) => _payMethod(s)
      ? (e
          ? 'Receipt account per payment line: payment method GL account → bank account GL account (CM) → the per-method account below → Cash / Bank.'
          : 'บัญชีรับเงินแต่ละบรรทัด: บัญชี GL ของวิธีชำระ → บัญชี GL ของบัญชีธนาคาร (CM) → บัญชีตามวิธีชำระด้านล่าง → เงินสด / ธนาคาร')
      : null,
  accounts: [
    GlAcct('ar_account_id', 'ลูกหนี้การค้า', 'Accounts receivable',
        show: (s) => _rev(s) || s == '80',
        fbTh: 'บัญชีของลูกค้า / กลุ่มลูกค้า (ใช้ก่อนบัญชีนี้เสมอ)',
        fbEn: 'The customer / customer group account (always checked before this one)',
        levelsTh: 'ลูกค้า · กลุ่มลูกค้า',
        levelsEn: 'Customer · customer group'),
    GlAcct('revenue_account_id', 'รายได้ขาย', 'Sales revenue',
        show: _rev,
        fbTh: 'บัญชีที่เลือกในแต่ละบรรทัดเอกสาร (ค่านี้เป็นค่าเริ่มต้นของบรรทัด)',
        fbEn: 'The account chosen on each document line (this is the line default)',
        levelsTh: 'บรรทัดเอกสาร',
        levelsEn: 'Document line'),
    GlAcct('vat_output_account_id', 'ภาษีขาย', 'Output VAT',
        show: (s) => _rev(s) || _cash(s),
        fbTh: 'บัญชีของรหัสอัตราภาษีที่เลือกในเอกสาร',
        fbEn: 'The account of the VAT rate chosen on the document',
        levelsTh: 'อัตราภาษี',
        levelsEn: 'VAT rate'),
    GlAcct('vat_pending_output_account_id', 'ภาษีขายรอตัดบัญชี', 'Deferred output VAT',
        show: (s) => _rev(s) || ['60', '80'].contains(s),
        optTh: 'ต้องตั้งเมื่อมีรายการ VAT รอตัด (ค่าบริการ / มัดจำ)',
        optEn: 'Needed only for deferred-VAT lines (services / deposits)'),
    GlAcct('discount_account_id', 'ส่วนลดจ่าย', 'Discount given',
        show: _rev, fbTh: 'ลงรายได้สุทธิหลังหักส่วนลด', fbEn: 'Revenue is posted net of discount'),
    GlAcct('advance_account_id', 'เงินมัดจำรับ', 'Advance received',
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
    _pay('credit_card_account_id', 'บัตรเครดิต', 'Credit card'),
    _pay('debit_card_account_id', 'บัตรเดบิต', 'Debit card'),
    _pay('qr_code_account_id', 'QR Code / พร้อมเพย์', 'QR code / PromptPay'),
    _pay('mobile_banking_account_id', 'Mobile / Internet Banking', 'Mobile / internet banking'),
    _pay('bill_of_exchange_account_id', 'ตั๋วแลกเงิน', 'Bill of exchange'),
    GlAcct('wht_account_id', 'ภาษีถูกหัก ณ ที่จ่าย', 'Withholding tax deducted',
        show: (s) => s == '80', optTh: 'ต้องตั้งเมื่อลูกค้าหักภาษี ณ ที่จ่าย', optEn: 'Needed only when the customer withholds tax'),
    GlAcct('fx_gain_account_id', 'กำไรจากอัตราแลกเปลี่ยน', 'FX gain',
        show: (s) => ['10', '80'].contains(s), optTh: 'ต้องตั้งเมื่ออัตราแลกเปลี่ยนต่างกัน', optEn: 'Needed only when exchange rates differ'),
    GlAcct('fx_loss_account_id', 'ขาดทุนจากอัตราแลกเปลี่ยน', 'FX loss',
        show: (s) => ['10', '80'].contains(s), optTh: 'ต้องตั้งเมื่ออัตราแลกเปลี่ยนต่างกัน', optEn: 'Needed only when exchange rates differ'),
  ],
  journal: (s) => switch (s) {
    '10' || '30' || '35' => [
        const GlJSection([
          GlJ('Dr', 'ar_account_id'),
          GlJ('Dr', 'discount_account_id', 'ถ้ามีส่วนลด', 'if a discount applies'),
          GlJ('  Cr', 'revenue_account_id', 'ต่อบรรทัด', 'per line'),
          GlJ('  Cr', 'vat_output_account_id'),
          GlJ('  Cr', 'vat_pending_output_account_id', 'บรรทัด VAT รอตัด', 'deferred-VAT lines'),
        ]),
        if (s == '10')
          const GlJSection([
            GlJ('Dr', 'fx_loss_account_id', 'ขาดทุน', 'loss'),
            GlJ('  Cr', 'fx_gain_account_id', 'กำไร', 'gain'),
          ], th: 'หักมัดจำที่อัตราแลกเปลี่ยนต่างกัน', en: 'Deposit deducted at a different exchange rate'),
      ],
    '50' || '55' => const [
        GlJSection([
          GlJ('Dr', 'revenue_account_id', 'ต่อบรรทัด', 'per line'),
          GlJ('Dr', 'vat_output_account_id'),
          GlJ('Dr', 'vat_pending_output_account_id', 'บรรทัด VAT รอตัด', 'deferred-VAT lines'),
          GlJ('  Cr', 'discount_account_id', 'ถ้ามีส่วนลด', 'if a discount applies'),
          GlJ('  Cr', 'ar_account_id'),
        ]),
      ],
    '60' => const [
        GlJSection([
          GlJ('Dr', 'cash_account_id', 'หรือบัญชีตามวิธีชำระ', 'or the per-method account'),
          GlJ('  Cr', 'advance_account_id'),
          GlJ('  Cr', 'vat_output_account_id', 'ถ้ามี VAT', 'if VAT applies'),
        ]),
      ],
    '65' => const [
        GlJSection([
          GlJ('Dr', 'advance_account_id'),
          GlJ('Dr', 'vat_output_account_id', 'กลับรายการ VAT มัดจำ', 'reverse the deposit VAT'),
          GlJ('  Cr', 'cash_account_id'),
        ]),
      ],
    '80' => const [
        GlJSection([
          GlJ('Dr', 'cash_account_id', 'หรือบัญชีตามวิธีชำระ', 'or the per-method account'),
          GlJ('Dr', 'advance_account_id', 'ตัดมัดจำ', 'deposit applied'),
          GlJ('Dr', 'wht_account_id', 'ถ้าลูกค้าหักภาษี', 'if tax is withheld'),
          GlJ('Dr', 'fx_loss_account_id', 'ขาดทุน FX', 'FX loss'),
          GlJ('  Cr', 'ar_account_id', 'บัญชีที่ใบแจ้งหนี้ลงไว้', 'the account each invoice was posted to'),
          GlJ('  Cr', 'fx_gain_account_id', 'กำไร FX', 'FX gain'),
        ]),
        GlJSection([
          GlJ('Dr', 'vat_pending_output_account_id'),
          GlJ('  Cr', 'vat_output_account_id'),
        ], th: 'รับรู้ภาษีขายรอตัด (รายการ VAT รอตัด)', en: 'Recognise deferred output VAT (deferred-VAT lines)'),
      ],
    _ => const <GlJSection>[],
  },
);

class ArGlAccountSetupScreen extends StatelessWidget {
  const ArGlAccountSetupScreen({super.key});

  @override
  Widget build(BuildContext context) => GlSetupScreen(spec: arGlSetupSpec);
}
