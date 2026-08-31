import 'package:media_kit/media_kit.dart';

/// `Player` 的薄包装，在 `seek()` 上做 **in-flight coalescing**：任意时刻至多
/// 1 次 seek 在飞，期间的新 seek 请求**覆盖** pending 目标（不排队追加）。
///
/// ## 为什么需要它
///
/// 115 CDN 对**同一签名 URL 的并发连接上限 ≈ 2 条**，超出即回 `403 115 pmt`。
/// 而 media_kit_video 的 `MaterialSeekBar` 在 `onPointerMove` 里每帧调
/// `player.seek()`——鼠标拖动进度条时 seek 调用速率高达 30-60 次/秒。libmpv
/// 每次 seek 都要在新位置开 range 请求（关旧连接 + 开新连接一次都要 100-200ms），
/// 开的速率 > 关的速率，2-3 秒内并发连接就堆到 3+ 条打爆 115 的上限，
/// 之后所有直链请求全部 403。
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
/// - 用户拖动 60 次/秒 → libmpv 实际见到的 seek 频率 ≈ 5-10 次/秒（受
///   单次 seek 完成耗时限制），CDN 并发始终 ≤ 1
///
/// **返回的 `Future` 在 seek 排队时不等待真实执行完毕**——这里刻意如此。
/// 拖动过程中所有 seek 都是 unawaited 的（`MaterialSeekBar` 里就是 no-await
/// 调用），少数需要"seek 完再干下一步"的路径（resume 播放）本身不会与拖动
/// 并发，见不到 coalescing。
class ThrottlingPlayer extends Player {
  ThrottlingPlayer({super.configuration});

  Duration? _pendingSeek;
  bool _seekInFlight = false;

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
