import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/external_player/presentation/providers/external_player_preference_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(retry: (_, __) => null);
  });

  tearDown(() {
    container.dispose();
  });

  test('默认未选择外部播放器时使用应用内播放器', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final selection = await container.read(
      externalPlayerPreferenceProvider.future,
    );

    expect(selection.hasExternalPlayer, isFalse);
    expect(selection.packageName, isNull);
    expect(selection.label, isNull);
  });

  test('选择外部播放器后持久化包名与名称', () async {
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
        .selectExternalPlayer(packageName: 'org.videolan.vlc', label: 'VLC');

    final selection =
        container.read(externalPlayerPreferenceProvider).requireValue;
    expect(selection.hasExternalPlayer, isTrue);
    expect(selection.packageName, 'org.videolan.vlc');
    expect(selection.label, 'VLC');
    expect(notifiedCount, greaterThan(0));

    // 用第二个容器重新 build 验证真落盘。
    final reloadedContainer = ProviderContainer(retry: (_, __) => null);
    addTearDown(reloadedContainer.dispose);
    final reloaded = await reloadedContainer.read(
      externalPlayerPreferenceProvider.future,
    );
    expect(reloaded.packageName, 'org.videolan.vlc');
    expect(reloaded.label, 'VLC');
  });

  test('切回应用内播放器清除持久化偏好', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await container.read(externalPlayerPreferenceProvider.future);
    final notifier = container.read(externalPlayerPreferenceProvider.notifier);
    await notifier.selectExternalPlayer(
      packageName: 'com.mxtech.videoplayer.ad',
      label: 'MX Player',
    );

    await notifier.useInAppPlayer();

    final selection =
        container.read(externalPlayerPreferenceProvider).requireValue;
    expect(selection.hasExternalPlayer, isFalse);
    expect(selection.packageName, isNull);

    final reloadedContainer = ProviderContainer(retry: (_, __) => null);
    addTearDown(reloadedContainer.dispose);
    final reloaded = await reloadedContainer.read(
      externalPlayerPreferenceProvider.future,
    );
    expect(reloaded.hasExternalPlayer, isFalse);
  });
}
