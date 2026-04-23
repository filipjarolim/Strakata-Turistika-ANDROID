import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../config/app_colors.dart';
import '../../../models/forms/form_config.dart';
import '../../../models/forms/form_context.dart';
import '../form_design.dart';

String storageKeyForField(FormFieldWidget field) =>
    field.metadata['name']?.toString().trim().isNotEmpty == true
        ? field.metadata['name']!.toString().trim()
        : field.id;

String? _placeholder(FormFieldWidget field) =>
    field.metadata['placeholder']?.toString();

/// Jednořádkové textové pole ukládané do [FormContext.extraData] podle `name` z DB.
class ExtraDataTextFieldWidget extends StatefulWidget {
  final FormFieldWidget field;
  final TextInputType keyboardType;

  const ExtraDataTextFieldWidget({
    super.key,
    required this.field,
    this.keyboardType = TextInputType.text,
  });

  @override
  State<ExtraDataTextFieldWidget> createState() => _ExtraDataTextFieldWidgetState();
}

class _ExtraDataTextFieldWidgetState extends State<ExtraDataTextFieldWidget> {
  late TextEditingController _controller;
  late String _key;

  @override
  void initState() {
    super.initState();
    _key = storageKeyForField(widget.field);
    final initial =
        context.read<FormContext>().extraData[_key]?.toString() ?? '';
    _controller = TextEditingController(text: initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FormContext>(
      builder: (context, ctx, _) {
        return FormSectionCard(
          title: widget.field.label,
          subtitle: _placeholder(widget.field),
          icon: Icons.edit_outlined,
          child: TextFormField(
            controller: _controller,
            keyboardType: widget.keyboardType,
            decoration: FormDesign.inputDecoration(
              label: widget.field.label,
              hint: _placeholder(widget.field) ?? '',
            ),
            onChanged: (v) => ctx.updateField(_key, v),
          ),
        );
      },
    );
  }
}

class ExtraDataTextAreaWidget extends StatefulWidget {
  final FormFieldWidget field;

  const ExtraDataTextAreaWidget({super.key, required this.field});

  @override
  State<ExtraDataTextAreaWidget> createState() => _ExtraDataTextAreaWidgetState();
}

class _ExtraDataTextAreaWidgetState extends State<ExtraDataTextAreaWidget> {
  late TextEditingController _controller;
  late String _key;

  @override
  void initState() {
    super.initState();
    _key = storageKeyForField(widget.field);
    final initial =
        context.read<FormContext>().extraData[_key]?.toString() ?? '';
    _controller = TextEditingController(text: initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FormContext>(
      builder: (context, ctx, _) {
        return FormSectionCard(
          title: widget.field.label,
          subtitle: _placeholder(widget.field),
          icon: Icons.notes_rounded,
          child: TextFormField(
            controller: _controller,
            minLines: 3,
            maxLines: 8,
            decoration: FormDesign.inputDecoration(
              label: widget.field.label,
              hint: _placeholder(widget.field) ?? '',
            ),
            onChanged: (v) => ctx.updateField(_key, v),
          ),
        );
      },
    );
  }
}

class ExtraDataNumberFieldWidget extends StatefulWidget {
  final FormFieldWidget field;

  const ExtraDataNumberFieldWidget({super.key, required this.field});

  @override
  State<ExtraDataNumberFieldWidget> createState() => _ExtraDataNumberFieldWidgetState();
}

class _ExtraDataNumberFieldWidgetState extends State<ExtraDataNumberFieldWidget> {
  late TextEditingController _controller;
  late String _key;

  @override
  void initState() {
    super.initState();
    _key = storageKeyForField(widget.field);
    final initial =
        context.read<FormContext>().extraData[_key]?.toString() ?? '';
    _controller = TextEditingController(text: initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDuration = _key == 'duration' ||
        widget.field.label.toLowerCase().contains('čas') ||
        widget.field.label.toLowerCase().contains('cas');

    return Consumer<FormContext>(
      builder: (context, ctx, _) {
        return FormSectionCard(
          title: widget.field.label,
          subtitle: _placeholder(widget.field),
          icon: Icons.numbers_rounded,
          child: TextFormField(
            controller: _controller,
            keyboardType: isDuration
                ? TextInputType.text
                : const TextInputType.numberWithOptions(decimal: true, signed: false),
            decoration: FormDesign.inputDecoration(
              label: widget.field.label,
              hint: _placeholder(widget.field) ??
                  (isDuration ? 'Např. 90 nebo 1:30' : ''),
            ),
            onChanged: (v) => ctx.updateField(_key, v),
          ),
        );
      },
    );
  }
}

class ExtraDataDateFieldWidget extends StatefulWidget {
  final FormFieldWidget field;

