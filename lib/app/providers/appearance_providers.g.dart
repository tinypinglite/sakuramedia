// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appearance_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 外观偏好存储；生产在 `MyApp` 组合根注入 SharedPreferences 实现。

@ProviderFor(appearanceStore)
final appearanceStoreProvider = AppearanceStoreProvider._();

/// 外观偏好存储；生产在 `MyApp` 组合根注入 SharedPreferences 实现。

final class AppearanceStoreProvider
    extends
        $FunctionalProvider<AppearanceStore, AppearanceStore, AppearanceStore>
    with $Provider<AppearanceStore> {
  /// 外观偏好存储；生产在 `MyApp` 组合根注入 SharedPreferences 实现。
  AppearanceStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appearanceStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appearanceStoreHash();

  @$internal
  @override
  $ProviderElement<AppearanceStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppearanceStore create(Ref ref) {
    return appearanceStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppearanceStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppearanceStore>(value),
    );
  }
}

String _$appearanceStoreHash() => r'a9e3d6c17f58e77638f13466fa0d83e10833f5e3';

/// 当前外观偏好（明暗模式 + 主题色），供 `MaterialApp` 与设置页读写。

@ProviderFor(Appearance)
final appearanceProvider = AppearanceProvider._();

/// 当前外观偏好（明暗模式 + 主题色），供 `MaterialApp` 与设置页读写。
final class AppearanceProvider
    extends $NotifierProvider<Appearance, AppearanceSettings> {
  /// 当前外观偏好（明暗模式 + 主题色），供 `MaterialApp` 与设置页读写。
  AppearanceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appearanceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appearanceHash();

  @$internal
  @override
  Appearance create() => Appearance();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppearanceSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppearanceSettings>(value),
    );
  }
}

String _$appearanceHash() => r'086e9dfc92a2ccbbf1656def066d0694c8d76c4d';

/// 当前外观偏好（明暗模式 + 主题色），供 `MaterialApp` 与设置页读写。

abstract class _$Appearance extends $Notifier<AppearanceSettings> {
  AppearanceSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppearanceSettings, AppearanceSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppearanceSettings, AppearanceSettings>,
              AppearanceSettings,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
