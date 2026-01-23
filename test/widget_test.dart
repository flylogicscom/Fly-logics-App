// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fly_logicd_logbook_app/main.dart' as app;

// Importa tu app con alias para evitar colisiones de nombre

void main() {
  testWidgets('MyApp compila', (tester) async {
    // OJO: esto solo verifica tipos, no ejecuta inicialización de Firebase,
    // por eso dejamos el test en skip para no correr en CI hasta mockear Firebase.
    await tester.pumpWidget(const app.MyApp() as Widget);
    expect(find.byType(MaterialApp), findsOneWidget);
  }, skip: true); // quita el skip cuando tengas mocks de Firebase
}
