import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_catalog_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/provider_login_capture.dart';

void main() {
  const login = ProviderLoginDto(
    mode: 'webview',
    startUrl: 'https://115.com/?ct=login&ac=web',
    allowedHosts: <String>['115.com', 'guangyapan.com'],
    cookieCaptures: <ProviderLoginCookieCaptureDto>[
      ProviderLoginCookieCaptureDto(
        url: 'https://115.com/',
        captureNames: <String>['UID', 'CID', 'SEID', 'KID'],
        requiredNames: <String>['UID', 'CID', 'SEID'],
      ),
    ],
    localStorageCaptures: <ProviderLoginLocalStorageCaptureDto>[
      ProviderLoginLocalStorageCaptureDto(
        origin: 'https://www.guangyapan.com',
        requiredJsonKeys: <String>['refresh_token'],
      ),
    ],
    managedConfigKeys: <String>['web_cookie', 'refresh_token'],
    timeoutSeconds: 300,
  );

  test('matches only HTTPS hosts in the provider allowlist', () {
    expect(
      isAllowedProviderLoginUri(
        Uri.parse('https://my.115.com/login'),
        login.allowedHosts,
      ),
      isTrue,
    );
    expect(
      isAllowedProviderLoginUri(
        Uri.parse('http://115.com/login'),
        login.allowedHosts,
      ),
      isFalse,
    );
    expect(
      isAllowedProviderLoginUri(
        Uri.parse('https://115.com.evil.example/login'),
        login.allowedHosts,
      ),
      isFalse,
    );
  });

  test('recognizes allowed HTTP post-login navigations', () {
    expect(
      isAllowedProviderLoginHttpUri(
        Uri.parse('http://115.com/?cid=0&offset=0&mode=wangpan'),
        login.allowedHosts,
      ),
      isTrue,
    );
    expect(
      isAllowedProviderLoginHttpUri(
        Uri.parse('http://115.com.evil.example/login'),
        login.allowedHosts,
      ),
      isFalse,
    );
    expect(
      isAllowedProviderLoginHttpUri(
        Uri.parse('http://115.com.evil.example@evil.example/login'),
        login.allowedHosts,
      ),
      isFalse,
    );
  });

  test('selects only requested non-empty cookies', () {
    final values = selectProviderLoginCookies(
      const <(String, String)>[
        ('UID', '123'),
        ('CID', 'cid'),
        ('OTHER', 'ignored'),
      ],
      <String>['UID', 'CID', 'SEID'],
    );

    expect(values, <String, String>{'UID': '123', 'CID': 'cid'});
    expect(
      providerLoginCookieCaptureSatisfied(login.cookieCaptures.first, values),
      isFalse,
    );
  });

  test('finds refresh_token in any JSON localStorage value', () {
    final items = decodeProviderLoginLocalStorage(
      jsonEncode(<String, String>{
        'credentials_client': jsonEncode(<String, String>{
          'refresh_token': 'gy.test',
        }),
        'other': 'plain',
      }),
    );

    expect(
      providerLoginStorageCaptureSatisfied(
        login.localStorageCaptures.first,
        items,
      ),
      isTrue,
    );
    expect(
      isProviderLoginCaptureComplete(
        login: login,
        cookiesByUrl: <String, Map<String, String>>{
          'https://115.com/': <String, String>{
            'UID': '123',
            'CID': 'cid',
            'SEID': 'seid',
          },
        },
        localStorageByOrigin: <String, Map<String, String>>{
          'https://www.guangyapan.com': items,
        },
      ),
      isTrue,
    );
  });

  test('builds payloads in provider declaration order', () {
    final cookies = buildProviderLoginCookiePayloads(
      login,
      <String, Map<String, String>>{
        'https://115.com/': <String, String>{
          'UID': '123',
          'CID': 'cid',
          'SEID': 'seid',
          'KID': 'kid',
        },
      },
    );
    final storage = buildProviderLoginLocalStoragePayloads(
      login,
      <String, Map<String, String>>{
        'https://www.guangyapan.com': <String, String>{'x': 'y'},
      },
    );

    expect(cookies.single.values, <String, String>{
      'UID': '123',
      'CID': 'cid',
      'SEID': 'seid',
      'KID': 'kid',
    });
    expect(storage.single.origin, 'https://www.guangyapan.com');
    expect(storage.single.items, <String, String>{'x': 'y'});
  });
}
