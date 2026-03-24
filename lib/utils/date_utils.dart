/// แปลง string/dynamic วันที่จาก backend เป็น local DateTime โดยไม่มี timezone shift
/// รองรับทั้ง '1992-01-01' และ '1992-01-01T00:00:00.000Z'
/// คืน DateTime ปัจจุบัน (วันนี้) หากค่าเป็น null หรือว่าง
DateTime parseLocalDate(dynamic dateVal) {
  final dateStr = dateVal?.toString();
  if (dateStr == null || dateStr.isEmpty) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
  try {
    final local = DateTime.parse(dateStr).toLocal();
    return DateTime(local.year, local.month, local.day);
  } catch (_) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

/// แปลง string/dynamic วันที่จาก backend เป็น local DateTime?
/// คืน null หากค่าเป็น null หรือว่าง
DateTime? parseLocalDateNullable(dynamic dateVal) {
  final dateStr = dateVal?.toString();
  if (dateStr == null || dateStr.isEmpty) return null;
  try {
    final local = DateTime.parse(dateStr).toLocal();
    return DateTime(local.year, local.month, local.day);
  } catch (_) {
    return null;
  }
}

/// Format DateTime เป็น 'YYYY-MM-DD' สำหรับส่งไป backend (DATE field)
/// ใช้แทน toIso8601String().split('T')[0] เพื่อหลีกเลี่ยง timezone shift
String formatLocalDate(DateTime dt) {
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
