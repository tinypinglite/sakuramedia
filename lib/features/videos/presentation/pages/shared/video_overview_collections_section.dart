import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collections_overview_provider.dart';
import 'package:sakuramedia/features/videos/presentation/video_placeholders.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_card.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_hint_box.dart';

/// PornBox 首页的合集横滑区。
class VideoOverviewCollectionsSection extends ConsumerWidget {
  const VideoOverviewCollectionsSection({
    super.key,
    required this.mobile,
    required this.onViewAll,
    required this.onCollectionTap,
    this.onCreate,
  });

  final bool mobile;
  final VoidCallback onViewAll;
  final ValueChanged<VideoCollectionDto> onCollectionTap;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(videoCollectionsOverviewProvider);
    final collections = async.value ?? const <VideoCollectionDto>[];
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);

    final title = Text(
      l10n.videoCollectionsTitle,
      style: resolveAppTextStyle(
        context,
        size: mobile ? AppTextSize.s18 : AppTextSize.s14,
        weight: AppTextWeight.semibold,
        tone: AppTextTone.primary,
      ),
    );
    final viewAll = mobile
        ? AppGlassIconButton(
            key: const Key('mobile-pornbox-view-all-collections-button'),
            tooltip: l10n.videoViewAll,
            icon: Icons.chevron_right_rounded,
            onPressed: onViewAll,
          )
        : AppTextButton(
            key: const Key('videos-view-all-collections-button'),
            label: l10n.videoViewAll,
            size: AppTextButtonSize.small,
            trailingIcon: const Icon(Icons.chevron_right_rounded),
            emphasis: AppTextButtonEmphasis.secondary,
            onPressed: onViewAll,
          );
    final create = onCreate;

    final header = Row(
      children: [
        title,
        const Spacer(),
        if (collections.isNotEmpty) viewAll,
        if (!mobile && create != null) ...[
          SizedBox(width: spacing.sm),
          AppGlassHeaderGroup(
            children: <Widget>[
              AppGlassHeaderButton(
                key: const Key('videos-create-collection-button'),
                icon: Icons.add_rounded,
                label: l10n.videoNewCollection,
                onTap: create,
              ),
            ],
          ),
        ],
      ],
    );

    final content = mobile
        ? Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: spacing.sm),
                  child: header,
                ),
                Padding(
                  padding: EdgeInsets.only(top: spacing.md),
                  child: _buildRow(context, async, collections),
                ),
                SizedBox(height: spacing.sm),
              ],
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              SizedBox(height: spacing.sm),
              _buildRow(context, async, collections),
            ],
          );

    return content;
  }

  Widget _buildRow(
    BuildContext context,
    AsyncValue<List<VideoCollectionDto>> async,
    List<VideoCollectionDto> collections,
  ) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    if (async.hasError && collections.isEmpty) {
      return CollectionHintBox(
        message: apiErrorMessage(
          async.error!,
          fallback: l10n.videoCollectionsLoadFailed,
          l10n: l10n,
        ),
      );
    }
    final isLoading = async.isLoading && collections.isEmpty;
    final display = isLoading
        ? videoCollectionPlaceholders(count: 4)
        : collections;
    if (display.isEmpty) {
      return CollectionHintBox(message: l10n.videoCollectionsEmptyHint);
    }
    if (mobile) {
      return AppSkeletonizer(
        enabled: isLoading,
        child: SizedBox(
          height: 88,
          child: ListView.separated(
            key: const Key('mobile-pornbox-collections-row'),
            scrollDirection: Axis.horizontal,
            itemCount: display.length,
            separatorBuilder: (context, index) => SizedBox(width: spacing.sm),
            itemBuilder: (context, index) {
              final collection = display[index];
              return SizedBox(
                width: 156,
                child: CollectionCard.video(
                  key: Key('mobile-video-collection-card-${collection.id}'),
                  collection: collection,
                  coverBackdrop: true,
                  onTap: () => onCollectionTap(collection),
                ),
              );
            },
          ),
        ),
      );
    }
    const cardWidth = 210.0;
    final cardHeight = cardWidth * 9 / 16;
    return AppSkeletonizer(
      enabled: isLoading,
      child: SizedBox(
        height: cardHeight,
        child: ListView.separated(
          key: const Key('videos-collections-row'),
          scrollDirection: Axis.horizontal,
          itemCount: display.length,
          separatorBuilder: (context, index) =>
              SizedBox(width: context.appSpacing.md),
          itemBuilder: (context, index) {
            final collection = display[index];
            return SizedBox(
              width: cardWidth,
              child: Align(
                alignment: Alignment.topCenter,
                child: CollectionCard.video(
                  collection: collection,
                  onTap: () => onCollectionTap(collection),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
