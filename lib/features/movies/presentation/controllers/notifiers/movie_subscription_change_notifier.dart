import 'package:flutter/foundation.dart';

class MovieSubscriptionChange {
  const MovieSubscriptionChange({
    required this.movieNumber,
    required this.isSubscribed,
  });

  final String movieNumber;
  final bool isSubscribed;
}

class MovieSubscriptionChangeNotifier extends ChangeNotifier {
  MovieSubscriptionChange? _lastChange;
  MovieSubscriptionChange? get lastChange => _lastChange;

  List<MovieSubscriptionChange>? _lastBatch;

  /// 最近一次广播的批量变更；单条 [reportChange] 只写 [_lastChange]，
  /// 监听方读到这里为 null 时按单条路径打补丁。
  List<MovieSubscriptionChange>? get lastBatch => _lastBatch;

  void reportChange({required String movieNumber, required bool isSubscribed}) {
    _lastBatch = null;
    _lastChange = MovieSubscriptionChange(
      movieNumber: movieNumber,
      isSubscribed: isSubscribed,
    );
    notifyListeners();
  }

  /// 批量变更一次广播；[_lastChange] 同步写入 changes.last，兼容仍走单条
  /// [lastChange] 补丁路径的旧监听方。
  void reportBatch(List<MovieSubscriptionChange> changes) {
    if (changes.isEmpty) {
      return;
    }
    _lastBatch = List<MovieSubscriptionChange>.unmodifiable(changes);
    _lastChange = changes.last;
    notifyListeners();
  }

  /// 监听方消费本次广播的统一入口：批量优先、否则回退单条，一律以列表形式交给
  /// [apply]（多为 `controller.applySubscriptionChanges`）。
  ///
  /// 收敛此前 9 处 `_onMovieSubscriptionChanged` 里逐字重复的
  /// 「读 lastBatch → 命中就 applyChanges、否则读 lastChange → applyChange」分派。
  void consumePendingChanges(
    void Function(List<MovieSubscriptionChange> changes) apply,
  ) {
    final batch = _lastBatch;
    if (batch != null) {
      apply(batch);
      return;
    }
    final change = _lastChange;
    if (change == null) {
      return;
    }
    apply(<MovieSubscriptionChange>[change]);
  }
}
