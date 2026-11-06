import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/clip_collections/data/dto/clip_collection_dto.dart';
import 'package:sakuramedia/features/moment_collections/data/dto/moment_collection_dto.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_context_menu_trigger.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_cover_card.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/base/overlays/app_action_menu.dart';

/// 合集封面卡：16:9 封面 + 名称 + 计数角标，「编辑 / 删除」走右键 / 长按菜单。
///
/// 切片 / 视频 / 时刻合集结构完全一致，仅在 DTO、计数字段、占位与计数角标图标、
/// 封面 `fit` 与 key 前缀上有差异，统一为 [CollectionCard.clip] /
/// [CollectionCard.video] / [CollectionCard.moment] 命名构造。
///
/// 用于合集主页横滑区（仅 [onTap]）与合集列表网格（带 [onEdit] / [onDelete]）。
/// 卡片宽度由调用方通过外层约束（如 `SizedBox(width: ...)`）控制。
class CollectionCard extends StatelessWidget {
  const CollectionCard._({
    super.key,
    required this.tapKey,
    required this.menuKey,
    required this.title,
    required this.count,
    required this.countIcon,
    required this.coverUrl,
    required this.coverFit,
    required this.placeholderIcon,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.glassChrome = false,
    this.coverBackdrop = false,
  });

  /// 视频合集卡。封面取自某个视频的首帧、可能是竖图，故 `fit: contain` 完整展示。
  factory CollectionCard.video({
    Key? key,
    required VideoCollectionDto collection,
    required VoidCallback onTap,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    bool coverBackdrop = false,
  }) {
    return CollectionCard._(
      key: key,
      tapKey: Key('video-collection-card-tap-${collection.id}'),
      menuKey: Key('video-collection-more-${collection.id}'),
      title: collection.name,
      count: collection.itemCount,
      countIcon: Icons.video_collection_rounded,
      coverUrl: collection.coverImage?.origin,
      coverFit: BoxFit.contain,
      placeholderIcon: Icons.video_collection_outlined,
      onTap: onTap,
      onEdit: onEdit,
      onDelete: onDelete,
      glassChrome: true,
      coverBackdrop: coverBackdrop,
    );
  }

