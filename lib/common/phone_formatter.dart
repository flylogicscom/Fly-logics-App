import 'package:flutter/services.dart';
// ignore: unused_import
import 'package:characters/characters.dart';
import 'package:fly_logicd_logbook_app/utils/country_data.dart';

/// Normaliza un prefijo a forma "+NNN".
String _normalizePrefix(String s) {
  var x = s.trim();
  if (!x.startsWith('+')) x = '+$x';
  return x;
}

/// Mapa bandera → prefijo principal (sin Simulator).
final Map<String, String> _flagToMainPhoneCode = {
  for (final c in allCountryData)
    if (c.name != 'Simulator' &&
        c.flagEmoji.trim().isNotEmpty &&
        c.phoneCode.isNotEmpty &&
        c.phoneCode.first.trim().isNotEmpty)
      c.flagEmoji: _normalizePrefix(c.phoneCode.first.trim()),
};

/// Mapa prefijo → CountryData (todos los prefijos conocidos, sin Simulator).
final Map<String, CountryData> _prefixToCountry = {
  for (final c in allCountryData)
    if (c.name != 'Simulator')
      for (final raw in c.phoneCode)
        if (raw.trim().isNotEmpty) _normalizePrefix(raw.trim()): c,
};

String? phoneCodeForFlag(String flagEmoji) => _flagToMainPhoneCode[flagEmoji];

String _sanitize(String input) {
  final t = input.trim();
  if (t.isEmpty) return '';
  final hasPlus = t.startsWith('+');
  final digits = t.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return hasPlus ? '+' : '';
  return hasPlus ? '+$digits' : '+$digits';
}

/// Agrupa dígitos de derecha a izquierda en bloques de 4.
String _groupFromRight(String digits) {
  if (digits.isEmpty) return '';
  final groups = <String>[];
  var current = '';
  for (var i = digits.length - 1; i >= 0; i--) {
    current = digits[i] + current;
    if (current.length == 4) {
      groups.insert(0, current);
      current = '';
    }
  }
  if (current.isNotEmpty) {
    groups.insert(0, current);
  }
  return groups.join(' ');
}

/// Formato visual:
/// - NANP (+1…):
///    Entrada: +1XXXrest
///    Salida: "(+1-XXX) XXXX XXXX"
///    *Si +1XXX existe en country_data → territorio NANP.
///    *Si +1XXX no existe → se trata como USA igual, mismo formato.
/// - Otros códigos:
///    "(+CC...) XXXX XXXX" agrupando de 4 en 4 desde la derecha.
/// Si no se reconoce prefijo, deja "+dígitos" sin decorar.
String formatPhone(String input) {
  final clean = _sanitize(input);
  if (clean.isEmpty) return '';
  if (!clean.startsWith('+')) return clean;

  final digits = clean.substring(1);
  if (digits.isEmpty) return '+';

  // NANP
  if (digits[0] == '1') {
    if (digits.length < 4) {
      // Deja escribir hasta tener +1XXX completo.
      return '+$digits';
    }
    final area = digits.substring(1, 4);
    final rest = digits.substring(4);
    final tail = _groupFromRight(rest);
    return '(+1-$area)${tail.isNotEmpty ? ' $tail' : ''}';
  }

  // Buscar prefijo internacional conocido (más largo primero)
  String? match;
  for (var len = digits.length; len >= 1; len--) {
    final cand = '+${digits.substring(0, len)}';
    if (_prefixToCountry.containsKey(cand)) {
      match = cand;
      break;
    }
  }

  if (match == null) {
    // Prefijo no reconocido, no aplicar paréntesis/espacios.
    return '+$digits';
  }

  final rest = digits.substring(match.length - 1);
  final tail = _groupFromRight(rest);
  return '($match)${tail.isNotEmpty ? ' $tail' : ''}';
}

/// Mantiene compatibilidad con código existente.
String formatearTelefonoInternacional(String input) => formatPhone(input);

/// Infieren bandera según número:
/// - NANP: +1XXX en mapa → bandera territorio; si no → 🇺🇸
/// - Otros: prefijo más largo conocido.
String? inferPhoneFlag(String input) {
  final t = input.trim();
  if (t.isEmpty) return null;

  final hasPlus = t.startsWith('+');
  final digits = t.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;

  final normalized = (hasPlus ? '+' : '+') + digits;
  final body = normalized.substring(1);
  if (body.isEmpty) return null;

  // NANP
  if (body[0] == '1') {
    if (body.length < 4) return null;
    final area = body.substring(1, 4);
    final cand = '+1$area';
    final territory = _prefixToCountry[cand];
    if (territory != null) return territory.flagEmoji;
    return '🇺🇸';
  }

  // Otros
  for (var len = body.length; len >= 1; len--) {
    final cand = '+${body.substring(0, len)}';
    final c = _prefixToCountry[cand];
    if (c != null) return c.flagEmoji;
  }

  return null;
}

/// Formatter que aplica `formatPhone`.
/// La bandera se muestra en la UI usando `inferPhoneFlag`.
class PhoneFormatter extends TextInputFormatter {
  const PhoneFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = formatPhone(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
