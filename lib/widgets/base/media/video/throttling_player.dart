import 'package:media_kit/media_kit.dart';
import 'package:sakuramedia/core/media/media_source_metadata.dart';
import 'package:sakuramedia/core/media/playback_proxy_policy.dart';
import 'package:sakuramedia/core/media/playback_range_proxy.dart';
import 'package:sakuramedia/core/media/playback_source.dart';
import 'package:sakuramedia/core/network/debug_capture_proxy.dart';

/// `Player` 的薄包装，在 `seek()` 上做 **in-flight coalescing**：任意时刻至多
/// 1 次 seek 在飞，期间的新 seek 请求**覆盖** pending 目标（不排队追加）。
///
/// ## 为什么需要它
///
/// 播放 CDN 对**同一签名 URL 的并发连接数通常有限**，超出可能直接返回 403。
/// 而 media_kit_video 的 `MaterialSeekBar` 在 `onPointerMove` 里每帧调
/// `player.seek()`——鼠标拖动进度条时 seek 调用速率高达 30-60 次/秒。libmpv
/// 每次 seek 都要在新位置开 range 请求（关旧连接 + 开新连接一次都要 100-200ms），
/// 开的速率 > 关的速率，短时间内并发连接就会超过服务端上限，之后所有直链请求
/// 都可能失败。
///
/// 直接改 `MaterialSeekBar` 得 fork media_kit_video；重写自定义 seek bar 又要
/// 复刻整套 overlay（seek 手势、buffer bar、自动隐藏 timer 等）。**在 Player 层
/// 拦截 `seek()` 是最小侵入**——所有调用点（seek bar、controller、resume、
/// thumbnail 跳转、快捷键）自动生效，UI 一行不动。
///
/// ## 语义
///
/// - 无 seek 在飞时：立刻 `super.seek(duration)`
/// - 有 seek 在飞时：把 `duration` 记进 `_pendingSeek`（**覆盖**旧 pending）并
///   立刻返回；等当前 seek 完成后循环消化 pending
/// - 用户拖动 60 次/秒 → libmpv 实际见到的 seek 命令会明显减少
///
/// 声明启用代理的 provider 会在 [open] 时切到进程内 loopback Range 代理；
/// 上游并发由 provider policy 决定，seek 合并只负责降低命令频率，不能替代
/// 网络层闸门。HLS 的播放列表和分片地址改写不在本代理能力内，因此 `m3u8`
/// 保持直连。
///
/// **返回的 `Future` 在 seek 排队时不等待真实执行完毕**——这里刻意如此。
/// 拖动过程中所有 seek 都是 unawaited 的（`MaterialSeekBar` 里就是 no-await
/// 调用），少数需要"seek 完再干下一步"的路径（resume 播放）本身不会与拖动
/// 并发，见不到 coalescing。
class ThrottlingPlayer extends Player {
  ThrottlingPlayer({
    super.configuration,
    super.platformPlayer,
    this.playbackProxy,
  });

  /// 本地流式代理已经接住网络字节，关闭 libmpv 自己的磁盘缓存并缩短预读，
  /// 避免第二次落盘和大段无用上游读取。
  static const _proxiedPlaybackProperties = <String, String>{
    'cache-on-disk': 'no',
    'cache-secs': '2',
    'demuxer-max-bytes': '8388608',
    'demuxer-max-back-bytes': '8388608',
  };

