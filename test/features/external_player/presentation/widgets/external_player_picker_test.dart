import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/external_player/data/external_player_app.dart';
import 'package:sakuramedia/features/external_player/presentation/widgets/external_player_picker.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../support/pump_with_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('lists detected players and returns the selected player', (
    tester,
  ) async {
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final session = SessionStore.inMemory();
    const channel = MethodChannel('sakuramedia/external_player');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    try {
      await session.saveBaseUrl('http://nas:8000');
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method != 'listPlayers') {
          return null;
        }
        return <Map<String, String>>[
          <String, String>{'id': 'org.videolan.vlc', 'label': 'VLC'},
          <String, String>{
            'id': 'com.mxtech.videoplayer.ad',
            'label': 'MX Player',
          },
        ];
      });

      await pumpWithProviders(
        tester,
        home: const _PickerLauncher(),
        overrides: [sessionStoreProvider.overrideWithValue(session)],
        theme: sakuraDesktopThemeData,
        physicalSize: const Size(900, 700),
      );
      await tester.tap(find.byKey(const Key('open-external-player-picker')));
      await tester.pumpAndSettle();

      expect(find.text('VLC'), findsOneWidget);
      expect(find.text('MX Player'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('external-player-picker-org.videolan.vlc')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('external-player-picker-result-VLC')),
        findsOneWidget,
      );
    } finally {
      await tester.pumpWidget(const SizedBox());
      messenger.setMockMethodCallHandler(channel, null);
      session.dispose();
      debugDefaultTargetPlatformOverride = previous;
    }
  });
}

class _PickerLauncher extends StatefulWidget {
  const _PickerLauncher();

  @override
  State<_PickerLauncher> createState() => _PickerLauncherState();
}

class _PickerLauncherState extends State<_PickerLauncher> {
  ExternalPlayerApp? _selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              key: const Key('open-external-player-picker'),
              onPressed: () async {
                final selected = await showExternalPlayerPicker(context);
                if (!mounted) {
                  return;
                }
                setState(() => _selected = selected);
              },
              child: const Text('open'),
            ),
            if (_selected case final selected?)
              Text(
                selected.label,
                key: Key('external-player-picker-result-${selected.label}'),
              ),
          ],
        ),
      ),
    );
  }
}
