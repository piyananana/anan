// lib/sa/widgets/sa_sys_doc_type_guide.dart
// ตารางอธิบายประเภทเอกสารระบบ (sys_doc_type) — ใช้ในหน้าจอตั้งค่ารหัสบัญชีของทุกโมดูล (AR/AP/IM/CM)
// ชื่อประเภทมาจากแผนที่ ??SysDocType ใน sa_anan_module.dart (มาตรฐานคงที่) ส่วนคำอธิบายการใช้และผลกระทบ
// ต้องตรงกับ logic การ Post จริงใน backend — แก้ข้อความที่นี่ทุกครั้งที่พฤติกรรมของ sys_doc_type เปลี่ยน
import 'package:flutter/material.dart';
import '../models/sa_anan_module.dart';

class SysDocTypeGuideEntry {
  final String code;
  final String usageTh, usageEn;       // ความหมาย / ใช้เมื่อไร
  final String effectTh, effectEn;     // ผลในโมดูลเอง (ยอดคงเหลือ/สต็อก/การบันทึกบัญชี)
  final String relatedTh, relatedEn;   // ผลต่อโมดูลที่เกี่ยวข้อง

  const SysDocTypeGuideEntry(this.code,
      {required this.usageTh, required this.usageEn,
      required this.effectTh, required this.effectEn,
      this.relatedTh = '-', this.relatedEn = '-'});
}

const List<SysDocTypeGuideEntry> _arGuide = [
  SysDocTypeGuideEntry('10',
      usageTh: 'ออกใบแจ้งหนี้/ใบกำกับภาษีขายเงินเชื่อ (สินค้าที่ไม่ผ่านสต็อก หรือค่าบริการ)',
      usageEn: 'Issue a credit sales invoice / tax invoice (non-stock goods or services)',
      effectTh: 'เพิ่มยอดลูกหนี้ค้างรับ\nGL: Dr ลูกหนี้ / Cr รายได้ + ภาษีขาย (บรรทัด VAT รอตัด → ภาษีขายรอตัดบัญชี), Dr ส่วนลด',
      effectEn: 'Increases customer balance\nGL: Dr AR / Cr Revenue + Output VAT (deferred-VAT lines → Deferred Output VAT), Dr Discount',
      relatedTh: 'VT: เข้ารายงานภาษีขาย (ยกเว้น VAT รอตัด)\nวงเงินเครดิต: เกินวงเงินต้องอนุมัติก่อน Post\nIM: ใบแจ้งหนี้ที่ IM \'31\'/\'32\' สร้างอัตโนมัติเป็นประเภทนี้',
      relatedEn: 'VT: in the output VAT report (except deferred VAT)\nCredit limit: over-limit needs approval before posting\nIM: invoices auto-created by IM \'31\'/\'32\' use this type'),
  SysDocTypeGuideEntry('30',
      usageTh: 'เพิ่มหนี้ลูกค้าแบบมีรายการ (ราคาต่ำไป / ค่าใช้จ่ายเพิ่ม)',
      usageEn: 'Debit note with its own lines (under-charged price / extra charges)',
      effectTh: 'เพิ่มยอดลูกหนี้ค้างรับ (มียอดค้างของตัวเอง)\nGL: เหมือนตั้งหนี้ — Dr ลูกหนี้ / Cr รายได้ + ภาษีขาย',
      effectEn: 'Increases customer balance (own open balance)\nGL: same as billing — Dr AR / Cr Revenue + Output VAT',
      relatedTh: 'VT: ภาษีขายเพิ่ม\nวงเงินเครดิต: ตรวจวงเงิน\nIM: \'45\' สร้างเอกสารประเภทนี้อัตโนมัติ',
      relatedEn: 'VT: adds output VAT\nCredit limit: checked\nIM: \'45\' auto-creates this type'),
  SysDocTypeGuideEntry('35',
      usageTh: 'เพิ่มหนี้โดยอ้างอิงใบแจ้งหนี้เดิม (ไม่ต้องคีย์รายการ)',
      usageEn: 'Debit note referencing an existing invoice (no item lines needed)',
      effectTh: 'ไม่มียอดค้างของตัวเอง — ไปเพิ่มยอดค้างของใบแจ้งหนี้ที่อ้างอิง\nGL: Dr ลูกหนี้ / Cr รายได้ (บัญชี default) + ภาษีขาย',
      effectEn: 'No open balance of its own — adds to the referenced invoice\'s balance\nGL: Dr AR / Cr Revenue (default account) + Output VAT',
      relatedTh: 'VT: ภาษีขายเพิ่ม\nวงเงินเครดิต: ตรวจวงเงิน',
      relatedEn: 'VT: adds output VAT\nCredit limit: checked'),
  SysDocTypeGuideEntry('50',
      usageTh: 'ลดหนี้ลูกค้าแบบมีรายการ (รับคืน ส่วนลดภายหลัง ราคาสูงไป)',
      usageEn: 'Credit note with its own lines (returns, later discounts, over-charged price)',
      effectTh: 'ลดยอดลูกหนี้ (ใช้ตัดกับใบแจ้งหนี้ตอนรับชำระ)\nGL: กลับทิศตั้งหนี้ — Dr รายได้ + ภาษีขาย / Cr ลูกหนี้',
      effectEn: 'Reduces customer balance (offset against invoices at receipt)\nGL: reverse of billing — Dr Revenue + Output VAT / Cr AR',
      relatedTh: 'VT: ภาษีขายติดลบ\nIM: \'35\'/\'40\' สร้างเอกสารประเภทนี้อัตโนมัติ',
      relatedEn: 'VT: negative output VAT\nIM: \'35\'/\'40\' auto-create this type'),
  SysDocTypeGuideEntry('55',
      usageTh: 'ลดหนี้โดยอ้างอิงใบแจ้งหนี้เดิม (ไม่ต้องคีย์รายการ)',
      usageEn: 'Credit note referencing an existing invoice (no item lines needed)',
      effectTh: 'ไม่มียอดค้างของตัวเอง — ไปลดยอดค้างของใบแจ้งหนี้ที่อ้างอิง\nGL: Dr รายได้ + ภาษีขาย / Cr ลูกหนี้',
      effectEn: 'No open balance of its own — reduces the referenced invoice\'s balance\nGL: Dr Revenue + Output VAT / Cr AR',
      relatedTh: 'VT: ภาษีขายติดลบ',
      relatedEn: 'VT: negative output VAT'),
  SysDocTypeGuideEntry('60',
      usageTh: 'รับเงินมัดจำ / เงินรับล่วงหน้าจากลูกค้า',
      usageEn: 'Receive a customer deposit / advance',
      effectTh: 'เกิดยอดมัดจำคงเหลือ ใช้ตัดตอนรับชำระ (80)\nGL: Dr เงินสด/ธนาคารตามช่องทาง / Cr เงินรับล่วงหน้า + ภาษีขาย (ถ้ามี)',
      effectEn: 'Creates an open deposit, offset later at receipt (80)\nGL: Dr Cash/Bank by payment method / Cr Customer Advance + Output VAT (if any)',
      relatedTh: 'VT: ภาษีขายของเงินมัดจำ (ถ้ามี VAT)',
      relatedEn: 'VT: output VAT on the deposit (if VAT applies)'),
  SysDocTypeGuideEntry('65',
      usageTh: 'คืนเงินมัดจำให้ลูกค้า',
      usageEn: 'Refund a customer deposit',
      effectTh: 'ลดยอดมัดจำคงเหลือ\nGL: Dr เงินรับล่วงหน้า (+ กลับภาษีขาย) / Cr เงินสด/ธนาคาร',
      effectEn: 'Reduces the open deposit\nGL: Dr Customer Advance (+ reverse Output VAT) / Cr Cash/Bank',
      relatedTh: 'VT: กลับรายการภาษีขายของมัดจำ',
      relatedEn: 'VT: reverses the deposit\'s output VAT'),
  SysDocTypeGuideEntry('70',
      usageTh: 'ใบวางบิล — รวมใบแจ้งหนี้ค้างรับของลูกค้าเพื่อนัดชำระ (สกุลเงินเดียวต่อลูกค้า)',
      usageEn: 'Bill collection — groups a customer\'s open invoices for collection (one currency per customer)',
      effectTh: 'ไม่ลงบัญชี GL ไม่เปลี่ยนยอดลูกหนี้\nเมื่อรับชำระ (80) อ้างเลขที่ใบวางบิล ยอดวางบิลจะถูกเคลียร์',
      effectEn: 'No GL posting, customer balance unchanged\nCleared when a receipt (80) references the bill collection number',
      relatedTh: '-',
      relatedEn: '-'),
  SysDocTypeGuideEntry('80',
      usageTh: 'รับชำระหนี้จากลูกค้า ตัดใบแจ้งหนี้/เพิ่มหนี้ ใช้ลดหนี้และมัดจำหักได้',
      usageEn: 'Receive payment, settling invoices/debit notes; credit notes and deposits can be offset',
      effectTh: 'ลดยอดลูกหนี้ค้างรับของใบที่ตัด\nGL: Dr เงินสด/ธนาคารตามช่องทาง + มัดจำที่ตัด / Cr ลูกหนี้; กำไร/ขาดทุนอัตราแลกเปลี่ยน; รับรู้ VAT รอตัด: Dr ภาษีขายรอตัด / Cr ภาษีขาย ตามสัดส่วนที่รับ',
      effectEn: 'Reduces the settled documents\' balances\nGL: Dr Cash/Bank by method + offset deposits / Cr AR; FX gain/loss; deferred VAT: Dr Deferred Output VAT / Cr Output VAT pro rata to the amount received',
      relatedTh: 'CM: สร้างรายรับจาก AR (CM \'15\') รอเคลียร์/กระทบยอดธนาคาร\nVT: VAT รอตัดที่รับรู้เข้ารายงานภาษีขาย',
      relatedEn: 'CM: creates a Receipt from AR (CM \'15\') for clearing/bank reconciliation\nVT: recognized deferred VAT goes to the output VAT report'),
];

