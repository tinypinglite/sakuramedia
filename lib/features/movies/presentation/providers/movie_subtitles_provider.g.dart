// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie_subtitles_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(movieSubtitles)
final movieSubtitlesProvider = MovieSubtitlesFamily._();

final class MovieSubtitlesProvider
    extends
        $FunctionalProvider<
          AsyncValue<MovieSubtitleListDto>,
          MovieSubtitleListDto,
          FutureOr<MovieSubtitleListDto>
        >
    with
        $FutureModifier<MovieSubtitleListDto>,
        $FutureProvider<MovieSubtitleListDto> {
  MovieSubtitlesProvider._({
    required MovieSubtitlesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'movieSubtitlesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$movieSubtitlesHash();

  @override
  String toString() {
    return r'movieSubtitlesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<MovieSubtitleListDto> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MovieSubtitleListDto> create(Ref ref) {
    final argument = this.argument as String;
    return movieSubtitles(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MovieSubtitlesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$movieSubtitlesHash() => r'4c5a750a48763a1705c2affe54dc1e40fad159cc';

final class MovieSubtitlesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<MovieSubtitleListDto>, String> {
  MovieSubtitlesFamily._()
    : super(
        retry: null,
        name: r'movieSubtitlesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MovieSubtitlesProvider call(String movieNumber) =>
      MovieSubtitlesProvider._(argument: movieNumber, from: this);

  @override
  String toString() => r'movieSubtitlesProvider';
}
