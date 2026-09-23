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
  final VoidCallback? onImportCv;

  const TemplateSelectorBar({
    super.key,
    required this.activeTemplate,
    required this.onSelectTemplate,
    required this.profiles,
    required this.activeProfileId,
    required this.onSelectProfile,
    required this.onAddProfile,
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard.withOpacity(0.9) : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Row(
        children: [
          // Title / Label for Templates
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.style_outlined, color: AppTheme.emerald, size: 18),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Plantillas de Currículum',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
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
          ),

          const SizedBox(width: 16),
          const VerticalDivider(width: 1, indent: 6, endIndent: 6),
          const SizedBox(width: 16),

          // Template Cards (Horizontal Scrollable)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: templates.map((tpl) {
                  final isSelected = activeTemplate == tpl.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: InkWell(
                      onTap: () => onSelectTemplate(tpl.id),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 184,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.emerald.withOpacity(0.18)
                              : (isDark ? const Color(0xFF161F30) : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.emerald
                                : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
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
                }).toList(),
              ),
            ),
          ),

          const SizedBox(width: 14),

          // Profile / Learner Quick Selector
          PopupMenuButton<String>(
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161F30) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        activeProfile.fullName.isNotEmpty ? activeProfile.fullName : 'Alumno',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'Cambiar ficha ▾',
                        style: TextStyle(fontSize: 9, color: AppTheme.emerald),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (onImportCv != null) ...[
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: onImportCv,
              icon: const Icon(Icons.file_upload_outlined, size: 15),
              label: const Text('Importar PDF o Word', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                foregroundColor: Colors.white,
                elevation: 1,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
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
