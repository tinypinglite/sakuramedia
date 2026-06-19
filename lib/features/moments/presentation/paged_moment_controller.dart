import 'package:flutter/material.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/media/data/media_point_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/features/shared/presentation/paged_load_controller.dart';

typedef MomentPageFetcher =
    Future<PaginatedResponseDto<MediaPointListItemDto>> Function(
      int page,
      int pageSize,
      String sort,
      String kind,
    );

enum MomentSortOrder {
  latest(label: '最新', apiValue: 'created_at:desc'),
  earliest(label: '最早', apiValue: 'created_at:asc');

  const MomentSortOrder({required this.label, required this.apiValue});

  final String label;
  final String apiValue;
}

enum MomentKindFilter {
  jav(label: 'JAV', apiValue: 'jav'),
  video(label: '视频', apiValue: 'video');

  const MomentKindFilter({required this.label, required this.apiValue});

  final String label;
  final String apiValue;
}

class MomentListItem {
  const MomentListItem({
    required this.pointId,
    required this.mediaId,
    required this.movieNumber,
    this.videoItemId,
    required this.thumbnailId,
    required this.offsetSeconds,
    required this.createdAt,
    required this.image,
  });

  final int pointId;
  final int mediaId;
  // JAV 时刻带番号；视频时刻为 null（用 videoItemId 区分归属）。
  final String? movieNumber;
  final int? videoItemId;
  final int thumbnailId;
  final int offsetSeconds;
  final DateTime? createdAt;
  final MovieImageDto? image;

  bool get isVideo => videoItemId != null && videoItemId! > 0;

  // 卡片标签 / 播放器标题 / 副标题统一走这里，避免三处各拼一遍导致 pointId / videoItemId 不一致。
  String get displayLabel {
    final number = movieNumber;
    if (number != null && number.isNotEmpty) {
      return number;
    }
    final videoId = videoItemId;
    if (videoId != null && videoId > 0) {
      return '视频 #$videoId';
    }
    return '时刻 #$pointId';
  }
}

class PagedMomentController extends PagedLoadController<MomentListItem> {
  PagedMomentController({
    required MomentPageFetcher fetchPage,
    int initialPage = 1,
    int pageSize = 20,
    double loadMoreTriggerOffset = 300,
    String initialLoadErrorText = '时刻列表加载失败，请稍后重试',
    String loadMoreErrorText = '加载更多失败，请点击重试',
    ScrollController? scrollController,
  }) : _fetchPage = fetchPage,
       super(
         fetchPage:
             (_, __) =>
                 throw UnimplementedError(
                   'PagedMomentController overrides fetchPage.',
                 ),
         initialPage: initialPage,
         pageSize: pageSize,
         loadMoreTriggerOffset: loadMoreTriggerOffset,
         initialLoadErrorText: initialLoadErrorText,
         loadMoreErrorText: loadMoreErrorText,
         scrollController: scrollController,
       );

  final MomentPageFetcher _fetchPage;
  MomentSortOrder _sortOrder = MomentSortOrder.latest;
  MomentSortOrder get sortOrder => _sortOrder;

  MomentKindFilter _kindFilter = MomentKindFilter.jav;
  MomentKindFilter get kindFilter => _kindFilter;

  @override
  Future<PaginatedResponseDto<MomentListItem>> fetchPage(
    int page,
    int pageSize,
  ) async {
    final response = await _fetchPage(
      page,
      pageSize,
      _sortOrder.apiValue,
      _kindFilter.apiValue,
    );
    return PaginatedResponseDto<MomentListItem>(
      items: response.items
          .map(
            (item) => MomentListItem(
              pointId: item.pointId,
              mediaId: item.mediaId,
              movieNumber: item.movieNumber,
              videoItemId: item.videoItemId,
              thumbnailId: item.thumbnailId,
              offsetSeconds: item.offsetSeconds,
              createdAt: item.createdAt,
              image: item.image,
            ),
          )
          .toList(growable: false),
      page: response.page,
      pageSize: response.pageSize,
      total: response.total,
    );
  }

  Future<void> setSortOrder(MomentSortOrder nextOrder) async {
    if (_sortOrder == nextOrder) {
      return;
    }
    _sortOrder = nextOrder;
    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
    }
    await reload();
  }

  Future<void> setKindFilter(MomentKindFilter nextKind) async {
    if (_kindFilter == nextKind) {
      return;
    }
    _kindFilter = nextKind;
    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
    }
    await reload();
  }
}
