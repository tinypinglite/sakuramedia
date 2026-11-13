import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/media/bounded_range_cache_store.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'bounded_range_cache_test',
    );
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test(
    'evicts old chunks from one long media so per-entry cap holds',
    () async {
      final store = BoundedRangeCacheStore(
        directory: directory,
        maxBytes: 32,
        maxEntryBytes: 12,
        chunkSize: 4,
      );
      await store.init();

      for (var index = 0; index < 5; index++) {
        await store.putChunk('movie', index, _chunk(index, 4));
      }

      expect(store.usage().usedBytes, lessThanOrEqualTo(12));
      expect(store.hasChunk('movie', 0), isFalse);
      expect(store.hasChunk('movie', 4), isTrue);
      expect(store.hasChunk('movie', 3), isTrue);
    },
  );

  test('evicts whole inactive media to keep global cap', () async {
    final store = BoundedRangeCacheStore(
      directory: directory,
      maxBytes: 16,
      maxEntryBytes: 12,
      chunkSize: 4,
    );
    await store.init();

    await store.putChunk('first', 0, _chunk(0, 4));
    await store.putChunk('first', 1, _chunk(1, 4));
    await store.putChunk('first', 2, _chunk(2, 4));
    await store.putChunk('second', 0, _chunk(3, 4));
    await store.putChunk('second', 1, _chunk(4, 4));

    expect(store.usage().usedBytes, lessThanOrEqualTo(16));
    expect(store.usage().entryCount, 1);
    expect(store.hasChunk('second', 0), isTrue);
    expect(store.hasChunk('second', 1), isTrue);
  });

  test(
    'reloads metadata and trims entries to the new cap on startup',
    () async {
      final first = BoundedRangeCacheStore(
        directory: directory,
        maxBytes: 16,
        maxEntryBytes: 8,
        chunkSize: 4,
      );
      await first.init();
      await first.setTotalLength('first', 100);
      for (var index = 0; index < 3; index++) {
        await first.putChunk('first', index, _chunk(index, 4));
      }
      await first.putChunk('second', 0, _chunk(4, 4));

      final second = BoundedRangeCacheStore(
        directory: directory,
        maxBytes: 8,
        maxEntryBytes: 4,
        chunkSize: 4,
      );
      await second.init();

      expect(second.usage().usedBytes, lessThanOrEqualTo(8));
      expect(second.usage().entryCount, lessThanOrEqualTo(2));
      expect(second.totalLength('first'), 100);
    },
  );

  test('clamps an undersized per-entry cap to one complete chunk', () async {
    final store = BoundedRangeCacheStore(
      directory: directory,
      maxBytes: 12,
      maxEntryBytes: 1,
      chunkSize: 4,
    );
    await store.init();

    await store.putChunk('movie', 0, _chunk(0, 4));
    await store.putChunk('movie', 1, _chunk(1, 4));

    expect(store.usage().usedBytes, 4);
    expect(store.hasChunk('movie', 0), isFalse);
    expect(store.hasChunk('movie', 1), isTrue);
  });
}

Uint8List _chunk(int seed, int length) =>
    Uint8List.fromList(List<int>.generate(length, (index) => seed + index));
