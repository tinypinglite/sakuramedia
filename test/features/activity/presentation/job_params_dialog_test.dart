import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/activity/data/job_metadata_dto.dart';
import 'package:sakuramedia/features/activity/presentation/job_params_dialog.dart';
import 'package:sakuramedia/theme.dart';

void main() {
  testWidgets('keeps parameter actions visible in a short mobile drawer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraMobileThemeData,
        home: AppPlatformScope(
          platform: AppPlatform.mobile,
          child: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () =>
                      showJobParamsDialog(context, job: _jobWithManyFields),
                  child: const Text('打开'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('activity-job-params-dialog')), findsOneWidget);
    expect(
      find.byKey(const Key('activity-job-params-submit-button')),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const Key('activity-job-params-form-scroll')),
      const Offset(0, -180),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('activity-job-params-submit-button')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

final _jobWithManyFields = JobMetadataDto(
  taskKey: 'bulk_job',
  logName: 'bulk_job',
  cliName: 'bulk-job',
  cliHelp: '批量任务参数',
  cronSetting: '',
  cronExpr: '',
  manualTriggerAllowed: true,
  lastTaskRun: null,
  paramsSchema: <String, dynamic>{
    'type': 'object',
    'properties': <String, dynamic>{
      for (var index = 0; index < 6; index++)
        'path_$index': <String, dynamic>{
          'type': 'string',
          'title': '路径 ${index + 1}',
        },
    },
  },
);
