import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'app_colors.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? rightIconPath;
  final VoidCallback? onRightIconTap;
  final double height;

  const CustomAppBar({
    super.key,
    this.title = "",
    this.rightIconPath,
    this.onRightIconTap,
    this.height = 56.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Decoration bg = isDark
        ? const BoxDecoration(color: AppColors.blackDeep)
        : BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.teal3, AppColors.teal2],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          );

    final Color titleColor = Colors.white;
    final Color iconColor = isDark ? AppColors.teal5 : Colors.white;

    return Container(
      decoration: bg,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(
                  painter: GradientLinePainter(
                    strokeWidth: 2,
                    horizontalRatio: 0.8,
                  ),
                ),
              ),
              if (title.isNotEmpty)
                Center(
                  child: Text(
                    title.toUpperCase(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: titleColor,
                          fontSize: 15,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              if (rightIconPath != null)
                Positioned(
                  right:
                      8, // antes 20, compensamos porque ahora la caja es más grande
                  top: (height - 44) / 2, // centra la caja tocable
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Material(
                      color: Colors.transparent,
                      child: InkResponse(
                        radius: 24,
                        containedInkWell: true,
                        onTap: onRightIconTap ??
                            () {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              }
                            },
                        child: Center(
                          child: rightIconPath!.endsWith(".svg")
                              ? SvgPicture.asset(
                                  rightIconPath!,
                                  height: 25, // tamaño visual igual
                                  colorFilter: ColorFilter.mode(
                                      iconColor, BlendMode.srcIn),
                                )
                              : Image.asset(
                                  rightIconPath!,
                                  height: 28, // tamaño visual igual
                                  color: iconColor,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(height);
}

class GradientLinePainter extends CustomPainter {
  final double strokeWidth;
  final double horizontalRatio;
  final Color? startColor; // opcional override
  final Color? endColor; // opcional override

  const GradientLinePainter({
    this.strokeWidth = 2.0,
    this.horizontalRatio = 0.5,
    this.startColor,
    this.endColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final half = strokeWidth / 2;
    final topY = half;

    // Subimos la parte inferior un par de píxeles
    const double bottomOffset = 2.0;
    final double bottomY = size.height - half - bottomOffset;

    final midX = size.width * horizontalRatio;

    final path = Path()
      ..moveTo(half, topY)
      ..lineTo(midX, topY)
      ..lineTo(midX + (bottomY - topY), bottomY)
      ..lineTo(size.width - half, bottomY);

    final c1 = startColor ?? AppColors.teal4;
    final c2 = endColor ?? AppColors.teal5;

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [c1, c2],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant GradientLinePainter old) =>
      old.strokeWidth != strokeWidth ||
      old.horizontalRatio != horizontalRatio ||
      old.startColor != startColor ||
      old.endColor != endColor;
}
