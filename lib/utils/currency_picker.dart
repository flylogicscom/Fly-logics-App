import 'package:flutter/material.dart';
import 'package:fly_logicd_logbook_app/common/popwindow.dart';
import 'package:fly_logicd_logbook_app/utils/country_data.dart' as cdata;

/// Resultado que devolvemos al caller
class CurrencyPickResult {
  final String code; // USD
  final String emoji; // 🇺🇸
  final String label; // United States / Europe
  final String currencyName; // United States Dollar
  const CurrencyPickResult({
    required this.code,
    required this.emoji,
    required this.label,
    required this.currencyName,
  });
}

/// Fuente única: allCountryData
List<cdata.CountryData> _allCountries() {
  return List<cdata.CountryData>.from(cdata.allCountryData);
}

/// Muestra un diálogo emergente para seleccionar una moneda a partir de los datos de país.
Future<CurrencyPickResult?> showCurrencyPickerPopup(
  BuildContext context,
) async {
  // 1) construir mapa código -> CurrencyPickResult
  final Map<String, CurrencyPickResult> byCode = {};
  final allCountries = _allCountries();

  for (final c in allCountries) {
    final codeRaw = c.localCurrency.trim();
    if (codeRaw.isEmpty) continue;
    final code = codeRaw.toUpperCase();

    final String currencyName =
        (c.currencyName.trim().isEmpty) ? code : c.currencyName.trim();

    // EUR fijo
    if (code == 'EUR') {
      byCode.putIfAbsent(
        'EUR',
        () => const CurrencyPickResult(
          code: 'EUR',
          emoji: '🇪🇺',
          label: 'Europe',
          currencyName: 'Euro',
        ),
      );
      continue;
    }

    // USD: preferimos United States como etiqueta principal
    if (code == 'USD') {
      if (c.name == 'United States') {
        byCode['USD'] = CurrencyPickResult(
          code: 'USD',
          emoji: '🇺🇸',
          label: 'United States',
          currencyName: currencyName,
        );
        continue;
      } else {
        byCode.putIfAbsent(
          'USD',
          () => CurrencyPickResult(
            code: 'USD',
            emoji: c.flagEmoji,
            label: c.name,
            currencyName: currencyName,
          ),
        );
        continue;
      }
    }

    // Resto: primera aparición gana
    byCode.putIfAbsent(
      code,
      () => CurrencyPickResult(
        code: code,
        emoji: c.flagEmoji,
        label: c.name,
        currencyName: currencyName,
      ),
    );
  }

  // 2) lista base ordenada por código
  final List<CurrencyPickResult> all = byCode.values.toList()
    ..sort((a, b) => a.code.compareTo(b.code));

  // 3) lista visible y estado
  List<CurrencyPickResult> current = List.of(all);
  CurrencyPickResult? selected;

  await showPopWindow(
    context: context,
    title: 'Search currency',
    children: [
      StatefulBuilder(
        builder: (ctx, setState) {
          final theme = Theme.of(ctx);
          final colorScheme = theme.colorScheme;

          // Fijamos estilo pensado para el tema oscuro (sin branch por brightness)
          final borderColor = colorScheme.outline.withOpacity(0.35);
          final primaryTextColor = colorScheme.onSurface;
          final secondaryTextColor =
              colorScheme.onSurfaceVariant.withOpacity(0.9);

          void applyFilter(String txt) {
            final q = txt.trim().toLowerCase();
            setState(() {
              if (q.isEmpty) {
                current = List.of(all);
              } else {
                current = all.where((e) {
                  return e.code.toLowerCase().contains(q) ||
                      e.currencyName.toLowerCase().contains(q) ||
                      e.label.toLowerCase().contains(q);
                }).toList();
              }
            });
          }

          return Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search',
                ),
                onChanged: applyFilter,
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 280,
                child: ListView.builder(
                  itemCount: current.length,
                  itemBuilder: (ctx, i) {
                    final item = current[i];
                    return InkWell(
                      onTap: () {
                        selected = item;
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 0,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: borderColor,
                              width: 1,
                            ),
                            bottom: BorderSide(
                              color: borderColor,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: Text(
                                item.emoji,
                                style: const TextStyle(fontSize: 38),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 52,
                              color: borderColor,
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item.code} - ${item.currencyName}',
                                      style:
                                          theme.textTheme.bodyLarge?.copyWith(
                                                color: primaryTextColor,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                              ) ??
                                              TextStyle(
                                                color: primaryTextColor,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                              ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      item.label,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                                color: secondaryTextColor,
                                                fontSize: 15,
                                              ) ??
                                              TextStyle(
                                                color: secondaryTextColor,
                                                fontSize: 15,
                                              ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 10),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );

  return selected;
}
