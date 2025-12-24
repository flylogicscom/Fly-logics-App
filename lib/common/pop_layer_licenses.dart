// lib/common/pop_layer_licenses.dart

import 'package:flutter/material.dart';

import 'package:fly_logicd_logbook_app/common/app_colors.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';

/// Resultado de seleccionar un tipo de licencia desde el popup.
class LicenseSelection {
  /// Código corto de la licencia (por ejemplo: PPL(A), CPL(H), etc.).
  final String code;

  /// Nombre/título visible de la licencia.
  final String title;

  const LicenseSelection({
    required this.code,
    required this.title,
  });
}

enum _LicenseKind {
  pplA,
  pplH,
  cplA,
  cplH,
  atplA,
  atplH,
  fiA,
  fiH,
  mpl,
  spl,
  bpl,
  rpl,
  laplA,
  laplH,
  acpl,
  other,
}

/// Muestra el popup de selección de licencias y devuelve la licencia elegida.
/// Devuelve `null` si se cierra sin seleccionar.
Future<LicenseSelection?> showLicensePopup(BuildContext context) async {
  final l = AppLocalizations.of(context);

  // Título del popup
  final titlePopup = l.t("licenses_popup_title");

  // Títulos de cada licencia
  final pplATitle = l.t("license_ppl_a_title");
  final pplHTitle = l.t("license_ppl_h_title");
  final cplATitle = l.t("license_cpl_a_title");
  final cplHTitle = l.t("license_cpl_h_title");
  final atplATitle = l.t("license_atpl_a_title");
  final atplHTitle = l.t("license_atpl_h_title");
  final fiATitle = l.t("license_fi_a_title");
  final fiHTitle = l.t("license_fi_h_title");
  final mplTitle = l.t("license_mpl_title");
  final splTitle = l.t("license_spl_title");
  final bplTitle = l.t("license_bpl_title");
  final rplTitle = l.t("license_rpl_title");
  final laplATitle = l.t("license_lapl_a_title");
  final laplHTitle = l.t("license_lapl_h_title");
  final acplTitle = l.t("license_acpl_title");
  final otherTitle = l.t("license_other_title");

  final _LicenseKind? kind = await showDialog<_LicenseKind>(
    context: context,
    builder: (ctx) {
      final maxHeight = MediaQuery.of(ctx).size.height * 0.8;

      return AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentPadding: EdgeInsets.zero,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Container(
            width: 360,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [AppColors.teal1, AppColors.teal2],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                  child: Text(
                    titlePopup,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Divider(
                  thickness: 0.5,
                  height: 8,
                  color: Colors.white24,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      16.0,
                      8.0,
                      16.0,
                      12.0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLicenseTile(
                          context: ctx,
                          kind: _LicenseKind.pplA,
                          code: 'PPL(A)',
                          title: pplATitle,
                          color: const Color(0xFF024755),
                        ),
                        _thinDivider(),
                        _buildLicenseTile(
                          context: ctx,
                          kind: _LicenseKind.pplH,
                          code: 'PPL(H)',
                          title: pplHTitle,
                          color: const Color(0xFF125864),
                        ),
                        _thinDivider(),
                        _buildLicenseTile(
                          context: ctx,
                          kind: _LicenseKind.cplA,
                          code: 'CPL(A)',
                          title: cplATitle,
                          color: const Color(0xFF216873),
                        ),
                        _thinDivider(),
                        _buildLicenseTile(
                          context: ctx,
                          kind: _LicenseKind.cplH,
                          code: 'CPL(H)',
                          title: cplHTitle,
                          color: const Color(0xFF337983),
                        ),
                        _thinDivider(),
                        _buildLicenseTile(
                          context: ctx,
                          kind: _LicenseKind.atplA,
                          code: 'ATPL(A)',
                          title: atplATitle,
                          color: const Color(0xFF418991),
                        ),
                        _thinDivider(),
                        _buildLicenseTile(
                          context: ctx,
                          kind: _LicenseKind.atplH,
                          code: 'ATPL(H)',
                          title: atplHTitle,
                          color: const Color(0xFF519AA0),
                        ),
                        _thinDivider(),
                        _buildLicenseTile(
                          context: ctx,
                          kind: _LicenseKind.fiA,
                          code: 'FI(A)',
                          title: fiATitle,
                          color: const Color(0xFF61AAAF),
                        ),
                        _thinDivider(),
                        _buildLicenseTile(
                          context: ctx,
                          kind: _LicenseKind.fiH,
                          code: 'FI(H)',
                          title: fiHTitle,
                          color: const Color(0xFF72BBBF),
                        ),
                        _thinDivider(),
                        _buildLicenseTile(
                          context: ctx,
                          kind: _LicenseKind.mpl,
                          code: 'MPL',
                          title: mplTitle,
                          color: const Color(0xFF3B6D7C),
                        ),
                        _thinDivider(),
                        _buildLicenseTile(
                          context: ctx,
                          kind: _LicenseKind.spl,
                          code: 'SPL',
                          title: splTitle,
                          color: const Color(0xFF2F5E6C),
                        ),
                        _thinDivider(),
                        _buildLicenseTile(
                          context: ctx,
                          kind: _LicenseKind.bpl,
                          code: 'BPL',
                          title: bplTitle,
                          color: const Color(0xFF25505E),
                        ),
                        _thinDivider(),
                        _buildLicenseTile(
                          context: ctx,
                          kind: _LicenseKind.rpl,
                          code: 'RPL',
                          title: rplTitle,
                          color: const Color(0xFF1C4454),
                        ),
                        _thinDivider(),
                        _buildLicenseTile(
                          context: ctx,
                          kind: _LicenseKind.laplA,
                          code: 'LAPL(A)',
                          title: laplATitle,
                          color: const Color(0xFF16505A),
                        ),
                        _thinDivider(),
                        _buildLicenseTile(
                          context: ctx,
                          kind: _LicenseKind.laplH,
                          code: 'LAPL(H)',
                          title: laplHTitle,
                          color: const Color(0xFF14646F),
                        ),
                        _thinDivider(),
                        _buildLicenseTile(
                          context: ctx,
                          kind: _LicenseKind.acpl,
                          code: 'ACPL',
                          title: acplTitle,
                          color: const Color(0xFF0F767D),
                        ),
                        _thinDivider(),
                        _buildLicenseTile(
                          context: ctx,
                          kind: _LicenseKind.other,
                          code: 'OTRO',
                          title: otherTitle,
                          color: const Color(0xFF0A8A88),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  if (kind == null) return null;

  return _selectionForKind(context, kind);
}

// ---------- Helpers ----------

LicenseSelection _selectionForKind(
  BuildContext context,
  _LicenseKind kind,
) {
  final l = AppLocalizations.of(context);

  switch (kind) {
    case _LicenseKind.pplA:
      return LicenseSelection(
        code: 'PPL(A)',
        title: l.t("license_ppl_a_title"),
      );
    case _LicenseKind.pplH:
      return LicenseSelection(
        code: 'PPL(H)',
        title: l.t("license_ppl_h_title"),
      );
    case _LicenseKind.cplA:
      return LicenseSelection(
        code: 'CPL(A)',
        title: l.t("license_cpl_a_title"),
      );
    case _LicenseKind.cplH:
      return LicenseSelection(
        code: 'CPL(H)',
        title: l.t("license_cpl_h_title"),
      );
    case _LicenseKind.atplA:
      return LicenseSelection(
        code: 'ATPL(A)',
        title: l.t("license_atpl_a_title"),
      );
    case _LicenseKind.atplH:
      return LicenseSelection(
        code: 'ATPL(H)',
        title: l.t("license_atpl_h_title"),
      );
    case _LicenseKind.fiA:
      return LicenseSelection(
        code: 'FI(A)',
        title: l.t("license_fi_a_title"),
      );
    case _LicenseKind.fiH:
      return LicenseSelection(
        code: 'FI(H)',
        title: l.t("license_fi_h_title"),
      );
    case _LicenseKind.mpl:
      return LicenseSelection(
        code: 'MPL',
        title: l.t("license_mpl_title"),
      );
    case _LicenseKind.spl:
      return LicenseSelection(
        code: 'SPL',
        title: l.t("license_spl_title"),
      );
    case _LicenseKind.bpl:
      return LicenseSelection(
        code: 'BPL',
        title: l.t("license_bpl_title"),
      );
    case _LicenseKind.rpl:
      return LicenseSelection(
        code: 'RPL',
        title: l.t("license_rpl_title"),
      );
    case _LicenseKind.laplA:
      return LicenseSelection(
        code: 'LAPL(A)',
        title: l.t("license_lapl_a_title"),
      );
    case _LicenseKind.laplH:
      return LicenseSelection(
        code: 'LAPL(H)',
        title: l.t("license_lapl_h_title"),
      );
    case _LicenseKind.acpl:
      return LicenseSelection(
        code: 'ACPL',
        title: l.t("license_acpl_title"),
      );
    case _LicenseKind.other:
      return LicenseSelection(
        code: 'OTRO',
        title: l.t("license_other_title"),
      );
  }
}

Widget _thinDivider() {
  return const Divider(
    thickness: 0.5,
    height: 8,
    color: Colors.white24,
  );
}

/// Fila de licencia con pill a la izquierda y título a la derecha (sin subtítulo).
Widget _buildLicenseTile({
  required BuildContext context,
  required _LicenseKind kind,
  required String code,
  required String title,
  required Color color,
}) {
  return InkWell(
    onTap: () {
      Navigator.of(context).pop(kind);
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Pill izquierda con el código de licencia.
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8.0,
              vertical: 3.5,
            ),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6.0),
              border: Border.all(color: Colors.white, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 2,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              code,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Solo título (multilínea si hace falta).
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
