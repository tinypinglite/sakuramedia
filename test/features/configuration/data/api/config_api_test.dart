import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';

import '../../../../support/test_api_bundle.dart';

void main() {
  test('GET /config parses the values snapshot', () async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/config',
      body: _configJson(),
    );

    final result = await bundle.configApi.get();

    expect(result.scheduler.crons['download_task_sync'], '* * * * *');
    expect(result.downloads.subscriptionSearchFreshDays, 7);
    expect(result.downloads.subscriptionSearchStaleAttemptLimit, 3);
    expect(result.logging.level, 'INFO');
  });

  test('PATCH /config parses values and restart_required', () async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);
    bundle.adapter.enqueueJson(
      method: 'PATCH',
      path: '/config',
      body: _configJson(
        extra: <String, dynamic>{
          'restart_required': <String>['aps'],
        },
      ),
    );

    final result = await bundle.configApi.patch(const <String, dynamic>{
      'scheduler': <String, dynamic>{'movie_heat_cron': '30 0 * * *'},
    });

    expect(result.restartRequired, <String>['aps']);
    expect(result.values.logging.level, 'INFO');
    final request = bundle.adapter.requests.single;
    expect(request.body, <String, dynamic>{
      'scheduler': <String, dynamic>{'movie_heat_cron': '30 0 * * *'},
    });
  });
}

Map<String, dynamic> _configJson({
  Map<String, dynamic> extra = const <String, dynamic>{},
}) => <String, dynamic>{
  'values': <String, dynamic>{
    'media': <String, dynamic>{
      'allowed_min_video_file_size': 268435456,
    },
    'scheduler': const <String, dynamic>{
      'actor_subscription_sync_cron': '0 2 * * *',
      'subscribed_movie_auto_download_cron': '30 2 * * *',
      'download_task_sync_cron': '* * * * *',
      'download_task_auto_import_cron': '* * * * *',
      'movie_heat_cron': '15 0 * * *',
      'movie_interaction_sync_cron': '0 5 * * *',
      'media_thumbnail_cron': '*/30 * * * *',
      'image_search_index_cron': '*/5 * * * *',
      'movie_similarity_recompute_cron': '30 3 * * *',
      'moment_recommendation_generate_cron': '0 4 * * *',
      'daily_recommendation_generate_cron': '0 5 * * *',
      'activity_cleanup_cron': '30 5 * * *',
    },
    'downloads': <String, dynamic>{
      'subscription_search_fresh_days': 7,
      'subscription_search_stale_attempt_limit': 3,
    },
    'logging': <String, dynamic>{'level': 'INFO'},
  },
  'restart_required': const <String>[],
  ...extra,
};

Future<SessionStore> _buildLoggedInSessionStore() async {
  final store = SessionStore.inMemory();
  await store.saveBaseUrl('https://api.example.com');
  await store.saveTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
  );
  return store;
}
