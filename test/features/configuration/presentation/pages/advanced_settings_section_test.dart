import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/advanced_settings_section.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../support/logged_in_session_store.dart';
import '../../../../support/preview_helpers.dart';
import '../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    sessionStore = await buildLoggedInSessionStore();
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  testWidgets('renders all advanced settings cards after loading config', (
    tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/config',
      body: _configJson(),
    );

    await pumpPreviewApp(
      tester,
      home: const DesktopAdvancedSettingsSection(active: true),
      size: const Size(1100, 900),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
      wrap: (child) => SingleChildScrollView(child: child),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('configuration-advanced-media-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('configuration-advanced-scheduler-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key('configuration-advanced-cron-actor_subscription_sync-field'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('configuration-advanced-other-card')),
      findsOneWidget,
    );
    expect(bundle.adapter.hitCount('GET', '/config'), 1);
    expect(tester.takeException(), isNull);
  });
}

Map<String, dynamic> _configJson() => <String, dynamic>{
  'values': <String, dynamic>{
    'media': <String, dynamic>{'allowed_min_video_file_size': 268435456},
    'scheduler': <String, dynamic>{
      'worker_default_concurrency': 4,
      'actor_subscription_sync_cron': '0 2 * * *',
      'subscribed_movie_auto_download_cron': '30 2 * * *',
      'download_task_sync_cron': '* * * * *',
      'download_task_auto_import_cron': '* * * * *',
      'movie_stats_sync_cron': '0 5 * * *',
      'media_file_hash_backfill_cron': '0 3 * * *',
      'media_file_scan_cron': '0 4 * * *',
      'media_thumbnail_cron': '*/30 * * * *',
      'image_search_index_cron': '*/5 * * * *',
      'movie_similarity_recompute_cron': '30 3 * * *',
      'moment_recommendation_generate_cron': '0 4 * * *',
      'daily_recommendation_generate_cron': '0 5 * * *',
      'activity_cleanup_cron': '30 5 * * *',
      'gfriends_filetree_refresh_cron': '0 4 * * 1',
    },
    'downloads': <String, dynamic>{
      'subscription_search_fresh_days': 7,
      'subscription_search_stale_attempt_limit': 3,
    },
    'logging': <String, dynamic>{'level': 'INFO'},
  },
  'restart_required': const <String>[],
};
