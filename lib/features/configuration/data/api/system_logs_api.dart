import 'dart:typed_data';

import 'package:sakuramedia/core/network/api_client.dart';

enum SystemLogRange {
  lastHour('1h'),
  last24Hours('24h'),
  last7Days('7d'),
  last30Days('30d');

  const SystemLogRange(this.apiValue);

  final String apiValue;
}

class SystemLogsApi {
  const SystemLogsApi({required ApiClient apiClient}) : _apiClient = apiClient;

  static const _downloadTimeout = Duration(minutes: 2);

  final ApiClient _apiClient;

  Future<Uint8List> downloadArchive({
    required SystemLogRange range,
    required bool redactSensitive,
  }) {
    return _apiClient.getBytes(
      '/system/logs/archive',
      queryParameters: <String, dynamic>{
        'range': range.apiValue,
        'redact_sensitive': redactSensitive,
      },
      receiveTimeout: _downloadTimeout,
    );
  }
}
