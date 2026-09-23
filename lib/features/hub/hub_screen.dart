import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/repo_link_model.dart';
import '../../data/models/user_model.dart';
import '../../data/services/api_service.dart';
import 'add_link_dialog.dart';
import 'user_profile_dialog.dart';

class HubScreen extends StatefulWidget {
  final ApiService apiService;
  final UserModel currentUser;
  final VoidCallback onOpenCvBuilder;
  final VoidCallback? onOpenPdfSigner;
  final VoidCallback onLogout;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleCosmic;
  final bool isDark;
  final bool isCosmicActive;

  const HubScreen({
    super.key,
    required this.apiService,
    required this.currentUser,
    required this.onOpenCvBuilder,
    this.onOpenPdfSigner,
    required this.onLogout,
    required this.onToggleTheme,
    required this.onToggleCosmic,
    required this.isDark,
    required this.isCosmicActive,
  });

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  late UserModel _currentUser;
  List<RepoLinkModel> _links = [];
  bool _isLoading = true;
  String _selectedCategory = 'Todos';
  String _searchQuery = '';
  bool _dbHealthy = false;

  // GitHub Widget state
  late String _githubUsername;
  List<Map<String, dynamic>> _githubRepos = [];
  bool _isLoadingGitHub = false;

  final List<String> _categories = ['Todos', 'Repositorios', 'Web Apps', 'Educación', 'Docs'];

