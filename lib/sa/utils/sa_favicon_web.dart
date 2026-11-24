// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// เปลี่ยน favicon เป็นรูปจาก [url] — null/ว่าง = กลับไปใช้ favicon.png มาตรฐาน (โลโก้ ANAN)
void setFavicon(String? url) {
  final href = (url == null || url.isEmpty) ? 'favicon.png' : url;
  final links = html.document.querySelectorAll('link[rel~="icon"]');
  if (links.isEmpty) {
    html.document.head?.append(html.LinkElement()
      ..rel = 'icon'
      ..href = href);
    return;
  }
  for (final l in links) {
    if (l is html.LinkElement) {
      l.href = href;
      l.type = ''; // รูปที่อัปโหลดอาจเป็น JPG — ไม่ระบุชนิดให้เบราว์เซอร์ดูจากไฟล์เอง
    }
  }
}
