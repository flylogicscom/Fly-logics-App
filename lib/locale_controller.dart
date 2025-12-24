import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController extends ChangeNotifier {
  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  Future<void> loadLocale(Locale systemLocale) async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString("locale");

    if (savedLang != null) {
      _locale = Locale(savedLang);
    } else {
      final langCode = systemLocale.languageCode;
      if (langCode == 'es' || langCode == 'pt') {
        _locale = Locale(langCode);
      } else {
        _locale = const Locale('en');
      }
    }
    notifyListeners();
  }

  Future<void> setLocale(Locale newLocale) async {
    _locale = newLocale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("locale", newLocale.languageCode);
  }
}
