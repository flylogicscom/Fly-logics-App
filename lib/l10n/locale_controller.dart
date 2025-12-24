import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController extends ChangeNotifier {
  Locale _locale = const Locale('en'); // fallback inglés
  Locale get locale => _locale;

  Future<void> loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('locale');

    if (code != null && ['en', 'es', 'pt'].contains(code)) {
      // ✅ Usamos el idioma guardado por el usuario
      _locale = Locale(code);
    } else {
      // ✅ Detectamos idioma del sistema
      final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
      if (['en', 'es', 'pt'].contains(systemLocale.languageCode)) {
        _locale = Locale(systemLocale.languageCode);
      } else {
        _locale = const Locale('en'); // fallback
      }
    }

    notifyListeners();
  }

  Future<void> setLocale(Locale newLocale) async {
    if (!['en', 'es', 'pt'].contains(newLocale.languageCode)) return;

    _locale = newLocale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', newLocale.languageCode);

    notifyListeners();
  }
}
