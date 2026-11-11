import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/status/data/status_dto.dart';

/// 系统概览 State。
///
/// 各加载腿错误语义**刻意不同**(勿统一):
/// - status / insights / watchTrend 失败 → 置各自的 error 文案;
/// - imageSearchStatus 失败 → 静默置 null,不置错。
@immutable
class OverviewSystemInfoState {
  const OverviewSystemInfoState({
    this.isLoadingStatus = true,
    this.isLoadingImageSearchStatus = true,
    this.isLoadingInsights = true,
    this.isLoadingWatchTrend = true,
    this.isResettingImageSearch = false,
    this.status,
    this.imageSearchStatus,
    this.insights,
    this.watchTrend,
    this.statusError,
    this.insightsError,
    this.watchTrendError,
    this.watchTrendRange = WatchTrendRange.last30Days,
  });

  final bool isLoadingStatus;
  final bool isLoadingImageSearchStatus;
  final bool isLoadingInsights;
  final bool isLoadingWatchTrend;
  final bool isResettingImageSearch;
  final StatusDto? status;
  final StatusImageSearchDto? imageSearchStatus;
  final StatusInsightsDto? insights;
  final StatusWatchTrendDto? watchTrend;
  final String? statusError;
  final String? insightsError;
  final String? watchTrendError;
  final WatchTrendRange watchTrendRange;

  OverviewSystemInfoState copyWith({
    bool? isLoadingStatus,
    bool? isLoadingImageSearchStatus,
    bool? isLoadingInsights,
    bool? isLoadingWatchTrend,
    bool? isResettingImageSearch,
    Object? status = _kSentinel,
    Object? imageSearchStatus = _kSentinel,
    Object? insights = _kSentinel,
    Object? watchTrend = _kSentinel,
    Object? statusError = _kSentinel,
    Object? insightsError = _kSentinel,
    Object? watchTrendError = _kSentinel,
    WatchTrendRange? watchTrendRange,
  }) {
    return OverviewSystemInfoState(
      isLoadingStatus: isLoadingStatus ?? this.isLoadingStatus,
      isLoadingImageSearchStatus:
          isLoadingImageSearchStatus ?? this.isLoadingImageSearchStatus,
      isLoadingInsights: isLoadingInsights ?? this.isLoadingInsights,
      isLoadingWatchTrend: isLoadingWatchTrend ?? this.isLoadingWatchTrend,
      isResettingImageSearch:
          isResettingImageSearch ?? this.isResettingImageSearch,
      status: identical(status, _kSentinel)
          ? this.status
          : status as StatusDto?,
      imageSearchStatus: identical(imageSearchStatus, _kSentinel)
          ? this.imageSearchStatus
          : imageSearchStatus as StatusImageSearchDto?,
      insights: identical(insights, _kSentinel)
          ? this.insights
          : insights as StatusInsightsDto?,
      watchTrend: identical(watchTrend, _kSentinel)
          ? this.watchTrend
          : watchTrend as StatusWatchTrendDto?,
      statusError: identical(statusError, _kSentinel)
          ? this.statusError
          : statusError as String?,
      insightsError: identical(insightsError, _kSentinel)
          ? this.insightsError
          : insightsError as String?,
      watchTrendError: identical(watchTrendError, _kSentinel)
          ? this.watchTrendError
          : watchTrendError as String?,
      watchTrendRange: watchTrendRange ?? this.watchTrendRange,
    );
  }
}

const Object _kSentinel = Object();
