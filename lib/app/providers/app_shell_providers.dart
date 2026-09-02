import 'dart:async';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/app_version_info_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/status/presentation/providers/status_api_provider.dart';

part 'app_shell_providers.g.dart';

/// 桌面壳侧边栏折叠状态。
///
/// 迁移前形态:`AppShellController extends ChangeNotifier`(仅一个 bool)
/// + 桥 provider。keepAlive:折叠偏好在会话内跨路由存续(与旧常驻控制器
/// 语义一致)。
@Riverpod(keepAlive: true)
class AppShellSidebarCollapsed extends _$AppShellSidebarCollapsed {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }
}

typedef AppPackageInfoLoader = Future<PackageInfo> Function();

@Riverpod(keepAlive: true)
AppPackageInfoLoader appPackageInfoLoader(Ref ref) => PackageInfo.fromPlatform;

/// 前后端版本信息。provider 本身常驻，但 [load] 仍由版本 UI 出现时显式
/// 触发，避免仅创建应用容器就请求 `/status`。
@Riverpod(keepAlive: true, retry: kNoAsyncNotifierRetry)
class AppVersionInfo extends _$AppVersionInfo {
  Future<void>? _loadFuture;
  Future<String>? _frontendVersionFuture;

  @override
  FutureOr<AppVersionInfoState> build() => AppVersionInfoState.initial;

  Future<void> load() {
    final inFlight = _loadFuture;
    if (inFlight != null) {
      return inFlight;
    }
    final next = _loadVersions();
    _loadFuture = next;
    return next.whenComplete(() {
      if (identical(_loadFuture, next)) {
        _loadFuture = null;
      }
    });
  }

  Future<void> _loadVersions() async {
    final current = state.value ?? AppVersionInfoState.initial;
    state = AsyncData(current.copyWith(isLoading: true));

    final results = await Future.wait<String>([
      _frontendVersionFuture ??= _loadFrontendVersion(),
      _loadBackendVersion(),
    ]);
    if (!ref.mounted) {
      return;
    }
    state = AsyncData(
      AppVersionInfoState(
        frontendVersion: results[0],
        backendVersion: results[1],
        hasLoaded: true,
      ),
    );
  }

  Future<String> _loadFrontendVersion() async {
    try {
      final packageInfo = await ref.read(appPackageInfoLoaderProvider)();
      return packageInfo.version.trim();
    } catch (_) {
      return '';
    }
  }

  Future<String> _loadBackendVersion() async {
    try {
      final status = await ref.read(statusApiProvider).getStatus();
      return status.backendVersion.trim();
    } catch (_) {
      return '';
    }
  }
}
