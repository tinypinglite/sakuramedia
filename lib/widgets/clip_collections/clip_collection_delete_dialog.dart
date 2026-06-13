import 'package:flutter/material.dart';
import 'package:sakuramedia/features/clip_collections/data/clip_collection_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';

/// 删除合集确认弹窗，确认返回 `true`。仅删合集，不删切片本体。
Future<bool?> showClipCollectionDeleteDialog(
  BuildContext context, {
  required ClipCollectionDto collection,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => _ClipCollectionDeleteDialog(collection: collection),
  );
}

class _ClipCollectionDeleteDialog extends StatelessWidget {
  const _ClipCollectionDeleteDialog({required this.collection});

  final ClipCollectionDto collection;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final name = collection.name.trim().isEmpty ? '该合集' : '“${collection.name.trim()}”';
    return AlertDialog(
      backgroundColor: context.appColors.surfaceCard,
      actionsOverflowButtonSpacing: spacing.sm,
      title: Text(
        '删除合集',
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s16,
          weight: AppTextWeight.semibold,
          tone: AppTextTone.primary,
        ),
      ),
      content: Text(
        '确认删除$name？只会删除合集本身，合集内的切片不会被删除。',
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s14,
          weight: AppTextWeight.regular,
          tone: AppTextTone.secondary,
        ),
      ),
      actions: [
        AppButton(
          label: '取消',
          size: AppButtonSize.small,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        SizedBox(width: spacing.sm),
        AppButton(
          key: const Key('clip-collection-delete-confirm-button'),
          label: '删除',
          variant: AppButtonVariant.danger,
          size: AppButtonSize.small,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
