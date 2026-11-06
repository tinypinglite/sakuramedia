import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('non-theme library files avoid direct visual literals', () {
    final files =
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => _isGuardedLibraryFile(file.path))
            .toList()
          ..sort((left, right) => left.path.compareTo(right.path));

    final directColor = RegExp(r'(?:const\s+)?\bColor\(');
    final directMaterialColor = RegExp(
      r'(?:^|[^A-Za-z])Colors\.(?!transparent\b)',
    );
    final directFontSize = RegExp(r'fontSize:\s*\d');
    final directInsets = RegExp(
      r'EdgeInsets\.(?:all|only|symmetric|fromLTRB)\([^)]*(?:[:(,]\s*[1-9]\d*(?:\.\d+)?)',
    );
    final directRadius = RegExp(r'(?:BorderRadius|Radius)\.circular\(\d');
    final directTextTheme = RegExp(r'(?:^|[^\w])textTheme(?:\b|\.)');

    final violations = <String>[];
    for (final file in files) {
      final source = file.readAsStringSync();
      for (final (name, pattern) in <(String, RegExp)>[
        ('Color()', directColor),
        ('Colors.*', directMaterialColor),
        ('fontSize', directFontSize),
        ('EdgeInsets literal', directInsets),
        ('circular radius literal', directRadius),
        ('textTheme access', directTextTheme),
      ]) {
        if (name == 'Colors.*' && _isImmersiveMediaFile(file.path)) {
          continue;
        }
        final match = pattern.firstMatch(source);
        if (match != null) {
          violations.add('${file.path}: disallowed $name literal');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

/// 沉浸式媒体界面（播放器、全屏看图、封面遮罩）在设计上明暗模式共用同一套
/// 黑白，允许保留 `Colors.black/white`；除此之外的业务代码必须走主题 token。
bool _isImmersiveMediaFile(String path) {
  final normalizedPath = path.replaceAll('\\', '/');
  const allowedPrefixes = <String>[
    'lib/widgets/base/media/',
    'lib/widgets/domain/media/',
    'lib/widgets/domain/collections/',
    'lib/widgets/domain/movies/player/',
  ];
  const allowedFiles = <String>{
    'lib/widgets/base/interaction/app_cover_hover_info.dart',
    'lib/widgets/base/interaction/selection/selection_check_badge.dart',
    'lib/features/clip_collections/presentation/pages/shared/clip_collection_play_content.dart',
    'lib/features/clips/presentation/pages/mobile/clip_player_page.dart',
    'lib/features/image_search/presentation/widgets/image_search_result_card.dart',
    'lib/features/movies/presentation/pages/shared/movie_merged_play_content.dart',
    'lib/features/movies/presentation/pages/shared/movie_player_content.dart',
    'lib/features/movies/presentation/widgets/detail/movie_detail_hero_card.dart',
    'lib/features/movies/presentation/widgets/detail/movie_media_point_gallery.dart',
    'lib/features/videos/presentation/pages/shared/video_collection_play_content.dart',
    'lib/features/videos/presentation/pages/shared/video_player_content.dart',
  };
  if (allowedFiles.contains(normalizedPath)) {
    return true;
  }
  return allowedPrefixes.any(normalizedPath.startsWith);
}

bool _isGuardedLibraryFile(String path) {
  final normalizedPath = path.replaceAll('\\', '/');
  return normalizedPath.endsWith('.dart') &&
      !normalizedPath.startsWith('lib/theme/') &&
      normalizedPath != 'lib/theme.dart';
}
