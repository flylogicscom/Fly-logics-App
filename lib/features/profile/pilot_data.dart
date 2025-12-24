// lib/features/profile/pilot_data.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';

import 'package:fly_logicd_logbook_app/common/base_scaffold.dart';
import 'package:fly_logicd_logbook_app/common/custom_app_bar.dart';
import 'package:fly_logicd_logbook_app/common/button_styles.dart';
import 'package:fly_logicd_logbook_app/common/section_container.dart';
import 'package:fly_logicd_logbook_app/common/popwindow.dart';
import 'package:fly_logicd_logbook_app/common/phone_formatter.dart';
import 'package:fly_logicd_logbook_app/common/app_colors.dart';
import 'package:fly_logicd_logbook_app/utils/country_data.dart' as cdata;
import 'package:fly_logicd_logbook_app/utils/db_helper.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';

class PilotData extends StatefulWidget {
  const PilotData({super.key});

  @override
  State<PilotData> createState() => _PilotDataState();
}

class _PilotDataState extends State<PilotData> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _idNumberCtrl = TextEditingController();
  final _passportCtrl = TextEditingController();
  final _airlineCtrl = TextEditingController();
  final _employeeNumberCtrl = TextEditingController();

  DateTime? _birthDate;
  String? _photoPath;
  String? _phoneFlag;
  cdata.CountryData? _selectedCountry;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPilot();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _birthDateCtrl.dispose();
    _countryCtrl.dispose();
    _cityCtrl.dispose();
    _streetCtrl.dispose();
    _idNumberCtrl.dispose();
    _passportCtrl.dispose();
    _airlineCtrl.dispose();
    _employeeNumberCtrl.dispose();
    super.dispose();
  }

  // ---------- HELPERS ----------

  Future<void> _loadPilot() async {
    final data = await DBHelper.getPilot();
    if (!mounted || data == null) return;

    final l = AppLocalizations.of(context);

    // Nombre
    final rawName = (data['name'] as String? ?? '').trim();
    if (rawName.isNotEmpty) {
      final parts = rawName.split(' ');
      _firstNameCtrl.text = _toTitleCase(parts.first);
      if (parts.length > 1) {
        _lastNameCtrl.text = _toTitleCase(parts.sublist(1).join(' '));
      }
    }

    // Teléfono y bandera
    final storedPhone = (data['phone'] as String? ?? '').trim();
    if (storedPhone.isNotEmpty) {
      _phoneCtrl.text = storedPhone;
    }

    final savedFlagRaw = data['phoneFlag'] as String?;
    final savedFlag = savedFlagRaw != null && savedFlagRaw.trim().isNotEmpty
        ? savedFlagRaw.trim()
        : null;

    if (savedFlag != null) {
      _phoneFlag = savedFlag;
    } else if (storedPhone.isNotEmpty) {
      _phoneFlag = inferPhoneFlag(storedPhone);
    }

    // Email
    _emailCtrl.text = data['email'] as String? ?? '';

    // País (en BD guardas el nombre en inglés; lo traducimos al mostrar)
    final countryRaw = (data['country'] as String? ?? '').trim();
    if (countryRaw.isNotEmpty) {
      cdata.CountryData? match;
      for (final c in cdata.allCountryData) {
        if (c.name == 'Simulator') continue;
        if (c.name == countryRaw) {
          match = c;
          break;
        }
      }
      _selectedCountry = match;
      _countryCtrl.text = match != null
          ? '${match.flagEmoji} ${_localizedCountryName(l, match)}'
          : countryRaw;
    }

    // Pasaporte / IDs (forzar mayúsculas)
    _passportCtrl.text = _toUpper(data['passport'] as String? ?? '');

    // Campos extra
    _cityCtrl.text = _toTitleCase(data['city'] as String? ?? '');
    _streetCtrl.text = _toTitleCase(data['street'] as String? ?? '');
    _idNumberCtrl.text = _toUpper(data['idNumber'] as String? ?? '');
    _airlineCtrl.text = _toTitleCase(data['airline'] as String? ?? '');
    _employeeNumberCtrl.text =
        _toUpper(data['employeeNumber'] as String? ?? '');

    // Foto
    _photoPath = data['photoPath'] as String?;

    // Fecha de nacimiento
    final birth = data['birthDate'] as String?;
    if (birth != null && birth.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(birth);
      if (parsed != null) {
        _birthDate = parsed;
        _birthDateCtrl.text = _fmtDate(parsed);
      }
    }

    setState(() {});
  }

  String _fmtDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd/$mm/$yyyy';
  }

  String? _nullIfEmpty(String v) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  String _toUpper(String v) => v.toUpperCase();

  String _toTitleCase(String input) {
    final text = input.trim();
    if (text.isEmpty) return '';
    final sb = StringBuffer();
    bool start = true;

    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      final isSep = ch == ' ' ||
          ch == '\t' ||
          ch == '\n' ||
          ch == '-' ||
          ch == '\'' ||
          ch == '’';
      if (isSep) {
        sb.write(ch);
        start = true;
        continue;
      }

      if (start) {
        sb.write(ch.toUpperCase());
        start = false;
      } else {
        sb.write(ch.toLowerCase());
      }
    }
    return sb.toString();
  }

  // 🇦🇫 -> "AF"
  String? _isoFromFlagEmoji(String flagEmoji) {
    final runes =
        flagEmoji.runes.where((r) => r >= 0x1F1E6 && r <= 0x1F1FF).toList();
    if (runes.length < 2) return null;

    final a = runes[0] - 0x1F1E6 + 65;
    final b = runes[1] - 0x1F1E6 + 65;
    if (a < 65 || a > 90 || b < 65 || b > 90) return null;

    return String.fromCharCode(a) + String.fromCharCode(b);
  }

  String _localizedCountryName(AppLocalizations l, cdata.CountryData c) {
    final iso = _isoFromFlagEmoji(c.flagEmoji);
    if (iso == null) return c.name;

    // Soporta ambas por si tu sistema usa "." o "_"
    final kDot = 'countries.$iso';
    final vDot = l.t(kDot);
    if (vDot != kDot && vDot.trim().isNotEmpty) return vDot;

    final kUnd = 'countries_$iso';
    final vUnd = l.t(kUnd);
    if (vUnd != kUnd && vUnd.trim().isNotEmpty) return vUnd;

    return c.name;
  }

  // Normaliza el teléfono: deja solo dígitos y un '+' inicial (si lo hay)
  String _normalizePhone(String input) {
    final t = input.trim();
    if (t.isEmpty) return '';

    final buffer = StringBuffer();
    for (var i = 0; i < t.length; i++) {
      final ch = t[i];
      if (ch == '+' && buffer.isEmpty) {
        buffer.write(ch);
      } else if (RegExp(r'\d').hasMatch(ch)) {
        buffer.write(ch);
      }
    }
    return buffer.toString();
  }

  // Deducción de bandera desde el teléfono, tolerando espacios, guiones, etc.
  String? inferPhoneFlag(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return null;

    // 1) Si empieza con una bandera ya pegada
    for (final c in cdata.allCountryData) {
      final flag = c.flagEmoji.trim();
      if (flag.isNotEmpty && raw.startsWith(flag)) {
        return flag;
      }
    }

    // 2) Detección por código telefónico, ignorando formato
    final normalized = _normalizePhone(raw);
    if (normalized.isEmpty) return null;

    final digits = normalized.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return null;

    for (final c in cdata.allCountryData) {
      for (final code in c.phoneCode) {
        final codeNorm = _normalizePhone(code).replaceAll(RegExp(r'[^\d]'), '');
        if (codeNorm.isEmpty) continue;

        if (digits.startsWith(codeNorm)) {
          return c.flagEmoji;
        }
      }
    }

    return null;
  }

  Future<void> _savePilot() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final l = AppLocalizations.of(context);

      final first = _firstNameCtrl.text.trim();
      final last = _lastNameCtrl.text.trim();
      final name = ('$first $last').trim();

      String? countryToStore;
      if (_selectedCountry != null) {
        // Se guarda en BD el nombre original en inglés (estable)
        countryToStore = _selectedCountry!.name;
      } else {
        final raw = _countryCtrl.text.trim();
        countryToStore = raw.isEmpty ? null : raw;
      }

      final data = <String, Object?>{
        'name': name.isEmpty ? null : name,
        'displayName': name.isEmpty ? null : name,
        'phone': _nullIfEmpty(_phoneCtrl.text),
        'email': _nullIfEmpty(_emailCtrl.text),
        'country': countryToStore,
        'passport': _nullIfEmpty(_passportCtrl.text),
        'birthDate': _birthDate?.toIso8601String(),
        'city': _nullIfEmpty(_cityCtrl.text),
        'street': _nullIfEmpty(_streetCtrl.text),
        'idNumber': _nullIfEmpty(_idNumberCtrl.text),
        'airline': _nullIfEmpty(_airlineCtrl.text),
        'employeeNumber': _nullIfEmpty(_employeeNumberCtrl.text),
        'phoneFlag': _phoneFlag,
        'photoPath': _photoPath,
      };

      await DBHelper.upsertPilot(data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.t("pilot_data_saved"))),
      );

      await Future.delayed(const Duration(milliseconds: 250));
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.t("error_saving_pilot_data"))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(now.year - 25, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthDateCtrl.text = _fmtDate(picked);
      });
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 80,
    );
    if (picked != null && mounted) {
      setState(() => _photoPath = picked.path);
    }
  }

  Future<void> _showPhotoSourceGallery() async {
    await _pickPhoto(ImageSource.gallery);
  }

  Future<void> _pickCountry() async {
    final l = AppLocalizations.of(context);
    final searchCtrl = TextEditingController();

    List<cdata.CountryData> filtered =
        cdata.allCountryData.where((c) => c.name != 'Simulator').toList();

    cdata.CountryData? selected;

    await showPopWindow(
      context: context,
      title: l.t("select_country"),
      children: [
        StatefulBuilder(
          builder: (ctx, setSB) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(
                    labelText: l.t("search"),
                  ),
                  onChanged: (txt) {
                    final q = txt.trim().toLowerCase();
                    setSB(() {
                      filtered = cdata.allCountryData
                          .where((c) => c.name != 'Simulator')
                          .where((c) {
                        final loc = _localizedCountryName(l, c).toLowerCase();
                        return loc.contains(q) ||
                            c.name.toLowerCase().contains(q) ||
                            c.flagEmoji.contains(q);
                      }).toList();
                    });
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 280,
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final c = filtered[i];
                      return ListTile(
                        leading: Text(
                          c.flagEmoji,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        title: Text(
                          _localizedCountryName(l, c),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        onTap: () {
                          selected = c;
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedCountry = selected;
        _countryCtrl.text =
            '${selected!.flagEmoji} ${_localizedCountryName(l, selected!)}';
      });
    }
  }

  // ---------- UI BUILDERS ----------

  Widget _buildCameraIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: AppColors.teal3,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: SvgPicture.asset(
          'assets/icons/photo.svg',
          width: 20,
          height: 20,
          colorFilter: const ColorFilter.mode(
            Colors.white,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection(BuildContext context) {
    final l = AppLocalizations.of(context);
    const double avatarRadius = 80;

    return Column(
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: _showPhotoSourceGallery,
              child: CircleAvatar(
                radius: avatarRadius,
                backgroundColor: Theme.of(context).cardColor,
                child: ClipOval(
                  child: _photoPath != null
                      ? Image.file(
                          File(_photoPath!),
                          width: avatarRadius * 2,
                          height: avatarRadius * 2,
                          fit: BoxFit.cover,
                        )
                      : Image.asset(
                          'assets/icons/preperfil.png',
                          width: avatarRadius * 2,
                          height: avatarRadius * 2,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            ),
            Positioned(
              bottom: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _pickPhoto(ImageSource.camera),
                child: _buildCameraIcon(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _showPhotoSourceGallery,
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1,
            ),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: Text(l.t("change_photo")),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPilotDetailsSection(BuildContext context) {
    final l = AppLocalizations.of(context);

    return SectionContainer(
      children: [
        SectionItemTitle(title: l.t("pilot_details")),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _firstNameCtrl,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [TitleCaseTextFormatter()],
                decoration: InputDecoration(
                  labelText: l.t("first_name"),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _lastNameCtrl,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [TitleCaseTextFormatter()],
                decoration: InputDecoration(
                  labelText: l.t("last_name"),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          inputFormatters: const [PhoneFormatter()],
          decoration: InputDecoration(
            labelText: l.t("phone_number"),
            prefixText: _phoneFlag != null ? '$_phoneFlag ' : null,
          ),
          onChanged: (value) {
            final trimmed = value.trim();

            if (trimmed.isEmpty) {
              setState(() {
                _phoneFlag = null;
              });
              return;
            }

            final newFlag = inferPhoneFlag(value);
            if (newFlag != null) {
              setState(() {
                _phoneFlag = newFlag;
              });
            }
          },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: l.t("email"),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _pickBirthDate,
          child: AbsorbPointer(
            child: TextField(
              controller: _birthDateCtrl,
              decoration: InputDecoration(
                labelText: l.t("birth_date"),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _pickCountry,
          child: AbsorbPointer(
            child: TextField(
              controller: _countryCtrl,
              decoration: InputDecoration(
                labelText: l.t("country"),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _cityCtrl,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [TitleCaseTextFormatter()],
          decoration: InputDecoration(
            labelText: l.t("city"),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _streetCtrl,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [TitleCaseTextFormatter()],
          decoration: InputDecoration(
            labelText: l.t("street"),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _idNumberCtrl,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [UpperCaseTextFormatter()],
          decoration: InputDecoration(
            labelText: l.t("id_number"),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passportCtrl,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [UpperCaseTextFormatter()],
          decoration: InputDecoration(
            labelText: l.t("passport"),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _airlineCtrl,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [TitleCaseTextFormatter()],
          decoration: InputDecoration(
            labelText: l.t("airline"),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _employeeNumberCtrl,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [UpperCaseTextFormatter()],
          decoration: InputDecoration(
            labelText: l.t("employee_number"),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return BaseScaffold(
      appBar: CustomAppBar(
        title: l.t("pilot_data"),
        rightIconPath: 'assets/icons/logoback.svg',
        onRightIconTap: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPhotoSection(context),
            _buildPilotDetailsSection(context),
            const SizedBox(height: 16),
            ButtonStyles.pillCancelSave(
              cancelLabel: l.t("cancel"),
              saveLabel: _saving ? l.t("saving") : l.t("save"),
              onCancel: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              onSave: () async {
                if (!_saving) {
                  await _savePilot();
                }
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ---------------- FORMATTERS ----------------

class TitleCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final sb = StringBuffer();
    bool start = true;

    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      final isSep = ch == ' ' ||
          ch == '\t' ||
          ch == '\n' ||
          ch == '-' ||
          ch == '\'' ||
          ch == '’';

      if (isSep) {
        sb.write(ch);
        start = true;
        continue;
      }

      if (start) {
        sb.write(ch.toUpperCase());
        start = false;
      } else {
        sb.write(ch.toLowerCase());
      }
    }

    final transformed = sb.toString();
    if (transformed == text) return newValue;

    return TextEditingValue(
      text: transformed,
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final upper = newValue.text.toUpperCase();
    if (upper == newValue.text) return newValue;
    return TextEditingValue(
      text: upper,
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}
