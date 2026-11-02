import 'dart:convert';

import 'package:sakuramedia/features/configuration/data/dto/provider_catalog_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_login_dto.dart';

bool isAllowedProviderLoginUri(Uri uri, List<String> allowedHosts) {
  return uri.scheme == 'https' && _providerLoginHostAllowed(uri, allowedHosts);
}

bool isAllowedProviderLoginHttpUri(Uri uri, List<String> allowedHosts) {
  return uri.scheme == 'http' && _providerLoginHostAllowed(uri, allowedHosts);
}

bool _providerLoginHostAllowed(Uri uri, List<String> allowedHosts) {
  if (uri.host.isEmpty || uri.userInfo.isNotEmpty) return false;
  final host = uri.host.toLowerCase();
  for (final allowed in allowedHosts) {
    final normalized = allowed.toLowerCase();
    if (host == normalized || host.endsWith('.$normalized')) {
      return true;
    }
  }
  return false;
}

Map<String, String> selectProviderLoginCookies(
  Iterable<(String, String)> cookies,
  Iterable<String> names,
) {
  final selectedNames = names.toSet();
  return <String, String>{
    for (final (name, value) in cookies)
      if (selectedNames.contains(name) && value.isNotEmpty) name: value,
  };
}

bool providerLoginCookieCaptureSatisfied(
  ProviderLoginCookieCaptureDto capture,
  Map<String, String> values,
) {
  return capture.requiredNames.every((name) => (values[name] ?? '').isNotEmpty);
}

Map<String, String> decodeProviderLoginLocalStorage(Object? raw) {
  if (raw is String) {
    try {
      return decodeProviderLoginLocalStorage(jsonDecode(raw));
    } on FormatException {
      return const <String, String>{};
    }
  }
  if (raw is! Map) {
    return const <String, String>{};
  }
  return <String, String>{
    for (final entry in raw.entries)
      if (entry.key is String && entry.value is String)
        entry.key as String: entry.value as String,
  };
}

bool providerLoginStorageCaptureSatisfied(
  ProviderLoginLocalStorageCaptureDto capture,
  Map<String, String> items,
) {
  if (capture.requiredJsonKeys.isEmpty) {
    return items.isNotEmpty;
  }
  final found = <String>{};
  for (final value in items.values) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        found.addAll(
          capture.requiredJsonKeys.where((key) {
            final value = decoded[key];
            return value is String && value.isNotEmpty;
          }),
        );
      }
    } on FormatException {
      continue;
    }
  }
  return capture.requiredJsonKeys.every(found.contains);
}

bool isProviderLoginCaptureComplete({
  required ProviderLoginDto login,
  required Map<String, Map<String, String>> cookiesByUrl,
  required Map<String, Map<String, String>> localStorageByOrigin,
}) {
  return login.cookieCaptures.every(
        (capture) => providerLoginCookieCaptureSatisfied(
          capture,
          cookiesByUrl[capture.url] ?? const <String, String>{},
        ),
      ) &&
      login.localStorageCaptures.every(
        (capture) => providerLoginStorageCaptureSatisfied(
          capture,
          localStorageByOrigin[capture.origin] ?? const <String, String>{},
        ),
      );
}

List<ProviderLoginCookieSetPayload> buildProviderLoginCookiePayloads(
  ProviderLoginDto login,
  Map<String, Map<String, String>> cookiesByUrl,
) {
  return <ProviderLoginCookieSetPayload>[
    for (final capture in login.cookieCaptures)
      ProviderLoginCookieSetPayload(
        url: capture.url,
        values: <String, String>{
          for (final name in capture.captureNames)
            if ((cookiesByUrl[capture.url]?[name] ?? '').isNotEmpty)
              name: cookiesByUrl[capture.url]![name]!,
        },
      ),
  ];
}

List<ProviderLoginLocalStorageSetPayload>
buildProviderLoginLocalStoragePayloads(
  ProviderLoginDto login,
  Map<String, Map<String, String>> localStorageByOrigin,
) {
  return <ProviderLoginLocalStorageSetPayload>[
    for (final capture in login.localStorageCaptures)
      ProviderLoginLocalStorageSetPayload(
        origin: capture.origin,
        items: localStorageByOrigin[capture.origin] ?? const <String, String>{},
      ),
  ];
}
