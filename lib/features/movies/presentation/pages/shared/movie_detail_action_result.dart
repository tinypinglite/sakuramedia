import 'package:flutter/foundation.dart';

enum MovieDetailActionResultStatus { success, warning, error, ignored }

@immutable
class MovieDetailActionResult {
  const MovieDetailActionResult({required this.status, this.message});

  const MovieDetailActionResult.success([this.message])
    : status = MovieDetailActionResultStatus.success;

  const MovieDetailActionResult.warning(this.message)
    : status = MovieDetailActionResultStatus.warning;

  const MovieDetailActionResult.error(this.message)
    : status = MovieDetailActionResultStatus.error;

  const MovieDetailActionResult.ignored()
    : status = MovieDetailActionResultStatus.ignored,
      message = null;

  final MovieDetailActionResultStatus status;
  final String? message;

  bool get succeeded => status == MovieDetailActionResultStatus.success;
}
