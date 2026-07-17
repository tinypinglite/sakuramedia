// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invalid_media_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 「媒体维护」失效媒体列表（Riverpod）。
///
/// 复查 → 若已恢复：从列表移除；若仍失效：加入 [InvalidMediaState.deleteEnabledMediaIds]
/// 允许删除。删除 → 移除并扣减 total。单飞守卫：同时只能一项复查/一项删除。
///
/// 迁移前对应：`InvalidMediaController extends PagedLoadController<InvalidMediaDto>`。

@ProviderFor(InvalidMedia)
final invalidMediaProvider = InvalidMediaProvider._();

/// 「媒体维护」失效媒体列表（Riverpod）。
///
/// 复查 → 若已恢复：从列表移除；若仍失效：加入 [InvalidMediaState.deleteEnabledMediaIds]
/// 允许删除。删除 → 移除并扣减 total。单飞守卫：同时只能一项复查/一项删除。
///
/// 迁移前对应：`InvalidMediaController extends PagedLoadController<InvalidMediaDto>`。
final class InvalidMediaProvider
    extends $AsyncNotifierProvider<InvalidMedia, InvalidMediaState> {
  /// 「媒体维护」失效媒体列表（Riverpod）。
  ///
  /// 复查 → 若已恢复：从列表移除；若仍失效：加入 [InvalidMediaState.deleteEnabledMediaIds]
  /// 允许删除。删除 → 移除并扣减 total。单飞守卫：同时只能一项复查/一项删除。
  ///
  /// 迁移前对应：`InvalidMediaController extends PagedLoadController<InvalidMediaDto>`。
  InvalidMediaProvider._()
    : super(
        from: null,
        argument: null,
        retry: noInvalidMediaRetry,
        name: r'invalidMediaProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$invalidMediaHash();

  @$internal
  @override
  InvalidMedia create() => InvalidMedia();
}

String _$invalidMediaHash() => r'3b9790bc7d61b137ee5761f866871f8315adfc1f';

/// 「媒体维护」失效媒体列表（Riverpod）。
///
/// 复查 → 若已恢复：从列表移除；若仍失效：加入 [InvalidMediaState.deleteEnabledMediaIds]
/// 允许删除。删除 → 移除并扣减 total。单飞守卫：同时只能一项复查/一项删除。
///
/// 迁移前对应：`InvalidMediaController extends PagedLoadController<InvalidMediaDto>`。

abstract class _$InvalidMedia extends $AsyncNotifier<InvalidMediaState> {
  FutureOr<InvalidMediaState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<InvalidMediaState>, InvalidMediaState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<InvalidMediaState>, InvalidMediaState>,
              AsyncValue<InvalidMediaState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
