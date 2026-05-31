import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_draft_store.dart';

void main() {
  group('ImageSearchDraftStore', () {
    test('save 返回非空 id 且能被 get 取回原始数据', () {
      final store = ImageSearchDraftStore();
      final bytes = Uint8List.fromList(const [1, 2, 3, 4]);

      final id = store.save(
        fileName: 'cover.jpg',
        bytes: bytes,
        mimeType: 'image/jpeg',
      );

      expect(id, isNotEmpty);

      final draft = store.get(id);
      expect(draft, isNotNull);
      expect(draft!.fileName, 'cover.jpg');
      expect(draft.mimeType, 'image/jpeg');
      expect(draft.bytes, bytes);
    });

    test('id 末尾 nonce 恒为 8 位合法 hex', () {
      final store = ImageSearchDraftStore();

      for (var i = 0; i < 200; i++) {
        final id = store.save(
          fileName: 'f$i.jpg',
          bytes: Uint8List.fromList([i & 0xff]),
        );
        final nonce = id.substring(id.length - 8);
        expect(nonce.length, 8);
        // 不抛 FormatException 即为合法 hex。
        expect(() => int.parse(nonce, radix: 16), returnsNormally);
      }
    });

    test('多次 save 生成互不相同的 id', () {
      final store = ImageSearchDraftStore();
      final ids = <String>{};

      for (var i = 0; i < 500; i++) {
        ids.add(
          store.save(fileName: 'f$i.jpg', bytes: Uint8List.fromList([i & 0xff])),
        );
      }

      expect(ids.length, 500);
    });

    test('超过 maxEntries 后淘汰最早的草稿', () {
      final store = ImageSearchDraftStore(maxEntries: 2);

      final first = store.save(fileName: 'a.jpg', bytes: Uint8List(1));
      final second = store.save(fileName: 'b.jpg', bytes: Uint8List(1));
      final third = store.save(fileName: 'c.jpg', bytes: Uint8List(1));

      expect(store.get(first), isNull);
      expect(store.get(second), isNotNull);
      expect(store.get(third), isNotNull);
    });

    test('get 对空或未知 id 返回 null', () {
      final store = ImageSearchDraftStore();

      expect(store.get(null), isNull);
      expect(store.get(''), isNull);
      expect(store.get('not-exist'), isNull);
    });
  });
}
