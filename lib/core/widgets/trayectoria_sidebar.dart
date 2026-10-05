import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import 'sanctuary_planet_logo.dart';

class GitHubRepo {
  final String name;
  final String desc;
  final String url;
  final String stars;

  const GitHubRepo({
    required this.name,
    required this.desc,
    required this.url,
    this.stars = '★',
  });
}

class TrayectoriaSidebar extends StatefulWidget {
  final String activeItem;
  final ValueChanged<String> onSelect;
  final bool isDark;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;
  final String? githubUsername;
  final String? userDisplayName;

  const TrayectoriaSidebar({
    super.key,
    this.activeItem = 'Orientación',
    required this.onSelect,
    required this.isDark,
    this.isCollapsed = false,
    this.onToggleCollapse,
    this.githubUsername,
    this.userDisplayName,
  });

  @override
  State<TrayectoriaSidebar> createState() => _TrayectoriaSidebarState();
}

class _TrayectoriaSidebarState extends State<TrayectoriaSidebar> {
  String _effectiveUsername = '';
  String _effectiveDisplayName = '';
  List<GitHubRepo> _gitHubRepos = [];
  bool _isLoadingRepos = false;

  @override
  void initState() {
    super.initState();
    _resolveUserAndFetchRepos();
  }

  @override
  void didUpdateWidget(covariant TrayectoriaSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.githubUsername != widget.githubUsername ||
        oldWidget.userDisplayName != widget.userDisplayName) {
      _resolveUserAndFetchRepos();
    }
  }

  Future<void> _resolveUserAndFetchRepos() async {
    String resolvedUser = (widget.githubUsername ?? '').trim();
    String resolvedName = (widget.userDisplayName ?? '').trim();

    try {
      final prefs = await SharedPreferences.getInstance();
      if (resolvedUser.isEmpty) {
        final userJson = prefs.getString('current_user');
        String? currentUsername;
        if (userJson != null) {
          try {
            final map = jsonDecode(userJson);
            currentUsername = map['username']?.toString();
            if (resolvedName.isEmpty) {
              resolvedName = map['full_name']?.toString() ?? currentUsername ?? '';
            }
          } catch (_) {}
        }
        if (currentUsername != null && currentUsername.isNotEmpty) {
          resolvedUser = prefs.getString('sanctuary_github_${currentUsername.toLowerCase()}') ?? '';
        }
        if (resolvedUser.isEmpty) {
          resolvedUser = prefs.getString('sanctuary_github_username') ?? '';
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _effectiveUsername = resolvedUser;
        _effectiveDisplayName = resolvedName;
      });
      if (resolvedUser.isNotEmpty) {
        _fetchRepos(resolvedUser);
      } else {
        setState(() {
          _gitHubRepos = [];
          _isLoadingRepos = false;
        });
      }
    }
  }

  Future<void> _fetchRepos(String username) async {
    if (username.trim().isEmpty) {
      if (mounted) setState(() => _gitHubRepos = []);
      return;
    }

    setState(() => _isLoadingRepos = true);

    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/users/${username.trim()}/repos?sort=updated&per_page=6'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        final repos = list.map((item) {
          final desc = item['description']?.toString() ?? 'Repositorio público en GitHub';
          return GitHubRepo(
            name: item['name']?.toString() ?? '',
            desc: desc,
            url: item['html_url']?.toString() ?? 'https://github.com/${username.trim()}',
            stars: (item['stargazers_count'] != null) ? '${item['stargazers_count']} ★' : '★',
          );
        }).toList();

        if (mounted) {
          setState(() {
            _gitHubRepos = repos;
            _isLoadingRepos = false;
          });
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isLoadingRepos = false;
      });
    }
  }

  Future<void> _openExternal(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final isCollapsed = widget.isCollapsed;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: isCollapsed ? 64 : 250,
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0A0F1D).withOpacity(0.52) : Colors.white.withOpacity(0.65),
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(28)),
              border: Border(
                right: BorderSide(
                  color: isDark ? Colors.white.withOpacity(0.14) : Colors.white.withOpacity(0.75),
                  width: 1.2,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          // 1. Header: Fixed Hamburger Button on the Left, Logo & Title to the Right
          if (!isCollapsed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.menu_open_rounded,
                      size: 24,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    tooltip: 'Plegar barra lateral',
                    onPressed: () {
                      if (widget.onToggleCollapse != null) {
                        widget.onToggleCollapse!();
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  ),
                  const SizedBox(width: 6),
                  const SanctuaryPlanetLogo(size: 28, showGlow: true),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'SANCTUARY',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.8,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Portal & Repositorios',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.menu_rounded,
                      size: 24,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    tooltip: 'Desplegar barra lateral',
                    onPressed: widget.onToggleCollapse,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  ),
                  const SizedBox(height: 8),
                  const SanctuaryPlanetLogo(size: 28, showGlow: true),
                ],
              ),
            ),

          Divider(height: 1, color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),

          // 2. Navigation Items & Repos
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 6 : 10, vertical: 12),
              children: [
                // SECTION: NAVEGACIÓN PRINCIPAL
                _buildSectionHeader('PLATAFORMA', isDark),
                const SizedBox(height: 4),

                _buildNavItem(
                  icon: Icons.hub_outlined,
                  title: 'Inicio / Santuario (Hub)',
                  itemKey: 'Inicio',
                  isDark: isDark,
                  isActive: widget.activeItem == 'Inicio',
                ),
                const SizedBox(height: 4),

                _buildNavItem(
                  icon: Icons.badge_outlined,
                  title: 'CV Maker',
                  itemKey: 'Orientación',
                  isDark: isDark,
                  isActive: widget.activeItem == 'Orientación',
                ),
                const SizedBox(height: 4),

                _buildNavItem(
                  icon: Icons.draw_outlined,
                  title: 'PDF Signer',
                  itemKey: 'PdfSigner',
                  isDark: isDark,
                  isActive: widget.activeItem == 'PdfSigner',
                  badge: 'PDF',
                ),
                const SizedBox(height: 4),

                _buildNavItem(
                  icon: Icons.present_to_all_outlined,
                  title: 'Slide Downloader',
                  itemKey: 'Prezi2Pdf',
                  isDark: isDark,
                  isActive: widget.activeItem == 'Prezi2Pdf',
                  badge: 'Multi',
                ),
                const SizedBox(height: 4),

                _buildNavItem(
                  icon: Icons.school_outlined,
                  title: 'Gestión de Alumnos',
                  itemKey: 'Alumnos',
                  isDark: isDark,
                  isActive: widget.activeItem == 'Alumnos',
                ),
                const SizedBox(height: 4),

                _buildNavItem(
                  icon: Icons.web_outlined,
                  title: 'Aplicaciones Web',
                  itemKey: 'WebApps',
                  isDark: isDark,
                  isActive: false,
                  badge: 'Pronto',
                ),
                const SizedBox(height: 4),

                _buildNavItem(
                  icon: Icons.menu_book_outlined,
                  title: 'Documentación & Guías',
                  itemKey: 'Docs',
                  isDark: isDark,
                  isActive: false,
                  badge: 'Pronto',
                ),
                const SizedBox(height: 4),

                _buildNavItem(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Panel de Control',
                  itemKey: 'AdminPanel',
                  isDark: isDark,
                  isActive: widget.activeItem == 'AdminPanel' || widget.activeItem == 'Ajustes',
                  badge: 'Admin',
                ),

                const SizedBox(height: 18),
                Divider(height: 1, color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
                const SizedBox(height: 14),

                // SECTION: REPOSITORIOS GITHUB
                if (!isCollapsed)
                  Row(
                    children: [
                      const Icon(Icons.code, size: 14, color: AppTheme.emerald),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildSectionHeader(
                          _effectiveUsername.isNotEmpty
                              ? 'REPOSITORIOS GITHUB (@$_effectiveUsername)'
                              : 'REPOSITORIOS GITHUB',
                          isDark,
                        ),
                      ),
                    ],
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Center(child: Icon(Icons.code, size: 14, color: AppTheme.emerald)),
                  ),
                const SizedBox(height: 8),

                if (_isLoadingRepos)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.emerald),
                      ),
                    ),
                  )
                else if (_effectiveUsername.isEmpty)
                  if (!isCollapsed)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.65),
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.account_circle_outlined, size: 14, color: AppTheme.emerald),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Sin usuario vinculado',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Configura tu perfil de GitHub en el widget de la pantalla de inicio para sincronizar tus repositorios.',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => widget.onSelect('Inicio'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.emerald.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.emerald.withOpacity(0.35)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.link, size: 12, color: AppTheme.emerald),
                                  SizedBox(width: 4),
                                  Text(
                                    'Configurar perfil',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.emerald,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Tooltip(
                        message: 'Configurar usuario de GitHub en Inicio',
                        preferBelow: false,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => widget.onSelect('Inicio'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.65),
                                width: 1.0,
                              ),
                            ),
                            child: const Icon(Icons.link_outlined, size: 16, color: AppTheme.emerald),
                          ),
                        ),
                      ),
                    )
                else if (_gitHubRepos.isEmpty)
                  if (!isCollapsed)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.65),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        'No se encontraron repositorios públicos para @$_effectiveUsername.',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink()
                else
                  ..._gitHubRepos.map((repo) => _buildRepoCard(repo, isDark)),
              ],
            ),
          ),

          // 3. Bottom Footer
          Container(
            padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 8 : 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                  width: 1,
                ),
              ),
            ),
            child: isCollapsed
                ? Tooltip(
                    message: _effectiveUsername.isNotEmpty
                        ? 'Usuario GitHub: @$_effectiveUsername'
                        : 'Sanctuary Platform',
                    preferBelow: false,
                    child: InkWell(
                      onTap: () {
                        if (_effectiveUsername.isNotEmpty) {
                          _openExternal('https://github.com/$_effectiveUsername');
                        } else {
                          widget.onSelect('Inicio');
                        }
                      },
                      child: const Center(
                        child: Icon(Icons.code_rounded, size: 16, color: AppTheme.emerald),
                      ),
                    ),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _effectiveDisplayName.isNotEmpty
                              ? _effectiveDisplayName
                              : 'Sanctuary Platform',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        InkWell(
                          onTap: () {
                            if (_effectiveUsername.isNotEmpty) {
                              _openExternal('https://github.com/$_effectiveUsername');
                            } else {
                              widget.onSelect('Inicio');
                            }
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.code_rounded, size: 12, color: AppTheme.emerald),
                              const SizedBox(width: 4),
                              Text(
                                _effectiveUsername.isNotEmpty
                                    ? 'GitHub: @$_effectiveUsername'
                                    : 'Conectar GitHub',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.emerald,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    ),
  ),
),
);
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    if (widget.isCollapsed) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String title,
    required String itemKey,
    required bool isDark,
    required bool isActive,
    String? badge,
  }) {
    if (widget.isCollapsed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Tooltip(
          message: title,
          preferBelow: false,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => widget.onSelect(itemKey),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive
                    ? (isDark ? AppTheme.emerald.withOpacity(0.22) : AppTheme.emerald.withOpacity(0.16))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: isActive
                    ? Border.all(
                        color: isDark ? AppTheme.emerald.withOpacity(0.65) : AppTheme.emerald.withOpacity(0.55),
                        width: 1.0,
                      )
                    : Border.all(color: Colors.transparent, width: 1.0),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppTheme.emerald.withOpacity(isDark ? 0.25 : 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                size: 19,
                color: isActive ? AppTheme.emerald : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => widget.onSelect(itemKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? AppTheme.emerald.withOpacity(0.22) : AppTheme.emerald.withOpacity(0.16))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isActive
              ? Border.all(
                  color: isDark ? AppTheme.emerald.withOpacity(0.65) : AppTheme.emerald.withOpacity(0.55),
                  width: 1.0,
                )
              : Border.all(color: Colors.transparent, width: 1.0),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppTheme.emerald.withOpacity(isDark ? 0.25 : 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 17,
              color: isActive ? AppTheme.emerald : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? AppTheme.emerald : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(fontSize: 8.5, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepoCard(GitHubRepo repo, bool isDark) {
    if (widget.isCollapsed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Tooltip(
          message: '${repo.name}: ${repo.desc}',
          preferBelow: false,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openExternal(repo.url),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.45),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.65),
                  width: 1.0,
                ),
              ),
              child: const Icon(Icons.folder_open_outlined, size: 16, color: AppTheme.emerald),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openExternal(repo.url),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.45),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.65),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.folder_open_outlined, size: 14, color: AppTheme.emerald),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      repo.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      repo.desc,
                      style: TextStyle(
                        fontSize: 9,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new, size: 12, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
