import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_rapid_upload_history_provider.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/rapid_upload_history_section.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../support/test_api_bundle.dart';

void main() {
  testWidgets('virtualizes accumulated rapid upload batches', (tester) async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    const itemCount = 80;
    const pageSize = 20;
    for (var page = 1; page <= itemCount ~/ pageSize; page++) {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/rapid-uploads',
        body: <String, dynamic>{
          'items': List<Map<String, dynamic>>.generate(
            pageSize,
            (index) => _batchJson((page - 1) * pageSize + index + 1),
          ),
          'page': page,
          'page_size': pageSize,
          'total': itemCount,
        },
      );
    }
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-libraries',
      body: const <Map<String, dynamic>>[],
    );

    await _pumpSection(tester, sessionStore, bundle);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(RapidUploadHistorySection)),
    );
    for (var page = 2; page <= itemCount ~/ pageSize; page++) {
      await tester.runAsync(
        () =>
            container.read(mediaRapidUploadHistoryProvider.notifier).loadMore(),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(
      container.read(mediaRapidUploadHistoryProvider).requireValue.items,
      hasLength(itemCount),
    );
    expect(find.byKey(const Key('rapid-upload-batch-card-80')), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const Key('rapid-upload-batch-card-80')),
      600,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rapid-upload-batch-card-80')), findsOneWidget);
    expect(find.byKey(const Key('rapid-upload-batch-card-1')), findsNothing);
  });

  testWidgets('shows batch details in a bounded virtualized dialog', (
    tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/rapid-uploads',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[_batchJson(42, totalCount: 100)],
        'page': 1,
        'page_size': 20,
        'total': 1,
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-libraries',
      body: const <Map<String, dynamic>>[],
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/rapid-uploads/42',
      body: <String, dynamic>{
        ..._batchJson(42, totalCount: 100),
        'items': List<Map<String, dynamic>>.generate(
          100,
          (index) => _batchItemJson(index + 1),
        ),
      },
    );

    await _pumpSection(tester, sessionStore, bundle);
    await tester.tap(find.byKey(const Key('rapid-upload-batch-toggle-42')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('rapid-upload-batch-detail-dialog-42')),
      findsOneWidget,
    );
    final listFinder = find.byKey(
      const Key('rapid-upload-batch-detail-list-42'),
    );
    expect(listFinder, findsOneWidget);
    expect(find.byKey(const Key('rapid-upload-item-100')), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const Key('rapid-upload-item-100')),
      400,
      scrollable: find.descendant(
        of: listFinder,
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rapid-upload-item-100')), findsOneWidget);
    expect(find.byKey(const Key('rapid-upload-item-1')), findsNothing);
  });
}

Future<void> _pumpSection(
  WidgetTester tester,
  SessionStore sessionStore,
  TestApiBundle bundle,
) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final scrollController = ScrollController();
  addTearDown(scrollController.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
      ],
      child: ProviderScope(
        overrides: [
          mediaApiProvider.overrideWithValue(bundle.mediaApi),
          mediaLibrariesApiProvider.overrideWithValue(bundle.mediaLibrariesApi),
        ],
        child: MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: RapidUploadHistorySection(
              scrollController: scrollController,
              retryingBatchId: null,
              onRetry: (_) async {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Map<String, dynamic> _batchJson(int id, {int totalCount = 1}) {
  return <String, dynamic>{
    'id': id,
    'target_library_id': 8,
    'retry_of_batch_id': null,
    'task_run_id': 99,
    'state': 'completed',
    'total_count': totalCount,
    'succeeded_count': totalCount,
    'failed_count': 0,
    'cleanup_failed_count': 0,
    'started_at': '2026-03-12T10:00:00Z',
    'finished_at': '2026-03-12T10:05:00Z',
    'created_at': '2026-03-12T09:59:00Z',
    'updated_at': '2026-03-12T10:05:00Z',
  };
}

Map<String, dynamic> _batchItemJson(int id) {
  return <String, dynamic>{
    'id': id,
    'media_id': id,
    'action': 'rapid_upload',
    'state': 'succeeded',
    'source_path': '/library/main/$id.mp4',
    'source_size_bytes': 100,
    'source_sha1': 'sha1-$id',
    'target_fid': 'fid-$id',
    'target_pickcode': 'pickcode-$id',
    'target_name': '$id.mp4',
    'error_message': null,
    'started_at': '2026-03-12T10:00:00Z',
    'finished_at': '2026-03-12T10:01:00Z',
    'created_at': '2026-03-12T09:59:00Z',
    'updated_at': '2026-03-12T10:01:00Z',
  };
}
