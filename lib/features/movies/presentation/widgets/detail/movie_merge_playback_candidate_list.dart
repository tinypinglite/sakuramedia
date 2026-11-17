import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_layout.dart';

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
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.movieWidgetSelectMergeLibraryTitle,
          style: resolveAppTextStyle(context, size: AppTextSize.s18),
        ),
        SizedBox(height: context.appSpacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: SingleChildScrollView(
            child: AppPickerIosSection(
              children: [
                for (final candidate in candidates)
                  AppPickerIosRow(
                    optionKey: Key(
                      'movie-merge-playback-library-${candidate.libraryId}',
                    ),
                    title: candidate.libraryName.trim().isEmpty
                        ? l10n.movieWidgetMediaLibraryFallback(
                            candidate.libraryId,
                          )
                        : candidate.libraryName.trim(),
                    subtitle: l10n.movieWidgetMediaLibrarySegments(
                      candidate.providerKey,
                      candidate.segmentCount,
                    ),
                    trailingIcon: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: context.appTextPalette.muted,
                    ),
                    onTap: () => onSelected(candidate),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
