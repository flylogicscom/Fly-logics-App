import 'package:flutter/material.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';
import 'package:fly_logicd_logbook_app/common/custom_app_bar.dart';

class AmendmentsPage extends StatelessWidget {
  const AmendmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: localizations.t("amendments"), // ✅ título traducido
        rightIconPath: "assets/icons/logoback.svg", // ✅ icono de la derecha
        onRightIconTap: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context); // ✅ vuelve atrás
          }
        },
      ),
      body: const Center(
        child: Text(
          "Aquí va el contenido de Logs",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
