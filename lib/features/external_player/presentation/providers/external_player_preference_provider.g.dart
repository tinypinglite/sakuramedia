// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'external_player_preference_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 「默认外部播放器」偏好（keepAlive AsyncNotifier）。
///
/// 迁移前形态:`ExternalPlayerStore extends ChangeNotifier` + legacy
/// `ChangeNotifierProvider` 的 `..load()` 副作用——现由 `build()` 承载读盘,
/// `isLoaded` 字段由 [AsyncValue] 的加载态取代。
///
/// **刻意语义(勿"顺手修复")**:写入走「先改内存、再写盘、写盘失败静默」——
/// 内存态与磁盘态允许不一致,保持选择立即可用;读盘失败也全吞归未选择。

@ProviderFor(ExternalPlayerPreference)
final externalPlayerPreferenceProvider = ExternalPlayerPreferenceProvider._();

/// 「默认外部播放器」偏好（keepAlive AsyncNotifier）。
///
/// 迁移前形态:`ExternalPlayerStore extends ChangeNotifier` + legacy
/// `ChangeNotifierProvider` 的 `..load()` 副作用——现由 `build()` 承载读盘,
/// `isLoaded` 字段由 [AsyncValue] 的加载态取代。
///
/// **刻意语义(勿"顺手修复")**:写入走「先改内存、再写盘、写盘失败静默」——
/// 内存态与磁盘态允许不一致,保持选择立即可用;读盘失败也全吞归未选择。
final class ExternalPlayerPreferenceProvider
    extends
        $AsyncNotifierProvider<
          ExternalPlayerPreference,
          ExternalPlayerSelection
        > {
  /// 「默认外部播放器」偏好（keepAlive AsyncNotifier）。
  ///
  /// 迁移前形态:`ExternalPlayerStore extends ChangeNotifier` + legacy
  /// `ChangeNotifierProvider` 的 `..load()` 副作用——现由 `build()` 承载读盘,
  /// `isLoaded` 字段由 [AsyncValue] 的加载态取代。
  ///
  /// **刻意语义(勿"顺手修复")**:写入走「先改内存、再写盘、写盘失败静默」——
  /// 内存态与磁盘态允许不一致,保持选择立即可用;读盘失败也全吞归未选择。
  ExternalPlayerPreferenceProvider._()
    : super(
        from: null,
        argument: null,
        retry: kNoAsyncNotifierRetry,
        name: r'externalPlayerPreferenceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$externalPlayerPreferenceHash();

  @$internal
  @override
  ExternalPlayerPreference create() => ExternalPlayerPreference();
}

String _$externalPlayerPreferenceHash() =>
    r'7a19b1c36c984ac7d92f172312af672aba31c709';

/// 「默认外部播放器」偏好（keepAlive AsyncNotifier）。
///
/// 迁移前形态:`ExternalPlayerStore extends ChangeNotifier` + legacy
/// `ChangeNotifierProvider` 的 `..load()` 副作用——现由 `build()` 承载读盘,
/// `isLoaded` 字段由 [AsyncValue] 的加载态取代。
///
/// **刻意语义(勿"顺手修复")**:写入走「先改内存、再写盘、写盘失败静默」——
/// 内存态与磁盘态允许不一致,保持选择立即可用;读盘失败也全吞归未选择。

abstract class _$ExternalPlayerPreference
    extends $AsyncNotifier<ExternalPlayerSelection> {
  FutureOr<ExternalPlayerSelection> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<ExternalPlayerSelection>,
              ExternalPlayerSelection
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<ExternalPlayerSelection>,
                ExternalPlayerSelection
              >,
              AsyncValue<ExternalPlayerSelection>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
