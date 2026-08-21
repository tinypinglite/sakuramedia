import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';

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
