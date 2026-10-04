import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SanctuaryBottomDock extends StatelessWidget {
  final String currentRoute;
  final ValueChanged<String> onNavigate;
  final bool isDark;
  final String? userRole;

  const SanctuaryBottomDock({
    super.key,
    required this.currentRoute,
    required this.onNavigate,
    required this.isDark,
    this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = userRole?.toLowerCase() == 'admin';
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 500;

    final items = [
      _DockItem(
        route: 'hub',
        label: 'Inicio',
        tooltip: 'Santuario (Hub Principal)',
        icon: Icons.hub_rounded,
        accentColor: AppTheme.emerald,
      ),
      _DockItem(
        route: 'cv_builder',
        label: 'CV Builder',
        tooltip: 'Orientación Laboral · Taller de CV',
        icon: Icons.badge_outlined,
        accentColor: const Color(0xFF10B981),
      ),
      _DockItem(
        route: 'prezi2pdf',
        label: 'Slides',
        tooltip: 'Slide Downloader (Prezi / Slides a PDF)',
        icon: Icons.present_to_all_rounded,
        accentColor: const Color(0xFFA855F7),
      ),
      _DockItem(
        route: 'pdf_signer',
        label: 'Firmar',
        tooltip: 'Firmador Electrónico de PDF',
        icon: Icons.draw_rounded,
        accentColor: const Color(0xFF3B82F6),
      ),
      if (isAdmin)
        _DockItem(
          route: 'admin_panel',
          label: 'Admin',
          tooltip: 'Panel de Administración',
          icon: Icons.admin_panel_settings_rounded,
          accentColor: const Color(0xFF06B6D4),
        ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0B132B).withOpacity(0.88)
                : Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF334155).withOpacity(0.7)
                  : const Color(0xFFCBD5E1),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.45 : 0.12),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: items.map((it) {
              final isSelected = currentRoute == it.route;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Tooltip(
                  message: it.tooltip,
                  waitDuration: const Duration(milliseconds: 400),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onNavigate(it.route),
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.symmetric(
                          horizontal: isSelected
                              ? (isCompact ? 10 : 14)
                              : (isCompact ? 8 : 10),
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? it.accentColor.withOpacity(isDark ? 0.22 : 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: isSelected
                              ? Border.all(
                                  color: it.accentColor.withOpacity(0.6),
                                  width: 1.2,
                                )
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              it.icon,
                              size: 19,
                              color: isSelected
                                  ? (isDark ? Colors.white : it.accentColor)
                                  : (isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B)),
                            ),
                            if (isSelected && !isCompact) ...[
                              const SizedBox(width: 6),
                              Text(
                                it.label,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : it.accentColor,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _DockItem {
  final String route;
  final String label;
  final String tooltip;
  final IconData icon;
  final Color accentColor;

  const _DockItem({
    required this.route,
    required this.label,
    required this.tooltip,
    required this.icon,
    required this.accentColor,
  });
}