const List<SysDocTypeGuideEntry> _apGuide = [
  SysDocTypeGuideEntry('10',
      usageTh: 'บันทึกใบแจ้งหนี้/ใบกำกับภาษีซื้อจากผู้ขาย (ค่าใช้จ่าย บริการ สินค้าที่ไม่ผ่านสต็อก)',
      usageEn: 'Record a vendor invoice / purchase tax invoice (expenses, services, non-stock goods)',
      effectTh: 'เพิ่มยอดเจ้าหนี้ค้างจ่าย\nGL: Dr ค่าใช้จ่าย + ภาษีซื้อ (บรรทัด VAT รอตัด → ภาษีซื้อรอตัดบัญชี) / Cr เจ้าหนี้, Cr ส่วนลด',
      effectEn: 'Increases vendor balance\nGL: Dr Expense + Input VAT (deferred-VAT lines → Deferred Input VAT) / Cr AP, Cr Discount',
      relatedTh: 'VT: เข้ารายงานภาษีซื้อ (ยกเว้น VAT รอตัด)\nIM: ใบตั้งหนี้ที่ IM \'11\'/\'12\' สร้างอัตโนมัติเป็นประเภทนี้\nการอนุมัติ: ตามการตั้งค่าอนุมัติเอกสาร',
      relatedEn: 'VT: in the input VAT report (except deferred VAT)\nIM: invoices auto-created by IM \'11\'/\'12\' use this type\nApproval: per document approval settings'),
  SysDocTypeGuideEntry('30',
      usageTh: 'ใบลดหนี้จากผู้ขาย (คืนของ ส่วนลดภายหลัง ราคาสูงไป)',
      usageEn: 'Credit note from vendor (returns, later discounts, over-charged price)',
      effectTh: 'ลดยอดเจ้าหนี้ (ใช้ตัดกับใบแจ้งหนี้ตอนจ่ายชำระ)\nGL: กลับทิศตั้งหนี้ — Dr เจ้าหนี้ / Cr ค่าใช้จ่าย + ภาษีซื้อ',
      effectEn: 'Reduces vendor balance (offset against invoices at payment)\nGL: reverse of billing — Dr AP / Cr Expense + Input VAT',
      relatedTh: 'VT: ภาษีซื้อติดลบ\nIM: \'15\'/\'20\' สร้างเอกสารประเภทนี้อัตโนมัติ',
      relatedEn: 'VT: negative input VAT\nIM: \'15\'/\'20\' auto-create this type'),
  SysDocTypeGuideEntry('35',
      usageTh: 'ลดหนี้อ้างอิงใบแจ้งหนี้เดิม — ยังไม่รองรับการ Post',
      usageEn: 'Credit note referencing an invoice — posting not supported yet',
      effectTh: 'ยังไม่รองรับการบันทึกบัญชี (ใช้ \'30\' แทน)',
      effectEn: 'Posting not supported (use \'30\' instead)'),
  SysDocTypeGuideEntry('50',
      usageTh: 'ใบเพิ่มหนี้จากผู้ขาย (ราคาต่ำไป / ค่าใช้จ่ายเพิ่ม)',
      usageEn: 'Debit note from vendor (under-charged price / extra charges)',
      effectTh: 'เพิ่มยอดเจ้าหนี้ค้างจ่าย\nGL: เหมือนตั้งหนี้ — Dr ค่าใช้จ่าย + ภาษีซื้อ / Cr เจ้าหนี้',
      effectEn: 'Increases vendor balance\nGL: same as billing — Dr Expense + Input VAT / Cr AP',
      relatedTh: 'VT: ภาษีซื้อเพิ่ม\nIM: \'25\' สร้างเอกสารประเภทนี้อัตโนมัติ',
      relatedEn: 'VT: adds input VAT\nIM: \'25\' auto-creates this type'),
  SysDocTypeGuideEntry('55',
      usageTh: 'เพิ่มหนี้อ้างอิงใบแจ้งหนี้เดิม — ยังไม่รองรับการ Post',
      usageEn: 'Debit note referencing an invoice — posting not supported yet',
      effectTh: 'ยังไม่รองรับการบันทึกบัญชี (ใช้ \'50\' แทน)',
      effectEn: 'Posting not supported (use \'50\' instead)'),
  SysDocTypeGuideEntry('60',
      usageTh: 'จ่ายเงินมัดจำ / เงินจ่ายล่วงหน้าให้ผู้ขาย',
      usageEn: 'Pay a vendor deposit / advance',
      effectTh: 'เกิดยอดมัดจำคงเหลือ ใช้ตัดตอนจ่ายชำระ (80)\nGL: Dr เงินจ่ายล่วงหน้า + ภาษีซื้อ (ถ้ามี) / Cr เงินสด/ธนาคารตามช่องทาง',
      effectEn: 'Creates an open deposit, offset later at payment (80)\nGL: Dr Vendor Advance + Input VAT (if any) / Cr Cash/Bank by payment method',
      relatedTh: 'VT: ภาษีซื้อของเงินมัดจำ (ถ้ามี VAT)',
      relatedEn: 'VT: input VAT on the deposit (if VAT applies)'),
  SysDocTypeGuideEntry('65',
      usageTh: 'รับคืนเงินมัดจำจากผู้ขาย',
      usageEn: 'Receive a deposit refund from vendor',
      effectTh: 'ลดยอดมัดจำคงเหลือ\nGL: Dr เงินสด/ธนาคาร / Cr เงินจ่ายล่วงหน้า (+ กลับภาษีซื้อ)',
      effectEn: 'Reduces the open deposit\nGL: Dr Cash/Bank / Cr Vendor Advance (+ reverse Input VAT)',
      relatedTh: 'VT: กลับรายการภาษีซื้อของมัดจำ',
      relatedEn: 'VT: reverses the deposit\'s input VAT'),
  SysDocTypeGuideEntry('70',
      usageTh: 'ใบแจ้งชำระ (Remittance Advice) — แจ้งผู้ขายว่าจะจ่ายใบแจ้งหนี้ใดบ้าง',
      usageEn: 'Remittance advice — tells the vendor which invoices will be paid',
      effectTh: 'ไม่ลงบัญชี GL ไม่เปลี่ยนยอดเจ้าหนี้',
      effectEn: 'No GL posting, vendor balance unchanged'),
  SysDocTypeGuideEntry('80',
      usageTh: 'จ่ายชำระหนี้ผู้ขาย ตัดใบแจ้งหนี้/เพิ่มหนี้ ใช้ลดหนี้และมัดจำหักได้ หักภาษี ณ ที่จ่ายได้',
      usageEn: 'Pay a vendor, settling invoices/debit notes; credit notes and deposits can be offset; WHT can be deducted',
      effectTh: 'ลดยอดเจ้าหนี้ค้างจ่ายของใบที่ตัด\nGL: Dr เจ้าหนี้ / Cr เงินสด/ธนาคารตามช่องทาง + มัดจำที่ตัด + ภาษีหัก ณ ที่จ่ายค้างจ่าย; กำไร/ขาดทุนอัตราแลกเปลี่ยน; รับรู้ VAT รอตัด: Dr ภาษีซื้อ / Cr ภาษีซื้อรอตัด ตามสัดส่วนที่จ่าย',
      effectEn: 'Reduces the settled documents\' balances\nGL: Dr AP / Cr Cash/Bank by method + offset deposits + WHT payable; FX gain/loss; deferred VAT: Dr Input VAT / Cr Deferred Input VAT pro rata to the amount paid',
      relatedTh: 'CM: สร้างรายจ่ายจาก AP (CM \'25\') รอเคลียร์/กระทบยอดธนาคาร\nVT: VAT รอตัดที่รับรู้เข้ารายงานภาษีซื้อ\nจ่ายชำระแบบกลุ่ม (Bulk Payment): ใช้บัญชีของรหัสเอกสารประเภทนี้',
      relatedEn: 'CM: creates a Payment from AP (CM \'25\') for clearing/bank reconciliation\nVT: recognized deferred VAT goes to the input VAT report\nBulk payment: uses this type\'s document code accounts'),
];

