import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_subscription_batch_dto.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/notifiers/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/paged_load_controller.dart';

typedef MovieSubscriptionWriter =
    Future<void> Function({required String movieNumber});

typedef MovieUnsubscriptionWriter =
    Future<void> Function({required String movieNumber, bool deleteMedia});

typedef MovieBatchSubscriptionWriter =
    Future<MovieSubscriptionBatchResultDto> Function({
      required List<String> movieNumbers,
    });

typedef MovieSubscriptionChangeReporter =
    void Function({required String movieNumber, required bool isSubscribed});

typedef MovieSubscriptionBatchReporter =
    void Function(List<MovieSubscriptionChange> changes);

/// 未接入批量端点时的兜底 stub：真正被调到就抛错，比运行到 null 更明确。
///
/// 作为具体控制器构造参数的默认值使用，故必须是公开的顶层函数。
Future<MovieSubscriptionBatchResultDto> unwiredMovieBatchSubscription({
  required List<String> movieNumbers,
}) {
  throw UnimplementedError(
    '当前分页控制器未接入批量订阅端点，请传入 batchSubscribeMovies / '
    'batchUnsubscribeMovies 后再调用 batchToggleSubscription。',
  );
}

enum MovieSubscriptionToggleStatus {
  subscribed,
  unsubscribed,
  blockedByMedia,
  failed,
  ignored,
}

class MovieSubscriptionToggleResult {
  const MovieSubscriptionToggleResult({required this.status, this.message});

  const MovieSubscriptionToggleResult.subscribed()
    : this(status: MovieSubscriptionToggleStatus.subscribed);

  const MovieSubscriptionToggleResult.unsubscribed()
    : this(status: MovieSubscriptionToggleStatus.unsubscribed);

  const MovieSubscriptionToggleResult.blockedByMedia()
    : this(status: MovieSubscriptionToggleStatus.blockedByMedia);

  const MovieSubscriptionToggleResult.failed({required String message})
    : this(status: MovieSubscriptionToggleStatus.failed, message: message);

  const MovieSubscriptionToggleResult.ignored()
    : this(status: MovieSubscriptionToggleStatus.ignored);

  final MovieSubscriptionToggleStatus status;
  final String? message;
}

/// 批量订阅/取消订阅在列表控制器一侧的最终结果。
///
/// 若请求本身失败（网络/服务端 5xx 等）由 [errorMessage] 承载，此时命中项已回滚。
/// 请求成功时按后端「部分成功」语义拆分：[skippedMovieNotFoundNumbers] 与
/// [skippedHasMediaNumbers] 直接映射后端 skipped 数组的两种 reason。
class MovieSubscriptionBatchToggleResult {
  const MovieSubscriptionBatchToggleResult({
    required this.requestedCount,
    required this.updatedCount,
    required this.skippedMovieNotFoundNumbers,
    required this.skippedHasMediaNumbers,
    this.errorMessage,
  });

  const MovieSubscriptionBatchToggleResult.failed({
    required this.requestedCount,
    required String message,
  }) : updatedCount = 0,
       skippedMovieNotFoundNumbers = const <String>[],
       skippedHasMediaNumbers = const <String>[],
       errorMessage = message;

  final int requestedCount;
  final int updatedCount;
  final List<String> skippedMovieNotFoundNumbers;
  final List<String> skippedHasMediaNumbers;
  final String? errorMessage;

  bool get hasError => errorMessage != null;
  int get skippedCount =>
      skippedMovieNotFoundNumbers.length + skippedHasMediaNumbers.length;

  /// 本次实际被后端跳过的番号（用于「保留跳过项仍选中」的 UI 行为）。
  Iterable<String> get allSkippedNumbers sync* {
    yield* skippedMovieNotFoundNumbers;
    yield* skippedHasMediaNumbers;
  }
}

