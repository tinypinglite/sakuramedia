import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_binding_dto.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_bindings_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_capabilities_provider.dart';

void main() {
  test('capabilities require available bound sources', () async {
    final container = ProviderContainer(
      overrides: [
        pluginBindingsProvider.overrideWith(
          (ref) async => const PluginBindingsDto(
            statsSource: 'stats_plugin',
            statsSourceAvailable: true,
            reviewSource: 'review_plugin',
            reviewSourceAvailable: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(pluginBindingsProvider.future);

    expect(container.read(statsFeaturesEnabledProvider), isTrue);
    expect(container.read(reviewFeaturesEnabledProvider), isFalse);
  });

  test('unbound sources disable both capabilities', () async {
    final container = ProviderContainer(
      overrides: [
        pluginBindingsProvider.overrideWith(
          (ref) async => const PluginBindingsDto(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(pluginBindingsProvider.future);

    expect(container.read(statsFeaturesEnabledProvider), isFalse);
    expect(container.read(reviewFeaturesEnabledProvider), isFalse);
  });

  test('binding load errors disable both capabilities', () async {
    final container = ProviderContainer(
      overrides: [
        pluginBindingsProvider.overrideWith(
          (ref) async => throw StateError('boom'),
        ),
      ],
      retry: (_, __) => null,
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(pluginBindingsProvider.future),
      throwsA(isA<StateError>()),
    );

    expect(container.read(statsFeaturesEnabledProvider), isFalse);
    expect(container.read(reviewFeaturesEnabledProvider), isFalse);
  });
}
