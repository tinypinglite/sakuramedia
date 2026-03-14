import 'package:sakuramedia/core/network/api_exception.dart';

String apiErrorMessage(Object error, {required String fallback}) {
  if (error is ApiException) {
    return error.error?.message ?? error.message;
  }
  return fallback;
}
