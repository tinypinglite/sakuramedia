import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/theme.dart';

class MovieMergePlaybackCandidateList extends StatelessWidget {
  const MovieMergePlaybackCandidateList({
    super.key,
    required this.candidates,
    required this.onSelected,
  });

  final List<MovieMergePlaybackCandidateDto> candidates;
  final ValueChanged<MovieMergePlaybackCandidateDto> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择合并播放媒体库',
          style: resolveAppTextStyle(context, size: AppTextSize.s18),
        ),
        SizedBox(height: context.appSpacing.md),
        for (final candidate in candidates)
          ListTile(
            key: Key('movie-merge-playback-library-${candidate.libraryId}'),
            contentPadding: EdgeInsets.zero,
            title: Text(
              candidate.libraryName.trim().isEmpty
                  ? '媒体库 ${candidate.libraryId}'
                  : candidate.libraryName.trim(),
            ),
            subtitle: Text(
              '${candidate.providerKey} · ${candidate.segmentCount} 段',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => onSelected(candidate),
          ),
      ],
    );
  }
}
