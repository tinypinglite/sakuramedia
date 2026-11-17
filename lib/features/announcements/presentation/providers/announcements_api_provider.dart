import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/announcements/data/announcements_api.dart';

part 'announcements_api_provider.g.dart';

@Riverpod(keepAlive: true)
AnnouncementsApi announcementsApi(Ref ref) {
  return AnnouncementsApi(apiClient: ref.watch(apiClientProvider));
}
