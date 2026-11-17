import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_collection_type_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/api/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_toggle_result.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/overlays/app_action_menu.dart';

enum _MovieCollectionFeatureMenuAction {
  enterSelection,
  toggleSubscription,
  toggleCollectionType,
  blacklist,
}

class _MovieCollectionStatusLookupResult {
  const _MovieCollectionStatusLookupResult({this.status, this.errorMessage});

  final MovieCollectionStatusDto? status;
  final String? errorMessage;
}

/// 列表页右键/长按菜单的便捷入口:免去各处重复的
/// `unawaited(showMovieCollectionFeatureActionMenu(...))` 闭包。
///
/// [isSubscribed] 为 null 时菜单不显示"订阅/取消订阅"项;
/// 传入布尔值时按当前状态显示"订阅影片" / "取消订阅"。
void requestMovieCollectionMenu(
  BuildContext context,
  String movieNumber,
  Offset globalPosition, {
  bool? isSubscribed,
  VoidCallback? onEnterSelection,
}) {
  unawaited(
    showMovieCollectionFeatureActionMenu(
      context: context,
      movieNumber: movieNumber,
      globalPosition: globalPosition,
      isSubscribed: isSubscribed,
      onEnterSelection: onEnterSelection,
    ),
  );
}

/// [onEnterSelection] 非空时菜单首项为「选择」——移动端多选入口从此挂在卡片长按
/// 上，列表顶栏不再常驻「选择」按钮。桌面端不传，多选入口仍在顶栏。
///
/// 传了它还会**跳过合集状态预查**：长按是即时交互，不该先等一个网络请求才弹菜单，
/// 代价是合集项文案退化为中性的「标记为合集/单体」，真正点下去时才查。
Future<void> showMovieCollectionFeatureActionMenu({
  required BuildContext context,
  required String movieNumber,
  required Offset globalPosition,
  bool? isSubscribed,
  VoidCallback? onEnterSelection,
  VoidCallback? onBlacklisted,
}) async {
  final moviesApi = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(moviesApiProvider);
  final l10n = AppLocalizations.of(context);
  final deferLookup = onEnterSelection != null;

  _MovieCollectionStatusLookupResult? statusResult;
  if (!deferLookup) {
    statusResult = await _lookupCollectionStatus(
      moviesApi: moviesApi,
      movieNumber: movieNumber,
      l10n: l10n,
    );
    if (!context.mounted) {
      return;
    }
  }

  final action = await _showMovieCollectionFeatureMenu(
    context: context,
    isCollection: statusResult?.status?.isCollection,
    isSubscribed: isSubscribed,
    globalPosition: globalPosition,
    canEnterSelection: onEnterSelection != null,
  );
  if (action == null || !context.mounted) {
    return;
  }

  switch (action) {
    case _MovieCollectionFeatureMenuAction.enterSelection:
      onEnterSelection?.call();
      return;
    case _MovieCollectionFeatureMenuAction.toggleSubscription:
      if (isSubscribed == null) {
        return;
      }
      await _handleToggleSubscriptionAction(
        context: context,
        movieNumber: movieNumber,
        isSubscribed: isSubscribed,
        moviesApi: moviesApi,
      );
      return;
    case _MovieCollectionFeatureMenuAction.toggleCollectionType:
      // 菜单打开时已预查过状态（长按场景除外），这里复用，避免重复请求。
      final resolved =
          statusResult ??
          await _lookupCollectionStatus(
            moviesApi: moviesApi,
            movieNumber: movieNumber,
            l10n: l10n,
          );
      if (!context.mounted) {
        return;
      }
      await _handleCollectionTypeToggleAction(
        context: context,
        movieNumber: movieNumber,
        statusResult: resolved,
        moviesApi: moviesApi,
      );
      return;
    case _MovieCollectionFeatureMenuAction.blacklist:
      await blacklistMovie(
        context: context,
        movieNumber: movieNumber,
        onBlacklisted: onBlacklisted,
      );
      return;
  }
}

/// 切换影片「合集 / 单体」标记：先查当前状态再切换，成功后广播并 toast。
/// 右键菜单与卡片悬停动作行共用这一入口。
Future<void> toggleMovieCollectionType({
  required BuildContext context,
  required String movieNumber,
}) async {
  final moviesApi = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(moviesApiProvider);
  final statusResult = await _lookupCollectionStatus(
    moviesApi: moviesApi,
    movieNumber: movieNumber,
    l10n: AppLocalizations.of(context),
  );
  if (!context.mounted) {
    return;
  }
  await _handleCollectionTypeToggleAction(
    context: context,
    movieNumber: movieNumber,
    statusResult: statusResult,
    moviesApi: moviesApi,
  );
}

