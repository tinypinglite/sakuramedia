import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:sakuramedia/core/network/api_sse_event.dart';

class SseDecoder extends StreamTransformerBase<Uint8List, ApiSseEvent> {
  const SseDecoder();

  @override
  Stream<ApiSseEvent> bind(Stream<Uint8List> stream) async* {
    final textStream = utf8.decoder.bind(stream);
    var buffer = '';

    await for (final chunk in textStream) {
      buffer += chunk.replaceAll('\r\n', '\n');
      while (true) {
        final boundary = buffer.indexOf('\n\n');
        if (boundary == -1) {
          break;
        }

        final rawEvent = buffer.substring(0, boundary);
        buffer = buffer.substring(boundary + 2);

        final event = _parseEvent(rawEvent);
        if (event != null) {
          yield event;
        }
      }
    }

    final trailingEvent = _parseEvent(buffer);
    if (trailingEvent != null) {
      yield trailingEvent;
    }
  }

  ApiSseEvent? _parseEvent(String rawEvent) {
    final trimmed = rawEvent.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    var event = 'message';
    final dataLines = <String>[];

    for (final line in trimmed.split('\n')) {
      if (line.isEmpty || line.startsWith(':')) {
        continue;
      }
      if (line.startsWith('event:')) {
        event = line.substring(6).trim();
        continue;
      }
      if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      }
    }

    if (event.isEmpty && dataLines.isEmpty) {
      return null;
    }

    return ApiSseEvent(event: event, data: dataLines.join('\n'));
  }
}
