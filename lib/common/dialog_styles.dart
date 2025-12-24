import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'button_styles.dart';
import '../l10n/app_localizations.dart';

class DialogStyles {
  DialogStyles._();

  /// 🔹 Diálogo con formulario
  static Widget formDialog({
    required BuildContext context,
    required String title,
    required Widget formContent,
    required VoidCallback onSave,
    required VoidCallback onCancel,
  }) {
    final t = AppLocalizations.of(context);

    return Dialog(
      // card (sustituido por teal1)
      backgroundColor: AppColors.teal1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.headline2),
            const SizedBox(height: 16),
            formContent,
            const SizedBox(height: 24),

            // 🔹 Botones traducidos
            Row(
              children: ButtonStyles.pillButtons(
                context: context,
                labels: [t.t("cancel"), t.t("save")],
                actions: [onCancel, onSave],
                // error (ya existe), secondary (0xFF498481) -> teal3
                colors: [AppColors.error, AppColors.teal3],
              )
                  .map((btn) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: btn,
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
