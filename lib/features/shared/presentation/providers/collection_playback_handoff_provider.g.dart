// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collection_playback_handoff_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 合集详情页 → 连播页的一次性成员交接信箱（原生 Riverpod 装配）。
///
/// offer/take-and-clear 的信箱语义保持不变：写读都发生在页面 initState /
/// 跳转前的命令式代码里（`ref.read`，从不 watch），不存在声明式重建下的
/// 双触发问题。keepAlive 对应旧 MultiProvider 的全局单例。

@ProviderFor(collectionPlaybackHandoff)
final collectionPlaybackHandoffProvider = CollectionPlaybackHandoffProvider._();

/// 合集详情页 → 连播页的一次性成员交接信箱（原生 Riverpod 装配）。
///
/// offer/take-and-clear 的信箱语义保持不变：写读都发生在页面 initState /
/// 跳转前的命令式代码里（`ref.read`，从不 watch），不存在声明式重建下的
/// 双触发问题。keepAlive 对应旧 MultiProvider 的全局单例。

final class CollectionPlaybackHandoffProvider
    extends
        $FunctionalProvider<
          CollectionPlaybackHandoff,
          CollectionPlaybackHandoff,
          CollectionPlaybackHandoff
        >
    with $Provider<CollectionPlaybackHandoff> {
  /// 合集详情页 → 连播页的一次性成员交接信箱（原生 Riverpod 装配）。
  ///
  /// offer/take-and-clear 的信箱语义保持不变：写读都发生在页面 initState /
  /// 跳转前的命令式代码里（`ref.read`，从不 watch），不存在声明式重建下的
  /// 双触发问题。keepAlive 对应旧 MultiProvider 的全局单例。
  CollectionPlaybackHandoffProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'collectionPlaybackHandoffProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$collectionPlaybackHandoffHash();

  @$internal
  @override
  $ProviderElement<CollectionPlaybackHandoff> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CollectionPlaybackHandoff create(Ref ref) {
    return collectionPlaybackHandoff(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CollectionPlaybackHandoff value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CollectionPlaybackHandoff>(value),
    );
  }
}

String _$collectionPlaybackHandoffHash() =>
    r'c52e6fa8ed3814e46ca3784809664fb725d746aa';
