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
