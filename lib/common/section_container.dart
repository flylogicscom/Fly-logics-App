// lib/common/section_container.dart

import 'package:flutter/material.dart';
import 'package:fly_logicd_logbook_app/common/app_colors.dart';
import 'package:fly_logicd_logbook_app/common/app_text_styles.dart';

/// Contenedor de sección base sin líneas ni divisores internos.
class FLSection extends StatelessWidget {
  const FLSection({
    super.key,
    this.title,
    required this.children,
    this.margin = const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    this.padding = const EdgeInsets.all(12),
  });

  final String? title;
  final List<Widget> children;
  final EdgeInsets margin;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    // Fondo: respeta tema. En oscuro mantenemos degradado teal.
    final List<Color> bgColors = isDark
        ? <Color>[AppColors.teal1, AppColors.teal2]
        : <Color>[colorScheme.surface, colorScheme.surface];

    // Borde basado en tema.
    final Color borderColor = isDark
        ? AppColors.teal5.withOpacity(0.40)
        : colorScheme.primary.withOpacity(0.90);

    // Color del título de la sección.
    final Color titleColor = isDark
        ? colorScheme.onSurface // típico blanco en dark
        : colorScheme.primary; // acento teal en light

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: bgColors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: AppTextStyles.headline1.copyWith(color: titleColor),
            ),
            const SizedBox(height: 4),
          ],
          ...children,
        ],
      ),
    );
  }
}

/// Alias de FLSection para compatibilidad.
class SectionContainer extends FLSection {
  const SectionContainer({
    super.key,
    super.title,
    required super.children,
    super.margin,
    super.padding,
  });
}

/// Título interno de elemento, con línea arriba y abajo.
class SectionItemTitle extends StatelessWidget {
  const SectionItemTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final Color lineColor = colorScheme.primary;
    final Color textColor = colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // línea superior
        Container(
          height: 1,
          decoration: BoxDecoration(
            color: lineColor,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: AppTextStyles.subtitle.copyWith(color: textColor),
        ),
        const SizedBox(height: 2),
        // línea inferior
        Container(
          height: 1,
          decoration: BoxDecoration(
            color: lineColor,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}
