import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
// App Orchestrator
//
// Focus: Lightweight coordination only.
// Routing, session awareness, and lifecycle.
// NO business logic.
// ═══════════════════════════════════════════════════════════════

class AppOrchestrator extends ChangeNotifier {
  // ─── Navigation ───
  int _currentNavIndex = 0;
  int get currentNavIndex => _currentNavIndex;

  void setNavIndex(int index) {
    _currentNavIndex = index;
    notifyListeners();
  }
}
