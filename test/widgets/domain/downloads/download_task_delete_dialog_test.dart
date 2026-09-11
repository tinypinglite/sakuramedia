import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/downloads/data/download_request_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/downloads/download_task_delete_dialog.dart';

void main() {
  for (final importStatus in ['failed', 'skipped']) {
    testWidgets('shows blacklist warning for $importStatus tasks', (
      tester,
    ) async {
      late Future<bool> dialogResult;
      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraDesktopThemeData,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  dialogResult = showDownloadTaskDeleteDialog(
                    context,
                    tasks: [_task(importStatus)],
                    onDelete: (_, __) async {},
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
      expect(await dialogResult, isFalse);
    });
  }

  testWidgets('hides blacklist warning for completed tasks', (tester) async {
    late Future<bool> dialogResult;
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraDesktopThemeData,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                dialogResult = showDownloadTaskDeleteDialog(
                  context,
                  tasks: [_task('completed')],
                  onDelete: (_, __) async {},
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
    expect(await dialogResult, isFalse);
  });
}

DownloadTaskDto _task(String importStatus) => DownloadTaskDto(
  id: 1,
  clientId: 1,
  movieNumber: 'TEST-001',
  name: 'TEST-001',
  remoteId: 'remote-1',
  state: 'completed',
  progress: 1,
  importStatus: importStatus,
  importStatusLabel: importStatus,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
