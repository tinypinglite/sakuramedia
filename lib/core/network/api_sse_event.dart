import 'dart:convert';

import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/core/network/api_exception.dart';

class ApiSseEvent {
  const ApiSseEvent({this.id, required this.event, required this.data});

  final int? id;
  final String event;
  final String data;

  Map<String, dynamic> get jsonData {
    if (data.trim().isEmpty) {
      return const <String, dynamic>{};
    }

    try {
      final decoded = asMapOrNull(jsonDecode(data));
      if (decoded != null) {
        return decoded;
      }
    } catch (_) {
      // Fall through to the typed error below.
    }

    throw const ApiException(
      message: 'Invalid SSE JSON payload received from server',
    );
  }
}
