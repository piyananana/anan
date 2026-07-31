import '../../../config/app_config.dart';
// File: gl/services/gl_period_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../sa/services/sa_auth_service.dart';
import '../models/gl_period.dart';

// ไม่มีผู้อนุมัติที่ active อยู่สำหรับเมนูนี้ในขณะนี้ — ให้ผู้ใช้เลือกว่าจะดำเนินการต่อ (ข้ามขั้นตอนอนุมัติ) หรือยกเลิก
class NoActiveApproverException implements Exception {
  final String message;
  NoActiveApproverException(this.message);
  @override
  String toString() => message;
}

class PeriodService {
  final String baseUrl = AppConfig.apiGl;
  final AuthService authService = AuthService();

  // ดึงรายการปีบัญชีที่ is_active = true เท่านั้น (ใช้ใน dropdown transaction/report)
  Future<List<FiscalYear>> fetchActiveFiscalYears() async {
    final all = await fetchFiscalYears();
    return all.where((fy) => fy.isActive).toList();
  }

  // 1. ดึงรายการปีบัญชีทั้งหมด
  Future<List<FiscalYear>> fetchFiscalYears() async {
    try {
      final headers = await authService.getAuthHeader();
      final response = await http.get(
        Uri.parse('$baseUrl/gl_fiscal_year'), 
        headers: headers
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => FiscalYear.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load fiscal years: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching fiscal years: $e');
    }
  }

  // ดึงงวดบัญชีที่ gl_status = 'OPEN' ทั้งหมด
  Future<List<PostingPeriod>> fetchOpenGlPeriods() async {
    try {
      final headers = await authService.getAuthHeader();
      final response = await http.get(
        Uri.parse('$baseUrl/gl_posting_period/open'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => PostingPeriod.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load open GL periods: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching open GL periods: $e');
    }
  }

  // 2. ดึงงวดบัญชีของปีที่ระบุ
  Future<List<PostingPeriod>> fetchPostingPeriodsByFiscalYearId(int fyId) async {
    try {
      final headers = await authService.getAuthHeader();
      final response = await http.get(
        Uri.parse('$baseUrl/gl_fiscal_year/$fyId/gl_posting_period'), 
        headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => PostingPeriod.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load periods: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching periods: $e');
    }
  }


  // ----------------------------------------------------
  // A. GL FISCAL YEAR CRUD
  // ----------------------------------------------------

  Future<List<FiscalYear>> fetchHeaderRows() async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/gl_fiscal_year'), 
      headers: headers);

    if (response.statusCode == 200) {
      List jsonList = json.decode(response.body);
      return jsonList.map((json) => FiscalYear.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load fiscal years: ${json.decode(response.body)['message']}');
    }
  }

  Future<FiscalYear> addHeaderRow(FiscalYear row) async {
    final body = row.toJson();
    
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/gl_fiscal_year'),
      headers: headers,
      body: json.encode(body),
    );

    if (response.statusCode == 201) {
      return FiscalYear.fromJson(json.decode(response.body)['fiscalYear']);
    } else {
      throw Exception('Failed to create fiscal year: ${json.decode(response.body)['message']}');
    }
  }
  
  Future<FiscalYear> updateHeaderRow(FiscalYear row) async {
    final body = {
      'description': row.description,
      'year_start_date': row.yearStartDate.toIso8601String().split('T')[0],
      'year_end_date': row.yearEndDate.toIso8601String().split('T')[0],
      'is_active': row.isActive,
    };

    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/gl_fiscal_year/${row.id}'),
      headers: headers,
      body: json.encode(body),
    );

    if (response.statusCode == 200) {
      return FiscalYear.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update fiscal year: ${json.decode(response.body)['message']}');
    }
  }

  Future<void> deleteHeaderRow(int rowId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(
      Uri.parse('$baseUrl/gl_fiscal_year/$rowId'), 
      headers: headers);
    
    if (response.statusCode != 200) {
      throw Exception('Failed to delete fiscal year: ${json.decode(response.body)['message']}');
    }
  }
  
  // ----------------------------------------------------
  // B. GL POSTING PERIOD CRUD
  // ----------------------------------------------------
  
  Future<List<PostingPeriod>> fetchDetailRows(int rowId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.get(
      Uri.parse('$baseUrl/gl_fiscal_year/$rowId/gl_posting_period'), 
      headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((json) => PostingPeriod.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load posting periods: ${json.decode(response.body)['message']}');
    }
  }
  
  Future<PostingPeriod> addDetailRow(PostingPeriod row) async {
    final body = row.toJson();

    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/gl_posting_period'),
      headers: headers,
      body: json.encode(body),
    );
    
    if (response.statusCode == 201) {
      return PostingPeriod.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create period: ${json.decode(response.body)['message']}');
    }
  }

  Future<PostingPeriod> updateDetailRow(PostingPeriod row) async {
    final body = {
      'period_name': row.periodName,
      'period_start_date': row.periodStartDate.toIso8601String().split('T')[0],
      'period_end_date': row.periodEndDate.toIso8601String().split('T')[0],
    };

    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/gl_posting_period/${row.id}'),
      headers: headers,
      body: json.encode(body),
    );
    
    if (response.statusCode == 200) {
      return PostingPeriod.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update period: ${json.decode(response.body)['message']}');
    }
  }

