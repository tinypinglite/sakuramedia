// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sse_event_stream_client_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 全局 SSE 流客户端（原生装配）。dispose 与 provider 生命周期配对。

@ProviderFor(sseEventStreamClient)
final sseEventStreamClientProvider = SseEventStreamClientProvider._();

/// 全局 SSE 流客户端（原生装配）。dispose 与 provider 生命周期配对。

final class SseEventStreamClientProvider
    extends
        $FunctionalProvider<
          SseEventStreamClient,
          SseEventStreamClient,
          SseEventStreamClient
        >
    with $Provider<SseEventStreamClient> {
  /// 全局 SSE 流客户端（原生装配）。dispose 与 provider 生命周期配对。
  SseEventStreamClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sseEventStreamClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sseEventStreamClientHash();

  @$internal
  @override
  $ProviderElement<SseEventStreamClient> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SseEventStreamClient create(Ref ref) {
    return sseEventStreamClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SseEventStreamClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SseEventStreamClient>(value),
    );
  }
}

String _$sseEventStreamClientHash() =>
    r'cd67e4307aebe739d1e0fb95c97353614b6ffd63';
