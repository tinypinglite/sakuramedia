import 'package:sakuramedia/routes/app_route.dart';

const List<AppQueryParam> moviePlaybackQueryParameters = <AppQueryParam>[
  AppQueryParam(name: 'mediaId', alias: 'media-id', type: AppQueryType.integer),
  AppQueryParam(
    name: 'mergedLibraryId',
    alias: 'merged-library-id',
    type: AppQueryType.integer,
  ),
  AppQueryParam(
    name: 'mergedMediaIds',
    alias: 'merged-media-ids',
    type: AppQueryType.string,
  ),
  AppQueryParam(
    name: 'positionSeconds',
    alias: 'position-seconds',
    type: AppQueryType.integer,
  ),
];

List<int>? parseMergedMediaIds(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  final values = <int>[];
  for (final part in raw.split(',')) {
    final value = int.tryParse(part.trim());
    if (value == null || value <= 0) {
      return const <int>[];
    }
    values.add(value);
  }
  if (values.length < 2 || values.toSet().length != values.length) {
    return const <int>[];
  }
  return values;
}

const List<AppQueryParam> videoPlaybackQueryParameters = <AppQueryParam>[
  AppQueryParam(
    name: 'positionSeconds',
    alias: 'position-seconds',
    type: AppQueryType.integer,
  ),
];

const List<AppQueryParam> collectionPlayQueryParameters = <AppQueryParam>[
  AppQueryParam(
    name: 'startIndex',
    alias: 'start-index',
    type: AppQueryType.integer,
    defaultValue: 0,
  ),
  AppQueryParam(name: 'sort', type: AppQueryType.string),
];

const List<AppQueryParam> startIndexQueryParameters = <AppQueryParam>[
  AppQueryParam(
    name: 'startIndex',
    alias: 'start-index',
    type: AppQueryType.integer,
    defaultValue: 0,
  ),
];

const List<AppQueryParam> downloadTasksQueryParameters = <AppQueryParam>[
  AppQueryParam(
    name: 'downloadMovieNumber',
    alias: 'download-movie-number',
    type: AppQueryType.string,
  ),
];

const List<AppQueryParam> searchQueryParameters = <AppQueryParam>[
  AppQueryParam(
    name: 'useOnlineSearch',
    alias: 'use-online-search',
    type: AppQueryType.boolean,
    defaultValue: false,
  ),
];

const List<AppQueryParam> imageSearchQueryParameters = <AppQueryParam>[
  AppQueryParam(name: 'draftId', alias: 'draft-id', type: AppQueryType.string),
  AppQueryParam(
    name: 'currentMovieNumber',
    alias: 'current-movie-number',
    type: AppQueryType.string,
  ),
  AppQueryParam(
    name: 'currentMovieScope',
    alias: 'current-movie-scope',
    type: AppQueryType.string,
    defaultValue: 'all',
  ),
  AppQueryParam(name: 'mode', type: AppQueryType.string, defaultValue: 'image'),
];

const List<AppQueryParam> seriesQueryParameters = <AppQueryParam>[
  AppQueryParam(
    name: 'seriesName',
    alias: 'series-name',
    type: AppQueryType.string,
  ),
];
