import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/announcements/presentation/announcement_state_store.dart';

part 'announcement_state_store_provider.g.dart';

/// 公告已读/已确认状态。生产在应用组合根注入 SharedPreferences 实现。
@Riverpod(keepAlive: true)
AnnouncementStateStore announcementStateStore(Ref ref) {
  return InMemoryAnnouncementStateStore();
}
