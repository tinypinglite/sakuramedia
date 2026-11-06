import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/account/presentation/widgets/account_security_content.dart';

class MobileAccountSecurityPage extends StatelessWidget {
  const MobileAccountSecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AccountSecurityContent(mobile: true);
  }
}
