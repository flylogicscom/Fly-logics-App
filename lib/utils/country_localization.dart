import 'package:flutter/widgets.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';
import 'package:fly_logicd_logbook_app/utils/country_data.dart';

/// Localiza países usando el flagEmoji como referencia:
/// 🇦🇫 -> "AF" -> key: "countries.AF"
/// Caso especial: Simulator -> key: "countries.SIM"
class CountryLocalization {
  /// Devuelve el nombre localizado del país usando tus JSON:
  /// { "countries": { "AF": "...", ... } }
  /// Fallback: CountryData.name (inglés).
  static String name(BuildContext context, CountryData c) {
    final key = _countryKey(c);
    if (key == null) return c.name;

    final fullKey = 'countries.$key';
    final value = _l10n(context, fullKey);

    // Si no existe la key, devolvemos el fallback en inglés.
    return (value == fullKey) ? c.name : value;
  }

  /// Devuelve "AF", "CL", etc. desde 🇦🇫 / 🇨🇱.
  /// Si no es bandera ISO (ej. 🕹️), devuelve null.
  static String? iso2FromFlagEmoji(String flagEmoji) {
    final runes = flagEmoji.runes.toList();
    if (runes.length < 2) return null;

    // Las banderas son 2 "Regional Indicator Symbols"
    final r0 = runes[0];
    final r1 = runes[1];

    const base = 0x1F1E6; // Regional Indicator Symbol Letter A
    final a = r0 - base;
    final b = r1 - base;

    if (a < 0 || a > 25 || b < 0 || b > 25) return null;

    return String.fromCharCode('A'.codeUnitAt(0) + a) +
        String.fromCharCode('A'.codeUnitAt(0) + b);
  }

  static String? _countryKey(CountryData c) {
    // Caso especial: tu "Simulator" no tiene bandera ISO
    final isSim = c.name == 'Simulator' ||
        c.icaoPrefixes.contains('SIM') ||
        c.registration.contains('SIM');

    if (isSim) return 'SIM';

    return iso2FromFlagEmoji(c.flagEmoji);
  }

  /// Intenta traducir con distintos nombres típicos de método para tu AppLocalizations.
  /// (Compila aunque tu clase use t(), tr() o translate()).
  static String _l10n(BuildContext context, String key) {
    final l = AppLocalizations.of(context);
    final dyn = l as dynamic;

    try {
      final v = dyn.t(key);
      if (v is String) return v;
    } catch (_) {}

    try {
      final v = dyn.tr(key);
      if (v is String) return v;
    } catch (_) {}

    try {
      final v = dyn.translate(key);
      if (v is String) return v;
    } catch (_) {}

    return key;
  }
}
