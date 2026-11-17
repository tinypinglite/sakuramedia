import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';
import 'package:sakuramedia/l10n/app_localizations_en.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';

void main() {
  MomentListItem buildMoment({
    int mediaId = 5,
    int? videoItemId,
    String? movieNumber = 'ABC-001',
  }) {
    return MomentListItem(
      pointId: 10,
      mediaId: mediaId,
      movieNumber: movieNumber,
      videoItemId: videoItemId,
      thumbnailId: 1,
      offsetSeconds: 90,
      image: null,
    );
  }

  test('display label follows the given locale', () {
    final zh = AppLocalizationsZh();
    expect(buildMoment(movieNumber: null).localizedDisplayLabel(zh), '时刻 #10');
    expect(
      buildMoment(videoItemId: 7, movieNumber: null).localizedDisplayLabel(zh),
      '视频 #7',
    );
    // 番号存在时直接显示番号，不走本地化。
    expect(buildMoment().localizedDisplayLabel(zh), 'ABC-001');
  });

  test('display label follows the English locale', () {
    final en = AppLocalizationsEn();
    expect(buildMoment(movieNumber: null).localizedDisplayLabel(en), 'Moment #10');
    expect(
      buildMoment(videoItemId: 7, movieNumber: null).localizedDisplayLabel(en),
      'Video #7',
    );
  });

  test('hover meta follows the given locale', () {
    final zh = AppLocalizationsZh();
    expect(
      buildMoment(mediaId: 0).localizedHoverMeta(zh),
      contains('来源已删除'),
    );
    expect(buildMoment().localizedHoverMeta(zh), startsWith('JAV · '));
  });

  test('hover meta follows the English locale', () {
    final en = AppLocalizationsEn();
    expect(buildMoment(mediaId: 0).localizedHoverMeta(en), contains('Source deleted'));
    expect(buildMoment(videoItemId: 7).localizedHoverMeta(en), startsWith('Video · '));
  });
}
