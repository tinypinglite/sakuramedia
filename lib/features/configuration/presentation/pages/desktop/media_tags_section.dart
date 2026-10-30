import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/config_delete_helpers.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/media_tag_retag_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/media_tag_rule_editor.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/media_tag_rule_tester.dart';
import 'package:sakuramedia/features/media/data/media_tag_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_tags_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_inline_action_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';

class DesktopMediaTagsSection extends ConsumerWidget {
  const DesktopMediaTagsSection({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!active) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(mediaTagsProvider);
    final content = async.hasError
        ? AppSectionError(
            title: l10n.mediaTagsLoadFailedTitle,
            message: apiErrorMessage(
              async.error!,
              fallback: l10n.mediaTagsLoadFailedFallback,
              l10n: l10n,
            ),
            onRetry: () => ref.read(mediaTagsProvider.notifier).reload(),
          )
        : AppSkeletonizer(
            enabled: async.isLoading && async.value == null,
            child: _buildContent(
              context,
              ref,
              async.value ?? const <MediaTagDto>[],
            ),
          );
    return AppPageRefreshScope(
      onRefresh: () async {
        final message = await ref.read(mediaTagsProvider.notifier).refresh();
        if (message != null && context.mounted) showToast(message);
      },
      child: content,
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<MediaTagDto> tags,
  ) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppNoticeCard(
          leadingIcon: Icons.sell_outlined,
          title: l10n.mediaTagsManagementNoticeTitle,
          description: l10n.mediaTagsManagementNoticeDescription,
        ),
        SizedBox(height: spacing.lg),
        if (tags.isEmpty)
          AppEmptyState(message: l10n.mediaTagsEmpty)
        else
          AppSettingsGroup(
            dividerIndent: spacing.lg + spacing.xxl + spacing.md,
            children: [
              for (final tag in tags)
                AppSettingCell(
                  key: Key('media-tag-rule-${tag.id}'),
                  icon: Icons.sell_outlined,
                  title: tag.name,
                  subtitle: _ruleSummary(l10n, tag),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!tag.enabled)
                        AppBadge(
                          label: l10n.mediaTagsDisabledBadge,
                          tone: AppBadgeTone.neutral,
                          size: AppBadgeSize.compact,
                        ),
                      if (!tag.enabled) SizedBox(width: spacing.sm),
                      Text(
                        l10n.mediaTagsMediaCount(tag.mediaCount),
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s12,
                          tone: AppTextTone.muted,
                        ),
                      ),
                      SizedBox(width: spacing.sm),
                      AppInlineActionButton(
                        key: Key('media-tag-edit-${tag.id}'),
                        icon: Icons.edit_outlined,
                        onTap: () => unawaited(
                          showMediaTagRuleEditor(
                            context,
                            mobile: false,
                            initialTag: tag,
                          ),
                        ),
                      ),
                      SizedBox(width: spacing.xs),
                      AppInlineActionButton(
                        key: Key('media-tag-delete-${tag.id}'),
                        icon: Icons.delete_outline_rounded,
                        onTap: () => _deleteTag(context, ref, tag),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        SizedBox(height: spacing.lg),
        AppSettingsGroup(
          children: [
            AppSettingCell(
              key: const Key('media-tag-create-button'),
              icon: Icons.add_rounded,
              iconColor: Theme.of(context).colorScheme.primary,
              title: l10n.mediaTagsAdd,
              titleTone: AppTextTone.accent,
              titleWeight: AppTextWeight.medium,
              trailing: const AppSettingCellChevron(),
              onTap: () =>
                  unawaited(showMediaTagRuleEditor(context, mobile: false)),
            ),
          ],
        ),
        SizedBox(height: spacing.xl),
        const MediaTagRuleTester(),
        SizedBox(height: spacing.lg),
        const MediaTagRetagCard(),
      ],
    );
  }

  String _ruleSummary(AppLocalizations l10n, MediaTagDto tag) {
    final include = tag.includeTerms.join(' / ');
    final exclude = tag.excludeTerms.isEmpty
        ? null
        : '${l10n.mediaTagsExcludeSummary(tag.excludeTerms.length)}: '
              '${tag.excludeTerms.join(' / ')}';
    return exclude == null ? include : '$include · $exclude';
  }

  Future<void> _deleteTag(
    BuildContext context,
    WidgetRef ref,
    MediaTagDto tag,
  ) async {
    final l10n = AppLocalizations.of(context);
    await showAppConfigDeleteConfirm(
      context: context,
      title: l10n.mediaTagsDeleteTitle,
      message: l10n.mediaTagsDeleteMessage(tag.name),
      onDelete: () => ref.read(mediaTagsProvider.notifier).delete(tag.id),
      successToast: l10n.mediaTagsDeleted,
      failureFallback: l10n.mediaTagsDeleteFailed,
      dialogKey: Key('media-tag-delete-dialog-${tag.id}'),
      confirmKey: Key('media-tag-delete-confirm-${tag.id}'),
      cancelKey: Key('media-tag-delete-cancel-${tag.id}'),
    );
  }
}
