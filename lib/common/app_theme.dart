import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// Tema único oscuro de la app.
class AppTheme {
  AppTheme._();

  /// Tema oscuro base (único tema).
  static ThemeData get darkTheme => _buildDarkTheme();

  static ThemeData _buildDarkTheme() {
    const brightness = Brightness.dark;
    const background = AppColors.black;
    const surface = AppColors.darkSurface;
    const primary = AppColors.teal5;
    const secondary = AppColors.teal3;
    const textPrimary = Colors.white;
    const textSecondary = Colors.white;
    const divider = AppColors.grayDivider;
    const snackBarBg = AppColors.darkSurface;

    final colorScheme = ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      surface: surface,
      error: AppColors.error,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
    );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      canvasColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: primary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.headline2.copyWith(color: primary),
      ),
      textTheme: base.textTheme.copyWith(
        bodyLarge: AppTextStyles.body.copyWith(color: textPrimary),
        bodyMedium: AppTextStyles.body.copyWith(color: textPrimary),
        bodySmall: AppTextStyles.bodySecondary.copyWith(color: textSecondary),
        titleLarge: AppTextStyles.headline1.copyWith(color: textPrimary),
        titleMedium: AppTextStyles.headline2.copyWith(color: primary),
        titleSmall: AppTextStyles.sectionTitle.copyWith(color: primary),
        labelLarge: AppTextStyles.buttonText.copyWith(color: textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(
          color: textSecondary.withValues(alpha: 0.8),
        ),
        filled: false,
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: divider, width: 1),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: primary, width: 1.2),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: AppTextStyles.body.copyWith(color: textPrimary),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll<Color>(surface),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: snackBarBg,
        contentTextStyle: AppTextStyles.body.copyWith(
          color: textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStatePropertyAll<Color>(primary),
        checkColor: WidgetStatePropertyAll<Color>(
          Colors.black,
        ),
        side: BorderSide(color: primary, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll<Color>(primary),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? AppColors.teal4 : divider,
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStatePropertyAll<Color>(primary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll<Color>(secondary),
          foregroundColor: WidgetStatePropertyAll<Color>(textPrimary),
          textStyle: WidgetStatePropertyAll<TextStyle>(
            AppTextStyles.buttonText,
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          elevation: const WidgetStatePropertyAll<double>(0),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll<Color>(primary),
          textStyle: WidgetStatePropertyAll<TextStyle>(
            AppTextStyles.buttonText,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 1,
      ),
    );
  }
}
