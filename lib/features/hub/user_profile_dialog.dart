import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_model.dart';
import '../../data/services/api_service.dart';

class UserProfileDialog extends StatefulWidget {
  final UserModel user;
  final ApiService apiService;
  final ValueChanged<UserModel> onUserUpdated;

  const UserProfileDialog({
    super.key,
    required this.user,
    required this.apiService,
    required this.onUserUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required UserModel user,
    required ApiService apiService,
    required ValueChanged<UserModel> onUserUpdated,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => UserProfileDialog(
        user: user,
        apiService: apiService,
        onUserUpdated: onUserUpdated,
      ),
    );
  }

  @override
  State<UserProfileDialog> createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends State<UserProfileDialog> {
  late TextEditingController _fullNameController;
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _roleController;
  late TextEditingController _bioController;
  late TextEditingController _passwordController;

  String? _avatarUrl;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  String? _statusMessage;
  bool _isSuccess = false;

  final List<String> _sampleAvatars = [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=400&auto=format&fit=crop&q=80',
  ];

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.user.fullName ?? widget.user.username);
    _usernameController = TextEditingController(text: widget.user.username);
    _emailController = TextEditingController(text: widget.user.email ?? '');
    _roleController = TextEditingController(text: widget.user.role);
    _bioController = TextEditingController(text: widget.user.bio ?? '');
    _passwordController = TextEditingController();
    _avatarUrl = widget.user.avatarUrl;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _roleController.dispose();
    _bioController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotoFromPC() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );

      if (files.isNotEmpty) {
        final picked = files.first;
        final bytes = await picked.readAsBytes();
        if (bytes.isEmpty) return;

        setState(() => _isUploadingPhoto = true);
        final url = await widget.apiService.uploadImage(bytes, picked.name);
        if (mounted) {
          setState(() {
            _avatarUrl = url ?? 'data:image/png;base64,${base64Encode(bytes)}';
            _isUploadingPhoto = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });

    final updated = widget.user.copyWith(
      fullName: _fullNameController.text.trim(),
      username: _usernameController.text.trim().isEmpty ? widget.user.username : _usernameController.text.trim(),
      email: _emailController.text.trim(),
      role: _roleController.text.trim().isEmpty ? 'admin' : _roleController.text.trim(),
      bio: _bioController.text.trim(),
      avatarUrl: _avatarUrl,
    );

    final res = await widget.apiService.updateUserProfile(
      updated,
      newPassword: _passwordController.text.trim().isNotEmpty ? _passwordController.text.trim() : null,
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
        _isSuccess = res['success'] == true;
        _statusMessage = res['message'] ?? (_isSuccess ? 'Perfil guardado con éxito' : 'Error al guardar');
      });

      if (_isSuccess) {
        final finalUser = res['user'] is UserModel ? res['user'] as UserModel : updated;
        widget.onUserUpdated(finalUser);
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted && Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
        });
      }
    }
  }

  Widget _buildAvatarPreview() {
    Widget imageWidget;
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      if (_avatarUrl!.startsWith('data:image')) {
        try {
          final comma = _avatarUrl!.indexOf(',');
          final bytes = base64Decode(_avatarUrl!.substring(comma + 1));
          imageWidget = Image.memory(bytes, fit: BoxFit.cover);
        } catch (_) {
          imageWidget = const Icon(Icons.person, size: 42, color: Colors.white);
        }
      } else {
        imageWidget = Image.network(
          _avatarUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 42, color: Colors.white),
        );
      }
    } else {
      final initial = widget.user.username.isNotEmpty ? widget.user.username[0].toUpperCase() : 'U';
      imageWidget = Center(
        child: Text(
          initial,
          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Stack(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.emerald.withOpacity(0.2),
            border: Border.all(color: AppTheme.emerald, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppTheme.emerald.withOpacity(0.25),
                blurRadius: 18,
                offset: const Offset(0, 4),
              )
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: _isUploadingPhoto
              ? const Center(child: CircularProgressIndicator(color: AppTheme.emerald, strokeWidth: 2))
              : imageWidget,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: InkWell(
            onTap: _pickPhotoFromPC,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppTheme.emerald,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dialog Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.emerald.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.manage_accounts_outlined, color: AppTheme.emerald, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Editar Perfil de Usuario',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Personaliza tu foto, credenciales y datos en Sanctuary',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const Divider(height: 24),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Photo Section
                      Center(
                        child: Column(
                          children: [
                            _buildAvatarPreview(),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _pickPhotoFromPC,
                                  icon: const Icon(Icons.upload_file, size: 16),
                                  label: const Text('Subir foto desde PC', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                                if (_avatarUrl != null) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: 'Quitar foto',
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                    onPressed: () => setState(() => _avatarUrl = null),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Quick Avatar Presets
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: _sampleAvatars.map((url) {
                                  final isSelected = _avatarUrl == url;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: InkWell(
                                      onTap: () => setState(() => _avatarUrl = url),
                                      borderRadius: BorderRadius.circular(18),
                                      child: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected ? AppTheme.emerald : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: Image.network(url, fit: BoxFit.cover),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Full Name
                      const Text('Nombre Completo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _fullNameController,
                        decoration: InputDecoration(
                          hintText: 'Ej: Carlos Docente',
                          prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Username & Role Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Nombre de Usuario', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _usernameController,
                                  decoration: InputDecoration(
                                    hintText: 'admin',
                                    prefixIcon: const Icon(Icons.person_outline, size: 18),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Rol / Función', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _roleController,
                                  decoration: InputDecoration(
                                    hintText: 'admin / docente / alumno',
                                    prefixIcon: const Icon(Icons.shield_outlined, size: 18),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Email
                      const Text('Correo Electrónico', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          hintText: 'ejemplo@sanctuary.local',
                          prefixIcon: const Icon(Icons.email_outlined, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Bio
                      const Text('Biografía / Descripción', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _bioController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Administrador de la plataforma Sanctuary y tutor técnico...',
                          prefixIcon: const Icon(Icons.notes_outlined, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // New Password (Optional)
                      const Text('Nueva Contraseña (dejar en blanco para no cambiar)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_reset, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),

                      if (_statusMessage != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _isSuccess ? AppTheme.emerald.withOpacity(0.12) : Colors.red.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isSuccess ? AppTheme.emerald.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _statusMessage!,
                            style: TextStyle(
                              color: _isSuccess ? AppTheme.emerald : Colors.redAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveProfile,
                    icon: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check, size: 18),
                    label: Text(_isSaving ? 'Guardando...' : 'Guardar Cambios'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emerald,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
