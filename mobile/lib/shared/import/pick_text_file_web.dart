// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

class PickedTextFile {
  const PickedTextFile({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;

  String get content => utf8.decode(bytes, allowMalformed: true);
}

Future<PickedTextFile?> pickTextFile({
  String accept = '.xls,.csv,.tsv,.txt',
}) async {
  final input = html.FileUploadInputElement()
    ..accept = accept
    ..multiple = false
    ..style.display = 'none';
  html.document.body?.append(input);
  final completer = Completer<PickedTextFile?>();
  var completed = false;

  void cleanup() {
    input.remove();
  }

  void complete(PickedTextFile? file) {
    if (completed) return;
    completed = true;
    cleanup();
    completer.complete(file);
  }

  void completeError(Object error) {
    if (completed) return;
    completed = true;
    cleanup();
    completer.completeError(error);
  }

  input.onChange.first.then((_) {
    final file = input.files?.isEmpty ?? true ? null : input.files!.first;
    if (file == null) {
      complete(null);
      return;
    }
    final reader = html.FileReader();
    reader.onLoad.first.then((_) {
      final buffer = reader.result as ByteBuffer;
      complete(
        PickedTextFile(
          name: file.name,
          bytes: Uint8List.view(buffer).toList(growable: false),
        ),
      );
    });
    reader.onError.first.then((_) => completeError(reader.error!));
    reader.readAsArrayBuffer(file);
  });
  input.addEventListener('cancel', (_) => complete(null));
  input.click();
  Future<void>.delayed(const Duration(minutes: 2)).then((_) => complete(null));
  return completer.future;
}
