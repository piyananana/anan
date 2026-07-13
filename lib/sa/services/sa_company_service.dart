import '../../config/app_config.dart';
// services/sa_company_service.dart

import 'dart:convert';
// import 'dart:io'; // สำหรับ File
import 'package:http/http.dart' as http;
// import 'package:http_parser/http_parser.dart'; // สำหรับ MediaType
import '../models/sa_company.dart';
import '../utils/sa_platform_file_picker.dart'; // import ไฟล์ใหม่
import 'sa_auth_service.dart';

class CompanyService {
  // final String baseUrl = 'http://localhost:3000/api/sa'; // ปรับตาม IP ของคุณ
  final String baseUrl = AppConfig.apiSa;
  final AuthService authService = AuthService();

  // ดึงข้อมูลบริษัท
  Future<Company?> fetchCompany() async {
    try {
      final headers = await authService.getAuthHeader();
      final response = await http.get(
        Uri.parse('$baseUrl/sa_company'),
        headers: headers,
      );
      // var request = http.MultipartRequest('GET', Uri.parse('$baseUrl/sa_company'));
      // final response = await request.send();
      // final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return Company.fromJson(jsonDecode(response.body));
        // return Company.fromJson(jsonDecode(responseBody));
      } else if (response.statusCode == 404) {
        return null; // ไม่มีข้อมูลบริษัท
      } else {
        print('Failed to fetch company: Status ${response.statusCode}, Body: ${response.body}');
        throw Exception('Failed to fetch company: ${response.body}');
        // print('Failed to fetch company: Status ${response.statusCode}, Body: $responseBody');
        // throw Exception('Failed to fetch company: $responseBody');
      }
    } catch (e) {
      print('Error fetching company: $e');
      throw Exception('Network error fetching company: $e');
    }
  }

  // เพิ่มข้อมูลบริษัท (พร้อมโลโก้)
  Future<Company> createCompany(Company company, {PickedPlatformFile? logoFile}) async {
    final headers = await authService.getAuthHeader();
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/sa_company'));
    request.headers.addAll(headers);

    // เพิ่มฟิลด์ข้อมูล
    company.toFormJson().forEach((key, value) {
      request.fields[key] = value;
    });

    // เพิ่มไฟล์โลโก้
    if (logoFile != null) {
      request.files.add(await logoFile.toMultipartFile('logo')); // ใช้เมธอดใหม่
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 201) {
      return Company.fromJson(jsonDecode(responseBody)['company']);
    } else {
      print('Failed to create company: Status ${response.statusCode}, Body: $responseBody');
      throw Exception('Failed to create company: $responseBody');
    }
  }

  // อัปเดตข้อมูลบริษัท (พร้อมโลโก้)
  Future<Company> updateCompany(Company company, {PickedPlatformFile? logoFile}) async {
    final headers = await authService.getAuthHeader();
    var request = http.MultipartRequest('PUT', Uri.parse('$baseUrl/sa_company/${company.id}'));
    request.headers.addAll(headers);

    // เพิ่มฟิลด์ข้อมูล
    company.toFormJson().forEach((key, value) {
      request.fields[key] = value;
    });

    // เพิ่มไฟล์โลโก้
    if (logoFile != null) {
      request.files.add(await logoFile.toMultipartFile('logo')); // ใช้เมธอดใหม่
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      return Company.fromJson(jsonDecode(responseBody)['company']);
    } else {
      print('Failed to update company: Status ${response.statusCode}, Body: $responseBody');
      throw Exception('Failed to update company: $responseBody');
    }
  }
}