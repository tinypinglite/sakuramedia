import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_hint_box.dart';

import '../../../support/pump_with_providers.dart';

void main() {
  testWidgets('合集错误提示提供重试回调', (tester) async {
    var retries = 0;
    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: CollectionHintBox.error(
          message: '合集加载失败',
          retryKey: const Key('collection-hint-retry'),
          onRetry: () => retries++,
        ),
      ),
      physicalSize: const Size(390, 300),
    );

    await tester.tap(find.byKey(const Key('collection-hint-retry')));

    expect(retries, 1);
  });
}
