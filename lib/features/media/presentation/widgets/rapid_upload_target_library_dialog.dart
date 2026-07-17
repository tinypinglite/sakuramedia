import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selectable_tile.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

/// 秒传目标 115 网盘挑选弹窗。
///
/// - 无 115 库时给一个明确的空态引导用户先去「媒体库」tab 新建；
/// - 只有一个 115 库时默认选中它；
/// - 用户点击确认返回选中的 [MediaLibraryDto]，取消返回 `null`。
Future<MediaLibraryDto?> showRapidUploadTargetLibraryDialog(
  BuildContext context, {
  required int selectedCount,
  required List<MediaLibraryDto> libraries,
}) {
  return showDialog<MediaLibraryDto>(
    context: context,
    builder: (dialogContext) {
      return AppDesktopDialog(
        dialogKey: const Key('rapid-upload-target-library-dialog'),
        width: dialogContext.appLayoutTokens.dialogWidthSm,
        child: _RapidUploadTargetBody(
          selectedCount: selectedCount,
          libraries: libraries,
        ),
      );
    },
  );
}

class _RapidUploadTargetBody extends HookWidget {
  const _RapidUploadTargetBody({
    required this.selectedCount,
    required this.libraries,
  });

  final int selectedCount;
  final List<MediaLibraryDto> libraries;

  @override
  Widget build(BuildContext context) {
    final selectedId = useState<int?>(
      libraries.length == 1 ? libraries.first.id : null,
    );
    final riskAcknowledged = useState(false);
    final spacing = context.appSpacing;
    final hasLibraries = libraries.isNotEmpty;

    MediaLibraryDto? resolveSelectedLibrary() {
      final id = selectedId.value;
      if (id == null) return null;
      for (final library in libraries) {
        if (library.id == id) return library;
      }
      return null;
    }

    final selectedLibrary = resolveSelectedLibrary();
    final canSubmit = selectedLibrary != null && riskAcknowledged.value;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '秒传到 115',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s18,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.md),
        Text(
          '已选 $selectedCount 项本地媒体。选择目标 115 网盘后，'
          '系统会创建后台批次逐个秒传。',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.lg),
        if (!hasLibraries)
          const AppEmptyState(
            message: '尚未配置任何 115 网盘媒体库。请到「媒体库」中先扫码创建一个 115 库。',
          )
        else
          _LibraryList(
            libraries: libraries,
            selectedId: selectedId.value,
            onSelected: (id) => selectedId.value = id,
          ),
        SizedBox(height: spacing.lg),
        const AppNoticeCard(
          leadingIcon: Icons.warning_amber_rounded,
          title: '成功后会删除本地文件',
          description: '每一项秒传成功后，SakuraMedia 会将其切换到 115 云端并删除对应的本地文件。'
              '该操作不可恢复，请提前确认这些本地文件无需保留。',
        ),
        SizedBox(height: spacing.sm),
        CheckboxListTile(
          key: const Key('rapid-upload-risk-checkbox'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: riskAcknowledged.value,
          onChanged: !hasLibraries
              ? null
              : (value) => riskAcknowledged.value = value ?? false,
          title: Text(
            '我已了解成功秒传的条目会删除本地文件，且该操作不可恢复。',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.primary,
            ),
          ),
        ),
        SizedBox(height: spacing.xl),
        Row(
          children: [
            Expanded(
              child: AppButton(
                key: const Key('rapid-upload-target-cancel-button'),
                label: '取消',
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: AppButton(
                key: const Key('rapid-upload-target-confirm-button'),
                label: '开始秒传',
                variant: AppButtonVariant.primary,
                icon: const Icon(Icons.cloud_upload_outlined),
                onPressed: !canSubmit
                    ? null
                    : () => Navigator.of(context).pop(selectedLibrary),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LibraryList extends StatelessWidget {
  const _LibraryList({
    required this.libraries,
    required this.selectedId,
    required this.onSelected,
  });

  final List<MediaLibraryDto> libraries;
  final int? selectedId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Column(
      children: [
        for (final library in libraries)
          Padding(
            padding: EdgeInsets.only(bottom: spacing.sm),
            child: _LibraryTile(
              library: library,
              selected: library.id == selectedId,
              onTap: () => onSelected(library.id),
            ),
          ),
      ],
    );
  }
}

class _LibraryTile extends StatelessWidget {
  const _LibraryTile({
    required this.library,
    required this.selected,
    required this.onTap,
  });

  final MediaLibraryDto library;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return AppSelectableTile(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          Radio<int>(
            key: Key('rapid-upload-target-radio-${library.id}'),
            value: library.id,
            groupValue: selected ? library.id : null,
            onChanged: (_) => onTap(),
          ),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        library.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s14,
                          weight: AppTextWeight.semibold,
                          tone: AppTextTone.primary,
                        ),
                      ),
                    ),
                    SizedBox(width: spacing.sm),
                    const AppBadge(label: '115 网盘', tone: AppBadgeTone.info),
                  ],
                ),
                if (library.rootCid.isNotEmpty) ...[
                  SizedBox(height: spacing.xs),
                  Text(
                    '根目录 CID：${library.rootCid}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      weight: AppTextWeight.regular,
                      tone: AppTextTone.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
