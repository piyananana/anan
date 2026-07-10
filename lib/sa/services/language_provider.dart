import 'package:flutter/foundation.dart';

class LanguageProvider extends ChangeNotifier {
  bool _isEnglish = false;

  bool get isEnglish => _isEnglish;

  void toggle() {
    _isEnglish = !_isEnglish;
    notifyListeners();
  }

  void setEnglish(bool value) {
    if (_isEnglish == value) return;
    _isEnglish = value;
    notifyListeners();
  }
}
