import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/collection_number_features_api.dart';
import 'package:sakuramedia/features/configuration/data/collection_number_features_dto.dart';
import 'package:sakuramedia/theme.dart';

enum _MovieCollectionFeatureMenuAction { addFeature }

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
  if (feature == null) {
    showToast('无法从当前番号提取合集特征');
    return;
  }

  final action = await _showMovieCollectionFeatureMenu(
    context: context,
    feature: feature,
    globalPosition: globalPosition,
  );
  if (action == null || !context.mounted) {
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

Future<_MovieCollectionFeatureMenuAction?> _showMovieCollectionFeatureMenu({
  required BuildContext context,
  required String feature,
  required Offset globalPosition,
}) {
  final componentTokens = Theme.of(context).appComponentTokens;
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
    items: <PopupMenuEntry<_MovieCollectionFeatureMenuAction>>[
      PopupMenuItem<_MovieCollectionFeatureMenuAction>(
        key: const Key('movie-collection-feature-menu-add-item'),
        value: _MovieCollectionFeatureMenuAction.addFeature,
        child: Row(
          children: [
            Icon(Icons.category_outlined, size: componentTokens.iconSizeSm),
            const SizedBox(width: 8),
            Text('将"$feature"加入合集特征'),
          ],
        ),
      ),
    ],
  );
}
