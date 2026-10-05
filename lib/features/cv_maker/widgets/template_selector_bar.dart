import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/cv_profile_model.dart';

class TemplateOption {
  final String id;
  final String name;
  final String description;
  final IconData icon;

  const TemplateOption({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });
}

class TemplateSelectorBar extends StatelessWidget {
  final String activeTemplate;
  final ValueChanged<String> onSelectTemplate;
  final List<CvProfileModel> profiles;
  final String activeProfileId;
  final ValueChanged<String> onSelectProfile;
  final VoidCallback onAddProfile;
  final ValueChanged<String>? onDeleteProfile;
  final VoidCallback? onImportCv;

  const TemplateSelectorBar({
    super.key,
    required this.activeTemplate,
    required this.onSelectTemplate,
    required this.profiles,
    required this.activeProfileId,
    required this.onSelectProfile,
    required this.onAddProfile,
    this.onDeleteProfile,
    this.onImportCv,
  });

  static const List<TemplateOption> templates = [
    TemplateOption(
      id: 'sidebar_dark',
      name: 'Columna Lateral',
      description: 'Barra lateral de énfasis con marca de agua y cuerpo derecho',
      icon: Icons.view_sidebar_outlined,
    ),
    TemplateOption(
      id: 'modern_header',
      name: 'Cabecera Moderna',
      description: 'Franja superior de color y marca de agua + 2 columnas',
      icon: Icons.view_agenda_outlined,
    ),
    TemplateOption(
      id: 'minimalist',
      name: 'Minimalista Clásico',
      description: 'Disposición lineal centrada, limpia y con divisores sutiles',
      icon: Icons.article_outlined,
    ),
    TemplateOption(
      id: 'tech_cards',
      name: 'Tarjetas Modulares',
      description: 'Estructura en cuadrícula de tarjetas con bordes acentuados',
      icon: Icons.dashboard_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeProfile = profiles.firstWhere(
      (p) => p.id == activeProfileId,
      orElse: () => profiles.isNotEmpty ? profiles.first : const CvProfileModel(id: 'temp'),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A).withOpacity(0.55) : Colors.white.withOpacity(0.68),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.70),
              width: 1.0,
            ),
          ),
          child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 780;

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Título arriba de la tarjeta + botón de importar más pequeño
                Row(
                  children: [
                    _buildTitleLabel(isDark, isCompact: true),
                    const Spacer(),
                    if (onImportCv != null)
                      _buildCompactImportButton(isDark),
                  ],
                ),
                const SizedBox(height: 8),
                // 2. Debajo: selector de perfiles guardados + iconos de plantilla (sin texto para que quepa todo sin deslizar)
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: _buildProfileSelector(context, activeProfile, isDark, isCompact: true),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 6,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: templates.map((tpl) => _buildTemplateIconButton(tpl, isDark)).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          final canFitTemplates = constraints.maxWidth > 1180;

          return Row(
            children: [
              // Title / Label for Templates
              _buildTitleLabel(isDark),
              const SizedBox(width: 12),
              const SizedBox(height: 24, child: VerticalDivider(width: 1)),
              const SizedBox(width: 12),

              // Profile Card placed right next to Plantillas de Currículum + Papelera
              _buildProfileSelector(context, activeProfile, isDark),
              const SizedBox(width: 12),
              const SizedBox(height: 24, child: VerticalDivider(width: 1)),
              const SizedBox(width: 12),

              // Template Cards: Flexible distribution if enough room, or scrollable
              Expanded(
                child: canFitTemplates
                    ? Row(
                        children: templates
                            .map((tpl) => Expanded(child: _buildTemplateCard(tpl, isDark, isFlexible: true)))
                            .toList(),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: templates.map((tpl) => _buildTemplateCard(tpl, isDark)).toList(),
                        ),
                      ),
              ),

              if (onImportCv != null) ...[
                const SizedBox(width: 10),
                _buildImportButton(),
              ],
            ],
          );
        },
      ),
    ),
  ),
);
  }

  Widget _buildTitleLabel(bool isDark, {bool isCompact = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(isCompact ? 5 : 6),
          decoration: BoxDecoration(
            color: AppTheme.emerald.withOpacity(0.18),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.style_outlined, color: AppTheme.emerald, size: isCompact ? 16 : 18),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Plantillas de Currículum',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: isCompact ? 12 : 13),
            ),
            if (!isCompact)
              Text(
                'Diferentes disposiciones de datos',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTemplateIconButton(TemplateOption tpl, bool isDark) {
    final isSelected = activeTemplate == tpl.id;
    return Tooltip(
      message: '${tpl.name}: ${tpl.description}',
      child: InkWell(
        onTap: () => onSelectTemplate(tpl.id),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.emerald.withOpacity(0.22)
                : (isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.50)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppTheme.emerald
                  : (isDark ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.60)),
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.emerald.withOpacity(0.20),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Icon(
            tpl.icon,
            size: 20,
            color: isSelected
                ? AppTheme.emerald
                : (isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactImportButton(bool isDark) {
    return Tooltip(
      message: 'Importar currículum desde archivo PDF o DOCX',
      child: InkWell(
        onTap: onImportCv,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.emerald.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.emerald.withOpacity(0.4)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.file_upload_outlined, size: 14, color: AppTheme.emerald),
              SizedBox(width: 4),
              Text(
                'Importar',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.emerald,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSelector(BuildContext context, CvProfileModel activeProfile, bool isDark, {bool isCompact = false}) {
    final popup = PopupMenuButton<String>(
      tooltip: 'Cambiar Alumno / Ficha Activa',
      offset: const Offset(0, 42),
      color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      onSelected: (id) {
        if (id == '__add__') {
          onAddProfile();
        } else {
          onSelectProfile(id);
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Text(
            'Aprendices Matriculados (${profiles.length}):',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ),
        const PopupMenuDivider(),
        ...profiles.map((p) => PopupMenuItem<String>(
              value: p.id,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: p.id == activeProfileId ? AppTheme.emerald : Colors.grey.withOpacity(0.3),
                    child: Text(
                      p.fullName.isNotEmpty ? p.fullName[0].toUpperCase() : 'A',
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          p.fullName.isNotEmpty ? p.fullName : 'Sin nombre',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: p.id == activeProfileId ? FontWeight.bold : FontWeight.normal,
                            color: p.id == activeProfileId ? AppTheme.emerald : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          p.jobTitle,
                          style: const TextStyle(fontSize: 9, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (p.id == activeProfileId)
                    const Icon(Icons.check, size: 14, color: AppTheme.emerald),
                  if (onDeleteProfile != null && profiles.length > 1) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        onDeleteProfile!(p.id);
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.delete_outline_rounded, size: 15, color: Colors.redAccent),
                      ),
                    ),
                  ],
                ],
              ),
            )),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: '__add__',
          child: Row(
            children: [
              Icon(Icons.add, size: 14, color: AppTheme.emerald),
              SizedBox(width: 8),
              Text('Añadir Nuevo Aprendiz', style: TextStyle(fontSize: 11, color: AppTheme.emerald, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
      child: Container(
        constraints: BoxConstraints(maxWidth: isCompact ? double.infinity : 220),
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 12, vertical: isCompact ? 5 : 7),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.50),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.60),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 11,
              backgroundColor: AppTheme.emerald,
              child: Text(
                activeProfile.fullName.isNotEmpty ? activeProfile.fullName[0].toUpperCase() : 'A',
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    activeProfile.fullName.isNotEmpty ? activeProfile.fullName : 'Alumno',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'Cambiar ficha ▾',
                    style: TextStyle(fontSize: 9, color: AppTheme.emerald),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (isCompact) return popup;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        popup,
        if (onDeleteProfile != null && profiles.length > 1) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: 'Eliminar esta ficha de currículum',
            child: InkWell(
              onTap: () => onDeleteProfile!(activeProfile.id),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTemplateCard(TemplateOption tpl, bool isDark, {bool isFlexible = false}) {
    final isSelected = activeTemplate == tpl.id;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        onTap: () => onSelectTemplate(tpl.id),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: isFlexible ? null : 184,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.emerald.withOpacity(0.18)
                : (isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.40)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppTheme.emerald.withOpacity(0.8)
                  : (isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.55)),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.emerald.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            children: [
              _buildMiniPreviewLayout(tpl.id, isSelected),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tpl.name,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected
                                  ? AppTheme.emerald
                                  : (isDark ? Colors.white : Colors.black87),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle, size: 13, color: AppTheme.emerald),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tpl.description,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImportButton() {
    return ElevatedButton.icon(
      onPressed: onImportCv,
      icon: const Icon(Icons.file_upload_outlined, size: 15),
      label: const Text('Importar PDF o Word', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.emerald.withOpacity(0.90),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.white.withOpacity(0.25), width: 1),
        ),
      ),
    );
  }

  // Mini visual schematic representing each layout's data arrangement
  Widget _buildMiniPreviewLayout(String templateId, bool isSelected) {
    final accent = isSelected ? AppTheme.emerald : Colors.grey;
    switch (templateId) {
      case 'sidebar_dark':
        // Two columns: Left colored column, right lines
        return Container(
          width: 26,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: isSelected ? AppTheme.emerald : Colors.grey.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 9,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.7),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(2), bottomLeft: Radius.circular(2)),
                ),
                child: Center(
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 11, height: 2, color: Colors.black87),
                      const SizedBox(height: 2),
                      Container(width: 8, height: 1.5, color: Colors.black38),
                      const SizedBox(height: 4),
                      Container(width: 12, height: 1.5, color: Colors.black26),
                      const SizedBox(height: 2),
                      Container(width: 10, height: 1.5, color: Colors.black26),
                      const SizedBox(height: 2),
                      Container(width: 12, height: 1.5, color: Colors.black26),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

      case 'modern_header':
        // Full top colored banner with 2 columns below
        return Container(
          width: 26,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: isSelected ? AppTheme.emerald : Colors.grey.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              Container(
                height: 11,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.7),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(2), topRight: Radius.circular(2)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                    const SizedBox(width: 2),
                    Expanded(child: Container(height: 2, color: Colors.white)),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(width: 8, height: 1.5, color: Colors.black54),
                            const SizedBox(height: 2),
                            Container(width: 7, height: 1.5, color: Colors.black26),
                            const SizedBox(height: 2),
                            Container(width: 9, height: 1.5, color: Colors.black26),
                          ],
                        ),
                      ),
                      Container(width: 1, color: Colors.black12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(width: 8, height: 1.5, color: Colors.black54),
                              const SizedBox(height: 2),
                              Container(width: 7, height: 1.5, color: Colors.black26),
                              const SizedBox(height: 2),
                              Container(width: 6, height: 1.5, color: Colors.black26),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

      case 'minimalist':
        // Centered clean 1 column
        return Container(
          width: 26,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: isSelected ? AppTheme.emerald : Colors.grey.withOpacity(0.5)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
              const SizedBox(height: 2),
              Container(width: 14, height: 2, color: Colors.black87),
              const SizedBox(height: 2),
              Container(width: 18, height: 1, color: accent.withOpacity(0.7)),
              const SizedBox(height: 3),
              Align(alignment: Alignment.centerLeft, child: Container(width: 16, height: 1.5, color: Colors.black38)),
              const SizedBox(height: 2),
              Align(alignment: Alignment.centerLeft, child: Container(width: 14, height: 1.5, color: Colors.black26)),
              const SizedBox(height: 2),
              Align(alignment: Alignment.centerLeft, child: Container(width: 15, height: 1.5, color: Colors.black26)),
            ],
          ),
        );

      case 'tech_cards':
      default:
        // Grid / Modular cards layout
        return Container(
          width: 26,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: isSelected ? AppTheme.emerald : Colors.grey.withOpacity(0.5)),
          ),
          padding: const EdgeInsets.all(2.5),
          child: Column(
            children: [
              Container(
                height: 7,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(1.5),
                  border: Border.all(color: accent.withOpacity(0.5), width: 0.5),
                ),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
    }
  }
}
