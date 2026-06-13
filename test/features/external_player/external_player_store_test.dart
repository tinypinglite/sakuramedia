import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/features/external_player/data/external_player_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('默认未选择外部播放器时使用应用内播放器', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = ExternalPlayerStore();
    await store.load();

    expect(store.isLoaded, isTrue);
    expect(store.hasExternalPlayer, isFalse);
    expect(store.packageName, isNull);
    expect(store.label, isNull);
  });

  test('选择外部播放器后持久化包名与名称', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = ExternalPlayerStore();
    await store.load();

    var notifiedCount = 0;
    store.addListener(() => notifiedCount++);

    await store.selectExternalPlayer(
      packageName: 'org.videolan.vlc',
      label: 'VLC',
    );

    expect(store.hasExternalPlayer, isTrue);
    expect(store.packageName, 'org.videolan.vlc');
    expect(store.label, 'VLC');
    expect(notifiedCount, greaterThan(0));

    // 重新加载验证持久化生效。
    final reloaded = ExternalPlayerStore();
    await reloaded.load();
    expect(reloaded.packageName, 'org.videolan.vlc');
    expect(reloaded.label, 'VLC');
  });

  test('切回应用内播放器清除持久化偏好', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = ExternalPlayerStore();
    await store.load();
    await store.selectExternalPlayer(
      packageName: 'com.mxtech.videoplayer.ad',
      label: 'MX Player',
    );

    await store.useInAppPlayer();

    expect(store.hasExternalPlayer, isFalse);
    expect(store.packageName, isNull);

    final reloaded = ExternalPlayerStore();
    await reloaded.load();
    expect(reloaded.hasExternalPlayer, isFalse);
  });
}