  const ExtraDataDateFieldWidget({super.key, required this.field});

  @override
  State<ExtraDataDateFieldWidget> createState() => _ExtraDataDateFieldWidgetState();
}

class _ExtraDataDateFieldWidgetState extends State<ExtraDataDateFieldWidget> {
  late String _key;

  @override
  void initState() {
    super.initState();
    _key = storageKeyForField(widget.field);
  }

  String _formatYmd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime? _parseStored(FormContext ctx) {
    final raw = ctx.extraData[_key]?.toString();
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FormContext>(
      builder: (context, ctx, _) {
        final parsed = _parseStored(ctx);
        final display = parsed != null ? _formatYmd(parsed) : '';

        return FormSectionCard(
          title: widget.field.label,
          subtitle: _placeholder(widget.field),
          icon: Icons.calendar_month_outlined,
          child: InkWell(
            onTap: () async {
              final now = DateTime.now();
              final initial = parsed ?? now;
              final picked = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(2000),
                lastDate: now.add(const Duration(days: 365)),
              );
              if (picked != null && context.mounted) {
                ctx.updateField(_key, _formatYmd(picked));
              }
            },
            borderRadius: BorderRadius.circular(14),
            child: InputDecorator(
              decoration: FormDesign.inputDecoration(
                label: widget.field.label,
                hint: 'Vyberte datum',
              ).copyWith(
                suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
              ),
              child: Text(
                display.isEmpty ? 'Vyberte…' : display,
                style: GoogleFonts.libreFranklin(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: display.isEmpty
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ExtraDataSelectWidget extends StatelessWidget {
  final FormFieldWidget field;

  const ExtraDataSelectWidget({super.key, required this.field});

  List<Map<String, String>> _options() {
    final raw = field.metadata['options'];
    if (raw is! List) return [];
    final out = <Map<String, String>>[];
    for (final e in raw) {
      if (e is Map) {
        final m = Map<String, dynamic>.from(e);
        out.add({
          'label': m['label']?.toString() ?? '',
          'value': m['value']?.toString() ?? '',
        });
      }
    }
    return out.where((o) => o['value']!.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final key = storageKeyForField(field);
    final opts = _options();

    return Consumer<FormContext>(
      builder: (context, ctx, _) {
        final current = ctx.extraData[key]?.toString() ?? '';

        if (opts.isEmpty) {
          return FormSectionCard(
            title: field.label,
            subtitle: 'V definici formuláře chybí možnosti výběru.',
            icon: Icons.warning_amber_rounded,
            child: Text(
              'Pole typu „select“ nemá v databázi vyplněné `options`.',
              style: GoogleFonts.libreFranklin(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        return FormSectionCard(
          title: field.label,
          subtitle: _placeholder(field),
          icon: Icons.list_alt_rounded,
          child: DropdownButtonFormField<String>(
            value: current.isEmpty || !opts.any((o) => o['value'] == current)
                ? null
                : current,
            decoration: FormDesign.inputDecoration(
              label: field.label,
              hint: 'Vyberte…',
            ),
            items: opts
                .map(
                  (o) => DropdownMenuItem<String>(
                    value: o['value'],
                    child: Text(o['label'] ?? o['value'] ?? ''),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) ctx.updateField(key, v);
            },
          ),
        );
      },
    );
  }
}

class ExtraDataCheckboxWidget extends StatelessWidget {
  final FormFieldWidget field;

  const ExtraDataCheckboxWidget({super.key, required this.field});

  @override
  Widget build(BuildContext context) {
    final key = storageKeyForField(field);

    return Consumer<FormContext>(
      builder: (context, ctx, _) {
        final v = ctx.extraData[key] == true;

        return FormSectionCard(
          title: field.label,
          subtitle: _placeholder(field),
          icon: Icons.check_box_outlined,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              field.label,
              style: GoogleFonts.libreFranklin(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            value: v,
            onChanged: (checked) => ctx.updateField(key, checked == true),
          ),
        );
      },
    );
  }
}
