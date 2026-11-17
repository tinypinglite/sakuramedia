import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';

class _GuardNotifier extends AsyncNotifier<String>
    with AsyncNotifierDisposeGuardMixin<String> {
  bool get disposed => isDisposed;

  @override
  Future<String> build() async {
    attachDisposeGuard();
    return 'loaded';
  }
}

final _guardProvider = AsyncNotifierProvider<_GuardNotifier, String>(
  _GuardNotifier.new,
  retry: kNoAsyncNotifierRetry,
);

void main() {
  test('attachDisposeGuard: 容器 dispose 后 isDisposed == true', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(_guardProvider.future);
    final notifier = container.read(_guardProvider.notifier);
    expect(notifier.disposed, isFalse);

    container.dispose();
    expect(notifier.disposed, isTrue);
  });

  test('kNoAsyncNotifierRetry 恒为 null（不自动重试）', () {
    expect(kNoAsyncNotifierRetry(0, Exception('x')), isNull);
    expect(kNoAsyncNotifierRetry(5, Exception('y')), isNull);
  });
}
