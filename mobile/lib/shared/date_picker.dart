import 'package:flutter/material.dart';

import 'app_preferences.dart';
import 'formatters.dart';

Future<DateTime?> pickAppDate(
  BuildContext context, {
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  return showDatePicker(
    context: context,
    firstDate: firstDate ?? DateTime(2020),
    lastDate: lastDate ?? DateTime(2040),
    initialDate: initialDate ?? dateOnly(DateTime.now()),
    locale: AppPreferences.instance.datePickerLocale,
  );
}
