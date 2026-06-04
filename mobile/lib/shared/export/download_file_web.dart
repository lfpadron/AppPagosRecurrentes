// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

Future<bool> downloadBytesFile({
  required String fileName,
  required List<int> bytes,
  required String mimeType,
}) async {
  final blob = html.Blob([Uint8List.fromList(bytes)], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  try {
    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    return true;
  } finally {
    html.Url.revokeObjectUrl(url);
  }
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
