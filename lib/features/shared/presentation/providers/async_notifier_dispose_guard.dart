import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

/// 请求型业务 AsyncNotifier 的默认重试策略：一律不自动重试。
///
/// 失败语义交给 UI 的重试按钮 / `refresh()` 的「用户显式重试」，不让框架在
/// 失败态里静默重放 `build()`。用法：
/// `@Riverpod(keepAlive: true, retry: kNoAsyncNotifierRetry)`。
Duration? kNoAsyncNotifierRetry(int retryCount, Object error) => null;

/// 非分页 `$AsyncNotifier<S>` 的 dispose 守卫样板。
///
/// 收敛各域重复三行（`bool _disposed = false; ref.onDispose(...); getter`）：
/// 在 `build()` 首行调 [attachDisposeGuard]，await 回写 State 前用
/// [isDisposed] 判断，避免 provider 已 dispose 后 `state = ...` 静默失败
/// 或抛错。分页宿主请用 `PagedAsyncNotifierMixin` 自带的同款守卫。
mixin AsyncNotifierDisposeGuardMixin<S> on $AsyncNotifier<S> {
  bool _disposed = false;

  /// 必须在 `build()` 首行调用；防 dispose 后 `state = ...` 静默失败或抛错。
  @protected
  void attachDisposeGuard() {
    ref.onDispose(() => _disposed = true);
  }

  @protected
  bool get isDisposed => _disposed;
}
