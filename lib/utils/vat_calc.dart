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

// ── ส่วนลดเอกสารขาย (มิเรอร์ computeSalesDiscounts ใน anan_backend/utils/vatCalc.js) ──────────────────────────
// ส่วนลดขั้นบันได "10+5+2" = ลดทบกัน (0.90 × 0.95 × 0.98) สูงสุด 5 ขั้น แต่ละขั้น 0–100
const int maxDiscountSteps = 5;

class StepDiscount {
  final List<double> steps;
  final double factor; // ยอดคงเหลือหลังส่วนลด (1 = ไม่ลด)
  final bool valid;
  const StepDiscount(this.steps, this.factor, this.valid);
}

StepDiscount parseStepDiscount(String? text) {
  final t = (text ?? '').replaceAll(RegExp(r'[\s%]'), '');
  if (t.isEmpty) return const StepDiscount([], 1, true);
  final parts = t.split('+');
  final re = RegExp(r'^\d+(\.\d+)?$');
  if (parts.length > maxDiscountSteps || parts.any((p) => !re.hasMatch(p) || double.parse(p) > 100)) {
    return const StepDiscount([], 1, false);
  }
  final steps = parts.map(double.parse).toList();
  return StepDiscount(steps, steps.fold(1.0, (f, s) => f * (1 - s / 100)), true);
}

double _r2(double v) => (v.abs() * 100 + 1e-7).round() / 100 * (v < 0 ? -1 : 1);

// แบ่ง amount ตามน้ำหนัก (ปัด 2 ตำแหน่ง) เศษไปบรรทัดที่น้ำหนักมากที่สุด
List<double> _distribute(double amount, List<double> weights) {
  final total = weights.fold(0.0, (t, w) => t + (w > 0 ? w : 0));
  if (total <= 0 || amount == 0) return List.filled(weights.length, 0);
  final shares = weights.map((w) => w > 0 ? _r2(amount * w / total) : 0.0).toList();
  final diff = _r2(amount - shares.fold(0.0, (t, s) => t + s));
  if (diff != 0) {
    var iMax = 0;
    for (var i = 1; i < weights.length; i++) {
      if (weights[i] > weights[iMax]) iMax = i;
    }
    shares[iMax] = _r2(shares[iMax] + diff);
  }
  return shares;
}

class SalesLineDiscount {
  final double own;   // ขั้นบันได + ส่วนลดเงินของบรรทัด
  final double bill;  // ส่วนที่ปันมาจากส่วนลดท้ายบิล % + เงินสด
  double get total => _r2(own + bill);
  const SalesLineDiscount(this.own, this.bill);
}

class SalesDiscountInput {
  final double entered;      // จำนวน × ราคาที่กรอก
  final String? stepText;    // "10+5+2"
  final double lineAmount;   // ส่วนลดเงินของบรรทัด (ทั้งบรรทัด)
  final bool isFree;
  const SalesDiscountInput({required this.entered, this.stepText, this.lineAmount = 0, this.isFree = false});
}

// ลำดับ: ขั้นบันได → ส่วนลดเงินของบรรทัด → ส่วนลดท้ายบิล % → ส่วนลดเงินสดท้ายบิล (ข้อ 3-4 ปันตามสัดส่วนยอดคงเหลือ)
// ยอดทั้งหมดอยู่ในหน่วยเดียวกับราคาที่กรอก — ข้อมูลไม่ถูกต้อง (ขั้นบันไดผิดรูปแบบ/ส่วนลดเกินยอด) ปัดให้อยู่ในช่วง
// เพื่อแสดงผลได้ ส่วน backend ปฏิเสธตอนบันทึก
List<SalesLineDiscount> computeSalesDiscounts(List<SalesDiscountInput> lines,
    {double billDiscountPercent = 0, double cashDiscountAmount = 0}) {
  final billPct = billDiscountPercent.clamp(0, 100).toDouble();
  final own = <double>[];
  final bases = <double>[];
  for (final l in lines) {
    final entered = _r2(l.entered.abs());
    if (l.isFree) {
      own.add(0);
      bases.add(0);
      continue;
    }
    final o = _r2(entered * (1 - parseStepDiscount(l.stepText).factor) + (l.lineAmount > 0 ? l.lineAmount : 0));
    final clamped = o > entered ? entered : o;
    own.add(clamped);
    bases.add(_r2(entered - clamped));
  }
  final pct = _distribute(_r2(bases.fold(0.0, (t, b) => t + b) * billPct / 100), bases);
  final afterPct = [for (var i = 0; i < bases.length; i++) _r2(bases[i] - pct[i])];
  final room = _r2(afterPct.fold(0.0, (t, b) => t + b));
  final cash = _r2(cashDiscountAmount > room ? room : (cashDiscountAmount < 0 ? 0 : cashDiscountAmount));
  final cashShares = _distribute(cash, afterPct);
  return [for (var i = 0; i < lines.length; i++) SalesLineDiscount(own[i], _r2(pct[i] + cashShares[i]))];
}
