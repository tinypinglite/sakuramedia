import 'package:flutter/material.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/system_maintenance_content.dart';

class MobileSystemMaintenancePage extends StatelessWidget {
  const MobileSystemMaintenancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SystemMaintenanceContent(
      active: true,
      variant: SystemMaintenanceContentVariant.mobile,
    );
  }
}
