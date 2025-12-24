import 'package:flutter/material.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';

import 'package:fly_logicd_logbook_app/common/base_scaffold.dart';
import 'package:fly_logicd_logbook_app/common/custom_app_bar.dart';
import 'package:fly_logicd_logbook_app/common/button_styles.dart';

import 'package:fly_logicd_logbook_app/features/profile/crew_data.dart';
import 'package:fly_logicd_logbook_app/features/profile/pilot_data.dart';
import 'package:fly_logicd_logbook_app/utils/db_helper.dart';

class PersonalData extends StatelessWidget {
  /// pickMode = true -> devuelve un nombre (String) al hacer pop.
  final bool pickMode;

  const PersonalData({super.key, this.pickMode = false});

  Future<void> _onPilotTap(BuildContext context) async {
    if (!pickMode) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PilotData(),
        ),
      );
      return;
    }

    // En modo selección: dejamos que el usuario edite/cree su ficha,
    // luego leemos el nombre desde la DB y lo devolvemos.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PilotData(),
      ),
    );

    final data = await DBHelper.getPilot();
    if (data == null) return;

    String name = (data['displayName'] as String? ?? '').trim();
    if (name.isEmpty) {
      name = (data['name'] as String? ?? '').trim();
    }
    if (name.isEmpty) return;

    if (Navigator.canPop(context)) {
      Navigator.pop(context, name);
    }
  }

  Future<void> _onCrewTap(BuildContext context) async {
    if (!pickMode) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const CrewData(),
        ),
      );
      return;
    }

    final Map<String, dynamic>? selected =
        await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (_) => const CrewData(pickMode: true),
      ),
    );

    if (selected == null) return;
    final String fullName = (selected['fullName'] as String? ?? '').trim();
    if (fullName.isEmpty) return;

    if (Navigator.canPop(context)) {
      Navigator.pop(context, fullName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return BaseScaffold(
      appBar: CustomAppBar(
        title: localizations.t("personal_data").toUpperCase(),
        rightIconPath: "assets/icons/logoback.svg",
        onRightIconTap: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),

            // Pilot data
            ButtonStyles.menuButton(
              label: localizations.t("pilot_data").toUpperCase(),
              onTap: () => _onPilotTap(context),
            ),

            const SizedBox(height: 12),

            // Crew data
            ButtonStyles.menuButton(
              label: localizations.t("crew_details").toUpperCase(),
              onTap: () => _onCrewTap(context),
            ),
          ],
        ),
      ),
    );
  }
}
