import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/shared/presentation/providers/optimistic_patch_mixin.dart';

class _Row {
  const _Row(this.id, {this.on = false});

  final int id;
  final bool on;

  _Row flip() => _Row(id, on: !on);

  @override
  String toString() => 'Row($id, on=$on)';
}

class _ToggleState {
  const _ToggleState(this.rows);

  final List<_Row> rows;

  _ToggleState flip(int id) => _ToggleState(
    List<_Row>.unmodifiable(
      rows.map((row) => row.id == id ? row.flip() : row),
    ),
  );

  bool onOf(int id) => rows.firstWhere((row) => row.id == id).on;

  _Row rowOf(int id) => rows.firstWhere((row) => row.id == id);

  /// 按 original 逐项恢复 keys 里的行（模拟订阅场景的精准回滚）。
  _ToggleState restoreFrom(
    _ToggleState original,
    Set<int> keys,
  ) {
    final byId = <int, _Row>{for (final row in original.rows) row.id: row};
    return _ToggleState(
      List<_Row>.unmodifiable(
        rows.map((row) => keys.contains(row.id) ? byId[row.id]! : row),
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _ToggleState) return false;
    if (rows.length != other.rows.length) return false;
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].id != other.rows[i].id || rows[i].on != other.rows[i].on) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(rows.map((r) => Object.hash(r.id, r.on)));
}

class _ToggleNotifier extends AsyncNotifier<_ToggleState>
    with OptimisticPatchMixin<_ToggleState> {
  @override
  Future<_ToggleState> build() async {
    return _ToggleState(const <_Row>[
      _Row(1),
      _Row(2),
      _Row(3),
    ]);
  }
}

final _toggleProvider = AsyncNotifierProvider<_ToggleNotifier, _ToggleState>(
  _ToggleNotifier.new,
);

