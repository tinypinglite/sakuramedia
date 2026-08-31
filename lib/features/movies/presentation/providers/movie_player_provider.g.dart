// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie_player_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 生产依赖装配与播放器状态机解耦，测试可直接 override 这一层。

@ProviderFor(moviePlayerDependencies)
final moviePlayerDependenciesProvider = MoviePlayerDependenciesProvider._();

/// 生产依赖装配与播放器状态机解耦，测试可直接 override 这一层。

final class MoviePlayerDependenciesProvider
    extends
        $FunctionalProvider<
          MoviePlayerDependencies,
          MoviePlayerDependencies,
          MoviePlayerDependencies
        >
    with $Provider<MoviePlayerDependencies> {
  /// 生产依赖装配与播放器状态机解耦，测试可直接 override 这一层。
  MoviePlayerDependenciesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'moviePlayerDependenciesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$moviePlayerDependenciesHash();

  @$internal
  @override
  $ProviderElement<MoviePlayerDependencies> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MoviePlayerDependencies create(Ref ref) {
    return moviePlayerDependencies(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MoviePlayerDependencies value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MoviePlayerDependencies>(value),
    );
  }
}

String _$moviePlayerDependenciesHash() =>
    r'9f65ead08f7fa3cadd34517d9bf8a50d363cb938';

/// 单个播放器路由的业务状态；页面离开后自动销毁并停止定时上报。

@ProviderFor(MoviePlayer)
final moviePlayerProvider = MoviePlayerFamily._();

/// 单个播放器路由的业务状态；页面离开后自动销毁并停止定时上报。
final class MoviePlayerProvider
    extends $NotifierProvider<MoviePlayer, MoviePlayerState> {
  /// 单个播放器路由的业务状态；页面离开后自动销毁并停止定时上报。
  MoviePlayerProvider._({
    required MoviePlayerFamily super.from,
    required MoviePlayerScope super.argument,
  }) : super(
         retry: null,
         name: r'moviePlayerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$moviePlayerHash();

  @override
  String toString() {
    return r'moviePlayerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MoviePlayer create() => MoviePlayer();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MoviePlayerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MoviePlayerState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MoviePlayerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$moviePlayerHash() => r'c956e20b0a78eeced0ed01efa639238b01a4dfc6';

/// 单个播放器路由的业务状态；页面离开后自动销毁并停止定时上报。

final class MoviePlayerFamily extends $Family
    with
        $ClassFamilyOverride<
          MoviePlayer,
          MoviePlayerState,
          MoviePlayerState,
          MoviePlayerState,
          MoviePlayerScope
        > {
  MoviePlayerFamily._()
    : super(
        retry: null,
        name: r'moviePlayerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 单个播放器路由的业务状态；页面离开后自动销毁并停止定时上报。

  MoviePlayerProvider call(MoviePlayerScope scope) =>
      MoviePlayerProvider._(argument: scope, from: this);

  @override
  String toString() => r'moviePlayerProvider';
}

/// 单个播放器路由的业务状态；页面离开后自动销毁并停止定时上报。

abstract class _$MoviePlayer extends $Notifier<MoviePlayerState> {
  late final _$args = ref.$arg as MoviePlayerScope;
  MoviePlayerScope get scope => _$args;

  MoviePlayerState build(MoviePlayerScope scope);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<MoviePlayerState, MoviePlayerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MoviePlayerState, MoviePlayerState>,
              MoviePlayerState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
