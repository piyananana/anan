import '../../config/app_config.dart';
// services/sa_user_document_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'sa_auth_service.dart';

class UserDocumentService {
  // final String baseUrl = 'http://localhost:3000/api/sa'; // เปลี่ยนตาม IP ของ Node.js backend
  final String baseUrl = AppConfig.apiSa;
  final AuthService authService = AuthService();

  Future<void> updateRowsByUserId(int headerId, Set<int> newDetailIds) async {
    try {
      final headers = await authService.getAuthHeader();
      final requestBody = jsonEncode({'docIds': newDetailIds.toList()});
      final response = await http.put(
        Uri.parse('$baseUrl/sa_user_document/$headerId'),
        headers: headers,
        body: requestBody
      );

      if (response.statusCode == 200) {
        print('User document updated successfully for User $headerId');
        print('Node.js Response Body: ${response.body}');
      } else {
        print('Failed to update user document: Status ${response.statusCode}, Body: ${response.body}');
        throw Exception('Failed to update user doc: Status ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      print('Error in update User document catch block: $e');
      throw Exception('Network or unknown error during user document update: $e');
    }
  }

  Future<void> deleteRowsByUserId(int headerId) async {
    try {
      final headers = await authService.getAuthHeader();
      final response = await http.delete(
        Uri.parse('$baseUrl/sa_user_document/$headerId'),
        headers: headers,
        body: jsonEncode({'user_id': headerId})
      );

      if (response.statusCode == 204) {
        print('All user document deleted successfully for User $headerId');
      } else if (response.statusCode == 404) {
        print('No user document found for User $headerId to delete.');
      } else {
        throw Exception('Failed to delete user document: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error in delete User document: $e');
      throw Exception('Failed to delete user document: $e');
    }
    
  }
}
