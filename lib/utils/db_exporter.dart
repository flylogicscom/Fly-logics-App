import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:fly_logicd_logbook_app/utils/db_helper.dart';

class DBExporter {
  DBExporter._();

  static Future<void> exportDB() async {
    try {
      await DBHelper.checkpointAndCloseForExport();

      final runtimePath = await DBHelper.dbPath();
      final src = File(runtimePath);
      debugPrint('Origen (runtime): $runtimePath '
          'exists=${await src.exists()} bytes=${await src.length()}');

      final downloads = Directory('/storage/emulated/0/Download');
      if (!await downloads.exists()) {
        await downloads.create(recursive: true);
      }
      final destPath = p.join(downloads.path, 'app.db');

      await src.copy(destPath);
      debugPrint('✅ Copia exportada a: $destPath');

      await DBHelper.getDB();
    } catch (e) {
      debugPrint('❌ Error al exportar DB: $e');
      rethrow;
    }
  }
}
