import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_collection_type_dto.dart';
import 'package:sakuramedia/features/movies/data/api/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/notifiers/movie_collection_type_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/notifiers/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/paged_movie_summary_controller.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/theme.dart';

enum _MovieCollectionFeatureMenuAction {
  enterSelection,
  toggleSubscription,
  toggleCollectionType,
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
}) async {
  final moviesApi = context.read<MoviesApi>();
  final deferLookup = onEnterSelection != null;

  _MovieCollectionStatusLookupResult? statusResult;
  if (!deferLookup) {
    statusResult = await _lookupCollectionStatus(
      moviesApi: moviesApi,
      movieNumber: movieNumber,
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
      final resolved =
          statusResult ??
          await _lookupCollectionStatus(
            moviesApi: moviesApi,
            movieNumber: movieNumber,
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
  }
}

Future<void> _handleToggleSubscriptionAction({
  required BuildContext context,
  required String movieNumber,
  required bool isSubscribed,
  required MoviesApi moviesApi,
}) async {
  MovieSubscriptionToggleResult result;
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
          fallback: isSubscribed ? '取消订阅影片失败' : '订阅影片失败',
        ),
      );
    }
  }

  if (!context.mounted) {
    return;
  }

  if (result.status == MovieSubscriptionToggleStatus.subscribed ||
      result.status == MovieSubscriptionToggleStatus.unsubscribed) {
    context.read<MovieSubscriptionChangeNotifier>().reportChange(
      movieNumber: movieNumber,
      isSubscribed: result.status == MovieSubscriptionToggleStatus.subscribed,
    );
  }

  showMovieSubscriptionFeedback(result);
}

Future<void> _handleCollectionTypeToggleAction({
  required BuildContext context,
  required String movieNumber,
  required _MovieCollectionStatusLookupResult statusResult,
  required MoviesApi moviesApi,
}) async {
  final status = statusResult.status;
  if (status == null) {
    showToast(statusResult.errorMessage ?? '获取合集状态失败，请稍后重试');
    return;
  }

  final targetCollectionType =
      status.isCollection
          ? MovieCollectionType.single
          : MovieCollectionType.collection;
  final normalizedMovieNumber = status.movieNumber.trim();
  final displayMovieNumber =
      normalizedMovieNumber.isNotEmpty
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
      showToast('未匹配到影片，未更新合集状态');
      return;
    }
    context.read<MovieCollectionTypeChangeNotifier>().reportChange(
      movieNumber: displayMovieNumber,
      targetType: targetCollectionType,
    );
    showToast(
      targetCollectionType == MovieCollectionType.collection
          ? '已将 $displayMovieNumber 标记为合集'
          : '已将 $displayMovieNumber 标记为单体',
    );
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    showToast(apiErrorMessage(error, fallback: '更新合集状态失败'));
  }
}

Future<_MovieCollectionStatusLookupResult> _lookupCollectionStatus({
  required MoviesApi moviesApi,
  required String movieNumber,
}) async {
  try {
    final status = await moviesApi.getMovieCollectionStatus(
      movieNumber: movieNumber,
    );
    return _MovieCollectionStatusLookupResult(status: status);
  } catch (error) {
    return _MovieCollectionStatusLookupResult(
      errorMessage: apiErrorMessage(error, fallback: '获取合集状态失败，请稍后重试'),
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
  final colors = context.appColors;
  final spacing = context.appSpacing;
  final componentTokens = Theme.of(context).appComponentTokens;
  const menuItemHeight = 36.0;
  final navigator = Navigator.of(context);
  final overlay = navigator.overlay!.context.findRenderObject() as RenderBox;
  final localPosition = overlay.globalToLocal(globalPosition);
  final position = RelativeRect.fromRect(
    Rect.fromPoints(localPosition, localPosition),
    Offset.zero & overlay.size,
  );

  final subscriptionTone =
      isSubscribed == true ? AppTextTone.error : AppTextTone.primary;

  return showMenu<_MovieCollectionFeatureMenuAction>(
    context: context,
    position: position,
    useRootNavigator: false,
    color: colors.surfaceElevated,
    elevation: 12,
    shape: RoundedRectangleBorder(
      borderRadius: context.appRadius.lgBorder,
      side: BorderSide(color: colors.borderSubtle),
    ),
    items: <PopupMenuEntry<_MovieCollectionFeatureMenuAction>>[
      if (canEnterSelection)
        PopupMenuItem<_MovieCollectionFeatureMenuAction>(
          key: const Key('movie-collection-feature-menu-select-item'),
          value: _MovieCollectionFeatureMenuAction.enterSelection,
          height: menuItemHeight,
          padding: EdgeInsets.symmetric(
            horizontal: spacing.sm,
            vertical: spacing.xs,
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: componentTokens.iconSizeXs,
                color: context.appTextPalette.secondary,
              ),
              SizedBox(width: spacing.sm),
              Text(
                '选择',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.primary,
                ),
              ),
            ],
          ),
        ),
      if (canEnterSelection)
        PopupMenuItem<_MovieCollectionFeatureMenuAction>(
          enabled: false,
          height: 1,
          padding: EdgeInsets.zero,
          child: Divider(height: 1, thickness: 1, color: colors.borderStrong),
        ),
      if (isSubscribed != null)
        PopupMenuItem<_MovieCollectionFeatureMenuAction>(
          key: const Key('movie-collection-feature-menu-subscription-item'),
          value: _MovieCollectionFeatureMenuAction.toggleSubscription,
          height: menuItemHeight,
          padding: EdgeInsets.symmetric(
            horizontal: spacing.sm,
            vertical: spacing.xs,
          ),
          child: Row(
            children: [
              Icon(
                isSubscribed
                    ? Icons.favorite_border_rounded
                    : Icons.favorite_rounded,
                size: componentTokens.iconSizeXs,
                color: resolveAppTextToneColor(context, subscriptionTone),
              ),
              SizedBox(width: spacing.sm),
              Text(
                isSubscribed ? '取消订阅' : '订阅影片',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: subscriptionTone,
                ),
              ),
            ],
          ),
        ),
      if (isSubscribed != null)
        PopupMenuItem<_MovieCollectionFeatureMenuAction>(
          enabled: false,
          height: 1,
          padding: EdgeInsets.zero,
          child: Divider(height: 1, thickness: 1, color: colors.borderStrong),
        ),
      PopupMenuItem<_MovieCollectionFeatureMenuAction>(
        key: const Key('movie-collection-feature-menu-toggle-item'),
        value: _MovieCollectionFeatureMenuAction.toggleCollectionType,
        height: menuItemHeight,
        padding: EdgeInsets.symmetric(
          horizontal: spacing.sm,
          vertical: spacing.xs,
        ),
        child: Row(
          children: [
            Icon(
              Icons.category_outlined,
              size: componentTokens.iconSizeXs,
              color: context.appTextPalette.secondary,
            ),
            SizedBox(width: spacing.sm),
            Text(
              isCollection == null
                  ? '标记为合集/单体'
                  : (isCollection ? '标记为单体' : '标记为合集'),
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.primary,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
