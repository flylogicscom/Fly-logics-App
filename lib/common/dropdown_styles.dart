// lib/common/dropdown_styles.dart
import 'package:flutter/material.dart';
import 'app_text_styles.dart';

class DropdownStyles {
  DropdownStyles._();

  // Encabezado reutilizable (usa colores del tema)
  static Widget headerRow({
    required BuildContext context,
    String? prefixText,
    required String label,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        if (prefixText != null && prefixText.isNotEmpty) ...[
          Text(
            '$prefixText ',
            style: AppTextStyles.bodyBold.copyWith(
              color: cs.primary,
              fontSize: 14,
            ),
          ),
        ],
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.copyWith(
              color: cs.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // Dropdown tipo “tile” adaptado a tema claro/oscuro
  static DropdownButtonFormField<T> tile<T>({
    required BuildContext context,
    required T? value,
    required List<T> options,
    required ValueChanged<T?> onChanged,
    String Function(T v)? toLabel,
    String? prefixText,
    String? hintText,
    String? Function(T?)? validator,
    Widget? prefixIcon,
  }) {
    final cs = Theme.of(context).colorScheme;
    final toStr = toLabel ?? (T v) => v.toString();

    return DropdownButtonFormField<T>(
      // ignore: deprecated_member_use
      value: value,
      isExpanded: true,
      iconEnabledColor: cs.onSurface,
      dropdownColor: cs.surface,
      style: AppTextStyles.body.copyWith(
        color: cs.onSurface,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        labelText: null,
        hintText: hintText,
        prefixIcon: prefixIcon,
        filled: true,
        fillColor: cs.surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: cs.outline,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: cs.primary,
            width: 1,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      items: options
          .map(
            (e) => DropdownMenuItem<T>(
              value: e,
              child: Text(
                toStr(e),
                style: AppTextStyles.body.copyWith(
                  color: cs.onSurface,
                  fontSize: 16,
                ),
              ),
            ),
          )
          .toList(),
      selectedItemBuilder: (ctx) {
        final items = options.isEmpty ? <T?>[null] : options.cast<T?>();
        return items.map((opt) {
          final label = (opt == null) ? (hintText ?? '') : toStr(opt as T);
          return headerRow(
            context: context,
            prefixText: prefixText,
            label: label,
          );
        }).toList();
      },
      onChanged: onChanged,
      validator: validator,
    );
  }

  // Variante de formulario adaptada a tema claro/oscuro
  static DropdownButtonFormField<T> formField<T>({
    required BuildContext context,
    required String label,
    required T? value,
    required List<T> options,
    required ValueChanged<T?> onChanged,
    String Function(T v)? toLabel,
    String? hintText,
    String? Function(T?)? validator,
    Widget? prefixIcon,
  }) {
    final cs = Theme.of(context).colorScheme;
    final toStr = toLabel ?? (T v) => v.toString();

    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      dropdownColor: cs.surface,
      iconEnabledColor: cs.onSurfaceVariant,
      style: AppTextStyles.body.copyWith(
        color: cs.onSurface,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: prefixIcon,
      ),
      items: options
          .map(
            (e) => DropdownMenuItem<T>(
              value: e,
              child: Text(
                toStr(e),
                style: AppTextStyles.body.copyWith(
                  color: cs.onSurface,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }
}
