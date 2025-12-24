// lib/features/expenses/expenses_control_page.dart
import 'package:flutter/material.dart';
import 'package:fly_logicd_logbook_app/common/custom_app_bar.dart';
import 'package:fly_logicd_logbook_app/common/app_colors.dart';
import 'package:fly_logicd_logbook_app/common/app_text_styles.dart';
import 'package:fly_logicd_logbook_app/common/dialog_styles.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';

class ExpensesControlPage extends StatefulWidget {
  final int travelId;
  final String travelTitle;

  const ExpensesControlPage({
    super.key,
    required this.travelId,
    required this.travelTitle,
  });

  @override
  State<ExpensesControlPage> createState() => _ExpensesControlPageState();
}

class _ExpensesControlPageState extends State<ExpensesControlPage> {
  final List<Map<String, dynamic>> _expenses = [];

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: CustomAppBar(
        title: widget.travelTitle,
        rightIconPath: "assets/icons/logoback.svg",
        onRightIconTap: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.t("expenses"),
              style: AppTextStyles.subtitle,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _showAddExpenseDialog(context),
              child: Text(t.t("new_expense")),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddExpenseDialog(BuildContext context) async {
    final cargoCtrl = TextEditingController();
    final detailCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String currency = "USD";

    final t = AppLocalizations.of(context);

    await showDialog(
      context: context,
      builder: (_) {
        return DialogStyles.formDialog(
          context: context,
          title: t.t("new_expense"),
          formContent: Column(
            children: [
              TextField(
                controller: cargoCtrl,
                style: AppTextStyles.body,
                decoration: const InputDecoration(labelText: 'Charge'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailCtrl,
                style: AppTextStyles.body,
                decoration: const InputDecoration(labelText: 'Details'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: AppTextStyles.body,
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
            ],
          ),
          onCancel: () => Navigator.pop(context),
          onSave: () {
            setState(() {
              _expenses.add({
                "cargo": cargoCtrl.text,
                "detail": detailCtrl.text,
                "amount":
                    double.tryParse(amountCtrl.text.replaceAll(",", ".")) ?? 0,
                "currency": currency,
              });
            });
            Navigator.pop(context);
          },
        );
      },
    );
  }
}
