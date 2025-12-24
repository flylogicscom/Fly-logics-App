// lib/features/settings/settings_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:fly_logicd_logbook_app/l10n/locale_controller.dart';
import 'package:fly_logicd_logbook_app/common/custom_app_bar.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';
import 'package:fly_logicd_logbook_app/common/app_text_styles.dart';
import 'package:fly_logicd_logbook_app/common/base_scaffold.dart';
import 'package:fly_logicd_logbook_app/common/dropdown_styles.dart';
import 'package:fly_logicd_logbook_app/common/app_colors.dart';

import 'package:fly_logicd_logbook_app/features/auth/login_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _handleChangePassword(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay sesión iniciada.'),
        ),
      );
      return;
    }

    final hasPasswordProvider =
        user.providerData.any((p) => p.providerId == 'password');

    if (!hasPasswordProvider) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Has iniciado sesión con una cuenta de Google, no puedes cambiar la contraseña desde aquí.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.t("change_password"))),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      // Cerrar sesión de Google (si aplica), mejor esfuerzo
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}

      // Cerrar sesión de Firebase
      await FirebaseAuth.instance.signOut();

      // Ir a LoginPage y limpiar el stack de navegación
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cerrar sesión: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeController = Provider.of<LocaleController>(context);
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return BaseScaffold(
      appBar: CustomAppBar(
        title: t.t("settings_title"),
        rightIconPath: "assets/icons/logoback.svg",
        onRightIconTap: () {
          if (Navigator.canPop(context)) Navigator.pop(context);
        },
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Idioma
              Text(
                t.t("language"),
                style: AppTextStyles.bodyBold
                    .copyWith(fontSize: 18, color: cs.onSurface),
              ),
              const SizedBox(height: 10),
              DropdownStyles.tile<Locale>(
                context: context,
                value: localeController.locale,
                options: const [Locale('en'), Locale('es'), Locale('pt')],
                toLabel: (v) => {
                  'en': t.t("english"),
                  'es': t.t("spanish"),
                  'pt': t.t("portuguese"),
                }[v.languageCode]!,
                onChanged: (newLocale) {
                  if (newLocale != null) localeController.setLocale(newLocale);
                },
              ),

              const SizedBox(height: 24),
              Divider(color: cs.outlineVariant),

              // Opciones principales
              _buildSettingItem(
                context,
                icon: Icons.lock,
                label: t.t("change_password"),
                onTap: () => _handleChangePassword(context),
              ),
              _buildSettingItem(
                context,
                icon: Icons.info,
                label: t.t("about"),
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: "Fly Logics Logbook",
                    applicationVersion: "1.0.0",
                    applicationLegalese: "© 2025 Fly Logics.",
                  );
                },
              ),

              _buildSettingItem(
                context,
                icon: Icons.notifications,
                label: t.t("notifications"),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t.t("notifications"))),
                ),
              ),

              const SizedBox(height: 24),
              Divider(color: cs.outlineVariant),

              // Cerrar sesión — pill gradiente
              InkWell(
                onTap: () => _handleLogout(context),
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.teal3, AppColors.teal4],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: AppColors.teal4, width: 1),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    t.t("logout"),
                    style: AppTextStyles.buttonText
                        .copyWith(color: AppColors.white),
                  ),
                ),
              ),
            ],
          ),

          // Sombras superior e inferior (siguen usando el tema oscuro base)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 10,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      cs.shadow.withValues(alpha: 0.10),
                      cs.shadow.withValues(alpha: 0.00),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 10,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      cs.shadow.withValues(alpha: 0.10),
                      cs.shadow.withValues(alpha: 0.00),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.body
                    .copyWith(fontSize: 16, color: cs.onSurface),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: cs.primary),
          ],
        ),
      ),
    );
  }
}