void main() {
  test('单条成功：本地立即变 → await action → 结果保留', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(_toggleProvider.future);
    final notifier = container.read(_toggleProvider.notifier);

    final result = await notifier.withOptimisticPatch<int>(key: 1, apply: (s) {
      return s.flip(1);
    }, action: () async {
      expect(container.read(_toggleProvider).value!.onOf(1), isTrue);
      return 42;
    });

    expect(result, 42);
    expect(container.read(_toggleProvider).value!.onOf(1), isTrue);
  });

  test('单条失败：状态恢复原态并 rethrow', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(_toggleProvider.future);
    final notifier = container.read(_toggleProvider.notifier);
    final original = container.read(_toggleProvider);

    await expectLater(
      notifier.withOptimisticPatch<int>(key: 1, apply: (s) => s.flip(1),
          action: () async {
            throw Exception('boom');
          }),
      throwsA(isA<Exception>()),
    );

    expect(container.read(_toggleProvider), original);
  });

  test('单条同 key 重复调用：in-flight 时短路返回 duplicateResult', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(_toggleProvider.future);
    final notifier = container.read(_toggleProvider.notifier);

    final gate = Completer<void>();
    var actionCalls = 0;
    final first = notifier.withOptimisticPatch<int>(
      key: 1,
      apply: (s) => s.flip(1),
      action: () async {
        actionCalls++;
        await gate.future;
        return 1;
      },
    );

    // 首调用还在飞，二次调用立即短路。
    final second = await notifier.withOptimisticPatch<int>(
      key: 1,
      apply: (s) => s.flip(1),
      action: () async {
        actionCalls++;
        return 2;
      },
      duplicateResult: 99,
    );
    expect(second, 99);
    expect(actionCalls, 1);
    expect(notifier.isInFlight(1), isTrue);

    gate.complete();
    await first;
    expect(notifier.isInFlight(1), isFalse);
    expect(actionCalls, 1);
  });

  test('单条 finally 清空 in-flight（rethrow 路径）', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(_toggleProvider.future);
    final notifier = container.read(_toggleProvider.notifier);

    await expectLater(
      notifier.withOptimisticPatch<int>(key: 2, apply: (s) => s.flip(2),
          action: () async {
            throw StateError('x');
          }),
      throwsA(isA<StateError>()),
    );
    expect(notifier.isInFlight(2), isFalse);
  });

  test('批量全接受：全打补丁、accepted=全部、isFullSuccess', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(_toggleProvider.future);
    final notifier = container.read(_toggleProvider.notifier);

    final result = await notifier.withBatchOptimisticPatch<int, List<int>>(
      keys: const [1, 2],
      apply: (s, keys) {
        var next = s;
        for (final k in keys) {
          next = next.flip(k);
        }
        return next;
      },
      action: (keys) async {
        expect(container.read(_toggleProvider).value!.onOf(1), isTrue);
        expect(container.read(_toggleProvider).value!.onOf(2), isTrue);
        return keys.toList();
      },
      skippedFromResult: (result) => const <int>{},
      rollback: (current, original, keys) => current.restoreFrom(original, keys),
    );

    expect(result.isFullSuccess, isTrue);
    expect(result.accepted, {1, 2});
    expect(result.skipped, isEmpty);
    expect(container.read(_toggleProvider).value!.onOf(1), isTrue);
    expect(container.read(_toggleProvider).value!.onOf(2), isTrue);
  });

  test('批量部分 skipped：精准回滚 skipped、其它保留', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(_toggleProvider.future);
    final notifier = container.read(_toggleProvider.notifier);

    final result = await notifier.withBatchOptimisticPatch<int, Set<int>>(
      keys: const [1, 2, 3],
      apply: (s, keys) {
        var next = s;
        for (final k in keys) {
          next = next.flip(k);
        }
        return next;
      },
      action: (keys) async => keys,
      skippedFromResult: (result) => <int>{2},
      rollback: (current, original, keys) => current.restoreFrom(original, keys),
    );

    expect(result.isPartialSuccess, isTrue);
    expect(result.accepted, {1, 3});
    expect(result.skipped, {2});
    final s = container.read(_toggleProvider).value!;
    expect(s.onOf(1), isTrue);
    expect(s.onOf(2), isFalse); // 已回滚
    expect(s.onOf(3), isTrue);
  });

  test('批量重复 key 去重：action 只收一次、accepted 无重复', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(_toggleProvider.future);
    final notifier = container.read(_toggleProvider.notifier);

    Set<int>? received;
    final result = await notifier.withBatchOptimisticPatch<int, Set<int>>(
      keys: const [1, 1, 2, 2, 2],
      apply: (s, keys) {
        var next = s;
        for (final k in keys) {
          next = next.flip(k);
        }
        return next;
      },
      action: (keys) async {
        received = keys;
        return keys;
      },
      skippedFromResult: (result) => const <int>{},
      rollback: (current, original, keys) => current.restoreFrom(original, keys),
    );

    expect(received, {1, 2});
    expect(result.accepted, {1, 2});
  });

  test('批量整体失败：全回滚 + errorMessage + isTotalFailure（不抛）', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(_toggleProvider.future);
    final notifier = container.read(_toggleProvider.notifier);
    final original = container.read(_toggleProvider);

    final result = await notifier.withBatchOptimisticPatch<int, Set<int>>(
      keys: const [1, 2],
      apply: (s, keys) {
        var next = s;
        for (final k in keys) {
          next = next.flip(k);
        }
        return next;
      },
      action: (keys) async => throw Exception('net down'),
      skippedFromResult: (result) => const <int>{},
      rollback: (current, original, keys) => current.restoreFrom(original, keys),
      errorMessageOf: (error) => '网络错误',
    );

    expect(result.isTotalFailure, isTrue);
    expect(result.errorMessage, '网络错误');
    expect(result.accepted, isEmpty);
    expect(container.read(_toggleProvider), original);
  });

  test('批量 apply 抛异常：与单条对称，走整体失败路径（不冒到调用方）', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(_toggleProvider.future);
    final notifier = container.read(_toggleProvider.notifier);
    final original = container.read(_toggleProvider);

    var actionCalls = 0;
    final result = await notifier.withBatchOptimisticPatch<int, Set<int>>(
      keys: const [1, 2],
      apply: (s, keys) => throw StateError('apply boom'),
      action: (keys) async {
        actionCalls++;
        return keys;
      },
      skippedFromResult: (result) => const <int>{},
      rollback: (current, original, keys) => current.restoreFrom(original, keys),
    );

    // apply 抛出 → 不冒泡：整批走 total-failure、action 不发出、状态还原。
    expect(result.isTotalFailure, isTrue);
    expect(result.errorMessage, contains('apply boom'));
    expect(result.accepted, isEmpty);
    expect(actionCalls, 0);
    expect(container.read(_toggleProvider), original);
  });

  test('批量空 key 集短路：不调 action、不动 state', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(_toggleProvider.future);
    final notifier = container.read(_toggleProvider.notifier);
    final original = container.read(_toggleProvider);

    var actionCalls = 0;
    final result = await notifier.withBatchOptimisticPatch<int, Set<int>>(
      keys: const <int>[],
      apply: (s, keys) => s,
      action: (keys) async {
        actionCalls++;
        return keys;
      },
      skippedFromResult: (result) => const <int>{},
      rollback: (current, original, keys) => current,
    );

    expect(actionCalls, 0);
    expect(result.isFullSuccess, isTrue);
    expect(container.read(_toggleProvider), original);
  });

  test('批量「已达目标态」项：apply no-op、不破坏状态、调用方可过滤广播', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(_toggleProvider.future);
    final notifier = container.read(_toggleProvider.notifier);

    // 业务语义：id=2 已经处于目标态（on=true），apply 对它是 no-op。
    notifier.state = AsyncData(
      _ToggleState(const <_Row>[_Row(1), _Row(2, on: true), _Row(3)]),
    );

    final patchedKeys = <int>{};
    final result = await notifier.withBatchOptimisticPatch<int, Set<int>>(
      keys: const [1, 2],
      apply: (s, keys) {
        var next = s;
        for (final k in keys) {
          if (s.onOf(k)) {
            continue; // 已达目标态：跳过
          }
          next = next.flip(k);
          patchedKeys.add(k);
        }
        return next;
      },
      action: (keys) async => keys,
      skippedFromResult: (result) => const <int>{},
      rollback: (current, original, keys) => current.restoreFrom(original, keys),
    );

    // 调用方按「accepted ∩ 实际打过补丁」过滤广播——与参考实现一致。
    final broadcast = result.accepted.intersection(patchedKeys);
    expect(broadcast, {1});
    final s = container.read(_toggleProvider).value!;
    expect(s.onOf(1), isTrue);
    expect(s.onOf(2), isTrue); // 未被破坏
  });

  test('批量 skipped 且该 key 未被打补丁：回滚 no-op 不破坏状态', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(_toggleProvider.future);
    final notifier = container.read(_toggleProvider.notifier);

    // id=3 已处于目标态（on=true），apply 跳过它；后端却把它放进 skipped。
    notifier.state = AsyncData(
      _ToggleState(const <_Row>[_Row(1), _Row(2), _Row(3, on: true)]),
    );

    final result = await notifier.withBatchOptimisticPatch<int, Set<int>>(
      keys: const [1, 3],
      apply: (s, keys) {
        var next = s;
        for (final k in keys) {
          if (s.onOf(k)) continue;
          next = next.flip(k);
        }
        return next;
      },
      action: (keys) async => keys,
      skippedFromResult: (result) => <int>{3},
      rollback: (current, original, keys) => current.restoreFrom(original, keys),
    );

    expect(result.skipped, {3});
    expect(result.accepted, {1});
    final s = container.read(_toggleProvider).value!;
    expect(s.onOf(1), isTrue);
    expect(s.onOf(3), isTrue); // 回滚 restoreFrom 对该 key 是 no-op（原本就在目标态）
  });

  test('批量 in-flight 期间 state 立即生效（乐观）', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(_toggleProvider.future);
    final notifier = container.read(_toggleProvider.notifier);

    final gate = Completer<Set<int>>();
    final fut = notifier.withBatchOptimisticPatch<int, Set<int>>(
      keys: const [1],
      apply: (s, keys) => s.flip(1),
      action: (keys) async => gate.future,
      skippedFromResult: (result) => const <int>{},
      rollback: (current, original, keys) => current.restoreFrom(original, keys),
    );

    expect(container.read(_toggleProvider).value!.onOf(1), isTrue);
    gate.complete(<int>{1});
    await fut;
    expect(container.read(_toggleProvider).value!.onOf(1), isTrue);
  });

  test('批量 state 未 build 完成：跳过本地补丁/回滚，action 照发', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(_toggleProvider.notifier);
    expect(notifier.state.value, isNull);

    var applyCalls = 0;
    var rollbackCalls = 0;
    final result = await notifier.withBatchOptimisticPatch<int, Set<int>>(
      keys: const [1],
      apply: (s, keys) {
        applyCalls++;
        return s;
      },
      action: (keys) async => <int>{},
      skippedFromResult: (result) => const <int>{},
      rollback: (current, original, keys) {
        rollbackCalls++;
        return current;
      },
    );

    expect(applyCalls, 0);
    expect(rollbackCalls, 0);
    expect(result.accepted, {1});
    expect(result.isFullSuccess, isTrue);
  });

  test('单条 state 未 build 完成：跳过本地补丁，action 照发', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(_toggleProvider.notifier);

    var applyCalls = 0;
    final result = await notifier.withOptimisticPatch<String>(
      key: 1,
      apply: (s) {
        applyCalls++;
        return s;
      },
      action: () async => 'done',
    );

    expect(applyCalls, 0);
    expect(result, 'done');
  });

  test('BatchOptimisticResult 三态 flag 语义', () {
    expect(
      const BatchOptimisticResult<int>(
        accepted: {1},
        skipped: <int>{},
      ).isFullSuccess,
      isTrue,
    );
    expect(
      const BatchOptimisticResult<int>(
        accepted: {1},
        skipped: {2},
      ).isPartialSuccess,
      isTrue,
    );
    expect(
      const BatchOptimisticResult<int>(
        accepted: <int>{},
        skipped: <int>{},
        errorMessage: 'x',
      ).isTotalFailure,
      isTrue,
    );
    expect(
      BatchOptimisticResult<int>.empty().isFullSuccess,
      isTrue,
    );
  });
}
