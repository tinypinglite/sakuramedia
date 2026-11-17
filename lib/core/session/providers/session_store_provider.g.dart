// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_store_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 全局 [SessionStore] 的 Riverpod 入口。
///
/// 会话是应用输入：body 保持抛 [UnimplementedError]，实例由组合根
/// （`lib/app/app.dart`，main 传入持久化实例 / 测试传 inMemory）用
/// `overrideWithValue` 注入。

@ProviderFor(sessionStore)
final sessionStoreProvider = SessionStoreProvider._();

/// 全局 [SessionStore] 的 Riverpod 入口。
///
/// 会话是应用输入：body 保持抛 [UnimplementedError]，实例由组合根
/// （`lib/app/app.dart`，main 传入持久化实例 / 测试传 inMemory）用
/// `overrideWithValue` 注入。

final class SessionStoreProvider
    extends $FunctionalProvider<SessionStore, SessionStore, SessionStore>
    with $Provider<SessionStore> {
  /// 全局 [SessionStore] 的 Riverpod 入口。
  ///
  /// 会话是应用输入：body 保持抛 [UnimplementedError]，实例由组合根
  /// （`lib/app/app.dart`，main 传入持久化实例 / 测试传 inMemory）用
  /// `overrideWithValue` 注入。
  SessionStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionStoreHash();

  @$internal
  @override
  $ProviderElement<SessionStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SessionStore create(Ref ref) {
    return sessionStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionStore>(value),
    );
  }
}

String _$sessionStoreHash() => r'2321d4502d696301d097ee7ba96662271aa60453';

/// 细粒度派生：当前会话的 baseUrl。
///
/// [SessionStore] 是 ChangeNotifier，`ref.watch(sessionStoreProvider)` 拿到的
/// 是稳定实例、变更不会自动传播——这里手动 addListener 并在值变化时
/// `invalidateSelf`，让只关心 baseUrl 的组件（masked_image 等）精准重建。

@ProviderFor(baseUrl)
final baseUrlProvider = BaseUrlProvider._();

/// 细粒度派生：当前会话的 baseUrl。
///
/// [SessionStore] 是 ChangeNotifier，`ref.watch(sessionStoreProvider)` 拿到的
/// 是稳定实例、变更不会自动传播——这里手动 addListener 并在值变化时
/// `invalidateSelf`，让只关心 baseUrl 的组件（masked_image 等）精准重建。

final class BaseUrlProvider extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  /// 细粒度派生：当前会话的 baseUrl。
  ///
  /// [SessionStore] 是 ChangeNotifier，`ref.watch(sessionStoreProvider)` 拿到的
  /// 是稳定实例、变更不会自动传播——这里手动 addListener 并在值变化时
  /// `invalidateSelf`，让只关心 baseUrl 的组件（masked_image 等）精准重建。
  BaseUrlProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'baseUrlProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$baseUrlHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return baseUrl(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$baseUrlHash() => r'a4d149e9bf1e6e57544fceb87823f8cf7a3a4fba';
