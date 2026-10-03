import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_model.dart';
import '../../data/services/api_service.dart';
import '../hub/user_profile_dialog.dart';

class AdminPanelScreen extends StatefulWidget {
  final ApiService apiService;
  final UserModel currentUser;
  final VoidCallback onBackToHub;
  final VoidCallback onLogout;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleCosmic;
  final bool isDark;
  final bool isCosmicActive;

  const AdminPanelScreen({
    super.key,
    required this.apiService,
    required this.currentUser,
    required this.onBackToHub,
    required this.onLogout,
    required this.onToggleTheme,
    required this.onToggleCosmic,
    required this.isDark,
    required this.isCosmicActive,
  });

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<UserModel> _users = [];
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _chatMessages = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _roleFilter = 'todos'; // todos, admin, docente, usuario, baneados

  // Email test state
  final TextEditingController _testEmailCtrl = TextEditingController();
  bool _isTestingEmail = false;
  String? _emailTestResult;

  // Active module flags
  final Map<String, bool> _activeModules = {
    'cv_builder': true,
    'slide_downloader': true,
    'pdf_signer': true,
    'chat_ephemeral': true,
    'github_explorer': true,
    'email_activation': true,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllAdminData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _testEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllAdminData() async {
    setState(() => _isLoading = true);
    final users = await widget.apiService.getAdminUsers();
    final stats = await widget.apiService.getAdminStats();
    final chat = await widget.apiService.getChatMessages();
    if (mounted) {
      setState(() {
        _users = users;
        _stats = stats;
        _chatMessages = chat;
        _isLoading = false;
      });
    }
  }

  // --- CRUD: CREATE USER DIALOG ---
  Future<void> _showCreateUserDialog() async {
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final fullNameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String selectedRole = 'usuario';
    String? dialogError;
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.emerald, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Crear Nuevo Usuario', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (dialogError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(dialogError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Text('Nombre de Usuario *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: usernameCtrl,
                        decoration: InputDecoration(
                          hintText: 'ej. maria.gonzalez',
                          prefixIcon: const Icon(Icons.alternate_email, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Contraseña *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: passwordCtrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Mínimo 4 caracteres',
                          prefixIcon: const Icon(Icons.lock_outline, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Rol asignado *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'usuario', child: Text('Usuario Estándar')),
                          DropdownMenuItem(value: 'docente', child: Text('Docente / Tutor FP')),
                          DropdownMenuItem(value: 'admin', child: Text('Administrador (Acceso Total)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedRole = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text('Nombre Completo (Opcional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: fullNameCtrl,
                        decoration: InputDecoration(
                          hintText: 'ej. María González Ramos',
                          prefixIcon: const Icon(Icons.badge, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Correo Electrónico (Opcional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'ej. maria@correo.es',
                          prefixIcon: const Icon(Icons.mail_outline, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final u = usernameCtrl.text.trim();
                          final p = passwordCtrl.text.trim();
                          if (u.isEmpty || p.isEmpty) {
                            setDialogState(() => dialogError = 'Usuario y contraseña requeridos');
                            return;
                          }
                          setDialogState(() {
                            isSaving = true;
                            dialogError = null;
                          });

                          final res = await widget.apiService.createAdminUser(
                            username: u,
                            password: p,
                            role: selectedRole,
                            fullName: fullNameCtrl.text.trim().isNotEmpty ? fullNameCtrl.text.trim() : null,
                            email: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                          );

                          if (res['success'] == true) {
                            if (mounted) {
                              Navigator.pop(dialogCtx);
                              _loadAllAdminData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✔ Usuario "$u" creado con rol "$selectedRole"'),
                                  backgroundColor: AppTheme.emerald,
                                ),
                              );
                            }
                          } else {
                            setDialogState(() {
                              dialogError = res['message'] ?? 'Error al crear usuario';
                              isSaving = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emerald,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: isSaving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check, size: 18),
                  label: const Text('Crear Usuario'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- CRUD: EDIT USER DIALOG ---
  Future<void> _showEditUserDialog(UserModel user) async {
    final fullNameCtrl = TextEditingController(text: user.fullName ?? '');
    final emailCtrl = TextEditingController(text: user.email ?? '');
    final passwordCtrl = TextEditingController();
    String selectedRole = user.role.toLowerCase();
    if (!['admin', 'docente', 'usuario'].contains(selectedRole)) {
      selectedRole = 'usuario';
    }
    bool isBanned = user.isBanned;
    String? dialogError;
    bool isSaving = false;
    final isRootAdmin = user.username.toLowerCase() == 'admin';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_note_rounded, color: Colors.blueAccent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Editar @${user.username}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        Text('ID: ${user.id ?? "N/A"}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (dialogError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(dialogError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Rol selection
                      const Text('Rol del Sistema', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'usuario', child: Text('Usuario Estándar')),
                          DropdownMenuItem(value: 'docente', child: Text('Docente / Tutor FP')),
                          DropdownMenuItem(value: 'admin', child: Text('Administrador (Acceso Total)')),
                        ],
                        onChanged: isRootAdmin
                            ? null
                            : (val) {
                                if (val != null) setDialogState(() => selectedRole = val);
                              },
                      ),
                      if (isRootAdmin)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text('El administrador principal siempre mantiene el rol admin.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ),

                      const SizedBox(height: 12),
                      const Text('Nombre Completo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: fullNameCtrl,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person_outline, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),

                      const SizedBox(height: 12),
                      const Text('Correo Electrónico', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.mail_outline, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),

                      const SizedBox(height: 12),
                      const Text('Restablecer Contraseña (Dejar en blanco para conservar)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: passwordCtrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Nueva contraseña opcional',
                          prefixIcon: const Icon(Icons.lock_reset, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),

                      const SizedBox(height: 14),
                      // Estado de baneo / suspensión
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Cuenta suspendida / baneada', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          isBanned ? 'El usuario NO podrá iniciar sesión' : 'El usuario tiene acceso normal al sistema',
                          style: TextStyle(fontSize: 11, color: isBanned ? Colors.redAccent : Colors.grey),
                        ),
                        value: isBanned,
                        activeColor: Colors.redAccent,
                        onChanged: isRootAdmin
                            ? null
                            : (val) {
                                setDialogState(() => isBanned = val);
                              },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() {
                            isSaving = true;
                            dialogError = null;
                          });

                          final res = await widget.apiService.updateAdminUser(
                            id: user.id ?? user.username,
                            username: user.username,
                            role: selectedRole,
                            fullName: fullNameCtrl.text.trim(),
                            email: emailCtrl.text.trim(),
                            isBanned: isBanned,
                            password: passwordCtrl.text.trim().isNotEmpty ? passwordCtrl.text.trim() : null,
                          );

                          if (res['success'] == true) {
                            if (mounted) {
                              Navigator.pop(dialogCtx);
                              _loadAllAdminData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✔ Usuario @${user.username} actualizado correctamente'),
                                  backgroundColor: AppTheme.emerald,
                                ),
                              );
                            }
                          } else {
                            setDialogState(() {
                              dialogError = res['message'] ?? 'Error al actualizar usuario';
                              isSaving = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: isSaving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Guardar Cambios'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- CRUD: TOGGLE BAN QUICK ACTION ---
  Future<void> _toggleBanUser(UserModel user) async {
    if (user.username.toLowerCase() == 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se puede banear al administrador principal'), backgroundColor: Colors.orange),
      );
      return;
    }

    final newBanState = !user.isBanned;
    final actionName = newBanState ? 'suspender / banear' : 'reactivar';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('¿Deseas $actionName a @${user.username}?'),
        content: Text(
          newBanState
              ? 'El usuario quedará inhabilitado para iniciar sesión en la plataforma de inmediato.'
              : 'El usuario recuperará el acceso regular a la plataforma con sus credenciales actuales.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newBanState ? Colors.redAccent : AppTheme.emerald,
              foregroundColor: Colors.white,
            ),
            child: Text(newBanState ? 'Banear Usuario' : 'Reactivar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await widget.apiService.updateAdminUser(
        id: user.id ?? user.username,
        username: user.username,
        isBanned: newBanState,
      );
      if (res['success'] == true) {
        _loadAllAdminData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(newBanState ? 'Usuario @${user.username} suspendido' : 'Usuario @${user.username} reactivado'),
              backgroundColor: newBanState ? Colors.redAccent : AppTheme.emerald,
            ),
          );
        }
      }
    }
  }

  // --- CRUD: DELETE USER ---
  Future<void> _deleteUser(UserModel user) async {
    if (user.username.toLowerCase() == 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se puede eliminar la cuenta principal de administrador'), backgroundColor: Colors.orange),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text('Eliminar @${user.username}'),
          ],
        ),
        content: Text('¿Estás seguro de que deseas eliminar permanentemente al usuario "${user.username}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Eliminar Definitivamente'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await widget.apiService.deleteAdminUser(user.id ?? user.username, username: user.username);
      if (res['success'] == true) {
        _loadAllAdminData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Usuario @${user.username} eliminado'), backgroundColor: AppTheme.emerald),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Error al eliminar usuario'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  List<UserModel> get _filteredUsers {
    return _users.where((u) {
      // Role filter
      if (_roleFilter == 'admin' && u.role.toLowerCase() != 'admin') return false;
      if (_roleFilter == 'docente' && u.role.toLowerCase() != 'docente') return false;
      if (_roleFilter == 'usuario' && u.role.toLowerCase() != 'usuario') return false;
      if (_roleFilter == 'baneados' && !u.isBanned) return false;

      // Query filter
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final uName = u.username.toLowerCase();
      final fName = (u.fullName ?? '').toLowerCase();
      final email = (u.email ?? '').toLowerCase();
      return uName.contains(q) || fName.contains(q) || email.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        titleSpacing: 10,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver al Inicio (Hub)',
          onPressed: widget.onBackToHub,
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.4)),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF06B6D4), size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Text('PANEL DE CONTROL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2)),
                    SizedBox(width: 8),
                    Badge(
                      label: Text('SUPER ADMIN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                      backgroundColor: Color(0xFF06B6D4),
                    ),
                  ],
                ),
                Text(
                  'Gestión integral de usuarios, chat, módulos y estado del sistema',
                  style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Recargar datos',
            onPressed: _loadAllAdminData,
          ),
          // Cosmic Animation Toggle
          IconButton(
            tooltip: widget.isCosmicActive ? 'Pausar cosmos' : 'Activar cosmos',
            icon: Icon(
              widget.isCosmicActive ? Icons.auto_awesome : Icons.auto_awesome_outlined,
              color: widget.isCosmicActive ? const Color(0xFF06B6D4) : Colors.grey,
              size: 20,
            ),
            onPressed: widget.onToggleCosmic,
          ),
          // Light / Dark Theme Toggle
          IconButton(
            tooltip: isDark ? 'Tema Claro' : 'Tema Oscuro',
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 20),
            onPressed: widget.onToggleTheme,
          ),
          const SizedBox(width: 6),
          // User Profile Dropdown Menu (Standardized right side)
          _buildProfileDropdown(isDark),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: const Color(0xFF06B6D4),
          labelColor: const Color(0xFF06B6D4),
          unselectedLabelColor: isDark ? Colors.grey : Colors.blueGrey,
          tabs: [
            const Tab(icon: Icon(Icons.manage_accounts_rounded, size: 18), text: 'Usuarios y Roles'),
            Tab(
              icon: const Icon(Icons.forum_rounded, size: 18),
              text: 'Chat y Moderación (${_chatMessages.length})',
            ),
            const Tab(icon: Icon(Icons.dashboard_customize_rounded, size: 18), text: 'Módulos y Web Apps'),
            const Tab(icon: Icon(Icons.dns_rounded, size: 18), text: 'Servidor y Base de Datos'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF06B6D4)),
                  SizedBox(height: 16),
                  Text('Cargando datos administrativos...', style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUsersTab(isDark),
                _buildChatModerationTab(isDark),
                _buildModulesTab(isDark),
                _buildSystemStatusTab(isDark),
              ],
            ),
    );
  }

  // ===========================================================================
  // TAB 1: GESTIÓN DE USUARIOS Y ROLES (CRUD)
  // ===========================================================================
  Widget _buildUsersTab(bool isDark) {
    final filtered = _filteredUsers;
    final totalUsers = _users.length;
    final totalBanned = _users.where((u) => u.isBanned).length;
    final totalAdmins = _users.where((u) => u.role.toLowerCase() == 'admin').length;
    final totalDocentes = _users.where((u) => u.role.toLowerCase() == 'docente').length;
    final totalRegular = _users.where((u) => u.role.toLowerCase() == 'usuario').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary Stat Cards
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildStatCard(
                    title: 'Total Usuarios',
                    value: '$totalUsers',
                    subtitle: '$totalRegular estándar',
                    icon: Icons.group_rounded,
                    color: AppTheme.emerald,
                    isDark: isDark,
                  ),
                  _buildStatCard(
                    title: 'Administradores',
                    value: '$totalAdmins',
                    subtitle: 'Control total',
                    icon: Icons.shield_rounded,
                    color: const Color(0xFF06B6D4),
                    isDark: isDark,
                  ),
                  _buildStatCard(
                    title: 'Docentes / Tutores',
                    value: '$totalDocentes',
                    subtitle: 'Gestión formativa',
                    icon: Icons.school_rounded,
                    color: Colors.cyanAccent,
                    isDark: isDark,
                  ),
                  _buildStatCard(
                    title: 'Cuentas Suspendidas',
                    value: '$totalBanned',
                    subtitle: totalBanned == 0 ? 'Sin suspensiones' : 'Acceso bloqueado',
                    icon: Icons.block_rounded,
                    color: totalBanned > 0 ? Colors.redAccent : Colors.grey,
                    isDark: isDark,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Filter & Search & Create Action Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A).withOpacity(0.8) : Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155).withOpacity(0.6) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Search box
                        Expanded(
                          child: TextField(
                            onChanged: (val) => setState(() => _searchQuery = val),
                            decoration: InputDecoration(
                              hintText: 'Buscar por usuario, nombre o email...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _searchQuery = ''))
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Add user button
                        ElevatedButton.icon(
                          onPressed: _showCreateUserDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.emerald,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text('Nuevo Usuario', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('Todos ($totalUsers)', 'todos', isDark),
                          const SizedBox(width: 8),
                          _buildFilterChip('Admins ($totalAdmins)', 'admin', isDark),
                          const SizedBox(width: 8),
                          _buildFilterChip('Docentes ($totalDocentes)', 'docente', isDark),
                          const SizedBox(width: 8),
                          _buildFilterChip('Usuarios ($totalRegular)', 'usuario', isDark),
                          const SizedBox(width: 8),
                          _buildFilterChip('Suspendidos ($totalBanned)', 'baneados', isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Users List / Cards
              if (filtered.isEmpty)
                Container(
                  padding: const EdgeInsets.all(40),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A).withOpacity(0.5) : Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.person_search_rounded, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('No se encontraron usuarios coincidentes con el filtro.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final u = filtered[i];
                    return _buildUserCard(u, isDark);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String key, bool isDark) {
    final isSelected = _roleFilter == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (_) => setState(() => _roleFilter = key),
      selectedColor: const Color(0xFF06B6D4).withOpacity(0.2),
      side: BorderSide(color: isSelected ? const Color(0xFF06B6D4) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      labelStyle: TextStyle(color: isSelected ? const Color(0xFF06B6D4) : (isDark ? Colors.white70 : Colors.black87)),
    );
  }

  Widget _buildUserCard(UserModel user, bool isDark) {
    final isRootAdmin = user.username.toLowerCase() == 'admin';
    final role = user.role.toLowerCase();

    Color roleColor = AppTheme.emerald;
    String roleLabel = 'Usuario';
    if (role == 'admin') {
      roleColor = const Color(0xFF06B6D4);
      roleLabel = 'Administrador';
    } else if (role == 'docente') {
      roleColor = Colors.cyanAccent;
      roleLabel = 'Docente';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withOpacity(0.85) : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: user.isBanned
              ? Colors.redAccent.withOpacity(0.5)
              : (isDark ? const Color(0xFF334155).withOpacity(0.6) : const Color(0xFFE2E8F0)),
          width: user.isBanned ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Stack(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: roleColor.withOpacity(0.2),
                backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty ? NetworkImage(user.avatarUrl!) : null,
                child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                    ? Text(
                        user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
                        style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 16),
                      )
                    : null,
              ),
              if (user.isBanned)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 10, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // User details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user.fullName ?? user.username,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        decoration: user.isBanned ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('@${user.username}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    if (isRootAdmin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.4)),
                        ),
                        child: const Text('ROOT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4))),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (user.email != null && user.email!.isNotEmpty) ...[
                      const Icon(Icons.mail_outline, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(user.email!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(width: 12),
                    ],
                    // Role badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: roleColor.withOpacity(0.4)),
                      ),
                      child: Text(roleLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: roleColor)),
                    ),
                    const SizedBox(width: 8),
                    // Ban / Active status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (user.isBanned ? Colors.redAccent : AppTheme.emerald).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        user.isBanned ? 'Suspendido' : 'Activo',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: user.isBanned ? Colors.redAccent : AppTheme.emerald,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Actions Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Edit button
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueAccent),
                tooltip: 'Editar usuario y rol',
                onPressed: () => _showEditUserDialog(user),
              ),
              // Ban / Unban button
              IconButton(
                icon: Icon(
                  user.isBanned ? Icons.lock_open_rounded : Icons.block_rounded,
                  size: 18,
                  color: user.isBanned ? AppTheme.emerald : Colors.orange,
                ),
                tooltip: isRootAdmin ? 'Cuenta principal protegida' : (user.isBanned ? 'Reactivar usuario' : 'Suspender/Banear'),
                onPressed: isRootAdmin ? null : () => _toggleBanUser(user),
              ),
              // Delete button
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, size: 18, color: isRootAdmin ? Colors.grey : Colors.redAccent),
                tooltip: isRootAdmin ? 'No se puede eliminar al admin principal' : 'Eliminar usuario',
                onPressed: isRootAdmin ? null : () => _deleteUser(user),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withOpacity(0.85) : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155).withOpacity(0.6) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 11, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: ESTADO DEL SERVIDOR Y BASE DE DATOS
  // ===========================================================================
  Widget _buildSystemStatusTab(bool isDark) {
    final dbName = _stats['database'] ?? 'Comprobando...';
    final isPostgres = dbName.toString().toLowerCase().contains('postgres');
    final totalCvs = _stats['total_cvs'] ?? 0;
    final uptimeSeconds = _stats['uptime_seconds'] ?? 0;
    final uptimeHours = (uptimeSeconds / 3600).toStringAsFixed(1);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // DB Info card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A).withOpacity(0.85) : Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isPostgres ? AppTheme.emerald.withOpacity(0.4) : Colors.orange.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isPostgres ? Icons.check_circle_rounded : Icons.info_outline,
                          color: isPostgres ? AppTheme.emerald : Colors.orange,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Base de Datos: $dbName',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                isPostgres
                                    ? 'Conexión activa con PostgreSQL (Cloud Render / Docker local)'
                                    : 'Operando en modo de respaldo local offline (Local JSON Storage)',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 28),
                    _buildInfoRow('Endpoint API Base', widget.apiService.baseUrl, isDark),
                    _buildInfoRow('Perfiles de CV en Memoria / DB', '$totalCvs perfiles', isDark),
                    _buildInfoRow('Tiempo activo del servidor Node.js', '$uptimeHours horas ($uptimeSeconds seg)', isDark),
                    _buildInfoRow('Versión de Plataforma', 'Sanctuary Suite v2.4 (Enterprise Edition)', isDark),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Actions card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A).withOpacity(0.85) : Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? const Color(0xFF334155).withOpacity(0.6) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Acciones Rápidas del Administrador', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final healthy = await widget.apiService.checkHealth();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(healthy ? '✔ Conexión con el servidor y DB saludable' : '⚠ El servidor no responde'),
                                  backgroundColor: healthy ? AppTheme.emerald : Colors.orange,
                                ),
                              );
                              _loadAllAdminData();
                            }
                          },
                          icon: const Icon(Icons.network_check_rounded, size: 18),
                          label: const Text('Comprobar Latencia'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            foregroundColor: isDark ? Colors.white : Colors.black87,
                            elevation: 0,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _showCreateUserDialog,
                          icon: const Icon(Icons.person_add_rounded, size: 18),
                          label: const Text('Dar de Alta Usuario'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF06B6D4),
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // SMTP Email Diagnostics Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A).withOpacity(0.85) : Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF06B6D4).withOpacity(0.3),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.mail_lock_rounded, color: Color(0xFF06B6D4), size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Diagnóstico de Servicio de Correo Electrónico (SMTP)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Prueba el envío de correos reales para activación de cuentas y restablecimiento de contraseña.',
                      style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _testEmailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: 'Introduce un correo de destino (ej. tu@correo.com)',
                              prefixIcon: const Icon(Icons.send_rounded, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _isTestingEmail
                              ? null
                              : () async {
                                  final dest = _testEmailCtrl.text.trim();
                                  if (dest.isEmpty || !dest.contains('@')) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Escribe un correo válido para la prueba'), backgroundColor: Colors.orange),
                                    );
                                    return;
                                  }
                                  setState(() {
                                    _isTestingEmail = true;
                                    _emailTestResult = null;
                                  });
                                  final res = await widget.apiService.testSmtp(dest);
                                  if (mounted) {
                                    setState(() {
                                      _isTestingEmail = false;
                                      _emailTestResult = res['message'] ?? (res['success'] == true ? '✔ Correo enviado con éxito' : 'Error en envío');
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF06B6D4),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: _isTestingEmail
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.mark_email_read_outlined, size: 18),
                          label: const Text('Enviar Prueba'),
                        ),
                      ],
                    ),
                    if (_emailTestResult != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
                        ),
                        child: Text(
                          _emailTestResult!,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF06B6D4)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 2: CHAT EFÍMERO Y MODERACIÓN
  // ===========================================================================
  Widget _buildChatModerationTab(bool isDark) {
    final totalMessages = _chatMessages.length;
    final activeUsers = _chatMessages.map((m) => m['username']).toSet().length;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary cards
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildStatCard(
                    title: 'Mensajes de Hoy',
                    value: '$totalMessages',
                    subtitle: 'Historial activo',
                    icon: Icons.forum_rounded,
                    color: const Color(0xFF06B6D4),
                    isDark: isDark,
                  ),
                  _buildStatCard(
                    title: 'Participantes Únicos',
                    value: '$activeUsers',
                    subtitle: 'Usuarios conversando',
                    icon: Icons.people_outline_rounded,
                    color: AppTheme.emerald,
                    isDark: isDark,
                  ),
                  _buildStatCard(
                    title: 'Auto-Purga Diaria',
                    value: '00:00',
                    subtitle: 'Limpieza automática',
                    icon: Icons.auto_delete_rounded,
                    color: Colors.orangeAccent,
                    isDark: isDark,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Chat Action Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A).withOpacity(0.85) : Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: isDark ? const Color(0xFF334155).withOpacity(0.6) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Historial del Chat Diario',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Los mensajes se reinician cada día a las 00:00 de forma automática para mantener el canal ágil y ligero.',
                            style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: totalMessages == 0
                          ? null
                          : () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: const Text('¿Vaciar y Purgar el Chat Ahora?'),
                                  content: const Text('Esta acción eliminará todos los mensajes acumulados el día de hoy inmediatamente.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                                      child: const Text('Purgar Chat'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                final ok = await widget.apiService.clearChatMessages();
                                if (ok && mounted) {
                                  _loadAllAdminData();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('✔ Historial del chat vaciado con éxito'), backgroundColor: Color(0xFF06B6D4)),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                      label: const Text('Vaciar Chat Ahora'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Chat messages list
              if (_chatMessages.isEmpty)
                Container(
                  padding: const EdgeInsets.all(40),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A).withOpacity(0.5) : Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.forum_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('No hay mensajes registrados hoy en el chat.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _chatMessages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final msg = _chatMessages[i];
                    final username = msg['username']?.toString() ?? 'Anónimo';
                    final content = msg['message']?.toString() ?? '';
                    final role = msg['role']?.toString().toLowerCase() ?? 'usuario';
                    final time = msg['created_at']?.toString() ?? '';

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A).withOpacity(0.85) : Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? const Color(0xFF334155).withOpacity(0.6) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: role == 'admin' ? const Color(0xFF06B6D4) : AppTheme.emerald,
                            child: Text(
                              username.isNotEmpty ? username[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('@$username', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (role == 'admin' ? const Color(0xFF06B6D4) : AppTheme.emerald).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        role.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: role == 'admin' ? const Color(0xFF06B6D4) : AppTheme.emerald,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      time.length >= 16 ? time.substring(11, 16) : time,
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(content, style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 3: MÓDULOS Y WEB APPS DISPONIBLES
  // ===========================================================================
  Widget _buildModulesTab(bool isDark) {
    final modules = [
      {
        'id': 'cv_builder',
        'title': 'Taller de Currículum Vitae (A4)',
        'description': 'Maquetador interactivo con autoguardado, vista previa continua, exportación PDF y perfiles docentes.',
        'icon': Icons.description_rounded,
        'color': AppTheme.emerald,
        'category': 'Inserción & Orientación',
      },
      {
        'id': 'slide_downloader',
        'title': 'Slide & Video Downloader Universal',
        'description': 'Descarga presentaciones de Prezi, Google Slides, SlideShare y extrae vídeos MP4 individuales o empaquetados en ZIP.',
        'icon': Icons.present_to_all_rounded,
        'color': const Color(0xFFE11D48),
        'category': 'Docencia & Multimedia',
      },
      {
        'id': 'pdf_signer',
        'title': 'Firma Digital Biométrica eIDAS / PAdES',
        'description': 'Firma electrónica avanzada en documentos PDF con sello temporal, verificación criptográfica SHA-256 y trazabilidad de auditoría.',
        'icon': Icons.draw_rounded,
        'color': const Color(0xFF2563EB),
        'category': 'Gestión & Seguridad Legal',
      },
      {
        'id': 'chat_ephemeral',
        'title': 'Chat Efímero Comunitario en Vivo',
        'description': 'Burbuja flotante de comunicación rápida entre usuarios autenticados con emojis y reinicio programado diario a las 00:00.',
        'icon': Icons.forum_rounded,
        'color': const Color(0xFF06B6D4),
        'category': 'Interacción & Soporte',
      },
      {
        'id': 'github_explorer',
        'title': 'Explorador de Repositorios GitHub',
        'description': 'Widget en tiempo real que consulta la API de GitHub para mostrar proyectos, commits y estadísticas.',
        'icon': Icons.hub_rounded,
        'color': const Color(0xFF8B5CF6),
        'category': 'Desarrollo & Proyectos',
      },
      {
        'id': 'email_activation',
        'title': 'Servicio de Activación por Email & Recuperación',
        'description': 'Sistema de verificación de usuarios nuevos y restablecimiento seguro de credenciales con hashing bcrypt.',
        'icon': Icons.mark_email_read_rounded,
        'color': const Color(0xFF10B981),
        'category': 'Seguridad & Autenticación',
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A).withOpacity(0.85) : Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: isDark ? const Color(0xFF334155).withOpacity(0.6) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.dashboard_customize_rounded, color: Color(0xFF06B6D4), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Control Central de Aplicaciones y Módulos',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'Activa o desactiva las herramientas disponibles en el portal para todos los usuarios de la plataforma.',
                            style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: modules.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final mod = modules[i];
                  final id = mod['id'] as String;
                  final title = mod['title'] as String;
                  final desc = mod['description'] as String;
                  final icon = mod['icon'] as IconData;
                  final color = mod['color'] as Color;
                  final cat = mod['category'] as String;
                  final isEnabled = _activeModules[id] ?? true;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A).withOpacity(0.85) : Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isEnabled
                            ? color.withOpacity(0.4)
                            : (isDark ? const Color(0xFF334155).withOpacity(0.5) : const Color(0xFFE2E8F0)),
                        width: isEnabled ? 1.4 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: color, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(cat, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: color)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(desc, style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Switch(
                          value: isEnabled,
                          activeColor: color,
                          onChanged: (val) {
                            setState(() => _activeModules[id] = val);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${val ? "Activado" : "Desactivado"}: $title'),
                                duration: const Duration(seconds: 2),
                                backgroundColor: val ? color : Colors.grey,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // User Profile Dropdown Menu in the top right
  Widget _buildProfileDropdown(bool isDark) {
    final user = widget.currentUser;

    return PopupMenuButton<String>(
      tooltip: 'Menú de usuario',
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1.2),
      ),
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      onSelected: (val) {
        if (val == 'edit_profile') {
          UserProfileDialog.show(
            context,
            user: user,
            apiService: widget.apiService,
            onUserUpdated: (updated) {
              _loadAllAdminData();
            },
          );
        } else if (val == 'hub') {
          widget.onBackToHub();
        } else if (val == 'toggle_theme') {
          widget.onToggleTheme();
        } else if (val == 'toggle_cosmic') {
          widget.onToggleCosmic();
        } else if (val == 'logout') {
          widget.onLogout();
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF06B6D4),
                  backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                      ? Text(
                          user.username.isNotEmpty ? user.username[0].toUpperCase() : 'A',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(user.fullName ?? user.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const Text('Administrador', style: TextStyle(fontSize: 10.5, color: Color(0xFF06B6D4), fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'edit_profile',
          child: Row(
            children: [
              Icon(Icons.badge_outlined, size: 17, color: Color(0xFF06B6D4)),
              SizedBox(width: 10),
              Text('Editar Perfil', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'hub',
          child: Row(
            children: [
              Icon(Icons.home_outlined, size: 17),
              SizedBox(width: 10),
              Text('Volver al Santuario Hub', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 17, color: Colors.redAccent),
              SizedBox(width: 10),
              Text('Cerrar Sesión', style: TextStyle(fontSize: 13, color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: const Color(0xFF06B6D4),
              child: Text(
                user.username.isNotEmpty ? user.username[0].toUpperCase() : 'A',
                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              user.username,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