const List<SysDocTypeGuideEntry> _imGuide = [
  SysDocTypeGuideEntry('10',
      usageTh: 'รับสินค้าเข้าคลังก่อนได้ใบแจ้งหนี้ (ตั้งหนี้เองภายหลังใน AP) — อ้างอิงใบสั่งซื้อได้',
      usageEn: 'Receive goods before the invoice (bill manually in AP later) — can reference a PO',
      effectTh: 'สต็อก: เพิ่มจำนวนและมูลค่า\nGL: Dr สินค้าคงคลัง / Cr บัญชีพักรอใบกำกับ (GR/IR) (+ ผลต่างต้นทุนมาตรฐาน) — Post ทุกบรรทัด บรรทัด Periodic ลง Dr บัญชีซื้อสินค้าแทน',
      effectEn: 'Stock: increases qty and value\nGL: Dr Inventory / Cr GR/IR clearing (+ standard-cost variance) — posts every line; Periodic lines debit Purchases instead',
      relatedTh: 'PO: เพิ่มจำนวนรับแล้วของใบสั่งซื้อ\nAP: ไม่สร้างใบตั้งหนี้ — ต้องตั้งหนี้เองและล้าง GR/IR',
      relatedEn: 'PO: updates received qty\nAP: no invoice created — bill manually and clear GR/IR'),
  SysDocTypeGuideEntry('11',
      usageTh: 'รับสินค้าพร้อมใบแจ้งหนี้ — รับของและตั้งหนี้ในครั้งเดียว',
      usageEn: 'Goods receipt with invoice — receive and bill in one step',
      effectTh: 'สต็อก: เพิ่มจำนวนและมูลค่า\nGL: IM ไม่ลงบัญชีเอง — ลงผ่านใบตั้งหนี้ AP (Dr สินค้าคงคลัง + ภาษีซื้อ (+ ผลต่าง) / Cr เจ้าหนี้)',
      effectEn: 'Stock: increases qty and value\nGL: IM does not post itself — posted via the AP invoice (Dr Inventory + Input VAT (+ variance) / Cr AP)',
      relatedTh: 'AP: สร้างและ Post ใบตั้งหนี้ (AP \'10\') อัตโนมัติ ใช้ประเภทเอกสาร GL ของการตั้งค่าบัญชี AP\nPO: เพิ่มจำนวนรับแล้ว\nVT: ภาษีซื้อ',
      relatedEn: 'AP: auto-creates and posts an AP invoice (AP \'10\'), using the AP setup\'s GL document type\nPO: updates received qty\nVT: input VAT'),
  SysDocTypeGuideEntry('12',
      usageTh: 'รับสินค้ารอใบแจ้งหนี้ — รับของก่อน ค่อย Post AP/GL เมื่อได้ใบกำกับ',
      usageEn: 'Goods receipt pending invoice — receive now, post AP/GL when the invoice arrives',
      effectTh: 'ขั้นที่ 1 "Post IM": เพิ่มสต็อก ยังไม่ลงบัญชี (สถานะ Received)\nขั้นที่ 2 "Post AP/GL": ปรับต้นทุนตามใบกำกับแล้วลงบัญชีผ่านใบตั้งหนี้ AP',
      effectEn: 'Step 1 "Post IM": adds stock, no GL yet (status Received)\nStep 2 "Post AP/GL": uses the billed cost and posts via the AP invoice',
      relatedTh: 'AP: สร้างใบตั้งหนี้ (AP \'10\') ตอนขั้นที่ 2\nPO: เพิ่มจำนวนรับแล้ว\nVT: ภาษีซื้อตอนขั้นที่ 2',
      relatedEn: 'AP: creates an AP invoice (AP \'10\') at step 2\nPO: updates received qty\nVT: input VAT at step 2'),
  SysDocTypeGuideEntry('13',
      usageTh: 'รับสินค้าฝากขาย (กรรมสิทธิ์ยังเป็นของผู้ฝาก) — สินค้าต้องคิดต้นทุนแบบ FIFO/Specific',
      usageEn: 'Consignment receipt (consignor keeps ownership) — items must use FIFO/Specific costing',
      effectTh: 'สต็อก: เพิ่มจำนวนและมูลค่า\nGL: Dr สินค้าคงคลัง / Cr เจ้าหนี้ฝากขาย',
      effectEn: 'Stock: increases qty and value\nGL: Dr Inventory / Cr Consignment Payable',
      relatedTh: 'AP: ไม่สร้างใบตั้งหนี้ — ตั้งหนี้จริงตอน Consignment Settlement ตามยอดขาย',
      relatedEn: 'AP: no invoice — the real liability is billed at Consignment Settlement based on sales'),
  SysDocTypeGuideEntry('15',
      usageTh: 'คืนสินค้าให้ผู้ขาย — ต้องอ้างอิงเอกสารรับสินค้าเดิม (คืนได้ไม่เกินจำนวนที่รับ)',
      usageEn: 'Return to supplier — must reference the original receipt (up to the received qty)',
      effectTh: 'สต็อก: ลดจำนวนและมูลค่า\nGL: ลงผ่านใบลดหนี้ AP (Dr เจ้าหนี้ / Cr สินค้าคงคลัง + ภาษีซื้อ (+ ผลต่าง))',
      effectEn: 'Stock: reduces qty and value\nGL: posted via the AP credit note (Dr AP / Cr Inventory + Input VAT (+ variance))',
      relatedTh: 'AP: สร้างใบลดหนี้ (AP \'30\') อัตโนมัติ\nVT: ภาษีซื้อติดลบ',
      relatedEn: 'AP: auto-creates a credit note (AP \'30\')\nVT: negative input VAT'),
  SysDocTypeGuideEntry('20',
      usageTh: 'ลดหนี้เจ้าหนี้พร้อมตัดสต็อก (ไม่ต้องอ้างอิงเอกสารเดิม) — ต้องระบุราคา',
      usageEn: 'Vendor credit note with stock out (no reference needed) — price required',
      effectTh: 'สต็อก: ลดจำนวนและมูลค่า\nGL: ลงผ่านใบลดหนี้ AP',
      effectEn: 'Stock: reduces qty and value\nGL: posted via the AP credit note',
      relatedTh: 'AP: สร้างใบลดหนี้ (AP \'30\') อัตโนมัติ\nVT: ภาษีซื้อติดลบ',
      relatedEn: 'AP: auto-creates a credit note (AP \'30\')\nVT: negative input VAT'),
  SysDocTypeGuideEntry('25',
      usageTh: 'เพิ่มหนี้เจ้าหนี้พร้อมรับสต็อกเพิ่ม — ต้องระบุราคา',
      usageEn: 'Vendor debit note with stock in — price required',
      effectTh: 'สต็อก: เพิ่มจำนวนและมูลค่า\nGL: ลงผ่านใบเพิ่มหนี้ AP (Dr สินค้าคงคลัง + ภาษีซื้อ / Cr เจ้าหนี้)',
      effectEn: 'Stock: increases qty and value\nGL: posted via the AP debit note (Dr Inventory + Input VAT / Cr AP)',
      relatedTh: 'AP: สร้างใบเพิ่มหนี้ (AP \'50\') อัตโนมัติ\nVT: ภาษีซื้อเพิ่ม',
      relatedEn: 'AP: auto-creates a debit note (AP \'50\')\nVT: adds input VAT'),
  SysDocTypeGuideEntry('30',
      usageTh: 'ส่งสินค้าให้ลูกค้า (ตั้งหนี้เองภายหลังใน AR) — อ้างอิงใบสั่งขายได้',
      usageEn: 'Deliver goods (bill manually in AR later) — can reference an SO',
      effectTh: 'สต็อก: ลดจำนวนและมูลค่า\nGL: Dr ต้นทุนขาย / Cr สินค้าคงคลัง (บรรทัด Periodic ไม่ลงบัญชีตอน Post)',
      effectEn: 'Stock: reduces qty and value\nGL: Dr COGS / Cr Inventory (Periodic lines: no posting at Post)',
      relatedTh: 'SO: เพิ่มจำนวนส่งแล้วของใบสั่งขาย\nAR: ไม่สร้างใบแจ้งหนี้\nวงเงินเครดิต: ตรวจวงเงิน (ไม่นับเป็นยอดหนี้)',
      relatedEn: 'SO: updates delivered qty\nAR: no invoice created\nCredit limit: checked (not counted as exposure)'),
  SysDocTypeGuideEntry('31',
      usageTh: 'ส่งสินค้าพร้อมใบแจ้งหนี้ — ส่งของและตั้งหนี้ในครั้งเดียว',
      usageEn: 'Delivery with invoice — deliver and bill in one step',
      effectTh: 'สต็อก: ลดจำนวนและมูลค่า\nGL (IM): Dr ต้นทุนขาย / Cr สินค้าคงคลัง',
      effectEn: 'Stock: reduces qty and value\nGL (IM): Dr COGS / Cr Inventory',
      relatedTh: 'AR: สร้างและ Post ใบแจ้งหนี้ (AR \'10\') อัตโนมัติ (Dr ลูกหนี้ / Cr รายได้ + ภาษีขาย)\nSO: เพิ่มจำนวนส่งแล้ว\nVT: ภาษีขาย\nวงเงินเครดิต: ตรวจวงเงิน',
      relatedEn: 'AR: auto-creates and posts an AR invoice (AR \'10\') (Dr AR / Cr Revenue + Output VAT)\nSO: updates delivered qty\nVT: output VAT\nCredit limit: checked'),
  SysDocTypeGuideEntry('32',
      usageTh: 'ส่งสินค้ารอใบแจ้งหนี้ — ส่งของก่อน ค่อย Post AR/GL เมื่อยืนยันราคา',
      usageEn: 'Delivery pending invoice — deliver now, post AR/GL once the price is confirmed',
      effectTh: 'ขั้นที่ 1 "Post IM": ลดสต็อก + ลงต้นทุนขายทันที\nขั้นที่ 2 "Post AR/GL": ออกใบแจ้งหนี้ (ปรับราคา/อัตราแลกเปลี่ยนได้ สกุลเงินคงเดิม)',
      effectEn: 'Step 1 "Post IM": reduces stock + posts COGS immediately\nStep 2 "Post AR/GL": issues the invoice (price/rate may change, currency stays)',
      relatedTh: 'AR: สร้างใบแจ้งหนี้ (AR \'10\') ตอนขั้นที่ 2\nSO: เพิ่มจำนวนส่งแล้ว\nVT: ภาษีขายตอนขั้นที่ 2',
      relatedEn: 'AR: creates an AR invoice (AR \'10\') at step 2\nSO: updates delivered qty\nVT: output VAT at step 2'),
  SysDocTypeGuideEntry('35',
      usageTh: 'รับคืนสินค้าจากลูกค้า — ต้องอ้างอิงใบส่งสินค้าเดิม (ราคาจากเอกสารเดิม)',
      usageEn: 'Return from customer — must reference the original delivery (price from it)',
      effectTh: 'สต็อก: เพิ่มจำนวนและมูลค่า\nGL (IM): Dr สินค้าคงคลัง / Cr ต้นทุนขาย',
      effectEn: 'Stock: increases qty and value\nGL (IM): Dr Inventory / Cr COGS',
      relatedTh: 'AR: สร้างใบลดหนี้ (AR \'50\') อัตโนมัติ\nVT: ภาษีขายติดลบ',
      relatedEn: 'AR: auto-creates a credit note (AR \'50\')\nVT: negative output VAT'),
  SysDocTypeGuideEntry('40',
      usageTh: 'ลดหนี้ลูกหนี้พร้อมรับสต็อกคืน (ไม่ต้องอ้างอิง) — ต้องระบุราคา',
      usageEn: 'Customer credit note with stock in (no reference) — price required',
      effectTh: 'สต็อก: เพิ่มจำนวนและมูลค่า\nGL (IM): Dr สินค้าคงคลัง / Cr ต้นทุนขาย',
      effectEn: 'Stock: increases qty and value\nGL (IM): Dr Inventory / Cr COGS',
      relatedTh: 'AR: สร้างใบลดหนี้ (AR \'50\') อัตโนมัติ\nVT: ภาษีขายติดลบ',
      relatedEn: 'AR: auto-creates a credit note (AR \'50\')\nVT: negative output VAT'),
  SysDocTypeGuideEntry('45',
      usageTh: 'เพิ่มหนี้ลูกหนี้พร้อมส่งสต็อกเพิ่ม — ต้องระบุราคา',
      usageEn: 'Customer debit note with stock out — price required',
      effectTh: 'สต็อก: ลดจำนวนและมูลค่า\nGL (IM): Dr ต้นทุนขาย / Cr สินค้าคงคลัง',
      effectEn: 'Stock: reduces qty and value\nGL (IM): Dr COGS / Cr Inventory',
      relatedTh: 'AR: สร้างใบเพิ่มหนี้ (AR \'30\') อัตโนมัติ\nVT: ภาษีขายเพิ่ม\nวงเงินเครดิต: ตรวจวงเงิน',
      relatedEn: 'AR: auto-creates a debit note (AR \'30\')\nVT: adds output VAT\nCredit limit: checked'),
  SysDocTypeGuideEntry('60',
      usageTh: 'เบิกสินค้าใช้ภายใน (โครงการ แผนก ฯลฯ)',
      usageEn: 'Issue stock for internal use (project, department, etc.)',
      effectTh: 'สต็อก: ลดจำนวนและมูลค่า\nGL: Dr ต้นทุน/ค่าใช้จ่าย (บัญชีต้นทุนขาย) / Cr สินค้าคงคลัง',
      effectEn: 'Stock: reduces qty and value\nGL: Dr Cost/Expense (COGS account) / Cr Inventory'),
  SysDocTypeGuideEntry('70',
      usageTh: 'โอนสินค้าระหว่างคลัง/ตำแหน่ง',
      usageEn: 'Transfer stock between warehouses/locations',
      effectTh: 'สต็อก: ย้ายจำนวน มูลค่ารวมไม่เปลี่ยน\nGL: Dr สินค้าคงคลัง (ปลายทาง) / Cr สินค้าคงคลัง (ต้นทาง) — ถ้าเป็นบัญชีเดียวกันจะไม่เกิดรายการ',
      effectEn: 'Stock: moves qty, total value unchanged\nGL: Dr Inventory (to) / Cr Inventory (from) — no entry when both are the same account'),
  SysDocTypeGuideEntry('80',
      usageTh: 'ปรับยอดสินค้า (เช่น จากการตรวจนับ)',
      usageEn: 'Adjust stock quantity (e.g. from a physical count)',
      effectTh: 'สต็อก: เพิ่ม/ลดตามผลต่าง\nGL: ส่วนเกิน Dr สินค้าคงคลัง / Cr ผลต่าง; ส่วนขาดกลับทิศ',
      effectEn: 'Stock: increases/decreases by the difference\nGL: surplus Dr Inventory / Cr Variance; shortage the reverse',
      relatedTh: 'การตรวจนับสต็อก: สร้างเอกสารประเภทนี้ตอน Post ใบตรวจนับ',
      relatedEn: 'Stock count: posting a count sheet creates this type'),
  SysDocTypeGuideEntry('85',
      usageTh: 'เปลี่ยนแปลงราคาซื้อ/ราคาขายในรายการราคา',
      usageEn: 'Change purchase/selling prices in price lists',
      effectTh: 'ไม่กระทบสต็อกและไม่ลงบัญชี GL — เปลี่ยนเฉพาะรายการราคา',
      effectEn: 'No stock or GL effect — updates price lists only',
      relatedTh: 'PO/SO/IM: ใช้ราคาใหม่เป็นค่าเริ่มต้นของเอกสารถัดไป',
      relatedEn: 'PO/SO/IM: new prices become defaults on later documents'),
  SysDocTypeGuideEntry('90',
      usageTh: 'เบิกวัตถุดิบเข้าผลิต — อ้างอิงใบสั่งผลิต',
      usageEn: 'Manufacturing issue — references a manufacturing order',
      effectTh: 'สต็อก: ลดวัตถุดิบ\nGL: Dr งานระหว่างผลิต (WIP) / Cr สินค้าคงคลัง',
      effectEn: 'Stock: reduces raw materials\nGL: Dr WIP / Cr Inventory',
      relatedTh: 'MO: นับเป็นยอดเบิกวัตถุดิบของใบสั่งผลิต',
      relatedEn: 'MO: counted as material issued on the order'),
  SysDocTypeGuideEntry('95',
      usageTh: 'รับสินค้าสำเร็จรูปเข้าคลังจากการผลิต — อ้างอิงใบสั่งผลิตเดียวกัน',
      usageEn: 'Manufacturing receipt of finished goods — references the same order',
      effectTh: 'สต็อก: เพิ่มสินค้าสำเร็จรูป\nGL: Dr สินค้าคงคลัง / Cr งานระหว่างผลิต (WIP) (+ ผลต่างต้นทุนมาตรฐาน/จริง)',
      effectEn: 'Stock: adds finished goods\nGL: Dr Inventory / Cr WIP (+ standard/actual variance)',
      relatedTh: 'MO: นับเป็นยอดรับสินค้าสำเร็จรูปของใบสั่งผลิต',
      relatedEn: 'MO: counted as output received on the order'),
];

