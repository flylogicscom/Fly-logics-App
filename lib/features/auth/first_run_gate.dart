// lib/features/logs/first_run_gate.dart  (solo referencia; no cambies tu Home)
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_page.dart';
import 'register_page.dart';
import '../home/home_page.dart';

/// Gate inicial:
/// - Primera ejecución → RegisterPage
/// - Si no es primera → AuthGate (escucha FirebaseAuth)
class FirstRunGate extends StatefulWidget {
  const FirstRunGate({super.key});

  @override
  State<FirstRunGate> createState() => _FirstRunGateState();
}

class _FirstRunGateState extends State<FirstRunGate> {
  late final Future<bool> _firstRunFuture = _isFirstRun();

  Future<bool> _isFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('has_run') ?? false;
    if (!seen) {
      await prefs.setBool('has_run', true);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _firstRunFuture,
      builder: (context, snap) {
        if (!snap.hasData) return const _Splash();
        final isFirstRun = snap.data!;
        if (isFirstRun) return const RegisterPage();
        return const AuthGate();
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Splash();
        }
        if (snap.hasData) {
          // 🔁 SESIÓN ACTIVA → HomePage (cámbialo a LogsPage/UIPreviewPage si prefieres)
          return const HomePage();
        }
        // 🚪 SIN SESIÓN → Login
        return const LoginPage();
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