/// 「列表项可订阅」的分页控制器能力：单条切换 + 批量切换 + 外部变更打补丁。
///
/// [PagedMovieSummaryController]（`MovieListItemDto`）与
/// `PagedRankedMovieController`（`RankedMovieListItemDto`）此前逐字重复同一套
/// 逻辑，差异仅在「怎么从条目取番号 / 读订阅态 / 写订阅态」——故把这三点抽成
/// 抽象方法由具体控制器实现，其余全部收敛到本 mixin。
///
/// 订阅端点与广播回调声明为抽象 getter，具体控制器用构造注入的 `final` 字段
/// 天然满足。
mixin MovieSubscribableListMixin<T> on PagedLoadController<T> {
  /// 从列表项取番号（订阅逻辑的唯一身份键）。
  String movieNumberOf(T item);

  /// 读列表项当前订阅态。
  bool isSubscribedOf(T item);

  /// 产出订阅态改写后的新列表项（DTO 不可变，走各自的 `copyWith`）。
  T copyWithSubscribed(T item, bool isSubscribed);

  MovieSubscriptionWriter get subscribeMovie;
  MovieUnsubscriptionWriter get unsubscribeMovie;
  MovieBatchSubscriptionWriter get batchSubscribeMovies;
  MovieBatchSubscriptionWriter get batchUnsubscribeMovies;
  MovieSubscriptionChangeReporter? get onSubscriptionChanged;
  MovieSubscriptionBatchReporter? get onSubscriptionsBatchChanged;

  final Set<String> _updatingMovieNumbers = <String>{};

  bool isSubscriptionUpdating(String movieNumber) {
    return _updatingMovieNumbers.contains(movieNumber);
  }

  int _indexOfMovie(String movieNumber) {
    return mutableItems.indexWhere(
      (item) => movieNumberOf(item) == movieNumber,
    );
  }

  Future<MovieSubscriptionToggleResult> toggleSubscription({
    required String movieNumber,
  }) async {
    final index = _indexOfMovie(movieNumber);
    if (index == -1 || _updatingMovieNumbers.contains(movieNumber)) {
      return const MovieSubscriptionToggleResult.ignored();
    }

    final movie = mutableItems[index];
    final wasSubscribed = isSubscribedOf(movie);
    _updatingMovieNumbers.add(movieNumber);
    notifyListenersSafely();

    try {
      if (wasSubscribed) {
        await unsubscribeMovie(movieNumber: movieNumber, deleteMedia: false);
        mutableItems[index] = copyWithSubscribed(movie, false);
        onSubscriptionChanged?.call(
          movieNumber: movieNumber,
          isSubscribed: false,
        );
        return const MovieSubscriptionToggleResult.unsubscribed();
      }

      await subscribeMovie(movieNumber: movieNumber);
      mutableItems[index] = copyWithSubscribed(movie, true);
      onSubscriptionChanged?.call(movieNumber: movieNumber, isSubscribed: true);
      return const MovieSubscriptionToggleResult.subscribed();
    } catch (error) {
      if (_isBlockedByMedia(error)) {
        return const MovieSubscriptionToggleResult.blockedByMedia();
      }
      return MovieSubscriptionToggleResult.failed(
        message: apiErrorMessage(
          error,
          fallback: wasSubscribed ? '取消订阅影片失败' : '订阅影片失败',
        ),
      );
    } finally {
      _updatingMovieNumbers.remove(movieNumber);
      notifyListenersSafely();
    }
  }

  void removeItem(String movieNumber) {
    final index = _indexOfMovie(movieNumber);
    if (index == -1) {
      return;
    }
    mutableItems.removeAt(index);
    mutableTotal = (mutableTotal - 1).clamp(0, mutableTotal);
    notifyListenersSafely();
  }

  void applySubscriptionChange({
    required String movieNumber,
    required bool isSubscribed,
    bool removeIfUnsubscribed = false,
  }) {
    final index = _indexOfMovie(movieNumber);
    if (index == -1) {
      return;
    }
    if (!isSubscribed && removeIfUnsubscribed) {
      removeItem(movieNumber);
      return;
    }

    final movie = mutableItems[index];
    if (isSubscribedOf(movie) == isSubscribed) {
      return;
    }
    mutableItems[index] = copyWithSubscribed(movie, isSubscribed);
    notifyListenersSafely();
  }

  /// 一次消费多条变更；只在真正打了补丁时通知一次，避免 N 次刷新。
  void applySubscriptionChanges(
    List<MovieSubscriptionChange> changes, {
    bool removeIfUnsubscribed = false,
  }) {
    if (changes.isEmpty) {
      return;
    }
    var mutated = false;
    for (final change in changes) {
      final index = _indexOfMovie(change.movieNumber);
      if (index == -1) {
        continue;
      }
      if (!change.isSubscribed && removeIfUnsubscribed) {
        mutableItems.removeAt(index);
        mutableTotal = (mutableTotal - 1).clamp(0, mutableTotal);
        mutated = true;
        continue;
      }
      final movie = mutableItems[index];
      if (isSubscribedOf(movie) == change.isSubscribed) {
        continue;
      }
      mutableItems[index] = copyWithSubscribed(movie, change.isSubscribed);
      mutated = true;
    }
    if (mutated) {
      notifyListenersSafely();
    }
  }

  /// 批量订阅或取消订阅：先按目标态乐观更新命中项，请求返回后按后端「部分成功」
  /// 语义精准回滚 skipped 项；已订阅项再订阅、未订阅项再取消订阅等等价空操作也
  /// 会算入 requestedCount 并按后端返回的 updatedCount 报告。
  ///
  /// 请求本身失败（网络/5xx/…）则所有乐观改动整体回滚，返回 `errorMessage` 非空的
  /// 结果，不再触发批量广播。
  Future<MovieSubscriptionBatchToggleResult> batchToggleSubscription({
    required Iterable<String> movieNumbers,
    required bool subscribe,
  }) async {
    final orderedNumbers = <String>[];
    final seen = <String>{};
    for (final number in movieNumbers) {
      if (number.isEmpty || !seen.add(number)) {
        continue;
      }
      orderedNumbers.add(number);
    }
    if (orderedNumbers.isEmpty) {
      return const MovieSubscriptionBatchToggleResult(
        requestedCount: 0,
        updatedCount: 0,
        skippedMovieNotFoundNumbers: <String>[],
        skippedHasMediaNumbers: <String>[],
      );
    }

    final originalByNumber = <String, T>{};
    final indexByNumber = <String, int>{};
    for (final number in orderedNumbers) {
      final index = _indexOfMovie(number);
      if (index == -1) {
        continue;
      }
      indexByNumber[number] = index;
      originalByNumber[number] = mutableItems[index];
    }

    // 乐观更新命中项。
    if (indexByNumber.isNotEmpty) {
      for (final entry in indexByNumber.entries) {
        final movie = mutableItems[entry.value];
        if (isSubscribedOf(movie) == subscribe) {
          continue;
        }
        mutableItems[entry.value] = copyWithSubscribed(movie, subscribe);
      }
      notifyListenersSafely();
    }

    final MovieSubscriptionBatchResultDto response;
    try {
      response =
          subscribe
              ? await batchSubscribeMovies(movieNumbers: orderedNumbers)
              : await batchUnsubscribeMovies(movieNumbers: orderedNumbers);
    } catch (error) {
      // 请求整体失败：所有乐观改动回滚。
      if (indexByNumber.isNotEmpty) {
        for (final entry in indexByNumber.entries) {
          mutableItems[entry.value] = originalByNumber[entry.key] as T;
        }
        notifyListenersSafely();
      }
      return MovieSubscriptionBatchToggleResult.failed(
        requestedCount: orderedNumbers.length,
        message: apiErrorMessage(
          error,
          fallback: subscribe ? '批量订阅影片失败' : '批量取消订阅影片失败',
        ),
      );
    }

    final skippedNotFound = response.movieNumbersSkippedBecause(
      MovieSubscriptionSkipReason.movieNotFound,
    );
    final skippedHasMedia = response.movieNumbersSkippedBecause(
      MovieSubscriptionSkipReason.hasMedia,
    );
    final skippedSet = <String>{...skippedNotFound, ...skippedHasMedia};

    // 精准回滚被后端跳过的项。
    var mutated = false;
    for (final number in skippedSet) {
      final index = indexByNumber[number];
      if (index == null || !originalByNumber.containsKey(number)) {
        continue;
      }
      final original = originalByNumber[number] as T;
      if (isSubscribedOf(mutableItems[index]) != isSubscribedOf(original)) {
        mutableItems[index] = original;
        mutated = true;
      }
    }
    if (mutated) {
      notifyListenersSafely();
    }

    // 广播批量变更：只报告实际被后端接受的项（未 skip 的、且原来态不同的）。
    final broadcastChanges = <MovieSubscriptionChange>[];
    for (final number in orderedNumbers) {
      if (skippedSet.contains(number)) {
        continue;
      }
      if (originalByNumber.containsKey(number) &&
          isSubscribedOf(originalByNumber[number] as T) == subscribe) {
        // 已是目标态，服务端也不会算作 updated，前端不广播冗余变更。
        continue;
      }
      broadcastChanges.add(
        MovieSubscriptionChange(movieNumber: number, isSubscribed: subscribe),
      );
    }
    if (broadcastChanges.isNotEmpty) {
      onSubscriptionsBatchChanged?.call(broadcastChanges);
    }

    return MovieSubscriptionBatchToggleResult(
      requestedCount: response.requestedCount,
      updatedCount: response.updatedCount,
      skippedMovieNotFoundNumbers: skippedNotFound,
      skippedHasMediaNumbers: skippedHasMedia,
    );
  }

  bool _isBlockedByMedia(Object error) {
    return error is ApiException &&
        error.error?.code == 'movie_subscription_has_media';
  }
}
