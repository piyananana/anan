import 'package:flutter_test/flutter_test.dart';
import 'package:anan/utils/vat_calc.dart';

// ตัวเลขชุดเดียวกับการทดสอบฝั่ง backend (computeSalesDiscounts ใน anan_backend/utils/vatCalc.js) — ผลต้องตรงกัน
void main() {
  test('step discount parsing', () {
    expect(parseStepDiscount(' 10 + 5 ').factor, closeTo(0.855, 1e-12));
    expect(parseStepDiscount('').valid, isTrue);
    expect(parseStepDiscount('10+5+2+1+1+1').valid, isFalse);
    expect(parseStepDiscount('10+abc').valid, isFalse);
    expect(parseStepDiscount('120').valid, isFalse);
  });

  test('line, bill % and cash discounts allocate like the backend', () {
    final r = computeSalesDiscounts(const [
      SalesDiscountInput(entered: 200, stepText: '10+5', lineAmount: 20),
      SalesDiscountInput(entered: 150),
      SalesDiscountInput(entered: 0, isFree: true),
    ], billDiscountPercent: 10, cashDiscountAmount: 15);
    expect(r[0].own, 49);
    expect(r[0].bill, 22.62);
    expect(r[0].total, 71.62);
    expect(r[1].total, 22.48);
    expect(r[2].total, 0);
    final net = calcLineAmounts(qty: 2, price: 100, discountAmount: r[0].total, vatRate: 7);
    expect(net.net, closeTo(128.38, 1e-9));
  });
}
