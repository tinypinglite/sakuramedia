import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_catalog_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/provider_login_session_reset.dart';

void main() {
  const login = ProviderLoginDto(
    mode: 'webview',
    startUrl: 'https://login.115.com/?ct=login&ac=web',
    allowedHosts: <String>['115.com'],
    cookieCaptures: <ProviderLoginCookieCaptureDto>[
      ProviderLoginCookieCaptureDto(
        url: 'https://my.115.com/',
        captureNames: <String>['UID'],
        requiredNames: <String>['UID'],
      ),
    ],
    localStorageCaptures: <ProviderLoginLocalStorageCaptureDto>[
      ProviderLoginLocalStorageCaptureDto(
        origin: 'https://www.115.com',
        requiredJsonKeys: <String>[],
      ),
    ],
    managedConfigKeys: <String>[],
    timeoutSeconds: 300,
  );

  test('derives all provider hosts from the login declaration', () {
    expect(providerLoginDomains(login), <String>{
      '115.com',
      'login.115.com',
      'my.115.com',
      'www.115.com',
    });
  });

  test('matches parent and subdomain website data records only', () {
    final domains = providerLoginDomains(login);

    expect(providerLoginWebsiteDataRecordMatches('115.com', domains), isTrue);
    expect(
      providerLoginWebsiteDataRecordMatches('my.115.com', domains),
      isTrue,
    );
    expect(
      providerLoginWebsiteDataRecordMatches('115.com.evil.example', domains),
      isFalse,
    );
    expect(
      providerLoginWebsiteDataRecordMatches('evil115.com', domains),
      isFalse,
    );
  });
}
