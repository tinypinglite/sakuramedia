import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/config_delete_helpers.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_config_empty_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_entity_list_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/media_tag_retag_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/media_tag_rule_editor.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/media_tag_rule_tester.dart';
import 'package:sakuramedia/features/media/data/media_tag_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_tags_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/overlays/app_action_menu.dart';

class MobileMediaTagsPage extends ConsumerWidget {
  const MobileMediaTagsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final async = ref.watch(mediaTagsProvider);
    return ColoredBox(
      key: const Key('mobile-settings-media-tags'),
      color: colors.surfaceCard,
      child: Column(
        children: [
          Expanded(
            child: AppAdaptiveRefreshScrollView(
              onRefresh: () async {
                final message = await ref
                    .read(mediaTagsProvider.notifier)
                    .refresh();
                if (message != null && context.mounted) showToast(message);
              },
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    spacing.md,
                    spacing.md,
                    spacing.md,
                    spacing.lg,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppNoticeCard(
                          leadingIcon: Icons.sell_outlined,
                          title: l10n.mediaTagsManagementNoticeTitle,
                          description:
                              l10n.mediaTagsManagementNoticeDescription,
                        ),
                        SizedBox(height: spacing.md),
                        _buildContent(context, ref, async),
                        SizedBox(height: spacing.lg),
                        const MediaTagRuleTester(),
                        SizedBox(height: spacing.md),
                        const MediaTagRetagCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(spacing.md),
            decoration: BoxDecoration(
              color: colors.surfaceCard,
              border: Border(top: BorderSide(color: colors.divider)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: AppButton(
                key: const Key('mobile-media-tag-create-button'),
                label: l10n.mediaTagsAdd,
                variant: AppButtonVariant.primary,
                icon: const Icon(Icons.add_rounded),
                onPressed: () => showMediaTagRuleEditor(context, mobile: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<MediaTagDto>> async,
  ) {
    final l10n = AppLocalizations.of(context);
    if (async.isLoading && async.value == null) {
      return AppSkeletonizer(
        enabled: true,
        child: Column(
          children: [
            for (var index = 0; index < 3; index++) ...[
              _tagCard(
                context,
                ref,
                MediaTagDto(
                  id: index + 1,
                  name: 'Media tag',
                  includeTerms: const ['4k'],
                  excludeTerms: const [],
                  enabled: true,
                  mediaCount: 12,
                ),
              ),
              if (index < 2) SizedBox(height: context.appSpacing.sm),
            ],
          ],
        ),
      );
    }
    if (async.hasError) {
      return AppMobileSectionError(
        key: const Key('mobile-media-tags-error'),
        title: l10n.mediaTagsLoadFailedTitle,
        message: apiErrorMessage(
          async.error!,
          fallback: l10n.mediaTagsLoadFailedFallback,
          l10n: l10n,
        ),
        onRetry: () => ref.read(mediaTagsProvider.notifier).reload(),
        retryButtonKey: const Key('mobile-media-tags-retry'),
      );
    }
    final tags = async.value ?? const <MediaTagDto>[];
    if (tags.isEmpty) {
      return MobileConfigEmptyCard(
        key: const Key('mobile-media-tags-empty'),
        message: l10n.mediaTagsEmpty,
      );
    }
    return Column(
      children: [
        for (var index = 0; index < tags.length; index++) ...[
          _tagCard(context, ref, tags[index]),
          if (index < tags.length - 1) SizedBox(height: context.appSpacing.sm),
        ],
      ],
    );
  }

  Widget _tagCard(BuildContext context, WidgetRef ref, MediaTagDto tag) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final colors = context.appColors;
    return MobileEntityListCard(
      outerKey: Key('mobile-media-tag-rule-${tag.id}'),
      bodyKey: Key('mobile-media-tag-rule-body-${tag.id}'),
      leading: Container(
        width: context.appComponentTokens.iconSizeXl + spacing.md,
        height: context.appComponentTokens.iconSizeXl + spacing.md,
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: context.appRadius.mdBorder,
        ),
        child: Icon(
          Icons.sell_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(
        tag.name,
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s14,
          weight: AppTextWeight.semibold,
          tone: AppTextTone.primary,
        ),
      ),
      titleTrailing: tag.enabled
          ? null
          : AppBadge(
              label: l10n.mediaTagsDisabledBadge,
              tone: AppBadgeTone.neutral,
              size: AppBadgeSize.compact,
            ),
      body: [
        SizedBox(height: spacing.xs),
        Text(
          tag.includeTerms.join(' / '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.secondary,
          ),
        ),
        if (tag.excludeTerms.isNotEmpty) ...[
          SizedBox(height: spacing.xs),
          Text(
            '${l10n.mediaTagsExcludeSummary(tag.excludeTerms.length)}: '
            '${tag.excludeTerms.join(' / ')}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.muted,
            ),
          ),
        ],
        SizedBox(height: spacing.sm),
        Text(
          l10n.mediaTagsMediaCount(tag.mediaCount),
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.muted,
          ),
        ),
      ],
      onTap: () =>
          showMediaTagRuleEditor(context, mobile: true, initialTag: tag),
      trailingAction: AppIconButton(
        key: Key('mobile-media-tag-more-${tag.id}'),
        tooltip: l10n.mediaTagsMoreActions,
        backgroundColor: colors.surfaceMuted,
        borderColor: colors.borderSubtle,
        icon: const Icon(Icons.more_horiz_rounded),
        onPressed: () => _openActions(context, ref, tag),
      ),
    );
  }

  Future<void> _openActions(
    BuildContext context,
    WidgetRef ref,
    MediaTagDto tag,
  ) async {
    final l10n = AppLocalizations.of(context);
    final action = await showAppActionMenu<_MediaTagAction>(
      context: context,
      presentation: AppMenuPresentation.bottomDrawer,
      drawerKey: Key('mobile-media-tag-actions-${tag.id}'),
      title: tag.name,
      items: [
        AppMenuItem(
          key: Key('mobile-media-tag-edit-${tag.id}'),
          value: _MediaTagAction.edit,
          label: l10n.mediaTagsEditTitle,
          icon: Icons.edit_outlined,
        ),
        AppMenuItem(
          key: Key('mobile-media-tag-delete-${tag.id}'),
          value: _MediaTagAction.delete,
          label: l10n.mediaTagsDeleteTitle,
          icon: Icons.delete_outline_rounded,
          tone: AppTextTone.error,
        ),
      ],
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case _MediaTagAction.edit:
        await showMediaTagRuleEditor(context, mobile: true, initialTag: tag);
      case _MediaTagAction.delete:
        await _deleteTag(context, ref, tag);
    }
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
      dialogKey: Key('mobile-media-tag-delete-dialog-${tag.id}'),
      confirmKey: Key('mobile-media-tag-delete-confirm-${tag.id}'),
      cancelKey: Key('mobile-media-tag-delete-cancel-${tag.id}'),
    );
  }
}

enum _MediaTagAction { edit, delete }
