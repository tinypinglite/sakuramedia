String desktopMoviesPageStateKey() => 'desktop:movies:list';
String mobileMoviesPageStateKey() => 'mobile:movies:list';

String desktopActorsPageStateKey() => 'desktop:actors:list';
String mobileActorsPageStateKey() => 'mobile:actors:list';

String mobileRankingsPageStateKey() => 'mobile:rankings:list';

String desktopImageSearchPageStateKey(String location) =>
    'desktop:image-search:$location';
String mobileImageSearchPageStateKey(String location) =>
    'mobile:image-search:$location';

String desktopSearchPageStateKey(String fullPath) => 'desktop:search:$fullPath';
String mobileSearchPageStateKey(String fullPath) => 'mobile:search:$fullPath';