/// 屏蔽影片（确认后隐藏出正常列表与推荐）。右键菜单与卡片悬停动作行共用。
Future<void> blacklistMovie({
  required BuildContext context,
  required String movieNumber,
  VoidCallback? onBlacklisted,
}) async {
  final moviesApi = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(moviesApiProvider);
  final l10n = AppLocalizations.of(context);
  final confirmed = await showAppConfirmDialog(
    context,
    title: l10n.movieActionBlacklistMovie,
    message: l10n.movieActionBlacklistMovieMessage,
    confirmLabel: l10n.movieActionBlacklistConfirm,
    cancelLabel: l10n.commonCancel,
    danger: true,
    failureFallback: l10n.movieActionBlacklistMovieFailed,
    onConfirm: () => moviesApi.setMoviesBlacklisted(
      movieNumbers: <String>[movieNumber],
      isBlacklisted: true,
    ),
  );
  if (confirmed && context.mounted) {
    onBlacklisted?.call();
    showToast(l10n.movieActionMovieBlacklisted, tone: AppToastTone.success);
  }
}

/// 影片卡悬停动作行里「标记合集/单体 + 屏蔽」两个回调的默认接线。
///
/// 各列表页把它直接传给 `MovieSummarySliver` / `RankedMovieSummarySliver` /
/// 搜索结果页的悬停回调；
/// [onBlacklisted] 由页面提供（通常把该影片从当前列表移除）。
typedef MovieCardHoverFeatureActions = ({
  ValueChanged<MovieListItemDto> toggleCollectionType,
  ValueChanged<MovieListItemDto> blacklist,
});

/// 组装 [MovieCardHoverFeatureActions]；其余悬停动作（播放 / 订阅）由各页自己接线。
MovieCardHoverFeatureActions movieCardHoverFeatureActions(
  BuildContext context, {
  void Function(String movieNumber)? onBlacklisted,
}) {
  return (
    toggleCollectionType: (movie) => unawaited(
      toggleMovieCollectionType(
        context: context,
        movieNumber: movie.movieNumber,
      ),
    ),
    blacklist: (movie) => unawaited(
      blacklistMovie(
        context: context,
        movieNumber: movie.movieNumber,
        onBlacklisted: onBlacklisted == null
            ? null
            : () => onBlacklisted(movie.movieNumber),
      ),
    ),
  );
}

Future<void> _handleToggleSubscriptionAction({
  required BuildContext context,
  required String movieNumber,
  required bool isSubscribed,
  required MoviesApi moviesApi,
}) async {
  MovieSubscriptionToggleResult result;
  final l10n = AppLocalizations.of(context);
  try {
    if (isSubscribed) {
      await moviesApi.unsubscribeMovie(
        movieNumber: movieNumber,
        deleteMedia: false,
      );
      result = const MovieSubscriptionToggleResult.unsubscribed();
    } else {
      await moviesApi.subscribeMovie(movieNumber: movieNumber);
      result = const MovieSubscriptionToggleResult.subscribed();
    }
  } catch (error) {
    if (error is ApiException &&
        error.error?.code == 'movie_subscription_has_media') {
      result = const MovieSubscriptionToggleResult.blockedByMedia();
    } else {
      result = MovieSubscriptionToggleResult.failed(
        message: apiErrorMessage(
          error,
          fallback: isSubscribed
              ? l10n.errorUnsubscribeMovieFailed
              : l10n.movieProviderSubscribeMovieFailed,
          l10n: l10n,
        ),
      );
    }
  }

  if (!context.mounted) {
    return;
  }

  if (result.status == MovieSubscriptionToggleStatus.subscribed ||
      result.status == MovieSubscriptionToggleStatus.unsubscribed) {
    ProviderScope.containerOf(context, listen: false)
        .read(movieSubscriptionEventsProvider.notifier)
        .reportChange(
          movieNumber: movieNumber,
          isSubscribed:
              result.status == MovieSubscriptionToggleStatus.subscribed,
        );
  }

  showMovieSubscriptionFeedback(result, l10n: l10n);
}