const List<SysDocTypeGuideEntry> _cmGuide = [
  SysDocTypeGuideEntry('10',
      usageTh: 'รับเงินอื่นๆ ที่ไม่ผ่านลูกหนี้ (เช่น รายได้เบ็ดเตล็ด)',
      usageEn: 'Other receipts not through AR (e.g. miscellaneous income)',
      effectTh: 'GL: Dr เงินสด/ธนาคารตามช่องทางรับเงิน / Cr รายได้',
      effectEn: 'GL: Dr Cash/Bank by receipt method / Cr Revenue',
      relatedTh: 'กระทบยอดธนาคาร: เป็นรายการรอเคลียร์ของบัญชีธนาคาร',
      relatedEn: 'Bank reconciliation: an item to clear on the bank account'),
  SysDocTypeGuideEntry('15',
      usageTh: 'รายรับที่มาจากการรับชำระ AR — สร้างอัตโนมัติ ดูได้อย่างเดียว',
      usageEn: 'Receipts created by AR receipts — automatic, read-only',
      effectTh: 'ไม่ลงบัญชีจาก CM — บัญชีลงโดยเอกสารรับชำระ AR (\'80\') แล้ว',
      effectEn: 'No CM posting — already posted by the AR receipt (\'80\')',
      relatedTh: 'AR: เกิดจากการ Post รับชำระ (AR \'80\') ยกเลิกเมื่อกลับรายการ/ยกเลิกเอกสาร AR',
      relatedEn: 'AR: created by posting a receipt (AR \'80\'), removed when that document is reversed/voided'),
  SysDocTypeGuideEntry('20',
      usageTh: 'จ่ายเงินอื่นๆ ที่ไม่ผ่านเจ้าหนี้ (เช่น ค่าใช้จ่ายเบ็ดเตล็ด)',
      usageEn: 'Other payments not through AP (e.g. miscellaneous expenses)',
      effectTh: 'GL: Dr ค่าใช้จ่าย / Cr เงินสด/ธนาคารตามช่องทางจ่ายเงิน',
      effectEn: 'GL: Dr Expense / Cr Cash/Bank by payment method',
      relatedTh: 'กระทบยอดธนาคาร: เป็นรายการรอเคลียร์ของบัญชีธนาคาร',
      relatedEn: 'Bank reconciliation: an item to clear on the bank account'),
  SysDocTypeGuideEntry('25',
      usageTh: 'รายจ่ายที่มาจากการจ่ายชำระ AP — สร้างอัตโนมัติ ดูได้อย่างเดียว',
      usageEn: 'Payments created by AP payments — automatic, read-only',
      effectTh: 'ไม่ลงบัญชีจาก CM — บัญชีลงโดยเอกสารจ่ายชำระ AP (\'80\') แล้ว',
      effectEn: 'No CM posting — already posted by the AP payment (\'80\')',
      relatedTh: 'AP: เกิดจากการ Post จ่ายชำระ (AP \'80\') ยกเลิกเมื่อกลับรายการ/ยกเลิกเอกสาร AP',
      relatedEn: 'AP: created by posting a payment (AP \'80\'), removed when that document is reversed/voided'),
  SysDocTypeGuideEntry('30',
      usageTh: 'เติมเงินสดย่อย — จ่ายเงินชดเชยใบเบิกเงินสดย่อย (\'40\') ที่ค้างอยู่',
      usageEn: 'Petty cash replenishment — reimburses open petty cash vouchers (\'40\')',
      effectTh: 'ล้างยอดค้างของใบเบิกที่เลือก\nGL: Dr เงินสดย่อย (บัญชี GL ของกองเงินสดย่อย ถ้าไม่ผูกใช้บัญชีในหน้านี้) / Cr เงินสด/ธนาคารตามช่องทางจ่ายเงิน',
      effectEn: 'Clears the selected vouchers\' balances\nGL: Dr Petty Cash (the fund\'s GL account, else this setup) / Cr Cash/Bank by payment method'),
  SysDocTypeGuideEntry('40',
      usageTh: 'เบิกเงินสดย่อย — บันทึกค่าใช้จ่ายที่จ่ายจากเงินสดย่อย',
      usageEn: 'Petty cash reimbursement — records expenses paid from petty cash',
      effectTh: 'เกิดยอดค้างรอเติมเงิน (\'30\')\nGL: Dr ค่าใช้จ่ายตามรายการ / Cr เงินสดย่อย (บัญชี GL ของกองเงินสดย่อย ถ้าไม่ผูกใช้บัญชีในหน้านี้)',
      effectEn: 'Creates an open balance awaiting replenishment (\'30\')\nGL: Dr Expense per line / Cr Petty Cash (the fund\'s GL account, else this setup)'),
  SysDocTypeGuideEntry('50',
      usageTh: 'โอนเงินระหว่างบัญชีธนาคาร/เงินสดของบริษัท — สองบัญชีต้องเป็นสกุลเงินเดียวกัน',
      usageEn: 'Transfer between the company\'s bank/cash accounts — both must be in the same currency',
      effectTh: 'GL: Dr บัญชีปลายทาง / Cr บัญชีต้นทาง — ใช้รหัสบัญชีที่ผูกกับบัญชีธนาคารแต่ละบัญชี',
      effectEn: 'GL: Dr destination / Cr source — uses each bank account\'s own GL account',
      relatedTh: 'กระทบยอดธนาคาร: เป็นรายการรอเคลียร์ทั้งสองบัญชี',
      relatedEn: 'Bank reconciliation: an item to clear on both accounts'),
  SysDocTypeGuideEntry('70',
      usageTh: 'ค่าธรรมเนียมธนาคาร',
      usageEn: 'Bank charges',
      effectTh: 'GL: Dr ค่าธรรมเนียม (บัญชีค่าใช้จ่าย) / Cr ธนาคาร',
      effectEn: 'GL: Dr Bank Charges (expense account) / Cr Bank',
      relatedTh: 'กระทบยอดธนาคาร: เป็นรายการรอเคลียร์',
      relatedEn: 'Bank reconciliation: an item to clear'),
  SysDocTypeGuideEntry('90',
      usageTh: 'ดอกเบี้ยรับ/จ่ายของบัญชีธนาคาร',
      usageEn: 'Bank interest received/paid',
      effectTh: 'GL: ดอกเบี้ยรับ Dr ธนาคาร / Cr บัญชีดอกเบี้ยรับ; ดอกเบี้ยจ่าย Dr บัญชีดอกเบี้ยจ่าย / Cr ธนาคาร',
      effectEn: 'GL: interest received Dr Bank / Cr Interest Income; interest paid Dr Interest Expense / Cr Bank',
      relatedTh: 'กระทบยอดธนาคาร: เป็นรายการรอเคลียร์',
      relatedEn: 'Bank reconciliation: an item to clear'),
];

