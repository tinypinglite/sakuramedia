import 'package:flutter/material.dart';
import 'package:sakuramedia/features/media/data/media_play_url_dto.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_pill_wrap.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_playback_options.dart';
import 'package:sakuramedia/theme.dart';

/// 影片详情页媒体区的「播放源 + 播放模式」设置行。
///
/// 分情况展示：
/// - 播放源：仅当本地与 115 两种源都有可播媒体时显示；
/// - 播放模式：仅当合并播放可用（外部播放器 + 本地/115 多分段）时显示。
/// 都不满足时整行隐藏，播放行为回落到旧逻辑。
class MoviePlaybackOptionsBar extends StatelessWidget {
  const MoviePlaybackOptionsBar({
    super.key,
    required this.sourceOptions,
    required this.selectedSource,
    required this.onSourceChanged,
    required this.mergedAvailable,
    required this.selectedMode,
    required this.onModeChanged,
  });

  final MoviePlaybackSourceOptions sourceOptions;
  final MoviePlayUrlSource? selectedSource;
  final ValueChanged<MoviePlayUrlSource> onSourceChanged;
  final bool mergedAvailable;
  final MoviePlayUrlMode selectedMode;
  final ValueChanged<MoviePlayUrlMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final showSource = sourceOptions.hasBothSources;
    final showMode = mergedAvailable;
    if (!showSource && !showMode) {
      return const SizedBox.shrink();
    }

    final rows = <Widget>[
      if (showSource)
        _buildRow(
          context,
          label: '播放源',
          labelKey: const Key('movie-playback-source-label'),
          child: MovieDetailPillWrap(
            emptyMessage: '',
            items: <MovieDetailPillItem>[
              _sourcePill(
                key: const Key('movie-playback-source-local'),
                label: '本地存储',
                source: MoviePlayUrlSource.local,
              ),
              _sourcePill(
                key: const Key('movie-playback-source-cloud115'),
                label: '115 网盘',
                source: MoviePlayUrlSource.cloud115,
              ),
            ],
          ),
        ),
      if (showMode)
        _buildRow(
          context,
          label: '播放模式',
          labelKey: const Key('movie-playback-mode-label'),
          child: MovieDetailPillWrap(
            emptyMessage: '',
            items: <MovieDetailPillItem>[
              _modePill(
                key: const Key('movie-playback-mode-single'),
                label: '单个播放',
                mode: MoviePlayUrlMode.single,
              ),
              _modePill(
                key: const Key('movie-playback-mode-merged'),
                label: '合并播放',
                mode: MoviePlayUrlMode.merged,
              ),
            ],
          ),
        ),
    ];

    return Column(
      key: const Key('movie-playback-options-bar'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          if (index > 0) SizedBox(height: context.appSpacing.xs),
          rows[index],
        ],
      ],
    );
  }

  Widget _buildRow(
    BuildContext context, {
    required String label,
    required Key labelKey,
    required Widget child,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          key: labelKey,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.medium,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(width: context.appSpacing.md),
        Expanded(child: child),
      ],
    );
  }

  MovieDetailPillItem _sourcePill({
    required Key key,
    required String label,
    required MoviePlayUrlSource source,
  }) {
    return MovieDetailPillItem(
      key: key,
      label: label,
      isSelected: selectedSource == source,
      onTap: () => onSourceChanged(source),
    );
  }

  MovieDetailPillItem _modePill({
    required Key key,
    required String label,
    required MoviePlayUrlMode mode,
  }) {
    return MovieDetailPillItem(
      key: key,
      label: label,
      isSelected: selectedMode == mode,
      onTap: () => onModeChanged(mode),
    );
  }
}