Future<void> _handleCollectionTypeToggleAction({
  required BuildContext context,
  required String movieNumber,
  required _MovieCollectionStatusLookupResult statusResult,
  required MoviesApi moviesApi,
}) async {
  final status = statusResult.status;
  final l10n = AppLocalizations.of(context);
  if (status == null) {
    showToast(
      statusResult.errorMessage ?? l10n.movieActionCollectionStatusLoadFailed,
      tone: AppToastTone.error,
    );
    return;
  }

  final targetCollectionType = status.isCollection
      ? MovieCollectionType.single
      : MovieCollectionType.collection;
  final normalizedMovieNumber = status.movieNumber.trim();
  final displayMovieNumber = normalizedMovieNumber.isNotEmpty
      ? normalizedMovieNumber
      : movieNumber.trim().toUpperCase();

  try {
    final result = await moviesApi.updateMovieCollectionType(
      movieNumbers: <String>[displayMovieNumber],
      collectionType: targetCollectionType,
    );
    if (!context.mounted) {
      return;
    }
    if (result.updatedCount <= 0) {
      showToast(
        l10n.movieActionCollectionStatusUnmatched,
        tone: AppToastTone.warning,
      );
      return;
    }
    ProviderScope.containerOf(context, listen: false)
        .read(movieCollectionTypeEventsProvider.notifier)
        .reportChange(
          movieNumber: displayMovieNumber,
          targetType: targetCollectionType,
        );
    showToast(
      targetCollectionType == MovieCollectionType.collection
          ? l10n.movieActionMovieMarkedAsCollection(displayMovieNumber)
          : l10n.movieActionMovieMarkedAsSingle(displayMovieNumber),
      tone: AppToastTone.success,
    );
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    showToast(
      apiErrorMessage(
        error,
        fallback: l10n.movieActionCollectionStatusUpdateFailed,
        l10n: l10n,
      ),
      tone: AppToastTone.error,
    );
  }
}

Future<_MovieCollectionStatusLookupResult> _lookupCollectionStatus({
  required MoviesApi moviesApi,
  required String movieNumber,
  required AppLocalizations l10n,
}) async {
  try {
    final status = await moviesApi.getMovieCollectionStatus(
      movieNumber: movieNumber,
    );
    return _MovieCollectionStatusLookupResult(status: status);
  } catch (error) {
    return _MovieCollectionStatusLookupResult(
      errorMessage: apiErrorMessage(
        error,
        fallback: l10n.movieActionCollectionStatusLoadFailed,
        l10n: l10n,
      ),
    );
  }
}

Future<_MovieCollectionFeatureMenuAction?> _showMovieCollectionFeatureMenu({
  required BuildContext context,
  required bool? isCollection,
  required bool? isSubscribed,
  required Offset globalPosition,
  required bool canEnterSelection,
}) {
  final l10n = AppLocalizations.of(context);
  return showAppActionMenu<_MovieCollectionFeatureMenuAction>(
    context: context,
    globalPosition: globalPosition,
    items: <AppMenuItem<_MovieCollectionFeatureMenuAction>>[
      if (canEnterSelection)
        AppMenuItem(
          key: const Key('movie-collection-feature-menu-select-item'),
          value: _MovieCollectionFeatureMenuAction.enterSelection,
          label: l10n.movieActionSelect,
          icon: Icons.check_circle_outline,
        ),
      if (isSubscribed != null)
        AppMenuItem(
          key: const Key('movie-collection-feature-menu-subscription-item'),
          value: _MovieCollectionFeatureMenuAction.toggleSubscription,
          label: isSubscribed
              ? l10n.movieActionUnsubscribeMovie
              : l10n.movieActionSubscribeMovie,
          icon: isSubscribed
              ? Icons.favorite_border_rounded
              : Icons.favorite_rounded,
          tone: isSubscribed ? AppTextTone.error : AppTextTone.primary,
        ),
      AppMenuItem(
        key: const Key('movie-collection-feature-menu-toggle-item'),
        value: _MovieCollectionFeatureMenuAction.toggleCollectionType,
        label: isCollection == null
            ? l10n.movieActionMarkAsCollectionOrSingle
            : (isCollection
                  ? l10n.movieActionMarkAsSingle
                  : l10n.movieActionMarkAsCollection),
        icon: Icons.category_outlined,
      ),
      if (isSubscribed != true)
        AppMenuItem(
          key: const Key('movie-collection-feature-menu-blacklist-item'),
          value: _MovieCollectionFeatureMenuAction.blacklist,
          label: l10n.movieActionBlacklistMovie,
          icon: Icons.block_rounded,
          tone: AppTextTone.error,
        ),
    ],
  );
}
