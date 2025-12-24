// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'package:fly_logicd_logbook_app/common/app_theme.dart';
import 'package:fly_logicd_logbook_app/common/app_colors.dart';
import 'l10n/locale_controller.dart';
import 'l10n/app_localizations.dart';

// DB local
import 'utils/db_helper.dart';

// Gate inicial (Registro/Login/Home)
import 'features/auth/first_run_gate.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bloquear orientación a vertical
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // 1) Abrir BD
  await DBHelper.getDB();

  // 2) Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3) Controladores
  final localeController = LocaleController();
  await localeController.loadLocale();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: localeController),
      ],
      child: const MyApp(),
    ),
  );

  // 4) Sincronización en background
  Future.microtask(() async {
    try {
      await DBHelper.syncCountriesFromCode(prune: true);
    } catch (e, st) {
      // ignore: avoid_print
      print('syncCountriesFromCode error: $e\n$st');
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeController = Provider.of<LocaleController>(context);
    // Ya no usamos ThemeController para cambiar tema,
    // pero puedes dejar el provider creado en main() sin problema.

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fly Logics Logbook',

      // ÚNICO TEMA: el oscuro
      theme: AppTheme.darkTheme.copyWith(
        textTheme: AppTheme.darkTheme.textTheme.copyWith(
          bodyMedium: const TextStyle(
            fontSize: 18,
            color: AppColors.white,
          ),
          titleMedium: const TextStyle(
            fontSize: 18,
            color: AppColors.teal5,
          ),
        ),
        inputDecorationTheme: AppTheme.darkTheme.inputDecorationTheme.copyWith(
          isDense: true,
          labelStyle: const TextStyle(
            fontSize: 18,
            color: Colors.white70,
          ),
          floatingLabelStyle: const TextStyle(
            fontSize: 18,
            color: AppColors.teal5,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: const BoxConstraints(minHeight: 10),
          border: InputBorder.none,
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white70, width: 0.5),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.tealAccent, width: 0.5),
          ),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: AppColors.teal3,
          selectionColor: AppColors.teal1,
          selectionHandleColor: AppColors.teal3,
        ),
      ),

      // SIN darkTheme:
      // darkTheme: ...
      // SIN themeMode:
      // themeMode: themeController.themeMode,

      // Localización
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('es'),
        Locale('pt'),
      ],
      locale: localeController.locale,

      home: const FirstRunGate(),
    );
  }
}
