import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fly_logicd_logbook_app/features/settings/settings_page.dart';
import 'package:fly_logicd_logbook_app/features/logs/logs_page.dart';
import 'package:fly_logicd_logbook_app/features/shop/shop_page.dart';
import 'package:fly_logicd_logbook_app/features/expenses/expenses_page.dart';
import 'package:fly_logicd_logbook_app/features/newflight/newflight.dart';
import 'package:fly_logicd_logbook_app/features/profile/personal_data.dart';
import 'package:fly_logicd_logbook_app/features/documents/documents.dart';
import 'package:fly_logicd_logbook_app/features/instructions/instructions_page.dart';
import 'package:fly_logicd_logbook_app/features/airplanes/airplaneslist.dart';
import 'package:fly_logicd_logbook_app/features/dashboard/dashboard_page.dart';
import 'package:fly_logicd_logbook_app/features/reports/annual_report_page.dart';
import 'package:fly_logicd_logbook_app/features/reports/aircraft_report_page.dart';
import 'package:fly_logicd_logbook_app/features/amendments/amendments_page.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';
import 'package:fly_logicd_logbook_app/common/app_colors.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    final locale = Localizations.localeOf(context).languageCode;
    final String logoPath = switch (locale) {
      'es' => "assets/background/backgroundes.png",
      'pt' => "assets/background/backgroundpt.png",
      _ => "assets/background/backgrounden.png",
    };

    // Fondo siempre oscuro
    const BoxDecoration bgDecoration = BoxDecoration(
      gradient: LinearGradient(
        colors: [AppColors.blackDeep, AppColors.black],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );

    return Scaffold(
      appBar: const HomeAppBar(),
      backgroundColor: AppColors.blackDeep,
      body: Container(
        decoration: bgDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              // Más separación desde el AppBar y márgenes laterales claros
              padding: const EdgeInsets.fromLTRB(10, 50, 10, 0),
              child: _HomeLocaleCarousel(
                logoPath: logoPath,
                locale: locale,
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: GridView.count(
                  crossAxisCount: 2,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 3.5,
                  shrinkWrap: true,
                  children: [
                    _MenuButton(
                      title: localizations.t("personal_data"),
                      isLeft: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PersonalData()),
                      ),
                    ),
                    _MenuButton(
                      title: localizations.t("documents"),
                      isLeft: false,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DocumentsPage(),
                        ),
                      ),
                    ),
                    _MenuButton(
                      title: localizations.t("instructions"),
                      isLeft: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const InstructionsPage(),
                        ),
                      ),
                    ),
                    _MenuButton(
                      title: localizations.t("airplanes"),
                      isLeft: false,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AirplanesList(),
                        ),
                      ),
                    ),
                    _MenuButton(
                      title: localizations.t("dashboard"),
                      isLeft: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DashboardPage(),
                        ),
                      ),
                    ),
                    _MenuButton(
                      title: localizations.t("annual_report"),
                      isLeft: false,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AnnualReportPage(),
                        ),
                      ),
                    ),
                    _MenuButton(
                      title: localizations.t("aircraft_report"),
                      isLeft: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AircraftReportPage(),
                        ),
                      ),
                    ),
                    _MenuButton(
                      title: localizations.t("amendments"),
                      isLeft: false,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AmendmentsPage(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomBar(),
    );
  }
}

class _HomeLocaleCarousel extends StatefulWidget {
  final String logoPath;
  final String locale;

  const _HomeLocaleCarousel({
    required this.logoPath,
    required this.locale,
  });

  @override
  State<_HomeLocaleCarousel> createState() => _HomeLocaleCarouselState();
}

