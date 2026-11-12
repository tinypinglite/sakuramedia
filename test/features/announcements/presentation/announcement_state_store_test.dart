import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/announcements/presentation/announcement_state_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists last seen time and acknowledged critical ids', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = await SharedPreferencesAnnouncementStateStore.create();
    final seenAt = DateTime.utc(2026, 11, 12, 8);

    await store.markSeen(seenAt);
    await store.acknowledge(<String>['critical-1']);

    final reloaded = await SharedPreferencesAnnouncementStateStore.create();
    expect(reloaded.lastSeenAt, seenAt);
    expect(reloaded.acknowledgedIds, contains('critical-1'));
  });

  test('does not move last seen time backwards', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = await SharedPreferencesAnnouncementStateStore.create();
    final later = DateTime.utc(2026, 11, 12, 9);

    await store.markSeen(later);
    await store.markSeen(later.subtract(const Duration(hours: 1)));

    expect(store.lastSeenAt, later);
  });
}
