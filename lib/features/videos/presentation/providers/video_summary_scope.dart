/// 视频列表页面的缓存身份。桌面与移动各保留独立的分页/筛选进度。
enum VideoSummaryScope {
  desktop('desktop:videos:list'),
  mobile('mobile:pornbox:list');

  const VideoSummaryScope(this.cacheKey);

  final String cacheKey;
}