  Future<void> deleteDetailRow(int rowId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.delete(
      Uri.parse('$baseUrl/gl_posting_period/$rowId'), 
      headers: headers);
    
    if (response.statusCode != 200) {
      throw Exception('Failed to delete period: ${json.decode(response.body)['message']}');
    }
  }
  
  Future<Map<String, dynamic>> verifyCloseApprover(String username, String password) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/gl_posting_period/verify_close_approver'),
      headers: headers,
      body: json.encode({'username': username, 'password': password}),
    );
    final body = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return body;
    } else {
      throw Exception(body['message'] ?? 'ไม่สามารถยืนยันตัวตนได้');
    }
  }

  // ── GL Period Close Approval Workflow ──────────────────────────────────

  Future<Map<String, dynamic>> requestClose(int periodId, {required int menuId, bool force = false}) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/gl_posting_period/$periodId/request_close'),
      headers: headers,
      body: json.encode({'menu_id': menuId, 'force': force}),
    );
    final body = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return body;
    } else if (response.statusCode == 409 && body['code'] == 'NO_ACTIVE_APPROVER') {
      throw NoActiveApproverException(body['message'] ?? 'ไม่มีผู้อนุมัติที่ใช้งานอยู่');
    } else {
      throw Exception(body['message'] ?? 'ไม่สามารถส่งคำขอปิดงวดได้');
    }
  }

  Future<void> approveCloseRequest(int requestId, {String? remarks}) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/gl_period_close_request/$requestId/approve'),
      headers: headers,
      body: json.encode({'remarks': remarks}),
    );
    if (response.statusCode != 200) {
      final body = json.decode(response.body);
      throw Exception(body['message'] ?? 'ไม่สามารถอนุมัติได้');
    }
  }

  Future<void> rejectCloseRequest(int requestId, String remarks) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/gl_period_close_request/$requestId/reject'),
      headers: headers,
      body: json.encode({'remarks': remarks}),
    );
    if (response.statusCode != 200) {
      final body = json.decode(response.body);
      throw Exception(body['message'] ?? 'ไม่สามารถปฏิเสธได้');
    }
  }

  Future<void> cancelCloseRequest(int requestId) async {
    final headers = await authService.getAuthHeader();
    final response = await http.post(
      Uri.parse('$baseUrl/gl_period_close_request/$requestId/cancel'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      final body = json.decode(response.body);
      throw Exception(body['message'] ?? 'ไม่สามารถยกเลิกคำขอได้');
    }
  }

  Future<PostingPeriod> updateStatusDetailRow(int rowId, String module, String newStatus) async {
    final body = {
      // ใช้ dynamic key เพื่อส่งสถานะที่ต้องการเปลี่ยนเท่านั้น
      '${module.toLowerCase()}_status': newStatus, 
    };
    
    final headers = await authService.getAuthHeader();
    final response = await http.put(
      Uri.parse('$baseUrl/gl_posting_period/$rowId/status'),
      headers: headers,
      body: json.encode(body),
    );

    if (response.statusCode == 200) {
      return PostingPeriod.fromJson(json.decode(response.body));
    } else {
      final body = json.decode(response.body);
      throw Exception(body['error'] ?? body['message'] ?? 'Failed to update status');
    }
  }
}

// // File: gl/services/gl_period_service.dart
// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import '../../sa/services/sa_auth_service.dart';
// import '../models/gl_period.dart';
// // import '../models/gl_posting_period.dart';

// class PeriodService {
//   // static const String _baseUrl = 'http://localhost:3000/api/gl'; 
//   final String baseUrl = AppConfig.apiGl;
//   final AuthService authService = AuthService();
//   // final Map<String, String> _headers = {'Content-Type': 'application/json'};

//   // ----------------------------------------------------
//   // A. GL FISCAL YEAR CRUD
//   // ----------------------------------------------------

