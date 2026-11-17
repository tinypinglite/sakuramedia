import 'package:sakuramedia/core/network/api_exception.dart';

/// 取消订阅是否被后端以「该影片存在本地 media」为由拒绝。
bool isMovieSubscriptionBlockedByMedia(Object error) {
  return error is ApiException &&
      error.error?.code == 'movie_subscription_has_media';
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

/// 批量订阅或取消订阅的最终结果。
///
/// 请求失败时由 [errorMessage] 承载；请求成功时按后端的部分成功语义拆分两种
/// skipped 原因，供批量选择 UI 精准保留未更新项。
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

  Iterable<String> get allSkippedNumbers sync* {
    yield* skippedMovieNotFoundNumbers;
    yield* skippedHasMediaNumbers;
  }
}
