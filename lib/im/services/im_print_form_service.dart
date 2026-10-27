// lib/im/services/im_print_form_service.dart — แบบฟอร์มพิมพ์กลาง (ออกแบบ / พิมพ์ / ประวัติการพิมพ์)
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../models/im_print_form.dart';
import '../../sa/services/sa_auth_service.dart';

class ImPrintFormService {
  final String _base = AppConfig.apiIm;
  final AuthService _auth = AuthService();

  String _msg(http.Response r) {
    try {
      return jsonDecode(r.body)['message']?.toString() ?? r.body;
    } catch (_) {
      return r.body;
    }
  }

  Future<List<PrintDataSource>> fetchSources() async {
    final r = await http.get(Uri.parse('$_base/print_form_source'), headers: await _auth.getAuthHeader());
    if (r.statusCode != 200) throw Exception(_msg(r));
    return (jsonDecode(r.body) as List).map((e) => PrintDataSource.fromJson(e)).toList();
  }

  Future<List<PrintDocType>> fetchDocTypes(String source) async {
    final r = await http.get(Uri.parse('$_base/print_form_source/$source/doc_types'), headers: await _auth.getAuthHeader());
    if (r.statusCode != 200) throw Exception(_msg(r));
    return (jsonDecode(r.body) as List).map((e) => PrintDocType.fromJson(e)).toList();
  }

  Future<List<PrintDocRow>> fetchDocs(
    String source, {
    List<int> docIds = const [],
    String? docNoFrom,
    String? docNoTo,
    String? dateFrom,
    String? dateTo,
  }) async {
    final q = <String, String>{
      if (docIds.isNotEmpty) 'doc_ids': docIds.join(','),
      if ((docNoFrom ?? '').isNotEmpty) 'doc_no_from': docNoFrom!,
      if ((docNoTo ?? '').isNotEmpty) 'doc_no_to': docNoTo!,
      if ((dateFrom ?? '').isNotEmpty) 'date_from': dateFrom!,
      if ((dateTo ?? '').isNotEmpty) 'date_to': dateTo!,
    };
    final uri = Uri.parse('$_base/print_form_source/$source/docs').replace(queryParameters: q);
    final r = await http.get(uri, headers: await _auth.getAuthHeader());
    if (r.statusCode != 200) throw Exception(_msg(r));
    return (jsonDecode(r.body) as List).map((e) => PrintDocRow.fromJson(e)).toList();
  }

  // log = true บันทึกประวัติการพิมพ์ (ปุ่มพิมพ์) / false = ดูตัวอย่าง
  Future<PrintData> fetchPrintData(String source, List<String> keys,
      {int? formId, bool log = false, String? copies}) async {
    final r = await http.post(
      Uri.parse('$_base/print_form_source/$source/data'),
      headers: await _auth.getAuthHeader(),
      body: jsonEncode({'keys': keys, 'form_id': formId, 'log': log, 'copies': copies}),
    );
    if (r.statusCode != 200) throw Exception(_msg(r));
    return PrintData.fromJson(jsonDecode(r.body));
  }

  Future<List<PrintForm>> fetchForms({String? dataSource, bool activeOnly = false}) async {
    final uri = Uri.parse('$_base/print_form').replace(queryParameters: {
      if (dataSource != null) 'data_source': dataSource,
      if (activeOnly) 'active': '1',
    });
    final r = await http.get(uri, headers: await _auth.getAuthHeader());
    if (r.statusCode != 200) throw Exception(_msg(r));
    return (jsonDecode(r.body) as List).map((e) => PrintForm.fromJson(e)).toList();
  }

  Future<PrintForm> fetchForm(int id) async {
    final r = await http.get(Uri.parse('$_base/print_form/$id'), headers: await _auth.getAuthHeader());
    if (r.statusCode != 200) throw Exception(_msg(r));
    return PrintForm.fromJson(jsonDecode(r.body));
  }

  Future<PrintForm> saveForm(PrintForm form) async {
    final headers = await _auth.getAuthHeader();
    final body = jsonEncode(form.toJson());
    final r = form.id == null
        ? await http.post(Uri.parse('$_base/print_form'), headers: headers, body: body)
        : await http.put(Uri.parse('$_base/print_form/${form.id}'), headers: headers, body: body);
    if (r.statusCode != 200 && r.statusCode != 201) throw Exception(_msg(r));
    return PrintForm.fromJson(jsonDecode(r.body));
  }

  Future<PrintForm> duplicateForm(int id, String code, String nameTh) async {
    final r = await http.post(
      Uri.parse('$_base/print_form/$id/duplicate'),
      headers: await _auth.getAuthHeader(),
      body: jsonEncode({'form_code': code, 'form_name_th': nameTh}),
    );
    if (r.statusCode != 201) throw Exception(_msg(r));
    return PrintForm.fromJson(jsonDecode(r.body));
  }

  Future<void> deleteForm(int id) async {
    final r = await http.delete(Uri.parse('$_base/print_form/$id'), headers: await _auth.getAuthHeader());
    if (r.statusCode != 200) throw Exception(_msg(r));
  }
}
