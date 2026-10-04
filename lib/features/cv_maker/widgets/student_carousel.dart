import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/cv_profile_model.dart';

class StudentCarousel extends StatefulWidget {
  final List<CvProfileModel> profiles;
  final String activeProfileId;
  final ValueChanged<String> onSelectProfile;
  final VoidCallback onAddProfile;

  const StudentCarousel({
    super.key,
    required this.profiles,
    required this.activeProfileId,
    required this.onSelectProfile,
    required this.onAddProfile,
  });

  @override
  State<StudentCarousel> createState() => _StudentCarouselState();
}

class _StudentCarouselState extends State<StudentCarousel> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = widget.profiles.where((p) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return p.fullName.toLowerCase().contains(q) || p.jobTitle.toLowerCase().contains(q);
    }).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard.withOpacity(0.9) : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Label & Search Input
          Row(
            children: [
              const Icon(Icons.group_outlined, size: 18, color: AppTheme.emerald),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                    ),
                    children: [
                      TextSpan(
                        text: 'Plantilla de Aprendices (${widget.profiles.length} alumnos): ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: '(Elige un alumno para ver o editar su CV individual)',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Search input
              SizedBox(
                width: 260,
                height: 36,
                child: TextField(
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Buscar alumno u oficio...',
                    prefixIcon: const Icon(Icons.search, size: 16),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                    ),
                  ),
                  onChanged: (val) => setState(() => _search = val),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Horizontal Carousel
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filtered.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, idx) {
                if (idx == filtered.length) {
                  // Add Student Button
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: widget.onAddProfile,
                    child: Container(
                      width: 54,
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkInput : AppTheme.lightInput,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.emerald.withOpacity(0.4),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, color: AppTheme.emerald, size: 20),
                          SizedBox(height: 2),
                          Text('Añadir', style: TextStyle(fontSize: 9, color: AppTheme.emerald, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  );
                }

                final profile = filtered[idx];
                final isActive = profile.id == widget.activeProfileId;

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => widget.onSelectProfile(profile.id),
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive
                          ? (isDark ? const Color(0xFF16252C) : const Color(0xFFE6F4EA))
                          : (isDark ? AppTheme.darkInput : AppTheme.lightInput),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive
                            ? AppTheme.emerald
                            : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                        width: isActive ? 1.5 : 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Row(
                          children: [
                            // Circular Avatar
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: AppTheme.emerald.withOpacity(0.2),
                              backgroundImage: profile.photoUrl.isNotEmpty && profile.photoUrl.startsWith('http')
                                  ? NetworkImage(profile.photoUrl)
                                  : null,
                              child: profile.photoUrl.isEmpty || !profile.photoUrl.startsWith('http')
                                  ? Text(
                                      profile.fullName.isNotEmpty
                                          ? profile.fullName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
                                          : 'AL',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile.fullName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    profile.jobTitle.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Green Active Dot
                            if (isActive)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.emerald,
                                ),
                              ),
                          ],
                        ),
                        // Active indicator line at bottom
                        if (isActive)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 2.5,
                              decoration: BoxDecoration(
                                color: AppTheme.emerald,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
