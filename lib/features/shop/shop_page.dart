// lib/features/shop/shop_page.dart

import 'package:flutter/material.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';
import 'package:fly_logicd_logbook_app/common/custom_app_bar.dart';
import 'package:fly_logicd_logbook_app/ui_preview_page.dart';
import 'package:fly_logicd_logbook_app/utils/db_exporter.dart' as dbe;
import 'package:fly_logicd_logbook_app/utils/db_helper.dart' as dbh;
import 'package:fly_logicd_logbook_app/utils/country_data.dart' as cdata;

class ShopPage extends StatelessWidget {
  const ShopPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: localizations.t("shop"),
        rightIconPath: "assets/icons/logoback.svg",
        onRightIconTap: () {
          if (Navigator.canPop(context)) Navigator.pop(context);
        },
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                localizations.t("shop"),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Aquí va el contenido de la tienda",
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 32),

              // UI Preview
              ElevatedButton.icon(
                icon: const Icon(Icons.visibility),
                label: const Text("Abrir UI Preview"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UIPreviewPage()),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Listar tablas
              ElevatedButton.icon(
                icon: const Icon(Icons.storage),
                label: const Text("Listar tablas"),
                onPressed: () async {
                  final tables = await dbh.DBHelper.getTables();
                  showDialog(
                    // ignore: use_build_context_synchronously
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Tablas encontradas'),
                      content: Text(
                        tables.isEmpty ? 'Sin tablas.' : tables.join('\n'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Contar países (DB)
              ElevatedButton.icon(
                icon: const Icon(Icons.tag),
                label: const Text("Contar países (DB)"),
                onPressed: () async {
                  final n = await dbh.DBHelper.countCountries();
                  messenger.showSnackBar(
                    SnackBar(content: Text('countries (DB): $n')),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Contar países (código)
              ElevatedButton.icon(
                icon: const Icon(Icons.code),
                label: const Text("Contar países (código)"),
                onPressed: () {
                  final totalFromCode = cdata.allCountryData.length;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'countries (código): $totalFromCode',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Ver 5 países
              ElevatedButton.icon(
                icon: const Icon(Icons.list),
                label: const Text("Ver 5 países"),
                onPressed: () async {
                  final db = await dbh.DBHelper.getDB();
                  final rows = await db.query(
                    dbh.DBHelper.tableCountries,
                    limit: 5,
                    orderBy: 'name',
                  );
                  showDialog(
                    // ignore: use_build_context_synchronously
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Muestra de países'),
                      content: Text(
                        rows.isEmpty
                            ? 'Sin datos.'
                            : rows.map((e) => e['name']).join('\n'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Sync países
              ElevatedButton.icon(
                icon: const Icon(Icons.sync),
                label: const Text("Sincronizar países (desde código)"),
                onPressed: () async {
                  final r = await dbh.DBHelper.syncCountriesFromCodeReport(
                    prune: true,
                  );
                  final n = await dbh.DBHelper.countCountries();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'sync → ins:${r['inserted']} '
                        'upd:${r['updated']} del:${r['deleted']} | DB=$n',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Mostrar ruta BD
              ElevatedButton.icon(
                icon: const Icon(Icons.folder),
                label: const Text("Mostrar ruta BD"),
                onPressed: () async {
                  final path = await dbh.DBHelper.dbPath();
                  messenger.showSnackBar(
                    SnackBar(content: Text(path)),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Exportar BD
              ElevatedButton.icon(
                icon: const Icon(Icons.save_alt),
                label: const Text("Exportar Base de Datos"),
                onPressed: () async {
                  await dbe.DBExporter.exportDB();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Base de datos exportada a Descargas ✅",
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
