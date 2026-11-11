// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie_detail_review_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MovieDetailReview)
final movieDetailReviewProvider = MovieDetailReviewFamily._();

final class MovieDetailReviewProvider
    extends $NotifierProvider<MovieDetailReview, MovieDetailReviewState> {
  MovieDetailReviewProvider._({
    required MovieDetailReviewFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'movieDetailReviewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$movieDetailReviewHash();

  @override
  String toString() {
    return r'movieDetailReviewProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MovieDetailReview create() => MovieDetailReview();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MovieDetailReviewState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MovieDetailReviewState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MovieDetailReviewProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$movieDetailReviewHash() => r'84ddcddeac54afddacbab042cb38172fac952bdb';

final class MovieDetailReviewFamily extends $Family
    with
        $ClassFamilyOverride<
          MovieDetailReview,
          MovieDetailReviewState,
          MovieDetailReviewState,
          MovieDetailReviewState,
          String
        > {
  MovieDetailReviewFamily._()
    : super(
        retry: null,
        name: r'movieDetailReviewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MovieDetailReviewProvider call(String movieNumber) =>
      MovieDetailReviewProvider._(argument: movieNumber, from: this);

  @override
  String toString() => r'movieDetailReviewProvider';
}

abstract class _$MovieDetailReview extends $Notifier<MovieDetailReviewState> {
  late final _$args = ref.$arg as String;
  String get movieNumber => _$args;

  MovieDetailReviewState build(String movieNumber);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<MovieDetailReviewState, MovieDetailReviewState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MovieDetailReviewState, MovieDetailReviewState>,
              MovieDetailReviewState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
