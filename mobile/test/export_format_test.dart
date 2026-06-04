import 'package:flutter_test/flutter_test.dart';
import 'package:pagos_recurrentes_mobile/shared/export/export_format.dart';

void main() {
  test('export file names include local date time suffix', () {
    final name = exportFileName(
      'servicios',
      'csv',
      now: DateTime(2026, 5, 15, 9, 8, 7),
    );

    expect(name, 'servicios_20260515_090807.csv');
  });

  test('spreadsheet exports add UTF-8 BOM once', () {
    expect(withUtf8Bom('áéíóú'), '\ufeffáéíóú');
    expect(withUtf8Bom('\ufeffáéíóú'), '\ufeffáéíóú');
  });
}
