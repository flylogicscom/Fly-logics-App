import 'package:flutter/material.dart';

import 'package:fly_logicd_logbook_app/common/base_scaffold.dart';
import 'package:fly_logicd_logbook_app/common/custom_app_bar.dart';
import 'package:fly_logicd_logbook_app/common/button_styles.dart';
import 'package:fly_logicd_logbook_app/features/documents/doc_class_ratingslist.dart';
import 'package:fly_logicd_logbook_app/features/documents/doc_medical_examlist.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';

// Páginas de documentos
import 'package:fly_logicd_logbook_app/features/documents/doc_flight_licenseslist.dart';
import 'package:fly_logicd_logbook_app/features/documents/doc_type_ratinglist.dart';
import 'package:fly_logicd_logbook_app/features/documents/doc_personal_documentslist.dart';

class DocumentsPage extends StatelessWidget {
  const DocumentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return BaseScaffold(
      appBar: CustomAppBar(
        title: l.t("documents").toUpperCase(),
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

            // Licencias de vuelo
            ButtonStyles.menuButton(
              label: l.t("flight_licenses").toUpperCase(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DocFlightLicensesList(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Type rating
            ButtonStyles.menuButton(
              label: l.t("type_rating").toUpperCase(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DocTypeRatingsList(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Class rating
            ButtonStyles.menuButton(
              label: l.t("class_rating").toUpperCase(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DocClassRatingsList(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Examen médico
            ButtonStyles.menuButton(
              label: l.t("medical_exam").toUpperCase(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DocMedicalExamList(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Documentos personales
            ButtonStyles.menuButton(
              label: l.t("personal_documents").toUpperCase(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DocPersonalDocumentsList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class DocTypeRating {
  const DocTypeRating();
}
