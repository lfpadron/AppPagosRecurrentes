import 'dart:convert';

import 'package:file_picker/file_picker.dart';

class PickedTextFile {
  const PickedTextFile({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;

  String get content => utf8.decode(bytes, allowMalformed: true);
}

Future<PickedTextFile?> pickTextFile({String accept = '.xls,.xlsx'}) async {
  final extensions = accept
      .split(',')
      .map((value) => value.trim().replaceFirst('.', '').toLowerCase())
      .where((value) => value.isNotEmpty)
      .toList();
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: extensions,
    allowMultiple: false,
    withData: true,
    cancelUploadOnWindowBlur: false,
  );
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.single;
  final bytes = file.bytes;
  if (bytes == null) {
    throw const FormatException('No se pudo leer el archivo seleccionado.');
  }
  return PickedTextFile(name: file.name, bytes: bytes);
}
