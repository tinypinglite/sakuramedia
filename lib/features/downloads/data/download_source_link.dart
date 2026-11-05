/// 手动或评论文本中可提交的下载来源。
enum DownloadSourceKind {
  magnet,
  ed2k,
  http,
  torrent;

  String get apiValue => name;
}

class DownloadSourceLink {
  const DownloadSourceLink({required this.kind, required this.uri});

  final DownloadSourceKind kind;
  final String uri;
}

/// 从评论或任意文本中提取 magnet 和 eD2k 文件链接；HTTP 不参与自动识别。
List<DownloadSourceLink> extractDownloadLinks(String text) {
  if (text.isEmpty) return const <DownloadSourceLink>[];

  final normalized = _decodeHtmlEntities(text);
  final matches =
      <({int start, String resourceKey, DownloadSourceLink link})>[];

  for (final match in _magnetPattern.allMatches(normalized)) {
    if (_isPartOfLongerWord(normalized, match.start)) continue;
    final candidate = _trimTrailingPunctuation(match.group(0)!);
    final btih = _btihPattern.firstMatch(candidate);
    if (btih == null) continue;

    final infoHash = btih.group(1)!.toUpperCase();
    final hashEnd = btih.end;
    var uriEnd = candidate.length;
    if (hashEnd < candidate.length) {
      final next = candidate[hashEnd];
      if (_isAsciiAlphanumeric(next)) continue;
      if (!_isUriContinuation(next)) uriEnd = hashEnd;
    }

    final uri = _trimTrailingPunctuation(candidate.substring(0, uriEnd));
    matches.add((
      start: match.start,
      resourceKey: 'bt:$infoHash',
      link: DownloadSourceLink(kind: DownloadSourceKind.magnet, uri: uri),
    ));
  }

  for (final match in _ed2kFilePattern.allMatches(normalized)) {
    if (_isPartOfLongerWord(normalized, match.start)) continue;
    matches.add((
      start: match.start,
      resourceKey: 'ed2k:${match.group(3)!.toUpperCase()}:${match.group(2)!}',
      link: DownloadSourceLink(
        kind: DownloadSourceKind.ed2k,
        uri: match.group(0)!,
      ),
    ));
  }

  matches.sort((left, right) => left.start.compareTo(right.start));
  final links = <DownloadSourceLink>[];
  final seenKeys = <String>{};
  for (final match in matches) {
    if (!seenKeys.add(match.resourceKey)) continue;
    links.add(match.link);
  }
  return links;
}

/// 自动识别并校验一条可提交的下载链接。
///
/// 返回 null 同时覆盖「无法识别协议」和「协议可识别但格式不合法」，调用方
/// 只把它当作「当前输入不可提交」。
DownloadSourceLink? parseDetectedDownloadSourceLink(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;
  final lower = text.toLowerCase();

  if (lower.startsWith('magnet:')) {
    final btih = _btihPattern.firstMatch(text);
    if (btih == null) return null;
    return DownloadSourceLink(kind: DownloadSourceKind.magnet, uri: text);
  }

  if (lower.startsWith('ed2k:')) {
    final match = _ed2kFilePattern.firstMatch(text);
    if (match == null || match.start != 0 || match.end != text.length) {
      return null;
    }
    return DownloadSourceLink(kind: DownloadSourceKind.ed2k, uri: text);
  }

  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    final parsed = Uri.tryParse(text);
    if (parsed == null ||
        !const <String>{
          'http',
          'https',
        }.contains(parsed.scheme.toLowerCase()) ||
        parsed.host.isEmpty ||
        parsed.userInfo.isNotEmpty) {
      return null;
    }
    return DownloadSourceLink(kind: DownloadSourceKind.http, uri: text);
  }

  return null;
}

final RegExp _magnetPattern = RegExp(
  "magnet:\\?[^\\s<>\"'`]+",
  caseSensitive: false,
);

final RegExp _btihPattern = RegExp(
  r'[?&]xt=urn:btih:([0-9a-fA-F]{40}|[A-Za-z2-7]{32})',
  caseSensitive: false,
);

final RegExp _ed2kFilePattern = RegExp(
  r'ed2k://\|file\|([^|\r\n]*)\|(\d+)\|([0-9a-fA-F]{32})'
  r'(?:\|(?:p=[0-9a-fA-F:]+|h=[A-Za-z0-9]+|s=[^|\s]+|sources,[^|\s]+))*\|/',
  caseSensitive: false,
);

bool _isUriContinuation(String char) => char == '&' || char == '?';

bool _isPartOfLongerWord(String text, int start) {
  if (start == 0) return false;
  return _isAsciiAlphanumericCode(text.codeUnitAt(start - 1));
}

bool _isAsciiAlphanumeric(String char) {
  if (char.isEmpty) return false;
  return _isAsciiAlphanumericCode(char.codeUnitAt(0));
}

bool _isAsciiAlphanumericCode(int code) {
  return (code >= 0x30 && code <= 0x39) ||
      (code >= 0x41 && code <= 0x5a) ||
      (code >= 0x61 && code <= 0x7a);
}

String _decodeHtmlEntities(String text) {
  if (!text.contains('&')) return text;
  return text
      .replaceAll(RegExp(r'&amp;', caseSensitive: false), '&')
      .replaceAll(RegExp(r'&#0*38;'), '&')
      .replaceAll(RegExp(r'&#x0*26;', caseSensitive: false), '&');
}

const String _trailingPunctuation = '.,;:!?&)]}，。；：！？、）】》」』”’';

String _trimTrailingPunctuation(String value) {
  var end = value.length;
  while (end > 0 && _trailingPunctuation.contains(value[end - 1])) {
    end--;
  }
  return value.substring(0, end);
}
