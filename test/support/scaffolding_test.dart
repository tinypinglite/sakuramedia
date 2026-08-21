import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_sse_event.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';

import 'fake_sse_event_stream_client.dart';
import 'pump_with_providers.dart';
import 'riverpod_test_helpers.dart';
import 'test_api_bundle.dart';

Future<void> pumpMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
}

final _tickController = StreamController<int>.broadcast();
final _tickProvider = StreamProvider<int>((ref) => _tickController.stream);

class _ProbeHome extends ConsumerWidget {
  const _ProbeHome({this.extraOverrideText});

  final String? extraOverrideText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 触发一次依赖解析：bundle overrides 未正确安装时这里会抛。
    ref.watch(apiClientProvider);
    return Scaffold(body: Center(child: Text(extraOverrideText ?? 'has-api')));
  }
}

void main() {
  group('FakeSseEventStreamClient（传输层打桩）', () {
    test('connect + emit：事件投递到监听方', () async {
      final fake = FakeSseEventStreamClient();
      addTearDown(fake.dispose);
      final received = <ApiSseEvent>[];
      fake.connect('/downloads/stream').listen(received.add);

      fake.emit('/downloads/stream', id: 7, event: 'update', data: '{"a":1}');
      await pumpMicrotasks();
      expect(received, hasLength(1));
      expect(received.single.id, 7);
      expect(received.single.event, 'update');
      expect(received.single.jsonData, <String, dynamic>{'a': 1});
    });

    test('emitJson：data 自动 encode', () async {
      final fake = FakeSseEventStreamClient();
      addTearDown(fake.dispose);
      final received = <ApiSseEvent>[];
      fake.connect('/x').listen(received.add);

      fake.emitJson('/x', json: <String, dynamic>{'k': 'v'});
      await pumpMicrotasks();
      expect(received.single.jsonData, <String, dynamic>{'k': 'v'});
    });

    test('emitError：错误沿 stream 冒泡', () async {
      final fake = FakeSseEventStreamClient();
      addTearDown(fake.dispose);
      final errors = <Object>[];
      fake.connect('/x').listen((_) {}, onError: errors.add);

      fake.emitError('/x', StateError('boom'));
      await pumpMicrotasks();
      expect(errors, hasLength(1));
      expect(errors.single, isA<StateError>());
    });

    test('endpoint 隔离：不同 endpoint 互不干扰；closeAll 幂等', () async {
      final fake = FakeSseEventStreamClient();
      addTearDown(fake.dispose);
      final a = <ApiSseEvent>[];
      final b = <ApiSseEvent>[];
      fake.connect('/a').listen(a.add);
      fake.connect('/b').listen(b.add);

      fake.emit('/a', id: 1);
      await pumpMicrotasks();
      expect(a, hasLength(1));
      expect(b, isEmpty);

      fake.closeAll();
      fake.closeAll(); // 幂等
      fake.emit('/a', id: 2);
      await pumpMicrotasks();
      expect(a, hasLength(1)); // 流已关，不再投递
    });
  });

  group('pumpWithProviders（widget 测试树）', () {
    testWidgets('bundle overrides 生效 + OKToast 树可用', (tester) async {
      final sessionStore = SessionStore.inMemory();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);

      await pumpWithProviders(tester, home: const _ProbeHome(), bundle: bundle);

      // bundle 的 apiClient override 生效：ref.watch(apiClientProvider) 非 null。
      expect(find.text('has-api'), findsOneWidget);

      // OKToast 树可用：showToast 可渲染。
      showToast('hello-toast');
      await tester.pump();
      expect(find.text('hello-toast'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3)); // 排掉 oktoast 计时器
    });

    testWidgets('额外 overrides 与 wrap 生效', (tester) async {
      final sessionStore = SessionStore.inMemory();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);

      await pumpWithProviders(
        tester,
        home: const _ProbeHome(extraOverrideText: 'wrapped'),
        bundle: bundle,
        wrap: (child) => Scaffold(body: child),
      );

      expect(find.text('wrapped'), findsOneWidget);
    });
  });

  group('keepEventsProviderAlive（events 挂监听者）', () {
    test('沉默监听者阻止入站流 pause：事件照常投递', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      keepEventsProviderAlive(container, _tickProvider);

      _tickController.add(1);
      await pumpMicrotasks();
      expect(container.read(_tickProvider).value, 1);

      _tickController.add(2);
      await pumpMicrotasks();
      expect(container.read(_tickProvider).value, 2);
    });
  });
}
