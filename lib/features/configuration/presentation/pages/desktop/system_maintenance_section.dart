import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/system_maintenance_content.dart';

class SystemMaintenanceSection extends StatelessWidget {
  const SystemMaintenanceSection({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return SystemMaintenanceContent(
      active: active,
      variant: SystemMaintenanceContentVariant.desktop,
    );
  }
}
