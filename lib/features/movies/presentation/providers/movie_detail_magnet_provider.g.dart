// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie_detail_magnet_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MovieDetailMagnet)
final movieDetailMagnetProvider = MovieDetailMagnetFamily._();

final class MovieDetailMagnetProvider
    extends $NotifierProvider<MovieDetailMagnet, MovieDetailMagnetState> {
  MovieDetailMagnetProvider._({
    required MovieDetailMagnetFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'movieDetailMagnetProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$movieDetailMagnetHash();

  @override
  String toString() {
    return r'movieDetailMagnetProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MovieDetailMagnet create() => MovieDetailMagnet();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MovieDetailMagnetState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MovieDetailMagnetState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MovieDetailMagnetProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$movieDetailMagnetHash() => r'd6c416b4ce32fb0c69d49cca1488c70a6b90ad2a';

final class MovieDetailMagnetFamily extends $Family
    with
        $ClassFamilyOverride<
          MovieDetailMagnet,
          MovieDetailMagnetState,
          MovieDetailMagnetState,
          MovieDetailMagnetState,
          String
        > {
  MovieDetailMagnetFamily._()
    : super(
        retry: null,
        name: r'movieDetailMagnetProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MovieDetailMagnetProvider call(String movieNumber) =>
      MovieDetailMagnetProvider._(argument: movieNumber, from: this);

  @override
  String toString() => r'movieDetailMagnetProvider';
}

abstract class _$MovieDetailMagnet extends $Notifier<MovieDetailMagnetState> {
  late final _$args = ref.$arg as String;
  String get movieNumber => _$args;

  MovieDetailMagnetState build(String movieNumber);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<MovieDetailMagnetState, MovieDetailMagnetState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MovieDetailMagnetState, MovieDetailMagnetState>,
              MovieDetailMagnetState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
