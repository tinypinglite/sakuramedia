import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/subscriptions/data/dto/movie_subscription_list_item_dto.dart';
import 'package:sakuramedia/features/subscriptions/presentation/movie_subscription_filter_state.dart';

/// 正在执行的批量动作。
///
/// 用单个可空枚举而不是三个 bool：批量动作互斥，「只让正在执行的那一个
/// `isLoading`、其余禁用」这条 UI 约定用它表达是天然的，也堵死了三个 bool 同时
/// 为 true 的非法态。
enum MovieSubscriptionBatchAction {
  /// 批量取消订阅。
  unsubscribe,

  /// 一键重置**全部**「已放弃」（不依赖多选）。
  resetAllExhausted,
}

/// 单条 / 批量动作的统一结果。
///
/// [affectedCount] 的含义由调用方按具体动作解释。
@immutable
class MovieSubscriptionActionResult {
  const MovieSubscriptionActionResult.success(this.affectedCount)
    : errorMessage = null;

  const MovieSubscriptionActionResult.failure(String message)
    : affectedCount = 0,
      errorMessage = message;

  final int affectedCount;
  final String? errorMessage;

  bool get hasError => errorMessage != null;
}

/// 「订阅管理」页的组合 State：分页列表 + 筛选 + 多选 + 进行中的动作。
///
/// - [paged] 由 `PagedAsyncNotifierMixin` 维护；
/// - [filter] 走「筛选状态驱动」范式，notifier 内部另存一份字段供 `fetchPage` 读；
/// - [selectionMode] / [selectedMovieNumbers] 是显式多选态——常规态整卡点击是
///   「打开影片详情」，只有进了多选才改成勾选，避免两种语义抢同一个手势。
@immutable
class MovieSubscriptionManagerState {
  const MovieSubscriptionManagerState({
    required this.paged,
    required this.filter,
    this.selectionMode = false,
    this.selectedMovieNumbers = const <String>{},
    this.pendingMovieNumbers = const <String>{},
    this.runningBatchAction,
  });

  static const MovieSubscriptionManagerState initial =
      MovieSubscriptionManagerState(
        paged: PagedListState<MovieSubscriptionListItemDto>(),
        filter: MovieSubscriptionFilterState.initial,
      );

  final PagedListState<MovieSubscriptionListItemDto> paged;
  final MovieSubscriptionFilterState filter;

  final bool selectionMode;
  final Set<String> selectedMovieNumbers;

  /// 正在执行行内动作（重置 / 取消订阅）的番号——该行按钮转 spinner。
  final Set<String> pendingMovieNumbers;

  final MovieSubscriptionBatchAction? runningBatchAction;

  int get selectionCount => selectedMovieNumbers.length;
  bool get hasSelection => selectedMovieNumbers.isNotEmpty;
  bool get isBatchRunning => runningBatchAction != null;

  bool isSelected(String movieNumber) =>
      selectedMovieNumbers.contains(movieNumber);

  bool isPending(String movieNumber) =>
      pendingMovieNumbers.contains(movieNumber);

  bool isBatchActionRunning(MovieSubscriptionBatchAction action) =>
      runningBatchAction == action;

  MovieSubscriptionManagerState copyWith({
    PagedListState<MovieSubscriptionListItemDto>? paged,
    MovieSubscriptionFilterState? filter,
    bool? selectionMode,
    Set<String>? selectedMovieNumbers,
    Set<String>? pendingMovieNumbers,
    Object? runningBatchAction = _kSentinel,
  }) {
    return MovieSubscriptionManagerState(
      paged: paged ?? this.paged,
      filter: filter ?? this.filter,
      selectionMode: selectionMode ?? this.selectionMode,
      selectedMovieNumbers: selectedMovieNumbers ?? this.selectedMovieNumbers,
      pendingMovieNumbers: pendingMovieNumbers ?? this.pendingMovieNumbers,
      // 可空且「清空」有独立语义（动作结束），走哨兵。
      runningBatchAction:
          identical(runningBatchAction, _kSentinel)
              ? this.runningBatchAction
              : runningBatchAction as MovieSubscriptionBatchAction?,
    );
  }
}

const Object _kSentinel = Object();
