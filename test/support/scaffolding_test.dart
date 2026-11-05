import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'riverpod_test_helpers.dart';

Future<void> pumpMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
}

final _tickController = StreamController<int>.broadcast();
final _tickProvider = StreamProvider<int>((ref) => _tickController.stream);

void main() {
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
