bool isValidHttpUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
      uri.hasScheme &&
      uri.hasAuthority &&
      (uri.scheme == 'http' || uri.scheme == 'https');
}
