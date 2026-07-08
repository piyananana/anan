// lib/utils/thai_amount_words.dart

const _units  = ['', 'หนึ่ง', 'สอง', 'สาม', 'สี่', 'ห้า', 'หก', 'เจ็ด', 'แปด', 'เก้า'];
const _powers = ['', 'สิบ', 'ร้อย', 'พัน', 'หมื่น', 'แสน'];

String thaiAmountToWords(double amount) {
  final totalSatang = (amount * 100).round();
  final baht   = totalSatang ~/ 100;
  final satang = totalSatang % 100;
  if (baht == 0 && satang == 0) return 'ศูนย์บาทถ้วน';
  String result = baht > 0 ? '${_intToThai(baht)}บาท' : '';
  result += satang > 0 ? '${_intToThai(satang)}สตางค์' : 'ถ้วน';
  return result;
}

String _intToThai(int n) {
  if (n <= 0)      return '';
  if (n >= 1000000) {
    final m = n ~/ 1000000;
    final r = n % 1000000;
    return '${_intToThai(m)}ล้าน${r > 0 ? _intToThai(r) : ''}';
  }
  // Build digit list from most-significant to least-significant
  final s = n.toString();
  final len = s.length;
  final result = StringBuffer();
  for (int i = 0; i < len; i++) {
    final d   = int.parse(s[i]);
    final pos = len - 1 - i; // 0 = ones, 1 = tens, ...
    if (d == 0) continue;
    if (pos == 1) {
      // Tens place
      if (d == 1) {
        result.write('สิบ'); // not หนึ่งสิบ
      } else if (d == 2) {
        result.write('ยี่สิบ');
      } else {
        result.write('${_units[d]}สิบ');
      }
    } else if (pos == 0 && d == 1 && len > 1) {
      // Ones place = 1 and there is a tens digit → เอ็ด
      // But only when (n % 100) >= 11 i.e. tens > 0
      final tens = (n % 100) ~/ 10;
      result.write(tens > 0 ? 'เอ็ด' : 'หนึ่ง');
    } else {
      result.write(_units[d]);
      if (pos > 0) result.write(_powers[pos]);
    }
  }
  return result.toString();
}