class _HomeLocaleCarouselState extends State<_HomeLocaleCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;

  List<_HomeSlideData> get _slides {
    return List<_HomeSlideData>.generate(
      3,
      (_) => _HomeSlideData(imageAsset: widget.logoPath),
    );
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = _slides;

    // Colores fijos estilo oscuro
    const Color activeColor = AppColors.teal4;
    const Color inactiveColor = AppColors.teal2;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _pageController,
            itemCount: slides.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final slide = slides[index];
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      slide.imageAsset,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            slides.length,
            (index) {
              final bool isActive = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 12 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive ? activeColor : inactiveColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HomeSlideData {
  final String imageAsset;

  const _HomeSlideData({
    required this.imageAsset,
  });
}

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final double height;
  const HomeAppBar({super.key, this.height = 56.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.blackDeep,
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
                    horizontalRatio: 0.75,
                  ),
                ),
              ),
              Center(
                child: Image.asset(
                  "assets/icons/logoflname.png",
                  height: 35,
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                right: 25,
                top: (56 - 28) / 2,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsPage(),
                      ),
                    );
                  },
                  child: SvgPicture.asset(
                    "assets/icons/option.svg",
                    height: 23,
                    colorFilter: const ColorFilter.mode(
                      AppColors.teal4,
                      BlendMode.srcIn,
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

class _MenuButton extends StatelessWidget {
  final String title;
  final bool isLeft;
  final VoidCallback onTap;
  const _MenuButton({
    required this.title,
    required this.isLeft,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final gradientColors = isLeft
        ? [AppColors.teal2, AppColors.teal3]
        : [AppColors.teal3, AppColors.teal2];

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: AppColors.teal4, width: 1),
        ),
        child: Center(
          child: Text(
            title.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class CustomBottomBar extends StatelessWidget {
  const CustomBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    // Colores fijos estilo oscuro
    const Color iconColor = Colors.white;
    const Color labelColor = AppColors.teal4;

    return Container(
      height: 75,
      decoration: const BoxDecoration(color: AppColors.black),
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(
              painter: GradientLinePainter(
                strokeWidth: 2,
                horizontalRatio: 0.69,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _BottomBarItem(
                  iconPath: "assets/icons/logbooks.svg",
                  label: localizations.t("logs"),
                  iconColor: iconColor,
                  labelColor: labelColor,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LogsPage()),
                  ),
                ),
              ),
              Expanded(
                child: _BottomBarItem(
                  iconPath: "assets/icons/internet.svg",
                  label: localizations.t("visit_web"),
                  iconColor: iconColor,
                  labelColor: labelColor,
                  onTap: () async {
                    final url = Uri.parse("https://www.fly-logics.com");
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    }
                  },
                ),
              ),
              Expanded(
                child: _BottomBarItem(
                  iconPath: "assets/icons/shop.svg",
                  label: localizations.t("shop"),
                  iconColor: iconColor,
                  labelColor: labelColor,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ShopPage()),
                  ),
                ),
              ),
              Expanded(
                child: _BottomBarItem(
                  iconPath: "assets/icons/viatic.svg",
                  label: localizations.t("expenses"),
                  iconColor: iconColor,
                  labelColor: labelColor,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ExpensesPage()),
                  ),
                ),
              ),
              SizedBox(
                width: 105,
                height: 60,
                child: CustomPaint(
                  painter: const PlusButtonPainter(),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NewFlightPage(),
                        ),
                      );
                    },
                    child: Center(
                      child: SvgPicture.asset(
                        "assets/icons/more.svg",
                        height: 30,
                        colorFilter: const ColorFilter.mode(
                          AppColors.teal4,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomBarItem extends StatelessWidget {
  final String iconPath;
  final String label;
  final Color iconColor;
  final Color labelColor;
  final VoidCallback onTap;

  const _BottomBarItem({
    required this.iconPath,
    required this.label,
    required this.iconColor,
    required this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            iconPath,
            height: 22,
            colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
          ),
          const SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: labelColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class GradientLinePainter extends CustomPainter {
  final double strokeWidth;
  final double horizontalRatio;

  const GradientLinePainter({
    this.strokeWidth = 2.0,
    this.horizontalRatio = 0.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final half = strokeWidth / 2;
    final topY = half;
    final bottomY = size.height - half;
    final midX = size.width * horizontalRatio;

    final path = Path()
      ..moveTo(half, topY)
      ..lineTo(midX, topY)
      ..lineTo(midX + (bottomY - topY), bottomY)
      ..lineTo(size.width - half, bottomY);

    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.teal3, AppColors.teal5],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant GradientLinePainter old) {
    return old.strokeWidth != strokeWidth ||
        old.horizontalRatio != horizontalRatio;
  }
}

class PlusButtonPainter extends CustomPainter {
  const PlusButtonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        colors: [AppColors.teal3, AppColors.teal2],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(rect);

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(55, size.height)
      ..lineTo(0, 5)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant PlusButtonPainter old) {
    return false;
  }
}
