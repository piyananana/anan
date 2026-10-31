// ยอดของบรรทัดเอกสารซื้อ/ขาย ตามตัวเลือก "ราคารวม VAT" (user-approved 2026-10-31, ใช้ร่วม AR/AP/IM/PO/SO)
// ค่าที่คืนเป็นยอดก่อน VAT เสมอ (ยกเว้น total) ไม่ว่าราคาที่กรอกจะรวม VAT หรือไม่ — ความหมายของ subtotal / discount /
// vat / total ที่เก็บในฐานข้อมูลจึงเหมือนเดิม การลงบัญชีและรายงานภาษีไม่ต้องรู้จักตัวเลือกนี้
//   ราคาไม่รวม VAT: gross = จำนวน × ราคา, ส่วนลด = gross × % (หรือจำนวนเงิน), net = gross − ส่วนลด, vat = net × อัตรา
//   ราคารวม VAT:   ยอดรวม VAT หลังส่วนลด = จำนวน × ราคา − ส่วนลด (ทั้งสองค่ารวม VAT), vat = ยอดนั้น × อัตรา / (100 + อัตรา)
//                  แล้วแปลงส่วนลดเป็นยอดก่อน VAT ด้วยสัดส่วนเดียวกัน
class LineAmounts {
  final double gross;    // ก่อนส่วนลด ก่อน VAT
  final double discount; // ส่วนลด ก่อน VAT
  final double net;      // หลังส่วนลด ก่อน VAT
  final double vat;
  final double total;    // หลังส่วนลด รวม VAT
  const LineAmounts(this.gross, this.discount, this.net, this.vat, this.total);
}

LineAmounts calcLineAmounts({
  required double qty,
  required double price,
  double discountPercent = 0,
  double? discountAmount, // ระบุ = ใช้จำนวนเงินนี้แทน % (หน่วยเดียวกับราคาที่กรอก)
  required double vatRate,
  bool noVat = false,
  bool priceIncludesVat = false,
}) {
  final rate = noVat ? 0.0 : vatRate;
  final entered = qty * price;
  final enteredDisc = discountAmount ?? entered * discountPercent / 100;
  final afterDisc = entered - enteredDisc;
  if (!priceIncludesVat || rate == 0) {
    final vat = afterDisc * rate / 100;
    return LineAmounts(entered, enteredDisc, afterDisc, vat, afterDisc + vat);
  }
  final vat = afterDisc * rate / (100 + rate);
  final factor = 100 / (100 + rate);
  return LineAmounts(entered * factor, enteredDisc * factor, afterDisc - vat, vat, afterDisc);
}
