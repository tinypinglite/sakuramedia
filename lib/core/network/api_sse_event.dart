import 'dart:convert';

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
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map(
          (dynamic key, dynamic value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {
      // Fall through to the typed error below.
    }

    throw const ApiException(
      message: 'Invalid SSE JSON payload received from server',
    );
  }
}
