import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';

void main() {
  test('layout tokens 暴露共享断点与搜索框宽度', () {
    const tokens = AppLayoutTokens.defaults();

    expect(tokens.breakpointMinContent, 320);
    expect(tokens.breakpointCardCompact, 340);
    expect(tokens.breakpointCompact, 420);
    expect(tokens.breakpointMedium, 520);
    expect(tokens.breakpointWide, 640);
    expect(tokens.breakpointDesktop, 980);
    expect(tokens.searchFieldWidth, 360);
  });

  test('copyWith 与 lerp 保留新增 token', () {
    const tokens = AppLayoutTokens.defaults();
    final updated = tokens.copyWith(
      breakpointCompact: 444,
      searchFieldWidth: 400,
    );

    expect(updated.breakpointCompact, 444);
    expect(updated.searchFieldWidth, 400);

    final lerped = tokens.lerp(updated, 0.5);
    expect(lerped.breakpointCompact, 432);
    expect(lerped.searchFieldWidth, 380);
  });

  test('主题默认接入 layout tokens', () {
    final theme = buildSakuraDesktopThemeData();

    expect(theme.appLayoutTokens.searchFieldWidth, 360);
  });
}
