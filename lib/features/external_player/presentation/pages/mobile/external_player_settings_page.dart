import 'package:flutter/material.dart';
import 'package:sakuramedia/features/external_player/presentation/widgets/external_player_settings_content.dart';

class MobileExternalPlayerSettingsPage extends StatelessWidget {
  const MobileExternalPlayerSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('mobile-external-player-settings'),
      children: const [ExternalPlayerSettingsContent()],
    );
  }
}
