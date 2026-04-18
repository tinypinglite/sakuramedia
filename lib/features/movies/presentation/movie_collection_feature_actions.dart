import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/collection_number_features_api.dart';
import 'package:sakuramedia/features/configuration/data/collection_number_features_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_collection_type_dto.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_collection_type_change_notifier.dart';
import 'package:sakuramedia/theme.dart';

enum _MovieCollectionFeatureMenuAction { toggleCollectionType, addFeature }

class _MovieCollectionStatusLookupResult {
  const _MovieCollectionStatusLookupResult({this.status, this.errorMessage});

  final MovieCollectionStatusDto? status;
  final String? errorMessage;
}

String? extractCollectionFeaturePrefix(String movieNumber) {
  final normalizedMovieNumber = movieNumber.trim().toUpperCase();
  if (normalizedMovieNumber.isEmpty) {
    return null;
  }

  final match = RegExp(r'^(.*?)(\d+)$').firstMatch(normalizedMovieNumber);
  if (match == null) {
    return null;
  }

  final prefix = match.group(1)?.trim();
  if (prefix == null || prefix.isEmpty) {
    return null;
  }

  return prefix;
}

Future<void> showMovieCollectionFeatureActionMenu({
  required BuildContext context,
  required String movieNumber,
  required Offset globalPosition,
  bool applyNow = true,
}) async {
  final feature = extractCollectionFeaturePrefix(movieNumber);
  final moviesApi = context.read<MoviesApi>();
  final statusResult = await _lookupCollectionStatus(
    moviesApi: moviesApi,
    movieNumber: movieNumber,
  );
  if (!context.mounted) {
    return;
  }

  final action = await _showMovieCollectionFeatureMenu(
    context: context,
    feature: feature,
    isCollection: statusResult.status?.isCollection,
    globalPosition: globalPosition,
  );
  if (action == null || !context.mounted) {
    return;
  }

  switch (action) {
    case _MovieCollectionFeatureMenuAction.toggleCollectionType:
      await _handleCollectionTypeToggleAction(
        context: context,
        movieNumber: movieNumber,
        statusResult: statusResult,
        moviesApi: moviesApi,
      );
      return;
    case _MovieCollectionFeatureMenuAction.addFeature:
      await _handleAddFeatureAction(
        context: context,
        feature: feature,
        applyNow: applyNow,
      );
      return;
  }
}

Future<void> _handleAddFeatureAction({
  required BuildContext context,
  required String? feature,
  required bool applyNow,
}) async {
  if (feature == null) {
    showToast('无法从当前番号提取合集特征');
    return;
  }

  final collectionNumberFeaturesApi =
      context.read<CollectionNumberFeaturesApi>();
  try {
    final settings = await collectionNumberFeaturesApi.getFeatures();
    final normalizedFeature = feature.trim().toUpperCase();
    final hasFeature = settings.features
        .map((item) => item.trim().toUpperCase())
        .contains(normalizedFeature);

    if (hasFeature) {
      if (context.mounted) {
        showToast('合集特征中已包含 $normalizedFeature');
      }
      return;
    }

    final nextFeatures = List<String>.from(settings.features)
      ..add(normalizedFeature);
    await collectionNumberFeaturesApi.updateFeatures(
      UpdateCollectionNumberFeaturesPayload(features: nextFeatures),
      applyNow: applyNow,
    );

    if (!context.mounted) {
      return;
    }
    showToast(
      applyNow
          ? '已将 $normalizedFeature 加入合集特征，并重新统计合集影片'
          : '已将 $normalizedFeature 加入合集特征',
    );
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    showToast(apiErrorMessage(error, fallback: '保存合集番号特征失败'));
  }
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
  required String? feature,
  required bool? isCollection,
  required Offset globalPosition,
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
              color: colors.textSecondary,
            ),
            SizedBox(width: spacing.sm),
            Text(
              isCollection == null
                  ? '标记为合集/单体'
                  : (isCollection ? '标记为单体' : '标记为合集'),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      if (feature != null)
        PopupMenuItem<_MovieCollectionFeatureMenuAction>(
          enabled: false,
          height: 1,
          padding: EdgeInsets.zero,
          child: Divider(height: 1, thickness: 1, color: colors.borderStrong),
        ),
      if (feature != null)
        PopupMenuItem<_MovieCollectionFeatureMenuAction>(
          key: const Key('movie-collection-feature-menu-add-item'),
          value: _MovieCollectionFeatureMenuAction.addFeature,
          height: menuItemHeight,
          padding: EdgeInsets.symmetric(
            horizontal: spacing.sm,
            vertical: spacing.xs,
          ),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome_motion_outlined,
                size: componentTokens.iconSizeXs,
                color: colors.textSecondary,
              ),
              SizedBox(width: spacing.sm),
              Text(
                '将"$feature"加入合集特征',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
    ],
  );
}
