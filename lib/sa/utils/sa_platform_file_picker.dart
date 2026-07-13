// utils/sa_platform_file_picker.dart

import 'package:flutter/foundation.dart'; // สำหรับ kIsWeb
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' if (dart.library.html) 'dart:html'; // Conditional import
import 'package:http/http.dart' as http; // สำหรับ http.MultipartFile

// Class เพื่อห่อหุ้มข้อมูลไฟล์ที่เลือกได้จาก ImagePicker/html.File
class PickedPlatformFile {
  final String? path; // สำหรับ dart:io (Mobile/Desktop)
  final Uint8List? bytes; // สำหรับ dart:html (Web)
  final String? name; // ชื่อไฟล์
  final String? mimeType; // ประเภทไฟล์

  PickedPlatformFile({this.path, this.bytes, this.name, this.mimeType});

  bool get isWeb => kIsWeb;
  bool get isMobileOrDesktop => !kIsWeb;

  // เมธอดสำหรับแปลงเป็น MultipartFile
  Future<http.MultipartFile> toMultipartFile(String fieldName) async {
    if (isWeb) {
      if (bytes == null || name == null || mimeType == null) {
        throw Exception('Web file data (bytes, name, mimeType) cannot be null for MultipartFile.');
      }
      return http.MultipartFile.fromBytes(
        fieldName,
        bytes!,
        filename: name,
        contentType: (mimeType != null && mimeType!.isNotEmpty)
            ? MediaType.parse(mimeType!)
            : null,
      );
    } else {
      if (path == null) {
        throw Exception('File path cannot be null for Mobile/Desktop MultipartFile.');
      }
      return http.MultipartFile.fromPath(fieldName, path!);
    }
  }
}

// Helper class สำหรับเลือกรูปภาพที่รองรับหลายแพลตฟอร์ม
class PlatformImagePicker {
  static final ImagePicker _picker = ImagePicker();

  static Future<PickedPlatformFile?> pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (pickedFile != null) {
      if (kIsWeb) {
        // สำหรับ Web: อ่าน bytes
        final bytes = await pickedFile.readAsBytes();
        return PickedPlatformFile(
          bytes: bytes,
          name: pickedFile.name,
          mimeType: pickedFile.mimeType,
        );
      } else {
        // สำหรับ Mobile/Desktop: ใช้ path
        return PickedPlatformFile(
          path: pickedFile.path,
          name: pickedFile.name,
          mimeType: pickedFile.mimeType,
        );
      }
    }
    return null;
  }
}