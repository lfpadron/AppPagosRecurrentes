import 'dart:convert';

class PickedTextFile {
  const PickedTextFile({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;

  String get content => utf8.decode(bytes, allowMalformed: true);
}

Future<PickedTextFile?> pickTextFile({
  String accept = '.xls,.csv,.tsv,.txt',
}) async {
  return null;
}
