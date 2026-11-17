String desktopMoviesPageCacheKey() => 'desktop:movies:list';
String mobileMoviesPageCacheKey() => 'mobile:movies:list';

String desktopActorsPageCacheKey() => 'desktop:actors:list';
String mobileActorsPageCacheKey() => 'mobile:actors:list';

String desktopVideosPageCacheKey() => 'desktop:videos:list';
String mobilePornboxPageCacheKey() => 'mobile:pornbox:list';

String desktopRankingsPageCacheKey() => 'desktop:rankings:list';
String mobileRankingsPageCacheKey() => 'mobile:rankings:list';

String desktopImageSearchPageCacheKey(String location) =>
    'desktop:image-search:$location';
String mobileImageSearchPageCacheKey(String location) =>
    'mobile:image-search:$location';

String desktopSearchPageCacheKey(String fullPath) =>
    'desktop:search:$fullPath';
String mobileSearchPageCacheKey(String fullPath) => 'mobile:search:$fullPath';

String desktopMovieDetailPageCacheKey(String movieNumber) =>
    'desktop:movies:detail:$movieNumber';
String mobileMovieDetailPageCacheKey(String movieNumber) =>
    'mobile:movies:detail:$movieNumber';
