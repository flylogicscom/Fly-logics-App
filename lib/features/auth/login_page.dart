import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:fly_logicd_logbook_app/common/app_colors.dart';
import 'package:fly_logicd_logbook_app/common/popwindow.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loginEmail() async {
    final l = AppLocalizations.of(context);

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      _showSnack(l.t('login_snackbar_session_started'));
    } on FirebaseAuthException catch (e) {
      final msg = e.message ?? e.code;
      setState(() => _error = msg);
      _showSnack('${l.t("login_error_prefix")} $msg');
    } catch (e) {
      final msg = e.toString();
      setState(() => _error = msg);
      _showSnack('${l.t("login_unexpected_error_prefix")} $msg');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loginAnon() async {
    final l = AppLocalizations.of(context);

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.signInAnonymously();
      _showSnack(l.t('login_snackbar_guest'));
    } on FirebaseAuthException catch (e) {
      final msg = e.message ?? e.code;
      setState(() => _error = msg);
      _showSnack(
        '${l.t("login_error_prefix")} $msg\n${l.t("login_guest_error_hint")}',
      );
    } catch (e) {
      final msg = e.toString();
      setState(() => _error = msg);
      _showSnack('${l.t("login_unexpected_error_prefix")} $msg');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    final l = AppLocalizations.of(context);

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final GoogleSignIn signIn = GoogleSignIn.instance;

      if (!signIn.supportsAuthenticate()) {
        _showSnack(l.t('login_google_not_available'));
        return;
      }

      final GoogleSignInAccount user = await signIn.authenticate();
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
      _showSnack(l.t('login_snackbar_session_started_with_google'));
    } on GoogleSignInException catch (e) {
      final msg =
          '${l.t("login_google_error_prefix")} ${e.code.name}${e.description != null ? ' - ${e.description}' : ''}';
      setState(() => _error = msg);
      _showSnack(msg);
    } on FirebaseAuthException catch (e) {
      final msg = e.message ?? e.code;
      setState(() => _error = msg);
      _showSnack('${l.t("login_error_prefix")} $msg');
    } catch (e) {
      final msg = e.toString();
      setState(() => _error = msg);
      _showSnack('${l.t("login_unexpected_error_prefix")} $msg');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
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
    final l = AppLocalizations.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _loading,
          child: Column(
            children: [
              // CONTENIDO CENTRADO
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo (un poco más chico)
                          Image.asset(
                            'assets/icons/logoflname.png',
                            height: size.height * 0.10,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 16),
                          // Subtítulo (tagline)
                          Text(
                            l.t('login_subtitle'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 28),

                          if (_error != null) ...[
                            Text(
                              '${l.t("login_error_prefix")} $_error',
                              style: const TextStyle(color: Colors.redAccent),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                          ],

                          // 1) Google
                          _AuthPillButton(
                            label: l.t('login_btn_google'),
                            onTap: _loading ? null : _signInWithGoogle,
                            icon: Image.asset(
                              'assets/icons/googlelogo.png',
                              height: 22,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 2) Crear cuenta (popup)
                          _AuthPillButton(
                            label: l.t('login_btn_create_email'),
                            onTap: _loading ? null : _showRegisterDialog,
                            icon: Icon(
                              Icons.person_add_alt_1,
                              color: AppColors.teal1,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // OR
                          Row(
                            children: [
                              const Expanded(
                                child: Divider(
                                  color: Colors.white24,
                                  thickness: 0.7,
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  l.t('login_separator_or'),
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: Divider(
                                  color: Colors.white24,
                                  thickness: 0.7,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // 3) Login con email (popup)
                          _AuthPillButton(
                            label: l.t('login_btn_login_email'),
                            onTap: _loading ? null : _showEmailLoginDialog,
                            icon: Icon(
                              Icons.mail_outline,
                              color: AppColors.teal1,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Invitado
                          TextButton.icon(
                            onPressed: _loading ? null : _loginAnon,
                            icon: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    // ignore: deprecated_member_use
                                    const Color(0xFFCDFCF3).withOpacity(0.15),
                                border: Border.all(
                                  color: const Color(0xFFCDFCF3),
                                  width: 1.4,
                                ),
                              ),
                              child: Icon(
                                Icons.explore,
                                size: 18,
                                color: AppColors.teal1,
                              ),
                            ),
                            label: Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Text(
                                l.t('login_btn_guest'),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // TÉRMINOS Y PRIVACIDAD PEGADOS ABAJO
              Padding(
                padding: const EdgeInsets.only(left: 24, right: 24, bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        _showSnack(l.t('login_terms_todo'));
                      },
                      child: Text(
                        l.t('login_terms'),
                        style: const TextStyle(
                          color: Colors.white70,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const Text(
                      ' · ',
                      style: TextStyle(color: Colors.white70),
                    ),
                    TextButton(
                      onPressed: () {
                        _showSnack(l.t('login_privacy_todo'));
                      },
                      child: Text(
                        l.t('login_privacy'),
                        style: const TextStyle(
                          color: Colors.white70,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- POPUP LOGIN EMAIL (showPopWindow) ----------

  Future<void> _showEmailLoginDialog() async {
    final l = AppLocalizations.of(context);

    final formKey = GlobalKey<FormState>();
    final emailCtrl = TextEditingController(text: _emailCtrl.text);
    final passCtrl = TextEditingController(text: _passCtrl.text);
    bool saving = false;

    await showPopWindow(
      context: context,
      title: l.t('login_dialog_login_title'),
      barrierDismissible: false,
      children: [
        StatefulBuilder(
          builder: (ctx, setSB) {
            return Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l.t('login_field_email'),
                      prefixIcon: const Icon(Icons.mail_outline),
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? l.t('login_field_email_required')
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: l.t('login_field_password'),
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                    validator: (v) => (v == null || v.length < 6)
                        ? l.t('login_field_password_min')
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            saving ? null : () => Navigator.of(ctx).pop(),
                        child: Text(
                          l.t('login_action_cancel'),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setSB(() => saving = true);

                                _emailCtrl.text = emailCtrl.text;
                                _passCtrl.text = passCtrl.text;

                                Navigator.of(ctx).pop();
                                await _loginEmail();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.teal3,
                        ),
                        child: Text(l.t('login_dialog_login_action')),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ---------- POPUP REGISTER (EMAIL + PASS + REPETIR, showPopWindow) ----------

  Future<void> _showRegisterDialog() async {
    final l = AppLocalizations.of(context);

    final formKey = GlobalKey<FormState>();
    final emailCtrl = TextEditingController(text: _emailCtrl.text);
    final passCtrl = TextEditingController();
    final repeatCtrl = TextEditingController();
    bool saving = false;

    // Patrón tipo "Aa11xxxx": mayúscula, minúscula, dígito, 8+ caracteres
    final passwordPattern = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$');

    await showPopWindow(
      context: context,
      title: l.t('login_dialog_register_title'),
      barrierDismissible: false,
      children: [
        StatefulBuilder(
          builder: (ctx, setSB) {
            return Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l.t('login_field_email'),
                      prefixIcon: const Icon(Icons.mail_outline),
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? l.t('login_field_email_required')
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: l.t('login_field_password'),
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return l.t('login_field_password_min');
                      }
                      if (!passwordPattern.hasMatch(v)) {
                        return l.t('login_field_password_min');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: repeatCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: l.t('login_field_password_repeat'),
                      prefixIcon: const Icon(Icons.lock_reset),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return l.t('login_field_password_repeat_required');
                      }
                      if (v != passCtrl.text) {
                        return l.t('login_field_password_mismatch');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            saving ? null : () => Navigator.of(ctx).pop(),
                        child: Text(
                          l.t('login_action_cancel'),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setSB(() => saving = true);

                                try {
                                  await FirebaseAuth.instance
                                      .createUserWithEmailAndPassword(
                                    email: emailCtrl.text.trim(),
                                    password: passCtrl.text,
                                  );

                                  _emailCtrl.text = emailCtrl.text;
                                  _passCtrl.text = passCtrl.text;

                                  if (mounted) {
                                    Navigator.of(ctx).pop();
                                    _showSnack(
                                        l.t('login_snackbar_account_created'));
                                  }
                                } on FirebaseAuthException catch (e) {
                                  final msg = e.message ?? e.code;
                                  if (mounted) {
                                    _showSnack(
                                      '${l.t("login_error_prefix")} $msg',
                                    );
                                  }
                                } catch (e) {
                                  final msg = e.toString();
                                  if (mounted) {
                                    _showSnack(
                                      '${l.t("login_unexpected_error_prefix")} $msg',
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setSB(() => saving = false);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.teal3,
                        ),
                        child: Text(l.t('login_dialog_register_action')),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// ----------------- WIDGET DE PILL -----------------

class _AuthPillButton extends StatelessWidget {
  const _AuthPillButton({
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1.0 : 0.6,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.teal1, AppColors.teal3],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              // ignore: deprecated_member_use
              color: Colors.white.withOpacity(0.7),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 26), // padding izquierdo
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (icon != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFCDFCF3),
                    ),
                    child: Center(child: icon),
                  ),
                )
              else
                const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
