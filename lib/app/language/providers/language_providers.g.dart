// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'language_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 语言偏好存储；生产在 `MyApp` 组合根注入 SharedPreferences 实现。

@ProviderFor(appLanguageStore)
final appLanguageStoreProvider = AppLanguageStoreProvider._();

/// 语言偏好存储；生产在 `MyApp` 组合根注入 SharedPreferences 实现。

final class AppLanguageStoreProvider
    extends
        $FunctionalProvider<
          AppLanguageStore,
          AppLanguageStore,
          AppLanguageStore
        >
    with $Provider<AppLanguageStore> {
  /// 语言偏好存储；生产在 `MyApp` 组合根注入 SharedPreferences 实现。
  AppLanguageStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLanguageStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLanguageStoreHash();

  @$internal
  @override
  $ProviderElement<AppLanguageStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppLanguageStore create(Ref ref) {
    return appLanguageStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppLanguageStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppLanguageStore>(value),
    );
  }
}

String _$appLanguageStoreHash() => r'd7fd72e5026ba00c8982d32f76a012f61b7c0693';

/// 当前界面语言。默认 zh-CN；登录成功后可用后端 user.language 覆盖。

@ProviderFor(AppLanguageController)
final appLanguageControllerProvider = AppLanguageControllerProvider._();

/// 当前界面语言。默认 zh-CN；登录成功后可用后端 user.language 覆盖。
final class AppLanguageControllerProvider
    extends $NotifierProvider<AppLanguageController, AppLanguage> {
  /// 当前界面语言。默认 zh-CN；登录成功后可用后端 user.language 覆盖。
  AppLanguageControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLanguageControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLanguageControllerHash();

  @$internal
  @override
  AppLanguageController create() => AppLanguageController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppLanguage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppLanguage>(value),
    );
  }
}

String _$appLanguageControllerHash() =>
    r'1a3ef21b07fd8d13442ff2e1c7a8a7ab1c16dad5';

/// 当前界面语言。默认 zh-CN；登录成功后可用后端 user.language 覆盖。

abstract class _$AppLanguageController extends $Notifier<AppLanguage> {
  AppLanguage build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppLanguage, AppLanguage>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppLanguage, AppLanguage>,
              AppLanguage,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
