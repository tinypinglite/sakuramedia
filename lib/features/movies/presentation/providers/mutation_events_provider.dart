import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_collection_type_dto.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/notifiers/movie_collection_type_change.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/notifiers/movie_subscription_change.dart';

export 'package:sakuramedia/features/movies/presentation/controllers/notifiers/movie_collection_type_change.dart';
export 'package:sakuramedia/features/movies/presentation/controllers/notifiers/movie_subscription_change.dart';

part 'mutation_events_provider.g.dart';

/// 跨页订阅变更广播 —— 单一 provider 兼「事件流 + 发布 API」。
///
/// **消费方**：`ref.listen(movieSubscriptionEventsProvider, (prev, next) {
/// final changes = next.value; if (changes != null) applyChanges(changes); })`
/// 收到后做**就地补丁**（移除 / 改字段），不 invalidate 整页重拉。
///
/// **发起方**：`ref.read(movieSubscriptionEventsProvider.notifier).reportChange(...)`
/// 或 `reportBatch(...)`。单条 / 批量都统一成列表广播一次。
///
/// 迁移前形态：`MovieSubscriptionChangeNotifier extends ChangeNotifier` +
/// broadcaster 桥 provider + Stream 派生 provider 三件套；
/// 现在合成单一 `@Riverpod` class Notifier，`StreamController.broadcast(sync: true)`
/// 承载事件流，`reportXxx` 直接推入。**离屏挂起**：没有监听者时 riverpod 会挂起
/// 派生 Stream，事件缓冲、恢复监听时补投（写测试须挂监听者）。
@Riverpod(keepAlive: true)
class MovieSubscriptionEvents extends _$MovieSubscriptionEvents {
  final StreamController<List<MovieSubscriptionChange>> _controller =
      StreamController<List<MovieSubscriptionChange>>.broadcast(sync: true);

  @override
  Stream<List<MovieSubscriptionChange>> build() {
    ref.onDispose(_controller.close);
    return _controller.stream;
  }

  /// 单条变更：等价原 `reportChange` + `notifyListeners`。
  void reportChange({
    required String movieNumber,
    required bool isSubscribed,
  }) {
    if (_controller.isClosed) return;
    _controller.add(<MovieSubscriptionChange>[
      MovieSubscriptionChange(
        movieNumber: movieNumber,
        isSubscribed: isSubscribed,
      ),
    ]);
  }

  /// 批量变更一次广播；空列表 no-op。
  void reportBatch(List<MovieSubscriptionChange> changes) {
    if (_controller.isClosed || changes.isEmpty) return;
    _controller.add(List<MovieSubscriptionChange>.unmodifiable(changes));
  }
}

/// 跨页合集类型（单体/合集）变更广播 —— 与 [MovieSubscriptionEvents] 同范式，
/// 每次广播携带单个 [MovieCollectionTypeChange]。
@Riverpod(keepAlive: true)
class MovieCollectionTypeEvents extends _$MovieCollectionTypeEvents {
  final StreamController<MovieCollectionTypeChange> _controller =
      StreamController<MovieCollectionTypeChange>.broadcast(sync: true);

  @override
  Stream<MovieCollectionTypeChange> build() {
    ref.onDispose(_controller.close);
    return _controller.stream;
  }

  void reportChange({
    required String movieNumber,
    required MovieCollectionType targetType,
  }) {
    if (_controller.isClosed) return;
    _controller.add(
      MovieCollectionTypeChange(
        movieNumber: movieNumber,
        targetType: targetType,
      ),
    );
  }
}

/// 删除资源后从服务端取得的影片状态，供已加载列表就地同步。
class MovieMediaChange {
  const MovieMediaChange({
    required this.movieNumber,
    required this.canPlay,
    required this.isSubscribed,
  });

  final String movieNumber;
  final bool canPlay;
  final bool isSubscribed;
}

@Riverpod(keepAlive: true)
class MovieMediaEvents extends _$MovieMediaEvents {
  final StreamController<MovieMediaChange> _controller =
      StreamController<MovieMediaChange>.broadcast(sync: true);

  @override
  Stream<MovieMediaChange> build() {
    ref.onDispose(_controller.close);
    return _controller.stream;
  }

  void reportChange(MovieMediaChange change) {
    if (_controller.isClosed) return;
    _controller.add(change);
  }
}
