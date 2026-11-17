import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/appearance_settings_content.dart';

class MobileAppearanceSettingsPage extends StatelessWidget {
  const MobileAppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('mobile-appearance-settings'),
      children: const [AppearanceSettingsContent()],
    );
  }
}
