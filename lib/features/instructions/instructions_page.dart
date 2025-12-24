// lib/features/instructions/instructions_page.dart
import 'package:flutter/material.dart';

import 'package:fly_logicd_logbook_app/common/base_scaffold.dart';
import 'package:fly_logicd_logbook_app/common/custom_app_bar.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';
import 'package:fly_logicd_logbook_app/common/app_text_styles.dart';
import 'package:fly_logicd_logbook_app/common/dropdown_styles.dart';

class InstructionsPage extends StatefulWidget {
  const InstructionsPage({super.key});

  @override
  State<InstructionsPage> createState() => _InstructionsPageState();
}

class _InstructionsPageState extends State<InstructionsPage> {
  final int _expandedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);
    final sectionLabel = t.t("section_label");

    final sections = List.generate(12, (index) {
      final n = index + 1;
      return {
        "title": t.t("section_${n}_title"),
        "content": t.t("section_${n}_body"),
      };
    });

    return BaseScaffold(
      appBar: CustomAppBar(
        title: t.t("instructions"),
        rightIconPath: "assets/icons/logoback.svg",
        onRightIconTap: () {
          if (Navigator.canPop(context)) Navigator.pop(context);
        },
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),
            ExpansionPanelList.radio(
              expandedHeaderPadding: EdgeInsets.zero,
              initialOpenPanelValue: _expandedIndex,
              elevation: 0,
              children: sections.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;

                return ExpansionPanelRadio(
                  value: idx,
                  backgroundColor: cs.surface,
                  headerBuilder: (context, isExpanded) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 15,
                        horizontal: 16,
                      ),
                      child: DropdownStyles.headerRow(
                        context: context,
                        prefixText: "$sectionLabel ${idx + 1}:",
                        label: item["title"] ?? "",
                      ),
                    );
                  },
                  body: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        child: _buildSectionBody(
                          idx + 1,
                          item["content"] ?? "",
                        ),
                      ),
                      Container(
                        height: 1,
                        color: cs.outlineVariant,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionBody(int sectionNumber, String content) {
    final cs = Theme.of(context).colorScheme;

    if (sectionNumber == 9) {
      final lines = content.split("\n\n");
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((line) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "• ",
                  style: TextStyle(color: cs.primary, fontSize: 18),
                ),
                Expanded(
                  child: Text(
                    line.trim(),
                    style: AppTextStyles.body.copyWith(
                      color: cs.onSurface,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    return Text(
      content,
      style: AppTextStyles.body.copyWith(
        color: cs.onSurface,
        fontSize: 14,
      ),
    );
  }
}
