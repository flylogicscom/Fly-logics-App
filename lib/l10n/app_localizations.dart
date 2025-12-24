import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

class AppLocalizations {
  final Locale locale;

  late Map<String, String> _strings;

  AppLocalizations(this.locale);

  static AppLocalizations? maybeOf(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static AppLocalizations of(BuildContext context) {
    final result = maybeOf(context);
    assert(result != null,
        'AppLocalizations no encontrado en el árbol de widgets');
    return result!;
  }

  /// Traducción normal
  String t(String key) => _strings[key] ?? key;

  /// Helper dinámico para secciones (section_1, section_2, etc.)
  String section(int number) =>
      _strings["section_$number"] ?? "Section $number";

  Future<bool> load() async {
    final code = locale.languageCode;
    final data = await rootBundle.loadString('assets/l10n/$code.json');
    final Map<String, dynamic> map = json.decode(data);

    final Map<String, String> out = <String, String>{};

    void walk(String prefix, dynamic value) {
      if (value is Map) {
        value.forEach((k, v) {
          final key = prefix.isEmpty ? k.toString() : '$prefix.${k.toString()}';
          walk(key, v);
        });
        return;
      }
      // listas u otros tipos: string simple
      out[prefix] = value?.toString() ?? '';
    }

    map.forEach((k, v) => walk(k.toString(), v));
    _strings = out;
    return true;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'es', 'pt'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
