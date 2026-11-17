import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_catalog_dto.dart';

Future<void> resetProviderLoginWebViewSession(ProviderLoginDto login) async {
  final domains = providerLoginDomains(login);
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      await _resetAppleWebsiteData(domains);
    case TargetPlatform.android:
      await _resetAndroidWebsiteData();
    case TargetPlatform.windows:
      await CookieManager.instance().deleteAllCookies();
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      await CookieManager.instance().deleteAllCookies();
      await InAppWebViewController.clearAllCache();
  }
}

Set<String> providerLoginDomains(ProviderLoginDto login) {
  final domains = <String>{};
  void addHost(Object? value) {
    final text = value?.toString().trim() ?? '';
    var uri = value is Uri ? value : Uri.tryParse(text);
    if ((uri?.host ?? '').isEmpty && text.isNotEmpty) {
      uri = Uri.tryParse('https://$text');
    }
    final host = uri?.host.toLowerCase().replaceFirst(RegExp(r'^\.'), '');
    if (host == null || host.isEmpty) return;
    domains.add(host);
  }

  addHost(login.startUrl);
  for (final host in login.allowedHosts) {
    addHost(host);
  }
  for (final capture in login.cookieCaptures) {
    addHost(capture.url);
  }
  for (final capture in login.localStorageCaptures) {
    addHost(capture.origin);
  }
  return domains;
}

bool providerLoginWebsiteDataRecordMatches(
  String displayName,
  Set<String> domains,
) {
  final normalized = displayName.toLowerCase().replaceFirst(RegExp(r'^\.'), '');
  if (normalized.isEmpty) return false;
  for (final domain in domains) {
    if (normalized == domain || normalized.endsWith('.$domain')) {
      return true;
    }
    if (normalized.contains('.') && domain.endsWith('.$normalized')) {
      return true;
    }
  }
  return false;
}

Future<void> _resetAppleWebsiteData(Set<String> domains) async {
  final webStorageManager = WebStorageManager.instance();
  final records = await webStorageManager.fetchDataRecords(
    dataTypes: WebsiteDataType.ALL,
  );
  final matchingRecords = records
      .where(
        (record) => providerLoginWebsiteDataRecordMatches(
          record.displayName ?? '',
          domains,
        ),
      )
      .toList(growable: false);
  if (matchingRecords.isNotEmpty) {
    await webStorageManager.removeDataFor(
      dataTypes: WebsiteDataType.ALL,
      dataRecords: matchingRecords,
    );
  }
  await CookieManager.instance().deleteAllCookies();
  await InAppWebViewController.clearAllCache();
  await HttpAuthCredentialDatabase.instance().clearAllAuthCredentials();
}

Future<void> _resetAndroidWebsiteData() async {
  await CookieManager.instance().deleteAllCookies();
  await WebStorageManager.instance().deleteAllData();
  await InAppWebViewController.clearAllCache();
  await HttpAuthCredentialDatabase.instance().clearAllAuthCredentials();
}
