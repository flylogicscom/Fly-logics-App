// lib/features/expenses/add_expenses_page.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import 'package:fly_logicd_logbook_app/common/base_scaffold.dart';
import 'package:fly_logicd_logbook_app/common/custom_app_bar.dart';
import 'package:fly_logicd_logbook_app/common/section_container.dart';
import 'package:fly_logicd_logbook_app/common/app_text_styles.dart';
import 'package:fly_logicd_logbook_app/common/button_styles.dart';
import 'package:fly_logicd_logbook_app/common/app_colors.dart';
import 'package:fly_logicd_logbook_app/common/popwindow.dart';

import 'package:fly_logicd_logbook_app/utils/db_helper.dart';
import 'package:fly_logicd_logbook_app/utils/currency_picker.dart';
import 'package:fly_logicd_logbook_app/l10n/app_localizations.dart';

// Modelo simple para cargos del viaje
class _TripCharge {
  String? type;
  String ticket; // RCP, INV, CRCP (tipo)
  DateTime date;
  String? detail;
  double? amount;
  String? currencyCode;
  String? currencyEmoji;
  _TripCharge({
    this.type,
    this.ticket = 'RCP',
    required this.date,
    this.detail,
    this.amount,
    this.currencyCode,
    this.currencyEmoji,
  });
}

// Acumulado por moneda
class _CurrencyTotal {
  double sum;
  String? emoji;
  _CurrencyTotal(this.sum, this.emoji);
}

class AddExpensesPage extends StatefulWidget {
  final int sheetId;
  final String sheetTitle;
  final bool editable;

  const AddExpensesPage({
    super.key,
    required this.sheetId,
    required this.sheetTitle,
    this.editable = true,
  });

  @override
  State<AddExpensesPage> createState() => _AddExpensesPageState();
}

class _AddExpensesPageState extends State<AddExpensesPage> {
  late bool _editable;
  late String _title;

  // personal
  final TextEditingController _personalDataCtrl = TextEditingController();

  // bank stored
  String? _bankName;
  String? _accountType;
  String? _accountNumber;
  String? _ibanSwift; // NUEVO
  String? _holderName;
  String? _idNumber;
  String? _email;
  String? _localCurrencyText; // Ej: "CLP 🇨🇱 Chilean Peso"
  String? _currencyCode; // moneda local (código)
  String? _currencyEmoji; // moneda local (emoji)

  // travel limits
  late DateTime _createdAt;
  DateTime? _beginDate;
  DateTime? _endDate;

  // max approved
  double? _maxApprovedAmount;
  String? _maxApprovedCurrencyCode;
  String? _maxApprovedCurrencyEmoji;

  // extra approved
  double? _extraApprovedAmount;
  String? _extraApprovedCurrencyCode;
  String? _extraApprovedCurrencyEmoji;

  // trip charges
  final List<_TripCharge> _charges = [];

  // ratios de cambio por moneda origen -> moneda local
  final Map<String, double> _fxRates = {};

  @override
  void initState() {
    super.initState();
    _editable = widget.editable;
    _title = widget.sheetTitle;

    _createdAt = DateTime.now();
    _beginDate = DateTime(_createdAt.year, _createdAt.month, _createdAt.day);
    _endDate = null;

    _loadFromDb();
  }

  @override
  void dispose() {
    _personalDataCtrl.dispose();
    super.dispose();
  }

  // ================== DB LOAD / SAVE ==================

