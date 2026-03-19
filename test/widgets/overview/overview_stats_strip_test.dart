import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('overview stats strip uses component tokens for tile sizing', () {
    final source =
        File(
          'lib/widgets/overview/overview_stats_strip.dart',
        ).readAsStringSync();

    expect(source, contains('context.appComponentTokens'));
    expect(source, isNot(contains('AppContentCard')));
    expect(
      source,
      isNot(contains('BoxConstraints(minWidth: 150, maxWidth: 190)')),
    );
    expect(source, isNot(contains('width: 64')));
    expect(source, isNot(contains('height: 10')));
    expect(source, isNot(contains('width: 96')));
    expect(source, isNot(contains('height: 22')));
    expect(source, contains('maxLines: 1'));
    expect(source, contains('softWrap: false'));
    expect(source, contains('TextOverflow.ellipsis'));
  });
}
