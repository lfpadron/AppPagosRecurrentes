String exportFileName(String baseName, String extension, {DateTime? now}) {
  return '${baseName}_${exportTimestampSuffix(now: now)}.$extension';
}

String exportTimestampSuffix({DateTime? now}) {
  final value = now ?? DateTime.now();
  final date = [
    value.year.toString().padLeft(4, '0'),
    value.month.toString().padLeft(2, '0'),
    value.day.toString().padLeft(2, '0'),
  ].join();
  final time = [
    value.hour.toString().padLeft(2, '0'),
    value.minute.toString().padLeft(2, '0'),
    value.second.toString().padLeft(2, '0'),
  ].join();
  return '${date}_$time';
}

String withUtf8Bom(String content) {
  return content.startsWith('\ufeff') ? content : '\ufeff$content';
}

String utf8Mime(String mimeType) => '$mimeType; charset=utf-8';
