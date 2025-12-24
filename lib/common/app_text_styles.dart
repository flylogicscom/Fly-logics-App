import 'package:flutter/material.dart';

class AppTextStyles {
  AppTextStyles._();

  // Titulares
  static const TextStyle headline1 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle headline2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
  );

  /// Subtítulo (usado para textos secundarios destacados)
  static const TextStyle subtitle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  /// Título usado en contenedores/secciones
  /// Sin color fijo; tomará onSurface. Si quieres primario, aplica en uso:
  /// AppTextStyles.sectionTitle.copyWith(color: Theme.of(context).colorScheme.primary)
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );

  // Cuerpo
  static const TextStyle body = TextStyle(
    fontSize: 16,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontSize: 15,
  );

  static const TextStyle bodyBold = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
  );

  // Botones
  static const TextStyle buttonText = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );
}
