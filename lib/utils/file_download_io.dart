import 'dart:io';
import 'package:file_selector/file_selector.dart';

Future<String?> downloadFile(List<int> bytes, String filename) async {
  final ext = filename.contains('.') ? filename.split('.').last : '';
  final location = await getSaveLocation(
    suggestedName: filename,
    acceptedTypeGroups: ext.isNotEmpty
        ? [XTypeGroup(label: ext.toUpperCase(), extensions: <String>[ext])]
        : [],
  );
  if (location == null) return null;
  await File(location.path).writeAsBytes(bytes);
  return location.path;
}
