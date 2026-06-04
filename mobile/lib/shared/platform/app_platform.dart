import 'package:flutter/foundation.dart';

bool get isAndroidApp =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
