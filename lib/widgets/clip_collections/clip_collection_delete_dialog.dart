import 'package:flutter/material.dart';
import 'package:sakuramedia/features/clip_collections/data/clip_collection_dto.dart';
import 'package:sakuramedia/widgets/feedback/app_confirm_dialog.dart';

/// 删除合集确认弹窗，确认返回 `true`。仅删合集，不删切片本体。
Future<bool?> showClipCollectionDeleteDialog(
  BuildContext context, {
  required ClipCollectionDto collection,
}) {
  final name = collection.name.trim().isEmpty ? '该合集' : '“${collection.name.trim()}”';
  return showAppConfirmDialog(
    context,
    title: '删除合集',
    message: '确认删除$name？只会删除合集本身，合集内的切片不会被删除。',
    danger: true,
    confirmLabel: '删除',
    confirmKey: const Key('clip-collection-delete-confirm-button'),
  );
}
