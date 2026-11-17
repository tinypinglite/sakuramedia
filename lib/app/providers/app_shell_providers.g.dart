// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_shell_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 桌面壳侧边栏折叠状态。
///
/// 迁移前形态:`AppShellController extends ChangeNotifier`(仅一个 bool)
/// + 桥 provider。keepAlive:折叠偏好在会话内跨路由存续(与旧常驻控制器
/// 语义一致)。

@ProviderFor(AppShellSidebarCollapsed)
final appShellSidebarCollapsedProvider = AppShellSidebarCollapsedProvider._();

/// 桌面壳侧边栏折叠状态。
///
/// 迁移前形态:`AppShellController extends ChangeNotifier`(仅一个 bool)
/// + 桥 provider。keepAlive:折叠偏好在会话内跨路由存续(与旧常驻控制器
/// 语义一致)。
final class AppShellSidebarCollapsedProvider
    extends $NotifierProvider<AppShellSidebarCollapsed, bool> {
  /// 桌面壳侧边栏折叠状态。
  ///
  /// 迁移前形态:`AppShellController extends ChangeNotifier`(仅一个 bool)
  /// + 桥 provider。keepAlive:折叠偏好在会话内跨路由存续(与旧常驻控制器
  /// 语义一致)。
  AppShellSidebarCollapsedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appShellSidebarCollapsedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appShellSidebarCollapsedHash();

  @$internal
  @override
  AppShellSidebarCollapsed create() => AppShellSidebarCollapsed();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$appShellSidebarCollapsedHash() =>
    r'96b9b66c1b4d5c41aeafe05d7c1eec34f35fd3e2';

/// 桌面壳侧边栏折叠状态。
///
/// 迁移前形态:`AppShellController extends ChangeNotifier`(仅一个 bool)
/// + 桥 provider。keepAlive:折叠偏好在会话内跨路由存续(与旧常驻控制器
/// 语义一致)。

abstract class _$AppShellSidebarCollapsed extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(appPackageInfoLoader)
final appPackageInfoLoaderProvider = AppPackageInfoLoaderProvider._();

final class AppPackageInfoLoaderProvider
    extends
        $FunctionalProvider<
          AppPackageInfoLoader,
          AppPackageInfoLoader,
          AppPackageInfoLoader
        >
    with $Provider<AppPackageInfoLoader> {
  AppPackageInfoLoaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appPackageInfoLoaderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appPackageInfoLoaderHash();

  @$internal
  @override
  $ProviderElement<AppPackageInfoLoader> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AppPackageInfoLoader create(Ref ref) {
    return appPackageInfoLoader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppPackageInfoLoader value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppPackageInfoLoader>(value),
    );
  }
}

String _$appPackageInfoLoaderHash() =>
    r'7cd06c31f5770373df163de2010ec55bba149bae';

/// 前后端版本信息。provider 本身常驻，但 [load] 仍由版本 UI 出现时显式
/// 触发，避免仅创建应用容器就请求 `/status`。

@ProviderFor(AppVersionInfo)
final appVersionInfoProvider = AppVersionInfoProvider._();

/// 前后端版本信息。provider 本身常驻，但 [load] 仍由版本 UI 出现时显式
/// 触发，避免仅创建应用容器就请求 `/status`。
final class AppVersionInfoProvider
    extends $AsyncNotifierProvider<AppVersionInfo, AppVersionInfoState> {
  /// 前后端版本信息。provider 本身常驻，但 [load] 仍由版本 UI 出现时显式
  /// 触发，避免仅创建应用容器就请求 `/status`。
  AppVersionInfoProvider._()
    : super(
        from: null,
        argument: null,
        retry: kNoAsyncNotifierRetry,
        name: r'appVersionInfoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appVersionInfoHash();

  @$internal
  @override
  AppVersionInfo create() => AppVersionInfo();
}

String _$appVersionInfoHash() => r'a5f1bef5b35b77580b162c01a2eb0c5737b9f2cd';

/// 前后端版本信息。provider 本身常驻，但 [load] 仍由版本 UI 出现时显式
/// 触发，避免仅创建应用容器就请求 `/status`。

abstract class _$AppVersionInfo extends $AsyncNotifier<AppVersionInfoState> {
  FutureOr<AppVersionInfoState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<AppVersionInfoState>, AppVersionInfoState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AppVersionInfoState>, AppVersionInfoState>,
              AsyncValue<AppVersionInfoState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
