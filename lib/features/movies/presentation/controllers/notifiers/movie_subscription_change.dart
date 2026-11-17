import 'package:flutter/foundation.dart';

/// 一次跨页订阅变更事件的载荷。
@immutable
class MovieSubscriptionChange {
  const MovieSubscriptionChange({
    required this.movieNumber,
    required this.isSubscribed,
    this.fromBatch = false,
  });

  final String movieNumber;
  final bool isSubscribed;

  /// 是否来自显式批量操作（多选批量 / 强制取消流程）。状态筛选视图据此决定
  /// 是否即时移出已翻转的行；单条心形切换一律保留行、就地翻态。
  final bool fromBatch;
}
