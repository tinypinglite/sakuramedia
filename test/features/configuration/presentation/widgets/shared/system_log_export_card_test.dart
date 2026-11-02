import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/system_log_export_card.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;
  late FilePickerPlatform originalPicker;
  late _RecordingSaveFilePicker picker;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'mobile-access-token',
      refreshToken: 'mobile-refresh-token',
      expiresAt: DateTime.parse('2026-09-02T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
    originalPicker = FilePickerPlatform.instance;
    picker = _RecordingSaveFilePicker();
    FilePickerPlatform.instance = picker;
  });

  tearDown(() {
    FilePickerPlatform.instance = originalPicker;
    bundle.dispose();
    sessionStore.dispose();
  });

  testWidgets('exports the default 24-hour redacted archive', (tester) async {
    bundle.adapter.enqueueBytes(
      method: 'GET',
      path: '/system/logs/archive',
      body: Uint8List.fromList(const <int>[80, 75, 3, 4]),
    );
    await _pumpCard(tester, bundle, isMobile: true);

    expect(find.text('最近 24 小时'), findsOneWidget);
    expect(find.textContaining('屏蔽常见密码、Token、Cookie'), findsOneWidget);

    await tester.tap(find.byKey(const Key('system-logs-export-button')));
    await tester.pumpAndSettle();

    final request = bundle.adapter.requests.single;
    expect(request.uri.path, '/system/logs/archive');
    expect(request.uri.queryParameters, <String, String>{
      'range': '24h',
      'redact_sensitive': 'true',
    });
    expect(picker.bytes, Uint8List.fromList(const <int>[80, 75, 3, 4]));
    expect(picker.fileName, startsWith('sakuramedia-logs-24h-'));
    expect(picker.fileName, endsWith('.zip'));
    expect(picker.mimeType, 'application/zip');
    expect(find.text('日志已导出'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('cancelling the raw-log confirmation does not export', (
    tester,
  ) async {
    await _pumpCard(tester, bundle, isMobile: false);

    await tester.tap(find.byKey(const Key('system-logs-redact-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('system-logs-export-button')));
    await tester.pumpAndSettle();

    expect(find.text('导出未脱敏日志？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('system-logs-raw-cancel')));
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('GET', '/system/logs/archive'), 0);
    expect(picker.bytes, isNull);
  });

  testWidgets('exports the selected time range', (tester) async {
    bundle.adapter.enqueueBytes(
      method: 'GET',
      path: '/system/logs/archive',
      body: Uint8List.fromList(const <int>[4, 5, 6]),
    );
    await _pumpCard(tester, bundle, isMobile: true);

    await tester.tap(find.byKey(const Key('system-logs-range-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('最近 7 天'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('system-logs-export-button')));
    await tester.pumpAndSettle();

    expect(bundle.adapter.requests.single.uri.queryParameters, <String, String>{
      'range': '7d',
      'redact_sensitive': 'true',
    });
    expect(picker.fileName, startsWith('sakuramedia-logs-7d-'));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('confirmed raw export disables redaction', (tester) async {
    bundle.adapter.enqueueBytes(
      method: 'GET',
      path: '/system/logs/archive',
      body: Uint8List.fromList(const <int>[1, 2, 3]),
    );
    await _pumpCard(tester, bundle, isMobile: false);

    await tester.tap(find.byKey(const Key('system-logs-redact-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('system-logs-export-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('system-logs-raw-confirm')));
    await tester.pumpAndSettle();

    final request = bundle.adapter.requests.single;
    expect(request.uri.queryParameters, <String, String>{
      'range': '24h',
      'redact_sensitive': 'false',
    });
    expect(picker.bytes, Uint8List.fromList(const <int>[1, 2, 3]));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('cancelling the save dialog does not show a success toast', (
    tester,
  ) async {
    bundle.adapter.enqueueBytes(
      method: 'GET',
      path: '/system/logs/archive',
      body: Uint8List.fromList(const <int>[1, 2, 3]),
    );
    picker.result = null;
    await _pumpCard(tester, bundle, isMobile: false);

    await tester.tap(find.byKey(const Key('system-logs-export-button')));
    await tester.pumpAndSettle();

    expect(picker.bytes, Uint8List.fromList(const <int>[1, 2, 3]));
    expect(find.text('日志已导出'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('shows the server error when no logs match the range', (
    tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/logs/archive',
      statusCode: 404,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'log_entries_not_found',
          'message': '所选时间范围内没有可导出的日志',
          'details': null,
        },
      },
    );
    await _pumpCard(tester, bundle, isMobile: true);

    await tester.tap(find.byKey(const Key('system-logs-export-button')));
    await tester.pumpAndSettle();

    expect(find.text('所选时间范围内没有可导出的日志'), findsOneWidget);
    expect(picker.bytes, isNull);
    await tester.pump(const Duration(seconds: 3));
  });
}

Future<void> _pumpCard(
  WidgetTester tester,
  TestApiBundle bundle, {
  required bool isMobile,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = isMobile
      ? const Size(360, 760)
      : const Size(1100, 760);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: bundle.riverpodOverrides(),
      child: OKToast(
        child: MaterialApp(
          theme: isMobile ? sakuraMobileThemeData : sakuraDesktopThemeData,
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          home: AppPlatformScope(
            platform: isMobile ? AppPlatform.mobile : AppPlatform.desktop,
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: SystemLogExportCard(isMobile: isMobile),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _RecordingSaveFilePicker extends FilePickerPlatform {
  Uint8List? bytes;
  String? fileName;
  String? mimeType;
  String? dialogTitle;
  Uri? result = Uri.file('/tmp/logs.zip');

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    this.bytes = bytes;
    this.fileName = fileName;
    this.mimeType = mimeType;
    this.dialogTitle = dialogTitle;
    return result;
  }
}
