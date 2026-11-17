String guessImageFileExtension(String fileName, {String fallback = 'webp'}) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) {
    return 'png';
  }
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return 'jpg';
  }
  if (lower.endsWith('.gif')) {
    return 'gif';
  }
  if (lower.endsWith('.webp')) {
    return 'webp';
  }
  return fallback;
}
