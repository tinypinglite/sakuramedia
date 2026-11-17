import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/indexer_connection_test_provider.dart';

IndexerConnectionTestResultDto _result({bool healthy = true}) =>
    IndexerConnectionTestResultDto(
      healthy: healthy,
      checkedAt: DateTime.parse('2026-07-11T08:00:00Z'),
      query: 'SSNI-888',
      indexersChecked: 1,
      resultCount: 2,
      elapsedMs: 24,
      error: null,
    );

void main() {
  ProviderContainer createContainer() {
    final container = ProviderContainer(retry: (_, __) => null);
    addTearDown(container.dispose);
    return container;
  }

  test('配置变更使在途结果失效，且不影响其他 UI 实例', () async {
    final container = createContainer();
    final firstScope = Object();
    final secondScope = Object();
    container.listen(indexerConnectionTestProvider(firstScope), (_, _) {});
    container.listen(indexerConnectionTestProvider(secondScope), (_, _) {});
    final first = container.read(
      indexerConnectionTestProvider(firstScope).notifier,
    );
    final completer = Completer<IndexerConnectionTestResultDto>();

    final pending = first.testConnection(() => completer.future);
    expect(
      container.read(indexerConnectionTestProvider(firstScope)).isTesting,
      isTrue,
    );
    first.invalidate();
    completer.complete(_result());

    expect(await pending, isNull);
    expect(
      container.read(indexerConnectionTestProvider(firstScope)).result,
      isNull,
    );
    expect(
      container
          .read(indexerConnectionTestProvider(secondScope))
          .configurationVersion,
      0,
    );
  });

  test('busy 去重，并将失败回写为面板可消费的状态', () async {
    final container = createContainer();
    final scope = Object();
    container.listen(indexerConnectionTestProvider(scope), (_, _) {});
    final notifier = container.read(
      indexerConnectionTestProvider(scope).notifier,
    );
    final completer = Completer<IndexerConnectionTestResultDto>();
    var calls = 0;

    final first = notifier.testConnection(() {
      calls += 1;
      return completer.future;
    });
    expect(await notifier.testConnection(() async => _result()), isNull);
    expect(calls, 1);
    completer.complete(_result());
    expect((await first)?.healthy, isTrue);
    expect(
      container.read(indexerConnectionTestProvider(scope)).result?.healthy,
      isTrue,
    );

    await notifier.testConnection(
      () async => throw StateError('network unavailable'),
    );
    final state = container.read(indexerConnectionTestProvider(scope));
    expect(state.isTesting, isFalse);
    expect(state.result, isNull);
    expect(state.requestError, isNotEmpty);
  });
}
