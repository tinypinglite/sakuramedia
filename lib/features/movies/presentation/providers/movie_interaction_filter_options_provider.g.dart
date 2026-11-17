// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie_interaction_filter_options_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 互动数滑块上限跟随库内数据变化，面板每次打开时按需拉取，不做全局常驻缓存。

@ProviderFor(movieInteractionFilterOptions)
final movieInteractionFilterOptionsProvider =
    MovieInteractionFilterOptionsProvider._();

/// 互动数滑块上限跟随库内数据变化，面板每次打开时按需拉取，不做全局常驻缓存。

final class MovieInteractionFilterOptionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<MovieInteractionFilterOptionsDto>,
          MovieInteractionFilterOptionsDto,
          FutureOr<MovieInteractionFilterOptionsDto>
        >
    with
        $FutureModifier<MovieInteractionFilterOptionsDto>,
        $FutureProvider<MovieInteractionFilterOptionsDto> {
  /// 互动数滑块上限跟随库内数据变化，面板每次打开时按需拉取，不做全局常驻缓存。
  MovieInteractionFilterOptionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'movieInteractionFilterOptionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$movieInteractionFilterOptionsHash();

  @$internal
  @override
  $FutureProviderElement<MovieInteractionFilterOptionsDto> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MovieInteractionFilterOptionsDto> create(Ref ref) {
    return movieInteractionFilterOptions(ref);
  }
}

String _$movieInteractionFilterOptionsHash() =>
    r'07ee663d5d0f8895d7744f4788d14b8165a223ca';
