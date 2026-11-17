import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/recent_views/data/dto/recent_view_dto.dart';
import 'package:sakuramedia/features/recent_views/presentation/providers/recent_views_provider.dart';
import 'package:sakuramedia/features/recent_views/presentation/widgets/recent_views_rail.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/navigation/app_section_header.dart';

/// 概览/「我的」tab 的「最近浏览」区块：与其他预览区块同款的横向 rail
/// （影片/女优混排标准卡片）。
///
/// 无记录（含加载失败）时整块隐藏，和「最近播放」缺省时的行为一致。
class RecentViewsSection extends ConsumerWidget {
  const RecentViewsSection({
    super.key,
    required this.onMoreTap,
    required this.onMovieTap,
    required this.onActorTap,
    this.actionSize = AppTextButtonSize.small,
    this.actionKey,
    this.spacingBefore = 0,
  });

  final VoidCallback onMoreTap;
  final ValueChanged<String> onMovieTap;
  final ValueChanged<int> onActorTap;
  final AppTextButtonSize actionSize;
  final Key? actionKey;

  /// 区块上方的间距；无记录整块隐藏时一并收起。
  final double spacingBefore;

  /// 区块只预览一屏多一点；更全的列表走「更多」页。
  /// 数据源是共享的单实例列表，这里只做展示截断。
  static const int previewLimit = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all =
        ref.watch(recentViewsProvider).value ?? const <RecentViewEntryDto>[];
    final entries = all.take(previewLimit).toList(growable: false);
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (spacingBefore > 0) SizedBox(height: spacingBefore),
        AppSectionHeader(
          title: AppLocalizations.of(context).recentSectionTitle,
          actionLabel: AppLocalizations.of(context).recentMore,
          actionSize: actionSize,
          actionKey: actionKey,
          onActionTap: onMoreTap,
        ),
        SizedBox(height: context.appSpacing.xs),
        RecentViewsRail(
          entries: entries,
          onMovieTap: onMovieTap,
          onActorTap: onActorTap,
        ),
      ],
    );
  }
}
