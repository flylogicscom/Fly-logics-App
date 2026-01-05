// lib/common/button_styles.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class ButtonStyles {
  ButtonStyles._();

  // 1. Lista de pills
  static List<Widget> pillButtons({
    required BuildContext context,
    required List<String> labels,
    required List<VoidCallback> actions,
    List<Color>? colors,
  }) {
    return List.generate(labels.length, (i) {
      final color =
          (colors != null && i < colors.length) ? colors[i] : AppColors.teal5;
      return InkWell(
        onTap: actions[i],
        borderRadius: BorderRadius.circular(30),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(30),
          ),
          alignment: Alignment.center,
          child: Text(labels[i], style: AppTextStyles.buttonText),
        ),
      );
    });
  }

  // 2. Pill sólida
  static Widget pillButton({
    required String label,
    required VoidCallback onTap,
    Color color = AppColors.teal5,
    required BuildContext context,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
        ),
        alignment: Alignment.center,
        child: Text(
          label.toUpperCase(),
          style: AppTextStyles.buttonText.copyWith(color: AppColors.white),
        ),
      ),
    );
  }

  // 3. Pill info sin icon, ancho = contenido
  static Widget pillInfo({
    required String label,
    Color color = AppColors.teal3,
    VoidCallback? onTap,
  }) {
    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 15),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.teal2, AppColors.teal1],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: color, width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.teal3,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(color: AppColors.white),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

