// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invalid_media_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 「媒体维护」失效媒体列表（Riverpod）。删除成功后从列表移除并扣减 total。

@ProviderFor(InvalidMedia)
final invalidMediaProvider = InvalidMediaProvider._();

/// 「媒体维护」失效媒体列表（Riverpod）。删除成功后从列表移除并扣减 total。
final class InvalidMediaProvider
    extends $AsyncNotifierProvider<InvalidMedia, InvalidMediaState> {
  /// 「媒体维护」失效媒体列表（Riverpod）。删除成功后从列表移除并扣减 total。
  InvalidMediaProvider._()
    : super(
        from: null,
        argument: null,
        retry: kNoAsyncNotifierRetry,
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

String _$invalidMediaHash() => r'310bd501d4ef1d3ebc6090a4ac71617bc76e3d52';

/// 「媒体维护」失效媒体列表（Riverpod）。删除成功后从列表移除并扣减 total。

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
