import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/media/data/media_storage_descriptor.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';

/// 影片详情页当前展示的预览图（封面或占位）——迁移前是 controller 私有的
/// `_MovieDetailPreview`，现在跟随不可变 state 暴露给页面。
@immutable
class MovieDetailPreview {
  const MovieDetailPreview({required this.key, required this.url});

  const MovieDetailPreview.cover({required String url})
    : this(key: 'cover', url: url);

  const MovieDetailPreview.placeholder() : this(key: 'placeholder', url: null);

  final String key;
  final String? url;
}

/// 影片详情 provider 状态：迁移前对应 `MovieDetailController` 的 11 个字段
/// 合成一个不可变 State，`copyWith` 用哨兵区分「不改」与「显式置 null」。
@immutable
class MovieDetailState {
  const MovieDetailState({
    this.movie,
    this.isLoading = true,
    this.errorMessage,
    this.similarMovies = const <MovieListItemDto>[],
    this.storageDescriptors = const <int, MediaStorageDescriptor>{},
    this.isSimilarMoviesLoading = false,
    this.similarMoviesErrorMessage,
    this.selectedPreview = const MovieDetailPreview.placeholder(),
  });

  static const MovieDetailState initial = MovieDetailState();

  final MovieDetailDto? movie;
  final bool isLoading;
  final String? errorMessage;
  final List<MovieListItemDto> similarMovies;
  final Map<int, MediaStorageDescriptor> storageDescriptors;
  final bool isSimilarMoviesLoading;
  final String? similarMoviesErrorMessage;
  final MovieDetailPreview selectedPreview;

  String? get selectedPreviewUrl => selectedPreview.url;
  String get selectedPreviewKey => selectedPreview.key;

  MovieDetailState copyWith({
    Object? movie = _sentinel,
    bool? isLoading,
    Object? errorMessage = _sentinel,
    List<MovieListItemDto>? similarMovies,
    Map<int, MediaStorageDescriptor>? storageDescriptors,
    bool? isSimilarMoviesLoading,
    Object? similarMoviesErrorMessage = _sentinel,
    MovieDetailPreview? selectedPreview,
  }) {
    return MovieDetailState(
      movie: identical(movie, _sentinel) ? this.movie : movie as MovieDetailDto?,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      similarMovies: similarMovies ?? this.similarMovies,
      storageDescriptors: storageDescriptors ?? this.storageDescriptors,
      isSimilarMoviesLoading:
          isSimilarMoviesLoading ?? this.isSimilarMoviesLoading,
      similarMoviesErrorMessage: identical(similarMoviesErrorMessage, _sentinel)
          ? this.similarMoviesErrorMessage
          : similarMoviesErrorMessage as String?,
      selectedPreview: selectedPreview ?? this.selectedPreview,
    );
  }
}

const Object _sentinel = Object();
