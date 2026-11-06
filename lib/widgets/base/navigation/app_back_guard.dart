import 'package:material_ui/material_ui.dart';

typedef AppBackGuardCallback = Future<bool> Function();

/// 可释放的返回拦截注册。
class AppBackGuardRegistration {
  AppBackGuardRegistration._(this._controller, this._id);

  final AppBackGuardController? _controller;
  final int _id;
  bool _disposed = false;

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _controller?._unregister(_id);
  }
}

class _AppBackGuardEntry {
  const _AppBackGuardEntry({required this.id, required this.callback});

  final int id;
  final AppBackGuardCallback callback;
}

/// 按注册顺序串行执行返回拦截；任一回调返回 false 即停止。
class AppBackGuardController {
  final List<_AppBackGuardEntry> _entries = <_AppBackGuardEntry>[];
  int _nextId = 0;

  AppBackGuardRegistration register(AppBackGuardCallback callback) {
    final id = _nextId++;
    _entries.add(_AppBackGuardEntry(id: id, callback: callback));
    return AppBackGuardRegistration._(this, id);
  }

  Future<bool> canLeave() async {
    for (final entry in List<_AppBackGuardEntry>.of(_entries)) {
      if (!await entry.callback()) {
        return false;
      }
    }
    return true;
  }

  void _unregister(int id) {
    _entries.removeWhere((entry) => entry.id == id);
  }
}

class AppBackGuardScope extends InheritedWidget {
  const AppBackGuardScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final AppBackGuardController controller;

  static AppBackGuardController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppBackGuardScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(AppBackGuardScope oldWidget) {
    return !identical(controller, oldWidget.controller);
  }
}
