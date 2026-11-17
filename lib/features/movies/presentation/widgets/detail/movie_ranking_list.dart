import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_pill.dart';

/// 影片详情「榜单」区块：每条上榜记录一枚紧凑的荣誉徽章（奖杯 + 名次 + 榜单 · 周期），
/// 徽章按流式排列，不占整行。
class MovieRankingList extends StatelessWidget {
  const MovieRankingList({super.key, required this.rankings});

  final List<MovieRankingDto> rankings;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('movie-ranking-list'),
      spacing: context.appComponentTokens.movieDetailPillGap,
      runSpacing: context.appComponentTokens.movieDetailPillGap,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final ranking in rankings) _MovieRankingChip(ranking: ranking),
      ],
    );
  }
}

class _MovieRankingChip extends StatelessWidget {
  const _MovieRankingChip({required this.ranking});

  final MovieRankingDto ranking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = [
      ranking.boardName.trim(),
      ranking.periodLabel(l10n).trim(),
    ].where((part) => part.isNotEmpty).join(' · ');

    return AppPill.custom(
      tone: AppPillTone.warning,
      size: AppPillSize.prominent,
      leading: Icon(
        Icons.emoji_events_rounded,
        color: context.appColors.movieDetailScoreIcon,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '#${ranking.rank}',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.warning,
            ),
          ),
          if (label.isNotEmpty) ...[
            SizedBox(width: context.appSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.warning,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
