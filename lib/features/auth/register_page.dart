import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  String? _error; // Mensaje de error visible en pantalla

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      _showSnack('Cuenta creada. Entrando…');
      // AuthGate detectará la sesión y te enviará al Home.
    } on FirebaseAuthException catch (e) {
      final msg = e.message ?? e.code;
      setState(() {
        _error = msg;
      });
      _showSnack('Error: $msg');
    } catch (e) {
      final msg = e.toString();
      setState(() {
        _error = msg;
      });
      _showSnack('Error inesperado: $msg');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _signInGuest() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.signInAnonymously();
      _showSnack('Entraste como invitado.');
      // AuthGate te manda al Home.
    } on FirebaseAuthException catch (e) {
      final msg = e.message ?? e.code;
      setState(() {
        _error = msg;
      });
      _showSnack(
        'Error: $msg\n¿Activaste Anonymous en Firebase?',
      );
    } catch (e) {
      final msg = e.toString();
      setState(() {
        _error = msg;
      });
      _showSnack('Error inesperado: $msg');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final GoogleSignIn signIn = GoogleSignIn.instance;

      if (!signIn.supportsAuthenticate()) {
        _showSnack('Google Sign-In no está disponible en este dispositivo.');
        return;
      }

      // En v7 authenticate() devuelve siempre una cuenta no nula.
      final GoogleSignInAccount user = await signIn.authenticate();

      // Tokens de Google (solo idToken en v7).
      final GoogleSignInAuthentication googleAuth =
          // ignore: await_only_futures
          await user.authentication;

      final String? idToken = googleAuth.idToken;
      if (idToken == null) {
        throw FirebaseAuthException(
          code: 'no-id-token',
          message: 'No se pudo obtener el idToken de Google.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      _showSnack('Sesión iniciada con Google.');
      // AuthGate redirige al Home automáticamente.
    } on GoogleSignInException catch (e) {
      final msg =
          'Error de Google: ${e.code.name}${e.description != null ? ' - ${e.description}' : ''}';
      setState(() {
        _error = msg;
      });
      _showSnack(msg);
    } on FirebaseAuthException catch (e) {
      final msg = e.message ?? e.code;
      setState(() {
        _error = msg;
      });
      _showSnack('Error: $msg');
    } catch (e) {
      final msg = e.toString();
      setState(() {
        _error = msg;
      });
      _showSnack('Error inesperado: $msg');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: const Text('Registro'),
      ),
      body: AbsorbPointer(
        absorbing: _loading,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            // ① Crear cuenta (email/contraseña)
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const Text(
                        'Crear cuenta',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Ingresa tu email'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock),
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Mínimo 6 caracteres'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _createAccount,
                        icon: _loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.person_add_alt_1),
                        label: const Text('Crear cuenta'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ② Google Sign-In
            OutlinedButton.icon(
              onPressed: _loading ? null : _signInWithGoogle,
              icon: SvgPicture.asset(
                'assets/icons/googlelogo.svg',
                height: 18,
              ),
              label: const Text('Continuar con Google'),
            ),

            const SizedBox(height: 16),

            // ③ Ya tengo cuenta → Login
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
              icon: const Icon(Icons.login),
              label: const Text('Ya tengo cuenta / Iniciar sesión'),
            ),

            const SizedBox(height: 8),

            // ④ Invitado / demo
            TextButton.icon(
              onPressed: _loading ? null : _signInGuest,
              icon: const Icon(Icons.explore),
              label: const Text('Entrar como invitado (explorar ahora)'),
            ),
          ],
        ),
      ),
    );
  }
}
