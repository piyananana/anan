{{flutter_js}}
{{flutter_build_config}}

// โหลด CanvasKit จากเซิร์ฟเวอร์ของเราเอง (build/web/canvaskit/) แทน www.gstatic.com
// เพื่อให้เครื่องในวง LAN ที่ไม่มีอินเทอร์เน็ตเปิดระบบได้
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
  },
});
