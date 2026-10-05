import 'dart:ui';
import 'package:flutter/material.dart';
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
}class TrayectoriaSidebar extends StatefulWidget {
  final String activeItem;
  final ValueChanged<String> onSelect;
  final bool isDark;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;

  const TrayectoriaSidebar({
    super.key,
    this.activeItem = 'Orientación',
    required this.onSelect,
    required this.isDark,
    this.isCollapsed = false,
    this.onToggleCollapse,
  });

  @override
  State<TrayectoriaSidebar> createState() => _TrayectoriaSidebarState();
}

class _TrayectoriaSidebarState extends State<TrayectoriaSidebar> {
  final List<GitHubRepo> _gitHubRepos = const [
    GitHubRepo(
      name: 'Sanctuary',
      desc: 'Portal Web Docker & CV Builder',
      url: 'https://github.com/carlosss91/Sanctuary',
    ),
    GitHubRepo(
      name: 'portaldocente20',
      desc: 'Gestión docente y módulos FP',
      url: 'https://github.com/carlosss91/portaldocente20',
    ),
    GitHubRepo(
      name: 'odysseus',
      desc: 'Sistema de automatización',
      url: 'https://github.com/carlosss91/odysseus',
    ),
    GitHubRepo(
      name: 'cv-builder-flutter',
      desc: 'Herramienta interactiva A4',
      url: 'https://github.com/carlosss91',
    ),
  ];

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
                      Expanded(child: _buildSectionHeader('REPOSITORIOS GITHUB', isDark)),
                    ],
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Center(child: Icon(Icons.code, size: 14, color: AppTheme.emerald)),
                  ),
                const SizedBox(height: 8),

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
                    message: 'Property of Carlos Santana Sánchez · GitHub: carlosss91',
                    preferBelow: false,
                    child: InkWell(
                      onTap: () => _openExternal('https://github.com/carlosss91'),
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
                          'Property of Carlos Santana Sánchez',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        InkWell(
                          onTap: () => _openExternal('https://github.com/carlosss91'),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.code_rounded, size: 12, color: AppTheme.emerald),
                              SizedBox(width: 4),
                              Text(
                                'GitHub: carlosss91',
                                style: TextStyle(
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
