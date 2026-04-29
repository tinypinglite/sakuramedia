import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/metadata_provider_license_api.dart';

import '../../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late ApiClient apiClient;
  late MetadataProviderLicenseApi licenseApi;
  late FakeHttpClientAdapter adapter;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-08T10:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    licenseApi = MetadataProviderLicenseApi(apiClient: apiClient);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
  });

  tearDown(() {
    apiClient.dispose();
  });

  test('getStatus parses metadata provider license status', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/metadata-provider-license/status',
      statusCode: 200,
      body: <String, dynamic>{
        'configured': true,
        'active': false,
        'instance_id': 'inst_test',
        'expires_at': null,
        'license_valid_until': 1780000000,
        'renew_after_seconds': null,
        'error_code': 'license_required',
        'message': 'License activation is required',
      },
    );

    final status = await licenseApi.getStatus();

    expect(status.configured, isTrue);
    expect(status.active, isFalse);
    expect(status.instanceId, 'inst_test');
    expect(status.licenseValidUntil, 1780000000);
    expect(status.errorCode, 'license_required');
    expect(status.message, 'License activation is required');
  });

  test('activate posts activation code and parses active status', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/metadata-provider-license/activate',
      statusCode: 200,
      body: <String, dynamic>{
        'configured': true,
        'active': true,
        'instance_id': 'inst_test',
        'expires_at': 1777181126,
        'license_valid_until': 1780000000,
        'renew_after_seconds': 21600,
        'error_code': null,
        'message': null,
      },
    );

    final status = await licenseApi.activate(
      activationCode: 'SMB-SUPER-SECRET',
    );

    expect(status.active, isTrue);
    expect(status.expiresAt, 1777181126);
    expect(status.licenseValidUntil, 1780000000);
    expect(status.renewAfterSeconds, 21600);
    expect(adapter.requests.single.body['activation_code'], 'SMB-SUPER-SECRET');
  });

  test('testConnectivity parses license center connectivity result', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/metadata-provider-license/connectivity-test',
      statusCode: 200,
      body: <String, dynamic>{
        'ok': true,
        'url': 'https://license.example.com/',
        'proxy_enabled': true,
        'elapsed_ms': 128,
        'status_code': 200,
        'error': null,
      },
    );

    final result = await licenseApi.testConnectivity();

    expect(result.ok, isTrue);
    expect(result.url, 'https://license.example.com/');
    expect(result.proxyEnabled, isTrue);
    expect(result.elapsedMs, 128);
    expect(result.statusCode, 200);
    expect(result.error, isNull);
  });

  test('syncAuthorization posts renew endpoint and parses status', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/metadata-provider-license/renew',
      statusCode: 200,
      body: <String, dynamic>{
        'configured': true,
        'active': true,
        'instance_id': 'inst_test',
        'expires_at': 1777181126,
        'license_valid_until': 1780000000,
        'renew_after_seconds': 21600,
        'error_code': null,
        'message': null,
      },
    );

    final status = await licenseApi.syncAuthorization();

    expect(status.active, isTrue);
    expect(status.licenseValidUntil, 1780000000);
    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.path, '/metadata-provider-license/renew');
  });

  test('activate converts backend error to ApiException', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/metadata-provider-license/activate',
      statusCode: 403,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'activation_code_invalid',
          'message': 'Activation code is invalid',
          'details': <String, dynamic>{
            'license_error_code': 'activation_code_invalid',
          },
        },
      },
    );

    expect(
      () => licenseApi.activate(activationCode: 'SMB-SUPER-SECRET'),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.error?.code,
          'error.code',
          'activation_code_invalid',
        ),
      ),
    );
  });
}
