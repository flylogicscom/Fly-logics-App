// lib/common/base_scaffold.dart
import 'package:flutter/material.dart';
import 'package:fly_logicd_logbook_app/common/app_colors.dart';

class BaseScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  const BaseScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Degradado continuo en toda la pantalla (detrás de appBar y body)
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.blackDeep, // negro arriba
            Color(0xFF001B28), // azul muy oscuro abajo
          ],
        ),
      ),
      child: Scaffold(
        // importante para que se vea el degradado del Container
        backgroundColor: Colors.transparent,
        appBar: appBar,
        body: Padding(
          // margen superior fijo (después del appbar)
          padding: const EdgeInsets.only(top: 30),
          child: SafeArea(
            top: false, // no vuelve a subir el contenido
            child: body,
          ),
        ),
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: bottomNavigationBar,
      ),
    );
  }
}
