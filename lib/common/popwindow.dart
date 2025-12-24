// lib/common/popwindow.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'app_colors.dart';

Future<void> showPopWindow({
  required BuildContext context,
  required String title,
  required List<Widget> children,
  bool barrierDismissible = false,
  double maxWidth = 370,
  EdgeInsets? insetPadding,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final barrier =
      isDark ? Colors.black.withOpacity(0.75) : Colors.white.withOpacity(0.75);

  return showDialog(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrier,
    builder: (ctx) {
      final vp = MediaQuery.of(ctx).viewPadding;
      final inset = insetPadding ??
          EdgeInsets.only(
            left: vp.left + 15,
            right: vp.right + 15,
            top: 0,
            bottom: 5,
          );

      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: inset,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: _PopCard(title: title, children: children),
          ),
        ),
      );
    },
  );
}

class _PopCard extends StatelessWidget {
  const _PopCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Fondo según tema
    final grad = isDark
        ? <Color>[AppColors.teal1, AppColors.teal2]
        : <Color>[Colors.white, Colors.white];

    // Borde según tema
    final borderColor = isDark
        ? Colors.white.withOpacity(0.50)
        : Colors.black.withOpacity(0.08);

    // Texto base según tema
    final baseTextColor = isDark
        ? AppColors.white
        : (theme.textTheme.bodyMedium?.color ?? Colors.black87);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: grad,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: baseTextColor),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppColors.teal3,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (children.isNotEmpty) const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}
