import 'package:flutter/widgets.dart';

/// Keeps a lazily built `PageView` or `TabBarView` child mounted after visit.
///
/// Use this for page-local UI state that should still be there when a user
/// returns to a sibling tab. It deliberately does not retain providers or
/// other data outside the page's own lifetime.
class AppKeepAlive extends StatefulWidget {
  const AppKeepAlive({super.key, required this.child});

  final Widget child;

  @override
  State<AppKeepAlive> createState() => _AppKeepAliveState();
}

class _AppKeepAliveState extends State<AppKeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
