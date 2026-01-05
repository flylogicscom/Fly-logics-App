// lib/features/auth/first_run_gate.dart
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
  bool? _isFirstRun; // null = aún cargando prefs

  @override
  void initState() {
    super.initState();
    _loadFirstRunFlag();
  }

  Future<void> _loadFirstRunFlag() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('has_run') ?? false;

    if (!seen) {
      await prefs.setBool('has_run', true);
    }

    if (!mounted) return;
    setState(() => _isFirstRun = !seen);
  }

  @override
  Widget build(BuildContext context) {
    final v = _isFirstRun;

    // Sin splash artesanal: pantalla vacía mientras se resuelve SharedPreferences
    if (v == null) return const SizedBox.shrink();

    if (v) return const RegisterPage();
    return const AuthGate();
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        // Sin splash artesanal: pantalla vacía mientras Firebase entrega estado
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (snap.hasData) {
          return const HomePage();
        }

        return const LoginPage();
      },
    );
  }
}
