import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/controllers/indexer_connection_test_controller.dart';

IndexerConnectionTestResultDto _result({bool healthy = true}) {
  return IndexerConnectionTestResultDto(
    healthy: healthy,
    checkedAt: DateTime.parse('2026-07-11T08:00:00Z'),
    query: 'SSNI-888',
    indexersChecked: 1,
    resultCount: 2,
    elapsedMs: 24,
    error: null,
  );
}

void main() {
  test(
    'configuration invalidation discards an in-flight stale result',
    () async {
      final completer = Completer<IndexerConnectionTestResultDto>();
      final controller = IndexerConnectionTestController(
        runTest: () => completer.future,
      );
      addTearDown(controller.dispose);

      final pending = controller.testConnection();
      expect(controller.isTesting, isTrue);

      controller.invalidate();
      completer.complete(_result());

      expect(await pending, isNull);
      expect(controller.isTesting, isFalse);
      expect(controller.result, isNull);
      expect(controller.requestError, isNull);
    },
  );

  test('only starts one connection request while another is running', () async {
    final completer = Completer<IndexerConnectionTestResultDto>();
    var requestCount = 0;
    final controller = IndexerConnectionTestController(
      runTest: () {
        requestCount += 1;
        return completer.future;
      },
    );
    addTearDown(controller.dispose);

    final first = controller.testConnection();
    final second = controller.testConnection();

    expect(await second, isNull);
    expect(requestCount, 1);
    completer.complete(_result());
    expect((await first)?.healthy, isTrue);
    expect(controller.result?.healthy, isTrue);
  });

  test('request failure stays in state for the shared result panel', () async {
    final controller = IndexerConnectionTestController(
      runTest: () async => throw StateError('network unavailable'),
    );
    addTearDown(controller.dispose);

    expect(await controller.testConnection(), isNull);
    expect(controller.isTesting, isFalse);
    expect(controller.result, isNull);
    expect(controller.requestError, isNotEmpty);
  });
}
