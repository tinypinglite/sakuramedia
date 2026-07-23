import 'package:flutter/widgets.dart';

typedef AppPageRefreshCallback = Future<void> Function();

@immutable
class AppPageRefreshRegistrar {
  const AppPageRefreshRegistrar({
    required this.register,
    required this.unregister,
  });

  final void Function(AppPageRefreshCallback callback) register;
  final void Function(AppPageRefreshCallback callback) unregister;
}

class AppPageRefreshRegistrarScope extends InheritedWidget {
  const AppPageRefreshRegistrarScope({
    super.key,
    required this.registrar,
    required super.child,
  });

  final AppPageRefreshRegistrar registrar;

  static AppPageRefreshRegistrar? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppPageRefreshRegistrarScope>()
        ?.registrar;
  }

  @override
  bool updateShouldNotify(AppPageRefreshRegistrarScope oldWidget) {
    return oldWidget.registrar != registrar;
  }
}

class AppPageRefreshScope extends StatefulWidget {
  const AppPageRefreshScope({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final AppPageRefreshCallback onRefresh;
  final Widget child;

  @override
  State<AppPageRefreshScope> createState() => _AppPageRefreshScopeState();
}

class _AppPageRefreshScopeState extends State<AppPageRefreshScope> {
  AppPageRefreshRegistrar? _registrar;
  late final AppPageRefreshCallback _boundCallback = _invoke;

  Future<void> _invoke() => widget.onRefresh();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registrar = AppPageRefreshRegistrarScope.maybeOf(context);
    if (identical(registrar, _registrar)) {
      return;
    }
    _registrar?.unregister(_boundCallback);
    _registrar = registrar;
    _registrar?.register(_boundCallback);
  }

  @override
  void dispose() {
    _registrar?.unregister(_boundCallback);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
