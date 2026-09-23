import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SignerIdentity {
  final String name;
  final String surname;
  final String nationalId;

  const SignerIdentity({
    required this.name,
    required this.surname,
    this.nationalId = '',
  });

  String get fullName => '$name $surname'.trim();
}

class SignerIdentificationDialog extends StatefulWidget {
  final SignerIdentity? initialIdentity;

  const SignerIdentificationDialog({super.key, this.initialIdentity});

  static Future<SignerIdentity?> show(BuildContext context, [SignerIdentity? initial]) {
    return showDialog<SignerIdentity>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SignerIdentificationDialog(initialIdentity: initial),
    );
  }

  @override
  State<SignerIdentificationDialog> createState() => _SignerIdentificationDialogState();
}

class _SignerIdentificationDialogState extends State<SignerIdentificationDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _surnameCtrl;
  late TextEditingController _dniCtrl;
  bool _acceptTerms = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialIdentity?.name ?? '');
    _surnameCtrl = TextEditingController(text: widget.initialIdentity?.surname ?? '');
    _dniCtrl = TextEditingController(text: widget.initialIdentity?.nationalId ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _surnameCtrl.dispose();
    _dniCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes aceptar las condiciones de firma para continuar.')),
      );
      return;
    }

    Navigator.of(context).pop(SignerIdentity(
      name: _nameCtrl.text.trim(),
      surname: _surnameCtrl.text.trim(),
      nationalId: _dniCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.verified_user_outlined, color: AppTheme.emerald, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Identificación del Firmante', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Datos requeridos para la validez de la firma digital', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Por favor, introduce tu Nombre y Apellidos completos antes de proceder a plasmar tu firma en el documento:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nombre *',
                  hintText: 'Ej. Carlos',
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'El nombre es obligatorio';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _surnameCtrl,
                decoration: InputDecoration(
                  labelText: 'Apellidos *',
                  hintText: 'Ej. Sánchez García',
                  prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Los apellidos son obligatorios';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _dniCtrl,
                decoration: InputDecoration(
                  labelText: 'DNI / NIE / Pasaporte (Opcional)',
                  hintText: '12345678Z',
                  prefixIcon: const Icon(Icons.credit_card_outlined, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              CheckboxListTile(
                value: _acceptTerms,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppTheme.emerald,
                title: const Text(
                  'Acepto estampar mi firma de conformidad en este documento digital con plena validez.',
                  style: TextStyle(fontSize: 11.5),
                ),
                onChanged: (val) => setState(() => _acceptTerms = val ?? true),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.arrow_forward, size: 16),
          label: const Text('Aceptar e Iniciar Firma'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.emerald,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}