  Future<void> _loadFromDb() async {
    final header = await DBHelper.getExpenseSheetHeader(widget.sheetId);
    if (header != null) {
      setState(() {
        _title = (header['title'] as String?) ?? _title;

        _personalDataCtrl.text = (header['personalData'] as String?) ?? '';

        _bankName = header['bankName'] as String?;
        _accountType = header['accountType'] as String?;
        _accountNumber = header['accountNumber'] as String?;
        _ibanSwift = header['ibanSwift'] as String?; // NUEVO
        _holderName = header['holderName'] as String?;
        _idNumber = header['idNumber'] as String?;
        _email = header['email'] as String?;

        _localCurrencyText = header['localCurrencyText'] as String?;
        _currencyCode = header['localCurrencyCode'] as String?;
        _currencyEmoji = header['localCurrencyEmoji'] as String?;

        _createdAt = _dtFromInt(header['createdAt']) ?? _createdAt;
        _beginDate = _dtFromInt(header['beginDate']) ?? _beginDate;
        _endDate = _dtFromInt(header['endDate']) ?? _endDate;

        _maxApprovedAmount = (header['maxApprovedAmount'] as num?)?.toDouble();
        _maxApprovedCurrencyCode = header['maxApprovedCurrencyCode'] as String?;
        _maxApprovedCurrencyEmoji =
            header['maxApprovedCurrencyEmoji'] as String?;

        _extraApprovedAmount =
            (header['extraApprovedAmount'] as num?)?.toDouble();
        _extraApprovedCurrencyCode =
            header['extraApprovedCurrencyCode'] as String?;
        _extraApprovedCurrencyEmoji =
            header['extraApprovedCurrencyEmoji'] as String?;
      });
    }

    final chargesRows = await DBHelper.getExpenseCharges(widget.sheetId);
    if (chargesRows.isNotEmpty) {
      setState(() {
        _charges
          ..clear()
          ..addAll(
            chargesRows.map((r) {
              return _TripCharge(
                type: r['type'] as String?,
                ticket: (r['ticket'] as String?) ?? 'RCP',
                date: _dtFromInt(r['date']) ?? DateTime.now(),
                detail: r['detail'] as String?,
                amount: (r['amount'] as num?)?.toDouble(),
                currencyCode: r['currencyCode'] as String?,
                currencyEmoji: r['currencyEmoji'] as String?,
              );
            }),
          );
      });
    }

    final fx = await DBHelper.getExpenseFxRates(widget.sheetId);
    if (fx.isNotEmpty) {
      setState(() {
        _fxRates
          ..clear()
          ..addAll(fx);
      });
    }
  }

  Future<void> _saveAndClose() async {
    await DBHelper.upsertExpenseSheetHeader(
      sheetId: widget.sheetId,
      title: _title,
      personalData: _toNull(_personalDataCtrl.text),
      bankName: _bankName,
      accountType: _accountType,
      accountNumber: _accountNumber,
      ibanSwift: _ibanSwift, // NUEVO
      holderName: _holderName,
      idNumber: _idNumber,
      email: _email,
      localCurrencyText: _localCurrencyText,
      localCurrencyCode: _currencyCode,
      localCurrencyEmoji: _currencyEmoji,
      createdAt: _createdAt,
      beginDate: _beginDate,
      endDate: _endDate,
      maxApprovedAmount: _maxApprovedAmount,
      maxApprovedCurrencyCode: _maxApprovedCurrencyCode,
      maxApprovedCurrencyEmoji: _maxApprovedCurrencyEmoji,
      extraApprovedAmount: _extraApprovedAmount,
      extraApprovedCurrencyCode: _extraApprovedCurrencyCode,
      extraApprovedCurrencyEmoji: _extraApprovedCurrencyEmoji,
    );

    final chargesMaps = _charges.map<Map<String, Object?>>((c) {
      return {
        'type': c.type,
        'ticket': c.ticket,
        'date': c.date.millisecondsSinceEpoch,
        'detail': c.detail,
        'amount': c.amount,
        'currencyCode': c.currencyCode,
        'currencyEmoji': c.currencyEmoji,
      };
    }).toList();

    await DBHelper.replaceExpenseCharges(
      widget.sheetId,
      chargesMaps,
    );

    await DBHelper.replaceExpenseFxRates(
      widget.sheetId,
      _fxRates,
    );

    _close();
  }

  DateTime? _dtFromInt(Object? v) {
    if (v is int) {
      return DateTime.fromMillisecondsSinceEpoch(v);
    }
    if (v is num) {
      return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    }
    return null;
  }

  // ================== BASICS ==================

  void _toggleEditable() {
    setState(() {
      _editable = !_editable;
    });
  }

  void _close() {
    Navigator.pop<bool>(context, _editable);
  }

