import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/image_search/data/image_search_result_item_dto.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';

const Object _unsetImageSearchValue = Object();

/// 图搜页面可跨导航保留的不可变业务状态。
///
/// 滚动控制器、viewport 自动续页门闩和弹窗仍由 View 持有。
@immutable
class ImageSearchState {
  ImageSearchState({
    this.fileBytes,
    this.fileName,
    this.mimeType,
    this.sessionId,
    this.nextCursor,
    this.expiresAt,
    List<ImageSearchResultItemDto> items = const <ImageSearchResultItemDto>[],
    this.filterState = const ImageSearchFilterState(),
    this.activeFilter = const ImageSearchFilterState(),
    this.activeCurrentMovieNumber,
    List<ActorListItemDto> subscribedActors = const <ActorListItemDto>[],
    this.isSearching = false,
    this.isLoadingMore = false,
    this.isLoadingSubscribedActors = false,
    this.isResolvingActorMovieIds = false,
    this.isPreviewExpanded = false,
    this.isFilterExpanded = false,
    this.errorMessage,
    this.subscribedActorsErrorMessage,
    this.bootstrappedSourceSignature,
    this.hasInitialized = false,
  }) : items = List<ImageSearchResultItemDto>.unmodifiable(items),
       subscribedActors = List<ActorListItemDto>.unmodifiable(subscribedActors);

  final Uint8List? fileBytes;
  final String? fileName;
  final String? mimeType;
  final String? sessionId;
  final String? nextCursor;
  final DateTime? expiresAt;
  final List<ImageSearchResultItemDto> items;
  final ImageSearchFilterState filterState;
  final ImageSearchFilterState activeFilter;
  final String? activeCurrentMovieNumber;
  final List<ActorListItemDto> subscribedActors;
  final bool isSearching;
  final bool isLoadingMore;
  final bool isLoadingSubscribedActors;
  final bool isResolvingActorMovieIds;
  final bool isPreviewExpanded;
  final bool isFilterExpanded;
  final String? errorMessage;
  final String? subscribedActorsErrorMessage;
  final Object? bootstrappedSourceSignature;
  final bool hasInitialized;

  bool get hasMore => nextCursor != null;

  bool get hasSource =>
      fileBytes != null &&
      fileBytes!.isNotEmpty &&
      (fileName?.isNotEmpty ?? false);

  ImageSearchState copyWith({
    Object? fileBytes = _unsetImageSearchValue,
    Object? fileName = _unsetImageSearchValue,
    Object? mimeType = _unsetImageSearchValue,
    Object? sessionId = _unsetImageSearchValue,
    Object? nextCursor = _unsetImageSearchValue,
    Object? expiresAt = _unsetImageSearchValue,
    List<ImageSearchResultItemDto>? items,
    ImageSearchFilterState? filterState,
    ImageSearchFilterState? activeFilter,
    Object? activeCurrentMovieNumber = _unsetImageSearchValue,
    List<ActorListItemDto>? subscribedActors,
    bool? isSearching,
    bool? isLoadingMore,
    bool? isLoadingSubscribedActors,
    bool? isResolvingActorMovieIds,
    bool? isPreviewExpanded,
    bool? isFilterExpanded,
    Object? errorMessage = _unsetImageSearchValue,
    Object? subscribedActorsErrorMessage = _unsetImageSearchValue,
    Object? bootstrappedSourceSignature = _unsetImageSearchValue,
    bool? hasInitialized,
  }) {
    return ImageSearchState(
      fileBytes:
          identical(fileBytes, _unsetImageSearchValue)
              ? this.fileBytes
              : fileBytes as Uint8List?,
      fileName:
          identical(fileName, _unsetImageSearchValue)
              ? this.fileName
              : fileName as String?,
      mimeType:
          identical(mimeType, _unsetImageSearchValue)
              ? this.mimeType
              : mimeType as String?,
      sessionId:
          identical(sessionId, _unsetImageSearchValue)
              ? this.sessionId
              : sessionId as String?,
      nextCursor:
          identical(nextCursor, _unsetImageSearchValue)
              ? this.nextCursor
              : nextCursor as String?,
      expiresAt:
          identical(expiresAt, _unsetImageSearchValue)
              ? this.expiresAt
              : expiresAt as DateTime?,
      items: items ?? this.items,
      filterState: filterState ?? this.filterState,
      activeFilter: activeFilter ?? this.activeFilter,
      activeCurrentMovieNumber:
          identical(activeCurrentMovieNumber, _unsetImageSearchValue)
              ? this.activeCurrentMovieNumber
              : activeCurrentMovieNumber as String?,
      subscribedActors: subscribedActors ?? this.subscribedActors,
      isSearching: isSearching ?? this.isSearching,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isLoadingSubscribedActors:
          isLoadingSubscribedActors ?? this.isLoadingSubscribedActors,
      isResolvingActorMovieIds:
          isResolvingActorMovieIds ?? this.isResolvingActorMovieIds,
      isPreviewExpanded: isPreviewExpanded ?? this.isPreviewExpanded,
      isFilterExpanded: isFilterExpanded ?? this.isFilterExpanded,
      errorMessage:
          identical(errorMessage, _unsetImageSearchValue)
              ? this.errorMessage
              : errorMessage as String?,
      subscribedActorsErrorMessage:
          identical(subscribedActorsErrorMessage, _unsetImageSearchValue)
              ? this.subscribedActorsErrorMessage
              : subscribedActorsErrorMessage as String?,
      bootstrappedSourceSignature:
          identical(bootstrappedSourceSignature, _unsetImageSearchValue)
              ? this.bootstrappedSourceSignature
              : bootstrappedSourceSignature,
      hasInitialized: hasInitialized ?? this.hasInitialized,
    );
  }
}
