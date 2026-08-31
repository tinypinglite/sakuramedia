import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/external_player/presentation/providers/external_player_preference_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    container = ProviderContainer(retry: (_, __) => null);
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    container.dispose();
  });

  test('默认未选择外部播放器时使用应用内播放器', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final selection = await container.read(
      externalPlayerPreferenceProvider.future,
    );

    expect(selection.hasExternalPlayer, isFalse);
    expect(selection.playerId, isNull);
    expect(selection.label, isNull);
  });

  test('选择外部播放器后持久化标识与名称', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await container.read(externalPlayerPreferenceProvider.future);

    var notifiedCount = 0;
    final subscription = container.listen(externalPlayerPreferenceProvider, (
      _,
      __,
    ) {
      notifiedCount++;
    });
    addTearDown(subscription.close);

    await container
        .read(externalPlayerPreferenceProvider.notifier)
        .selectExternalPlayer(playerId: 'org.videolan.vlc', label: 'VLC');

    final selection = container
        .read(externalPlayerPreferenceProvider)
        .requireValue;
    expect(selection.hasExternalPlayer, isTrue);
    expect(selection.playerId, 'org.videolan.vlc');
    expect(selection.label, 'VLC');
    expect(notifiedCount, greaterThan(0));

    // 用第二个容器重新 build 验证真落盘。
    final reloadedContainer = ProviderContainer(retry: (_, __) => null);
    addTearDown(reloadedContainer.dispose);
    final reloaded = await reloadedContainer.read(
      externalPlayerPreferenceProvider.future,
    );
    expect(reloaded.playerId, 'org.videolan.vlc');
    expect(reloaded.label, 'VLC');
  });

  test('切回应用内播放器清除持久化偏好', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await container.read(externalPlayerPreferenceProvider.future);
    final notifier = container.read(externalPlayerPreferenceProvider.notifier);
    await notifier.selectExternalPlayer(
      playerId: 'com.mxtech.videoplayer.ad',
      label: 'MX Player',
    );

    await notifier.useInAppPlayer();

    final selection = container
        .read(externalPlayerPreferenceProvider)
        .requireValue;
    expect(selection.hasExternalPlayer, isFalse);
    expect(selection.playerId, isNull);

    final reloadedContainer = ProviderContainer(retry: (_, __) => null);
    addTearDown(reloadedContainer.dispose);
    final reloaded = await reloadedContainer.read(
      externalPlayerPreferenceProvider.future,
    );
    expect(reloaded.hasExternalPlayer, isFalse);
  });

  test('macOS 使用独立的应用路径偏好', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await container.read(externalPlayerPreferenceProvider.future);

    await container
        .read(externalPlayerPreferenceProvider.notifier)
        .selectExternalPlayer(
          playerId: '/Applications/IINA.app',
          label: 'IINA',
        );

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString('macos.external_player.application_path'),
      '/Applications/IINA.app',
    );
    expect(preferences.getString('macos.external_player.label'), 'IINA');
  });
}
