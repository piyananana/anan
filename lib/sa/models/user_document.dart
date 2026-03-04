// models/user_document.dart
class UserDocument {
  final int userId;
  final int docId;

  UserDocument({
    required this.userId,
    required this.docId,
  });

  factory UserDocument.fromJson(Map<String, dynamic> json) {
    return UserDocument(
      userId: json['user_id'],
      docId: json['doc_id'],
    );
  }

  // Add this method for storing in SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'doc_id': docId,
    };
  }

  UserDocument copyWith({
    int? userId,
    int? docId,
  }) {
    return UserDocument(
      userId: userId ?? this.userId,
      docId: docId ?? this.docId,
    );
  }
}
