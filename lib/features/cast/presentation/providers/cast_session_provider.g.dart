// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cast_session_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 进行中的投屏会话（内存态，跨页面共享；App 重启后丢失）。

@ProviderFor(CastSessionController)
final castSessionControllerProvider = CastSessionControllerProvider._();

/// 进行中的投屏会话（内存态，跨页面共享；App 重启后丢失）。
final class CastSessionControllerProvider
    extends $NotifierProvider<CastSessionController, CastSession?> {
  /// 进行中的投屏会话（内存态，跨页面共享；App 重启后丢失）。
  CastSessionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'castSessionControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$castSessionControllerHash();

  @$internal
  @override
  CastSessionController create() => CastSessionController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CastSession? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CastSession?>(value),
    );
  }
}

String _$castSessionControllerHash() =>
    r'fd1f0ab7e4e269985771052e969532c5c7e7bc8a';

/// 进行中的投屏会话（内存态，跨页面共享；App 重启后丢失）。

abstract class _$CastSessionController extends $Notifier<CastSession?> {
  CastSession? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CastSession?, CastSession?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CastSession?, CastSession?>,
              CastSession?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