//   Future<List<FiscalYear>> fetchFiscalYears() async {
//     final headers = await authService.getAuthHeader();
//     final response = await http.get(
//       Uri.parse('$baseUrl/gl_fiscal_year'), 
//       headers: headers);

//     if (response.statusCode == 200) {
//       final List<dynamic> jsonList = json.decode(response.body);
//       return jsonList.map((json) => FiscalYear.fromJson(json)).toList();
//     } else {
//       throw Exception('Failed to load fiscal years: ${json.decode(response.body)['message']}');
//     }
//   }

//   Future<FiscalYear> createFiscalYear(FiscalYear fy, int userId) async {
//     final body = fy.toJson();
//     body['created_by'] = userId;
//     body['updated_by'] = userId;
    
//     final headers = await authService.getAuthHeader();
//     final response = await http.post(
//       Uri.parse('$baseUrl/gl_fiscal_year'),
//       headers: headers,
//       body: json.encode(body),
//     );

//     if (response.statusCode == 201) {
//       return FiscalYear.fromJson(json.decode(response.body)['fiscalYear']);
//     } else {
//       throw Exception('Failed to create fiscal year: ${json.decode(response.body)['message']}');
//     }
//   }
  
//   // ----------------------------------------------------
//   // B. GL POSTING PERIOD CRUD
//   // ----------------------------------------------------
  
//   Future<List<PostingPeriod>> fetchPeriodsByYearId(int fyId) async {
//     final headers = await authService.getAuthHeader();
//     final response = await http.get(
//       Uri.parse('$baseUrl/gl_fiscal_year/$fyId/gl_posting_period'), 
//       headers: headers);

//     if (response.statusCode == 200) {
//       final List<dynamic> jsonList = json.decode(response.body);
//       return jsonList.map((json) => PostingPeriod.fromJson(json)).toList();
//     } else {
//       throw Exception('Failed to load posting periods: ${json.decode(response.body)['message']}');
//     }
//   }
  
//   Future<PostingPeriod> createPeriod(PostingPeriod period, int userId) async {
//     final body = period.toJson();
//     body['updated_by'] = userId;

//     final headers = await authService.getAuthHeader();
//     final response = await http.post(
//       Uri.parse('$baseUrl/gl_posting_period'),
//       headers: headers,
//       body: json.encode(body),
//     );
    
//     if (response.statusCode == 201) {
//       return PostingPeriod.fromJson(json.decode(response.body));
//     } else {
//       throw Exception('Failed to create period: ${json.decode(response.body)['message']}');
//     }
//   }

//   Future<PostingPeriod> updatePeriod(PostingPeriod period, int userId) async {
//     final body = {
//       'period_name': period.periodName,
//       'period_start_date': period.periodStartDate.toIso8601String().split('T')[0],
//       'period_end_date': period.periodEndDate.toIso8601String().split('T')[0],
//       'updated_by': userId,
//     };

//     final headers = await authService.getAuthHeader();
//     final response = await http.put(
//       Uri.parse('$baseUrl/gl_posting_period/${period.id}'),
//       headers: headers,
//       body: json.encode(body),
//     );
    
//     if (response.statusCode == 200) {
//       return PostingPeriod.fromJson(json.decode(response.body));
//     } else {
//       throw Exception('Failed to update period: ${json.decode(response.body)['message']}');
//     }
//   }

//   Future<void> deletePeriod(int periodId) async {
//     final headers = await authService.getAuthHeader();
//     final response = await http.delete(
//       Uri.parse('$baseUrl/gl_posting_period/$periodId'), 
//       headers: headers);
    
//     if (response.statusCode != 200) {
//       throw Exception('Failed to delete period: ${json.decode(response.body)['message']}');
//     }
//   }
  
//   Future<PostingPeriod> updatePeriodStatus(int periodId, String module, String newStatus, int userId) async {
//     final body = {
//       // ใช้ dynamic key เพื่อส่งสถานะที่ต้องการเปลี่ยนเท่านั้น
//       '${module.toLowerCase()}_status': newStatus, 
//       'updated_by': userId,
//     };
    
//     final headers = await authService.getAuthHeader();
//     final response = await http.put(
//       Uri.parse('$baseUrl/gl_posting_period/$periodId/status'),
//       headers: headers,
//       body: json.encode(body),
//     );

//     if (response.statusCode == 200) {
//       return PostingPeriod.fromJson(json.decode(response.body));
//     } else {
//       throw Exception('Failed to update status: ${json.decode(response.body)['message']}');
//     }
//   }
// }