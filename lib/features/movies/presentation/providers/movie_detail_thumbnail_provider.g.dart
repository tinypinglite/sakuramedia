// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie_detail_thumbnail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MovieDetailThumbnail)
final movieDetailThumbnailProvider = MovieDetailThumbnailFamily._();

final class MovieDetailThumbnailProvider
    extends $NotifierProvider<MovieDetailThumbnail, MovieDetailThumbnailState> {
  MovieDetailThumbnailProvider._({
    required MovieDetailThumbnailFamily super.from,
    required int? super.argument,
  }) : super(
         retry: null,
         name: r'movieDetailThumbnailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$movieDetailThumbnailHash();

  @override
  String toString() {
    return r'movieDetailThumbnailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MovieDetailThumbnail create() => MovieDetailThumbnail();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MovieDetailThumbnailState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MovieDetailThumbnailState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MovieDetailThumbnailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$movieDetailThumbnailHash() =>
    r'24601d705af52765f5a51458d092b0577cd57197';

final class MovieDetailThumbnailFamily extends $Family
    with
        $ClassFamilyOverride<
          MovieDetailThumbnail,
          MovieDetailThumbnailState,
          MovieDetailThumbnailState,
          MovieDetailThumbnailState,
          int?
        > {
  MovieDetailThumbnailFamily._()
    : super(
        retry: null,
        name: r'movieDetailThumbnailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MovieDetailThumbnailProvider call({required int? mediaId}) =>
      MovieDetailThumbnailProvider._(argument: mediaId, from: this);

  @override
  String toString() => r'movieDetailThumbnailProvider';
}

abstract class _$MovieDetailThumbnail
    extends $Notifier<MovieDetailThumbnailState> {
  late final _$args = ref.$arg as int?;
  int? get mediaId => _$args;

  MovieDetailThumbnailState build({required int? mediaId});
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<MovieDetailThumbnailState, MovieDetailThumbnailState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MovieDetailThumbnailState, MovieDetailThumbnailState>,
              MovieDetailThumbnailState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(mediaId: _$args));
  }
}
