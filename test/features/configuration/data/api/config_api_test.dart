import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/dto/config_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';

import '../../../../support/test_api_bundle.dart';

void main() {
  group('ConfigApi', () {
    test('gets only advanced config sections from /config', () async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);

      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/config',
        body: _buildConfigResourceJson(),
      );

      final resource = await bundle.configApi.get();

      expect(resource.media.othersNumberFeatures, contains('OFJE'));
      expect(resource.media.allowedMinVideoFileSize, 268435456);
      expect(resource.metadata.javdbHost, 'jdforrepam.com');
      expect(resource.scheduler.crons['download_task_sync'], '* * * * *');
      expect(resource.downloads.smallFileCleanupThresholdMb, 256);
      expect(resource.downloads.preferredClientKinds, <DownloadClientKind>[
        DownloadClientKind.qbittorrent,
        DownloadClientKind.cloud115,
      ]);
      expect(resource.logging.level, 'INFO');
      expect(resource.effects['media'], 'hot');
      expect(resource.effects.containsKey('database'), isFalse);
      expect(resource.effects.containsKey('image_search'), isFalse);
      expect(bundle.adapter.hitCount('GET', '/config'), 1);
    });

    test('patches partial config and parses restart metadata', () async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);

      bundle.adapter.enqueueJson(
        method: 'PATCH',
        path: '/config',
        body: _buildConfigResourceJson(
          includeEffects: false,
          extra: <String, dynamic>{
            'applied': <String>['scheduler.movie_heat_cron'],
            'pending_restart': <Map<String, dynamic>>[
              <String, dynamic>{
                'field': 'scheduler.movie_heat_cron',
                'restart': 'scheduler',
              },
            ],
          },
        ),
      );

      final result = await bundle.configApi.patch(const <String, dynamic>{
        'scheduler': <String, dynamic>{'movie_heat_cron': '30 0 * * *'},
      });

      expect(result.applied, contains('scheduler.movie_heat_cron'));
      expect(result.pendingRestart.single.field, 'scheduler.movie_heat_cron');
      expect(result.pendingRestart.single.restart, 'scheduler');
      final request = bundle.adapter.requests.single;
      expect(request.method, 'PATCH');
      expect(request.path, '/config');
      expect(request.body.keys, contains('scheduler'));
      expect(request.body.keys, isNot(contains('media')));
      expect(request.body['scheduler']['movie_heat_cron'], '30 0 * * *');
    });

    test('throws when a target section is missing', () async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);

      final body = _buildConfigResourceJson();
      final values = body['values'] as Map<String, dynamic>;
      values.remove('scheduler');
      bundle.adapter.enqueueJson(method: 'GET', path: '/config', body: body);

      await expectLater(
        bundle.configApi.get(),
        throwsA(isA<FormatException>()),
      );
    });

    // 回归：后端删掉 media.collection_duration_threshold_minutes 之后，只读
    // downloads 一节的「下载偏好」页也被整包解析异常拖成「加载失败」。字段级
    // 缺失必须降级成默认值，不能连坐其它节。
    test('tolerates unknown field removal inside a section', () async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);

      final body = _buildConfigResourceJson();
      final values = body['values'] as Map<String, dynamic>;
      (values['media'] as Map<String, dynamic>)
        ..remove('allowed_min_video_file_size')
        ..remove('uncensored_tags');
      (values['logging'] as Map<String, dynamic>).remove('level');
      (values['scheduler'] as Map<String, dynamic>).remove('movie_heat_cron');
      bundle.adapter.enqueueJson(method: 'GET', path: '/config', body: body);

      final result = await bundle.configApi.get();

      // 缺失字段降级成默认值……
      expect(result.media.allowedMinVideoFileSize, 0);
      expect(result.media.uncensoredTags, isEmpty);
      expect(result.logging.level, 'INFO');
      expect(result.scheduler.crons.containsKey('movie_heat'), isFalse);
      // ……同节其它字段与其它节完全不受影响。
      expect(result.media.othersNumberFeatures, <String>['OFJE', 'CJOB']);
      expect(result.downloads.smallFileCleanupThresholdMb, 256);
      expect(result.downloads.preferredClientKinds, <DownloadClientKind>[
        DownloadClientKind.qbittorrent,
        DownloadClientKind.cloud115,
      ]);
    });
  });
}

Map<String, dynamic> _buildConfigResourceJson({
  bool includeEffects = true,
  Map<String, dynamic> extra = const <String, dynamic>{},
}) {
  return <String, dynamic>{
    'values': <String, dynamic>{
      'media': <String, dynamic>{
        'others_number_features': <String>['OFJE', 'CJOB'],
        'inner_sub_tags': <String>['中字', '-C'],
        'blueray_tags': <String>['蓝光', '4K'],
        'uncensored_tags': <String>['uncensored', '-UC'],
        'uncensored_prefix': <String>['PT-', 'S2M'],
        'allowed_min_video_file_size': 268435456,
      },
      'metadata': <String, dynamic>{
        'javdb_host': 'jdforrepam.com',
        'javdb_username': 'alice',
        'javdb_password': '',
        'proxy': 'http://127.0.0.1:7890',
      },
      'scheduler': <String, dynamic>{
        for (final key in AdvancedSchedulerConfigDto.cronKeys)
          '${key}_cron':
              key == 'download_task_sync' ? '* * * * *' : '0 2 * * *',
      },
      'downloads': <String, dynamic>{
        'small_file_cleanup_threshold_mb': 256,
        'preferred_client_kinds': <String>['qbittorrent', 'cloud115'],
      },
      'logging': <String, dynamic>{'level': 'INFO'},
      'database': <String, dynamic>{
        'url': 'postgresql://user:password@postgres:5432/sakuramedia',
      },
      'image_search': <String, dynamic>{'inference_api_key': 'secret'},
    },
    if (includeEffects)
      'effects': <String, dynamic>{
        'media': 'hot',
        'metadata': 'hot',
        'scheduler': 'restart_scheduler',
        'downloads': 'restart_scheduler',
        'logging': 'restart_api',
        'database': 'restart_api',
        'image_search': 'restart_scheduler',
      },
    ...extra,
  };
}

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
