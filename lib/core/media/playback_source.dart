const String playbackProviderKeyExtraKey = 'sakuramedia.playbackProviderKey';

const String cloud115PlaybackProviderKey = 'cloud115';
const String localPlaybackProviderKey = 'local';
const String guangyapanPlaybackProviderKey = 'guangyapan';

String? playbackProviderKeyFromExtras(Map<String, dynamic>? extras) {
  final value = extras?[playbackProviderKeyExtraKey];
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}

Map<String, dynamic>? playbackExtrasForProvider(
  String? providerKey, {
  Map<String, dynamic>? extras,
}) {
  final normalized = providerKey?.trim();
  if (normalized == null || normalized.isEmpty) {
    return extras;
  }
  return <String, dynamic>{...?extras, playbackProviderKeyExtraKey: normalized};
}
