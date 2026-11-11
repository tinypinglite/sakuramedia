// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie_detail_interaction_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MovieDetailInteraction)
final movieDetailInteractionProvider = MovieDetailInteractionFamily._();

final class MovieDetailInteractionProvider
    extends
        $NotifierProvider<MovieDetailInteraction, MovieDetailInteractionState> {
  MovieDetailInteractionProvider._({
    required MovieDetailInteractionFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'movieDetailInteractionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$movieDetailInteractionHash();

  @override
  String toString() {
    return r'movieDetailInteractionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MovieDetailInteraction create() => MovieDetailInteraction();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MovieDetailInteractionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MovieDetailInteractionState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MovieDetailInteractionProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$movieDetailInteractionHash() =>
    r'802018973cfef71101e635ac3cde9ed07cc6c205';

final class MovieDetailInteractionFamily extends $Family
    with
        $ClassFamilyOverride<
          MovieDetailInteraction,
          MovieDetailInteractionState,
          MovieDetailInteractionState,
          MovieDetailInteractionState,
          String
        > {
  MovieDetailInteractionFamily._()
    : super(
        retry: null,
        name: r'movieDetailInteractionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MovieDetailInteractionProvider call(String movieNumber) =>
      MovieDetailInteractionProvider._(argument: movieNumber, from: this);

  @override
  String toString() => r'movieDetailInteractionProvider';
}

abstract class _$MovieDetailInteraction
    extends $Notifier<MovieDetailInteractionState> {
  late final _$args = ref.$arg as String;
  String get movieNumber => _$args;

  MovieDetailInteractionState build(String movieNumber);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<MovieDetailInteractionState, MovieDetailInteractionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                MovieDetailInteractionState,
                MovieDetailInteractionState
              >,
              MovieDetailInteractionState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