  Duration? _pendingSeek;
  bool _seekInFlight = false;
  bool _proxiedProfileApplied = false;
  final PlaybackRangeProxy? playbackProxy;

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    final proxied = await _proxyPlayable(playable);
    final hasLocalProxy = switch (proxied) {
      Media media => _isLocalRangeProxy(media.uri),
      Playlist playlist => playlist.medias.any(
        (media) => _isLocalRangeProxy(media.uri),
      ),
      _ => false,
    };
    await _configurePlaybackNetwork(hasLocalProxy: hasLocalProxy);
    await super.open(proxied, play: play);
  }

  Future<Playable> _proxyPlayable(Playable playable) async {
    final medias = switch (playable) {
      Media media => <Media>[media],
      Playlist playlist => playlist.medias,
      _ => const <Media>[],
    };
    if (!medias.any((media) => _proxyConfigFor(media) != null)) {
      return playable;
    }

    try {
      final wrapped = <Media>[];
      for (final media in medias) {
        final config = _proxyConfigFor(media);
        if (config == null) {
          wrapped.add(media);
          continue;
        }
        final proxy =
            playbackProxy ??
            await LoopbackRangePlaybackProxy.shared(config.policy);
        final localUrl = await proxy.localUrlFor(
          media.uri,
          headers: media.httpHeaders ?? const <String, String>{},
          cacheKey: playbackProxyCacheKey(
            providerKey: config.providerKey,
            policy: config.policy,
            url: media.uri,
          ),
        );
        wrapped.add(
          Media(
            localUrl.toString(),
            extras: <String, dynamic>{
              ...?media.extras,
              originalMediaUriExtraKey: media.uri,
              playbackProviderKeyExtraKey: config.providerKey,
            },
            httpHeaders: media.httpHeaders,
            start: media.start,
            end: media.end,
          ),
        );
      }
      return switch (playable) {
        Playlist playlist => playlist.copyWith(medias: wrapped),
        _ => wrapped.single,
      };
    } catch (_) {
      // A local proxy failure must not make an otherwise playable source
      // unplayable. Fall back to the original URL and let mpv report the
      // upstream error if the source itself is unavailable.
      return playable;
    }
  }

  static ({String providerKey, PlaybackProxyPolicy policy})? _proxyConfigFor(
    Media media,
  ) {
    final providerKey = playbackProviderKeyForMedia(media);
    if (providerKey == null) {
      return null;
    }
    final policy = playbackProxyPolicyForProvider(providerKey);
    if (!policy.enabled || _isLocalRangeProxy(media.uri)) {
      return null;
    }
    final originalUri = Uri.tryParse(
      originalMediaUriFromExtras(media.extras) ?? media.uri,
    );
    if (originalUri?.path.toLowerCase().endsWith('.m3u8') ?? false) {
      return null;
    }
    return (providerKey: providerKey, policy: policy);
  }

  static bool _isLocalRangeProxy(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.host != '127.0.0.1' &&
            uri.host != 'localhost' &&
            uri.host != '::1')) {
      return false;
    }
    return uri.path == '/v' && uri.queryParameters.containsKey('k');
  }

  Future<void> _configurePlaybackNetwork({required bool hasLocalProxy}) async {
    final platformPlayer = platform;
    if (platformPlayer == null) {
      return;
    }
    try {
      final dynamic nativePlayer = platformPlayer;
      if (hasLocalProxy) {
        for (final property in _proxiedPlaybackProperties.entries) {
          await nativePlayer.setProperty(property.key, property.value);
        }
        _proxiedProfileApplied = true;
      } else if (_proxiedProfileApplied) {
        // 恢复 media_kit 初始化时使用的普通媒体缓存默认值。
        await nativePlayer.setProperty('cache-on-disk', 'yes');
        await nativePlayer.setProperty('cache-secs', '3600000');
        await nativePlayer.setProperty('demuxer-max-bytes', '33554432');
        await nativePlayer.setProperty('demuxer-max-back-bytes', '33554432');
        _proxiedProfileApplied = false;
      }
      if (debugCaptureProxyActive) {
        await nativePlayer.setProperty(
          'stream-lavf-o',
          hasLocalProxy ? '' : debugCaptureStreamLavfProxyOptions,
        );
      }
    } catch (_) {
      // 网络读取策略是尽力而为，不能因为某个平台缺少属性而阻断播放。
    }
  }

  @override
  Future<void> seek(Duration duration) async {
    if (_seekInFlight) {
      // 覆盖：拖动连打时只保留最新目标，中间的中间态直接丢弃
      _pendingSeek = duration;
      return;
    }
    _seekInFlight = true;
    try {
      await super.seek(duration);
      // 拖动过程中攒下的最新目标位置：连续消化直到没有新的 pending
      while (_pendingSeek != null) {
        final next = _pendingSeek!;
        _pendingSeek = null;
        await super.seek(next);
      }
    } finally {
      _seekInFlight = false;
      // super.seek 抛错时丢掉 pending：那是几百毫秒前的过期拖动位置，
      // 不该在错误路径里追补一次意外 seek
      _pendingSeek = null;
    }
  }
}
