import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/shared/data/batch_operation_dto.dart';
import 'package:sakuramedia/features/shared/presentation/batch_operation_submit.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-12-31T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  Future<void> pumpSubmitTrigger(
    WidgetTester tester, {
    required List<int> ids,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          builder: (context, child) =>
              OKToast(child: child ?? const SizedBox.shrink()),
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => submitBatchOperation(
                  context,
                  ref,
                  operation: BatchOperationType.mediaDelete,
                  ids: ids,
                ),
                child: const Text('submit'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('超过 ids 上限时本地拦截且不发出请求', (tester) async {
    await pumpSubmitTrigger(
      tester,
      ids: List<int>.generate(maxBatchOperationItems + 1, (index) => index + 1),
    );

    await tester.tap(find.text('submit'));
    await tester.pumpAndSettle();

    expect(
      bundle.adapter.requests.where((r) => r.path == '/batch-operations'),
      isEmpty,
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('恰好达到 ids 上限时正常提交', (tester) async {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/batch-operations',
      statusCode: 202,
      body: <String, dynamic>{
        'task_run_id': 7,
        'task_key': 'batch_operation',
        'state': 'pending',
      },
    );
    await pumpSubmitTrigger(
      tester,
      ids: List<int>.generate(maxBatchOperationItems, (index) => index + 1),
    );

    await tester.tap(find.text('submit'));
    await tester.pumpAndSettle();

    final submit = bundle.adapter.requests
        .where((r) => r.path == '/batch-operations')
        .toList();
    expect(submit, hasLength(1));
    expect(
      (submit.single.body! as Map<String, dynamic>)['ids'],
      hasLength(1000),
    );
    await tester.pump(const Duration(seconds: 3));
  });
}