  Future<void> _editTitle() async {
    final l = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: _title);
    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(l.t("edit_title")),
          content: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              labelText: l.t("title"),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.t("cancel")),
            ),
            TextButton(
              onPressed: () {
                final v = ctrl.text.trim();
                if (v.isNotEmpty) {
                  setState(() => _title = v);
                }
                Navigator.pop(context);
              },
              child: Text(l.t("save")),
            ),
          ],
        );
      },
    );
  }

  // ================== POPUPS ==================

  Future<void> _openBankPopup() async {
    if (!_editable) return;
    final l = AppLocalizations.of(context);

    final bankNameCtrl = TextEditingController(text: _bankName ?? '');
    final accountNumberCtrl = TextEditingController(text: _accountNumber ?? '');
    final ibanCtrl = TextEditingController(text: _ibanSwift ?? ''); // NUEVO
    final holderCtrl = TextEditingController(text: _holderName ?? '');
    final idCtrl = TextEditingController(text: _idNumber ?? '');
    final emailCtrl = TextEditingController(text: _email ?? '');
    final currencyCtrl = TextEditingController(text: _localCurrencyText ?? '');

    String accountType = _accountType ?? l.t('checking_account');
    String tempCurrencyCode = _currencyCode ?? '';
    String tempCurrencyEmoji = _currencyEmoji ?? '';
    String tempCurrencyText = _localCurrencyText ?? '';

    await showPopWindow(
      context: context,
      title: l.t('bank_details'),
      children: [
        TextField(
          controller: bankNameCtrl,
          decoration: InputDecoration(
            labelText: l.t('bank_name'),
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: accountType,
          decoration: InputDecoration(
            labelText: l.t('account_type'),
          ),
          items: [
            DropdownMenuItem(
              value: l.t('checking_account'),
              child: Text(l.t('checking_account')),
            ),
            DropdownMenuItem(
              value: l.t('on_demand_at_sight'),
              child: Text(l.t('on_demand_at_sight')),
            ),
            DropdownMenuItem(
              value: l.t('savings_account'),
              child: Text(l.t('savings_account')),
            ),
          ],
          onChanged: (v) {
            if (v != null) {
              accountType = v;
            }
          },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: accountNumberCtrl,
          decoration: InputDecoration(
            labelText: l.t('account_number'),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: ibanCtrl,
          decoration: InputDecoration(
            labelText: l.t('iban_swift'),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: holderCtrl,
          decoration: InputDecoration(
            labelText: l.t('account_holder'),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: idCtrl,
          decoration: InputDecoration(
            labelText: l.t('id_number'),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: l.t('email'),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () async {
            final picked = await showCurrencyPickerPopup(context);
            if (picked != null) {
              tempCurrencyCode = picked.code;
              tempCurrencyEmoji = picked.emoji;
              tempCurrencyText =
                  '${picked.code} ${picked.emoji} ${picked.label}';
              currencyCtrl.text = tempCurrencyText;
            }
          },
          child: AbsorbPointer(
            child: TextField(
              controller: currencyCtrl,
              decoration: InputDecoration(
                labelText: l.t('local_currency'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ButtonStyles.pillCancelSave(
          onCancel: () => Navigator.pop(context),
          onSave: () {
            setState(() {
              _bankName = _toNull(bankNameCtrl.text);
              _accountType = accountType;
              _accountNumber = _toNull(accountNumberCtrl.text);
              _ibanSwift = _toNull(ibanCtrl.text);
              _holderName = _toNull(holderCtrl.text);
              _idNumber = _toNull(idCtrl.text);
              _email = _toNull(emailCtrl.text);
              _localCurrencyText = _toNull(tempCurrencyText);
              _currencyCode =
                  tempCurrencyCode.isEmpty ? null : tempCurrencyCode;
              _currencyEmoji =
                  tempCurrencyEmoji.isEmpty ? null : tempCurrencyEmoji;
            });
            Navigator.pop(context);
          },
          cancelLabel: l.t('cancel'),
          saveLabel: l.t('save'),
        ),
      ],
    );
  }

  Future<void> _openMaxApprovedPopup() async {
    if (!_editable) return;
    final l = AppLocalizations.of(context);

    final amountCtrl = TextEditingController(
      text: _maxApprovedAmount != null
          ? _maxApprovedAmount!.toStringAsFixed(2)
          : '',
    );
    final currencyCtrl = TextEditingController(
      text: _maxApprovedCurrencyCode != null
          ? (_maxApprovedCurrencyEmoji != null
              ? '${_maxApprovedCurrencyCode!} ${_maxApprovedCurrencyEmoji!}'
              : _maxApprovedCurrencyCode!)
          : '',
    );

    String tempCode = _maxApprovedCurrencyCode ?? '';
    String tempEmoji = _maxApprovedCurrencyEmoji ?? '';

    await showPopWindow(
      context: context,
      title: l.t('maximum_authorized'),
      children: [
        TextField(
          controller: amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l.t('amount'),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () async {
            final picked = await showCurrencyPickerPopup(context);
            if (picked != null) {
              tempCode = picked.code;
              tempEmoji = picked.emoji;
              currencyCtrl.text = tempEmoji.isNotEmpty
                  ? '${picked.code} ${picked.emoji}'
                  : picked.code;
            }
          },
          child: AbsorbPointer(
            child: TextField(
              controller: currencyCtrl,
              decoration: InputDecoration(
                labelText: l.t('currency'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ButtonStyles.pillCancelSave(
          onCancel: () => Navigator.pop(context),
          onSave: () {
            final raw = amountCtrl.text.trim();
            final parsed = double.tryParse(raw.replaceAll(',', '.'));
            setState(() {
              _maxApprovedAmount = parsed;
              _maxApprovedCurrencyCode = tempCode.isEmpty ? null : tempCode;
              _maxApprovedCurrencyEmoji = tempEmoji.isEmpty ? null : tempEmoji;
            });
            Navigator.pop(context);
          },
          cancelLabel: l.t('cancel'),
          saveLabel: l.t('save'),
        ),
      ],
    );
  }

  Future<void> _openExtraApprovedPopup() async {
    if (!_editable) return;
    final l = AppLocalizations.of(context);

    final amountCtrl = TextEditingController(
      text: _extraApprovedAmount != null
          ? _extraApprovedAmount!.toStringAsFixed(2)
          : '',
    );
    final currencyCtrl = TextEditingController(
      text: _extraApprovedCurrencyCode != null
          ? (_extraApprovedCurrencyEmoji != null
              ? '${_extraApprovedCurrencyCode!} ${_extraApprovedCurrencyEmoji!}'
              : _extraApprovedCurrencyCode!)
          : '',
    );

    String tempCode = _extraApprovedCurrencyCode ?? '';
    String tempEmoji = _extraApprovedCurrencyEmoji ?? '';

    await showPopWindow(
      context: context,
      title: l.t('extra_authorized'),
      children: [
        TextField(
          controller: amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l.t('amount'),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () async {
            final picked = await showCurrencyPickerPopup(context);
            if (picked != null) {
              tempCode = picked.code;
              tempEmoji = picked.emoji;
              currencyCtrl.text = tempEmoji.isNotEmpty
                  ? '${picked.code} ${picked.emoji}'
                  : picked.code;
            }
          },
          child: AbsorbPointer(
            child: TextField(
              controller: currencyCtrl,
              decoration: InputDecoration(
                labelText: l.t('currency'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ButtonStyles.pillCancelSave(
          onCancel: () => Navigator.pop(context),
          onSave: () {
            final raw = amountCtrl.text.trim();
            final parsed = double.tryParse(raw.replaceAll(',', '.'));
            setState(() {
              _extraApprovedAmount = parsed;
              _extraApprovedCurrencyCode = tempCode.isEmpty ? null : tempCode;
              _extraApprovedCurrencyEmoji =
                  tempEmoji.isEmpty ? null : tempEmoji;
            });
            Navigator.pop(context);
          },
          cancelLabel: l.t('cancel'),
          saveLabel: l.t('save'),
        ),
      ],
    );
  }

  Future<void> _openChargePopup({int? index}) async {
    if (!_editable) return;
    final l = AppLocalizations.of(context);

    final existing = (index != null && index >= 0 && index < _charges.length)
        ? _charges[index]
        : null;

    final typeCtrl = TextEditingController(text: existing?.type ?? '');
    final detailCtrl = TextEditingController(text: existing?.detail ?? '');
    final amountCtrl = TextEditingController(
      text: (existing?.amount != null)
          ? existing!.amount!.toStringAsFixed(2)
          : '',
    );
    final currencyCtrl = TextEditingController(
      text: (existing?.currencyCode != null)
          ? ((existing?.currencyEmoji != null)
              ? '${existing!.currencyCode!} ${existing.currencyEmoji!}'
              : existing!.currencyCode!)
          : '',
    );
    final ticketCtrl = TextEditingController(
      text: existing?.ticket ?? '',
    );

    DateTime tempDate = existing?.date ?? _beginDate ?? DateTime.now();
    String tempTicket = existing?.ticket ?? 'RCP';
    String tempCode = existing?.currencyCode ?? '';
    String tempEmoji = existing?.currencyEmoji ?? '';

    final dateCtrl = TextEditingController(text: _fmtDate(context, tempDate));

    await showPopWindow(
      context: context,
      title: l.t('new_charge'),
      children: [
        TextField(
          controller: typeCtrl,
          decoration: InputDecoration(
            labelText: l.t('charge_type'),
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: tempTicket,
          decoration: InputDecoration(
            labelText: l.t('ticket_type'),
          ),
          items: [
            DropdownMenuItem(value: 'RCP', child: Text(l.t('receipt_rcp'))),
            DropdownMenuItem(value: 'INV', child: Text(l.t('invoice_inv'))),
            DropdownMenuItem(
              value: 'CRCP',
              child: Text(l.t('credit_card_receipt_crcp')),
            ),
          ],
          onChanged: (v) {
            if (v != null) tempTicket = v;
          },
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: tempDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              tempDate = DateTime(picked.year, picked.month, picked.day);
              dateCtrl.text = _fmtDate(context, tempDate);
            }
          },
          child: AbsorbPointer(
            child: TextField(
              controller: dateCtrl,
              decoration: InputDecoration(
                labelText: l.t('date'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: ticketCtrl,
          maxLines: 1,
          decoration: InputDecoration(
            labelText: l.t('ticket_number'),
          ),
        ),
        TextField(
          controller: detailCtrl,
          maxLength: 70,
          maxLines: null,
          decoration: InputDecoration(
            labelText: l.t('detail'),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(
            signed: false,
            decimal: false,
          ),
          decoration: InputDecoration(
            labelText: l.t('amount'),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () async {
            final picked = await showCurrencyPickerPopup(context);
            if (picked != null) {
              tempCode = picked.code;
              tempEmoji = picked.emoji;
              currencyCtrl.text = tempEmoji.isNotEmpty
                  ? '${picked.code} ${picked.emoji}'
                  : picked.code;
            }
          },
          child: AbsorbPointer(
            child: TextField(
              controller: currencyCtrl,
              decoration: InputDecoration(
                labelText: l.t('currency'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ButtonStyles.pillCancelSave(
          onCancel: () => Navigator.pop(context),
          onSave: () {
            final raw = amountCtrl.text.trim();
            final parsed = double.tryParse(raw.replaceAll(',', '.'));
            setState(() {
              final payload = _TripCharge(
                type: _toNull(typeCtrl.text),
                ticket: tempTicket,
                date: tempDate,
                detail: _toNull(detailCtrl.text),
                amount: parsed,
                currencyCode: tempCode.isEmpty ? null : tempCode,
                currencyEmoji: tempEmoji.isEmpty ? null : tempEmoji,
              );
              if (existing != null && index != null) {
                _charges[index] = payload;
              } else {
                _charges.add(payload);
              }
            });
            Navigator.pop(context);
          },
          cancelLabel: l.t('cancel'),
          saveLabel: l.t('save'),
        ),
      ],
    );
  }

  // Popup ratio de cambio
  Future<void> _openFxPopup(String code) async {
    if (!_editable) return;
    final l = AppLocalizations.of(context);

    final initial = _fxRates[code];
    final ratioCtrl =
        TextEditingController(text: initial != null ? '$initial' : '');
    await showPopWindow(
      context: context,
      title: l.t('exchange_rate'),
      children: [
        Text(l.t('set_ratio_to_local_currency'), style: AppTextStyles.body),
        const SizedBox(height: 8),
        Text(
          '${l.t('one')} $code = ? ${_currencyCode ?? l.t('local')}',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: ratioCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l.t('ratio')),
        ),
        const SizedBox(height: 12),
        ButtonStyles.pillCancelSave(
          onCancel: () => Navigator.pop(context),
          onSave: () {
            final raw = ratioCtrl.text.trim();
            final parsed = double.tryParse(raw.replaceAll(',', '.'));
            setState(() {
              if (parsed != null && parsed > 0) {
                _fxRates[code] = parsed;
              } else {
                _fxRates.remove(code);
              }
            });
            Navigator.pop(context);
          },
          cancelLabel: l.t('cancel'),
          saveLabel: l.t('save'),
        ),
      ],
    );
  }

  // ================== HELPERS LÓGICA ==================

  String? _toNull(String v) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  String _fmtDate(BuildContext context, DateTime? d) {
    if (d == null) return '--/--/----';
    final lang = Localizations.localeOf(context).languageCode;
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    if (lang == 'en') {
      return '$mm/$dd/$yyyy';
    }
    return '$dd/$mm/$yyyy';
  }

  String _fmtDayMonth(BuildContext context, DateTime? d) {
    if (d == null) return '--/--';
    final lang = Localizations.localeOf(context).languageCode;
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return (lang == 'en') ? '$mm/$dd' : '$dd/$mm';
  }

  Future<void> _pickBeginDate() async {
    if (!_editable) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _beginDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _beginDate = DateTime(picked.year, picked.month, picked.day);
        if (_endDate != null && _endDate!.isBefore(_beginDate!)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    if (!_editable) return;
    final base = _beginDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? base,
      firstDate: base,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _endDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  String _tripLabel() {
    final l = AppLocalizations.of(context);
    if (_beginDate == null || _endDate == null) return '';
    final b = DateTime(_beginDate!.year, _beginDate!.month, _beginDate!.day);
    final e = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
    final days = e.difference(b).inDays + 1;
    final nights = days > 1 ? days - 1 : 0;
    final dayLabel = l.t(days == 1 ? 'day' : 'days');
    final nightLabel = l.t(nights == 1 ? 'night' : 'nights');
    return '$days $dayLabel, $nights $nightLabel';
  }

  Widget _budgetRow({
    required String label,
    required String rightText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(label, style: AppTextStyles.body),
              ),
            ),
            Container(
              width: 1,
              height: 20,
              color: Theme.of(context).dividerColor.withOpacity(0.6),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(rightText, style: AppTextStyles.body),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildMaxApprovedRight() {
    final amount = _maxApprovedAmount ?? 0;
    final formatted = amount.toStringAsFixed(2);
    if (_maxApprovedCurrencyCode == null) return formatted;
    if (_maxApprovedCurrencyEmoji == null ||
        _maxApprovedCurrencyEmoji!.isEmpty) {
      return '$formatted ${_maxApprovedCurrencyCode!}';
    }
    return '$formatted ${_maxApprovedCurrencyCode!} ${_maxApprovedCurrencyEmoji!}';
  }

  String _buildExtraApprovedRight() {
    final amount = _extraApprovedAmount ?? 0;
    final formatted = amount.toStringAsFixed(2);
    if (_extraApprovedCurrencyCode == null) return formatted;
    if (_extraApprovedCurrencyEmoji == null ||
        _extraApprovedCurrencyEmoji!.isEmpty) {
      return '$formatted ${_extraApprovedCurrencyCode!}';
    }
    return '$formatted ${_extraApprovedCurrencyCode!} ${_extraApprovedCurrencyEmoji!}';
  }

  String _buildChargeAmountRightFor(_TripCharge c) {
    final amount = c.amount ?? 0;
    final formatted = amount.toStringAsFixed(2);
    if (c.currencyCode == null) return formatted;
    if (c.currencyEmoji == null || c.currencyEmoji!.isEmpty) {
      return '$formatted ${c.currencyCode!}';
    }
    return '$formatted ${c.currencyCode!} ${c.currencyEmoji!}';
  }

  Map<String, _CurrencyTotal> _groupChargesByCurrency() {
    final Map<String, _CurrencyTotal> map = {};
    for (final c in _charges) {
      final code = c.currencyCode;
      if (code == null) continue;
      final amt = c.amount ?? 0;
      if (map.containsKey(code)) {
        map[code]!.sum += amt;
        map[code]!.emoji ??= c.currencyEmoji;
      } else {
        map[code] = _CurrencyTotal(amt, c.currencyEmoji);
      }
    }
    return map;
  }

  bool _hasOkRatio(String code) {
    if (_currencyCode == null) return false;
    if (code == _currencyCode) return true;
    final r = _fxRates[code];
    return r != null && r > 0;
  }

  double _convertToLocal(String code, double sum) {
    if (_currencyCode == null) return 0;
    if (code == _currencyCode) return sum;
    final r = _fxRates[code];
    if (r == null || r <= 0) return 0;
    return sum * r;
  }

  double _convertBudgetToLocal(double? amount, String? code) {
    if (amount == null || code == null || _currencyCode == null) return 0;
    if (code == _currencyCode) return amount;
    final r = _fxRates[code];
    if (r == null || r <= 0) return 0;
    return amount * r;
  }

  String _fmtAmountCodeEmoji(double amount, String? code, String? emoji) {
    final cc = code ?? '';
    final em = (emoji != null && emoji.isNotEmpty) ? ' $emoji' : '';
    if (cc.isEmpty && em.isEmpty) {
      return amount.toStringAsFixed(2);
    }
    return '${amount.toStringAsFixed(2)} $cc$em';
  }

  double _localGrandTotal(Map<String, _CurrencyTotal> grouped) {
    double total = 0;
    grouped.forEach((code, data) {
      total += _convertToLocal(code, data.sum);
    });
    return total;
  }

  // ================== UI ROWS ==================

  Widget _chargeRow({
    required String leftText,
    required String dateLabel,
    required String ticket,
    required String amountText,
    required VoidCallback onTap,
  }) {
    const Color borderColor = AppColors.teal4;
    const Color textColor = AppColors.teal4;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                leftText,
                style: AppTextStyles.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dateLabel.isNotEmpty) ...[
                  Text(
                    dateLabel,
                    style: AppTextStyles.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                  const SizedBox(width: 8),
                ],
                if (ticket.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: borderColor,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      ticket,
                      style: AppTextStyles.body.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (amountText.isNotEmpty)
                  Text(
                    amountText,
                    style: AppTextStyles.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalRow({
    required String code,
    required String leftText,
    required bool okRatio,
    required String rightText,
    required VoidCallback? onTap,
  }) {
    final l = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                leftText,
                style: AppTextStyles.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: okRatio ? AppColors.teal4 : const Color(0xFFAF0000),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                okRatio ? l.t('ok_exg') : l.t('no_exg'),
                style: AppTextStyles.body.copyWith(fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              rightText,
              style: AppTextStyles.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ],
        ),
      ),
    );
  }

  // ================== BUILD ==================

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    final grouped = _groupChargesByCurrency();
    final chargesCount = _charges.length;
    final currenciesCount = grouped.length;

    final double expensesLocal = _localGrandTotal(grouped);
    final String localCode = _currencyCode ?? '';
    final String? localEmoji = _currencyEmoji;

    final double maxLocal =
        _convertBudgetToLocal(_maxApprovedAmount, _maxApprovedCurrencyCode);
    final double extraLocal =
        _convertBudgetToLocal(_extraApprovedAmount, _extraApprovedCurrencyCode);
    final bool hasBudget = (maxLocal > 0) || (extraLocal > 0);
    final double available = (maxLocal + extraLocal) - expensesLocal;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _close();
        }
      },
      child: BaseScaffold(
        appBar: CustomAppBar(
          title: l.t('add_expenses'),
          rightIconPath: 'assets/icons/logoback.svg',
          onRightIconTap: _close,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // encabezado
              SectionContainer(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _editTitle,
                        child: Text(
                          _title,
                          style: AppTextStyles.headline2,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _toggleEditable,
                        icon: Icon(
                          _editable ? Icons.lock_open : Icons.lock,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 2,
                    color: Colors.white.withOpacity(0.4),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _editable
                        ? l.t('section_is_editable')
                        : l.t('section_is_read_only'),
                    style: AppTextStyles.body,
                  ),
                ],
              ),
              // personal + bank
              SectionContainer(
                children: [
                  SectionItemTitle(title: l.t('personal_data')),
                  TextFormField(
                    controller: _personalDataCtrl,
                    enabled: _editable,
                    decoration: InputDecoration(
                      labelText: l.t('write_here'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SectionItemTitle(title: l.t('bank_details')),
                  InkWell(
                    onTap: _openBankPopup,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: (_bankName == null &&
                              _accountType == null &&
                              _currencyCode == null)
                          ? Center(
                              child: ButtonStyles.pillInfo(
                                label: '+ ${l.t('add_bank_details')}',
                                onTap: _openBankPopup,
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).dividerColor,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Row(
                                children: [
                                  if (_bankName != null) ...[
                                    Flexible(
                                      child: Text(
                                        _bankName!,
                                        style: AppTextStyles.body,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                  if (_bankName != null &&
                                      (_accountType != null ||
                                          _currencyCode != null))
                                    const SizedBox(width: 12),
                                  if (_accountType != null) ...[
                                    Text(
                                      _accountType!,
                                      style: AppTextStyles.body,
                                    ),
                                  ],
                                  if (_accountType != null &&
                                      _currencyCode != null)
                                    const SizedBox(width: 12),
                                  if (_currencyCode != null) ...[
                                    Text(
                                      _currencyEmoji != null
                                          ? '${_currencyCode!} ${_currencyEmoji!}'
                                          : _currencyCode!,
                                      style: AppTextStyles.body,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              // travel limits
              SectionContainer(
                children: [
                  SectionItemTitle(title: l.t('travel_limits')),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickBeginDate,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.t('begins')),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calendar_today, size: 18),
                                  const SizedBox(width: 6),
                                  Text(_fmtDate(context, _beginDate)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 48,
                        color: Theme.of(context).dividerColor.withOpacity(0.5),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickEndDate,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(l.t('ends')),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    _endDate == null
                                        ? l.t('pending')
                                        : _fmtDate(context, _endDate),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.calendar_today, size: 18),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_beginDate != null && _endDate != null) ...[
                    const SizedBox(height: 5),
                    ButtonStyles.pillInfo(
                      label: _tripLabel(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (_maxApprovedAmount == null) ...[
                    ButtonStyles.pillInfo(
                      label: l.t('add_max_approved'),
                      onTap: _openMaxApprovedPopup,
                    ),
                  ] else ...[
                    _budgetRow(
                      label: l.t('maximum_authorized'),
                      rightText: _buildMaxApprovedRight(),
                      onTap: _openMaxApprovedPopup,
                    ),
                  ],
                  if (_maxApprovedAmount != null) ...[
                    const SizedBox(height: 10),
                    if (_extraApprovedAmount == null) ...[
                      ButtonStyles.pillInfo(
                        label: l.t('add_extra_approved'),
                        onTap: _openExtraApprovedPopup,
                      ),
                    ] else ...[
                      _budgetRow(
                        label: l.t('extra_authorized'),
                        rightText: _buildExtraApprovedRight(),
                        onTap: _openExtraApprovedPopup,
                      ),
                    ],
                  ],
                ],
              ),
              // charges of the trip + totals
              SectionContainer(
                children: [
                  SectionItemTitle(title: l.t('trip_charges')),
                  if (_charges.isNotEmpty) ...[
                    Column(
                      children: List.generate(_charges.length, (i) {
                        final c = _charges[i];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: i == _charges.length - 1 ? 0 : 10,
                          ),
                          child: _chargeRow(
                            leftText: c.type ?? l.t('charge'),
                            dateLabel: _fmtDayMonth(context, c.date),
                            ticket: c.ticket,
                            amountText: _buildChargeAmountRightFor(c),
                            onTap: () => _openChargePopup(index: i),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 8,
                    ),
                    child: ButtonStyles.pillInfo(
                      label: '+ ${l.t('add_trip_charge')}',
                      onTap: () => _openChargePopup(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionItemTitle(title: l.t('totals')),
                  const SizedBox(height: 6),
                  Text(
                    l.t('totals_in_local_currency'),
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$chargesCount ${l.t('charges')} ${l.t('in_preposition')} $currenciesCount ${l.t('currencies')}',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: 10),
                  Column(
                    children: grouped.entries.map((e) {
                      final code = e.key;
                      final data = e.value;
                      final left =
                          '${data.sum.toStringAsFixed(2)} $code${data.emoji != null ? ' ${data.emoji!}' : ''}';
                      final ok = _hasOkRatio(code);
                      final converted = _convertToLocal(code, data.sum);
                      final right = (_currencyCode != null)
                          ? '${converted.toStringAsFixed(2)} $localCode${localEmoji != null ? ' $localEmoji' : ''}'
                          : '--';
                      final tappable =
                          _currencyCode != null && code != _currencyCode;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5.0),
                        child: _totalRow(
                          code: code,
                          leftText: left,
                          okRatio: ok,
                          rightText: right,
                          onTap: tappable ? () => _openFxPopup(code) : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 1,
                    color: Theme.of(context).dividerColor.withOpacity(0.6),
                  ),
                  const SizedBox(height: 8),
                  if (!hasBudget) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.t('total_in_local_currency'),
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          _currencyCode == null
                              ? '--'
                              : '${expensesLocal.toStringAsFixed(2)} $localCode${localEmoji != null ? ' $localEmoji' : ''}',
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 1,
                      color: Theme.of(context).dividerColor.withOpacity(0.6),
                    ),
                  ],
                  if (hasBudget) ...[
                    const SizedBox(height: 10),
                    if (maxLocal > 0) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.t('maximum_authorized_local'),
                              style: AppTextStyles.body,
                            ),
                          ),
                          Text(
                            _currencyCode == null
                                ? '--'
                                : _fmtAmountCodeEmoji(
                                    maxLocal, localCode, localEmoji),
                            style: AppTextStyles.body,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (extraLocal > 0) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.t('extra_authorized_local'),
                              style: AppTextStyles.body,
                            ),
                          ),
                          Text(
                            _currencyCode == null
                                ? '--'
                                : _fmtAmountCodeEmoji(
                                    extraLocal, localCode, localEmoji),
                            style: AppTextStyles.body,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    Container(
                      height: 1,
                      color: Theme.of(context).dividerColor.withOpacity(0.6),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.t('total_in_local_currency'),
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          _currencyCode == null
                              ? '--'
                              : '${expensesLocal.toStringAsFixed(2)} $localCode${localEmoji != null ? ' $localEmoji' : ''}',
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 1,
                      color: Theme.of(context).dividerColor.withOpacity(0.6),
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (_) {
                        final availAbs = available.abs();
                        final availStr = _currencyCode == null
                            ? '--'
                            : _fmtAmountCodeEmoji(
                                availAbs, localCode, localEmoji);
                        final isPositive = available >= 0;
                        final color = isPositive ? Colors.green : Colors.red;
                        return Row(
                          children: [
                            Expanded(
                              child: Text(
                                l.t('available'),
                                textAlign: TextAlign.left,
                              ),
                            ),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Theme.of(context).dividerColor,
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                alignment: Alignment.centerRight,
                                child: Text(
                                  availStr,
                                  textAlign: TextAlign.right,
                                  style: AppTextStyles.body.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              ButtonStyles.pillCancelSave(
                onCancel: _close,
                onSave: _saveAndClose,
                cancelLabel: l.t('cancel'),
                saveLabel: l.t('save'),
              ),
              const SizedBox(height: 8),
              Center(
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.print, size: 18),
                  label: Text(l.t('print')),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
