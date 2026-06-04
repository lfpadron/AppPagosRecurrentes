import 'dart:convert';

import 'package:archive/archive.dart';

List<int> buildSimpleXlsx({
  required String sheetName,
  required List<List<Object?>> rows,
}) {
  final archive = Archive();

  void addTextFile(String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  addTextFile('[Content_Types].xml', _contentTypesXml);
  addTextFile('_rels/.rels', _rootRelsXml);
  addTextFile('xl/workbook.xml', _workbookXml(sheetName));
  addTextFile('xl/_rels/workbook.xml.rels', _workbookRelsXml);
  addTextFile('xl/worksheets/sheet1.xml', _worksheetXml(rows));

  return ZipEncoder().encode(archive)!;
}

String _worksheetXml(List<List<Object?>> rows) {
  final maxColumns = rows.fold<int>(
    0,
    (max, row) => row.length > max ? row.length : max,
  );
  final lastCell = maxColumns == 0 || rows.isEmpty
      ? 'A1'
      : '${_columnName(maxColumns)}${rows.length}';
  final buffer = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write(
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
    )
    ..write('<dimension ref="A1:$lastCell"/>')
    ..write('<sheetViews><sheetView workbookViewId="0">')
    ..write(
      '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>',
    )
    ..write('</sheetView></sheetViews>')
    ..write('<sheetData>');

  for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
    final rowNumber = rowIndex + 1;
    buffer.write('<row r="$rowNumber">');
    for (var columnIndex = 0; columnIndex < maxColumns; columnIndex++) {
      final value = columnIndex < rows[rowIndex].length
          ? rows[rowIndex][columnIndex]
          : null;
      final cellRef = '${_columnName(columnIndex + 1)}$rowNumber';
      buffer.write(
        '<c r="$cellRef" t="inlineStr"><is><t xml:space="preserve">${_xmlEscape(_cellText(value))}</t></is></c>',
      );
    }
    buffer.write('</row>');
  }

  if (rows.isNotEmpty && maxColumns > 0) {
    buffer.write('<autoFilter ref="A1:$lastCell"/>');
  }
  buffer.write('</sheetData></worksheet>');
  return buffer.toString();
}

String _workbookXml(String sheetName) {
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets><sheet name="${_xmlEscape(_safeSheetName(sheetName))}" sheetId="1" r:id="rId1"/></sheets>'
      '</workbook>';
}

String _safeSheetName(String value) {
  final sanitized = value.replaceAll(RegExp(r'[\[\]\*\?/\\:]'), ' ').trim();
  if (sanitized.isEmpty) return 'Datos';
  return sanitized.length > 31 ? sanitized.substring(0, 31) : sanitized;
}

String _cellText(Object? value) => value?.toString() ?? '';

String _columnName(int columnNumber) {
  var number = columnNumber;
  final chars = <String>[];
  while (number > 0) {
    number--;
    chars.insert(0, String.fromCharCode(65 + (number % 26)));
    number ~/= 26;
  }
  return chars.join();
}

String _xmlEscape(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

const _contentTypesXml =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
    '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
    '</Types>';

const _rootRelsXml =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
    '</Relationships>';

const _workbookRelsXml =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
    '</Relationships>';
