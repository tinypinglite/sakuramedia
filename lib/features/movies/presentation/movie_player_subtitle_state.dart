class MoviePlayerSubtitleOption {
  const MoviePlayerSubtitleOption({
    required this.subtitleId,
    required this.label,
    required this.resolvedUrl,
    this.title,
    this.language,
  });

  final int subtitleId;
  final String label;
  final String resolvedUrl;
  final String? title;
  final String? language;
}

class MoviePlayerSubtitleState {
  const MoviePlayerSubtitleState({
    required this.options,
    required this.selectedSubtitleId,
    required this.isLoading,
    required this.fetchStatus,
    required this.errorMessage,
  });

  static const MoviePlayerSubtitleState empty = MoviePlayerSubtitleState(
    options: <MoviePlayerSubtitleOption>[],
    selectedSubtitleId: null,
    isLoading: false,
    fetchStatus: 'pending',
    errorMessage: null,
  );

  final List<MoviePlayerSubtitleOption> options;
  final int? selectedSubtitleId;
  final bool isLoading;
  final String fetchStatus;
  final String? errorMessage;
}
