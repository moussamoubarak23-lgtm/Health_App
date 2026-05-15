import 'package:flutter/material.dart';

class NavigationHistory with ChangeNotifier {
  static final NavigationHistory _instance = NavigationHistory._internal();
  factory NavigationHistory() => _instance;
  NavigationHistory._internal();

  final List<String> _history = [];
  int _currentIndex = -1;

  List<String> get history => List.unmodifiable(_history);
  int get currentIndex => _currentIndex;
  bool get canGoForward => _currentIndex < _history.length - 1;
  bool get canGoBack => _currentIndex > 0;

  void addRoute(String route) {
    // Ne pas ajouter login à l'historique
    if (route == '/login') return;
    
    // Si on est au milieu de l'historique et qu'on ajoute une nouvelle route,
    // on supprime tout ce qui est après l'index actuel
    if (_currentIndex < _history.length - 1) {
      _history.removeRange(_currentIndex + 1, _history.length);
    }
    
    // Éviter d'ajouter des routes dupliquées consécutives
    if (_history.isEmpty || _history.last != route) {
      _history.add(route);
      _currentIndex++;
      notifyListeners();
    }
  }

  void goBack() {
    if (canGoBack) {
      _currentIndex--;
      notifyListeners();
    }
  }

  void goForward() {
    if (canGoForward) {
      _currentIndex++;
      notifyListeners();
    }
  }

  void clear() {
    _history.clear();
    _currentIndex = -1;
    notifyListeners();
  }

  String? get currentRoute => _currentIndex >= 0 && _currentIndex < _history.length ? _history[_currentIndex] : null;
}
