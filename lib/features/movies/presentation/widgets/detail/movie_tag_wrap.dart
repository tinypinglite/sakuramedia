import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_pill_wrap.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

class MovieTagWrap extends StatelessWidget {
  const MovieTagWrap({super.key, required this.tags, this.onTagTap});

  final List<MovieTagDto> tags;
  final ValueChanged<MovieTagDto>? onTagTap;

  @override
  Widget build(BuildContext context) {
    final onTagTap = this.onTagTap;
    return MovieDetailPillWrap(
      items: tags
          .map(
            (tag) => MovieDetailPillItem(
              label: tag.name,
              onTap: onTagTap == null ? null : () => onTagTap(tag),
            ),
          )
          .toList(growable: false),
      emptyMessage: AppLocalizations.of(context).movieWidgetNoTags,
    );
  }
}
