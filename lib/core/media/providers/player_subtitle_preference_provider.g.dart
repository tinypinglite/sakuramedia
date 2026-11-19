// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_subtitle_preference_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 设备级字幕偏好；与账号无关，所有播放器共用。

@ProviderFor(PlayerSubtitlePreferenceController)
final playerSubtitlePreferenceControllerProvider =
    PlayerSubtitlePreferenceControllerProvider._();

/// 设备级字幕偏好；与账号无关，所有播放器共用。
final class PlayerSubtitlePreferenceControllerProvider
    extends
        $AsyncNotifierProvider<
          PlayerSubtitlePreferenceController,
          PlayerSubtitlePreference
        > {
  /// 设备级字幕偏好；与账号无关，所有播放器共用。
  PlayerSubtitlePreferenceControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: _noRetry,
        name: r'playerSubtitlePreferenceControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() =>
      _$playerSubtitlePreferenceControllerHash();

  @$internal
  @override
  PlayerSubtitlePreferenceController create() =>
      PlayerSubtitlePreferenceController();
}

String _$playerSubtitlePreferenceControllerHash() =>
    r'81e7c56a164f27ea5d7369017f88df19252d84e3';

/// 设备级字幕偏好；与账号无关，所有播放器共用。

abstract class _$PlayerSubtitlePreferenceController
    extends $AsyncNotifier<PlayerSubtitlePreference> {
  FutureOr<PlayerSubtitlePreference> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<PlayerSubtitlePreference>,
              PlayerSubtitlePreference
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<PlayerSubtitlePreference>,
                PlayerSubtitlePreference
              >,
              AsyncValue<PlayerSubtitlePreference>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
