import 'package:material_ui/material_ui.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/media/video/video_loading_indicator.dart';
import 'package:sakuramedia/widgets/domain/media/collapsible_player_split_view.dart';

/// 影片播放器纯展示布局组件族（左右分栏 / 加载 / 错误 / 空态面板）。
/// 由 [MoviePlayerContent] 组装；无业务状态，全部参数由调用方注入。

class MoviePlayerSplitLayout extends StatelessWidget {
  const MoviePlayerSplitLayout({
    super.key,
    required this.controller,
    required this.dividerHandleBuffer,
    required this.leftChild,
    required this.rightChild,
    this.collapsible = false,
    this.panelAvailable = true,
  });

  final MultiSplitViewController controller;
  final double dividerHandleBuffer;
  final Widget leftChild;
  final Widget rightChild;

  /// 传 true：缩略图面板默认展开，右上角常显开关可收起/再展开。
  final bool collapsible;

  /// 右侧缩略图面板是否有内容可展示；无内容时不显示开关。
  final bool panelAvailable;

  @override
  Widget build(BuildContext context) {
    return CollapsiblePlayerSplitView(
      controller: controller,
      dividerHandleBuffer: dividerHandleBuffer,
      collapsible: collapsible,
      panelAvailable: panelAvailable,
      handleKey: const Key('movie-player-panel-handle'),
      leftBuilder: (context) => MoviePlayerPanel(child: leftChild),
      rightBuilder: (context) => MoviePlayerSidePanel(child: rightChild),
    );
  }
}

class MoviePlayerPanel extends StatelessWidget {
  const MoviePlayerPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      key: const Key('movie-player-left-panel'),
      borderRadius: context.appRadius.lgBorder,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.appColors.movieDetailHeroBackgroundStart,
        ),
        child: child,
      ),
    );
  }
}

class MoviePlayerSidePanel extends StatelessWidget {
  const MoviePlayerSidePanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('movie-player-thumbnail-panel'),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.xsBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: child,
    );
  }
}

class MoviePlayerLoadingState extends StatelessWidget {
  const MoviePlayerLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    // 未就绪态全屏铺满单面板，不走左右分栏——否则右侧 28% 会露出一块空的纯白
    // `surfaceCard` 占位卡（surfaceCard = 0xFFFFFFFF），在黑底上显示成突兀的白条。
    return const MoviePlayerLoadingPanel();
  }
}

class MoviePlayerLoadingPanel extends StatelessWidget {
  const MoviePlayerLoadingPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('movie-player-loading-state'),
      color: context.appColors.movieDetailHeroBackgroundStart,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const SizedBox.expand(key: Key('movie-player-left-blackout')),
          Center(
            child: VideoLoadingIndicator(
              label: AppLocalizations.of(context).moviePagePlayerLoading,
            ),
          ),
        ],
      ),
    );
  }
}

class MoviePlayerErrorState extends StatelessWidget {
  const MoviePlayerErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // 同加载态：全屏单面板，避免右侧空白 surfaceCard 卡片露出成白条。
    final l10n = AppLocalizations.of(context);
    return MoviePlayerPanelMessage(
      title: l10n.moviePagePlayerLoadFailedTitle,
      message: message,
      icon: Icons.play_disabled_outlined,
      actionLabel: l10n.commonRetry,
      onAction: onRetry,
    );
  }
}

class MoviePlayerEmptyState extends StatelessWidget {
  const MoviePlayerEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MoviePlayerPanelMessage(
      title: l10n.moviePagePlayerEmptyTitle,
      message: l10n.moviePagePlayerEmptyMessage,
      icon: Icons.play_circle_outline_rounded,
      actionLabel: null,
      onAction: null,
    );
  }
}

class MoviePlayerPanelMessage extends StatelessWidget {
  const MoviePlayerPanelMessage({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.appColors.movieDetailHeroBackgroundStart,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: EdgeInsets.all(context.appSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: context.appComponentTokens.iconSize2xl,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(height: context.appSpacing.lg),
                Text(
                  title,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s18,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.onMedia,
                  ),
                ),
                SizedBox(height: context.appSpacing.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style:
                      resolveAppTextStyle(
                        context,
                        size: AppTextSize.s14,
                        weight: AppTextWeight.regular,
                        tone: AppTextTone.secondary,
                      ).copyWith(
                        color: context.appTextPalette.onMedia.withValues(
                          alpha: 0.8,
                        ),
                      ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  SizedBox(height: context.appSpacing.lg),
                  AppButton(
                    label: actionLabel!,
                    variant: AppButtonVariant.primary,
                    onPressed: onAction,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
