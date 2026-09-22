import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/repo_link_model.dart';
import '../../data/services/api_service.dart';

class AddLinkDialog extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onLinkAdded;

  const AddLinkDialog({
    super.key,
    required this.apiService,
    required this.onLinkAdded,
  });

  static Future<void> show(BuildContext context, ApiService api, VoidCallback onAdded) {
    return showDialog(
      context: context,
      builder: (_) => AddLinkDialog(apiService: api, onLinkAdded: onAdded),
    );
  }

  @override
  State<AddLinkDialog> createState() => _AddLinkDialogState();
}

class _AddLinkDialogState extends State<AddLinkDialog> {
  final _titleController = TextEditingController();
  final _urlController = TextEditingController(text: 'https://github.com/');
  final _descController = TextEditingController();
  String _category = 'Repositorios';
  bool _isLoading = false;

  final List<String> _categories = ['Repositorios', 'Web Apps', 'Educación', 'Docs', 'General'];

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final url = _urlController.text.trim();

    if (title.isEmpty || url.isEmpty) return;

    setState(() => _isLoading = true);

    final link = RepoLinkModel(
      title: title,
      url: url,
      description: _descController.text.trim(),
      category: _category,
      iconName: _category == 'Repositorios' ? 'folder_git' : 'apps',
    );

    await widget.apiService.addLink(link);
    widget.onLinkAdded();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppTheme.darkCard : AppTheme.lightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_link, color: AppTheme.emerald, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Añadir Enlace a Repositorio o Web App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 18),
              const Text('Título del proyecto o enlace', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(hintText: 'Ej. Mi Proyecto en GitHub'),
              ),
              const SizedBox(height: 12),
              const Text('URL o hipervínculo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(hintText: 'https://github.com/usuario/repo'),
              ),
              const SizedBox(height: 12),
              const Text('Categoría', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _category = val);
                },
              ),
              const SizedBox(height: 12),
              const Text('Descripción corta (opcional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _descController,
                maxLines: 2,
                decoration: const InputDecoration(hintText: 'Breve explicación de la app o repositorio'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Guardar Enlace'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
