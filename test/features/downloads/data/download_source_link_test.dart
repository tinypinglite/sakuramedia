import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/downloads/data/download_source_link.dart';

List<DownloadSourceLink> _extractMagnets(String text) =>
    extractDownloadLinks(text)
        .where((link) => link.kind == DownloadSourceKind.magnet)
        .toList(growable: false);

void main() {
  const hash = '0123456789abcdef0123456789abcdef01234567';

  test('extracts a magnet link and decodes HTML entities', () {
    final links = _extractMagnets(
      '这个可以看 magnet:?xt=urn:btih:$hash&amp;dn=movie 谢谢',
    );

    expect(links, hasLength(1));
    expect(links.single.uri, 'magnet:?xt=urn:btih:$hash&dn=movie');
  });

  test('trims trailing punctuation and text glued to the hash', () {
    final links = _extractMagnets(
      'magnet:?xt=urn:btih:$hash，下载看看。'
      '另一个 magnet:?xt=urn:btih:$hash试试',
    );

    expect(links, hasLength(1));
    expect(links.single.uri, 'magnet:?xt=urn:btih:$hash');
  });

  test('trims a dangling query separator', () {
    final links = _extractMagnets('magnet:?xt=urn:btih:$hash&');

    expect(links, hasLength(1));
    expect(links.single.uri, 'magnet:?xt=urn:btih:$hash');
  });

  test('deduplicates by BTIH and keeps the first URI', () {
    final links = _extractMagnets(
      'magnet:?xt=urn:btih:$hash&tr=udp://a\n'
      'magnet:?xt=urn:btih:${hash.toUpperCase()}&tr=udp://b',
    );

    expect(links, hasLength(1));
    expect(links.single.uri, 'magnet:?xt=urn:btih:$hash&tr=udp://a');
  });

  test('accepts base32 BTIH and uppercase scheme', () {
    const base32 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final links = _extractMagnets('MAGNET:?XT=URN:BTIH:$base32');

    expect(links, hasLength(1));
    expect(links.single.uri, 'MAGNET:?XT=URN:BTIH:$base32');
  });

  test('ignores incomplete or embedded magnet fragments', () {
    final links = _extractMagnets(
      'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef0123456\n'
      'xmagnet:?xt=urn:btih:$hash\n'
      'magnet:?dn=no-hash',
    );

    expect(links, isEmpty);
  });

  test('ignores a hash longer than a valid BTIH', () {
    final links = _extractMagnets('magnet:?xt=urn:btih:${hash}abcdef');

    expect(links, isEmpty);
  });

  test('extracts eD2k file links and ignores HTTP links', () {
    const ed2k =
        'ed2k://|file|movie.mp4|12345|0123456789abcdef0123456789abcdef|/';
    final links = extractDownloadLinks(
      '资源 $ed2k 另一个 https://example.com/movie.mp4 自取',
    );

    expect(links, hasLength(1));
    expect(links.single.kind, DownloadSourceKind.ed2k);
    expect(links.single.uri, ed2k);
  });

  test('deduplicates eD2k links by hash and size', () {
    const first = 'ed2k://|file|a.mp4|12345|0123456789abcdef0123456789abcdef|/';
    const second =
        'ed2k://|file|b.mp4|12345|0123456789abcdef0123456789abcdef|/';

    final links = extractDownloadLinks('$first $second');

    expect(links, hasLength(1));
    expect(links.single.uri, first);
  });

  test('rejects incomplete eD2k and server links in manual parsing', () {
    expect(
      parseDetectedDownloadSourceLink(
        'ed2k://|file|movie.mp4|12345|0123456789abcdef0123456789abcdef|/',
      )?.kind,
      DownloadSourceKind.ed2k,
    );
    expect(
      parseDetectedDownloadSourceLink('ed2k://|file|movie.mp4|12345|bad|/'),
      isNull,
    );
    expect(
      parseDetectedDownloadSourceLink('ed2k://|server|1.2.3.4|4662|/'),
      isNull,
    );
  });

  test('accepts eD2k optional part and AICH fields', () {
    const link =
        'ed2k://|file|movie.mp4|12345|'
        '0123456789abcdef0123456789abcdef|'
        'p=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|'
        'h=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB|/';

    expect(parseDetectedDownloadSourceLink(link)?.uri, link);
  });

  test('accepts HTTP direct links and rejects credentials', () {
    expect(
      parseDetectedDownloadSourceLink(
        'https://cdn.example/movie.mp4?token=secret',
      )?.kind,
      DownloadSourceKind.http,
    );
    expect(
      parseDetectedDownloadSourceLink('https://user@example.com/movie.mp4'),
      isNull,
    );
  });

  test('detects and parses supported download link kinds', () {
    const hash = '0123456789abcdef0123456789abcdef01234567';
    const ed2k =
        'ed2k://|file|movie.mp4|12345|0123456789abcdef0123456789abcdef|/';

    expect(
      parseDetectedDownloadSourceLink(
        'MAGNET:?xt=urn:btih:$hash&dn=movie',
      )?.kind,
      DownloadSourceKind.magnet,
    );
    expect(
      parseDetectedDownloadSourceLink(ed2k)?.kind,
      DownloadSourceKind.ed2k,
    );
    expect(
      parseDetectedDownloadSourceLink(
        'https://cdn.example/movie.mp4?token=secret',
      )?.kind,
      DownloadSourceKind.http,
    );
    expect(
      parseDetectedDownloadSourceLink('HTTP://cdn.example/movie.mp4')?.kind,
      DownloadSourceKind.http,
    );
  });

  test('returns null for unsupported or malformed download links', () {
    expect(
      parseDetectedDownloadSourceLink('ftp://example.com/movie.mp4'),
      isNull,
    );
    expect(parseDetectedDownloadSourceLink('not a link'), isNull);
    expect(parseDetectedDownloadSourceLink('   '), isNull);
    expect(parseDetectedDownloadSourceLink('magnet:?dn=missing-hash'), isNull);
    expect(
      parseDetectedDownloadSourceLink(
        'ed2k://|file|movie.mp4|bad|0123456789abcdef0123456789abcdef|/',
      ),
      isNull,
    );
    expect(
      parseDetectedDownloadSourceLink('https://user@example.com/movie.mp4'),
      isNull,
    );
  });
}
