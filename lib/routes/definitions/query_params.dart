import 'package:sakuramedia/routes/app_route.dart';

const List<AppQueryParam> moviePlaybackQueryParameters = <AppQueryParam>[
  AppQueryParam(name: 'mediaId', alias: 'media-id', type: AppQueryType.integer),
  AppQueryParam(
    name: 'mergedLibraryId',
    alias: 'merged-library-id',
    type: AppQueryType.integer,
  ),
  AppQueryParam(
    name: 'positionSeconds',
    alias: 'position-seconds',
    type: AppQueryType.integer,
  ),
];

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
