import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/features/downloads/data/download_request_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/domain/downloads/download_task_delete_dialog.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

void main() {
  for (final importStatus in ['failed', 'skipped']) {
    testWidgets('shows blacklist warning for $importStatus tasks', (
      tester,
    ) async {
      late Future<bool?> dialogResult;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          theme: sakuraDesktopThemeData,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  dialogResult = showDownloadTaskDeleteDialog(
                    context,
                    tasks: [_task(importStatus, blacklistable: true)],
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('会加入资源黑名单'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(await dialogResult, isNull);
    });
  }

  testWidgets('hides blacklist warning for completed tasks', (tester) async {
    late Future<bool?> dialogResult;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
        theme: sakuraDesktopThemeData,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                dialogResult = showDownloadTaskDeleteDialog(
                  context,
                  tasks: [_task('completed')],
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('会加入资源黑名单'), findsNothing);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(await dialogResult, isNull);
  });

  testWidgets('hides blacklist warning for non-BT task sources', (
    tester,
  ) async {
    late Future<bool?> dialogResult;
    await tester.pumpWidget(
      _dialogHost((context) {
        return dialogResult = showDownloadTaskDeleteDialog(
          context,
          tasks: [_task('failed')],
        );
      }),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('会加入资源黑名单'), findsNothing);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(await dialogResult, isNull);
  });

  testWidgets('returns the captured delete-files option on confirm', (
    tester,
  ) async {
    late Future<bool?> dialogResult;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
        theme: sakuraDesktopThemeData,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                dialogResult = showDownloadTaskDeleteDialog(
                  context,
                  tasks: [_task('completed')],
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('download-task-delete-files-checkbox')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(await dialogResult, isTrue);
  });

  testWidgets(
    'waits for onConfirm before closing and passes delete-files option',
    (tester) async {
      final gate = Completer<void>();
      bool? confirmedDeleteFiles;
      late Future<bool?> dialogResult;
      await tester.pumpWidget(
        _dialogHost((context) {
          return dialogResult = showDownloadTaskDeleteDialog(
            context,
            tasks: [_task('completed')],
            onConfirm: (deleteFiles) async {
              confirmedDeleteFiles = deleteFiles;
              await gate.future;
            },
          );
        }),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('download-task-delete-files-checkbox')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      // loading spinner 持续排帧，不能 pumpAndSettle。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(confirmedDeleteFiles, isTrue);
      expect(
        find.byKey(const Key('download-task-delete-dialog')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<AppButton>(find.widgetWithText(AppButton, '删除'))
            .isLoading,
        isTrue,
      );
      expect(
        tester
            .widget<AppButton>(find.widgetWithText(AppButton, '取消'))
            .onPressed,
        isNull,
      );

      gate.complete();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('download-task-delete-dialog')),
        findsNothing,
      );
      expect(await dialogResult, isTrue);
    },
  );

  testWidgets('keeps dialog open and restores buttons when onConfirm fails', (
    tester,
  ) async {
    late Future<bool?> dialogResult;
    await tester.pumpWidget(
      _dialogHost((context) {
        return dialogResult = showDownloadTaskDeleteDialog(
          context,
          tasks: [_task('completed')],
          onConfirm: (_) async {
            throw StateError('boom');
          },
        );
      }),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const Key('download-task-delete-dialog')),
      findsOneWidget,
    );
    expect(find.text('删除失败'), findsOneWidget);
    expect(
      tester.widget<AppButton>(find.widgetWithText(AppButton, '删除')).isLoading,
      isFalse,
    );
    expect(
      tester.widget<AppButton>(find.widgetWithText(AppButton, '取消')).onPressed,
      isNotNull,
    );

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(await dialogResult, isNull);
    // 排掉 toast 的自动消失计时器。
    await tester.pump(const Duration(seconds: 3));
  });
}

Widget _dialogHost(Future<bool?> Function(BuildContext context) open) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
    theme: sakuraDesktopThemeData,
    home: OKToast(
      child: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => open(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

DownloadTaskDto _task(String importStatus, {bool blacklistable = false}) =>
    DownloadTaskDto(
      id: 1,
      clientId: 1,
      movieNumber: 'TEST-001',
      name: 'TEST-001',
      remoteId: 'remote-1',
      state: 'completed',
      progress: 1,
      importStatus: importStatus,
      importStatusLabel: importStatus,
      blacklistable: blacklistable,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
