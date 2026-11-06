import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/account/presentation/widgets/account_security_content.dart';

class AccountSecuritySection extends StatelessWidget {
  const AccountSecuritySection({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return AccountSecurityContent(mobile: false, active: active);
  }
}
