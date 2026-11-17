import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/media/data/media_tags_api.dart';

part 'media_tags_api_provider.g.dart';

@Riverpod(keepAlive: true)
MediaTagsApi mediaTagsApi(Ref ref) {
  return MediaTagsApi(apiClient: ref.watch(apiClientProvider));
}
