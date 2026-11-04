import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/media_import/data/import_failure_reason_descriptions.dart';
import 'package:sakuramedia/l10n/app_localizations_en.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';

void main() {
  test('playback structure failure reasons have localized labels', () {
    final zh = AppLocalizationsZh();
    final en = AppLocalizationsEn();
    final cases = <String, (String, String)>{
      'media_playback_file_missing': (
        '文件已丢失，未导入',
        'File is missing; not imported',
      ),
      'media_playback_container_invalid': (
        '容器结构损坏，未导入',
        'Container structure is damaged; not imported',
      ),
      'media_playback_moov_missing': (
        '缺少 moov，无法导入',
        'moov is missing; cannot import',
      ),
      'media_playback_video_stream_missing': (
        '缺少视频流，未导入',
        'Video stream is missing; not imported',
      ),
      'media_playback_interleave_bad': (
        '音视频交错异常，未导入',
        'Audio/video interleaving is abnormal; not imported',
      ),
      'media_playback_invalid': (
        '播放结构异常，未导入',
        'Playback structure is invalid; not imported',
      ),
    };

    for (final entry in cases.entries) {
      final (zhLabel, enLabel) = entry.value;
      expect(describeImportFailureReason(entry.key, zh), zhLabel);
      expect(describeImportFailureReason(entry.key, en), enLabel);
    }
  });
}
