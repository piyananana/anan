import 'dart:io';
import 'package:file_selector/file_selector.dart';

Future<String?> downloadFile(List<int> bytes, String filename) async {
  final location = await getSaveLocation(
    suggestedName: filename,
    acceptedTypeGroups: [
      const XTypeGroup(label: 'Excel', extensions: <String>['xlsx']),
    ],
  );
  if (location == null) return null;
  await File(location.path).writeAsBytes(bytes);
  return location.path;
}
