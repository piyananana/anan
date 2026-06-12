class AppConfig {
  // สำหรับ dev: 'http://localhost:8888'
  // สำหรับ production (serve จาก backend): ''
  static const String baseHost = '';

  static const String apiSa = '${baseHost}/api/sa';
  static const String apiGl = '${baseHost}/api/gl';
  static const String apiCd = '${baseHost}/api/cd';
  static const String apiAr = '${baseHost}/api/ar';
  static const String apiCm = '${baseHost}/api/cm';
  static const String apiVt = '${baseHost}/api/vt';
  static const String apiAp = '${baseHost}/api/ap';
}
