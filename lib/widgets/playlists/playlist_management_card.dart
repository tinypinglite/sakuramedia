import 'package:flutter/material.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/playlists/playlist_banner_card.dart';

/// 播放列表管理卡片的布局形态。
/// - [normal]：大 banner 覆顶 + 信息竖列 + 三按钮底部横列（移动端管理页样式）。
/// - [dense]：左侧小 banner + 右侧信息 + 右端竖列按钮（桌面设置页 2 列网格样式）。
enum PlaylistCardLayout { normal, dense }

/// 「自定义播放列表管理」列表卡片，双端共用。
///
/// 由外层传入 `keyPrefix` 生成子按钮 / 卡本体的稳定 Key（桌面 `desktop-playlist`、
/// 移动 `mobile-playlist`），测试可按前缀锚点。任何一个 `on*Tap` 传 `null` 都
/// 会隐藏对应按钮（比如桌面不需要 view，可传 null）。
class PlaylistManagementCard extends StatelessWidget {
  const PlaylistManagementCard({
    super.key,
    required this.playlist,
    required this.layout,
    this.coverImageUrl,
    this.keyPrefix = 'playlist',
    this.onViewTap,
    this.onEditTap,
    this.onDeleteTap,
  });

  final PlaylistDto playlist;
  final PlaylistCardLayout layout;
  final String? coverImageUrl;
  final String keyPrefix;
  final VoidCallback? onViewTap;
  final VoidCallback? onEditTap;
  final VoidCallback? onDeleteTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      key: Key('$keyPrefix-management-card-${playlist.id}'),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
        boxShadow: context.appShadows.card,
      ),
      child: switch (layout) {
        PlaylistCardLayout.normal => _buildNormal(context),
        PlaylistCardLayout.dense => _buildDense(context),
      },
    );
  }

  Widget _buildNormal(BuildContext context) {
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(spacing.md, spacing.md, spacing.md, 0),
          child: PlaylistBannerCard(
            key: Key('$keyPrefix-banner-${playlist.id}'),
            title: playlist.name,
            coverImageUrl: coverImageUrl,
            onTap: onViewTap,
          ),
        ),
        Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitle(context),
              SizedBox(height: spacing.xs),
              _buildCount(context),
              SizedBox(height: spacing.xs),
              _buildDescription(context),
              ..._buildUpdatedAt(context, topSpacing: spacing.xs),
              SizedBox(height: spacing.md),
              _buildActionRow(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDense(BuildContext context) {
    final spacing = context.appSpacing;
    final tokens = context.appComponentTokens;
    return Padding(
      padding: EdgeInsets.all(spacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: tokens.playlistBannerHeight * 1.6,
            height: tokens.playlistBannerHeight,
            child: PlaylistBannerCard(
              key: Key('$keyPrefix-banner-${playlist.id}'),
              title: playlist.name,
              coverImageUrl: coverImageUrl,
              onTap: onViewTap,
            ),
          ),
          SizedBox(width: spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTitle(context),
                SizedBox(height: spacing.xs),
                _buildCount(context),
                SizedBox(height: spacing.xs),
                _buildDescription(context),
                ..._buildUpdatedAt(context, topSpacing: spacing.xs),
              ],
            ),
          ),
          SizedBox(width: spacing.md),
          _buildActionColumn(context),
        ],
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Text(
      playlist.name,
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s14,
        weight: AppTextWeight.semibold,
        tone: AppTextTone.primary,
      ),
    );
  }

  Widget _buildCount(BuildContext context) {
    return Text(
      '${playlist.movieCount} 部影片',
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s12,
        weight: AppTextWeight.regular,
        tone: AppTextTone.secondary,
      ),
    );
  }

  Widget _buildDescription(BuildContext context) {
    final trimmed = playlist.description.trim();
    return Text(
      trimmed.isEmpty ? '未填写描述' : trimmed,
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s12,
        weight: AppTextWeight.regular,
        tone: AppTextTone.muted,
      ),
    );
  }

  List<Widget> _buildUpdatedAt(
    BuildContext context, {
    required double topSpacing,
  }) {
    final label = formatUpdatedAtLabel(playlist.updatedAt);
    if (label == null) {
      return const <Widget>[];
    }
    return [
      SizedBox(height: topSpacing),
      Text(
        '更新时间: $label',
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          weight: AppTextWeight.regular,
          tone: AppTextTone.muted,
        ),
      ),
    ];
  }

  Widget _buildActionRow(BuildContext context) {
    final spacing = context.appSpacing;
    final buttons = _buildActionButtons();
    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) SizedBox(width: spacing.sm),
          Expanded(child: buttons[i]),
        ],
      ],
    );
  }

  Widget _buildActionColumn(BuildContext context) {
    final spacing = context.appSpacing;
    final buttons = _buildActionButtons();
    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: 100,
      child: Column(
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) SizedBox(height: spacing.xs),
            SizedBox(width: double.infinity, child: buttons[i]),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons() {
    final result = <Widget>[];
    if (onViewTap != null) {
      result.add(
        AppButton(
          key: Key('$keyPrefix-view-${playlist.id}'),
          label: '查看详情',
          size: AppButtonSize.xSmall,
          onPressed: onViewTap,
        ),
      );
    }
    if (onEditTap != null) {
      result.add(
        AppButton(
          key: Key('$keyPrefix-edit-${playlist.id}'),
          label: '编辑',
          size: AppButtonSize.xSmall,
          onPressed: onEditTap,
        ),
      );
    }
    if (onDeleteTap != null) {
      result.add(
        AppButton(
          key: Key('$keyPrefix-delete-${playlist.id}'),
          label: '删除',
          size: AppButtonSize.xSmall,
          variant: AppButtonVariant.danger,
          onPressed: onDeleteTap,
        ),
      );
    }
    return result;
  }
}
