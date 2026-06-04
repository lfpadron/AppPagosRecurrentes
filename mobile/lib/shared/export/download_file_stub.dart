import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<bool> downloadBytesFile({
  required String fileName,
  required List<int> bytes,
  required String mimeType,
}) async {
  final extension = fileName.contains('.')
      ? fileName.split('.').last.toLowerCase()
      : null;
  final path = await FilePicker.saveFile(
    dialogTitle: 'Guardar archivo',
    fileName: fileName,
    type: extension == null ? FileType.any : FileType.custom,
    allowedExtensions: extension == null ? null : [extension],
    bytes: Uint8List.fromList(bytes),
  );
  return path != null;
}

Future<bool> downloadTextFile({
  required String fileName,
  required String content,
  required String mimeType,
}) async {
  return downloadBytesFile(
    fileName: fileName,
    bytes: utf8.encode(content),
    mimeType: mimeType,
  );
}