  /// 时刻合集卡。缩略图为 16:9 横图，故 `fit: cover` 铺满。
  factory CollectionCard.moment({
    Key? key,
    required MomentCollectionDto collection,
    required VoidCallback onTap,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    return CollectionCard._(
      key: key,
      tapKey: Key('moment-collection-card-${collection.id}'),
      menuKey: Key('moment-collection-more-${collection.id}'),
      title: collection.name,
      count: collection.pointCount,
      countIcon: Icons.bookmarks_rounded,
      coverUrl: collection.coverImage?.origin,
      coverFit: BoxFit.cover,
      placeholderIcon: Icons.bookmarks_outlined,
      onTap: onTap,
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }

  /// 切片合集卡。缩略图为 16:9 横图，故 `fit: cover` 铺满。
  factory CollectionCard.clip({
    Key? key,
    required ClipCollectionDto collection,
    required VoidCallback onTap,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    return CollectionCard._(
      key: key,
      tapKey: Key('clip-collection-card-tap-${collection.id}'),
      menuKey: Key('clip-collection-more-${collection.id}'),
      title: collection.name,
      count: collection.clipCount,
      countIcon: Icons.video_library_rounded,
      coverUrl: collection.coverImage?.origin,
      coverFit: BoxFit.cover,
      placeholderIcon: Icons.video_library_outlined,
      onTap: onTap,
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }

  /// 整卡点击层（InkWell）的 key，供测试 / 自动化定位。
  final Key tapKey;

  /// 包裹整卡、接右键 / 长按手势的外层节点 key，供测试 / 自动化触发上下文菜单。
  final Key menuKey;

  /// 合集名称。
  final String title;

  /// 封面右下角的计数（切片数 / 视频数 / 时刻数）。
  final int count;

  /// 计数角标图标，按合集类型区分。
  final IconData countIcon;

  /// 封面图地址；为空时显示占位图标。
  final String? coverUrl;

  /// 封面填充方式。横图缩略图用 [BoxFit.cover] 铺满；可能为竖图的封面用
  /// [BoxFit.contain] 完整展示、不裁切。
  final BoxFit coverFit;

  /// 无封面时的占位图标。
  final IconData placeholderIcon;

  final VoidCallback onTap;

  /// 右键 / 长按菜单的「编辑」动作；与 [onDelete] 同为 `null` 时整卡不再接右键 / 长按。
  final VoidCallback? onEdit;

  /// 右键 / 长按菜单的「删除」动作。
  final VoidCallback? onDelete;

  /// 封面内浮玻璃信息条；为 `true` 时不再渲染封面下方的实色标题栏。
  final bool glassChrome;

  /// contain 封面两侧是否铺一层同图暗底，避免竖图在 16:9 框里露出两块空色。
  final bool coverBackdrop;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final cover = coverUrl;

    final card = AppInteractiveSurface(
      key: tapKey,
      onTap: onTap,
      child: AppCoverCard(
        coverAspectRatio: 16 / 9,
        cover: Stack(
          fit: StackFit.expand,
          children: [
            // muted 底色：cover 时被封面盖满，contain 时填充留白。
            ColoredBox(color: colors.surfaceMuted),
            if (cover != null && cover.isNotEmpty) ...[
              if (coverBackdrop && coverFit != BoxFit.cover) ...[
                Opacity(
                  opacity: 0.42,
                  child: MaskedImage(url: cover, fit: BoxFit.cover),
                ),
                ColoredBox(
                  color: colors.mediaOverlayStrong.withValues(alpha: 0.22),
                ),
              ],
              MaskedImage(url: cover, fit: coverFit),
            ] else
              Center(
                child: Icon(
                  placeholderIcon,
                  color: colors.borderStrong,
                  size: context.appComponentTokens.iconSizeLg,
                ),
              ),
          ],
        ),
        overlays: glassChrome
            ? <Widget>[
                Positioned(
                  left: spacing.xs,
                  right: spacing.xs,
                  bottom: spacing.xs,
                  child: _GlassCollectionInfoBar(
                    title: title,
                    count: count,
                    countIcon: countIcon,
                  ),
                ),
              ]
            : <Widget>[
                Positioned(
                  right: spacing.xs,
                  bottom: spacing.xs,
                  child: _CountBadge(count: count, icon: countIcon),
                ),
              ],
        footer: glassChrome
            ? null
            : Padding(
                padding: EdgeInsets.all(spacing.sm),
                child: Text(
                  title,
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
      ),
    );

    if (onEdit == null && onDelete == null) {
      return card;
    }
    return AppContextMenuTrigger(
      key: menuKey,
      onRequestMenu: (position) => _showContextMenu(context, position),
      child: card,
    );
  }

  Future<void> _showContextMenu(
    BuildContext context,
    Offset globalPosition,
  ) async {
    final edit = onEdit;
    final delete = onDelete;
    final action = await showAppActionMenu<_CollectionMenuAction>(
      context: context,
      globalPosition: globalPosition,
      items: [
        if (edit != null)
          AppMenuItem(
            value: _CollectionMenuAction.edit,
            label: AppLocalizations.of(context).commonEdit,
          ),
        if (delete != null)
          AppMenuItem(
            value: _CollectionMenuAction.delete,
            label: AppLocalizations.of(context).commonDelete,
            tone: AppTextTone.error,
          ),
      ],
    );
    if (action == null) {
      return;
    }
    switch (action) {
      case _CollectionMenuAction.edit:
        edit?.call();
      case _CollectionMenuAction.delete:
        delete?.call();
    }
  }
}

class _GlassCollectionInfoBar extends StatelessWidget {
  const _GlassCollectionInfoBar({
    required this.title,
    required this.count,
    required this.countIcon,
  });

  final String title;
  final int count;
  final IconData countIcon;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    final content = Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.onMedia,
            ),
          ),
        ),
        SizedBox(width: spacing.sm),
        Icon(
          countIcon,
          color: context.appTextPalette.onMedia,
          size: context.appComponentTokens.iconSize3xs,
        ),
        SizedBox(width: spacing.xs),
        Text(
          '$count',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.medium,
            tone: AppTextTone.onMedia,
          ),
        ),
      ],
    );
    final padding = EdgeInsets.symmetric(
      horizontal: spacing.sm,
      vertical: spacing.xs,
    );
    if (highContrast) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: context.appColors.mediaOverlayStrong.withValues(alpha: 0.86),
          borderRadius: context.appRadius.mdBorder,
        ),
        child: Padding(padding: padding, child: content),
      );
    }
    return GlassContainer(
      shape: LiquidRoundedSuperellipse(borderRadius: context.appRadius.md),
      padding: padding,
      settings: LiquidGlassSettings(
        thickness: 16,
        blur: 10,
        saturation: 1.3,
        chromaticAberration: 0.01,
        lightIntensity: 0.6,
        glassColor: context.appColors.mediaOverlayStrong.withValues(
          alpha: 0.34,
        ),
        shadowElevation: 0,
      ),
      // 卡片网格可能同时出现十几条玻璃信息条；用 minimal 档共享 BackdropFilter
      // 路径，避免每张卡都创建一条 premium/standard 玻璃纹理。
      quality: GlassQuality.minimal,
      useOwnLayer: true,
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.icon});

  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: context.appRadius.xsBorder,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.appSpacing.xs,
          vertical: context.appSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 12),
            SizedBox(width: context.appSpacing.xs),
            Text(
              '$count',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.medium,
                tone: AppTextTone.primary,
              ).copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

enum _CollectionMenuAction { edit, delete }

typedef CollectionCoverCard = CollectionCard;
