// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie_clips_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MovieClips)
final movieClipsProvider = MovieClipsFamily._();

final class MovieClipsProvider
    extends $NotifierProvider<MovieClips, MovieClipsState> {
  MovieClipsProvider._({
    required MovieClipsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'movieClipsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$movieClipsHash();

  @override
  String toString() {
    return r'movieClipsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MovieClips create() => MovieClips();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MovieClipsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MovieClipsState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MovieClipsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$movieClipsHash() => r'eac2fe090a29b82691c925ecd72eb4cf95363b12';

final class MovieClipsFamily extends $Family
    with
        $ClassFamilyOverride<
          MovieClips,
          MovieClipsState,
          MovieClipsState,
          MovieClipsState,
          String
        > {
  MovieClipsFamily._()
    : super(
        retry: null,
        name: r'movieClipsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MovieClipsProvider call(String movieNumber) =>
      MovieClipsProvider._(argument: movieNumber, from: this);

  @override
  String toString() => r'movieClipsProvider';
}

abstract class _$MovieClips extends $Notifier<MovieClipsState> {
  late final _$args = ref.$arg as String;
  String get movieNumber => _$args;

  MovieClipsState build(String movieNumber);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<MovieClipsState, MovieClipsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MovieClipsState, MovieClipsState>,
              MovieClipsState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
