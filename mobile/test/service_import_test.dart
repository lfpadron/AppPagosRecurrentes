import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagos_recurrentes_mobile/features/services/data/service_account.dart';
import 'package:pagos_recurrentes_mobile/features/services/data/services_api.dart';
import 'package:pagos_recurrentes_mobile/features/services/presentation/service_import_dialog.dart';
import 'package:pagos_recurrentes_mobile/features/services/presentation/services_page.dart';

void main() {
  test('service import detects duplicates and new rows from exported TSV', () {
    const content =
        'id\tactive\tstatus\ticon_key\tobject_name\tservice_name\tprovider_name\tservice_number\tprovider_url\tis_autopay\tcharge_account\tinitial_cutoff_date\tinitial_due_date\tweekend_adjustment\tfrequency\tinterval_count\testimated_amount\tcurrency\tnotes\n'
        '1\ttrue\tactive\tservice_default\tCasa\tInternet\tProveedor\tA1\t\tfalse\t\t\t2026-01-30\tnone\tmonthly\t1\t900\tMXN\t\n'
        '2\ttrue\tactive\tservice_default\tCasa\tGas\tProveedor\tA2\t\tfalse\t\t\t2026-02-15\tnone\tmonthly\t1\t300\tMXN\t';
    final existing = [
      ServiceAccount(
        id: 'existing-1',
        userId: 'user-1',
        active: true,
        status: ServiceLifecycleStatus.active,
        iconKey: 'service_default',
        objectName: 'casa',
        serviceName: 'internet',
        providerName: 'proveedor',
        serviceNumber: 'old',
        isAutopay: false,
        initialDueDate: DateTime(2026, 1, 30),
        weekendAdjustment: WeekendAdjustment.none,
        frequency: Frequency.monthly,
        intervalCount: 1,
        currency: 'MXN',
        version: 1,
      ),
    ];

    final rows = parseServiceImportContent(content, existing);

    expect(rows, hasLength(2));
    expect(rows.first.isDuplicate, isTrue);
    expect(rows.first.decision, isNull);
    expect(rows.last.isDuplicate, isFalse);
    expect(rows.last.decision, ServiceImportDecision.create);
    expect(rows.last.draft.serviceName, 'Gas');
  });

  test('service import parses exported xls bytes', () {
    const content =
        'object_name\tservice_name\tprovider_name\tinitial_due_date\tfrequency\tinterval_count\testimated_amount\tcurrency\n'
        'Casa\tColegiatura\tEscuela Águila\t2026-05-17\tmonthly\t1\t1200\tMXN';

    final rows = parseServiceImportFile(
      fileName: 'servicios.xls',
      bytes: utf8.encode(content),
      existingServices: const [],
    );

    expect(rows, hasLength(1));
    expect(rows.single.decision, ServiceImportDecision.create);
    expect(rows.single.draft.providerName, 'Escuela Águila');
    expect(rows.single.draft.estimatedAmount, 1200);
  });

  test('service import parses app generated xlsx export bytes', () {
    final service = ServiceAccount(
      id: 'service-1',
      userId: 'user-1',
      active: true,
      status: ServiceLifecycleStatus.active,
      iconKey: 'service_default',
      objectName: 'Casa',
      serviceName: 'Colegiatura',
      providerName: 'Escuela Águila',
      serviceNumber: 'A-123',
      isAutopay: false,
      initialDueDate: DateTime(2026, 5, 17),
      weekendAdjustment: WeekendAdjustment.none,
      frequency: Frequency.monthly,
      intervalCount: 1,
      estimatedAmount: 1200.5,
      currency: 'MXN',
      version: 1,
    );

    final rows = parseServiceImportFile(
      fileName: 'servicios.xlsx',
      bytes: buildServicesXlsx([service]),
      existingServices: const [],
    );

    expect(rows, hasLength(1));
    expect(rows.single.decision, ServiceImportDecision.create);
    expect(rows.single.draft.objectName, 'Casa');
    expect(rows.single.draft.providerName, 'Escuela Águila');
    expect(rows.single.draft.estimatedAmount, 1200.5);
    expect(rows.single.draft.currency, 'MXN');
  });

  test('service import only accepts Excel file names', () {
    expect(isSupportedServiceImportFileName('servicios.xls'), isTrue);
    expect(isSupportedServiceImportFileName('servicios.XLSX'), isTrue);
    expect(isSupportedServiceImportFileName('servicios.csv'), isFalse);
    expect(isSupportedServiceImportFileName('servicios.txt'), isFalse);
  });

  testWidgets('service import review dialog has a stable bounded layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final existing = ServiceAccount(
      id: 'existing-1',
      userId: 'user-1',
      active: true,
      status: ServiceLifecycleStatus.active,
      iconKey: 'service_default',
      objectName: 'Casa',
      serviceName: 'Internet',
      providerName: 'Proveedor',
      serviceNumber: 'old',
      isAutopay: false,
      initialDueDate: DateTime(2026, 1, 30),
      weekendAdjustment: WeekendAdjustment.none,
      frequency: Frequency.monthly,
      intervalCount: 1,
      estimatedAmount: 900,
      currency: 'MXN',
      version: 1,
    );
    final duplicateDraft = ServiceDraft(
      objectName: 'Casa',
      serviceName: 'Internet',
      providerName: 'Proveedor',
      serviceNumber: 'new',
      initialDueDate: DateTime(2026, 1, 30),
      frequency: Frequency.monthly,
      intervalCount: 1,
      estimatedAmount: 950,
      isAutopay: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (context) => ServiceImportReviewDialog(
                      rows: [
                        ServiceImportRow(
                          rowNumber: 2,
                          draft: duplicateDraft,
                          existing: existing,
                          decision: null,
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Abrir importacion'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir importacion'));
    await tester.pumpAndSettle();

    expect(find.text('Importar servicios'), findsOneWidget);
    expect(find.text('Actual'), findsOneWidget);
    expect(find.text('Archivo'), findsOneWidget);
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
