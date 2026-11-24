// ไอคอนแท็บเบราว์เซอร์ (favicon) = โลโก้ระบบที่ตั้งในหน้าตั้งค่าหน้าล็อกอิน
// web เท่านั้น — แพลตฟอร์มอื่นไม่ทำอะไร (conditional import)
export 'sa_favicon_stub.dart' if (dart.library.html) 'sa_favicon_web.dart';
