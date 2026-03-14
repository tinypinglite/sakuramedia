import 'package:flutter/foundation.dart';

class AppShellController extends ChangeNotifier {
  bool _isSidebarCollapsed = false;

  bool get isSidebarCollapsed => _isSidebarCollapsed;

  void toggleSidebar() {
    _isSidebarCollapsed = !_isSidebarCollapsed;
    notifyListeners();
  }
}
