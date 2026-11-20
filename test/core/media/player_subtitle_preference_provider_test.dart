import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/media/providers/player_subtitle_preference_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    container = ProviderContainer(retry: (retryCount, error) => null);
  });

  tearDown(() {
    container.dispose();
  });

  test('字幕字号默认使用 1.0 倍', () async {
    final preference = await container.read(
      playerSubtitlePreferenceControllerProvider.future,
    );

    expect(preference.scale, 1.0);
    expect(preference.isDefault, isTrue);
  });

  test('字幕字号写入后可由新的 Provider 容器读回', () async {
    await container.read(playerSubtitlePreferenceControllerProvider.future);

    await container
        .read(playerSubtitlePreferenceControllerProvider.notifier)
        .setScale(1.5);

    final reloadedContainer = ProviderContainer(
      retry: (retryCount, error) => null,
    );
    addTearDown(reloadedContainer.dispose);
    final reloaded = await reloadedContainer.read(
      playerSubtitlePreferenceControllerProvider.future,
    );

    expect(reloaded.scale, 1.5);
  });

  test('恢复默认会清除已保存的字幕字号', () async {
    await container.read(playerSubtitlePreferenceControllerProvider.future);
    final notifier = container.read(
      playerSubtitlePreferenceControllerProvider.notifier,
    );

    await notifier.setScale(1.5);
    await notifier.reset();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getDouble('player.subtitle.scale'), isNull);
    expect(
      container
          .read(playerSubtitlePreferenceControllerProvider)
          .requireValue
          .isDefault,
      isTrue,
    );
  });
}
