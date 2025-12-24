import 'package:flutter/services.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  const UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    if (upper == newValue.text) return newValue;

    final base = newValue.selection.baseOffset;
    final extent = newValue.selection.extentOffset;

    return newValue.copyWith(
      text: upper,
      selection: TextSelection(
        baseOffset: base.clamp(0, upper.length),
        extentOffset: extent.clamp(0, upper.length),
      ),
      composing: TextRange.empty,
    );
  }
}

class TitleCaseTextFormatter extends TextInputFormatter {
  const TitleCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = _toTitleCase(newValue.text);
    if (formatted == newValue.text) return newValue;

    final diff = formatted.length - newValue.text.length;
    final base =
        (newValue.selection.baseOffset + diff).clamp(0, formatted.length);
    final extent =
        (newValue.selection.extentOffset + diff).clamp(0, formatted.length);

    return newValue.copyWith(
      text: formatted,
      selection: TextSelection(baseOffset: base, extentOffset: extent),
      composing: TextRange.empty,
    );
  }

  String _toTitleCase(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return '';

    // Normaliza espacios múltiples a uno
    final words = raw.split(RegExp(r'\s+'));

    final out = <String>[];
    for (final w in words) {
      if (w.isEmpty) continue;

      // Soporte para palabras con guiones: "juan-pablo"
      final parts = w.split('-');
      final partsOut = parts.map((p) {
        if (p.isEmpty) return p;

        // Si no hay letras, no tocar
        if (!RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(p)) return p;

        final lower = p.toLowerCase();
        final first = lower.substring(0, 1).toUpperCase();
        final rest = lower.length > 1 ? lower.substring(1) : '';
        return '$first$rest';
      }).toList();

      out.add(partsOut.join('-'));
    }

    return out.join(' ');
  }
}