  @override
  void initState() {
    super.initState();
    _currentUser = widget.currentUser;
    _githubUsername = widget.apiService.storage.getGitHubUsername();
    _loadData();
    _loadGitHubRepos();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final links = await widget.apiService.getLinks();
    final health = await widget.apiService.checkHealth();
    if (mounted) {
      setState(() {
        _links = links;
        _dbHealthy = health;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadGitHubRepos() async {
    setState(() => _isLoadingGitHub = true);
    final repos = await widget.apiService.fetchGitHubRepos(_githubUsername);
    if (mounted) {
      setState(() {
        _githubRepos = repos;
        _isLoadingGitHub = false;
      });
    }
  }

  Future<void> _showConnectGitHubDialog() async {
    final controller = TextEditingController(text: _githubUsername);
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.hub_outlined, color: AppTheme.emerald),
              SizedBox(width: 10),
              Text('Conectar con GitHub', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Introduce el usuario u organización de GitHub para explorar sus repositorios en tiempo real dentro del Widget de Sanctuary:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.person, size: 18),
                  hintText: 'carlosss91',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                foregroundColor: Colors.white,
              ),
              child: const Text('Conectar y Sincronizar'),
            ),
          ],
        );
      },
    );

    if (res != null && res.isNotEmpty) {
      await widget.apiService.storage.setGitHubUsername(res);
      setState(() => _githubUsername = res);
      await _loadGitHubRepos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sincronizado con cuenta de GitHub: @$res'),
            backgroundColor: AppTheme.emerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Color _getLanguageColor(String lang) {
    switch (lang.toLowerCase()) {
      case 'dart':
        return const Color(0xFF00B4AB);
      case 'javascript':
        return const Color(0xFFF7DF1E);
      case 'typescript':
        return const Color(0xFF3178C6);
      case 'python':
        return const Color(0xFF3776AB);
      case 'html':
        return const Color(0xFFE34F26);
      case 'css':
        return const Color(0xFF1572B6);
      case 'java':
        return const Color(0xFFB07219);
      case 'shell':
      case 'bash':
        return const Color(0xFF89E051);
      default:
        return AppTheme.emerald;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    final filteredLinks = _links.where((l) {
      final matchesCategory = _selectedCategory == 'Todos' || l.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          l.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          l.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.emerald.withOpacity(0.4)),
              ),
              child: const Icon(Icons.hub_outlined, color: AppTheme.emerald, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'SANCTUARY',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5),
                ),
                Text(
                  'Portal de Web Apps & Repositorios',
                  style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // DB Health status indicator
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _dbHealthy ? AppTheme.emerald.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _dbHealthy ? AppTheme.emerald.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _dbHealthy ? AppTheme.emerald : Colors.orange,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _dbHealthy ? 'Postgres 5438' : 'Modo Offline',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _dbHealthy ? AppTheme.emerald : Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Cosmic Animation Toggle
          IconButton(
            tooltip: widget.isCosmicActive ? 'Pausar animación espacial' : 'Activar animación espacial',
            icon: Icon(
              widget.isCosmicActive ? Icons.auto_awesome : Icons.auto_awesome_outlined,
              color: widget.isCosmicActive ? AppTheme.emerald : Colors.grey,
              size: 20,
            ),
            onPressed: widget.onToggleCosmic,
          ),

          // Light / Dark Theme Toggle
          IconButton(
            tooltip: isDark ? 'Cambiar a Tema Claro' : 'Cambiar a Tema Oscuro',
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 20),
            onPressed: widget.onToggleTheme,
          ),

          const SizedBox(width: 6),

          // ====================================================================
          // USER PROFILE DROPDOWN (Session Logout consolidated strictly inside)
          // ====================================================================
          PopupMenuButton<String>(
            tooltip: 'Menú de usuario',
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1.2),
            ),
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            onSelected: (val) {
              if (val == 'edit_profile') {
                UserProfileDialog.show(
                  context,
                  user: _currentUser,
                  apiService: widget.apiService,
                  onUserUpdated: (updated) {
                    setState(() => _currentUser = updated);
                  },
                );
              } else if (val == 'toggle_theme') {
                widget.onToggleTheme();
              } else if (val == 'toggle_cosmic') {
                widget.onToggleCosmic();
              } else if (val == 'logout') {
                widget.onLogout();
              }
            },
            itemBuilder: (ctx) => [
              // Header item: user card summary
              PopupMenuItem<String>(
                enabled: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.emerald,
                        backgroundImage: _currentUser.avatarUrl != null && _currentUser.avatarUrl!.isNotEmpty
                            ? NetworkImage(_currentUser.avatarUrl!)
                            : null,
                        child: (_currentUser.avatarUrl == null || _currentUser.avatarUrl!.isEmpty)
                            ? Text(
                                _currentUser.username.isNotEmpty ? _currentUser.username[0].toUpperCase() : 'U',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentUser.fullName ?? _currentUser.username,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '@${_currentUser.username} · ${_currentUser.role}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const PopupMenuDivider(),
              // Option: Editar Perfil
              const PopupMenuItem<String>(
                value: 'edit_profile',
                child: Row(
                  children: [
                    Icon(Icons.manage_accounts_outlined, size: 18, color: AppTheme.emerald),
                    SizedBox(width: 12),
                    Text('Editar Perfil y Foto', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              // Option: Tema
              PopupMenuItem<String>(
                value: 'toggle_theme',
                child: Row(
                  children: [
                    Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 18),
                    const SizedBox(width: 12),
                    Text(isDark ? 'Tema Claro' : 'Tema Oscuro', style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              // Option: Animación Cósmica
              PopupMenuItem<String>(
                value: 'toggle_cosmic',
                child: Row(
                  children: [
                    Icon(widget.isCosmicActive ? Icons.pause_circle_outline : Icons.play_circle_outline, size: 18),
                    const SizedBox(width: 12),
                    Text(widget.isCosmicActive ? 'Pausar Cosmos' : 'Activar Cosmos', style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              // Option: Cerrar Sesión (Strictly inside dropdown)
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: Colors.redAccent),
                    SizedBox(width: 12),
                    Text(
                      'Cerrar Sesión',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.emerald.withOpacity(0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: AppTheme.emerald,
                    backgroundImage: _currentUser.avatarUrl != null && _currentUser.avatarUrl!.isNotEmpty
                        ? NetworkImage(_currentUser.avatarUrl!)
                        : null,
                    child: (_currentUser.avatarUrl == null || _currentUser.avatarUrl!.isEmpty)
                        ? Text(
                            _currentUser.username.isNotEmpty ? _currentUser.username[0].toUpperCase() : 'U',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _currentUser.username,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.emerald))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- HERO SECTION ---
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0C1322).withOpacity(0.85) : Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.emerald.withOpacity(0.08),
                              blurRadius: 28,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.emerald.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'SANCTUARY PLATFORM · DIGITAL SUITE',
                                      style: TextStyle(
                                        color: AppTheme.emerald,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Bienvenido, ${_currentUser.fullName ?? _currentUser.username}',
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 24,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Tu centro unificado con herramientas y repositorio interactivo estilo iOS.',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ================================================================
                      // 1. IPHONE STYLE APPS & TOOLS GRID (iOS SQUIRCLES)
                      // ================================================================
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppTheme.emerald,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'HERRAMIENTAS & APLICACIONES',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // iOS App Icons Grid
                      Wrap(
                        spacing: 24,
                        runSpacing: 20,
                        alignment: WrapAlignment.start,
                        children: [
                          _buildIPhoneAppIcon(
                            title: 'Creador de CV',
                            subtitle: 'Taller FC0003',
                            icon: Icons.badge_rounded,
                            gradient: const [Color(0xFF10B981), Color(0xFF047857)],
                            badge: 'A4 Live',
                            onTap: widget.onOpenCvBuilder,
                          ),
                          _buildIPhoneAppIcon(
                            title: 'Firmador PDF',
                            subtitle: 'Firma en Vivo',
                            icon: Icons.draw_rounded,
                            gradient: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                            badge: 'Nuevo',
                            onTap: () {
                              if (widget.onOpenPdfSigner != null) {
                                widget.onOpenPdfSigner!();
                              }
                            },
                          ),
                          _buildIPhoneAppIcon(
                            title: 'Alumnos',
                            subtitle: 'Gestor Docente',
                            icon: Icons.school_rounded,
                            gradient: const [Color(0xFF8B5CF6), Color(0xFF4F46E5)],
                            badge: 'Activo',
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Gestor de alumnos activo en el creador de CV')),
                              );
                            },
                          ),
                          _buildIPhoneAppIcon(
                            title: 'Apps Web',
                            subtitle: 'Microservicios',
                            icon: Icons.grid_view_rounded,
                            gradient: const [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                            badge: 'Pronto',
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Próximamente nuevas Web Apps en Sanctuary')),
                              );
                            },
                          ),
                          _buildIPhoneAppIcon(
                            title: 'Documentación',
                            subtitle: 'Guías y Manuales',
                            icon: Icons.menu_book_rounded,
                            gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                            badge: 'Docs',
                            onTap: () => _openUrl('https://github.com/$_githubUsername/Sanctuary'),
                          ),
                          _buildIPhoneAppIcon(
                            title: 'Mi Perfil',
                            subtitle: 'Ajustes de cuenta',
                            icon: Icons.manage_accounts_rounded,
                            gradient: const [Color(0xFF64748B), Color(0xFF334155)],
                            badge: 'User',
                            onTap: () {
                              UserProfileDialog.show(
                                context,
                                user: _currentUser,
                                apiService: widget.apiService,
                                onUserUpdated: (updated) {
                                  setState(() => _currentUser = updated);
                                },
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 34),

                      // ================================================================
                      // 2. GITHUB REPOSITORIES iOS-STYLE WIDGET
                      // ================================================================
                      _buildGitHubIOSWidget(isDark),

                      const SizedBox(height: 34),

                      // ================================================================
                      // 3. REPOSITORIOS & ENLACES GUARDADOS DIRECTORY
                      // ================================================================
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppTheme.emerald,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'ENLACES DIRECTOS GUARDADOS',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              AddLinkDialog.show(context, widget.apiService, _loadData);
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Añadir Enlace'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Category Pills & Search Field
                      Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _categories.map((cat) {
                                  final isSelected = _selectedCategory == cat;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(cat),
                                      selected: isSelected,
                                      selectedColor: AppTheme.emerald.withOpacity(0.2),
                                      side: BorderSide(
                                        color: isSelected ? AppTheme.emerald : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                                      ),
                                      onSelected: (val) {
                                        if (val) setState(() => _selectedCategory = cat);
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          SizedBox(
                            width: 220,
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: 'Buscar enlaces...',
                                prefixIcon: Icon(Icons.search, size: 18),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onChanged: (val) => setState(() => _searchQuery = val),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Grid of Saved Links
                      if (filteredLinks.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          alignment: Alignment.center,
                          child: const Text('No se encontraron enlaces en esta categoría.', style: TextStyle(color: Colors.grey)),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 360,
                            mainAxisExtent: 130,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: filteredLinks.length,
                          itemBuilder: (context, idx) {
                            final link = filteredLinks[idx];
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(7),
                                          decoration: BoxDecoration(
                                            color: AppTheme.emerald.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            link.category == 'Repositorios' ? Icons.code : Icons.open_in_new,
                                            size: 16,
                                            color: AppTheme.emerald,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            link.title,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.launch, size: 16, color: AppTheme.emerald),
                                          onPressed: () => _openUrl(link.url),
                                          tooltip: 'Abrir enlace',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Expanded(
                                      child: Text(
                                        link.description.isNotEmpty ? link.description : link.url,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // ==============================================================================
  // WIDGET BUILDER: IPHONE / iOS APP ICON (SQUIRCLE)
  // ==============================================================================
  Widget _buildIPhoneAppIcon({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required String badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // iOS Squircle Container
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: gradient.first.withOpacity(0.38),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Glass gloss reflection on top half
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 38,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0.24),
                            Colors.white.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // App Icon
                  Icon(icon, color: Colors.white, size: 36),
                  // Little pill badge at top right
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Title Label under icon
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================================================
  // WIDGET BUILDER: iOS-STYLE GITHUB REPOSITORIES WIDGET
  // ==============================================================================
  Widget _buildGitHubIOSWidget(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C1322).withOpacity(0.9) : Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Widget Header: GitHub branding & connection status
          Row(
            children: [
              // GitHub Logo Box
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.emerald.withOpacity(0.3)),
                ),
                child: const Icon(Icons.code_rounded, color: AppTheme.emerald, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'GitHub Repositories',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.emerald.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'iOS Smart Widget',
                            style: TextStyle(color: AppTheme.emerald, fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Explora y accede en directo a los repositorios de @$_githubUsername',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              // Connect / Change Account Button
              OutlinedButton.icon(
                onPressed: _showConnectGitHubDialog,
                icon: const Icon(Icons.link, size: 15),
                label: Text('@$_githubUsername', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.emerald,
                  side: const BorderSide(color: AppTheme.emerald, width: 1.2),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 8),

              // Refresh Button
              IconButton(
                tooltip: 'Actualizar repositorios de GitHub',
                icon: _isLoadingGitHub
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppTheme.emerald, strokeWidth: 2))
                    : const Icon(Icons.refresh, size: 20),
                onPressed: _isLoadingGitHub ? null : _loadGitHubRepos,
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Widget Repositories List
          if (_isLoadingGitHub)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(color: AppTheme.emerald)),
            )
          else if (_githubRepos.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              alignment: Alignment.center,
              child: const Text('No se pudieron obtener repositorios públicos para este usuario.', style: TextStyle(color: Colors.grey)),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 380,
                    mainAxisExtent: 135,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: _githubRepos.length,
                  itemBuilder: (ctx, idx) {
                    final repo = _githubRepos[idx];
                    final name = repo['name'] as String? ?? '';
                    final desc = repo['description'] as String? ?? 'Sin descripción';
                    final url = repo['html_url'] as String? ?? '';
                    final lang = repo['language'] as String? ?? 'Code';
                    final stars = repo['stars'] as int? ?? 0;
                    final forks = repo['forks'] as int? ?? 0;
                    final langColor = _getLanguageColor(lang);

                    return InkWell(
                      onTap: () => _openUrl(url),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF131C2E) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.bookmark_border, size: 16, color: AppTheme.emerald),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.arrow_outward, size: 14, color: Colors.grey),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: Text(
                                desc,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: langColor),
                                ),
                                const SizedBox(width: 5),
                                Text(lang, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
                                const Spacer(),
                                if (stars > 0) ...[
                                  const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                                  const SizedBox(width: 3),
                                  Text('$stars', style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                                  const SizedBox(width: 10),
                                ],
                                if (forks > 0) ...[
                                  const Icon(Icons.fork_right, size: 14, color: Colors.grey),
                                  const SizedBox(width: 3),
                                  Text('$forks', style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}
