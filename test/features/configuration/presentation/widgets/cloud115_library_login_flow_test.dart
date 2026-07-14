import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/api/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/cloud115_library_login_flow.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../support/test_api_bundle.dart';

const _onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cloud115 login apps expose the complete backend whitelist', () {
    expect(
      Cloud115LoginApp.values.map((item) => item.wireValue),
      <String>[
        'web',
        'android',
        'ios',
        'linux',
        'mac',
        'windows',
        'tv',
        'alipaymini',
        'wechatmini',
        'qandroid',
      ],
    );
    expect(Cloud115LoginApp.alipaymini.isRecommended, isTrue);
    expect(Cloud115LoginAppX.fromWire('unknown'), Cloud115LoginApp.alipaymini);
  });

  testWidgets('requires risk acknowledgement and creates after confirmed', (
    tester,
  ) async {
    final bundle = await _buildBundle();
    addTearDown(bundle.dispose);
    _enqueueToken(bundle, uid: 'uid-create');
    _enqueueStatus(bundle, 'waiting');
    _enqueueStatus(bundle, 'scanned');
    _enqueueStatus(bundle, 'confirmed');
    _enqueueCloudLibrary(bundle, app: 'alipaymini', name: '115 主账号');

    await _pumpHarness(tester, bundle, platform: AppPlatform.desktop);
    await tester.tap(find.byKey(const Key('launch-cloud115-flow')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('cloud115-library-name-field')),
      '115 主账号',
    );

    await tester.tap(
      find.byKey(const Key('cloud115-login-continue-button')),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('cloud115-login-risk-error')),
      findsOneWidget,
    );
    expect(
      bundle.adapter.hitCount(
        'POST',
        '/media-libraries/cloud115/qrlogin/token',
      ),
      0,
    );

    await tester.tap(
      find.byKey(const Key('cloud115-login-risk-checkbox')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('cloud115-login-continue-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('result:115 主账号:alipaymini'), findsOneWidget);
    final createRequest = bundle.adapter.requests.firstWhere(
      (request) =>
          request.method == 'POST' &&
          request.path == '/media-libraries/cloud115',
    );
    expect(createRequest.body, {
      'name': '115 主账号',
      'uid': 'uid-create',
      'app': 'alipaymini',
    });
  });

  testWidgets('expired qr can be refreshed before automatic create', (
    tester,
  ) async {
    final bundle = await _buildBundle();
    addTearDown(bundle.dispose);
    _enqueueToken(bundle, uid: 'uid-expired');
    _enqueueStatus(bundle, 'expired');
    _enqueueToken(bundle, uid: 'uid-fresh');
    _enqueueStatus(bundle, 'confirmed');
    _enqueueCloudLibrary(bundle, app: 'alipaymini', name: '115 归档库');

    await _pumpHarness(tester, bundle, platform: AppPlatform.desktop);
    await tester.tap(find.byKey(const Key('launch-cloud115-flow')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('cloud115-library-name-field')),
      '115 归档库',
    );
    await tester.tap(
      find.byKey(const Key('cloud115-login-risk-checkbox')),
    );
    await tester.tap(
      find.byKey(const Key('cloud115-login-continue-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('二维码已过期'), findsOneWidget);
    await tester.tap(find.text('刷新二维码'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('result:115 归档库:alipaymini'), findsOneWidget);
    final createRequest = bundle.adapter.requests.firstWhere(
      (request) => request.path == '/media-libraries/cloud115',
    );
    expect(createRequest.body['uid'], 'uid-fresh');
  });

  testWidgets('reauth defaults to the library app on mobile', (tester) async {
    final bundle = await _buildBundle();
    addTearDown(bundle.dispose);
    _enqueueToken(bundle, uid: 'uid-reauth');
    _enqueueStatus(bundle, 'confirmed');
    _enqueueCloudLibrary(bundle, app: 'web', reauth: true);
    const library = MediaLibraryDto(
      id: 8,
      name: '115 主账号',
      backend: MediaLibraryBackend.cloud115,
      backendConfig: {'root_cid': 'cid-root', 'app': 'web'},
      createdAt: null,
      updatedAt: null,
    );

    await _pumpHarness(
      tester,
      bundle,
      platform: AppPlatform.mobile,
      reauthLibrary: library,
    );
    await tester.tap(find.byKey(const Key('launch-cloud115-flow')));
    await tester.pumpAndSettle();

    expect(find.textContaining('持续占用“网页版”登录槽'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('cloud115-login-risk-checkbox')),
    );
    await tester.tap(
      find.byKey(const Key('cloud115-login-continue-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('result:115 主账号:web'), findsOneWidget);
    final request = bundle.adapter.requests.firstWhere(
      (item) => item.path == '/media-libraries/cloud115/8/reauth',
    );
    expect(request.body, {'uid': 'uid-reauth', 'app': 'web'});
  });

  testWidgets('changing app resets risk acknowledgement', (tester) async {
    final bundle = await _buildBundle();
    addTearDown(bundle.dispose);
    await _pumpHarness(tester, bundle, platform: AppPlatform.desktop);
    await tester.tap(find.byKey(const Key('launch-cloud115-flow')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('cloud115-login-risk-checkbox')),
    );
    await tester.pump();
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const Key('cloud115-login-risk-checkbox')),
          )
          .value,
      isTrue,
    );
    await tester.tap(find.text('支付宝小程序（推荐）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('微信小程序').last);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const Key('cloud115-login-risk-checkbox')),
          )
          .value,
      isFalse,
    );
    expect(find.textContaining('持续占用“微信小程序”登录槽'), findsOneWidget);
  });
}

Future<TestApiBundle> _buildBundle() async {
  final sessionStore = SessionStore.inMemory();
  await sessionStore.saveBaseUrl('https://api.example.com');
  await sessionStore.saveTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
  );
  return createTestApiBundle(sessionStore);
}

Future<void> _pumpHarness(
  WidgetTester tester,
  TestApiBundle bundle, {
  required AppPlatform platform,
  MediaLibraryDto? reauthLibrary,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AppPlatform>.value(value: platform),
        Provider<MediaLibrariesApi>.value(value: bundle.mediaLibrariesApi),
      ],
      child: MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: _FlowHarness(reauthLibrary: reauthLibrary),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FlowHarness extends StatefulWidget {
  const _FlowHarness({this.reauthLibrary});

  final MediaLibraryDto? reauthLibrary;

  @override
  State<_FlowHarness> createState() => _FlowHarnessState();
}

class _FlowHarnessState extends State<_FlowHarness> {
  MediaLibraryDto? _result;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          key: const Key('launch-cloud115-flow'),
          onPressed: () async {
            final result = await showCloud115LibraryLoginFlow(
              context,
              reauthLibrary: widget.reauthLibrary,
            );
            if (mounted) {
              setState(() => _result = result);
            }
          },
          child: const Text('launch'),
        ),
        if (_result != null)
          Text(
            'result:${_result!.name}:${_result!.cloud115App.wireValue}',
          ),
      ],
    );
  }
}

void _enqueueToken(TestApiBundle bundle, {required String uid}) {
  bundle.adapter.enqueueJson(
    method: 'POST',
    path: '/media-libraries/cloud115/qrlogin/token',
    body: {
      'uid': uid,
      'time': 1700000000,
      'sign': 'sign-$uid',
      'qrcode_png_base64': _onePixelPng,
    },
  );
}

void _enqueueStatus(TestApiBundle bundle, String status) {
  bundle.adapter.enqueueJson(
    method: 'POST',
    path: '/media-libraries/cloud115/qrlogin/status',
    body: {'status': status},
  );
}

void _enqueueCloudLibrary(
  TestApiBundle bundle, {
  required String app,
  String name = '115 主账号',
  bool reauth = false,
}) {
  bundle.adapter.enqueueJson(
    method: 'POST',
    path: reauth
        ? '/media-libraries/cloud115/8/reauth'
        : '/media-libraries/cloud115',
    statusCode: reauth ? 200 : 201,
    body: {
      'id': 8,
      'name': name,
      'backend': 'cloud115',
      'backend_config': {'root_cid': 'cid-root', 'app': app},
      'created_at': '2026-07-14T09:30:00Z',
      'updated_at': '2026-07-14T10:00:00Z',
    },
  );
}
