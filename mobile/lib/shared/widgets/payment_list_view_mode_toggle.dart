import 'package:flutter/material.dart';

import '../app_preferences.dart';

class PaymentListViewModeToggle extends StatelessWidget {
  const PaymentListViewModeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppPreferences.instance,
      builder: (context, _) {
        final prefs = AppPreferences.instance;
        return SegmentedButton<PaymentListViewMode>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: PaymentListViewMode.cards,
              label: Text('Tarjetas'),
              icon: Icon(Icons.view_agenda_outlined),
            ),
            ButtonSegment(
              value: PaymentListViewMode.table,
              label: Text('Tabla'),
              icon: Icon(Icons.table_rows_outlined),
            ),
          ],
          selected: {prefs.paymentListViewMode},
          onSelectionChanged: (value) {
            prefs.setPaymentListViewMode(value.first);
          },
        );
      },
    );
  }
}
