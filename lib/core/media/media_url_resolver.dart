import 'dart:convert';
import 'dart:math';

String? resolveMediaUrl({required String? rawUrl, required String baseUrl}) {
  final normalizedRawUrl = rawUrl?.trim() ?? '';
  if (normalizedRawUrl.isEmpty) {
    return null;
  }

  final parsedUrl = Uri.tryParse(normalizedRawUrl);
  if (parsedUrl != null && parsedUrl.hasScheme) {
    return normalizedRawUrl;
  }

  final normalizedBaseUrl = baseUrl.trim();
  if (normalizedBaseUrl.isEmpty) {
    return null;
  }

  final base =
      normalizedBaseUrl.endsWith('/')
          ? normalizedBaseUrl.substring(0, normalizedBaseUrl.length - 1)
          : normalizedBaseUrl;
  final path =
      normalizedRawUrl.startsWith('/')
          ? normalizedRawUrl.substring(1)
          : normalizedRawUrl;

  return '$base/$path';
}

String withPlaybackAttemptId(String url, [String? attemptId]) {
  attemptId ??= base64UrlEncode(
    List<int>.generate(16, (_) => _playbackAttemptRandom.nextInt(256)),
  ).replaceAll('=', '');
  final uri = Uri.tryParse(url);
  if (uri == null || attemptId.isEmpty) {
    return url;
  }
  return uri
      .replace(
        queryParameters: <String, String>{
          ...uri.queryParameters,
          'playback_attempt_id': attemptId,
        },
      )
      .toString();
}

final _playbackAttemptRandom = Random.secure();