// module: 'AR' | 'AP' | 'IM' | 'CM'
// docCodesBySdt: รหัสเอกสาร (doc_code) ที่ตั้งไว้ในฐานข้อมูลนี้ แยกตาม sys_doc_type — แสดงให้เห็นว่ารหัสไหนเป็นประเภทใด
// currentSdt: sys_doc_type ของเอกสารที่เลือกอยู่ — ไฮไลต์แถว
Future<void> showSysDocTypeGuide(
  BuildContext context, {
  required String module,
  required bool isEnglish,
  Map<String, List<String>> docCodesBySdt = const {},
  String? currentSdt,
}) {
  final (Map<String, String> names, List<SysDocTypeGuideEntry> guide, String moduleName) = switch (module) {
    'AR' => (arSysDocType, _arGuide, isEnglish ? 'Accounts Receivable (AR)' : 'บัญชีลูกหนี้ (AR)'),
    'AP' => (apSysDocType, _apGuide, isEnglish ? 'Accounts Payable (AP)' : 'บัญชีเจ้าหนี้ (AP)'),
    'IM' => (imSysDocType, _imGuide, isEnglish ? 'Inventory Management (IM)' : 'สินค้าคงคลัง (IM)'),
    _    => (cmSysDocType, _cmGuide, isEnglish ? 'Cash & Cheque Management (CM)' : 'เงินสดและเช็ค (CM)'),
  };

  // ชื่อในแผนที่เป็นรูปแบบ 'ไทย - English'
  String nameOf(String code) {
    final full = names[code] ?? '';
    final i = full.indexOf(' - ');
    if (i < 0) return full;
    return isEnglish ? full.substring(i + 3) : full.substring(0, i);
  }

  const headStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white);
  const cellStyle = TextStyle(fontSize: 12);
  Widget cell(Widget child) => Padding(padding: const EdgeInsets.all(8), child: child);
  Widget text(String s, {TextStyle style = cellStyle}) => cell(Text(s, style: style));

  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final size = MediaQuery.of(ctx).size;
      return AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
        title: Row(children: [
          const Icon(Icons.menu_book_outlined, color: Colors.teal),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isEnglish ? 'System Document Types — $moduleName' : 'ประเภทเอกสารระบบ — $moduleName',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(ctx).pop()),
        ]),
        content: SizedBox(
          width: (size.width * 0.9).clamp(320.0, 1200.0),
          height: size.height * 0.75,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              isEnglish
                  ? 'Every document code (doc_code) belongs to one fixed system document type (the number). The type decides how the document behaves and posts; '
                    'a type can have several document codes, each with its own GL accounts on this screen.'
                  : 'รหัสเอกสาร (doc_code) ทุกตัวผูกกับประเภทเอกสารระบบ (ตัวเลข) หนึ่งตัวที่กำหนดตายตัว ประเภทนี้เป็นตัวกำหนดพฤติกรรมและการบันทึกบัญชีของเอกสาร '
                    'ประเภทหนึ่งมีได้หลายรหัสเอกสาร และแต่ละรหัสตั้งรหัสบัญชีของตัวเองได้ในหน้านี้',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Table(
                  border: TableBorder.all(color: Colors.blueGrey.shade200),
                  columnWidths: const {
                    0: FixedColumnWidth(56),
                    1: FlexColumnWidth(1.3),
                    2: FlexColumnWidth(2),
                    3: FlexColumnWidth(2.6),
                    4: FlexColumnWidth(2.4),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.top,
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.teal.shade700),
                      children: [
                        text(isEnglish ? 'Type' : 'ประเภท', style: headStyle),
                        text(isEnglish ? 'Name / document codes' : 'ชื่อ / รหัสเอกสารที่ใช้', style: headStyle),
                        text(isEnglish ? 'Meaning / when to use' : 'ความหมาย / ใช้เมื่อไร', style: headStyle),
                        text(isEnglish ? 'Effect in $module' : 'ผลในโมดูล $module', style: headStyle),
                        text(isEnglish ? 'Effect on related modules' : 'ผลต่อโมดูลที่เกี่ยวข้อง', style: headStyle),
                      ],
                    ),
                    for (final e in guide)
                      TableRow(
                        decoration: BoxDecoration(
                          color: e.code == currentSdt ? Colors.amber.shade100 : (guide.indexOf(e).isEven ? Colors.white : Colors.blueGrey.shade50),
                        ),
                        children: [
                          text(e.code, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                          cell(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(nameOf(e.code), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            if ((docCodesBySdt[e.code] ?? const []).isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Wrap(spacing: 4, runSpacing: 4, children: [
                                for (final c in docCodesBySdt[e.code]!)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.teal.shade200),
                                    ),
                                    child: Text(c, style: TextStyle(fontSize: 11, color: Colors.teal.shade800)),
                                  ),
                              ]),
                            ],
                          ])),
                          text(isEnglish ? e.usageEn : e.usageTh),
                          text(isEnglish ? e.effectEn : e.effectTh),
                          text(isEnglish ? e.relatedEn : e.relatedTh),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      );
    },
  );
}

// ปุ่มไอคอนสำหรับ AppBar ของหน้าจอตั้งค่ารหัสบัญชี
class SysDocTypeGuideButton extends StatelessWidget {
  final String module;
  final bool isEnglish;
  final Map<String, List<String>> docCodesBySdt;
  final String? currentSdt;

  const SysDocTypeGuideButton({
    super.key,
    required this.module,
    required this.isEnglish,
    this.docCodesBySdt = const {},
    this.currentSdt,
  });

  // รวม doc_code ตาม sys_doc_type จากรายการในหน้าจอ
  static Map<String, List<String>> groupDocCodes<T>(
      Iterable<T> rows, String? Function(T) sdt, String Function(T) docCode) {
    final map = <String, List<String>>{};
    for (final r in rows) {
      final k = sdt(r);
      if (k == null || k.isEmpty) continue;
      map.putIfAbsent(k, () => []).add(docCode(r));
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.help_outline, color: Colors.white),
      tooltip: isEnglish ? 'System document types explained' : 'คำอธิบายประเภทเอกสารระบบ',
      onPressed: () => showSysDocTypeGuide(context,
          module: module, isEnglish: isEnglish, docCodesBySdt: docCodesBySdt, currentSdt: currentSdt),
    );
  }
}
