import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_pill_wrap.dart';

class MovieTagWrap extends StatelessWidget {
  const MovieTagWrap({super.key, required this.tags});

  final List<MovieTagDto> tags;

  @override
  Widget build(BuildContext context) {
    return MovieDetailPillWrap(
      items: tags
          .map((tag) => MovieDetailPillItem(label: tag.name))
          .toList(growable: false),
      emptyMessage: '暂无标签',
    );
  }
}
