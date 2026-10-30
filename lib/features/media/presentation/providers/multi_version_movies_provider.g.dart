// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'multi_version_movies_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MultiVersionMovies)
final multiVersionMoviesProvider = MultiVersionMoviesFamily._();

final class MultiVersionMoviesProvider
    extends
        $AsyncNotifierProvider<
          MultiVersionMovies,
          PagedListState<MultiVersionMovieDto>
        > {
  MultiVersionMoviesProvider._({
    required MultiVersionMoviesFamily super.from,
    required ({bool includeVr, bool includeFc2, bool includeProcessed})
    super.argument,
  }) : super(
         retry: kNoAsyncNotifierRetry,
         name: r'multiVersionMoviesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$multiVersionMoviesHash();

  @override
  String toString() {
    return r'multiVersionMoviesProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  MultiVersionMovies create() => MultiVersionMovies();

  @override
  bool operator ==(Object other) {
    return other is MultiVersionMoviesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$multiVersionMoviesHash() =>
    r'7a704dd5fd82639ce72996107f00f9c75e55fc4e';

final class MultiVersionMoviesFamily extends $Family
    with
        $ClassFamilyOverride<
          MultiVersionMovies,
          AsyncValue<PagedListState<MultiVersionMovieDto>>,
          PagedListState<MultiVersionMovieDto>,
          FutureOr<PagedListState<MultiVersionMovieDto>>,
          ({bool includeVr, bool includeFc2, bool includeProcessed})
        > {
  MultiVersionMoviesFamily._()
    : super(
        retry: kNoAsyncNotifierRetry,
        name: r'multiVersionMoviesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MultiVersionMoviesProvider call({
    bool includeVr = false,
    bool includeFc2 = false,
    bool includeProcessed = false,
  }) => MultiVersionMoviesProvider._(
    argument: (
      includeVr: includeVr,
      includeFc2: includeFc2,
      includeProcessed: includeProcessed,
    ),
    from: this,
  );

  @override
  String toString() => r'multiVersionMoviesProvider';
}

abstract class _$MultiVersionMovies
    extends $AsyncNotifier<PagedListState<MultiVersionMovieDto>> {
  late final _$args =
      ref.$arg as ({bool includeVr, bool includeFc2, bool includeProcessed});
  bool get includeVr => _$args.includeVr;
  bool get includeFc2 => _$args.includeFc2;
  bool get includeProcessed => _$args.includeProcessed;

  FutureOr<PagedListState<MultiVersionMovieDto>> build({
    bool includeVr = false,
    bool includeFc2 = false,
    bool includeProcessed = false,
  });
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<PagedListState<MultiVersionMovieDto>>,
              PagedListState<MultiVersionMovieDto>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<PagedListState<MultiVersionMovieDto>>,
                PagedListState<MultiVersionMovieDto>
              >,
              AsyncValue<PagedListState<MultiVersionMovieDto>>,
              Object?,
              Object?
            >;
    return element.handleCreate(
      ref,
      () => build(
        includeVr: _$args.includeVr,
        includeFc2: _$args.includeFc2,
        includeProcessed: _$args.includeProcessed,
      ),
    );
  }
}
