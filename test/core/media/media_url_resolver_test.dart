import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';

void main() {
  test('returns null when raw url is null or empty', () {
    expect(
      resolveMediaUrl(rawUrl: null, baseUrl: 'https://api.example.com'),
      isNull,
    );
    expect(
      resolveMediaUrl(rawUrl: '', baseUrl: 'https://api.example.com'),
      isNull,
    );
    expect(
      resolveMediaUrl(rawUrl: '   ', baseUrl: 'https://api.example.com'),
      isNull,
    );
  });

  test('keeps absolute urls unchanged', () {
    expect(
      resolveMediaUrl(
        rawUrl: 'https://img.example.com/a.jpg',
        baseUrl: 'https://api.example.com',
      ),
      'https://img.example.com/a.jpg',
    );
  });

  test('joins base url and relative path without duplicate slashes', () {
    expect(
      resolveMediaUrl(
        rawUrl: '/covers/a.jpg',
        baseUrl: 'https://api.example.com',
      ),
      'https://api.example.com/covers/a.jpg',
    );
    expect(
      resolveMediaUrl(
        rawUrl: 'covers/a.jpg',
        baseUrl: 'https://api.example.com/',
      ),
      'https://api.example.com/covers/a.jpg',
    );
    expect(
      resolveMediaUrl(
        rawUrl: '/covers/a.jpg',
        baseUrl: 'https://api.example.com/',
      ),
      'https://api.example.com/covers/a.jpg',
    );
  });

  test('returns null for relative urls when base url is empty', () {
    expect(resolveMediaUrl(rawUrl: '/covers/a.jpg', baseUrl: ''), isNull);
    expect(resolveMediaUrl(rawUrl: 'covers/a.jpg', baseUrl: '  '), isNull);
  });
}