// 4. Pill add con gradiente
  static Widget pillAdd({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
    Widget? icon, // icono opcional
    List<Color>? gradientColors,
    Color borderColor = AppColors.teal3,
    double widthFactor = 0.6,
    double height = 38,
  }) {
    final List<Color> colors =
        gradientColors ?? const <Color>[AppColors.teal1, AppColors.teal2];

    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    icon,
                    const SizedBox(width: 10),
                  ] else ...[
                    const Icon(Icons.add, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.buttonText.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 5. Botón de menú
  static Widget menuButton({
    required String label,
    required VoidCallback onTap,
    List<Widget> icons = const [],
    List<Color> gradientColors = const [AppColors.teal1, AppColors.teal2],
    Color borderColor = AppColors.teal3,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withOpacity(0.15),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.body.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: icons
                  .take(3)
                  .map(
                    (icon) => Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: icon,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  static Widget pillCancelSave({
    required VoidCallback onCancel,
    required VoidCallback onSave,
    VoidCallback? onDelete,
    String cancelLabel = 'Cancel',
    String saveLabel = 'Save',
    String? deleteLabel,
    String cancelIcon = 'assets/icons/cancel.svg',
    String saveIcon = 'assets/icons/save.svg',
    String deleteIcon = 'assets/icons/erase.svg',
    double height = 42,
    double gap = 9,
    EdgeInsets margin = const EdgeInsets.symmetric(vertical: 20),
  }) {
    final hasDelete =
        onDelete != null && deleteLabel != null && deleteLabel.isNotEmpty;

    return Padding(
      padding: margin,
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 5 / 5,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fila superior: Cancel + Save
              Row(
                children: [
                  Expanded(
                    child: _pillAction(
                      label: cancelLabel,
                      iconAsset: cancelIcon,
                      color: AppColors.teal4,
                      onTap: onCancel,
                      height: height,
                    ),
                  ),
                  SizedBox(width: gap),
                  Expanded(
                    child: _pillAction(
                      label: saveLabel,
                      iconAsset: saveIcon,
                      color: AppColors.teal2,
                      onTap: onSave,
                      height: height,
                    ),
                  ),
                ],
              ),

              // Fila inferior: Delete centrado (opcional)
              if (hasDelete) ...[
                const SizedBox(height: 32),
                Align(
                  alignment: Alignment.center,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    child: _pillAction(
                      label: deleteLabel,
                      iconAsset: deleteIcon,
                      color: const Color(0xF8700000),
                      onTap: onDelete,
                      height: height,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Widget _pillAction({
    required String label,
    required String iconAsset,
    required Color color,
    required VoidCallback onTap,
    double height = 48,
  }) {
    return Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 25),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  iconAsset,
                  width: 15,
                  height: 15,
                  colorFilter: const ColorFilter.mode(
                    AppColors.white,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  label.toUpperCase(),
                  style:
                      AppTextStyles.buttonText.copyWith(color: AppColors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 7. Botón cuadrado "+"
  static Widget squareAddButton({
    required BuildContext context,
    required VoidCallback onTap,
    double size = 56,
    double radius = 14,
    Color? lightColor,
    Color? darkColor,
  }) {
    // Solo tema oscuro: priorizamos darkColor, luego lightColor, luego por defecto
    final Color bg = darkColor ?? lightColor ?? AppColors.teal2;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: const Center(
            child: Icon(
              Icons.add,
              color: AppColors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  // 8. infoButtonOne
  static Widget infoButtonOne({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
    String? leftIconAsset,
    bool? locked,
    String? rightIconAsset1,
    String? rightIconAsset2,
    Widget? rightIconWidget1,
    Widget? rightIconWidget2,
    VoidCallback? onRight1Tap,
    VoidCallback? onRight2Tap,
    List<Color>? lightGradient,
    List<Color>? darkGradient,
    double height = 58,
  }) {
    // Solo tema oscuro: priorizamos darkGradient, luego lightGradient
    final List<Color> colors = darkGradient ??
        lightGradient ??
        <Color>[AppColors.teal1, AppColors.teal2];

    const double boxSize = 36;
    const double iconSize = 20;
    const double buttonRadius = 10;
    final BorderRadius btnBR = BorderRadius.circular(buttonRadius);
    final BorderRadius iconBR = BorderRadius.circular(6);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: btnBR,
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            border: Border.all(color: AppColors.teal4, width: 1),
            borderRadius: btnBR,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 08, 0),
            child: Row(
              children: [
                // IZQUIERDA
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (leftIconAsset != null) ...[
                      SvgPicture.asset(
                        leftIconAsset,
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          AppColors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      label,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // DERECHA
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (locked != null)
                      Container(
                        width: boxSize,
                        height: boxSize,
                        decoration: BoxDecoration(
                          color: AppColors.teal2,
                          border: Border.all(color: AppColors.teal4, width: 1),
                          borderRadius: iconBR,
                        ),
                        child: Center(
                          child: Icon(
                            locked ? Icons.lock : Icons.lock_open,
                            size: iconSize,
                            color: AppColors.white,
                          ),
                        ),
                      )
                    else if (rightIconWidget1 != null)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onRight1Tap,
                        child: Container(
                          width: boxSize,
                          height: boxSize,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            border:
                                Border.all(color: AppColors.teal4, width: 2),
                            borderRadius: iconBR,
                          ),
                          child: Center(child: rightIconWidget1),
                        ),
                      )
                    else if (rightIconAsset1 != null)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onRight1Tap,
                        child: Container(
                          width: boxSize,
                          height: boxSize,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            border:
                                Border.all(color: AppColors.teal4, width: 2),
                            borderRadius: iconBR,
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              rightIconAsset1,
                              width: iconSize,
                              height: iconSize,
                              colorFilter: const ColorFilter.mode(
                                AppColors.teal2,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (rightIconWidget2 != null || rightIconAsset2 != null)
                      const SizedBox(width: 8),
                    if (rightIconWidget2 != null)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onRight2Tap,
                        child: Container(
                          width: boxSize,
                          height: boxSize,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            border:
                                Border.all(color: AppColors.teal4, width: 2),
                            borderRadius: iconBR,
                          ),
                          child: Center(child: rightIconWidget2),
                        ),
                      )
                    else if (rightIconAsset2 != null)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onRight2Tap,
                        child: Container(
                          width: boxSize,
                          height: boxSize,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            border:
                                Border.all(color: AppColors.teal4, width: 2),
                            borderRadius: iconBR,
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              rightIconAsset2,
                              width: iconSize,
                              height: iconSize,
                              colorFilter: const ColorFilter.mode(
                                AppColors.teal2,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

// 9. infoButtonTwo: código + autoridad + caducidad + semáforo
  static Widget infoButtonTwo({
    required BuildContext context,
    required String code,
    required VoidCallback onTap,
    String? authorityLabel,
    String? authorityValue,
    String? authorityFlagEmoji,
    String? expiryLabel,
    String? expiryText,
    Color? expiryStatusColor,
    Color pillColor = AppColors.teal3,
    double height = 65,
    EdgeInsets margin = const EdgeInsets.symmetric(vertical: 4),
    EdgeInsets contentPadding =
        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    List<Color>? lightGradient,
    List<Color>? darkGradient,
  }) {
    // Solo tema oscuro: priorizamos darkGradient, luego lightGradient
    final List<Color> colors = darkGradient ??
        lightGradient ??
        <Color>[AppColors.teal2, AppColors.teal1];

    const double borderRadiusValue = 12;
    final BorderRadius borderRadius = BorderRadius.circular(borderRadiusValue);

    // títulos
    final TextStyle labelStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.teal5,
    );

    // valores
    final TextStyle valueStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Colors.white.withOpacity(0.95),
    );

    final String authorityText = (authorityValue ?? '').trim();
    final String flag = (authorityFlagEmoji ?? '').trim();
    final String expiryValue =
        (expiryText ?? '').trim().isEmpty ? '-' : (expiryText ?? '').trim();
    final Color statusColor = expiryStatusColor ?? Colors.white38;

    return Padding(
      padding: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Ink(
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: borderRadius,
              border: Border.all(color: AppColors.teal3, width: 1),
            ),
            child: Padding(
              padding: contentPadding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // IZQUIERDA: pill de código
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7.0, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: pillColor,
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(color: Colors.white, width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 2,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        code,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // DERECHA: bloques + separador vertical + semáforo
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final bool compact = c.maxWidth < 260;

                        final authorityBlock = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if ((authorityLabel ?? '').trim().isNotEmpty)
                              Text(
                                authorityLabel!.trim(),
                                style: labelStyle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: 2),
                            if (authorityText.isNotEmpty || flag.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (flag.isNotEmpty)
                                    Text(flag,
                                        style: const TextStyle(fontSize: 16)),
                                  if (flag.isNotEmpty &&
                                      authorityText.isNotEmpty)
                                    const SizedBox(width: 4),
                                  if (authorityText.isNotEmpty)
                                    Flexible(
                                      child: Text(
                                        authorityText,
                                        style: valueStyle,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        softWrap: false,
                                      ),
                                    ),
                                ],
                              )
                            else
                              Text('-', style: valueStyle),
                          ],
                        );

                        final expiryBlock = Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if ((expiryLabel ?? '').trim().isNotEmpty)
                              Text(
                                expiryLabel!.trim(),
                                style: labelStyle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                              ),
                            const SizedBox(height: 2),
                            Text(
                              expiryValue,
                              style: valueStyle,
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          ],
                        );

                        // ✅ Línea vertical ENTRE BLOQUE COMPLETO Autoridad y Caducidad
                        final divider = VerticalDivider(
                          width: compact ? 18 : 22,
                          thickness: 1,
                          color: Colors.white.withOpacity(0.55),
                          indent: 6,
                          endIndent: 6,
                        );

                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 4, child: authorityBlock),
                              divider,
                              Expanded(flex: 6, child: expiryBlock),
                              const SizedBox(width: 10),
                              Align(
                                alignment: Alignment.center,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.7),
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 10. aircraftButton: ficha de aeronave/simulador
  static Widget aircraftButton({
    required BuildContext context,
    required VoidCallback onTap,
    required String registration,
    required String identifier,
    required String countryName,
    required String countryFlagEmoji,
    required String typeLabel,
    required String makeAndModel,
    List<String> tags = const <String>[],
    bool isSimulator = false,

    // NUEVO: info de tipos para color y orden
    List<String>? typeCodes, // ej: ['SE', 'OTHER']
    List<String>? typeTitles, // ej: ['Monomotor', 'Militar']

    // Font sizes
    double registrationFontSize = 20,
    double identifierFontSize = 16,
    double typeFontSize = 16,
    double tagFontSize = 10,

    // Spacing
    double verticalSpacing = 2,

    // Pill colors (puedes sobreescribirlos si quieres)
    Color? registrationPillColor,
    Color? aircraftPillColor,
    Color? simulatorPillColor,
    EdgeInsets margin = const EdgeInsets.symmetric(vertical: 4),
    EdgeInsets contentPadding =
        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),

    // Extra data (opcionales, para nuevo layout)
    String? owner,
    String? simulatorCompany,
    String? simulatorLevel,

    // Ocultar fila "Marca y modelo / Propietario" (solo aeronave)
    bool hideMakeOwnerRow = false,
  }) {
    final l = AppLocalizations.of(context);

    // ---- estilos base -------------------------------------------------------
    final TextStyle registrationStyle = AppTextStyles.subtitle.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: registrationFontSize,
      color: Colors.white,
    );

    final TextStyle valueMainStyle = AppTextStyles.subtitle.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: identifierFontSize,
      color: Colors.white,
    );

    final TextStyle labelStyle = AppTextStyles.body.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.teal5,
      letterSpacing: 0.4,
    );

    final TextStyle typeText = AppTextStyles.body.copyWith(
      fontSize: typeFontSize,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    );

    final TextStyle tagStyle = AppTextStyles.body.copyWith(
      fontSize: tagFontSize,
      color: Colors.white,
    );

    // ---- helper colores por código -----------------------------------------
    Color typeColorForCode(String code) {
      switch (code.toUpperCase()) {
        case 'SE':
          return AppColors.se;
        case 'ME':
          return AppColors.me;
        case 'TP':
          return AppColors.tp;
        case 'TJ':
          return AppColors.tj;
        case 'LSA':
          return AppColors.lsa;
        case 'HELI':
          return AppColors.he;
        case 'GLID':
          return AppColors.pl;
        case 'OTHER':
          return AppColors.ot;
        case 'SIM':
          return AppColors.sim;
        default:
          return AppColors.teal4;
      }
    }

    // prioridad: 1 SIM, 2 OTHER, 3 LSA, 4 TP, 5 TJ, 6 ME, 7 SE, 8 HELI, 9 GLID
    int priorityForCode(String code) {
      switch (code.toUpperCase()) {
        case 'SIM':
          return 1;
        case 'OTHER':
          return 2;
        case 'LSA':
          return 3;
        case 'TP':
          return 4;
        case 'TJ':
          return 5;
        case 'ME':
          return 6;
        case 'SE':
          return 7;
        case 'HELI':
          return 8;
        case 'GLID':
          return 9;
        default:
          return 100; // desconocidos al final
      }
    }

    // ---- helper pill genérico ----------------------------------------------
    Widget buildLabelPill(
      String value,
      TextStyle baseStyle, {
      Color? customColor,
    }) {
      final v = value.trim();
      if (v.isEmpty) {
        return Text(
          '—',
          style: baseStyle,
          overflow: TextOverflow.ellipsis,
        );
      }
      final Color bg = customColor ?? Colors.white.withOpacity(0.18);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: Colors.white,
            width: 0.8,
          ),
        ),
        child: Text(
          v,
          style: baseStyle.copyWith(fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    // ---- tags (línea única con "...") --------------------------------------
    Widget buildTagsRow() {
      if (tags.isEmpty) {
        return const SizedBox.shrink();
      }

      Widget buildTagChip(String text) {
        return Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(
            horizontal: 5,
            vertical: 1,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: Colors.white,
              width: 0.8,
            ),
          ),
          child: Text(
            text,
            style: tagStyle,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }

      Widget buildEllipsisChip() {
        return Container(
          width: 18,
          height: 18,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: AppColors.teal3,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Colors.white,
              width: 0.8,
            ),
          ),
          child: Center(
            child: Text(
              '...',
              style: tagStyle.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          if (!maxWidth.isFinite) {
            return Row(
              children: [
                for (final tag in tags.where((t) => t.trim().isNotEmpty))
                  buildTagChip(tag.trim()),
              ],
            );
          }

          const double ellipsisWidth = 18 + 6;

          final textPainter = TextPainter(
            textDirection: TextDirection.ltr,
            maxLines: 1,
          );

          double measureTagWidth(String text) {
            textPainter.text = TextSpan(text: text, style: tagStyle);
            textPainter.layout();
            return textPainter.width + 10 + 1.6 + 6;
          }

          final List<Widget> chips = [];
          double usedWidth = 0;

          final cleanTags =
              tags.map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

          for (int i = 0; i < cleanTags.length; i++) {
            final String tag = cleanTags[i];
            final bool isLastTag = i == cleanTags.length - 1;
            final double chipWidth = measureTagWidth(tag);
            final bool hasRemaining = !isLastTag;

            final double reserved = hasRemaining ? ellipsisWidth : 0;

            if (usedWidth + chipWidth + reserved > maxWidth) {
              if (chips.isEmpty) {
                chips.add(buildEllipsisChip());
              } else {
                chips.add(buildEllipsisChip());
              }
              break;
            } else {
              chips.add(buildTagChip(tag));
              usedWidth += chipWidth;

              if (hasRemaining && usedWidth + ellipsisWidth > maxWidth) {
                chips.add(buildEllipsisChip());
                break;
              }
            }
          }

          return Row(children: chips);
        },
      );
    }

    // ---- datos normalizados -------------------------------------------------
    final String regText =
        registration.trim().isEmpty ? '—' : registration.trim();

    final List<String> countryParts = <String>[];
    if (countryFlagEmoji.trim().isNotEmpty) {
      countryParts.add(countryFlagEmoji.trim());
    }
    if (countryName.trim().isNotEmpty) {
      countryParts.add(countryName.trim());
    }
    final String countryText = countryParts.join(' ');

    // typeLabel -> etiquetas separadas por "|" o coma (fallback)
    List<String> typeTitlesList;
    if (typeTitles != null && typeTitles.isNotEmpty) {
      typeTitlesList =
          typeTitles.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    } else {
      typeTitlesList = typeLabel
          .split(RegExp(r'[|,]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    List<String> typeCodesList =
        (typeCodes ?? const <String>[]).map((e) => e.trim()).toList();

    // Si faltan códigos, los rellenamos (SIM si es simulador, sino vacío)
    if (typeCodesList.length < typeTitlesList.length) {
      final missing = typeTitlesList.length - typeCodesList.length;
      final padCode = isSimulator ? 'SIM' : '';
      typeCodesList = [
        ...typeCodesList,
        ...List<String>.filled(missing, padCode),
      ];
    }

    final String makeModelText =
        makeAndModel.trim().isEmpty ? '—' : makeAndModel.trim();
    final String ownerText = (owner ?? '').trim();
    final String identifierText = identifier.trim();

    final String simulatorCompanyText = (simulatorCompany ?? '').trim();
    final String simulatorLevelText = (simulatorLevel ?? '').trim();

    // ---- color base según prioridad de tipos -------------------------------
    final Color regPillColor =
        registrationPillColor ?? AppColors.teal3.withOpacity(0.9);

    String baseTypeCode = '';
    if (typeCodesList.isNotEmpty) {
      baseTypeCode = typeCodesList.reduce(
        (best, c) => priorityForCode(c) < priorityForCode(best) ? c : best,
      );
    } else if (isSimulator) {
      baseTypeCode = 'SIM';
    }

    final Color defaultBaseColor = typeColorForCode(baseTypeCode);
    final Color cardBaseColor = isSimulator
        ? (simulatorPillColor ?? defaultBaseColor)
        : (aircraftPillColor ?? defaultBaseColor);

    Color chipColorForIndex(int index) {
      final String code =
          index < typeCodesList.length ? typeCodesList[index] : baseTypeCode;
      final upper = code.toUpperCase();
      final def = typeColorForCode(code);
      if (upper == 'SIM') return simulatorPillColor ?? def;
      return aircraftPillColor ?? def;
    }

    // ---- orden de chips por prioridad --------------------------------------
    final List<int> chipOrder = () {
      final len = typeTitlesList.length;
      final idx = List<int>.generate(len, (i) => i);
      idx.sort((a, b) {
        final codeA = a < typeCodesList.length ? typeCodesList[a] : '';
        final codeB = b < typeCodesList.length ? typeCodesList[b] : '';
        final pa = priorityForCode(codeA);
        final pb = priorityForCode(codeB);
        if (pa != pb) return pa.compareTo(pb);
        return a.compareTo(b);
      });
      return idx;
    }();

    return Padding(
      padding: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  cardBaseColor,
                  cardBaseColor.withOpacity(0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: AppColors.teal3.withOpacity(0.6),
                width: 1.2,
              ),
            ),
            child: Padding(
              padding: contentPadding,
              child: isSimulator
                  // ================== SIMULATOR CARD ==================
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // -------- SIMULATOR TOP ROW --------
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Pill "SIMULADOR"
                            buildLabelPill(
                              l.t("aircraft_type_simulator_title"),
                              registrationStyle,
                              customColor: chipColorForIndex(0),
                            ),
                            const SizedBox(width: 12),
                            // Simulated model title + value
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    l.t("aircraft_sim_model_label"),
                                    style: labelStyle,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    makeModelText,
                                    style: valueMainStyle,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: verticalSpacing),

                        // -------- TAGS --------
                        buildTagsRow(),

                        // -------- DIVISOR --------
                        Container(
                          height: 0.5,
                          margin: EdgeInsets.symmetric(
                            vertical: verticalSpacing + 2,
                          ),
                          color: Colors.white.withOpacity(0.5),
                        ),

                        // -------- BOTTOM: COMPANY / LEVEL --------
                        Row(
                          children: [
                            // Company
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    l.t("aircraft_sim_company_label"),
                                    style: labelStyle,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    simulatorCompanyText.isEmpty
                                        ? '—'
                                        : simulatorCompanyText,
                                    style: valueMainStyle,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),

                            // Vertical divider
                            Container(
                              width: 0.5,
                              height: 28,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              color: Colors.white.withOpacity(0.5),
                            ),

                            // Level
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    l.t("aircraft_sim_level_label"),
                                    style: labelStyle,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    simulatorLevelText.isEmpty
                                        ? '—'
                                        : simulatorLevelText,
                                    style: valueMainStyle,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  // ================== AIRCRAFT CARD ==================
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // -------- AIRCRAFT TOP ROW --------
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Registration pill
                            Expanded(
                              flex: 4,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: buildLabelPill(
                                  regText,
                                  registrationStyle,
                                  customColor: regPillColor,
                                ),
                              ),
                            ),

                            // Identifier
                            Expanded(
                              flex: 3,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    l.t("aircraft_identifier_label"),
                                    style: labelStyle,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    identifierText.isEmpty
                                        ? '—'
                                        : identifierText,
                                    style: valueMainStyle,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),

                            // Separador vertical
                            Container(
                              width: 0.5,
                              height: 35,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              color: Colors.white.withOpacity(0.5),
                            ),

                            // Country
                            Expanded(
                              flex: 3,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l.t("aircraft_country_label"),
                                    style: labelStyle,
                                    textAlign: TextAlign.left,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    countryText.isEmpty ? '—' : countryText,
                                    style: valueMainStyle,
                                    textAlign: TextAlign.left,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: verticalSpacing),

                        // -------- TYPE PILLS (individuales en orden de prioridad) --------
                        if (typeTitlesList.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              for (final i in chipOrder)
                                if (i < typeTitlesList.length)
                                  buildLabelPill(
                                    typeTitlesList[i],
                                    typeText,
                                    customColor: chipColorForIndex(i),
                                  ),
                            ],
                          ),

                        SizedBox(height: verticalSpacing),

                        // -------- TAGS --------
                        buildTagsRow(),

                        if (!hideMakeOwnerRow) ...[
                          // -------- DIVISOR --------
                          Container(
                            height: 0.5,
                            margin: EdgeInsets.symmetric(
                              vertical: verticalSpacing + 2,
                            ),
                            color: Colors.white.withOpacity(0.5),
                          ),

                          // -------- BOTTOM: MAKE & MODEL / OWNER --------
                          Row(
                            children: [
                              // Make & model
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      l.t("aircraft_make_model_label"),
                                      style: labelStyle,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      makeModelText,
                                      style: valueMainStyle,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              // Vertical divider
                              Container(
                                width: 0.5,
                                height: 35,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                color: Colors.white.withOpacity(0.5),
                              ),

                              // Owner
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      l.t("aircraft_owner_label"),
                                      style: labelStyle,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      ownerText.isEmpty ? '—' : ownerText,
                                      style: valueMainStyle,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
