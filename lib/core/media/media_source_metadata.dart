const String originalMediaUriExtraKey = 'sakuramedia.originalMediaUri';

String? originalMediaUriFromExtras(Map<String, dynamic>? extras) {
  final value = extras?[originalMediaUriExtraKey];
  return value is String && value.isNotEmpty ? value : null;
}
