/// 播放列表影片的分辨率筛选档位。
///
/// 精确档位匹配：按影片最高分辨率媒体归入唯一档位（8K / 4K 互斥）。
///
/// 影片列表与播放列表共用的筛选参数取值及展示顺序。
enum PlaylistResolutionFilter { k8k, k4k, k2k, f1080p, f720p, f480p, f360p }

extension PlaylistResolutionFilterX on PlaylistResolutionFilter {
  String get apiValue => switch (this) {
    PlaylistResolutionFilter.k8k => '8K',
    PlaylistResolutionFilter.k4k => '4K',
    PlaylistResolutionFilter.k2k => '2K',
    PlaylistResolutionFilter.f1080p => '1080P',
    PlaylistResolutionFilter.f720p => '720P',
    PlaylistResolutionFilter.f480p => '480P',
    PlaylistResolutionFilter.f360p => '360P',
  };

  String get label => apiValue;

  static PlaylistResolutionFilter? fromApiValue(String value) {
    for (final filter in PlaylistResolutionFilter.values) {
      if (filter.apiValue == value) {
        return filter;
      }
    }
    return null;
  }
}
