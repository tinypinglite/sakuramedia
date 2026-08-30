import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/status/data/status_dto.dart';

/// 系统概览 State(迁移前 `OverviewSystemInfoController` 的 11 个公有可变
/// 字段重塑为不可变值对象)。
///
/// 两条加载腿错误语义**刻意不同**(勿统一):
/// - status 失败 → 置 [statusError];
/// - imageSearchStatus 失败 → 静默置 null(UI 显示「不可用」),不置错。
@immutable
class OverviewSystemInfoState {
  const OverviewSystemInfoState({
    this.isLoadingStatus = true,
    this.isLoadingImageSearchStatus = true,
    this.isTestingMetadataProviders = false,
    this.status,
    this.imageSearchStatus,
    this.javdbHealthy,
    this.statusError,
  });

  final bool isLoadingStatus;
  final bool isLoadingImageSearchStatus;
  final bool isTestingMetadataProviders;
  final StatusDto? status;
  final StatusImageSearchDto? imageSearchStatus;
  final bool? javdbHealthy;
  final String? statusError;

  OverviewSystemInfoState copyWith({
    bool? isLoadingStatus,
    bool? isLoadingImageSearchStatus,
    bool? isTestingMetadataProviders,
    Object? status = _kSentinel,
    Object? imageSearchStatus = _kSentinel,
    Object? javdbHealthy = _kSentinel,
    Object? statusError = _kSentinel,
  }) {
    return OverviewSystemInfoState(
      isLoadingStatus: isLoadingStatus ?? this.isLoadingStatus,
      isLoadingImageSearchStatus:
          isLoadingImageSearchStatus ?? this.isLoadingImageSearchStatus,
      isTestingMetadataProviders:
          isTestingMetadataProviders ?? this.isTestingMetadataProviders,
      status: identical(status, _kSentinel)
          ? this.status
          : status as StatusDto?,
      imageSearchStatus: identical(imageSearchStatus, _kSentinel)
          ? this.imageSearchStatus
          : imageSearchStatus as StatusImageSearchDto?,
      javdbHealthy: identical(javdbHealthy, _kSentinel)
          ? this.javdbHealthy
          : javdbHealthy as bool?,
      statusError: identical(statusError, _kSentinel)
          ? this.statusError
          : statusError as String?,
    );
  }
}

const Object _kSentinel = Object();
