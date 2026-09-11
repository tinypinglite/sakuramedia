import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/moment_collections/data/dto/moment_collection_dto.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collections_overview_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/widgets/moment_collection_editor.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

enum PickMomentCollectionPresentation { dialog, bottomDrawer }

/// 批量加入合集时选择一个目标合集。实际成员写入由调用方执行。
Future<MomentCollectionDto?> showPickMomentCollectionDialog(
  BuildContext context, {
  PickMomentCollectionPresentation presentation =
      PickMomentCollectionPresentation.dialog,
}) {
  switch (presentation) {
    case PickMomentCollectionPresentation.dialog:
      return showDialog<MomentCollectionDto>(
        context: context,
        builder: (_) => const _PickMomentCollectionDialog(),
      );
    case PickMomentCollectionPresentation.bottomDrawer:
      return showAppBottomDrawer<MomentCollectionDto>(
        context: context,
        drawerKey: const Key('pick-moment-collection-bottom-sheet'),
        maxHeightFactor: 0.7,
        builder: (_) => const _PickMomentCollectionDialog(
          presentation: PickMomentCollectionPresentation.bottomDrawer,
        ),
      );
  }
}

class _PickMomentCollectionDialog extends ConsumerStatefulWidget {
  const _PickMomentCollectionDialog({
    this.presentation = PickMomentCollectionPresentation.dialog,
  });

  final PickMomentCollectionPresentation presentation;

  @override
  ConsumerState<_PickMomentCollectionDialog> createState() =>
      _PickMomentCollectionDialogState();
}

class _PickMomentCollectionDialogState
    extends ConsumerState<_PickMomentCollectionDialog> {
  bool get _isBottomDrawer =>
      widget.presentation == PickMomentCollectionPresentation.bottomDrawer;

  Future<void> _createAndPick() async {
    final created = await showMomentCollectionEditor(
      context,
      presentation: _isBottomDrawer
          ? MomentCollectionEditPresentation.bottomDrawer
          : MomentCollectionEditPresentation.dialog,
    );
    if (created != null && mounted) {
      Navigator.of(context).pop(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final collectionsAsync = ref.watch(momentCollectionsOverviewProvider);
    final content = _buildContent(context, collectionsAsync);
    if (_isBottomDrawer) return content;
    return AppDesktopDialog(width: 420, child: content);
  }

  Widget _buildContent(
    BuildContext context,
    AsyncValue<List<MomentCollectionDto>> collectionsAsync,
  ) {
    final spacing = context.appSpacing;
    final listSection = _isBottomDrawer
        ? Flexible(child: _buildBody(context, collectionsAsync))
        : ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: _buildBody(context, collectionsAsync),
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '加入合集',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s16,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.md),
        listSection,
        SizedBox(height: spacing.md),
        Row(
          children: [
            Expanded(
              child: AppButton(label: '新建合集并加入', onPressed: _createAndPick),
            ),
            SizedBox(width: spacing.md),
            AppButton(
              label: '关闭',
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncValue<List<MomentCollectionDto>> collectionsAsync,
  ) {
    if (collectionsAsync.isLoading && !collectionsAsync.hasValue) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator.adaptive(),
        ),
      );
    }
    if (collectionsAsync.hasError && !collectionsAsync.hasValue) {
      return AppEmptyState(
        message: apiErrorMessage(collectionsAsync.error!, fallback: '合集加载失败'),
      );
    }
    final collections = collectionsAsync.value ?? const <MomentCollectionDto>[];
    if (collections.isEmpty) {
      return const AppEmptyState(message: '暂无合集，点击下方新建');
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: collections.length,
      separatorBuilder: (context, _) => SizedBox(height: context.appSpacing.xs),
      itemBuilder: (context, index) {
        final collection = collections[index];
        return ListTile(
          key: Key('pick-moment-collection-${collection.id}'),
          title: Text(collection.name),
          subtitle: Text('${collection.pointCount} 个时刻'),
          trailing: const Icon(Icons.add),
          onTap: () => Navigator.of(context).pop(collection),
        );
      },
    );
  }
}
